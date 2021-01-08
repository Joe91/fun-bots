class('BotSpawner')

local BotManager = require('botManager')
local Globals = require('globals')

function BotSpawner:__init()

end





-- Singleton.
if g_BotSpawner == nil then
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner