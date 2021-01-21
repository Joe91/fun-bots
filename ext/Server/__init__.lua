class('FunBotServer');

require('__shared/Config');
require('__shared/Constants/BotColors');
require('__shared/Constants/BotNames');
require('__shared/Constants/BotKits');
require('__shared/Constants/BotNames');
require('__shared/Constants/BotWeapons');

local SettingsManager		= require('SettingsManager');
local BotManager			= require('BotManager');
local TraceManager			= require('TraceManager');
local BotSpawner			= require('BotSpawner');
local WeaponModification	= require('__shared/WeaponModification');
local ChatCommands			= require('ChatCommands');
local FunBotUIServer		= require('UIServer');

function FunBotServer:__init()
	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded);
	Events:Subscribe('Player:Chat', self, self._onChat);
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload);
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded);
	NetEvents:Subscribe('RequestClientSettings', self, self._onRequestClientSettings);
end

function FunBotServer:_onExtensionUnload()
	BotManager:destroyAllBots();
	TraceManager:onUnload();
end

function FunBotServer:_onExtensionLoaded()
	SettingsManager:onLoad();

	local fullLevelPath = SharedUtils:GetLevelName();

	if (fullLevelPath ~= nil) then
		fullLevelPath	= fullLevelPath:split('/');
		local level		= fullLevelPath[#fullLevelPath];
		local gameMode	= SharedUtils:GetCurrentGameMode();

		print(level .. '_' .. gameMode .. ' reloaded');

		if (level ~= nil and gameMode~= nil) then
			self:_onLevelLoaded(level, gameMode);
		end
	end
end

function FunBotServer:_onRequestClientSettings(player)
	NetEvents:SendToLocal('WriteClientSettings', player, Config, true);
end

function FunBotServer:_onLevelLoaded(levelName, gameMode)
	NetEvents:BroadcastLocal('WriteClientSettings', Config, true);
	WeaponModification:ModifyAllWeapons(Config.botAimWorsening);
	print('level ' .. levelName .. ' loaded...');
	TraceManager:onLevelLoaded(levelName, gameMode);
	BotSpawner:onLevelLoaded();
end

function FunBotServer:_onChat(player, recipientMask, message)
	local messageParts = string.lower(message):split(' ');

	ChatCommands:execute(messageParts, player);
end

--helper fucntion for string, @ToDo move to Utils class
function string:split(sep)
	local sep, fields	= sep or ':', {};
	local pattern		= string.format("([^%s]+)", sep);

	self:gsub(pattern, function(c) fields[#fields + 1] = c end);

	return fields;
end

-- Singleton.
if g_FunBotServer == nil then
	g_FunBotServer = FunBotServer();
end

return g_FunBotServer;