"""Small walking networks for the zones around the objectives, generated from the grids of a census.

Inside a capture zone or around an MCOM the bots shall move freely instead of following waypoints. For that each zone
gets a few points (about every SPACING metres) and the straight walkable connections between them. The fine grid of the
census (report.area_graph) is only needed to make them, the network itself is small.

How it is made, per area of the census:

1. The walkable surfaces of the grid and their connections (report.area_graph). Only the parts the waypoints reach are
   kept, so roofs and closed rooms don't get points.
2. Every surface gets its distance to the next wall or edge (clearance).
3. Points: the surfaces with the most clearance first, each at least SPACING away from the points so far.
4. Every surface belongs to the point it is closest to, walking (a Voronoi-diagram along the surfaces). Points whose
   areas touch are connected, with the shortest way between them on the grid, straightened where a straight line is
   walkable. So the network is connected wherever the grid is.
5. Each point knows whether it is inside the zone, indoors, how much cover is around it and whether it needs crouching.
6. The existing waypoints are attached where they enter, leave or end in the area: those are the junctions between the
   paths and the network ([path, point, network-point, walking distance, position of the waypoint, corners of the way
   from the network-point towards the waypoint]).

The result (navzones.json) is what the mod will need: points, connections and junctions.

Land vehicles get a network of their own in each zone ("vehicle"): the same way, with the VEHICLE profile (wide and
open ground only, fewer points), attached to the paths with "Vehicles".
"""

from __future__ import annotations

import heapq
import json
import math
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path

from ..protocol import as_list
from .report import _Nodes, area_graph, capture_points

VERSION = 1
SPACING = 5.0             # Metres between the points.
MIN_CLEARANCE = 0.5       # Points only where the next wall is at least this far away.
WALL_COST = 4.0           # Ways along walls (clearance below MIN_CLEARANCE) cost this much more.
MIN_COMPONENT = 20        # Walkable parts with fewer surfaces are ignored.
MCOM_ZONE = 20.0          # Metres around an MCOM that count as its zone.
BASE_ZONE = 40.0          # Metres around an HQ that count as the base.
CROUCH_HEADROOM = 1.7     # Less headroom: crouching.
COVER_RANGE = 3           # Cells in each of the 8 directions that are checked for cover.
ATTACH_HEIGHT = 1.0       # A waypoint belongs to a surface this close below or above it.
STEP_HEIGHT = 0.6         # Same as report.STEP_HEIGHT: what a straight line may step up or down per cell.

# Land vehicles: wide and open ground only.
VEHICLE_CLEARANCE = 1.8   # Metres to the next wall (half the width of a tank, and some).
VEHICLE_NORMAL_Y = 0.75   # Slopes up to about 41 degrees.
VEHICLE_HEADROOM = 4.0    # Under a roof only with this much space.


@dataclass(frozen=True)
class Profile:
    """What a network is made for."""

    spacing: float          # Metres between the points.
    point_clearance: float  # Points only where the next wall is at least this far away.
    line_clearance: float   # Straight lines only over cells with more clearance than this (0: off the walls).
    wall_clearance: float   # Ways over cells with less clearance cost WALL_COST times as much.
    attach_range: float     # A waypoint is attached to a surface of the network up to this far away.
    attach_distance: float  # Junctions more than this far (walking) from their network-point are left out.


SOLDIER = Profile(SPACING, MIN_CLEARANCE, 0.0, MIN_CLEARANCE, 1.0, 20.0)
VEHICLE = Profile(10.0, VEHICLE_CLEARANCE, VEHICLE_CLEARANCE, VEHICLE_CLEARANCE, 6.0, 30.0)

# Flags of a point.
IN_ZONE = 1
INDOOR = 2
CROUCH = 4

Surface = tuple[int, int, int]  # row, column, layer


