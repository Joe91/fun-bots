require('__shared/Constants/VersionType')

--[[
        <!> Modifications to this file should not be made unless you know what you are doing.

		Welcome to the fun-bots registry. This file contains config-like variables related to the mod, such as versions and API-related stuff,
		but also important variables related to bots.
		These variables should not be configured by the end-user. The development team and CI/CD should set these variables to their correct value.
		As such, modifications to these variables are not supported by the fun-bots development team. Changing them is not recommended.
]]
Registry = {
		-- Version and Release related variables
		-- Variables related to the current build version, version and the type of version.
		-- We use semantic versioning. Please see: https://semver.org
		VERSION = {
				-- Major version
				VERSION_MAJ = 2,
				-- Minor version
				VERSION_MIN = 3,
				-- Patch version
				VERSION_PATCH = 0,
				-- Additional label for pre-releases and build meta data
				VERSION_LABEL = "RC3",
				-- Current version type of this build
				VERSION_TYPE = VersionType.Stable,
				-- The Version used for the Update-Check
				UPDATE_CHANNEL = VersionType.DevBuild,
		},

		-- Variables related to raycasting
		GAME_RAYCASTING = {
				-- Raycast Interval of client for different raycasts
				RAYCAST_INTERVAL = 0.05,
		},

		GAME_DIRECTOR = {
				UPDATE_OBJECTIVES_CYCLE = 1.5,

				MCOMS_CHECK_CYCLE = 26.0,

				ZONE_CHECK_CYCLE = 20.0, --Zone is 30 s. 10 Seconds without damage

				MAX_ASSIGNED_LIMIT = 8,
		},

		VEHICLES = {
			MIN_DISTANCE_VEHICLE_ENTER = 10.0,
		},

		-- Bot related
		BOT = {
				-- Bot attack bot check interval
				BOT_ATTACK_BOT_CHECK_INTERVAL = 0.05,
				-- Max Raycasts for Bot-Bot Attack per player and cycle
				MAX_RAYCASTS_PER_PLAYER_BOT_BOT = 4,
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
		},

		-- Bot team balancing
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
				PROBABILITY_SQUADMATE_SPAWN = 60,
				-- Probability of a bot spawning on the closest spawn point
				PROBABILITY_CLOSEST_SPAWN = 80,
				-- Probability of a bot spawning on an attacked spawn point
				PROBABILITY_ATTACKED_SPAWN = 80,
				-- Probability of a bot spawning on their deployment base.
				PROBABILITY_BASE_SPAWN = 15,
		}
}