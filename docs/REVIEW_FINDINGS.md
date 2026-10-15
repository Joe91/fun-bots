# Code Review Findings (branch `dev`)

Open items from static reviews of `ext/`, `WebUI/` and `fun-bots-helper/` (September 2026; zone navigation October 2026) and from playtests. Fixed items have been removed; their write-ups are in the git history of this file.

---

## Open

**I3. Table-driven command dispatch.** `Chat.lua` and `UIServer:_onBotEditorEvent` are long `if/elseif` chains. A table of `{permission, handler}` per command is shorter and makes a missing permission check obvious. Move debug-only commands (`!car`, `!caryaw`, `!cardiff`, `!weap`, `!dbg`, `!perks`, `!objectives`) behind `Registry.DEBUG`.

**I4. Safer persistence (remaining).** Key permissions by account GUID instead of player name. The GUID is already stored but not used for lookups.

**Conquest: bot spawns cost no tickets.** Reported in dev4 and the latest dev commits: bots respawn in conquest modes without a ticket being taken. In the clientless test rounds of 2026-10-15 the conquest tickets didn't move at all: XP5_003 CQL 750/750 for 600 s (214 bot spawns, flags held unevenly, so no bleed either), XP3_Alborz CQL 625/625 (129 spawns). In rush, where the bots spawn the same way (`ServerPlayerEvent("Spawn")` fired at a `ServerCharacterSpawnEntity`, `BotSpawner:_RushSpawn` / `_ConquestSpawn`), the tickets count: XP1_003 attackers 250 → 62, defenders 2497 → 2335. There was a workaround once: `fdb5e2c7` (2021) took a ticket per bot spawn with `TicketManager:SetTicketCount(team, count - 1)` in conquest, assault and domination, `8ead74cd` (2022) removed it as no longer needed. Check with a real player on the server whether the bleed and the player's own deaths count (then only the bot spawns are missing, and the workaround fits again: once per respawn after a death, not for a revive or the first spawn of the round), or whether the ticket counter of conquest doesn't run at all. Domination counts as conquest now (`SetGameMode`), so it would get the same treatment.

**Debug-bridge tests: don't move soldiers from Lua.** Two server crashes (engine null-read at `vu.com+0x119501f`) happened the moment a debug command put a bot into a vehicle ~500 m away, and the moment one set a bot's soldier transform. Test vehicle behavior by waiting for bots to use the vehicles on their own. The mod itself now sets soldier transforms in normal play too (`Bot:TeleportToMesh`, `Bot:_ZoneForceAcross`, the arm spot in `Bot:_ZoneAction`, `GameDirector:ForwardSpawn`, spawns at a mate), always over a few metres up to `OFF_MESH_TELEPORT_RANGE` (30 m). If a crash at that address shows up again, check the `zone_force` / `mod_kill` events right before it.

---

## Zone navigation (review of `836f72d7..fbf6afeb`, October 2026)

