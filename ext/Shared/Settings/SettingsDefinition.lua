--[[
	@property: SettingsDefinition
]]
---@class SettingsDefinition
SettingsDefinition = {
	--[[
		@property: Categorys
	]]
	Categorys = {
		GENERAL = "General",
		DIFFICULTY = "Difficulty",
		SPAWN = "Spawn",
		WAVES = "Waves",
		BEHAVIOUR = "Behaviour",
		VEHICLE = "Vehicle",
		WEAPONS = "Weapons",
		TRACE = "Trace",
		ADVANCED = "Advanced",
		EXPERT = "Expert",
		OTHER = "Other"
	},

	--[[
		@property: Elements
	]]
	Elements = {
		-- General.
		{
			Name = "BotKit",
			Text = "Bot Kit",
			---@type Type|integer
			Type = Type.Enum,
			Value = Config.BotKit,
			Reference = BotKits,
			Description = "The Kit of the Bots",
			Default = BotKits.RANDOM_KIT,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "BotColor",
			Text = "Bot Color",
			---@type Type|integer
			Type = Type.Enum,
			Reference = BotColors,
			Value = Config.BotColor,
			Description = "The Color of the Bots",
			Default = BotColors.RANDOM_COLOR,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "ZombiesDropAmmo",
			Text = "Zombies Drop Ammo",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.ZombiesDropAmmo,
			Description = "Zombies drop randomly some ammo",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "RandomHealthOfZombies",
			Text = "Randomize Helth of Zombies",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.RandomHealthOfZombies,
			Description = "zombie-helth differs from bot to bot",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "RandomAttackSpeedOfZombies",
			Text = "Randomize Attack-Speed of Zombies",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.RandomAttackSpeedOfZombies,
			Description = "zombie-speed differs from bot to bot",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "RandomDamgeOfZombies",
			Text = "Randomize Damage that zombies deal",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.RandomDamgeOfZombies,
			Description = "zombie-damage differs from bot to bot",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "RandomJumpSpeedOfZombies",
			Text = "Randomize Jump-Speeds of zombies",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.RandomJumpSpeedOfZombies,
			Description = "zombie-high-jumps differs from bot to bot",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "ZombiesProne",
			Text = "Zombies prone",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.ZombiesProne,
			Description = "Zombies can prone when walking around",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "ZombiesCrouch",
			Text = "Zombies crouch",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.ZombiesCrouch,
			Description = "Zombies can crouch when walking around",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "ZombiesWalk",
			Text = "Zombies walk",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.ZombiesWalk,
			Description = "Zombies can walk when walking around",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "ZombiesSprint",
			Text = "Zombies sprint",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.ZombiesSprint,
			Description = "Zombies can sprint when walking around",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},

		-- Difficulty.
		{
			Name = "BotMaxHealth",
			Text = "Bot Max Health at spawn",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.BotMaxHealth,
			Description = "Max health of bot at spawn(default 100.0)",
			Reference = Range(0.0, 1000.00, 1.0),
			Default = 125.0,
			UpdateFlag = UpdateFlag.Wave,
			Category = "DIFFICULTY"
		},
		{
			Name = "BotMinHealth",
			Text = "Bot Min Health at spawn",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.BotMinHealth,
			Description = "Min health of bot at spawn (default 100.0)",
			Reference = Range(0.0, 1000.00, 1.0),
			Default = 75.0,
			UpdateFlag = UpdateFlag.Wave,
			Category = "DIFFICULTY"
		},
		{
			Name = "BotHeadshotDamageMultiplier",
			Text = "Bot Headshot DamageMultiplier",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.BotHeadshotDamageMultiplier,
			Description = "Damage multiplier for shooting bots in the head",
			Reference = Range(0.0, 100.00, 0.1),
			Default = 2.0,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "BotWorseningSkill",
			Text = "Bot Worsening Skill",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.BotWorseningSkill,
			Description = "Variation of the skill of a single bot. The higher, the worse the bots can get compared to the original settings",
			Reference = Range(0.00, 1.00, 0.05),
			Default = 0.50,
			UpdateFlag = UpdateFlag.Skill,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorKnife",
			Text = "Damage Factor Knife",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.DamageFactorKnife,
			Description = "Original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 5.00, 0.10),
			Default = 1.5,
			UpdateFlag = UpdateFlag.Wave,
			Category = "DIFFICULTY"
		},
		{
			Name = "SpeedFactorAttack",
			Text = "Speed factor attack",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.SpeedFactorAttack,
			Description = "Modifies the speed while attacking. 1 = normal",
			Reference = Range(0.00, 3.00, 0.10),
			Default = 1.2,
			UpdateFlag = UpdateFlag.Wave,
			Category = "DIFFICULTY"
		},
		{
			Name = "MinSpeedFactorAttack",
			Text = "Min Speed factor attack",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.MinSpeedFactorAttack,
			Description = "Modifies the minimal speed while attacking. 1 = normal",
			Reference = Range(0.00, 3.00, 0.10),
			Default = 0.5,
			UpdateFlag = UpdateFlag.Wave,
			Category = "DIFFICULTY"
		},
		{
			Name = "MinHighJumpSpeed",
			Text = "Min High Jump Speed",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.MinHighJumpSpeed,
			Description = "Min Speed the bots jump with on high-jumps",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 5.0,
			UpdateFlag = UpdateFlag.Wave,
			Category = "DIFFICULTY"
		},
		{
			Name = "MaxHighJumpSpeed",
			Text = "Max High Jump Speed",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.MaxHighJumpSpeed,
			Description = "Max Speed the bots jump with on high-jumps",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 12.0,
			UpdateFlag = UpdateFlag.Wave,
			Category = "DIFFICULTY"
		},

		-- Spawn.
		{
			Name = "SpawnMode",
			Text = "Spawn Mode",
			---@type Type|integer
			Type = Type.Enum,
			Value = Config.SpawnMode,
			Description = "Mode the bots spawn with",
			Reference = SpawnModes,
			Default = SpawnModes.wave_spawn,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "InitNumberOfBots",
			Text = "Start Number of Bots",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.InitNumberOfBots,
			Description = "Bots for spawnmode",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 0,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "NewBotsPerNewPlayer",
			Text = "New Bots per Player",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.NewBotsPerNewPlayer,
			Description = "Number to increase Bots by when new players join",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 5,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "FactorPlayerTeamCount",
			Text = "Factor Player Team Count",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.FactorPlayerTeamCount,
			Description = "Reduce player team in balanced_teams or fixed_number mode",
			Reference = Range(0.00, 1.00, 0.05),
			Default = 0.2,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "BotTeam",
			Text = "Team of the Bots",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.BotTeam,
			Description = "Default bot team (0 = neutral / auto, 1 = US, 2 = RU) TeamId.Team2",
			Reference = Range(0.00, 4.00, 1.0),
			Default = 2,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "BotNewLoadoutOnSpawn",
			Text = "New Loadout on Spawn",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.BotNewLoadoutOnSpawn,
			Description = "Bots get a new kit and color, if they respawn",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxAssaultBots",
			Text = "Max Assault Bots",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxAssaultBots,
			Description = "Maximum number of Bots with Assault Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxEngineerBots",
			Text = "Max Engineer Bots",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxEngineerBots,
			Description = "Maximum number of Bots with Engineer Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxSupportBots",
			Text = "Max Support Bots",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxSupportBots,
			Description = "Maximum number of Bots with Support Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxReconBots",
			Text = "Max Recon Bots",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxReconBots,
			Description = "Maximum number of Bots with Recon Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "AdditionalBotSpawnDelay",
			Text = "Additional Spawn Delay",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.AdditionalBotSpawnDelay,
			Description = "Additional time a bot waits to respawn",
			Reference = Range(0.0, 60.00, 0.5),
			Default = 0.1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxBotsPerTeamDefault",
			Text = "Max Bots Per Team (default)",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamDefault,
			Description = "Max number of bots in one team, if no other mode fits",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 128,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		-- Waves
		{
			Name = "Waves",
			Text = "Max waves",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.Waves,
			Description = "Total amount of waves needed to win. 0 = infinite",
			Reference = Range(0.00, 999.00, 1.0),
			Default = 20,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "PlayerLives",
			Text = "Player Lives",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.PlayerLives,
			Description = "Amount of times players can die before losing",
			Reference = Range(1.00, 1000.0, 1.0),
			Default = 20,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "FirstWaveCount",
			Text = "Zombies in first Wave",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.FirstWaveCount,
			Description = "Zombies that spawn in the first wave",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 30,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "IncrementZombiesPerWave",
			Text = "Additional Zombies per wave",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.IncrementZombiesPerWave,
			Description = "Zombies that are added in each new wave",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 10,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "IncrementMaxHealthPerWave",
			Text = "Additional Max Health per wave",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.IncrementMaxHealthPerWave,
			Description = "Zombies get more health each wave",
			Reference = Range(0.00, 500.00, 1.0),
			Default = 25,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "IncrementDamageFactorPerWave",
			Text = "Additional Damage of Zombies per wave",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.IncrementDamageFactorPerWave,
			Description = "Zombies deal more damage each wave",
			Reference = Range(0.00, 2.00, 0.05),
			Default = 0.1,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "IncrementMaxSpeedPerWave",
			Text = "Additional Speed for Attack",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.IncrementMaxSpeedPerWave,
			Description = "Zombies get more speed each wave",
			Reference = Range(0.00, 5.00, 1.0),
			Default = 0.05,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "IncrementJumpSpeedPerWave",
			Text = "Additional High-Jump-Speed for Attack",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.IncrementJumpSpeedPerWave,
			Description = "Zombies get more speed each wave",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 3.0,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "SubtractSpawnDistancePerWave",
			Text = "Decrease spawn distance per wave",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.SubtractSpawnDistancePerWave,
			Description = "Decreases the spawn distance each wave. This can help sell the effect of a continuous wave when the server slot limit is reached",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 1.0,
			UpdateFlag = UpdateFlag.Wave,
			Category = "WAVES"
		},
		{
			Name = "ZombiesAliveForNextWave",
			Text = "Zombies alive for next wave",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.ZombiesAliveForNextWave,
			Description = "New wave is triggered when this number of zombies is reached",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 5,
			UpdateFlag = UpdateFlag.None,
			Category = "WAVES"
		},
		{
			Name = "TimeBetweenWaves",
			Text = "Time between waves",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.TimeBetweenWaves,
			Description = "Time in seconds between two waves",
			Reference = Range(0.00, 60.00, 1.0),
			Default = 7.0,
			UpdateFlag = UpdateFlag.None,
			Category = "WAVES"
		},
		{
			Name = "KillRemainingZombiesAfterWave",
			Text = "kill remaining zombies after wave",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.KillRemainingZombiesAfterWave,
			Description = "Remaining Bots Get Killed before a new wave starts",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "WAVES"
		},

		-- Bot behaviour.
		{
			Name = "FovForShooting",
			Text = "FOV of Bots",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.FovForShooting,
			Description = "Degrees of FOV of Bot",
			Reference = Range(0.00, 360.00, 1.0),
			Default = 270,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "FovVerticleForShooting",
			Text = "FOV of Bots Verticle",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.FovVerticleForShooting,
			Description = "Degrees of FOV of Bot in vertical direction",
			Reference = Range(0.00, 180.00, 1.0),
			Default = 270,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MaxShootDistance",
			Text = "Max Shoot-Distance No Sniper",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxShootDistance,
			Description = "Meters before bots (not sniper) will start shooting at players",
			Reference = Range(1.00, 1500.00, 5.0),
			Default = 125,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MaxDistanceShootBack",
			Text = "Max Distance a normal soldier shoots back if Hit",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxDistanceShootBack,
			Description = "Meters until bots (not sniper) shoot back if hit",
			Reference = Range(1.00, 1500.00, 5.0),
			Default = 150,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotAttackMode",
			Text = "Bot Attack Mode",
			---@type Type|integer
			Type = Type.Enum,
			Value = Config.BotAttackMode,
			Description = "Mode the Bots attack with. Random, Crouch or Stand",
			Reference = BotAttackModes,
			Default = BotAttackModes.RandomNotSet,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "ShootBackIfHit",
			Text = "Shoot Back if Hit",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.ShootBackIfHit,
			Description = "Bot shoots back if hit",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotsAttackPlayers",
			Text = "Bots Attack Players",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.BotsAttackPlayers,
			Description = "Bots attack Players from other team",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotCanKillHimself",
			Text = "Bots can kill themselves",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.BotCanKillHimself,
			Description = "Bot takes fall damage or explosion-damage from own frags",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "TeleportIfStuck",
			Text = "Bots teleport them when stuck",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.TeleportIfStuck,
			Description = "Bot teleport to their target if they are stuck",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "SnipersAttackChoppers",
			Text = "Snipers attack choppers",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.SnipersAttackChoppers,
			Description = "Bots with sniper-rifels attack choppers",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},

		-- Weapons.
		{
			Name = "UseRandomWeapon",
			Text = "Random Weapon usage",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.UseRandomWeapon,
			Description = "Use a random weapon out of the Weapon Set",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},
		{
			Name = "Knife",
			Text = "Knife of Bots",
			---@type Type|integer
			Type = Type.DynamicList,
			Value = Config.Knife,
			Description = "Knife of Bots, if random-weapon == false",
			Reference = "KnifeWeapons",
			Default = "Knife",
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},

		-- Traces.
		{
			Name = "DebugTracePaths",
			Text = "Debug Trace Paths",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DebugTracePaths,
			Description = "Shows the trace line and search area from Commo Rose selection",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "WaypointRange",
			Text = "Waypoint Range",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.WaypointRange,
			Description = "Set how far away waypoints are visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 50,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "DrawWaypointLines",
			Text = "Draw Waypoint Lines",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DrawWaypointLines,
			Description = "Draw waypoint connection lines",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "LineRange",
			Text = "Line Range",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.LineRange,
			Description = "Set how far away waypoint lines are visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 25,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "DrawWaypointIDs",
			Text = "Draw Waypoint IDs",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DrawWaypointIDs,
			Description = "Draw the IDs of the waypoints",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "TextRange",
			Text = "Text Range",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.TextRange,
			Description = "Set how far away waypoint text is visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 7,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "DrawSpawnPoints",
			Text = "Draw Spawn Points",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DrawSpawnPoints,
			Description = "Draw the Points where players can spawn",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "SpawnPointRange",
			Text = "Range of Spawn Points",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.SpawnPointRange,
			Description = "Set how far away spawn points are visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 100,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "TraceDelta",
			Text = "Trace Delta Points",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.TraceDelta,
			Description = "Update interval of trace",
			Reference = Range(0.10, 10.00, 0.1),
			Default = 0.3,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "NodesPerCycle",
			Text = "Nodes that are drawn per cycle",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.NodesPerCycle,
			Description = "Set how many nodes get drawn per cycle. Affects performance",
			Reference = Range(1.00, 10000.00, 1.0),
			Default = 400,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		-- Advanced properties.
		{
			Name = "DistanceForDirectAttack",
			Text = "Distance for direct attack",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.DistanceForDirectAttack,
			Description = "Distance bots can hear you at",
			Reference = Range(0.00, 1000.00, 1.0),
			Default = 8,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "MeleeAttackCoolDown",
			Text = "Bot melee attack cool-down",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.MeleeAttackCoolDown,
			Description = "The time a bot waits before attacking with melee again",
			Reference = Range(0.00, 60.00, 0.5),
			Default = 1.5,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "JumpWhileShooting",
			Text = "Jump while shooting",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.JumpWhileShooting,
			Description = "Bots jump over obstacles while shooting if needed",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "JumpWhileMoving",
			Text = "Jump while moving",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.JumpWhileMoving,
			Description = "Bots jump while moving. If false, only on obstacles!",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "OverWriteBotSpeedMode",
			Text = "Overwrite speed mode",
			---@type Type|integer
			Type = Type.Enum,
			Value = Config.OverWriteBotSpeedMode,
			Description = "0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run",
			Reference = BotMoveSpeeds,
			Default = BotMoveSpeeds.NoMovement,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "SpeedFactor",
			Text = "Speed factor",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.SpeedFactor,
			Description = "Reduces the movement speed. 1 = normal, 0 = standing",
			Reference = Range(0.00, 1.00, 0.10),
			Default = 1.0,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "UseRandomNames",
			Text = "Use Random Names",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.UseRandomNames,
			Description = "Changes names of the bots on every new round. Experimental right now...",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "MoveSidewards",
			Text = "Move Sidewards",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.MoveSidewards,
			Description = "Bots move sidewards",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "MaxStraigtCycle",
			Text = "Max straight Cycle",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.MaxStraigtCycle,
			Description = "Max time bots move straight, before sidewards-movement (in sec)",
			Reference = Range(1.00, 60.00, 1.0),
			Default = 10.0,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "MaxSideCycle",
			Text = "Max Side Cycle",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.MaxSideCycle,
			Description = "Max time bots move sidewards, before straight-movement (in sec)",
			Reference = Range(1.00, 60.00, 1.0),
			Default = 5.0,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "MinMoveCycle",
			Text = "Min Move Cycle",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.MinMoveCycle,
			Description = "Min time bots move sidewards or straight before switching (in sec)",
			Reference = Range(0.30, 10.00, 0.5),
			Default = 0.3,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},

		-- Expert Properties.
		{
			Name = "BotMinTimeAttackOnePlayer",
			Text = "Bot min time Attack one player",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.BotMinTimeAttackOnePlayer,
			Description = "The minimum time a bot attacks one player for",
			Reference = Range(0.00, 60.00, 0.5),
			Default = 1.0,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "BotAttackDuration",
			Text = "Bot attack mode duration",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.BotAttackDuration,
			Description = "The minimum time a zombie-bot tries to attack a player - recommended minimum 15,",
			Reference = Range(0.00, 120.00, 0.5),
			Default = 20,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "MaximunYawPerSec",
			Text = "Maximum yaw per sec",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaximunYawPerSec,
			Description = "In Degrees. Rotation Movement per second",
			Reference = Range(0.00, 1080.00, 5.0),
			Default = 450,
			UpdateFlag = UpdateFlag.YawPerSec,
			Category = "EXPERT"
		},
		{
			Name = "TargetDistanceWayPoint",
			Text = "Target distance waypoint",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.TargetDistanceWayPoint,
			Description = "The distance the bots have to reach to continue with the next Waypoint",
			Reference = Range(0.00, 100.00, 0.10),
			Default = 0.8,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "KeepOneSlotForPlayers",
			Text = "Keep one slot for players",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.KeepOneSlotForPlayers,
			Description = "Always keep one slot for free new Players to join",
			Default = true,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "EXPERT"
		},
		{
			Name = "DistanceToSpawnBots",
			Text = "Distance to spawn",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.DistanceToSpawnBots,
			Description = "Distance to spawn Bots away from players",
			Reference = Range(0.00, 100.00, 5.0),
			Default = 30,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "HeightDistanceToSpawn",
			Text = "Height distance to spawn",
			---@type Type|integer
			Type = Type.Float,
			Value = Config.HeightDistanceToSpawn,
			Description = "Distance vertically, Bots should spawn away, if closer than distance",
			Reference = Range(0.00, 100.00, 0.10),
			Default = 2.8,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "DistanceToSpawnReduction",
			Text = "Distance to spawn reduction",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.DistanceToSpawnReduction,
			Description = "Reduce distance if not possible",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 5,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "MaxTrysToSpawnAtDistance",
			Text = "Max tries to spawn at distance",
			---@type Type|integer
			Type = Type.Integer,
			Value = Config.MaxTrysToSpawnAtDistance,
			Description = "Try this often to spawn a bot away from players",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 3,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "AttackWayBots",
			Text = "Attack way Bots",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.AttackWayBots,
			Description = "Bots on paths attack player",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "RespawnWayBots",
			Text = "Respawn way Bots",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.RespawnWayBots,
			Description = "Bots on paths respawn if killed",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "SpawnMethod",
			Text = "Spawn Method",
			---@type Type|integer
			Type = Type.Enum,
			Value = Config.SpawnMethod,
			Description = "Method the bots spawn with. Careful, not supported on most of the maps!!",
			Reference = SpawnMethod,
			Default = SpawnMethod.SpawnSoldierAt,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},

		-- Other Stuff.
		{
			Name = "DisableUserInterface",
			Text = "Disable UI",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DisableUserInterface,
			Description = "If true, the complete UI will be disabled (not available in the UI)",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "AllowCommForAll",
			Text = "Allow Comm-UI for all",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DisableUserInterface,
			Description = "If true, all Players can access the Comm-Screen",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "DisableChatCommands",
			Text = "Disable chat-commands",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DisableChatCommands,
			Description = "If true, no chat commands can be used",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "DisableRCONCommands",
			Text = "Disable RCON-commands",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.DisableRCONCommands,
			Description = "If true, no RCON commands can be used",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "IgnorePermissions",
			Text = "Ignore Permissions",
			---@type Type|integer
			Type = Type.Boolean,
			Value = Config.IgnorePermissions,
			Description = "If true, all permissions are ignored --> everyone can do everything",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "Language",
			Text = "Language",
			---@type Type|integer
			Type = Type.List,
			Value = Config.Language,
			Description = "de_DE as sample (default is English, when language file does not exist)",
			Default = nil,
			Reference = Languages,
			UpdateFlag = UpdateFlag.Language,
			Category = "OTHER"
		}
	}
}
