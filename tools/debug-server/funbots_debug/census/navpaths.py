"""The paths of a level trimmed at the mesh: the bots walk the mesh in the zones and the paths between them.

The mesh (navzones.py) covers the objectives (capture points, MCOMs) and the spawns of the game. In there the bots walk
it freely, the paths lead from one area of the mesh to the next (NavRoutes.lua finds the way over both). This trims the
paths of a level (as they were recorded, with links) for that:

1. Foot paths lose their waypoints on the mesh in the zones: what is left are the pieces between the areas. A piece
   keeps the first waypoint on the mesh at each end, the junction with the mesh there. A piece shorter than MIN_LENGTH
   between two waypoints on the same part of the mesh is dropped (the mesh leads there). A path that never comes onto
   the mesh stays whole.
2. Foot paths need no names any more ("Objectives"): the bots find their way by the mesh and the waypoints. Their first
   waypoint has "Nav": {"Length": metres} instead, the mark of a trimmed level. The paths with an action (arming an
   MCOM, getting into a vehicle) and the ways to a vehicle or a beacon are dropped: the bots do that on the mesh.
3. Links stay where both waypoints are left, the others are dropped (the mesh is the way there).
4. Foot paths that lead nowhere are dropped, again until there is none: fewer than two ways out (a waypoint on the mesh,
   a link to a path that is left). A stub that touches the mesh once, a branch off a single link, a path without any
   connection: a bot on it would walk to its end and back.

Vehicle paths stay as they are, with their names: the vehicles still find their way by them, and the soldiers walk the
roads (land vehicle paths) too where they lead to the target (the mesh gets junctions with them). Their links to dropped
foot waypoints are dropped.

A waypoint is on the mesh where a point of a part the bots can use (MIN_PART points) is close (MESH_DISTANCE, on the same
floor) and it lies inside of the circle of an area of the census.

    python -m funbots_debug.census navpaths MP_012_ConquestSmall0 [--write] [--db ../../mod.db]
"""

from __future__ import annotations

import json
import math
import sqlite3
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from ..paths.mapfile import MapData, Node, PathData

MESH_DISTANCE = 4.0       # A waypoint this close to a point of the mesh (horizontally)...
FLOOR_HEIGHT = 1.5        # ...and on its floor is on the mesh...
COVER_MARGIN = 0.5        # ...if it lies at least this far inside of the circle of an area.
MIN_PART = 10             # Same as NavZones.lua: parts of the mesh with fewer points get no junctions.
LOOP_CLOSE = 30.0         # A looping path whose ends are this close is walked over from its last waypoint to its first.
MIN_LENGTH = 10.0         # Shorter pieces between two waypoints on the same part of the mesh: the mesh leads there.
FUNCTION_WORDS = ("vehicle", "beacon", "interact")  # Names of the ways to something to do.

MESH_ROW = "@mesh"  # The one row of <map>_navzones in mod.db: the whole mesh (NavZones.lua).

Vertex = tuple[int, int]  # path, point


@dataclass
class Result:
    data: MapData
    kept: int = 0  # foot paths that never come onto the mesh
    pieces: int = 0  # pieces of foot paths between areas of the mesh
    on_mesh: int = 0  # foot paths all on the mesh
    short: int = 0  # pieces dropped: shorter than MIN_LENGTH where the mesh connects their ends
    functions: int = 0  # ways to something to do dropped (actions, vehicles, beacons)
    vehicles: int = 0  # vehicle paths kept as they are
    links: int = 0  # links kept (each direction counted)
    lost_links: int = 0  # links to dropped waypoints
    dead_ends: int = 0  # foot paths dropped that lead nowhere (fewer than two ways out)
    dropped: dict[int, str] = field(default_factory=dict)  # old path -> why it's gone


class Mesh:
    """The points of the mesh in buckets: is a waypoint on it, on which part."""

    def __init__(self, navzones: dict, cell: float = 10.0):
        self.cell = cell
        self.points = navzones.get("points") or []
        parent = list(range(len(self.points)))

        def find(index: int) -> int:
            while parent[index] != index:
                parent[index] = parent[parent[index]]
                index = parent[index]
            return index

        for edge in navzones.get("edges") or []:
            parent[find(int(edge[0]))] = find(int(edge[1]))
        self.part = [find(index) for index in range(len(self.points))]
        self.sizes: dict[int, int] = defaultdict(int)
        for part in self.part:
            self.sizes[part] += 1
        # Where the census measured: discs [x, z, radius] of all areas.
        self.discs: list[list[float]] = []
        for area in list(navzones.get("zones") or []) + list(navzones.get("areas") or []):
            if area.get("discs"):
                self.discs += [[float(disc[0]), float(disc[1]), float(disc[2])] for disc in area["discs"]]
            elif area.get("radius"):
                center = area.get("center") or [0.0, 0.0, 0.0]
                self.discs.append([float(center[0]), float(center[2]), float(area["radius"])])
        self.buckets: dict[tuple[int, int], list[int]] = defaultdict(list)
        for index, point in enumerate(self.points):
            self.buckets[self._key(point)].append(index)

    def _key(self, pos) -> tuple[int, int]:
        return math.floor(pos[0] / self.cell), math.floor(pos[2] / self.cell)

    def point_of(self, pos, distance: float = MESH_DISTANCE) -> int | None:
        """The closest point of a usable part on the floor of the position, up to distance away (horizontally)."""
        x, z = self._key(pos)
        best = None
        for d_x in (-1, 0, 1):
            for d_z in (-1, 0, 1):
                for index in self.buckets.get((x + d_x, z + d_z), []):
                    point = self.points[index]
                    if abs(point[1] - pos[1]) > FLOOR_HEIGHT or self.sizes[self.part[index]] < MIN_PART:
                        continue
                    horizontal = math.hypot(point[0] - pos[0], point[2] - pos[2])
                    if horizontal <= distance and (best is None or horizontal < best[0]):
                        best = (horizontal, index)
        return best[1] if best else None

    def covered(self, pos) -> bool:
        return any(math.hypot(disc[0] - pos[0], disc[1] - pos[2]) <= disc[2] - COVER_MARGIN for disc in self.discs)

    def on_mesh(self, pos) -> bool:
        return self.point_of(pos) is not None and self.covered(pos)


