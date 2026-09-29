"""Simulates the DebugBridge of the mod: bots on a made-up map, vehicles, kills, raycasts and all built-in
commands. For working on the debug-server and its web-interface without starting the game, and as reference of
the protocol (see ext/Server/Debug/DebugBridge.lua).

    python fake_mod.py [--url http://127.0.0.1:8765] [--bots 24]
"""

from __future__ import annotations

import argparse
import json
import math
import random
import time
import urllib.error
import urllib.request

TICK = 0.05


def terrain(x: float, z: float) -> tuple[float, float]:
    """Height and normal-y of the made-up ground. A block-house at (40, 40)."""
    if 30 <= x <= 50 and 30 <= z <= 50:
        return 72.0, 1.0
    height = 60 + 15 * math.sin(x / 80) + 10 * math.cos(z / 60) + 4 * math.sin((x + z) / 23)
    dx = 15 / 80 * math.cos(x / 80) + 4 / 23 * math.cos((x + z) / 23)
    dz = -10 / 60 * math.sin(z / 60) + 4 / 23 * math.cos((x + z) / 23)
    return height, 1 / math.sqrt(1 + dx * dx + dz * dz)


def make_paths() -> dict[int, list[tuple[float, float, float]]]:
    paths = {}
    for index, radius in enumerate((80, 160, 240), start=1):
        points = []
        for step in range(int(radius * 2 * math.pi / 3)):
            angle = step * 3 / radius
            x, z = radius * math.cos(angle), radius * math.sin(angle)
            points.append((x, terrain(x, z)[0], z))
        paths[index] = points
    points = []
    for step in range(200):
        x, z = -300 + step * 3, -40 + 30 * math.sin(step / 15)
        points.append((x, terrain(x, z)[0], z))
    paths[4] = points
    return paths


def rounded(values) -> list[float]:
    return [round(value, 2) for value in values]


class Bot:
    def __init__(self, bot_id: int, team: int, path: int, paths: dict):
        self.id, self.team, self.path, self.paths = bot_id, team, path, paths
        self.name = f"BOT_{'US' if team == 1 else 'RU'}_{bot_id}"
        self.point = random.randrange(len(paths[path]))
        self.direction = random.choice((-1, 1))
        self.alive, self.respawn = True, 0.0
        self.health = 100.0
        self.target, self.attack_time = -1, 0.0
        self.state = "Moving"
        self.pos = list(paths[path][self.point])
        self.yaw = 0.0
        self.stuck = bot_id == 3  # one bot that never moves, for the stuck-analyzer

    def update(self, dt: float, bots: list["Bot"], sim: "FakeMod") -> None:
        if not self.alive:
            self.respawn -= dt
            if self.respawn <= 0:
                self.alive, self.health, self.target = True, 100.0, -1
                self.point = random.randrange(len(self.paths[self.path]))
                self.pos = list(self.paths[self.path][self.point])
            return

        enemies = [bot for bot in bots if bot.alive and bot.team != self.team
                   and math.dist((bot.pos[0], bot.pos[2]), (self.pos[0], self.pos[2])) < 90]
        if self.target == -1 and enemies and random.random() < 0.05:
            enemy = min(enemies, key=lambda bot: math.dist(bot.pos, self.pos))
            visible = random.random() < 0.6
            sim.ray("botbot", self.eye(), enemy.eye(), visible)
            if visible:
                self.target, self.attack_time, self.state = enemy.id, 0.0, "Attacking"

        if self.target != -1:
            enemy = next((bot for bot in bots if bot.id == self.target and bot.alive), None)
            if enemy is None or self.attack_time > 6:
                self.target, self.state = -1, "Moving"
            else:
                self.attack_time += dt
                self.yaw = math.atan2(-(enemy.pos[0] - self.pos[0]), enemy.pos[2] - self.pos[2])
                if random.random() < 0.15 * dt:
                    enemy.alive, enemy.respawn, enemy.target = False, 5.0, -1
                    sim.event("kill", victim=enemy.id, victimTeam=enemy.team, killer=self.id, killerTeam=self.team,
                              weapon=random.choice(["M16A4", "AK74M", "M249", "SV98"]), pos=rounded(enemy.pos),
                              headshot=random.random() < 0.3, roadkill=False)
                    self.target, self.state = -1, "Moving"
            return

        if self.stuck:
            return
        points = self.paths[self.path]
        target = points[(self.point + self.direction) % len(points)]
        dx, dz = target[0] - self.pos[0], target[2] - self.pos[2]
        distance = math.hypot(dx, dz)
        speed = 5.0 * dt
        if distance <= speed:
            self.point = (self.point + self.direction) % len(points)
            self.pos = list(target)
        else:
            self.pos[0] += dx / distance * speed
            self.pos[2] += dz / distance * speed
            self.pos[1] = terrain(self.pos[0], self.pos[2])[0]
            self.yaw = math.atan2(-dx, dz)

    def eye(self) -> list[float]:
        return [self.pos[0], self.pos[1] + 1.6, self.pos[2]]

    def snapshot(self) -> dict:
        entry = {"id": self.id, "name": self.name, "team": self.team, "squad": 1 + self.id % 4, "kit": "Assault",
                 "alive": self.alive, "state": self.state if self.alive else "Idle", "action": "NoActionActive",
                 "move": "Paths", "target": self.target, "path": self.path, "point": self.point + 1,
                 "objective": ""}
        if self.alive:
            points = self.paths[self.path]
            entry.update(pos=rounded(self.pos), yaw=round(self.yaw, 3), pitch=0.0, health=self.health, pose=0,
                         stuck=False, waypoint=rounded(points[(self.point + self.direction) % len(points)]))
        return entry


