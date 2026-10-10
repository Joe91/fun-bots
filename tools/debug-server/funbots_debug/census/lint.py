"""Offline checks of the routes of a level, the way the mod sees them (ext/Server/NavRoutes.lua): the mesh of
navzones/<map>.json, the walkable paths of mapfiles/<map>.map (foot paths, and land vehicle paths as roads), their
links and the junctions between both. No game needed: `python -m funbots_debug.census lint` (all levels with a mesh).

- unreachable (error): an objective (capture point, MCOM) the bots can't walk to from another one.
- spawn-cut-off (warning): a spawn area (base) from which no objective can be walked to. The carriers and ships of
  some levels are like that by design (boats, AMTRACs or helicopters are their way): list them in lint_known.json.
- dead-end (warning): a foot path with fewer than two ways out (junctions onto the mesh, links to other paths).
- split-junctions (info): two junctions next to each other on a path whose mesh points are close straight but far
  over the mesh (NavRoutes:Step goes on from the second only at a cost, NO_ENTER_RANGE).
- blocked-junction (warning): a junction the rays of the game found blocked (census/<map>.checks.json, check.py) is
  still in the mesh: the cut found no free one for that end of the path (a wall all around), it needs work by hand.

The findings in lint_known.json (next to this file) are known and accepted: only others fail the check.
"""

from __future__ import annotations

import heapq
import json
import math
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from ..paths.mapfile import MapData

# As in NavRoutes.lua.
ROAD_FACTOR = 1.5
LINK_COST = 2.0
LINK_MAX = 15.0
MESH_CROSSING = 10.0
NO_ENTER_RANGE = 10.0
# Over the mesh this much longer than NO_ENTER_RANGE straight: the two junctions are "split".
SPLIT_DETOUR = 30.0
# A loop closes over its gap only if it is this short (NodeCollection).
LOOP_GAP = 30.0
# As check.MATCH: a blocked junction of the checks is at this point and waypoint.
CHECK_MATCH = 0.3
OBJECTIVE_KINDS = ("capturepoint", "mcom")
SPAWN_KINDS = ("base",)
KNOWN = Path(__file__).with_name("lint_known.json")


@dataclass
class Finding:
    map: str
    kind: str
    severity: str
    message: str

    @property
    def key(self) -> str:
        return f"{self.map}: {self.kind}: {self.message}"


def _walkable(path) -> bool:
    return not path.vehicles or path.vehicles == ["land"]


def build_graph(networks: dict, data: MapData) -> dict:
    """node -> [(node, metres)]: ("m", point) for the mesh, ("w", path, point) for waypoints."""
    graph: dict = defaultdict(list)

    def add(a, b, cost):
        graph[a].append((b, cost))
        graph[b].append((a, cost))

    for edge in networks.get("edges") or []:
        add(("m", edge[0]), ("m", edge[1]), edge[2])
    walkable = {index for index, path in data.paths.items() if _walkable(path)}
    for index in walkable:
        path = data.paths[index]
        factor = ROAD_FACTOR if path.vehicles else 1.0
        for a, b in zip(path.nodes, path.nodes[1:]):
            add(("w", index, a.point), ("w", index, b.point), math.dist(a.pos, b.pos) * factor)
        if len(path.nodes) > 2 and path.loops and path.gap <= LOOP_GAP:
            add(("w", index, path.nodes[-1].point), ("w", index, path.nodes[0].point), path.gap * factor)
        for node in path.nodes:
            for link in node.links:
                if link[0] not in walkable:
                    continue
                other = data.node(*link)
                if other is not None and math.dist(node.pos, other.pos) <= LINK_MAX:
                    add(("w", index, node.point), ("w", *link), math.dist(node.pos, other.pos) + LINK_COST)
    for attach in networks.get("attach") or []:
        if int(attach[0]) in walkable:
            add(("w", int(attach[0]), int(attach[1])), ("m", int(attach[2])), float(attach[3]) + MESH_CROSSING)
    return graph


def _field(graph: dict, sources, limit: float = math.inf) -> dict:
    cost = {source: 0.0 for source in sources}
    heap = [(0.0, source) for source in cost]
    heapq.heapify(heap)
    while heap:
        current, node = heapq.heappop(heap)
        if current > cost[node] or current > limit:
            continue
        for other, metres in graph[node]:
            if current + metres < cost.get(other, math.inf):
                cost[other] = current + metres
                heapq.heappush(heap, (current + metres, other))
    return cost


