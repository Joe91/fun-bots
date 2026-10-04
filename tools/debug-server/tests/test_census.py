"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import math
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.census.report import area_graph, build_report  # noqa: E402
from funbots_debug.census.store import load  # noqa: E402
from funbots_debug.hub import CENSUS_SCAN_BASE, Hub  # noqa: E402


def _nodes_event(path, points, **fields):
    count = len(points)
    event = {"type": "census_nodes", "census": 1, "path": path, "first": 1, "last": True, "loops": False,
             "points": points, "inputs": [3] * count, "ground": [0.0] * count, "normal": [1.0] * count,
             "water": [False] * count, "ceiling": [False] * count, "left": [2.0] * count, "right": [False] * count,
             "next": [[False, False, False]] * (count - 1) + [False], "nextHit": [False] * count, "links": [],
             "actions": [], "objectives": ["a"]}
    event.update(fields)
    return event


def _census_events():
    walk = [[float(x), 0.0, 0.0] for x in range(10)]
    return [
        {"type": "census_started", "census": 1, "level": "Levels/MP_001/MP_001", "mode": "ConquestLarge0",
         "paths": "MP_001_ConquestLarge0", "parts": ["entities", "nodes", "areas"]},
        {"type": "census_entities", "census": 1, "data": {
            "capturePoints": [
                {"name": "CP_A", "objective": "a", "pos": [5.0, 0.0, 0.0], "radius": 10.0, "hq": False},
                {"name": "CP_B", "objective": "b", "pos": [500.0, 0.0, 0.0], "radius": 10.0, "hq": False}],
            "combatAreas": [{"team": 1, "teamSpecific": False,
                             "shapes": [{"points": [[-50, 0, -50], [50, 0, -50], [50, 0, 50], [-50, 0, 50]]}]}],
            "spawns": [], "vehicleSpawns": [], "errors": []}},
        # Point 3 floats 2 m over the ground, the way from point 5 is a wall.
        _nodes_event(1, walk, ground=[0.0, 0.0, -2.0] + [0.0] * 7,
                     next=[[False, False, False]] * 4 + [[0.5, 0.5, 0.5]] + [[False, False, False]] * 4 + [False]),
        {"type": "census_area", "census": 1, "area": 1, "name": "a", "kind": "capturepoint",
         "center": [5.0, 0.0, 0.0], "radius": 2.0, "x0": 3.0, "z0": -2.0, "step": 1.0, "columns": 5, "rows": 5,
         "layers": 2},
        *[{"type": "census_area_row", "census": 1, "area": 1, "row": row,
           # Flat floor, a wall between column 2 and 3 (chest-ray of column 2 to +x hits).
           "cells": [[0.0, 1.0, 2 if column == 2 else 0, -1] for column in range(5)]} for row in range(5)],
        {"type": "census_done", "census": 1, "raycasts": 123, "seconds": 1.5, "nodes": 10, "cells": 25},
    ]


