"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug import maps  # noqa: E402
from funbots_debug.paths.mapfile import MapData, Node, PathData  # noqa: E402


def _data(cut: bool = False) -> MapData:
    nodes = [Node(1, point, (float(point), 0.0, 2.5), 3) for point in range(1, 4)]
    nodes[0].data["Links"] = [[1, 3]]
    if cut:
        nodes[0].data["Nav"] = {"From": "a", "To": "b", "Length": 2.0}
    return MapData({1: PathData(1, nodes)})


class MapsTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        root = Path(self.folder.name)
        self.mapfiles, self.navzones, self.census = root / "mapfiles", root / "navzones", root / "census"
        for folder in (self.mapfiles, self.navzones, self.census):
            folder.mkdir()
        self.db = root / "mod.db"

    def tearDown(self):
        self.folder.cleanup()

    def states(self):
        return {state["name"]: state for state in maps.level_states(self.mapfiles, self.navzones, self.census,
                                                                    self.db, Path(self.folder.name))}

    def test_import_and_export_give_the_same_waypoints(self):
        data = _data()
        maps.import_map(self.db, "MP_001_TeamDeathMatch0", data, None)
        self.assertEqual(maps.export_map(self.db, "MP_001_TeamDeathMatch0").dumps(), data.dumps())

    def test_new_level_with_mesh_needs_import_census_and_cut(self):
        _data().save(self.mapfiles / "MP_001_RushLarge0.map")
        state = self.states()["MP_001_RushLarge0"]
        self.assertEqual((state["kind"], state["db"], state["cut"]), ("mesh", "missing", False))
        self.assertEqual(state["missing"], ["import", "census", "cut", "check"])

    def test_cut_level_in_mod_db_is_done(self):
        data = _data(cut=True)
        data.save(self.mapfiles / "MP_001_ConquestLarge0.map")
        networks = {"version": 2, "points": [], "edges": [], "attach": [], "zones": [{"name": "a"}]}
        (self.navzones / "MP_001_ConquestLarge0.json").write_text(json.dumps(networks), encoding="utf-8")
        maps.import_map(self.db, "MP_001_ConquestLarge0", data, networks)
        state = self.states()["MP_001_ConquestLarge0"]
        self.assertEqual((state["db"], state["dbMesh"], state["missing"]), ("same", "same", ["check"]))
        (self.census / "MP_001_ConquestLarge0.checks.json").write_text("{}", encoding="utf-8")
        self.assertEqual(self.states()["MP_001_ConquestLarge0"]["missing"], [])

    def test_paths_only_level_differs_from_mod_db(self):
        data = _data()
        data.save(self.mapfiles / "MP_001_GunMaster0.map")
        other = _data()
        other.paths[1].nodes[1].pos = (9.0, 0.0, 9.0)
        maps.import_map(self.db, "MP_001_GunMaster0", other, None)
        state = self.states()["MP_001_GunMaster0"]
        self.assertEqual((state["kind"], state["db"], state["missing"]), ("paths", "differs", ["import"]))


if __name__ == "__main__":
    unittest.main()
