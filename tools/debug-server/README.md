# fun-bots debug-server

Watch and analyze what the bots do without joining the game server. The mod streams its state to this
server, and the server shows it on a live map in the browser, runs analyzers on it, and can record it for later.
The server can also send commands back to the mod (test raycasts, waypoint export, map scans).

Only the Python standard library is needed (Python 3.9 or newer). There is nothing to install.

```
mod (ext/Server/Debug)  ── POST /api/ingest (snapshots + events) ──▶  debug-server  ── SSE ──▶  browser
                        ◀──────────── commands (in the answer) ────                ◀── POST /api/command ──
```

## Quick start

1. Start the server from `tools/debug-server`:
   ```
   python -m funbots_debug --open
   ```
2. Turn on the bridge in the mod. Use any of these:
   - `Registry.DEBUG.DEBUG_BRIDGE = true` in `ext/Shared/Registry/Registry.lua`, which is on from the start
   - `!debugbridge on` in the chat (needs the `ChatCommands` permission)
   - RCON `funbots.debugBridge on [url]`, which works without a client in the game
3. Open http://127.0.0.1:8765.

If the game server runs on another machine, start with `--host 0.0.0.0` and set `DEBUG_BRIDGE_URL` (or pass the URL
to the RCON command). There is no authentication, and everyone who reaches the debug-server can run any RCON command on
the game server (see *Console*), so only do this in a trusted network.

To work on the server or the UI without the game, use the simulator. It speaks the same protocol:
```
python fake_mod.py
```

## Bots without any client: server-side raycasts

Normally the clients raycast whether bots can see each other (`ClientBotManager.lua`). Without a player in the
game, bots don't fight each other. With server-side raycasts the server does all sight checks itself
(`ext/Server/ServerRaycasts.lua`):

| Check | Normally | With server raycasts |
| --- | --- | --- |
| Bot sees bot | Sent to the clients | `BotManager:_DispatchRaycastsBotBotAttack` |
| Bot sees player | Client of the player | `ServerRaycasts:UpdatePlayerChecks` |
| Bot revives player | Client of the player | `ServerRaycasts:UpdatePlayerChecks` |
| Bot revives bot | Already on the server, but only with a player in the game | Also without players |

Switch it on with `Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS`, `!serverraycasts on|off`, RCON
`funbots.serverRaycasts on|off`, or the button in the web UI. The clients are told when it changes, so they stop
their own raycasts. The budgets are `SERVER_RAYCASTS_BOT_BOT` and `SERVER_RAYCASTS_PER_PLAYER` in the Registry.

The server only has collision raycasts. They ignore characters, so the environment and vehicles block the sight
and other soldiers don't. See-through materials (windows, fences) are passed like on the client. Every server
raycast shows up on the map as a trace: green if the target is visible, red up to the blocking hit if not.

## The web UI

- **Map**: bots (heading, trail, current target, the waypoint they walk to), players, vehicles (forward
  direction and 1-second velocity vector, altitude for aircraft), objectives (capture points with team and flag
  progress, dashed when attacked; rush MCOMs: yellow = active, red = armed, crossed = destroyed), raycast traces,
  kills, waypoints, and height maps of scans. Drag to pan, scroll to zoom, click to select. F fits the view, C follows the selection.
- **Mod**: toggle server raycasts, toggle sending traces, set the snapshot interval, load all waypoints, and
  scan the visible area (up to 4,000,000 cells; *rays/update* sets the speed). *Clear scans* or the × next to a
  scan removes it again, and stops it if it still runs.
- **Console**: run fun-bots chat commands (`!spawnbots 5`) or any RCON command (`admin.nextLevel`,
  `modList.reloadExtensions`, `admin.say "hello all" all`). The answer is shown below, for chat commands also
  everything they printed. RCON goes straight to the RCON port of the game server (see *RCON* below), so it also
  works while the mod reloads. Chat
  commands run either as a real player in the game (with their permissions and soldier, answers also go to their
  chat) or as *debug-server*: all permissions, but no soldier, so commands like `!row` or `!trace` need a player.
  While typing, matching commands are suggested (any part of the name, any case). Tab or a click takes one, the
  arrow keys choose, and the arguments stay visible while typing them. A known RCON command in the wrong case is
  corrected before it is sent. `?` or `help [filter]` lists the commands (BF3, VU, fun-bots). Without suggestions,
  up and down go through the history. Two lines above the output show whether RCON is logged in and whether the
  running mod is new enough for the console (the mod sends its command list in `meta.commands`).
- **Objectives**: all capture points and MCOMs with their state. Click one to jump to it.
- **Selection**: the snapshot of the selected bot. *Full details* shows every plain field of the `Bot` object.
- **Findings**: problems found by the analyzers. Click one to jump to it.
- **Statistics**: numbers from the analyzers (kills, raycast rates, visible ratio, server hitches, Lua memory).
- **Raw data**: snapshot parts without their own view yet, so a new collector shows up at once.