def _is_function(path: PathData) -> bool:
    """The way to something to do: an action on it (arm an MCOM, get into a vehicle), or named so."""
    if any(node.data.get("Action") for node in path.nodes):
        return True
    return any(word in name.lower() for name in path.objectives for word in FUNCTION_WORDS)


def _length(positions: list) -> float:
    return sum(math.dist(a, b) for a, b in zip(positions, positions[1:]))


def _pieces(path: PathData, on: list[bool]) -> list[list[int]]:
    """The runs of waypoints off the mesh, with the waypoint on the mesh at each end where there is one. Point
    numbers from 1. A closed loop is walked around once, from a waypoint on the mesh."""
    count = len(path.nodes)
    order = list(range(1, count + 1))
    if count > 2 and path.loops and path.gap <= LOOP_CLOSE:
        first_on = next(index for index in order if on[index - 1])
        order = order[first_on - 1:] + order[:first_on - 1] + [first_on]
    pieces = []
    run: list[int] = []
    before: int | None = None
    for point in order:
        if not on[point - 1]:
            run.append(point)
            continue
        if run:
            pieces.append(([before] if before is not None else []) + run + [point])
            run = []
        before = point
    if run:
        pieces.append(([before] if before is not None else []) + run)
    return pieces


def trim(data: MapData, navzones: dict) -> Result:
    mesh = Mesh(navzones)
    result = Result(MapData(info=data.info))
    paths: dict[int, PathData] = {}
    moved: dict[Vertex, Vertex] = {}  # old waypoint -> new one
    sources: dict[int, list[Vertex]] = {}  # new path -> its old waypoints
    ends: dict[int, set[int]] = {}  # new foot path -> its points on the mesh (its junctions to be)

    def add(nodes: list[Node], old: list[Vertex], loops: bool, keep_data: bool) -> int:
        number = len(paths) + 1
        new_nodes = []
        for point, (node, vertex) in enumerate(zip(nodes, old), start=1):
            node_data = {key: value for key, value in node.data.items() if key not in ("Links", "LinkMode")} \
                if keep_data else {}
            new_nodes.append(Node(number, point, node.pos, node.input, node_data))
            moved.setdefault(vertex, (number, point))
        path = PathData(number, new_nodes)
        path.loops = loops
        if not keep_data:
            # The mark of a trimmed foot path (a level is trimmed once, from the paths as recorded).
            new_nodes[0].data["Nav"] = {"Length": round(_length([node.pos for node in nodes]), 1)}
        paths[number] = path
        sources[number] = old
        return number

    for index, path in sorted(data.paths.items()):
        if not path.nodes:
            continue
        if path.vehicles:
            add(path.nodes, [(index, node.point) for node in path.nodes], path.loops, True)
            result.vehicles += 1
            continue
        if _is_function(path):
            result.functions += 1
            result.dropped[index] = "the way to something to do"
            continue
        on = [mesh.on_mesh(node.pos) for node in path.nodes]
        if not any(on):
            number = add(path.nodes, [(index, node.point) for node in path.nodes], path.loops, False)
            ends[number] = set()
            result.kept += 1
            continue
        if all(on):
            result.on_mesh += 1
            result.dropped[index] = "all on the mesh"
            continue
        made = 0
        for points in _pieces(path, on):
            if len(points) < 2:
                continue
            positions = [path.nodes[point - 1].pos for point in points]
            first, last = on[points[0] - 1], on[points[-1] - 1]
            if first and last and _length(positions) < MIN_LENGTH:
                a, b = mesh.point_of(positions[0]), mesh.point_of(positions[-1])
                if a is not None and b is not None and mesh.part[a] == mesh.part[b]:
                    result.short += 1
                    continue
            number = add([path.nodes[point - 1] for point in points], [(index, point) for point in points], False, False)
            ends[number] = {new for new, point in enumerate(points, start=1) if on[point - 1]}
            result.pieces += 1
            made += 1
        if not made:
            result.dropped[index] = "only short pieces where the mesh leads"

    # Links between the waypoints that are left, both ways.
    for number, path in paths.items():
        for node, vertex in zip(path.nodes, sources[number]):
            old = data.node(*vertex)
            links = []
            for link in old.links if old is not None else []:
                target = moved.get(link)
                if target is None or target[0] == number:
                    result.lost_links += 1
                    continue
                links.append(target)
            node.set_links(list(dict.fromkeys(node.links + links)))
    for number, path in paths.items():
        for node in path.nodes:
            for target in node.links:
                back = paths[target[0]].nodes[target[1] - 1]
                if (number, node.point) not in back.links:
                    back.set_links(back.links + [(number, node.point)])
    result.data.paths = _prune(paths, ends, result)
    result.links = sum(len(node.links) for path in result.data.paths.values() for node in path.nodes)
    return result


