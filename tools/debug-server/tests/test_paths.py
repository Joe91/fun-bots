"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import io
import json
import math
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.analyzers import create_analyzers  # noqa: E402
from funbots_debug.hub import Hub, LabelError  # noqa: E402
from funbots_debug.paths.__main__ import main as paths_main  # noqa: E402
from funbots_debug.paths.labeler import (Anchor, Labeler, Options, anchors_from_flags,  # noqa: E402
                                         anchors_from_labels, apply_patch, label, make_patch, uses_objectives)
from funbots_debug.paths.mapfile import HEADER, MapData, Node, PathData  # noqa: E402

FLAGS = [
    {"name": "ID_H_US_A", "hq": False, "pos": [0, 0, 0], "team": 0},
    {"name": "ID_H_US_B", "hq": False, "pos": [200, 0, 0], "team": 0},
    {"name": "ID_H_US_HQ", "hq": True, "pos": [-200, 0, 0], "team": 1},
    {"name": "ID_H_RU_HQ", "hq": True, "pos": [400, 0, 0], "team": 2},
]


def loop(cx, radius=15.0):
    steps = int(2 * math.pi * radius / 2)
    return [(cx + radius * math.cos(i * 2 * math.pi / steps), 0.0, radius * math.sin(i * 2 * math.pi / steps))
            for i in range(steps + 1)]


def straight(x0, x1, z=0.0):
    steps = int(abs(x1 - x0) / 2)
    return [(x0 + (x1 - x0) * i / steps, 0.0, z) for i in range(steps + 1)]


def make_map(paths: dict[int, list], data: dict[int, dict] | None = None) -> MapData:
    """Paths as recorded: walk (inputVar 3, which loops), no data unless given for the first node."""
    data = data or {}
    return MapData({index: PathData(index, [Node(index, point, pos, 3, dict(data.get(index, {})) if point == 1 else {})
                                            for point, pos in enumerate(points, start=1)])
                    for index, points in paths.items()})


def level() -> MapData:
    """Loops around a, b and both bases, and paths between them that end at the loops."""
    return make_map({
        1: loop(0),  # a
        2: loop(200),  # b
        3: loop(-200, 25),  # base us
        4: loop(400, 25),  # base ru
        5: straight(15, 185),  # a - b
        6: straight(-175, -15, 3),  # base us - a
        7: straight(215, 375, 3),  # b - base ru
    })


def links(data: MapData) -> set:
    return {(index, node.point, target) for index, path in data.paths.items() for node in path.nodes
            for target in node.links}


class MapfileTest(unittest.TestCase):
    TEXT = (f"{HEADER}\n"
            '0;0;0.000000;0.000000;0.000000;0;{"Authors":["x"]}\n'
            '1;1;1.000000;2.000000;3.000000;65283;{"Objectives":["b","a"]}\n'
            '1;2;2.000000;2.000000;3.000000;4;{"LinkMode":0,"Links":[[2,1]]}\n'
            '2;1;2.500000;2.000000;3.000000;3;{"LinkMode":0,"Links":[[1,2]]}\n')

    def test_roundtrip(self):
        data = MapData.parse(self.TEXT)
        self.assertEqual(data.info, {"Authors": ["x"]})
        self.assertEqual(data.paths[1].objectives, ["b", "a"])
        self.assertFalse(data.paths[1].loops)
        self.assertTrue(data.paths[2].loops)
        self.assertEqual(data.paths[1].nodes[1].links, [(2, 1)])
        # The objectives come out sorted, like the export of the fun-bots-helper.
        self.assertEqual(data.dumps(), self.TEXT.replace('["b","a"]', '["a","b"]'))

    def test_points_numbered_like_the_mod(self):
        data = MapData.parse(f"{HEADER}\n1;1;0;0;0;3;\n1;1;1;0;0;3;\n1;5;2;0;0;3;\n")
        self.assertEqual([node.point for node in data.paths[1].nodes], [1, 2, 3])
        self.assertEqual(data.node(1, 3).pos, (2.0, 0.0, 0.0))

    def test_set_loops_and_links(self):
        path = MapData.parse(self.TEXT).paths[1]
        path.loops = True
        self.assertEqual(path.first.input, 3)
        path.nodes[1].set_links([])
        self.assertEqual(path.nodes[1].data, {})

    def test_from_rows(self):
        data = MapData.from_rows({4: {"points": [[0, 0, 0], [1, 0, 0]], "inputs": [65283, 3],
                                      "data": {"1": {"Objectives": ["a"]}}}})
        self.assertEqual(data.paths[4].objectives, ["a"])
        self.assertFalse(data.paths[4].loops)


