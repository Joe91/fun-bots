"""Checks a census (store.py) for problems of the waypoints and sums up what it found.

The checks only read the census, nothing is changed. Each problem is an Issue with a position, so the debug-server
can show it under *Findings* and jump to it. Problems of neighbouring waypoints of the same path are one issue.
"""

from __future__ import annotations

import math
from collections import defaultdict, deque
from dataclasses import dataclass, field
from statistics import median
from typing import Any, Iterable

from ..protocol import as_list

# inputVar of a waypoint: speed in bits 0-3, extra-mode in 4-7 (NodeCollection.lua).
SPEED_PRONE = 1
SPEED_CROUCH = 2
EXTRA_JUMP = 1

# Waypoints, see CensusTask:_ProbeNode in MapCensus.lua.
FLOAT_WARN = 0.6          # Ground this far below the waypoint.
FLOAT_ERROR = 1.5         # Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT: the waypoint is never reached.
STEEP_NORMAL_Y = 0.7      # Ground steeper than about 45°.
SWIM_DEPTH = 1.3          # Water deeper than this: the soldier swims.
CEILING_CROUCH = 1.7      # Less headroom: crouch.
CEILING_PRONE = 1.1       # Less headroom: prone.
CLEARANCE_MAX = 4.0
OFFSET_SCRAPE = 1.5       # Bot:ApplyPathOffset moves up to 1.2 m to the side, plus the soldier itself.
NARROW = 1.0              # Free space left + right.
SEGMENT_HEIGHTS = (0.4, 1.0, 1.6)

AIR_SHARE = 0.5           # Paths with more of their waypoints this high above the ground (or none below) fly.

# Entities.
CAPTURE_HEIGHT = 15.0     # Waypoints up to this far above / below a capture point count as inside of it.
UNKNOWN_RADIUS = 25.0     # Capture-radius while nothing was measured (zones.py).
SPAWN_DISTANCE = 25.0     # A spawn this far from the next walkable waypoint.
VEHICLE_SPAWN_DISTANCE = 40.0

# Grids around the objectives, see CensusTask:_ProbeCell.
WALK_NORMAL_Y = 0.7
WALK_HEADROOM = 1.0       # Crouching.
LAYER_GAP = 1.3           # A lower floor needs at least this much below the one above (else: inside of a solid).
STEP_HEIGHT = 0.6         # Height difference between neighbour-cells a soldier walks over.
SEED_HEIGHT = 1.0         # A waypoint seeds the cell-surface this close to it.

# Findings per kind of issue (all are counted in the summary).
MAX_ISSUES_PER_KIND = 150


@dataclass
class Issue:
    kind: str
    severity: str  # info | warn | error
    message: str
    pos: list[float] | None = None
    path: int | None = None
    points: tuple[int, int] | None = None
    data: dict[str, Any] = field(default_factory=dict)

    @property
    def key(self) -> str:
        where = f"{self.path}:{self.points[0]}" if self.path is not None and self.points else \
            ",".join(str(round(value)) for value in self.pos or [])
        return f"census:{self.kind}:{where}"


@dataclass
class Report:
    name: str
    summary: dict[str, Any]
    issues: list[Issue]

    def counts(self) -> dict[str, int]:
        counts: dict[str, int] = defaultdict(int)
        for issue in self.issues:
            counts[issue.kind] += 1
        return dict(sorted(counts.items()))

    def limited(self) -> list[Issue]:
        """At most MAX_ISSUES_PER_KIND of each kind, errors first."""
        order = {"error": 0, "warn": 1, "info": 2}
        result = []
        seen: dict[str, int] = defaultdict(int)
        for issue in sorted(self.issues, key=lambda issue: order.get(issue.severity, 3)):
            seen[issue.kind] += 1
            if seen[issue.kind] <= MAX_ISSUES_PER_KIND:
                result.append(issue)
        return result

    def text(self) -> str:
        lines = [f"census {self.name}"]
        for key, value in self.summary.items():
            if isinstance(value, list):
                lines.append(f"  {key}:")
                lines.extend(f"    {item}" for item in value)
            else:
                lines.append(f"  {key}: {value}")
        lines.append("  issues:")
        lines.extend(f"    {kind}: {count}" for kind, count in self.counts().items())
        return "\n".join(lines)