class CensusTest(unittest.TestCase):
    def test_hub_collects_saves_and_reports(self):
        with tempfile.TemporaryDirectory() as folder:
            hub = Hub([], census=Path(folder))
            hub.ingest({"v": 1, "seq": 1, "frames": [], "events": _census_events()})

            for _ in range(100):
                if hub.census_report is not None:
                    break
                time.sleep(0.05)
            self.assertIsNotNone(hub.census_report)

            file = Path(folder) / "MP_001_ConquestLarge0.json.gz"
            census = load(file)
            self.assertEqual(len(census["nodes"]["1"]["points"]), 10)
            self.assertEqual(len(census["areas"][0]["cells"]), 5)

            # The grid shows up as scan, census-events stay out of the log.
            self.assertIn(CENSUS_SCAN_BASE + 100 + 1, hub.state.scans)
            self.assertFalse(any(str(event.get("type")).startswith("census") for event in hub.state.log))

            kinds = hub.census_report.counts()
            self.assertEqual(kinds.get("floating"), 1)
            self.assertEqual(kinds.get("wall"), 1)
            self.assertEqual(kinds.get("capture-uncovered"), 1)  # b has no waypoint
            self.assertNotIn("out-of-area", kinds)

            findings = hub.snapshot()["analysis"]["findings"]
            self.assertTrue(any(finding["analyzer"] == "census" for finding in findings))

    def test_area_graph_respects_walls(self):
        area = {"cells": [[[0.0, 1.0, 2 if column == 1 else 0, -1] for column in range(3)]]}
        surfaces, links = area_graph(area)
        self.assertEqual(len(surfaces), 3)
        self.assertIn((0, 1, 0), links[(0, 0, 0)])
        self.assertNotIn((0, 2, 0), links[(0, 1, 0)])

    def test_out_of_area(self):
        # Each team gets the smallest shape around its HQ, the big one (aircraft) counts for nobody.
        big = {"points": [[-500, 0, -500], [500, 0, -500], [500, 0, 500], [-500, 0, 500]]}
        team1 = {"points": [[-50, 0, -50], [50, 0, -50], [50, 0, 50], [-50, 0, 50]]}
        team2 = {"points": [[-60, 0, -60], [60, 0, -60], [60, 0, 60], [-60, 0, 60]]}
        census = {"nodes": {"1": _nodes_event(1, [[100.0, 0.0, 0.0], [101.0, 0.0, 0.0]])},
                  "entities": {
                      "capturePoints": [{"name": "US_HQ", "hq": True, "team": 1, "pos": [0, 0, 0]},
                                        {"name": "RU_HQ", "hq": True, "team": 2, "pos": [55, 0, 0]}],
                      "combatAreas": [{"teamSpecific": True, "team": team, "shapes": [team1, big, team2]}
                                      for team in (1, 2)]}}
        report = build_report(census)
        self.assertEqual(report.counts().get("out-of-area"), 1)
        self.assertIn("team 1: 0.01 km²", report.summary["combat area"])

    def test_zone_estimator(self):
        from funbots_debug.census.zones import ZoneEstimator
        from funbots_debug.state import WorldState

        state = WorldState()
        state.apply_frame({"t": 1.0, "meta": {"level": "Levels/MP_001/MP_001", "mode": "ConquestLarge0"},
                           "bots": [{"id": 1, "alive": True, "pos": [8.0, 0.0, 0.0]},
                                    {"id": 2, "alive": True, "pos": [0.0, 0.0, 12.0]}],
                           "players": [],
                           "objectives": {"flags": [{"name": "CP_A", "pos": [0.0, 0.0, 0.0], "inside": [1]}]}})
        zones = ZoneEstimator()
        zones.on_frame(state)
        zone = zones.to_json()[0]
        self.assertEqual((zone["radius"], zone["outside"], zone["samples"]), (8.0, 12.0, 1))

    def test_zone_probe(self):
        from funbots_debug.census.report import capture_points
        from funbots_debug.census.zones import ZoneEstimator
        from funbots_debug.hub import Hub

        # 10 m to the east half (+x), 30 m to the west half: the shape, not a circle of 30 m.
        directions = [{"angle": index * 2 * math.pi / 16, "inside": 10.0 if index < 4 or index >= 12 else 30.0,
                       "outside": 40.0} for index in range(16)]
        flags = [{"name": "ID_H_US_A", "pos": [0.0, 0.0, 0.0], "active": True, "directions": directions},
                 {"name": "ID_H_US_C", "pos": [200.0, 0.0, 0.0], "active": False, "directions": []}]
        zones = ZoneEstimator()
        zones.apply_probe(flags)
        result = {zone["name"]: zone for zone in zones.to_json()}
        self.assertEqual((result["ID_H_US_A"]["radius"], result["ID_H_US_A"]["samples"]), (30.0, 16))
        self.assertEqual((result["ID_H_US_C"]["samples"], result["ID_H_US_C"]["active"]), (0, False))

        census = {"zones": zones.to_json(), "entities": {"capturePoints": [
            {"name": "ID_H_US_A", "pos": [0.0, 0.0, 0.0], "objective": "a"},
            {"name": "ID_H_US_C", "pos": [200.0, 0.0, 0.0], "objective": "c"}]}}
        points = {point["name"]: point for point in capture_points(census)}
        self.assertFalse(points["ID_H_US_A"]["inactive"])
        self.assertTrue(points["ID_H_US_C"]["inactive"])
        cell = points["ID_H_US_A"]["cell"]
        self.assertIn((math.floor(-25 / cell), 0), points["ID_H_US_A"]["zoneCells"])  # 25 m west: inside
        self.assertNotIn((math.floor(20 / cell), 0), points["ID_H_US_A"]["zoneCells"])  # 20 m east: outside

        # The census areas: the measured one, not the one nobody is inside of.
        hub = Hub([])
        hub.state.objectives = {"flags": [dict(flag, objective=flag["name"][-1].lower()) for flag in flags]}
        hub.zones.apply_probe(flags)
        self.assertEqual([(area["name"], area["radius"]) for area in hub._census_areas()], [("a", 45.0)])


