"""Base-paths bots can't leave.

Bots spawn on the paths that carry a single base objective ("base us", "base ru 2") and no "Vehicles"
(GameDirector:GetSpawnPath). They have to leave them: at a junction of a base-path PathSwitcher:GetNewPath always takes
(priority 5) a walkable path whose objectives are all active and that isn't a path of a base alone. Paths that are
partly or not active (an MCOM of another rush stage, no objectives at all), other base-paths and the paths to a vehicle
don't get a bot out: it stays on the base-path for its whole life.

The paths out of a base ("base us 1, mcom 2") are the same: a bot on them never switches onto another path with a base,
it needs a junction to an active path without a base, best the objective the path leads to ("mcom 2").

PathSwitcher:GetNewPath also makes a bot leave a base-path onto any other walkable path if there is no such way out, but
then it may walk anywhere. So the paths are fixed:
  1. relabel (rush): a path out of a base ("base us 2, mcom 2") that names an MCOM of another stage is only partly
     active in the stage of its base. The MCOM is replaced by the MCOM of that stage closest to an end of the path
     (within relabel_radius), or dropped if the path already names that one.
  2. Rush: the paths of an MCOM are linked to the other MCOM of their stage (mcoms.py).
  3. For every path out of a base (in rush: in the stage of its base) without a way out:
     - relink: link it to the closest node of a path with one of its other objectives (within link_radius), else of
       any way out,
     - else it's reported.
  4. For every base-path that is spawned on (in rush: in the stage of its base) and still has no way out:
     - relink: link it to the closest node of a path that is a way out (own or no base) within link_radius,
     - remove: a base-path without any links and nothing in reach is of no use, it's deleted (if its base has
       other paths to spawn on),
     - else it's reported (e.g. a base-path that only leads to vehicles, with no way out in reach).
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from .labeler import Change, Labeler, Result, _Grid
from .mapfile import MapData, PathData

RUSH_MODES = ("RushLarge0", "SquadRush0")


@dataclass
class Options:
    link_radius: float = 20.0  # distance from a node of the base-path to the node of a way out it's linked to
    max_height: float = 2.5  # height difference of the two linked nodes (else another floor)
    remove: bool = True  # delete base-paths without links and without a way out in reach
    relabel_radius: float = 80.0  # end of a path out of a base to the MCOM of the stage that replaces another one


@dataclass
class DeadEnd:
    stage: int
    path: int
    reason: str
    kind: str = "spawn"  # spawn: a base-path bots spawn on, connection: a path out of a base


def uses_bases(mode: str) -> bool:
    """Game modes in which bots spawn on base-paths (GameDirector objectives: Globals.IsConquest / IsRush)."""
    return any(part in mode for part in ("Conquest", "TankSuperiority", "CaptureTheFlag", "BFLAG", "AirSuperiority",
                                         "Rush"))


def _number(text: str) -> int | None:
    try:
        return int(text)
    except ValueError:
        return None


def _team(name: str) -> str | None:
    """Team of a base: "us" (Team1) or "ru", as GameDirector:_InitObjectives tells it."""
    lower = name.lower()
    if "base" not in lower:
        return None
    return "us" if "us" in lower else "ru"


class Stage:
    """The objectives of the GameDirector in one stage (rush), or the whole round (other modes)."""

    def __init__(self, data: MapData, mode: str, stage: int = 1):
        self.data = data
        self.mode = mode
        self.stage = stage
        self.active: dict[str, bool] = {}
        for path in data.paths.values():
            for name in path.objectives:
                self.active.setdefault(name, self._active(name))

    def _active(self, name: str) -> bool:
        lower = name.lower()
        if any(word in lower for word in ("spawn", "beacon", "explore", "vehicle")):
            return False
        if self.mode not in RUSH_MODES:
            return True
        # GameDirector:_UpdateValidObjectives
        fields = name.split(" ")
        if "base" in lower:
            return len(fields) > 2 and _number(fields[2]) == self.stage
        if self.mode == "SquadRush0":
            mcoms = (self.stage,)
        else:
            mcoms = (self.stage * 2 - 1, self.stage * 2)
        return len(fields) > 1 and _number(fields[1]) in mcoms

    def status(self, path: PathData) -> int:
        """GameDirector:GetEnableStateOfPath: 0 none, 1 some, 2 all objectives active."""
        objectives = path.objectives
        count = sum(1 for name in objectives if self.active.get(name))
        if count == 0:
            return 0
        return 1 if count < len(objectives) else 2

    def spawn_bases(self) -> list[PathData]:
        """The base-paths bots spawn on."""
        return [path for path in self.data.paths.values() if len(path.objectives) == 1 and not path.vehicles
                and _team(path.objectives[0]) and self.active.get(path.objectives[0])]

    def connections(self) -> list[PathData]:
        """The paths out of an active base: a base and other objectives, walked (no vehicles)."""
        return [path for path in self.data.paths.values() if len(path.objectives) > 1 and not path.vehicles
                and any(_team(name) and self.active.get(name) for name in path.objectives)
                and not any("vehicle" in name.lower() for name in path.objectives)]

    def way_out(self, path: PathData, team: str | None = None, connection: bool = False) -> bool:
        """Whether a bot on a base-path (with connection: on a path out of a base) always switches to this path
        (PathSwitcher:GetNewPath, priority 5). With team: not through the base of the other team."""
        objectives = path.objectives
        if not path.nodes or "air" in path.vehicles or Labeler._driven(path):
            return False
        if self.status(path) != 2:
            return False
        if connection:
            return not any(_team(name) for name in objectives)  # never onto another path with a base
        if len(objectives) == 1 and _team(objectives[0]):
            return False  # another base-path
        return team is None or all(_team(name) in (None, team) for name in objectives)


def stages(data: MapData, mode: str) -> list[int]:
    if mode not in RUSH_MODES:
        return [1]
    highest = 1
    for path in data.paths.values():
        for name in path.objectives:
            fields = name.lower().split(" ")
            if fields[0] == "base" and len(fields) > 2 and _number(fields[2]):
                highest = max(highest, _number(fields[2]))
    return list(range(1, highest + 1))


def _describe(data: MapData, stage: Stage, path: PathData, connection: bool = False) -> str:
    targets = sorted({target[0] for node in path.nodes for target in node.links})
    if not targets:
        return "no links"
    parts = []
    for index in targets:
        other = data.paths.get(index)
        if other is None:
            parts.append(f"{index} (missing)")
            continue
        names = ", ".join(other.objectives) or "no objectives"
        if any("vehicle" in name.lower() for name in other.objectives):
            why = "to a vehicle"
        elif any(_team(name) for name in other.objectives) and (connection or len(other.objectives) == 1):
            why = "base-path"
        elif "air" in other.vehicles or Labeler._driven(other):
            why = "vehicles only"
        else:
            why = ("not active", "partly active", "active")[stage.status(other)]
        parts.append(f"{index} [{names}] {why}")
    return "only links to " + "; ".join(parts)


def check(data: MapData, mode: str) -> list[DeadEnd]:
    """The base-paths and paths out of a base bots can't leave, per stage. The paths out of a base first."""
    if not uses_bases(mode):
        return []
    found = []
    for number in stages(data, mode):
        stage = Stage(data, mode, number)
        for path in stage.connections():
            if not any(stage.way_out(data.paths[target[0]], connection=True) for node in path.nodes
                       for target in node.links if target[0] in data.paths):
                found.append(DeadEnd(number, path.index, _describe(data, stage, path, True), "connection"))
    for number in stages(data, mode):
        stage = Stage(data, mode, number)
        for path in stage.spawn_bases():
            if not any(stage.way_out(data.paths[target[0]]) for node in path.nodes for target in node.links
                       if target[0] in data.paths):
                found.append(DeadEnd(number, path.index, _describe(data, stage, path)))
    return found


