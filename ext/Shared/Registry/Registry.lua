require('__shared/Constants/VersionType')

--[[
        <!> Modifications to this file should not be made unless you know what you are doing.

        Welcome to the fun-bots registry. This file contains config-like variables related to the mod, such as versions and API-related stuff,
        but also important variables related to bots.
        These variables should not be configured by the end-user. The development team and CI/CD should set these variables to their correct value.
        As such, modifications to these variables are not supported by the fun-bots development team. Changing them is not recommended.

        Note to project contributors: when making changes to the registry, create a pull request and add Firjen <https://github.com/Firjens> as reviewer.
        Updates related to CI/CD is required before merging it, see <https://registry.funbots.dev/>
]]
Registry = {
        -- Numerical representation for this registry
        REGISTRY_VERSION = 1,
        
        -- This UUID is used for tracking changes to the registry.
        -- You can view the registries based on the UUID on: https://registry.funbots.dev/
        REGISTRY_ID = "f48fc4bb-af20-4159-9214-968a2af1d777",

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
                VERSION_LABEL = "dev6",

                -- Numerical ID (int) of the current build.
                -- Increase it upon a new release or release candidate, end-point servers require the correct version ID.
                -- For a list of version ID's and their appropriate version name, see: https://repository.funbots.dev/
                VERSION_ID = 1,

                -- Current version type of this build
                VERSION_TYPE = VersionType.DevBuild
        },

        -- Variables related to raycasting
        GAME_RAYCASTING = {
                -- Raycast Interval of client for different raycasts
                RAYCAST_INTERVAL = 0.05,
        },

		GAME_DIRECTOR = {
				UPDATE_OBJECTIVES_CYCLE = 1.5,

				MCOMS_CHECK_CYCLE = 30.0,
		},

        -- Bot related
        BOT = {
                -- Bot attack bot check interval
                BOT_ATTACK_BOT_CHECK_INTERVAL = 0.05,

				-- Update cycle fast
                BOT_FAST_UPDATE_CYCLE = 0.03, -- equals 30 fps

                -- Update cycle
                BOT_UPDATE_CYCLE = 0.1,

                -- - distance the bots have to reach in height to continue with next Waypoint
                TARGET_HEIGHT_DISTANCE_WAYPOINT = 1.5,

                -- Chance that the bot will teleport when they are stuck.
                PROBABILITY_TELEPORT_IF_STUCK = 80,

                -- At the end of an attack cycle, chance of throwing a grenade.
                PROBABILITY_THROW_GRENADE = 55,

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