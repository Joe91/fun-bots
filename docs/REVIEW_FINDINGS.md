# Code Review Findings (September 2026, branch `dev`)

Open items from a static review of `ext/`, `WebUI/` and `fun-bots-helper/`. Fixed items have been removed; their write-ups are in the git history of this file.

---

## Open

**I3. Table-driven command dispatch.** `Chat.lua` and `UIServer:_onBotEditorEvent` are long `if/elseif` chains. A table of `{permission, handler}` per command is shorter and makes a missing permission check obvious. Move debug-only commands (`!car`, `!caryaw`, `!cardiff`, `!weap`, `!dbg`, `!perks`, `!objectives`) behind `Registry.DEBUG`.

**I4. Safer persistence (remaining).**
- Use a transaction for settings batches. Trace saves already use one.
- Key permissions by account GUID instead of player name. The GUID is already stored but not used for lookups.

**Kill weapon "Death".** In a clientless XP3_Desert round (63 bots, server raycasts), 60 of 76 kills arrived with the weapon `"Death"` from the engine's `Player:Killed` event. Find out which kills these are (finishing downed soldiers? vehicle weapons?), e.g. from `p_WasVictimInReviveState` / `p_Info`, so kill statistics and weapon-based logic see the real weapon.

**German translation typo.** [de_DE.lua](../ext/Shared/Languages/de_DE.lua) translates "Add Chopper" as "Hacker hinzufügen" instead of "Hubschrauber hinzufügen".

**Debug-bridge tests: don't move soldiers from Lua.** Two server crashes (engine null-read at `vu.com+0x119501f`) happened the moment a debug command put a bot into a vehicle ~500 m away, and the moment one set a bot's soldier transform. The mod itself only enters vehicles within a few metres. Test vehicle behavior by waiting for bots to use the vehicles on their own.

---

## TODOs in the code that need a decision

Collected from `TODO` comments. Each needs a design decision or an in-game test, so none were changed.

**Test in-game: mobile artillery and light AA attack again.** Their drivers (HIMARS, BM-23, Vodnik AA, HMMWV ASRAD) attack by switching to the gunner seat (`Bot:_CheckForVehicleActions`). Two things stopped that: `UpdateDontAttackFlag` blocked every seat without an aimable part (-1) since `dc959f0d`, including these driver seats, and the seat switch lost the target in `UpdateVehicleMovableId` → `ResetSpawnVars()`, so the bot went back to the driver seat right away. Now these driver seats may attack, and the switch keeps the target. Check on an Armored Kill map (on XP3_Desert the BM-23 only spawns once flags are taken): in the debug-server, an artillery driver should go to seat 1 when attacking, back to seat 0 afterwards, and get kills with the artillery.

**T1. Duplicate `CalculateDeviationRelativeToOrientation`.** [VehicleJetControl.lua](../ext/Server/Bot/VehicleJetControl.lua) and [VehicleMovement.lua](../ext/Server/Bot/VehicleMovement.lua) have identical copies. Keep one (e.g. in `Utilities`) and call it from both.

**T2. Unexplained server setting.** `FunBotServer:OnServerSettingsCallback` sets `ServerSettings.isRenderDamageEvents = true` with `TODO: what is this doing?` ([Server/__init__.lua](../ext/Server/__init__.lua)). Find out whether bots rely on it (damage/hit events) and document it, or drop it.

**T4. Passenger look-around uses relative yaws.** `StateOnVehicleIdle` notes that `_UpdateLookAroundPassenger` is "little broken" and should set absolute yaws ([StateOnVehicleIdle.lua](../ext/Server/BotStates/StateOnVehicleIdle.lua)).

**T5. `UpdateVehicleMovableId` resets all spawn vars.** It calls `ResetSpawnVars()` on every vehicle enter and seat change, with `TODO: this might be too hard? Only Inputs relevant?` ([Bot.lua](../ext/Server/Bot/Bot.lua)). The full reset came in with a fix for a seat-change crash (`6b3a78bb`). Besides the inputs it also clears the objective, `m_HasBeacon` and the target, and sets the 2 s spawn protection. The attack seat switch of artillery / light AA now keeps its target (see above); all other callers abort the attack before anyway. Check whether resetting only the inputs is enough. If it is narrowed down, keep the PID-controller resets in it, so no stale integral or derivative carries over into the new seat.

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
