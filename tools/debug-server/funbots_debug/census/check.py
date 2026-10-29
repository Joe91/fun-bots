"""The check of a finished mesh with rays in the game: what the census couldn't see.

The census measures walls with short rays between its cells. A ray that starts inside of a solid (a wall, a slab, a
rock) doesn't hit it, and the rays of the census don't see the detail-meshes of the level: some walls and ceilings.
So the mesh can lead through them. The check casts rays over the finished mesh (command "rays" of the mod, with the
detail-meshes):

- every connection, along its way (the corners), at 1.0 and 1.3 m above the ground, in both directions: blocked if
  both heights hit on the same stretch in the same direction (a wall; only one of them: a railing, the edge of a
  ceiling over stairs, a kerb). And the ground along it, every GROUND_STEP: a step up or down of more than LEDGE
  between two samples (a ledge a soldier can't climb), or no ground (a hole), blocks it as well. Of the connections
  along waypoints (navzones._trace_edges) only the straight pieces from the points to the first and from the last
  waypoint: a person walked the rest, the census just doesn't see it (stairs, jumps);
- every point: up to 1.0 m above it (no room even to crouch: a ceiling, the inside of a slab), and in 8 directions at
  1.0 m: from the point outwards and from outside back to the point. Hit from outside but not from inside in at least
  INSIDE_DIRECTIONS directions: the point is inside of a solid;
- every junction (attach): the way from its point over its corners to the waypoint at both heights, both directions.

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
SPAWN_REACH = 15.0        # A spawn keeps the part of the mesh with a point this close (horizontal metres)...
SPAWN_FLOOR = 2.0         # ...on its floor.
GROUND_STEP = 0.5          # Metres between the ground-rays along a connection...
GROUND_ABOVE = 1.6         # ...from this far above the straight line...
GROUND_BELOW = 2.5         # ...to this far below it.
LEDGE = 0.8                # More up or down between two of them: a ledge.
CORNER_REACH = 0.4         # Across each corner of a way: from this far before it to this far after it (a corner inside a
                           # thin wall: the rays of both stretches end on its surface, neither hits it. MP_Subway
                           # conquest: a breakable panel at (-166.6, 65, -431), 60-90 bots per round were put across).
CORNER_SEGMENT = 1000      # The corner rays count as stretches of their own: segment CORNER_SEGMENT + the corner.
CHUNK = 3000               # Rays per command.
RECHECK_WAIT = 20.0        # Seconds between the two passes of the check (both): a block has to hold.
# Vehicles stand on their spawns while the check runs (the bots are killed): a hit this close (horizontal metres) to one
# is no wall, the vehicle drives away (MP_001: the junctions of the roads with the mesh start at the vehicle-spawns, all
# of them "blocked"). Not the stationary weapons (TOW, Kornet, AA): they stay. VehicleTypes of the mod.
VEHICLE_REACH = 4.5
AIRCRAFT_REACH = 9.0
VEHICLE_HEIGHT = 4.0
STATIONARY_TYPES = {8, 9}
AIRCRAFT_TYPES = {4, 5, 13, 14, 17, 18}
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


def _across_corners(way: list[list[float]]) -> list[tuple[list[float], list[float]]]:
    """For each corner of the way: a stretch from CORNER_REACH before it to CORNER_REACH after it (at most half of each
    stretch), over the corner."""
    result = []
    for before, corner, after in zip(way, way[1:], way[2:]):
        ends = []
        for other in (before, after):
            length = math.hypot(other[0] - corner[0], other[2] - corner[2])
            share = min(CORNER_REACH, length / 2) / length if length > 0 else 0.0
            ends.append([corner[i] + (other[i] - corner[i]) * share for i in range(3)])
        result.append((ends[0], corner, ends[1]))
    return result


def _corner_rays(way: list[list[float]], kind: str, index: int) -> tuple[list[list[float]], list[tuple]]:
    """The rays across the corners of the way, both heights and directions: over the corner in two pieces would start
    inside of the wall again, so straight from end to end (the corner is close to that line)."""
    result, meaning = [], []
    for corner_index, (p, _, q) in enumerate(_across_corners(way)):
        for height_index, height in enumerate(HEIGHTS):
            start = [p[0], p[1] + height, p[2]]
            end = [q[0], q[1] + height, q[2]]
            result += [start + end, end + start]
            segment = CORNER_SEGMENT + corner_index
            meaning += [(kind, index, segment, height_index, 0), (kind, index, segment, height_index, 1)]
    return result, meaning


def rays(networks: dict, junctions_only: bool = False) -> tuple[list[list[float]], list[tuple]]:
    """The rays and what each one checks: ("edge", index) or ("up", point) / ("out", point) / ("back", point).
    junctions_only: only the junctions (a few hundred rays instead of a hundred thousand): the ones a cut added after
    the last full check (navzones._attach_loose) were never checked."""
    points = networks.get("points") or []
    result, meaning = [], []
    for index, edge in enumerate([] if junctions_only else networks.get("edges") or []):
        if _along_waypoints(edge):
            # Along waypoints a person walked: only the pieces from the points of the mesh to the first and from the
            # last waypoint (straight lines nobody walked, through the wall of a train next to its door).
            corners = [list(corner) for corner in (edge[3] if len(edge) > 3 and edge[3] else [])]
            if corners:
                a, b = points[int(edge[0])], points[int(edge[1])]
                for segment, (p, q) in enumerate(((a[:3], corners[0]), (corners[-1], b[:3]))):
                    for height_index, height in enumerate(HEIGHTS):
                        start = [p[0], p[1] + height, p[2]]
                        end = [q[0], q[1] + height, q[2]]
                        result += [start + end, end + start]
                        meaning += [("trace", index, segment, height_index, 0), ("trace", index, segment, height_index, 1)]
            continue
        a, b = points[int(edge[0])], points[int(edge[1])]
        way = [a[:3]] + [list(corner) for corner in (edge[3] if len(edge) > 3 and edge[3] else [])] + [b[:3]]
        for segment, (p, q) in enumerate(zip(way, way[1:])):
            for height_index, height in enumerate(HEIGHTS):
                start = [p[0], p[1] + height, p[2]]
                end = [q[0], q[1] + height, q[2]]
                result += [start + end, end + start]
                meaning += [("edge", index, segment, height_index, 0), ("edge", index, segment, height_index, 1)]
            samples = max(1, math.ceil(math.hypot(q[0] - p[0], q[2] - p[2]) / GROUND_STEP))
            for sample in range(samples + 1):
                t = sample / samples
                x, y, z = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t
                result.append([x, y + GROUND_ABOVE, z, x, y - GROUND_BELOW, z])
                meaning.append(("ground", index, segment, sample, y + GROUND_ABOVE))
        corner_rays, corner_meaning = _corner_rays(way, "edge", index)
        result += corner_rays
        meaning += corner_meaning
    # The junctions: the way from the point of the mesh to the waypoint (the grid can lead through a wall it missed,
    # the side of an escalator).
    for index, entry in enumerate(networks.get("attach") or []):
        if int(entry[2]) >= len(points):
            continue
        way = [points[int(entry[2])][:3]] + [list(corner) for corner in (entry[5] if len(entry) > 5 and entry[5] else [])] \
            + [list(entry[4])]
        for segment, (p, q) in enumerate(zip(way, way[1:])):
            for height_index, height in enumerate(HEIGHTS):
                start = [p[0], p[1] + height, p[2]]
                end = [q[0], q[1] + height, q[2]]
                result += [start + end, end + start]
                meaning += [("junction", index, segment, height_index, 0), ("junction", index, segment, height_index, 1)]
        corner_rays, corner_meaning = _corner_rays(way, "junction", index)
        result += corner_rays
        meaning += corner_meaning
    for index, point in enumerate([] if junctions_only else points):
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


def vehicles_of(state: dict) -> list[tuple[list[float], float]]:
    """The vehicles of the state of the debug-server that a hit close to doesn't count: (position, reach)."""
    result = []
    for vehicle in state.get("vehicles") or []:
        kind = vehicle.get("type")
        if vehicle.get("pos") and kind not in STATIONARY_TYPES:
            result.append((list(vehicle["pos"]), AIRCRAFT_REACH if kind in AIRCRAFT_TYPES else VEHICLE_REACH))
    return result


