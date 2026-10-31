"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from funbots_debug.census import connect  # noqa: E402
from funbots_debug.paths.mapfile import MapData  # noqa: E402
from test_lint import _networks, _path  # noqa: E402


def _bigger():
    """As _networks, with pieces of 12 points (connect leaves out islands under MIN_PART)."""
    points, edges, zones = [], [], []
    for name, kind, x0 in (("mcom 1", "mcom", 0), ("mcom 2", "mcom", 100), ("spawn ru 1", "base", 200)):
        first = len(points)
        for i in range(12):
            points.append([x0 + 2.0 * i, 0.0, 0.0, 2.0, 0, 1])
            if i > 0:
                edges.append([len(points) - 2, len(points) - 1, 2.0, []])
        center = [x0 + 11.0, 0.0, 0.0]
        zones.append({"name": name, "kind": kind, "center": center, "inside": list(range(first, len(points)))})
    return {"points": points, "edges": edges, "attach": [], "zones": zones}


class ConnectTest(unittest.TestCase):
    def test_islands_and_tree(self):
        networks = _bigger()
        found = connect.islands(networks, MapData({}))
        self.assertEqual(sorted(island["zones"][0] for island in found), ["mcom 1", "mcom 2", "spawn ru 1"])
        joins = connect.tree(networks, found)
        # Three islands in a row: two joins, each between neighbours (78 m apart: 22 to 100, 122 to 200).
        self.assertEqual(len(joins), 2)
        self.assertEqual([round(join[0]) for join in joins], [78, 78])

    def test_islands_joined_by_a_path(self):
        networks = _bigger()
        # A path from the end of mcom 1 (x 22) to the start of mcom 2 (x 100): one island.
        networks["attach"] = [[1, 1, 11, 0.0], [1, 40, 12, 0.0]]
        data = MapData({1: _path(1, 22, 100)})
        found = connect.islands(networks, data)
        self.assertEqual(sorted(len(island["zones"]) for island in found), [1, 2])

    def test_small_parts_left_out(self):
        networks = _networks()  # pieces of 6 points
        self.assertEqual(connect.islands(networks, MapData({})), [])

    def test_team_of(self):
        self.assertEqual(connect.team_of(["spawn ru 2", "mcom 3"], ["mcom 2"]), 2)
        self.assertEqual(connect.team_of(["spawn us 4"], ["mcom 1", "spawn ru 1"]), 1)
        self.assertEqual(connect.team_of(["mcom 1"], ["mcom 2"]), 1)

    def test_second_ways(self):
        networks = _bigger()
        ways = connect.second_ways(networks, MapData({}))
        # mcom 1 -> mcom 2 only (the base is no objective), via a point 25 m to the side of the middle.
        self.assertEqual(len(ways), 1)
        start, goal, via = ways[0]
        self.assertEqual(start, [11.0, 0.0, 0.0])
        self.assertEqual(goal, [111.0, 0.0, 0.0])
        self.assertAlmostEqual(abs(via[2]), connect.SECOND_APART)
        self.assertAlmostEqual(via[0], 61.0)


if __name__ == "__main__":
    unittest.main()
