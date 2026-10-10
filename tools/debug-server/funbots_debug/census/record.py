"""Records the ways the waypoints are missing: a spawn the bots can't walk to an objective from (lint: spawn-cut-off).

1. The way is planned with the rays of the game (a running level, through the debug-server): A* over cells of CELL
   metres, from the points of the spawn on the mesh to the closest part of the network the objectives are reached from.
   Each step to a neighbour cell asks for the ground there (a ray down from the height of the cell, up to STEP_UP higher
   or STEP_DOWN lower), for walls between both (rays at WALL_HEIGHTS) and for room above. Near walls a step costs more
   (WALL_COST): the way keeps to the middle, as people walk.
2. The cells are joined to straight pieces where nothing is in the way (with room to the sides), not longer than
   PIECE_MAX, then points every SPACING metres, on the ground.
3. A bot walks it (command "walk", ext/Server/Debug/BotWalker.lua). Where it gets stuck, the cells around are blocked
   and the way is planned again (TRIES times).
4. The points it walked to the end are the path.

The paths are written into mapfiles/<map>.map (as recorded in the game, `census navpaths` trims them at the mesh) and
census/recorded/<map>.json.

    python -m funbots_debug.census record XP4_Rubble_RushLarge0 [--spawn "spawn us 1"] [--dry-run]
"""

from __future__ import annotations

import heapq
import json
import math
from dataclasses import dataclass, field
from pathlib import Path

from ..paths.mapfile import MapData, Node, PathData
from ..protocol import as_list
from . import lint
from .report import _in_polygon, _transform

CELL = 1.5
STEP_UP = 0.55           # Higher than this from a cell to the middle to its neighbour, or from there on: a step people
                         # don't take (a jump is no way). Stairs and ramps rise about twice that from cell to cell.
STEP_DOWN = 1.2          # Lower: a drop (one way only, the paths are walked both ways).
GROUND_ABOVE = 1.2       # The ray down to the ground of a neighbour starts this far above the cell.
GROUND_BELOW = 3.0
WALL_HEIGHTS = (0.7, 1.4)
HEADROOM = 1.8
WALL_COST = 0.6          # Per blocked neighbour (of 8) a step costs this much more.
GOAL_RANGE = 2.0         # A cell this close to a point of the network (horizontal, GOAL_HEIGHT vertical) is the goal.
GOAL_HEIGHT = 1.5
MARGIN = 40.0            # The cells may go this far beyond the box around start and goal.
MAX_EXPANSIONS = 8000
GOALS_MAX = 300
BATCH = 64               # Cells expanded per round of rays.
PIECE_MAX = 12.0
SIDE = 0.5               # A straight piece needs room this far to both sides.
SAMPLE = 0.75            # Ground samples along a straight piece.
SPACING = 1.8            # Between the points of the path (as recorded by players).
TRIES = 4
BLOCK_RADIUS = 2.0       # Cells this close to where the bot got stuck are blocked...
BORDER_RADIUS = 8.0      # ...where it left the combat-area (the level gives no shapes of it in rush).
RAY_CHUNK = 3000
RAY_FLAGS = ["DontCheckCharacter", "DontCheckRagdoll", "DontCheckWater", "CheckDetailMesh"]
NEIGHBOURS = [(dx, dz) for dx in (-1, 0, 1) for dz in (-1, 0, 1) if dx or dz]
RECORDED = Path(__file__).resolve().parents[2] / "census" / "recorded"


@dataclass
class Gap:
    """A cut-off spawn: its points on the mesh, and the points the objectives are reached from (goals)."""
    spawn: str
    starts: list[list[float]]
    goals: list[list[float]]
    best: tuple[list[float], list[float]] = field(default_factory=lambda: ([], []))
    # Goal positions that are waypoints of a path: (path, point), the recorded path gets a link there.
    waypoints: dict[tuple[float, float, float], tuple[int, int]] = field(default_factory=dict)


