class 'FunBotUIServer';

require('__shared/ArrayMap');
require('__shared/config')
local BotManager = require('botManager')
local TraceManager = require('traceManager')
local BotSpawner = require('botSpawner')

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

	if request.action == "request_settings" then
		if Config.language == nil then
			Config.language = "en_US";
		end
		
		NetEvents:SendTo('UI_Settings', player, Config);

	-- Bots
	elseif request.action == "bot_spawn_default" then
		local amount = tonumber(request.value)
		BotSpawner:spawnWayBots(player, amount, true)

	elseif request.action == "bot_spawn_path" then--todo: whats the difference? make a function to spawn bots on a fixed way instead?
		local amount = 1
		local indexOnPath = 1
		local index = tonumber(request.value)
		BotSpawner:spawnWayBots(player, amount, false, index, indexOnPath)

	elseif request.action == "bot_kick_all" then
		BotManager:destroyAllBots()

	elseif request.action == "bot_kill_all" then
		BotManager:killAll()

	elseif request.action == "bot_respawn" then  --toggle this function
		local respawning = not Config.respawnWayBots
		Config.respawnWayBots = respawning
		BotManager:setOptionForAll("respawn", respawning)

	elseif request.action == "bot_attack" then  --toggle this function
		local attack = not Config.attackWayBots
		Config.attackWayBots = attack
        BotManager:setOptionForAll("shoot", attack)

	-- Trace
	elseif request.action == "trace_start" then
		local index = tonumber(request.value)
		TraceManager:startTrace(player, index)

	elseif request.action == "trace_end" then
		TraceManager:endTrace(player)

	elseif request.action == "trace_clear_current" then
		local index = tonumber(request.value)
		TraceManager:clearTrace(index)

	elseif request.action == "trace_reset_all" then
		TraceManager:clearAllTraces()

	elseif request.action == "trace_save" then
		TraceManager:savePaths()

	elseif request.action == "trace_reload" then
		TraceManager:loadPaths()
	
	else
		ChatManager:Yell(request.action .. ' is currently not implemented. 😒', 2.5);
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

	self:_writeSettings(request)

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

function FunBotUIServer:_writeSettings(request)
	if request.spawnInSameTeam ~= nil then
		Config.spawnInSameTeam = (request.spawnInSameTeam == "true")
	end
	if request.disableChatCommands ~= nil then
		Config.disableChatCommands = (request.disableChatCommands == "true")
	end
	if request.fovForShooting ~= nil then
		local tempValue = tonumber(request.fovForShooting)
		if tempValue >= 0 and tempValue <= 360 then
			Config.fovForShooting = tempValue
		end
	end
	if request.bulletDamageBot ~= nil then
		local tempValue = tonumber(request.bulletDamageBot)
		if tempValue >= 0 then
			Config.bulletDamageBot = tempValue
		end
	end
	if request.bulletDamageBotSniper ~= nil then
		local tempValue = tonumber(request.bulletDamageBotSniper)
		if tempValue >= 0 then
			Config.bulletDamageBotSniper = tempValue
		end
	end
	if request.meleeDamageBot ~= nil then
		local tempValue = tonumber(request.meleeDamageBot)
		if tempValue >= 0 then
			Config.meleeDamageBot = tempValue
		end
	end
	if request.meleeAttackIfClose ~= nil then
		Config.meleeAttackIfClose = (request.meleeAttackIfClose == "true")
	end
	if request.useKnifeOnly ~= nil then
		Config.useKnifeOnly = (request.useKnifeOnly == "true")
	end
	if request.shootBackIfHit ~= nil then
		Config.shootBackIfHit = (request.shootBackIfHit == "true")
	end
	if request.botAimWorsening ~= nil then
		local tempValue = tonumber(request.botAimWorsening) / 100
		if tempValue >= 0 and temValue < 10 then
			Config.botAimWorsening = tempValue
		end
	end
	if request.botKit ~= nil then
		local tempString = request.botKit
		for _, kit in pairs(Kits) do
			if tempString == kit then
				Config.botKit = tempString
				break
			end
		end
	end
	if request.botColor ~= nil then
		local tempString = request.botColor
		for _, color in pairs(Colors) do
			if tempString == color then
				Config.botColor = tempString
				break
			end
		end
	end

	--client settings
	if request.maxRaycastDistance ~= nil then
		local tempValue = tonumber(request.maxRaycastDistance)
		if tempValue >= 0 and tempValue <= 500 then
			Config.maxRaycastDistance = tempValue
		end
	end
	if request.distanceForDirectAttack ~= nil then
		local tempValue = tonumber(request.distanceForDirectAttack)
		if tempValue >= 0 and tempValue <= 10 then
			Config.distanceForDirectAttack = tempValue
		end
	end
	NetEvents:BroadcastLocal('WriteClientSettings', Config, false)
end

if (g_FunBotUIServer == nil) then
	g_FunBotUIServer = FunBotUIServer();
end

return g_FunBotUIServer;
