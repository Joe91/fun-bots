"""Labels and links the paths of a level automatically.

What the bots need from the paths (GameDirector.lua, PathSwitcher.lua, NodeCollection.lua):
  - The first node of a path names its objectives. One objective: the path belongs to that objective ("a",
    "base us"), the bots defend, capture and spawn on it. Two or more: the path connects these objectives.
  - Links are junctions. At a node with links a bot may switch to the linked node of another path, it walks
    there straight. The mod keeps links on both nodes.
  - The option of the first node: 0xFF walks the path back and forth, anything else loops it. A looping bot walks
    from the last node straight to the first one.

The objectives come as anchors: the positions of the capture points and HQs of the running game (debug-server), or,
offline, the middle of the paths that already carry a single objective. Then:
  1. Objective paths: a path that stays in the area of one objective gets that objective.
  2. Connection paths: every end of a path is attached to the objective whose area or objective path it ends at. The
     path gets the objectives of both ends. An end at another connection path takes over its objectives. A base only
     belongs to the paths directly at it, it's removed from the others (bots leave a base path at every junction).
  3. Loop: a closed path loops, an open one (big gap between the ends) is walked back and forth.
  4. Links: the end of a path at an objective is linked to that objective path (even a bit further away), other
     ends to the closest path next to them. An end still without junction follows its trajectory to the first path it
     crosses, else it joins the closest path a bit further away. Optionally paths are linked where they cross. Links
     that point nowhere are removed, one-sided ones completed.

Paths with other objectives ("vehicle tank1 us", "spawn a", "mcom 1", "beacon", ...) keep them, they are only linked.
Paths with "Vehicles" belong to the vehicle network and keep their objectives. They are only linked with vehicles=True
(land paths among each other), unless they are walkable as well (recorded on foot): a loop around one flag, or a path
between flags. Soldiers never switch onto a path with "Vehicles" and no objectives (out of a base) or a closed loop
through several objectives (around the map), so links between those and foot paths are removed. Vehicle paths out of a
base (or away from a vehicle spawn) are always linked at their far end to the next vehicle path, vehicles have to get
out. Air paths are never touched.
"""

from __future__ import annotations

import math
import re
from collections import defaultdict
from dataclasses import asdict, dataclass, field

from .mapfile import MapData, PathData

# Objectives the labeler owns: capture points "a".."z" and the conquest bases. Everything else is kept.
FLAG_NAME = re.compile(r"^([a-z]|base (us|ru))$")
# Paths with more distance between their nodes are most likely recorded in a vehicle (foot paths: 99.8 % below 5 m).
VEHICLE_STEP = 5.0
# Node distance up to which a path with "Vehicles" was recorded on foot (foot paths: median 1.7 m, vehicles 3.7 m).
FOOT_STEP = 2.5
# Metres around the vehicle end of a path to a vehicle (its spawn) in which a vehicle path end needs no junction.
SPAWN_RADIUS = 10.0
# Paths with a vehicle-objective ("vehicle tank1 us") up to this length lead to the vehicle, longer ones are driven.
ENTER_PATH_NODES = 100
# Ends of a loop of the vehicles through several objectives at most this far apart (or 5 % of its length). The loop
# flag of the hand-made paths isn't reliable. Same in PathSwitcher:IsWalkable.
DRIVEN_LOOP_GAP = 15.0
# Longest distance between two nodes that is searched for crossings.
MAX_SEGMENT = 6.0
# Metres of a path its end direction is taken from (for the trajectory of the end).
END_DIRECTION = 5.0


@dataclass
class Anchor:
    name: str
    pos: tuple[float, float, float]
    source: str = "game"  # "game" (capture point of the running level) or "labels" (middle of labeled paths)
    radius: float = 0.0  # of the area, set by the labeler

    @property
    def is_base(self) -> bool:
        return self.name.startswith("base")


@dataclass
class Options:
    relabel: bool = False  # recompute the objectives of paths that already have capture point / base objectives
    relink: bool = False  # drop all links between the processed paths and link them anew
    vehicles: bool = False  # also link land vehicle paths among each other
    flag_radius: float = 50.0  # area of a capture point at most (else half the distance to the next objective)
    base_radius: float = 80.0  # area of a base (HQ) at most
    inside: float = 0.8  # share of the nodes in the area that makes a path an objective path
    attach_radius: float = 15.0  # end of a path to a node of the objective path it belongs to
    end_radius: float = 5.0  # end of a path to a node of any other path
    extend_radius: float = 30.0  # an end without junction follows its trajectory this far for a path to cross
    crossings: bool = False  # also link paths where they cross
    cross_angle: float = 30.0  # smallest angle of a crossing (paths along the same way weave across each other)
    touch_radius: float = 0.5  # nodes of two paths that touch
    cross_height: float = 2.0  # height difference of two paths that cross (else one runs over the other)
    link_spacing: int = 8  # nodes along both paths in which only one link between them is made
    objectives: bool = True  # the game mode uses objectives (conquest, rush), see uses_objectives()
    loops: bool = True  # set loop / back and forth
    loop_closed: float = 3.0  # gap between the ends of a closed path (at least 1.5 * node distance)
    loop_open: float = 15.0  # gap from which a path is walked back and forth