def area_shapes(census: dict) -> list[list[tuple[float, float]]]:
    """The shapes of the combat-areas of the level (x, z), as report.combat_polygons reads them. Outside of all shapes
    around the spawn the game kills the bot after 10 s."""
    shapes = []
    for area in as_list((census.get("entities") or {}).get("combatAreas")):
        for shape in as_list(area.get("shapes")):
            polygon = [_transform(as_list(point), None) for point in as_list(shape.get("points"))
                       if len(as_list(point)) >= 3]
            if len(polygon) >= 3 and polygon not in shapes:
                shapes.append(polygon)
    return shapes


def gaps(name: str, networks: dict, data: MapData) -> list[Gap]:
    """The spawns of the level the bots can't walk to an objective from (as lint: spawn-cut-off)."""
    graph = lint.build_graph(networks, data)
    points = networks.get("points") or []
    zones = [zone for zone in networks.get("zones") or [] if zone.get("inside")]
    objectives = [zone for zone in zones if zone.get("kind") in lint.OBJECTIVE_KINDS]
    field_ = lint._field(graph, [("m", point) for zone in objectives for point in zone["inside"]])

    def position(node) -> list[float]:
        return list(points[node[1]][:3]) if node[0] == "m" else list(data.node(node[1], node[2]).pos)

    reachable = [position(node) for node in field_]
    waypoints = {tuple(position(node)): (node[1], node[2]) for node in field_ if node[0] == "w"}
    # Cut-off spawns that reach each other (one island, MP_007: three spawns next to each other) get one way: three
    # parallel ones into the same place made a ring the bots walked round in.
    cut_off = [zone for zone in zones if zone.get("kind") in lint.SPAWN_KINDS
               and not any(("m", point) in field_ for point in zone["inside"])]
    islands: list[list[dict]] = []
    for zone in cut_off:
        island = lint._field(graph, [("m", point) for point in zone["inside"]])
        for group in islands:
            if any(("m", point) in island for point in group[0]["inside"]):
                group.append(zone)
                break
        else:
            islands.append([zone])
    result = []
    for group in islands:
        starts = [list(points[point][:3]) for zone in group for point in zone["inside"]]
        best = min(((math.dist(s, g), s, g) for s in starts for g in reachable), key=lambda entry: entry[0],
                   default=None)
        if best is None:
            continue
        result.append(Gap(" + ".join(zone["name"] for zone in group), starts, reachable, (best[1], best[2]),
                          waypoints))
    return result


class Rays:
    """Rays of the running level (command "rays" of the mod): distance to the first hit, None without one."""

    def __init__(self, server):
        self.server = server
        self.count = 0

    def cast(self, rays: list[list[float]]) -> list[float | None]:
        hits: list[float | None] = []
        for start in range(0, len(rays), RAY_CHUNK):
            answer = self.server.request("/api/command?wait=120", {"type": "rays", "args": {
                "rays": rays[start:start + RAY_CHUNK], "flags": RAY_FLAGS}}, timeout=130.0)
            result = answer.get("result") or {}
            if "hits" not in result:
                raise RuntimeError(f"rays: {answer.get('error') or answer}")
            hits += [None if value is None or value < 0 else value for value in result["hits"]]
        self.count += len(rays)
        return hits


def _key(x: float, y: float, z: float) -> tuple[int, int, int]:
    return round(x / CELL), round(z / CELL), round(y / 2.0)


