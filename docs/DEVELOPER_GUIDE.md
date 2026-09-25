# fun-bots Developer Guide

A technical map of the fun-bots codebase for people who want to change it. For installing and configuring the mod as a server owner, see the [README](../README.md) and the [wiki](https://github.com/Joe91/fun-bots/wiki).

- **What it is:** a [Venice Unleashed](https://veniceunleashed.net/) (VU) mod that adds AI soldiers ("bots") to Battlefield 3 servers. Bots follow hand-authored waypoint graphs ("traces"), fight, revive, use vehicles (including jets, choppers and stationary AA), and play objectives in Conquest, Rush, TDM, SDM, GunMaster, Domination, CTF and Scavenger.
- **Version:** see [mod.json](../mod.json) (currently `3.1.0-dev1`), requires VEXT `>= 1.12.0`.
- **Size:** ~35k lines of Lua (server ~70%), a Vite WebUI and a Python helper tool.

---

## 1. Repository layout

```
fun-bots/
├── mod.json                  VU mod manifest (name, version, VEXT dependency, HasWebUI)
├── ext/
│   ├── Shared/               Loaded by server AND client (VU realm "__shared")
│   ├── Server/               Authoritative game logic: bots, spawning, AI, editor, persistence
│   └── Client/               Raycast helper for the server, node-editor rendering, UI bridge
├── WebUI/                    In-game UI (settings editor, trace editor, comm-rose); built into ui.vuic
├── ui.vuic                   Compiled WebUI bundle that VU loads
├── mod.db                    SQLite DB: settings, permissions and one table per map trace
├── mapfiles/                 ~185 trace files (<Level>_<GameMode>.map), the source of truth in git
├── permission_and_config/    Text exports of the FB_Settings / FB_Config_Trace / FB_Permissions tables
├── fun-bots-helper/          Python/customtkinter GUI for DB import/export, map fixes, code generation
├── tools/                    check-lua.sh (luacheck + lua-language-server) and one-off map-file scripts
├── Supported-maps.md         Generated table of which maps/modes have traces
└── .github/                  Changelog, contributing, coding guidelines, CI workflows (release, luacheck)
```

`.vummignore` keeps `mapfiles/*.map`, `permission_and_config/*.cfg` and `.vu/` out of the release package. Released builds ship `mod.db` with the traces already imported.

---

## 2. The three Lua realms

VU runs each `ext/<Realm>/__init__.lua` as the entry point for that realm. Anything required via `__shared/...` is loaded into both server and client.

### 2.1 Shared ([ext/Shared](../ext/Shared))

| Area | Files | Purpose |
|---|---|---|
| Compile-time tuning | [Registry/Registry.lua](../ext/Shared/Registry/Registry.lua) | Constants not exposed in the UI: update-cycle timings, raycast budgets, vehicle tuning, bot token (`BOT_`), debug switches. **Load first.** |
| Runtime settings | [Settings/SettingsDefinition.lua](../ext/Shared/Settings/SettingsDefinition.lua) | Single source of truth for every user-facing setting: name, type (`Integer`, `Float`, `Boolean`, `Enum`, `List`, `DynamicList`), range/reference, default, category, `UpdateFlag`. |
| | [Config.lua](../ext/Shared/Config.lua) | **Generated** from `SettingsDefinition.lua` by the helper (`create_settings`). Holds the global `Config` table with defaults. |
| Enums/constants | [Constants/](../ext/Shared/Constants), [Settings/BotEnums.lua](../ext/Shared/Settings/BotEnums.lua) | Kits, colors, weapons, spawn modes/methods, team-switch modes, attack modes, move speeds, vehicle data, bot names. |
| Weapons | [WeaponList.lua](../ext/Shared/WeaponList.lua), [WeaponClass.lua](../ext/Shared/WeaponClass.lua), [WeaponLists/](../ext/Shared/WeaponLists) | Weapon catalogue per kit/team; builds the dynamic lists (`AssaultPrimary`, `PistolWeapons`, …) that `DynamicList` settings refer to by global name. |
| i18n | [Language.lua](../ext/Shared/Language.lua), [Languages/](../ext/Shared/Languages) | `Language:I18N()` for server-side chat/yell text. |
| Utilities | [Utilities.lua](../ext/Shared/Utilities.lua), [ArrayMap.lua](../ext/Shared/ArrayMap.lua), [Utils/Logger.lua](../ext/Shared/Utils/Logger.lua), [Utils/Profiler.lua](../ext/Shared/Utils/Profiler.lua), [Debug.lua](../ext/Shared/Debug.lua) | `isBot`, string `split`, `table.has`, logger per module with per-module debug level. |
| Bundle workaround | [\_\_init\_\_.lua](../ext/Shared/__init__.lua) | Optional (`Registry.COMMON.USE_LOAD_BUNDLE_BUGFIX`): mounts MP_011/MP_003 bundles to stop bot weapons disappearing. |

**Settings vs Registry:** if an admin should change it at runtime, add it to `SettingsDefinition.lua` (then regenerate `Config.lua`). If it is a developer knob, put it in `Registry.lua`.

### 2.2 Server ([ext/Server](../ext/Server))

Every manager is a singleton: the module creates `g_<Name>` once and returns it, so `require('BotManager')` from anywhere returns the same instance.

| Module | Responsibility |
|---|---|
| [\_\_init\_\_.lua](../ext/Server/__init__.lua) | Bootstrap. Subscribes to all engine events and hooks and forwards them to managers. Detects game mode (`SetGameMode`), max bots per team, respawn delay, other mods (PreRound, Civilianizer), input restrictions. Patches EBX data (server-side damage, AA spread, auto-team settings). |
| [BotManager.lua](../ext/Server/BotManager.lua) | Owns all `Bot` objects (`_Bots`, `_BotsByName`, `_BotsByPlayerId`, `_BotsByTeam`). Runs the tiered update loop, bot-vs-bot attack/revive checks, damage hook (damage multipliers, no suicide), delayed destruction queue, and comm-rose actions (follow, enter/exit vehicle, deploy, repair, attack). |
| [BotSpawner.lua](../ext/Server/BotSpawner.lua) | Decides **how many** bots per team (spawn modes: manual, fixed number, increment with players, balanced teams, keep player count), **where** they spawn (path node, squad mate, beacon, vehicle, engine spawn), team switching between rounds, kicking players using bot names, kit/weapon/appearance customization. |
| [BotCreator.lua](../ext/Server/BotCreator.lua) | Bot personas (skill, accuracy, reaction, preferred weapon/vehicle) and name allocation. |
| [GameDirector.lua](../ext/Server/GameDirector.lua) | Strategic layer: tracks capture points, MCOMs, bases, spawnable vehicles, beacons, gunship. Periodically assigns bots to attack/defend objectives and handles path switching at objectives. |
| [PathSwitcher.lua](../ext/Server/PathSwitcher.lua) | Chooses which linked path a bot takes at a junction node, weighted by objectives. |
| [NodeCollection.lua](../ext/Server/NodeCollection.lua) | In-memory waypoint graph: create/link/split/merge nodes, objectives metadata, and a frame-sliced **save/load state machine** against SQLite. |
| [NodeEditor.lua](../ext/Server/NodeEditor.lua) | Server side of the trace editor: handles `NodeEditor:*` NetEvents, per-player custom trace recording, syncing nodes to editing clients. |
| [UIServer.lua](../ext/Server/UIServer.lua), [UIPathMenu.lua](../ext/Server/UIPathMenu.lua) | Handles WebUI requests (`BotEditor`, `UI_Request_Save_Settings`, comm-rose, path menu) with permission checks. |
| [SettingsManager.lua](../ext/Server/SettingsManager.lua), [Database.lua](../ext/Server/Database.lua) | Persist `Config` to SQLite (`FB_Settings`, `FB_Config_Trace`), validate single-setting updates. |
| [PermissionManager.lua](../ext/Server/PermissionManager.lua), [Constants/Permissions.lua](../ext/Server/Constants/Permissions.lua) | Hierarchical permissions (`UserInterface.WaypointEditor.*`) stored in `FB_Permissions`, keyed by player name. `Config.IgnorePermissions` bypasses everything. |
| [Commands/Chat.lua](../ext/Server/Commands/Chat.lua), [Commands/RCON.lua](../ext/Server/Commands/RCON.lua), [Commands/Console.lua](../ext/Server/Commands/Console.lua) | `!chat` commands, `funbots.*` RCON commands (including `funbots.config.<Name>` for every setting), client-console `config.*` commands. |
| [Vehicles.lua](../ext/Server/Vehicles.lua), [AirTargets.lua](../ext/Server/AirTargets.lua) | Vehicle type lookup and the list of air targets for AA bots. |
| [UpdateCheck.lua](../ext/Server/UpdateCheck.lua) | Queries the GitHub API on startup for newer releases. |
| [Model/Globals.lua](../ext/Server/Model/Globals.lua) | Runtime global state: current game mode flags (`IsConquest`, `IsRush`, …), `SpawnMode`, `MaxPlayers`, `RespawnDelay`, `IsInputAllowed`. |

#### The Bot object

[Bot/Bot.lua](../ext/Server/Bot/Bot.lua) defines the `Bot` class. Its methods are spread across mixin files that add functions to the same class:

- Soldier: `BotMovement`, `BotAiming`, `BotAttacking`, `BotWeaponHandling`, `BotActions`
- Vehicle: `VehicleMovement`, `VehicleAiming`, `VehicleAttacking`, `VehicleWeaponHandling`, `VehicleJetControl`, `VehicleChopperControl`, `VehicleActions`
- Accessors: `BotGetters`, `BotSetters`

A bot drives its soldier by writing to an `EntryInput` (`self.m_Player.input:SetLevel(...)`) and setting authoritative yaw/pitch. It does not teleport or script animations.

#### State machine

[BotStates/BotStates.lua](../ext/Server/BotStates/BotStates.lua) holds one stateless singleton per state; `bot.m_ActiveState` points to the current one. Each state implements four update methods that the BotManager calls at different rates:

| Method | Rate (default Registry values) | Typical work |
|---|---|---|
| `UpdateVeryFast(bot)` | every engine tick (after `SingleStepEntry`) | apply yaw/pitch |
| `UpdateFast(bot, dt)` | ~33 Hz (`BOT_FAST_UPDATE_CYCLE = 0.03`) | target tracking, aiming |
| `Update(bot, dt)` | ~7.7 Hz (`BOT_UPDATE_CYCLE = 0.13`) | movement, weapon choice, inputs, state transitions |
| `UpdateSlow(bot, dt)` | ~1.5 Hz (`BOT_SLOW_UPDATE_CYCLE = 0.66`) | reload/deploy decisions, vehicle checks |

States: `Idle`, `Moving`, `Attacking`, `InVehicleMoving`, `InVehicleAttacking`, `InVehicleJetControl`, `InVehicleChopperControl`, `InVehicleStationaryAaControl`, `OnVehicleIdle`, `OnVehicleAttacking` (passenger seats), `StaticMovement`, `StaticAttacking` (mimic/mirror/standstill bots from chat commands). Transitions happen inside the states via `bot:SetState(...)`.

**Batching:** `BotManager:UpdateBotsInBatches` splits the bot list so each tick only updates `N / ratio` bots at each tier. Each bot still gets every tier at its nominal rate, and the per-tick cost stays flat. Keep per-tick work in `UpdateVeryFast` minimal.

### 2.3 Client ([ext/Client](../ext/Client))

The client has no AI authority. It:

- **Does line-of-sight raycasts for the server** ([ClientBotManager.lua](../ext/Client/ClientBotManager.lua)). The server distributes bot-vs-bot and bot-vs-player visibility checks across connected clients (`CheckBotBotAttack`). Clients reply with `Botmanager:RaycastResults`, which trigger `ShootAt` / `Revive`. The budget is `Registry.GAME_RAYCASTING.MAX_RAYCASTS_PER_PLAYER_BOT_BOT`.
- Renders the node editor and handles its input ([ClientNodeEditor.lua](../ext/Client/ClientNodeEditor.lua)), plus the spawn-point helper ([ClientSpawnPointHelper.lua](../ext/Client/ClientSpawnPointHelper.lua)).
- Bridges WebUI ↔ server ([UIClient.lua](../ext/Client/UIClient.lua), [UIViews.lua](../ext/Client/UIViews.lua)): F12 opens the UI, and the configured comm key opens the comm-rose.
- Registers client console commands `config.get.*`, `config.set.*`, `config.saveall`, `config.restore` ([ConsoleCommands.lua](../ext/Client/ConsoleCommands.lua)). The server only sends these to players with the right permission.

---

## 3. Runtime lifecycle (server)

```
Extension:Loaded
  ├─ BotManager:DestroyAllOldBotPlayers()      clean up bots from a previous mod load
  ├─ SettingsManager:OnExtensionLoaded()       merge Config.lua defaults with FB_Settings (see §4)
  ├─ Language / WeaponList init
  ├─ Register events, hooks, NetEvents, EBX instance callbacks
  ├─ BotCreator:CreateBotAttributes()
  └─ OnModReloaded()                           if a level is already running, replay OnLevelLoaded
Level:Loaded
  ├─ set Globals (GameMode, LevelName, IsTdm/IsConquest/…, NrOfTeams, UsedSpawnMethod, MaxBotsPerTeam)
  ├─ optional obstacle destruction (grenades on XP4_Quake)
  ├─ GameDirector / AirTargets / BotSpawner :OnLevelLoaded
  └─ NodeEditor:OnLevelLoaded → NodeCollection:StartLoad(level, mode)   (frame-sliced)
NodeCollection:FinishedLoading  → NodeEditor:EndOfLoad, GameDirector:OnLoadFinished
Engine:Update                   → GameDirector, BotSpawner (spawn queue, 0.3 s spacing), NodeEditor (save/load slices)
UpdateManager:Update(PostFrame) → BotManager tiered loop
Server:RoundOver / RoundReset   → GameDirector; IsInputAllowed=false
Level:Destroy                   → all managers reset; bots are killed, not destroyed (reused next level)
Extension:Unloading             → BotManager:DestroyAll(force)
```

Bots are real `Player` objects created with `PlayerManager:CreatePlayer`. A bot is identified by `onlineId == 0` (`Utilities:isBot`) and its name is prefixed with `Registry.COMMON.BOT_TOKEN`.

---

## 4. Configuration and persistence

All persistent data lives in `mod.db` (SQLite, accessed through VU's `SQL` API):

| Table | Written by | Content |
|---|---|---|
| `FB_Config_Trace` | `SettingsManager:OnExtensionLoaded` | Last-seen value of every `Config.lua` default, with a timestamp |
| `FB_Settings` | UI save / `SaveAll` | Values set by admins at runtime |
| `FB_Permissions` | `PermissionManager:AddPermission` | `(GUID, PlayerName, Value, Time)` |
| `<Level>_<Mode>_table` | `NodeCollection` save | One row per waypoint: `pathIndex, pointIndex, transX/Y/Z, inputVar, data(JSON)` |

**Settings precedence at load:** for each key, the value in `FB_Settings` wins. The exception is when `Config.lua`'s default changed more recently (its `FB_Config_Trace.Time` is newer), in which case the new default wins. So editing `Config.lua` and restarting overrides older UI changes to the same key.

There are three ways to change a setting at runtime, and each has its own validation code:
1. WebUI → `UI_Request_Save_Settings` → `FunBotUIServer:_writeSettings` (batched DB write).
2. RCON `funbots.config.<Name> <value>` → `SettingsManager:UpdateSetting` (memory only).
3. Client console `config.set.<Name>` → `ConsoleCommands:SetConfig` → `SettingsManager:UpdateSetting` (memory only).

`UpdateFlag` on a setting triggers side effects after a change: weapon list rebuild, yaw-per-frame recalculation, spawn-amount rebalance, language reload, bot-name refresh, max-bots recalculation.

### Waypoint / trace format

`inputVar` packs per-node behaviour: bits 0–3 are the speed mode (0 wait, 1 prone, 2 crouch, 3 walk, 4 run), bits 4–7 the extra mode, bits 8–15 an optional value. The `data` JSON may contain:

- `Objectives: ["a","base us","vehicle tank1 ru", …]` on the first node of a path, naming the objectives that path serves
- `Links: [[pathIndex, pointIndex], …]` for junctions to other paths
- `LinkMode`, vehicle/action metadata

Path 0, point 0 is an info node (authors, compatibility index `COMP_MAP_TRACES`, date). Objective names are matched by substring in `GameDirector` (`base`, `spawn`, `beacon`, `vehicle`, `chopper`, `plane`, …), so naming conventions matter.

In git, traces live as `mapfiles/*.map` (semicolon-separated, header `pathIndex;pointIndex;transX;transY;transZ;inputVar;data`). The helper moves them between the files and `mod.db`.

---

## 5. Network events and permissions

The server trusts nothing from the client except the event name and arguments. Every server-side `NetEvents:Subscribe` handler that mutates state **must** call `PermissionManager:HasPermission(player, '<Permission>')` itself. Hiding the button in the UI or skipping client-side command registration does not count as a check.

Permission strings are hierarchical: granting `UserInterface.WaypointEditor.*` or `UserInterface.WaypointEditor` covers every child. Grant them via RCON:

```
funbots.Permissions <PlayerName> UserInterface.*        grant
funbots.Permissions <PlayerName> !UserInterface.Settings revoke one
funbots.Permissions <PlayerName> !                       revoke all
funbots.Permissions                                      list everyone
```

All valid names are in [Constants/Permissions.lua](../ext/Server/Constants/Permissions.lua).

---

## 6. WebUI ([WebUI](../WebUI))

Plain JS classes (no framework) bundled by Vite with `@vextjs/vite-plugin`, rendered in-game by Coherent GT.

- [index.html](../WebUI/index.html): all views (settings, bot editor toolbar, waypoint editor, comm-rose).
- [classes/BotEditor.js](../WebUI/classes/BotEditor.js): view logic, settings form serialization, `WebUI:Call('DispatchEventLocal', 'BotEditor', json)` to the client.
- [classes/EntryElement.js](../WebUI/classes/EntryElement.js): custom `<ui-entry>` widgets for each setting type.
- [languages/](../WebUI/languages): UI translations, separate from the Lua `Languages/`.

Build: `cd WebUI && npm install && npm run build`. This writes `ui.vuic` in the repo root directly: on Windows through `@vextjs/vite-plugin`, on Linux by running `vuicc.exe` through Wine (see [vite.config.js](../WebUI/vite.config.js)). `fun-bots-helper/CompileUI.bat` is a shortcut for the same build.

---

## 7. fun-bots-helper ([fun-bots-helper](../fun-bots-helper))

A Python GUI (`./fun-bots-helper.sh` or `fun-bots-helper.cmd`, Poetry project), run from the repo root. The important buttons:

| Tool | Effect |
|---|---|
| Export / Import traces | `mod.db` ↔ `mapfiles/*.map` |
| Export / Import permission & config | `mod.db` ↔ `permission_and_config/*.cfg` |
| Create settings | Regenerate `ext/Shared/Config.lua` from `SettingsDefinition.lua` |
| Create / update languages | Regenerate language templates; machine-translate via `deep_translator` |
| Create maplist / update supported maps | Regenerate `MapList.txt` and `Supported-maps.md` |
| Fix nodes / objectives / links, merge map files | Map-file maintenance |

Tests: `fun-bots-helper/tests` (pytest, `make test`).

There are no automated tests for the Lua code. [tools/check-lua.sh](../tools/check-lua.sh) runs `luacheck` (configured in [.luacheckrc](../.luacheckrc), also run in CI by `.github/workflows/lua-checks.yml`) and, if the VU type stubs exist in `.vua_data/`, `lua-language-server --check`. Run it before committing Lua changes.

---

## 8. Common tasks

**Add a setting**
1. Add an entry to `SettingsDefinition.Elements` (pick a `Type`, `Reference` (a `Range(min,max,step)` or an enum table), `Default`, `Category`, `UpdateFlag`).
2. Run the helper's *Create settings* to regenerate `Config.lua`.
3. Read it as `Config.<Name>`. If a change must take effect immediately, handle its `UpdateFlag` in `UIServer:_writeSettings` **and** `SettingsManager:UpdateSetting`.
4. Add UI translations if the text should be localized.

**Add a bot behaviour**
Put the logic in the relevant `Bot/*.lua` mixin and call it from the right tier of the right state in `BotStates/`. Use `UpdateSlow` for anything that does not need to run every 0.13 s.

**Add a NetEvent**
Subscribe in the owning manager, check permissions first in the handler, and nil-check `player.soldier` before using it.

**Add or fix a map trace**
In-game: F12 → Waypoint editor (needs `UserInterface.WaypointEditor.*`), then save. To commit it, export traces with the helper and commit the `.map` file. Regenerate `Supported-maps.md`.

**Debugging**
Set per-module levels in [Debug.lua](../ext/Shared/Debug.lua) and the switches in `Registry.DEBUG`. `g_Profiler:Start/End` markers are already in hot paths, commented out.

---

## 9. Conventions

See [.github/CODING_GUIDELINES.md](../.github/CODING_GUIDELINES.md). In short:
- Hungarian-style prefixes: `p_` parameter, `s_` local, `l_` loop variable, `m_` module-level/member, `_` private member, `g_` global singleton.
- EmmyLua annotations (`---@param`, `---@class`) for lua-language-server with VU type stubs.
- Tabs for indentation; Prettier for the WebUI.

---

## 10. Related docs

- [CHANGELOG](../.github/CHANGELOG.md), [CONTRIBUTING](../.github/CONTRIBUTING.md), [CODING_GUIDELINES](../.github/CODING_GUIDELINES.md)
- [REVIEW_FINDINGS.md](REVIEW_FINDINGS.md): open items and things still to test from the September 2026 code review
