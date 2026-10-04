"""The check of a finished mesh with rays in the game: what the census couldn't see.

The census measures walls with short rays between its cells. A ray that starts inside of a solid (a wall, a slab, a
rock) doesn't hit it, and the rays of the census don't see the detail-meshes of the level: some walls and ceilings.
So the mesh can lead through them. The check casts rays over the finished mesh (command "rays" of the mod, with the
detail-meshes):

- every connection, along its way (the corners), at 1.0 and 1.3 m above the ground, in both directions: blocked if
  both heights hit on the same stretch in the same direction (a wall; only one of them: a railing, the edge of a
  ceiling over stairs, a kerb). Not the connections along waypoints (navzones._trace_edges): a person walked them, the
  census just doesn't see them (stairs, ladders, jumps);
- every point: up to 1.0 m above it (no room even to crouch: a ceiling, the inside of a slab), and in 8 directions at
  1.0 m: from the point outwards and from outside back to the point. Hit from outside but not from inside in at least
  INSIDE_DIRECTIONS directions: the point is inside of a solid.

The result goes into census/<map>.checks.json; navzones.build leaves those connections and points out and drops what
the junctions don't reach anymore.

    python -m funbots_debug.census check MP_Subway_RushLarge0     # switches to the level over RCON first
"""

from __future__ import annotations

import json
import math
from pathlib import Path

RAY_FLAGS = ["DontCheckCharacter", "DontCheckRagdoll", "DontCheckWater", "CheckDetailMesh"]
HEIGHTS = (1.0, 1.3)       # Above the ground: a hit at one of these is a wall (lower: steps, kerbs).
HEADROOM = 1.0             # Crouching.
SIDE = 1.5                 # Metres of the side rays of a point.
SIDE_HEIGHT = 1.0
INSIDE_DIRECTIONS = 3
MATCH = 0.3                # A point of the check this close to a point of a new mesh is the same one.
CHUNK = 3000               # Rays per command.
VERSION = 1


def _along_waypoints(edge: list) -> bool:
    return len(edge) > 4 and edge[4] == 1


def checks_file(census_file: Path) -> Path:
    """census/<map>.json.gz -> census/<map>.checks.json"""
    return census_file.with_name(census_file.name.split(".")[0] + ".checks.json")