class Planner:
    """A* over the cells, the rays asked for in batches (BATCH cells at once)."""

    def __init__(self, rays: Rays, gap: Gap, shapes: list | None = None):
        self.rays = rays
        self.gap = gap
        xs = [p[0] for p in gap.best] + [gap.best[0][0]]
        zs = [p[2] for p in gap.best]
        self.box = (min(xs) - MARGIN, max(xs) + MARGIN, min(zs) - MARGIN, max(zs) + MARGIN)
        # Only in the combat-areas the spawn is in (MP_003, MP_007: the bot left it and was killed).
        start = gap.best[0]
        self.shapes = [shape for shape in shapes or [] if _in_polygon(start[0], start[2], shape)]
        target = gap.best[1]
        # The points of the network in the box, the closest ones to the target (each cell is compared with all).
        inside = [g for g in gap.goals if self._inside(g[0], g[2])]
        self.goals = sorted(inside, key=lambda g: math.dist(g, target))[:GOALS_MAX]
        self.blocked: set[tuple[int, int, int]] = set()
        # Cell -> its neighbours (key, position, step cost without the wall cost) and the number of blocked ones.
        self.cache: dict[tuple[int, int, int], tuple[list, int]] = {}

    def _inside(self, x: float, z: float) -> bool:
        return self.box[0] <= x <= self.box[1] and self.box[2] <= z <= self.box[3] and \
            (not self.shapes or any(_in_polygon(x, z, shape) for shape in self.shapes))

    def _goal(self, pos) -> bool:
        return any(math.hypot(pos[0] - g[0], pos[2] - g[2]) <= GOAL_RANGE and abs(pos[1] - g[1]) <= GOAL_HEIGHT
                   for g in self.goals)

    def _heuristic(self, pos) -> float:
        return min(math.dist(pos, g) for g in self.goals) if self.goals else 0.0

    def _expand(self, cells: list[tuple[tuple[int, int, int], list[float]]]) -> None:
        """Neighbours of the cells (not in the cache yet): ground first, then walls and room."""
        todo = [(key, pos) for key, pos in cells if key not in self.cache]
        if not todo:
            return
        # The ground at the neighbour and in the middle (from twice the height at the neighbour: stairs rise more than
        # a step from cell to cell, a ledge rises all at once).
        ground_rays, ground_meaning = [], []
        for key, pos in todo:
            x, y, z = pos
            for dx, dz in NEIGHBOURS:
                nx, nz = (key[0] + dx) * CELL, (key[1] + dz) * CELL
                if not self._inside(nx, nz):
                    continue
                mx, mz = (x + nx) / 2, (z + nz) / 2
                ground_rays.append([mx, y + GROUND_ABOVE, mz, mx, y - GROUND_BELOW, mz])
                ground_rays.append([nx, y + 2 * GROUND_ABOVE, nz, nx, y - GROUND_BELOW, nz])
                ground_meaning.append((key, pos, nx, nz))
        hits = self.rays.cast(ground_rays)
        candidates = []
        for index, (key, pos, nx, nz) in enumerate(ground_meaning):
            middle, end = hits[2 * index], hits[2 * index + 1]
            if middle is None or end is None:
                candidates.append((key, pos, None))
                continue
            my = pos[1] + GROUND_ABOVE - middle
            ny = pos[1] + 2 * GROUND_ABOVE - end
            if my - pos[1] > STEP_UP or ny - my > STEP_UP or pos[1] - my > STEP_DOWN or my - ny > STEP_DOWN:
                candidates.append((key, pos, None))
                continue
            candidates.append((key, pos, [nx, ny, nz]))
        wall_rays, wall_meaning = [], []
        for index, (key, pos, npos) in enumerate(candidates):
            if npos is None:
                continue
            for height in WALL_HEIGHTS:
                wall_rays.append([pos[0], pos[1] + height, pos[2], npos[0], npos[1] + height, npos[2]])
                wall_meaning.append(index)
            wall_rays.append([npos[0], npos[1] + 0.2, npos[2], npos[0], npos[1] + HEADROOM, npos[2]])
            wall_meaning.append(index)
        blocked_index = {index for index, hit in zip(wall_meaning, self.rays.cast(wall_rays)) if hit is not None}
        result: dict[tuple[int, int, int], tuple[list, int]] = {key: ([], 0) for key, _ in todo}
        for index, (key, pos, npos) in enumerate(candidates):
            neighbours, walls = result[key]
            if npos is None or index in blocked_index:
                result[key] = (neighbours, walls + 1)
                continue
            neighbours.append((_key(*npos), npos, math.dist(pos, npos)))
        self.cache.update(result)

    def plan(self, starts: list[list[float]]) -> list[list[float]] | None:
        """The cells from a start to the goal, None if none is found."""
        heap = []
        cost: dict = {}
        came: dict = {}
        positions: dict = {}
        for start in starts:
            key = _key(*start)
            if key in self.blocked:
                continue
            cost[key] = 0.0
            positions[key] = start
            heapq.heappush(heap, (self._heuristic(start), key))
        closed = set()
        expansions = 0
        while heap and expansions < MAX_EXPANSIONS:
            batch = []
            while heap and len(batch) < BATCH:
                _, key = heapq.heappop(heap)
                if key in closed:
                    continue
                closed.add(key)
                if self._goal(positions[key]):
                    route = [positions[key]]
                    while key in came:
                        key = came[key]
                        route.append(positions[key])
                    # On to the point of the network itself: else the way ended up to GOAL_RANGE short of it, on the
                    # mesh of the spawn (XP5_002: a gap of 4 m, nothing of the path was left between both parts).
                    end = route[0]
                    goal = min(self.goals, key=lambda g: math.dist(g, end))
                    if math.dist(goal, end) > 0.3:
                        route.insert(0, list(goal))
                    return route[::-1]
                batch.append((key, positions[key]))
            expansions += len(batch)
            self._expand(batch)
            for key, pos in batch:
                neighbours, walls = self.cache[key]
                factor = 1.0 + WALL_COST * walls / len(NEIGHBOURS)
                for nkey, npos, metres in neighbours:
                    if nkey in self.blocked or nkey in closed:
                        continue
                    new = cost[key] + metres * factor
                    if new < cost.get(nkey, math.inf):
                        cost[nkey] = new
                        came[nkey] = key
                        positions[nkey] = npos
                        heapq.heappush(heap, (new + self._heuristic(npos), nkey))
        return None

    def block_near(self, pos: list[float], radius: float = BLOCK_RADIUS) -> int:
        count = 0
        for key in list(self.cache) + list(self.blocked):
            x, z = key[0] * CELL, key[1] * CELL
            if math.hypot(x - pos[0], z - pos[2]) <= radius and abs(key[2] * 2.0 - pos[1]) <= 2.5:
                if key not in self.blocked:
                    self.blocked.add(key)
                    count += 1
        self.blocked.add(_key(*pos))
        return count