def fix(data: MapData, mode: str, options: Options | None = None) -> Result:
    """Relinks or removes the base-paths bots can't leave (in place), reports the rest. See the module doc."""
    options = options or Options()
    changes: list[Change] = []
    if mode in RUSH_MODES:
        _relabel(data, mode, options, changes)
        from .mcoms import fix as fix_mcoms  # mcoms uses this module
        fix_mcoms(data, mode, options, changes)
    for dead in check(data, mode):
        path = data.paths.get(dead.path)
        if path is None:
            continue
        stage = Stage(data, mode, dead.stage)
        where = f"stage {dead.stage}: " if mode in RUSH_MODES else ""
        connection = dead.kind == "connection"
        if connection and _has_way_out(data, stage, path):
            continue  # got one with a link made for another path
        found = _closest_way_out(data, stage, path, options, connection)
        name = f"[{', '.join(path.objectives)}]" if connection else f"\"{path.objectives[0]}\""
        if found is not None:
            distance, own, target = found
            _link(data, own, target)
            other = data.paths[target[0]]
            changes.append(Change("link-added", path.index, f"{where}way out of {name} to "
                                                            f"[{', '.join(other.objectives)}], {distance:.1f} m",
                                  own[1], target))
        elif connection:
            changes.append(Change("warning", path.index, f"{where}bots can't leave {name}: {dead.reason}, no way out "
                                                         f"within {options.link_radius:.0f} m"))
        elif options.remove and not any(node.links for node in path.nodes) and _other_spawn(data, path):
            _remove(data, path.index)
            changes.append(Change("removed", path.index, f"{where}\"{path.objectives[0]}\" without links and no way "
                                                         f"out within {options.link_radius:.0f} m"))
        else:
            changes.append(Change("warning", path.index, f"{where}bots can't leave \"{path.objectives[0]}\": "
                                                         f"{dead.reason}, no way out within "
                                                         f"{options.link_radius:.0f} m"))
    return Result(data, [], changes)


