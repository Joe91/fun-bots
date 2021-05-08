SettingsDefinition = {
	Categorys = {
		GENERAL	= "General",
		BOTS	= "BOTS",
		OTHER	= "Other"
	},
	Elements = {
		-- Bots
		{
			Name		= "BotWeapon",
			Type		= Type.Enum,
			Value		= Config.BotWeapon,
			Reference	= BotWeapons,
			Description	= "Select the weapon the bots use",
			Default		= BotWeapons.Auto,
			Category	= SettingsDefinition.Categorys.BOTS
		}, {
			Name		= "ZombieMode",
			Type		= Type.Boolean,
			Value		= Config.ZombieMode,
			Description	= "Zombie Bot Mode",
			Default		= false,
			Category	= SettingsDefinition.Categorys.BOTS
		},
		
		-- General
		{
			Name		= "BotFirstShotDelay",
			Type		= Type.Float,
			Value		= Config.BotFirstShotDelay,
			Description	= "delay for first shot. If too small, there will be great spread in first cycle because its not kompensated jet.",
			Reference	= Range(0.00, 1.00),
			Default		= 0.35,
			Category	= SettingsDefinition.Categorys.GENERAL
		}
	}
}