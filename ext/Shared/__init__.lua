class('FunBotShared')

require('__shared/Debug')
require ('__shared/Utils/Logger')
require('__shared/WeaponList')
require('__shared/EbxEditUtils')

local m_Logger = Logger("FunBotServer", true)
local m_Language = require('__shared/Language')

function FunBotShared:__init()

end

if g_FunBotShared == nil then
	g_FunBotShared = FunBotShared()
end