class _Area:
    """The grid of one area of the census, with what the generator needs of it."""

    def __init__(self, area: dict):
        self.area = area
        self.step = float(area["step"])
        self.x0 = float(area["x0"])
        self.z0 = float(area["z0"])
        self.center = as_list(area.get("center"))
        self.surfaces, self.links = area_graph(area)
        self.by_cell: dict[tuple[int, int], list[Surface]] = defaultdict(list)
        for key in self.surfaces:
            self.by_cell[(key[0], key[1])].append(key)

    def pos(self, key: Surface) -> tuple[float, float, float]:
        row, column, _ = key
        return self.x0 + column * self.step, self.surfaces[key][0], self.z0 + row * self.step

    def cell_of(self, x: float, z: float) -> tuple[int, int]:
        return round((z - self.z0) / self.step), round((x - self.x0) / self.step)

    def surface_at(self, pos: list[float], height: float = ATTACH_HEIGHT) -> Surface | None:
        best = None
        for key in self.by_cell.get(self.cell_of(pos[0], pos[2]), []):
            difference = abs(self.surfaces[key][0] - pos[1])
            if difference <= height and (best is None or difference < best[0]):
                best = (difference, key)
        return best[1] if best else None

    def distance(self, a: Surface, b: Surface) -> float:
        return math.dist(self.pos(a), self.pos(b))


def _clearance(grid: _Area) -> dict[Surface, float]:
    """Distance to the next surface that isn't connected to all four neighbours (a wall, an edge, a step)."""
    clearance: dict[Surface, float] = {}
    queue = deque()
    for key in grid.surfaces:
        if len(grid.links.get(key, [])) < 4:
            clearance[key] = 0.0
            queue.append(key)
    while queue:
        key = queue.popleft()
        for neighbour in grid.links.get(key, []):
            if neighbour not in clearance:
                clearance[neighbour] = clearance[key] + grid.step
                queue.append(neighbour)
    return clearance


def _components(grid: _Area, allowed: set[Surface] | None = None) -> list[set[Surface]]:
    seen: set[Surface] = set()
    components = []
    for start in grid.surfaces if allowed is None else allowed:
        if start in seen:
            continue
        component = {start}
        seen.add(start)
        queue = deque([start])
        while queue:
            for neighbour in grid.links.get(queue.popleft(), []):
                if neighbour not in seen and (allowed is None or neighbour in allowed):
                    seen.add(neighbour)
                    component.add(neighbour)
                    queue.append(neighbour)
        components.append(component)
    return components


def _place_points(grid: _Area, surfaces: set[Surface], clearance: dict[Surface, float],
                  components: list[set[Surface]], profile: Profile = SOLDIER) -> list[Surface]:
    """The surfaces with the most clearance first, each at least the spacing from the others (height counts double, so
    floors above each other get their own points). Every part gets at least one point."""
    spacing = profile.spacing
    candidates = sorted((key for key in surfaces if clearance.get(key, 0.0) >= profile.point_clearance),
                        key=lambda key: (-clearance[key], key))
    points: list[Surface] = []
    buckets: dict[tuple[int, int], list[tuple[float, float, float]]] = defaultdict(list)

    def free(pos: tuple[float, float, float]) -> bool:
        bucket = (math.floor(pos[0] / spacing), math.floor(pos[2] / spacing))
        for d_x in (-1, 0, 1):
            for d_z in (-1, 0, 1):
                for other in buckets.get((bucket[0] + d_x, bucket[1] + d_z), []):
                    if math.hypot(pos[0] - other[0], pos[2] - other[2], 2 * (pos[1] - other[1])) < spacing:
                        return False
        return True

    def add(key: Surface) -> None:
        pos = grid.pos(key)
        points.append(key)
        buckets[(math.floor(pos[0] / spacing), math.floor(pos[2] / spacing))].append(pos)

    for key in candidates:
        if free(grid.pos(key)):
            add(key)
    taken = set(points)
    for component in components:
        if not component & taken:
            add(max(component, key=lambda key: (clearance.get(key, 0.0), key)))
    return points


def _cost(grid: _Area, clearance: dict[Surface, float], a: Surface, b: Surface, profile: Profile = SOLDIER) -> float:
    cost = grid.distance(a, b)
    return cost * WALL_COST if clearance.get(b, 0.0) < profile.wall_clearance else cost


