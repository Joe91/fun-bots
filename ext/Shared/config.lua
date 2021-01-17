Config = {
    --general
    maxNumberOfBots = 32,
    initNumberOfBots = 16,  --bots on levelstart
    spawnOnLevelstart = true,
    maxRaycastDistance = 125, --meters bots start shooting at player
    spawnDelayBots = 2.0,   --time till bots respawn, if respawn enabled
    botTeam = TeamId.Team2, --default bot team
    botNewLoadoutOnSpawn = true,
    disableChatCommands = false,
    --shooting
    fovForShooting = 270,  -- Degrees of FOV of Bot
    botFireDuration = 0.2,
    botFirePause = 0.3,
    botMinTimeShootAtPlayer = 1.0,
    botFireModeDuration = 5.0,
    meleeAttackCoolDown = 3.0,

    --values that can be modified ingame. These are the startup settings
    spawnInSameTeam = false,
    respawnWayBots = true,
    attackWayBots = true,
    bulletDamageBot = 10,
    bulletDamageBotSniper = 24,
    meleeDamageBot = 48,
    meleeAttackIfClose = true,
    shootBackIfHit = true,
    botAimWorsening = 0.0,    --make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy)
    botKit = 0, -- 0 = random, 1 = assault, 2 = engineer, 3 = support, 4 = recon
    botColor = 0, -- 0 = random, see Colors

    --trace
    traceUsageAllowed = true,
    maxTraceNumber = 15,

	-- UI settings & language options
	settingsPassword = nil, -- if nil, disable it. Otherwise use a String with your password
	language = "de_DE", -- de_DE as sample (default is english, when language file doesnt exists)
	
    --don't change these values unless you know what you do
    traceDelta = 0.2,
    raycastInterval = 0.1, -- seconds
    botUpdateCycle = 0.1,
    botAimUpdateCycle = 0.05, -- = 3 frames
    botBulletSpeed = 600,       --aproximately
    targetDistanceWayPoint = 0.5,
    targetHeightDistanceWayPoint = 2
}

Colors = {
    "Urban", --1
    "ExpForce", --2
    "Ninja", --3
    "DrPepper", --4
    "Para", --5
    "Ranger", --6
    "Specact", --7
    "Veteran", --8
    "Desert02", --9
    "Green", --10
    "Jungle", --11
    "Navy", --12
    "Wood01" --13
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