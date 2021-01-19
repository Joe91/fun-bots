MAX_NUMBER_OF_BOTS = 32;	-- maximum bots that can be spawned
MAX_TRACE_NUMBERS = 15;		-- maximum number of traces in one level

Config = {
	--global
	spawnInSameTeam = false,		-- Team the bots spawn in
	botWeapon = "Primary",			-- Select the weapon the bots use
	botKit = "RANDOM_KIT",			-- see BotKits
	botColor = "RANDOM_COLOR",		-- see BotColors

	--difficluty
	botAimWorsening = 0.0,			-- make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy). Restart of level needed
	bulletDamageBot = 10,			-- damage of a bot with normal bullet
	bulletDamageBotSniper = 24,	 	-- damage of a bot with sniper bullet
	meleeDamageBot = 48,			-- damage of a bot with melee attack

	--advanced
	fovForShooting = 270,			-- Degrees of FOV of Bot
	shootBackIfHit = true,			-- bot shoots back, if hit
	botNewLoadoutOnSpawn = true,	-- bots get a new kit and color, if they respawn
	meleeAttackIfClose = true,		-- bot attacks with melee if close
	maxRaycastDistance = 125,		-- meters bots start shooting at player
	distanceForDirectAttack = 3,	-- if a bot is that close he will attack, even if not in FOV
	meleeAttackCoolDown = 3.0,		-- the time a bot waits before attacking with melee again
	spawnDelayBots = 2.0,			-- time till bots respawn, if respawn enabled
	initNumberOfBots = 10,			-- bots on levelstart
	spawnOnLevelstart = true,		-- bots spawn on levelstart (if valid paths are available)
	jumpWhileShooting = true,		-- bots jump over obstacles while shooting if needed

	-- UI settings & language options
	disableChatCommands = true,	 	-- if true, no chat commands can be used
	traceUsageAllowed = true,		-- if false, no traces can be recorded, deleted or saved
	settingsPassword = nil,		 	-- if nil, disable it. Otherwise use a String with your password
	language = nil, --"de_DE",		-- de_DE as sample (default is english, when language file doesnt exists)

	-- values that are changed by the mod while running TODO: better solution for them
	botTeam = TeamId.Team2,		 	-- default bot team (0 = neutral, 1 = US, 2 = RU) TeamId.Team2
	respawnWayBots = true,			-- bots on paths respawn if killed
	attackWayBots = true,			-- bots on paths attack player
}

--don't change these values unless you know what you do
StaticConfig = {
	traceDelta = 0.2,				-- update intervall of trace
	traceDeltaShooting = 0.4,		-- update intervall of trace back to path the bots left for shooting
	raycastInterval = 0.1,			-- update intervall of client raycasts
	botUpdateCycle = 0.1,			-- update-intervall of bots
	botAimUpdateCycle = 0.05,		-- = 3 frames at 60 Hz
	botBulletSpeed = 600,			-- speed a bullet travels ingame (aproximately)
	botFireDuration = 0.2,			-- the duration a bot fires
	botFirePause = 0.3,			 	-- the duration a bot waits after fire
	botMinTimeShootAtPlayer = 1.0,	-- the minimum time a bot shoots at one player
	botFireModeDuration = 5.0,		-- the minimum time a bot tries to shoot a player
	targetDistanceWayPoint = 0.5,	-- distance the bots have to reach to continue with next Waypoint
	targetHeightDistanceWayPoint = 2-- distance the bots have to reach in height to continue with next Waypoint
}

-- @ToDo move these values outside config
BotKits = {
	"RANDOM_KIT",
	"Assault",
	"Engineer",
	"Support",
	"Recon"
}

BotColors = {
	"RANDOM_COLOR",
	"Urban",
	"ExpForce",
	"Ninja",
	"DrPepper",
	"Para",
	"Ranger",
	"Specact",
	"Veteran",
	"Desert02",
	"Green",
	"Jungle",
	"Navy",
	"Wood01"
}

BotWeapons = {
	"Primary",
	"Pistol",
	"Knive"
}

BotNames = {
	"BOT_Liam",
	"BOT_Noah",
	"BOT_Oliver",
	"BOT_William",
	"BOT_Elijah",
	"BOT_James",
	"BOT_Benjamin",
	"BOT_Lucas",
	"BOT_Mason",
	"BOT_Ethan",
	"BOT_Alexander",
	"BOT_Henry",
	"BOT_Jacob",
	"BOT_Michael",
	"BOT_Daniel",
	"BOT_Logan",
	"BOT_Jackson",
	"BOT_Sebastian",
	"BOT_Jack",
	"BOT_Aiden",
	"BOT_Owen",
	"BOT_Samuel",
	"BOT_Matthew",
	"BOT_Joseph",
	"BOT_Levi",
	"BOT_Mateo",
	"BOT_David",
	"BOT_John",
	"BOT_Wyatt",
	"BOT_Carter",
	"BOT_Julian",
	"BOT_Luke",
	"BOT_Grayson",
	"BOT_Isaac",
	"BOT_Jayden",
	"BOT_Theodore",
	"BOT_Gabriel",
	"BOT_Anthony",
	"BOT_Dylan",
	"BOT_Leo",
	"BOT_Lincoln",
	"BOT_Jaxon",
	"BOT_Asher",
	"BOT_Christopher",
	"BOT_Josiah",
	"BOT_Andrew",
	"BOT_Thomas",
	"BOT_Joshua",
	"BOT_Ezra",
	"BOT_Hudson",
	"BOT_Charles",
	"BOT_Caleb",
	"BOT_Isaiah",
	"BOT_Ryan",
	"BOT_Nathan",
	"BOT_Adrian",
	"BOT_Christian",
	"BOT_Maverick",
	"BOT_Colton",
	"BOT_Elias",
	"BOT_Aaron",
	"BOT_Eli",
	"BOT_Landon",
	"BOT_Jonathan",
	"BOT_Nolan",
	"BOT_Hunter",
	"BOT_Cameron",
	"BOT_Connor",
	"BOT_Santiago",
	"BOT_Jeremiah",
	"BOT_Ezekiel",
	"BOT_Angel",
	"BOT_Roman",
	"BOT_Easton",
	"BOT_Miles",
	"BOT_Robert",
	"BOT_Jameson",
	"BOT_Nicholas",
	"BOT_Greyson",
	"BOT_Cooper",
	"BOT_Ian",
	"BOT_Carson",
	"BOT_Axel",
	"BOT_Jaxson",
	"BOT_Dominic",
	"BOT_Leonardo",
	"BOT_Luca",
	"BOT_Austin",
	"BOT_Jordan",
	"BOT_Adam",
	"BOT_Xavier",
	"BOT_Jose",
	"BOT_Jace",
	"BOT_Everett",
	"BOT_Declan",
	"BOT_Evan",
	"BOT_Kayden",
	"BOT_Parker",
	"BOT_Wesley",
	"BOT_Kai"
}