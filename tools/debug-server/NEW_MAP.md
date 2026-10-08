# Supporting a new map

How a level and mode gets the bots moving: what someone records in the game, and what the tools do afterwards. All a
person has to do is record paths between the areas of the level; the **Maps** tab of the debug-server does the rest.

## What the bots need

| Mode | Needed | Made by |
|---|---|---|
| Conquest (all layouts), Rush, Squad Rush, Tank Superiority | paths between the areas (no names), the mesh with its zones | census and trim |
| Team / Squad Deathmatch, Gun Master, Scavenger, Domination | paths only; the bots walk them and switch at links at random | recording, labels (links) |
| Air Superiority | nothing: the bots spawn in jets | – |
| Capture the Flag | not supported yet | – |

On a level with a mesh the bots walk the mesh inside the areas (capture points, MCOMs, bases, spawns) and the
recorded paths between them (trimmed at the mesh, `NavRoutes` finds the way over both). What they do there comes from the game, not from the paths:

- **MCOMs**: the mod knows where they are (the interactions of the engine). A bot in the zone of an MCOM walks over the
  mesh to it, looks at it and arms or disarms it (`BotZoneMovement`, `Bot:_ZoneAction`).
- **Vehicles**: the team comes from the vehicle-spawn of the engine. Vehicles in a base of their team are spawned into
  directly; every other vehicle standing still with a free seat is an objective of its own (`vehicle <id>`), a bot
  walks over the mesh to it and gets in.
- **Spawns**: the bots spawn at the spawns of the game and start on the mesh there. The census reads the spawns of the
  mode from the engine (also the alternate spawns of the capture points) and measures the area around them (15 m); in
  rush they are the bases of the stages. A path has to lead from there to the next areas.

So no labels, actions or "ways to" paths are needed for these, also no `base ...` or `spawn vehicle ...` paths.
Vehicle-paths keep their objectives: vehicles find their way by them.

## The steps

### 1. Record in the game (node editor)

- **Paths on foot** that connect the areas: from each base, spawn and capture point (or MCOM) to its neighbours, a
  few alternatives where the level has them. No names needed, link them where they meet. Inside the areas nothing is
  needed, the mesh covers them; a path only has to reach into an area, the trim cuts it at the edge of the mesh.
- **Vehicle-paths**: drive them. A path traced while sitting in a vehicle gets its `Vehicles` tag (land, water, air)
  on its own.
Then save in the game: the paths go into `mod.db`.

### 2. Maps tab (debug-server)

Start the debug-server (`python -m funbots_debug --open` in `tools/debug-server`, or the button *Debug-Server* in the
fun-bots-helper) and open the tab **Maps**. It lists every waypoint-file of `mapfiles/` with what is done for it:
census, mesh, trim, whether `mod.db` holds the same waypoints and mesh, and the changes since the last commit. Select
levels and run steps; each one runs as a job, its output is listed next to the table.

| Step | What it does | Command |
|---|---|---|
| Export from mod.db | the paths recorded in the game into `mapfiles/<map>.map` | – |
| Label | links path ends and sets the loop mode (on a level that is cut already only links, no names) | `python -m funbots_debug.paths <file> --write` |
| Import into mod.db | `mapfiles/<map>.map` and `navzones/<map>.json` into `mod.db` | – |
| Census | measures the level (switches to it over RCON) and makes its mesh, 3 to 5 minutes | `python -m funbots_debug.census run --map "<Level> <Mode>" --apply` |
| Cut | trims the paths at the mesh (drops names and the ways to vehicles, beacons, MCOMs), from the file as it is: on a level that is cut already only the paths recorded since are trimmed, the cut ones stay as they are | `python -m funbots_debug.census navpaths <map> --write --db ../../mod.db` |
| Check | rays of the game over the finished mesh (switches to the level), then the cut again: connections through walls and points under ceilings the census missed are left out | `python -m funbots_debug.census check <map>`, then the cut |
| Report | the checks of the census | `python -m funbots_debug.census report census/<map>.json.gz` |

For a new level: record and save in the game, then **Export from mod.db** and **Run missing steps** (import, census,
trim, check). The census needs the game-server with RCON; *Start game-server* starts it with the command in the field (it also
restarts it when it crashes during a census). Afterwards play the level for a few minutes with the Live tab open
(*Findings* lists bots stuck on the mesh) and commit `mapfiles/`, `navzones/` and `mod.db`.

### More paths for a level that is cut already

The files as they are are the only source: nothing is taken from an older version in git.

1. In the game: load the level, record the new paths (link them where they meet the old ones), save.
2. Maps tab: **Export from mod.db** first (the new paths are only in `mod.db` until then), then **Label** and **Cut**.
   *Run missing steps* shows the cut as missing once the file has paths recorded since the last cut.
3. Play the level, then commit `mapfiles/`, `navzones/` and `mod.db`.

What the cut does with the new paths: the paths cut before (first waypoint with `"Nav"`) stay exactly as they are,
also edits made in the game, and are never dropped. The new foot paths are trimmed like on a new level (the waypoints on
the mesh go, the pieces between the areas stay, with their links to the old paths). On the mesh they still count: each
stretch a new path walks between two points of the mesh becomes a connection along it (a new one, or the straight one of
the grid takes the way the person walked). So a path recorded over a spot where the bots get stuck on the mesh (a ramp
they reach over its side, a railing the census doesn't see) shows them the way there. A path that does nothing on the
mesh (a way to arm an MCOM, to a vehicle) is dropped as on a new level.

**Nothing gets lost:** every step that overwrites `mapfiles/<map>.map`, `navzones/<map>.json`, the census or the tables
of the level in `mod.db` copies them first to `backups/<map>/<time>-<step>/` (not in git, the newest 50 per level;
`db.map` is the waypoints of `mod.db` as a waypoint-file). *Run missing steps* never imports a file over `mod.db` that
holds other waypoints: export or import by hand, whichever is right.

### New Rush levels

Without recorded paths to the MCOMs (`mcom N interact`) the mod numbers the MCOMs of the engine itself: stage 1 is the
pair (squad rush: the one) closest to the spawn of the attackers, each next stage the closest to the one before. That
was right on 24 of 26 levels with known numbers; check the numbers of a new level on the map (zones `mcom N`) after its
census. The bases of the stages come from the spawns of the game (`spawn us N`, `spawn ru N`); paths named `base us N`
are not used.

## Still manual

- Recording the paths: walking (or driving) the ways between the areas.
- Checking the MCOM numbers of a new Rush level (see above).
- Testing a level in the game before committing.
