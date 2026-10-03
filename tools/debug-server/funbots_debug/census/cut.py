"""Which waypoints the zone networks make unnecessary (dry run, nothing is changed).

Inside a zone the bots walk the network, so the paths only have to lead from zone to zone. For every walked path:

- drop: all its waypoints are inside of zones (a loop around a flag, a path inside a base),
- cut:  it runs through a zone; the waypoints inside could go, the pieces outside stay (they end at junctions),
- keep: no waypoint inside of a zone.

Paths with vehicles, actions (MCOM, vehicle, beacon) and air-paths are always kept. A waypoint is inside of a zone if
the closest point of the walking network (up to MATCH_DISTANCE away, same floor) lies in the zone.

    python -m funbots_debug.census cut ../../navzones/MP_012_ConquestSmall0.json [--mapfiles ../../mapfiles] [-v]
"""

from __future__ import annotations

import math
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from ..paths.mapfile import MapData

MATCH_DISTANCE = 6.0
FLOOR_HEIGHT = 1.5
IN_ZONE = 1


@dataclass
class PathCut:
    path: int
    objectives: list[str]
    count: int
    verdict: str  # drop | cut | keep | fixed
    inside: list[tuple[int, int, str]] = field(default_factory=list)  # (first, last, zone) runs of waypoints inside
    reason: str = ""


class _Zones:
    """The points of all networks in buckets, for "which zone is this waypoint in"."""

    def __init__(self, data: dict, cell: float = 10.0):
        self.cell = cell
        self.buckets: dict[tuple[int, int], list[tuple[list[float], bool, str]]] = defaultdict(list)
        for zone in data.get("zones") or []:
            for point in zone.get("points") or []:
                self.buckets[self._key(point)].append((point, bool(int(point[5]) & IN_ZONE), str(zone.get("name"))))

    def _key(self, pos) -> tuple[int, int]:
        return math.floor(pos[0] / self.cell), math.floor(pos[2] / self.cell)

    def zone_of(self, pos) -> str | None:
        x, z = self._key(pos)
        best = None
        for d_x in (-1, 0, 1):
            for d_z in (-1, 0, 1):
                for point, inside, name in self.buckets.get((x + d_x, z + d_z), []):
                    if abs(point[1] - pos[1]) > FLOOR_HEIGHT:
                        continue
                    distance = math.hypot(point[0] - pos[0], point[2] - pos[2])
                    if distance <= MATCH_DISTANCE and (best is None or distance < best[0]):
                        best = (distance, inside, name)
        return best[2] if best and best[1] else None


def analyze(data: dict, mapdata: MapData) -> list[PathCut]:
    zones = _Zones(data)
    result = []
    for index, path in sorted(mapdata.paths.items()):
        objectives = path.objectives
        count = len(path.nodes)
        fixed = ""
        if path.vehicles:
            fixed = "vehicles"
        elif any(node.data.get("Action") for node in path.nodes):
            fixed = "action"
        elif any("vehicle" in name or "beacon" in name or "interact" in name for name in objectives):
            fixed = objectives[0]
        if fixed:
            result.append(PathCut(index, objectives, count, "fixed", reason=fixed))
            continue

        runs: list[tuple[int, int, str]] = []
        for node in path.nodes:
            name = zones.zone_of(node.pos)
            if name is None:
                continue
            if runs and runs[-1][1] == node.point - 1 and runs[-1][2] == name:
                runs[-1] = (runs[-1][0], node.point, name)
            else:
                runs.append((node.point, node.point, name))
        inside = sum(last - first + 1 for first, last, _ in runs)
        verdict = "keep" if inside == 0 else "drop" if inside == count else "cut"
        result.append(PathCut(index, objectives, count, verdict, runs))
    return result


def summary(cuts: list[PathCut], verbose: bool = False) -> str:
    counts = defaultdict(int)
    nodes = defaultdict(int)
    for cut in cuts:
        counts[cut.verdict] += 1
        nodes[cut.verdict] += cut.count
    removable = sum(cut.count for cut in cuts if cut.verdict == "drop") + \
        sum(last - first + 1 for cut in cuts if cut.verdict == "cut" for first, last, _ in cut.inside)
    total = sum(cut.count for cut in cuts)
    lines = [f"{len(cuts)} paths, {total} waypoints: {removable} inside of zones "
             f"({100 * removable / max(1, total):.0f} %)"]
    for verdict in ("drop", "cut", "keep", "fixed"):
        lines.append(f"  {verdict}: {counts[verdict]} paths ({nodes[verdict]} waypoints)")
    if verbose:
        for cut in cuts:
            if cut.verdict in ("drop", "cut"):
                runs = ", ".join(f"{first}-{last} in {zone}" for first, last, zone in cut.inside)
                lines.append(f"    {cut.verdict} path {cut.path} ({', '.join(cut.objectives) or '-'}, {cut.count}): {runs}")
    return "\n".join(lines)


def run(file: Path, mapfiles: Path, verbose: bool) -> str:
    import json
    data = json.loads(file.read_text(encoding="utf-8"))
    name = data.get("map") or file.stem
    mapdata = MapData.load(mapfiles / f"{name}.map")
    return f"{name}\n{summary(analyze(data, mapdata), verbose)}"
