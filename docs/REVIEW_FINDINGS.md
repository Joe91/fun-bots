# Code Review Findings (September 2026, branch `dev`)

Open items from a static review of `ext/`, `WebUI/` and `fun-bots-helper/`. Fixed items have been removed; their write-ups are in the git history of this file.

---

## Open

**I3. Table-driven command dispatch.** `Chat.lua` and `UIServer:_onBotEditorEvent` are long `if/elseif` chains. A table of `{permission, handler}` per command is shorter and makes a missing permission check obvious. Move debug-only commands (`!car`, `!caryaw`, `!cardiff`, `!weap`, `!dbg`, `!perks`, `!objectives`) behind `Registry.DEBUG`.

**I4. Safer persistence (remaining).**
- Use a transaction for settings batches. Trace saves already use one.
- Key permissions by account GUID instead of player name. The GUID is already stored but not used for lookups.

**I7. Don't broadcast full node lists.** `NodeEditor:OnRequestData` sends *all* waypoints to *all* active editor players whenever anyone requests them ([NodeEditor.lua](../ext/Server/NodeEditor.lua), marked `TODO: better handling here for all Players`). Send them only to the requester.

**I8. Store WebUI booleans in `data-value`.** `EntryElement` renders the literal `"Yes"` / `"No"`, and `BotEditor` reads the value back by comparing `innerHTML == "Yes"` ([BotEditor.js](../WebUI/classes/BotEditor.js)). This breaks as soon as the words are translated.

**Stricter luacheck (optional).** Unused variables and shadowing are now enforced. Still off: values overwritten before use (`311`, 87 hits, mostly `local x = nil` before an assignment) and empty `if` branches (`542`, 5 hits, all intentional placeholders such as `-- already in this state`). Enable them in `.luacheckrc` once those are cleaned up.

---

## TODOs in the code that need a decision

Collected from `TODO` comments. Each needs a design decision or an in-game test, so none were changed.

**Test in-game: comment cleanup.** Dead, commented-out code was removed across `ext/` and `WebUI/` without changing behavior. The only functional changes: the unused `Engine:Update` subscription on the client and the unused `StateInVehicleIdle` state are gone; the NetEvent `ClientNodeEditor:RevieveNodes` is now `ClientNodeEditor:ReceiveNodes` (client and server both updated); the settings-migration and language debug prints are active again behind `Debug.Server.SETTINGS` / `Debug.Shared.LANGUAGE`; French translations have their apostrophes back (safe now that all UI payloads go through `UIViews:escape`).

**T1. Duplicate `CalculateDeviationRelativeToOrientation`.** [VehicleJetControl.lua](../ext/Server/Bot/VehicleJetControl.lua) and [VehicleMovement.lua](../ext/Server/Bot/VehicleMovement.lua) have identical copies. Keep one (e.g. in `Utilities`) and call it from both.

**T2. Unexplained server setting.** `FunBotServer:OnServerSettingsCallback` sets `ServerSettings.isRenderDamageEvents = true` with `TODO: what is this doing?` ([Server/__init__.lua](../ext/Server/__init__.lua)). Find out whether bots rely on it (damage/hit events) and document it, or drop it.

**T3. Infantry can switch onto air paths.** `PathSwitcher:GetNewPath` has `todo: prevent air-paths?` in the on-foot branch ([PathSwitcher.lua](../ext/Server/PathSwitcher.lua)). The vehicle branch filters by terrain; the soldier branch does not.

**T4. Passenger look-around uses relative yaws.** `StateOnVehicleIdle` notes that `_UpdateLookAroundPassenger` is "little broken" and should set absolute yaws ([StateOnVehicleIdle.lua](../ext/Server/BotStates/StateOnVehicleIdle.lua)).

**T5. `UpdateVehicleMovableId` resets all spawn vars.** It calls `ResetSpawnVars()` on every vehicle enter/exit, with `TODO: this might be too hard? Only Inputs relevant?` ([Bot.lua](../ext/Server/Bot/Bot.lua)). Check whether resetting only the inputs is enough. If it is narrowed down, keep the PID-controller resets in it, so no stale integral or derivative carries over into the new seat.

**T6. Bot names can collide with players.** `BotCreator` picks a name without checking for an existing player or bot of that name (`TODO: check for existing player or Bot?`, [BotCreator.lua](../ext/Server/BotCreator.lua)).

**T7. Spawn logic in two places.** `BotSpawner:_ConquestSpawn` has its own spawn path (`TODO: handle spawn-logic here as well (unify it?)`, [BotSpawner.lua](../ext/Server/BotSpawner.lua)).

**T8. Flag teams only for Conquest.** `GameDirector:_InitFlagTeams` returns early for non-Conquest modes (`TODO: check for rush?`, [GameDirector.lua](../ext/Server/GameDirector.lua)).

**T9. Node scan on every click.** `ClientNodeEditor` sets `m_ScanForNode = true` on every select click (`TODO: don't always do this?`, [ClientNodeEditor.lua](../ext/Client/ClientNodeEditor.lua)). The `T` key in move mode is reserved for an area mode that was never implemented.

**T10. Vehicle data gaps.** [VehicleData.lua](../ext/Shared/Constants/VehicleData.lua): projectile speed for the IFV TOW missile is unknown; light AA vehicles (Vodnik AA) may need their own handling.

**T11. Refactoring ideas (low priority).**
- [Bot.lua](../ext/Server/Bot/Bot.lua): move persona attributes and loadout into inner classes; use state base classes.
- `StateAttacking`: split revive, repair and C4 into their own states.
- `StateMoving` / `StateAttacking` / `StateStaticMovement`: combine `UpdateWeaponSelection` with reload.
- `StateInVehicleAttacking`: simplify once the gunship has its own state.
- `FunBotServer:OnAutoTeamEntityDataCallback`: revisit once the VU runtime branch releases.
- [BotActions.lua](../ext/Server/Bot/BotActions.lua): defib checks assume vanilla kits, modes and slots; mods that change these break it.
- [BotEditor.js](../WebUI/classes/BotEditor.js): Enter submits the form instead of moving to the next input.