class FakeMod:
    def __init__(self, url: str, bot_count: int, interval: float):
        self.url, self.interval = url.rstrip("/"), interval
        self.paths = make_paths()
        self.bots = [Bot(index + 1, 1 + index % 2, 1 + index % len(self.paths), self.paths)
                     for index in range(bot_count)]
        self.events: list[dict] = []
        self.tasks: list = []
        self.channels = {"traces": True, "meta": True, "bots": True, "players": True, "vehicles": True,
                         "objectives": True}
        self.server_raycasts = True
        self.commands = ["bot", "channels", "chat", "interval", "nodes", "ping", "raycast", "rcon", "scan", "scan_stop",
                         "server_raycasts"]
        self.time = 0.0
        self.seq = 0
        self.scan_id = 0
        self.connected = False

    # --- like DebugBridge.lua ----------------------------------------------------------------------------------

    def event(self, event_type: str, **data) -> None:
        data.update(type=event_type, t=round(self.time, 3))
        self.events.append(data)

    def ray(self, kind: str, start, end, visible: bool) -> None:
        if not self.channels.get("traces"):
            return
        hit = None
        if not visible:
            f = random.uniform(0.3, 0.9)
            hit = rounded(a + (b - a) * f for a, b in zip(start, end))
        self.event("ray", kind=kind, **{"from": rounded(start)}, to=rounded(end), visible=visible, hit=hit)

    def reply(self, command_id, ok: bool, data) -> None:
        if ok:
            self.event("command_result", id=command_id, ok=True, data=data)
        else:
            self.event("command_result", id=command_id, ok=False, error=str(data))

    def snapshot(self) -> dict:
        frame = {"t": round(self.time, 3)}
        if self.channels.get("meta", True):
            frame["meta"] = {"level": "Levels/FAKE_001/FAKE_001", "mode": "ConquestLarge0", "round": 1,
                             "tickrate": 30, "bots": len(self.bots), "players": len(self.bots),
                             "serverRaycasts": self.server_raycasts, "luaMemoryKb": 80000 + int(self.time * 10),
                             "version": "fake", "commands": self.commands}
        if self.channels.get("bots", True):
            frame["bots"] = [bot.snapshot() for bot in self.bots]
        if self.channels.get("players", True):
            frame["players"] = []
        if self.channels.get("vehicles", True):
            frame["vehicles"] = self.vehicles()
        if self.channels.get("objectives", True):
            frame["objectives"] = self.objectives()
        return frame

    def objectives(self) -> dict:
        # Conquest-flags and rush-MCOMs at once, so both show up in the UI.
        flags = []
        for index, (name, x, z) in enumerate((("CP_A", -150, -60), ("CP_B", 0, 0), ("CP_C", 150, 60))):
            raised = (self.time * 4 + index * 40) % 200
            team = 1 + (int((self.time * 4 + index * 40) // 200) + index) % 2
            flags.append({"name": name, "objective": name[-1], "hq": False, "pos": rounded((x, terrain(x, z)[0], z)),
                          "team": team, "attacked": raised < 100, "controlled": raised >= 100,
                          "flag": round(min(raised, 100.0), 1)})
        for name, team, x in (("US_HQ", 1, -260), ("RU_HQ", 2, 260)):
            flags.append({"name": name, "hq": True, "pos": rounded((x, terrain(x, 0)[0], 0)), "team": team,
                          "attacked": False, "controlled": True, "flag": 100.0})
        stage = 1 + int(self.time // 60) % 2
        mcoms = []
        for index, (x, z) in enumerate(((-80, 120), (-40, 150), (60, 130), (100, 160)), start=1):
            active = (index + 1) // 2 == stage
            mcoms.append({"index": index, "name": f"MCOM {index}", "pos": rounded((x, terrain(x, z)[0], z)),
                          "active": active, "destroyed": (index + 1) // 2 < stage,
                          "armed": round(self.time % 60, 1) if active and index % 2 and self.time % 60 > 30 else None})
        return {"flags": flags, "mcoms": mcoms, "stage": stage}

    def vehicles(self) -> list[dict]:
        result = []
        angle = self.time * 0.08
        x, z = 120 * math.cos(angle), 120 * math.sin(angle)
        forward = [-math.sin(angle), 0, math.cos(angle)]
        result.append({"id": 1001, "name": "M1Abrams", "type": 1, "team": 1, "pos": rounded((x, terrain(x, z)[0], z)),
                       "forward": rounded(forward), "velocity": rounded(v * 9.6 for v in forward),
                       "health": 900.0, "occupants": [{"seat": 0, "id": 1}]})
        angle = self.time * 0.15
        x, z = 200 * math.sin(angle), 120 * math.sin(2 * angle)
        dx, dz = 200 * math.cos(angle), 240 * math.cos(2 * angle)
        length = math.hypot(dx, dz) or 1
        result.append({"id": 1002, "name": "Mi28", "type": 5, "team": 2, "pos": rounded((x, 150, z)),
                       "forward": rounded((dx / length, 0, dz / length)),
                       "velocity": rounded((dx * 0.15, 0, dz * 0.15)), "health": 700.0, "occupants": []})
        return result

    # --- commands ----------------------------------------------------------------------------------------------

    def execute(self, command: dict) -> None:
        command_id, kind, args = command.get("id"), command.get("type"), command.get("args") or {}
        try:
            if kind == "ping":
                self.reply(command_id, True, {"time": self.time})
            elif kind == "channels":
                for name, enabled in args.items():
                    self.channels[name] = bool(enabled)
                self.reply(command_id, True, self.channels)
            elif kind == "interval":
                self.interval = max(0.02, float(args["seconds"]))
                self.reply(command_id, True, {"seconds": self.interval})
            elif kind == "rcon":
                if not args.get("command"):
                    raise ValueError("rcon needs a command")
                self.reply(command_id, True, {"lines": ["OK", f"fake rcon: {args['command']} {args.get('args', [])}"]})
            elif kind == "chat":
                if args.get("player") is not None:
                    raise ValueError(f"no player with id {args['player']}")
                self.reply(command_id, True, {"lines": [f"fake chat-command: {args.get('message', '').lower()}"]})
            elif kind == "server_raycasts":
                if "enabled" in args:
                    self.server_raycasts = bool(args["enabled"])
                self.reply(command_id, True, {"enabled": self.server_raycasts})
            elif kind == "bot":
                bot = next(bot for bot in self.bots if bot.id == int(args["id"]))
                self.reply(command_id, True, {key: value for key, value in vars(bot).items()
                                              if isinstance(value, (int, float, str, bool))})
            elif kind == "raycast":
                self.reply(command_id, True, self.raycast(args["from"], args["to"]))
            elif kind == "nodes":
                self.tasks.append(self.nodes_task(command_id))
            elif kind == "scan":
                self.tasks.append(self.scan_task(command_id, args))
            elif kind == "scan_stop":
                stopped = len(self.tasks)
                self.tasks.clear()
                self.reply(command_id, True, {"stopped": stopped})
            else:
                self.reply(command_id, False, f"unknown command: {kind}")
        except Exception as error:  # like the pcall in DebugBridge:_ExecuteCommand
            self.reply(command_id, False, repr(error))

    def raycast(self, start, end) -> dict:
        hits = []
        for step in range(1, 201):
            f = step / 200
            x, y, z = (a + (b - a) * f for a, b in zip(start, end))
            height, normal = terrain(x, z)
            if y <= height:
                hits.append({"pos": rounded((x, height, z)), "normal": [0, round(normal, 3), 0],
                             "entity": "StaticPhysicsEntity", "materialFlags": 0})
                break
        self.ray("test", start, end, not hits)
        return {"from": start, "to": end, "hits": hits}

    def nodes_task(self, command_id):
        self.event("nodes_started", paths=len(self.paths))
        total = 0
        for path, points in self.paths.items():
            for first in range(0, len(points), 100):
                chunk = points[first:first + 100]
                total += len(chunk)
                event = {"path": path, "first": first + 1, "points": [rounded(p) for p in chunk],
                         "last": first + 100 >= len(points)}
                if first == 0:
                    event["objectives"] = [f"objective {path}"]
                self.event("nodes", **event)
                yield
        self.reply(command_id, True, {"paths": len(self.paths), "points": total})

    def scan_task(self, command_id, args):
        step = max(0.25, float(args.get("step", 2)))
        x0, x1 = sorted((float(args["x0"]), float(args["x1"])))
        z0, z1 = sorted((float(args["z0"]), float(args["z1"])))
        columns, rows = int((x1 - x0) / step) + 1, int((z1 - z0) / step) + 1
        if columns * rows > 4_000_000:
            self.reply(command_id, False, f"scan too big: {columns} x {rows}")
            return
        self.scan_id += 1
        scan = self.scan_id
        self.event("scan_started", scan=scan, x0=x0, z0=z0, step=step, columns=columns, rows=rows, layers=1)
        per_update = int(args.get("perUpdate", 100))
        done = 0
        for row in range(rows):
            z = z0 + row * step
            heights, normals = [], []
            for column in range(columns):
                height, normal = terrain(x0 + column * step, z)
                heights.append(round(height, 2))
                normals.append(round(normal, 3))
                done += 1
                if done % per_update == 0:
                    yield
            self.event("scan_row", scan=scan, row=row, z=round(z, 2), x0=x0, step=step, heights=heights,
                       normals=normals)
        self.reply(command_id, True, {"scan": scan, "raycasts": columns * rows})

    # --- loop --------------------------------------------------------------------------------------------------

    def send(self) -> None:
        self.seq += 1
        body = {"v": 1, "seq": self.seq, "frames": [self.snapshot()] if self.connected else [],
                "events": self.events, "dropped": 0}
        self.events = []
        request = urllib.request.Request(self.url + "/api/ingest", data=json.dumps(body).encode(),
                                         headers={"Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=5) as response:
                answer = json.loads(response.read())
        except (urllib.error.URLError, OSError, ValueError) as error:
            if self.connected:
                print(f"lost connection: {error}")
            self.connected = False
            return
        if not self.connected:
            print(f"connected to {self.url}")
            self.event("level_loaded", level="FAKE_001", mode="ConquestLarge0")
        self.connected = True
        for command in answer.get("commands", []):
            self.execute(command)

    def run(self) -> None:
        next_send = 0.0
        while True:
            start = time.monotonic()
            self.time += TICK
            for bot in self.bots:
                bot.update(TICK, self.bots, self)
            if self.connected and len(self.events) < 1000:
                for task in list(self.tasks):
                    try:
                        next(task)
                    except StopIteration:
                        self.tasks.remove(task)
            if self.time >= next_send:
                next_send = self.time + (self.interval if self.connected else 3.0)
                self.send()
            time.sleep(max(0.0, TICK - (time.monotonic() - start)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", default="http://127.0.0.1:8765")
    parser.add_argument("--bots", type=int, default=24)
    parser.add_argument("--interval", type=float, default=0.2)
    args = parser.parse_args()
    try:
        FakeMod(args.url, args.bots, args.interval).run()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