def load_checks(census_file: Path) -> dict | None:
    file = checks_file(census_file)
    if not file.is_file():
        return None
    try:
        return json.loads(file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def rays(networks: dict) -> tuple[list[list[float]], list[tuple]]:
    """The rays and what each one checks: ("edge", index) or ("up", point) / ("out", point) / ("back", point)."""
    points = networks.get("points") or []
    result, meaning = [], []
    for index, edge in enumerate(networks.get("edges") or []):
        if _along_waypoints(edge):
            continue
        a, b = points[int(edge[0])], points[int(edge[1])]
        way = [a[:3]] + [list(corner) for corner in (edge[3] if len(edge) > 3 and edge[3] else [])] + [b[:3]]
        for segment, (p, q) in enumerate(zip(way, way[1:])):
            for height_index, height in enumerate(HEIGHTS):
                start = [p[0], p[1] + height, p[2]]
                end = [q[0], q[1] + height, q[2]]
                result += [start + end, end + start]
                meaning += [("edge", index, segment, height_index, 0), ("edge", index, segment, height_index, 1)]
    for index, point in enumerate(points):
        x, y, z = point[:3]
        result.append([x, y + 0.2, z, x, y + HEADROOM, z])
        meaning.append(("up", index))
        for direction in range(8):
            angle = direction * math.pi / 4
            outside = [x + SIDE * math.cos(angle), y + SIDE_HEIGHT, z + SIDE * math.sin(angle)]
            inside = [x, y + SIDE_HEIGHT, z]
            result += [inside + outside, outside + inside]
            meaning += [("out", index, direction), ("back", index, direction)]
    return result, meaning


def evaluate(networks: dict, hits: list[float], meaning: list[tuple]) -> dict:
    """The blocked connections and the bad points (positions, so they still match after a rebuild)."""
    points = networks.get("points") or []
    edges = networks.get("edges") or []
    edge_hits: dict[tuple[int, int, int], set[int]] = {}
    low = set()
    out_hit: dict[tuple[int, int], bool] = {}
    back_hit: dict[tuple[int, int], bool] = {}
    for hit, what in zip(hits, meaning):
        hit = hit is not None and hit >= 0
        if what[0] == "edge" and hit:
            edge_hits.setdefault((what[1], what[2], what[4]), set()).add(what[3])
        elif what[0] == "up" and hit:
            low.add(what[1])
        elif what[0] == "out":
            out_hit[(what[1], what[2])] = hit
        elif what[0] == "back":
            back_hit[(what[1], what[2])] = hit
    blocked = {key[0] for key, heights in edge_hits.items() if len(heights) == len(HEIGHTS)}
    inside = {index for index in range(len(points))
              if sum(1 for direction in range(8) if back_hit.get((index, direction)) and not out_hit.get((index, direction)))
              >= INSIDE_DIRECTIONS}

    def position(index: int) -> list[float]:
        return [round(value, 2) for value in points[index][:3]]

    return {
        "version": VERSION,
        "blockedEdges": [position(int(edges[index][0])) + position(int(edges[index][1])) for index in sorted(blocked)],
        "lowPoints": [position(index) for index in sorted(low)],
        "insidePoints": [position(index) for index in sorted(inside)],
    }


def merge(old: dict | None, new: dict) -> dict:
    """Earlier checks stay (a rebuilt mesh has the connections that are left)."""
    if not old:
        return new
    merged = dict(new)
    for key in ("blockedEdges", "lowPoints", "insidePoints"):
        seen = {tuple(entry) for entry in old.get(key) or []}
        merged[key] = list(old.get(key) or []) + [entry for entry in new.get(key) or [] if tuple(entry) not in seen]
    return merged


def summary(networks: dict, checks: dict) -> str:
    return (f"  check: {len(checks['blockedEdges'])} of {len(networks.get('edges') or [])} connections blocked, "
            f"{len(checks['lowPoints'])} points without room, {len(checks['insidePoints'])} inside of a solid "
            f"(of {len(networks.get('points') or [])})")


# --- applying it to a mesh -----------------------------------------------------------------------------------------

class _Positions:
    def __init__(self, positions: list[list[float]], cell: float = 1.0):
        self.cell = cell
        self.buckets: dict[tuple[int, int, int], list[list[float]]] = {}
        for position in positions:
            self.buckets.setdefault(self._key(position), []).append(position)

    def _key(self, position) -> tuple[int, int, int]:
        return (math.floor(position[0] / self.cell), math.floor(position[1] / self.cell),
                math.floor(position[2] / self.cell))

    def has(self, position) -> bool:
        x, y, z = self._key(position)
        for d_x in (-1, 0, 1):
            for d_y in (-1, 0, 1):
                for d_z in (-1, 0, 1):
                    for other in self.buckets.get((x + d_x, y + d_y, z + d_z), []):
                        if math.dist(other, position[:3]) <= MATCH:
                            return True
        return False


def apply(network: dict, checks: dict | None) -> dict:
    """The network (points, edges, attach of navzones._network) without the blocked connections and the bad points,
    and without the parts of the mesh no junction leads to anymore. Indices are counted anew."""
    if not checks or not network.get("points"):
        return network
    points = network["points"]
    bad = _Positions((checks.get("lowPoints") or []) + (checks.get("insidePoints") or []))
    blocked = {tuple(entry) for entry in checks.get("blockedEdges") or []}
    blocked_index = _Positions([list(entry[:3]) for entry in blocked])

    removed = {index for index, point in enumerate(points) if bad.has(point)}

    def is_blocked(a: list[float], b: list[float]) -> bool:
        if not blocked_index.has(a) and not blocked_index.has(b):
            return False
        for entry in blocked:
            first, second = entry[:3], entry[3:]
            if (math.dist(first, a[:3]) <= MATCH and math.dist(second, b[:3]) <= MATCH) or \
                    (math.dist(first, b[:3]) <= MATCH and math.dist(second, a[:3]) <= MATCH):
                return True
        return False

    edges = [edge for edge in network["edges"] if int(edge[0]) not in removed and int(edge[1]) not in removed
             and (_along_waypoints(edge) or not is_blocked(points[int(edge[0])], points[int(edge[1])]))]
    attach = [entry for entry in network["attach"] if int(entry[2]) not in removed]

    # Only the parts a junction leads to.
    neighbours: dict[int, list[int]] = {}
    for edge in edges:
        neighbours.setdefault(int(edge[0]), []).append(int(edge[1]))
        neighbours.setdefault(int(edge[1]), []).append(int(edge[0]))
    reached = set()
    todo = [int(entry[2]) for entry in attach]
    while todo:
        index = todo.pop()
        if index in reached:
            continue
        reached.add(index)
        todo.extend(neighbours.get(index, []))
    new_index = {}
    kept_points = []
    for index, point in enumerate(points):
        if index in reached:
            new_index[index] = len(kept_points)
            kept_points.append(point)
    result = dict(network)
    result["points"] = kept_points
    result["edges"] = [[new_index[int(edge[0])], new_index[int(edge[1])]] + list(edge[2:]) for edge in edges
                       if int(edge[0]) in new_index and int(edge[1]) in new_index]
    result["attach"] = [[entry[0], entry[1], new_index[int(entry[2])]] + list(entry[3:]) for entry in attach
                        if int(entry[2]) in new_index]
    stats = dict(network.get("stats") or {})
    stats.update(points=len(kept_points), edges=len(result["edges"]), attached=len(result["attach"]),
                 checkRemovedPoints=len(points) - len(kept_points),
                 checkRemovedEdges=len(network["edges"]) - len(result["edges"]))
    result["stats"] = stats
    return result
