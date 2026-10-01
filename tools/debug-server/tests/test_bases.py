"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.paths.bases import Options, Stage, _relabel, check, fix  # noqa: E402
from funbots_debug.paths.fix_bases import main as fix_bases_main  # noqa: E402
from funbots_debug.paths.routes import Play, Situation, check as check_routes  # noqa: E402
from funbots_debug.paths.mapfile import MapData  # noqa: E402
from test_paths import links, loop, make_map, straight  # noqa: E402


def link(data: MapData, a: tuple[int, int], b: tuple[int, int]) -> None:
    data.node(*a).set_links(data.node(*a).links + [b])
    data.node(*b).set_links(data.node(*b).links + [a])


def rush() -> MapData:
    """Stage 1: a base-path with a way out, the path out of the base isn't linked to its MCOM. Stage 2: the path out of
    the base names the MCOM of stage 1, a base-path only leads to a vehicle, and two base-paths have no links at all."""
    data = make_map({
        1: straight(0, 6),  # base us 1
        2: straight(8, 100),  # base us 1 - mcom 1
        3: loop(100),  # mcom 1
        4: straight(200, 206),  # base us 2
        5: straight(208, 300),  # base us 2 - "mcom 1", ends at mcom 3
        6: straight(200, 204, 10),  # base us 2, only to a vehicle
        7: straight(196, 190, 10),  # vehicle
        8: loop(300),  # mcom 3
        9: straight(500, 504),  # base us 2, nothing around
        10: straight(-500, -496),  # base ru 2, nothing around, its only path
        11: straight(250, 260, 2),  # mcom 3 - mcom 4, along path 5
    }, {
        1: {"Objectives": ["base us 1"]},
        2: {"Objectives": ["base us 1", "mcom 1"]},
        3: {"Objectives": ["mcom 1"]},
        4: {"Objectives": ["base us 2"]},
        5: {"Objectives": ["base us 2", "mcom 1"]},
        6: {"Objectives": ["base us 2"]},
        7: {"Objectives": ["vehicle tank1 us"]},
        8: {"Objectives": ["mcom 3"]},
        9: {"Objectives": ["base us 2"]},
        10: {"Objectives": ["base ru 2"]},
        11: {"Objectives": ["mcom 3", "mcom 4"]},
    })
    link(data, (1, 4), (2, 1))
    link(data, (4, 4), (5, 1))
    link(data, (6, 1), (7, 1))
    link(data, (8, 1), (11, 6))  # mcom 3 - mcom 4
    return data


class StageTest(unittest.TestCase):
    def test_active_objectives_of_a_rush_stage(self):
        stage = Stage(rush(), "RushLarge0", 2)
        self.assertTrue(stage.active["base us 2"])
        self.assertTrue(stage.active["mcom 3"])
        self.assertFalse(stage.active["mcom 1"])
        self.assertFalse(stage.active["base us 1"])
        self.assertFalse(stage.active["vehicle tank1 us"])

    def test_way_out(self):
        data = rush()
        stage = Stage(data, "RushLarge0", 1)
        self.assertTrue(stage.way_out(data.paths[2]))  # all active, more than the base
        self.assertFalse(stage.way_out(data.paths[1]))  # a base alone
        self.assertFalse(stage.way_out(data.paths[7]))  # to a vehicle
        self.assertFalse(stage.way_out(data.paths[2], "ru"))  # through the base of the other team
        self.assertFalse(Stage(data, "RushLarge0", 2).way_out(data.paths[5]))  # partly active


