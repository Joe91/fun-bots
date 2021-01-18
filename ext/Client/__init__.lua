class('FunBotClient')
local FunBotUIClient = require('UIClient')
local ClientBotManager = require('clientBotManager')

function FunBotClient:__init()
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload)
	Events:Subscribe('Engine:Message', self, self._onEngineMessage)
end

function FunBotClient:_onExtensionUnload()
	ClientBotManager:onExtensionUnload()
end

function FunBotClient:_onEngineMessage(p_Message)
	ClientBotManager:onEngineMessage(p_Message)
end

-- Singleton.
if g_FunBotClient == nil then
	g_FunBotClient = FunBotClient()
end

return g_FunBotClient