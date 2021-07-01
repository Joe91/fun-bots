# What is a trace?
Basically a trace is what allows the bot to walk around.

There are currently two types of traces
- [Infantry paths](#creating-an-infantry-path), paths which the bots will follow on foot.
- [Vehicle paths](#creating-a-land-vehicle-path), paths which the bots will follow when in any vehicle (excluding planes)

# Creating a trace
In order to create a trace, you need to have a server running fun-bots (preferably the latest version, [available here](https://github.com/Joe91/fun-bots/tags)). You also need to have the [permissions](https://github.com/Joe91/fun-bots/wiki/Permissions) to create a path.

You can open the fun-bots settings menu using `F12` and clicking the `WAYPOINT-EDITOR` button. [Example](https://github.com/Joe91/fun-bots/blob/master/Screenshots/Menu/Full.png)

You are greeted by a lot of [buttons and options](https://github.com/Firjens/fun-bots/blob/master/Screenshots/Menu/Traces/FullTraceMenuExample.png).

#### Sharing your new traces with the community
When you have created a new share or updated an existing path, and it's of good quality, you can share it with the rest of the community and add it to traces database included in fun-bots. Please see [TBA](/#) on how to share it.

## Creating an infantry path

### Infantry paths for any Conquest or Assault gamemode
- Paths should run around the flag

### Infantry path for Rush
For Rush things get a little more complex.
First the easy ones:
- you need a base path for every defender-base (attacker-bases are the defender base from one index before, if no own base is defined)
- you need paths around each mcom (not directly at, but around)
- you need very short paths directly on the mcomcs
- you need paths from every attacker-base to the mcoms
- you need paths connecting the mcomcs of the current stage
- you need paths from the mcoms to the next mcoms (after they are destroyed)


## Creating a land-vehicle path
TBA

# Notes
The shorther the links are, the easier they are to understand and maintain.

## Known bugs and issues
This list contains all bugs and issues related to traces.

No current confirmed issues related to traces are reported.

# FAQ
Some frequent asked questions here

#### Q: I don't understand something, what should I do?
You should ask the contributors, maintainers and developers before you are wasting too much time on something that does not work.

#### Q: Black points are still visible after removing a waypoint. [Example](https://media.discordapp.net/attachments/860159569107615764/860167425962147870/unknown.png)
This is intended behavior. The black dots are orphaned nodes and get cleaned out on a save/load cycle. They are left in place so that they can still be interacted with in case of accidental removal.<sup>[1]</sup>

#### Q: I can't erase a waypoint
You cannot erase or modify traces that have not been saved, these traces will be colored white. You must save the waypoint, select the waypoint and then remove it.

### Footnotes
[Opened issue related to black points visible after removing them](https://github.com/Joe91/fun-bots/issues/82) <sup>[1]</sup>