class CheckTest(unittest.TestCase):
    def test_dead_ends(self):
        dead_ends = check(rush(), "RushLarge0")
        found = {(dead.stage, dead.path): dead.reason for dead in dead_ends}
        self.assertEqual(set(found), {(1, 2), (2, 5), (2, 4), (2, 6), (2, 9), (2, 10)})
        # The paths out of a base first: only a path without a base gets a bot off them.
        self.assertEqual([dead.kind for dead in dead_ends[:2]], ["connection"] * 2)
        self.assertIn("1 [base us 1] base-path", found[(1, 2)])
        self.assertIn("partly active", found[(2, 4)])
        self.assertIn("to a vehicle", found[(2, 6)])
        self.assertEqual(found[(2, 9)], "no links")

    def test_no_bases_without_objectives(self):
        self.assertEqual(check(rush(), "TeamDeathMatch0"), [])

    def test_conquest(self):
        data = make_map({1: straight(0, 6), 2: straight(8, 100), 3: straight(0, 6, 50), 4: straight(8, 100, 50)},
                        {1: {"Objectives": ["base us"]}, 2: {"Objectives": ["a", "base us"]},
                         3: {"Objectives": ["base us"]}})
        link(data, (1, 4), (2, 1))
        link(data, (3, 4), (4, 1))
        # A path without objectives is never active: no way out. Path 2 leads to "a", but isn't linked to it.
        self.assertEqual([dead.path for dead in check(data, "ConquestSmall0")], [2, 3])


class FixTest(unittest.TestCase):
    def setUp(self):
        self.data = rush()
        self.result = fix(self.data, "RushLarge0")

    def test_relabels_the_mcom_of_another_stage(self):
        self.assertEqual(self.data.paths[5].objectives, ["base us 2", "mcom 3"])
        self.assertEqual(self.data.paths[2].objectives, ["base us 1", "mcom 1"])  # right stage, kept

    def test_relinks_to_the_closest_way_out(self):
        new = {(index, point, target) for index, point, target in links(self.data) if index == 6}
        self.assertEqual({target[0] for _, _, target in new}, {5, 7})
        added = {change.path: change for change in self.result.changes if change.kind == "link-added"}
        self.assertEqual(set(added), {2, 5, 6})  # path 4 got out over path 5
        # On both nodes.
        point, target = added[6].point, added[6].target
        self.assertIn((6, point), self.data.node(*target).links)

    def test_links_a_path_out_of_a_base_to_its_objective(self):
        added = {change.path: change for change in self.result.changes if change.kind == "link-added"}
        self.assertEqual(added[2].target[0], 3)
        # Where it reaches mcom 1 (the loop around x=100 with 15 m radius).
        self.assertLessEqual(abs(self.data.node(2, added[2].point).pos[0] - 100.0), 16.0)
        # The path of its MCOM, not the closer path that only passes it.
        self.assertEqual(added[5].target[0], 8)

    def test_removes_a_base_path_without_links(self):
        self.assertNotIn(9, self.data.paths)
        # The only path of its base stays, reported.
        self.assertIn(10, self.data.paths)
        warnings = [change.path for change in self.result.changes if change.kind == "warning"]
        self.assertEqual(warnings, [10])

    def test_nothing_left(self):
        self.assertEqual([dead.path for dead in check(self.data, "RushLarge0")], [10])
        self.assertEqual(fix(self.data, "RushLarge0").counts(), {"warning": 1})


