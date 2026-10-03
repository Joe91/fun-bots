"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.census import navpaths  # noqa: E402
from funbots_debug.paths.mapfile import NO_LOOP, MapData, Node, PathData  # noqa: E402


def _zone(name, x0, z0, size=20.0, kind="capturepoint", margin=8.0):
    """A network of points every 2 m over a square, in the zone, and a margin of points around it outside of it."""
    points = []
    half = size / 2 + margin
    steps = int(2 * half / 2) + 1
    for i in range(steps):
        for j in range(steps):
            x, z = 2 * i - half, 2 * j - half
            inside = abs(x) <= size / 2 and abs(z) <= size / 2
            points.append([x0 + x, 0.0, z0 + z, 2.0, 0, 1 if inside else 0])
    return {"name": name, "kind": kind, "center": [x0, 0.0, z0], "points": points, "edges": [], "attach": []}


def _path(index, positions, data=None, loops=False):
    nodes = [Node(index, point, (float(x), 0.0, float(z)), 3) for point, (x, z) in enumerate(positions, start=1)]
    if data:
        nodes[0].data.update(data)
    path = PathData(index, nodes)
    path.loops = loops
    return path


def _line(x0, x1, z, step=2.0):
    count = int(abs(x1 - x0) / step)
    return [(x0 + (x1 - x0) * i / count, z) for i in range(count + 1)]


class NavpathsTest(unittest.TestCase):
    def setUp(self):
        # Zones a (around x=0) and b (around x=100), c (around z=100) only over a road.
        self.zones = {"zones": [_zone("a", 0, 0), _zone("b", 100, 0), _zone("c", 0, 100)]}

    def test_path_through_two_zones(self):
        data = MapData({1: _path(1, _line(-5, 105, 0), {"Objectives": ["a", "b"]})})
        result = navpaths.build(data, self.zones)
        self.assertEqual(len(result.routes), 1)
        path = result.data.paths[1]
        nav = path.first.data["Nav"]
        self.assertEqual((nav["From"], nav["To"]), ("a", "b"))
        self.assertEqual(path.objectives, ["a", "b"])
        self.assertFalse(path.loops)
        self.assertEqual(path.first.input >> 8, NO_LOOP)
        # From the first waypoint in a to the first one in b, nothing deeper in the zones.
        self.assertAlmostEqual(path.nodes[0].pos[0], 10.0, delta=2.1)
        self.assertAlmostEqual(path.nodes[-1].pos[0], 90.0, delta=2.1)
        self.assertAlmostEqual(nav["Length"], 80.0, delta=4.5)

    def test_inside_and_back_dropped(self):
        loop = [(-6, -6), (6, -6), (6, 6), (-6, 6)]
        out_and_back = _line(0, 40, 0) + list(reversed(_line(0, 40, 4)))
        data = MapData({1: _path(1, loop, {"Objectives": ["a"]}, loops=True), 2: _path(2, out_and_back)})
        result = navpaths.build(data, self.zones)
        self.assertEqual(result.routes, [])
        self.assertEqual(result.dropped[1], "inside of a zone")

    def test_open_end_extended_over_link(self):
        # Path 2 starts outside and only goes on over a link to path 1 at x=50.
        path1 = _path(1, _line(-5, 105, 0))
        path2 = _path(2, [(50, 2)] + _line(50, 105, 8)[1:])
        path1.nodes[27].set_links([(2, 1)])  # x = 49
        path2.nodes[0].set_links([(1, 28)])
        result = navpaths.build(MapData({1: path1, 2: path2}), self.zones)
        origins = sorted(route.origin for route in result.routes)
        self.assertEqual(origins, ["extended", "path"])
        extended = next(route for route in result.routes if route.origin == "extended")
        self.assertEqual({result.zones[extended.start], result.zones[extended.end]}, {"a", "b"})
        self.assertIn((1, 28), extended.vertices)

    def test_duplicate_along_another_dropped(self):
        data = MapData({1: _path(1, _line(-5, 105, 0)), 2: _path(2, _line(-5, 105, 1))})
        result = navpaths.build(data, self.zones)
        self.assertEqual(len(result.routes), 1)
        self.assertEqual(result.duplicates, 1)

    def test_road_where_no_path_leads(self):
        road = _path(2, [(0, z) for z in range(0, 101, 4)], {"Vehicles": ["land"]})
        data = MapData({1: _path(1, _line(-5, 105, 0)), 2: road})
        result = navpaths.build(data, self.zones)
        pairs = {frozenset((result.zones[route.start], result.zones[route.end])) for route in result.routes}
        self.assertIn(frozenset(("a", "c")), pairs)
        crafted = next(route for route in result.routes if route.origin == "crafted")
        self.assertEqual(crafted.source, [2])
        # The road itself stays as it is.
        self.assertEqual(result.fixed[2], "vehicles")

    def test_kept_paths_and_their_links(self):
        vehicle = _path(1, [(50, 4), (50, 8)], {"Objectives": ["vehicle tank us"]})
        vehicle.nodes[0].data["Action"] = {"type": "vehicle"}
        vehicle.nodes[0].set_links([(2, 28)])
        walk = _path(2, _line(-5, 105, 0))
        walk.nodes[27].set_links([(1, 1)])
        result = navpaths.build(MapData({1: vehicle, 2: walk}), self.zones)
        kept = result.data.paths[1]
        self.assertEqual(kept.objectives, ["vehicle tank us"])
        target = kept.nodes[0].links[0]
        self.assertIn("Nav", result.data.paths[target[0]].first.data)
        back = result.data.paths[target[0]].nodes[target[1] - 1]
        self.assertEqual(back.links, [(1, 1)])
        self.assertEqual(result.moved_links, 1)

    def test_missing_ends(self):
        data = MapData({1: _path(1, _line(-5, 105, 0))})
        result = navpaths.build(data, self.zones)
        count = len(result.data.paths[1].nodes)
        networks = {"zones": [{"name": "a", "attach": [[1, 1, 0, 1.0, [0, 0, 0], []]]},
                              {"name": "b", "attach": [[1, count - 20, 0, 1.0, [0, 0, 0], []]]}]}
        self.assertEqual(navpaths.missing_ends(result.data, networks), [(1, "end in b")])


if __name__ == "__main__":
    unittest.main()
