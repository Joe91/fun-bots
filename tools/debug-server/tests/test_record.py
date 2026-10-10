"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.census import record  # noqa: E402
from funbots_debug.paths.mapfile import MapData, Node, PathData  # noqa: E402
from test_lint import _networks, _path  # noqa: E402


class RecordTest(unittest.TestCase):
    def test_resample(self):
        points = record.resample([[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]], 2.0)
        self.assertEqual([p[0] for p in points], [0.0, 2.0, 4.0, 6.0, 8.0, 10.0])
        # The last one stays, also if the spacing doesn't fit.
        points = record.resample([[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]], 2.0)
        self.assertEqual(points[-1], [5.0, 0.0, 0.0])
        self.assertTrue(all(math.dist(a, b) <= 2.0 + 1e-6 for a, b in zip(points, points[1:])))

    def test_gaps(self):
        # a and b connected by path 1, the base (x 200..210) not: one gap, its closest pair the end of b.
        networks = _networks()
        data = MapData({1: _path(1, 10, 100)})
        networks["attach"] = [[1, 1, 5, 0.0], [1, 46, 6, 0.0]]
        gaps = record.gaps("X", networks, data)
        self.assertEqual([gap.spawn for gap in gaps], ["spawn us 1"])
        self.assertEqual(gaps[0].best[0][0], 200.0)
        self.assertEqual(gaps[0].best[1][0], 110.0)
        # The closest point of the network there is a mesh point (of b), no waypoint: no link.
        self.assertIsNone(record.link_of(gaps[0], gaps[0].best[1]))
        self.assertEqual(record.link_of(gaps[0], [100.0, 0.0, 0.0]), (1, 46))

    def test_gaps_one_way_per_island(self):
        # A second base next to the first (connected over the mesh): one gap for both.
        networks = _networks()
        first = len(networks["points"])
        for i in range(6):
            networks["points"].append([212.0 + 2.0 * i, 0.0, 0.0, 2.0, 0, 1])
            networks["edges"].append([first + i - 1 if i else first - 1, first + i, 2.0, []])
        networks["zones"].append({"name": "spawn us 2", "kind": "base", "inside": list(range(first, first + 6))})
        data = MapData({1: _path(1, 10, 100)})
        networks["attach"] = [[1, 1, 5, 0.0], [1, 46, 6, 0.0]]
        gaps = record.gaps("X", networks, data)
        self.assertEqual([gap.spawn for gap in gaps], ["spawn us 1 + spawn us 2"])
        self.assertEqual(len(gaps[0].starts), 12)

    def test_add_path(self):
        data = MapData({1: PathData(1, [Node(1, 1, (0.0, 0.0, 0.0))])})
        index = record.add_path(data, [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
        self.assertEqual(index, 2)
        self.assertEqual([node.point for node in data.paths[2].nodes], [1, 2])
        self.assertEqual(data.paths[2].vehicles, [])
        self.assertFalse(data.paths[2].loops)
        linked = record.add_path(data, [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], (1, 1))
        self.assertEqual(data.paths[linked].nodes[-1].links, [(1, 1)])
        self.assertEqual(data.paths[linked].nodes[0].links, [])


if __name__ == "__main__":
    unittest.main()