# --- helpers -------------------------------------------------------------------------------------------------------

def _runs(points: Iterable[int]) -> list[tuple[int, int]]:
    """[3, 4, 5, 9] -> [(3, 5), (9, 9)]"""
    runs: list[tuple[int, int]] = []
    for point in sorted(points):
        if runs and point == runs[-1][1] + 1:
            runs[-1] = (runs[-1][0], point)
        else:
            runs.append((point, point))
    return runs


def _blocked(fractions: Any) -> list[bool]:
    values = as_list(fractions)
    return [value is not False and value is not None for value in values] + [False] * (3 - len(values))


def _free(value: Any) -> float | None:
    """Free space to one side: None = not measured, CLEARANCE_MAX = more than that."""
    if value is False or value is None:
        return CLEARANCE_MAX
    return None if value < 0 else float(value)


def _in_polygon(x: float, z: float, polygon: list[tuple[float, float]]) -> bool:
    inside = False
    for (ax, az), (bx, bz) in zip(polygon, polygon[1:] + polygon[:1]):
        if (az > z) != (bz > z) and x < (bx - ax) * (z - az) / (bz - az) + ax:
            inside = not inside
    return inside


def _transform(point: list[float], transform: dict | None) -> tuple[float, float]:
    """x and z of a point of a shape in world space: trans + x * left + y * up + z * forward."""
    if not transform:
        return point[0], point[2]
    trans, left, up, forward = (transform[key] for key in ("trans", "left", "up", "forward"))
    return tuple(trans[axis] + point[0] * left[axis] + point[1] * up[axis] + point[2] * forward[axis]
                 for axis in (0, 2))  # type: ignore[return-value]


def _flies(entry: dict) -> bool:
    ground = entry.get("ground") or []
    high = sum(1 for value in ground if value is False or value < -FLOAT_ERROR)
    return bool(ground) and high > AIR_SHARE * len(ground)


class _Nodes:
    """The waypoints of the census, with the ones soldiers walk on."""

    def __init__(self, census: dict):
        self.paths: dict[int, dict] = {int(path): entry for path, entry in (census.get("nodes") or {}).items()}
        # Paths in the air without "Vehicles": air paths that lack the tag.
        self.air = {path for path, entry in self.paths.items() if not entry.get("vehicles") and _flies(entry)}
        self.foot = {path for path, entry in self.paths.items() if not entry.get("vehicles") and path not in self.air}
        self.vehicle = {path for path, entry in self.paths.items() if entry.get("vehicles")
                        or any("vehicle" in str(name).lower() for name in entry.get("objectives") or [])}

    def positions(self, paths: Iterable[int]) -> list[tuple[int, int, list[float]]]:
        return [(path, point, pos) for path in paths
                for point, pos in enumerate(self.paths[path]["points"], start=1)]

    def objectives(self, path: int) -> list[str]:
        return [str(name) for name in self.paths[path].get("objectives") or []]


def _closest(positions: list[tuple[int, int, list[float]]], pos: list[float]) -> tuple[float, Any]:
    best = (math.inf, None)
    for path, point, node in positions:
        distance = math.dist(node, pos)
        if distance < best[0]:
            best = (distance, (path, point))
    return best


# --- waypoints -----------------------------------------------------------------------------------------------------

