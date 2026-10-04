# Supporting a new map

How a level and mode gets the bots moving: what someone has to record in the game, and what the tools do with it
afterwards. The goal is that recording a few paths is all the manual work, and one run of the tools does the rest.
The sections *Today* and *Gaps* show how far that is.

## What the bots need

| Mode | Needed | Made by |
|---|---|---|
| Conquest (all layouts), Rush, Squad Rush, Tank Superiority | waypoint paths between the areas, the mesh with its zones, navigation paths | census and cut (below) |
| Team / Squad Deathmatch, Gun Master, Scavenger, Domination | waypoint paths only; the bots walk them and switch at links at random | recording, labeler (links) |
| Air Superiority | nothing: the bots spawn in jets | – |
| Capture the Flag | not supported yet | – |

On a level with a mesh the bots walk the mesh inside the areas (capture points, MCOMs, bases, spawns) and the
navigation paths between them. Paths keep only labels that say what they are for: the way to a vehicle
(`vehicle tank1 us`), to arm an MCOM (`mcom 2 interact`), to place a beacon (`beacon`). Vehicle-paths keep all their
labels, the vehicles still find their way by them. See `README.md`, *The mesh and its zones*.

## Today

### 1. Record in the game (node editor)

- **Paths on foot** that connect the areas: from each base and capture point (or MCOM) to its neighbours, a few
  alternatives where the level has them. Inside the areas nothing is needed, the mesh covers them. Paths only have to
  reach into an area; the cut trims them at its edge.
- **Rush, Squad Rush**: one path per MCOM that ends at the MCOM, with the action *MCOM* at its end, labelled
  `mcom N interact`. The census takes the position of the MCOM from it. For new levels also the paths of the bases
  (`base us N`, `base ru N`): the census measures the bases around them.
- **Vehicles**: a path from the foot network to each vehicle, with the action *vehicle* at its end, labelled
  `vehicle <name> <team>` (e.g. `vehicle tank1 us`); `spawn vehicle ...` for vehicles the bots spawn in.
- **Vehicle-paths**: driven in the vehicle, tagged with *Vehicles* `land`, `water` or `air`.
- Optional: ways to a spot for a beacon (action *beacon*, label `beacon`).

Then save in the game (the paths go into `mod.db`) and export them into `mapfiles/<level>_<mode>.map` with the
fun-bots-helper (`export_traces`).

### 2. Labels and links (debug-server)

With the level running and the debug-server connected: **Load waypoints**, **Auto-label**, **Write .map** (or
`python -m funbots_debug.paths ../../mapfiles/<map>.map --server http://127.0.0.1:8765 --write`). This links path ends
to each other and sets the loop mode. In rush, `python -m funbots_debug.paths.fix_bases` fixes the ways out of the bases.

### 3. Census and mesh

```
python -m funbots_debug.census run --map "<Level> <Mode>" --apply
```
Needs the game server with RCON. The zone probe measures the capture zones with the bots, the census measures every
walkable surface around the areas, and the mesh with its zones is written to `navzones/<map>.json` and `mod.db`.
About 3 to 5 minutes per level. Check it with `python -m funbots_debug.census report census/<map>.json.gz`: the last
line must say `waypoint-file: same as <map>.map`.

### 4. Cut the paths

```
python -m funbots_debug.census navpaths <Level>_<Mode> -v                       # dry run
python -m funbots_debug.census navpaths <Level>_<Mode> --write --db ../../mod.db
```
Turns the foot paths into navigation paths between the zones, keeps vehicle-paths and the ways to vehicles, MCOMs
and beacons, and connects their links. A few `warning: navigation path N has no junction` are fine.

### 5. Check and commit

Play the level for a few minutes with the debug-server open (*Findings* lists bots stuck on the mesh), then commit
`mapfiles/`, `navzones/` and `mod.db`. For many levels at once see `ALL_MAPS.md`.

## Gaps: what is still manual

| Manual today | Could come from | Where |
|---|---|---|
| *Vehicles* tag on vehicle-paths | the recorder knows whether the player sits in a vehicle while tracing (`NodeEditor:StartTrace`) and its terrain | node editor |
| Ways to vehicles: action *vehicle* and label | the vehicle-spawns of the census (position, team, blueprint): the path end closest to each spawn gets the action, the label comes from the blueprint | cut (`navpaths.py`) |
| `mcom N interact` paths (position and arming point) | the MCOM entities of the census; the arming point a point of the mesh next to the MCOM, no path needed | census, mod (`GameDirector`, `BotZoneMovement`) |
| `base us N` paths (rush bases) | the soldier-spawns of each stage (the census already makes `spawn ...` areas from them); the stage from the order in which the spawns get enabled | census |
| Export from `mod.db` into `mapfiles/` | the debug-server reads the waypoints from the mod already (`nodes` command) | debug-server |
| Several commands per level | one command that runs labels, census, cut and report | debug-server |

With these, recording becomes: walk (or drive) the ways between the areas, nothing else. The order above is also a
sensible order to build it in: each step removes one kind of label from the recording.

## A GUI for all of it

Proposal: a **Maps** page in the web UI of the debug-server, not a separate program. The debug-server already talks
to the mod and to RCON, runs the labeler, the census and the cut, and shows the level on a map. The page would list
every level of `mapfiles/` with its state per step (recorded, labelled, census, mesh, cut, in `mod.db`, tested,
changed since the last commit) and run the missing steps for one level or a selection, with the log and the findings
next to it. The parts of the fun-bots-helper that work on `mod.db` and `mapfiles/` (import and export of traces,
fixes) would move into the debug-server as well; the helper keeps settings, languages and permissions, or gets
merged later.
