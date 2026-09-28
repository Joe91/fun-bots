"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import json
import sys
import tempfile
import threading
import unittest
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from funbots_debug.analyzers import create_analyzers  # noqa: E402
from funbots_debug.analyzers.combat import CombatAnalyzer  # noqa: E402
from funbots_debug.analyzers.stuck import StuckBotAnalyzer  # noqa: E402
from funbots_debug.hub import Hub  # noqa: E402
from funbots_debug.protocol import as_list, yaw_to_direction  # noqa: E402
from funbots_debug.recorder import Recorder, read_recording, replay  # noqa: E402
from funbots_debug.server import DebugServer  # noqa: E402

LEVEL = "Levels/MP_001/MP_001"


def bot(bot_id, pos, team=1, state="Moving", target=-1, **extra):
    entry = {"id": bot_id, "name": f"BOT_{bot_id}", "team": team, "alive": True, "state": state,
             "action": "NoActionActive", "target": target, "pos": list(pos), "yaw": 0.0}
    entry.update(extra)
    return entry


def frame(t, bots=(), level=LEVEL, **extra):
    data = {"t": t, "meta": {"level": level, "mode": "ConquestLarge0"}, "bots": list(bots), "players": [],
            "vehicles": []}
    data.update(extra)
    return data


def payload(frames=(), events=()):
    return {"v": 1, "seq": 1, "frames": list(frames), "events": list(events), "dropped": 0}


class ProtocolTest(unittest.TestCase):
    def test_as_list(self):
        self.assertEqual(as_list(None), [])
        self.assertEqual(as_list({}), [])
        self.assertEqual(as_list([1, 2]), [1, 2])
        self.assertEqual(as_list({"2": "b", "1": "a", "10": "c"}), ["a", "b", "c"])

    def test_yaw(self):
        x, z = yaw_to_direction(0.0)
        self.assertAlmostEqual(x, 0.0)
        self.assertAlmostEqual(z, 1.0)


class HubTest(unittest.TestCase):
    def setUp(self):
        self.hub = Hub(create_analyzers())

    def test_frame_updates_state(self):
        self.hub.ingest(payload([frame(1.0, [bot(1, (0, 0, 0)), bot(2, (5, 0, 5), team=2)])]))
        self.assertEqual(set(self.hub.state.bots), {1, 2})
        self.assertEqual(self.hub.state.level, LEVEL)
        self.assertTrue(self.hub.mod_connected)

    def test_empty_lua_tables(self):
        # The VU json-encoder writes empty Lua-tables as {}.
        answer = self.hub.ingest({"v": 1, "frames": {}, "events": {}})
        self.assertEqual(answer, {"commands": []})

    def test_unknown_collector_lands_in_extras(self):
        self.hub.ingest(payload([frame(1.0, gamedirector={"objectives": 3})]))
        self.assertEqual(self.hub.state.extras["gamedirector"], {"objectives": 3})

    def test_command_roundtrip(self):
        command = self.hub.submit_command("ping", {})
        answer = self.hub.ingest(payload())
        self.assertEqual(answer["commands"], [{"id": command.id, "type": "ping", "args": {}}])
        self.assertEqual(self.hub.ingest(payload())["commands"], [])
        self.hub.ingest(payload(events=[{"type": "command_result", "id": command.id, "ok": True,
                                         "data": {"time": 5}, "t": 1}]))
        self.assertEqual(command.status, "ok")
        self.assertEqual(command.result, {"time": 5})

    def test_command_error(self):
        command = self.hub.submit_command("nope")
        self.hub.ingest(payload())
        self.hub.ingest(payload(events=[{"type": "command_result", "id": command.id, "ok": False,
                                         "error": "unknown command: nope", "t": 1}]))
        self.assertEqual(command.status, "error")
        self.assertIn("unknown", command.error)

    def test_level_change_resets(self):
        self.hub.ingest(payload([frame(1.0, [bot(1, (0, 0, 0))])],
                                [{"type": "nodes", "path": 1, "first": 1, "points": [[0, 0, 0], [1, 0, 1]], "t": 1}]))
        self.assertIn(1, self.hub.state.paths)
        subscriber = self.hub.subscribe()
        self.hub.ingest(payload([frame(2.0, [bot(7, (0, 0, 0))], level="Levels/MP_003/MP_003")]))
        self.assertEqual(self.hub.state.paths, {})
        self.assertEqual(set(self.hub.state.bots), {7})
        kinds = [subscriber.queue.get_nowait()[0] for _ in range(subscriber.queue.qsize())]
        self.assertIn("reset", kinds)

    def test_nodes_and_scan(self):
        self.hub.ingest(payload(events=[
            {"type": "nodes_started", "paths": 1, "t": 1},
            {"type": "nodes", "path": 3, "first": 1, "points": [[0, 0, 0]], "objectives": ["a"], "t": 1},
            {"type": "nodes", "path": 3, "first": 2, "points": [[1, 0, 1]], "t": 1},
            {"type": "scan_started", "scan": 1, "x0": 0, "z0": 0, "step": 2, "columns": 2, "rows": 1, "t": 1},
            {"type": "scan_row", "scan": 1, "row": 0, "heights": [10.5, False], "normals": [1, False], "t": 1},
        ]))
        self.assertEqual(self.hub.state.paths[3]["points"], [[0, 0, 0], [1, 0, 1]])
        self.assertEqual(self.hub.state.paths[3]["objectives"], ["a"])
        grid = self.hub.state.scans[1]
        self.assertEqual(grid.height_at(0, 0), 10.5)
        self.assertIsNone(grid.height_at(2, 0))

    def test_subscriber_overflow_resyncs(self):
        subscriber = self.hub.subscribe()
        for index in range(subscriber.queue.maxsize + 5):
            self.hub.ingest(payload([frame(float(index))]))
        kinds = [subscriber.queue.get_nowait()[0] for _ in range(subscriber.queue.qsize())]
        self.assertIn("resync", kinds)


