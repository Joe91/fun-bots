--[[
	@property: SettingsDefinition
]]
SettingsDefinition = {
	--[[
		@property: Categorys
	]]
	Categorys = {
		GENERAL	= "General",
		DIFFICULTY = "Difficulty",
		SPAWN = "Spawn",
		SPAWNLIMITS = "Spawnlimits",
		BOTS	= "BOTS",
		OTHER	= "Other"
	},

	--[[
		@property: Elements
	]]
	Elements = {
		-- General
		{
			Name		= "BotWeapon",
			Text 		= "Bot Weapon",
			Type		= Type.Enum,
			Value		= Config.BotWeapon,
			Reference	= BotWeapons,
			Description	= "Select the weapon the bots use",
			Default		= BotWeapons.Auto,
			Category	= "GENERAL"
		},
		{
			Name		= "BotKit",
			Text 		= "Bot Kit",
			Type		= Type.Enum,
			Value		= Config.BotKit,
			Reference	= BotKits,
			Description	= "The Kit of the Bots",
			Default		= BotKits.RANDOM_KIT,
			Category	= "GENERAL"
		},
		{
			Name		= "BotColor",
			Text 		= "Bot Color",
			Type		= Type.Enum,
			Reference	= BotColors,
			Value		= Config.BotColor,
			Description	= "The Color of the Bots",
			Default		= BotColors.RANDOM_COLOR,
			Category	= "GENERAL"
		},
		{
			Name		= "ZombieMode",
			Type		= Type.Boolean,
			Value		= Config.ZombieMode,
			Description	= "Zombie Bot Mode",
			Default		= false,
			Category	= "GENERAL"
		},

		-- Difficulty
		{
			Name		= "BotAimWorsening",
			Text 		= "Bot Aim Worsening",
			Type		= Type.Float,
			Value		= Config.BotAimWorsening,
			Description	= "make aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy).",
			Reference	= Range(0.00, 10.00),
			Default		= 0.5,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "BotSniperAimWorsening",
			Text 		= "Bot Aim Worsening of Snipers",
			Type		= Type.Float,
			Value		= Config.BotSniperAimWorsening,
			Description	= "see botAimWorsening, only for Sniper-rifles",
			Reference	= Range(0.00, 10.00),
			Default		= 0.2,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "BotWorseningSkill",
			Text 		= "Bot Worsening Skill",
			Type		= Type.Float,
			Value		= Config.BotWorseningSkill,
			Description	= "variation of the skill of a single bot. the higher, the worse the bots can get compared to the original settings",
			Reference	= Range(0.00, 0.50),
			Default		= 0.25,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorAssault",
			Text 		= "Damage Factor Assault",
			Type		= Type.Float,
			Value		= Config.DamageFactorAssault,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorCarabine",
			Text 		= "Damage Factor Carabine",
			Type		= Type.Float,
			Value		= Config.DamageFactorCarabine,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorLMG",
			Text 		= "Damage Factor LMG",
			Type		= Type.Float,
			Value		= Config.DamageFactorLMG,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorPDW",
			Text 		= "Damage Factor PDW",
			Type		= Type.Float,
			Value		= Config.DamageFactorPDW,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorPDW",
			Text 		= "Damage Factor PDW",
			Type		= Type.Float,
			Value		= Config.DamageFactorPDW,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorSniper",
			Text 		= "Damage Factor Sniper",
			Type		= Type.Float,
			Value		= Config.DamageFactorSniper,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.8,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorShotgun",
			Text 		= "Damage Factor Shotgun",
			Type		= Type.Float,
			Value		= Config.DamageFactorShotgun,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.8,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorPistol",
			Text 		= "Damage Factor Pistol",
			Type		= Type.Float,
			Value		= Config.DamageFactorPistol,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.7,
			Category	= "DIFFICULTY"
		},
		{
			Name		= "DamageFactorKnife",
			Text 		= "Damage Factor Knife",
			Type		= Type.Float,
			Value		= Config.DamageFactorKnife,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 1.5,
			Category	= "DIFFICULTY"
		},

		-- Spawn
		{
			Name		= "SpawnMode",
			Text 		= "Spawn Mode",
			Type		= Type.Enum,
			Value		= Config.SpawnMode,
			Description	= "mode the bots spawn with",
			Reference	= SpawnModes,
			Default		= SpawnModes.balanced_teams,
			Category	= "SPAWN"
		},
		{
			Name		= "SpawnInBothTeams",
			Text 		= "Spawn Bots in all teams",
			Type		= Type.Boolean,
			Value		= Config.SpawnInBothTeams,
			Description	= "Bots spawn in both teams",
			Default		= true,
			Category	= "SPAWN"
		},
		{
			Name		= "InitNumberOfBots",
			Text 		= "Start Number of Bots",
			Type		= Type.Integer,
			Value		= Config.InitNumberOfBots,
			Description	= "bots for spawnmode",
			Reference	= Range(0.00, 128.00),
			Default		= 6,
			Category	= "SPAWN"
		},
		{
			Name		= "NewBotsPerNewPlayer",
			Text 		= "New Bots per Player",
			Type		= Type.Integer,
			Value		= Config.NewBotsPerNewPlayer,
			Description	= "number to increase Bots, when new players join",
			Reference	= Range(0.00, 128.00),
			Default		= 2,
			Category	= "SPAWN"
		},
		{
			Name		= "NewBotsPerNewPlayer",
			Text 		= "New Bots per Player",
			Type		= Type.Integer,
			Value		= Config.NewBotsPerNewPlayer,
			Description	= "number to increase Bots, when new players join",
			Reference	= Range(0.00, 128.00),
			Default		= 2,
			Category	= "SPAWN"
		},
		{
			Name		= "BotTeam",
			Text 		= "Team of the Bots",
			Type		= Type.Integer,
			Value		= Config.BotTeam,
			Description	= "default bot team (0 = neutral / auto, 1 = US, 2 = RU) TeamId.Team2",
			Reference	= Range(0.00, 4.00),
			Default		= 0,
			Category	= "SPAWN"
		},
		{
			Name		= "BotNewLoadoutOnSpawn",
			Text 		= "New Loadout on Spawn",
			Type		= Type.Boolean,
			Value		= Config.BotNewLoadoutOnSpawn,
			Description	= "bots get a new kit and color, if they respawn",
			Default		= true,
			Category	= "SPAWN"
		},
		{
			Name		= "MaxAssaultBots",
			Text 		= "Max Assault Bots",
			Type		= Type.Integer,
			Value		= Config.MaxAssaultBots,
			Description	= "maximum number of Bots with Assault Kit. -1 = no limit",
			Reference	= Range(-1.00, 128.00),
			Default		= -1,
			Category	= "SPAWN"
		},
		{
			Name		= "MaxEngineerBots",
			Text 		= "Max Engineer Bots",
			Type		= Type.Integer,
			Value		= Config.MaxEngineerBots,
			Description	= "maximum number of Bots with Engineer Kit. -1 = no limit",
			Reference	= Range(-1.00, 128.00),
			Default		= -1,
			Category	= "SPAWN"
		},
		{
			Name		= "MaxSupportBots",
			Text 		= "Max Support Bots",
			Type		= Type.Integer,
			Value		= Config.MaxSupportBots,
			Description	= "maximum number of Bots with Support Kit. -1 = no limit",
			Reference	= Range(-1.00, 128.00),
			Default		= -1,
			Category	= "SPAWN"
		},
		{
			Name		= "MaxReconBots",
			Text 		= "Max Support Bots",
			Type		= Type.Integer,
			Value		= Config.MaxReconBots,
			Description	= "maximum number of Bots with Recon Kit. -1 = no limit",
			Reference	= Range(-1.00, 128.00),
			Default		= -1,
			Category	= "SPAWN"
		},

	-- spawn-limits
		{
			Name		= "MaxBotsPerTeamDefault",
			Text 		= "Max Bots Per Team (default)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamDefault,
			Description	= "max number of bots in one team, if no other mode fits",
			Reference	= Range(0.00, 128.00),
			Default		= 32,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamTdm",
			Text 		= "Max Bots Per Team (TDM)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamTdm,
			Description	= "max number of bots in one team for TDM",
			Reference	= Range(0.00, 128.00),
			Default		= 32,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamTdmc",
			Text 		= "Max Bots Per Team (TDM-CQ)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamTdmc,
			Description	= "max number of bots in one team for TDM-CQ",
			Reference	= Range(0.00, 128.00),
			Default		= 8,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamSdm",
			Text 		= "Max Bots Per Team (Squad-DM)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamSdm,
			Description	= "max number of bots in one team for Squad-DM",
			Reference	= Range(0.00, 128.00),
			Default		= 5,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamCl",
			Text 		= "Max Bots Per Team (CQ-Large)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamCl,
			Description	= "max number of bots in one team for CQ-Large",
			Reference	= Range(0.00, 128.00),
			Default		= 32,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamCs",
			Text 		= "Max Bots Per Team (CQ-Small)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamCs,
			Description	= "max number of bots in one team for CQ-Small",
			Reference	= Range(0.00, 128.00),
			Default		= 16,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamCal",
			Text 		= "Max Bots Per Team (CQ-Assault-Large)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamCal,
			Description	= "max number of bots in one team for CQ-Assault-Large",
			Reference	= Range(0.00, 128.00),
			Default		= 32,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamCas",
			Text 		= "Max Bots Per Team (CQ-Assault-Small)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamCas,
			Description	= "max number of bots in one team for CQ-Assault-Small",
			Reference	= Range(0.00, 128.00),
			Default		= 16,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamRl",
			Text 		= "Max Bots Per Team (Rush)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamRl,
			Description	= "max number of bots in one team for Rush",
			Reference	= Range(0.00, 128.00),
			Default		= 24,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamCtf",
			Text 		= "Max Bots Per Team (CTF)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamCtf,
			Description	= "max number of bots in one team for CTF",
			Reference	= Range(0.00, 128.00),
			Default		= 24,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamD",
			Text 		= "Max Bots Per Team (Domination)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamD,
			Description	= "max number of bots in one team for Domination",
			Reference	= Range(0.00, 128.00),
			Default		= 12,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamGm",
			Text 		= "Max Bots Per Team (Gunmaster)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamGm,
			Description	= "max number of bots in one team for Gunmaster",
			Reference	= Range(0.00, 128.00),
			Default		= 12,
			Category	= "SPAWNLIMITS"
		},
		{
			Name		= "MaxBotsPerTeamS",
			Text 		= "Max Bots Per Team (Scavenger)",
			Type		= Type.Integer,
			Value		= Config.MaxBotsPerTeamS,
			Description	= "max number of bots in one team for Scavenger",
			Reference	= Range(0.00, 128.00),
			Default		= 12,
			Category	= "SPAWNLIMITS"
		}
	}
}