def lint_map(name: str, networks: dict, data: MapData, checks: dict | None = None) -> list[Finding]:
    findings: list[Finding] = []
    graph = build_graph(networks, data)
    zones = [zone for zone in networks.get("zones") or [] if zone.get("inside")]
    objectives = [zone for zone in zones if zone.get("kind") in OBJECTIVE_KINDS]
    fields = {zone["name"]: _field(graph, [("m", point) for point in zone["inside"]]) for zone in objectives}

    def reaches(zone: dict, objective: dict) -> bool:
        field = fields[objective["name"]]
        return any(("m", point) in field for point in zone["inside"])

    for zone in objectives:
        for objective in objectives:
            if zone is not objective and zone["name"] < objective["name"] and not reaches(zone, objective):
                findings.append(Finding(name, "unreachable", "error",
                                        f"{objective['name']} can't be walked to from {zone['name']}"))
    for zone in zones:
        if zone.get("kind") in SPAWN_KINDS and objectives and not any(reaches(zone, o) for o in objectives):
            findings.append(Finding(name, "spawn-cut-off", "warning",
                                    f"no objective can be walked to from {zone['name']}"))

    junctions = defaultdict(list)
    for attach in networks.get("attach") or []:
        junctions[int(attach[0])].append((int(attach[1]), int(attach[2])))
    for index, path in sorted(data.paths.items()):
        if path.vehicles:
            continue
        ways = len({point for point, _ in junctions[index]}) + len({link[0] for node in path.nodes for link in node.links})
        if ways < 2:
            findings.append(Finding(name, "dead-end", "warning",
                                    f"foot path {index} ({len(path.nodes)} waypoints) has {ways} ways out"))

    points = networks.get("points") or []
    mesh: dict = defaultdict(list)
    for edge in networks.get("edges") or []:
        mesh[("m", edge[0])].append((("m", edge[1]), edge[2]))
        mesh[("m", edge[1])].append((("m", edge[0]), edge[2]))
    for index, attached in sorted(junctions.items()):
        if index not in data.paths or not _walkable(data.paths[index]):
            continue
        attached.sort()
        for (point_a, mesh_a), (point_b, mesh_b) in zip(attached, attached[1:]):
            if mesh_a == mesh_b or math.dist(points[mesh_a][:3], points[mesh_b][:3]) >= NO_ENTER_RANGE:
                continue
            limit = NO_ENTER_RANGE + SPLIT_DETOUR
            if _field(mesh, [("m", mesh_a)], limit).get(("m", mesh_b), math.inf) > limit:
                findings.append(Finding(name, "split-junctions", "info",
                                        f"path {index} points {point_a} and {point_b}: mesh points {mesh_a} and "
                                        f"{mesh_b} close, but not over the mesh"))

    blocked = (checks or {}).get("blockedJunctions") or []
    for attach in networks.get("attach") or [] if blocked else []:
        if len(attach) < 5:
            continue
        point, waypoint = points[int(attach[2])], attach[4]
        if any(math.dist(entry[:3], point[:3]) <= CHECK_MATCH and math.dist(entry[3:6], waypoint[:3]) <= CHECK_MATCH
               for entry in blocked):
            findings.append(Finding(name, "blocked-junction", "warning",
                                    f"path {attach[0]} point {attach[1]} at ({waypoint[0]:.0f}, {waypoint[1]:.0f}, "
                                    f"{waypoint[2]:.0f}): the way onto the mesh is blocked in the game"))
    return findings


def load_known(file: Path = KNOWN) -> set[str]:
    if not file.is_file():
        return set()
    return set(json.loads(file.read_text(encoding="utf-8")).get("known") or [])


def lint(names: list[str], navzones_dir: Path, mapfiles: Path, census_dir: Path | None = None) -> list[Finding]:
    """census_dir: where the checks of the game are (census/<map>.checks.json), for blocked-junction."""
    findings = []
    for name in names:
        networks = json.loads((navzones_dir / f"{name}.json").read_text(encoding="utf-8"))
        checks_file = census_dir / f"{name}.checks.json" if census_dir is not None else None
        checks = json.loads(checks_file.read_text(encoding="utf-8")) if checks_file and checks_file.is_file() else None
        findings.extend(lint_map(name, networks, MapData.load(mapfiles / f"{name}.map"), checks))
    return findings


def all_maps(navzones_dir: Path, mapfiles: Path) -> list[str]:
    """The levels with a mesh and a waypoint-file."""
    return [file.stem for file in sorted(navzones_dir.glob("*.json")) if (mapfiles / f"{file.stem}.map").is_file()]
