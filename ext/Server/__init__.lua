class('FunBotServer');

require('__shared/Config');
require('__shared/Constants/BotColors');
require('__shared/Constants/BotNames');
require('__shared/Constants/BotKits');
require('__shared/Constants/BotNames');
require('__shared/Constants/BotWeapons');
require('__shared/Constants/WeaponsSets');


Language					= require('__shared/Language');
local SettingsManager		= require('SettingsManager');
local BotManager			= require('BotManager');
local TraceManager			= require('TraceManager');
local BotSpawner			= require('BotSpawner');
local WeaponModification	= require('__shared/WeaponModification');
local WeaponList			= require('__shared/WeaponList');
local ChatCommands			= require('ChatCommands');
local FunBotUIServer		= require('UIServer');
local Globals 				= require('Globals');

function FunBotServer:__init()
	Language:loadLanguage(Config.language);

	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded);
	Events:Subscribe('Player:Chat', self, self._onChat);
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload);
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded);
	Events:Subscribe('Partition:Loaded', self, self._onPartitionLoaded)
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

function FunBotServer:_onPartitionLoaded(partition)
	for _, instance in pairs(partition.instances) do
		if USE_REAL_DAMAGE then
			if instance:Is("SyncedGameSettings") then
				local syncedGameSettings = SyncedGameSettings(instance)
				syncedGameSettings:MakeWritable()
				syncedGameSettings.allowClientSideDamageArbitration = false
			end
			if instance:Is("ServerSettings") then
				local serverSettings = ServerSettings(instance)
				serverSettings:MakeWritable()
				--serverSettings.drawActivePhysicsObjects = true --doesn't matter
				--serverSettings.isSoldierAnimationEnabled = true --doesn't matter
				--serverSettings.isSoldierDetailedCollisionEnabled = true --doesn't matter
				serverSettings.isRenderDamageEvents = true
			end
		end
	end
end

function FunBotServer:_onRequestClientSettings(player)
	NetEvents:SendToLocal('WriteClientSettings', player, Config);
end

function FunBotServer:_onLevelLoaded(levelName, gameMode)
	NetEvents:BroadcastLocal('WriteClientSettings', Config);
	WeaponModification:ModifyAllWeapons(Config.botAimWorsening, Config.botSniperAimWorsening);
	WeaponList:onLevelLoaded();
	print('level ' .. levelName .. ' loaded...');
	if gameMode == 'TeamDeathMatchC0' or gameMode == 'TeamDeathMatch0' then
		Globals.isTdm = true;
	else
		Globals.isTdm = false;
	end
	TraceManager:onLevelLoaded(levelName, gameMode);
	BotSpawner:onLevelLoaded(false);
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