# Vehicle-spawns of the census by the end of their blueprint: the stationary weapons stay (walls), the aircraft are big.
STATIONARY_BLUEPRINTS = ("TOW2", "Kornet", "Centurion_C-RAM", "Centurion_C-RAM_Carrier", "Pantsir-S1")
AIRCRAFT_BLUEPRINTS = ("A10_THUNDERBOLT", "AC130", "AH1Z", "AH6_Littlebird", "C130", "F18", "F18_SpawnInAir", "F35B",
                       "KA-60_Kasatka", "Mi28", "SU-25TM", "SU-35BM-E", "SU-35BM-E_SpawnInAir", "Venom", "Z-11w")


def vehicle_spawns_of(census: dict) -> list[tuple[list[float], float]]:
    """The vehicle-spawns of the census as vehicles a hit close to doesn't count (position, reach): the vehicles stand
    there at the start of a round, also when the state doesn't know them yet (XP3_Desert CQL: the Tunguska on the spawn
    of path 80, its sides "walls", the points next to it left out, the bots then came at it from the other side)."""
    result = []
    for spawn in (census.get("entities") or {}).get("vehicleSpawns") or []:
        kind = str(spawn.get("blueprint") or "").rsplit("/", 1)[-1]
        if spawn.get("pos") and kind not in STATIONARY_BLUEPRINTS:
            result.append((list(spawn["pos"]), AIRCRAFT_REACH if kind in AIRCRAFT_BLUEPRINTS else VEHICLE_REACH))
    return result


