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
   paths and the network ([path, point, network-point, walking distance, position of the waypoint]).

The result (navzones.json) is what the mod will need: points, connections and junctions.
"""

from __future__ import annotations

import heapq
import json
import math
from collections import defaultdict, deque
from pathlib import Path

from ..protocol import as_list
from .report import _Nodes, area_graph, capture_points

VERSION = 1
SPACING = 5.0             # Metres between the points.
MIN_CLEARANCE = 0.5       # Points only where the next wall is at least this far away.
WALL_COST = 4.0           # Ways along walls (clearance below MIN_CLEARANCE) cost this much more.
MIN_COMPONENT = 20        # Walkable parts with fewer surfaces are ignored.
MCOM_ZONE = 20.0          # Metres around an MCOM that count as its zone.
CROUCH_HEADROOM = 1.7     # Less headroom: crouching.
COVER_RANGE = 3           # Cells in each of the 8 directions that are checked for cover.
ATTACH_HEIGHT = 1.0       # A waypoint belongs to a surface this close below or above it.
STEP_HEIGHT = 0.6         # Same as report.STEP_HEIGHT: what a straight line may step up or down per cell.

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


def _components(grid: _Area) -> list[set[Surface]]:
    seen: set[Surface] = set()
    components = []
    for start in grid.surfaces:
        if start in seen:
            continue
        component = {start}
        seen.add(start)
        queue = deque([start])
        while queue:
            for neighbour in grid.links.get(queue.popleft(), []):
                if neighbour not in seen:
                    seen.add(neighbour)
                    component.add(neighbour)
                    queue.append(neighbour)
        components.append(component)
    return components


def _place_points(grid: _Area, surfaces: set[Surface], clearance: dict[Surface, float],
                  components: list[set[Surface]]) -> list[Surface]:
    """The surfaces with the most clearance first, each at least SPACING from the others (height counts double, so
    floors above each other get their own points). Every part gets at least one point."""
    candidates = sorted((key for key in surfaces if clearance.get(key, 0.0) >= MIN_CLEARANCE),
                        key=lambda key: (-clearance[key], key))
    points: list[Surface] = []
    buckets: dict[tuple[int, int], list[tuple[float, float, float]]] = defaultdict(list)

    def free(pos: tuple[float, float, float]) -> bool:
        bucket = (math.floor(pos[0] / SPACING), math.floor(pos[2] / SPACING))
        for d_x in (-1, 0, 1):
            for d_z in (-1, 0, 1):
                for other in buckets.get((bucket[0] + d_x, bucket[1] + d_z), []):
                    if math.hypot(pos[0] - other[0], pos[2] - other[2], 2 * (pos[1] - other[1])) < SPACING:
                        return False
        return True

    def add(key: Surface) -> None:
        pos = grid.pos(key)
        points.append(key)
        buckets[(math.floor(pos[0] / SPACING), math.floor(pos[2] / SPACING))].append(pos)

    for key in candidates:
        if free(grid.pos(key)):
            add(key)
    taken = set(points)
    for component in components:
        if not component & taken:
            add(max(component, key=lambda key: (clearance.get(key, 0.0), key)))
    return points


def _cost(grid: _Area, clearance: dict[Surface, float], a: Surface, b: Surface) -> float:
    cost = grid.distance(a, b)
    return cost * WALL_COST if clearance.get(b, 0.0) < MIN_CLEARANCE else cost


def _regions(grid: _Area, points: list[Surface], clearance: dict[Surface, float],
             surfaces: set[Surface]) -> tuple[dict[Surface, int], dict[Surface, float]]:
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
                heapq.heappush(heap, (cost + _cost(grid, clearance, key, neighbour), index, neighbour))
    return owner, distance


def _grid_way(grid: _Area, clearance: dict[Surface, float], start: Surface, goal: Surface,
              allowed: set[int], owner: dict[Surface, int]) -> list[Surface] | None:
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
            new_cost = cost + _cost(grid, clearance, key, neighbour)
            if new_cost < costs.get(neighbour, math.inf):
                costs[neighbour] = new_cost
                came[neighbour] = key
                heapq.heappush(heap, (new_cost + math.dist(grid.pos(neighbour), goal_pos), new_cost, neighbour))
    return None


def _straight(grid: _Area, clearance: dict[Surface, float], a: Surface, b: Surface) -> bool:
    """Whether a soldier can walk the straight line from a to b: every cell on the way has a surface connected to the
    one before, away from walls (except at both ends)."""
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
        if nxt is None or clearance.get(nxt, 0.0) <= 0.0:
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


def _simplify(grid: _Area, clearance: dict[Surface, float], way: list[Surface]) -> list[Surface]:
    """Drops the corners of a way on the grid as long as the straight line stays walkable."""
    result = [way[0]]
    index = 0
    while index < len(way) - 1:
        reach = index + 1
        for candidate in range(len(way) - 1, index + 1, -1):
            if _straight(grid, clearance, way[index], way[candidate]):
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
    point = next((point for point in capture_points(census)
                  if not point["inactive"] and not point.get("hq")
                  and str(point.get("objective") or point.get("name")) == str(area.get("name"))), None)
    if point is None:
        radius = float(area.get("radius") or 0)
        return (lambda x, z: math.hypot(x - center[0], z - center[2]) <= radius), "the whole area"
    if point["zoneCells"]:
        cell = point["cell"]
        shape = {(column + d_column, row + d_row) for column, row in point["zoneCells"]
                 for d_column in (-1, 0, 1) for d_row in (-1, 0, 1)}
        return (lambda x, z: (math.floor(x / cell), math.floor(z / cell)) in shape), \
            f"measured shape ({len(point['zoneCells'])} cells)"
    radius = point["radius"]
    return (lambda x, z: math.hypot(x - center[0], z - center[2]) <= radius), \
        f"radius {radius:.0f} m ({'measured' if point['samples'] else 'not measured'})"


def _round(pos) -> list[float]:
    return [round(value, 2) for value in pos]


def build_zone(census: dict, area: dict, nodes: _Nodes) -> dict:
    grid = _Area(area)
    clearance = _clearance(grid)
    components = [component for component in _components(grid) if len(component) >= MIN_COMPONENT]

    # The waypoints in the area: they choose the parts that are kept, and get attached later.
    walked = []
    radius = float(area.get("radius") or 0)
    for path in sorted(nodes.foot):
        for point, pos in enumerate(nodes.paths[path]["points"], start=1):
            if math.hypot(pos[0] - grid.center[0], pos[2] - grid.center[2]) <= radius:
                walked.append((path, point, pos, grid.surface_at(pos)))
    seeds = {key for _, _, _, key in walked if key is not None}
    kept = [component for component in components if component & seeds]
    if not kept and components:
        kept = [max(components, key=len)]
    surfaces = set().union(*kept) if kept else set()

    points = _place_points(grid, surfaces, clearance, kept)
    owner, owner_distance = _regions(grid, points, clearance, surfaces)

    # Connections between points whose areas touch.
    pairs = set()
    for key in surfaces:
        for neighbour in grid.links.get(key, []):
            a, b = owner.get(key), owner.get(neighbour)
            if a is not None and b is not None and a != b:
                pairs.add((min(a, b), max(a, b)))
    edges = []
    for a, b in sorted(pairs):
        way = _grid_way(grid, clearance, points[a], points[b], {a, b}, owner)
        if way is None:
            continue
        corners = _simplify(grid, clearance, way)
        positions = [grid.pos(key) for key in corners]
        length = sum(math.dist(p, q) for p, q in zip(positions, positions[1:]))
        edges.append([a, b, round(length, 1), [_round(pos) for pos in positions[1:-1]]])

    inside, zone_source = _zone_test(census, area)
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
                              _cover(grid, key), flags])

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
                unattached += 1
                continue
            attach.append([path, point, owner[key], round(owner_distance[key], 1), _round(pos)])

    in_zone = sum(1 for entry in point_entries if entry[5] & IN_ZONE)
    return {
        "name": area.get("name"),
        "kind": area.get("kind"),
        "center": as_list(area.get("center")),
        "radius": area.get("radius"),
        "zone": zone_source,
        "points": point_entries,
        "edges": edges,
        "attach": attach,
        "stats": {
            "surfaces": len(grid.surfaces),
            "kept": len(surfaces),
            "parts": len(kept),
            "points": len(points),
            "inZone": in_zone,
            "edges": len(edges),
            "attached": len(attach),
            "unattached": unattached,
        },
    }


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
    return "\n".join(lines)


def save(data: dict, file: Path) -> None:
    file.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")


def load_or_build(file: Path) -> dict:
    """A saved network (.navzones.json), or the networks of a census (.json.gz)."""
    if file.name.endswith(".navzones.json"):
        return json.loads(file.read_text(encoding="utf-8"))
    from .store import load
    return build(load(file))
