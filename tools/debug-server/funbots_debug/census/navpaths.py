"""Navigation paths: the paths soldiers walk, cut at the zones, so each leads from one zone to another.

Inside the zones (capture points, MCOMs, bases, spawns) the bots walk the networks (navzones.py), so the waypoints only
have to lead from zone to zone. This turns the paths of a level into such navigation paths:

1. Paths soldiers walk are cut where they enter a zone. Each piece between two zones becomes a navigation path: from
   the first waypoint in the one zone to the first waypoint in the other one (both ends lie in the zones, where the
   networks get junctions with them). Pieces in a zone and pieces back into the same zone are dropped.
2. A piece that ends outside of the zones (the path ends, or only goes on over a link) is extended along the paths and
   links to the closest zone (not the one at its other end).
3. Pieces that run along another navigation path between the same zones (DUPLICATE_SHARE of their waypoints within
   DUPLICATE_DISTANCE) are dropped: the pieces of whole paths are kept first, then the extended ones, the shorter first.
4. Zones the paths connect without crossing another zone, but no navigation path does (or only over a detour of more
   than DETOUR times as long), get the shortest way between them over paths and links, and roads (land vehicle paths, ROAD_FACTOR times as long) where no path leads (in rush the
   attackers spawn at their vehicles, the way out is the road).

Paths with vehicles, actions (MCOM, vehicle, beacon), the way to a vehicle or a beacon and air-paths stay as they are;
their links to the cut paths move to the same waypoints of the navigation paths (or the closest one), which link back.
A navigation path is walked back and forth, its first waypoint has "Objectives" (both zones) and "Nav":
{"From": zone at the first waypoint, "To": zone at the last waypoint, "Length": metres}.

A waypoint is in a zone if the closest point of its network (up to MATCH_DISTANCE away, same floor) lies in the zone.

    python -m funbots_debug.census navpaths ../../navzones/MP_012_ConquestSmall0.json [--write] [-v]
"""

from __future__ import annotations

import copy
import heapq
import json
import math
import sqlite3
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from ..paths.mapfile import NO_LOOP, MapData, Node, PathData
from ..protocol import as_list

MATCH_DISTANCE = 6.0      # A waypoint belongs to the closest point of the mesh up to this far away...
FLOOR_HEIGHT = 1.5        # ...on the same floor.
MESH_DISTANCE = 4.0       # A waypoint this close to a point of the mesh (same floor) is on the mesh.
COVER_MARGIN = 0.5        # Metres inside of the circle of a zone a waypoint must be to count as on the mesh.
LINK_MAX = 10.0           # Longer links are no way to walk.
LINK_COST = 2.0           # Metres added for a link: rather stay on a path.
LOOP_CLOSE = 30.0         # A looping path whose ends are this close is walked over from its last waypoint to its first.
EXTEND_MAX = 600.0        # A piece is extended at most this far to the next zone.
DUPLICATE_DISTANCE = 4.0  # A waypoint this close to another navigation path between the same zones runs along it.
DUPLICATE_SHARE = 0.7     # Share of the waypoints of a piece that run along another one: it's dropped.
MOVE_LINK = 5.0           # A link of a kept path to a dropped waypoint moves to a navigation path this close.
DETOUR = 1.5              # Zones whose navigation paths connect them only over this many times the way between them...
ZONE_CROSSING = 20.0      # ...(each zone on the way counted with these metres) get that way as well.
ROAD_FACTOR = 1.5         # Soldiers walk along a road (a land vehicle path) only where no path leads, so it costs more.
MIN_LENGTH = 10.0         # Shorter navigation paths lie where two zones touch, the mesh leads there: no junctions, bots
                          # would walk them back and forth.

Vertex = tuple[int, int]  # path, point


@dataclass
class Route:
    """A navigation path to be: the waypoints from a zone to another zone."""

    start: int  # zone index
    end: int
    vertices: list[Vertex]
    origin: str  # path | extended | crafted
    source: list[int]  # the paths it was made from
    length: float = 0.0


