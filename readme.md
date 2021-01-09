# fun-bots

Simple bots with some functions:
* Bots can walk around on paths and shoot at player (Khark and Noshar)
* You can spwan static bots (tower, line or grid)
* You can record you own paths
** while holding your primary weapon, all movement is recorded
** while holding your secondary weapon, bot will pause in this position


This mod is based on the Mod [BotSpawn](https://github.com/J4nssent/VU-Mods/tree/master/BotSpawn "Original Mod by Jassent") by [Jassent](https://github.com/J4nssent "Jassent").
It provieds lots of ways to play and mess with bots. Also with multible Players at once.

The following Maps are supported right now:
Noshar TDM, Khark TDM, Firestorm TDM.
Just type the wanted command in the chat. Still work in progress.
Feel free to contribute or improve ;-)
If you have any questions just ask them on Discord (Joe_91)


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
!mimic
!mirror
!static
```

### Moving bot spawn:

With these commands you can spawn moving bots. To spawn bots on a way, you have to trace a path at first

```html
!spawnbots  <number>  -- default command. Spawns bots on valid paths
!spawnline <number> <opt: spacing>
!spawnring <number> <opt: spacing>
!spawnway <number> <opt: trace-index>
!spawnrandway <number>
```
    
### Moving bot settings:

Some settings for the moving bots.
If you use respawn, all Bots will respawn directly after they have been killed

```html
!run
!walk
!speed <value: 0-4>
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
!kick
!kickteam <1 / 2>
!kickall
!kill
!killall
!enter <opt: entryId>
!fill <opt: number>
```
