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
- **Path labels**: label and link the waypoints automatically, see *Labeling and linking paths* below.
- **Objectives**: all capture points and MCOMs with their state. Click one to jump to it.
- **Selection**: the snapshot of the selected bot. *Full details* shows every plain field of the `Bot` object.
- **Findings**: problems found by the analyzers. Click one to jump to it.
- **Statistics**: numbers from the analyzers (kills, raycast rates, visible ratio, server hitches, Lua memory).
- **Raw data**: snapshot parts without their own view yet, so a new collector shows up at once.

## Labeling and linking paths

Bots need three things from the waypoints (`GameDirector.lua`, `PathSwitcher.lua`):

- **Objectives** on the first node of each path. One objective (`a`, `base us`) makes it the path of that objective:
  the bots capture, defend and spawn there. Two or more (`a, b`) make it a path between these objectives.
- **Links** (junctions): where a bot may switch to another path. It walks straight to the linked node.
- **Loop**: a closed path loops, an open one has to be walked back and forth, otherwise a bot walks straight from its
  last node to its first one.

The labeler (`funbots_debug/paths/`) sets all three from the positions of the capture points and HQs of the running game:

1. A path that stays in the area of one objective (up to half the distance to the next one) gets that objective.
2. Every other path gets the objectives at its two ends: the area it ends in, or the objective path next to it. An end
   at a junction takes over the objectives of the path it joins, an end at nothing the closest other objective. A base
   only if the end is at it (within 80 m of the HQ).
3. Closed paths loop, paths whose ends are more than 15 m apart are walked back and forth.
4. Each path end at an objective is linked to that objective path (up to 15 m away), other ends to the closest path within
   5 m. No end a bot can reach stays without a junction: it follows the direction of its last 5 m for up to 30 m and is
   linked to the first path it crosses, else to the closest path within 15 m. What is still left is reported as dead
   end (ends of looping paths and the vehicle end of paths to a vehicle need no junction). Links to missing nodes are
   removed, one-sided links completed. With *crossings*, paths are also linked where they cross (at least 30°, same
   height).

It only fills in what's missing: paths that have objectives keep them (*relabel* recomputes capture point and base
objectives), existing links stay (*relink* drops the links between walkable paths first), and an end that already has a
junction nearby gets no new one. Other objectives (`vehicle tank1 us`, `spawn a`, `mcom 1`, `beacon`, ...) are never
changed, those paths are only linked. Paths with `Vehicles` keep their objectives and belong to the vehicle network:
they are only linked with *vehicles* (land paths among each other; an end at a vehicle spawn needs no junction), unless
they are walkable too, i.e. recorded on foot: a loop around one flag, or a path between flags. Soldiers never switch
onto a path with `Vehicles` that has no objectives (out of a base) or is a closed loop through several objectives
(around the map; ends within 15 m or 5 % of its length), see `PathSwitcher:IsWalkable`. Links between those and foot
paths are useless, so they are removed. Air paths are never touched.

A base objective belongs only to the paths directly at the base: bots on a path with a base leave it at every
junction, and never switch onto it from elsewhere. So it's removed from any path that doesn't come to the base (80 m
around the HQ), isn't linked to a path of the base and doesn't end at one, e.g. a vehicle loop through the capture
points labeled `a, b, base ru, c`. The path gets the capture points it passes instead; if that's fewer than two, it's
only reported. This needs the HQs of the running game, offline the position of a base is a guess.

Vehicles always have to leave their base, so vehicle paths out of a base (or away from a vehicle spawn) are handled
without *vehicles* too: they are walked back and forth, and their far end is linked to the next vehicle path of the same
terrain, labeled or not (straight ahead, else the closest one within 30 m; another base exit only outside of the base).
Where the vehicles can't get out (no vehicle path in reach, or the junctions only lead to other base exits), it's
reported. Rush has no capture points, so there only links and loops are set.

In the web interface: **Load waypoints**, then **Auto-label** in *Path labels*. The map shows the result: the areas of
the objectives, new objectives in blue, new links green, removed ones red. Click a change to jump to it. Nothing changes
in the game until:

- **Apply to game**: the mod takes the labels over at once (`paths_apply`), the bots use them right away. With *save*
  it saves the paths into `mod.db`, like the save of the node-editor.