@dataclass
class Result:
    data: MapData
    routes: list[Route]
    zones: list[str]
    fixed: dict[int, str] = field(default_factory=dict)  # old path -> why it was kept as it is
    dropped: dict[int, str] = field(default_factory=dict)  # old foot path -> why no navigation path came from it
    duplicates: int = 0
    on_mesh: int = 0  # pieces dropped: all on the mesh
    short: int = 0  # pieces dropped: shorter than MIN_LENGTH
    old_paths: dict[int, int] = field(default_factory=dict)  # new path -> old path (the kept ones)
    moved_links: int = 0
    lost_links: int = 0
    connectors: int = 0  # paths kept to connect a kept path whose links lead nowhere else


class _Zones:
    """The points of the mesh in buckets, for "in which zone is this waypoint" and "is it on the mesh"."""

    def __init__(self, navzones: dict, cell: float = 10.0):
        self.cell = cell
        zones = navzones.get("zones") or []
        self.names: list[str] = [str(zone.get("name")) for zone in zones]
        self.centers = [as_list(zone.get("center")) for zone in zones]
        # Without a radius (made by hand) the whole zone counts.
        self.radii = [float(zone["radius"]) if zone.get("radius") else math.inf for zone in zones]
        member: dict[int, list[int]] = defaultdict(list)
        for index, zone in enumerate(zones):
            for point in zone.get("inside") or []:
                member[int(point)].append(index)
        self.buckets: dict[tuple[int, int], list[tuple[list[float], list[int]]]] = defaultdict(list)
        for index, point in enumerate(navzones.get("points") or []):
            self.buckets[self._key(point)].append((point, member.get(index, [])))

    def _key(self, pos) -> tuple[int, int]:
        return math.floor(pos[0] / self.cell), math.floor(pos[2] / self.cell)

    def _closest(self, pos, distance: float):
        x, z = self._key(pos)
        best = None
        for d_x in (-1, 0, 1):
            for d_z in (-1, 0, 1):
                for point, zones in self.buckets.get((x + d_x, z + d_z), []):
                    if abs(point[1] - pos[1]) > FLOOR_HEIGHT:
                        continue
                    horizontal = math.hypot(point[0] - pos[0], point[2] - pos[2])
                    if horizontal <= distance and (best is None or horizontal < best[0]):
                        best = (horizontal, zones)
        return best

    def zone_of(self, pos) -> int | None:
        """The zone of the closest point of the mesh; where zones overlap the one whose middle is closest. Only inside of
        the circle of a zone: else the mesh can't be attached there (covered)."""
        best = self._closest(pos, MATCH_DISTANCE)
        if best is None or not best[1] or not self.covered(pos):
            return None
        return min(best[1], key=lambda zone: math.hypot(self.centers[zone][0] - pos[0], self.centers[zone][2] - pos[2]))

    def covered(self, pos) -> bool:
        """Inside of the circle of a zone (the area of the census around it): only there the mesh gets attached to the
        waypoints (navzones.py), close to a point at the edge isn't enough."""
        return any(math.hypot(center[0] - pos[0], center[2] - pos[2]) <= radius - COVER_MARGIN
                   for center, radius in zip(self.centers, self.radii))

    def on_mesh(self, pos) -> bool:
        return self._closest(pos, MESH_DISTANCE) is not None and self.covered(pos)


def fixed_reason(path: PathData) -> str:
    """Why a path stays as it is ("" if it's cut)."""
    if path.vehicles:
        return "vehicles"
    if any(node.data.get("Action") for node in path.nodes):
        return "action"
    for name in path.objectives:
        lower = name.lower()
        if "vehicle" in lower or "beacon" in lower or "interact" in lower:
            return name
    return ""