def _on_vehicle(ray: list[float], distance: float, vehicles: list[tuple[list[float], float]]) -> bool:
    length = math.dist(ray[:3], ray[3:6])
    if length <= 0:
        return False
    t = distance / length
    x, y, z = (ray[i] + (ray[i + 3] - ray[i]) * t for i in range(3))
    return any(math.hypot(x - pos[0], z - pos[2]) <= reach and abs(y - pos[1]) <= VEHICLE_HEIGHT
               for pos, reach in vehicles)


def evaluate(networks: dict, hits: list[float], meaning: list[tuple], rays: list[list[float]] | None = None,
             vehicles: list[tuple[list[float], float]] | None = None) -> dict:
    """The blocked connections and the bad points (positions, so they still match after a rebuild). rays and
    vehicles (vehicles_of): hits on a parked vehicle don't count."""
    if rays is not None and vehicles:
        hits = [-1 if raw is not None and raw >= 0 and _on_vehicle(ray, raw, vehicles) else raw
                for ray, raw in zip(rays, hits)]
    points = networks.get("points") or []
    edges = networks.get("edges") or []
    edge_hits: dict[tuple[int, int, int], set[int]] = {}
    trace_hits: dict[tuple[int, int, int], set[int]] = {}
    junction_hits: dict[tuple[int, int, int], set[int]] = {}
    grounds: dict[tuple[int, int], dict[int, float | None]] = {}
    low = set()
    out_hit: dict[tuple[int, int], bool] = {}
    back_hit: dict[tuple[int, int], bool] = {}
    for raw, what in zip(hits, meaning):
        hit = raw is not None and raw >= 0
        if what[0] == "edge" and hit:
            edge_hits.setdefault((what[1], what[2], what[4]), set()).add(what[3])
        elif what[0] == "trace" and hit:
            trace_hits.setdefault((what[1], what[2], what[4]), set()).add(what[3])
        elif what[0] == "junction" and hit:
            junction_hits.setdefault((what[1], what[2], what[4]), set()).add(what[3])
        elif what[0] == "ground":
            grounds.setdefault((what[1], what[2]), {})[what[3]] = what[4] - raw if hit else None
        elif what[0] == "up" and hit:
            low.add(what[1])
        elif what[0] == "out":
            out_hit[(what[1], what[2])] = hit
        elif what[0] == "back":
            back_hit[(what[1], what[2])] = hit
    ledges = set()
    for (index, _), profile in grounds.items():
        heights = [profile[sample] for sample in sorted(profile)]
        if any(height is None for height in heights) or \
                any(abs(b - a) > LEDGE for a, b in zip(heights, heights[1:])):
            ledges.add(index)
    blocked = {key[0] for key, heights in edge_hits.items() if len(heights) == len(HEIGHTS)} | ledges
    blocked_traces = {key[0] for key, heights in trace_hits.items() if len(heights) == len(HEIGHTS)}
    blocked_junctions = {key[0] for key, heights in junction_hits.items() if len(heights) == len(HEIGHTS)}
    attach = networks.get("attach") or []
    inside = {index for index in range(len(points))
              if sum(1 for direction in range(8) if back_hit.get((index, direction)) and not out_hit.get((index, direction)))
              >= INSIDE_DIRECTIONS}

    def position(index: int) -> list[float]:
        return [round(value, 2) for value in points[index][:3]]

    # Blocked with corners the builder moved to more room (navzones._center_corners): the next cut keeps the corners of
    # the census for it (XP1_003 rush: moved, 3 of 5 connections ran into something the census doesn't see; their old
    # corners were free, dropping them sent more bots over the stairs at (274, 96, -140)).
    centered = networks.get("centered") or []

    def moved(index: int) -> bool:
        a, b = position(int(edges[index][0])), position(int(edges[index][1]))
        return any((math.dist(entry[:3], a) <= MATCH and math.dist(entry[3:], b) <= MATCH)
                   or (math.dist(entry[:3], b) <= MATCH and math.dist(entry[3:], a) <= MATCH) for entry in centered)

    blocked_centered = {index for index in blocked if moved(index)}
    blocked = blocked - blocked_centered

    return {
        "version": VERSION,
        "blockedCentered": [position(int(edges[index][0])) + position(int(edges[index][1]))
                            for index in sorted(blocked_centered)],
        "blockedEdges": [position(int(edges[index][0])) + position(int(edges[index][1])) for index in sorted(blocked)],
        "blockedTraces": [position(int(edges[index][0])) + position(int(edges[index][1]))
                          for index in sorted(blocked_traces)],
        # The point of the mesh and the waypoint.
        "blockedJunctions": [position(int(attach[index][2])) + [round(value, 2) for value in attach[index][4][:3]]
                             for index in sorted(blocked_junctions)],
        "lowPoints": [position(index) for index in sorted(low)],
        "insidePoints": [position(index) for index in sorted(inside)],
    }


