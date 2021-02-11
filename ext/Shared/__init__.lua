class('FunBotShared');

require('__shared/WeaponList');
require('__shared/EbxEditUtils');

Language					= require('__shared/Language');
local WeaponModification	= require('__shared/WeaponModification');

function FunBotShared:__init()
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded);
end

function FunBotShared:OnPartitionLoaded(p_Partition)
	WeaponModification:OnPartitionLoaded(p_Partition);
end

-- Singleton.
if g_FunBotShared == nil then
	g_FunBotShared = FunBotShared();
end