def _regions(grid: _Area, points: list[Surface], clearance: dict[Surface, float], surfaces: set[Surface],
             profile: Profile = SOLDIER) -> tuple[dict[Surface, int], dict[Surface, float]]:
    """Every surface belongs to the point it's closest to, walking."""
    owner: dict[Surface, int] = {}
    distance: dict[Surface, float] = {}
    heap = [(0.0, index, key) for index, key in enumerate(points)]
    heapq.heapify(heap)
    while heap:
        cost, index, key = heapq.heappop(heap)
        if key in owner:
            continue
        owner[key] = index
        distance[key] = cost
        for neighbour in grid.links.get(key, []):
            if neighbour in surfaces and neighbour not in owner:
                heapq.heappush(heap, (cost + _cost(grid, clearance, key, neighbour, profile), index, neighbour))
    return owner, distance


def _grid_way(grid: _Area, clearance: dict[Surface, float], start: Surface, goal: Surface,
              allowed: set[int], owner: dict[Surface, int], profile: Profile = SOLDIER) -> list[Surface] | None:
    """Shortest way on the grid (A*), only over the surfaces of the allowed points."""
    goal_pos = grid.pos(goal)
    heap = [(math.dist(grid.pos(start), goal_pos), 0.0, start)]
    came: dict[Surface, Surface | None] = {start: None}
    costs = {start: 0.0}
    while heap:
        _, cost, key = heapq.heappop(heap)
        if key == goal:
            way = [key]
            while came[way[-1]] is not None:
                way.append(came[way[-1]])  # type: ignore[arg-type]
            return way[::-1]
        if cost > costs.get(key, math.inf):
            continue
        for neighbour in grid.links.get(key, []):
            if owner.get(neighbour) not in allowed:
                continue
            new_cost = cost + _cost(grid, clearance, key, neighbour, profile)
            if new_cost < costs.get(neighbour, math.inf):
                costs[neighbour] = new_cost
                came[neighbour] = key
                heapq.heappush(heap, (new_cost + math.dist(grid.pos(neighbour), goal_pos), new_cost, neighbour))
    return None


def _straight(grid: _Area, clearance: dict[Surface, float], a: Surface, b: Surface, profile: Profile = SOLDIER,
              allowed: set[Surface] | None = None) -> bool:
    """Whether a soldier (or vehicle) can move the straight line from a to b: every cell on the way has a surface
    connected to the one before, away from walls (except at both ends)."""
    ax, _, az = grid.pos(a)
    bx, _, bz = grid.pos(b)
    samples = max(1, math.ceil(math.hypot(bx - ax, bz - az) / (grid.step / 2)))
    current = a
    for index in range(1, samples + 1):
        t = index / samples
        cell = grid.cell_of(ax + (bx - ax) * t, az + (bz - az) * t)
        if cell == (current[0], current[1]):
            continue
        if cell == (b[0], b[1]):
            return b == current or b in grid.links.get(current, []) or _diagonal(grid, current, b)
        nxt = None
        y = grid.surfaces[current][0]
        for key in grid.by_cell.get(cell, []):
            if key in grid.links.get(current, []) or (abs(grid.surfaces[key][0] - y) <= STEP_HEIGHT and
                                                      _diagonal(grid, current, key)):
                nxt = key
                break
        if nxt is None or (allowed is not None and nxt not in allowed):
            return False
        value = clearance.get(nxt, 0.0)
        if value <= 0.0 or value < profile.line_clearance:
            return False
        current = nxt
    return current == b


def _diagonal(grid: _Area, a: Surface, b: Surface) -> bool:
    """Diagonal neighbours: connected over one of the two cells in between."""
    if abs(a[0] - b[0]) != 1 or abs(a[1] - b[1]) != 1:
        return False
    for middle in ((a[0], b[1]), (b[0], a[1])):
        for key in grid.by_cell.get(middle, []):
            links = grid.links.get(key, [])
            if a in links and b in links:
                return True
    return False


def _simplify(grid: _Area, clearance: dict[Surface, float], way: list[Surface], profile: Profile = SOLDIER,
              allowed: set[Surface] | None = None) -> list[Surface]:
    """Drops the corners of a way on the grid as long as the straight line stays walkable."""
    result = [way[0]]
    index = 0
    while index < len(way) - 1:
        reach = index + 1
        for candidate in range(len(way) - 1, index + 1, -1):
            if _straight(grid, clearance, way[index], way[candidate], profile, allowed):
                reach = candidate
                break
        result.append(way[reach])
        index = reach
    return result