def _check_nodes(nodes: _Nodes, issues: list[Issue], summary: dict) -> None:
    clearance: list[float] = []
    scrape = narrow = measured = 0

    for path in sorted(nodes.air):
        entry = nodes.paths[path]
        issues.append(Issue("air-untagged", "warn", f"path {path} ({len(entry['points'])} waypoints) is in the air but "
                            "has no Vehicles-tag (air)", pos=entry["points"][0], path=path, points=(1, 1)))

    for path, entry in sorted(nodes.paths.items()):
        if path in nodes.air or "air" in [str(name).lower() for name in entry.get("vehicles") or []]:
            continue
        foot = path in nodes.foot
        points = entry["points"]
        inputs = entry.get("inputs") or [3] * len(points)
        flagged: dict[tuple[str, str, str], list[int]] = defaultdict(list)

        def flag(kind: str, severity: str, message: str, point: int) -> None:
            flagged[(kind, severity, message)].append(point)

        for index, pos in enumerate(points):
            point = index + 1
            speed = inputs[index] & 0xF
            ground = entry["ground"][index]
            if ground is False:
                flag("no-ground", "warn", "no ground within 4 m below the waypoints", point)
            elif foot and ground < -FLOAT_ERROR:
                flag("floating", "error", f"waypoints more than {FLOAT_ERROR} m above the ground (never reached)",
                     point)
            elif foot and ground < -FLOAT_WARN:
                flag("floating", "warn", f"waypoints more than {FLOAT_WARN} m above the ground", point)

            if not foot:
                continue

            normal = entry["normal"][index]
            if normal is not False and normal < STEEP_NORMAL_Y:
                flag("steep", "info", "ground steeper than 45°", point)
            water = entry["water"][index]
            if water is not False and water > SWIM_DEPTH:
                flag("water", "info", f"water deeper than {SWIM_DEPTH} m (swimming)", point)

            ceiling = entry["ceiling"][index]
            if ceiling is not False:
                if ceiling < CEILING_PRONE and speed != SPEED_PRONE:
                    flag("low-ceiling", "warn", f"headroom below {CEILING_PRONE} m, but not prone", point)
                elif ceiling < CEILING_CROUCH and speed not in (SPEED_PRONE, SPEED_CROUCH):
                    flag("low-ceiling", "warn", f"headroom below {CEILING_CROUCH} m, but standing", point)

            left, right = _free(entry["left"][index]), _free(entry["right"][index])
            if left is not None and right is not None:
                measured += 1
                clearance.append(min(left, right))
                scrape += min(left, right) < OFFSET_SCRAPE
                narrow += left + right < NARROW

            # The way to the next waypoint.
            fractions = entry["next"][index]
            if fractions is False:
                continue
            low, middle, high = _blocked(fractions)
            following = index + 1 if index + 1 < len(points) else 0
            jump = (inputs[index] >> 4) & 0xF == EXTRA_JUMP or (inputs[following] >> 4) & 0xF == EXTRA_JUMP
            next_speed = inputs[following] & 0xF
            hit = entry["nextHit"][index]
            kind = f" (hit {hit})" if hit else ""
            if low and middle and high:
                flag("wall", "error", f"the way to the next waypoint is blocked at all heights{kind}", point)
            elif low and middle and not jump:
                flag("obstacle", "warn", f"obstacle up to the chest on the way to the next waypoint, no jump{kind}",
                     point)
            elif low and not middle and not jump and math.dist(pos, points[following]) < 4.0:
                flag("step", "info", f"low obstacle on the way to the next waypoint, no jump{kind}", point)
            elif not low and (middle or high):
                crouched = {speed, next_speed} & {SPEED_PRONE, SPEED_CROUCH}
                if middle and SPEED_PRONE not in {speed, next_speed}:
                    flag("low-passage", "warn", "passage below 1 m to the next waypoint, but not prone", point)
                elif high and not middle and not crouched:
                    flag("low-passage", "warn", "passage below 1.6 m to the next waypoint, but standing", point)

        for (kind, severity, message), flagged_points in flagged.items():
            for first, last in _runs(flagged_points):
                count = last - first + 1
                issues.append(Issue(kind, severity, f"path {path} points {first}-{last} ({count}): {message}"
                                    if count > 1 else f"path {path} point {first}: {message}",
                                    pos=points[first - 1], path=path, points=(first, last)))

    if measured:
        clearance.sort()
        summary["clearance"] = (
            f"{measured} walked waypoints: median {median(clearance):.1f} m to the closer side, "
            f"{100 * scrape / measured:.0f} % closer than {OFFSET_SCRAPE} m (path-offset scrapes), "
            f"{100 * narrow / measured:.0f} % narrower than {NARROW} m")


def _check_links(census: dict, nodes: _Nodes, issues: list[Issue], summary: dict) -> None:
    blocked = 0
    links = census.get("links") or []
    for path, point, other_path, other_point, fractions, kind in links:
        low, middle, high = _blocked(fractions)
        if middle and high:
            blocked += 1
            entry = nodes.paths.get(path)
            pos = entry["points"][point - 1] if entry and 0 < point <= len(entry["points"]) else None
            hit = f" (hit {kind})" if kind else ""
            issues.append(Issue("link-blocked", "warn",
                                f"link {path}:{point} -> {other_path}:{other_point} goes through a wall{hit}",
                                pos=pos, path=path, points=(point, point)))
    summary["links"] = f"{len(links)} links checked (>= 1 m), {blocked} blocked"


