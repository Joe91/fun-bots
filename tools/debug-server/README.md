# fun-bots debug-server

Watch and analyze what the bots do without joining the game server. The mod streams its state to this
server, and the server shows it on a live map in the browser, runs analyzers on it, and can record it for later.
The server can also send commands back to the mod (test raycasts, waypoint export, map scans).

Only the Python standard library is needed (Python 3.9 or newer). There is nothing to install.

How a new level gets supported (recording, census, mesh, trim) is in `NEW_MAP.md`, the run over all levels in
`ALL_MAPS.md`.

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

Two tabs: **Live** (below) and **Maps**.

**Maps** lists every waypoint-file of `mapfiles/` with what is done for it (census, mesh, trim, `mod.db` against the
files, changes since the last commit, the steps still to do) and runs steps for the selected levels as jobs, one after
the other, with their output: export from `mod.db`, label, import into `mod.db`, census, trim (again from the untrimmed
version in git) and report (`funbots_debug/maps.py`, `GET /api/maps`, `POST /api/maps/run`). *Start game-server* runs
`--game-command` (default `census/start_vu.sh`), which the census also uses after a crash. How a new level gets
supported: `NEW_MAP.md`.

The **Live** tab:

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

On levels with a mesh (conquest, rush, squad rush, tank superiority, see below) the soldiers find their way over the
mesh and the paths between its areas, without names: the trim drops them from the foot paths, and the ways to vehicles,
to arm an MCOM, to place a beacon (the bots do that on the mesh). Vehicle-paths keep all their objectives, the vehicles
still switch paths by them. The labeling below
prepares the waypoints of a level before its census (the bases of rush and the MCOMs come from their paths), and is what
the deathmatch modes and levels without a mesh use: there the bots walk the paths and switch at links at random.

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
that all carry the base. In the game the soldiers don't spawn on base-paths anymore (spawns of the game, see the mesh
below), and the paths of the bases are trimmed at their zones; this only matters for the vehicles and for the census.
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
python -m funbots_debug.census run --current                       # the level that runs now
python -m funbots_debug.census run --map "MP_001 ConquestLarge0"   # switches the level over RCON first
python -m funbots_debug.census run --maplist ../../MapList.txt     # every level of the list
python -m funbots_debug.census report census/*.json.gz --issues 40
```

The engine doesn't tell the radius of a capture point (`CaptureRadius` is 0, the level sets it in a way the server
can't read), only who is inside. So before the census the mod measures the zones with the bots (zone probe,
`ext/Server/Debug/ZoneProbe.lua`, command `zone_probe`): one bot per direction (16 around each capture point) is put
at a distance, and the distance where it stops being inside is searched (about 0.8 m exact). A few seconds per capture
point; the debug-server turns the result into the shape of the zone (`census/zones.py`). A capture point nobody is
inside of even next to it is the layout of another mode (loaded as well, e.g. a second "C" on XP3_Alborz) and is
skipped. Then the census runs with 20 ms of raycasts per update (`--budget-ms`; about 100,000 raycasts per second is
the most the server does, from about 20 ms on). Kicking the bots before (`--kick-bots`) is only 5 % faster and crashed
the game-server on rush maps, 1 to 2 minutes into the census (likely the vehicles they leave behind). Without the probe (`--no-probe`) the zones can still be measured from the bots
playing (`--warmup SECONDS`): only as far as they went. A census without explicit `areas` puts its grids around the
measured zones.

The census measures the level as it is at the start of a round (quiet, the default): before it switches the level
(also if it runs already: a new round) it sets `BotsAttackBots` and `UseVehicles` of the mod to false over RCON, and
after the zone probe it kills all bots (`funbots.killAll`: they don't respawn until the next level). Bots that fight
destroy walls (tanks, rockets) and an MCOM that goes off destroys what is around it: the census would see the ways
through them, which are walls again in the next round. Afterwards the settings are restored, the bots spawn again with
the next level. The check (below) does the same. `--no-quiet` measures the level as it runs.

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
  to the neighbour-cells, so the walkable area and its connections are known without waypoints. Ground under more than
  1.3 m of water isn't walkable (the soldiers swim there: the seabed off the shore of MP_018 was a mesh).

The report checks: paths in the air without the `Vehicles` tag `air`, waypoints floating above the ground (more than
1.5 m is never reached), low ceilings that are walked
upright, walls and obstacles between waypoints without a jump, blocked links, capture points without waypoints inside
the radius, waypoints outside the combat area, spawns far from the waypoints, and how much of the walkable area around
each objective can be reached from the waypoints.

The raycasts ignore soldiers, but vehicles standing around block them (`nextHit` names what was hit). The census sees
the level before anything is destroyed (quiet, above): walls that can be shot away (the boards over the doors of the
train with MCOM 7 on MP_Subway) are walls, the bots shoot them away in the game (*Breaching* below).

## The mesh and its zones

Inside a capture zone, around an MCOM and in a base the bots move freely instead of along waypoints; waypoints are only
needed between these areas (and for vehicles, actions, jumps). `funbots_debug/census/navzones.py` makes one walking
mesh for the level from the grids of a census: points about every 5 m (the open spots first), the walkable connections
between them, and the junctions with the existing waypoints (where a path enters, leaves or ends in an area). Areas
overlap (rush: the bases of one stage lie at the MCOMs of another), so their grids are put onto one lattice first and
there is one mesh; the zones are labels on it (the list of their points). Only the parts of the grid the waypoints reach
get points, so roofs and closed rooms stay out. Where a path walks from one part of the mesh into another one the grid
doesn't connect (stairs, ladders, jumps the vertical rays don't see), the mesh gets a connection along its waypoints.
Bots only walk to points they can reach.

```
python -m funbots_debug.census navzones census/*.json.gz             # writes census/<level>_<mode>.navzones.json
python -m funbots_debug --navzones census/XP3_Alborz_ConquestLarge0.json.gz   # show them on the map, also offline
```

The debug-server also makes them after every census, or on `POST /api/navzones` (`{"file": ...}`, default: the census
of the running level). On the map (layer *Mesh*) connections inside the zone are green, outside blue-grey,
points indoors have a blue ring, points that need crouching an orange one, the junctions with the waypoints are dashed
orange. The zones are the areas around their points (green capture points, blue bases, orange MCOMs).

Areas are made around the capture points, the MCOMs and the HQs of the running mode (`base us`, `base ru`, 60 m). The
spawns come from the engine only, never from waypoints: the alternate spawns (`AlternateSpawnEntityData`) of the layers of
the running mode (`SpawnPoints.lua`, collected while the level loads them: after a reload of the mod within a level the
level has to be loaded again), and the ones the layer of the mode links from the common layers of the level. A capture
point spawns its team there, up to 70 m from the flag. Without any, the soldier-spawn-entities are used. Spawns no
other area covers get an area of their own: all spawns of a group (40 m apart at most) and 15 m around the outer ones
(`spawn us 1`, `spawn 1` for both teams; 15 m: a single spawn still gets a mesh the bots can use). In rush they are zones (kind `base`), elsewhere only mesh (kind `spawn`, no
objective). The mesh keeps every part a spawn lies on, as the parts with waypoints. The debug-command `spawns` lists
them. Spawn-entities may float above the ground, the soldiers appear on the ground below. The paths are trimmed at all
of these areas (`areas` of the mesh-file: the ones that are only mesh).

Only the objectives and the spawns get mesh: between them the bots walk the recorded paths. On request the census
measures more (census arguments): `ways: true` the straight way from each group of spawns to its target (discs of 12 m,
kind `way`), `corridors: true` the ground along the foot paths (discs of 5 m, `corridor N`), `hubs: true` where foot
paths end outside of every area (`hub N`). The mesh got too big and broke into pieces with them, so they're off.

Land vehicles get a mesh of their own (`vehicle`): the same way, but only over wide and open ground
(1.8 m to the next wall, slopes up to about 41°, no roof below 4 m), a point about every 10 m, attached to the paths with
`Vehicles: land`.

**In the game** (`ext/Server/NavZones.lua`, `ext/Server/Bot/BotZoneMovement.lua`, on every level with a mesh):
`POST /api/navzones/apply` (`{"save": true}`) sends the mesh shown on the map to the
mod, which saves it in the table `<level>_<mode>_navzones` of `mod.db` (one row `@mesh`) and loads it with the waypoints
from then on. A bot that reaches a junction of the mesh leaves the waypoints and decides where to go (`_ZoneDecide`): in
the zone of its objective it walks from point to point and waits at each (longer and crouched in cover when it defends);
else it walks the mesh to that zone if the mesh leads there, or to the junction of the path its route leaves the mesh
at (`NavRoutes`); without route over the junction of a path closest to the objective. A bot that gets stuck between two points (4 s without progress) takes another way, and all bots avoid that
connection until the level ends (given up three times it's removed); after three of them it goes back to the waypoints,
after three such zones in a row it respawns. Off the mesh a bot that doesn't get 5 m closer to the next node of the
routes on its path (an end, a link, a junction; or to its objective) for 20 s is put onto the mesh up to 30 m away (`TeleportIfStuck`), after 50 s
killed (`Registry.GAME_DIRECTOR.OFF_MESH_*`), not while it fights, waits or does an action. The
debug-server lists these spots under *Findings* (analyzer `zones`). In the snapshot a bot on the mesh has `zone` (the
zone it walks in, `@mesh` outside of the zones) and `zoneExit` on its way out.

- **MCOMs**: inside the zone of an MCOM a bot asks the GameDirector every second whether it shall arm (attackers, MCOM
  not armed) or disarm it (defenders, MCOM armed), at most two per team. Then its objective becomes `mcom N interact`:
  it walks over the mesh to the point next to the MCOM (up to 8 m, on a part of the mesh with at least 10 points),
  steps up to it, looks at it and interacts (`Bot:_ZoneAction`), no path needed. Without such a point (a room the mesh
  doesn't reach) it walks the recorded way to it instead (the paths named `mcom N interact`). Where the MCOM is: the interactions of the engine (`GameInteractionEntityData`, about 1 m from it,
  `GameDirector:GetMcom`), where a recorded path `mcom N interact` exists also its action-node (where to stand) and
  yaw. A new rush level without these paths gets its MCOMs numbered from the attackers' spawn
  (`GameDirector:_NumberEngineMcoms`, see `NEW_MAP.md`). The defenders hold the zone of their MCOM: they wait longer at
  each point, crouched where there is cover (`Bot:_ZoneDefends`). While fighting, an attacker keeps going to its MCOM
  now and then and always close to it (`Bot:ShouldPushWhileShooting`, `RUSH_PUSH_*`), a defender the same while its
  MCOM is armed (to disarm it).
- **Vehicles**: the team of a vehicle is the one of the vehicle-spawn of the engine it spawned at
  (`GameDirector:_VehicleSpawnTeam`). A vehicle in a base of its team (an HQ within 120 m, in rush a spawn of the team
  within 60 m) is spawned into directly, like jets: bots that spawn at the game spawns get into it at once
  (`m_SpawnableVehicles`). Every other
  vehicle that stands still with a free seat is an objective (`vehicle <id>`, `GameDirector:_RefreshVehicleEntities`):
  a bot walks over the mesh to it and gets in as soon as it is next to it (5.5 m from the middle, 10 m if it doesn't
  get closer). Only while a seat a bot may take is free (`Vehicles:HasFreeBotSeat`: seats kept for players, at most
  `MaxBotsPerVehicle`, air vehicles and jets only if allowed). No labels or paths `vehicle ...` / `spawn vehicle ...`
  are used on levels with a mesh (the trim drops them).
- **Rush spawns**: the bots spawn where the game spawns its players (the alternate spawns of the stage); one bot per
  free vehicle at the spawn next to it (`GameDirector:ReserveVehicle`, only vehicles up to 100 m from a spawn of the
  team that is on).
- **Forward spawns (rush)**: the game still offers the base of a stage that fell, and spawns bots there now and then.
  A bot that spawned more than 100 m farther from the MCOMs than the most forward spawn of its team starts at one of
  the forward spawns instead (`GameDirector:ForwardSpawn`, on the ground below the spawn).
- **Paths after a spawn**: the closest path is searched along all of each path (they are trimmed: their first
  waypoints can be far off) and among the routes' paths, roads included (`GameDirector:FindClosestPath`).
- **Route spread**: each bot weighs stretches a bit differently (`NAV_ROUTE_SPREAD`), at most 15 m more
  (`NavRoutes` `SPREAD_MAX`), and not when it decides between the mesh and the path it is on: a bigger spread made
  loops over nearby junctions look shorter. A bot doesn't go back onto the piece of the mesh it left within 20 s in the
  middle of a path (`Bot:_BackOntoLeftPart`, MP_018 spawn 7).
- **Last resorts**: a bot on foot that doesn't get 5 m closer to its objective for 90 s respawns (not within 30 m of
  it or in its zone, not while it fights; event `no_progress`, `GameDirector:_CheckObjectiveProgress`), on a mate away
  from there if it spawns close to that spot again (a rush base behind a border that stays closed). A ground vehicle
  whose driver doesn't get 5 m away for 30 s (not waiting for passengers, not at its objective; also an aircraft that
  stands on the ground, a point of the mesh close below) is left by all bots in it (event `vehicle_stuck`,
  `_CheckVehicleProgress`), also one that doesn't get 10 m closer to its objective in 90 s (back and forth between two
  waypoints), one on its side or roof after 5 s, an unarmed one standing at an own capture point, a launcher (TOW,
  Kornet) without a target for 30 s. A vehicle that got stuck is no objective for 5 min unless it moved; launchers are
  objectives only within 100 m of a capture point or MCOM. A bot on foot that doesn't get within 10 m of the vehicle it
  was sent to in 30 s gives it up for 5 min (`vehicle_unreachable`); one that got out or gave a vehicle up isn't sent
  to it again for 60 / 20 s. Drivers prefer attacking (defending seems 1000 m farther). An "exit" on a vehicle path
  counts only after 50 m of driving (bikes spawned at the end of a path were left at once). A passenger (also on an outer seat or a mounted weapon) whose seat doesn't move for 45 s
  and that doesn't fight gets out (event `passenger_out`), still on it 5 s later it respawns (`passenger_respawn`).
  A passenger whose vehicle is gone (destroyed, thrown off) walks on at once (`StateOnVehicleIdle`). A helicopter far
  from its target flies at least 40 m above where it took off: a target far below (MP_013: the base on the mountain,
  the MCOMs in the valley) gave no throttle, it never took off. A bot runs after the target of C4, repair, revive or a vehicle to
  get into at most 8 s per target (a vehicle that drives on, a launcher on a ledge it can't get to), then it uses no
  C4 for 20 s (`StateAttacking`). An aim that can't
  be solved (NaN) keeps the view (`Bot:UpdateYaw`): the bot spun around its axis without end.
- **MCOMs behind walls**: without a point of the mesh in sight of the MCOM the closest ones are taken (up to 25 m),
  the bots shoot their way through what can be shot away (Subway MCOM 7). Only points on the floor of the MCOM (at
  most 2 m above its interaction point, 2.5 m below): from a floor or rubble above it the bots interacted in vain
  (XP4_Rubble MCOM 2). Without a recorded spot to arm it from (the trim drops the ways to the MCOMs) the free spots
  1 m around it are found with rays (free at chest height, ground below, `GameDirector:_McomStands`); after each try
  that failed the next bot takes the next one (`McomTryFailed`). The middle of the MCOM's zone is the spot the
  recording soldier stood on: it is tried first. The bot aims at the interaction of the engine (pitch from its eyes),
  jumps up to a spot higher than it, and is put onto the spot if it is still not there after 2.5 s within 2.5 m
  (XP3_Desert MCOM 2 stands on a platform the mesh doesn't cover). Points up to 2 m above the MCOM count (MP_018
  MCOM 3).
- **No route from its part of the mesh**: the bot walks straight to the closest point of another part from which a
  route leads on, up to 30 m away, else up to 120 m over open ground (at most 1 m up or down per 4 m, plus 3 m): a
  spawn on a piece of the mesh the census didn't join to the rest (18-110 m on Rubble, Caspian Border, XP5_004). Not
  from a ship or a carrier (150-900 m): the boats are the way there (`Bot:_ZoneRejoin`).
- **Stranded**: a spawn from which neither the mesh nor the paths lead to any objective (the ship of the
  attackers in stage 1 of MP_018: the boats are their way) spawns the bot on a squad-mate (or its beacon, its vehicle)
  more than 60 m away whenever there is one (`GameDirector:IsStranded`). Else the bot waits there: the GameDirector only
  gives a bot on the mesh objectives it gets to (`Bot:CanReach`), a vehicle next to it as soon as there is one. Without
  an objective and without a way to any objective or vehicle for 30 s it respawns at such a mate (`stranded`,
  `GameDirector:_CheckStranded`). A bot
  on the mesh without a way to its objective only goes onto a path within 30 m (`Bot:_ZoneNoWay`), not straight to one
  far away.
- **Rush border**: the area of the next stage opens a while after the last one fell, the objectives are the new MCOMs at
  once. A bot that leaves the combat area (`CombatArea:PlayerDeserting`) walks back over the points it passed (to one at
  least 15 m behind it, the last one can be outside already), stops as soon as it is inside again
  (`CombatArea:PlayerReturning`) and waits there 6 s, then tries again (off the mesh it turns around on its path). Not
  back inside within 10 s: it was outside already (the area got smaller), it goes on (`Bot:OnCombatAreaLeft`,
  `Bot:UpdateBorder`).
- **Bases and spawns**: bots that spawn at the spawn-points of the game (`SpawnMethod.Spawn`) start on the mesh there
  (a base, a spawn, a capture point; up to 30 m away they walk straight to it) and go where their objective is as soon
  as they have one. In conquest and rush the bots always use the spawn of the game once the level has a mesh
  (else they spawn on random waypoints away from the enemy, as in the deathmatch modes). In conquest they spawn at a
  capture point of their team at the front (closest to one the team doesn't hold, at random among the ones up to 60 m
  farther back; `BotSpawner:_FindClosestSpawnPoint`), at the HQ only without capture points, or for a vehicle outside of
  the bases (`PROBABILITY_SPAWN_FOR_VEHICLE`, at the spawn closest to it). Squad-spawns on a mate
  on the mesh start on it as well. A bot only starts at a point it can walk to straight (rays at knee and chest height,
  `NavZones:ZoneAtVisible`), not on an island of the mesh (a nook next to the spawn the checks cut off, fewer than 10
  points: no way leads on); with none in sight within 30 m it is put onto the closest point at once.
- **Hazards**: the census sees the ground, not that it kills (the rails in the metro of MP_Subway). When a second player
  dies in a damage area (weapon `DamageArea`) within 3 m of an earlier death, the points of the mesh within 2.5 m are
  left out until the level ends (`NavZones:OnDamageAreaDeath`). Deaths outside of the combat area (`CombatArea` events:
  the border, the defenders left in the area of a stage that fell) don't count.
- **Breaching**: a bot that doesn't get along (on the mesh or on a path) with a wall of a material bullets go through
  (`MfPenetrable`: wood, boards, glass) right in front of it, towards its target, stands, turns to it and shoots at it for
  2.5 s, then goes on (at most twice per target; `Bot:_TryBreach`). On MP_Subway the boards over the doors of the train
  with MCOM 7 need that. Concrete and rock have no such flag, nothing happens there.
- **Back to its point**: a bot that doesn't get back to its own point of the mesh (pushed off it, came onto the mesh
  beside it) blocks the connection from the point it stands at to that one, for all bots (a railing or a bench the
  census and the checks don't see).
- **Stuck on the mesh**: beside the line of the connection (pushed aside, a corner cut) the bot steps back onto it
  sideways, the census found the line free (a pillar next to it held the bots). A bot that leaves a vehicle (bails out
  of a helicopter) goes onto the mesh where it lands. It only goes onto the mesh at a junction it is next to (6 m), and
  the obstacle-handling of the paths only teleports a bot onto a waypoint up to 10 m away.
- **Smoothing** (`Registry.BOT.ZONE_SMOOTHING`): on the way from point to point a bot turns towards the next point
  before it gets there, within the room around both points (their clearance, at most 2.5 m), not at corners around
  walls, on narrow ways, steps or where it crouches (`Bot:_ZoneSmooth`).
- **Land vehicles** (`Registry.BOT.USE_VEHICLE_ZONE_NETWORKS`, experimental): a driver that reaches a junction of the
  vehicle-mesh in the capture point of its objective drives the zone there, stands a few seconds at each point, and
  leaves over the vehicle-junction that suits its next objective. When it doesn't get along it reverses, after three
  times it takes another way.

**In git** the meshes are `navzones/<level>_<mode>.json` (the debug-server writes them when it applies them with
`save`). The fun-bots-helper imports them into `mod.db` with the traces (`import_traces`) and exports them with
`export_traces`.

**All maps**: `python -m funbots_debug.census run --all --modes ConquestSmall0,ConquestLarge0,RushLarge0 --apply`
(also `ConquestAssault*`, `SquadRush0`, `TankSuperiority0`; see `ALL_MAPS.md`)
makes census and mesh of every waypoint-file of these modes, one level after the other. That takes about 2 to 4
minutes per level (rush longer: more areas). For a long run let the driver start the game-server again after a crash
(the level is tried once more):
```
python -m funbots_debug.census run --all --modes ConquestSmall0,ConquestLarge0,RushLarge0 --apply \
    --restart-command 'cd /home/jo/Games/vu/client && wine vu.com -gamepath "<BF3>" -serverInstancePath "$(winepath -w <instance>)" -server -dedicated -high60'
```

A point is `[x, y, z, clearance, cover, flags]`: clearance is the distance to the next wall, cover the number of the 8
directions with a wall within 1.5 m, flags 1 = in a zone, 2 = indoors, 4 = crouch. A connection is
`[a, b, length, corners]` (the corners of the way between the points, if it isn't straight); along waypoints
`[a, b, length, corners, 1, jumps]`: the corners where the soldier who recorded the waypoints jumped (their extra-mode),
the bots jump there as well. Waypoints up or down a ladder give no connection (the bots can't climb on the mesh, the
trim keeps the path there). A junction on an island of the mesh (fewer than 10 points, the game drops it) is moved to
the closest point of a bigger part up to 6 m away on its floor. A junction is
`[path, point, mesh-point, walking distance, position of the waypoint, corners]`, the corners of the way from the
mesh-point to the waypoint (around the walls of the room of an MCOM, for example). A zone is `{name, kind, center,
radius, zone, inside, vehicleInside}`, `inside` the indices of its points.

### Checking the mesh in the game

The census measures walls with short rays between its cells. A ray that starts inside of a solid (a wall, a slab, a
rock) doesn't hit it, and its rays don't see the detail-meshes of a level. Where areas overlap, the grids are merged,
and a wall one area measured stays a wall even if another one saw nothing there (`_Merged`). What is still missed,
the check finds with rays of the game over the finished mesh (`census/check.py`, command `rays` of the mod):
```
python -m funbots_debug.census check MP_Subway_RushLarge0       # switches to the level, saves census/<map>.checks.json
python -m funbots_debug.census navpaths MP_Subway_RushLarge0 --write --db ../../mod.db   # trim again: without them
```
Every connection is cast along its way at 1.0 and 1.3 m in both directions (hit: blocked; at knee height only it's a
step), every point up to 1.0 m (no room to crouch) and in 8 directions from and towards it (seen from outside only:
inside of a solid), and every junction from its point over its corners to the waypoint (both heights, a wall the grid
missed between them: the side of an escalator on MP_Subway). The mesh is built without them (blocked junctions are not
moved onto that point either) (`navzones.build(..., checks=...)`) and keeps only the parts a
junction leads to. On MP_Subway (rush) that removed 343 of 4051 connections and 105 of 1899 points; a second check
found nothing. In the Maps tab: step *Check* (check, then trim). `census run --detail-mesh` makes the census rays hit the
detail-meshes as well, `--area-layers N` keeps more floors per cell (default 4).

### Paths: trimmed at the mesh

In the areas of the mesh the bots walk the mesh, between them the recorded paths (as released, with their links: the
census runs on them). `census/navpaths.py` trims the paths of a level for that:
```
python -m funbots_debug.census navpaths MP_012_RushLarge0 -v                    # dry run: what it would do
python -m funbots_debug.census navpaths MP_012_RushLarge0 --write --db ../../mod.db
```
1. Foot paths lose their waypoints on the mesh (a point of a part with at least 10 points within 4 m on the same floor,
   inside of the circle of an area): what is left are the pieces between the areas. A piece keeps the first waypoint
   on the mesh at each end, the junction there. A piece shorter than 10 m between two waypoints on the same part of the
   mesh is dropped (the mesh leads there), a path that never comes onto the mesh stays whole, a closed loop is walked
   around once from a waypoint on the mesh.
2. Foot paths lose their names (`Objectives`): the routes need none. The ways to something to do (an action on the
   path: arm an MCOM, get into a vehicle; or named `vehicle ...`, `beacon`, `... interact`) are dropped: the bots do that
   on the mesh. The pieces are walked back and forth.
3. Links stay where both waypoints are left (both ways), the others are dropped.
4. Foot paths that lead nowhere are dropped, again until there is none: fewer than two ways out (a waypoint on the
   mesh or an end up to 15 m from it, a link to a path that is left; a vehicle path always counts; ways out within
   10 m along the path are one). A stub that touches the mesh once, a branch off
   a single link, a path without any connection: a bot on it would walk to its end and back. After the mesh is made
   with the junctions: an end without junction or link is attached straight to the closest usable point up to 15 m
   away (also outside of the areas: a wrong junction is better than a dead end), else the path is cut back to its
   outermost junction or link. Junctions of a foot path within 10 m along it are thinned to one (the one closest to the
   end of the path, `thin_junctions`): with two next to each other on different points of the mesh the bots went off
   the mesh at one and onto it at the other, again and again. Once more with the junctions it really has (a waypoint on the mesh can get none), and without
   foot paths under 50 m whose first and last junction the mesh connects about as well (1.5 times as long plus 20 m):
   bits at the edge of an area. The short ones that are left join parts of the mesh nothing else joins (stairs, a
   door the census didn't see).

Vehicle paths stay as they are, with their names (the vehicles find their way by them), their links to dropped foot
waypoints are dropped. The soldiers walk the roads as well (land vehicle paths, not amphibious ones): the mesh gets
junctions with them (their waypoints are where the vehicle was, attached to the ground up to 3 m below), and to the
routes they seem 1.5 times as long, a foot path wins where there is one. On XP3_Desert the HQs are left on foot only
over the roads, on MP_018 the last stage only. The trim decides on the mesh as it will be: made from the census with the checks of the game
(above). `--write` replaces `mapfiles/<map>.map` and `navzones/<map>.json` (the mesh made again from the census, with
junctions on the trimmed paths; parts without a path or an objective dropped), `--db` also writes both tables of the
level into `mod.db`. Missing ways are recorded as plain paths, without names, and linked where they meet.

**In the game** (`ext/Server/NavRoutes.lua`): the graph of the paths has the waypoints where something can change as
its nodes (the ends of the paths, the waypoints with links, the junctions), the stretches between them (both ways),
the links (2 m added) and the junctions as edges. Per target one field gives the metres from every point of the mesh
and every node to it, over the mesh and the paths (Dijkstra, again when connections were removed or exits blocked, at
most every 5 s; leaving the mesh costs 10 m). The target is the points of the zone of the objective, or the points next
to a vehicle or an MCOM (in sight of it), or the junctions of a vehicle-path of that name. A bot on the mesh walks to
the target if the mesh leads there about as cheaply, else to the junction where its route leaves the mesh. Off the
mesh it decides at each node (`NavRoutes:Step`, `Bot:_CheckForZoneEntry`): onto the mesh at the junction there, over a
link to another path, or on along its path in one of the two directions, not straight back to the node it came from.
For 30 s after a bot came onto the mesh from a path, no exit leads straight back to that path node, and for 5 s after
it left the mesh it doesn't go onto it at a junction within 10 m of where it left: the weighing of each bot
(`_Spread`) could send it back and forth there.
Between the nodes it keeps its direction (`NavRoutes:Direction`, also for `NodeCollection:ObjectiveDirection`). Where
the routes don't know the objective the old path-switching goes on (`PathSwitcher`). An exit a bot doesn't get to costs
100 m more for all bots, the bot tries another one. So does a stretch of a path a bot got stuck on (no progress off the
mesh until it is teleported, `NavRoutes:BlockStretch`, event `path_stuck`), and a junction where a bot came onto the
mesh but didn't get from its waypoint to its point (`NavRoutes:BlockEntry`, a pillar or a corner the census measured
too open): the levels have issues no tool finds (a door that is closed now, a fence, a gap the recording jumped), the
bots learn them during the round.

The bots spread over the ways: each one weighs each path by a factor of its own (1 to 1 + `NAV_ROUTE_SPREAD`, per
life; for the way to the junction and the first stretch only, the rest is what the field says: a stub that leads back
onto the mesh never seems shorter), and each bot of its team on a path or on the mesh on its way to one adds 15 m to
the exit onto that path, at most 45 m (`NavRoutes:_Crowd`): the next ones take the other staircase, the next street, but no long way round. On the mesh the regions of 30 m weigh
differently for each bot as well (`NavZones:Route`).

**On the map** the debug-server loads `navzones/<map>.json` of the running level on its own. The zones as areas (the hull of their points: green capture points, blue bases, orange
MCOMs). The node editor in the game draws the mesh near the player as well (points, connections, junctions in orange,
the names of the zones).

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