class _Graph:
    """The waypoints of the paths that get cut, connected along the paths and over links. Roads (land vehicle paths)
    are in it as well, as more expensive ways: only for the shortest ways between zones (step 4)."""

    def __init__(self, data: MapData, foot: list[int], zones: _Zones, roads: list[int] = ()):
        self.data = data
        self.pos: dict[Vertex, tuple[float, float, float]] = {}
        self.zone: dict[Vertex, int | None] = {}
        self.edges: dict[Vertex, list[tuple[Vertex, float]]] = defaultdict(list)
        self.road: set[Vertex] = set()
        walked = set(foot) | set(roads)
        for index in list(foot) + list(roads):
            factor = ROAD_FACTOR if index in roads else 1.0
            nodes = data.paths[index].nodes
            for node in nodes:
                vertex = (index, node.point)
                self.pos[vertex] = node.pos
                self.zone[vertex] = zones.zone_of(node.pos)
                if index in roads:
                    self.road.add(vertex)
            for a, b in zip(nodes, nodes[1:]):
                self._connect((index, a.point), (index, b.point), factor * math.dist(a.pos, b.pos))
            path = data.paths[index]
            if len(nodes) > 2 and path.loops and path.gap <= LOOP_CLOSE:
                self._connect((index, nodes[-1].point), (index, nodes[0].point), factor * path.gap)
        for index in walked:
            for node in data.paths[index].nodes:
                for link in node.links:
                    target = data.node(*link)
                    if link[0] in walked and target is not None and link[0] != index:
                        distance = math.dist(node.pos, target.pos)
                        if distance <= LINK_MAX:
                            self._connect((index, node.point), link, distance + LINK_COST)

    def _connect(self, a: Vertex, b: Vertex, cost: float) -> None:
        if all(other != b for other, _ in self.edges[a]):
            self.edges[a].append((b, cost))
            self.edges[b].append((a, cost))

    def to_zone(self, start: Vertex, avoid_zone: int | None, blocked: set[Vertex]) -> list[Vertex] | None:
        """The shortest way from an outside waypoint over outside waypoints to the first waypoint in a zone (not
        avoid_zone), without the blocked ones. [start, ..., waypoint in the zone]"""
        best = {start: 0.0}
        previous: dict[Vertex, Vertex] = {}
        queue = [(0.0, start)]
        while queue:
            cost, vertex = heapq.heappop(queue)
            if cost > best.get(vertex, math.inf) or cost > EXTEND_MAX:
                continue
            zone = self.zone[vertex]
            if zone is not None:
                if zone == avoid_zone:
                    continue
                way = [vertex]
                while way[-1] in previous:
                    way.append(previous[way[-1]])
                return list(reversed(way))
            for neighbour, step in self.edges[vertex]:
                if neighbour in blocked or neighbour in self.road:
                    continue
                total = cost + step
                if total < best.get(neighbour, math.inf):
                    best[neighbour] = total
                    previous[neighbour] = vertex
                    heapq.heappush(queue, (total, neighbour))
        return None

    def from_zone(self, zone: int) -> dict[int, list[Vertex]]:
        """The shortest ways out of the zone to every other zone it reaches without crossing a third one:
        {zone: [waypoint in the zone, outside waypoints..., waypoint in that zone]}."""
        best: dict[Vertex, float] = {}
        previous: dict[Vertex, Vertex] = {}
        queue = []
        for vertex, own in self.zone.items():
            if own == zone:
                best[vertex] = 0.0
                queue.append((0.0, vertex))
        heapq.heapify(queue)
        found: dict[int, list[Vertex]] = {}
        while queue:
            cost, vertex = heapq.heappop(queue)
            if cost > best.get(vertex, math.inf):
                continue
            own = self.zone[vertex]
            if own is not None and own != zone:
                if own not in found:
                    way = [vertex]
                    while way[-1] in previous:
                        way.append(previous[way[-1]])
                    found[own] = list(reversed(way))
                continue
            for neighbour, step in self.edges[vertex]:
                if self.zone[neighbour] == zone:
                    continue
                total = cost + step
                if total < best.get(neighbour, math.inf):
                    best[neighbour] = total
                    previous[neighbour] = vertex
                    heapq.heappush(queue, (total, neighbour))
        return found

    def length(self, vertices: list[Vertex]) -> float:
        return sum(math.dist(self.pos[a], self.pos[b]) for a, b in zip(vertices, vertices[1:]))


