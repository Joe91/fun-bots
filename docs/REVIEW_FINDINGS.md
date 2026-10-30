# Review Findings (branch `dev`)

Open items from the code reviews of `ext/`, `WebUI/` and `fun-bots-helper/` and from the clientless playtests. Fixed
items are removed; their write-ups are in the git history of this file. Checked against the code and playtests of
2026-10-29 for v3.6.0 (47 rounds on 36 layouts: Rush, Squad Rush, Conquest, Conquest Assault, Tank and Air
Superiority, Scavenger, Domination, CTF, TDM, Gun Master, Squad Deathmatch).

---

## Gameplay

**P0. Rush balance differs by level.** 2026-10-18 (12 layouts, 900 s, factor 0.85): 1.7 MCOMs destroyed per 10 min.
XP4_Parl lost all 8 in 9 min and MP_001 lost 6, while XP1_003, XP5_001, XP4_Quake and MP_018 lost only MCOM 1 before
the attackers ran out of tickets (XP5_003: 0-1 MCOMs in four rounds of 10 min). MP_017 varies most: since the kills of
the mod cost no tickets (2026-10-18) one of two rounds destroyed 5 MCOMs, the other armed none (the attackers didn't get ashore: 46 of 117 lives began there,
against 198 of 239). 2026-10-20 (22 rounds of 900 s): 0-6 MCOMs per round, 0 in most. With the attackers getting off
the ship again (2026-10-20: boats, AMTRAC passenger seats) stage 1 still mostly holds: the attack fails at the beach
and the MCOMs, not on the ship.

**P4. Connections with a single way.** From the recordings (`routes.py`): MP_007 Rush spawn 6 ↔ spawn us 3 (paths
39/5), mcom 2 ↔ spawn us 3, mcom 1 ↔ spawn 5; XP3_Valley Rush mcom 2 ↔ spawn ru 8 (path 38). Record another path
there.

**P5. Obstacles on deathmatch paths** (squad deathmatch has no mesh): XP4_Parl path 10 waypoints 80-88, path 4
waypoints 440-442; MP_011 path 1 waypoints 58-66, paths 2 and 4 at (5-26, -5, 45).

**P8. Rush: a defender stuck on the way to the arm spot interacts from where it is** (MP_Subway MCOM 2: 4.7 m away,
`_ZoneAction` stall).

**P10. MP_017 Rush: the helicopters on the top deck of the ship** (y 88) have no mesh around them: bots only get in
by spawning into them. Boats wedge in the well deck at (-212, 66, 578): marked stuck, nobody takes them for a while.
MP_018 Rush is alike: 27 stranded kills a round on the ship (spawn us 6), its boats lie 3.7-5.5 m below the deck
(far ring raised to 6 m), 120 `zone_stuck` of bots in the water next to it at (-243, 87, -856).

**P11. Bots repair only on request.** `Bot:Repair` runs only from the commo rose of a player
(`BotManager:RepairVehicle`): engineers never repair the vehicles of bots (0 repairs in 8 rounds with vehicles).

**P12. Grenades are rare** (0.00-0.05 throws per bot-minute, 0 in two rounds of MP_Subway conquest): only at the last
known position of a target out of sight for 1.2 s, and only with a free arc (`_IsGrenadeArcFree`, ceilings in the metro).
The throws themselves work (median 1.4 s, no timeouts).

**Mobile artillery and light AA (test in game).** Their drivers attack from the gunner seat (`Bot:_CheckForVehicleActions`)
and drive on after it (`Bot:_DriveOnAfterSeatChange`). Check on an Armored Kill map that they switch, score and drive on.

## Navigation

**Z6. The parts of the mesh ignore one-way connections.** `_ComputeParts` joins both ends of a jump down, so a goal on a
deck can be picked from below (`Route` nil, the bot waits a cycle). There are more of them since the rescan: 107 on
34 levels. The lint could flag areas only a drop leads into.

**P9. What is left after the rescan of all levels.** XP3_Valley Rush is back to 4.0 `zone_stuck`/min. MP_Subway: the
junction of path 23 at its first waypoint clips a pillar at (-97.7, 69.8, -123.3). MP_017: bots on path 74 (boat/AAV to
the beach) stand off the mesh for 30-70 s.

**P13. What is left of the corners at the ends of obstacles.** All 97 layouts were cut again on 2026-10-24 with
`navzones._center_corners` (a corner with less than 1 m room moves up to 2 cells to more room; routes keep the cost of
the census corners; a connection the check blocks with moved corners gets the census corners again, `blockedCentered`)
and the check casting across each corner, twice. MP_Subway conquest: the bots that ran into the barrier at (-167, 65,
-432) went from 29 to 6 a round. Left there: bots that drift 1.5 m east of 387-614 into a structure at the south end of
the barrier (-167.8, 65, -435.9), about 10 a round. Gains elsewhere are modest (per rush stage `zone_stuck` 0-25 % lower, conquest about the same); a new
census changes nothing (cells measured again: 0.00 % differ).