class AnalyzerTest(unittest.TestCase):
    def test_stuck_bot(self):
        hub = Hub([StuckBotAnalyzer()])
        for step in range(60):
            t = step * 0.2
            hub.ingest(payload([frame(t, [bot(1, (0, 0, 0)), bot(2, (step * 1.0, 0, 0))])]))
        findings = hub.analyzers[0].findings()
        self.assertEqual([finding.bot for finding in findings], [1])

        # Moving again resolves it.
        for step in range(60, 70):
            hub.ingest(payload([frame(step * 0.2, [bot(1, (step * 1.0, 0, 0))])]))
        self.assertEqual(hub.analyzers[0].findings(), [])

    def test_friendly_target(self):
        hub = Hub([CombatAnalyzer()])
        hub.ingest(payload([frame(1.0, [bot(1, (0, 0, 0), target=2), bot(2, (1, 0, 1)), bot(3, (5, 0, 5), team=2,
                                                                                            target=1)])]))
        self.assertEqual([finding.bot for finding in hub.analyzers[0].findings()], [1])

    def test_revive_is_no_friendly_target(self):
        hub = Hub([CombatAnalyzer()])
        hub.ingest(payload([frame(1.0, [bot(1, (0, 0, 0), target=2, action="ReviveActive"), bot(2, (1, 0, 1))])]))
        self.assertEqual(hub.analyzers[0].findings(), [])

    def test_team_kill(self):
        hub = Hub([CombatAnalyzer()])
        hub.ingest(payload(events=[{"type": "kill", "victim": 2, "victimTeam": 1, "killer": 1, "killerTeam": 1,
                                    "weapon": "M16A4", "pos": [0, 0, 0], "t": 3}]))
        self.assertEqual(len(hub.analyzers[0].findings()), 1)
        self.assertEqual(hub.analyzers[0].stats()["team-kills"], 1)


class RecorderTest(unittest.TestCase):
    def test_roundtrip_and_replay(self):
        with tempfile.TemporaryDirectory() as directory:
            recorder = Recorder(Path(directory))
            hub = Hub(create_analyzers(), recorder=recorder)
            hub.ingest(payload([frame(1.0, [bot(1, (0, 0, 0))])]))
            hub.ingest(payload([frame(1.2, [bot(1, (1, 0, 0))])]))
            recorder.close()
            entries = list(read_recording(recorder.path))
            self.assertEqual(len(entries), 2)

            replayed = Hub(create_analyzers(), accept_commands=False)
            replay(recorder.path, replayed.ingest, speed=0)
            self.assertEqual(replayed.state.bots[1]["pos"], [1, 0, 0])
            self.assertEqual(replayed.ingest(payload())["commands"], [])


class HttpTest(unittest.TestCase):
    def setUp(self):
        self.hub = Hub(create_analyzers())
        self.server = DebugServer(("127.0.0.1", 0), self.hub)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()

    def post(self, path, data):
        request = urllib.request.Request(self.url + path, data=json.dumps(data).encode(), method="POST",
                                         headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=5) as response:
            return json.loads(response.read())

    def test_ingest_command_and_state(self):
        command = self.post("/api/command", {"type": "ping"})
        answer = self.post("/api/ingest", payload([frame(1.0, [bot(1, (0, 0, 0))])]))
        self.assertEqual(answer["commands"][0]["id"], command["id"])
        with urllib.request.urlopen(self.url + "/api/state", timeout=5) as response:
            state = json.loads(response.read())
        self.assertEqual(len(state["bots"]), 1)
        self.assertTrue(state["status"]["modConnected"])

    def test_static_files(self):
        with urllib.request.urlopen(self.url + "/", timeout=5) as response:
            self.assertIn(b"fun-bots", response.read())
        with self.assertRaises(urllib.error.HTTPError):
            urllib.request.urlopen(self.url + "/../server.py", timeout=5)

    def test_stream_hello(self):
        with urllib.request.urlopen(self.url + "/api/stream", timeout=5) as response:
            self.assertEqual(response.readline().strip(), b"event: hello")


if __name__ == "__main__":
    unittest.main()
