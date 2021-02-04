MAX_NUMBER_OF_BOTS	= 32;	-- maximum bots that can be spawned
MAX_TRACE_NUMBERS	= 15;		-- maximum number of traces in one level

Config = {
	--global
	spawnInSameTeam = false,		-- Team the bots spawn in
	botWeapon = "Primary",			-- Select the weapon the bots use
	botKit = "RANDOM_KIT",			-- see BotKits
	botColor = "RANDOM_COLOR",		-- see BotColors
	useShotgun = false,				-- only shotguns with frag, as it counts the kills of the Bots

	--difficluty
	botAimWorsening = 0.2,			-- make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy). Restart of level needed
	botSniperAimWorsening = 0.0,	-- see botAimWorsening, only for Sniper-rifles
	aimForHead = false,				-- bots aim for the head
	damageFactorAssault = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorCarabine = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorLMG = 0.8,			-- origninal Damage from bots gets multiplied by this
	damageFactorSniper = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorShotgun = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorPistol = 0.8,		-- origninal Damage from bots gets multiplied by this
	damageFactorKnife = 0.8,		-- origninal Damage from bots gets multiplied by this

	--spawn
	spawnOnLevelstart = true,		-- bots spawn on levelstart (if valid paths are available)
	onlySpawnBotsWithPlayers = false,-- Bots only spawn if at least one Player is on the server
	initNumberOfBots = 8,			-- bots on levelstart
	incBotsWithPlayers = true,		-- increase Bots, when new players join
	newBotsPerNewPlayer = 3,		-- number to increase Bots, when new players join
	keepOneSlotForPlayers = true,	-- always keep one slot for new Players to join
	spawnDelayBots = 2.0,			-- time till bots respawn, if respawn enabled
	botTeam = TeamId.Team2,		 	-- default bot team (0 = neutral, 1 = US, 2 = RU) TeamId.Team2
	respawnWayBots = true,			-- bots on paths respawn if killed
	botNewLoadoutOnSpawn = true,	-- bots get a new kit and color, if they respawn
	maxAssaultBots = -1,			-- maximum number of Bots with Assault Kit
	maxEngineerBots = -1,			-- maximum number of Bots with Engineer Kit
	maxSupportBots = -1,			-- maximum number of Bots with Support Kit
	maxReconBots = -1,				-- maximum number of Bots with Recon Kit
	distanceToSpawnBots	= 50,		-- distance to spawn Bots away from players
	distanceToSpawnReduction = 5,	-- reduce distance if not possible
	maxTrysToSpawnAtDistance = 3,	-- try this often to spawn a bot away from players

	-- weapons
	assaultWeapon = "M416",			-- weapon of Assault class
	assaultShotgun = "USAS-12",		-- shotgun of Assault class
	engineerWeapon = "M4A1",		-- weapon of Engineer class
	engineerShotgun = "saiga20",	-- shotgun of Engineer class
	supportWeapon = "M240",			-- weapon of Support class
	supportShotgun = "Jackhammer",	-- shotgun of Support class
	reconWeapon = "L96",			-- weapon of Recon class
	reconShotgun = "SPAS12",		-- shotgun of Recon class
	pistol = "M1911_Lit",			-- Bot pistol
	knife = "Razor",				-- Bot knife

	--advanced
	fovForShooting = 270,			-- Degrees of FOV of Bot
	shootBackIfHit = true,			-- bot shoots back, if hit
	maxRaycastDistance = 150,		-- meters bots start shooting at player
	maxShootDistanceNoSniper = 80,	-- meters a bot (not sniper) start shooting at player
	distanceForDirectAttack = 5,	-- if a bot is that close he will attack, even if not in FOV
	meleeAttackIfClose = true,		-- bot attacks with melee if close
	attackWayBots = true,			-- bots on paths attack player
	meleeAttackCoolDown = 3.0,		-- the time a bot waits before attacking with melee again
	jumpWhileShooting = true,		-- bots jump over obstacles while shooting if needed
	jumpWhileMoving = true,			-- bots jump while moving. If false, only on obstacles!
	overWriteBotSpeedMode = 0,		-- 0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run
	overWriteBotAttackMode = 0,		-- Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk, 4 = run
	speedFactor = 1.0,				-- reduces the movementspeed. 1 = normal, 0 = standing.
	speedFactorAttack = 1.0,		-- reduces the movementspeed while attacking. 1 = normal, 0 = standing.

	--expert
	botFirstShotDelay = 0.2,		-- delay for first shot. If too small, there will be great spread in first cycle because its not kompensated jet.
	botMinTimeShootAtPlayer = 1.0,	-- the minimum time a bot shoots at one player
	botFireModeDuration = 5.0,		-- the minimum time a bot tries to shoot a player
	maximunYawPerSec = 540,			-- in Degree. Rotaion-Movement per second.
	targetDistanceWayPoint = 1.2,	-- distance the bots have to reach to continue with next Waypoint

	-- UI settings & language options
	disableUserInterface = false,	-- if true, the complete UI will be disabled
	disableChatCommands = true,	 	-- if true, no chat commands can be used
	traceUsageAllowed = true,		-- if false, no traces can be recorded, deleted or saved
	settingsPassword = "fun",		-- if nil, disable it. Otherwise use a String with your password
	language = nil, --"de_DE",		-- de_DE as sample (default is english, when language file doesnt exists)
};

--don't change these values unless you know what you do
StaticConfig = {
	traceDelta = 0.2,					-- update intervall of trace
	traceDeltaShooting = 0.4,			-- update intervall of trace back to path the bots left for shooting
	raycastInterval = 0.1,				-- update intervall of client raycasts
	botUpdateCycle = 0.1,				-- update-intervall of bots
	botAimUpdateCycle = 0.05,			-- = 3 frames at 60 Hz
	targetHeightDistanceWayPoint = 1.5	-- distance the bots have to reach in height to continue with next Waypoint
};
