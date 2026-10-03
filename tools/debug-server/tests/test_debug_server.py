"""python -m unittest discover -s tests (from tools/debug-server)"""

from __future__ import annotations

import hashlib
import json
import re
import socket
import struct
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
from funbots_debug.console_commands import MOD_EXT, catalog  # noqa: E402
from funbots_debug.hub import Hub  # noqa: E402
from funbots_debug.protocol import as_list, yaw_to_direction  # noqa: E402
from funbots_debug.rcon import RconClient, RconError, decode_packet, encode_packet  # noqa: E402
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

    def test_big_args_only_go_to_the_mod(self):
        zones = [{"name": "a", "points": [[float(i), 0.0, 0.0]] * 50} for i in range(20)]
        command = self.hub.submit_command("navzones_apply", {"map": "MP_001_ConquestLarge0", "zones": zones})
        self.assertEqual(self.hub.ingest(payload())["commands"][0]["args"]["zones"], zones)
        shown = self.hub.snapshot()["commands"][0]["args"]
        self.assertEqual(shown["map"], "MP_001_ConquestLarge0")
        self.assertNotIn("zones", shown)
        self.assertGreater(shown["_bytes"], 2000)
        self.assertEqual(command.args["zones"], zones)

    def test_mod_gone_loses_sent_commands(self):
        command = self.hub.submit_command("census", {})
        self.hub.ingest(payload())
        queued_later = self.hub.submit_command("ping", {})
        self.hub._last_request -= 60
        self.hub.check_connection()
        self.assertFalse(self.hub.mod_connected)
        self.assertEqual(command.status, "lost")
        self.assertTrue(self.hub.commands.wait(command, 0))
        self.assertEqual(queued_later.status, "queued")

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

    def test_objectives(self):
        flag = {"name": "CP_A", "pos": [1, 2, 3], "team": 1, "flag": 50.0}
        self.hub.ingest(payload([frame(1.0, objectives={"flags": [flag], "mcoms": {}, "stage": 0})]))
        self.assertEqual(self.hub.state.objectives, {"flags": [flag], "mcoms": [], "vehicles": [], "stage": 0})
        self.assertNotIn("objectives", self.hub.state.extras)
        self.assertEqual(self.hub.snapshot()["objectives"]["flags"], [flag])

    def test_clear_scans(self):
        self.hub.ingest(payload(events=[
            {"type": "scan_started", "scan": 1, "x0": 0, "z0": 0, "step": 1, "columns": 1, "rows": 1, "t": 1},
            {"type": "scan_row", "scan": 1, "row": 0, "heights": [1], "normals": [1], "t": 1},
            {"type": "scan_started", "scan": 2, "x0": 0, "z0": 0, "step": 1, "columns": 1, "rows": 2, "t": 1},
        ]))
        self.assertEqual(self.hub.snapshot()["scans"][0]["rowData"], [[0, [1.0], [1.0]]])
        subscriber = self.hub.subscribe()
        self.assertEqual(self.hub.clear_scans(1), [1])
        self.assertEqual(self.hub.commands.take_pending(), [])  # finished, nothing to stop
        self.assertEqual(self.hub.clear_scans(), [2])
        self.assertEqual(self.hub.commands.take_pending()[0]["type"], "scan_stop")  # still running
        self.assertEqual(self.hub.state.scans, {})
        messages = [subscriber.queue.get_nowait() for _ in range(subscriber.queue.qsize())]
        self.assertIn(("scans_cleared", '{"scans":[2]}'), messages)
        # Rows of a cleared scan are ignored.
        self.hub.ingest(payload(events=[{"type": "scan_row", "scan": 2, "row": 1, "heights": [1], "normals": [1]}]))
        self.assertEqual(self.hub.state.scans, {})

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

    def test_holding_bot_is_not_stuck(self):
        # Defending / waiting bots stand on purpose.
        hub = Hub([StuckBotAnalyzer()])
        for step in range(60):
            hub.ingest(payload([frame(step * 0.2, [bot(1, (0, 0, 0), holding=True)])]))
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

    def test_port_in_use(self):
        with self.assertRaises(OSError):
            DebugServer(("127.0.0.1", self.server.server_address[1]), self.hub)

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

    def test_clear_scans(self):
        self.assertEqual(self.post("/api/scans/clear", {}), {"cleared": []})
        with self.assertRaises(urllib.error.HTTPError):
            self.post("/api/scans/clear", {"scan": "x"})

    def test_console_commands(self):
        with urllib.request.urlopen(self.url + "/api/console", timeout=5) as response:
            commands = json.loads(response.read())
        self.assertTrue(commands["chat"] and commands["rcon"])

    def test_static_files(self):
        with urllib.request.urlopen(self.url + "/", timeout=5) as response:
            self.assertIn(b"fun-bots", response.read())
        with self.assertRaises(urllib.error.HTTPError):
            urllib.request.urlopen(self.url + "/../server.py", timeout=5)

    def test_stream_hello(self):
        with urllib.request.urlopen(self.url + "/api/stream", timeout=5) as response:
            self.assertEqual(response.readline().strip(), b"event: hello")