def prune_unattached(result: Result, networks: dict) -> int:
    """Again with the junctions the mesh really has (navzones.build can leave a waypoint on the mesh without one: too far
    from its point, a point the checks removed). Returns how many paths were dropped: then the mesh has to be made again
    (the paths are numbered anew)."""
    ends: dict[int, set[int]] = {index: set() for index, path in result.data.paths.items() if not path.vehicles}
    for entry in networks.get("attach") or []:
        if int(entry[0]) in ends:
            ends[int(entry[0])].add(int(entry[1]))
    before = result.dead_ends
    result.data.paths = _prune(result.data.paths, ends, result)
    return result.dead_ends - before


def _prune(paths: dict[int, PathData], ends: dict[int, set[int]], result: Result) -> dict[int, PathData]:
    """Without the foot paths that lead nowhere: fewer than two ways out, again and again (the next one may lead nowhere
    now). A way out is a waypoint on the mesh (a junction) or a link to a path that is left (a vehicle path always is).
    So no stub that only touches the mesh once, no branch off a single link, no path without any connection: a bot on
    it would walk to its end and back. The paths are numbered anew, their links with them."""
    alive = set(paths)
    changed = True
    while changed:
        changed = False
        for number in sorted(alive):
            if number not in ends:
                continue  # A vehicle path.
            exits = len(ends[number])
            exits += len({target for node in paths[number].nodes for target, _ in node.links if target in alive})
            if exits < 2:
                alive.discard(number)
                result.dead_ends += 1
                changed = True
    new_index = {old: new for new, old in enumerate(sorted(alive), start=1)}
    kept: dict[int, PathData] = {}
    for old, new in new_index.items():
        path = paths[old]
        nodes = []
        for node in path.nodes:
            fresh = Node(new, node.point, node.pos, node.input, dict(node.data))
            fresh.set_links([(new_index[target], point) for target, point in node.links if target in new_index])
            nodes.append(fresh)
        kept[new] = PathData(new, nodes)
    return kept


def attach_nodes(data: MapData) -> dict[int, dict]:
    """The waypoints as the mesh needs them to attach (navzones.build(census, attach=...)). The foot paths and the roads
    (land vehicle paths) are the ways between the areas ("nav"): parts of the mesh without one and without an objective
    are dropped."""
    return {index: {"points": [list(node.pos) for node in path.nodes], "vehicles": path.vehicles,
                    "objectives": path.objectives, "nav": not path.vehicles or path.vehicles == ["land"]}
            for index, path in data.paths.items()}


def summary(result: Result, before: MapData, verbose: bool = False) -> str:
    old_count = sum(len(path.nodes) for path in before.paths.values())
    new_count = sum(len(path.nodes) for path in result.data.paths.values())
    lines = [
        f"{len(before.paths)} paths ({old_count} waypoints) -> {len(result.data.paths)} paths ({new_count} waypoints)",
        f"  foot paths: {result.kept} off the mesh kept whole, {result.pieces} pieces between areas of the mesh, "
        f"{result.on_mesh} all on the mesh dropped, {result.short} short pieces dropped where the mesh leads",
        f"  ways to something to do dropped: {result.functions}, vehicle paths kept: {result.vehicles}",
        f"  links: {result.links} kept, {result.lost_links} to dropped waypoints",
        f"  foot paths dropped that lead nowhere (a stub, a branch off one link, no connection): {result.dead_ends}",
    ]
    if verbose:
        for index, reason in sorted(result.dropped.items()):
            lines.append(f"    dropped path {index} ({', '.join(before.paths[index].objectives) or '-'}): {reason}")
    return "\n".join(lines)


def write_db(db: Path, name: str, data: MapData, networks: dict) -> None:
    """The waypoints and the networks of one level into mod.db (tables <name>_table and <name>_navzones), as the
    fun-bots-helper imports them. The tables of the other levels stay untouched."""
    # The game-server and the debug-server read it as well: wait for them.
    connection = sqlite3.connect(db, timeout=30.0)
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
