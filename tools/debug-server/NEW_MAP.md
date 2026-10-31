# Supporting a new map

All you record in the game are paths between the areas of a level; the **Maps** tab of the debug-server does the rest.

## What the bots need

| Mode | Needed |
|---|---|
| Conquest (all layouts), Rush, Squad Rush, Tank Superiority, Domination | paths between the areas, then census and cut (below) |
| Team / Squad Deathmatch, Gun Master, Scavenger, Capture the Flag | paths only, linked where they meet (CTF: no flag carrying yet) |
| Air Superiority | nothing: the bots spawn in jets |

On a level with a mesh the bots walk the mesh inside the areas (capture points, MCOMs, bases, spawns) and the recorded
paths between them. MCOMs, vehicles and spawns come from the game: no names, labels, actions, `base ...`,
`spawn vehicle ...` or "way to" paths are needed. Vehicle-paths keep their objectives, vehicles find their way by them.

## 1. Record in the game (node editor, <kbd>F12</kbd>)

- **Paths on foot** from each base, spawn and capture point (or MCOM) to its neighbours, with a few alternatives where
  the level has them. Link them where they meet. A path only has to reach into an area: the cut trims it at the mesh.
- **Vehicle-paths**: drive them. A path traced in a vehicle gets its `Vehicles` tag (land, water, air) on its own.

Then save in the game: the paths go into `mod.db`.

## 2. Maps tab (debug-server)

Start the debug-server (`python -m funbots_debug --open` in `tools/debug-server`, or *Debug-Server* in the
fun-bots-helper) and open **Maps**. It lists every file of `mapfiles/` with the steps done for it. Select levels and
run steps; each runs as a job with its output next to the table.

For a new level: **Export from mod.db**, then **Run missing steps**. The census needs the game-server with RCON:
*Start game-server* starts it (and restarts it if it crashes during a census). Then play the level for a few minutes
with the **Live** tab open (*Findings* lists bots stuck on the mesh) and commit `mapfiles/`, `navzones/` and `mod.db`.

| Step | What it does | Command |
|---|---|---|
| Export from mod.db | the paths recorded in the game into `mapfiles/<map>.map` | – |
| Label | links path ends, sets the loop mode | `python -m funbots_debug.paths <file> --write` |
| Import into mod.db | `mapfiles/<map>.map` and `navzones/<map>.json` into `mod.db` | – |
| Census | measures the level in the game and makes its mesh (3-5 minutes) | `python -m funbots_debug.census run --map "<Level> <Mode>" --apply` |
| Cut | trims the paths at the mesh | `python -m funbots_debug.census navpaths <map> --write --db ../../mod.db` |
| Check | rays of the game over the mesh, then the cut again: drops connections through walls | `python -m funbots_debug.census check <map>`, then the cut |
| Report | the checks of the census | `python -m funbots_debug.census report census/<map>.json.gz` |

## Without recording: paths by bots

A layout can get its paths from bots instead (first done for MP_012 Squad Rush):

1. An empty waypoint-file (header and the info line) in `mapfiles/`, imported into `mod.db` together with an empty
   mesh (Maps tab: Import), else the mod loads no mesh for the level.
2. Census (`--apply`), twice on a rush layout: the first finds the spawns; the MCOMs of the engine are taken near
   them, numbered by the stages of the spawn layers (`base1`, `base2`), and the second census measures them.
3. `python -m funbots_debug.census connect <map> --stages`: bots walk the ways between the parts of the mesh and two
   ways between the objectives that follow each other; rush layouts are played stage by stage (README, *A level
   recorded by bots*).
4. Play it (Live tab), commit.

Vehicle paths: `census trace --from ... --to ... --vehicle NAME --test-vehicles ...`, or where another layout of the
level has roads `census roads` (README; Alborz Tank Superiority from the conquest roads: some of them leave the
combat-area of tank superiority, the drives show where).

## More paths for a level that is cut already

1. In the game: load the level, record the new paths (linked to the old ones), save.
2. Maps tab: **Export from mod.db**, then **Label** and **Cut**.
3. Play the level, then commit `mapfiles/`, `navzones/` and `mod.db`.

The paths cut before stay exactly as they are (edits made in the game too). The new ones are trimmed like on a new
level, and where they cross the mesh they become connections of it: a path recorded over a spot where bots get stuck (a
ramp, a railing the census missed) shows them the way there.

**Nothing gets lost:** every step that overwrites a file of the level or its tables in `mod.db` copies them first to
`backups/<map>/<time>-<step>/` (not in git, the newest 50 per level). *Run missing steps* never imports a file over a
`mod.db` that holds other waypoints: export or import by hand, whichever is right.

## New Rush levels

The mod numbers the MCOMs itself: stage 1 is the pair (squad rush: the one) closest to the spawn of the attackers, each
next stage the closest to the one before. Check the numbers on the map (zones `mcom N`) after the census of a new
level: they were right on 24 of 26 levels.