def _clear(rays: Rays, a: list[float], b: list[float]) -> bool:
    """Whether a soldier walks straight from a to b: ground all along (no step, no hole), nothing in the way, room to
    the sides."""
    length = math.hypot(b[0] - a[0], b[2] - a[2])
    samples = max(1, math.ceil(length / SAMPLE))
    ground_rays = []
    for index in range(samples + 1):
        t = index / samples
        x, y, z = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
        ground_rays.append([x, y + GROUND_ABOVE, z, x, y - GROUND_BELOW, z])
    side_x, side_z = (-(b[2] - a[2]) / length * SIDE, (b[0] - a[0]) / length * SIDE) if length > 0 else (0.0, 0.0)
    wall_rays = []
    for height in WALL_HEIGHTS:
        for offset in (0.0, 1.0, -1.0):
            wall_rays.append([a[0] + side_x * offset, a[1] + height, a[2] + side_z * offset,
                              b[0] + side_x * offset, b[1] + height, b[2] + side_z * offset])
    hits = rays.cast(ground_rays + wall_rays)
    grounds, walls = hits[:len(ground_rays)], hits[len(ground_rays):]
    if any(hit is not None for hit in walls) or any(hit is None for hit in grounds):
        return False
    heights = [ray[1] - hit for ray, hit in zip(ground_rays, grounds)]
    # Samples every SAMPLE metres: half a cell, as the planner checks.
    return all(-STEP_DOWN <= h2 - h1 <= STEP_UP for h1, h2 in zip(heights, heights[1:]))


def smooth(rays: Rays, cells: list[list[float]]) -> list[list[float]]:
    """The cells joined to straight pieces where that is clear (greedy, the farthest cell first)."""
    result = [cells[0]]
    index = 0
    while index < len(cells) - 1:
        reach = index + 1
        for other in range(len(cells) - 1, index + 1, -1):
            if math.dist(cells[index], cells[other]) <= PIECE_MAX and _clear(rays, cells[index], cells[other]):
                reach = other
                break
        result.append(cells[reach])
        index = reach
    return result


