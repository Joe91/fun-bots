# Code Review Findings (September 2026, branch `dev`)

Open items from a static review of `ext/`, `WebUI/` and `fun-bots-helper/`. Fixed items have been removed; their write-ups are in the git history of this file.

---

## Open

**Test in-game: chopper bank direction.** The fix for choppers banking the same way on every turn was made from source only and still needs checking in a live game.

**I3. Table-driven command dispatch.** `Chat.lua` and `UIServer:_onBotEditorEvent` are long `if/elseif` chains. A table of `{permission, handler}` per command is shorter and makes a missing permission check obvious. Move debug-only commands (`!car`, `!caryaw`, `!cardiff`, `!weap`, `!dbg`, `!perks`, `!objectives`) behind `Registry.DEBUG`.

**I4. Safer persistence (remaining).**
- Use a transaction for settings batches. Trace saves already use one.
- Key permissions by account GUID instead of player name. The GUID is already stored but not used for lookups.

**I6. Escape data passed into `WebUI:ExecuteJS`.** [UIClient.lua](../ext/Client/UIClient.lua) wraps JSON in `'…'`, so a `'` in any translated label or setting string breaks the UI. The French file drops apostrophes (`"Objectif d attaque"`) to work around this. Escaping `'` and `\` in the Lua helper removes the constraint.

**I7. Don't broadcast full node lists.** `NodeEditor:OnRequestData` sends *all* waypoints to *all* active editor players whenever anyone requests them ([NodeEditor.lua](../ext/Server/NodeEditor.lua)). Send them only to the requester.

**I8. Store WebUI booleans in `data-value`.** `EntryElement` renders the literal `"Yes"` / `"No"`, and `BotEditor` reads the value back by comparing `innerHTML == "Yes"` ([BotEditor.js](../WebUI/classes/BotEditor.js)). This breaks as soon as the words are translated.

**Stricter luacheck.** Enable the unused-variable and shadowing warnings in `.luacheckrc` once the existing ones are cleaned up.