def _cover(grid: _Area, key: Surface) -> int:
    """In how many of the 8 directions a wall is within COVER_RANGE cells (at chest height, or no floor)."""
    blocked = 0
    for d_row, d_column in ((0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)):
        current = key
        for _ in range(COVER_RANGE):
            target = (current[0] + d_row, current[1] + d_column)
            y = grid.surfaces[current][0]
            nxt = next((other for other in grid.by_cell.get(target, [])
                        if abs(grid.surfaces[other][0] - y) <= STEP_HEIGHT
                        and (other in grid.links.get(current, []) or _diagonal(grid, current, other))), None)
            if nxt is None:
                blocked += 1
                break
            current = nxt
    return blocked


def _zone_test(census: dict, area: dict):
    """Whether a position is inside the zone of the objective of the area: the measured shape of the capture point,
    its radius, or MCOM_ZONE around an MCOM."""
    center = as_list(area.get("center"))
    if area.get("kind") == "mcom":
        return (lambda x, z: math.hypot(x - center[0], z - center[2]) <= MCOM_ZONE), f"{MCOM_ZONE:.0f} m around the MCOM"
    if area.get("kind") == "base":
        return (lambda x, z: math.hypot(x - center[0], z - center[2]) <= BASE_ZONE), f"{BASE_ZONE:.0f} m around the HQ"
    point = next((point for point in capture_points(census)
                  if not point["inactive"] and not point.get("hq")
                  and str(point.get("objective") or point.get("name")) == str(area.get("name"))), None)
    if point is None:
        radius = float(area.get("radius") or 0)
        return (lambda x, z: math.hypot(x - center[0], z - center[2]) <= radius), "the whole area"
    if point["zoneCells"]:
        # Where players were inside, and within the measured radius where nobody was ever seen outside: the cells
        # with players inside lie along the waypoints, the zone goes beyond them.
        cell = point["cell"]
        radius = point["radius"]
        inside_cells = point["zoneCells"]
        outside_cells = point["outsideCells"] - inside_cells

        def inside(x: float, z: float) -> bool:
            key = (math.floor(x / cell), math.floor(z / cell))
            if key in inside_cells:
                return True
            return math.hypot(x - center[0], z - center[2]) <= radius and key not in outside_cells

        return inside, f"measured: radius {radius:.0f} m, {len(inside_cells)} cells inside, " \
            f"{len(outside_cells)} outside"
    radius = point["radius"]
    return (lambda x, z: math.hypot(x - center[0], z - center[2]) <= radius), \
        f"radius {radius:.0f} m ({'measured' if point['samples'] else 'not measured'})"


def _round(pos) -> list[float]:
    return [round(value, 2) for value in pos]


