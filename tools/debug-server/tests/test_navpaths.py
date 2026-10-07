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
    points, edges, entries = [], [], []
    for name, x0, z0 in zones:
        inside = []
        first = len(points)
        for i in range(19):
            for j in range(19):
                x, z = 2 * i - 18, 2 * j - 18
                in_zone = abs(x) <= 10 and abs(z) <= 10
                if in_zone:
                    inside.append(len(points))
                points.append([x0 + x, 0.0, z0 + z, 2.0, 0, 1 if in_zone else 0])
                # Connected to the neighbours: one part of the mesh per square.
                if i > 0:
                    edges.append([len(points) - 1, len(points) - 1 - 19, 2.0, []])
                if j > 0:
                    edges.append([len(points) - 1, len(points) - 2, 2.0, []])
        assert len(points) - first == 19 * 19
        # The circle of the area of the census around it: covers the square of points.
        entries.append({"name": name, "kind": "capturepoint", "center": [x0, 0.0, z0], "radius": 26.0,
                        "inside": inside})
    # Overlapping squares are one lattice in the real mesh (navzones._Merged): the same position is connected.
    by_position = {}
    for index, point in enumerate(points):
        other = by_position.setdefault((point[0], point[2]), index)
        if other != index:
            edges.append([index, other, 0.0, []])
    return {"version": 2, "points": points, "edges": edges, "attach": [], "zones": entries}


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