@dataclass
class Change:
    kind: str  # objectives | loop | link-added | link-removed | warning
    path: int
    message: str
    point: int | None = None
    target: tuple[int, int] | None = None


@dataclass
class Result:
    data: MapData
    anchors: list[Anchor]
    changes: list[Change] = field(default_factory=list)

    def counts(self) -> dict[str, int]:
        counts: dict[str, int] = defaultdict(int)
        for change in self.changes:
            counts[change.kind] += 1
        return dict(counts)

    def to_json(self) -> dict:
        """For the web-interface: what changed, plus labels, loop and links of every path afterwards."""
        paths = {}
        for index, path in self.data.paths.items():
            links = [[node.point, target[0], target[1]] for node in path.nodes for target in node.links]
            paths[index] = {"objectives": path.objectives, "vehicles": path.vehicles, "loop": path.loops,
                            "links": links}
        return {
            "anchors": [asdict(anchor) for anchor in self.anchors],
            "changes": [asdict(change) for change in self.changes],
            "counts": self.counts(),
            "paths": paths,
        }


def uses_objectives(mode: str) -> bool:
    """Whether the bots play objectives in this game mode (Globals.IsConquest / IsRush in ext/Server/__init__.lua)."""
    return any(part in mode for part in ("Conquest", "TankSuperiority", "CaptureTheFlag", "BFLAG", "AirSuperiority",
                                         "Rush"))


# --- anchors -------------------------------------------------------------------------------------------------------


def anchors_from_flags(flags: list[dict]) -> list[Anchor]:
    """Capture points of the debug-snapshot (DebugSnapshots.CollectObjectives): "ID_H_US_A" is "a", the HQs are the
    bases (team 1 "base us", team 2 "base ru")."""
    anchors = []
    for flag in flags:
        pos = flag.get("pos")
        name = str(flag.get("name") or "")
        if not pos or len(pos) < 3:
            continue
        if flag.get("hq") or name.endswith("HQ"):
            team = flag.get("team")
            if team not in (1, 2):
                continue
            label = "base us" if team == 1 else "base ru"
        else:
            label = name.rsplit("_", 1)[-1].lower()
            if not re.fullmatch(r"[a-z]", label):
                continue
        anchors.append(Anchor(label, (float(pos[0]), float(pos[1]), float(pos[2]))))
    return anchors


def anchors_from_labels(data: MapData) -> list[Anchor]:
    """Middle of all paths that carry exactly one capture point / base objective (not in the air)."""
    points: dict[str, list] = defaultdict(list)
    for path in data.paths.values():
        objectives = path.objectives
        if len(objectives) == 1 and FLAG_NAME.match(objectives[0]) and "air" not in path.vehicles:
            points[objectives[0]].extend(node.pos for node in path.nodes)
    return [Anchor(name, tuple(sum(pos[i] for pos in positions) / len(positions) for i in range(3)), "labels")
            for name, positions in sorted(points.items())]


def merge_anchors(game: list[Anchor], labels: list[Anchor]) -> list[Anchor]:
    """The anchors of the game, completed by those from labels the game doesn't have (e.g. no HQ-entities)."""
    names = {anchor.name for anchor in game}
    return game + [anchor for anchor in labels if anchor.name not in names]


# --- geometry ------------------------------------------------------------------------------------------------------


def _dist2d(a, b) -> float:
    return math.hypot(a[0] - b[0], a[2] - b[2])


class _Grid:
    """Nodes in square cells, for "all nodes within r"."""

    def __init__(self, cell: float):
        self.cell = cell
        self.cells: dict[tuple[int, int], list[tuple[int, int, tuple]]] = defaultdict(list)

    def add(self, path: int, point: int, pos) -> None:
        self.cells[(math.floor(pos[0] / self.cell), math.floor(pos[2] / self.cell))].append((path, point, pos))

    def near(self, pos, radius: float):
        reach = math.ceil(radius / self.cell)
        cx, cz = math.floor(pos[0] / self.cell), math.floor(pos[2] / self.cell)
        for dx in range(-reach, reach + 1):
            for dz in range(-reach, reach + 1):
                for path, point, other in self.cells.get((cx + dx, cz + dz), ()):
                    distance = math.dist(pos, other)
                    if distance <= radius:
                        yield path, point, distance


# --- the labeler ---------------------------------------------------------------------------------------------------


