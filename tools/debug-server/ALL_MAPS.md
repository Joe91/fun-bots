# Running all maps: census, mesh and trimmed paths

These are instructions for an agent working without supervision. For each map of the modes RushLarge0, SquadRush0,
ConquestLarge0, ConquestSmall0, ConquestAssault* and TankSuperiority0, you will:

- start from the released waypoint-file of the map (git `master`: the paths as recorded, with links);
- measure the map with the census (the objectives and the spawns of the game);
- check the mesh with rays of the game;
- trim the waypoint paths at the mesh (the ways between its areas, without names or dead ends);
- write the results into `mapfiles/`, `navzones/` and `mod.db`.

Follow the steps exactly. **Do not change any code.** Do not commit. If something isn't covered here, stop and report.

Paths:

- REPO = `/home/jo/workspace/VU_Server/Admin/Mods/fun-bots`
- DS = `REPO/tools/debug-server`

These are placeholders, not shell variables: write the full paths into each command. The user's shell is fish, so
wrap commands that use `$(...)` in `bash -c '...'`.

## 0. Check before starting

1. `git -C REPO status --short mapfiles navzones`: note what is already modified. Don't touch those files.
2. Maps that are trimmed already have `"Nav"` in their file (`grep -l '"Nav"' REPO/mapfiles/*.map`). They are done
   anew from `master` like all others (step 1 restores them); write down which ones they were.
3. `REPO/ext/Shared/Registry/Registry.lua` must contain `DEBUG_BRIDGE = true`. If it is missing, stop and report.

## 1. Build the map list and restore the released paths

The census measures the level with the paths that are in `mod.db`, and the trim works on them: both need the paths as
recorded (git `master`), not trimmed ones. This writes them into `mapfiles/` and `mod.db` (the mesh of the map is
dropped from `mod.db`, the census makes it anew) and builds the list:

```
cd REPO && python3 - <<'EOF'
import pathlib, re, sqlite3, subprocess, sys
sys.path.insert(0, "tools/debug-server")
from funbots_debug.maps import import_map
from funbots_debug.paths.mapfile import MapData
out = []
for f in sorted(pathlib.Path("mapfiles").glob("*.map")):
    level, _, mode = f.stem.rpartition("_")
    if not re.fullmatch(r"RushLarge0|SquadRush0|ConquestLarge0|ConquestSmall0|ConquestAssault\w*|TankSuperiority0", mode):
        continue
    text = subprocess.run(["git", "show", f"master:mapfiles/{f.name}"], capture_output=True, text=True).stdout
    if not text or '"Nav"' in text:
        print("no released paths:", f.stem)
        continue
    f.write_text(text, encoding="utf-8")
    import_map(pathlib.Path("mod.db"), f.stem, MapData.load(f), None)
    with sqlite3.connect("mod.db") as connection:
        connection.execute(f"DROP TABLE IF EXISTS {f.stem}_navzones")
    out.append(f"{level} {mode} 1")
pathlib.Path("tools/debug-server/census/all_maps.txt").write_text("\n".join(out) + "\n")
print(len(out), "maps")
EOF
```

Expect about 93 maps. Each one takes about 2–5 minutes (Rush longer), so the whole run takes a few hours. To work in batches, split
the list (for example the Rush maps first). Each batch is its own file and its own `run` in step 3.

## 2. Start the servers

Nothing else may run on the ports. Check with `pgrep -af "vu.com|funbots_debug"`, and stop old instances first.

1. Start the debug-server in the background, with output going to a log:

   ```
   cd DS && python -m funbots_debug > census/debug-server.log 2>&1
   ```

2. Write a start script for the game server. Step 3 needs it too, to restart after crashes:

   ```
   cat > DS/census/start_vu.sh <<'EOF'
   #!/bin/bash
   cd /home/jo/Games/vu/client/
   exec wine vu.com -gamepath "/home/jo/Games/ea-app/drive_c/Program Files/EA Games/Battlefield 3/" \
     -serverInstancePath "$(winepath -w /home/jo/workspace/VU_Server/)" -server -dedicated -high60 -updateBranch dev \
     > /dev/null 2>&1
   EOF
   chmod +x DS/census/start_vu.sh
   ```

   Then run `DS/census/start_vu.sh` in the background.

3. Wait until the mod is connected (about 1–2 minutes):

   ```
   curl -s http://127.0.0.1:8765/api/state | python3 -c "import json,sys; print(json.load(sys.stdin)['status']['modConnected'])"
   ```

   This must print `True`. The `rcon` entry in that status must show `ok: true` as well, because switching maps needs
   RCON. RCON can need another minute after the mod connects.

## 3. Run the census for all maps

Run this in the background and log to a file:

```
cd DS && python -u -m funbots_debug.census run --maplist census/all_maps.txt --apply \
  --restart-command "$PWD/census/start_vu.sh" > census/all_maps.log 2>&1
```

For each map, the command does the following:

1. switches the level;
2. measures the capture zones with the bots (zone probe, Conquest only, a few seconds per capture point);
3. runs the census;
4. with `--apply`, builds the mesh and saves it to `navzones/<map>.json` and into `mod.db` through the mod.