- **Write .map**: patches `mapfiles/<level>_<mode>.map` of this repository (`--mapfiles DIR` for another folder). The
  file has to hold the same paths as the game, so export the waypoints with the fun-bots-helper first if you changed
  them in the game.

The labeler also works on waypoint-files without the game:
```
python -m funbots_debug.paths ../../mapfiles/MP_001_ConquestSmall0.map -v            # only show what it would do
python -m funbots_debug.paths ../../mapfiles/MP_001_ConquestSmall0.map --write
python -m funbots_debug.paths ../../mapfiles/*.map --server http://127.0.0.1:8765     # capture points of the game
```
Without `--server` (or `--flags FILE` with the `flags` of `/api/state`), the objectives come from the paths that
already carry exactly one objective. Measured on the hand-made conquest maps, the labeler finds the same objectives for
87 % of the paths, and about as many links as the authors made.

### Ways out of the bases

Bots spawn on the paths of a base alone (`base us`, `base ru 2`) and have to leave them. At a junction they always
take a walkable path whose objectives are all active (in rush: of the current stage) and that isn't a base-path alone.
On a path out of a base (`base us 1, mcom 2`) they never switch onto another path with a base, so it needs a junction to
an active path without one, best its objective (`mcom 2`). `funbots_debug/paths/bases.py` finds the paths without such
a junction, for every rush stage, and fixes them:

1. **Relabel** (rush): an MCOM a path doesn't come near (80 m) becomes the MCOM of the same stage it passes (30 m), e.g.
   `mcom 2, mcom 3` between mcom 3 and 4. The MCOMs are where their `mcom N interact` paths end. A path that names
   both MCOMs of a stage and earlier ones (`mcom 2, mcom 3, mcom 4`) is never fully active: the earlier ones are
   dropped (paths to the next stage like `mcom 2, mcom 4` stay). A walked path without objectives that passes both
   MCOMs of a stage gets them. A path out of a base
   that names an MCOM of another stage (`base us 2, mcom 2`) is only partly active, bots don't take it. The MCOM becomes
   the one of the base's stage closest to an end of the path (80 m).
2. **Relink** a path out of a base to the closest node of the path of its objective within 20 m, else of a path to it,
   else of any way out. If nothing is within 20 m, the closest one up to 50 m (`--fallback-radius`, `--no-fallback`):
   a bot may get stuck on the long link and teleport, but doesn't stay there. This holds for steps 3 and 5 too.
