class('FunBotClient')

require('__shared/Debug')
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/SpawnModes')

require('ClientNodeEditor')

local m_Language = require('__shared/Language')
local m_FunBotUIClient = require('UIClient')
local m_ClientBotManager = require('ClientBotManager')

function FunBotClient:__init()
	m_Language:loadLanguage(Config.Language)
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload)
	Events:Subscribe('Engine:Message', self, self._onEngineMessage)
end

function FunBotClient:_onExtensionUnload()
	m_ClientBotManager:onExtensionUnload()
end

function FunBotClient:_onEngineMessage(p_Message)
	m_ClientBotManager:onEngineMessage(p_Message)
end

if g_FunBotClient == nil then
	g_FunBotClient = FunBotClient()
end

return g_FunBotClient
