# Available Commands:

All commands can be executed by several players. Just type the wanted command in the chat. Still work in progress.

## Static bot spawn:

For spawning bots in different Groupings. These bots don't move from their own

    !stand <opt:spacing>
    !crouch <opt:spacing>
    !row <number> <opt:spacing>
    !tower <number> <opt:spacing>
    !grid <rows> <opt:collums> <opt:spacing>
    !john

    
## Static bot commands:

With these commands you can set the static bots to mimic or mirror your behavior.

    !mimic
    !mirror
    !static


## Moving bot spawn:

With these commands you can spawn moving bots. To spawn bots on a way, you have to trace a path at first

    !spawncenter <number> <opt:duration>
    !spawnline <number> <opt:spacing>
    !spawnring <number> <opt:spacing>
    !spawnway <number> <opt:trace-index>
    
    
## Moving bot settings:

Some settings for the moving bots.
If you use respawn, all Bots will respawn directly after they have been killed

    !run
    !walk
    !speed <value: 0-4>
    !jump <opt:0>
    !adad <opt:0>
    !sway <opt:0/1> <opt:swayMaxDeviation> <opt:swayPeriod>
    !respawn <opt:0>


## Path recording settings:

With these commands you can record a path that can be used by bots (spawn way)

    !trace <opt:index>
    !tracedone
    !setpoint <opt:index>
    !clearpoints <opt:index>

## More settings / commands:

Here are some more commands. Partly not tested jet

    !spawnsameteam <opt:0>
    !nice
    !die <opt:0>
    !stop
    !stopall
    !kick
    !kickteam <1 / 2>
    !kickall
    !kill
    !killall
    !enter <opt:entryId>
    !fill <opt:number>
