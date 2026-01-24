[![Support Server](https://img.shields.io/discord/862736286774198322.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.com/invite/FKamccAEqz)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://www.paypal.me/joe91de)
![Image](https://img.shields.io/github/downloads/Joe91/fun-bots/total?style=for-the-badge)
![Image](https://img.shields.io/github/stars/Joe91/fun-bots?style=for-the-badge)

## Welcome to the changelogs for release **V3.0**
This is the changelog for release **V3.0**. Don't forget to [join us on Discord](https://discord.com/invite/FKamccAEqz)


## Changelog

### New features / improvements
* Rework of the complete update to state pattern
* Performance improvements
* Use the original game spawn method by default (still a bit to do until it works fine)
* Add two missing weapons
* Info node in maps for future versioning and information
* Pathless jets
* Pathless choppers
* Bots can use the gunships (TODO: separate state with separate distance and targets)
* Separate worsening values for different vehicle types (by MatiasPastori)
* Make bots attack the gunship by themselves (by ThyKingdomCome)
* Bots can use every jet in Conquest now (no more paths needed)
* No more air paths needed (only enter paths for choppers)
* Kind of support for Air Superiority (jets still too passive)
* Bots randomly move or stop while shooting in vehicles (by MatiasPastori)
* Cooldown time for rockets after refill
* Max bot kits per team
* Randomized spawn order
* Better distance handling for attack
* Registry option to still spawn bots on the last tickets added
* Passengers now exit when close to objective in some vehicles (by ThyKingdomCome)
* Spawn of bots in AMTRAC and transport choppers (by ThyKingdomCome)
* Option to disable KeepVehicleSeatForPlayer (by MatiasPastori)
* Registry option to USE_EXPERIMENTAL_NAMETAGS (by MatiasPastori)
* Bots don't use the 3rd seat of tanks anymore (by MatiasPastori)
* Support for dynamic jet spawn + fixes for some special cases (by MatiasPastori)
* Support of gunship on Rush maps
* Variation in default fire cycles (by MatiasPastori)
* Refactoring of lots of Bot-Stuff (by Bree_Arnold)
* Switch to the new Web UI backend (by Paul)
* Sometimes stop for shooting of bots (by MatiasPastori)
* Improved performance of the node editor
* Don't exit vehicle if player is driver
* Attempt to fix messed-up first spawn in TDM (only a workaround right now)
* Bots now can use a path offset sideways (by MatiasPastori)
* Added the command to make the bots follow a player (by MatiasPastori)
* Default color for appearance added (thanks to QuantumTube)
* Bot movement and obstacle handling rework
* Fix of mcom handling of the bots
* Fix of some path switching issues in context with actions
* improvement in FOV-logic (by kruschk)

### Some open TODOs:
* Vehicle/Tank: better aiming on steep slopes (compensate car rotation)
* Chopper: handle different heights and positions depending on capture points
* Add logic for jets in Rush
* Improve team logic for AA and other vehicles (example: AA on Rush)
* Fully support default spawn method? (for now only on TDM/GM/SDM by default)
* (Rework raycasts for better performance)
* (Improve node editor)

### Bug fixes
* Fix stationary AA again...
* Fix horn usage of jeeps #356
* Fix refill of rockets
* Fix keep same bot players
* Fix air vehicles attacking bases (by ThyKingdomCome)
* Fix bots trying to spawn in unarmed gunships (by MatiasPastori)
* Fixed static-bot-modes

### Updated maps
* MP12_ConquestSmall0 by ThyKingdomCome (with explore paths)
* MP17_ConquestLarge0 by ThyKingdomCome (with explore paths)
* MP01_ConquestLarge0 by MatiasPastori (with explore paths)
* XP1_003_ConquestAssaultLarge0 by MatiasPastori
* XP3_Desert_ConquestLarge0 by MatiasPastori
* MP01_ConquestLarge0 by MatiasPastori (with explore paths)
* XP4_ConquestLarge0 by MatiasPastori
