"""Rush: where bots get stuck on the way to their MCOM.

This plays through the path-switches of the waypoint navigation before the mesh: in the game the soldiers don't switch
by these rules anymore (NavRoutes, see README), only levels without a census are prepared with it.

The bots of both teams go for the MCOMs of the stage, and when one is destroyed, for the other one. They follow the
path-switches of PathSwitcher:GetNewPath, which mostly only lead towards their objective. This module plays that
through for every stage, both teams, and with none or one of the MCOMs destroyed: from the base-paths of the team and the
paths of the MCOMs, which paths can bots get to, and from which of them can't they get to their MCOM? Vehicles are left
out (bots on foot), as are the random switches to explore- and beacon-paths.

The rules, as in PathSwitcher:GetNewPath and GameDirector:
  - At a junction a bot switches to the path with the highest priority above the one of its own path (a path of its
    objective alone 4, a path naming it 3, of another objective alone 2), or at random to one of the same priority.
    Only to paths with at least as many objectives active as its own (a path of "mcom 2, mcom 3" is partly active in the
    stage of mcom 3 and 4), and onto a path with a base only from a base-path alone, or with priority 5 (a path with
    more objectives active than its own; off a path with a base a path with all active and no base).
  - Bots leave a base-path alone, a path out of a base at its ends, the path of a destroyed MCOM and the way to a
    vehicle that isn't theirs over any other path, if the path has no regular way out at all.
  - A destroyed MCOM stays active (the path of its "interact" has status -1).

fix() links the paths bots get stuck on to the closest path that names their MCOM (all objectives active, no base,
within link_radius, else the closest one), shortest link first, until nothing more can be linked. The rest is
reported.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .bases import RUSH_MODES, Found, Options, Stage, _link, _team, closest_link, stages
from .labeler import Change, Labeler
from .mapfile import MapData, PathData


@dataclass(frozen=True)
class Situation:
    stage: int
    team: str  # "us" (attackers) or "ru"
    target: str  # the MCOM the bots go for
    destroyed: str | None = None  # the other MCOM of the stage, if destroyed

    def __str__(self) -> str:
        gone = f", {self.destroyed} destroyed" if self.destroyed else ""
        return f"stage {self.stage}, {self.team} for {self.target}{gone}"


@dataclass
class Stuck:
    situation: Situation
    paths: list[int] = field(default_factory=list)


def _mcom(name: str) -> bool:
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


def _special(name: str) -> bool:
    """The way to a vehicle or a beacon: only with one."""
    lower = name.lower()
    return "vehicle" in lower or "beacon" in lower


class Play:
    """The path-switches in one situation."""

    def __init__(self, data: MapData, stage: Stage, situation: Situation):
        self.data = data
        self.stage = stage
        self.situation = situation
        self.target = situation.target

    def destroyed(self, path: PathData) -> bool:
        """GameDirector:IsDestroyedPath"""
        gone = self.situation.destroyed
        objectives = path.objectives
        return gone is not None and len(objectives) == 1 and objectives[0] in (gone, gone + " interact")

    def status(self, path: PathData) -> int:
        if self.destroyed(path) and path.objectives[0].endswith("interact"):
            return -1
        return self.stage.status(path)

    def has_regular_exit(self, path: PathData, on_base: bool) -> bool:
        """PathSwitcher:_HasRegularExit"""
        spawn = on_base and len(path.objectives) == 1
        for node in path.nodes:
            for index, _ in node.links:
                new = self.data.paths.get(index)
                if new is None or new is path or not _walkable(new) or self.status(new) != 2:
                    continue
                objectives = new.objectives
                if len(objectives) == 1 and _special(objectives[0]):
                    continue
                base = any(_team(name) for name in objectives)
                if on_base:
                    if not base or (spawn and len(objectives) > 1):
                        return True
                elif not base and self.target in objectives:
                    return True
        return False

    def at_node(self, current: PathData, node) -> set[int]:
        """Paths a bot on current switches to at this node (PathSwitcher:GetNewPath)."""
        objectives = current.objectives
        status = self.status(current)
        on_base = any(_team(name) for name in objectives)
        priority = _priority(current, self.target)
        if on_base:
            leave = len(objectives) == 1 or node.point in (1, len(current.nodes))
        else:
            leave = self.destroyed(current) or (len(objectives) == 1 and "vehicle" in objectives[0].lower())
        valid: list[tuple[int, int]] = []
        exits: list[tuple[int, int]] = []
        highest = 0
        for index, _ in node.links:
            new = self.data.paths.get(index)
            if new is None or new is current or not _walkable(new):
                continue
            new_objectives = new.objectives
            if len(new_objectives) == 1 and _special(new_objectives[0]):
                continue  # no vehicles, no beacon
            new_status = self.status(new)
            new_base = any(_team(name) for name in new_objectives)
            if leave and not (len(new_objectives) == 1 and (new_base or self.destroyed(new))):
                exits.append((new_status + (3 if self.target in new_objectives else 0), index))
            new_priority = _priority(new, self.target)
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
                valid.append((new_priority, index))
                highest = max(highest, new_priority)
        regular = highest >= 5 or (not on_base and highest > priority)
        if leave and not regular and exits and not self.has_regular_exit(current, on_base):
            best = max(score for score, _ in exits)
            return {index for score, index in exits if score == best}
        if not valid:
            return set()
        if priority < highest:
            return {index for value, index in valid if value == highest}
        return {index for _, index in valid}

    def successors(self) -> dict[int, set[int]]:
        result = {}
        for index, path in self.data.paths.items():
            found = set()
            if _walkable(path):
                for node in path.nodes:
                    if node.links:
                        found |= self.at_node(path, node)
            result[index] = found
        return result

    def can_leave(self, path: PathData) -> bool:
        """GameDirector:CanLeaveBasePath without vehicles: a link to a walkable path with an active objective that
        isn't a base-path alone or the way to a vehicle or a beacon."""
        for node in path.nodes:
            for index, _ in node.links:
                other = self.data.paths.get(index)
                if other is None or other is path or not _walkable(other) or self.stage.status(other) <= 0:
                    continue
                objectives = other.objectives
                if len(objectives) != 1 or not (_team(objectives[0]) or _special(objectives[0])):
                    return True
        return False

    def starts(self) -> list[int]:
        """Where the bots of the team are: the base-paths they spawn on (GameDirector:GetSpawnPath only takes those they
        can leave, e.g. not those that only lead to a vehicle), and the paths of the MCOMs of the stage."""
        found = []
        for index, path in self.data.paths.items():
            objectives = path.objectives
            if len(objectives) != 1 or path.vehicles:
                continue
            name = objectives[0]
            if _team(name) == self.situation.team and self.stage.active.get(name):
                if self.can_leave(path):
                    found.append(index)
            elif _mcom(name) and self.stage.active.get(name):
                found.append(index)
        return found

    def stuck(self) -> list[int]:
        """The paths bots get to, but not from there to their MCOM. Not those without an active objective: bots there
        were killed after a while (GameDirector of the waypoint navigation)."""
        successors = self.successors()
        seen, todo = set(self.starts()), list(self.starts())
        while todo:
            for index in successors[todo.pop()]:
                if index not in seen:
                    seen.add(index)
                    todo.append(index)
        # Backwards from the paths of the target.
        before: dict[int, set[int]] = {}
        for index, after in successors.items():
            for other in after:
                before.setdefault(other, set()).add(index)
        done = {index for index, path in self.data.paths.items()
                if self.target in path.objectives or path.objectives == [self.target + " interact"]}
        todo = list(done)
        while todo:
            for index in before.get(todo.pop(), ()):
                if index not in done:
                    done.add(index)
                    todo.append(index)
        return sorted(index for index in seen - done if self.status(self.data.paths[index]) > 0)


