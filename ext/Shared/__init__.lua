class('FunBotShared')
local WeaponModification = require('__shared/weaponModification')

function FunBotShared:__init()
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
	Events:Subscribe('Level:Loaded', self, self.OnLevelLoaded)
end

function FunBotShared:OnPartitionLoaded(p_Partition)
	WeaponModification:OnPartitionLoaded(p_Partition)
end

function FunBotShared:OnLevelLoaded(levelName, gameMode)
	WeaponModification:OnLevelLoaded(levelName, gameMode)
end

-- Singleton.
if g_FunBotShared == nil then
	g_FunBotShared = FunBotShared()
end

return g_FunBotShared