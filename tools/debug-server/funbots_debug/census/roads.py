"""Vehicle paths for a layout from the roads of the other layouts of the level (`census roads`): the vehicle paths
players drove there are the roads. A route over them from a start to a goal (their waypoints, along the paths, their
links, and the waypoints of other paths close by), driven by bots with the vehicles of the team. Where one leaves the
combat-area, gets stuck or is wrecked, the roads around that spot are left out and the route is composed again.

    python -m funbots_debug.census roads XP3_Alborz_TankSuperiority0 --refs XP3_Alborz_ConquestLarge0 \\
        --from 553,548,-88 --to 450.5,420.4,442.6 --team 1 --vehicles M1Abrams,M1128 --objectives "base us,a" --write

XP3_Alborz tank superiority: the roads of conquest leave its combat-area east of the RU base, the drives show where.
"""
from __future__ import annotations

import heapq
import math
from collections import defaultdict

from ..paths.mapfile import MapData
from . import record

JOIN = 6.0         # Waypoints of different roads this close: a crossing.
LINK_COST = 2.0
CROSSING_COST = 1.0
PENALTY = 4.0      # A next route pays this many times for the stretches of the ones before.
SPACING = 4.0      # Metres between the points of a route (as recorded vehicle paths).
SLOW_RANGE = 8.0   # The speed of a point: the slowest players drove within this far.
BLOCK = 20.0       # Roads this close to where a drive failed are left out.


