class('FunBotShared')

require('__shared/Debug')
require('__shared/Utils/Logger')
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/WeaponTypes')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/SpawnModes')
require('__shared/Constants/SpawnMethods')
require('__shared/WeaponList')
require('__shared/EbxEditUtils')

local m_Logger = Logger("FunBotServer", true)
local m_Language = require('__shared/Language')

function FunBotShared:__init()

end

if g_FunBotShared == nil then
	g_FunBotShared = FunBotShared()
end