def _pieces(graph: _Graph, path: PathData) -> list[tuple[Vertex | None, list[Vertex], Vertex | None]]:
    """The runs of waypoints outside of the zones: (waypoint in a zone before it or None, run, waypoint in a zone
    after it or None). A looping path is walked around once, starting in a zone."""
    vertices = [(path.index, node.point) for node in path.nodes]
    closed = len(vertices) > 2 and path.loops and path.gap <= LOOP_CLOSE
    if closed:
        first_in = next((i for i, vertex in enumerate(vertices) if graph.zone[vertex] is not None), None)
        if first_in is None:
            return []  # A loop that never comes into a zone.
        vertices = vertices[first_in:] + vertices[:first_in] + [vertices[first_in]]
    pieces = []
    run: list[Vertex] = []
    before: Vertex | None = None
    for vertex in vertices:
        if graph.zone[vertex] is None:
            run.append(vertex)
            continue
        if run:
            pieces.append((before, run, vertex))
            run = []
        before = vertex
    if run:
        pieces.append((before, run, None))
    return pieces


def _route(graph: _Graph, before: Vertex | None, run: list[Vertex], after: Vertex | None, source: int) -> Route | str:
    """The navigation path from a piece, extended at open ends. A reason if there is none."""
    vertices = list(run)
    origin = "path"
    blocked = set(run)
    if before is None:
        way = graph.to_zone(run[0], graph.zone[after] if after else None, blocked)
        if way is None:
            return "ends outside of the zones"
        vertices = list(reversed(way[1:-1])) + vertices
        blocked.update(way)
        before = way[-1]
        origin = "extended"
    if after is None:
        way = graph.to_zone(run[-1], graph.zone[before], blocked)
        if way is None:
            return "ends outside of the zones"
        vertices = vertices + way[1:-1]
        after = way[-1]
        origin = "extended"
    start, end = graph.zone[before], graph.zone[after]
    if start is None or end is None:
        return "ends outside of the zones"
    if start == end:
        return "leads back into the same zone"
    full = [before] + vertices + ([after] if vertices[-1] != after else [])
    return Route(start, end, full, origin, [source], graph.length(full))


def _zone_distance(routes: list[Route], start: int, end: int) -> float:
    """Metres from zone to zone over the navigation paths (ZONE_CROSSING for each zone on the way)."""
    edges: dict[int, list[tuple[int, float]]] = defaultdict(list)
    for route in routes:
        edges[route.start].append((route.end, route.length))
        edges[route.end].append((route.start, route.length))
    best = {start: 0.0}
    queue = [(0.0, start)]
    while queue:
        cost, zone = heapq.heappop(queue)
        if zone == end:
            return cost
        if cost > best.get(zone, math.inf):
            continue
        for other, length in edges[zone]:
            total = cost + length + (ZONE_CROSSING if zone != start else 0.0)
            if total < best.get(other, math.inf):
                best[other] = total
                heapq.heappush(queue, (total, other))
    return math.inf


def _runs_along(graph: _Graph, route: Route, other: Route) -> bool:
    """Whether most waypoints of the route are close to the other one."""
    cell = DUPLICATE_DISTANCE
    buckets: dict[tuple[int, int], list[tuple[float, float, float]]] = defaultdict(list)
    for vertex in other.vertices:
        pos = graph.pos[vertex]
        buckets[(math.floor(pos[0] / cell), math.floor(pos[2] / cell))].append(pos)
    close = 0
    for vertex in route.vertices:
        pos = graph.pos[vertex]
        key = (math.floor(pos[0] / cell), math.floor(pos[2] / cell))
        if any(math.dist(pos, near) <= DUPLICATE_DISTANCE
               for d_x in (-1, 0, 1) for d_z in (-1, 0, 1) for near in buckets.get((key[0] + d_x, key[1] + d_z), [])):
            close += 1
    return close >= DUPLICATE_SHARE * len(route.vertices)