class Roads:
    """The waypoints of the land vehicle paths of the layouts and their connections."""

    def __init__(self, layouts: list[MapData], terrain: str = "land"):
        self.nodes: list[list[float]] = []
        self.speeds: list[int] = []
        self.edges: dict[int, list[tuple[int, float]]] = defaultdict(list)
        index_of: dict[tuple, int] = {}
        for number, data in enumerate(layouts):
            paths = [path for path in data.paths.values() if terrain in [str(v).lower() for v in path.vehicles]]
            for path in paths:
                previous = None
                for node in path.nodes:
                    index_of[(number, path.index, node.point)] = len(self.nodes)
                    self.nodes.append(list(node.pos))
                    self.speeds.append(node.input & 0xF)
                    if previous is not None:
                        self._add(previous, len(self.nodes) - 1, 0.0)
                    previous = len(self.nodes) - 1
                if path.loops and len(path.nodes) > 2:
                    self._add(index_of[(number, path.index, 1)], index_of[(number, path.index, len(path.nodes))], 0.0)
            for path in paths:
                for node in path.nodes:
                    a = index_of.get((number, path.index, node.point))
                    for link in node.links:
                        b = index_of.get((number, link[0], link[1]))
                        if a is not None and b is not None:
                            self._add(a, b, LINK_COST)
        owner = {index: key[:2] for key, index in index_of.items()}
        grid: dict[tuple[int, int], list[int]] = defaultdict(list)
        for index, pos in enumerate(self.nodes):
            grid[(int(pos[0] // JOIN), int(pos[2] // JOIN))].append(index)
        for index, pos in enumerate(self.nodes):
            cx, cz = int(pos[0] // JOIN), int(pos[2] // JOIN)
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for other in grid.get((cx + dx, cz + dz), []):
                        if other > index and owner[other] != owner[index] and \
                                math.dist(pos, self.nodes[other]) <= JOIN:
                            self._add(index, other, CROSSING_COST)

    def _add(self, a: int, b: int, extra: float) -> None:
        metres = math.dist(self.nodes[a], self.nodes[b]) + extra
        self.edges[a].append((b, metres))
        self.edges[b].append((a, metres))

    def route(self, start: list[float], goal: list[float], start_range: float, goal_range: float,
              blocked: set[int], used: set[tuple[int, int]]) -> list[int] | None:
        """The cheapest route over the roads that aren't blocked (used stretches cost PENALTY times)."""
        cost: dict[int, float] = {}
        came: dict[int, int] = {}
        heap = []
        for index, pos in enumerate(self.nodes):
            if index not in blocked and math.dist(pos, start) <= start_range:
                cost[index] = 1.5 * math.dist(pos, start)
                heapq.heappush(heap, (cost[index], index))
        goals = {index for index, pos in enumerate(self.nodes)
                 if math.hypot(pos[0] - goal[0], pos[2] - goal[2]) <= goal_range and abs(pos[1] - goal[1]) < 10}
        while heap:
            current, index = heapq.heappop(heap)
            if current > cost.get(index, math.inf):
                continue
            if index in goals:
                way = [index]
                while index in came:
                    index = came[index]
                    way.append(index)
                return way[::-1]
            for other, metres in self.edges[index]:
                if other in blocked:
                    continue
                new = current + metres * (PENALTY if (min(index, other), max(index, other)) in used else 1.0)
                if new < cost.get(other, math.inf):
                    cost[other] = new
                    came[other] = index
                    heapq.heappush(heap, (new, other))
        return None

    def points(self, way: list[int]) -> list[list[float]]:
        """Points every SPACING metres with the speed players drove there (the slowest within SLOW_RANGE: they slowed
        down before the curves)."""
        result = record.resample([self.nodes[index] for index in way], SPACING)
        for point in result:
            near = [self.speeds[index] for index in way
                    if self.speeds[index] > 0 and math.dist(self.nodes[index], point[:3]) <= SLOW_RANGE]
            point.append(min(near) if near else 3)
        return result

    def near(self, way: list[int], position: list[float]) -> set[int]:
        """The waypoints of the route close to where a drive failed (at least the closest one)."""
        near = {index for index in way if math.dist(self.nodes[index], position[:3]) <= BLOCK}
        return near or {min(way, key=lambda index: math.dist(self.nodes[index], position[:3]))}


def drive_route(server, roads: Roads, start, goal, team: int, vehicles: list[str], pick, tries: int = 6,
                start_range: float = 60.0, goal_range: float = 25.0, blocked: set[int] | None = None,
                used: set | None = None, log=print) -> tuple[list[list[float]] | None, list[int] | None]:
    """A route that all the vehicles drive through: (points with speeds, waypoints of the roads), None if none."""
    blocked = set() if blocked is None else blocked
    used = set() if used is None else used
    for attempt in range(1, tries + 1):
        way = roads.route(start, goal, start_range, goal_range, blocked, used)
        if way is None:
            log("  no route left")
            return None, None
        points = roads.points(way)
        length = sum(math.dist(a[:3], b[:3]) for a, b in zip(points, points[1:]))
        log(f"  try {attempt}: {len(points)} points, {length:.0f} m")
        failed = None
        for name in vehicles:
            vehicle = pick(name, points[0][:3])
            if vehicle is None:
                log(f"    no {name} in the level")
                continue
            result = record.walk(server, points, vehicle=vehicle["id"], timeout=480, team=team)
            if result.get("status") == "exited":
                # Put down onto another vehicle (a parked one at its spawn): once more.
                vehicle = pick(name, points[0][:3]) or vehicle
                result = record.walk(server, points, vehicle=vehicle["id"], timeout=480, team=team)
            status, reached = result.get("status"), int(result.get("reached") or 0)
            log(f"    {vehicle['name']}: {status}, {reached}/{len(points)} points in {result.get('time')} s")
            if status != "done":
                failed = result.get("pos") or points[min(reached, len(points) - 1)][:3]
                break
        if failed is None:
            for a, b in zip(way, way[1:]):
                used.add((min(a, b), max(a, b)))
            return points, way
        near = roads.near(way, failed)
        blocked |= near
        log(f"    {len(near)} road points left out around {[round(c) for c in failed]}")
    return None, None


def add_vehicle_path(data: MapData, points: list[list[float]], objectives: list[str] | None) -> int:
    """The route as a vehicle path (land, driven back and forth), the speeds on its waypoints."""
    index = record.add_path(data, [point[:3] for point in points], vehicles=["land"])
    nodes = data.paths[index].nodes
    for node, point in zip(nodes, points):
        node.input = int(point[3]) if len(point) > 3 and point[3] else 3
    data.paths[index].loops = False
    if objectives:
        nodes[0].data["Objectives"] = list(objectives)
    return index