def _network(grid: _Area, clearance: dict[Surface, float], allowed: set[Surface],
             walked: list[tuple[int, int, list[float], Surface | None]], nodes: _Nodes, inside, profile: Profile,
             cover: bool) -> dict:
    """Points, connections and junctions over the allowed surfaces. walked: the waypoints in the area that choose the
    parts that are kept and get attached ([path, point, position, surface])."""
    components = [component for component in _components(grid, allowed) if len(component) >= MIN_COMPONENT]
    seeds = {key for _, _, _, key in walked if key is not None}
    kept = [component for component in components if component & seeds]
    if not kept and components and cover:
        kept = [max(components, key=len)]
    surfaces = set().union(*kept) if kept else set()

    points = _place_points(grid, surfaces, clearance, kept, profile)
    owner, owner_distance = _regions(grid, points, clearance, surfaces, profile)

    # Connections between points whose areas touch.
    pairs = set()
    for key in surfaces:
        for neighbour in grid.links.get(key, []):
            a, b = owner.get(key), owner.get(neighbour)
            if a is not None and b is not None and a != b:
                pairs.add((min(a, b), max(a, b)))
    edges = []
    for a, b in sorted(pairs):
        way = _grid_way(grid, clearance, points[a], points[b], {a, b}, owner, profile)
        if way is None:
            continue
        corners = _simplify(grid, clearance, way, profile, surfaces)
        positions = [grid.pos(key) for key in corners]
        length = sum(math.dist(p, q) for p, q in zip(positions, positions[1:]))
        edges.append([a, b, round(length, 1), [_round(pos) for pos in positions[1:-1]]])
    if cover:
        edges += _trace_edges(grid, owner, points, edges, walked, nodes)

    point_entries = []
    for key in points:
        x, y, z = grid.pos(key)
        flags = 0
        if inside(x, z):
            flags |= IN_ZONE
        headroom = grid.surfaces[key][3]
        if key[2] > 0 and headroom >= 0:
            flags |= INDOOR
        if 0 <= headroom < CROUCH_HEADROOM:
            flags |= CROUCH
        point_entries.append([round(x, 2), round(y, 2), round(z, 2), round(clearance.get(key, 0.0), 1),
                              _cover(grid, key) if cover else 0, flags])

    # Junctions with the waypoints: where a path enters, leaves or ends in the area.
    attach = []
    unattached = 0
    by_path: dict[int, list[tuple[int, list[float], Surface | None]]] = defaultdict(list)
    for path, point, pos, key in walked:
        by_path[path].append((point, pos, key))
    for path, entries in by_path.items():
        count = len(nodes.paths[path]["points"])
        points_in = {point for point, _, _ in entries}
        for point, pos, key in entries:
            ends_run = point - 1 not in points_in or point + 1 not in points_in or point in (1, count)
            if not ends_run:
                continue
            if key is None or key not in owner:
                key = _nearest_owned(grid, owner, pos, profile.attach_range)
            if key is None:
                unattached += 1
                continue
            # The way from the network-point to the waypoint, around walls (the action-node of an MCOM in a room).
            network = owner[key]
            if owner_distance[key] > profile.attach_distance:
                unattached += 1
                continue
            way = _grid_way(grid, clearance, points[network], key, {network}, owner, profile)
            corners = [_round(grid.pos(corner)) for corner in _simplify(grid, clearance, way, profile, surfaces)[1:]] \
                if way and len(way) > 1 else []
            attach.append([path, point, network, round(owner_distance[key] + math.dist(grid.pos(key), pos), 1),
                           _round(pos), corners])

    return {
        "points": point_entries,
        "edges": edges,
        "attach": attach,
        "stats": {
            "kept": len(surfaces),
            "parts": len(kept),
            "points": len(points),
            "inZone": sum(1 for entry in point_entries if entry[5] & IN_ZONE),
            "edges": len(edges),
            "attached": len(attach),
            "unattached": unattached,
        },
    }


def _nearest_owned(grid: _Area, owner: dict[Surface, int], pos: list[float], distance: float) -> Surface | None:
    """The surface of the network closest to the position, up to the distance away (horizontally) and 3 m up or down."""
    row, column = grid.cell_of(pos[0], pos[2])
    cells = math.ceil(distance / grid.step)
    best = None
    for d_row in range(-cells, cells + 1):
        for d_column in range(-cells, cells + 1):
            for key in grid.by_cell.get((row + d_row, column + d_column), []):
                if key not in owner:
                    continue
                x, y, z = grid.pos(key)
                horizontal = math.hypot(x - pos[0], z - pos[2])
                if horizontal <= distance and abs(y - pos[1]) <= 3.0 and (best is None or horizontal < best[0]):
                    best = (horizontal, key)
    return best[1] if best else None


def _trace_edges(grid: _Area, owner: dict[Surface, int], points: list[Surface], edges: list,
                 walked: list[tuple[int, int, list[float], Surface | None]], nodes: _Nodes) -> list:
    """Connections along the waypoints between parts of the network that the grid doesn't connect: stairs, ladders,
    jumps the vertical rays don't see. A path that walks from one part into another joins them, over its waypoints."""
    parent = list(range(len(points)))

    def find(index: int) -> int:
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    for a, b, *_ in edges:
        parent[find(a)] = find(b)

    by_path: dict[int, dict[int, list[float]]] = defaultdict(dict)
    owned: dict[tuple[int, int], int] = {}
    for path, point, pos, key in walked:
        by_path[path][point] = pos
        key = key if key is not None and key in owner else _nearest_owned(grid, owner, pos, 1.0)
        if key is not None:
            owned[(path, point)] = owner[key]

    result = []
    for path, positions in by_path.items():
        last = None  # (point, network-point)
        for point in sorted(positions):
            network = owned.get((path, point))
            if network is None:
                continue
            if last is not None and point - last[0] <= 40 and find(last[1]) != find(network):
                corners = [_round(positions[index]) for index in range(last[0], point + 1) if index in positions]
                way = [points_pos for points_pos in [grid.pos(points[last[1]])] + corners + [grid.pos(points[network])]]
                length = sum(math.dist(p, q) for p, q in zip(way, way[1:]))
                result.append([last[1], network, round(length, 1), corners])
                parent[find(last[1])] = find(network)
            last = (point, network)
    return result