def build(data: MapData, navzones: dict) -> Result:
    zones = _Zones(navzones)
    fixed = {index: fixed_reason(path) for index, path in data.paths.items() if fixed_reason(path)}
    foot = [index for index in sorted(data.paths) if index not in fixed]
    roads = [index for index in sorted(fixed) if fixed[index] == "vehicles"
             and set(data.paths[index].vehicles) <= {"land"}]
    graph = _Graph(data, foot, zones, roads)
    result = Result(MapData(info=copy.deepcopy(data.info)), [], zones.names, fixed)

    # 1. and 2.: the pieces of the paths, extended where they end outside.
    candidates: list[Route] = []
    for index in foot:
        pieces = _pieces(graph, data.paths[index])
        if not pieces:
            inside = any(graph.zone[(index, node.point)] is not None for node in data.paths[index].nodes)
            result.dropped[index] = "inside of a zone" if inside else "never comes into a zone"
            continue
        reasons = []
        for before, run, after in pieces:
            route = _route(graph, before, run, after, index)
            if isinstance(route, Route):
                candidates.append(route)
            else:
                reasons.append(route)
        if reasons and not any(route.source == [index] for route in candidates):
            result.dropped[index] = reasons[0]

    # 3.: no two along each other between the same zones, none where the mesh leads (overlapping zones).
    order = {"path": 0, "extended": 1, "crafted": 2}
    candidates.sort(key=lambda route: (order[route.origin], route.length))
    kept: list[Route] = []
    for route in candidates:
        if all(zones.on_mesh(graph.pos[vertex]) for vertex in route.vertices):
            result.on_mesh += 1
            continue
        if route.length < MIN_LENGTH:
            result.short += 1
            continue
        pair = {route.start, route.end}
        if any({other.start, other.end} == pair and _runs_along(graph, route, other) for other in kept):
            result.duplicates += 1
            continue
        kept.append(route)

    # 4.: neighbouring zones the navigation paths don't connect, or only over a long detour. The shortest ways first,
    # each one can make the next ones unnecessary.
    crafted = []
    for zone in range(len(zones.names)):
        for other, way in graph.from_zone(zone).items():
            if zone < other and len(way) >= 2:
                crafted.append(Route(zone, other, way, "crafted", sorted({vertex[0] for vertex in way}),
                                     graph.length(way)))
    crafted.sort(key=lambda route: route.length)
    for route in crafted:
        if all(zones.on_mesh(graph.pos[vertex]) for vertex in route.vertices) or route.length < MIN_LENGTH:
            continue
        if _zone_distance(kept, route.start, route.end) > DETOUR * route.length:
            kept.append(route)

    result.routes = kept
    _write(result, data, graph)
    return result


def _write(result: Result, data: MapData, graph: _Graph) -> None:
    """The new waypoints: the kept paths first (their links moved), then the navigation paths."""
    paths: dict[int, PathData] = {}
    new_index: dict[int, int] = {}
    for index in sorted(result.fixed):
        new_index[index] = len(paths) + 1
        nodes = [Node(new_index[index], node.point, node.pos, node.input, copy.deepcopy(node.data))
                 for node in data.paths[index].nodes]
        paths[new_index[index]] = PathData(new_index[index], nodes)
        result.old_paths[new_index[index]] = index

    # Where the waypoints of the cut paths are now (the first navigation path that has them).
    moved: dict[Vertex, Vertex] = {}
    for route in result.routes:
        number = len(paths) + 1
        nodes = []
        for point, vertex in enumerate(route.vertices, start=1):
            old = data.node(*vertex)
            assert old is not None
            node_data = {}
            if point == 1:
                start, end = result.zones[route.start], result.zones[route.end]
                node_data = {"Objectives": sorted({start, end}),
                             "Nav": {"From": start, "To": end, "Length": round(route.length, 1)}}
            nodes.append(Node(number, point, old.pos, old.input, node_data))
            moved.setdefault(vertex, (number, point))
        path = PathData(number, nodes)
        path.loops = False
        assert path.first.input >> 8 == NO_LOOP
        paths[number] = path

    # Links of the kept paths.
    nav_nodes = [(node.pos, (node.path, node.point)) for index, path in paths.items()
                 if index not in result.old_paths for node in path.nodes]
    for index, path in list(paths.items()):
        if index not in result.old_paths:
            continue
        for node in path.nodes:
            links = []
            for link in node.links:
                if link[0] in new_index:
                    links.append((new_index[link[0]], link[1]))
                    continue
                target = moved.get(link)
                if target is None:
                    target = _closest(nav_nodes, node.pos)
                if target is None:
                    target = _connector(result, data, graph, paths, moved, link)
                if target is None:
                    result.lost_links += 1
                    continue
                result.moved_links += 1
                links.append(target)
                back = paths[target[0]].nodes[target[1] - 1]
                back.set_links(list(dict.fromkeys(back.links + [(node.path, node.point)])))
            node.set_links(list(dict.fromkeys(links)))
    result.data.paths = paths


