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
                VERSION_MIN = 2,

                -- Patch version
                VERSION_PATCH = 0,

                -- Additional label for pre-releases and build meta data
                VERSION_LABEL = "dev7",

                -- Numerical ID (int) of the current build.
                -- Increase it upon a new release or release candidate, end-point servers require the correct version ID.
                -- For a list of version ID's and their appropriate version name, see: https://repository.funbots.dev/
                VERSION_ID = 0,

                -- Current version type of this build
                VERSION_TYPE = VersionType.DevBuild
        },

        -- Bot raycasting
        GAME_RAYCASTING = {
                -- Trace delta shooting
                TRACE_DELTA_SHOOTING = 0.4,

                -- Raycast Interval
                RAYCAST_INTERVAL = 0.05,
        },

        -- Bot related
        BOT = {
                -- Bot attack bot check interval
                BOT_ATTACK_BOT_CHECK_INTERVAL = 0.05,

                -- Update cycle
                BOT_UPDATE_CYCLE = 0.1,

                -- = 3 frames at 60 Hz
                BOT_AIM_UPDATE_INTERVAL = 0.05,

                -- - distance the bots have to reach in height to continue with next Waypoint
                TARGET_HEIGHT_DISTANCE_WAYPOINT = 1.5
        }
}