[![Support Server](https://img.shields.io/discord/862736286774198322.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.com/invite/FKamccAEqz)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://www.paypal.me/joe91de)
![Image](https://img.shields.io/github/downloads/Joe91/fun-bots/total?style=for-the-badge)
![Image](https://img.shields.io/github/stars/Joe91/fun-bots?style=for-the-badge)

## Welcome to the changelogs for release **V3.6.0**
This is the changelog for release **V3.6.0**. Don't forget to [join us on Discord](https://discord.com/invite/FKamccAEqz)


## Changelog

### New features / improvements
* Kick bot out of Gunship by bot-command (#380)
* Some performance improvements
* World-Compensation for vehicle-guns
* Try to fix Auto-AA on Rush
* Add logic for jets in Rush
* Improved Air-Vehicle-Control (much smoother now)
* Much improved GC times
* Some Jet aim rework
* improved "lookaround"
* Optional server-side raycasts: bots also fight each other without any client ("!serverraycasts on")
* Debug-server (tools/debug-server): live map, analyzers, recordings and map-scans in the browser ("!debugbridge on")
* Debug-server: objectives on the map, console for RCON and chat commands (with suggestions)
* Debug-server: auto-labeler for paths (objectives, junctions, loops) from the capture points of the running game
* Rework of bot aiming: new settings "Bot Aim Error" (in milliradians), "Bot Aim Error of Snipers / Support" and "Bot Aim Error Spread" replace the old "Aim Worsening" settings (old values are not taken over, set them again if you changed them)
* More human aiming: smaller aim error on greater distances, less precise hip-fire on short distances
* New grenade behavior: bots throw grenades at the last known position of a target that went out of sight
* New movement and stuck logic: smoother path offset (one side per life, fades in and out), better obstacle detection, stuck bots reroute and get killed after a few tries
* Bots leave a stuck ground vehicle after 30 s and continue on foot
* Soldiers don't switch onto vehicle-only paths anymore
* Better hit detection for vehicles (see-through parts, low vehicles)
* Improved chopper aiming
* Improved PID controllers for vehicle control
* Aim evaluation to check the vehicle data ("!aimeval on|off|report|reset|verbose")
* Web UI: values can be typed directly into the settings, changed values are marked and can be restored to default
* Node editor: better performance and more info on selected nodes
* Adjusted default bot numbers (InitNumberOfBots and max bots per team for some modes)
* All server events now check the permissions of the player
* Performance statistics for debugging (Registry ROUND_STATS_INTERVAL)
* Lua checks (luacheck) in CI and a developer guide (docs/DEVELOPER_GUIDE.md)
* Better Linux support for development (WebUI build, helper script)


### Some optional TODOs:
* Fully support default spawn method? (for now only on TDM/GM/SDM by default)
* (Rework raycasts for better performance)
* (Improve node editor)

### Bug fixes
* Mobile artillery and light AA attack again (switch to the gunner seat)
* Seats without an aimable weapon don't fire anymore
* Errors with destroyed vehicles and beacons on round switch (#382)
* "Save temporarily" in the settings UI deleted all saved settings
* "config.saveall" and "config.restore" did each other's job
* Importing traces with the helper wiped settings and permissions
* A failed trace save destroyed the saved traces of the map
* Invalid default settings (weapons, language)
* Weapon and enum settings via RCON or console picked the wrong value, empty number fields broke the settings save
* Language and max-bots changes via RCON or console took no effect
* Values with a ' broke the database queries
* Chat commands fixed: !spawnway, !spawnbots, !setbotkit, !setbotcolor, !permissions, !stop, !stopall, !kickplayer, !kick 0; no crash if the caller is dead
* Anyone could change the vehicle aim offsets with !dbg
* The comm-rose "Defend objective" made bots attack
* No objectives assigned when team 1 had no active bots
* Defending bots hold their position again
* Scavenger and GunMaster crashed on beacon paths
* Stuck bots looped through the same reroute
* Rejoining the path after a fight picked the wrong node
* Team balancing moved dead bots and counted them as players
* Beacon and squad-mate spawns were overwritten and could teleport repeatedly
* A failed vehicle spawn disabled the bot permanently
* Path switching ignored better paths if the best one was filtered out
* Bots aimed with the part of the previous weapon after a weapon switch
* Choppers and jets of one team all flew to the same flag
* Passengers only saw one MCOM (Rush) or none (Squad Rush) when deciding to get out
* Vehicle bots kept attacking forever when shooting was disabled
* Bots following a player who left the server
* Invalid entries in the air targets
* Destroyed player objects on the client
* Possible bug with repairing vehicles
* Fixes for the VU runtime branch
* More robust angle normalization (by kruschk)
* Several more small bugs are fixed

### Updated maps
* XP4_FD_ConquestLarge (by ThyKingdomCome)
* MP_007_ConquestLarge, MP_001_ConquestLarge, XP3_Desert_ConquestLarge
* All maps: objectives, junctions and loops checked and completed with the new auto-labeler
