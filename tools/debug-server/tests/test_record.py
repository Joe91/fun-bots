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

    def test_add_vehicle_path(self):
        data = MapData({1: PathData(1, [Node(1, 1, (0.0, 0.0, 0.0)), Node(1, 2, (9.0, 0.0, 0.0))])})
        index = record.add_path(data, [[0.0, 0.0, 0.0], [4.0, 0.0, 0.0]], (1, 2), vehicles=["land"], start_link=(1, 1))
        self.assertEqual(data.paths[index].vehicles, ["land"])
        self.assertEqual(data.paths[index].nodes[0].links, [(1, 1)])
        self.assertEqual(data.paths[index].nodes[-1].links, [(1, 2)])
        self.assertFalse(data.paths[index].loops)

    def test_ring_starts(self):
        ring = record.ring_starts([10.0, 5.0, 20.0], 2.0)
        self.assertEqual(len(ring), 8)
        for point in ring:
            self.assertAlmostEqual(math.hypot(point[0] - 10.0, point[2] - 20.0), 2.0)
            self.assertEqual(point[1], 5.0)

    def test_mesh_outside(self):
        # An island of 2 points up at y 10, the ground of 3 points (min_part 3), a speck of 1 point.
        points = [[0, 10, 0], [2, 10, 0], [0, 0, 0], [5, 0, 0], [10, 0, 0], [50, 0, 50]]
        networks = {"points": points, "edges": [[0, 1, 2, []], [2, 3, 5, []], [3, 4, 5, []]]}
        goals = record.mesh_outside(networks, [1, 10, 0], min_part=3)
        self.assertEqual(goals, [[0, 0, 0], [5, 0, 0], [10, 0, 0]])

    def test_replace_stretch(self):
        nodes = [Node(1, n, (float(n * 10), 0.0, 0.0), 0x203 if n == 1 else 3, {"Vehicles": ["land"]} if n == 1 else {})
                 for n in range(1, 7)]
        nodes[4].set_links([(2, 1)])
        other = [Node(2, 1, (50.0, 0.0, 5.0), 3, {}), Node(2, 2, (30.0, 0.0, 5.0), 3, {})]
        other[0].set_links([(1, 5)])
        other[1].set_links([(1, 3)])
        data = MapData({1: PathData(1, nodes), 2: PathData(2, other)})
        # Waypoints 3 and 4 (30, 40) replaced by three points round something; 2 and 5 stay.
        dropped = record.replace_stretch(data, 1, 2, 5, [[20.0, 0.0, 0.0], [25.0, 0.0, 4.0], [35.0, 0.0, 6.0],
                                                         [45.0, 0.0, 4.0], [50.0, 0.0, 0.0]])
        path = data.paths[1]
        self.assertEqual([node.pos[0] for node in path.nodes], [10.0, 20.0, 25.0, 35.0, 45.0, 50.0, 60.0])
        self.assertEqual([node.point for node in path.nodes], list(range(1, 8)))
        self.assertEqual(path.nodes[2].input, 3)
        self.assertEqual(path.nodes[2].data, {})
        self.assertEqual(path.vehicles, ["land"])
        # The link of the old waypoint 5 moved with it to 6, the one to the old 3 is gone.
        self.assertEqual(data.paths[2].nodes[0].links, [(1, 6)])
        self.assertEqual(data.paths[2].nodes[1].links, [])
        self.assertEqual(path.nodes[5].links, [(2, 1)])
        self.assertEqual(dropped, ["link of 2:2 to 1:3"])


if __name__ == "__main__":
    unittest.main()