A crashed game server is restarted once per map. At the end, the original map list is loaded again.

Check the log now and then (`tail census/all_maps.log`). Per map, the log should show these lines:

- `saved ...json.gz`
- `zone probe: N zones` and `capture zones measured: N/M` (Conquest only; "not active" capture points are layouts
  of another mode)
- `networks: X zones, Y junctions, .../navzones/<map>.json`

Write down every map that shows `failed`, `error`, `no answer from the mod` or `not applied`.

## 4. Check each census

For every map that succeeded:

```
cd DS && python -m funbots_debug.census report census/<Level>_<Mode>.json.gz
```

The last line must say `waypoint-file: same as <map>.map`. If it says `differs`, the waypoints in the game don't match
the file. Skip that map in step 5 and report it.

## 5. Check the mesh and trim the paths

Run this one map at a time. The check switches to the level (a fresh round, the bots killed) and casts rays of the game
over the mesh, then the trim writes the result:

```
cd DS && python -u -m funbots_debug.census check <Level>_<Mode>
cd DS && python -m funbots_debug.census navpaths <Level>_<Mode> --write --db ../../mod.db
```

This rewrites `mapfiles/<map>.map` and `navzones/<map>.json`, and updates both tables of the map in `mod.db`.

Write down the following for each map:

- `N paths (...) -> M paths (...)` and the number of junctions;
- `foot paths dropped that lead nowhere` (and `more foot paths without junctions dropped`, if shown).

`is missing` or `cut already` means step 1 didn't restore the map: skip it and report it. A map where almost every
path was dropped (`M` close to the number of vehicle paths) needs a look: report it.

## 6. Spot test (optional, about 5 minutes per map)

Spot-test a few maps, at least one per mode. The mod loads the new paths on a level change, so start each test with
a level switch:

```
curl -s -X POST http://127.0.0.1:8765/api/rcon -H 'Content-Type: application/json' -d '{"words":["mapList.setNextMapIndex","<index>"]}'
curl -s -X POST http://127.0.0.1:8765/api/rcon -H 'Content-Type: application/json' -d '{"words":["mapList.runNextRound"]}'
```

`<index>` is the zero-based line of the map in `/home/jo/workspace/VU_Server/Admin/MapList.txt`. A map that isn't in
that list can't be tested this way: note it as untested.

After 5 minutes, sample `/api/state` a few times:

- Most living bots should have a `zone` or be moving (`state` is `Moving`).
- The positions of the bots should change between samples.
- In Conquest, `objectives.flags[*].team` should change over time. In Rush, `objectives.mcoms` should get destroyed.

Bots fight little without a real client, so judge only whether they move, not whether they win.

## 7. Clean up and report

1. Stop both servers: `pkill -f funbots_debug`, then kill the `vu.com` processes listed by `pgrep -af vu.com`.
2. Restore the map list. If the census was interrupted, send this RCON command while the server still runs:
   `["mapList.load"]`.
3. Report a table with one line per map: census ok, paths after the trim, junctions, dropped dead ends, spot-tested
   yes/no.
   Separately, list the failed and skipped maps with the reason for each.
4. Don't commit. The user tests and commits.

## Known issues

- `COOP_006_ConquestSmall0` is a co-op level: it doesn't load as a multiplayer level. Leave it out of the list.
- Don't kick the bots before the census (`--kick-bots`): on Rush maps the game server crashed 1–2 minutes later. The
  census kills them instead (quiet, the default): each level is loaded anew, the bots don't fight or take vehicles
  until the zone probe is done and are dead during the census, so nothing of the level is destroyed when it's measured.
  The bots spawn again with the next level.
- Zones of capture points are named after the engine ("ID_H_US_A" gives "a"), not after the paths. HQs are recognized
  by the engine (`CapturableType` 1), also with names like "_US_HQ_1".
- The zone probe needs at least 4 bots on foot. On maps where all bots sit in vehicles it waits up to 30 s and then
  fails with "no bots on foot"; the census still runs, with estimated zones. Run that map again.
- Small layouts of a level often contain the capture points and spawns of the large layout too. The probe reports
  those capture points as "not active". Their spawns give extra "spawn ..." zones, often empty and unconnected:
  harmless.
- On carrier maps (MP_017, XP1_002, XP1_004) the "base us" zone isn't connected to the rest: the US starts on a
  ship and reaches the shore by vehicle. That's expected.
- A map that is trimmed already can't be trimmed again. Redoing it (after a change of `navpaths.py`) needs the
  released file written back (step 1 for that map) while its census stays: then only `navpaths ... --write --db`.
  After a new census always run the check again: old checks don't match a new mesh.
- Foot paths lose their names, the ways to vehicles, beacons and MCOMs are dropped: the bots do that on the mesh.
  Vehicle paths stay as they are; the land ones (not amphibious) are walked by the soldiers as well.
- If the debug-server answers with errors or the mod disconnects repeatedly, stop and report the last 50 lines of
  `census/all_maps.log` and `census/debug-server.log`.
