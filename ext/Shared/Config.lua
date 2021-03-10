MAX_NUMBER_OF_BOTS	= 64;			-- maximum bots that can be spawned
USE_REAL_DAMAGE 	= true;			-- with real damage, the hitboxes are a bit buggy

Config = {
	--global
	botWeapon = "Auto",			-- Select the weapon the bots use
	botKit = "RANDOM_KIT",			-- see BotKits
	botColor = "RANDOM_COLOR",		-- see BotColors
	zombieMode = false,				-- Zombie Bot Mode

	--difficluty
	botAimWorsening = 0.8,			-- make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy).
	botSniperAimWorsening = 0.2,	-- see botAimWorsening, only for Sniper-rifles
	damageFactorAssault = 0.5,		-- origninal Damage from bots gets multiplied by this
	damageFactorCarabine = 0.5,		-- origninal Damage from bots gets multiplied by this
	damageFactorLMG = 0.5,			-- origninal Damage from bots gets multiplied by this
	damageFactorPDW = 0.5,			-- origninal Damage from bots gets multiplied by this
	damageFactorSniper = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorShotgun = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorPistol = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorKnife = 1.4,		-- origninal Damage from bots gets multiplied by this

	--spawn
	spawnMode = 'balanced_teams',	-- mode the bots spawn with
	spawnInBothTeams = true,		-- Bots spawn in both teams
	initNumberOfBots = 6,			-- bots for spawnmode
	newBotsPerNewPlayer = 2,		-- number to increase Bots, when new players join
	spawnDelayBots = 10.0,			-- time till bots respawn, if respawn enabled
	botTeam = TeamId.TeamNeutral, 	-- default bot team (0 = neutral / auto, 1 = US, 2 = RU) TeamId.Team2
	botNewLoadoutOnSpawn = true,	-- bots get a new kit and color, if they respawn
	maxAssaultBots = -1,			-- maximum number of Bots with Assault Kit
	maxEngineerBots = -1,			-- maximum number of Bots with Engineer Kit
	maxSupportBots = -1,			-- maximum number of Bots with Support Kit
	maxReconBots = -1,				-- maximum number of Bots with Recon Kit

	-- weapons
	useRandomWeapon = true,			-- use a random weapon out of the class list
	assaultWeapon = "M16A4",		-- weapon of Assault class
	engineerWeapon = "M4A1",		-- weapon of Engineer class
	supportWeapon = "M249",			-- weapon of Support class
	reconWeapon = "L96_6x",			-- weapon of Recon class
	pistol = "M1911_Lit",			-- Bot pistol
	knife = "Razor",				-- Bot knife
	assaultWeaponSet = "Class",				-- weaponset of Assault class
	engineerWeaponSet = "Class_PDW",		-- weaponset of Engineer class
	supportWeaponSet = "Class_Shotgun",	-- weaponset of Support class
	reconWeaponSet = "Class",				-- weaponset of Recon class

	-- behaviour
	fovForShooting = 200,			-- Degrees of FOV of Bot
	maxRaycastDistance = 150,		-- meters bots start shooting at player
	maxShootDistanceNoSniper = 70,	-- meters a bot (not sniper) start shooting at player
	botAttackMode = "Random",		-- Mode the Bots attack with. Random, Crouch or Stand
	shootBackIfHit = true,			-- bot shoots back, if hit
	botsAttackBots = true,			-- bots attack bots from other team
	meleeAttackIfClose = true,		-- bot attacks with melee if close
	botCanKillHimself = false,		-- if a bot is that close he will attack, even if not in FOV

	-- traces
	debugTracePaths = false,		-- Shows the trace line and search area from Commo Rose selection
	waypointRange = 100,			-- Set how far away waypoints are visible (meters)
	drawWaypointLines = true,		-- Draw waypoint connection Lines
	lineRange = 15,					-- Set how far away waypoint lines are visible (meters)
	drawWaypointIDs = true,			-- Draw waypoint IDs
	textRange = 3,					-- Set how far away waypoint text is visible (meters)
	debugSelectionRaytraces = false,-- Shows the trace line and search area from Commo Rose selection
	traceDelta = 0.2,					-- update intervall of trace

	-- advanced
	distanceForDirectAttack = 5,	-- if that close, the bot can hear you
	maxBotAttackBotDistance = 30,	-- meters a bot attacks an other bot
	meleeAttackCoolDown = 3.0,		-- the time a bot waits before attacking with melee again
	aimForHead = false,				-- bots aim for the head
	jumpWhileShooting = true,		-- bots jump over obstacles while shooting if needed
	jumpWhileMoving = true,			-- bots jump while moving. If false, only on obstacles!
	overWriteBotSpeedMode = 0,		-- 0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run
	overWriteBotAttackMode = 0,		-- Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk (good aim), 4 = run
	speedFactor = 1.0,				-- reduces the movementspeed. 1 = normal, 0 = standing.
	speedFactorAttack = 0.6,		-- reduces the movementspeed while attacking. 1 = normal, 0 = standing.

	-- expert
	botFirstShotDelay = 0.4,		-- delay for first shot. If too small, there will be great spread in first cycle because its not kompensated jet.
	botMinTimeShootAtPlayer = 1.0,	-- the minimum time a bot shoots at one player
	botFireModeDuration = 5.0,		-- the minimum time a bot tries to shoot a player
	maximunYawPerSec = 450,			-- in Degree. Rotaion-Movement per second.
	targetDistanceWayPoint = 0.8,	-- distance the bots have to reach to continue with next Waypoint
	keepOneSlotForPlayers = true,	-- always keep one slot for new Players to join
	distanceToSpawnBots	= 30,		-- distance to spawn Bots away from players
	heightDistanceToSpawn = 2.5,	-- distance vertically, Bots should spawn away, if closer than distance
	distanceToSpawnReduction = 5,	-- reduce distance if not possible
	maxTrysToSpawnAtDistance = 3,	-- try this often to spawn a bot away from players
	headShotFactorBots = 1.5,		-- factor for damage if headshot
	attackWayBots = true,			-- bots on paths attack player
	respawnWayBots = true,			-- bots on paths respawn if killed

	-- UI settings & language options
	disableUserInterface = false,	-- if true, the complete UI will be disabled (not available in the UI ;-) )
	disableChatCommands = true,	 	-- if true, no chat commands can be used
	disableRCONCommands = true,	 	-- if true, no RCON commands can be used
	traceUsageAllowed = true,		-- if false, no traces can be recorded, deleted or saved
	settingsPassword = "fun",		-- if nil, disable it. Otherwise use a String with your password
	language = nil, --"de_DE",		-- de_DE as sample (default is english, when language file doesnt exists)
};

--don't change these values unless you know what you do
StaticConfig = {
	traceDeltaShooting = 0.4,			-- update intervall of trace back to path the bots left for shooting
	raycastInterval = 0.05,				-- update intervall of client raycasts
	botAttackBotCheckInterval = 0.05,	-- update intervall of client raycasts
	botUpdateCycle = 0.1,				-- update-intervall of bots
	botAimUpdateCycle = 0.05,			-- = 3 frames at 60 Hz
	targetHeightDistanceWayPoint = 1.5	-- distance the bots have to reach in height to continue with next Waypoint
};