def resample(points: list[list[float]], spacing: float = SPACING) -> list[list[float]]:
    """Points every spacing metres along the line (the first and the last one stay)."""
    if len(points) < 2:
        return [list(p) for p in points]
    result = [list(points[0])]
    rest = 0.0
    for a, b in zip(points, points[1:]):
        length = math.dist(a, b)
        position = spacing - rest
        while position < length:
            t = position / length
            result.append([round(a[i] + (b[i] - a[i]) * t, 2) for i in range(3)])
            position += spacing
        rest = length - (position - spacing)
    if math.dist(result[-1], points[-1]) > spacing * 0.3:
        result.append(list(points[-1]))
    else:
        result[-1] = list(points[-1])
    return result


def walk(server, points: list[list[float]], timeout: float = 240.0) -> dict:
    answer = server.request("/api/command?wait=" + str(int(timeout) + 30), {"type": "walk", "args": {
        "points": points, "speed": "normal", "stuck": 6, "timeout": timeout}}, timeout=timeout + 40)
    if answer.get("status") != "ok":
        raise RuntimeError(f"walk: {answer.get('error') or answer.get('status')}")
    return answer.get("result") or {}


def link_of(gap: Gap, end: list[float]) -> tuple[int, int] | None:
    """The waypoint the way ends at (path, point), if it ends at a path and not at the mesh."""
    for position, node in gap.waypoints.items():
        if math.dist(position, end) <= 0.3:
            return node
    return None


def record_gap(server, gap: Gap, log=print, shapes: list | None = None) -> list[list[float]] | None:
    """Plans, walks and replans the way of one gap. The way the bot walked, or None. shapes: area_shapes."""
    rays = Rays(server)
    planner = Planner(rays, gap, shapes)
    # From the spawn points closest to the goal.
    starts = sorted(gap.starts, key=lambda s: math.dist(s, gap.best[1]))[:6]
    for attempt in range(1, TRIES + 1):
        cells = planner.plan(starts)
        if cells is None:
            log(f"    try {attempt}: no way found ({len(planner.cache)} cells, {rays.count} rays)")
            return None
        points = resample(smooth(rays, cells))
        log(f"    try {attempt}: {len(cells)} cells -> {len(points)} points, {rays.count} rays; walking")
        result = walk(server, points)
        status = result.get("status")
        log(f"    walked: {status}, {result.get('reached')}/{len(points)} points in {result.get('time')} s")
        if status == "done":
            # The points it walked: the trail itself starts with the turn after it was put there.
            return points
        if status not in ("stuck", "border") or not result.get("pos"):
            return None
        blocked = planner.block_near(result["pos"], BORDER_RADIUS if status == "border" else BLOCK_RADIUS)
        log(f"    {status} at {[round(c, 1) for c in result['pos']]}: {blocked} cells blocked")
    return None


def add_path(data: MapData, points: list[list[float]], link: tuple[int, int] | list | None = None) -> int:
    """A new foot path with the points (as recorded in the game, no objectives): its index. link: (path, point) of the
    waypoint its last point is linked to (the way ends at a path, not at the mesh)."""
    index = max(data.paths) + 1 if data.paths else 1
    nodes = [Node(index, number, (p[0], p[1], p[2]), 3, {}) for number, p in enumerate(points, start=1)]
    if link:
        nodes[-1].set_links([(int(link[0]), int(link[1]))])
    path = PathData(index, nodes)
    # Walked back and forth: a loop would close the gap between its ends (it was cut as one, back to the spawn).
    path.loops = False
    data.paths[index] = path
    return index


def save_recorded(name: str, entries: list[dict], directory: Path = RECORDED) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    file = directory / f"{name}.json"
    old = json.loads(file.read_text(encoding="utf-8")) if file.is_file() else {"paths": []}
    old["paths"] = [entry for entry in old["paths"] if entry["spawn"] not in {e["spawn"] for e in entries}] + entries
    file.write_text(json.dumps(old, indent=1) + "\n", encoding="utf-8")
    return file