**Checks edited by hand** (2026-10-30, in `tools/debug-server/census/<map>.checks.json`, which is not in git: a new check
of these levels writes them anew, put the entries back). MP_001 squad rush: the check blocked the junctions of path 1 to
its waypoints 1-8 one after another, the cut ended at waypoint 9 behind something on the way (the path walks over it, the
bots on the mesh don't): the attackers stayed at spawn us 1, 19-40 `no_progress` a round, no MCOM destroyed. The junction
to waypoint 1 is no longer blocked (as before the rescan): both MCOMs fall, 0-1 `no_progress`. XP2_Office: point (26, 1.3,
-41.5) is boxed in by something the census and the check don't see (60-80 bots a round put across its two connections)
and the connection (-78.5, 3.8, -28.5)-(-78, 4.4, -34.5) leads into the side of the stairs: both blocked. Domination 74 ->
3 bots put across a round, Gun Master 76 -> 32.

**P15. XP3_Desert conquest: a corner of the mesh under a parked vehicle.** The Tunguska at spawn ru 1 (-815.5, 68.7,
-148.4) stands on a corner of the mesh (the check leaves out hits next to vehicle spawns: they usually drive off). The
bots take no AA vehicle, it stays: 1-2 bots a round walk into it (21-46 `zone_stuck`, `vehicle_unreachable` every 30 s
for the buggies behind it).

**P16. MP_013 rush: bots slide down the slope off paths 8 and 9** (stage 3, MCOMs 5/6) and walk straight back to
their waypoint 30 m away at the same height: traps of 30-55 s at (-10..15, 215, 0) and (-112, 225, -14), then
`off_mesh` / `no_progress`. 0-6 traps a round on the old and the new mesh (P13 pilot: 2.1 vs 1.3 in 8 / 9 rounds),
more the longer a round stays in stage 3.

**P17. XP4_FD rush stage 3: the routes lead the attackers out of the combat area.** Up the staircases at (40, 68,
-20) and (40, 68, -40) onto the floor above (y 70), outside the area of stage 3: they turn back, wait at the border
(`Bot:OnCombatAreaLeft`, `BORDER_WAIT`) and take the same way again, 20-25 times a minute while stage 3 lasts (2026-10-29:
130-190 border waits a round, 7-10 `no_progress` respawns). The routes don't know the combat area. Tried: the spot where a
bot leaves the area as team danger (`NavZones:OnKilled`): no change (23 vs 25 a minute), removed.

**M0. Domination (XP2).** The zone of Factory's C has a single mesh point (capture radius 4 m, points 5 m apart): the
census needs a point at the flag for small zones. Each level has two HQs per team of the same name (NavZones warns and
drops the second). Many spawns land next to enemies (XP2_Office 49 %, XP2_Factory 35 %). XP2_Office (also its
Gun Master and TDM): bots get stuck on (-82.5, 3.8, -61.5)-(-78.5, 3.8, -65.5) between desks
(6-12 put across a round), the only way into 23 points of the mesh: not blocked.

**P18. MP_017 conquest large: a spawn 28 m from path 12** at (-663, 68, 63), no mesh within 140 m. The bots walk straight
to waypoint 81 and stand at (-663, 68, 59) for 50-70 s (5 a round), skipping through the waypoints of the path without
moving (`_ObstacleHandling`: a target more than 1.5 m higher or lower counts as reached at once). The spawn rule of
2026-10-29 (`SPAWN_PATH_RANGE`, onto the waypoint) should put them onto the path but doesn't there, cause unknown.

**M1. Scavenger and CTF have no objectives** (no mesh, no labels). Scavenger needs a mesh per layout and the mode in
`SetGameMode`, like Domination. CTF also needs flag pickup (Interact) and carrying the flag to the own stand.

## Stability

**P7. Server crashes.** 2026-10-29/30: three in 1¾ h with 8 game-servers on the host (load ~10 on 12 cores, 8 GB in
swap), none in the 1¾ h after with 7 (~12 server-hours, about 60 rounds). MP_007 conquest large 394 s into the round (a bot
spawned into a vehicle 4 s before), XP1_002 TDM 194 s in and XP5_002 squad deathmatch 140 s in (infantry only); nothing
in the logs (wine output included), nothing common in the last events, the reruns played. Likely the load of the host,
not proven. 2026-10-18: MP_017 Rush 94 s into the round, the log ends without an error. It came ~1 s after
two `stranded` kills on the ship. Those bots respawn into a mate's AAV/boat ~300 m away (`_EnterVehicleEntity` right
after the spawn), similar to the two crashes from debug commands (engine null-read at `vu.com+0x119501f`). Four reruns
with ~120 such respawns didn't crash, so it isn't proven. Earlier: loading XP5_003 CQL and MP_003 Rush once each, and
`modList.reloadExtensions` on several instances at once.

## Code

- **I3.** `Chat.lua` and `UIServer:_onBotEditorEvent` are long `if/elseif` chains: a table of `{permission, handler}`;
  debug-only commands (`!car`, `!caryaw`, `!cardiff`, `!weap`, `!dbg`, `!perks`, `!objectives`) behind `Registry.DEBUG`.
- **I4.** Key permissions by account GUID instead of player name (the GUID is stored, not used).
- **T2.** `FunBotServer:OnServerSettingsCallback` sets `isRenderDamageEvents = true` ("TODO: what is this doing?").
- **T4.** `_UpdateLookAroundPassenger` uses relative yaws (`StateOnVehicleIdle`).
- **T5.** `UpdateVehicleMovableId` calls `ResetSpawnVars()` on every seat change. Check whether resetting the inputs
  and the PID controllers is enough.
- **T7.** `BotSpawner:_ConquestSpawn` has its own spawn path ("unify it?").
- **T10.** Projectile speed of the IFV TOW missile is unknown (`VehicleData.lua`).
- **T11.** Refactoring ideas: inner classes for persona/loadout in `Bot.lua`, own states for revive/repair/C4, weapon
  selection with reload, the gunship state, `OnAutoTeamEntityDataCallback`, defib checks that assume vanilla kits,
  Enter in `BotEditor.js`.

---

## Next

1. **Z6:** the parts of the mesh with the one-way connections (107 on 34 levels now).
2. **P4/P5:** record the missing paths (single ways, deathmatch obstacles).
