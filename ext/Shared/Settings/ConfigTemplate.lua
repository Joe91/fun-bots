USE_REAL_DAMAGE = true					-- with real damage, the hitboxes are a bit buggy
BOT_TOKEN = "BOT_"						-- token Bots are marked with

Config = {

	--[[SETTINGS GET INSERTED HERE]]
}

VersionConfig = {
	-- Debugging will show extra output, both in-game using the VU console and in the server console.
	-- 0 = All messages. (All)
	-- 1 = Highly detailed tracing messages. Produces the most voluminous output. (High)
	-- 2 = Info - Informational messages that might make sense to end users and server administrators. (Info)
	-- 3 = Potentially harmful situations of interest to end users or system managers that indicate potential problems. (Warn)
	-- 4 = Error events of considerable importance that will prevent normal program execution, but might still allow the application to continue running. (Error)
	-- 5 = Only critical errors and general output (Fatal)
	DebugLevel = 4, -- default: 4 (recommended)

	AutoUpdater = {
		-- Enabling the auto updater will show you a notification when a new update for fun-bots is available for download.
		-- Please note that we do not support outdated versions.
		Enabled = true, -- default: true (recommended)

		-- Do you want notifications when newer development builds are available?
		DevBuilds = true,
	}
}