def situations(data: MapData, mode: str) -> list[tuple[Stage, Situation]]:
    if mode not in RUSH_MODES:
        return []
    result = []
    for number in stages(data, mode):
        stage = Stage(data, mode, number)
        mcoms = sorted({name for path in data.paths.values() for name in path.objectives
                        if _mcom(name) and stage.active.get(name)})
        for team in ("us", "ru"):
            for target in mcoms:
                result.append((stage, Situation(number, team, target)))
                for other in mcoms:
                    if other != target:
                        result.append((stage, Situation(number, team, target, other)))
    return result


def check(data: MapData, mode: str) -> list[Stuck]:
    found = []
    for stage, situation in situations(data, mode):
        paths = Play(data, stage, situation).stuck()
        if paths:
            found.append(Stuck(situation, paths))
    return found


def fix(data: MapData, mode: str, options: Options, changes: list[Change]) -> None:
    """Links the paths bots get stuck on to their MCOM, shortest link first (in place). See the module doc."""
    tried: set[tuple[int, str]] = set()
    while True:
        best = None
        stuck = check(data, mode)
        for entry in stuck:
            stage = Stage(data, mode, entry.situation.stage)
            for index in entry.paths:
                if (index, entry.situation.target) in tried:
                    continue
                found = _closest(data, stage, data.paths[index], entry.situation.target, options)
                if found is None:
                    tried.add((index, entry.situation.target))
                elif best is None or found.key < best[0].key:
                    best = (found, entry.situation)
        if best is None:
            break
        found, situation = best
        tried.add((found.own[0], situation.target))  # one link per path and MCOM
        _link(data, found.own, found.target)
        path, other = data.paths[found.own[0]], data.paths[found.target[0]]
        changes.append(Change("link-added", found.own[0], f"{situation}: from [{', '.join(path.objectives) or '-'}] "
                                                          f"over [{', '.join(other.objectives)}], "
                                                          f"{found.distance:.1f} m{found.note(options)}",
                              found.own[1], found.target))
    # What is left, once per path and MCOM.
    reported: dict[tuple[int, str], list[str]] = {}
    for entry in check(data, mode):
        for index in entry.paths:
            reported.setdefault((index, entry.situation.target), []).append(str(entry.situation))
    for (index, target), where in sorted(reported.items()):
        names = ", ".join(data.paths[index].objectives) or "no objectives"
        changes.append(Change("warning", index, f"bots on [{names}] can't get to \"{target}\" ({'; '.join(where)})"))


def _closest(data: MapData, stage: Stage, path: PathData, target: str, options: Options) -> Found | None:
    """The link to the best path to target next to path, or None: the path of the MCOM itself first, then walked paths
    naming it, then paths of the vehicles (see bases.closest_link)."""
    candidates = {index for index, other in data.paths.items() if index != path.index
                  and target in other.objectives and stage.status(other) == 2 and _walkable(other)
                  and not any(_team(name) for name in other.objectives)}

    def rank(other: PathData) -> int:
        return (0 if other.objectives == [target] else 1) + (2 if other.vehicles else 0)

    return closest_link(data, path, candidates, options, rank)