# --- entities ------------------------------------------------------------------------------------------------------

def capture_points(census: dict) -> list[dict]:
    """The capture points with their measured radius (zones.py): radius, measured (samples), inactive (nobody was
    ever inside, but in another capture point of the same name: the layout of another mode)."""
    zones = as_list(census.get("zones"))
    result = []
    for capture_point in as_list((census.get("entities") or {}).get("capturePoints")):
        pos = as_list(capture_point.get("pos"))
        if len(pos) < 3:
            continue
        entry = dict(capture_point)
        zone = next((zone for zone in zones if zone.get("name") == capture_point.get("name")
                     and math.dist(as_list(zone.get("pos")), pos) < 2.0), None)
        entry["samples"] = int(zone.get("samples") or 0) if zone else 0
        # The measured shape: cells (column, row) of zone["cell"] metres with players inside.
        entry["cell"] = float(zone.get("cell") or 2.0) if zone else 2.0
        entry["zoneCells"] = {(int(cell[0]), int(cell[1])) for cell in as_list(zone.get("cells")) if cell[2] > 0} \
            if zone else set()
        # Cells where players were only ever outside: not part of the zone.
        entry["outsideCells"] = {(int(cell[0]), int(cell[1])) for cell in as_list(zone.get("cells"))
                                 if cell[2] == 0 and cell[3] > 0} if zone else set()
        entry["radius"] = float(zone["radius"]) if zone and zone.get("radius") else \
            float(capture_point.get("radius") or 0) or UNKNOWN_RADIUS
        result.append(entry)
    visited = {entry.get("name") for entry in result if entry["samples"]}
    for entry in result:
        zone = next((zone for zone in zones if zone.get("name") == entry.get("name")
                     and math.dist(as_list(zone.get("pos")), as_list(entry.get("pos"))) < 2.0), None)
        # Nobody inside even next to it (zone probe, ZoneProbe.lua), or only in another one of the same name.
        probed_inactive = bool(zone and zone.get("probed") and not zone.get("active"))
        entry["inactive"] = probed_inactive or (not entry["samples"] and entry.get("name") in visited)
    return result


def _check_capture_points(census: dict, nodes: _Nodes, issues: list[Issue], summary: dict) -> None:
    foot = nodes.positions(nodes.foot)
    lines = []
    for capture_point in capture_points(census):
        pos = as_list(capture_point.get("pos"))
        name = capture_point.get("objective") or capture_point.get("name")
        if capture_point["inactive"]:
            lines.append(f"{name} ({capture_point.get('name')}{', HQ' if capture_point.get('hq') else ''}): "
                         f"inactive (nobody inside, layout of another mode)")
            continue
        radius = capture_point["radius"]
        inside = [entry for entry in foot
                  if math.hypot(entry[2][0] - pos[0], entry[2][2] - pos[2]) <= radius
                  and abs(entry[2][1] - pos[1]) <= CAPTURE_HEIGHT]
        hq = capture_point.get("hq")
        measured = f"measured from {capture_point['samples']} samples" if capture_point["samples"] else "not measured"
        lines.append(f"{name} ({capture_point.get('name')}{', HQ' if hq else ''}): radius {radius:.0f} m "
                     f"({measured}), {len(inside)} waypoints on {len({path for path, _, _ in inside})} paths inside")
        if not hq and not inside:
            issues.append(Issue("capture-uncovered", "error", f"no walked waypoint inside the capture-radius of "
                                f"{name} ({radius:.0f} m)", pos=pos))
        if not hq and not capture_point.get("objective"):
            issues.append(Issue("capture-unnamed", "warn", f"capture point {capture_point.get('name')} has no "
                                "objective of the waypoints", pos=pos))
    if lines:
        summary["capture points"] = lines

    # Two active capture points with the same objective: the waypoints lack the objective of one of them (the
    # GameDirector translates a capture point to the objective of the closest path that has it alone).
    by_objective: dict[str, list[str]] = defaultdict(list)
    for capture_point in capture_points(census):
        if not capture_point["inactive"] and not capture_point.get("hq") and capture_point.get("objective"):
            by_objective[str(capture_point["objective"])].append(str(capture_point.get("name")))
    for objective, names in by_objective.items():
        if len(names) > 1:
            issues.append(Issue("objective-shared", "error", f"capture points {', '.join(names)} all count as "
                                f"objective {objective}: the waypoints lack the objectives of the others"))


