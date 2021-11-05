First off, thanks for taking the time to contribute!

## 1.0 Coding conventions

### 1.1.0 Lua

#### Structure:

  The main structure of LUA consist of global singletons for each logic file with exception of some UI files. Classes are done with MiddleClass.
  Game events, WebUI events and `NetEvents` with the `RealityMod` prefix are processed in `__init__` files
  in client, server and shared. These files reroute these events to the different classes or intermediary
  classes like `LogicCommon`.

#### Code convention:

  * Tabs are use for indexing. Don't use spaces.
  * Don't use semicolons (`;`)
  * Put a space after commas `,`
  * Put spaces around binary operators (`a + b`)
  * Put spaces between control flow keywords (`if`, `when`, `for` and `while` for sample) and the corresponding opening parenthesis

#### Naming:

  Logic files that require client and server work are named with the `Client`
  or `Server` prefix, and can register and subscribe to NetEvents that are only used to communicate between
  them. These events names should contain the name of the class (without Client or Server prefix) followed by the
  name of the event and separated by a colon (i.e. `SpawnPointManager:CreateSpawnPoint`).

  Variables are named as UpperCamelCase, prefixed by `s_` for local variables, `m_` for member variables, `l_` for loop variables,
  `g_` for globals and `p_` for parameters. Functions are also UpperCamelCase without any prefix except for "private" functions, for which we use the prefix `_`. Lua middleclass doesn't have private functions, so it's just a style convention to mark functions that we don't want to be called outside its class.

#### Console output:

  As there is no debugger, we heavily rely on prints. For that we use the class Logger, which shows which class
  printed the message, as well as adds ability to disable prints per class or disabling all prints in production.
  Each class instantiates its own Logger object with its class name and an enabled flag. For testing, you can set that flag
  to true, but remember to disable it before pushing it.
  Never use the default `print` function.

  Logger has `Write`, `WriteTable`, `Error` and `Warning` methods.

#### DataContainers:

  DataContainers (DCs) and frostbite entities can be the cause of problems. That's why you should avoid keeping their
  references. If you need to, you have to clear all references either when you are done with them or when the
  mod unloads. For the latter, reroute the `__init__` function called `OnResetData`. More on this below.

  For DCs modifications use the helper functions in DataContainerExt class. They cast instances for you and check
  for potential errors. It also has debugging functions that can be helpful.

#### Player objects:

  VEXT player objects can also cause problems when keeping their references. To avoid that, save the player id or name,
  and look for the player object with `PlayerManager:GetPlayerById()` or `PlayerManager:GetPlayerByName()` when
  needed. If you
  are using ids as an index you should keep in mind that these ids aren't unique, so when a player disconnects the id
  gets reassigned to the next player that joins. You should subscribe to the player deleted or destroyed events and
  clear the necessary data.

#### Communication with UI:

  In RM, between WebUI and the logic we have a "presenter" layer. Files located in `ext/Client/UI` manage UI updates
  and follow a similar structure as WebUI one, where there are different views that hold different elements.
  By default you dont need to touch the client-sides LUA file, because the data will only forwarded to the WebUI. Here, all forwards will be handled by JavaScript.
  Logic classes have callbacks that the UI classes can register to, and call WebUI with the necessary info. This JS
  calls are throttled by a class, WebUpdater, preventing spams and derived performance issues.

#### Resetting of variables and DCs

  When working on LUA always keep in mind that after a round end everything has to be properly reset. For this we have
  the function `OnResetData`, which you should use to reset the variables that need to be defaulted or cleared and
  all references to DataContainers or Frostbite entities. To avoid repetition, we use `ResetVars`
  function in each class that sets the default value for resettable variables. This function should be called both in
  `OnResetData` and `RegisterVars` functions. Variables that don't need resetting are declared in `RegisterVars`.
  The structure would look like this:

  ```lua
  Class:__init()
      self:RegisterVars()
      self:RegisterEvents()
      self:RegisterHooks()
  end

  Class:RegisterVars()
      self.m_NonResetVar = nil
      self.m_NonResetTable = { }
      self:ResetVars()
  end

  Class:OnResetData()
      self:ResetVars()
  end

  Class:ResetVars()
      self.m_ResetVar = nil
      self.m_ResetTable = { }
      self.m_DataContainerRef = nil

      if self.m_EntityRef then
          self.m_EntityRef:Destroy()
          self.m_EntityRef = nil
      end
  end
  ```

### 1.1.1 WebUI

TODO

## 1.2 Productivity

Debugging and testing can become time consuming, specially with LUA. There are some ways to reduce wasted time like
loading times or finding the root of a problem.

First of all, having BF3 installed on an SSD is a must. Loading times will decrease greatly. High tickrate will
improve your loading times as well, and you should work on maps that are faster to load. DLC maps are faster than
vanilla, and if you are not running RM Ziba Tower map is one of the fastest, if not the fastest. You can
add your server id with the VU shortcut `vu://join/<server-id>` (replace `<server-id>` with the guid printed on the server console),
so your client will autoconnect to your server as soon as you log in.

Secondly, get yourself an RCON client like Procon. It's a server management tool that lets you, along other things,
change server settings easily. VU adds some extra options, like a mod reload command (`modList.reloadExtensions`).
This command is really useful, it allows hot reloading (reloading the mod on the fly). But keep in mind that hot
reloading means that everything is reinstantiated. If your changes rely on patching something when it loads or
something that requires a reload you should follow the command with a round restart (there's a button for that).
Hot reloading is not necessary if you updated `ui.vuic` file, but the client needs to reconnect in order to download
the new UI file, when you dont update the client file on the location `%localappdata%\VeniceUnleashed\mods\fun-bots\ui.vuic`.
The best solution is, to use our UI compiler-script located at `Binary/CompileUI.bat` - Here the client file will always
refreshed and the client dont needs any reconnects.
As stated previously, you should remove references to DCs, otherwise hot reloading will crash your client or server.

When working with DCs or a system that doesn't need RM functionalities, it's usually better to create a separate test
mod, as RM takes longer to load and doesn't support fast loading maps like Ziba Tower.

There is no IntelliSense for VEXT, but some linting helps. A good IDE is IntelliJ IDEA with the EmmyLua plugin.
We have keys for it, ask [Project Management](#project-management) for one if you are interested.
