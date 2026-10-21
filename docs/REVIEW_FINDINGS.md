# Review Findings (branch `dev`)

Open items from the code reviews of `ext/`, `WebUI/` and `fun-bots-helper/` and from the clientless playtests. Fixed
items are removed; their write-ups are in the git history of this file. Checked against the code and playtests of
2026-10-18 (Rush, Squad Rush, Conquest, Domination, CTF, TDM, Gun Master, Squad Deathmatch).

---

## Gameplay

**P0. Rush balance differs by level.** 2026-10-18 (12 layouts, 900 s, factor 0.85): 1.7 MCOMs destroyed per 10 min.
XP4_Parl lost all 8 in 9 min and MP_001 lost 6, while XP1_003, XP5_001, XP4_Quake and MP_018 lost only MCOM 1 before
the attackers ran out of tickets. MP_017 varies most: since the kills of the mod cost no tickets (2026-10-18) one of
two rounds destroyed 5 MCOMs, the other armed none (the attackers didn't get ashore: 46 of 117 lives began there,
against 198 of 239). 2026-10-20 (22 rounds of 900 s): 0-6 MCOMs per round, 0 in most. With the attackers getting off
the ship again (Next 1) stage 1 still mostly holds: the attack fails at the beach and the MCOMs, not on the ship.

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

**P13. MP_Subway conquest: a corner at the end of a barrier.** 60-92 bots per round are put across at (-167, 65, -432),
about 5 bot-minutes stuck (median 4.5 s each). A breakable barrier at x -166.6 has a gap from z -432.9 to -431.4; the
connection 614-492 leads through it over the corner (-166.5, -431.5), 0.1 m from the end of the barrier. The bots take
the corner as reached 1.0-1.3 m before it, head for 492 and run into the barrier. The census grid (0.5 m) sees the gap,
but A* only avoids cells with less than 0.5 m clearance and the simplified line hugs the end: `line_clearance` 1.0
would fix it but quadruples the corners of the level (675 -> 2698, offline build). Options: a corner placed in the
middle of a gap (most clearance among the cells of the way next to it), or a check ray offset by the radius of a
soldier. Also prepared: no blame for a connection with corners when the bot didn't get back to its point (bots east
of the barrier blamed 614-492 as well). Once (2026-10-20): (-191, 59, -265) 85 times by 18 bots.

**P14. The census check misses a wall through a corner of a connection.** The rays of both stretches end on its
surface (the corner of MP_Subway conquest edge 748-750 at (-82, 68.5, -115.5) lies in a solid). Prepared: `check.py`
casts across each corner (`CORNER_REACH` 0.4 m); applies with the next check + cut of a level.

**M0. Domination (XP2).** The zone of Factory's C has a single mesh point (capture radius 4 m, points 5 m apart): the
census needs a point at the flag for small zones. Each level has two HQs per team of the same name (NavZones warns and
drops the second). Many spawns land next to enemies (XP2_Office 49 %, XP2_Factory 35 %).

**M1. Scavenger and CTF have no objectives** (no mesh, no labels). Scavenger needs a mesh per layout and the mode in
`SetGameMode`, like Domination. CTF also needs flag pickup (Interact) and carrying the flag to the own stand.

## Stability

**P7. Server crashes.** 2026-10-18: MP_017 Rush 94 s into the round, the log ends without an error. It came ~1 s after
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

1. **MP_017 Rush (prepared 2026-10-20, uncommitted, to test):** three causes kept the attackers on the ship. The boats
   respawn 14 m off the dock (no mesh point within the 8 m of a vehicle target), the AAV 3.1 m below it: a second
   ring of 15 m / 4.5 m (`NavRoutes:_ActionTarget`). Bots that fell into the water of the well deck gave up the
   connections of the dock until it was cut off as a small part (`BlockEdge`, `MIN_PART`): no blame for a connection
   more than 1.5 m above the bot (`Bot:_ZoneGiveUpConnection`). 12 seats for 18 attackers: walkers also take the passenger seats
   of an AMTRAC (`Vehicles:WalkInPassengerSeats`). A/B 4 against 4 rounds: full boats 65 % instead of 39 %, the AAV
   with 5 instead of 3, 40 % fewer stranded kills; MCOMs unchanged (P0). Left: a bot put into a far vehicle after
   its spawn (the crash suspect of P7), P10.
2. **Z6:** the parts of the mesh with the one-way connections (107 on 34 levels now).
3. **P4/P5:** record the missing paths (single ways, deathmatch obstacles).