class TrimTest(unittest.TestCase):
    def setUp(self):
        # Zones a (around x=0) and b (around x=100), c (around z=100): squares of mesh from -18 to 18 m around them.
        self.zones = _mesh(("a", 0, 0), ("b", 100, 0), ("c", 0, 100))

    def test_path_between_two_zones(self):
        data = MapData({1: _path(1, _line(-5, 105, 0), {"Objectives": ["a", "b"]})})
        result = navpaths.trim(data, self.zones)
        self.assertEqual(result.pieces, 1)
        path = result.data.paths[1]
        # No names: the bots find their way over the mesh and the waypoints. The mark of a trimmed path instead.
        self.assertEqual(path.objectives, [])
        self.assertIn("Length", path.first.data["Nav"])
        self.assertFalse(path.loops)
        self.assertEqual(path.first.input >> 8, NO_LOOP)
        # From the last waypoint on the mesh of a to the first one on the mesh of b (up to MESH_DISTANCE beyond its
        # points at 18 m), nothing deeper in.
        self.assertAlmostEqual(path.nodes[0].pos[0], 20.0, delta=2.5)
        self.assertAlmostEqual(path.nodes[-1].pos[0], 80.0, delta=2.5)

    def test_all_on_the_mesh_dropped(self):
        loop = [(-6, -6), (6, -6), (6, 6), (-6, 6)]
        result = navpaths.trim(MapData({1: _path(1, loop, {"Objectives": ["a"]}, loops=True)}), self.zones)
        self.assertEqual(result.data.paths, {})
        self.assertEqual(result.dropped[1], "all on the mesh")

    def test_off_the_mesh_kept_whole_if_connected(self):
        # Path 2 never comes onto the mesh, but connects two pieces of path 1 and 3 over links.
        walk = _path(1, _line(-5, 40, 0))
        bridge = _path(2, _line(42, 58, 4), {"Objectives": ["x"]})
        other = _path(3, _line(60, 105, 0))
        walk.nodes[-1].set_links([(2, 1)])
        bridge.nodes[0].set_links([(1, len(walk.nodes))])
        bridge.nodes[-1].set_links([(3, 1)])
        other.nodes[0].set_links([(2, len(bridge.nodes))])
        result = navpaths.trim(MapData({1: walk, 2: bridge, 3: other}), self.zones)
        self.assertEqual(result.kept, 1)
        self.assertEqual(result.dead_ends, 0)
        kept = next(path for path in result.data.paths.values() if len(path.nodes) == len(bridge.nodes))
        self.assertEqual(kept.objectives, [])
        self.assertEqual(len([node for node in kept.nodes if node.links]), 2)

    def test_paths_that_lead_nowhere_dropped(self):
        alone = _path(1, [(40, 50), (60, 50), (60, 60), (40, 60)], loops=True)
        stub = _path(2, _line(10, 40, 4))  # From the mesh of a out into nothing.
        branch = _path(3, [(50, 10 + 2 * i) for i in range(10)])  # Off a stub only.
        stub.nodes[-1].set_links([(3, 1)])
        branch.nodes[0].set_links([(2, len(stub.nodes))])
        result = navpaths.trim(MapData({1: alone, 2: stub, 3: branch}), self.zones)
        self.assertEqual(result.data.paths, {})
        self.assertEqual(result.dead_ends, 3)

    def test_short_piece_where_the_mesh_leads_dropped(self):
        out_and_back = [(10, 0), (17.5, 0), (22.2, 0), (17.5, 0.5), (10, 0.5)]
        result = navpaths.trim(MapData({1: _path(1, out_and_back)}), self.zones)
        self.assertEqual(result.short, 1)
        self.assertEqual(result.data.paths, {})

    def test_ways_to_something_to_do_dropped(self):
        mcom = _path(1, [(50, 4), (50, 8)], {"Objectives": ["mcom 1 interact"]})
        mcom.nodes[0].data["Action"] = {"type": "mcom"}
        tank = _path(2, _line(20, 60, 10), {"Objectives": ["vehicle tank1 us"]})
        result = navpaths.trim(MapData({1: mcom, 2: tank}), self.zones)
        self.assertEqual(result.functions, 2)
        self.assertEqual(result.data.paths, {})

    def test_links_kept_between_the_waypoints_left(self):
        walk = _path(1, _line(-5, 105, 0))
        side = _path(2, [(50, 2 + 2 * i) for i in range(10)])
        walk.nodes[27].set_links([(2, 1)])  # x = 49
        side.nodes[0].set_links([(1, 28)])
        road = _path(3, [(0, z) for z in range(0, 101, 4)], {"Vehicles": ["land"], "Objectives": ["a", "c"]})
        road.nodes[0].set_links([(1, 3)])  # x = -1: on the mesh, dropped
        # The side path leads on to the road as well (else it's a branch off one link, dropped).
        side.nodes[-1].set_links([(3, 10)])
        road.nodes[9].set_links([(2, 10)])
        result = navpaths.trim(MapData({1: walk, 2: side, 3: road}), self.zones)
        # The vehicle path as it is.
        kept_road = next(path for path in result.data.paths.values() if path.vehicles)
        self.assertEqual(kept_road.objectives, ["a", "c"])
        self.assertEqual(kept_road.nodes[0].links, [])
        piece = next(path for path in result.data.paths.values() if len(path.nodes) > 20)
        side_new = next(path for path in result.data.paths.values() if len(path.nodes) == 10)
        linked = [node for node in piece.nodes if node.links]
        self.assertEqual(len(linked), 1)
        self.assertEqual(linked[0].links, [(side_new.index, 1)])
        self.assertEqual(side_new.nodes[0].links, [(piece.index, linked[0].point)])
        self.assertEqual(side_new.nodes[-1].links, [(kept_road.index, 10)])
        self.assertEqual(result.lost_links, 1)

    def test_closed_loop_walked_around_once(self):
        loop = _line(0, 50, 0) + [(50, z) for z in range(2, 31, 2)] + _line(50, 0, 30)[1:] \
            + [(0, z) for z in range(28, 1, -2)]
        result = navpaths.trim(MapData({1: _path(1, loop, loops=True)}), self.zones)
        self.assertEqual(result.pieces, 1)
        path = result.data.paths[1]
        # From the edge of the mesh at the bottom around to the edge on the left side.
        self.assertAlmostEqual(path.nodes[0].pos[0], 20.0, delta=2.5)
        self.assertAlmostEqual(path.nodes[-1].pos[2], 20.0, delta=2.5)
        self.assertFalse(path.loops)

    def test_attach_nodes(self):
        result = navpaths.trim(MapData({1: _path(1, _line(-5, 105, 0))}), self.zones)
        entry = navpaths.attach_nodes(result.data)[1]
        self.assertTrue(entry["nav"])
        self.assertEqual(len(entry["points"]), len(result.data.paths[1].nodes))


    def test_roads_are_ways_for_the_soldiers(self):
        road = _path(1, _line(-5, 105, 30), {"Vehicles": ["land"]})
        amphibious = _path(2, _line(-5, 105, 40), {"Vehicles": ["land", "water"]})
        boat = _path(3, _line(-5, 105, 50), {"Vehicles": ["water"]})
        entries = navpaths.attach_nodes(navpaths.trim(MapData({1: road, 2: amphibious, 3: boat}), self.zones).data)
        self.assertEqual([entries[index]["nav"] for index in (1, 2, 3)], [True, False, False])


    def test_loose_end_cut_back(self):
        # Out of a and back in at x=-1 (two junctions next to each other), then on to x=50 into nothing.
        walk = _path(1, [(-1, 0), (1, 0)] + _line(4, 50, 30))
        walk.nodes[0].data["Nav"] = {"Length": 1.0}
        data = MapData({1: walk})
        result = navpaths.Result(data)
        networks = {"attach": [[1, 1, 0, 1.0, [-1, 0, 0], []], [1, 2, 0, 1.0, [1, 0, 0], []]]}
        # Every end without a link: the mesh attaches the ones it has no junction for.
        self.assertEqual([entry[1] for entry in navpaths.loose_ends(data)], [1, len(walk.nodes)])
        self.assertEqual(navpaths.cut_loose(result, networks), 1)
        self.assertEqual(len(result.data.paths[1].nodes), 2)
        self.assertIn("Nav", result.data.paths[1].first.data)
        # Both junctions are one place: no way on, the path is dropped.
        self.assertEqual(navpaths.prune_unattached(result, networks), 1)
        self.assertEqual(result.data.paths, {})


    def test_thin_junctions(self):
        walk = _path(1, _line(0, 40, 0))
        data = MapData({1: walk})
        networks = {"attach": [[1, 1, 5, 1.0, [0, 0, 0], []], [1, 2, 9, 1.0, [2, 0, 0], []],
                               [1, len(walk.nodes), 7, 1.0, [40, 0, 0], []]]}
        self.assertEqual(navpaths.thin_junctions(data, networks), 1)
        self.assertEqual([entry[1] for entry in networks["attach"]], [1, len(walk.nodes)])


if __name__ == "__main__":
    unittest.main()
