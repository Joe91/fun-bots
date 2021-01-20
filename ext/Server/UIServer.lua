class 'FunBotUIServer';

require('__shared/ArrayMap');
require('__shared/Config');
require('SettingsManager');

local BotManager	= require('BotManager');
local TraceManager	= require('TraceManager');
local BotSpawner	= require('BotSpawner');

function FunBotUIServer:__init()
	self._webui			= 0;
	self._authenticated	= ArrayMap();

	Events:Subscribe('Player:Left', self, self._onPlayerLeft);
	NetEvents:Subscribe('UI_Request_Open', self, self._onUIRequestOpen);
	NetEvents:Subscribe('UI_Request_Save_Settings', self, self._onUIRequestSaveSettings);
	NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent);
end

function FunBotUIServer:_onBotEditorEvent(player, data)
	print('UIServer: BotEditor (' .. tostring(data) .. ')');

	if (Config.settingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
			print(player.name .. ' has no permissions for Bot-Editor.');
			ChatManager:Yell('You are not permitted to change Bots. Please press F12 for authenticate!', 2.5);
		return;
	end

	local request = json.decode(data);

	if request.action == 'request_settings' then
		if Config.language == nil then
			Config.language = 'en_US';
		end

		NetEvents:SendTo('UI_Settings', player, Config);

	-- Bots
	elseif request.action == 'bot_spawn_default' then
		local amount = tonumber(request.value);
		BotSpawner:spawnWayBots(player, amount, true);

	elseif request.action == 'bot_spawn_path' then --todo: whats the difference? make a function to spawn bots on a fixed way instead?
		local amount		= 1;
		local indexOnPath	= 1;
		local index			= tonumber(request.value);
		BotSpawner:spawnWayBots(player, amount, false, index, indexOnPath);

	elseif request.action == 'bot_kick_all' then
		BotManager:destroyAllBots();

	elseif request.action == 'bot_kill_all' then
		BotManager:killAll();

	elseif request.action == 'bot_respawn' then  --toggle this function
		local respawning		= not Config.respawnWayBots;
		Config.respawnWayBots	= respawning;
		BotManager:setOptionForAll('respawn', respawning);

	elseif request.action == 'bot_attack' then  --toggle this function
		local attack			= not Config.attackWayBots;
		Config.attackWayBots	= attack;
		BotManager:setOptionForAll('shoot', attack);

	-- Trace
	elseif request.action == 'trace_start' then
		local index = tonumber(request.value);
		TraceManager:startTrace(player, index);

	elseif request.action == 'trace_end' then
		TraceManager:endTrace(player);

	elseif request.action == 'trace_clear' then
		local index = tonumber(request.value);
		TraceManager:clearTrace(index);

	elseif request.action == 'trace_reset_all' then
		TraceManager:clearAllTraces();

	elseif request.action == 'trace_save' then
		TraceManager:savePaths();

	elseif request.action == 'trace_reload' then
		TraceManager:loadPaths();

	else
		ChatManager:Yell(request.action .. ' is currently not implemented.', 2.5);
	end
end

function FunBotUIServer:_onPlayerLeft(player)
	-- @ToDo current fix for auth-check after rejoin, remove it later or make it as configuration!
	self._authenticated:delete(tostring(player.accountGuid));
end

function FunBotUIServer:_onUIRequestSaveSettings(player, data)
	print(player.name .. ' requesting to save settings.');

	if (Config.settingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
		print(player.name .. ' has no permissions for Bot-Editor.');
		ChatManager:Yell('You are not permitted to change Bots. Please press F12 for authenticate!', 2.5);
		return;
	end

	local request = json.decode(data);

	self:_writeSettings(player, request);
end

function FunBotUIServer:_onUIRequestOpen(player, data)
	print(player.name .. ' requesting open Bot-Editor.');

	if (Config.settingsPassword == nil or self:_isAuthenticated(player.accountGuid)) then
		if (Config.settingsPassword == nil) then
			ChatManager:Yell('The Bot-Editor is not protected by an password!', 2.5);
			NetEvents:SendTo('UI_Password_Protection', player, 'true');
		end

		print('Open Bot-Editor for ' .. player.name .. '.');
		NetEvents:SendTo('UI_Toggle', player);
		NetEvents:SendTo('UI_Show_Toolbar', player, 'true');
	else
		if (data == nil) then
			print('Ask ' .. player.name .. ' for Bot-Editor password.');
			ChatManager:Yell('Please authenticate with password!', 2.5);
			NetEvents:SendTo('UI_Request_Password', player, 'true');
		else
			local form = json.decode(data);

			if (form.password ~= nil or form.password ~= '') then
				print(player.name .. ' has entered following Password: ' .. form.password);

				if (form.password == Config.settingsPassword) then
					self._authenticated:add(tostring(player.accountGuid));
					print('accountGuid: ' .. tostring(player.accountGuid));
					ChatManager:Yell('Successfully authenticated.', 2.5);
					NetEvents:SendTo('UI_Request_Password', player, 'false');
					NetEvents:SendTo('UI_Show_Toolbar', player, 'true');
				else
					print(player.name .. ' has entered a bad password.');
					NetEvents:SendTo('UI_Request_Password_Error', player, 'The password you entered is not correct!');
					ChatManager:Yell('Bad password.', 2.5);
				end
			else
				print(player.name .. ' has entered an empty password.');
				NetEvents:SendTo('UI_Request_Password_Error', player, 'The password you entered is not correct!');
				ChatManager:Yell('Please enter a password!', 2.5);
			end
		end
	end
end

function FunBotUIServer:_isAuthenticated(guid)
	if self._authenticated:isEmpty() then
		return false;
	end

	return self._authenticated:exists(tostring(guid));
end

function FunBotUIServer:_writeSettings(player, request)
	local temporary = false;
	
	if request.subaction ~= nil then
		temporary = (request.subaction == 'temp');
	end
	
	--global settings
	if request.spawnInSameTeam ~= nil then
		SettingsManager:update('spawnInSameTeam', (request.spawnInSameTeam == true), temporary);
	end

	if request.disableChatCommands ~= nil then
		SettingsManager:update('disableChatCommands', (request.disableChatCommands == true), temporary);
	end

	if request.fovForShooting ~= nil then
		local tempValue = tonumber(request.fovForShooting);

		if tempValue >= 0 and tempValue <= 360 then
			SettingsManager:update('fovForShooting', tempValue, temporary);
		end
	end

	if request.bulletDamageBot ~= nil then
		local tempValue = tonumber(request.bulletDamageBot);

		if tempValue >= 0 then
			SettingsManager:update('bulletDamageBot', tempValue, temporary);
		end
	end

	if request.bulletDamageBotSniper ~= nil then
		local tempValue = tonumber(request.bulletDamageBotSniper);

		if tempValue >= 0 then
			SettingsManager:update('bulletDamageBotSniper', tempValue, temporary);
		end
	end

	if request.meleeDamageBot ~= nil then
		local tempValue = tonumber(request.meleeDamageBot);

		if tempValue >= 0 then
			SettingsManager:update('meleeDamageBot', tempValue, temporary);
		end
	end

	if request.meleeAttackIfClose ~= nil then
		SettingsManager:update('meleeAttackIfClose', (request.meleeAttackIfClose == true), temporary);
	end

	if request.shootBackIfHit ~= nil then
		SettingsManager:update('shootBackIfHit', (request.shootBackIfHit == true), temporary);
	end

	if request.jumpWhileShooting ~= nil then
		SettingsManager:update('jumpWhileShooting', (request.jumpWhileShooting == true), temporary);
	end

	if request.botAimWorsening ~= nil then
		local tempValue = tonumber(request.botAimWorsening) / 100;

		if tempValue >= 0 and tempValue < 10 then
			SettingsManager:update('botAimWorsening', tempValue, temporary);
		end
	end

	if request.botWeapon ~= nil then
		local tempString = request.botWeapon;

		for _, weapon in pairs(BotWeapons) do
			if tempString == weapon then
				SettingsManager:update('botWeapon', tempString, temporary);
				break
			end
		end
	end

	if request.botKit ~= nil then
		local tempString = request.botKit;

		for _, kit in pairs(BotKits) do
			if tempString == kit then
				SettingsManager:update('botKit', tempString, temporary);
				break
			end
		end
	end

	if request.botColor ~= nil then
		local tempString = request.botColor;

		for _, color in pairs(BotColors) do
			if tempString == color then
				SettingsManager:update('botColor', tempString, temporary);
				break
			end
		end
	end

	--client settings
	if request.maxRaycastDistance ~= nil then
		local tempValue = tonumber(request.maxRaycastDistance);

		if tempValue >= 0 and tempValue <= 500 then
			SettingsManager:update('maxRaycastDistance', tempValue, temporary);
		end
	end

	if request.distanceForDirectAttack ~= nil then
		local tempValue = tonumber(request.distanceForDirectAttack);

		if tempValue >= 0 and tempValue <= 10 then
			SettingsManager:update('distanceForDirectAttack', tempValue, temporary);
		end
	end

	--UI
	if request.language ~= nil then	
		print('Lang changed to: ' .. request.language);
		NetEvents:SendTo('UI_Change_Language', player, request.language);
		SettingsManager:update('language', request.language, temporary);
	end
	
	-- Password
	if request.settingsPassword ~= nil then
		if request.settingsPassword == "" then
			request.settingsPassword = nil;
		end
		
		if Config.settingsPassword == nil and request.settingsPassword ~= nil then
			ChatManager:Yell('You can\'t change the password, if it\'s never set!', 2.5);
		else
			SettingsManager:update('settingsPassword', request.settingsPassword, temporary);
		end
	end

	if temporary then
		ChatManager:Yell('Settings has been saved temporarily.', 2.5);
	else
		ChatManager:Yell('Settings has been saved.', 2.5);
	end
	
	-- @ToDo create Error Array and dont hide if has values
	NetEvents:SendTo('UI_Settings', player, false);
end

if (g_FunBotUIServer == nil) then
	g_FunBotUIServer = FunBotUIServer();
end

return g_FunBotUIServer;
