# fun-bots

Simple AI for TDM-bots with some functions:
- Bots can walk around on paths and shoot at player (Khark Island and Noshar as example paths provided)
- You can record you own paths
	- while holding your primary weapon, all movement is recorded
	- recording includes jumping, running, walking, couching, ...
	- while holding your secondary weapon, bot will pause in this position
- You can spwan static bots (tower, line or grid)


This mod is based on the Mod [BotSpawn](https://github.com/J4nssent/VU-Mods/tree/master/BotSpawn "Original Mod by Jassent") by [Jassent](https://github.com/J4nssent "Jassent").
It provieds lots of ways to play and mess with bots. Also with multible Players at once.

The following Maps are supported right now:
Noshar TDM, Khark-Island TDM, Firestorm TDM.
Just press **F12** for the ingame menu!
The default-Password is __BotAdmin__.
Many Settings can be changed ingame. For some more changes have a look at __shared/config.lua__.
Feel free to contribute or improve ;-)
If you have any questions or problems just ask them on Discord (Joe_91#5467) or create an issue

## NEW: Possible Options for the UI
Just press **F12** to open the Menu

### Bot Menu
- SpawnBots
	- same Team or not? --> Config.spawnInSameTeam
	- Amount of Bots
- killall
- kickall
- kickTeam (1 / 2)
- kickNumber (with Number)
- respawn (0/1)
- shoot (0/1)

### Waypoint Menu
- Start Trace (either 0 or fixed index)
- End Trace
- Clear Trace (with Index)
- Clear all traces
- Save traces
- (spawnBotsOnWay (with Index)) optional. we can optionaly add this later

### Settings Menu
- spawnInSameTeam
- respawnWayBots
- bulletDamageBot
- bulletDamageBotSniper
- meleeDamageBot
- meleeAttackIfClose
- shootBackIfHit
- botAimWorsening  -- for difficulty: 0 = no offset (hard), 1 or greater = more sway (easy). Restart of round neededs
- botKit -- 0 = random, 1 = assault, 2 = engineer, 3 = support, 4 = recon
- botColor -- 0 = random, see Colors

### :grey_exclamation: Commands
A full list of available commands can be found here: [/wiki/Commands](https://github.com/Joe91/fun-bots/wiki/Commands)
