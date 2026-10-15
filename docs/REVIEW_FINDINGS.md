# Code Review Findings (branch `dev`)

Open items from static reviews of `ext/`, `WebUI/` and `fun-bots-helper/` (September 2026; zone navigation October 2026) and from playtests. Fixed items have been removed; their write-ups are in the git history of this file.

---

## Open

**I3. Table-driven command dispatch.** `Chat.lua` and `UIServer:_onBotEditorEvent` are long `if/elseif` chains. A table of `{permission, handler}` per command is shorter and makes a missing permission check obvious. Move debug-only commands (`!car`, `!caryaw`, `!cardiff`, `!weap`, `!dbg`, `!perks`, `!objectives`) behind `Registry.DEBUG`.

**I4. Safer persistence (remaining).**
- Use a transaction for settings batches. Trace saves already use one.
- Key permissions by account GUID instead of player name. The GUID is already stored but not used for lookups.

**Kill weapon "Death".** In a clientless XP3_Desert round (63 bots, server raycasts), 60 of 76 kills arrived with the weapon `"Death"` from the engine's `Player:Killed` event. Find out which kills these are (finishing downed soldiers? vehicle weapons?), e.g. from `p_WasVictimInReviveState` / `p_Info`, so kill statistics and weapon-based logic see the real weapon.

**Conquest: bot spawns cost no tickets.** Reported in dev4 and the latest dev commits: bots respawn in conquest modes without a ticket being taken. In the clientless test rounds of 2026-10-15 the conquest tickets didn't move at all: XP5_003 CQL 750/750 for 600 s (214 bot spawns, flags held unevenly, so no bleed either), XP3_Alborz CQL 625/625 (129 spawns). In rush, where the bots spawn the same way (`ServerPlayerEvent("Spawn")` fired at a `ServerCharacterSpawnEntity`, `BotSpawner:_RushSpawn` / `_ConquestSpawn`), the tickets count: XP1_003 attackers 250 → 62, defenders 2497 → 2335. There was a workaround once: `fdb5e2c7` (2021) took a ticket per bot spawn with `TicketManager:SetTicketCount(team, count - 1)` in conquest, assault and domination, `8ead74cd` (2022) removed it as no longer needed. Check with a real player on the server whether the bleed and the player's own deaths count (then only the bot spawns are missing, and the workaround fits again: once per respawn after a death, not for a revive or the first spawn of the round), or whether the ticket counter of conquest doesn't run at all. Domination counts as conquest now (`SetGameMode`), so it would get the same treatment.

**German translation typo.** [de_DE.lua](../ext/Shared/Languages/de_DE.lua) translates "Add Chopper" as "Hacker hinzufügen" instead of "Hubschrauber hinzufügen".

**Debug-bridge tests: don't move soldiers from Lua.** Two server crashes (engine null-read at `vu.com+0x119501f`) happened the moment a debug command put a bot into a vehicle ~500 m away, and the moment one set a bot's soldier transform. Test vehicle behavior by waiting for bots to use the vehicles on their own. The mod itself now sets soldier transforms in normal play too (`Bot:TeleportToMesh`, `Bot:_ZoneForceAcross`, the arm spot in `Bot:_ZoneAction`, `GameDirector:ForwardSpawn`, spawns at a mate), always over a few metres up to `OFF_MESH_TELEPORT_RANGE` (30 m). If a crash at that address shows up again, check the `zone_force` / `mod_kill` events right before it.

---

## Zone navigation (review of `836f72d7..fbf6afeb`, October 2026)

**Z1. `NavRoutes:_ActionTarget` never reuses a "no target" result.** [NavRoutes.lua](../ext/Server/NavRoutes.lua) stores `false` in `_ActionTargets` when no point of the mesh is next to the vehicle or MCOM, but the cache check needs `s_Known.Action`, so every call searches again. For a vehicle it searches all points of the mesh (6223 on XP3_Desert CQL) and reads `Position.x/.y/.z` of each: three engine calls per point. Most vehicles stand away from the mesh (it only covers objectives and spawns), and `Target` runs through `Knows` / `Next` / `CanReach` every GameDirector cycle: vehicle objectives for each bot without one, `ReserveVehicle` at each spawn, `_CheckStranded`. Cache the miss together with the position and `GetTopology()` (search again once the vehicle moved `ACTION_MOVED` or connections were removed). Search only the grid cells around it (`_PointsAround`), with the `X`/`Y`/`Z` numbers.

