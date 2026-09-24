# Code Review Findings (September 2026, branch `dev`)

This is a static review of `ext/`, `WebUI/` and `fun-bots-helper/`. Nothing was run in-game. Each bug below was traced through the code paths cited. Items marked *(plausible)* depend on VU engine behaviour that could not be checked from source alone.

Severity: **High**: data loss, security, or a core feature broken. **Medium**: a feature that visibly misbehaves. **Low**: an edge case, crash on bad input, or cosmetic issue.

---

## Bugs

### High

**B1. "Save temporarily" in the settings UI deletes every saved setting** — ✅ fixed
[UIServer.lua:620](../ext/Server/UIServer.lua#L620), [UIServer.lua:726-728](../ext/Server/UIServer.lua#L726-L728), [Database.lua:141-150](../ext/Server/Database.lua#L141-L150)
`batched` is always `true`, so `Database:ExecuteBatch()` always runs. On a temporary save, `SettingsManager:Update(..., p_Temporary=true)` skips the DB entirely and the batch stays empty. `ExecuteBatch` still runs `DELETE FROM FB_Settings` and then executes an empty INSERT, which fails. Result: every persisted runtime setting is erased, and after a restart the server falls back to `Config.lua` defaults.
*Fix:* `batched = not temporary`, and make `ExecuteBatch` return early when `m_Batches` is empty.

**B2. `config.saveall` and `config.restore` do each other's job** — ✅ fixed
[Commands/Console.lua:33-59](../ext/Server/Commands/Console.lua#L33-L59)
`OnConsoleCommandRestore` calls `SaveAll()`, and `OnConsoleCommandSaveAll` calls `RestoreDefault()`. An admin typing `config.saveall` in the client console resets all in-memory settings to defaults. RCON (`funbots.saveall` / `funbots.restore`) is wired correctly.

**B3. Importing traces with the helper wipes settings and permissions** — ✅ fixed
[fun-bots-helper/src/tools/import_traces.py:10-20](../fun-bots-helper/src/tools/import_traces.py#L10-L20)
The tool builds only the trace tables in an in-memory DB and then calls `memory_connection.backup(connection)`, which **replaces the whole `mod.db`**. That drops `FB_Settings`, `FB_Config_Trace`, `FB_Permissions`, and any map tables that have no `.map` file.
*Fix:* write into `mod.db` directly inside a transaction (as `import_permission_and_config.py` does), or `ATTACH` the file and copy only the trace tables.

**B4. A failed trace save destroys the map's saved traces** — ✅ fixed
[NodeCollection.lua:1565](../ext/Server/NodeCollection.lua#L1565), [NodeCollection.lua:1591-1603](../ext/Server/NodeCollection.lua#L1591-L1603)
The save runs `DROP TABLE` in one frame and then the INSERT batches over several later frames, with no transaction. If any batch fails, or the level changes mid-save (`Clear()` aborts the state machine), the table is left empty or partial.
*(plausible)* The SQL handle also stays open across frames while `Database:Query()` calls `SQL:Open()` / `SQL:Close()` on the same global `SQL` object, for example when a settings save lands during a trace save.
Loading traces held SQL open across frames in the same way; it now opens and closes it per step as well.
*Fix:* build `<map>_table_new`, then `BEGIN; DROP old; ALTER TABLE … RENAME; COMMIT`. Alternatively, do the whole write synchronously inside one transaction.

**B5. Server NetEvents with no permission check** — ✅ fixed
The client only hides or doesn't register these, but the server accepts them from any client:

| Event | Handler | Effect |
|---|---|---|
| `SpawnPointHelper:TeleportTo` | [\_\_init\_\_.lua:688](../ext/Server/__init__.lua#L688) | Any player can teleport themselves to any transform |
| `ConsoleCommands:SpawnGrenade` | [\_\_init\_\_.lua:654](../ext/Server/__init__.lua#L654) | Spawns a live M67. Also crashes when the sender is dead (`p_Player.soldier` is nil) |
| `ConsoleCommands:DestroyObstaclesTest` | [\_\_init\_\_.lua:662](../ext/Server/__init__.lua#L662) | Spawns grenades |
| All `NodeEditor:*` (≈30 events) | [NodeEditor.lua:40-74](../ext/Server/NodeEditor.lua#L40-L74) | Edit, move or remove waypoints and spawn bots on a path |
| `NodeCollection:Clear`, `NodeCollection:Create` | [NodeCollection.lua:27-28](../ext/Server/NodeCollection.lua#L27-L28) | Wipe the in-memory waypoint graph. No client ever sends these; the subscriptions are dead code |

Exploiting these needs a modified client, but the server must not rely on that. *Fix:* check `HasPermission` in each handler; §Improvements I2 describes a single wrapper.
*Done via I2.* The `NodeEditor:*`, `SpawnPointHelper:TeleportTo` and `PathMenu:Request/Open/Unhide` events need `UserInterface.WaypointEditor`; the grenade test events need `UserInterface.Settings`. The dead `NodeCollection:Create/Clear` subscriptions are removed. While doing this, `NodeEditor:SetLoopMode` and `NodeEditor:SetSpawnPath` turned out to be sent by the client under names the server never subscribed to (`SetPathLoops` / `AddSpawnPath`), so the console commands did nothing. The client now sends the subscribed names.

### Medium

**B6. `Globals.SpawnMode = "manual"` (a string) never equals `SpawnModes.manual` (`0`)** — ✅ fixed
Set in 11 places: [UIServer.lua:276-341](../ext/Server/UIServer.lua#L276), [BotSpawner.lua:740/764/793](../ext/Server/BotSpawner.lua#L740), [RCON.lua:94/122](../ext/Server/Commands/RCON.lua#L94).
After any manual spawn, kick or kill, `BotSpawner` doesn't recognise manual mode. The garbage-collection guard `~= SpawnModes.manual` ([BotSpawner.lua:139](../ext/Server/BotSpawner.lua#L139)) passes when it shouldn't, and the `== SpawnModes.manual` branch ([BotSpawner.lua:699](../ext/Server/BotSpawner.lua#L699)) never runs. *Fix:* use `SpawnModes.manual` everywhere.

**B7. Setting `DynamicList` values (weapons) via RCON or console picks the wrong weapon** — ✅ fixed (I1)
[SettingsManager.lua:270-281](../ext/Server/SettingsManager.lua#L270-L281)
`_G[Reference]` is an array such as `AssaultPrimary = {"M416", "AK74M", …}`, so `l_Key` is an integer. `string.find("M416", 1)` finds the digit `1` and returns weapon #1. Most inputs therefore select an arbitrary weapon or fail.
*Fix:* compare values (`l_Value == p_Value`) the way `UIServer:_writeSettings` does.

**B8. Enum settings via RCON or console use substring matching in `pairs` order** — ✅ fixed (I1)
[SettingsManager.lua:242-251](../ext/Server/SettingsManager.lua#L242-L251)
`string.find(p_Value, l_Key)` with `SpawnMethod = {SpawnSoldierAt, Spawn, SpawnOnTdm}`: the input `SpawnOnTdm` also matches the key `Spawn`. Which one wins depends on hash order. *Fix:* exact key match.

**B9. Empty or non-numeric number fields crash the settings save** — ✅ fixed (I1)
[UIServer.lua:674-680](../ext/Server/UIServer.lua#L674-L680), [SettingsManager.lua:228-233](../ext/Server/SettingsManager.lua#L228-L233), [Range.lua `IsValid`](../ext/Shared/Settings/Range.lua)
`tonumber("")` is `nil`, and `nil >= min` raises an error. In the WebUI path this aborts `_writeSettings` halfway: `Config` is partly updated, the batch never runs and the UI never closes. *Fix:* return `false` from `Range:IsValid` for non-numbers. Integer settings should also `math.floor` the value.

**B10. The comm-rose "Defend objective" makes bots attack** — ✅ fixed
[UIServer.lua:228-236](../ext/Server/UIServer.lua#L228-L236) calls `BotManager:Attack`, which always sets `BotObjectiveModes.Attack` ([BotManager.lua:1281](../ext/Server/BotManager.lua#L1281)). *Fix:* add an objective-mode parameter, or a `Defend` function that sets `BotObjectiveModes.Defend`.

**B11. `!spawnway` and `!spawnbots` chat commands are broken** — ✅ fixed
[Chat.lua:380](../ext/Server/Commands/Chat.lua#L380), [Chat.lua:393](../ext/Server/Commands/Chat.lua#L393) call `SpawnWayBots(p_Player, s_Amount, …)`, but the signature is `SpawnWayBots(p_Amount, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_TeamId)` ([BotSpawner.lua:827](../ext/Server/BotSpawner.lua#L827)). The Player object ends up as the amount.

**B12. `!setbotkit` and `!setbotcolor` set the config to `nil`** — ✅ fixed
[Chat.lua:435](../ext/Server/Commands/Chat.lua#L435), [Chat.lua:445-446](../ext/Server/Commands/Chat.lua#L445-L446)
`BotKits` and `BotColors` are name→number maps, so `BotKits[2]` is `nil`, and `#BotColors` is `0`, so the range check is wrong too. *Fix:* assign the number directly after range-checking it against `BotKits.Count` or the maximum color value.

**B13. Anyone can change vehicle aim offsets with `!dbg`** — ✅ fixed
[Chat.lua:245-252](../ext/Server/Commands/Chat.lua#L245-L252) has no permission check. `Debug.Vars[6]` and `Debug.Vars[7]` feed directly into vehicle yaw/pitch correction ([VehicleMovement.lua:469-470](../ext/Server/Bot/VehicleMovement.lua#L469-L470)). *Fix:* gate it behind a permission or `Registry.DEBUG`.

**B14. `!permissions` always reports "no active permissions"** — ✅ fixed
[Chat.lua:20](../ext/Server/Commands/Chat.lua#L20) passes the `Player` object. `GetPermissions` then indexes `m_Permissions[p_Name]` with that object instead of `player.name` ([PermissionManager.lua:77](../ext/Server/PermissionManager.lua#L77)).

### Low

**B15.** ✅ fixed. `!stop` / `!stopall` pass the option `'respawning'`, but only `'respawn'` exists, so respawn is never disabled ([Chat.lua:486](../ext/Server/Commands/Chat.lua#L486), [Chat.lua:495](../ext/Server/Commands/Chat.lua#L495)).
**B16.** ✅ fixed. `!kickp_Player` can never match because messages are lowercased first. This is a leftover of a rename to `!kickplayer` ([Chat.lua:497](../ext/Server/Commands/Chat.lua#L497)).
**B17.** ✅ fixed. Chat commands that use `p_Player.soldier` without a nil check crash when the caller is dead: `!weap`, `!printtrans`, `!row`, `!tower`, `!grid` (the latter via `BotSpawner:SpawnBotRow/Tower/Grid`). These now reply "You need to be alive for this command."
**B18.** ✅ fixed. `SetRespawnDelay`: `tonumber(x) / 100` raises an error on `nil` before the `~= nil` guard can run ([\_\_init\_\_.lua:780-782](../ext/Server/__init__.lua#L780-L782)). `OnModReloaded` concatenates `s_GameMode` before its nil check ([\_\_init\_\_.lua:769-772](../ext/Server/__init__.lua#L769-L772)).
**B19.** ✅ fixed (I1). Runtime changes via RCON or console ignore the `Language` and `MaxBots` update flags, so a language change via RCON doesn't reload text ([SettingsManager.lua:292-302](../ext/Server/SettingsManager.lua#L292-L302)). `RestoreDefault()` resets `Config` without triggering any update flag, broadcasting to clients or persisting ([SettingsManager.lua:209-213](../ext/Server/SettingsManager.lua#L209-L213)).
**B20.** ✅ fixed. `KillAll(0)` / `DestroyAll(0)` still remove one bot because the amount is checked after acting ([BotManager.lua:948-958](../ext/Server/BotManager.lua#L948-L958)). `!kick 0` kicks one bot.
**B21.** ✅ fixed. `Bot:_UpdateInputs` handles at most one expired delayed input per tick and stops decrementing the rest after it, so later delays run long ([Bot.lua:532-543](../ext/Server/Bot/Bot.lua#L532-L543)).
**B22.** ✅ fixed. SQL is built by string concatenation with no escaping in `Database:Insert/Update/Delete`, `PermissionManager:AddPermission` and `SettingsManager` lookups. Any value containing `'` breaks the query. Inputs come from admins and RCON, so this is mostly a robustness issue. *Fix:* `Database:Quote()` doubles embedded quotes (SQLite syntax) and is used for every concatenated value.
**B23.** ✅ fixed. `Client:RequestChangeVehicleSeat` doesn't range-check the client-supplied seat number ([BotManager.lua:500-514](../ext/Server/BotManager.lua#L500-L514)). `Botmanager:RaycastResults` trusts client-reported bot IDs, and `OnBotShootAtBot` doesn't check that the two bots are on different teams ([BotManager.lua:383-398](../ext/Server/BotManager.lua#L383-L398)). *Fix:* the seat number is range-checked. `Bot:ShootAt` already refuses teammates; `Bot:Revive` had no team check, so a forged report could make an enemy bot revive a player. It now only revives teammates.
**B24.** ✅ fixed. Minor cleanups: `BotNames` is required twice in [Shared/\_\_init\_\_.lua](../ext/Shared/__init__.lua#L13-L15). There's a stray `print(self:Query(...))` in `Database:Update`, and `ExecuteBatch` is commented "This is unused" although it is used.

---

## Bot behaviour, movement and management (second pass)

This second pass covers `Bot/`, `BotStates/`, `BotManager`, `BotSpawner`, `GameDirector` and `PathSwitcher`. As before, it is a static review.

### High

**B25. GameDirector assigns no objectives when team 1 has no active bots** — ✅ fixed
[GameDirector.lua:175-187](../ext/Server/GameDirector.lua#L175-L187), [GameDirector.lua:304](../ext/Server/GameDirector.lua#L304), [GameDirector.lua:314](../ext/Server/GameDirector.lua#L314)
`s_BotsByTeam` is keyed by team ID and only gets an entry for teams that have bots. Both loops run `for l_BotTeam = 1, #s_BotsByTeam`. When only team 2 has bots, `s_BotsByTeam[1]` is nil and `#s_BotsByTeam` is `0`, so neither loop runs. That happens in the usual "players vs bots" setups: `SpawnInBothTeams = false`, `BotTeam = 2`, or `increment_with_players`. In Conquest and Rush the bots then never get an attack or defend objective and wander along whatever `PathSwitcher` picks.
*Fix:* `for l_BotTeam = 1, Globals.NrOfTeams do` and skip teams where `s_BotsByTeam[l_BotTeam] == nil`.

**B26. Defending bots don't hold position (regression)** — ✅ fixed
[BotMovement.lua:188-229](../ext/Server/Bot/BotMovement.lua#L188-L229), [BotMovement.lua:572](../ext/Server/Bot/BotMovement.lua#L572)
Commit `7569899b` ("some cleanup") moved the defend block into `_HandleDefendingIfNeeded()`. Its `return` statements ("don't do anything else") now leave only the helper, not `UpdateNormalMovement`. The caller keeps running: `m_ActiveSpeedValue = s_Point.SpeedMode` overwrites `NoMovement`, `_TargetPoint = s_Point` undoes the `LookAround()` reset, and `_HandleSidwardsMovement` overwrites the strafe. Defenders therefore keep walking the objective path instead of stopping, looking around and changing pose. `DefendObjectives` is on by default, so this affects most Conquest games.
*Fix:* return a boolean from the helper and `return` from `UpdateNormalMovement` when it is true.

### Medium

**B27. Stuck bots are never killed and loop through the same reroute** — ✅ fixed
[BotMovement.lua:626-640](../ext/Server/Bot/BotMovement.lua#L626-L640), [BotMovement.lua:388-390](../ext/Server/Bot/BotMovement.lua#L388-L390)
The "hard reroute" patch fires at `_StuckTimer > 6.0` and resets the timer to 0. As a result, the `> 15.0` kill in `_ObstacleHandling` can no longer trigger. `FindClosestPath(pos, false, true)` returns the node closest to the bot, which is usually the one it is stuck on, so the bot repeats the reroute every 6 s indefinitely. The reroute also forces `_InvertPathDirection = false`, which discards the objective direction, and it doesn't reset `_ObstacleSequenceTimer` or `_LastWayDistance`.
*Fix:* count reroutes, and fall back to the kill after one or two failed attempts. Keep or recompute the direction with `ObjectiveDirection`.

**B28. Rejoining the path after combat picks the wrong node** — ✅ fixed
[BotMovement.lua:532-547](../ext/Server/Bot/BotMovement.lua#L532-L547)
The scan never updates `s_ClosestDistance`, so `s_ClosestNode` ends up as the last scanned node (up to ±19 away) that is closer than the *starting* node, not the closest node. The `< 5.0` check also tests the starting node's distance, so no rejoin happens once the bot has moved more than 5 m from its old waypoint. Bots then run back to their old waypoint or skip ahead or behind along the path. The scan also only checks every second node (`step 2`).
*Fix:* update `s_ClosestDistance` together with `s_ClosestNode`, and test the final closest distance.

**B29. The path offset on the next point uses the current segment's direction** — ✅ fixed
[BotMovement.lua:70-78](../ext/Server/Bot/BotMovement.lua#L70-L78)
`deltaNext = p_NextPoint.Position - p_OriginalPoint.Position` duplicates `delta`. It should be `p_NextToNextPoint.Position - p_NextPoint.Position`. At every corner, the offset target for the next node points sideways relative to the incoming segment, so bots cut or overshoot corners by up to 1.2 m, which is enough to clip walls in doorways. `p_NextToNextPoint` is otherwise only nil-checked. Also, `m_OffsetRecoveryNodes` is decremented once per `Update` tick (0.13 s), not per node as the comments say. *(Fixed by correcting the comments; the counter values are tuned for update ticks.)*

**B30. Player team balancing moves dead bots and counts them as players** — ✅ fixed
[BotSpawner.lua:530-552](../ext/Server/BotSpawner.lua#L530-L552)
The loop moves any player with `soldier == nil` who is in another team, and that includes bots waiting to respawn. Each move is counted in `s_CountPlayers` (real players only), so the target is "reached" without moving a human. Bots end up in the wrong team (and in the wrong `_BotsByTeam` list), and human players stay unbalanced. The loop also calls `PlayerManager:GetPlayers()` twice per iteration.
*Fix:* skip `m_Utilities:isBot(l_Player)`.

**B31. Beacon and squad-mate spawns are overwritten, and can teleport repeatedly** — ✅ fixed
[BotSpawner.lua:201-244](../ext/Server/BotSpawner.lua#L201-L244)
The beacon/mate branch sets the path, teleports or enters the vehicle, and applies customization, but it neither removes the bot from `_BotsWithoutPath` nor `break`s. Execution falls through to the closest-path code, which overwrites the chosen path and direction with `FindClosestPath(..., false, false)` (first nodes only, direction forced forward). Customization is also applied a second time. If no closest path is found, the bot stays in the list and is teleported to a mate or beacon again on the next frame. A bot whose spawn failed stays in the list with `soldier == nil`, and it can be added again on its next respawn, so it gets processed twice once it finally spawns.

**B32. A failed vehicle spawn permanently disables the bot** — ✅ fixed
[BotSpawner.lua:185-186](../ext/Server/BotSpawner.lua#L185-L186), [BotSpawner.lua:207-208](../ext/Server/BotSpawner.lua#L207-L208), [BotSpawner.lua:1416-1417](../ext/Server/BotSpawner.lua#L1416-L1417), [BotSpawner.lua:1433-1434](../ext/Server/BotSpawner.lua#L1433-L1434)
These paths call `Bot:Kill()`, which runs `ResetVars()` and sets `_SpawnMode = NoRespawn` and `_Respawning = false`. The bot becomes inactive and is later garbage-collected, and a new bot is created. That churns bot names and loses bots entirely in manual mode. `BotMovement.lua:649` shows the right pattern for "kill but keep respawning": `soldier:Kill()`. The `SpawnAt*` paths also spawn the soldier at `LinearTransform()` (the world origin) before trying the vehicle. When `s_SpawnEntity` is nil, the bot is spawned and killed immediately. *(plausible)* This costs a ticket in Conquest.

**B33. Scavenger and GunMaster crash on beacon paths and beacon actions** — ✅ fixed
[PathSwitcher.lua:154](../ext/Server/PathSwitcher.lua#L154), [BotMovement.lua:151](../ext/Server/Bot/BotMovement.lua#L151)
`p_Bot.m_SecondaryGadget.type` is read without a nil check. `_SetBotWeapons` sets `m_SecondaryGadget = nil` in Scavenger and returns early in GunMaster ([BotSpawner.lua:2253-2264](../ext/Server/BotSpawner.lua#L2253-L2264)). On any map with a beacon path or `beacon` action, this raises an error inside `BotManager:OnUpdateManagerUpdate`, which aborts that tick for every bot after it in the batch.

**B34. "Change direction if stuck" sets the direction instead of flipping it** — ✅ fixed
[BotMovement.lua:380-384](../ext/Server/Bot/BotMovement.lua#L380-L384)
`_InvertPathDirection = CheckProbability(P)` sets an absolute value. A bot that is already inverted is switched to forward with probability `1-P`, which is usually the likely outcome. The intended behaviour is `if CheckProbability(P) then invert = not invert end`.

**B35. PathSwitcher ignores better paths when the best one was filtered out** — ✅ fixed
[PathSwitcher.lua:234-246](../ext/Server/PathSwitcher.lua#L234-L246), [PathSwitcher.lua:270-282](../ext/Server/PathSwitcher.lua#L270-L282)
`s_HighestPriority` is updated *before* the validity filter on line 239. If the highest-priority link fails the filter (for example, a base path), `s_HighestPrioPathsIndex` is empty, `GetRandomInt(1, 0)` is called, and the function returns `false`. A valid path whose priority is still higher than the current one is then skipped.
*Fix:* update `s_HighestPriority` only for paths inserted into `s_ValidPaths`.

### Low

**B36.** ✅ fixed. In defend mode, `if self.m_Id % 2 then` is always true in Lua (`0` is truthy), so every defender strafes left ([BotMovement.lua:220](../ext/Server/Bot/BotMovement.lua#L220)). *Fix:* `% 2 == 0`. (This only matters once B26 is fixed.)
**B37.** ✅ fixed. Vehicle look-around reuses `_VehicleWaitTimer`, which is also the "wait for passengers" timer. When a driver with a weapon seat waits at a wait node, look-around adds `dt` and the next `UpdateNormalMovementVehicle` subtracts it again. As a result, `_SetVehicleObjectiveState()` runs every tick (a full scan over all paths), and the look-around never gets past its first phase ([VehicleMovement.lua:23-30](../ext/Server/Bot/VehicleMovement.lua#L23-L30), [VehicleMovement.lua:384-409](../ext/Server/Bot/VehicleMovement.lua#L384-L409)). *Fix:* use a separate look-around timer.
**B38.** ✅ fixed. *(plausible)* `_FindTargetLocation` returns an enemy HQ as soon as the iterator reaches one. It should prefer capturable flags and fall back to the HQ, as its closing comment says. Depending on iteration order, Conquest bots spawn at the flag closest to the enemy base instead of the one closest to the front ([BotSpawner.lua:1162-1194](../ext/Server/BotSpawner.lua#L1162-L1194)).
**B39.** ✅ fixed. *(plausible)* `OnPlayerLeft` calls `ClearPlayer`, which doesn't clear `_FollowTargetPlayer`. Bots following a player who disconnects keep reading `.soldier` on a deleted `Player` ([BotManager.lua:199-203](../ext/Server/BotManager.lua#L199-L203), [Bot.lua:439-454](../ext/Server/Bot/Bot.lua#L439-L454)).
**B40.** ✅ fixed. When `CreateBot` reuses an existing bot, it changes `teamId` but leaves the bot in its old `_BotsByTeam` list until the next `RefreshTables()`, which never runs in manual mode. Commands that use team lists (`KillAll(n, team)`, comm-rose actions) then act on the wrong bots ([BotManager.lua:848-853](../ext/Server/BotManager.lua#L848-L853)).
**B41.** ✅ fixed. `KillAll(n, team)` counts bots that are already dead or inactive towards `n`, so balancing needs several 2-second cycles to reach its target ([BotManager.lua:948-958](../ext/Server/BotManager.lua#L948-L958)).
**B42.** ✅ fixed. `_AirSuperioritySpawn` returns after the first spawn entity of the bot's team even when it isn't a vehicle spawn, so later valid spawns are never tried ([BotSpawner.lua:1024-1040](../ext/Server/BotSpawner.lua#L1024-L1040)).
**B43.** ✅ fixed. Leftovers: in `_GetWayIndex`, `s_Diff` is computed after the index has been clamped, so it is always `-1` and the reflection code is dead ([BotGetters.lua:481-498](../ext/Server/Bot/BotGetters.lua#L481-L498)). The dead code was removed, so path-end behaviour is unchanged. `_ExecuteActionIfNeeded` assigns the undeclared global `p_NextPoint` ([BotMovement.lua:144](../ext/Server/Bot/BotMovement.lua#L144)).

### Vehicles, choppers and jets

This subsection covers `VehicleMovement`, `VehicleChopperControl`, `VehicleJetControl`, `VehicleAttacking`, `VehicleAiming`, `VehicleWeaponHandling` and the vehicle states. B37 above also concerns vehicle movement.

**B44 (Medium). After a weapon switch, the bot aims with the previous weapon's part** — ✅ fixed
[VehicleWeaponHandling.lua:47-51](../ext/Server/Bot/VehicleWeaponHandling.lua#L47-L51)
`_VehicleMovableId` is computed from `_ActiveVehicleWeaponSlot` *before* that field is set to the new slot, so it always holds the part of the weapon that was just deselected. `GetOffsets` and `GetRotationOffsets` use the new slot, so the transform and the offsets come from different weapons. This matters wherever the parts differ per slot: the BMP-2 driver (cannon `37` vs. TOW `6`) and both AC-130 gunner seats (`{1, 3}`, `{0, 2}`) ([VehicleData.lua:150](../ext/Shared/Constants/VehicleData.lua#L150), [VehicleData.lua:587](../ext/Shared/Constants/VehicleData.lua#L587)). Their turret and gunship aim is computed against the wrong part.
*Fix:* assign the slot first, then call `GetPartIdForSeat(..., p_Bot._VehicleWeaponSlotToUse)`.

**B45 (Medium). Choppers and jets from one team all fly to the same flag** — ✅ fixed
[GameDirector.lua:1714-1739](../ext/Server/GameDirector.lua#L1714-L1739)
`s_EnemyNode` is never assigned: the first `if` stores every non-friendly flag in `s_NeutralNode`. The "enemy first, then neutral" preference therefore doesn't exist, and every air vehicle of a team targets whichever non-owned flag comes last in `_AllCapturePoints`. That is the same point for all of them and ignores distance. In Rush, `self._McomPositions[...]` is nil if a stage's MCOM has no trace path. Large Rush then does arithmetic on nil, and Squad Rush returns nil, so `:Clone()` in `UpdateMovementChopper` / `UpdateMovementJet` raises an error on every tick. In every other mode the function returns `Vec3.zero`, so air vehicles circle the world origin.

**B46 (Medium). Passenger bots only see one MCOM (Rush) or none (Squad Rush) when deciding to get out** — ✅ fixed
[GameDirector.lua:953-966](../ext/Server/GameDirector.lua#L953-L966), [Bot.lua:409-419](../ext/Server/Bot/Bot.lua#L409-L419)
`GetActiveMcomPositions` fills keys `0` and `1`, but the caller loops `for l_Index = 1, #s_ActiveMcoms`. Key `0` is never visited. In Squad Rush the only MCOM is at key `0`, and in Rush it is the even-numbered MCOM, so passengers ride past it instead of dismounting.
*Fix:* use keys `1` and `2`.

**B47 (Medium). A vehicle bot keeps attacking forever when shooting is disabled** — ✅ fixed
[VehicleAttacking.lua:17](../ext/Server/Bot/VehicleAttacking.lua#L17), [VehicleAttacking.lua:146-148](../ext/Server/Bot/VehicleAttacking.lua#L146-L148)
If `_Shoot` is false (for example after `!stop` or `SetOptionForAll("shoot", false)`) while the target is alive, neither branch runs. `_ShootModeTimer` never counts down and `AbortAttack` is never called. The vehicle stays in its attack state, stopped and aiming, until the target dies. The infantry path handles this case (`not p_Bot._Shoot` → abort).

**B48 (Low). The chopper banks the same way on every turn** — ✅ fixed *(bank direction not verified in-game)*
[VehicleChopperControl.lua:167-173](../ext/Server/Bot/VehicleChopperControl.lua#L167-L173)
`if s_AbsDeltaYaw > 0` is always true while `_FullVehicleSteering` is set, so the target roll is always `+0.1`. Left turns are flown with the wrong bank.
*Fix:* test the sign of `s_DeltaYaw`.

**B49 (Low, plausible). The gunship's aiming yaw is 90° off from every other yaw in the mod** — ❌ not a bug (fix reverted)
[VehicleMovement.lua:490](../ext/Server/Bot/VehicleMovement.lua#L490)
The gunship branch sets `_TargetYaw = math.atan(dz, dx)`, but everywhere else yaw is `atan(dz, dx) - π/2`, wrapped to 0–2π. That value is written to `authoritativeAimingYaw` ([VehicleMovement.lua:572](../ext/Server/Bot/VehicleMovement.lua#L572)), which `Bot:ShootAt` uses for the FOV check. Gunship gunners therefore detect targets in a cone rotated by a quarter turn from where their guns point.
*Resolution:* tested in-game. The original `atan(dz, dx)` is correct; the gunship's gunner entries are oriented differently in the engine, and the "fixed" version was off. Reverted, with a comment in the code.

**B50 (Low).** ✅ fixed. Assorted smaller issues:
- Pitch is derived as `-euler.z / math.cos(roll)` in the chopper, jet and vehicle-yaw code. It grows without bound as a chopper or jet banks towards 90° ([VehicleChopperControl.lua:70](../ext/Server/Bot/VehicleChopperControl.lua#L70), [VehicleMovement.lua:555](../ext/Server/Bot/VehicleMovement.lua#L555)).
- `PidController:Reset()` clears only the integral, not `_LastError`, so the first update after a reset (a jet aborting an attack) gets a derivative kick ([PidController.lua:18-20](../ext/Server/PidController.lua#L18-L20)).
- `StateInVehicleJetControl` reads `g_PlayerData:GetData(id).Vehicle` without a nil check ([StateInVehicleJetControl.lua:64](../ext/Server/BotStates/StateInVehicleJetControl.lua#L64)).
- `VehicleMovement:UpdateTargetMovementVehicle` sets `_TargetPoint = _NextTargetPoint` without checking it for nil, and then indexes `.Position` ([VehicleMovement.lua:354-358](../ext/Server/Bot/VehicleMovement.lua#L354-L358)).

---

## Improvements

**I1. One settings validator.** ✅ Done: `SettingsManager:Apply(values, persist)` with `ParseValue()`. `UpdateSetting()` (RCON, console) and the WebUI both call it. `RestoreDefault()` now persists the defaults and runs the update flags. Invalid values are kept at their current value and reported in chat. There are three independent parsers: `UIServer:_writeSettings`, `SettingsManager:UpdateSetting`, and `Console` via `UpdateSetting`. They disagree, and that is the root cause of B7, B8, B9 and B19. Move to a single `SettingsManager:Apply(name, rawValue, {persist=bool})` that validates, converts, persists, runs the `UpdateFlag` side effects and broadcasts. All three entry points should call it.

**I2. A guarded NetEvent helper.** ✅ Done: `PermissionManager:SubscribeNetEvent(name, permission, context, handler)`. `UIServer:_onBotEditorEvent` checks one action→permission table up front instead of repeating the check in each branch. For example, `SecureNetEvent(name, permission, handler)`, which checks `HasPermission` (and optionally that `player.soldier` exists) before dispatching. Register every mutating server NetEvent through it. This fixes B5 structurally and removes about 60 copies of the identical permission check in [UIServer.lua](../ext/Server/UIServer.lua).

**I3. Table-driven command dispatch.** `Chat.lua` and `UIServer:_onBotEditorEvent` are long `if/elseif` chains that repeat the permission boilerplate. A table of `{permission, handler}` per command is shorter and makes a missing check (B13) obvious. Move debug-only commands (`!car`, `!caryaw`, `!cardiff`, `!weap`, `!dbg`, `!perks`, `!objectives`) behind `Registry.DEBUG`.

**I4. Safer persistence.**
- Use transactions for trace saves (B4) and settings batches. *(Trace saves done with B4.)*
- ✅ Add a small `Database:Escape()` helper (VU provides `SQL:Escape`) and use it everywhere values are concatenated (B22). *(Done as `Database:Quote()`.)*
- Key permissions by account GUID rather than name. The GUID is already stored but not used for lookups.

**I5. Static checks in CI.** ✅ Done: `.luacheckrc` and `.github/workflows/lua-checks.yml` run luacheck on every push and PR (globals, std-library fields, unreachable code; unused/shadowing/style warnings are not enforced yet). `tools/check-lua.sh` also runs `lua-language-server --check` when the VU stubs from the VS Code extension exist in `.vua_data/`; CI can't generate those stubs, so the type check is local only. It currently reports 19 warnings on the server side, all annotation nits. The code already carries EmmyLua annotations. Running `lua-language-server --check` with the VU stubs, plus `luacheck`, in a GitHub workflow would have flagged B6 (string vs enum), B11 (argument mismatch), B12 and B14. The CodeQL workflow is currently in `disabled-workflows/`.

**I6. Escape data passed into `WebUI:ExecuteJS`.** [UIClient.lua:78/84/231](../ext/Client/UIClient.lua#L78) wrap JSON in `'…'`. A `'` in any translated label or setting string breaks the UI. The French file already drops apostrophes (`"Objectif d attaque"`) to work around this. Escaping `'` and `\` in the Lua helper removes the constraint.

**I7. Don't broadcast full node lists.** `NodeEditor:OnRequestData` sends *all* waypoints to *all* active editor players whenever anyone requests them ([NodeEditor.lua:644-659](../ext/Server/NodeEditor.lua#L644-L659)). Send only to the requester.

**I8. Localize booleans in the WebUI deliberately.** `EntryElement` renders the literal `"Yes"` / `"No"` and `BotEditor` reads the value back by comparing `innerHTML == "Yes"` ([BotEditor.js:569](../WebUI/classes/BotEditor.js#L569)). This works today only because the words are never translated. Store the value in a `data-value` attribute instead.

**I9. Documentation hygiene.** The earlier `docs/*_SUMMARY.md` files contain guesses ("likely", "appears to") that the code doesn't support. Merge anything useful into [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) and drop the rest. The auto-generated `Config.lua` header says "use this file and regenerate the Config.lua file"; it should say to edit `SettingsDefinition.lua`.

---

## Suggested order

Fixed items have been removed from this list. All bugs above are fixed; what remains are improvements.

1. Test in-game: B48 (chopper bank direction) couldn't be verified from source. (B49 tested: not a bug, reverted.)
2. I4: settings-batch transaction, and keying permissions by account GUID.
3. I6, I8: escaping for `WebUI:ExecuteJS` and `data-value` for booleans, which lifts the no-apostrophe constraint on translations.
4. I7: send node lists only to the requester.
5. I3: move debug-only chat commands behind `Registry.DEBUG`.
6. Enable more luacheck warnings (unused variables, shadowing) once the existing ones are cleaned up.
7. I9: documentation hygiene.
