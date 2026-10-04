"""The walking mesh of a level, generated from the grids of a census, with the zones as labels on its points.

Inside a capture zone, around an MCOM, in a base the bots move freely instead of following waypoints. For that the
level gets a mesh over the areas of its census: a few points (about every SPACING metres) and the straight walkable
connections between them. The fine grid of the census (report.area_graph) is only needed to make it, the mesh itself is
small. Areas overlap (rush: the bases of one stage lie at the MCOMs of the other), so all grids are put onto one lattice
first (_Merged) and there is one mesh, the zones are lists of its points.

1. The walkable surfaces of the grids and their connections (report.area_graph), on one lattice. Only the parts the
   waypoints reach are kept, so roofs and closed rooms don't get points.
2. Every surface gets its distance to the next wall or edge (clearance).
3. Points: the surfaces with the most clearance first, each at least SPACING away from the points so far.
4. Every surface belongs to the point it is closest to, walking (a Voronoi-diagram along the surfaces). Points whose
   areas touch are connected, with the shortest way between them on the grid, straightened where a straight line is
   walkable. So the mesh is connected wherever the grid is.
5. Each point knows whether it is in a zone, indoors, how much cover is around it and whether it needs crouching. Each
   zone lists its points.
6. The waypoints are attached where they enter, leave or end in the areas: those are the junctions between the paths
   and the mesh ([path, point, mesh-point, walking distance, position of the waypoint, corners of the way from the
   mesh-point towards the waypoint]).

Format (version 2): {map, spacing, points, edges, attach, stats, vehicle: {points, edges, attach, stats},
zones: [{name, kind, center, radius, zone, inside: [points], vehicleInside: [vehicle-points]}]}.

Land vehicles get a mesh of their own ("vehicle"): the same way, with the VEHICLE profile (wide and open ground only,
fewer points), attached to the paths with "Vehicles".
"""

from __future__ import annotations

import heapq
import json
import math
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path

from ..protocol import as_list
from .check import apply as check_apply
from .report import _Nodes, area_graph, capture_points

VERSION = 2               # 2: one mesh for the level, the zones as labels on its points.
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
MERGE_HEIGHT = 0.5        # Surfaces of the same cell from overlapping areas this close in height are the same.

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
    # Without a surface there (stairs down into a metro the census didn't measure): the end of a path is attached
    # straight to the closest point on its floor up to this far away (0: never).
    attach_fallback: float = 0.0


SOLDIER = Profile(SPACING, MIN_CLEARANCE, 0.0, MIN_CLEARANCE, 1.0, 20.0, 8.0)
FALLBACK_HEIGHT = 1.5     # The floor of a waypoint for attach_fallback: points this far above or below it...
FALLBACK_CLEARANCE = 1.0  # ...and this far from the next wall (not squeezed in a corner the bots don't get out of).
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
             cover: bool, attached: tuple[list, _Nodes] | None = None) -> dict:
    """Points, connections and junctions over the allowed surfaces. walked: the waypoints in the area that choose the
    parts that are kept and get attached ([path, point, position, surface]). attached: other waypoints to attach instead
    (walked, nodes), e.g. the paths cut at the zones (navpaths.py), while the parts still come from the census."""
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
    if attached is not None:
        walked, nodes = attached
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
                fallback = _closest_point(grid, clearance, points, pos, profile.attach_fallback) \
                    if point in (1, count) and profile.attach_fallback > 0 else None
                if fallback is None:
                    unattached += 1
                else:
                    attach.append([path, point, fallback, round(math.dist(grid.pos(points[fallback]), pos), 1),
                                   _round(pos), []])
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


def _closest_point(grid: _Area, clearance: dict[Surface, float], points: list[Surface], pos: list[float],
                   distance: float) -> int | None:
    """The point of the network closest to the position on its floor (FALLBACK_HEIGHT) with room around it
    (FALLBACK_CLEARANCE), up to the distance."""
    best = None
    for index, key in enumerate(points):
        x, y, z = grid.pos(key)
        if abs(y - pos[1]) > FALLBACK_HEIGHT or clearance.get(key, 0.0) < FALLBACK_CLEARANCE:
            continue
        horizontal = math.hypot(x - pos[0], z - pos[2])
        if horizontal <= distance and (best is None or horizontal < best[0]):
            best = (horizontal, index)
    return best[1] if best else None


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
                # 1: along waypoints, a way a person walked (the check of the mesh leaves it alone).
                result.append([last[1], network, round(length, 1), corners, 1])
                parent[find(last[1])] = find(network)
            last = (point, network)
    return result


