# How to trace
 
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
#### Paths from flags
- there should be a path to every of the other flags from one flag
- on path can link several or even all flags
- each flag a path connects has to be on the objectives of the paths
#### Paths at flags
- should run in the radius of the flag most of the time
- should only have one objective on them

## Other stuff
- Ask before you do too much and its not working ;-)
- Naming of objectives (all without "):
	- Bases: "base us" / "base ru"
	- Flags: "A", "B", "C",..

Advanced:
- If you want to create separated spawn-paths for a flag, just label them like this:
	"A spawn" is a spawn-path for A. A bot will always spawn on the first node of a spawn-path


## Creating Rush-Paths
For Rush things get a little more complex.
First the easy ones:
- you need a base path for every defender-base (attacker-bases are the defender base from one index before, if no own base is defined)
- you need paths around each mcom (not directly at, but around)
- you need very short paths directly on the mcomcs
- you need paths from every attacker-base to the mcoms
- you need paths connecting the mcomcs of the current stage
- you need paths from the mcoms to the next mcoms (after they are destroyed)

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

### needed commands
addObjective <name of objective> (adds a label to a path. Just select one point of a path)
addMcom (adds the MCOM-Interaction to one point - Select the point, stand on it and look at the MCOM, then execute this command)