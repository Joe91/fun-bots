USE_REAL_DAMAGE = true				-- with real damage, the hitboxes are a bit buggy
BOT_TOKEN = "BOT_"					-- token Bots are marked with

Config = {
	-- general
	BotWeapon = BotWeapons.Auto,	-- Select the weapon the bots use
	BotKit = BotKits.RANDOM_KIT,			-- The Kit of the Bots
	BotColor = BotColors.RANDOM_COLOR,		-- The Color of the Bots
	ZombieMode = false,				-- Zombie Bot Mode

	-- difficluty
	BotAimWorsening = 0.5,			-- make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy).
	BotSniperAimWorsening = 0.2,	-- see botAimWorsening, only for Sniper-rifles
	BotWorseningSkill = 0.3,		-- variation of the skill of a single bot. the higher, the worse the bots can get compared to the original settings
	DamageFactorAssault = 0.3,		-- original Damage from bots gets multiplied by this
	DamageFactorCarabine = 0.3,		-- original Damage from bots gets multiplied by this
	DamageFactorLMG = 0.3,			-- original Damage from bots gets multiplied by this
	DamageFactorPDW = 0.3,			-- original Damage from bots gets multiplied by this
	DamageFactorSniper = 0.8,		-- original Damage from bots gets multiplied by this
	DamageFactorShotgun = 0.7,		-- original Damage from bots gets multiplied by this
	DamageFactorPistol = 0.7,		-- original Damage from bots gets multiplied by this
	DamageFactorKnife = 1.5,		-- original Damage from bots gets multiplied by this

	-- spawn
	SpawnMode = SpawnModes.balanced_teams,	-- mode the bots spawn with
	SpawnInBothTeams = true,		-- Bots spawn in both teams
	InitNumberOfBots = 6,			-- bots for spawnmode
	NewBotsPerNewPlayer = 2,		-- number to increase Bots, when new players join
	BotTeam = TeamId.TeamNeutral, 	-- default bot team (0 = neutral / auto, 1 = US, 2 = RU) TeamId.Team2
	BotNewLoadoutOnSpawn = true,	-- bots get a new kit and color, if they respawn
	MaxAssaultBots = -1,			-- maximum number of Bots with Assault Kit. -1 = no Limit
	MaxEngineerBots = -1,			-- maximum number of Bots with Engineer Kit. -1 = no Limit
	MaxSupportBots = -1,			-- maximum number of Bots with Support Kit. -1 = no Limit
	MaxReconBots = -1,				-- maximum number of Bots with Recon Kit. -1 = no Limit

	-- spawn-limits
	MaxBotsPerTeamDefault = 32,		-- max number of bots in one team
	MaxBotsPerTeamTdm = 24,			-- max number of bots in one team in Team-Death-Match
    MaxBotsPerTeamTdmc = 8,			-- max number of bots in one team in Team-Death-Match-CQ
	MaxBotsPerTeamSdm = 5,			-- max number of bots in one team in Squad-Death-Match
    MaxBotsPerTeamCl = 32,			-- max number of bots in one team in Conquest-Large
    MaxBotsPerTeamCs = 16,			-- max number of bots in one team in Conquest-Small
    MaxBotsPerTeamCal = 32,			-- max number of bots in one team in Conquest-Assault-Large
    MaxBotsPerTeamCas = 16,			-- max number of bots in one team in Conquest-Assault-Small
    MaxBotsPerTeamRl = 24,			-- max number of bots in one team in Rush-Large
	MaxBotsPerTeamCtf = 24,			-- max number of bots in one team in Capture-The-Flag
    MaxBotsPerTeamD = 24,			-- max number of bots in one team in Domination
    MaxBotsPerTeamGm = 8,			-- max number of bots in one team in Gun-Master
	MaxBotsPerTeamS = 16,			-- max number of bots in one team in Scavenger

	-- behaviour
	FovForShooting = 245,			-- Degrees of FOV of Bot
	MaxRaycastDistance = 150,		-- meters bots start shooting at player
	MaxShootDistanceNoSniper = 70,	-- meters a bot (not sniper) start shooting at player
	MaxShootDistancePistol = 30,	-- only in auto-weapon-mode, the distance until a bot switches to pistol if his magazine is empty.
	BotAttackMode = BotAttackModes.Random,		-- Mode the Bots attack with. Random, Crouch or Stand
	ShootBackIfHit = true,			-- bot shoots back, if hit
	BotsAttackBots = true,			-- bots attack bots from other team
	MeleeAttackIfClose = true,		-- bot attacks with melee if close
	BotCanKillHimself = false,		-- bot takes falldamage or explosion-damage from onw frags
	BotsRevive = true,				-- Bots revive other players
	BotsThrowGrenades = true,		-- Bots throw grenades
	BotsDeploy = true,				-- Bots deploy ammo and medkits
	DeployCycle = 50,				-- time between deployment of bots

	-- weapons
	UseRandomWeapon = true,			-- use a random weapon out of the weapon set
	AssaultWeaponSet = WeaponSets.Custom,	-- weaponset of Assault class
	EngineerWeaponSet = WeaponSets.Custom,	-- weaponset of Engineer class
	SupportWeaponSet = WeaponSets.Custom,	-- weaponset of Support class
	ReconWeaponSet = WeaponSets.Custom,		-- weaponset of Recon class
	AssaultWeapon = "M416",			-- weapon of Assault class
	EngineerWeapon = "M4A1",		-- weapon of Engineer class
	SupportWeapon = "M249",			-- weapon of Support class
	ReconWeapon = "L96_6x",			-- weapon of Recon class
	Pistol = "MP412Rex",			-- Bot pistol
	Knife = "Razor",				-- Bot knife

	-- traces
	DebugTracePaths = false,		-- Shows the trace line and search area from Commo Rose selection
	WaypointRange = 100,			-- Set how far away waypoints are visible (meters)
	DrawWaypointLines = true,		-- Draw waypoint connection Lines
	LineRange = 15,					-- Set how far away waypoint lines are visible (meters)
	DrawWaypointIDs = true,			-- Draw waypoint IDs
	TextRange = 3,					-- Set how far away waypoint text is visible (meters)
	DebugSelectionRaytraces = false,-- Shows the trace line and search area from Commo Rose selection
	TraceDelta = 0.3,				-- update intervall of trace

	-- advanced
	DistanceForDirectAttack = 5,	-- if that close, the bot can hear you
	MaxBotAttackBotDistance = 30,	-- meters a bot attacks an other bot
	MeleeAttackCoolDown = 3.0,		-- the time a bot waits before attacking with melee again
	AimForHead = false,				-- bots aim for the head
	JumpWhileShooting = true,		-- bots jump over obstacles while shooting if needed
	JumpWhileMoving = true,			-- bots jump while moving. If false, only on obstacles!
	OverWriteBotSpeedMode = 0,		-- 0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run
	OverWriteBotAttackMode = 0,		-- Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk (good aim), 4 = run
	SpeedFactor = 1.0,				-- reduces the movementspeed. 1 = normal, 0 = standing.
	SpeedFactorAttack = 0.6,		-- reduces the movementspeed while attacking. 1 = normal, 0 = standing.

	-- expert
	BotFirstShotDelay = 0.35,		-- delay for first shot. If too small, there will be great spread in first cycle because its not kompensated jet.
	BotMinTimeShootAtPlayer = 2.0,	-- the minimum time a bot shoots at one player
	BotFireModeDuration = 5.0,		-- the minimum time a bot tries to shoot a player
	MaximunYawPerSec = 450,			-- in Degree. Rotaion-Movement per second.
	TargetDistanceWayPoint = 0.8,	-- distance the bots have to reach to continue with next Waypoint
	KeepOneSlotForPlayers = true,	-- always keep one slot for new Players to join
	DistanceToSpawnBots = 30,		-- distance to spawn Bots away from players
	HeightDistanceToSpawn = 2.5,	-- distance vertically, Bots should spawn away, if closer than distance
	DistanceToSpawnReduction = 5,	-- reduce distance if not possible
	MaxTrysToSpawnAtDistance = 3,	-- try this often to spawn a bot away from players
	HeadShotFactorBots = 1.5,		-- factor for damage if headshot
	AttackWayBots = true,			-- bots on paths attack player
	RespawnWayBots = true,			-- bots on paths respawn if killed
	SpawnMethod = SpawnMethod.SpawnSoldierAt,	-- method the bots spawn with. Careful, not supported on most of the maps!!

	-- UI settings & language options
	DisableUserInterface = false,	-- if true, the complete UI will be disabled (not available in the UI -) )
	DisableChatCommands = false,		-- if true, no chat commands can be used
	DisableRCONCommands = false,		-- if true, no RCON commands can be used
	IgnorePermissions = false,		-- if true, all permissions are ignored --> everyone can do everything
	Language = nil --"de_DE"		-- de_DE as sample (default is english, when language file doesnt exists)
}

-- don't change these values unless you know what you do
StaticConfig = {
	TraceDeltaShooting = 0.4,			-- update intervall of trace back to path the bots left for shooting
	RaycastInterval = 0.05,				-- update intervall of client raycasts
	BotAttackBotCheckInterval = 0.05,	-- update intervall of client raycasts
	BotUpdateCycle = 0.1,				-- update-intervall of bots
	BotAimUpdateCycle = 0.05,			-- = 3 frames at 60 Hz
	TargetHeightDistanceWayPoint = 1.5	-- distance the bots have to reach in height to continue with next Waypoint
}