class Labeler:
    def __init__(self, data: MapData, anchors: list[Anchor], options: Options | None = None):
        self.data = data
        self.anchors = anchors
        self.options = options or Options()
        self.changes: list[Change] = []
        self.kinds: dict[int, str] = {index: self._kind(path) for index, path in data.paths.items()}
        self._areas()
        # Where vehicles spawn: the ends of the paths to a vehicle.
        self.spawns = [node.pos for path in data.paths.values() if any("vehicle" in name for name in path.objectives)
                       for node in (path.nodes[0], path.nodes[-1])]
        # Vehicle paths out of a base (or away from a vehicle spawn): path -> the end at the base.
        self.exits: dict[int, object] = {}
        for index, path in data.paths.items():
            if self.kinds[index] == "vehicle" and len(path.nodes) > 1:
                at_base = [end for end in (path.nodes[0], path.nodes[-1]) if self._at_base(end.pos)]
                if len(at_base) == 1:
                    self.exits[index] = at_base[0]
        self.grid = _Grid(4.0)
        for index, path in data.paths.items():
            for node in path.nodes:
                self.grid.add(index, node.point, node.pos)

    def _nearest(self, pos, radius: float, paths) -> dict[int, tuple[float, int]]:
        """Closest node (distance, point) of each of the paths within radius."""
        closest: dict[int, tuple[float, int]] = {}
        for index, point, distance in self.grid.near(pos, radius):
            if index in paths and (index not in closest or distance < closest[index][0]):
                closest[index] = (distance, point)
        return closest

    def run(self) -> Result:
        self._label()
        self._loops()
        self._links()
        self._check()
        return Result(self.data, self.anchors, self.changes)

    # --- classes of paths ----------------------------------------------------------------------------------------

    def _kind(self, path: PathData) -> str:
        """foot: labeled by us. special: keeps its objectives, but is linked. shared: a walkable path for vehicles too,
        keeps its objectives. vehicle (only linked with options.vehicles) / air: untouched."""
        objectives = path.objectives
        vehicles = path.vehicles
        if "air" in vehicles:
            return "air"
        if any("vehicle" in name.lower() for name in objectives):
            # Short: walked to the vehicle. Long: driven with it.
            return "vehicle" if len(path.nodes) > ENTER_PATH_NODES else "special"
        if vehicles:
            # Part of the vehicle network. Walkable as well if recorded on foot: a loop around one flag, or a path
            # between flags. Never a path soldiers don't use (_driven).
            return "shared" if objectives and path.step <= FOOT_STEP and not self._driven(path) else "vehicle"
        if any(not FLAG_NAME.match(name) for name in objectives):
            return "special"
        if len(path.nodes) > 2 and path.step > VEHICLE_STEP and not objectives:
            return "vehicle?"
        return "foot"

    def _linkable(self, index: int) -> bool:
        kind = self.kinds[index]
        # Vehicles always have to get out of their base, the rest of the vehicle network only with options.vehicles.
        return kind in ("foot", "special", "shared") or index in self.exits or (kind == "vehicle"
                                                                               and self.options.vehicles)

    def _classes(self, index: int) -> set[str]:
        """The networks a path is part of: bots on foot, land or water vehicles."""
        kind = self.kinds[index]
        if kind in ("foot", "special"):
            return {"foot"}
        vehicles = self.data.paths[index].vehicles
        terrains = {"water"} if vehicles == ["water"] else {"land", "water"} if "water" in vehicles else {"land"}
        return terrains | ({"foot"} if kind == "shared" else set())

    def _at_base(self, pos) -> bool:
        """In the area of a base, or at a vehicle spawn."""
        return (self._area(pos) or "").startswith("base") or any(math.dist(pos, spawn) <= SPAWN_RADIUS
                                                                 for spawn in self.spawns)

    def _targets(self, index: int, linkable: set[int]) -> set[int]:
        """Paths an end of this one may be linked to. The far end of a base exit: any path of its terrain, labeled or
        not (another base exit only outside of the base, see _outside)."""
        if index in self.exits:
            return {other for other in self.data.paths if other != index and self.kinds[other] != "air"
                    and self._compatible(index, other)}
        return {other for other in linkable if other != index and self._compatible(index, other)}

    def _on_foot(self, index: int) -> bool:
        """Soldiers walk it, and it isn't the way to a vehicle."""
        path = self.data.paths[index]
        return not path.vehicles and not any("vehicle" in name.lower() for name in path.objectives)

    @staticmethod
    def _driven(path: PathData) -> bool:
        """Only vehicles use it (PathSwitcher:IsWalkable): "Vehicles" and no objectives (out of a base), or a closed
        loop through several objectives (around the map). Air paths too, but those are left alone."""
        if not path.vehicles or "air" in path.vehicles or len(path.objectives) == 1:
            return False
        if not path.objectives:
            return True
        length = sum(math.dist(a.pos, b.pos) for a, b in zip(path.nodes, path.nodes[1:]))
        return math.dist(path.nodes[0].pos, path.nodes[-1].pos) <= max(DRIVEN_LOOP_GAP, 0.05 * length)

    def _outside(self, index: int, found: dict[int, tuple[float, int]]) -> dict[int, tuple[float, int]]:
        """For the far end of a base exit: drop the nodes of other base exits that lie in a base."""
        if index not in self.exits:
            return found
        return {other: (distance, point) for other, (distance, point) in found.items()
                if other not in self.exits or not self._at_base(self.data.node(other, point).pos)}

    def _compatible(self, index: int, other: int) -> bool:
        return bool(self._classes(index) & self._classes(other))

    # --- 1 + 2: objectives ---------------------------------------------------------------------------------------

    def _areas(self) -> None:
        """Area of each objective: up to half the distance to the closest other objective, so they don't overlap."""
        self.radius: dict[str, float] = {}
        for anchor in self.anchors:
            limit = self.options.base_radius if anchor.is_base else self.options.flag_radius
            others = [_dist2d(anchor.pos, other.pos) for other in self.anchors if other.name != anchor.name]
            anchor.radius = round(min([limit] + [distance / 2 for distance in others]), 1)
            self.radius[anchor.name] = anchor.radius

    def _area(self, pos) -> str | None:
        """The objective in whose area pos lies."""
        best, best_distance = None, math.inf
        for anchor in self.anchors:
            distance = _dist2d(pos, anchor.pos)
            if distance <= self.radius[anchor.name] and distance < best_distance:
                best, best_distance = anchor.name, distance
        return best

    def _label(self) -> None:
        if not self.options.objectives:
            return
        paths = self.data.paths
        todo = [index for index, kind in self.kinds.items() if kind == "foot"
                and (self.options.relabel or not paths[index].objectives)]
        if not self.anchors:
            if todo:
                self.changes.append(Change("warning", 0, f"{len(todo)} paths not labeled: no objectives known (the "
                                                         f"capture points of the game, or paths that carry one "
                                                         f"objective)"))
            return
        for index, kind in self.kinds.items():
            if kind == "vehicle?" and not paths[index].objectives:
                self.changes.append(Change("warning", index, f"not labeled: looks like a vehicle path (nodes "
                                                             f"{paths[index].step:.1f} m apart), add \"Vehicles\" "
                                                             f"by hand"))

        self._bases(todo)

        # Objective paths first, the ends of the connection paths are attached to them.
        labels: dict[int, list[str]] = {}
        objective_paths: dict[str, list[int]] = defaultdict(list)
        for index, path in paths.items():
            if index not in todo and self.kinds[index] in ("foot", "shared") and len(path.objectives) == 1:
                objective_paths[path.objectives[0]].append(index)
        for index in todo:
            name = self._objective_of(paths[index])
            if name is not None:
                labels[index] = [name]
                objective_paths[name].append(index)

        # Connection paths: the objectives at both ends.
        open_ends: dict[int, list] = {}
        for index in todo:
            if index in labels:
                continue
            path = paths[index]
            found = set()
            for node in (path.nodes[0], path.nodes[-1]):
                name = self._attached(node.pos, index, objective_paths)
                if name is None:
                    open_ends.setdefault(index, []).append(node)
                else:
                    found.add(name)
            if found:
                labels[index] = sorted(found)
        # An end at no objective: a junction leads to the objectives of the connection path it ends at (only the
        # ones found above, chains would make every path lead everywhere). Without a junction the end leads to the
        # closest other objective.
        known = {index: objectives for index, objectives in labels.items() if index not in open_ends}
        for index, nodes in open_ends.items():
            found = set(labels.get(index, []))
            for node in nodes:
                inherited = self._inherited(node.pos, index, known)
                if not inherited or len(found | inherited) < 2:
                    # Nothing to take over, or only the objective of the other end (a base isn't taken over).
                    inherited |= self._closest_other(node.pos, found | inherited)
                found |= inherited
            if found:
                labels[index] = sorted(found)

        for index in todo:
            path = paths[index]
            new = labels.get(index, [])
            if not new:
                self.changes.append(Change("warning", index, "not labeled: no objective at the ends of the path"))
                continue
            if new != sorted(path.objectives):
                was = f" (was {', '.join(path.objectives)})" if path.objectives else ""
                self.changes.append(Change("objectives", index, ", ".join(new) + was))
                path.objectives = new

    def _bases(self, todo: list[int]) -> None:
        """A base objective belongs only to the paths directly at the base: bots on a base path leave it at every
        junction and never switch onto it from elsewhere (PathSwitcher.lua). Removed from the other paths, if they
        still connect two capture points (their other objectives and the areas they pass), else a warning. Only for
        the bases of the running game: offline the position of a base is a guess."""
        bases = {anchor.name: anchor for anchor in self.anchors if anchor.is_base and anchor.source == "game"}
        for index, path in self.data.paths.items():
            if index in todo or self.kinds[index] == "air" or len(path.objectives) < 2:
                continue
            if not all(FLAG_NAME.match(name) for name in path.objectives):
                continue
            away = [name for name in path.objectives if name in bases and not self._at_base_path(index, bases[name])]
            if not away:
                continue
            passed = {area for area in (self._area(node.pos) for node in path.nodes)
                      if area is not None and not self._is_base(area)}
            new = sorted({name for name in path.objectives if name not in away} | passed)
            names = ", ".join(f"\"{name}\"" for name in away)
            if len([name for name in new if not self._is_base(name)]) < 2:
                self.changes.append(Change("warning", index, f"{names} although the path doesn't start at the base: "
                                                             f"bots never switch onto it"))
                continue
            self.changes.append(Change("objectives", index, f"{', '.join(new)} (was {', '.join(path.objectives)}: "
                                                            f"doesn't start at the base)"))
            path.objectives = new

    @staticmethod
    def _is_base(name: str) -> bool:
        return name.startswith("base")

    def _near_base(self, pos, name: str) -> bool:
        """At the base: within base_radius of it (its area may be smaller, if a capture point is close)."""
        return any(anchor.name == name and _dist2d(pos, anchor.pos) <= self.options.base_radius
                   for anchor in self.anchors)

    def _at_base_path(self, index: int, base: Anchor) -> bool:
        """Whether the path comes to the base (its area plus attach_radius, at least base_radius), or is linked to a
        path of the base alone, or ends at one."""
        path = self.data.paths[index]
        radius = max(base.radius + self.options.attach_radius, self.options.base_radius)
        if any(_dist2d(node.pos, base.pos) <= radius for node in path.nodes):
            return True
        base_paths = {other for other, data in self.data.paths.items() if other != index
                      and data.objectives == [base.name]}
        if any(target[0] in base_paths for node in path.nodes for target in node.links):
            return True
        return any(self._nearest(end.pos, self.options.attach_radius, base_paths)
                   for end in (path.nodes[0], path.nodes[-1]))

    def _objective_of(self, path: PathData) -> str | None:
        """The objective whose area the path (mostly) doesn't leave, or which it starts and ends at (a loop)."""
        areas = [self._area(node.pos) for node in path.nodes]
        counts: dict[str, int] = defaultdict(int)
        for name in areas:
            if name is not None:
                counts[name] += 1
        if not counts:
            return None
        name = max(counts, key=lambda key: counts[key])
        share = counts[name] / len(areas)
        if share >= self.options.inside:
            return name
        if areas[0] == areas[-1] == name and share >= 0.5:
            return name
        return None

    def _attached(self, pos, own: int, objective_paths: dict[str, list[int]]) -> str | None:
        """Objective an end of a path belongs to: its area, else the closest objective path within attach_radius."""
        name = self._area(pos)
        if name is not None:
            return name
        owner = {index: name for name, indices in objective_paths.items() for index in indices if index != own}
        closest = self._nearest(pos, self.options.attach_radius, owner)
        return owner[min(closest, key=lambda index: closest[index])] if closest else None

    def _inherited(self, pos, own: int, known: dict[int, list[str]]) -> set[str]:
        """Objectives of the closest connection path within end_radius, a base only if the end is at it."""
        connections = {index: known.get(index) or path.objectives for index, path in self.data.paths.items()
                       if index != own and self.kinds[index] in ("foot", "shared")}
        connections = {index: objectives for index, objectives in connections.items() if len(objectives) > 1}
        closest = self._nearest(pos, self.options.end_radius, connections)
        if not closest:
            return set()
        return {name for name in connections[min(closest, key=lambda index: closest[index])]
                if not self._is_base(name) or self._near_base(pos, name)}

    def _closest_other(self, pos, found: set[str]) -> set[str]:
        """The closest other objective, a base only if the end is at it."""
        others = [anchor for anchor in self.anchors if anchor.name not in found
                  and (not anchor.is_base or self._near_base(pos, anchor.name))]
        return {min(others, key=lambda anchor: _dist2d(pos, anchor.pos)).name} if others else set()

    # --- 3: loop -------------------------------------------------------------------------------------------------

    def _loops(self) -> None:
        if not self.options.loops:
            return
        for index, path in self.data.paths.items():
            kind = self.kinds[index]
            if kind in ("air", "vehicle?") or len(path.nodes) < 3 or (kind == "vehicle" and not self.options.vehicles
                                                                       and index not in self.exits):
                continue
            gap = path.gap
            if gap <= max(self.options.loop_closed, 1.5 * path.step):
                loops = True
            elif gap > self.options.loop_open:
                loops = False
            else:
                continue
            if loops != path.loops:
                path.loops = loops
                how = "loops (ends meet)" if loops else f"back and forth (ends {gap:.0f} m apart)"
                self.changes.append(Change("loop", index, how))

    # --- 4: links ------------------------------------------------------------------------------------------------

    def _links(self) -> None:
        options = self.options
        data = self.data
        linkable = {index for index in data.paths if self._linkable(index)}

        # Links as unordered node pairs. The mod keeps each link on both nodes, "directed" is what the file has.
        links: set[tuple[tuple[int, int], tuple[int, int]]] = set()
        directed: set[tuple[tuple[int, int], tuple[int, int]]] = set()
        dropped: set[tuple[tuple[int, int], tuple[int, int]]] = set()
        unused: set[tuple[tuple[int, int], tuple[int, int]]] = set()  # between foot paths and the vehicle network
        for index, path in data.paths.items():
            for node in path.nodes:
                source = (index, node.point)
                for target in node.links:
                    if data.node(*target) is None:
                        self.changes.append(Change("link-removed", index, "points to a missing node", node.point,
                                                   target))
                    elif target == source:
                        self.changes.append(Change("link-removed", index, "points to itself", node.point, target))
                    elif self._on_foot(index) and self._driven(data.paths[target[0]]) or \
                            self._on_foot(target[0]) and self._driven(path):
                        if _pair(source, target) not in unused:
                            unused.add(_pair(source, target))
                            self.changes.append(Change("link-removed", index, "soldiers don't use this path of the "
                                                       "vehicles", node.point, target))
                    elif options.relink and index in linkable and target[0] in linkable:
                        dropped.add(_pair(source, target))
                    else:
                        links.add(_pair(source, target))
                        directed.add((source, target))

        # Links per pair of paths, so a new link keeps link_spacing nodes away from the others between them.
        near: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)

        def remember(a, b):
            near[(a[0], b[0])].append((a[1], b[1]))
            near[(b[0], a[0])].append((b[1], a[1]))

        def spaced(a, b) -> bool:
            return all(abs(a[1] - i) > options.link_spacing or abs(b[1] - j) > options.link_spacing
                       for i, j in near[(a[0], b[0])])

        for a, b in links:
            remember(a, b)
        # Nodes that already are junctions: an end next to one needs no new link.
        junctions = {node for pair in links for node in pair}

        # Candidates: (priority, distance, node, node, reason). Path ends first, then crossings, closest first.
        candidates = []
        objective_paths: dict[str, list[int]] = defaultdict(list)
        for index in linkable:
            objectives = data.paths[index].objectives
            if len(objectives) == 1 and self.kinds[index] in ("foot", "shared"):
                objective_paths[objectives[0]].append(index)

        for index in linkable - set(self.exits):
            path = data.paths[index]
            same_class = self._targets(index, linkable)
            own = set()
            if self.kinds[index] == "foot" and len(path.objectives) > 1:
                own = {other for name in path.objectives for other in objective_paths.get(name, ())} - {index}
            for node in {id(node): node for node in (path.nodes[0], path.nodes[-1])}.values():
                if self._junction_near(path, node, junctions):
                    continue
                # An end at an objective joins its objective path, even if a bit further away. Other ends join the
                # closest path next to them.
                closest = self._nearest(node.pos, options.attach_radius, own & same_class)
                reason = "path end at objective"
                if not closest:
                    closest = self._outside(index, self._nearest(node.pos, options.end_radius, same_class))
                    reason = "path end"
                if closest:
                    other = min(closest, key=lambda key: closest[key])
                    distance, point = closest[other]
                    candidates.append((0, distance, (index, node.point), (other, point), reason))

        # Crossings: where two paths cross (on the map, at about the same height, not just weaving along each other)
        # or touch. Off by default: the hand-made maps link path ends, hardly ever crossings.
        for index in linkable if options.crossings else ():
            nodes = data.paths[index].nodes
            for a, b in zip(nodes, nodes[1:]):
                reach = math.dist(a.pos, b.pos) / 2 + MAX_SEGMENT
                middle = tuple((a.pos[i] + b.pos[i]) / 2 for i in range(3))
                for other, point, _ in self.grid.near(middle, reach):
                    if other <= index or other not in linkable or not self._compatible(index, other):
                        continue
                    others = data.paths[other].nodes
                    c = others[point - 1]
                    for d in (others[point - 2] if point > 1 else None, others[point] if point < len(others) else None):
                        if d is None or not _crossing(a.pos, b.pos, c.pos, d.pos, options.cross_height,
                                                      options.cross_angle):
                            continue
                        i, j = min(((x, y) for x in (a, b) for y in (c, d)),
                                   key=lambda pair: math.dist(pair[0].pos, pair[1].pos))
                        candidates.append((1, math.dist(i.pos, j.pos), (index, i.point), (other, j.point), "crossing"))
                for other, point, distance in self.grid.near(a.pos, options.touch_radius):
                    if other > index and other in linkable and self._compatible(index, other):
                        candidates.append((1, distance, (index, a.point), (other, point), "touching"))

        def accept(candidates):
            for _, distance, a, b, reason in sorted(candidates, key=lambda item: (item[0], item[1])):
                pair = _pair(a, b)
                if pair in links or not spaced(a, b):
                    continue
                links.add(pair)
                remember(a, b)
                if pair not in dropped:
                    self.changes.append(Change("link-added", a[0], f"{reason}, {distance:.1f} m", a[1], b))

        accept(candidates)

        # Every end a bot can reach needs a junction, else it has to turn around there. An end without one follows its
        # trajectory: the first path it crosses within extend_radius, else the closest path within attach_radius.
        junctions = {node for pair in links for node in pair}
        for index in sorted(linkable):
            path = data.paths[index]
            if path.loops or len(path.nodes) < 2:
                continue  # a looping bot goes on at the other end
            same_class = self._targets(index, linkable)
            if index in self.exits:
                # Only the far end counts, and only a junction out of the base.
                leaving = {a for pair in links for a, b in (pair, pair[::-1]) if a[0] == index
                           and (b[0] not in self.exits or not self._at_base(data.node(*b).pos))}
                far = path.nodes[0] if self.exits[index] is path.nodes[-1] else path.nodes[-1]
                ends = [] if self._junction_near(path, far, leaving) else [far]
            else:
                ends = [end for end in (path.nodes[0], path.nodes[-1])
                        if not self._junction_near(path, end, junctions)]
            if self.kinds[index] == "special" and len(ends) < 2 and any("vehicle" in name for name in path.objectives):
                continue  # joined at one end, the bot gets into the vehicle at the other
            if self.kinds[index] == "vehicle":
                # The vehicle spawns there, the bot starts driving at this end.
                ends = [end for end in ends if not any(math.dist(end.pos, spawn) <= SPAWN_RADIUS
                                                       for spawn in self.spawns)]
            for end in ends:
                if index in self.exits:
                    found, reason = self._way_out(path, end, same_class)
                else:
                    found, reason = self._continuation(path, end, same_class, options.attach_radius)
                if found is None:
                    what = "vehicles can't leave the base" if index in self.exits else "dead end"
                    why = f"no path within {options.attach_radius:.0f} m or ahead within {options.extend_radius:.0f} m"
                    if index in self.exits:
                        why = f"no vehicle path within {options.extend_radius:.0f} m"
                        if self._nearest(end.pos, options.extend_radius, set(data.paths) - {index}):
                            why += " (the paths there have no \"Vehicles\")"
                    self.changes.append(Change("warning", index, f"{what}: {why}", end.point))
                    continue
                accept([(0, found[0], (index, end.point), found[1], reason)])
                junctions = {node for pair in links for node in pair}
        self._check_exits(links)
        for pair in sorted(dropped - links):
            self.changes.append(Change("link-removed", pair[0][0], "relinked", pair[0][1], pair[1]))
        one_sided = sum(1 for a, b in links if ((a, b) in directed) != ((b, a) in directed))
        if one_sided:
            self.changes.append(Change("link-added", 0, f"{one_sided} one-sided links completed on the other node"))

        # Write back, on both nodes, sorted.
        targets: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
        for a, b in links:
            targets[a].append(b)
            targets[b].append(a)
        for index, path in data.paths.items():
            for node in path.nodes:
                new = sorted(targets.get((index, node.point), []))
                if new != sorted(node.links):
                    node.set_links(new)

    def _continuation(self, path: PathData, end, targets: set, radius: float):
        """(distance, node) to link an end without junction to, and why: the first path its trajectory crosses, else
        the closest path within radius."""
        found = self._ahead(path, end, targets)
        if found is not None:
            return found, "trajectory of the path end"
        closest = self._nearest(end.pos, radius, targets)
        if closest:
            other = min(closest, key=lambda key: closest[key])
            return (closest[other][0], (other, closest[other][1])), "path end, closest path"
        return None, ""

    def _way_out(self, path: PathData, end, targets: set):
        """For the far end of a base exit: a vehicle path that is no base exit (vehicles can cross open ground, so up
        to extend_radius), else another base exit outside of the base."""
        found, reason = self._continuation(path, end, targets - set(self.exits), self.options.extend_radius)
        if found is not None:
            return found, reason + " out of the base"
        others = {other for other in targets & set(self.exits)}
        found, reason = self._continuation(path, end, others, self.options.attach_radius)
        if found is not None and self._outside(path.index, {found[1][0]: (found[0], found[1][1])}):
            return found, reason + " (another base exit)"
        return None, ""

    def _check_exits(self, links: set) -> None:
        """Every base exit has to lead (over other exits maybe) to a vehicle path that is no base exit, or that has
        objectives (the vehicles follow them)."""
        network: dict[int, set[int]] = defaultdict(set)
        for a, b in links:
            if a[0] != b[0] and self._compatible(a[0], b[0]):
                network[a[0]].add(b[0])
                network[b[0]].add(a[0])
        warned = {change.path for change in self.changes if change.kind == "warning" and "leave the base" in
                  change.message}
        for index in sorted(set(self.exits) - warned):
            seen, todo = {index}, [index]
            while todo:
                for other in network[todo.pop()] - seen:
                    seen.add(other)
                    todo.append(other)
            if all(other in self.exits and not self.data.paths[other].objectives for other in seen):
                others = ", ".join(str(other) for other in sorted(seen - {index})) or "none"
                self.changes.append(Change("warning", index, f"vehicles can't leave the base: its junctions only lead "
                                                             f"to other base exits ({others})"))

    def _ahead(self, path: PathData, end, paths: set) -> tuple[float, tuple[int, int]] | None:
        """The first path the trajectory of an end crosses within extend_radius: (distance, closest node there)."""
        # Direction of the last END_DIRECTION m of the path.
        nodes = path.nodes if end is path.nodes[-1] else path.nodes[::-1]
        back, walked = nodes[-1], 0.0
        for previous, node in zip(reversed(nodes[:-1]), reversed(nodes)):
            walked += math.dist(previous.pos, node.pos)
            back = previous
            if walked >= END_DIRECTION:
                break
        dx, dz = end.pos[0] - back.pos[0], end.pos[2] - back.pos[2]
        length = math.hypot(dx, dz)
        if length < 0.1:
            return None
        reach = self.options.extend_radius
        tip = (end.pos[0] + dx / length * reach, end.pos[1], end.pos[2] + dz / length * reach)

        best = None
        seen = set()
        for step in range(int(reach // MAX_SEGMENT) + 2):
            sample = [end.pos[i] + (tip[i] - end.pos[i]) * min(1.0, step * MAX_SEGMENT / reach) for i in range(3)]
            for other, point, _ in self.grid.near(sample, MAX_SEGMENT):
                if other not in paths or (other, point) in seen:
                    continue
                seen.add((other, point))
                others = self.data.paths[other].nodes
                if point >= len(others):
                    continue
                c, d = others[point - 1], others[point]
                hit = _intersection(end.pos, tip, c.pos, d.pos)
                if hit is None:
                    continue
                t, u = hit
                distance = t * reach
                # The trajectory is flat, allow for slopes along it.
                height = c.pos[1] + u * (d.pos[1] - c.pos[1])
                if abs(height - end.pos[1]) > self.options.cross_height + 0.15 * distance:
                    continue
                if best is None or distance < best[0]:
                    target = c if u <= 0.5 else d
                    best = (distance, (other, target.point))
        return best

    def _junction_near(self, path: PathData, end, junctions: set) -> bool:
        """Whether a node within link_spacing of this end of the path already is a junction."""
        if end is path.nodes[0]:
            near = path.nodes[:self.options.link_spacing + 1]
        else:
            near = path.nodes[-self.options.link_spacing - 1:]
        return any((path.index, node.point) in junctions for node in near)

    # --- 5: checks -----------------------------------------------------------------------------------------------

    def _check(self) -> None:
        data = self.data
        for anchor in self.anchors if self.options.objectives else ():
            if not any(path.objectives == [anchor.name] for path in data.paths.values()):
                self.changes.append(Change("warning", 0, f"no path belongs to \"{anchor.name}\" alone: record a "
                                                         f"path around it"))
        for index, path in data.paths.items():
            if self.kinds[index] not in ("foot", "special", "shared"):
                continue
            names = " ".join(path.objectives).lower()
            if "vehicle" in names and ("spawn" in names or "base" in names):
                continue  # the bot spawns into the vehicle
            if not any(node.links for node in path.nodes):
                self.changes.append(Change("warning", index, "no links: bots on this path can't leave it"))


def _intersection(a, b, c, d, min_angle: float = 0.0) -> tuple[float, float] | None:
    """Where the segments a-b and c-d cross on the map (x, z), as fractions (t on a-b, u on c-d). None if they don't,
    or at less than min_angle degrees."""
    rx, rz = b[0] - a[0], b[2] - a[2]
    sx, sz = d[0] - c[0], d[2] - c[2]
    denominator = rx * sz - rz * sx
    lengths = math.hypot(rx, rz) * math.hypot(sx, sz)
    if lengths < 1e-9 or abs(denominator) < 1e-9 or abs(denominator) / lengths < math.sin(math.radians(min_angle)):
        return None
    qx, qz = c[0] - a[0], c[2] - a[2]
    t = (qx * sz - qz * sx) / denominator
    u = (qx * rz - qz * rx) / denominator
    return (t, u) if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0 else None


def _crossing(a, b, c, d, max_height: float, min_angle: float) -> bool:
    """Whether the segments a-b and c-d cross on the map (x, z) at about the same height and at least min_angle
    degrees."""
    hit = _intersection(a, b, c, d, min_angle)
    if hit is None:
        return False
    t, u = hit
    return abs((a[1] + t * (b[1] - a[1])) - (c[1] + u * (d[1] - c[1]))) <= max_height


def _pair(a: tuple[int, int], b: tuple[int, int]):
    return (a, b) if a <= b else (b, a)


def label(data: MapData, anchors: list[Anchor], options: Options | None = None) -> Result:
    """Labels and links data in place, see the module doc."""
    return Labeler(data, anchors, options).run()


# --- patches -------------------------------------------------------------------------------------------------------
# The changes of a run as a list of paths, for the mod (DebugCommands.PathsApply) and for waypoint-files:
#   {"path", "count", "objectives"?, "loop"?, "links"?: [[point, [[path, point], ...]], ...]}
# count is the number of nodes the labeler saw, so a patch never lands on a path that was edited in the meantime.


def make_patch(before: MapData, after: MapData) -> list[dict]:
    patch = []
    for index, path in sorted(after.paths.items()):
        old = before.paths.get(index)
        if old is None:
            continue
        entry: dict = {"path": index, "count": len(path.nodes)}
        if sorted(old.objectives) != sorted(path.objectives):
            entry["objectives"] = path.objectives
        if old.loops != path.loops:
            entry["loop"] = path.loops
        links = [[node.point, [list(target) for target in node.links]]
                 for node, old_node in zip(path.nodes, old.nodes) if sorted(node.links) != sorted(old_node.links)]
        if links:
            entry["links"] = links
        if len(entry) > 2:
            patch.append(entry)
    return patch


def apply_patch(data: MapData, patch: list[dict]) -> None:
    """Applies a patch to data. Raises ValueError (and changes nothing) if a path doesn't match."""
    for entry in patch:
        path = data.paths.get(entry["path"])
        if path is None or len(path.nodes) != entry["count"]:
            found = "missing" if path is None else f"{len(path.nodes)} nodes"
            raise ValueError(f"path {entry['path']} doesn't match ({found}, expected {entry['count']} nodes)")
        for point, targets in entry.get("links", []):
            for target in targets:
                if data.node(*target) is None:
                    raise ValueError(f"link {entry['path']}:{point} -> {target[0]}:{target[1]} points to a missing "
                                     f"node")
    for entry in patch:
        path = data.paths[entry["path"]]
        if "objectives" in entry:
            path.objectives = entry["objectives"]
        if "loop" in entry:
            path.loops = entry["loop"]
        for point, targets in entry.get("links", []):
            path.nodes[point - 1].set_links([tuple(target) for target in targets])