class LabelerTest(unittest.TestCase):
    def test_anchors_from_flags(self):
        names = {anchor.name: anchor.pos for anchor in anchors_from_flags(FLAGS)}
        self.assertEqual(names, {"a": (0, 0, 0), "b": (200, 0, 0), "base us": (-200, 0, 0), "base ru": (400, 0, 0)})

    def test_labels(self):
        data = level()
        result = label(data, anchors_from_flags(FLAGS))
        objectives = {index: path.objectives for index, path in data.paths.items()}
        self.assertEqual(objectives, {1: ["a"], 2: ["b"], 3: ["base us"], 4: ["base ru"], 5: ["a", "b"],
                                      6: ["a", "base us"], 7: ["b", "base ru"]})
        self.assertEqual(result.counts()["objectives"], 7)

    def test_loops(self):
        data = level()
        label(data, anchors_from_flags(FLAGS))
        self.assertTrue(all(data.paths[index].loops for index in (1, 2, 3, 4)))
        self.assertFalse(any(data.paths[index].loops for index in (5, 6, 7)))

    def test_links_join_the_ends_to_the_objective_paths(self):
        data = level()
        label(data, anchors_from_flags(FLAGS))
        joined = {(index, target[0]) for index, _, target in links(data)}
        for connection, objectives in ((5, (1, 2)), (6, (3, 1)), (7, (2, 4))):
            for objective in objectives:
                self.assertIn((connection, objective), joined)
                self.assertIn((objective, connection), joined)  # on both nodes
        # Both ends, not the middle.
        self.assertEqual({point for index, point, _ in links(data) if index == 5}, {1, len(data.paths[5].nodes)})

    def test_end_follows_its_trajectory(self):
        # 8 comes from the south and stops 15 m before the path a - b: out of end_radius, but it runs into it.
        data = level()
        data.paths[8] = PathData(8, [Node(8, point, (100.0, 0.0, float(z))) for point, z in
                                     enumerate(range(-60, -13, 2), start=1)])
        result = label(data, anchors_from_flags(FLAGS))
        end = data.paths[8].nodes[-1]
        self.assertEqual(len(end.links), 1)
        path, point = end.links[0]
        self.assertEqual(path, 5)
        self.assertAlmostEqual(data.node(path, point).pos[0], 100.0, delta=2.0)
        # The other end has nothing around: reported, not linked.
        self.assertEqual(data.paths[8].nodes[0].links, [])
        self.assertTrue(any(change.kind == "warning" and change.path == 8 and change.point == 1
                            for change in result.changes))

    def test_end_without_trajectory_joins_the_closest_path(self):
        # 8 runs parallel to a - b, 10 m away, and ends there: nothing ahead, the closest path is a - b.
        data = level()
        data.paths[8] = PathData(8, [Node(8, point, (float(x), 0.0, -10.0)) for point, x in
                                     enumerate(range(60, 142, 2), start=1)])
        label(data, anchors_from_flags(FLAGS))
        self.assertEqual([path for path, _ in data.paths[8].nodes[-1].links], [5])
        self.assertEqual([path for path, _ in data.paths[8].nodes[0].links], [5])

    def test_second_run_changes_nothing(self):
        data = level()
        label(data, anchors_from_flags(FLAGS))
        again = label(data, anchors_from_flags(FLAGS))
        self.assertEqual([change for change in again.changes if change.kind != "warning"], [])

    def test_offline_anchors_from_labels(self):
        data = level()
        label(data, anchors_from_flags(FLAGS))
        for index in (5, 6, 7):
            data.paths[index].objectives = []
        label(data, anchors_from_labels(data))
        self.assertEqual(data.paths[5].objectives, ["a", "b"])
        self.assertEqual(data.paths[6].objectives, ["a", "base us"])

    def test_junction_takes_over_objectives(self):
        # 8 starts at a and ends in the middle of the path a - b: it leads to a and b as well.
        data = level()
        data.paths[8] = PathData(8, [Node(8, point, pos) for point, pos in enumerate(
            [(0, 0, -15 - 2 * i) for i in range(20)] + [(2 * i, 0, -53) for i in range(50)] +
            [(100, 0, -53 + 2 * i) for i in range(27)], start=1)])
        label(data, anchors_from_flags(FLAGS))
        self.assertEqual(data.paths[8].objectives, ["a", "b"])

    def test_junction_passes_on_no_base(self):
        # 8 starts at a and ends in the middle of the path b - base ru, 100 m before the base: it leads to a and b.
        data = level()
        data.paths[8] = PathData(8, [Node(8, point, (float(x), 0.0, 40.0 - 0.14 * x)) for point, x in
                                     enumerate(range(10, 302, 2), start=1)])
        label(data, anchors_from_flags(FLAGS))
        self.assertEqual(data.paths[8].objectives, ["a", "b"])

    def test_base_only_at_the_base(self):
        # Like MP_012 ConquestSmall 24/45: a vehicle loop through a and b, labeled with the base far away.
        data = level()
        label(data, anchors_from_flags(FLAGS))
        steps = 300
        data.paths[8] = PathData(8, [Node(8, point, (100 + 100 * math.cos(i * 2 * math.pi / steps), 0.0,
                                                    100 * math.sin(i * 2 * math.pi / steps)))
                                     for point, i in enumerate(range(steps + 1), start=1)])
        data.paths[8].objectives = ["a", "base ru"]
        data.paths[8].first.data["Vehicles"] = ["land"]
        data.paths[9] = PathData(9, [Node(9, point, (20.0, 0.0, float(z))) for point, z in
                                     enumerate(range(20, 50, 2), start=1)])  # at a, leads nowhere else
        data.paths[9].objectives = ["a", "base ru"]
        offline = label(data, anchors_from_labels(data))  # the position of the base is a guess
        self.assertEqual(data.paths[8].objectives, ["a", "base ru"])
        self.assertNotIn(8, {change.path for change in offline.changes if change.kind == "objectives"})
        result = label(data, anchors_from_flags(FLAGS))
        self.assertEqual(data.paths[8].objectives, ["a", "b"])
        self.assertEqual(data.paths[9].objectives, ["a", "base ru"])  # a alone would make it a path of a
        self.assertTrue(any(change.kind == "warning" and change.path == 9 and "base" in change.message
                            for change in result.changes))
        self.assertEqual(data.paths[7].objectives, ["b", "base ru"])  # at the base: kept

    def test_keeps_other_objectives_and_vehicle_paths(self):
        data = level()
        data.paths[5].objectives = ["mcom 1"]
        data.paths[7].first.data["Vehicles"] = ["land"]
        data.paths[7].nodes = data.paths[7].nodes[:40]  # b to the open field, not into the base
        result = label(data, anchors_from_flags(FLAGS))
        self.assertEqual(data.paths[5].objectives, ["mcom 1"])
        self.assertEqual(data.paths[7].objectives, [])
        self.assertTrue(data.paths[7].loops)  # vehicle paths keep their loop
        self.assertFalse(any(index == 7 or target[0] == 7 for index, _, target in links(data)))
        self.assertTrue(any(index == 5 for index, _, _ in links(data)))  # only labeled by hand, but linked
        self.assertNotIn(7, {change.path for change in result.changes})

    def test_vehicles_leave_the_base(self):
        # Like MP_012 ConquestSmall 47: a vehicle path out of the base whose far end lies next to an unlabeled
        # vehicle path. Linked without options.vehicles, back and forth, and only the far end.
        data = level()
        data.paths[8] = PathData(8, [Node(8, point, (float(x), 0.0, 40.0)) for point, x in
                                     enumerate(range(-200, -58, 4), start=1)])
        data.paths[8].first.data["Vehicles"] = ["land"]
        data.paths[9] = PathData(9, [Node(9, point, (-40.0, 0.0, float(z))) for point, z in
                                     enumerate(range(100, -20, -4), start=1)])
        data.paths[9].first.data["Vehicles"] = ["land"]
        result = label(data, anchors_from_flags(FLAGS))
        self.assertFalse(data.paths[8].loops)
        self.assertEqual(data.paths[8].nodes[0].links, [])  # in the base
        self.assertEqual({target[0] for target in data.paths[8].nodes[-1].links}, {9})
        self.assertFalse(any(change.kind == "warning" and change.path == 8 for change in result.changes))

    def test_warns_if_vehicles_cant_leave_the_base(self):
        data = level()
        data.paths[8] = PathData(8, [Node(8, point, (float(x), 0.0, 60.0)) for point, x in
                                     enumerate(range(-200, -98, 4), start=1)])
        data.paths[8].first.data["Vehicles"] = ["land"]
        result = label(data, anchors_from_flags(FLAGS))
        self.assertTrue(any(change.kind == "warning" and change.path == 8 and "leave the base" in change.message
                            for change in result.changes))

    def test_vehicle_loop_with_objectives_stays_a_vehicle_path(self):
        # Like MP_007 ConquestLarge 153/154: a vehicle patrol loop with objectives (recorded in the vehicle, 4 m
        # between the nodes), and a vehicle path from a tank spawn to it.
        data = level()
        steps = 50
        data.paths[8] = PathData(8, [Node(8, point, (100 + 30 * math.cos(i * 2 * math.pi / steps), 0.0,
                                                    60 + 30 * math.sin(i * 2 * math.pi / steps)))
                                     for point, i in enumerate(range(steps + 1), start=1)])
        data.paths[8].objectives = ["a", "b"]
        data.paths[8].first.data["Vehicles"] = ["land"]
        data.paths[9] = PathData(9, [Node(9, point, (100.0, 0.0, float(z))) for point, z in
                                     enumerate(range(150, 88, -4), start=1)])
        data.paths[9].first.data["Vehicles"] = ["land"]
        data.paths[9].loops = False
        data.paths[10] = PathData(10, [Node(10, point, (100.0 + x, 0.0, 152.0)) for point, x in
                                       enumerate(range(20, -1, -2), start=1)])  # walk to the tank at the spawn
        data.paths[10].objectives = ["vehicle tank1 us"]
        data.paths[10].loops = False

        result = label(data, anchors_from_flags(FLAGS), Options(relabel=True))
        self.assertEqual(data.paths[8].objectives, ["a", "b"])
        # No foot path joins the vehicle network. The path from the spawn has to lead out though.
        foot = {1, 2, 3, 4, 5, 6, 7}
        self.assertFalse(any({index, target[0]} & {8, 9} and {index, target[0]} & foot
                             for index, _, target in links(data)))
        self.assertEqual({target[0] for target in data.paths[9].nodes[-1].links}, {8})

        label(data, anchors_from_flags(FLAGS), Options(vehicles=True))
        self.assertEqual(data.paths[9].nodes[0].links, [])  # at the spawn, no dead end
        self.assertFalse(any(8 in (index, target[0]) and 5 in (index, target[0]) for index, _, target in links(data)))
        self.assertFalse(any(change.kind == "warning" and change.path == 9 for change in result.changes))

    def test_walkable_flag_loop_with_vehicles(self):
        # Like the flag loops of MP_001 ConquestSmall: recorded on foot, vehicles may use them too.
        data = level()
        label(data, anchors_from_flags(FLAGS))
        before = {target for _, _, target in links(data) if target[0] == 1}
        data = level()
        data.paths[1].first.data["Vehicles"] = ["land"]
        data.paths[1].objectives = ["a"]
        label(data, anchors_from_flags(FLAGS))
        self.assertEqual({target for _, _, target in links(data) if target[0] == 1}, before)

    def test_foot_paths_avoid_the_vehicle_network(self):
        # Like MP_012 ConquestSmall: 8 loops through a and b for the vehicles (closed, recorded in the vehicle), 9 leads
        # out of the base. Both are linked to foot paths: soldiers never use them (PathSwitcher:IsWalkable).
        data = level()
        steps = 150
        data.paths[8] = PathData(8, [Node(8, point, (100 + 100 * math.cos(i * 2 * math.pi / steps), 0.0,
                                                    100 * math.sin(i * 2 * math.pi / steps)))
                                     for point, i in enumerate(range(steps + 1), start=1)])
        data.paths[8].objectives = ["a", "b"]
        data.paths[8].first.data["Vehicles"] = ["land"]
        data.paths[9] = PathData(9, [Node(9, point, (-200.0, 0.0, float(z))) for point, z in
                                     enumerate(range(0, 200, 4), start=1)])
        data.paths[9].first.data["Vehicles"] = ["land"]
        # 10: between a and b, recorded on foot, vehicles may use it too: walkable.
        data.paths[10] = PathData(10, [Node(10, point, pos) for point, pos in
                                       enumerate(straight(20, 180, -12), start=1)])
        data.paths[10].objectives = ["a", "b"]
        data.paths[10].first.data["Vehicles"] = ["land"]
        for a, b in (((8, 30), (5, 40)), ((9, 1), (3, 1)), ((10, 40), (5, 40))):
            data.node(*a).set_links(data.node(*a).links + [b])
            data.node(*b).set_links(data.node(*b).links + [a])
        labeler = Labeler(data, anchors_from_flags(FLAGS))
        self.assertEqual((labeler.kinds[8], labeler.kinds[9], labeler.kinds[10]), ("vehicle", "vehicle", "shared"))

        result = label(data, anchors_from_flags(FLAGS))
        pairs = {frozenset((index, target[0])) for index, _, target in links(data)}
        self.assertNotIn(frozenset((8, 5)), pairs)
        self.assertNotIn(frozenset((9, 3)), pairs)
        self.assertIn(frozenset((10, 5)), pairs)
        removed = [change for change in result.changes if change.kind == "link-removed"]
        self.assertEqual(len(removed), 2)  # once per link, not per node

    def test_existing_labels_stay_unless_relabel(self):
        data = level()
        data.paths[5].objectives = ["a"]
        label(data, anchors_from_flags(FLAGS))
        self.assertEqual(data.paths[5].objectives, ["a"])
        label(data, anchors_from_flags(FLAGS), Options(relabel=True))
        self.assertEqual(data.paths[5].objectives, ["a", "b"])

    def test_broken_links(self):
        data = level()
        data.paths[5].nodes[3].set_links([(99, 1), (1, 1)])  # nowhere, and one-sided
        result = label(data, anchors_from_flags(FLAGS))
        self.assertNotIn((99, 1), data.paths[5].nodes[3].links)
        self.assertIn((5, 4), data.node(1, 1).links)
        kinds = {change.kind for change in result.changes if change.path in (0, 5)}
        self.assertIn("link-removed", kinds)

    def test_relink(self):
        data = level()
        data.paths[5].nodes[40].set_links([(1, 1)])
        data.node(1, 1).set_links([(5, 41)])
        label(data, anchors_from_flags(FLAGS), Options(relink=True))
        self.assertNotIn((1, 1), data.paths[5].nodes[40].links)

    def test_crossings(self):
        data = level()
        data.paths[8] = PathData(8, [Node(8, point, (100.0, 0.0, z)) for point, z in
                                     enumerate(range(-40, 42, 2), start=1)])
        label(data, anchors_from_flags(FLAGS))
        self.assertFalse(any({index, target[0]} == {5, 8} for index, _, target in links(data)))
        label(data, anchors_from_flags(FLAGS), Options(crossings=True))
        self.assertTrue(any({index, target[0]} == {5, 8} for index, _, target in links(data)))

    def test_modes_without_objectives(self):
        self.assertTrue(uses_objectives("ConquestAssaultSmall0"))
        self.assertTrue(uses_objectives("SquadRush0"))
        self.assertFalse(uses_objectives("TeamDeathMatch0"))
        data = level()
        label(data, [Anchor("a", (0, 0, 0))], Options(objectives=False))
        self.assertEqual(data.paths[1].objectives, [])

    def test_patch(self):
        before, after = level(), level()
        label(after, anchors_from_flags(FLAGS))
        patch = make_patch(before, after)
        self.assertEqual(len(patch), 7)
        self.assertEqual(patch[0]["count"], len(before.paths[1].nodes))
        apply_patch(before, patch)
        self.assertEqual(before.dumps(), after.dumps())

    def test_patch_refuses_other_paths(self):
        before, after = level(), level()
        label(after, anchors_from_flags(FLAGS))
        patch = make_patch(before, after)
        edited = level()
        edited.paths[5].nodes.pop()
        with self.assertRaises(ValueError):
            apply_patch(edited, patch)
        self.assertEqual(edited.paths[1].objectives, [])  # nothing changed