def _area(polygon: list[tuple[float, float]]) -> float:
    return 0.5 * abs(sum(ax * bz - bx * az for (ax, az), (bx, bz) in zip(polygon, polygon[1:] + polygon[:1])))


def combat_polygons(census: dict) -> tuple[dict[int, list[list[tuple[float, float]]]], str]:
    """The ground combat-area of each team. The level links the same shapes to the triggers of both teams (one per
    team and a big one for aircraft), so each team gets the smallest shape around its own HQ."""
    entities = census.get("entities") or {}
    shapes = []
    for area in as_list(entities.get("combatAreas")):
        for shape in as_list(area.get("shapes")):
            polygon = [_transform(as_list(point), None) for point in as_list(shape.get("points"))
                       if len(as_list(point)) >= 3]
            if len(polygon) >= 3 and polygon not in shapes:
                shapes.append(polygon)
    if not shapes:
        return {}, "no shapes found"

    hqs = {int(point.get("team") or 0): as_list(point.get("pos")) for point in capture_points(census)
           if point.get("hq") and not point["inactive"] and int(point.get("team") or 0) in (1, 2)}
    polygons: dict[int, list] = {}
    for team, pos in hqs.items():
        around = [polygon for polygon in shapes if _in_polygon(pos[0], pos[2], polygon)]
        if around:
            polygons[team] = [min(around, key=_area)]
    if not polygons:
        return {}, f"{len(shapes)} shapes, but none around an HQ"
    return polygons, (f"{len(shapes)} shapes, " + ", ".join(
        f"team {team}: {_area(polygon[0]) / 1e6:.2f} km²" for team, polygon in sorted(polygons.items())))


def _check_combat_area(census: dict, nodes: _Nodes, issues: list[Issue], summary: dict) -> None:
    polygons, how = combat_polygons(census)
    summary["combat area"] = how
    if not polygons:
        return

    def inside(team: int, pos: list[float]) -> bool:
        team_polygons = polygons.get(team, [])
        return not team_polygons or any(_in_polygon(pos[0], pos[2], polygon) for polygon in team_polygons)

    outside: dict[int, list[int]] = defaultdict(list)
    per_team = {1: 0, 2: 0}
    for path in sorted(nodes.foot):
        for point, pos in enumerate(nodes.paths[path]["points"], start=1):
            in_team = {team: inside(team, pos) for team in per_team}
            for team, ok in in_team.items():
                per_team[team] += not ok
            if not any(in_team.values()):
                outside[path].append(point)
    for path, points in outside.items():
        for first, last in _runs(points):
            issues.append(Issue("out-of-area", "error", f"path {path} points {first}-{last}: outside of the combat "
                                "area of both teams", pos=nodes.paths[path]["points"][first - 1], path=path,
                                points=(first, last)))
    summary["combat area"] += (f"; walked waypoints outside for team 1: {per_team[1]}, team 2: {per_team[2]}, "
                               f"both: {sum(len(points) for points in outside.values())}")


def _spawn_team(spawn: dict):
    """The team of a soldier-spawn: that of its data, else of the entity (MapCensus._SpawnAreas)."""
    return spawn.get("dataTeam") if spawn.get("dataTeam") in (1, 2) else spawn.get("team")