**Z3. Soldiers on labelled paths without a mesh switch paths only at random.** [PathSwitcher.lua](../ext/Server/PathSwitcher.lua) `_GetNewFootPath` switches at random when `NavRoutes:IsActive()` is false. The priority logic (state of the objectives, base paths, `UseSubobjective` onto "mcom N interact") now only runs for vehicles: `_GetNewVehiclePath` takes only links to paths with `Vehicles`. Before, soldiers used it as well. This affects every level with labelled paths but no mesh in `mod.db`: COOP_006 ConquestSmall0, XP5_003 CaptureTheFlag0 and any community mapfile. On a rush level without a mesh nobody arms an MCOM anymore: the zone movement that does it now needs the mesh. Every rush and squad rush layout in `mod.db` has a mesh (the two without one, XP2 Squad Rush, aren't offered by the game), so this only hits community mapfiles. Without a mesh, give soldiers the priority logic again (walkable links as candidates, with the `UseSubobjective` check).

**Z6. The parts of the mesh ignore one-way connections.** `_ComputeParts` ([NavZones.lua](../ext/Server/NavZones.lua)) joins both ends of a one-way connection (a jump down). `RandomPoint`, `NavRoutes:Next` (`_TargetIn`) and `_ZoneRejoinPoint` take the same part for "a way leads there". A goal up on a deck can be picked from below: `Route` returns nil, and the bot waits a cycle. A bot below a drop with no other way up finds no other part to rejoin: `_ZoneRejoinPoint` only takes points of other parts. It waits until `_CheckStranded` or the progress check respawns it. Low priority while one-way connections are few (24 on 14 maps). The lint could flag areas that only a drop leads into.

---

## Modes without a mesh (playtest 2026-10-15)

**M0. Domination: what is left for the four XP2 levels.** All four have a mesh now and play (600 s rounds 2026-10-15: Office 15 captures 0.2 % stuck, Palace 17 / 0.0 %, Skybar 29 / 0.6 %, Factory 27 / 0.2 %). Their floors are detail-meshes: the census needs `--detail-mesh` (the Maps tab adds it for `XP2_` levels), and the steps in the order census, check, one cut on the recorded paths (a cut before the check dropped the paths, the second cut had nothing to bridge what the check cut off: the floor of the RU spawn on Factory became an island). Open: the zone of Factory's C has a single point (capture radius 4 m, the points are 5 m apart): a point at the flag itself for zones smaller than the spacing (census). Each level has two HQs per team (the spawn high above the level and one on the ground), both named "base ru" / "base us": NavZones warns about two zones of one name and drops the second. The deathmatch modes of these levels (TDM C0, squad deathmatch, gun master) load the Domination mesh when they have none of their own; 420 s rounds: XP2_Palace TDM 142:142 kills, XP2_Factory gun master 134:121, both 0.0-0.1 % stuck, 30 % of the spawns within 25 m of an enemy (XP2_Office TDM: 18 %).

**M1. Scavenger and CTF have no objectives.** Neither mode has a mesh, and the mapfiles of Scavenger have no labels, so the GameDirector has no objectives: the bots wander, flags change by accident. Domination works the way to go: it counts as a conquest-type mode now (`SetGameMode`, capture points of the engine as objectives, `_EngineObjective` also maps the bare "A"), and with a mesh the bots play it (XP2_Office: flags changed 15 times in 9.5 min, 0.2 % stuck). Scavenger (XP4 levels, flags `ID_H_US_A`..`E`) needs the same: a mesh per layout, and the mode in the list of `SetGameMode` (check its spawns first: like Domination the spawns of the deathmatch layer?). CTF also needs the flags: picking up the enemy flag (bots within 1 m of a dropped one didn't take it, probably Interact) and carrying it to the own stand. The stands are HQ capture points, the flags `ServerMapMarkerEntity` (two per flag, they follow it).

---

## Playtests of 2026-10-15 (clientless, 420-600 s rounds)

**P0. Rush: the MCOM in front is outnumbered.** The engine spawns the defenders near the MCOM behind (XP1_003 stage 1: 33 of 36 spawns closer to MCOM 2, MP_007 21 of 23). Both teams get the MCOMs with the same cap per MCOM, so the defenders split evenly, while the attackers all reach the front MCOM first (XP1_003: 8 defenders against 11-16 attackers 40 s into the round, it fell 77-134 s into the round in 5 of 6 rounds, once after a disarm at 202 s). Now in the working tree: defenders on the way to their MCOM keep going while shooting (`RUSH_DEFEND_PUSH_DISTANCE`) and sprint in its zone (`RUSH_DEFEND_SPRINT_DISTANCE`): they arrive sooner (XP1_003: 6-7 at 30 s instead of 3-4), MCOMs destroyed 2.0 vs 2.6 per 10 min over 4 levels × 2 rounds, within the spread between rounds. Tried and dropped: caps per MCOM by the attackers within 50 m (3 rounds each: 2.9 destroyed per 10 min vs 0.7 without; the new defenders chased the attackers to one MCOM, the other was armed seconds later). Open: the first wave decides the stage; what is left are more defenders (`RUSH_DEFENDER_FACTOR`) or the defenders of the MCOM behind moving up while nobody attacks it.

**P1. Squad rush: the defenders spawn among the attackers.** MP_011 SquadRush0: 41 of 99 defender spawns within 25 m of an attacker, 36 defender lives shorter than 10 s, kills 99:32 for the attackers. In stage 2 the spawn of the defenders lies about 20 m from the MCOM the attackers stand at (22 of 29 spawns next to them). XP3_Valley SquadRush0 likewise (73:37). Both MCOMs of each level fell one fuse (26 s) after they were armed, none was disarmed. Rush large has 3-5 % such spawns. The engine picks the spot (`BotSpawner:_RushSpawn` fires the team's spawn-entity). Proposal, keeping the engine spawns otherwise: if an enemy is within 25 m of the spawned soldier, move it to the alternate spawn of its team and stage (`SpawnPoints`) farthest from the enemies, as `GameDirector:ForwardSpawn` does for spawns behind the front. But on MP_011 all spawns of the defenders in stage 2 lie within ~40 m of each other at the MCOM (clusters of the first positions after a spawn, 2026-10-16): another one of them wouldn't help, the attackers stand at the MCOM. What could help: a mate farther away (`GetSpawnableBeaconOrMate` with the spawn as the spot to avoid, as for stranded spawns).

**P3. Helicopters crash after a hit.** XP3_Alborz CQL (2 of 2 crashes in one round): the pilot hovers nose-down (-20°) at ~700 m, takes a hit (one only 19 health), the nose goes up to +50° within 2 s and the helicopter falls. The next round had none. Watch in game what the control does right after damage.

**P4. Connections with a single way (record another path).** From all recordings of October (`routes.py`, a way counts as another one only through another corridor): MP_007 RushLarge0 spawn 6 ↔ spawn us 3 (190 trips, all over paths 39/5), mcom 2 ↔ spawn us 3 (64 trips), mcom 1 ↔ spawn 5 (11 trips); XP3_Valley RushLarge0 mcom 2 ↔ spawn ru 8 (137 trips, path 38). Elsewhere another corridor exists at most 15 % longer and the bots still take one (routing, `NAV_ROUTE_SPREAD` spreads only the first stretch at a decision, capped at 15 m): MP_013 RushLarge0 mcom 1 ↔ spawn ru 6 (64 trips, +14 %), XP4_Parl RushLarge0 spawn 6 ↔ spawn ru 6 (34, +10 %) and mcom 5 ↔ mcom 7 (30, +6 %), XP5_003 CQL a ↔ d (30, +13 %), MP_013 CQL base ru ↔ c (20, +1 %), MP_Subway RushLarge0 mcom 3 ↔ spawn 2 (18, +6 %).

**P5. Obstacles on deathmatch paths.** Squad deathmatch has no mesh; the bots stood at these spots until the standing-still check (`GameDirector:_CheckStandingStill`) put them onto their waypoint or killed them: XP4_Parl path 10 waypoints 80-88 and path 4 waypoints 440-442 (-331, 64, 38); MP_011 path 1 waypoints 58-66 (48, 1, 73), paths 2 and 4 at (5-26, -5, 45) (two traps of 41 and 52 s). Fix the paths there.

**P6. A TDM round without damage after CTF.** XP2_Factory TeamDeathMatchC0 right after XP5_003 CaptureTheFlag0 on the same server: 40 bots attacked each other 1-2 m apart for 7 min, health stayed at 100, one death in the round. The same level again after Rush rounds: 230:174 kills. Probably a state the CTF round leaves (pre-round?). Also on these small levels 40-50 % of the TDM spawns are within 25 m of an enemy (40 bots).

**P7. Server crash loading XP5_003 CQL.** Once, after three 600 s conquest rounds: the log stops before the level registers its teams, the next load of the same level was fine. If it comes back, compare what the mod does while partitions load (`SpawnPoints:OnPartitionLoaded`).

---

## TODOs in the code that need a decision

Collected from `TODO` comments. Each needs a design decision or an in-game test, so none were changed.

**Test in-game: mobile artillery and light AA attack again.** Their drivers (HIMARS, BM-23, Vodnik AA, HMMWV ASRAD) attack by switching to the gunner seat (`Bot:_CheckForVehicleActions`). Two things stopped that: `UpdateDontAttackFlag` blocked every seat without an aimable part (-1) since `dc959f0d`, including these driver seats, and the seat switch lost the target in `UpdateVehicleMovableId` → `ResetSpawnVars()`, so the bot went back to the driver seat right away. Now these driver seats may attack, and the switch keeps the target. Back in seat 0 (and a gunner that moved to the free driver seat) the bot looks for a vehicle path again (`Bot:_DriveOnAfterSeatChange`), the reset of the seat change dropped its zone state. Check on an Armored Kill map (on XP3_Desert the BM-23 only spawns once flags are taken): in the debug-server, an artillery driver should go to seat 1 when attacking, back to seat 0 afterwards and drive on, and get kills with the artillery.

**T2. Unexplained server setting.** `FunBotServer:OnServerSettingsCallback` sets `ServerSettings.isRenderDamageEvents = true` with `TODO: what is this doing?` ([Server/__init__.lua](../ext/Server/__init__.lua)). Find out whether bots rely on it (damage/hit events) and document it, or drop it.

**T4. Passenger look-around uses relative yaws.** `StateOnVehicleIdle` notes that `_UpdateLookAroundPassenger` is "little broken" and should set absolute yaws ([StateOnVehicleIdle.lua](../ext/Server/BotStates/StateOnVehicleIdle.lua)).

**T5. `UpdateVehicleMovableId` resets all spawn vars.** It calls `ResetSpawnVars()` on every vehicle enter and seat change, with `TODO: this might be too hard? Only Inputs relevant?` ([Bot.lua](../ext/Server/Bot/Bot.lua)). The full reset came in with a fix for a seat-change crash (`6b3a78bb`). Besides the inputs it also clears the objective, `m_HasBeacon` and the target, and sets the 2 s spawn protection; since the zone navigation also the zone state and the vehicle network (a driver back in seat 0 now looks for a vehicle path again, `Bot:_DriveOnAfterSeatChange`). The attack seat switch of artillery / light AA now keeps its target (see above); all other callers abort the attack before anyway. Check whether resetting only the inputs is enough. If it is narrowed down, keep the PID-controller resets in it, so no stale integral or derivative carries over into the new seat.

**T7. Spawn logic in two places.** `BotSpawner:_ConquestSpawn` has its own spawn path (`TODO: handle spawn-logic here as well (unify it?)`, [BotSpawner.lua](../ext/Server/BotSpawner.lua)).

**T10. Vehicle data gap.** [VehicleData.lua](../ext/Shared/Constants/VehicleData.lua): projectile speed for the IFV TOW missile is unknown.

**T11. Refactoring ideas (low priority).**
- [Bot.lua](../ext/Server/Bot/Bot.lua): move persona attributes and loadout into inner classes; use state base classes.
- `StateAttacking`: split revive, repair and C4 into their own states.
- `StateMoving` / `StateAttacking` / `StateStaticMovement`: combine `UpdateWeaponSelection` with reload.
- `StateInVehicleAttacking`: simplify once the gunship has its own state.
- `FunBotServer:OnAutoTeamEntityDataCallback`: revisit once the VU runtime branch releases.
- [BotActions.lua](../ext/Server/Bot/BotActions.lua): defib checks assume vanilla kits, modes and slots; mods that change these break it.
- [BotEditor.js](../WebUI/classes/BotEditor.js): Enter submits the form instead of moving to the next input.
