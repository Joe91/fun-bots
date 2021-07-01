# What is a trace?
Basically a trace is what allows the bot to walk around.

There are currently two types of traces
- [Infantry paths](#creating-an-infantry-path), paths which the bots will follow on foot.
- [Vehicle paths](#creating-a-land-vehicle-path), paths which the bots will follow when in any vehicle (excluding planes and helicopters)
- Helicopters and planes are not (yet) supported.

# Creating a trace
In order to create a trace, you need to have a server running fun-bots (we recommend the latest version, [available here](https://github.com/Joe91/fun-bots/tags)). You also need to have the appropriate [permissions](https://github.com/Joe91/fun-bots/wiki/Permissions) to create a path.

You can open the fun-bots settings menu using `F12` and clicking the `WAYPOINT-EDITOR` button. [Example](https://github.com/Joe91/fun-bots/blob/master/Screenshots/Menu/Full.png)

You are greeted by a lot of [buttons and options](https://github.com/Firjens/fun-bots/blob/updated-traces/Screenshots/Menu/Traces/FullTraceMenuExample.png)

More information will be added later.

#### Sharing your new traces with the community
When you have created a new share or updated an existing path, and it's of good quality, you can share it with the rest of the community and add it to traces database included in fun-bots. Please see [TBA](/#) on how to share it.

## Creating an infantry path
Infantry paths are different for each gamemode.

### Infantry paths for any Conquest or Assault gamemode
The following paths are required to create a full map trace for any conquest or assault gamemode.

1. Create a spawn point at the principal deploy points. (Red circle on the image below). This can be a strait line, a circle or anything else you want. Bots spawn on this path line. When your path is complete, save the trace.
We need to add the objective to this path. Select the waypoint using the waypoint-editor and pressing Q on any node (red dots), open the Venice Unleashed console whilst the waypoint is selected and enter `funbots.AddObjective <base us/base ru>` based on the deploy location. [Example](https://github.com/Firjens/fun-bots/blob/updated-traces/documentation/images/traces/DeployBaseAddObjExample.png) - [Success](https://github.com/Firjens/fun-bots/blob/updated-traces/documentation/images/traces/DeployBaseAddObjSuccess.png)

2. Create a path around flag A (Point A with a Green circle around it on the image below). Bots will spawn on this based on your fun-bots configuration.
Just like the deployment point, we need to add the objective `A` to the path around the flag, do the exact same except instead of `<base us/base ru>`, enter `A` as objective.

3. Create a path between the deployment point and the A flag.
You do not need to give this an objective, bots will automatically use the appropriate path between two points.
   
4. You need to create a path around all other flags (flag B, C, D, etc.), just like in the 2nd example.
Create a path between all other flags (Colored orange on the image below). Every flag should be connected to each-other.

5. Save it (Go to `CLIENT` in the `WAYPOINT-EDITOR`, and click `SAVE`. Do the same for the `SERVER` button.)
You should receive confirmation (yell) once it's saved.
   
And you're done, that is the basic path you need for infantry. You can create multiple paths to same objectives as long as the start and end have an objective.

![Tracing scheme](https://github.com/Firjens/fun-bots/blob/updated-traces/documentation/images/traces/TraceExampleA.png "A scheme showing how tracing works")

**Notes:**
- A path should always start, and end at an objective.
- One path can link multiple flags, or even all flags. [Example](https://github.com/Firjens/fun-bots/blob/updated-traces/Screenshots/Menu/Traces/PathMultipleFlags.png)

#### Advanced: create a separate spawn point
You can create a separate spawn point by using the `A spawn` objective. Please note that a bot will always spawn on the first node of a spawn-path.

### Infantry path for Rush
The following paths are required to create a full map trace for any Rush gamemode.

This will be available soon.

## Creating a land-vehicle path
The following paths are used by bots for land vehicles.

1. Create a path from an objective to a nearby vehicle, the objective of this path should be `vehicle <uniqueName>`. At the end of the path when you are extremely close to the vehicle. Save the path and select the latest point of that path, open the Venice Unleashed console and enter `AddVehicle` whilst looking at the vehicle.
2. Trace a path (we highly recommend having this separate from the infantry paths, as vehicles drive on roads and infantry are not supposed to walk on the roads) for the vehicle. Follow the same guidelines as for infantry paths.
5. Save it (Go to `CLIENT` in the `WAYPOINT-EDITOR`, and click `SAVE`. Do the same for the `SERVER` button.)
   You should receive confirmation (yell) once it's saved.
   
#### Implementation Ideas
- You can make the vehicle path go around a certain location. Example is the current CL - Grand Bazaar map where the bots drive around the map. 

## Known bugs and issues
This list contains all bugs and issues related to traces.

No current confirmed issues related to traces are reported. If you find an issue, please [report them](https://github.com/Joe91/fun-bots/issues).

# FAQ
Information will be added here later.

#### Q: I don't understand something, what should I do?
You should ask the contributors, maintainers and developers before you are wasting too much time on something that does not work.

#### Q: Black points are still visible after removing a waypoint. [Example](https://media.discordapp.net/attachments/860159569107615764/860167425962147870/unknown.png)
This is intended behavior. The black dots are orphaned nodes and get cleaned out on a save/load cycle. They are left in place so that they can still be interacted with in case of accidental removal.<sup>[1]</sup>

#### Q: I can't erase a waypoint?
You cannot erase or modify traces that have not been saved, these traces will be colored white. You must save the waypoint, select the waypoint and then remove it.

### Footnotes
[Issue related to black points visible after removing them](https://github.com/Joe91/fun-bots/issues/82) <sup>[1]</sup>