def _blocked_pairs(surfaces: dict, links: dict) -> set[tuple[Surface, Surface]]:
    """Neighbour surfaces of one area a soldier could step between (as area_graph looks at them) that its rays found
    a wall between: not linked."""
    by_cell: dict[tuple[int, int], list[Surface]] = defaultdict(list)
    for key in surfaces:
        by_cell[(key[0], key[1])].append(key)
    blocked = set()
    for key, surface in surfaces.items():
        for d_row, d_column in ((0, 1), (1, 0)):
            for other in by_cell.get((key[0] + d_row, key[1] + d_column), []):
                if abs(surfaces[other][0] - surface[0]) <= STEP_HEIGHT and other not in links.get(key, []):
                    blocked.add((key, other))
    return blocked


class _Merged:
    """The grids of all areas on one lattice: one mesh for the whole level, the zones are only labels on its points.
    All areas have the same cell size, each lies on the lattice shifted by whole cells (at most a quarter of a cell
    off). Surfaces of the same cell from several areas (where they overlap) are one if their heights match. Two of them
    are connected if an area connects them and no other area found a wall between them: where areas overlap, the rays
    of one may start inside of a solid (the inside of a wall, of a slab) and see nothing there."""

    def __init__(self, areas: list[dict]):
        self.step = float(areas[0]["step"])
        self.x0 = self.z0 = 0.0
        self.areas = areas
        cells: dict[tuple[int, int], list[list]] = defaultdict(list)
        mapping: dict[tuple[int, Surface], tuple[tuple[int, int], int]] = {}
        area_links = []
        area_blocked = []
        for index, area in enumerate(areas):
            if abs(float(area["step"]) - self.step) > 1e-6:
                raise ValueError(f"area {area.get('name')}: cell size {area['step']} instead of {self.step}")
            d_row = round(float(area["z0"]) / self.step)
            d_column = round(float(area["x0"]) / self.step)
            surfaces, links = area_graph(area)
            area_blocked.append((index, _blocked_pairs(surfaces, links)))
            for (row, column, layer), surface in surfaces.items():
                cell = (row + d_row, column + d_column)
                entries = cells[cell]
                slot = next((i for i, entry in enumerate(entries) if abs(entry[0] - surface[0]) <= MERGE_HEIGHT), None)
                if slot is None:
                    entries.append(list(surface))
                    slot = len(entries) - 1
                mapping[(index, (row, column, layer))] = (cell, slot)
            area_links.append((index, links))

        # Layers of a cell from the top down, as in the grid of one area.
        order: dict[tuple[tuple[int, int], int], Surface] = {}
        self.surfaces: dict[Surface, tuple] = {}
        for cell, entries in cells.items():
            for layer, slot in enumerate(sorted(range(len(entries)), key=lambda i: -entries[i][0])):
                key = (cell[0], cell[1], layer)
                order[(cell, slot)] = key
                self.surfaces[key] = tuple(entries[slot])
        walls = set()
        for index, blocked in area_blocked:
            for a, b in blocked:
                merged_a, merged_b = order[mapping[(index, a)]], order[mapping[(index, b)]]
                walls.add((merged_a, merged_b))
                walls.add((merged_b, merged_a))
        self.walls = len(walls) // 2
        self.links: dict[Surface, list[Surface]] = defaultdict(list)
        for index, links in area_links:
            for a, neighbours in links.items():
                merged_a = order[mapping[(index, a)]]
                for b in neighbours:
                    merged_b = order[mapping[(index, b)]]
                    if merged_a != merged_b and merged_b not in self.links[merged_a] \
                            and (merged_a, merged_b) not in walls:
                        self.links[merged_a].append(merged_b)
        self.by_cell: dict[tuple[int, int], list[Surface]] = defaultdict(list)
        for key in self.surfaces:
            self.by_cell[(key[0], key[1])].append(key)

    def pos(self, key: Surface) -> tuple[float, float, float]:
        row, column, _ = key
        return column * self.step, self.surfaces[key][0], row * self.step

    def cell_of(self, x: float, z: float) -> tuple[int, int]:
        return round(z / self.step), round(x / self.step)

    def surface_at(self, pos: list[float], height: float = ATTACH_HEIGHT) -> Surface | None:
        best = None
        for key in self.by_cell.get(self.cell_of(pos[0], pos[2]), []):
            difference = abs(self.surfaces[key][0] - pos[1])
            if difference <= height and (best is None or difference < best[0]):
                best = (difference, key)
        return best[1] if best else None

    def distance(self, a: Surface, b: Surface) -> float:
        return math.dist(self.pos(a), self.pos(b))

    def covers(self, pos) -> bool:
        return any(math.hypot(pos[0] - float(area["center"][0]), pos[2] - float(area["center"][2]))
                   <= float(area.get("radius") or 0) for area in self.areas)


def _walked(grid: _Merged, nodes: _Nodes, paths: set[int], height: float) -> list:
    """The waypoints of the paths in the areas: [path, point, position, surface]."""
    walked = []
    for path in sorted(paths):
        for point, pos in enumerate(nodes.paths[path]["points"], start=1):
            if grid.covers(pos):
                walked.append((path, point, pos, grid.surface_at(pos, height)))
    return walked