def _connector(result: Result, data: MapData, graph: _Graph, paths: dict[int, PathData], moved: dict[Vertex, Vertex],
               start: Vertex) -> Vertex | None:
    """A kept path (the way to a beacon, a vehicle) links to a waypoint that got dropped, far from any navigation path
    (on a path that ran along another one, or never came into a zone): else the bots that get onto it (spawned at the
    beacon) can't leave it. The old waypoints from there to the closest navigation path stay as a path of their own,
    linked to it at its end. Returns where the kept path links to now."""
    way = _way_to(graph, start, moved)
    if way is None:
        return None
    end = moved[way[-1]]
    number = len(paths) + 1
    nodes = []
    for point, vertex in enumerate(way[:-1], start=1):
        old = data.node(*vertex)
        assert old is not None
        nodes.append(Node(number, point, old.pos, old.input, {}))
        moved.setdefault(vertex, (number, point))
    nodes[0].data["Objectives"] = list(paths[end[0]].objectives)
    path = PathData(number, nodes)
    path.loops = False
    paths[number] = path
    nodes[-1].set_links(list(dict.fromkeys(nodes[-1].links + [end])))
    back = paths[end[0]].nodes[end[1] - 1]
    back.set_links(list(dict.fromkeys(back.links + [(number, len(nodes))])))
    result.connectors += 1
    return (number, 1)


def _way_to(graph: _Graph, start: Vertex, targets: dict[Vertex, Vertex]) -> list[Vertex] | None:
    """The shortest way over the old foot paths from the waypoint to one of the targets. [start, ..., target]"""
    if start not in graph.pos:
        return None
    best = {start: 0.0}
    previous: dict[Vertex, Vertex] = {}
    queue = [(0.0, start)]
    while queue:
        cost, vertex = heapq.heappop(queue)
        if cost > best.get(vertex, math.inf) or cost > EXTEND_MAX:
            continue
        if vertex in targets and vertex != start:
            way = [vertex]
            while way[-1] in previous:
                way.append(previous[way[-1]])
            return list(reversed(way))
        for neighbour, step in graph.edges[vertex]:
            if neighbour in graph.road:
                continue
            total = cost + step
            if total < best.get(neighbour, math.inf):
                best[neighbour] = total
                previous[neighbour] = vertex
                heapq.heappush(queue, (total, neighbour))
    return None


def _closest(nodes: list[tuple[tuple[float, float, float], Vertex]], pos) -> Vertex | None:
    best = None
    for node_pos, vertex in nodes:
        distance = math.dist(node_pos, pos)
        if distance <= MOVE_LINK and (best is None or distance < best[0]):
            best = (distance, vertex)
    return best[1] if best else None


MESH_ROW = "@mesh"  # The one row of <map>_navzones in mod.db: the whole mesh (NavZones.lua).
END_SEARCH = 15  # Same as NavRoutes.lua: an end's junction among this many waypoints from the end.


def missing_ends(data: MapData, networks: dict) -> list[tuple[int, str]]:
    """Navigation paths the mod can't use: no junction with the mesh at an end (NavRoutes.lua looks among the
    END_SEARCH waypoints at each end). [(path, "start in <zone>" | "end in <zone>")]"""
    junctions = {(int(entry[0]), int(entry[1])) for entry in networks.get("attach") or []}
    result = []
    for index, path in sorted(data.paths.items()):
        nav = path.first.data.get("Nav")
        if not nav:
            continue
        count = len(path.nodes)
        if not any((index, point) in junctions for point in range(1, min(count, END_SEARCH) + 1)):
            result.append((index, f"start in {nav['From']}"))
        if not any((index, point) in junctions for point in range(count, max(0, count - END_SEARCH), -1)):
            result.append((index, f"end in {nav['To']}"))
    return result