def _rooms_area(door: bool) -> dict:
    """Two flat 10 x 10 m rooms side by side (0.5 m cells), a wall between them at column 20, with a door or not."""
    rows = []
    for row in range(20):
        cells = []
        for column in range(41):
            if column == 20:
                cells.append([0.0, 1.0, 0, -1] if door and 9 <= row <= 11 else False)
            else:
                cells.append([0.0, 1.0, 0, -1])
        rows.append(cells)
    return {"name": "a", "kind": "capturepoint", "center": [10.0, 0.0, 5.0], "radius": 30.0, "x0": 0.0,
            "z0": 0.0, "step": 0.5, "columns": 41, "rows": 20, "layers": 1, "cells": rows}


class NavzonesTest(unittest.TestCase):
    def _build(self, door):
        from funbots_debug.census import navzones
        census = {"paths": "MP_001_ConquestLarge0", "areas": [_rooms_area(door)], "entities": {},
                  "nodes": {"1": _nodes_event(1, [[2.0, 0.0, 5.0], [3.0, 0.0, 5.0]]),
                            "2": _nodes_event(2, [[17.0, 0.0, 5.0], [18.0, 0.0, 5.0]])}}
        return navzones.build(census)

    def _connected(self, zone):
        links = {}
        for a, b, *_ in zone["edges"]:
            links.setdefault(a, set()).add(b)
            links.setdefault(b, set()).add(a)
        seen, todo = {0}, [0]
        while todo:
            for other in links.get(todo.pop(), ()):
                if other not in seen:
                    seen.add(other)
                    todo.append(other)
        return len(seen) == len(zone["points"])

    def test_door_connects_rooms(self):
        zone = self._build(door=True)
        self.assertGreaterEqual(len(zone["points"]), 4)
        self.assertTrue(self._connected(zone))
        # Both paths are attached at both ends.
        self.assertEqual(sorted((path, point) for path, point, *_ in zone["attach"]), [(1, 1), (1, 2), (2, 1), (2, 2)])
        # No connection goes through the wall: every edge crosses column 20 (x = 10 m) only at the door.
        for a, b, _, corners, *_ in zone["edges"]:
            line = [zone["points"][a]] + corners + [zone["points"][b]]
            for p, q in zip(line, line[1:]):
                if (p[0] - 10.0) * (q[0] - 10.0) < 0:
                    t = (10.0 - p[0]) / (q[0] - p[0])
                    self.assertTrue(4.0 <= p[2] + t * (q[2] - p[2]) <= 6.0)

    def test_path_end_without_surface_attached_to_closest_point(self):
        # The ends of path 4 lie in a gap the census has no surfaces in (stairs down into a metro), 2.5 m from the
        # first room: attached straight to its closest point there.
        from funbots_debug.census import navzones
        area = _rooms_area(False)
        for cells in area["cells"]:
            for column in range(20, 31):
                cells[column] = False
        census = {"paths": "MP_001_ConquestLarge0", "areas": [area], "entities": {},
                  "nodes": {"1": _nodes_event(1, [[2.0, 0.0, 5.0], [3.0, 0.0, 5.0]])}}
        zone = navzones.build(census, attach={4: {"points": [[12.5, 0.0, 5.0], [12.5, 0.0, 7.0]], "vehicles": [],
                                                   "objectives": []}})
        ends = {(path, point): (network, corners) for path, point, network, _, _, corners in zone["attach"]}
        self.assertIn((4, 1), ends)
        self.assertEqual(ends[(4, 1)][1], [])
        self.assertLess(zone["points"][ends[(4, 1)][0]][0], 10.0)

    def test_wall_separates_rooms(self):
        zone = self._build(door=False)
        self.assertEqual(zone["stats"]["parts"], 2)
        self.assertFalse(self._connected(zone))

    def test_trace_joins_parts(self):
        # No door, but path 3 walks from one room into the other (e.g. over stairs the grid doesn't see).
        from funbots_debug.census import navzones
        census = {"paths": "MP_001_ConquestLarge0", "areas": [_rooms_area(False)], "entities": {},
                  "nodes": {"3": _nodes_event(3, [[float(x), 0.0, 5.0] for x in range(2, 19)])}}
        zone = navzones.build(census)
        self.assertTrue(self._connected(zone))

    def test_overlapping_areas_one_mesh(self):
        # Two areas over the same flat ground, shifted by 6.25 m (a quarter cell off the lattice): one mesh, both zones
        # on it.
        from funbots_debug.census import navzones
        first = _rooms_area(True)
        second = dict(_rooms_area(True), name="b", center=[16.25, 0.0, 5.0], x0=6.25)
        census = {"paths": "MP_001_ConquestLarge0", "areas": [first, second], "entities": {},
                  "nodes": {"1": _nodes_event(1, [[2.0, 0.0, 5.0], [3.0, 0.0, 5.0]])}}
        data = navzones.build(census)
        self.assertTrue(self._connected(data))
        points = data["points"]
        for i, p in enumerate(points):
            for q in points[i + 1:]:
                self.assertGreaterEqual(((p[0] - q[0]) ** 2 + (p[2] - q[2]) ** 2) ** 0.5, navzones.SPACING - 0.01)
        zones = {zone["name"]: zone for zone in data["zones"]}
        self.assertEqual(set(zones), {"a", "b"})
        self.assertTrue(zones["a"]["inside"] and zones["b"]["inside"])
        # The x of the second area is off the lattice by a quarter cell: the merged grid puts it onto it.
        self.assertTrue(all(abs(p[0] / 0.5 - round(p[0] / 0.5)) < 1e-6 for p in points))


class DriverTest(unittest.TestCase):
    def test_level_matches_waits_for_the_waypoints_of_the_mode(self):
        from funbots_debug.census.__main__ import _level_matches
        # Same level, the game already reports the next mode, the waypoints are still the ones of the old mode.
        meta = {"level": "Levels/MP_012/MP_012", "mode": "RushLarge0", "paths": "MP_012_ConquestSmall0"}
        self.assertFalse(_level_matches(meta, "MP_012", "RushLarge0"))
        meta["paths"] = "MP_012_RushLarge0"
        self.assertTrue(_level_matches(meta, "MP_012", "RushLarge0"))
        self.assertTrue(_level_matches({"level": "Levels/MP_001/MP_001", "mode": "RushLarge0"}, "MP_001", "RushLarge0"))


if __name__ == "__main__":
    unittest.main()
