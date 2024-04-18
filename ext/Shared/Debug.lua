--
-- SOON DEPRECATED - A better debugging system is currently in development by @Firjens
--
---@class Debug
Debug = {
	Globals = {
		UPDATE = true -- Debug the Updater.
	},
	Server = {
		INFO = false,     -- Global Informations.
		BOT = false,      -- Debug Bot-Handling.
		BOT_CREATION = true, -- Debug Bot-Attribute-Creation
		COMMAND = false,  -- Debug Chat- & RCON Commands.
		DATABASE = false, -- Debug Database-Operations.
		GAMEDIRECTOR = false, -- Debug the GameDirector.
		VEHICLES = false, -- Debug the Vehicle-Class.
		NODEEDITOR = false, -- Debug the NodeEditor.
		PATH = false,     -- Debug the PathSwitcher.
		SETTINGS = false, -- Debug the Settings-Migrator.
		TRACE = false,    -- Debug the TraceManager.
		UI = false,       -- Debug all UI things.
		PERMISSIONS = false, -- Debug all Permission things.
		MODIFICATIONS = false, -- Debug some Modifications.
		NODECOLLECTION = false, -- Debug NodeCollection.
		RCON = false      -- Debug some RCON Commands.
	},
	Client = {
		INFO = false, -- Global Informations.
		NODEEDITOR = true, -- Debug the NodeEditor.
		UI = false   -- Debug all UI things.
	},
	Shared = {
		INFO = false,   -- Global Informations.
		EBX = false,    -- Debug EBX-Utils.
		LANGUAGE = false, -- Debug Language.
		DATABASE = false, -- Debug Database-Operations.
		MODIFICATIONS = false -- Debug some Modifications.
	},
	Logger = {
		ENABLED = true,
		PRINTALL = false
	}
}
