SettingsDefinition = {
	Categorys = {
		GENERAL	= "General",
		DIFFICULTY = "Difficulty",
		BOTS	= "BOTS",
		OTHER	= "Other"
	},

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
			Category	= SettingsDefinition.Categorys.GENERAL
		},
		{
			Name		= "BotKit",
			Text 		= "Bot Kit",
			Type		= Type.Enum,
			Value		= Config.BotKit,
			Reference	= BotKits,
			Description	= "The Kit of the Bots",
			Default		= BotKits.RANDOM_KIT,
			Category	= SettingsDefinition.Categorys.GENERAL
		},
		{
			Name		= "BotColor",
			Text 		= "Bot Color",
			Type		= Type.Enum,
			Reference	= BotColors,
			Value		= Config.BotColor,
			Description	= "The Color of the Bots",
			Default		= BotColors.RANDOM_COLOR,
			Category	= SettingsDefinition.Categorys.GENERAL
		},
		{
			Name		= "ZombieMode",
			Type		= Type.Boolean,
			Value		= Config.ZombieMode,
			Description	= "Zombie Bot Mode",
			Default		= false,
			Category	= SettingsDefinition.Categorys.GENERAL
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
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "BotSniperAimWorsening",
			Text 		= "Bot Aim Worsening of Snipers",
			Type		= Type.Float,
			Value		= Config.BotSniperAimWorsening,
			Description	= "see botAimWorsening, only for Sniper-rifles",
			Reference	= Range(0.00, 10.00),
			Default		= 0.2,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorAssault",
			Text 		= "Damage Factor Assault",
			Type		= Type.Float,
			Value		= Config.DamageFactorAssault,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorCarabine",
			Text 		= "Damage Factor Carabine",
			Type		= Type.Float,
			Value		= Config.DamageFactorCarabine,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorLMG",
			Text 		= "Damage Factor LMG",
			Type		= Type.Float,
			Value		= Config.DamageFactorLMG,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorPDW",
			Text 		= "Damage Factor PDW",
			Type		= Type.Float,
			Value		= Config.DamageFactorPDW,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorPDW",
			Text 		= "Damage Factor PDW",
			Type		= Type.Float,
			Value		= Config.DamageFactorPDW,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.5,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorSniper",
			Text 		= "Damage Factor Sniper",
			Type		= Type.Float,
			Value		= Config.DamageFactorSniper,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.8,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorShotgun",
			Text 		= "Damage Factor Shotgun",
			Type		= Type.Float,
			Value		= Config.DamageFactorShotgun,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.8,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorPistol",
			Text 		= "Damage Factor Pistol",
			Type		= Type.Float,
			Value		= Config.DamageFactorPistol,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 0.7,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		},
		{
			Name		= "DamageFactorKnife",
			Text 		= "Damage Factor Knife",
			Type		= Type.Float,
			Value		= Config.DamageFactorKnife,
			Description	= "original Damage from bots gets multiplied by this",
			Reference	= Range(0.00, 2.00),
			Default		= 1.5,
			Category	= SettingsDefinition.Categorys.DIFFICULTY
		}
	}
}