class CliTest(unittest.TestCase):
    def test_write_with_flags(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "TEST_ConquestSmall0.map"
            level().save(file)
            flags = Path(folder) / "flags.json"
            flags.write_text(json.dumps({"objectives": {"flags": FLAGS}}))
            with redirect_stdout(io.StringIO()) as output:
                self.assertEqual(paths_main([str(file), "--flags", str(flags)]), 0)
            self.assertIn("7 objectives", output.getvalue())
            self.assertEqual(MapData.load(file).paths[5].objectives, [])  # no --write
            with redirect_stdout(io.StringIO()):
                paths_main([str(file), "--flags", str(flags), "--write"])
            self.assertEqual(MapData.load(file).paths[5].objectives, ["a", "b"])

    def test_cut_level_only_gets_links(self):
        # A level cut already (one navigation path): the mesh has the objectives, the paths get no names.
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "TEST_ConquestSmall0.map"
            data = level()
            data.paths[1].first.data["Nav"] = {"Length": 10.0}
            data.save(file)
            flags = Path(folder) / "flags.json"
            flags.write_text(json.dumps({"objectives": {"flags": FLAGS}}))
            with redirect_stdout(io.StringIO()):
                paths_main([str(file), "--flags", str(flags), "--write"])
            self.assertTrue(all(not path.objectives for path in MapData.load(file).paths.values()))


def nodes_events(data: MapData) -> list[dict]:
    """The waypoints as the mod streams them (DebugCommands.Nodes)."""
    events = [{"type": "nodes_started", "paths": len(data.paths), "t": 1}]
    for index, path in data.paths.items():
        events.append({"type": "nodes", "path": index, "first": 1, "points": [list(node.pos) for node in path.nodes],
                       "inputs": [node.input for node in path.nodes],
                       "data": [[node.point, node.data] for node in path.nodes if node.data], "last": True,
                       "objectives": path.objectives or None, "t": 1})
    return events


def labeled_frame():
    return {"t": 1, "meta": {"level": "Levels/TEST/TEST", "mode": "ConquestSmall0", "paths": "TEST_ConquestSmall0"},
            "objectives": {"flags": FLAGS, "mcoms": [], "stage": 0}}


class HubLabelsTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.mapfiles = Path(self.folder.name)
        self.hub = Hub(create_analyzers(), mapfiles=self.mapfiles)
        self.hub.ingest({"v": 1, "frames": [labeled_frame()], "events": nodes_events(level())})

    def tearDown(self):
        self.folder.cleanup()

    def test_needs_waypoints(self):
        hub = Hub(create_analyzers())
        with self.assertRaises(LabelError):
            hub.label_paths()

    def test_label_and_apply(self):
        labels = self.hub.label_paths({"relabel": False})
        self.assertEqual(labels["level"], "TEST_ConquestSmall0")
        self.assertEqual(labels["patched"], 7)
        self.assertEqual(self.hub.snapshot()["labels"]["patched"], 7)

        # The mod answers the paths_apply command with its next request.
        answer = {}
        thread = threading.Thread(target=lambda: answer.update(self.hub.apply_labels(save=True, timeout=5)))
        thread.start()
        for _ in range(100):
            commands = self.hub.ingest({"v": 1, "frames": [], "events": []})["commands"]
            if commands:
                break
            thread.join(0.02)
        self.assertEqual(commands[0]["type"], "paths_apply")
        self.assertTrue(commands[0]["args"]["save"])
        self.hub.ingest({"v": 1, "frames": [], "events": [
            {"type": "command_result", "id": commands[0]["id"], "ok": True, "data": {"paths": 7}, "t": 2}]})
        thread.join(5)
        self.assertEqual(answer["status"], "ok")
        self.assertIsNone(self.hub.labels)
        # The state holds the labels now, so a new run finds nothing.
        self.assertEqual(self.hub.state.paths[5]["objectives"], ["a", "b"])
        self.assertEqual(self.hub.label_paths()["patched"], 0)

    def test_write(self):
        level().save(self.mapfiles / "TEST_ConquestSmall0.map")
        self.hub.label_paths()
        result = self.hub.write_labels()
        self.assertEqual(result["paths"], 7)
        self.assertEqual(MapData.load(self.mapfiles / "TEST_ConquestSmall0.map").paths[6].objectives,
                         ["a", "base us"])

    def test_write_refuses_other_file(self):
        other = level()
        other.paths[5].nodes.pop()
        other.save(self.mapfiles / "TEST_ConquestSmall0.map")
        self.hub.label_paths()
        with self.assertRaises(LabelError):
            self.hub.write_labels()

    def test_new_waypoints_drop_the_labels(self):
        self.hub.label_paths()
        self.hub.ingest({"v": 1, "frames": [], "events": nodes_events(level())})
        self.assertIsNone(self.hub.labels)
        with self.assertRaises(LabelError):
            self.hub.write_labels()


if __name__ == "__main__":
    unittest.main()
