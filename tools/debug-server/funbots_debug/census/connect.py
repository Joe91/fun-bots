"""Records the paths of a level by itself (`census connect`): the mesh of the census covers the objectives and the
spawns, here bots walk the ways between them.

1. The islands of the level: parts of the mesh (with the paths there are) that reach each other.
2. The closest two islands are joined first, then the next (a tree over the islands, as Kruskal), so every spawn and
   objective reaches every other one. Then a second way between the objectives that follow each other (rush: MCOM N
   and N+1, conquest: neighbouring capture points), apart from the first one.
3. Each way is planned with the rays of the game and walked by a bot (record.record_gap). A way that leaves the
   combat-area of the running rush stage waits: the bots play until the next stage, then it is tried again.
4. The new paths go into mapfiles/<map>.map, are cut (navpaths --write --db) and loaded into the running round
   (command paths_reload), so the bots use them at once.

    python -m funbots_debug.census connect MP_012_SquadRush0 [--server URL] [--stages] [--dry-run]
"""
from __future__ import annotations

import json
import math
import time
from pathlib import Path

from ..paths.mapfile import MapData
from . import lint, record

MIN_PART = 10          # Mesh parts with fewer points are no island (a speck the rays left).
GOAL_SAMPLE = 400      # At most this many goal points of an island (the closest ones to the start).
SECOND_APART = 25.0    # A second way between two objectives keeps this far from the first one (metres, via point).
SECOND_MIN = 60.0      # Only between objectives this far apart.
STAGE_TIMEOUT = 900.0  # Seconds the bots get to win a rush stage.


def islands(networks: dict, data: MapData) -> list[dict]:
    """The islands: {"points": [mesh points], "zones": [names], "objectives": [names]}, the ones with a zone only."""
    graph = lint.build_graph(networks, data)
    points = networks.get("points") or []
    seen: dict[int, int] = {}
    result = []
    for start in range(len(points)):
        if start in seen:
            continue
        field = lint._field(graph, [("m", start)])
        members = [node[1] for node in field if node[0] == "m"]
        for member in members:
            seen[member] = len(result)
        result.append({"points": members, "zones": [], "objectives": []})
    for zone in networks.get("zones") or []:
        owners = {seen[point] for point in zone.get("inside") or [] if point in seen}
        for owner in owners:
            result[owner]["zones"].append(zone["name"])
            if zone.get("kind") in lint.OBJECTIVE_KINDS:
                result[owner]["objectives"].append(zone["name"])
    return [island for island in result if island["zones"] and len(island["points"]) >= MIN_PART]


def _closest(points: list[list[float]], a: list[int], b: list[int]) -> tuple[float, int, int]:
    best = (math.inf, -1, -1)
    for i in a:
        pa = points[i]
        for j in b:
            d = math.dist(pa, points[j])
            if d < best[0]:
                best = (d, i, j)
    return best


def tree(networks: dict, found: list[dict]) -> list[tuple[float, int, int, int, int]]:
    """The joins of a tree over the islands, shortest first: (metres, island a, island b, point a, point b)."""
    points = networks["points"]
    pairs = []
    for a in range(len(found)):
        for b in range(a + 1, len(found)):
            distance, pa, pb = _closest(points, found[a]["points"], found[b]["points"])
            pairs.append((distance, a, b, pa, pb))
    pairs.sort()
    owner = list(range(len(found)))

    def root(index: int) -> int:
        while owner[index] != index:
            owner[index] = owner[owner[index]]
            index = owner[index]
        return index

    joins = []
    for pair in pairs:
        ra, rb = root(pair[1]), root(pair[2])
        if ra != rb:
            owner[ra] = rb
            joins.append(pair)
    return joins


def objective_order(networks: dict) -> list[dict]:
    """The objectives in the order they are played: rush MCOMs by number, capture points by name."""
    zones = [zone for zone in networks.get("zones") or [] if zone.get("kind") in lint.OBJECTIVE_KINDS]

    def key(zone):
        name = str(zone.get("name"))
        number = name.split()[-1]
        return (0, int(number), name) if number.isdigit() else (1, 0, name)

    return sorted(zones, key=key)


def second_ways(networks: dict, data: MapData) -> list[tuple[list[float], list[float], list[float]]]:
    """(start, goal, via) of a second way between objectives that follow each other: through a point SECOND_APART to
    the side of the middle of the straight line, on the side away from the recorded paths there."""
    zones = objective_order(networks)
    result = []
    for a, b in zip(zones, zones[1:]):
        ca, cb = a["center"], b["center"]
        length = math.hypot(cb[0] - ca[0], cb[2] - ca[2])
        if length < SECOND_MIN:
            continue
        middle = [(ca[0] + cb[0]) / 2, (ca[1] + cb[1]) / 2, (ca[2] + cb[2]) / 2]
        side = [-(cb[2] - ca[2]) / length, 0.0, (cb[0] - ca[0]) / length]
        # The side with fewer waypoints near the middle (the first way went the other one).
        counts = []
        for sign in (1, -1):
            via = [middle[0] + sign * side[0] * SECOND_APART, middle[1], middle[2] + sign * side[2] * SECOND_APART]
            counts.append((sum(1 for p in data.paths.values() for n in p.nodes
                               if math.hypot(n.pos[0] - via[0], n.pos[2] - via[2]) < SECOND_APART), sign, via))
        counts.sort()
        result.append((list(ca), list(cb), counts[0][2]))
    return result


