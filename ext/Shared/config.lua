Config = {
    --general
    maxNumberOfBots = 32,           --maximum bots that can be spawned
    initNumberOfBots = 10,          --bots on levelstart
    spawnOnLevelstart = true,       --bots spawn on levelstart (if valid paths are available)
    maxRaycastDistance = 125,       --meters bots start shooting at player
    spawnDelayBots = 2.0,           --time till bots respawn, if respawn enabled
    botTeam = TeamId.Team2,         --default bot team
    botNewLoadoutOnSpawn = true,
    disableChatCommands = true,     --if true, no chat commands can be used
    respawnWayBots = true,          --bots on paths respawn if killed
    --shooting
    botFireDuration = 0.2,          -- the duration a bot fires
    botFirePause = 0.3,             -- the duration a bot waits after fire
    botMinTimeShootAtPlayer = 1.0,  -- the minimum time a bot shoots at one player
    botFireModeDuration = 5.0,      -- the minimum time a bot tries to shoot a player
    meleeAttackCoolDown = 3.0,      -- the time a bot waits before attacking with melee again
    attackWayBots = true,           -- bots on paths attack player

    --values that can be modified ingame. These are the startup settings
    fovForShooting = 270,           -- Degrees of FOV of Bot
    spawnInSameTeam = false,        -- Team the bots spawn in
    bulletDamageBot = 10,           -- damage of a bot with normal bullet
    bulletDamageBotSniper = 24,     -- damage of a bot with sniper bullet
    meleeDamageBot = 48,            -- damage of a bot with melee attack
    meleeAttackIfClose = true,      -- bot attacks with melee if close
    shootBackIfHit = true,          -- bot shoots back, if hit
    botAimWorsening = 0.0,          -- make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy). Restart of level needed
    botKit = "RANDOM_KIT",          -- see Kits
    botColor = "RANDOM_COLOR",      -- see Colors

    -- UI settings & language options
	settingsPassword = nil,         -- if nil, disable it. Otherwise use a String with your password
    language = nil, --"de_DE",      -- de_DE as sample (default is english, when language file doesnt exists)

    --trace
    traceUsageAllowed = true,       -- if false, no traces can be recorded, deleted or saved
    maxTraceNumber = 15,            -- maximum number of traces in one level

    --don't change these values unless you know what you do
    traceDelta = 0.2,               -- update intervall of trace
    raycastInterval = 0.1,          -- update intervall of client raycasts
    botUpdateCycle = 0.1,           -- update-intervall of bots
    botAimUpdateCycle = 0.05,       -- = 3 frames at 60 Hz
    botBulletSpeed = 600,           -- speed a bullet travels ingame (aproximately)
    targetDistanceWayPoint = 0.5,   -- distance the bots have to reach to continue with next Waypoint
    targetHeightDistanceWayPoint = 2 -- distance the bots have to reach in height to continue with next Waypoint
}

Kits = {
    "RANDOM_KIT",
    "Assault",
    "Engineer",
    "Support",
    "Recon"
}

Colors = {
    "RANDOM_COLOR", --0
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