**Z2. `Bot:_ZoneRejoinPoint` scans the whole mesh with engine calls.** [BotZoneMovement.lua](../ext/Server/Bot/BotZoneMovement.lua) `Bot:CanReach` calls it whenever `NavRoutes:Next` finds no route from the bot's point. The GameDirector asks `CanReach` for every objective it considers (closest objective, vehicles, `_ArmedDefenders`, `_CheckStranded`). It calls `Position:Distance` for every point of the mesh, a second pass up to 120 m when nothing is within 30 m, then `Next` per candidate part (for vehicles that hits Z1). A bot on a cut-off piece of the mesh repeats this every 1.5 s per candidate objective. Use the grid and the plain coordinates, and keep the result per point and objective for a few seconds. Not measured yet: check with `Registry.DEBUG.ROUND_STATS_INTERVAL` on a level with islands (MP_018 CQL beach, XP1_004 CAL carrier).

**Z3. Soldiers on labelled paths without a mesh switch paths only at random.** [PathSwitcher.lua](../ext/Server/PathSwitcher.lua) `_GetNewFootPath` switches at random when `NavRoutes:IsActive()` is false. The priority logic (state of the objectives, base paths, `UseSubobjective` onto "mcom N interact") now only runs for vehicles: `_GetNewVehiclePath` takes only links to paths with `Vehicles`. Before, soldiers used it as well. This affects every level with labelled paths but no mesh in `mod.db`: COOP_006 ConquestSmall0, XP5_003 CaptureTheFlag0 and any community mapfile. On a rush level without a mesh nobody arms an MCOM anymore: the zone movement that does it now needs the mesh. Without a mesh, give soldiers the priority logic again (walkable links as candidates, with the `UseSubobjective` check).

**Z4. A seat change clears the zone state of a driver.** `Bot:UpdateVehicleMovableId` calls `ResetSpawnVars` on every seat change (see T5). That now also clears `m_Zone`, `m_RouteSeed`, `m_Border`, `_LeftVehicle`, `_PassengerExitTime` and the objective. Drivers of mobile artillery and light AA switch to seat 1 to attack and back (`Bot:_CheckForVehicleActions`): on the vehicle network of a zone they lose it, and back in seat 0 they drive the `_PathIndex` they had before. That is the case `Bot:FindVehiclePath` avoids (MP_013: steering straight at a waypoint 68 m away behind houses). A gunner that moves to the free driver seat ("switch to better seat") gets no `FindVehiclePath` either. Narrow the reset (T5), or call `FindVehiclePath` after a switch into seat 0.

**Z5. Spawn-into vehicles at a capture point after the flag changed hands.** `GameDirector:GetSpawnableVehicle` checks only `SpawnEntity(spawn).enabled` for the vehicles `_SpawnInVehicle` registered. The vehicle stays in the list of the team that held the flag when it spawned. Once the enemy holds the flag, its spawn is on for the enemy, and bots of the old team would spawn into the vehicle at the enemy flag (XP5 dirt bikes). Compare the team of the spawn as well (`SpawnEntity.teamId`, as `_SpawnInVehicle` does). Check in game that `teamId` follows the flag.

**Z6. The parts of the mesh ignore one-way connections.** `_ComputeParts` ([NavZones.lua](../ext/Server/NavZones.lua)) joins both ends of a one-way connection (a jump down). `RandomPoint`, `NavRoutes:Next` (`_TargetIn`) and `_ZoneRejoinPoint` take the same part for "a way leads there". A goal up on a deck can be picked from below: `Route` returns nil, and the bot waits a cycle. A bot below a drop with no other way up finds no other part to rejoin: `_ZoneRejoinPoint` only takes points of other parts. It waits until `_CheckStranded` or the progress check respawns it. Low priority while one-way connections are few (24 on 14 maps). The lint could flag areas that only a drop leads into.

**Z7. Doc comments on the wrong function.** The comment of `NavZones:BlockEdge` sits above `_SizeWithout`, the one of `GameDirector:_CheckObjectiveProgress` above `_CheckStranded`. LuaLS shows them for the wrong function and checks the wrong `@param`s.

**Z8. `Bot:_ZoneForceAcross` can put a bot where the game kills it.** It sets the soldier onto the next point of its way when the bot is stuck on the only way or trapped, without checking that the soldier fits there. XP2_Factory Domination (2026-10-15): 22 times in 600 s a bot was put onto the point at (-26, 8, 38) and died there right after, without a killer (weapon "Death", no `mod_kill`); with a mesh built without the checks of the game 53 times at (-3.1, 12.8, -48). The point is fine to walk over, the soldier set onto it isn't. Remember the points a bot died at within a few seconds after being put there and don't put anybody there again (or cast a ray up and around the point before `SetTransform`).

