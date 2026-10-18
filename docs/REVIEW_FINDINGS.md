# Review Findings (branch `dev`)

Open items from the code reviews of `ext/`, `WebUI/` and `fun-bots-helper/` and from the clientless playtests. Fixed
items are removed; their write-ups are in the git history of this file. Checked against the code and playtests of
2026-10-18 (22 rounds on 10 servers: Rush, Squad Rush, Conquest, Domination, CTF, TDM, Gun Master, Squad Deathmatch).

---

## Gameplay

**Conquest: the tickets don't move.** In every clientless conquest round the tickets stay at their start value
(2026-10-18: XP5_003 CQL 750/750 for 9 min at 5:2 flags, XP3_Alborz CQL 625, MP_001 CQL 1000, MP_013 CQL 750; the same
on 2026-10-15/16). Not even the bleed runs, so it's more than the bot spawns. In Rush the tickets count. The mod only
reads `TicketManager`. Players reported it in dev4. Test with a real player on the server whether the player's deaths
and the bleed count. `fdb5e2c7` (2021) took a ticket per bot spawn with `TicketManager:SetTicketCount`, `8ead74cd`
removed it.

**P0. Rush balance differs by level.** 2026-10-18 (12 layouts, 900 s, factor 0.85): 1.7 MCOMs destroyed per 10 min.
XP4_Parl lost all 8 in 9 min and MP_001 lost 6, while XP1_003, XP5_001, XP4_Quake and MP_018 lost only MCOM 1 before
the attackers ran out of tickets. MP_017: no MCOM armed in 2 of 2 rounds (8 of the last 12). There 36-49 attackers per
round are killed on the ship (`stranded` at spawn us 2) to respawn at a mate, and the rest die near the beach.

**P1. Squad rush: the defenders spawn among the attackers.** Better since dev5: MP_011 19 % of the spawns within 25 m
of an enemy (41 % on 2026-10-15), kills 57:53 (99:32). In stage 2 the defender spawns all lie within ~40 m of the MCOM
the attackers stand at. What could help: a mate farther away (`GetSpawnableBeaconOrMate` with the spawn as the spot to
avoid).

**P4. Connections with a single way.** From the recordings (`routes.py`): MP_007 Rush spawn 6 ↔ spawn us 3 (paths
39/5), mcom 2 ↔ spawn us 3, mcom 1 ↔ spawn 5; XP3_Valley Rush mcom 2 ↔ spawn ru 8 (path 38). Record another path
there.

**P5. Obstacles on deathmatch paths** (squad deathmatch has no mesh): XP4_Parl path 10 waypoints 80-88, path 4
waypoints 440-442; MP_011 path 1 waypoints 58-66, paths 2 and 4 at (5-26, -5, 45).

**P8. Rush: a defender stuck on the way to the arm spot interacts from where it is** (MP_Subway MCOM 2: 4.7 m away,
`_ZoneAction` stall).

**Mobile artillery and light AA (test in game).** Their drivers attack from the gunner seat (`Bot:_CheckForVehicleActions`)
and drive on after it (`Bot:_DriveOnAfterSeatChange`). Check on an Armored Kill map that they switch, score and drive on.

## Navigation

**Z3. Without a mesh, soldiers switch paths only at random.** `PathSwitcher:_GetNewFootPath` runs the priority logic
(objectives, base paths, `UseSubobjective` onto "mcom N interact") only when `NavRoutes:IsActive()`. On a rush level
without a mesh nobody arms an MCOM. Every layout in `mod.db` has a mesh, so it hits only community mapfiles.

**Z6. The parts of the mesh ignore one-way connections.** `_ComputeParts` joins both ends of a jump down, so a goal on a
deck can be picked from below (`Route` nil, the bot waits a cycle). There are more of them since the rescan: 107 on
34 levels. The lint could flag areas only a drop leads into.

**P9. What is left after the rescan of all levels.** XP3_Valley Rush is back to 4.0 `zone_stuck`/min. MP_Subway: the
junction of path 23 at its first waypoint clips a pillar at (-97.7, 69.8, -123.3). MP_017: bots on path 74 (boat/AAV to
the beach) stand off the mesh for 30-70 s.

**M0. Domination (XP2).** The zone of Factory's C has a single mesh point (capture radius 4 m, points 5 m apart): the
census needs a point at the flag for small zones. Each level has two HQs per team of the same name (NavZones warns and
drops the second). Many spawns land next to enemies (XP2_Office 49 %, XP2_Factory 35 %).

**M1. Scavenger and CTF have no objectives** (no mesh, no labels). Scavenger needs a mesh per layout and the mode in
`SetGameMode`, like Domination. CTF also needs flag pickup (Interact) and carrying the flag to the own stand.

## Stability

**P7. Server crashes.** 2026-10-18: MP_017 Rush 94 s into the round, the log ends without an error. It came ~1 s after
two `stranded` kills on the ship. Those bots respawn into a mate's AAV/boat ~300 m away (`_EnterVehicleEntity` right
after the spawn), similar to the two crashes from debug commands (engine null-read at `vu.com+0x119501f`). Two reruns
with 82 such respawns didn't crash, so it isn't proven. Earlier: loading XP5_003 CQL and MP_003 Rush once each, and
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

1. **Conquest tickets:** one round with a real player. If only the bot spawns are missing, take a ticket per respawn
   after a death (not for a revive or the first spawn). If the whole counter is off, find what stops it.
2. **MP_017 Rush ship (P0, P7):** put the attackers that spawn on the ship straight onto the boats/AAV or a mate ashore,
   instead of killing them after `STRANDED_TIME`. Put a bot into a far vehicle only next to it, which also takes away
   the crash suspect.
3. **Z3:** the priority logic again for soldiers on levels without a mesh (community mapfiles).
4. **P1:** squad rush defenders spawn at a mate away from the attackers.
