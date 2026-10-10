"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.census import check, navzones  # noqa: E402


def _network():
    # A row of four points, a junction at the first one. Point 3 hangs on point 2 only.
    points = [[0.0, 0.0, 0.0, 2.0, 0, 0], [5.0, 0.0, 0.0, 2.0, 0, 0], [10.0, 0.0, 0.0, 2.0, 0, 0],
              [15.0, 0.0, 0.0, 2.0, 0, 0]]
    edges = [[0, 1, 5.0, []], [1, 2, 5.0, []], [2, 3, 5.0, []]]
    attach = [[1, 1, 0, 0.5, [0.0, 0.0, 0.0], []]]
    return {"points": points, "edges": edges, "attach": attach, "stats": {}}


class CheckTest(unittest.TestCase):
    def test_blocked_connection_drops_what_lies_behind_it(self):
        result = check.apply(_network(), {"blockedEdges": [[5.0, 0.0, 0.0, 10.0, 0.0, 0.0]]})
        self.assertEqual([point[0] for point in result["points"]], [0.0, 5.0])
        self.assertEqual([edge[:2] for edge in result["edges"]], [[0, 1]])
        self.assertEqual(result["stats"]["checkRemovedPoints"], 2)

    def test_point_inside_of_a_solid_is_left_out(self):
        result = check.apply(_network(), {"insidePoints": [[10.1, 0.0, 0.0]]})
        self.assertEqual([point[0] for point in result["points"]], [0.0, 5.0])

    def test_evaluate_finds_inside_points(self):
        network = _network()
        rays, meaning = check.rays(network)
        hits = []
        for what in meaning:
            # Point 3: seen from outside in every direction, nothing from inside. Connection 0 blocked.
            hit = (what[0] == "back" and what[1] == 3) or (what[0] == "edge" and what[1] == 0 and what[4] == 0) \
                or (what[0] == "edge" and what[1] == 1 and what[3] == 0)
            if what[0] == "ground":
                hits.append(check.GROUND_ABOVE)  # flat ground below the connections
            else:
                hits.append(0.5 if hit else -1)
        found = check.evaluate(network, hits, meaning)
        self.assertEqual(found["insidePoints"], [[15.0, 0.0, 0.0]])
        self.assertEqual(found["blockedEdges"], [[0.0, 0.0, 0.0, 5.0, 0.0, 0.0]])
        self.assertEqual(len(rays), len(meaning))

    def test_ledge_blocks_a_connection(self):
        network = _network()
        rays, meaning = check.rays(network)
        # Connection 2: the ground drops 1.5 m in its middle.
        hits = [(check.GROUND_ABOVE + (1.5 if what[1] == 2 and what[3] > 5 else 0.0)) if what[0] == "ground" else -1
                for what in meaning]
        found = check.evaluate(network, hits, meaning)
        self.assertEqual(found["blockedEdges"], [[10.0, 0.0, 0.0, 15.0, 0.0, 0.0]])

    def test_connection_along_waypoints_stays(self):
        network = _network()
        network["edges"][1].append(1)
        rays, meaning = check.rays(network)
        self.assertNotIn(1, {what[1] for what in meaning if what[0] == "edge"})
        result = check.apply(network, {"blockedEdges": [[5.0, 0.0, 0.0, 10.0, 0.0, 0.0]]})
        self.assertEqual(len(result["points"]), 4)

    def test_blocked_junction_is_dropped(self):
        network = _network()
        # A second junction from point 3 to a waypoint behind a wall.
        network["attach"].append([2, 1, 3, 3.0, [15.0, 0.0, 3.0], []])
        rays, meaning = check.rays(network)
        hits = [check.GROUND_ABOVE if what[0] == "ground" else (0.5 if what[0] == "junction" and what[1] == 1 else -1)
                for what in meaning]
        found = check.evaluate(network, hits, meaning)
        self.assertEqual(found["blockedJunctions"], [[15.0, 0.0, 0.0, 15.0, 0.0, 3.0]])
        result = check.apply(network, found)
        self.assertEqual([entry[0] for entry in result["attach"]], [1])

    def test_loose_end_not_attached_where_the_checks_found_it_blocked(self):
        # A loose end 1 m beside point 3; the way from point 3 is blocked: the next closest point (2) instead. With 10
        # points in one part (navzones.MIN_PART).
        points = [[float(index * 5), 0.0, 0.0, 2.0, 0, 0] for index in range(10)]
        edges = [[index, index + 1, 5.0, []] for index in range(9)]
        network = {"points": points, "edges": edges, "attach": [], "stats": {}}
        loose = [[7, 1, [15.0, 0.0, 1.0]]]
        self.assertEqual(navzones._attach_loose(network, loose)["attach"][0][2], 3)
        checks = {"blockedJunctions": [[15.0, 0.0, 0.0, 15.0, 0.0, 1.0]]}
        self.assertEqual(navzones._attach_loose(network, loose, checks)["attach"][0][2], 2)


if __name__ == "__main__":
    unittest.main()