3. **Relink** a base-path to the closest node of a way out within 20 m (not through the other team's base).
4. **Remove**: a base-path without any links and nothing in reach is deleted, if its base has other paths.
5. **Routes** (rush, `routes.py`): plays the path-switches through for every stage, both teams, and with none or one
   MCOM destroyed (then the bots go for the other one), from the base-paths and the paths of the MCOMs. Paths bots get
   to but not from there to their MCOM are linked to the closest path that names it (20 m), shortest link first.

The rest is reported: mostly base-paths that only lead to vehicles, and paths out of a base split into several pieces
that all carry the base. In the game, bots spawn on base-paths only while they can leave them, e.g. while one of their
vehicles is there (`GameDirector:CanLeaveBasePath`). If a path has no regular way out at all, a bot leaves it anyways
over any other linked path but a base-path alone, the way to a vehicle or a beacon (`PathSwitcher:GetNewPath`): a
base-path at any junction, a path out of a base at its ends, the path of a destroyed MCOM, and the way to a vehicle that
isn't the bot's. Bots that still stay on a path without an active objective, a base-path alone or the path of a
destroyed MCOM are teleported onto a path of their objective after 20 s if they don't fight
(`TELEPORT_ON_INVALID_PATH_TIME`, with `TeleportIfStuck`), else killed after 50 s. Bots only take the way to a vehicle
of their own team.
```
python -m funbots_debug.paths.fix_bases ../../mapfiles/*.map -v         # only show what it would do
python -m funbots_debug.paths.fix_bases ../../mapfiles/*.map --write
```

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
  `nodes_started`, `nodes`, `scan_started`, `scan_row`, `command_result`, and `error`. `nodes` has the positions, the
  `inputs` (inputVar) and the `data` (`[point, data]`, links as `[path, point]`) of a part of a path.
- **Commands**: `ping`, `channels`, `interval`, `server_raycasts`, `raycast`, `bot`, `nodes`, `paths_apply`, `scan`,
  `scan_stop`, `census`, `census_stop`, `rcon`, and `chat`
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
`POST /api/paths/label` (with the switches `relabel`, `relink`, `crossings`, `vehicles`, `loops`), `/api/paths/apply`
(`{"save": true}`) and `/api/paths/write` run the labeler.

## Census of a level

The census collects everything about the running level that the tools for the waypoints need, in one run
(`ext/Server/Debug/MapCensus.lua`). The debug-server saves it as `census/<level>_<mode>.json.gz` (`--census DIR`),
checks it (`funbots_debug/census/report.py`), prints the summary in its terminal and lists the problems under
*Findings*. The grids around the objectives show up on the map like scans.

```
python -m funbots_debug.census run --current --warmup 180                  # the level that runs now
python -m funbots_debug.census run --map "MP_001 ConquestLarge0" --warmup 180  # switches the level over RCON first
python -m funbots_debug.census run --maplist ../../MapList.txt --warmup 180    # every level of the list
python -m funbots_debug.census report census/*.json.gz --issues 40
```

The engine doesn't tell the radius of a capture point (`CaptureRadius` is 0, the level sets it in a way the server
can't read). The debug-server measures it instead, from the players the mod reports inside each capture point
(`census/zones.py`): at least as far as the farthest one inside. `--warmup` lets the bots play that long before the
census. Capture points nobody ever entered while another one of the same name was entered are the layout of another
mode (loaded as well, e.g. on XP3_Alborz) and are skipped. A census without explicit `areas` puts its grids around the
measured zones.

Switching levels needs the RCON-connection. Afterwards the map-list is loaded again from the `MapList.txt` of the
game-server. `report` also tells whether the waypoints of the game (`mod.db`) are the ones of `mapfiles/` in git.

What it collects:

- **Entities**: capture points with their spawns, soldier-spawns, vehicle-spawns (blueprint, team), combat areas
  (the points of their shapes), MCOMs, the vehicles, and how often each entity-type exists (types with `Ladder`,
  `Mcom`, `Objective`, `Zipline` or `Door` in the name with their positions). The level links the same shapes to the
  combat-area triggers of both teams: one per team and a big one for aircraft. Each team gets the smallest shape
  around its HQ.
- **Waypoints**: for every waypoint the ground below it (and its slope), water, headroom, the free space to the left
  and right of the path, and rays at 0.4, 1.0 and 1.6 m to the next waypoint and along every link longer than 1 m.
- **Areas**: a grid around every capture point (capture-radius + 15 m) and MCOM (30 m), 0.5 m cells with up to
  4 layers (floors of buildings, bridges). Every walkable surface has its headroom and rays at knee and chest height
  to the neighbour-cells, so the walkable area and its connections are known without waypoints.

The report checks: paths in the air without the `Vehicles` tag `air`, waypoints floating above the ground (more than
1.5 m is never reached), low ceilings that are walked
upright, walls and obstacles between waypoints without a jump, blocked links, capture points without waypoints inside
the radius, waypoints outside the combat area, spawns far from the waypoints, and how much of the walkable area around
each objective can be reached from the waypoints.

The raycasts ignore soldiers, but vehicles standing around block them (`nextHit` names what was hit). The census sees
the level before anything is destroyed.

## Zone networks

Inside a capture zone and around an MCOM the bots shall move freely instead of along waypoints; waypoints are only
needed between the zones (and for vehicles, actions, jumps). `funbots_debug/census/navzones.py` makes a small walking
network for every zone from the grids of a census: points about every 5 m (the open spots first), the walkable
connections between them, and the junctions with the existing waypoints (where a path enters, leaves or ends in the
zone). Only the parts of the grid the waypoints reach get points, so roofs and closed rooms stay out. Where a path walks
from one part of the network into another one the grid doesn't connect (stairs, ladders, jumps the vertical rays don't
see), the network gets a connection along its waypoints. Bots only walk to points they can reach.

```
python -m funbots_debug.census navzones census/*.json.gz             # writes census/<level>_<mode>.navzones.json
python -m funbots_debug --navzones census/XP3_Alborz_ConquestLarge0.json.gz   # show them on the map, also offline
```