def both(first: dict, second: dict) -> dict:
    """What two checks of the same mesh found both times. Right after the level loads something can stand in the way
    for a moment (XP1_003 rush: 3 of 5 connections blocked once were free in the running round): the check casts its
    rays twice, a while apart, and a block has to hold."""
    result = dict(second)
    for key in ("blockedEdges", "blockedCentered", "blockedTraces", "blockedJunctions", "lowPoints", "insidePoints"):
        seen = {tuple(entry) for entry in first.get(key) or []}
        result[key] = [entry for entry in second.get(key) or [] if tuple(entry) in seen]
    return result


def merge(old: dict | None, new: dict) -> dict:
    """Earlier checks stay (a rebuilt mesh has the connections that are left)."""
    if not old:
        return new
    merged = dict(new)
    for key in ("blockedEdges", "blockedCentered", "blockedTraces", "blockedJunctions", "lowPoints", "insidePoints"):
        seen = {tuple(entry) for entry in old.get(key) or []}
        merged[key] = list(old.get(key) or []) + [entry for entry in new.get(key) or [] if tuple(entry) not in seen]
    return merged


def summary(networks: dict, checks: dict) -> str:
    return (f"  check: {len(checks['blockedEdges'])} of {len(networks.get('edges') or [])} connections blocked "
            f"({len(checks.get('blockedTraces') or [])} along waypoints), "
            f"{len(checks.get('blockedCentered') or [])} with moved corners (the census corners again), "
            f"{len(checks.get('blockedJunctions') or [])} junctions blocked, "
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


def apply(network: dict, checks: dict | None, spawns: list | None = None) -> dict:
    """The network (points, edges, attach of navzones._network) without the blocked connections and the bad points,
    and without the parts of the mesh no junction or spawn of the game (spawns: positions on the ground) leads to
    anymore. Indices are counted anew."""
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

    traces = [tuple(entry) for entry in checks.get("blockedTraces") or []]

    def trace_blocked(a: list[float], b: list[float]) -> bool:
        return any((math.dist(entry[:3], a[:3]) <= MATCH and math.dist(entry[3:], b[:3]) <= MATCH)
                   or (math.dist(entry[:3], b[:3]) <= MATCH and math.dist(entry[3:], a[:3]) <= MATCH) for entry in traces)

    edges = [edge for edge in network["edges"] if int(edge[0]) not in removed and int(edge[1]) not in removed
             and (not is_blocked(points[int(edge[0])], points[int(edge[1])]) if not _along_waypoints(edge)
                  else not trace_blocked(points[int(edge[0])], points[int(edge[1])]))]
    junctions = [tuple(entry) for entry in checks.get("blockedJunctions") or []]

    def junction_blocked(entry: list) -> bool:
        point, waypoint = points[int(entry[2])], entry[4]
        return any(math.dist(blocked_entry[:3], point[:3]) <= MATCH and math.dist(blocked_entry[3:], waypoint[:3]) <= MATCH
                   for blocked_entry in junctions)

    attach = [entry for entry in network["attach"] if int(entry[2]) not in removed and not junction_blocked(entry)]

    # Only the parts a junction leads to.
    neighbours: dict[int, list[int]] = {}
    for edge in edges:
        neighbours.setdefault(int(edge[0]), []).append(int(edge[1]))
        neighbours.setdefault(int(edge[1]), []).append(int(edge[0]))
    reached = set()
    todo = [int(entry[2]) for entry in attach]
    # The point closest to each spawn (on its floor, SPAWN_REACH): the soldiers start there.
    for spawn in spawns or []:
        best = None
        for index, point in enumerate(points):
            if index in removed or abs(point[1] - spawn[1]) > SPAWN_FLOOR:
                continue
            distance = math.hypot(point[0] - spawn[0], point[2] - spawn[2])
            if distance <= SPAWN_REACH and (best is None or distance < best[0]):
                best = (distance, index)
        if best is not None:
            todo.append(best[1])
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
