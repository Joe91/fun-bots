"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.census import navpaths  # noqa: E402
from funbots_debug.paths.mapfile import NO_LOOP, MapData, Node, PathData  # noqa: E402


def _mesh(*zones):
    """A mesh of squares of points every 2 m, one per zone: (name, x, z). The middle 20 x 20 m are in the zone, a margin
    of 8 m around it is on the mesh but outside."""
    points, entries = [], []
    for name, x0, z0 in zones:
        inside = []
        for i in range(19):
            for j in range(19):
                x, z = 2 * i - 18, 2 * j - 18
                in_zone = abs(x) <= 10 and abs(z) <= 10
                if in_zone:
                    inside.append(len(points))
                points.append([x0 + x, 0.0, z0 + z, 2.0, 0, 1 if in_zone else 0])
        # The circle of the area of the census around it: covers the square of points.
        entries.append({"name": name, "kind": "capturepoint", "center": [x0, 0.0, z0], "radius": 26.0,
                        "inside": inside})
    return {"version": 2, "points": points, "edges": [], "attach": [], "zones": entries}


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
        self.zones = _mesh(("a", 0, 0), ("b", 100, 0), ("c", 0, 100))

    def test_path_through_two_zones(self):
        data = MapData({1: _path(1, _line(-5, 105, 0), {"Objectives": ["a", "b"]})})
        result = navpaths.build(data, self.zones)
        self.assertEqual(len(result.routes), 1)
        path = result.data.paths[1]
        nav = path.first.data["Nav"]
        self.assertEqual((nav["From"], nav["To"]), ("a", "b"))
        # The zones aren't labels of the path: the bots find their way over the mesh and "Nav".
        self.assertEqual(path.objectives, [])
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

    def test_kept_path_linked_far_away_gets_a_connector(self):
        # The beacon at the end of path 2, which never comes into a zone: path 2 is dropped, the beacon keeps the way
        # from there to the navigation path.
        walk = _path(1, _line(-5, 105, 0))
        side = _path(2, [(50, 2 + 2 * i) for i in range(20)])
        walk.nodes[27].set_links([(2, 1)])  # x = 49
        side.nodes[0].set_links([(1, 28)])
        beacon = _path(3, [(52, 40), (54, 40)], {"Objectives": ["beacon"]})
        beacon.nodes[1].data["Action"] = {"type": "beacon"}
        beacon.nodes[0].set_links([(2, 20)])
        side.nodes[19].set_links([(3, 1)])
        result = navpaths.build(MapData({1: walk, 2: side, 3: beacon}), self.zones)
        self.assertEqual((result.connectors, result.lost_links), (1, 0))
        kept = next(path for path in result.data.paths.values() if path.objectives == ["beacon"])
        connector = result.data.paths[kept.nodes[0].links[0][0]]
        self.assertNotIn("Nav", connector.first.data)
        self.assertEqual(len(connector.nodes), 20)
        self.assertEqual(connector.first.links, [(kept.index, 1)])
        end = connector.nodes[-1].links[0]
        self.assertIn("Nav", result.data.paths[end[0]].first.data)
        self.assertEqual(connector.objectives, [])

    def test_kept_foot_path_keeps_only_what_it_leads_to(self):
        # The way from zone a to a tank: the zone isn't a label of it anymore. A vehicle-path keeps all of its labels.
        way = _path(1, [(0, 2 * i) for i in range(20)], {"Objectives": ["a", "vehicle tank1 us"]})
        road = _path(2, [(0, z) for z in range(0, 101, 4)], {"Objectives": ["a", "c"], "Vehicles": ["land"]})
        other = _path(3, [(4, 4), (6, 4)], {"Objectives": ["a", "explore"]})
        other.nodes[0].data["Action"] = {"type": "explore"}
        result = navpaths.build(MapData({1: way, 2: road, 3: other, 4: _path(4, _line(-5, 105, 0))}), self.zones)
        labels = sorted(path.objectives for index, path in result.data.paths.items() if index in result.old_paths)
        self.assertEqual(labels, [["a", "c"], ["explore"], ["vehicle tank1 us"]])

    def test_short_piece_between_touching_zones_dropped(self):
        # Circles just around the squares: the gap between them isn't on the mesh (as where no mesh was measured). The
        # piece between them is 10 m long here, dropped with a higher limit.
        zones = _mesh(("a", 0, 0), ("b", 26, 0))
        for zone in zones["zones"]:
            zone["radius"] = 12.0
        data = MapData({1: _path(1, _line(-5, 31, 0), {"Objectives": ["a", "b"]})})
        self.assertEqual(len(navpaths.build(data, zones).routes), 1)
        limit = navpaths.MIN_LENGTH
        navpaths.MIN_LENGTH = 12.0
        try:
            result = navpaths.build(data, zones)
        finally:
            navpaths.MIN_LENGTH = limit
        self.assertEqual(result.routes, [])
        self.assertEqual(result.short, 1)

    def test_missing_ends(self):
        data = MapData({1: _path(1, _line(-5, 105, 0))})
        result = navpaths.build(data, self.zones)
        count = len(result.data.paths[1].nodes)
        networks = {"attach": [[1, 1, 0, 1.0, [0, 0, 0], []], [1, count - 20, 0, 1.0, [0, 0, 0], []]]}
        self.assertEqual(navpaths.missing_ends(result.data, networks), [(1, "end in b")])

    def test_end_at_the_edge_moves_inside(self):
        # Close to a point at the edge of the mesh, but outside of the circle of the zone: no junction there, the
        # path is cut further inside.
        zones = _mesh(("a", 0, 0), ("b", 100, 0))
        for zone in zones["zones"]:
            zone["radius"] = 20.0
        data = MapData({1: _path(1, _line(-10, 110, 0))})
        result = navpaths.build(data, zones)
        self.assertEqual(len(result.routes), 1)
        path = result.data.paths[min(result.data.paths)]
        for node in (path.nodes[0], path.nodes[-1]):
            center = 0.0 if node.pos[0] < 50 else 100.0
            self.assertLessEqual(abs(node.pos[0] - center), 20.0 - navpaths.COVER_MARGIN)

    def test_piece_on_the_mesh_dropped(self):
        # Zones a and d overlap in their margins: the piece between them lies on the mesh, the bots walk the mesh.
        zones = _mesh(("a", 0, 0), ("d", 26, 0))
        data = MapData({1: _path(1, _line(-5, 31, 0))})
        result = navpaths.build(data, zones)
        self.assertEqual(result.routes, [])
        self.assertEqual(result.on_mesh, 1)

if __name__ == "__main__":
    unittest.main()