def _check_spawns(entities: dict, nodes: _Nodes, issues: list[Issue], summary: dict) -> None:
    foot = nodes.positions(nodes.foot)
    distances = []
    spawns = as_list(entities.get("spawns"))
    # A spawn with a vehicle-spawn on its bus puts the soldier into the vehicle: only checked for a team without other
    # spawns (the B2K levels have one on the bus of all their spawns, the game spawns the soldier there on foot).
    on_foot = {_spawn_team(spawn) for spawn in spawns if spawn.get("vehicleSpawn") is None}
    for spawn in spawns:
        pos = as_list(spawn.get("pos"))
        if len(pos) < 3 or (spawn.get("vehicleSpawn") is not None and _spawn_team(spawn) in on_foot) or not foot:
            continue
        distance, _ = _closest(foot, pos)
        distances.append(distance)
        if distance > SPAWN_DISTANCE:
            issues.append(Issue("spawn-far", "info", f"soldier-spawn of team {spawn.get('team')} is "
                                f"{distance:.0f} m from the next walked waypoint", pos=pos))
    if distances:
        summary["spawns"] = (f"{len(distances)} soldier-spawns, median {median(distances):.0f} m, max "
                             f"{max(distances):.0f} m to the next walked waypoint")

    vehicle = nodes.positions(nodes.vehicle)
    lines = []
    for spawn in as_list(entities.get("vehicleSpawns")):
        pos = as_list(spawn.get("pos"))
        if len(pos) < 3 or not spawn.get("enabled"):
            continue
        name = str(spawn.get("blueprint") or "?").rsplit("/", 1)[-1]
        distance, where = _closest(vehicle, pos) if vehicle else (math.inf, None)
        lines.append(f"{name} (team {spawn.get('team')}, {'on' if spawn.get('enabled') else 'off'}): "
                     f"{distance:.0f} m to path {where[0] if where else '-'}")
        if distance > VEHICLE_SPAWN_DISTANCE:
            issues.append(Issue("vehicle-spawn-far", "info", f"vehicle-spawn {name} of team {spawn.get('team')} is "
                                f"{distance:.0f} m from the next vehicle-path", pos=pos))
    if lines:
        summary["vehicle spawns"] = lines


# --- grids around the objectives -----------------------------------------------------------------------------------

