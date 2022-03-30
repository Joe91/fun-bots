require('__shared/Constants/VersionType')

--[[
		<!> Modifications to this file should not be made unless you know what you are doing.

		Welcome to the fun-bots registry. This file contains config-like variables related to the mod, such as versions and API-related stuff,
		but also important variables related to bots.
		These variables should not be configured by the end-user. The development team and CI/CD should set these variables to their correct value.
		As such, modifications to these variables are not supported by the fun-bots development team. Changing them is not recommended.
]]
---@class Registry
Registry = {
		COMMON = {
			-- token Bots are marked with. Can also be " " or "". If it's "" players with names of the botlist can't join!
			BOT_TOKEN = "BOT_",
			-- allow players to use Bot-Names
			ALLOW_PLAYER_BOT_NAMES = true,
			-- with real damage, the hitboxes are a bit buggy
			USE_REAL_DAMAGE = true,
			-- collition-raycasts are only supporded by the dev-buidls of VU atm (VEXT 1.3.2 or greater)
			USE_COLLITION_RAYCASTS = false,
			-- timeout to save or load maps
			LOADING_TIMEOUT = 25,
			-- distance commands are heard by bots
			COMMAND_DISTANCE = 20,
			-- valid keys can be found here: https://docs.veniceunleashed.net/vext/ref/fb/inputdevicekeys/
			BOT_COMMAND_KEY = InputDeviceKeys.IDK_LeftAlt,
		},
		-- Version and Release related variables
		-- Variables related to the current build version, version and the type of version.
		-- We use semantic versioning. Please see: https://semver.org
		VERSION = {
			-- Major version
			VERSION_MAJ = 2,
			-- Minor version
			VERSION_MIN = 5,
			-- Patch version
			VERSION_PATCH = 0,
			-- Additional label for pre-releases and build meta data
			VERSION_LABEL = "dev8",
			-- Current version type of this build
			VERSION_TYPE = VersionType.DevBuild,
			-- The Version used for the Update-Check
			UPDATE_CHANNEL = VersionType.DevBuild,
			-- prints current version in console
			CLIENT_SHOW_VERSION_ON_JOIN = false,
		},

		-- some Client Variables
		CLIENT = {
			-- distance a bot tries to revive a player
			REVIVE_DISTANCE = 30.0,
			-- the number of attack-checks done per cycle
			MAX_CHECKS_PER_CYCLE = 10,
			-- time bots will not attack a player when spawned
			SPAWN_PROTECTION = 1.5,
		},

		-- Variables related to raycasting
		GAME_RAYCASTING = {
			MAX_RAYCASTS_PER_PLAYER_PER_CYCLE = 3,
			-- Max Raycasts for Bot-Bot Attack per player and cycle. Needs to be smaller than max_raycats
			MAX_RAYCASTS_PER_PLAYER_BOT_BOT = 2,
			-- how often get the nodes calculated
			UPDATE_INTERVAL_NODEEDITOR = 0.03,
			-- Raycast Interval of client for different raycasts
			RAYCAST_INTERVAL_ENEMY_CHECK = 0.03,
			-- how often are the connections for a bot-bot-attack checked
			BOT_BOT_CHECK_INTERVAL = 0.05,
			-- max checks per cycle
			BOT_BOT_MAX_CHECKS = 30
		},

		-- Variables used by the Gamedirector-context
		GAME_DIRECTOR = {
			UPDATE_OBJECTIVES_CYCLE = 1.5,
			-- Time after a mcom is considered destroyed
			MCOMS_CHECK_CYCLE = 26.0, 
			-- Zone is 30 s. 10 Seconds without damage
			ZONE_CHECK_CYCLE = 20.0, 
			-- max bots per objective
			MAX_ASSIGNED_LIMIT = 8, 
			-- after finding no valid path for that many crossings, a bot is killed (Rush only)
			KILL_ON_INVALID_PATH_CROSSINGS = 10, 
		},

		VEHICLES = {
			-- distance for the "enter vehicle" command
			MIN_DISTANCE_VEHICLE_ENTER = 10.0,
			-- once a jet is that low above a vehicle or person he aborts
			ABORT_ATTACK_HEIGHT_JET = 50,
			-- once a jet is that far away from a vehicle or person he aborts
			ABORT_ATTACK_DISTANCE_JET = 120,
			-- once a jet is that far away from a jet or chopper he aborts
			ABORT_ATTACK_AIR_DISTANCE_JET = 50,
			-- once a chopper is that low above a vehicle or person he aborts
			ABORT_ATTACK_HEIGHT_CHOPPER = 20,
			-- in this time a jet will not attack
			JET_TAKEOFF_TIME = 20,
			-- time a jet waits after an attack
			JET_ABORT_ATTACK_TIME = 5,
			-- percentage of vehicle health to leave vehicle with (currently no passive events for bot-only vehicles)
			VEHILCE_EXIT_HEALTH = 12,
			-- propability to exit on low health
			VEHICLE_PROPABILITY_EXIT_LOW_HEALTH = 60,
			-- health-check cycle-time
			VEHICLE_HEALTH_CYLCE_TIME = 0.5,
			-- seat-check cycle-time
			VEHICLE_SEAT_CHECK_CYCLE_TIME = 4.0,
		},

		-- Bot related
		BOT = {
			-- Update cycle fast
			BOT_FAST_UPDATE_CYCLE = 0.03, -- equals 30 fps
			-- Update cycle
			BOT_UPDATE_CYCLE = 0.1,
			-- - distance the bots have to reach in height to continue with next Waypoint
			TARGET_HEIGHT_DISTANCE_WAYPOINT = 1.5,
			-- Chance that the bot will teleport when they are stuck.
			PROBABILITY_TELEPORT_IF_STUCK = 80,
			-- Chance that the bot will teleport when they are stuck in a vehicle.
			PROBABILITY_TELEPORT_IF_STUCK_IN_VEHICLE = 20,
			-- At the end of an attack cycle, chance of throwing a grenade.
			PROBABILITY_THROW_GRENADE = 80,
			-- the probabilty to use the rocket instead of the a primary
			PROBABILITY_SHOOT_ROCKET = 33,
			-- If the gamemode is Rush or Conquest, change direction if the bot is stuck on non-connecting paths.
			PROBABILITY_CHANGE_DIRECTION_IF_STUCK = 50,
			-- Trace delta a bot uses when they are off a trace path to find his way back to the best path
			TRACE_DELTA_SHOOTING = 0.4,
			-- The max time a bot tries to move to the repair-vehicle
			MAX_TIME_TRY_REPAIR = 10,
			-- Advanced aiming makes a difference on huge distances, but costs more performance
			USE_ADVANCED_AIMING = false,
		},

		-- Bot team balancing (only in keep_playercount - spawn-mode)
		BOT_TEAM_BALANCING = {
			-- Minimum amount of players required before balancing bots across teams
			-- Note: Only for mode keep_playercount
			THRESHOLD = 6, -- only for mode
			-- Maximum bot count difference between both teams (even count: 1, uneven: 2)
			-- Note: Only for mode keep_playercount
			ALLOWED_DIFFERENCE = 1,
		},

		-- Bot spawning
		BOT_SPAWN = {
			-- Time between a level loading and the first bot spawning
			-- Note: Must be big enough to register inputActiveEvents (> 1.0)
			FIRST_SPAWN_DELAY = 5.0,
			-- Probability of a bot spawning on a member of the same squad.
			PROBABILITY_SQUADMATE_SPAWN = 40,
			-- Probability of a bot spawning in the vehicle of a bot of the same squad.
			PROBABILITY_SQUADMATE_VEHICLE_SPAWN = 40,
			-- Probability of a bot spawning in the vehicle of a player of the same squad.
			PROBABILITY_SQUADMATE_PLAYER_VEHICLE_SPAWN = 80,
			-- Probability of a bot spawning on the closest spawn point
			PROBABILITY_CLOSEST_SPAWN = 80,
			-- Probability of a bot spawning on an attacked spawn point
			PROBABILITY_ATTACKED_SPAWN = 80,
			-- Probability of a bot spawning on their deployment base.
			PROBABILITY_BASE_SPAWN = 15,
		}
}
