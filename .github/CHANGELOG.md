[![Support Server](https://img.shields.io/discord/862736286774198322.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.com/invite/FKamccAEqz)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://www.paypal.me/joe91de)
![Image](https://img.shields.io/github/downloads/Joe91/fun-bots/total?style=for-the-badge)
![Image](https://img.shields.io/github/stars/Joe91/fun-bots?style=for-the-badge)

## Welcome to the changelogs for release **V3.6.0**
This is the changelog for release **V3.6.0**. Don't forget to [join us on Discord](https://discord.com/invite/FKamccAEqz)


## Changelog

### New features / improvements
* **New navigation:** on Conquest and Rush the bots walk a navigation mesh at the objectives and spawns and use the
  paths only between them. Routes are found over both, bots spread over different ways and learn spots where they get
  stuck (other ways, shooting through penetrable walls, getting back onto the mesh)
* **Spawning:** bots use the spawn points of the game on Conquest and Rush, spawn next to free vehicles and in transport
  helicopters and AMTRACs (passengers jump out at the objective)
* **Rush:** MCOMs are found and armed/disarmed without recorded paths, defenders hold their MCOMs, bots wait at the
  border of the combat area
* **Vehicles:** vehicles and their teams are found automatically, smoother air-vehicle control and aiming (choppers,
  jets, PID controllers, world compensation for vehicle guns), bots leave stuck or flipped vehicles
* **Aiming and combat:** reworked, more human aim error (new settings "Bot Aim Error", "... of Snipers / Support",
  "... Spread"; old "Aim Worsening" values are not taken over), grenades at the last known position of a target,
  improved look-around, better hit detection on vehicles
* **Optional server-side raycasts:** bots fight each other without any client ("!serverraycasts on")
* **Debug-server** (tools/debug-server): live map, recordings and analyzers in the browser, RCON/chat console, and a
  *Maps* tab that makes the mesh of a level and cuts its paths (see tools/debug-server/NEW_MAP.md); every step keeps a
  backup of what it overwrites
* **Performance:** much less garbage collection, faster route and mesh searches
* Web UI: values can be typed directly, changed values are marked and can be reset
* Node editor: better performance, shows the mesh, more info on selected nodes
* All server events check the permissions of the player
* Development: luacheck in CI, developer guide (docs/DEVELOPER_GUIDE.md), better Linux support

### Bug fixes
* Settings: "Save temporarily", "config.saveall"/"config.restore", RCON/console values, invalid defaults and quotes in
  values fixed; importing traces no longer wipes settings, permissions or saved traces
* Chat commands fixed (!spawnway, !spawnbots, !setbotkit, !setbotcolor, !permissions, !stop, !stopall, !kickplayer,
  !kick), !dbg needs permission
* Vehicles: mobile artillery and light AA attack again, no firing from seats without weapon, failed vehicle spawns no
  longer disable a bot, choppers and jets don't all fly to the same flag
* Objectives: "Defend objective" of the comm-rose, defending bots hold their position, objectives with an empty team 1
* Spawning and team balance: dead bots no longer moved or counted, beacon/squad spawns no longer overwritten
* Errors with destroyed vehicles, beacons and players on round switch, crashes on Scavenger and GunMaster
* Many more small fixes

### Updated maps
* All Conquest and Rush maps: navigation mesh at the objectives and spawns, paths cut at it
* New paths on MP_013 Rush; XP4_FD_ConquestLarge (by ThyKingdomCome), MP_007_ConquestLarge, MP_001_ConquestLarge,
  XP3_Desert_ConquestLarge
