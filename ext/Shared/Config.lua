Config = {
	--general
	maxNumberOfBots = 32,			-- maximum bots that can be spawned
	initNumberOfBots = 10,			-- bots on levelstart
	spawnOnLevelstart = true,		-- bots spawn on levelstart (if valid paths are available)
	maxRaycastDistance = 125,		-- meters bots start shooting at player
	distanceForDirectAttack = 3,	-- if a bot is that close he will attack, even if not in FOV
	spawnDelayBots = 2.0,			-- time till bots respawn, if respawn enabled
	botTeam = TeamId.Team2,		 	-- default bot team (0 = neutral, 1 = US, 2 = RU) TeamId.Team2
	botNewLoadoutOnSpawn = true,
	respawnWayBots = true,			-- bots on paths respawn if killed
	--shooting
	botFireDuration = 0.2,			-- the duration a bot fires
	botFirePause = 0.3,			 	-- the duration a bot waits after fire
	botMinTimeShootAtPlayer = 1.0,	-- the minimum time a bot shoots at one player
	botFireModeDuration = 5.0,		-- the minimum time a bot tries to shoot a player
	meleeAttackCoolDown = 3.0,		-- the time a bot waits before attacking with melee again
	jumpWhileShooting = true,		-- bots jump over obstacles while shooting if needed
	attackWayBots = true,			-- bots on paths attack player

	--values that can be modified ingame. These are the startup settings
	fovForShooting = 270,			-- Degrees of FOV of Bot
	spawnInSameTeam = false,		-- Team the bots spawn in
	disableChatCommands = true,	 	-- if true, no chat commands can be used
	bulletDamageBot = 10,			-- damage of a bot with normal bullet
	bulletDamageBotSniper = 24,	 	-- damage of a bot with sniper bullet
	meleeDamageBot = 48,			-- damage of a bot with melee attack
	meleeAttackIfClose = true,		-- bot attacks with melee if close
	botWeapon = "Primary",			-- Select the weapon the bots use
	shootBackIfHit = true,			-- bot shoots back, if hit
	botAimWorsening = 0.0,			-- make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy). Restart of level needed
	botKit = "RANDOM_KIT",			-- see BotKits
	botColor = "RANDOM_COLOR",		-- see BotColors

	-- UI settings & language options
	settingsPassword = nil,		 	-- if nil, disable it. Otherwise use a String with your password
	language = nil, --"de_DE",		-- de_DE as sample (default is english, when language file doesnt exists)

	--trace
	traceUsageAllowed = true,		-- if false, no traces can be recorded, deleted or saved
	maxTraceNumber = 15,			-- maximum number of traces in one level

	--don't change these values unless you know what you do
	traceDelta = 0.2,				-- update intervall of trace
	traceDeltaShooting = 0.4,		-- update intervall of trace back to path the bots left for shooting
	raycastInterval = 0.1,			-- update intervall of client raycasts
	botUpdateCycle = 0.1,			-- update-intervall of bots
	botAimUpdateCycle = 0.05,		-- = 3 frames at 60 Hz
	botBulletSpeed = 600,			-- speed a bullet travels ingame (aproximately)
	targetDistanceWayPoint = 0.5,	-- distance the bots have to reach to continue with next Waypoint
	targetHeightDistanceWayPoint = 2 -- distance the bots have to reach in height to continue with next Waypoint
};