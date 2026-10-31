"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.census import roads  # noqa: E402
from funbots_debug.paths.mapfile import MapData, Node, PathData  # noqa: E402


def _road(index, points, speed=3):
    nodes = [Node(index, number, (float(x), 0.0, float(z)), speed, {}) for number, (x, z) in enumerate(points, start=1)]
    nodes[0].data["Vehicles"] = ["land"]
    return PathData(index, nodes)


def _layout():
    """Road 1 along x (z 0, x 0..100), road 2 along z from its middle (x 50, z 2..100, slow), a foot path."""
    data = MapData({1: _road(1, [(x, 0) for x in range(0, 101, 5)]),
                    2: _road(2, [(50, z) for z in range(2, 101, 5)], speed=2),
                    3: PathData(3, [Node(3, 1, (0.0, 0.0, 50.0)), Node(3, 2, (50.0, 0.0, 50.0))])})
    return data


class RoadsTest(unittest.TestCase):
    def test_route_over_a_crossing(self):
        network = roads.Roads([_layout()])
        # The foot path is no road.
        self.assertEqual(len(network.nodes), 21 + 20)
        way = network.route([0.0, 0.0, 0.0], [50.0, 0.0, 97.0], 5.0, 2.0, set(), set())
        self.assertIsNotNone(way)
        positions = [network.nodes[index] for index in way]
        self.assertEqual(positions[0][:3], [0.0, 0.0, 0.0])
        self.assertAlmostEqual(positions[-1][2], 97.0)
        # Over the crossing at x 50: along road 1, then road 2.
        self.assertTrue(all(pos[2] == 0.0 for pos in positions if pos[0] < 50.0))

    def test_blocked_crossing_no_route(self):
        network = roads.Roads([_layout()])
        way = network.route([0.0, 0.0, 0.0], [50.0, 0.0, 97.0], 5.0, 5.0, set(), set())
        blocked = network.near(way, [50.0, 0.0, 1.0])
        self.assertTrue(blocked)
        self.assertIsNone(network.route([0.0, 0.0, 0.0], [50.0, 0.0, 97.0], 5.0, 5.0, blocked, set()))

    def test_points_carry_the_speed_players_drove(self):
        network = roads.Roads([_layout()])
        way = network.route([0.0, 0.0, 0.0], [50.0, 0.0, 97.0], 5.0, 5.0, set(), set())
        points = network.points(way)
        self.assertEqual(points[0][3], 3)
        # On road 2 (slow) and up to SLOW_RANGE before it: speed 2.
        self.assertEqual(points[-1][3], 2)

    def test_add_vehicle_path(self):
        data = MapData({})
        index = roads.add_vehicle_path(data, [[0.0, 0.0, 0.0, 3], [4.0, 0.0, 0.0, 2]], ["base us", "a"])
        path = data.paths[index]
        self.assertEqual(path.vehicles, ["land"])
        self.assertEqual(path.objectives, ["base us", "a"])
        self.assertFalse(path.loops)
        self.assertEqual([node.input & 0xF for node in path.nodes], [3, 2])


if __name__ == "__main__":
    unittest.main()