The debug-server also makes them after every census, or on `POST /api/navzones` (`{"file": ...}`, default: the census
of the running level). On the map (layer *Zone networks*) connections inside the zone are green, outside blue-grey,
points indoors have a blue ring, points that need crouching an orange one, the junctions with the waypoints are dashed
orange.

Areas are made around the capture points, the MCOMs and the HQs of the running mode (`base us`, `base ru`, 60 m). Modes
without HQs (rush) get their bases from the waypoints: around the paths of each `base us 1`, `base ru 2`, ... objective.

Land vehicles get a network of their own in each zone (`vehicle`): the same way, but only over wide and open ground
(1.8 m to the next wall, slopes up to about 41°, no roof below 4 m), a point about every 10 m, attached to the paths with
`Vehicles: land`.

**In the game** (`ext/Server/NavZones.lua`, `ext/Server/Bot/BotZoneMovement.lua`, switch
`Registry.BOT.USE_ZONE_NETWORKS`): `POST /api/navzones/apply` (`{"save": true}`) sends the networks shown on the map to
the mod, which saves them in the table `<level>_<mode>_navzones` of `mod.db` and loads them with the waypoints from then
on. A bot that reaches a junction of the zone of its objective (capture point or MCOM) leaves the waypoints: it walks
from point to point inside the zone and waits at each (longer and crouched in cover when it defends). When its
objective changes it walks to the junction whose path leads to the new objective best (`PathSwitcher` priority, then
distance) and goes on along that path. A bot that gets stuck between two points (4 s without progress) takes another
way, and all bots avoid that connection until the level ends; after three of them it goes back to the waypoints. The
debug-server lists these spots under *Findings* (analyzer `zones`). In the snapshot a bot in a zone has `zone` (and
`zoneExit` on its way out).

- **MCOMs**: in the zone of an MCOM a bot asks the GameDirector every second whether it shall arm (attackers, MCOM not
  armed) or disarm it (defenders, MCOM armed), at most two per team. Then its objective becomes `mcom N interact`, it
  leaves the zone at the action-node of that path (a junction of the zone) and does the action there as on the
  waypoints.
- **Bases**: bots that spawn at the spawn-points of the game (`SpawnMethod.Spawn`) on the network of a base start in it
  and walk out over the junction that suits their objective as soon as they have one.
- **Land vehicles** (`Registry.BOT.USE_VEHICLE_ZONE_NETWORKS`, experimental): a driver that reaches a junction of the
  vehicle-network of the capture point of its objective drives the network, stands a few seconds at each point, and
  leaves over the vehicle-junction that suits its next objective. When it doesn't get along it reverses, after three
  times it takes another way.

**In git** the networks are `navzones/<level>_<mode>.json` (the debug-server writes them when it applies them with
`save`). The fun-bots-helper imports them into `mod.db` with the traces (`import_traces`) and exports them with
`export_traces`.

**All maps**: `python -m funbots_debug.census run --all --modes ConquestSmall0,ConquestLarge0,RushLarge0 --warmup 180
--apply` makes census and networks of every waypoint-file of these modes, one level after the other (rush only waits
45 s: no capture zones to measure). That takes about 7 minutes per level. For a long run let the driver start the
game-server again after a crash (the level is tried once more):
```
python -m funbots_debug.census run --all --modes ConquestSmall0,ConquestLarge0,RushLarge0 --warmup 180 --apply \
    --restart-command 'cd /home/jo/Games/vu/client && wine vu.com -gamepath "<BF3>" -serverInstancePath "$(winepath -w <instance>)" -server -dedicated -high60'
```
`python -m funbots_debug.census cut ../../navzones/*.json -v` then lists which paths lie inside of zones (drop), run
through them (cut) or have to stay (vehicles, actions): a dry run, nothing is changed.

A point is `[x, y, z, clearance, cover, flags]`: clearance is the distance to the next wall, cover the number of the 8
directions with a wall within 1.5 m, flags 1 = in the zone, 2 = indoors, 4 = crouch. A connection is
`[a, b, length, corners]` (the corners of the way between the points, if it isn't straight). A junction is
`[path, point, network-point, walking distance, position of the waypoint, corners]`, the corners of the way from the
network-point to the waypoint (around the walls of the room of an MCOM, for example).

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
