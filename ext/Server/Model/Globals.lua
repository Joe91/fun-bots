---@class Globals
Globals = {
	WayPoints = {},
	ActiveTraceIndexes = 0,
	YawPerFrame = 0.0,

	IsTdm = false,
	IsSdm = false,
	IsScavenger = false,
	IsRush = false,
	IsRushWithoutVehicles = false,
	IsSquadRush = false,
	IsGm = false,
	IsConquest = false,
	IsDomination = false,
	IsAssault = false,
	NrOfTeams = 0,
	MaxPlayers = 0,
	GameMode = "",
	LevelName = "",
	Round = 0,
	MaxBotsPerTeam = 0,
	RespawnDelay = 0,
	IsInputAllowed = false,
	IsInputRestrictionDisabled = false,
	RemoveKitVisuals = false,
	IgnoreBotNames = {},
	RespawnWayBots = false,     -- Used for the runtime respawn.
	AttackWayBots = false,      -- Used for the runtime attack.
	SpawnMode = SpawnModes.manual, -- Used for the runtime spawn mode.
	LastPorjectile = nil        -- Only used for debugging and Vehicle-Data-collection
}
