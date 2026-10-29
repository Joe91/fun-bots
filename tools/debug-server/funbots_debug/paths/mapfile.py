"""Waypoint-files (mapfiles/*.map), the format the fun-bots-helper exports from mod.db.

    pathIndex;pointIndex;transX;transY;transZ;inputVar;data

Path 0 point 0 is the info-node (authors, date). Points are numbered 1..n in each path. The data of a node is JSON: the
first node of a path holds its "Objectives" and "Vehicles", every node can hold "Links" ([[path, point], ...]) and
"Action". inputVar packs the speed (bits 0-3), the extra-mode (4-7) and an option (8-15). On the first node, option 0xFF
means the path is walked back and forth, any other value that it loops (Bot:_GetWayIndex).
"""

from __future__ import annotations

import copy
import json
import math
from dataclasses import dataclass, field
from pathlib import Path

HEADER = "pathIndex;pointIndex;transX;transY;transZ;inputVar;data"
# Option of the first node for paths that are walked back and forth instead of in a loop.
NO_LOOP = 0xFF


@dataclass
class Node:
    path: int
    point: int
    pos: tuple[float, float, float]
    input: int = 3
    data: dict = field(default_factory=dict)

    @property
    def links(self) -> list[tuple[int, int]]:
        return [(int(link[0]), int(link[1])) for link in self.data.get("Links") or []]

    def set_links(self, links) -> None:
        if links:
            self.data["LinkMode"] = self.data.get("LinkMode", 0)
            self.data["Links"] = [[path, point] for path, point in links]
        else:
            self.data.pop("Links", None)
            self.data.pop("LinkMode", None)


@dataclass
class PathData:
    index: int
    nodes: list[Node]

    @property
    def first(self) -> Node:
        return self.nodes[0]

    @property
    def objectives(self) -> list[str]:
        return list(self.first.data.get("Objectives") or [])

    @objectives.setter
    def objectives(self, names: list[str]) -> None:
        if names:
            self.first.data["Objectives"] = sorted(names)
        else:
            self.first.data.pop("Objectives", None)

    @property
    def vehicles(self) -> list[str]:
        return [str(name).lower() for name in self.first.data.get("Vehicles") or []]

    @property
    def loops(self) -> bool:
        return (self.first.input >> 8) & 0xFF != NO_LOOP

    @loops.setter
    def loops(self, value: bool) -> None:
        self.first.input = (self.first.input & 0xFF) | ((0 if value else NO_LOOP) << 8)

    @property
    def gap(self) -> float:
        """Distance between the last and the first node, what a looping bot walks straight."""
        return math.dist(self.nodes[0].pos, self.nodes[-1].pos)

    @property
    def step(self) -> float:
        """Average distance between two nodes."""
        if len(self.nodes) < 2:
            return 0.0
        return sum(math.dist(a.pos, b.pos) for a, b in zip(self.nodes, self.nodes[1:])) / (len(self.nodes) - 1)


class MapData:
    """All paths of one level and mode. Paths are kept in file order, nodes by point index."""

    def __init__(self, paths: dict[int, PathData] | None = None, info: dict | None = None):
        self.paths: dict[int, PathData] = paths or {}
        self.info = info

    def node(self, path: int, point: int) -> Node | None:
        entry = self.paths.get(path)
        if entry is None or not 1 <= point <= len(entry.nodes):
            return None
        return entry.nodes[point - 1]

    # --- reading -----------------------------------------------------------------------------------------------

    @classmethod
    def load(cls, file: Path | str) -> "MapData":
        return cls.parse(Path(file).read_text(encoding="utf-8"))

    @classmethod
    def parse(cls, text: str) -> "MapData":
        paths: dict[int, list[Node]] = {}
        info = None
        for line in text.splitlines()[1:]:
            if not line.strip():
                continue
            items = line.split(";", 6)
            raw = items[6].strip() if len(items) > 6 else ""
            data = json.loads(raw) if raw else {}
            path, point = int(items[0]), int(items[1])
            if path == 0:
                info = data
                continue
            node = Node(path, point, (float(items[2]), float(items[3]), float(items[4])), int(items[5]), data)
            paths.setdefault(path, []).append(node)
        data = cls({index: PathData(index, sorted(nodes, key=lambda node: node.point))
                    for index, nodes in paths.items()}, info)
        # The mod numbers the points by their order and resolves links by it (NodeCollection:RecalculateIndexes), so
        # a file with gaps or doubled point numbers means the same as one numbered 1..n.
        for path in data.paths.values():
            for point, node in enumerate(path.nodes, start=1):
                node.point = point
        return data

    @classmethod
    def from_rows(cls, rows: dict[int, dict]) -> "MapData":
        """From the paths the mod streams (state.paths: {path: {"points", "inputs", "data"}})."""
        paths = {}
        for index, entry in sorted(rows.items()):
            points = entry.get("points") or []
            inputs = entry.get("inputs") or []
            data = entry.get("data") or {}
            nodes = [Node(int(index), point, tuple(pos),
                          int(inputs[point - 1]) if point - 1 < len(inputs) else 3,
                          copy.deepcopy(data.get(str(point)) or {}))
                     for point, pos in enumerate(points, start=1)]
            if nodes:
                paths[int(index)] = PathData(int(index), nodes)
        return cls(paths)

    # --- writing -----------------------------------------------------------------------------------------------

    def dumps(self) -> str:
        lines = [HEADER]
        if self.info is not None:
            lines.append(f"0;0;0.000000;0.000000;0.000000;0;{_encode(self.info)}")
        for index in sorted(self.paths):
            for node in self.paths[index].nodes:
                x, y, z = node.pos
                lines.append(f"{node.path};{node.point};{x:.6f};{y:.6f};{z:.6f};{node.input};{_encode(node.data)}")
        return "\n".join(lines) + "\n"

    def save(self, file: Path | str) -> None:
        Path(file).write_text(self.dumps(), encoding="utf-8")


def _sorted(value):
    """Same order as the export of the fun-bots-helper (sort_dict_and_string_lists), so files diff cleanly."""
    if isinstance(value, dict):
        return {key: _sorted(value[key]) for key in sorted(value)}
    if isinstance(value, list):
        if all(isinstance(item, str) for item in value):
            return sorted(value)
        if all(isinstance(item, (int, float)) for item in value):
            return value
        return [_sorted(item) for item in value]
    return value


def _encode(data: dict) -> str:
    return json.dumps(_sorted(data), separators=(",", ":")) if data else ""
