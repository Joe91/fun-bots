# What is a trace?


# Creating an infantry path



## Infantry path for Rush
For Rush things get a little more complex.
First the easy ones:
- you need a base path for every defender-base (attacker-bases are the defender base from one index before, if no own base is defined)
- you need paths around each mcom (not directly at, but around)
- you need very short paths directly on the mcomcs
- you need paths from every attacker-base to the mcoms
- you need paths connecting the mcomcs of the current stage
- you need paths from the mcoms to the next mcoms (after they are destroyed)


# Creating a vehicle path
TBA

# Notes
The shorther the links are, the easier they are to understand and maintain.

## Known bugs and issues

*Black points are still visible after removing a waypoint [Example](https://media.discordapp.net/attachments/860159569107615764/860167425962147870/unknown.png)*
This is a known visual bug and does not affect tracing in any way. See https://github.com/Joe91/fun-bots/issues/82


# FAQ
*Q: I don't understand something, what should I do?*
TBA

*Q: I can't erase a waypoint*
A: You cannot erase or modify traces that have not been saved, these traces will be white. You must save the waypoint, select the waypoint and then remove it.











# Old content

## current process
- open waypoint-editor
- start trace
- end trace
- save trace

After that
- client save
- wait for yell
- server save
- wait for yell

## Ho to layout the paths
### Paths from bot-bases:
- each team needs a separated short path with only the Base-objective
- the paths from the base should just lead to any of the flags. From there they will continue on searching for their objectives
#### Paths connecting objectives
- there should be a path to every of the other flags from one flag
- one path can link several or even all flags
- each flag, a path connects, has to be on the objectives of this paths
- a path should always start and end on an objective-path
#### Paths at flags
- should run in the radius of the flag most of the time
- should only have one objective on them

## Other stuff
- Ask before you do too much and its not working ;-)
- Naming of objectives (all without "):
	- Bases: "base us" / "base ru"
	- Flags: "A", "B", "C",..
- shorter links are easier to maintain and understand...

Advanced:
- If you want to create separated spawn-paths for a flag, just label them like this:
	"A spawn" is a spawn-path for A. A bot will always spawn on the first node of a spawn-path


## Creating Rush-Paths

### Some special things
Naming of the objectives:
You need to use correct indexes:
- mcoms start with index 1 up to the last mcom.
	- "mcom 1", "mcom 2", "mcom 3", ...
- bases start with definding Base 1:
	- "base ru 1", "base ru 2", "base ru 3",
	- "base ru 0" == "base us 1"
	- no need to create attacking bases
- the paths directly at the mcoms have to be labeled like this:
	- path on mcom 1: "mcom 1 interact" and so on...

### Vehicle Paths
- Record a path to enter a vehicle with the Objective: "vehicle UniqueName"
- Add a Vehicle at the end of the path to the vehicle (Console "AddVehicle")
- Enter the vehicle and record a path from there
- Mark all paths of the vehicle as vehicle paths (Console "AddVehiclePath land")
- assign objectives as usual
- Keep vehivle-paths and normal paths separated from each other

### needed commands
addObjective <name of objective> (adds a label to a path. Just select one point of a path)
addMcom (adds the MCOM-Interaction to one point - Select the point, stand on it and look at the MCOM, then execute this command)