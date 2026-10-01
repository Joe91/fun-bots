"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.paths.bases import Stage, check, fix  # noqa: E402
from funbots_debug.paths.fix_bases import main as fix_bases_main  # noqa: E402
from funbots_debug.paths.mapfile import MapData  # noqa: E402
from test_paths import links, loop, make_map, straight  # noqa: E402


def link(data: MapData, a: tuple[int, int], b: tuple[int, int]) -> None:
    data.node(*a).set_links(data.node(*a).links + [b])
    data.node(*b).set_links(data.node(*b).links + [a])


def rush() -> MapData:
    """Stage 1: a base-path with a way out. Stage 2: the way out of a base names the MCOM of stage 1, a base-path only
    leads to a vehicle, and two base-paths have no links at all."""
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
    })
    link(data, (1, 4), (2, 1))
    link(data, (4, 4), (5, 1))
    link(data, (6, 1), (7, 1))
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
        found = {(dead.stage, dead.path): dead.reason for dead in check(rush(), "RushLarge0")}
        self.assertEqual(set(found), {(2, 4), (2, 6), (2, 9), (2, 10)})
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
        # A path without objectives is never active: no way out.
        self.assertEqual([dead.path for dead in check(data, "ConquestSmall0")], [3])


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
        added = [change for change in self.result.changes if change.kind == "link-added"]
        self.assertEqual([change.path for change in added], [6])  # path 4 got out by the relabel
        # On both nodes.
        point, target = added[0].point, added[0].target
        self.assertIn((6, point), self.data.node(*target).links)

    def test_removes_a_base_path_without_links(self):
        self.assertNotIn(9, self.data.paths)
        # The only path of its base stays, reported.
        self.assertIn(10, self.data.paths)
        warnings = [change.path for change in self.result.changes if change.kind == "warning"]
        self.assertEqual(warnings, [10])

    def test_nothing_left(self):
        self.assertEqual([dead.path for dead in check(self.data, "RushLarge0")], [10])
        self.assertEqual(fix(self.data, "RushLarge0").counts(), {"warning": 1})


class CliTest(unittest.TestCase):
    def test_write(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "MP_999_RushLarge0.map"
            rush().save(file)
            output = io.StringIO()
            with redirect_stdout(output):
                fix_bases_main([str(file)])
            self.assertIn("1 link-added", output.getvalue())
            self.assertEqual(MapData.load(file).dumps(), rush().dumps())  # only reported
            with redirect_stdout(io.StringIO()):
                fix_bases_main([str(file), "--write"])
            self.assertNotIn(9, MapData.load(file).paths)


if __name__ == "__main__":
    unittest.main()
