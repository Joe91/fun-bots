[![Support Server](https://img.shields.io/discord/862736286774198322.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.com/invite/FKamccAEqz)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://www.paypal.me/joe91de)
![Image](https://img.shields.io/github/downloads/Joe91/fun-bots/total?style=for-the-badge)
![Image](https://img.shields.io/github/stars/Joe91/fun-bots?style=for-the-badge)

## Welcome to the changelogs for release **V3.0**
This is the changelog for the version V3.0 Don't forget to [join us on Discord](https://discord.com/invite/FKamccAEqz)

## Changelog

### New features / improvements
* rework of complete update to state pattern
* performance-improvements
* original game-spawn-method by default (still a bit to do, till it works fine)
* add two missing weapons
* Info-Node in maps for future versioning and information
* pathless-jets
* pathless-choppers
* Bots can use the gunships (TODO: separate state with separate distace and tragets)
* Separate worsening values for different vehicle types (by MatiasPastori)
* Make bots attack the gunship by themselves (by ThyKingdomCome)
* Bots can use every jet in conquest now (no more paths needed)
* No more air-paths needed (only enter-paths for choppers)
* Kind of Support for AirSuperiority (jets still too passive)
* Bots randomly move or stop while shooting in vehicles (by MatiasPastori)
* Cooldown-time for rockets after refill
* Max Bot-Kits now per team
* Randomized spawn-order
* Better distance-handling for attack
* Registry-Option to still spawn bots on the last tickets added
* passengers now exit when close to objective in some vehicles (by ThyKingdomCome)
* Spawn of bots in AMTRAC and Transport-Choppters (by ThyKingdomCome)
* Option to disable KeepVehicleSeatForPlayer (by MatiasPastori)
* Registry-Option to USE_EXPERIMENTAL_NAMETAGS (by MatiasPastori)
* Bots don't use 3rd seat of Tanks anymore (by MatiasPastori)
* Support for dynamic-jet-spawn + fixes for some special cases (by MatiasPastori)
* Support of Gunship on Rush-Maps
* Variation in default fire-cycles (by MatiasPastori)
* Refactoring of lots of Bot-stuff (by Bree_Arnold)
* Switch to new Web-UI-Backend (by Paul)
* Sometimes Stop for shooting of bots (by MatiasPastori)
* performance of node-editor
* Don't exit vehicle, if player is driver
* Messed-up first spawn in TDM fixed

### some open TODOs:
* rework of raycasts for better performance
* fully support default-sapwn-method (for now only on TDM/GM/SDM by default)
* further performance increses
* chopper: handle different hights and positions depending on capture-points
* performance of spawn-point parsing -> save those?
* add logic for jets in rush
* improve team-logic for AA and other vehicles (example AA on Rush)
* improve node-editor
* Vehicle/Tank: better aiming on steep slopes (compensate car-rotation)
* unify soldier-nil-cheks in states and methods
* Delay-Spawn-Timer: have a look at the initial value, if this is done right...

### Bug fixes
* fix stationary AA again...
* fix horn-usage of jeeps #356
* fix refill of rockets
* fix keep same bot-players
* fix air-vehicles attacking bases (by ThyKingdomCome)
* fix Bots trying to spawn in unarmed Gunships (by MatiasPastori)

### New maps
* 

### Updated maps
* MP12_ConquestSmall0 by ThyKingdomCome (with explore-paths)
* MP17_ConquestLarge0 by ThyKingdomCome (with explore-paths)
* MP01_ConquestLarge0 by MatiasPastori (with explore-paths)
* XP1_003_ConquestAssaultLarge0 by MatiasPastori
* XP3_Desert_ConquestLarge0 by MatiasPastori
* MP01_ConquestLarge0 by MatiasPastori (with explore-paths)
* XP4 ConquestLarge0 by MatiasPastori

### Documentation update

