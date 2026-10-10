"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.census import lint  # noqa: E402
from funbots_debug.paths.mapfile import MapData, Node, PathData  # noqa: E402


def _networks():
    """Three pieces of mesh in a row along x (points every 2 m, one line each): capture points a and b, a base."""
    points, edges, zones = [], [], []
    for name, kind, x0 in (("a", "capturepoint", 0), ("b", "capturepoint", 100), ("spawn us 1", "base", 200)):
        first = len(points)
        for i in range(6):
            points.append([x0 + 2.0 * i, 0.0, 0.0, 2.0, 0, 1])
            if i > 0:
                edges.append([len(points) - 2, len(points) - 1, 2.0, []])
        zones.append({"name": name, "kind": kind, "inside": list(range(first, len(points)))})
    return {"points": points, "edges": edges, "attach": [], "zones": zones}


def _path(index, x0, x1):
    nodes = [Node(index, point, (float(x), 0.0, 0.0), 3) for point, x in enumerate(range(x0, x1 + 1, 2), start=1)]
    return PathData(index, nodes)


class LintTest(unittest.TestCase):
    def test_unreachable_and_cut_off(self):
        networks = _networks()
        data = MapData({1: _path(1, 10, 100)})
        # Path 1 from the end of a (point 5, x 10) to the start of b (point 6, x 100).
        networks["attach"] = [[1, 1, 5, 0.0], [1, 46, 6, 0.0]]
        kinds = sorted((f.kind, f.severity) for f in lint.lint_map("X", networks, data))
        self.assertEqual(kinds, [("spawn-cut-off", "warning")])

        networks["attach"] = [[1, 1, 5, 0.0]]
        findings = lint.lint_map("X", networks, data)
        self.assertIn(("unreachable", "error"), [(f.kind, f.severity) for f in findings])
        self.assertIn(("dead-end", "warning"), [(f.kind, f.severity) for f in findings])

    def test_vehicle_paths_only_land_roads(self):
        networks = _networks()
        road = _path(1, 10, 100)
        road.first.data["Vehicles"] = ["land"]
        networks["attach"] = [[1, 1, 5, 0.0], [1, 46, 6, 0.0]]
        self.assertNotIn("unreachable", [f.kind for f in lint.lint_map("X", networks, MapData({1: road}))])
        road.first.data["Vehicles"] = ["water"]
        self.assertIn("unreachable", [f.kind for f in lint.lint_map("X", networks, MapData({1: road}))])

    def test_split_junctions(self):
        networks = _networks()
        # Two junctions on one path, 4 m apart straight onto points of a and b that the mesh doesn't connect.
        networks["points"][11][0] = 14.0
        data = MapData({1: _path(1, 10, 14)})
        networks["attach"] = [[1, 1, 5, 0.0], [1, 3, 11, 0.0]]
        self.assertIn("split-junctions", [f.kind for f in lint.lint_map("X", networks, data)])


if __name__ == "__main__":
    unittest.main()