---

## Modes without a mesh (playtest 2026-10-15)

**M0. Domination: what is left for the four XP2 levels.** All four have a mesh now and play (600 s rounds 2026-10-15: Office 15 captures 0.2 % stuck, Palace 17 / 0.0 %, Skybar 29 / 0.6 %, Factory 27 / 0.2 %). Their floors are detail-meshes: the census needs `--detail-mesh` (the Maps tab adds it for `XP2_` levels), and the steps in the order census, check, one cut on the recorded paths (a cut before the check dropped the paths, the second cut had nothing to bridge what the check cut off: the floor of the RU spawn on Factory became an island). Open: the zone of Factory's C has a single point (capture radius 4 m, the points are 5 m apart): a point at the flag itself for zones smaller than the spacing (census). Each level has two HQs per team (the spawn high above the level and one on the ground), both named "base ru" / "base us": NavZones warns about two zones of one name and drops the second. Z8 kills bots on Factory.

**M1. Scavenger and CTF have no objectives.** Neither mode has a mesh, and the mapfiles of Scavenger have no labels, so the GameDirector has no objectives: the bots wander, flags change by accident. Domination works the way to go: it counts as a conquest-type mode now (`SetGameMode`, capture points of the engine as objectives, `_EngineObjective` also maps the bare "A"), and with a mesh the bots play it (XP2_Office: flags changed 15 times in 9.5 min, 0.2 % stuck). Scavenger (XP4 levels, flags `ID_H_US_A`..`E`) needs the same: a mesh per layout, and the mode in the list of `SetGameMode` (check its spawns first: like Domination the spawns of the deathmatch layer?). CTF also needs the flags: picking up the enemy flag (bots within 1 m of a dropped one didn't take it, probably Interact) and carrying it to the own stand. The stands are HQ capture points, the flags `ServerMapMarkerEntity` (two per flag, they follow it).

---

## TODOs in the code that need a decision

Collected from `TODO` comments. Each needs a design decision or an in-game test, so none were changed.

**Test in-game: mobile artillery and light AA attack again.** Their drivers (HIMARS, BM-23, Vodnik AA, HMMWV ASRAD) attack by switching to the gunner seat (`Bot:_CheckForVehicleActions`). Two things stopped that: `UpdateDontAttackFlag` blocked every seat without an aimable part (-1) since `dc959f0d`, including these driver seats, and the seat switch lost the target in `UpdateVehicleMovableId` → `ResetSpawnVars()`, so the bot went back to the driver seat right away. Now these driver seats may attack, and the switch keeps the target. Check on an Armored Kill map (on XP3_Desert the BM-23 only spawns once flags are taken): in the debug-server, an artillery driver should go to seat 1 when attacking, back to seat 0 afterwards, and get kills with the artillery.

**T1. Duplicate `CalculateDeviationRelativeToOrientation`.** [VehicleJetControl.lua](../ext/Server/Bot/VehicleJetControl.lua) and [VehicleMovement.lua](../ext/Server/Bot/VehicleMovement.lua) have identical copies. Keep one (e.g. in `Utilities`) and call it from both.

**T2. Unexplained server setting.** `FunBotServer:OnServerSettingsCallback` sets `ServerSettings.isRenderDamageEvents = true` with `TODO: what is this doing?` ([Server/__init__.lua](../ext/Server/__init__.lua)). Find out whether bots rely on it (damage/hit events) and document it, or drop it.

**T4. Passenger look-around uses relative yaws.** `StateOnVehicleIdle` notes that `_UpdateLookAroundPassenger` is "little broken" and should set absolute yaws ([StateOnVehicleIdle.lua](../ext/Server/BotStates/StateOnVehicleIdle.lua)).

**T5. `UpdateVehicleMovableId` resets all spawn vars.** It calls `ResetSpawnVars()` on every vehicle enter and seat change, with `TODO: this might be too hard? Only Inputs relevant?` ([Bot.lua](../ext/Server/Bot/Bot.lua)). The full reset came in with a fix for a seat-change crash (`6b3a78bb`). Besides the inputs it also clears the objective, `m_HasBeacon` and the target, and sets the 2 s spawn protection; since the zone navigation also the zone state and the vehicle network (Z4). The attack seat switch of artillery / light AA now keeps its target (see above); all other callers abort the attack before anyway. Check whether resetting only the inputs is enough. If it is narrowed down, keep the PID-controller resets in it, so no stale integral or derivative carries over into the new seat.

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