def team_of(*zone_lists: list[str]) -> int:
    """The team whose bot walks a way between islands with these zones: the one whose spawns are there (its own
    combat-area), the attackers (team 1) where both or none are."""
    names = " ".join(name for zones in zone_lists for name in zones)
    us = "spawn us" in names or "base us" in names
    ru = "spawn ru" in names or "base ru" in names
    return 2 if ru and not us else 1


def _gap(label: str, networks: dict, found: list[dict], a: int, b: int, pa: int, pb: int) -> record.Gap:
    points = networks["points"]
    start, goal = list(points[pa][:3]), list(points[pb][:3])
    starts = sorted((list(points[i][:3]) for i in found[a]["points"]), key=lambda p: math.dist(p, goal))[:6]
    goals = sorted((list(points[i][:3]) for i in found[b]["points"]), key=lambda p: math.dist(p, start))[:GOAL_SAMPLE]
    return record.Gap(label, starts, goals, (start, goal))


def stage(server) -> tuple[int | None, int]:
    """The rush stage that runs (None outside of rush) and the MCOMs destroyed."""
    objectives = server.request("/api/state").get("objectives") or {}
    return objectives.get("stage"), sum(1 for mcom in objectives.get("mcoms") or [] if mcom.get("destroyed"))


def record_round(server, name: str, networks: dict, data: MapData, log=print, max_gap: float = 400.0,
                 second_way: bool = True, shapes: list | None = None) -> tuple[list[dict], int]:
    """One round of joins on the level as it runs: the paths walked ([{label, points}]) and how many were left for a
    later stage (out of the combat-area now)."""
    found = islands(networks, data)
    log(f"  {len(found)} islands: " + "; ".join(", ".join(island["zones"]) for island in found))
    walked = []
    later = 0
    jobs = []
    for distance, a, b, pa, pb in tree(networks, found):
        label = f"{found[a]['zones'][0]} - {found[b]['zones'][0]}"
        if distance > max_gap:
            log(f"  {label}: {distance:.0f} m, skipped (--max-gap)")
            continue
        jobs.append((label, _gap(label, networks, found, a, b, pa, pb), None,
                     team_of(found[a]["zones"], found[b]["zones"])))
    if second_way and len(found) == 1:
        for start, goal, via in second_ways(networks, data):
            label = f"second way {[round(c) for c in start]} - {[round(c) for c in goal]}"
            if any(entry.get("spawn") == label for entry in _recorded(name)):
                continue
            gap = record.Gap(label, [start], [goal], (start, goal))
            jobs.append((label, gap, [via], 1))
    for label, gap, via, team in jobs:
        messages: list[str] = []

        def note(message: str) -> None:
            messages.append(message)
            log(message)

        log(f"  {label}: {math.dist(*gap.best):.0f} m, a bot of team {team}")
        way = record.record_gap(server, gap, log=note, shapes=shapes, via=via, stop_at_border=True, team=team)
        if way:
            walked.append({"spawn": label, "points": way})
            log(f"  {label}: way of {len(way)} points")
        elif any("border" in message for message in messages):
            later += 1
            log(f"  {label}: out of the combat-area now, in a later stage")
        else:
            log(f"  {label}: no way found")
    return walked, later


def _recorded(name: str) -> list[dict]:
    file = record.RECORDED / f"{name}.json"
    return json.loads(file.read_text(encoding="utf-8")).get("paths", []) if file.is_file() else []


def wait_next_stage(server, log=print, timeout: float = STAGE_TIMEOUT) -> bool:
    """The bots play (fight, attack) until the next rush stage starts. False if it didn't in time or the round ended."""
    before, destroyed = stage(server)
    if before is None:
        return False
    log(f"  stage {before}: the bots play until the next one")
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        time.sleep(10)
        now, gone = stage(server)
        if now is not None and (now != before or gone > destroyed):
            # The game opens the next combat-area a moment after the MCOM went off.
            time.sleep(15)
            log(f"  stage {now} ({gone} MCOMs destroyed)")
            return True
    log("  no next stage in time")
    return False


def add_paths(data: MapData, walked: list[dict]) -> list[int]:
    return [record.add_path(data, entry["points"]) for entry in walked]