## RCON

The console connects to the RCON port of the game server itself (`--rcon`, default `127.0.0.1:47200`) and logs in
with the password from `--rcon-password`, `$FUNBOTS_RCON_PASSWORD`, or `admin.password` in the `Startup.txt` of the
server this folder is in (`Admin/Startup.txt`). It logs in right at the start, and prints the result and every
RCON packet (`rcon >` / `rcon <`) in its terminal. Without a password (or with `--no-rcon`), the console sends RCON
commands through the mod instead. That way not every server command works
(e.g. `admin.nextLevel` or `modList.reloadExtensions`), and a mod that is older than the debug-server answers
`unknown command: rcon`.

## Recording and replay

```
python -m funbots_debug --record recordings            # one .jsonl.gz file per level
python -m funbots_debug --replay recordings/<file> --speed 4
```

Each line is one request of the mod: `{"recv": <unix time>, "payload": <body>}`. Read recordings in your own scripts
with `funbots_debug.recorder.read_recording()`.

## Protocol

The mod always makes the request, and only one request is in flight at a time (`DebugBridge.lua`).

```
POST /api/ingest   {"v": 1, "seq": n, "frames": [snapshot], "events": [event], "dropped": n}
answer             {"commands": [{"id": 1, "type": "scan", "args": {...}}]}
```

- **Snapshot**: `{"t", "meta", "bots", "players", "vehicles", "objectives", ...}`, one key per collector. Positions are `[x, y, z]`
  in metres, where y is up. The yaw of bots points to `x = -sin(yaw), z = cos(yaw)`.
- **Event**: `{"t", "type", ...}`. The built-in types are `ray`, `kill`, `level_loaded`, `level_destroyed`,
  `nodes_started`, `nodes`, `scan_started`, `scan_row`, `command_result`, and `error`.
- **Commands**: `ping`, `channels`, `interval`, `server_raycasts`, `raycast`, `bot`, `nodes`, `scan`, `scan_stop`,
  `rcon`, and `chat`
  (see the header of `DebugCommands.lua`). Each command is answered with a `command_result` event.

While the debug-server is unreachable, the mod only sends a small hello every 3 seconds.

## Extending

**New data from the mod.** Register a collector. Its data is in every snapshot and appears under *Raw data*
right away:
```lua
local m_DebugBridge = require('Debug/DebugBridge')
m_DebugBridge:RegisterCollector('gamedirector', function(p_Bridge)
	return { objectives = ..., tickets = ... } -- plain tables only, use DebugBridge.Vec for positions
end)
```
For something that happens once, send an event from anywhere: `if m_DebugBridge.m_Enabled then m_DebugBridge:Event('stuck', {...}) end`.

**New command.** Register it in the mod. Work that takes longer runs as a task over several updates (see
`MapScanner.lua`):
```lua
m_DebugBridge:RegisterCommand('teleport', function(p_Args, p_Bridge, p_Command)
	...
	return { ok = true } -- or DebugBridge.ASYNC and answer later with p_Bridge:Reply(p_Command.id, ...)
end)
```
Send it from the browser with `command("teleport", {...})` in `app.js`, with `POST /api/command`, or from Python with
`hub.run_command(...)`.

**New analyzer.** Add a class to `funbots_debug/analyzers/`, or put it in a separate folder and pass that folder
with `--plugins`:
```python
from funbots_debug.analyzers import Analyzer, Finding, register

@register
class LowHealthAnalyzer(Analyzer):
    name = "low-health"

    def on_frame(self, frame, state):
        for bot_id, bot in state.bots.items():
            if bot.get("alive") and bot.get("health", 100) < 10:
                self.report(Finding(key=f"low:{bot_id}", bot=bot_id, time=state.time, message=f"{bot['name']} low"))
            else:
                self.resolve(f"low:{bot_id}")
```

**New map layer.** Add an entry to `LAYERS` in `web/app.js`: `{id, label, on, draw(now)}`. Use `sx(x)` and `sy(z)`
to convert world coordinates to screen coordinates.

**Scripts.** `GET /api/state` returns the whole model. `POST /api/command?wait=10` blocks until the mod has
answered. `POST /api/scans/clear` with `{"scan": id}` (or `{}` for all) removes scans from the server and all browsers.

## Towards nav meshes

`scan` casts vertical rays over a grid and streams the height and surface normal of every cell, one row per
event (`MapScanner.lua`). The UI draws the result as a height map, with surfaces steeper than about 45° in red.
With `layers > 1`, the ray continues below each hit to find bridges, building floors, and tunnels. This part is
experimental. Scans are stored in `WorldState.scans` (`ScanGrid.height_at`), which is the starting point for
walkability grids and generated nav meshes.

## Tests

```
python -m unittest discover -s tests
```