def _mcom_index(name: str) -> int | None:
    """N of "mcom N" (not of "mcom N interact")."""
    fields = name.lower().split(" ")
    return _number(fields[1]) if len(fields) == 2 and fields[0] == "mcom" else None


def _relabel(data: MapData, mode: str, options: Options, changes: list[Change]) -> None:
    """Paths out of a rush base that name an MCOM of another stage get the closest MCOM of the stage of their base."""
    # Position of an MCOM: the middle of the paths that carry it alone.
    points: dict[str, list] = {}
    for path in data.paths.values():
        if len(path.objectives) == 1 and _mcom_index(path.objectives[0]) is not None:
            points.setdefault(path.objectives[0], []).extend(node.pos for node in path.nodes)
    mcoms = {name: tuple(sum(pos[i] for pos in positions) / len(positions) for i in range(3))
             for name, positions in points.items()}

    for path in data.paths.values():
        objectives = path.objectives
        bases = [name for name in objectives if _team(name)]
        if len(bases) != 1 or len(objectives) < 2 or path.vehicles:
            continue
        fields = bases[0].split(" ")
        if len(fields) < 3 or _number(fields[2]) is None:
            continue
        stage = Stage(data, mode, _number(fields[2]))
        stale = [name for name in objectives if _mcom_index(name) is not None and not stage.active.get(name)]
        if not stale:
            continue
        candidates = [(math.dist(end.pos, pos), name) for name, pos in mcoms.items() if stage.active.get(name)
                      for end in (path.nodes[0], path.nodes[-1])]
        if not candidates:
            continue
        distance, closest = min(candidates)
        if distance > options.relabel_radius:
            changes.append(Change("warning", path.index, f"names {', '.join(stale)} of another stage than "
                                                         f"\"{bases[0]}\", no MCOM of its stage within "
                                                         f"{options.relabel_radius:.0f} m"))
            continue
        new = sorted({name for name in objectives if name not in stale} | {closest})
        path.objectives = new
        changes.append(Change("objectives", path.index, f"{', '.join(new)} (was {', '.join(objectives)}: "
                                                        f"{', '.join(stale)} isn't active in the stage of "
                                                        f"\"{bases[0]}\", the path ends {distance:.0f} m from "
                                                        f"{closest})"))


def _has_way_out(data: MapData, stage: Stage, path: PathData) -> bool:
    return any(stage.way_out(data.paths[target[0]], connection=True) for node in path.nodes for target in node.links
               if target[0] in data.paths)


def _closest_way_out(data: MapData, stage: Stage, path: PathData, options: Options, connection: bool = False):
    """(distance, own node, node of the way out) closest to the path, or None. A path out of a base goes to its
    objective: the path of that objective first, then paths to it, then any (see _preference)."""
    team = next((_team(name) for name in path.objectives if _team(name)), None)
    exits = {index for index, other in data.paths.items()
             if index != path.index and stage.way_out(other, team, connection)}
    own_objectives = {name for name in path.objectives if not _team(name)} if connection else set()
    grid = _Grid(4.0)
    for index in exits:
        for node in data.paths[index].nodes:
            grid.add(index, node.point, node.pos)
    best = None
    for node in path.nodes:
        for index, point, distance in grid.near(node.pos, options.link_radius):
            if abs(data.node(index, point).pos[1] - node.pos[1]) > options.max_height:
                continue
            rank = (_preference(data.paths[index], own_objectives), distance)
            if best is None or rank < best[0]:
                best = (rank, (path.index, node.point), (index, point))
    return None if best is None else (best[0][1], best[1], best[2])


def _preference(other: PathData, objectives: set[str]) -> int:
    """Lower is better: the path of one of the objectives itself, a path to one of them, any path. Walked paths before
    the ones of the vehicles."""
    if len(other.objectives) == 1 and other.objectives[0] in objectives:
        rank = 0
    elif objectives & set(other.objectives):
        rank = 1
    else:
        rank = 2
    return rank + (3 if other.vehicles else 0)


def _other_spawn(data: MapData, path: PathData) -> bool:
    """Whether the base keeps another path to spawn on without this one."""
    return any(other is not path and other.objectives == path.objectives and not other.vehicles
               for other in data.paths.values())


def _link(data: MapData, a: tuple[int, int], b: tuple[int, int]) -> None:
    """Link on both nodes, as the mod keeps them."""
    for source, target in ((a, b), (b, a)):
        node = data.node(*source)
        if target not in node.links:
            node.set_links(sorted(set(node.links) | {target}))


def _remove(data: MapData, index: int) -> None:
    """Deletes a path and the links to it. The other paths keep their numbers (the mod allows gaps)."""
    del data.paths[index]
    for path in data.paths.values():
        for node in path.nodes:
            if any(target[0] == index for target in node.links):
                node.set_links([target for target in node.links if target[0] != index])

