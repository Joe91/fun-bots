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





# OLD: Will be removed soon:
Just type the wanted command in the chat.
## possible Commands:

### Static bot spawn:

For spawning bots in different Groupings. These bots don't move from their own

```html
!row <number> <opt: spacing>
!tower <number> <opt: spacing>
!grid <rows> <opt: collums> <opt: spacing>
```

    
### Static bot commands:

With these commands you can set the static bots to mimic or mirror your behavior.

```html
!mimic  --bots copy all your movement
!mirror --bots mirror you movement
!static --bots don't move at all
```

### Moving bot spawn:

With these commands you can spawn moving bots. To spawn bots on a way, you have to trace a path at first

```html
!spawnbots  <number>  -- default command. Spawns bots on valid paths
!spawnway <number> <opt: trace-index>
!spawnline <number> <opt: spacing>
```
    
### Moving bot settings:

Some settings for the moving bots.
If you use respawn, all Bots will respawn after they have been killed

```html
!run    --only for simple moving bots (line)
!walk   --only for simple moving bots (line)
!crouch --only for simple moving bots (line)
!prone  --only for simple moving bots (line)
!respawn <opt: 0>
!shoot <opt: 0>
```

### Path recording settings:

With these commands you can record a path that can be used by bots (spawn way)

```html
!trace/F5 <opt: index>
!tracedone/F6
!setpoint/F7 <opt: index>
!clearpoints/F8 <opt: index>
!savepaths/F12  -- CAUTION: Server does't react anymore on this command. Just wait till done
!clearalltraces/F9
!printtrans/F10
```

### More settings / commands:

Here are some more commands. Partly not tested jet

```html
!spawnsameteam <opt: 0>
!setbotkit <value: 0-4> -- 0 = random
!setbotColor <value: 0-14> -- 0 = random
!stop
!stopall
!kick <opt: number> --if no arg: 1
!kickteam <1 / 2>
!kickall
!kill
!killall
```
