"""Rush: the paths of one MCOM a bot can't get from to the other MCOM of the stage.

When one MCOM of a stage is destroyed, the bots there get the other one as objective. They follow the path-switches of
PathSwitcher:GetNewPath, which only lead towards their objective: from the path of an MCOM onto a path with all objectives
active that names the other MCOM, or with a higher priority. A path of "mcom 2, mcom 3" is only partly active in the stage
of mcom 3 and 4, a path with a base is never taken. If the paths of the two MCOMs are only connected that way, the bots
stay at the destroyed one.

For every path of an MCOM without a way to the other MCOM of its stage, it's linked to the closest node of a path that
names the other MCOM (all objectives active, no base) within link_radius: the path of that MCOM itself first, then walked
paths to it, then paths of the vehicles. Else it's reported.
"""

from __future__ import annotations

from dataclasses import dataclass

from .bases import RUSH_MODES, Options, Stage, _link, _team, stages
from .labeler import Change, Labeler, _Grid
from .mapfile import MapData, PathData


@dataclass
class Gap:
    stage: int
    path: int
    objective: str  # the MCOM of the path
    target: str  # the other MCOM of the stage it doesn't get to


def _mcom(name: str) -> bool:
    """"mcom N", not "mcom N interact"."""
    fields = name.lower().split(" ")
    return len(fields) == 2 and fields[0] == "mcom"


def _walkable(path: PathData) -> bool:
    """PathSwitcher:IsWalkable"""
    return bool(path.nodes) and "air" not in path.vehicles and not Labeler._driven(path)


def _priority(path: PathData, target: str) -> int:
    """PathSwitcher:GetPriorityOfPath"""
    objectives = path.objectives
    if objectives and target:
        if len(objectives) == 1:
            return 4 if objectives[0] == target else 2
        return 3 if target in objectives else -1
    return 0


def switches(data: MapData, stage: Stage, current: PathData, target: str) -> set[int]:
    """Paths a bot on current with the objective target may switch to (PathSwitcher:GetNewPath, without the fallbacks
    and random switches to explore- or beacon-paths)."""
    objectives = current.objectives
    if len(objectives) == 1 and "vehicle" in objectives[0].lower():
        return set()
    status = stage.status(current)
    on_base = any(_team(name) for name in objectives)
    priority = _priority(current, target)
    found = set()
    for node in current.nodes:
        for index, _ in node.links:
            new = data.paths.get(index)
            if new is None or new is current or not _walkable(new):
                continue
            new_objectives = new.objectives
            if len(new_objectives) == 1 and any(word in new_objectives[0].lower() for word in ("vehicle", "beacon")):
                continue
            new_status = stage.status(new)
            new_base = any(_team(name) for name in new_objectives)
            new_priority = _priority(new, target)
            switch = False
            if on_base:
                if not new_base and new_status == 2:
                    switch = True
                elif new_base and len(objectives) == 1 and len(new_objectives) > 1 and new_status == 2:
                    switch = True
            if new_status > status:
                switch = True
            if new_status == 0 and status == 0 and len(objectives) > len(new_objectives) and not new_base:
                switch = True
            if not objectives and new_objectives:
                switch = True
            if switch:
                new_priority = 5
            if status <= new_status and priority <= new_priority and (
                    not new_base or (on_base and len(objectives) == 1) or new_priority == 5):
                found.add(index)
    return found


def reaches(data: MapData, stage: Stage, start: int, target: str) -> bool:
    """Whether a bot on the path start with the objective target gets to a path that names it."""
    seen, todo = {start}, [start]
    while todo:
        path = data.paths[todo.pop()]
        if target in path.objectives:
            return True
        for index in switches(data, stage, path, target):
            if index not in seen:
                seen.add(index)
                todo.append(index)
    return False


def check(data: MapData, mode: str) -> list[Gap]:
    if mode not in RUSH_MODES:
        return []
    found = []
    for number in stages(data, mode):
        stage = Stage(data, mode, number)
        mcoms = sorted({name for path in data.paths.values() for name in path.objectives
                        if _mcom(name) and stage.active.get(name)})
        for name in mcoms:
            for path in data.paths.values():
                if path.objectives != [name] or path.vehicles:
                    continue
                for target in mcoms:
                    if target != name and not reaches(data, stage, path.index, target):
                        found.append(Gap(number, path.index, name, target))
    return found


def fix(data: MapData, mode: str, options: Options, changes: list[Change]) -> None:
    """Links the paths of the MCOMs to the other MCOM of their stage (in place). See the module doc."""
    for gap in check(data, mode):
        path = data.paths[gap.path]
        stage = Stage(data, mode, gap.stage)
        if reaches(data, stage, path.index, gap.target):
            continue  # got there with a link made for another path
        found = _closest(data, stage, path, gap.target, options)
        where = f"stage {gap.stage}: "
        if found is None:
            changes.append(Change("warning", path.index, f"{where}bots on \"{gap.objective}\" can't get to "
                                                         f"\"{gap.target}\", no path to it within "
                                                         f"{options.link_radius:.0f} m"))
            continue
        distance, own, target = found
        _link(data, own, target)
        other = data.paths[target[0]]
        changes.append(Change("link-added", path.index, f"{where}from \"{gap.objective}\" to \"{gap.target}\" over "
                                                        f"[{', '.join(other.objectives)}], {distance:.1f} m",
                              own[1], target))


def _closest(data: MapData, stage: Stage, path: PathData, target: str, options: Options):
    """(distance, own node, node) of the best path to the target MCOM next to the path, or None."""
    candidates = {index: other for index, other in data.paths.items() if index != path.index
                  and target in other.objectives and stage.status(other) == 2 and _walkable(other)
                  and not any(_team(name) for name in other.objectives)}
    grid = _Grid(4.0)
    for index, other in candidates.items():
        for node in other.nodes:
            grid.add(index, node.point, node.pos)
    best = None
    for node in path.nodes:
        for index, point, distance in grid.near(node.pos, options.link_radius):
            if abs(data.node(index, point).pos[1] - node.pos[1]) > options.max_height:
                continue
            other = candidates[index]
            rank = (0 if other.objectives == [target] else 1) + (2 if other.vehicles else 0)
            if best is None or (rank, distance) < best[0]:
                best = ((rank, distance), (path.index, node.point), (index, point))
    return None if best is None else (best[0][1], best[1], best[2])
