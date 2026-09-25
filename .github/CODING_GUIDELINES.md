First off, thanks for taking the time to contribute!

For an overview of the codebase, see the [Developer Guide](../docs/DEVELOPER_GUIDE.md).

## 1. Lua

### Structure

Each logic file defines a class with VU's `class('Name')` and creates one global singleton (`g_Name`), which the file returns, so every `require` gets the same instance. Engine events, hooks and NetEvents are subscribed in `ext/<Realm>/__init__.lua` or in the owning manager, and forwarded to the classes that handle them.

### Code style

* Use tabs for indentation, not spaces.
* Don't use semicolons (`;`).
* Put a space after commas (`a, b`) and around binary operators (`a + b`).
* Annotate functions with EmmyLua (`---@param`, `---@return`, `---@class`) so lua-language-server can check them.
* Run [tools/check-lua.sh](../tools/check-lua.sh) before committing. CI runs luacheck on every push and pull request.

### Naming

Variables and functions are UpperCamelCase with a prefix:

| Prefix | Use |
|---|---|
| `p_` | parameter |
| `s_` | local variable |
| `l_` | loop variable |
| `m_` | module-level local or member variable |
| `g_` | global singleton |
| `_` | "private" function or member (convention only; Lua has no private members) |

NetEvent names are `<Class>:<Event>`, for example `NodeEditor:SetLoopMode`. Client-side files that pair with a server file are prefixed with `Client` (for example `ClientNodeEditor`).

### NetEvents and permissions

The server must not trust the client. Every server NetEvent that changes state checks permissions itself. Register it through `PermissionManager:SubscribeNetEvent(name, permission, context, handler)`, which checks the permission before calling the handler. Hiding a button in the UI is not a permission check.

### Logging

Use the `Logger` class instead of `print`:

```lua
local m_Logger = Logger("BotManager", Debug.Server.BOT)
m_Logger:Write("message")
```

It prefixes the class name and can be switched on or off per module in [Debug.lua](../ext/Shared/Debug.lua). Methods: `Write`, `WriteTable`, `Warning`, `Error`. Leave debug logging off when you push.

### Engine objects and player references

Don't keep references to DataContainers, entities or `Player` objects longer than needed. They can crash the server or client after a level change or hot reload. Store the player's id or name and look the player up with `PlayerManager:GetPlayerById()` / `GetPlayerByName()` when needed. Player ids are reused after a disconnect, so clear per-player data on `Player:Left`.

Always nil-check `player.soldier` before using it: the player may be dead.

### Resetting state

Everything that belongs to a level has to be cleared when the level ends. `ext/Server/__init__.lua` forwards `Level:Destroy` to the managers, and each manager's `OnLevelDestroy` clears its per-level tables and engine references. Add new per-level state to that reset.

## 2. WebUI

Plain JavaScript, formatted with Prettier. Build with `cd WebUI && npm install && npm run build`, which writes `ui.vuic`.

## 3. Productivity

* Put BF3 on an SSD, and test on small maps.
* Use an RCON client (for example Procon). `modList.reloadExtensions` hot-reloads the mod. Follow it with a round restart if your change patches data when a level loads. Stale DataContainer references crash on hot reload (see above).
* After a WebUI change, the client has to reconnect to download the new `ui.vuic`, unless you also copy it to `%localappdata%\VeniceUnleashed\mods\fun-bots\ui.vuic`.
* Add your server to the VU shortcut `vu://join/<server-id>` (the GUID printed on the server console) to connect automatically.
* For editor support, use VS Code with the Lua extension (sumneko) and the VU Lua extension (`Imposter.vscode-lua-vu`), which generates the VU type stubs into `.vua_data/`.