def _land(nodes: _Nodes) -> set[int]:
    return {path for path, entry in nodes.paths.items()
            if "land" in [str(name).lower() for name in entry.get("vehicles") or []]}


def build(census: dict, attach: dict | None = None, checks: dict | None = None) -> dict:
    """The mesh of a level from all areas of its census, with the zones as labels on its points. attach: other
    waypoints to attach it to ({path: {"points", "vehicles", "objectives"}}, e.g. the paths cut at the zones), the
    parts of the mesh still come from the waypoints of the census. checks: what the rays of the game found blocked
    (check.py, census/<map>.checks.json), left out of the mesh."""
    areas = [area for area in census.get("areas") or [] if area.get("cells")]
    data = {"version": VERSION, "map": census.get("paths"), "spacing": SPACING, "points": [], "edges": [],
            "attach": [], "zones": []}
    if not areas:
        return data
    nodes = _Nodes(census)
    attach_nodes = _Nodes({"nodes": attach}) if attach is not None else None
    grid = _Merged(areas)
    clearance = _clearance(grid)
    tests = [(area, *_zone_test(census, area)) for area in areas]

    def inside_any(x: float, z: float) -> bool:
        return any(inside(x, z) for _, inside, _ in tests)

    def attached(paths: set[int], height: float) -> tuple[list, _Nodes] | None:
        return None if attach_nodes is None else (_walked(grid, attach_nodes, paths, height), attach_nodes)

    soldier = _network(grid, clearance, set(grid.surfaces), _walked(grid, nodes, nodes.foot, ATTACH_HEIGHT), nodes,
                       inside_any, SOLDIER, True, attached(attach_nodes.foot, ATTACH_HEIGHT) if attach_nodes else None)
    soldier = check_apply(soldier, checks)
    data.update(points=soldier["points"], edges=soldier["edges"], attach=soldier["attach"],
                stats=dict(soldier["stats"], surfaces=len(grid.surfaces)))

    # Land vehicles: wide, open, not too steep. The waypoints of vehicle-paths are the position of the vehicle, about a
    # metre above the ground.
    land = _land(nodes)
    vehicle = None
    if land:
        allowed = {key for key, (_, normal, _, headroom) in grid.surfaces.items()
                   if clearance.get(key, 0.0) >= VEHICLE_CLEARANCE and normal >= VEHICLE_NORMAL_Y
                   and (headroom < 0 or headroom >= VEHICLE_HEADROOM)}
        vehicle = _network(grid, clearance, allowed, _walked(grid, nodes, land, 3.0), nodes, inside_any, VEHICLE,
                           False, attached(_land(attach_nodes), 3.0) if attach_nodes else None)
        if vehicle["points"]:
            data["vehicle"] = vehicle

    for area, inside, source in tests:
        zone = {"name": area.get("name"), "kind": area.get("kind"), "center": as_list(area.get("center")),
                "radius": area.get("radius"), "zone": source,
                "inside": [index for index, point in enumerate(data["points"]) if inside(point[0], point[2])]}
        if "vehicle" in data:
            zone["vehicleInside"] = [index for index, point in enumerate(data["vehicle"]["points"])
                                     if inside(point[0], point[2])]
        data["zones"].append(zone)
    return data


def summary(data: dict) -> str:
    stats = data.get("stats") or {}
    lines = [f"mesh of {data.get('map')}: {len(data.get('points') or [])} points, {len(data.get('edges') or [])} "
             f"connections, {stats.get('parts', '?')} parts, {len(data.get('attach') or [])} junctions with waypoints "
             f"({stats.get('unattached', '?')} without surface)"]
    vehicle = data.get("vehicle")
    if vehicle:
        lines.append(f"  vehicles: {len(vehicle['points'])} points, {len(vehicle['edges'])} connections, "
                     f"{vehicle['stats']['parts']} parts, {len(vehicle['attach'])} junctions with vehicle-paths")
    for zone in data.get("zones") or []:
        vehicle_inside = f", {len(zone['vehicleInside'])} for vehicles" if "vehicleInside" in zone else ""
        lines.append(f"  {zone['name']} ({zone['kind']}, zone: {zone['zone']}): {len(zone['inside'])} points"
                     f"{vehicle_inside}")
    return "\n".join(lines)


def save(data: dict, file: Path) -> None:
    file.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")


def load_or_build(file: Path) -> dict:
    """Saved networks (.navzones.json, navzones/<map>.json), or the networks of a census (.json.gz)."""
    if file.name.endswith(".json"):
        return json.loads(file.read_text(encoding="utf-8"))
    from .store import load
    return build(load(file))