def attach_nodes(data: MapData) -> dict[int, dict]:
    """The waypoints as the networks need them to attach (navzones.build(census, attach=...))."""
    return {index: {"points": [list(node.pos) for node in path.nodes], "vehicles": path.vehicles,
                    "objectives": path.objectives} for index, path in data.paths.items()}


def summary(result: Result, before: MapData, verbose: bool = False) -> str:
    old_count = sum(len(path.nodes) for path in before.paths.values())
    new_count = sum(len(path.nodes) for path in result.data.paths.values())
    origins = defaultdict(int)
    for route in result.routes:
        origins[route.origin] += 1
    lines = [
        f"{len(before.paths)} paths ({old_count} waypoints) -> {len(result.data.paths)} paths ({new_count} waypoints)",
        f"  kept as they are: {len(result.fixed)} (vehicles, actions, ways to vehicles and beacons)",
        f"  navigation paths: {len(result.routes)} (" + ", ".join(f"{count} {origin}" for origin, count
                                                              in sorted(origins.items())) + f"), "
        f"{result.duplicates} pieces dropped along others, {result.on_mesh} on the mesh, "
        f"{result.short} shorter than {MIN_LENGTH:.0f} m",
        f"  cut paths without a navigation path of their own: {len(result.dropped)}",
        f"  links of kept paths moved: {result.moved_links}, lost: {result.lost_links}, "
        f"over connecting paths: {result.connectors}",
    ]
    degree = defaultdict(set)
    for route in result.routes:
        degree[route.start].add(route.end)
        degree[route.end].add(route.start)
    for index, name in enumerate(result.zones):
        neighbours = sorted(result.zones[other] for other in degree.get(index, set()))
        warn = "  <- no navigation path" if not neighbours else ""
        lines.append(f"  {name}: {', '.join(neighbours) or '-'}{warn}")
    if verbose:
        for number, route in enumerate(result.routes, start=1):
            lines.append(f"    {len(result.fixed) + number}: {result.zones[route.start]} -> {result.zones[route.end]}, "
                         f"{route.length:.0f} m, {len(route.vertices)} waypoints, {route.origin} from "
                         f"{', '.join(map(str, route.source))}")
        for index, reason in sorted(result.dropped.items()):
            lines.append(f"    dropped path {index} ({', '.join(before.paths[index].objectives) or '-'}): {reason}")
    return "\n".join(lines)


def write_db(db: Path, name: str, data: MapData, networks: dict) -> None:
    """The waypoints and the networks of one level into mod.db (tables <name>_table and <name>_navzones), as the
    fun-bots-helper imports them. The tables of the other levels stay untouched."""
    connection = sqlite3.connect(db)
    try:
        with connection:
            table = f"{name}_table"
            connection.execute(f"DROP TABLE IF EXISTS {table}")
            connection.execute(f"CREATE TABLE {table} (id INTEGER PRIMARY KEY AUTOINCREMENT, pathIndex INTEGER, "
                               "pointIndex INTEGER, transX FLOAT, transY FLOAT, transZ FLOAT, inputVar INTEGER, "
                               "data TEXT)")
            rows = []
            for line in data.dumps().splitlines()[1:]:
                items = line.split(";", 6)
                rows.append((int(items[0]), int(items[1]), float(items[2]), float(items[3]), float(items[4]),
                             int(items[5]), items[6] if len(items) > 6 else ""))
            connection.executemany(f"INSERT INTO {table} (pathIndex, pointIndex, transX, transY, transZ, inputVar, "
                                   "data) VALUES (?, ?, ?, ?, ?, ?, ?)", rows)
            zones = f"{name}_navzones"
            connection.execute(f"DROP TABLE IF EXISTS {zones}")
            connection.execute(f"CREATE TABLE {zones} (name TEXT, data TEXT)")
            connection.execute(f"INSERT INTO {zones} (name, data) VALUES (?, ?)",
                               (MESH_ROW, json.dumps(networks, separators=(",", ":"))))
    finally:
        connection.close()
