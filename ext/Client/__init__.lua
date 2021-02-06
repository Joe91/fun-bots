class('FunBotClient');

require('__shared/Constants/BotColors');
require('__shared/Constants/BotNames');
require('__shared/Constants/BotKits');
require('__shared/Constants/BotNames');
require('__shared/Constants/BotWeapons');
require('__shared/Constants/WeaponsAssault');
require('__shared/Constants/WeaponsEngineer');
require('__shared/Constants/WeaponsSupport');
require('__shared/Constants/WeaponsRecon');
require('__shared/Constants/Pistols');
require('__shared/Constants/Knifes');

require('ClientNodeEditor');

Language					= require('__shared/Language');
local FunBotUIClient		= require('UIClient');
local ClientTraceManager	= require('ClientTraceManager');
local ClientBotManager		= require('ClientBotManager');

function FunBotClient:__init()
	Language:loadLanguage(Config.language);
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload);
	Events:Subscribe('Engine:Message', self, self._onEngineMessage);
end

function FunBotClient:_onExtensionUnload()
	ClientBotManager:onExtensionUnload();
end

function FunBotClient:_onEngineMessage(p_Message)
	ClientBotManager:onEngineMessage(p_Message);
end

-- Singleton.
if (g_FunBotClient == nil) then
	g_FunBotClient = FunBotClient();
end

return g_FunBotClient;