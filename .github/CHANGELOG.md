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
  stuck (other ways, shooting through penetrable walls, getting back onto the mesh). They take other ways around spots
  where their team was just killed, and step aside for teammates in narrow places
* **Spawning:** bots use the spawn points of the game on Conquest and Rush, spawn next to free vehicles and in transport
  helicopters and AMTRACs (passengers jump out at the objective)
* **Rush:** MCOMs are found and armed/disarmed without recorded paths, defenders hold their MCOMs and hurry to armed
  ones to disarm them, bots wait at the border of the combat area
* **Domination:** supported on all four XP2 maps (with a navigation mesh); Team Deathmatch, Squad Deathmatch and Gun
  Master use it there as well
* **Vehicles:** vehicles and their teams are found automatically, smoother air-vehicle control and aiming (choppers,
  jets, PID controllers, world compensation for vehicle guns), bots leave stuck or flipped vehicles. Jets no longer
  hang nose-up at the ceiling of the level and score kills in Air Superiority
* **Aiming and combat:** reworked, more human aim error (new settings "Bot Aim Error", "... of Snipers / Support",
  "... Spread"; old "Aim Worsening" values are not taken over), grenades at the last known position of a target,
  improved look-around, better hit detection on vehicles
* **Optional server-side raycasts:** bots fight each other without any client ("!serverraycasts on")
* **Debug-server** (tools/debug-server): live map, recordings and analyzers in the browser, RCON/chat console, and a
  *Maps* tab that makes the mesh of a level and cuts its paths (see tools/debug-server/NEW_MAP.md); every step keeps a
  backup of what it overwrites. A bot can record the missing way from a cut-off spawn. The census measures only floors
  (up to 12 per spot) and can rescan the floors of a level without breaking its mesh
* **Levels recorded by bots:** `census connect` records all paths of a layout by itself (bots walk the ways between
  the objectives and spawns, rush stage by stage; where they are too far apart, a path of another layout of the
  level), `census roads` makes vehicle paths from the roads of the other
  layouts of a level and lets bots drive them with the vehicles of each team, `census trace` records vehicle paths
* **Performance:** much less garbage collection, faster route and mesh searches
* Web UI: values can be typed directly, changed values are marked and can be reset
* Node editor: better performance, shows the mesh, more info on selected nodes
* All server events check the permissions of the player
* Development: luacheck in CI, developer guide (docs/DEVELOPER_GUIDE.md), better Linux support

### Bug fixes
* Settings: "Save temporarily", "config.saveall"/"config.restore", RCON/console values, invalid defaults and quotes in
  values fixed; importing traces no longer wipes settings, permissions or saved traces; a failed save no longer loses
  all settings
* Chat commands fixed (!spawnway, !spawnbots, !setbotkit, !setbotcolor, !permissions, !stop, !stopall, !kickplayer,
  !kick), !dbg needs permission
* Vehicles: mobile artillery and light AA attack again, no firing from seats without weapon, failed vehicle spawns no
  longer disable a bot, choppers and jets don't all fly to the same flag
* Objectives: "Defend objective" of the comm-rose, defending bots hold their position, objectives with an empty team 1
* Spawning and team balance: dead bots no longer moved or counted, beacon/squad spawns no longer overwritten
* Errors with destroyed vehicles, beacons and players on round switch, crashes on Scavenger and GunMaster
* Bots kept the Gun Master weapons in the next level (no kills in Squad Deathmatch after Gun Master)
* Choppers crashing during an attack
* Bots out of a boat in the water no longer walk to a point of the mesh far away (MP_017)
* Conquest, Domination, Air and Tank Superiority: the deaths of bots cost tickets (the game only counted players); Rush:
  bots the mod respawns (stuck, stranded on a ship) cost no ticket
* No spawn on a squad mate in a fight (squad rush: 2 % of the spawns next to an enemy instead of 20-30 %)
* Medics revive bots again (since 2024 only right after their own spawn: 1 % of the deaths, now 11-21 %); in a fight
  only a mate down close by
* MP_017 Rush: the attackers on the ship get to the boats and the AMTRAC again and ride along in its passenger seats
  (40 % fewer bots stuck on the ship)
* Levels without a navigation mesh (community mapfiles): bots spawn at the spawns of the game and follow the objectives
  on the paths again (MCOMs are armed)
* Capture the Flag: bots spawn on the paths and walk them again (they spawned far from them: 4 % of the time stuck)
* Deathmatch modes: a bot that spawns far from the paths starts on the closest one (XP3_Alborz Team Deathmatch: bots
  stood at walls for minutes, 6.5 % of the time stuck, now 0.2 %)
* Vehicles no longer turn into a path that only leads back (the way out from a vehicle spawn)
* Many more small fixes

### Updated maps
* New: Squad Rush on MP_012, MP_013, MP_018, XP1_001, XP1_002, XP1_003, XP1_004, XP3_Alborz, XP4_FD, XP4_Parl,
  XP5_001 and XP5_003 (paths recorded by bots; MP_013: the jump from the summit taken over from rush), XP3_Alborz
  Tank Superiority (routes from the conquest roads, driven by bots)
* XP5_002 Conquest Large: vehicles no longer drive into the depot at D and get stuck there (paths driven by bots)
* All Conquest and Rush maps: navigation mesh at the objectives and spawns, paths cut at it
* New paths on MP_013 Rush; XP4_FD_ConquestLarge (by ThyKingdomCome), MP_007_ConquestLarge, MP_001_ConquestLarge,
  XP3_Desert_ConquestLarge
* Domination: navigation meshes for XP2_Office, XP2_Palace, XP2_Skybar and XP2_Factory
* Junctions re-checked on all maps; recorded ways from cut-off spawns on 11 maps; MP_017 Rush fixed
* All maps: meshes rescanned from the floors only, stairs and buildings with several storeys are covered now; MP_Subway
  Rush no longer leads through a wall north of MCOM 4
* All maps: meshes cut again, the corners of the mesh keep away from the ends of walls and barriers (MP_Subway
  Conquest: 60-90 bots a round ran into a barrier near B and C, now about 6) and the check finds walls through a
  corner
* MP_001 Squad Rush: the attackers get out of their first spawn again (they stayed there and no MCOM fell); XP2_Office:
  two spots of the mesh where 60-80 bots a round got stuck are left out
