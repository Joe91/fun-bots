class('BotSpawner')

local BotManager = require('botManager')
local Globals = require('globals')





-- Singleton.
if g_BotSpawner == nil then
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner