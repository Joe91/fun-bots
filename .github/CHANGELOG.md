[![Support Server](https://img.shields.io/discord/862736286774198322.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.gg/K44VsQsKnx)
[![Support me on Patreon](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.vercel.app%2Fapi%3Fusername%3Dfunbots%26type%3Dpatrons&style=for-the-badge)](https://patreon.com/funbots)
![Image](https://img.shields.io/github/downloads/Joe91/fun-bots/total?style=for-the-badge)
![Image](https://img.shields.io/github/stars/Joe91/fun-bots?style=for-the-badge)

## Welcome to the changelogs for release **V2.3.0**
This is the changelog for the released V2.3.0 version. Don't forget to [join us on Discord](https://discord.funbots.dev)

## Changelog
This release contains a lot of small bug fixes and more QoL updates. This Release supports all kind of vehicles

### New features
* Sidewared movement of bots (looking sidewareds while moving)
* SMAWs don't move when shooting anymore
* Rework Enter-Vehicle-System (preparation to let more bots enter one vehicle)
* Regestry for some inner Values added
* Added Exit-Command for vehicles (#169)
* Added Core of Auto-AA - Mod (by NyScorpy) to make bots use the stationary AA 
	* !!THANKS A LOT TO NyScorpy FOR LETTING ME USE HIS CODE!!!
* Option to let bots spawn directly into some vehicles with the Objective: "vehicle spawn us ..."
* Support for Bots flying Choppers
* Support for Bots flying Jets
* Export / Import system for easy shareing of paths
* Added more vehicles to the supported list
* bots wait for more passengers
* Selection of Nodes improved (under ground and above ground)
* Improved Code of Bot.lua to separate different Functions and for future functions
* Improved Nade calculations (still far from perfect)
* land-vehicles teleport if stuck
* Added Language-System again! You can now create your own translation
	* fill out the file ext\Shared\Languages\DEFAULT.lua
	* fill out the file WebUI\languages\DEFAULT.js 
	* send those files to me and we will add your language to fun-bots

### Bug fixes
* fixed bug with jeeps
* more failsave system for Rush-Mcoms
* fixed some bugs with the knife
* fixed path bug with destroyed mcoms
* New settings for vehicle-usage
* Added FOV-Settings for Vehicles
* fixed Garbage-Collection on Server
* fixed some vehicle-categories
* fixed bug in path-switching
* fixed a bug in target-objective-finding
* fixed some wrong objective-names on existing maps

### New maps
* Theran Highway CQS (Vehicles) - thanks to Gemini899
* Seine Crossing CQS (Vehicles) - thanks to Gemini899
* Nebandan Flats CQS (Vehicles) - thanks to KrazyIvan777
* Armored Shield CQS (Vehicles) - thanks to KrazyIvan777
* Bandar Desert CQS (Vehicles) - thanks to KrazyIvan777
* Alborz Mountains CQS (Vehicles) - thanks to KrazyIvan777
* Markaz Monolith CQS (Vehicles) - thanks to KrazyIvan777 and to MeisterPeitsche
* Grand Bazaar CQS (with Vehicles) - thanks to MeisterPeitsche
* Seine Crossing CQS (with Vehicles) - thanks to MeisterPeitsche
* Teheran Highway CQS (with Vehicles) - thanks to MeisterPeitsche
* Caspian Border CQS (with Vehicles) - thanks to MeisterPeitsche
* Operation Firestorm CQS (with Vehicles) - thanks to MeisterPeitsche
* Damavand Peak CQS (with Vehicles) - thanks to MeisterPeitsche
* Operation Firestorm CQS (Jets) - thanks to KrazyIvan777
* Gulf of Oman CQS (Jets) - thanks to KrazyIvan777
* Noshahr Canals CQS update - thanks to KrazyIvan777 and MeisterPeitsche
* Wake Island Assaullt Small (1+2) (infantery) - thanks to DuTcHrEaGaN
* Wake Island Assault Large (infantery) - thanks to DuTcHrEaGaN
* Wake Island Assault Large (Vehicles) - thanks to KrazyIvan777
* Death Valley CQS (Vehicles) - thanks to KrazyIvan777
* Riverside CQS (Vehicles) - thanks to KrazyIvan777
* Sharqi Peninsula Assault Day2 (infantery) - thanks to DuTcHrEaGaN

### Documentation update
* nothing done on this front :-(