def _walked(grid: _Area, area: dict, nodes: _Nodes, paths: set[int], height: float) -> list:
    radius = float(area.get("radius") or 0)
    walked = []
    for path in sorted(paths):
        for point, pos in enumerate(nodes.paths[path]["points"], start=1):
            if math.hypot(pos[0] - grid.center[0], pos[2] - grid.center[2]) <= radius:
                walked.append((path, point, pos, grid.surface_at(pos, height)))
    return walked


def build_zone(census: dict, area: dict, nodes: _Nodes) -> dict:
    grid = _Area(area)
    clearance = _clearance(grid)
    inside, zone_source = _zone_test(census, area)

    soldier = _network(grid, clearance, set(grid.surfaces), _walked(grid, area, nodes, nodes.foot, ATTACH_HEIGHT),
                       nodes, inside, SOLDIER, True)

    # Land vehicles: wide, open, not too steep. The waypoints of vehicle-paths are the position of the vehicle, about a
    # metre above the ground.
    land = {path for path, entry in nodes.paths.items()
            if "land" in [str(name).lower() for name in entry.get("vehicles") or []]}
    allowed = {key for key, (_, normal, _, headroom) in grid.surfaces.items()
               if clearance.get(key, 0.0) >= VEHICLE_CLEARANCE and normal >= VEHICLE_NORMAL_Y
               and (headroom < 0 or headroom >= VEHICLE_HEADROOM)}
    vehicle = _network(grid, clearance, allowed, _walked(grid, area, nodes, land, 3.0), nodes, inside, VEHICLE,
                       False) if land else None

    zone = {
        "name": area.get("name"),
        "kind": area.get("kind"),
        "center": as_list(area.get("center")),
        "radius": area.get("radius"),
        "zone": zone_source,
        "points": soldier["points"],
        "edges": soldier["edges"],
        "attach": soldier["attach"],
        "stats": dict(soldier["stats"], surfaces=len(grid.surfaces)),
    }
    if vehicle is not None and vehicle["points"]:
        zone["vehicle"] = vehicle
    return zone


def build(census: dict) -> dict:
    """The networks of all areas of a census."""
    nodes = _Nodes(census)
    zones = [build_zone(census, area, nodes) for area in census.get("areas") or []]
    return {"version": VERSION, "map": census.get("paths"), "spacing": SPACING, "zones": zones}


def summary(data: dict) -> str:
    lines = [f"zone networks of {data.get('map')}"]
    for zone in data["zones"]:
        stats = zone["stats"]
        lines.append(f"  {zone['name']} ({zone['kind']}, zone: {zone['zone']}): {stats['points']} points "
                     f"({stats['inZone']} in the zone), {stats['edges']} connections, {stats['parts']} parts, "
                     f"{stats['attached']} junctions with waypoints ({stats['unattached']} without surface)")
        vehicle = (zone.get("vehicle") or {}).get("stats")
        if vehicle:
            lines.append(f"    vehicles: {vehicle['points']} points ({vehicle['inZone']} in the zone), "
                         f"{vehicle['edges']} connections, {vehicle['parts']} parts, {vehicle['attached']} junctions "
                         f"with vehicle-paths ({vehicle['unattached']} without surface)")
    return "\n".join(lines)


def save(data: dict, file: Path) -> None:
    file.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")


def load_or_build(file: Path) -> dict:
    """A saved network (.navzones.json), or the networks of a census (.json.gz)."""
    if file.name.endswith(".navzones.json"):
        return json.loads(file.read_text(encoding="utf-8"))
    from .store import load
    return build(load(file))
