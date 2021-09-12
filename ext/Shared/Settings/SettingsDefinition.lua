--[[
	@property: SettingsDefinition
]]
SettingsDefinition = {
	--[[
		@property: Categorys
	]]
	Categorys = {
		GENERAL = "General",
		DIFFICULTY = "Difficulty",
		SPAWN = "Spawn",
		SPAWNLIMITS = "Spawnlimits",
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
		-- General
		{
			Name = "BotWeapon",
			Text = "Bot Weapon",
			Type = Type.Enum,
			Value = Config.BotWeapon,
			Reference = BotWeapons,
			Description = "Select the weapon the bots use",
			Default = BotWeapons.Auto,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "BotKit",
			Text = "Bot Kit",
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
			Type = Type.Enum,
			Reference = BotColors,
			Value = Config.BotColor,
			Description = "The Color of the Bots",
			Default = BotColors.RANDOM_COLOR,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},
		{
			Name = "ZombieMode",
			Text = "Zombie Mode",
			Type = Type.Boolean,
			Value = Config.ZombieMode,
			Description = "Zombie Bot Mode",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "GENERAL"
		},

		-- Difficulty
		{
			Name = "BotAimWorsening",
			Text = "Bot Aim Worsening",
			Type = Type.Float,
			Value = Config.BotAimWorsening,
			Description = "make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy).",
			Reference = Range(0.00, 10.00, 0,05),
			Default = 0.5,
			UpdateFlag = UpdateFlag.Weapons,
			Category = "DIFFICULTY"
		},
		{
			Name = "BotSniperAimWorsening",
			Text = "Bot Aim Worsening of Snipers",
			Type = Type.Float,
			Value = Config.BotSniperAimWorsening,
			Description = "see botAimWorsening, only for Sniper-rifles",
			Reference = Range(0.00, 10.00, 0,05),
			Default = 0.2,
			UpdateFlag = UpdateFlag.Weapons,
			Category = "DIFFICULTY"
		},
		{
			Name = "BotSupportAimWorsening",
			Text = "Bot Aim Worsening of Support",
			Type = Type.Float,
			Value = Config.BotSupportAimWorsening,
			Description = "see botAimWorsening, only for LMGs",
			Reference = Range(0.00, 10.00, 0,05),
			Default = 0.2,
			UpdateFlag = UpdateFlag.Weapons,
			Category = "DIFFICULTY"
		},
		{
			Name = "BotWorseningSkill",
			Text = "Bot Worsening Skill",
			Type = Type.Float,
			Value = Config.BotWorseningSkill,
			Description = "variation of the skill of a single bot. the higher, the worse the bots can get compared to the original settings",
			Reference = Range(0.00, 1.00, 0,05),
			Default = 0.25,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "BotSniperWorseningSkill",
			Text = "Bot Sniper Worsening Skill",
			Type = Type.Float,
			Value = Config.BotSniperWorseningSkill,
			Description = "see BotWorseningSkill - only for BOTs using sniper bolt-action rifles.",
			Reference = Range(0.00, 1.00, 0,05),
			Default = 0.50,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorAssault",
			Text = "Damage Factor Assault",
			Type = Type.Float,
			Value = Config.DamageFactorAssault,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 0.5,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorCarabine",
			Text = "Damage Factor Carabine",
			Type = Type.Float,
			Value = Config.DamageFactorCarabine,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 0.5,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorLMG",
			Text = "Damage Factor LMG",
			Type = Type.Float,
			Value = Config.DamageFactorLMG,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 0.5,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorPDW",
			Text = "Damage Factor PDW",
			Type = Type.Float,
			Value = Config.DamageFactorPDW,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 0.5,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorSniper",
			Text = "Damage Factor Sniper",
			Type = Type.Float,
			Value = Config.DamageFactorSniper,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 0.8,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorShotgun",
			Text = "Damage Factor Shotgun",
			Type = Type.Float,
			Value = Config.DamageFactorShotgun,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 0.8,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorPistol",
			Text = "Damage Factor Pistol",
			Type = Type.Float,
			Value = Config.DamageFactorPistol,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 0.7,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},
		{
			Name = "DamageFactorKnife",
			Text = "Damage Factor Knife",
			Type = Type.Float,
			Value = Config.DamageFactorKnife,
			Description = "original Damage from bots gets multiplied by this",
			Reference = Range(0.00, 2.00, 0,10),
			Default = 1.5,
			UpdateFlag = UpdateFlag.None,
			Category = "DIFFICULTY"
		},

		-- Spawn
		{
			Name = "SpawnMode",
			Text = "Spawn Mode",
			Type = Type.Enum,
			Value = Config.SpawnMode,
			Description = "mode the bots spawn with",
			Reference = SpawnModes,
			Default = SpawnModes.balanced_teams,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "TeamSwitchMode",
			Text = "Team Switch Mode",
			Type = Type.Enum,
			Value = Config.TeamSwitchMode,
			Description = "Mode to switch the team",
			Reference = TeamSwitcheModes,
			Default = TeamSwitcheModes.SwitchForRoundTwo,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "SpawnInBothTeams",
			Text = "Spawn Bots in all teams",
			Type = Type.Boolean,
			Value = Config.SpawnInBothTeams,
			Description = "Bots spawn in both teams",
			Default = true,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "InitNumberOfBots",
			Text = "Start Number of Bots",
			Type = Type.Integer,
			Value = Config.InitNumberOfBots,
			Description = "bots for spawnmode",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 6,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "NewBotsPerNewPlayer",
			Text = "New Bots per Player",
			Type = Type.Float,
			Value = Config.NewBotsPerNewPlayer,
			Description = "number to increase Bots, when new players join",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 1.6,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "FactorPlayerTeamCount",
			Text = "Factor Player Team Count",
			Type = Type.Float,
			Value = Config.FactorPlayerTeamCount,
			Description = "reduce playerteam in balanced_teams or fixed_number mode",
			Reference = Range(0.00, 1.00, 0.05),
			Default = 0.8,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "BotTeam",
			Text = "Team of the Bots",
			Type = Type.Integer,
			Value = Config.BotTeam,
			Description = "default bot team (0 = neutral / auto, 1 = US, 2 = RU) TeamId.Team2",
			Reference = Range(0.00, 4.00, 1.0),
			Default = 0,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "SPAWN"
		},
		{
			Name = "BotNewLoadoutOnSpawn",
			Text = "New Loadout on Spawn",
			Type = Type.Boolean,
			Value = Config.BotNewLoadoutOnSpawn,
			Description = "bots get a new kit and color, if they respawn",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxAssaultBots",
			Text = "Max Assault Bots",
			Type = Type.Integer,
			Value = Config.MaxAssaultBots,
			Description = "maximum number of Bots with Assault Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxEngineerBots",
			Text = "Max Engineer Bots",
			Type = Type.Integer,
			Value = Config.MaxEngineerBots,
			Description = "maximum number of Bots with Engineer Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxSupportBots",
			Text = "Max Support Bots",
			Type = Type.Integer,
			Value = Config.MaxSupportBots,
			Description = "maximum number of Bots with Support Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "MaxReconBots",
			Text = "Max Support Bots",
			Type = Type.Integer,
			Value = Config.MaxReconBots,
			Description = "maximum number of Bots with Recon Kit. -1 = no limit",
			Reference = Range(-1.00, 128.00, 1.0),
			Default = -1,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "AdditionalBotSpawnDelay",
			Text = "Additional Spawn Delay",
			Type = Type.Float,
			Value = Config.AdditionalBotSpawnDelay,
			Description = "additional time a bot waits to respawn",
			Reference = Range(0.0, 60.00, 0.5),
			Default = 0.5,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},
		{
			Name = "BotMaxHealth",
			Text = "Bot Health at spawn",
			Type = Type.Float,
			Value = Config.BotMaxHealth,
			Description = "max health of bot (default 100.0)",
			Reference = Range(0.0, 1000.00, 1.0),
			Default = 100.0,
			UpdateFlag = UpdateFlag.None,
			Category = "SPAWN"
		},

	-- Spawn limits
		{
			Name = "MaxBotsPerTeamDefault",
			Text = "Max Bots Per Team (default)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamDefault,
			Description = "max number of bots in one team, if no other mode fits",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 32,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamTdm",
			Text = "Max Bots Per Team (TDM)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamTdm,
			Description = "max number of bots in one team for TDM",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 32,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamTdmc",
			Text = "Max Bots Per Team (TDM-CQ)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamTdmc,
			Description = "max number of bots in one team for TDM-CQ",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 8,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamSdm",
			Text = "Max Bots Per Team (Squad-DM)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamSdm,
			Description = "max number of bots in one team for Squad-DM",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 5,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamCl",
			Text = "Max Bots Per Team (CQ-Large)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamCl,
			Description = "max number of bots in one team for CQ-Large",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 32,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamCs",
			Text = "Max Bots Per Team (CQ-Small)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamCs,
			Description = "max number of bots in one team for CQ-Small",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 16,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamCal",
			Text = "Max Bots Per Team (CQ-Assault-Large)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamCal,
			Description = "max number of bots in one team for CQ-Assault-Large",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 32,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamCas",
			Text = "Max Bots Per Team (CQ-Assault-Small)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamCas,
			Description = "max number of bots in one team for CQ-Assault-Small",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 16,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamRl",
			Text = "Max Bots Per Team (Rush)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamRl,
			Description = "max number of bots in one team for Rush",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 24,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamCtf",
			Text = "Max Bots Per Team (CTF)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamCtf,
			Description = "max number of bots in one team for CTF",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 24,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamD",
			Text = "Max Bots Per Team (Domination)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamD,
			Description = "max number of bots in one team for Domination",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 12,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamGm",
			Text = "Max Bots Per Team (Gunmaster)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamGm,
			Description = "max number of bots in one team for Gunmaster",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 12,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},
		{
			Name = "MaxBotsPerTeamS",
			Text = "Max Bots Per Team (Scavenger)",
			Type = Type.Integer,
			Value = Config.MaxBotsPerTeamS,
			Description = "max number of bots in one team for Scavenger",
			Reference = Range(0.00, 128.00, 1.0),
			Default = 12,
			UpdateFlag = UpdateFlag.MaxBots,
			Category = "SPAWNLIMITS"
		},

		-- Bot behaviour
		{
			Name = "FovForShooting",
			Text = "FOV of Bots",
			Type = Type.Integer,
			Value = Config.FovForShooting,
			Description = "Degrees of FOV of Bot",
			Reference = Range(0.00, 360.00, 1.0),
			Default = 180,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "FovVerticleForShooting",
			Text = "FOV of Bots Verticle",
			Type = Type.Integer,
			Value = Config.FovVerticleForShooting,
			Description = "Degrees of FOV of Bot in verticle  direction",
			Reference = Range(0.00, 180.00, 1.0),
			Default = 90,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MaxRaycastDistance",
			Text = "Max Raycast Distance",
			Type = Type.Integer,
			Value = Config.MaxRaycastDistance,
			Description = "meters bots start shooting at player",
			Reference = Range(1.00, 1500.00, 5.0),
			Default = 150,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MaxShootDistanceNoSniper",
			Text = "Max Shoot-Distance No Sniper",
			Type = Type.Integer,
			Value = Config.MaxShootDistanceNoSniper,
			Description = "meters a bot (not sniper) start shooting at player",
			Reference = Range(1.00, 1500.00, 5.0),
			Default = 70,
			UpdateFlag = UpdateFlag.None,
			Category ="BEHAVIOUR"
		},
		{
			Name = "MaxShootDistancePistol",
			Text = "Max Shoot-Distance Pistol",
			Type = Type.Integer,
			Value = Config.MaxShootDistancePistol,
			Description = "only in auto-weapon-mode, the distance until a bot switches to pistol if his magazine is empty",
			Reference = Range(1.00, 1500.00, 5.0),
			Default = 30,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotAttackMode",
			Text = "Bot Attack Mode",
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
			Type = Type.Boolean,
			Value = Config.ShootBackIfHit,
			Description = "bot shoots back, if hit",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotsAttackBots",
			Text = "Bots Attack Bots",
			Type = Type.Boolean,
			Value = Config.BotsAttackBots,
			Description = "bots attack bots from other team",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MeleeAttackIfClose",
			Text = "Melee Attack If Close",
			Type = Type.Boolean,
			Value = Config.MeleeAttackIfClose,
			Description = "bot attacks with melee if close",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotCanKillHimself",
			Text = "Bots can kill themself",
			Type = Type.Boolean,
			Value = Config.BotCanKillHimself,
			Description = "bot takes falldamage or explosion-damage from onw frags",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "TeleportIfStuck",
			Text = "Bots teleport them when stuck",
			Type = Type.Boolean,
			Value = Config.TeleportIfStuck,
			Description = "bot teleport to their target if stuck",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotsRevive",
			Text = "Bots revive players",
			Type = Type.Boolean,
			Value = Config.BotsRevive,
			Description = "Bots revive other players",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotsThrowGrenades",
			Text = "Bots throw grenades",
			Type = Type.Boolean,
			Value = Config.BotsThrowGrenades,
			Description = "Bots throw grenades",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "BotsDeploy",
			Text = "Bots deploy bags",
			Type = Type.Boolean,
			Value = Config.BotsDeploy,
			Description = "Bots deploy ammo and medkits",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "DeployCycle",
			Text = "Deploy Cycle",
			Type = Type.Integer,
			Value = Config.DeployCycle,
			Description = "time between deployment of bots in seconds",
			Reference = Range(1.00, 600.00, 5.0),
			Default = 50,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MoveSidewards",
			Text = "Move Sidewards",
			Type = Type.Boolean,
			Value = Config.MoveSidewards,
			Description = "Bots move sidewards",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MaxStraigtCycle",
			Text = "Max straight Cycle",
			Type = Type.Float,
			Value = Config.MaxStraigtCycle,
			Description = "max time bots move straigt, before sidewares-movement (in sec)",
			Reference = Range(1.00, 60.00, 1.0),
			Default = 10.0,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MaxSideCycle",
			Text = "Max Side Cycle",
			Type = Type.Float,
			Value = Config.MaxSideCycle,
			Description = "max time bots move sidewards, before straight-movement (in sec)",
			Reference = Range(1.00, 60.00, 1.0),
			Default = 5.0,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		{
			Name = "MinMoveCycle",
			Text = "min Move Cycle",
			Type = Type.Float,
			Value = Config.MinMoveCycle,
			Description = "min time bots move sidewards or staight before switching (in sec)",
			Reference = Range(0.30, 10.00, 0.5),
			Default = 0.5,
			UpdateFlag = UpdateFlag.None,
			Category = "BEHAVIOUR"
		},
		
		-- Vehicles behaviour
		{
			Name = "UseVehicles",
			Text = "Use vehicles",
			Type = Type.Boolean,
			Value = Config.UseVehicles,
			Description = "Bots use vehicles",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		{
			Name = "FovVehicleForShooting",
			Text = "FOV of Vehicles",
			Type = Type.Integer,
			Value = Config.FovForShooting,
			Description = "Degrees of FOV of Non AA - Vehicles",
			Reference = Range(0.00, 360.00, 1.0),
			Default = 180,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		{
			Name = "FovVerticleVehicleForShooting",
			Text = "FOV of Vehicles Verticle",
			Type = Type.Integer,
			Value = Config.FovVerticleVehicleForShooting,
			Description = "Degrees of FOV of Non AA-Vehicles",
			Reference = Range(0.00, 180.00, 1.0),
			Default = 60,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		{
			Name = "FovVerticleChopperForShooting",
			Text = "FOV of Chopper Verticle",
			Type = Type.Integer,
			Value = Config.FovVerticleChopperForShooting,
			Description = "Degrees of pitch a chopper attacks",
			Reference = Range(0.00, 180.00, 1.0),
			Default = 80,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		{
			Name = "FovVehicleAAForShooting",
			Text = "FOV of AA-Vehicles",
			Type = Type.Integer,
			Value = Config.FovVehicleAAForShooting,
			Description = "Degrees of FOV of AA - Vehicles",
			Reference = Range(0.00, 360.00, 1.0),
			Default = 360,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		{
			Name = "FovVerticleVehicleAAForShooting",
			Text = "FOV of AA-Vehicles Verticle",
			Type = Type.Integer,
			Value = Config.FovVerticleVehicleAAForShooting,
			Description = "Degrees of FOV of AA-Vehicles",
			Reference = Range(0.00, 180.00, 1.0),
			Default = 160,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		{
			Name = "MaxRaycastDistanceVehicles",
			Text = "Max Raycast Distance for Vehicles",
			Type = Type.Integer,
			Value = Config.MaxRaycastDistance,
			Description = "meters bots in Vehicles start shooting at player",
			Reference = Range(1.00, 1500.00, 5.0),
			Default = 250,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		{
			Name = "MaxShootDistanceNoAntiAir",
			Text = "Max Shoot-Distance No Anti Air",
			Type = Type.Integer,
			Value = Config.MaxShootDistanceNoAntiAir,
			Description = "meters a vehicle (no Anti-Air) starts shooting at player",
			Reference = Range(1.00, 1500.00, 5.0),
			Default = 150,
			UpdateFlag = UpdateFlag.None,
			Category ="VEHICLE"
		},
		{
			Name = "VehicleWaitForPassengersTime",
			Text = "Time a vehicle driver waits for passengers",
			Type = Type.Float,
			Value = Config.VehicleWaitForPassengersTime,
			Description = "seconds to wait for other passengers",
			Reference = Range(0.50, 60.00, 0.5),
			Default = 7.0,
			UpdateFlag = UpdateFlag.None,
			Category ="VEHICLE"
		},
		{
			Name = "ChopperDriversAttack",
			Text = "Choppers Attack",
			Type = Type.Boolean,
			Value = Config.ChopperDriversAttack,
			Description = "if false choppers only attack without gunner on board",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "VEHICLE"
		},
		-- Weapons
		{
			Name = "UseRandomWeapon",
			Text = "Random Weapon usage",
			Type = Type.Boolean,
			Value = Config.UseRandomWeapon,
			Description = "use a random weapon out of the weapon set",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},
		{
			Name = "AssaultWeaponSet",
			Text = "Weapon Set Assault",
			Type = Type.Enum,
			Value = Config.AssaultWeaponSet,
			Description = "weaponset of Assault class. Custom uses the Shared/WeaponLists",
			Reference = WeaponSets,
			Default = WeaponSets.Custom,
			UpdateFlag = UpdateFlag.WeaponSets,
			Category = "WEAPONS"
		},
		{
			Name = "EngineerWeaponSet",
			Text = "Weapon Set Engineer",
			Type = Type.Enum,
			Value = Config.EngineerWeaponSet,
			Description = "weaponset of Engineer class. Custom uses the Shared/WeaponLists",
			Reference = WeaponSets,
			Default = WeaponSets.Custom,
			UpdateFlag = UpdateFlag.WeaponSets,
			Category = "WEAPONS"
		},
		{
			Name = "SupportWeaponSet",
			Text = "Weapon Set Support",
			Type = Type.Enum,
			Value = Config.SupportWeaponSet,
			Description = "weaponset of Support class. Custom uses the Shared/WeaponLists",
			Reference = WeaponSets,
			Default = WeaponSets.Custom,
			UpdateFlag = UpdateFlag.WeaponSets,
			Category = "WEAPONS"
		},
		{
			Name = "ReconWeaponSet",
			Text = "Weapon Set Recon",
			Type = Type.Enum,
			Value = Config.ReconWeaponSet,
			Description = "weaponset of Recon class. Custom uses the Shared/WeaponLists",
			Reference = WeaponSets,
			Default = WeaponSets.Custom,
			UpdateFlag = UpdateFlag.WeaponSets,
			Category = "WEAPONS"
		},
		{
			Name = "AssaultWeapon",
			Text = "Primary Weapon Assault",
			Type = Type.Table,
			Value = Config.AssaultWeapon,
			Description = "primary weapon of Assault class, if random-weapon == false",
			Reference = AssaultPrimary,
			Default = "M416",
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},
		{
			Name = "EngineerWeapon",
			Text = "Primary Weapon Engineer",
			Type = Type.Table,
			Value = Config.EngineerWeapon,
			Description = "primary weapon of Engineer class, if random-weapon == false",
			Reference = EngineerPrimary,
			Default = "M4A1",
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},
		{
			Name = "SupportWeapon",
			Text = "Primary Weapon Support",
			Type = Type.Table,
			Value = Config.SupportWeapon,
			Description = "primary weapon of Support class, if random-weapon == false",
			Reference = SupportPrimary,
			Default = "M249",
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},
		{
			Name = "ReconWeapon",
			Text = "Primary Weapon Recon",
			Type = Type.Table,
			Value = Config.ReconWeapon,
			Description = "primary weapon of Recon class, if random-weapon == false",
			Reference = ReconPrimary,
			Default = "L96",
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},
		{
			Name = "Pistol",
			Text = "Pistol of Bots",
			Type = Type.Table,
			Value = Config.Pistol,
			Description = "Pistol of Bots, if random-weapon == false",
			Reference = PistoWeapons,
			Default = "MP412Rex",
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},
		{
			Name = "Knife",
			Text = "Knife of Bots",
			Type = Type.Table,
			Value = Config.Knife,
			Description = "Knife of Bots, if random-weapon == false",
			Reference = KnifeWeapons,
			Default = "Razor",
			UpdateFlag = UpdateFlag.None,
			Category = "WEAPONS"
		},

		-- Traces
		{
			Name = "DebugTracePaths",
			Text = "Debug Trace Paths",
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
			Type = Type.Integer,
			Value = Config.WaypointRange,
			Description = "Set how far away waypoints are visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 100,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "DrawWaypointLines",
			Text = "Draw Waypoint Lines",
			Type = Type.Boolean,
			Value = Config.DrawWaypointLines,
			Description = "Draw waypoint connection Lines",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "LineRange",
			Text = "Line Range",
			Type = Type.Integer,
			Value = Config.LineRange,
			Description = "Set how far away waypoint lines are visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 15,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "DrawWaypointIDs",
			Text = "Draw Waypoint IDs",
			Type = Type.Boolean,
			Value = Config.DrawWaypointIDs,
			Description = "Draw waypoint IDs",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "TextRange",
			Text = "Text Range",
			Type = Type.Integer,
			Value = Config.TextRange,
			Description = "Set how far away waypoint text is visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 5,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "DrawSpawnPoints",
			Text = "Draw Spawn Points",
			Type = Type.Boolean,
			Value = Config.DrawSpawnPoints,
			Description = "Draw Spawn Points",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "SpawnPointRange",
			Text = "Range of Spawnpoints",
			Type = Type.Integer,
			Value = Config.SpawnPointRange,
			Description = "Set how far away spawnpoints are visible (meters)",
			Reference = Range(1.00, 1000.00, 1.0),
			Default = 100,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "DebugSelectionRaytraces",
			Text = "Debug Selection Raytraces",
			Type = Type.Boolean,
			Value = Config.DebugSelectionRaytraces,
			Description = "Shows the trace line and search area from Commo Rose selection",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "TraceDelta",
			Text = "Trace Delta Points",
			Type = Type.Float,
			Value = Config.TraceDelta,
			Description = "update intervall of trace",
			Reference = Range(0.10, 10.00, 0.1),
			Default = 0.3,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		{
			Name = "NodesPerCycle",
			Text = "Nodes that are drawn per cycle",
			Type = Type.Integer,
			Value = Config.NodesPerCycle,
			Description = "Set how many nodes get drawn per cycle. Affects performance",
			Reference = Range(1.00, 10000.00, 1.0),
			Default = 300,
			UpdateFlag = UpdateFlag.None,
			Category = "TRACE"
		},
		-- Advanced properties
		{
			Name = "DistanceForDirectAttack",
			Text = "Distance for direct attack",
			Type = Type.Integer,
			Value = Config.DistanceForDirectAttack,
			Description = "if that close, the bot can hear you",
			Reference = Range(0.00, 1000.00, 1.0),
			Default = 5,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "MaxBotAttackBotDistance",
			Text = "Bot attack Bot distance",
			Type = Type.Integer,
			Value = Config.MaxBotAttackBotDistance,
			Description = "meters a bot attacks an other bot",
			Reference = Range(0.00, 1000.00, 5.0),
			Default = 30,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "MeleeAttackCoolDown",
			Text = "Bot melee attack cool-down",
			Type = Type.Float,
			Value = Config.MeleeAttackCoolDown,
			Description = "the time a bot waits before attacking with melee again",
			Reference = Range(0.00, 60.00, 0.5),
			Default = 3.0,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "AimForHead",
			Text = "Bots without sniper aim for head",
			Type = Type.Boolean,
			Value = Config.AimForHead,
			Description = "bots without sniper aim for the head. More an experimental config",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "AimForHeadSniper",
			Text = "Bots with Sniper aim for head",
			Type = Type.Boolean,
			Value = Config.AimForHeadSniper,
			Description = "bots with sniper aim for the head. More an experimental config",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "AimForHeadSupport",
			Text = "Bots with Support LMGs aim for head",
			Type = Type.Boolean,
			Value = Config.AimForHeadSupport,
			Description = "bots with support LMGs aim for the head. More an experimental config",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "JumpWhileShooting",
			Text = "jump while shooting",
			Type = Type.Boolean,
			Value = Config.JumpWhileShooting,
			Description = "bots jump over obstacles while shooting if needed",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "JumpWhileMoving",
			Text = "jump while moving",
			Type = Type.Boolean,
			Value = Config.JumpWhileMoving,
			Description = "bots jump while moving. If false, only on obstacles!",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "OverWriteBotSpeedMode",
			Text = "Overwrite speed mode",
			Type = Type.Enum,
			Value = Config.OverWriteBotSpeedMode,
			Description = "0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run",
			Reference = BotMoveSpeeds,
			Default = BotMoveSpeeds.NoMovement,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "OverWriteBotAttackMode",
			Text = "Overwrite attack speed mode",
			Type = Type.Enum,
			Value = Config.OverWriteBotAttackMode,
			Description = "Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk (good aim), 4 = run",
			Reference = BotMoveSpeeds,
			Default = BotMoveSpeeds.NoMovement,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "SpeedFactor",
			Text = "speed facator",
			Type = Type.Float,
			Value = Config.SpeedFactor,
			Description = "reduces the movementspeed. 1 = normal, 0 = standing.",
			Reference = Range(0.00, 1.00, 0.10),
			Default = 1.0,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "SpeedFactorAttack",
			Text = "speed facator attack",
			Type = Type.Float,
			Value = Config.SpeedFactorAttack,
			Description = "reduces the movementspeed while attacking. 1 = normal, 0 = standing.",
			Reference = Range(0.00, 1.00, 0.10),
			Default = 0.6,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},
		{
			Name = "UseRandomNames",
			Text = "Use Random Names",
			Type = Type.Boolean,
			Value = Config.UseRandomNames,
			Description = "changes names of the bots on every new round. Experimental right now...",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "ADVANCED"
		},

		-- Expert Properties
		{
			Name = "BotFirstShotDelay",
			Text = "Bot first shot delay",
			Type = Type.Float,
			Value = Config.BotFirstShotDelay,
			Description = "delay for first shot. If too small, there will be great spread in first cycle because its not kompensated jet.",
			Reference = Range(0.00, 10.00, 0.10),
			Default = 0.35,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "BotMinTimeShootAtPlayer",
			Text = "Bot min time shoot at player",
			Type = Type.Float,
			Value = Config.BotMinTimeShootAtPlayer,
			Description = "the minimum time a bot shoots at one player - recommended minimum 1.5, below this you will have issues.",
			Reference = Range(0.00, 60.00, 0.5),
			Default = 2.0,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "BotFireModeDuration",
			Text = "Bot fire mode duration",
			Type = Type.Float,
			Value = Config.BotFireModeDuration,
			Description = "the minimum time a bot tries to shoot a player - recommended minimum 3.0, below this you will have issues.",
			Reference = Range(0.00, 60.00, 0.5),
			Default = 5.0,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "MaximunYawPerSec",
			Text = "maximun yaw per sec",
			Type = Type.Integer,
			Value = Config.MaximunYawPerSec,
			Description = "in Degree. Rotaion-Movement per second.",
			Reference = Range(0.00, 1080.00, 5.0),
			Default = 450,
			UpdateFlag = UpdateFlag.YawPerSec,
			Category = "EXPERT"
		},
		{
			Name = "TargetDistanceWayPoint",
			Text = "target distance waypoint",
			Type = Type.Float,
			Value = Config.TargetDistanceWayPoint,
			Description = "distance the bots have to reach to continue with next Waypoint",
			Reference = Range(0.00, 100.00, 0.10),
			Default = 0.8,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "KeepOneSlotForPlayers",
			Text = "keep one slot for players",
			Type = Type.Boolean,
			Value = Config.KeepOneSlotForPlayers,
			Description = "always keep one slot for new Players to join",
			Default = true,
			UpdateFlag = UpdateFlag.AmountAndTeam,
			Category = "EXPERT"
		},
		{
			Name = "DistanceToSpawnBots",
			Text = "distance to spawn",
			Type = Type.Integer,
			Value = Config.DistanceToSpawnBots,
			Description = "distance to spawn Bots away from players.",
			Reference = Range(0.00, 100.00, 5.0),
			Default = 30,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "HeightDistanceToSpawn",
			Text = "height distance to spawn",
			Type = Type.Float,
			Value = Config.HeightDistanceToSpawn,
			Description = "distance vertically, Bots should spawn away, if closer than distance.",
			Reference = Range(0.00, 100.00, 0.10),
			Default = 2.8,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "DistanceToSpawnReduction",
			Text = "Distance to spawn reduction",
			Type = Type.Integer,
			Value = Config.DistanceToSpawnReduction,
			Description = "reduce distance if not possible.",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 5,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "MaxTrysToSpawnAtDistance",
			Text = "max tries to spawn at distance",
			Type = Type.Integer,
			Value = Config.MaxTrysToSpawnAtDistance,
			Description = "try this often to spawn a bot away from players",
			Reference = Range(0.00, 100.00, 1.0),
			Default = 3,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "HeadShotFactorBots",
			Text = "headshot factor bots",
			Type = Type.Float,
			Value = Config.HeadShotFactorBots,
			Description = "factor for damage if headshot (only in Fake-mode)",
			Reference = Range(0.00, 10.00, 0.1),
			Default = 1.5,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "AttackWayBots",
			Text = "attack way Bots",
			Type = Type.Boolean,
			Value = Config.AttackWayBots,
			Description = "bots on paths attack player",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "RespawnWayBots",
			Text = "respawn way Bots",
			Type = Type.Boolean,
			Value = Config.RespawnWayBots,
			Description = "bots on paths respawn if killed",
			Default = true,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},
		{
			Name = "SpawnMethod",
			Text = "spawn-mehtod",
			Type = Type.Enum,
			Value = Config.SpawnMethod,
			Description = "method the bots spawn with. Careful, not supported on most of the maps!!",
			Reference = SpawnMethod,
			Default = SpawnMethod.SpawnSoldierAt,
			UpdateFlag = UpdateFlag.None,
			Category = "EXPERT"
		},

		-- Other Stuff
		{
			Name = "DisableUserInterface",
			Text = "disable UI",
			Type = Type.Boolean,
			Value = Config.DisableUserInterface,
			Description = "if true, the complete UI will be disabled (not available in the UI -) )",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "DisableChatCommands",
			Text = "disable chat-commands",
			Type = Type.Boolean,
			Value = Config.DisableChatCommands,
			Description = "if true, no chat commands can be used",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "DisableRCONCommands",
			Text = "disable RCON-commands",
			Type = Type.Boolean,
			Value = Config.DisableRCONCommands,
			Description = "if true, no RCON commands can be used",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "IgnorePermissions",
			Text = "disable RCON-commands",
			Type = Type.Boolean,
			Value = Config.IgnorePermissions,
			Description = "if true, all permissions are ignored --> everyone can do everything",
			Default = false,
			UpdateFlag = UpdateFlag.None,
			Category = "OTHER"
		},
		{
			Name = "Language",
			Text = "language",
			Type = Type.String,
			Value = Config.Language,
			Description = "de_DE as sample (default is english, when language file doesnt exists)",
			Default = nil,
			UpdateFlag = UpdateFlag.Language,
			Category = "OTHER"
		}
	}
}
