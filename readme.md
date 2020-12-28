# fun-bots

Simple ways to play around with mods in venice-unleashed.
This mod is based on the Mod [BotSpawn](https://github.com/J4nssent/VU-Mods/tree/master/BotSpawn "Original Mod by Jassent") by [Jassent](https://github.com/J4nssent "Jassent").
It provieds lots of ways to play and mess with bots. Also with multible Players at once.

Just type the wanted command in the chat. Still work in progress.


## possible Commands:

### Static bot spawn:

For spawning bots in different Groupings. These bots don't move from their own

```html
!stand <opt: spacing>
!crouch <opt: spacing>
!row <number> <opt: spacing>
!tower <number> <opt: spacing>
!grid <rows> <opt: collums> <opt: spacing>
!john
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
!spawnbots  <number>  -- default command. Spawns bots on valid path
!spawncenter <number> <opt: duration>
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
!jump <opt: 0>
!adad <opt: 0>
!sway <opt: 0/1> <opt: swayMaxDeviation> <opt: swayPeriod>
!respawn <opt: 0>
```

### Path recording settings:

With these commands you can record a path that can be used by bots (spawn way)

```html
!trace <opt: index>
!tracedone
!setpoint <opt: index>
!clearpoints <opt: index>
!savepaths  -- CAUTION: Server does't react anymore on this command. Just wait till done
!clearalltraces
!printtrans
```

### More settings / commands:

Here are some more commands. Partly not tested jet

```html
!spawnsameteam <opt: 0>
!setbotkit <value: 1-4>
!nice
!die <opt: 0>
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
