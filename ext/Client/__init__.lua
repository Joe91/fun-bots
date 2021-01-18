class('FunBotClient')
require('__shared/Config')
local FunBotUIClient = require('UIClient')
local ClientBotManager = require('clientBotManager')

function FunBotClient:__init()
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload)
end

function FunBotClient:_onExtensionUnload()
	ClientBotManager:onExtensionUnload()
end

-- Singleton.
if g_FunBotClient == nil then
	g_FunBotClient = FunBotClient()
end

return g_FunBotClient