def mcoms() -> MapData:
    """Stage 1 of rush: the paths of mcom 1 and mcom 2 are only joined by a path that is partly active (stage 1 and 2),
    a path between both MCOMs passes path 1 at 5 m."""
    data = make_map({
        1: loop(0),  # mcom 1
        2: loop(100),  # mcom 2
        3: straight(15, 85),  # mcom 2 - mcom 3
        4: straight(20, 80, 20),  # mcom 1 - mcom 2, not linked
    }, {
        1: {"Objectives": ["mcom 1"]},
        2: {"Objectives": ["mcom 2"]},
        3: {"Objectives": ["mcom 2", "mcom 3"]},
        4: {"Objectives": ["mcom 1", "mcom 2"]},
    })
    link(data, (1, 1), (3, 1))
    link(data, (2, len(data.paths[2].nodes) // 2 + 1), (3, len(data.paths[3].nodes)))
    link(data, (2, 1), (4, len(data.paths[4].nodes)))
    return data


class MisplacedTest(unittest.TestCase):
    def level(self) -> MapData:
        """Stage 2: the MCOMs at x=6 (3) and x=106 (4), their interact-paths end there, mcom 1 and 2 far away. Path 3
        loops around mcom 4 but is labeled mcom 2, path 4 goes from mcom 3 to mcom 4 but names mcom 2, path 5 names
        mcom 1 and isn't near anything."""
        return make_map({
            1: straight(0, 6, 30),  # mcom 3 interact
            2: straight(100, 106, 30),  # mcom 4 interact
            3: loop(100),
            4: straight(5, 95, 20),
            5: straight(500, 520),
            6: straight(-200, -206, 30),  # mcom 1 interact
            7: straight(-300, -306, 30),  # mcom 2 interact
        }, {
            1: {"Objectives": ["mcom 3 interact"]},
            2: {"Objectives": ["mcom 4 interact"]},
            3: {"Objectives": ["mcom 2"]},
            4: {"Objectives": ["mcom 2", "mcom 3"]},
            5: {"Objectives": ["mcom 1"]},
            6: {"Objectives": ["mcom 1 interact"]},
            7: {"Objectives": ["mcom 2 interact"]},
        })

    def test_relabels_mcoms_the_path_doesnt_come_near(self):
        data = self.level()
        changes = []
        _relabel(data, "RushLarge0", Options(), changes)
        self.assertEqual(data.paths[3].objectives, ["mcom 4"])
        self.assertEqual(data.paths[4].objectives, ["mcom 3", "mcom 4"])
        self.assertEqual(data.paths[5].objectives, ["mcom 1"])  # nothing near: only reported
        self.assertEqual([change.path for change in changes if change.kind == "warning"], [5])


class RoutesTest(unittest.TestCase):
    def test_stuck(self):
        data = mcoms()
        stuck = {(entry.situation.team, entry.situation.target, entry.situation.destroyed): entry.paths
                 for entry in check_routes(data, "RushLarge0")}
        # mcom 1 to mcom 2 only over path 3, which is partly active: no way. Once mcom 1 is destroyed the bots leave
        # it anyways, over path 3 to mcom 2.
        self.assertEqual(stuck, {("us", "mcom 2", None): [1], ("ru", "mcom 2", None): [1]})

    def test_leaves_a_destroyed_mcom(self):
        data = mcoms()
        stage = Stage(data, "RushLarge0", 1)
        play = Play(data, stage, Situation(1, "us", "mcom 2", "mcom 1"))
        self.assertEqual(play.at_node(data.paths[1], data.node(1, 1)), {3})
        self.assertEqual(Play(data, stage, Situation(1, "us", "mcom 2")).at_node(data.paths[1], data.node(1, 1)), set())

    def test_fix(self):
        data = mcoms()
        result = fix(data, "RushLarge0")
        added = [change for change in result.changes if change.kind == "link-added"]
        self.assertEqual([(change.path, change.target[0]) for change in added], [(1, 4)])
        self.assertEqual(check_routes(data, "RushLarge0"), [])

    def test_only_rush(self):
        self.assertEqual(check_routes(mcoms(), "ConquestSmall0"), [])


class CliTest(unittest.TestCase):
    def test_write(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "MP_999_RushLarge0.map"
            rush().save(file)
            output = io.StringIO()
            with redirect_stdout(output):
                fix_bases_main([str(file)])
            self.assertIn("3 link-added", output.getvalue())
            self.assertEqual(MapData.load(file).dumps(), rush().dumps())  # only reported
            with redirect_stdout(io.StringIO()):
                fix_bases_main([str(file), "--write"])
            self.assertNotIn(9, MapData.load(file).paths)


if __name__ == "__main__":
    unittest.main()