def area_graph(area: dict) -> tuple[dict[tuple[int, int, int], tuple[float, float, int, float]],
                                    dict[tuple[int, int, int], list[tuple[int, int, int]]]]:
    """Walkable surfaces of a grid and their connections. A surface is (row, column, layer) -> (y, normal-y, edges,
    headroom). Two surfaces of neighbour-cells are connected if the height step is small and no ray between them hit
    at chest height (or at knee height without a step), in either direction (bits 16-128: the rays back, from censuses
    that have them). A lower floor needs LAYER_GAP below the one above: the vertical rays also find the ground inside
    of rocks and buildings, where the headroom-ray (from inside) hits nothing."""
    surfaces = {}
    for row, cells in enumerate(area.get("cells") or []):
        for column, cell in enumerate(as_list(cells)):
            values = as_list(cell)
            above = None
            for layer in range(len(values) // 4):
                y, normal, edges, headroom = values[layer * 4:layer * 4 + 4]
                gap_ok = above is None or above - y >= LAYER_GAP
                above = y
                if normal >= WALK_NORMAL_Y and gap_ok and (headroom < 0 or headroom >= WALK_HEADROOM):
                    edges = int(edges)
                    # Fold the rays back into the forward bits: blocked in either direction is blocked.
                    edges = (edges | (edges >> 4)) & 0xF
                    surfaces[(row, column, layer)] = (y, normal, edges, headroom)

    by_cell: dict[tuple[int, int], list[tuple[int, tuple]]] = defaultdict(list)
    for (row, column, layer), surface in surfaces.items():
        by_cell[(row, column)].append((layer, surface))

    links: dict[tuple[int, int, int], list[tuple[int, int, int]]] = defaultdict(list)
    for (row, column, layer), (y, _, edges, _) in surfaces.items():
        # +x: bits 1 (knee) and 2 (chest), +z: bits 4 and 8. The rays start at this surface.
        for d_row, d_column, knee, chest in ((0, 1, 1, 2), (1, 0, 4, 8)):
            for other_layer, (other_y, _, _, _) in by_cell.get((row + d_row, column + d_column), []):
                step = abs(other_y - y)
                if step > STEP_HEIGHT or edges & chest or (edges & knee and step < 0.3):
                    continue
                a, b = (row, column, layer), (row + d_row, column + d_column, other_layer)
                links[a].append(b)
                links[b].append(a)
    return surfaces, links


def _check_areas(census: dict, nodes: _Nodes, issues: list[Issue], summary: dict) -> None:
    zones = {str(point.get("objective") or point.get("name")): point
             for point in capture_points(census) if not point["inactive"] and not point.get("hq")}
    foot = nodes.positions(nodes.foot)
    lines = []
    for area in census.get("areas") or []:
        step = float(area["step"])
        x0, z0 = float(area["x0"]), float(area["z0"])
        center = as_list(area.get("center"))
        surfaces, links = area_graph(area)

        # Seeds: the surfaces under the waypoints in the area.
        seeds = set()
        for _, _, pos in foot:
            if math.hypot(pos[0] - center[0], pos[2] - center[2]) > float(area["radius"]):
                continue
            row, column = round((pos[2] - z0) / step), round((pos[0] - x0) / step)
            best = None
            for layer in range(int(area.get("layers") or 1)):
                surface = surfaces.get((row, column, layer))
                if surface and abs(surface[0] - pos[1]) <= SEED_HEIGHT and \
                        (best is None or abs(surface[0] - pos[1]) < abs(surfaces[best][0] - pos[1])):
                    best = (row, column, layer)
            if best:
                seeds.add(best)

        reached = set(seeds)
        queue = deque(seeds)
        while queue:
            for neighbour in links.get(queue.popleft(), []):
                if neighbour not in reached:
                    reached.add(neighbour)
                    queue.append(neighbour)

        name = str(area.get("name"))
        zone = zones.get(name)
        radius = zone["radius"] if zone else 0.0
        # The measured shape (grown by one cell), else the circle.
        shape = {(column + d_column, row + d_row) for column, row in zone["zoneCells"]
                 for d_column in (-1, 0, 1) for d_row in (-1, 0, 1)} if zone and zone["zoneCells"] else None

        def in_radius(key: tuple[int, int, int]) -> bool:
            row, column, _ = key
            x, z = x0 + column * step, z0 + row * step
            if shape is not None:
                return (math.floor(x / zone["cell"]), math.floor(z / zone["cell"])) in shape
            return math.hypot(x - center[0], z - center[2]) <= radius

        cell_area = step * step
        line = (f"{name} ({area.get('kind')}): {len(surfaces) * cell_area:.0f} m² walkable, "
                f"{len(reached) * cell_area:.0f} m² reached from {len(seeds)} waypoint-cells")
        if radius:
            inside = sum(1 for key in surfaces if in_radius(key))
            reached_inside = sum(1 for key in reached if in_radius(key))
            share = reached_inside / inside if inside else 0.0
            what = f"measured zone ({len(zone['zoneCells'])} cells)" if shape is not None else f"radius {radius:.0f} m"
            line += f"; {what}: {100 * share:.0f} % of its walkable area reached"
            if inside and share < 0.3:
                issues.append(Issue("area-unreached", "info", f"only {100 * share:.0f} % of the walkable area of "
                                    f"{name} is reached from the waypoints", pos=center))
        lines.append(line)
    if lines:
        summary["objective areas"] = lines


# --- all -----------------------------------------------------------------------------------------------------------

def build_report(census: dict) -> Report:
    nodes = _Nodes(census)
    entities = census.get("entities") or {}
    issues: list[Issue] = []
    total = sum(len(entry["points"]) for entry in nodes.paths.values())
    run = census.get("summary") or {}
    summary: dict[str, Any] = {
        "waypoints": f"{total} on {len(nodes.paths)} paths ({len(nodes.foot)} walked, "
                     f"{len(nodes.paths) - len(nodes.foot) - len(nodes.air)} with vehicles, "
                     f"{len(nodes.air)} in the air without tag)",
        "run": f"{run.get('raycasts')} raycasts in {run.get('seconds')} s, {run.get('cells')} grid-cells",
    }
    if entities.get("errors"):
        summary["errors"] = as_list(entities.get("errors"))

    _check_nodes(nodes, issues, summary)
    _check_links(census, nodes, issues, summary)
    _check_capture_points(census, nodes, issues, summary)
    _check_combat_area(census, nodes, issues, summary)
    _check_spawns(entities, nodes, issues, summary)
    _check_areas(census, nodes, issues, summary)
    return Report(str(census.get("paths") or ""), summary, issues)