class ConsoleCommandsTest(unittest.TestCase):
    def test_catalog(self):
        commands = catalog()
        chat = {entry["name"]: entry for entry in commands["chat"]}
        rcon = {entry["name"]: entry for entry in commands["rcon"]}
        # Every chat-command of the mod is in the list.
        source = (MOD_EXT / "Server/Commands/Chat.lua").read_text(encoding="utf-8")
        self.assertEqual(set(chat), set(re.findall(r"p_Parts\[1\] == '(![^']+)'", source)))
        self.assertEqual(chat["!spawnbots"]["args"], "<Amount>")
        self.assertEqual(chat["!grid"]["args"], "<Rows> [Columns] [Spacing]")
        self.assertEqual(rcon["funbots.spawn"]["args"], "<Amount> <Team>")
        self.assertEqual(rcon["funbots.kickAll"]["help"], "Kick All")
        for name in ("mapList.runNextRound", "vars.friendlyFire", "modList.ReloadExtensions", "vu.TimeScale",
                     "funbots.config.BotKit"):
            self.assertIn(name, rcon)

    def test_missing_mod(self):
        with tempfile.TemporaryDirectory() as folder:
            commands = catalog(Path(folder))
        self.assertEqual(commands["chat"], [])
        self.assertIn("mapList.runNextRound", {entry["name"] for entry in commands["rcon"]})


class FakeRconServer:
    """Answers like a game-server: login.hashed with salt, then echoes every command."""

    SALT = "0A1B2C3D"
    PASSWORD = "secret"

    def __init__(self):
        self.acks = 0
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen()
        self.port = self.listener.getsockname()[1]
        threading.Thread(target=self._serve, daemon=True).start()

    def _serve(self):
        while True:
            try:
                connection, _ = self.listener.accept()
            except OSError:
                return
            with connection:
                try:
                    self._handle(connection)
                except OSError:
                    pass

    def _handle(self, connection):
        logged_in = False
        while True:
            head = connection.recv(12, socket.MSG_WAITALL)
            if len(head) < 12:
                return
            size = struct.unpack("<III", head)[1]
            header, words = decode_packet(head + connection.recv(size - 12, socket.MSG_WAITALL))
            if header & 0x80000000:
                self.acks += 1  # the client acknowledges an event
                continue
            if words == ["login.hashed"]:
                answer = ["OK", self.SALT]
            elif words[0] == "login.hashed":
                expected = hashlib.md5(bytes.fromhex(self.SALT) + self.PASSWORD.encode()).hexdigest().upper()
                logged_in = words[1] == expected
                answer = ["OK"] if logged_in else ["InvalidPasswordHash"]
            elif not logged_in:
                answer = ["LogInRequired"]
            elif words[0] == "admin.eventsEnabled":
                answer = ["OK"]
            else:
                answer = ["OK", *words]
            # An event in between must be skipped (and acknowledged) by the client.
            connection.sendall(encode_packet(7, ["player.onChat", "Server", "hi"], from_server=True))
            connection.sendall(encode_packet(header, answer, response=True))

    def close(self):
        self.listener.close()


class RconTest(unittest.TestCase):
    def setUp(self):
        self.server = FakeRconServer()

    def tearDown(self):
        self.server.close()

    def test_packet_roundtrip(self):
        header, words = decode_packet(encode_packet(5, ["admin.say", "hällo all", ""]))
        self.assertEqual(header, 5)  # a request of the client: no flags
        self.assertEqual(decode_packet(encode_packet(5, ["OK"], from_server=True, response=True))[0], 0xC0000005)
        self.assertEqual(words, ["admin.say", "hällo all", ""])

    def test_login_and_command(self):
        client = RconClient("127.0.0.1", self.server.port, FakeRconServer.PASSWORD, log=False)
        self.assertEqual(client.command(["admin.nextLevel"]), ["OK", "admin.nextLevel"])
        self.assertEqual(client.command(["modList.reloadExtensions"]), ["OK", "modList.reloadExtensions"])
        client.close()
        self.assertGreater(self.server.acks, 0)

    def test_wrong_password(self):
        client = RconClient("127.0.0.1", self.server.port, "wrong", log=False)
        with self.assertRaises(RconError):
            client.command(["serverInfo"])
        self.assertFalse(client.ok)
        self.assertIn("InvalidPasswordHash", client.state)

    def test_no_server(self):
        self.server.close()
        client = RconClient("127.0.0.1", self.server.port, "x", log=False)
        with self.assertRaises(RconError):
            client.connect()
        self.assertFalse(client.ok)

    def test_http(self):
        hub = Hub([], rcon=RconClient("127.0.0.1", self.server.port, FakeRconServer.PASSWORD, log=False))
        server = DebugServer(("127.0.0.1", 0), hub)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            request = urllib.request.Request(f"http://127.0.0.1:{server.server_address[1]}/api/rcon",
                                             data=json.dumps({"words": ["serverInfo"]}).encode(), method="POST")
            with urllib.request.urlopen(request, timeout=5) as response:
                self.assertEqual(json.loads(response.read()), {"words": ["OK", "serverInfo"]})
            self.assertEqual(hub.snapshot()["status"]["rcon"],
                             {"address": f"127.0.0.1:{self.server.port}", "state": "logged in", "ok": True})
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
