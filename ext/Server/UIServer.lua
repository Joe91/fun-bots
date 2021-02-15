class 'FunBotUIServer';

require('__shared/ArrayMap');
require('__shared/Config');
require('SettingsManager');

Language					= require('__shared/Language');
local BotManager			= require('BotManager');
local TraceManager			= require('TraceManager');
local BotSpawner			= require('BotSpawner');
local WeaponModification	= require('__shared/WeaponModification');
local WeaponList			= require('__shared/WeaponList');
local Globals 				= require('Globals');

function FunBotUIServer:__init()
	self._webui			= 0;
	self._authenticated	= ArrayMap();

	if Config.disableUserInterface ~= true then
		Events:Subscribe('Player:Left', self, self._onPlayerLeft);
		NetEvents:Subscribe('UI_Request_Open', self, self._onUIRequestOpen);
		NetEvents:Subscribe('UI_Request_Save_Settings', self, self._onUIRequestSaveSettings);
		NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent);
	end
end

function FunBotUIServer:_onBotEditorEvent(player, data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIServer: BotEditor (' .. tostring(data) .. ')');

	if (Config.settingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
			print(player.name .. ' has no permissions for Bot-Editor.');
			ChatManager:Yell(Language:I18N('You are not permitted to change Bots. Please press F12 for authenticate!'), 2.5);
		return;
	end

	local request = json.decode(data);

	if request.action == 'request_settings' then
		if Config.language == nil then
			Config.language = 'en_US';
		end

		-- request.opened
		NetEvents:SendTo('UI_Settings', player, Config);

	-- Bots
	elseif request.action == 'bot_spawn_default' then
		local amount = tonumber(request.value);
		local team = player.teamId;
		if team == TeamId.Team1 then
			BotSpawner:spawnWayBots(player, amount, true, 0, 0, TeamId.Team2);
		else
			BotSpawner:spawnWayBots(player, amount, true, 0, 0, TeamId.Team1);
		end

	elseif request.action == 'bot_spawn_friend' then
		local amount = tonumber(request.value);
		BotSpawner:spawnWayBots(player, amount, true, 0, 0, player.teamId);

	elseif request.action == 'bot_spawn_path' then --todo: whats the difference? make a function to spawn bots on a fixed way instead?
		local amount		= 1;
		local indexOnPath	= 1;
		local index			= tonumber(request.value);
		BotSpawner:spawnWayBots(player, amount, false, index, indexOnPath);

	elseif request.action == 'bot_kick_all' then
		BotManager:destroyAllBots();

	elseif request.action == 'bot_kick_team' then
		local teamNumber = tonumber(request.value);
		if teamNumber == 1 then
			BotManager:destroyTeam(TeamId.Team1);
		elseif teamNumber == 2 then
			BotManager:destroyTeam(TeamId.Team2);
		end

	elseif request.action == 'bot_kill_all' then
		BotManager:killAll();

	elseif request.action == 'bot_respawn' then  --toggle this function
		local respawning		= not Globals.respawnWayBots;
		Globals.respawnWayBots	= respawning;
		BotManager:setOptionForAll('respawn', respawning);
		if respawning then
			ChatManager:Yell(Language:I18N('Bot respawn activated!', request.action), 2.5);
		else
			ChatManager:Yell(Language:I18N('Bot respawn deactivated!', request.action), 2.5);
		end

	elseif request.action == 'bot_attack' then  --toggle this function
		local attack			= not Globals.attackWayBots;
		Globals.attackWayBots	= attack;
		BotManager:setOptionForAll('shoot', attack);
		if attack then
			ChatManager:Yell(Language:I18N('Bots will attack!', request.action), 2.5);
		else
			ChatManager:Yell(Language:I18N('Bots will not attack!', request.action), 2.5);
		end

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
		ChatManager:Yell(Language:I18N('%s is currently not implemented.', request.action), 2.5);
	end
end

function FunBotUIServer:_onPlayerLeft(player)
	if Config.disableUserInterface == true then
		return;
	end
	
	-- @ToDo current fix for auth-check after rejoin, remove it later or make it as configuration!
	self._authenticated:delete(tostring(player.accountGuid));
end

function FunBotUIServer:_onUIRequestSaveSettings(player, data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print(player.name .. ' requesting to save settings.');

	if (Config.settingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
		print(player.name .. ' has no permissions for Bot-Editor.');
		ChatManager:Yell(Language:I18N('You are not permitted to change Bots. Please press F12 for authenticate!'), 2.5);
		return;
	end

	local request = json.decode(data);

	self:_writeSettings(player, request);
end

function FunBotUIServer:_onUIRequestOpen(player, data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print(player.name .. ' requesting open Bot-Editor.');

	if (Config.settingsPassword == nil or self:_isAuthenticated(player.accountGuid)) then
		if (Config.settingsPassword == nil) then
			ChatManager:Yell(Language:I18N('The Bot-Editor is not protected by an password!'), 2.5);
			NetEvents:SendTo('UI_Password_Protection', player, 'true');
		end

		print('Open Bot-Editor for ' .. player.name .. '.');
		NetEvents:SendTo('UI_Toggle', player);
		NetEvents:SendTo('UI_Show_Toolbar', player, 'true');
	else
		if (data == nil) then
			print('Ask ' .. player.name .. ' for Bot-Editor password.');
			ChatManager:Yell(Language:I18N('Please authenticate with password!'), 2.5);
			NetEvents:SendTo('UI_Request_Password', player, 'true');
		else
			local form = json.decode(data);

			if (form.password ~= nil or form.password ~= '') then
				print(player.name .. ' has entered following Password: ' .. form.password);

				if (form.password == Config.settingsPassword) then
					self._authenticated:add(tostring(player.accountGuid));
					print('accountGuid: ' .. tostring(player.accountGuid));
					ChatManager:Yell(Language:I18N('Successfully authenticated.'), 2.5);
					NetEvents:SendTo('UI_Request_Password', player, 'false');
					NetEvents:SendTo('UI_Show_Toolbar', player, 'true');
				else
					print(player.name .. ' has entered a bad password.');
					NetEvents:SendTo('UI_Request_Password_Error', player, Language:I18N('The password you entered is not correct!'));
					ChatManager:Yell('Bad password.', 2.5);
				end
			else
				print(player.name .. ' has entered an empty password.');
				NetEvents:SendTo('UI_Request_Password_Error', player, Language:I18N('The password you entered is not correct!'));
				ChatManager:Yell('Please enter a password!', 2.5);
			end
		end
	end
end

function FunBotUIServer:_isAuthenticated(guid)
	if Config.disableUserInterface == true then
		return false;
	end
	
	if self._authenticated:isEmpty() then
		return false;
	end

	return self._authenticated:exists(tostring(guid));
end

function FunBotUIServer:_writeSettings(player, request)
	if Config.disableUserInterface == true then
		return;
	end
	
	local temporary					= false;
	local updateWeapons				= false;
	local updateBotTeamAndNumber	= false;
	local updateWeaponSets			= false;
	local batched					= true;
	
	if request.subaction ~= nil then
		temporary = (request.subaction == 'temp');
	end

	--global settings
	if request.botWeapon ~= nil then
		local tempString = request.botWeapon;

		for _, weapon in pairs(BotWeapons) do
			if tempString == weapon then
				SettingsManager:update('botWeapon', tempString, temporary, batched);
				break
			end
		end
	end

	if request.botAttackMode ~= nil then
		local tempString = request.botAttackMode;

		for _, botAttackMode in pairs(BotAttackModes) do
			if tempString == botAttackMode then
				SettingsManager:update('botAttackMode', tempString, temporary, batched);
				break
			end
		end
	end

	if request.botKit ~= nil then
		local tempString = request.botKit;

		for _, kit in pairs(BotKits) do
			if tempString == kit then
				SettingsManager:update('botKit', tempString, temporary, batched);
				break
			end
		end
	end

	if request.botColor ~= nil then
		local tempString = request.botColor;

		for _, color in pairs(BotColors) do
			if tempString == color then
				SettingsManager:update('botColor', tempString, temporary, batched);
				break
			end
		end
	end

	-- difficluty
	if request.botAimWorsening ~= nil then
		local tempValue = tonumber(request.botAimWorsening)

		if tempValue >= 0 and tempValue <= 10 then
			if math.abs(tempValue - Config.botAimWorsening) > 0.001 then
				SettingsManager:update('botAimWorsening', tempValue, temporary, batched);
				updateWeapons = true;
			end
		end
	end

	if request.botSniperAimWorsening ~= nil then
		local tempValue = tonumber(request.botSniperAimWorsening)

		if tempValue >= 0 and tempValue <= 10 then
			if math.abs(tempValue - Config.botSniperAimWorsening) > 0.001 then
				SettingsManager:update('botSniperAimWorsening', tempValue, temporary, batched);
				updateWeapons = true;
			end
		end
	end

	if request.aimForHead ~= nil then
		SettingsManager:update('aimForHead', (request.aimForHead == true), temporary, batched);
	end
	if request.headShotFactorBots ~= nil then
		local tempValue = tonumber(request.headShotFactorBots);

		if tempValue >= 0.0 then
			SettingsManager:update('headShotFactorBots', tempValue, temporary, batched);
		end
	end

	if request.damageFactorAssault ~= nil then
		local tempValue = tonumber(request.damageFactorAssault);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorAssault', tempValue, temporary, batched);
		end
	end

	if request.damageFactorCarabine ~= nil then
		local tempValue = tonumber(request.damageFactorCarabine);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorCarabine', tempValue, temporary, batched);
		end
	end

	if request.damageFactorLMG ~= nil then
		local tempValue = tonumber(request.damageFactorLMG);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorLMG', tempValue, temporary, batched);
		end
	end

	if request.damageFactorPDW ~= nil then
		local tempValue = tonumber(request.damageFactorPDW);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorPDW', tempValue, temporary, batched);
		end
	end

	if request.damageFactorSniper ~= nil then
		local tempValue = tonumber(request.damageFactorSniper);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorSniper', tempValue, temporary, batched);
		end
	end

	if request.damageFactorShotgun ~= nil then
		local tempValue = tonumber(request.damageFactorShotgun);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorShotgun', tempValue, temporary, batched);
		end
	end

	if request.damageFactorPistol ~= nil then
		local tempValue = tonumber(request.damageFactorPistol);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorPistol', tempValue, temporary, batched);
		end
	end

	if request.damageFactorKnife ~= nil then
		local tempValue = tonumber(request.damageFactorKnife);

		if tempValue >= 0 then
			SettingsManager:update('damageFactorKnife', tempValue, temporary, batched);
		end
	end

	-- advanced
	if request.fovForShooting ~= nil then
		local tempValue = tonumber(request.fovForShooting);

		if tempValue >= 0 and tempValue <= 360 then
			SettingsManager:update('fovForShooting', tempValue, temporary, batched);
		end
	end

	if request.shootBackIfHit ~= nil then
		SettingsManager:update('shootBackIfHit', (request.shootBackIfHit == true), temporary, batched);
	end

	if request.maxRaycastDistance ~= nil then
		local tempValue = tonumber(request.maxRaycastDistance);

		if tempValue >= 0 and tempValue <= 500 then
			SettingsManager:update('maxRaycastDistance', tempValue, temporary, batched);
		end
	end

	if request.maxShootDistanceNoSniper ~= nil then
		local tempValue = tonumber(request.maxShootDistanceNoSniper);

		if tempValue >= 0 and tempValue <= 500 then
			SettingsManager:update('maxShootDistanceNoSniper', tempValue, temporary, batched);
		end
	end

	if request.distanceForDirectAttack ~= nil then
		local tempValue = tonumber(request.distanceForDirectAttack);

		if tempValue >= 0 and tempValue <= 10 then
			SettingsManager:update('distanceForDirectAttack', tempValue, temporary, batched);
		end
	end

	if request.botsAttackBots ~= nil then
		SettingsManager:update('botsAttackBots', (request.botsAttackBots == true), temporary, batched);
	end

	if request.maxBotAttackBotDistance ~= nil then
		local tempValue = tonumber(request.maxBotAttackBotDistance);

		if tempValue >= 0 and tempValue <= 10 then
			SettingsManager:update('maxBotAttackBotDistance', tempValue, temporary, batched);
		end
	end

	if request.meleeAttackIfClose ~= nil then
		SettingsManager:update('meleeAttackIfClose', (request.meleeAttackIfClose == true), temporary, batched);
	end

	if request.botCanKillHimself ~= nil then
		SettingsManager:update('botCanKillHimself', (request.botCanKillHimself == true), temporary, batched);
	end

	if request.attackWayBots ~= nil then
		SettingsManager:update('attackWayBots', (request.attackWayBots == true), temporary, batched);
	end

	if request.meleeAttackCoolDown ~= nil then
		local tempValue = tonumber(request.meleeAttackCoolDown);

		if tempValue >= 0 and tempValue <= 10 then
			SettingsManager:update('meleeAttackCoolDown', tempValue, temporary, batched);
		end
	end

	if request.jumpWhileShooting ~= nil then
		SettingsManager:update('jumpWhileShooting', (request.jumpWhileShooting == true), temporary, batched);
	end

	if request.jumpWhileMoving ~= nil then
		SettingsManager:update('jumpWhileMoving', (request.jumpWhileMoving == true), temporary, batched);
	end

	if request.overWriteBotSpeedMode ~= nil then
		local tempValue = tonumber(request.overWriteBotSpeedMode);

		if tempValue >= 0 and tempValue <= 5 then
			SettingsManager:update('overWriteBotSpeedMode', tempValue, temporary, batched);
		end
	end

	if request.overWriteBotAttackMode ~= nil then
		local tempValue = tonumber(request.overWriteBotAttackMode);

		if tempValue >= 0 and tempValue <= 5 then
			SettingsManager:update('overWriteBotAttackMode', tempValue, temporary, batched);
		end
	end

	if request.speedFactor ~= nil then
		local tempValue = tonumber(request.speedFactor);

		if tempValue > 0 and tempValue <= 2 then
			SettingsManager:update('speedFactor', tempValue, temporary, batched);
		end
	end

	if request.speedFactorAttack ~= nil then
		local tempValue = tonumber(request.speedFactorAttack);

		if tempValue > 0 and tempValue <= 2 then
			SettingsManager:update('speedFactorAttack', tempValue, temporary, batched);
		end
	end

	--spawnning
	if request.spawnMode ~= nil then
		local tempString = request.spawnMode;

		for _, spawnMode in pairs(SpawnModes) do
			if tempString == spawnMode then
				if Config.spawnMode ~= tempString then
					SettingsManager:update('spawnMode', tempString, temporary, batched);
					updateBotTeamAndNumber = true;
				end
				break
			end
		end
	end

	if request.spawnInBothTeams ~= nil then
		local tempVal = (request.spawnInBothTeams == true);
		if tempVal ~= Config.spawnInBothTeams then
			SettingsManager:update('spawnInBothTeams', tempVal, temporary, batched);
			updateBotTeamAndNumber = true;
		end
	end

	if request.onlySpawnBotsWithPlayers ~= nil then
		SettingsManager:update('onlySpawnBotsWithPlayers', (request.onlySpawnBotsWithPlayers == true), temporary, batched);
	end

	if request.initNumberOfBots ~= nil then
		local tempValue = tonumber(request.initNumberOfBots);

		if tempValue > 0 and tempValue <= MAX_NUMBER_OF_BOTS then
			if Config.initNumberOfBots ~= tempValue then
				SettingsManager:update('initNumberOfBots', tempValue, temporary, batched);
				updateBotTeamAndNumber = true;
			end
		end
	end

	if request.newBotsPerNewPlayer ~= nil then
		local tempValue = tonumber(request.newBotsPerNewPlayer);

		if tempValue > 0 and tempValue <= 10 then
			if Config.newBotsPerNewPlayer ~= tempValue then
				SettingsManager:update('newBotsPerNewPlayer', tempValue, temporary, batched);
				updateBotTeamAndNumber = true;
			end
		end
	end

	if request.keepOneSlotForPlayers ~= nil then
		local tempVal = (request.keepOneSlotForPlayers == true);
		if Config.keepOneSlotForPlayers ~= tempVal then
			SettingsManager:update('keepOneSlotForPlayers', tempVal, temporary, batched);
			updateBotTeamAndNumber = true;
		end
	end

	if request.spawnDelayBots ~= nil then
		local tempValue = tonumber(request.spawnDelayBots);

		if tempValue >= 0 and tempValue <= 60 then
			SettingsManager:update('spawnDelayBots', tempValue, temporary, batched);
		end
	end

	if request.botTeam ~= nil then
		local tempValue = tonumber(request.botTeam);

		if tempValue == 1 then
			SettingsManager:update('botTeam', TeamId.Team1, temporary, batched);
		elseif tempValue == 2 then
			SettingsManager:update('botTeam', TeamId.Team2, temporary, batched);
		end
	end

	if request.respawnWayBots ~= nil then
		SettingsManager:update('respawnWayBots', (request.respawnWayBots == true), temporary, batched);
	end

	if request.botNewLoadoutOnSpawn ~= nil then
		SettingsManager:update('botNewLoadoutOnSpawn', (request.botNewLoadoutOnSpawn == true), temporary, batched);
	end

	if request.maxAssaultBots ~= nil then
		local tempValue = tonumber(request.maxAssaultBots);

		if tempValue >= -1 and tempValue <= MAX_NUMBER_OF_BOTS then
			SettingsManager:update('maxAssaultBots', tempValue, temporary, batched);
		end
	end

	if request.maxEngineerBots ~= nil then
		local tempValue = tonumber(request.maxEngineerBots);

		if tempValue >= -1 and tempValue <= MAX_NUMBER_OF_BOTS then
			SettingsManager:update('maxEngineerBots', tempValue, temporary, batched);
		end
	end

	if request.maxSupportBots ~= nil then
		local tempValue = tonumber(request.maxSupportBots);

		if tempValue >= -1 and tempValue <= MAX_NUMBER_OF_BOTS then
			SettingsManager:update('maxSupportBots', tempValue, temporary, batched);
		end
	end

	if request.maxReconBots ~= nil then
		local tempValue = tonumber(request.maxReconBots);

		if tempValue >= -1 and tempValue <= MAX_NUMBER_OF_BOTS then
			SettingsManager:update('maxReconBots', tempValue, temporary, batched);
		end
	end

	if request.distanceToSpawnBots ~= nil then
		local tempValue = tonumber(request.distanceToSpawnBots);

		if tempValue >= 1 and tempValue <= 100 then
			SettingsManager:update('distanceToSpawnBots', tempValue, temporary, batched);
		end
	end

	if request.heightDistanceToSpawn ~= nil then
		local tempValue = tonumber(request.heightDistanceToSpawn);

		if tempValue >= 2 and tempValue <= 100 then
			SettingsManager:update('heightDistanceToSpawn', tempValue, temporary, batched);
		end
	end

	if request.distanceToSpawnReduction ~= nil then
		local tempValue = tonumber(request.distanceToSpawnReduction);

		if tempValue >= 1 and tempValue <= 100 then
			SettingsManager:update('distanceToSpawnReduction', tempValue, temporary, batched);
		end
	end

	if request.maxTrysToSpawnAtDistance ~= nil then
		local tempValue = tonumber(request.maxTrysToSpawnAtDistance);

		if tempValue >= 1 and tempValue <= 10 then
			SettingsManager:update('maxTrysToSpawnAtDistance', tempValue, temporary, batched);
		end
	end

	-- weapons
	if request.useRandomWeapon ~= nil then
		SettingsManager:update('useRandomWeapon', (request.useRandomWeapon == true), temporary, batched);
	end

	if request.pistol ~= nil then
		local tempString = request.pistol;

		for _, pistol in pairs(PistoWeapons) do
			if tempString == pistol then
				SettingsManager:update('pistol', tempString, temporary, batched);
				break
			end
		end
	end

	if request.knife ~= nil then
		local tempString = request.knife;
		
		for _, knife in pairs(KnifeWeapons) do
			if tempString == knife then
				SettingsManager:update('knife', tempString, temporary, batched);
				break
			end
		end
	end

	if request.assaultWeapon ~= nil then
		local tempString = request.assaultWeapon;

		for _, assaultWeapon in pairs(WeaponsAssault) do
			if tempString == assaultWeapon then
				SettingsManager:update('assaultWeapon', tempString, temporary, batched);
				break
			end
		end
	end

	if request.engineerWeapon ~= nil then
		local tempString = request.engineerWeapon;

		for _, engineerWeapon in pairs(WeaponsEngineer) do
			if tempString == engineerWeapon then
				SettingsManager:update('engineerWeapon', tempString, temporary, batched);
				break
			end
		end
	end

	if request.supportWeapon ~= nil then
		local tempString = request.supportWeapon;

		for _, supportWeapon in pairs(WeaponsSupport) do
			if tempString == supportWeapon then
				SettingsManager:update('supportWeapon', tempString, temporary, batched);
				break
			end
		end
	end

	if request.reconWeapon ~= nil then
		local tempString = request.reconWeapon;

		for _, reconWeapon in pairs(WeaponsRecon) do
			if tempString == reconWeapon then
				SettingsManager:update('reconWeapon', tempString, temporary, batched);
				break
			end
		end
	end


	if request.assaultWeaponSet ~= nil then
		local tempString = request.assaultWeaponSet;
		for _, assaultWeaponSet in pairs(WeaponSets) do
			if tempString == assaultWeaponSet then
				if assaultWeaponSet ~= Config.assaultWeaponSet then
					updateWeaponSets = true;
					SettingsManager:update('assaultWeaponSet', tempString, temporary, batched);
				end
				break
			end
		end
	end

	if request.engineerWeaponSet ~= nil then
		local tempString = request.engineerWeaponSet;

		for _, engineerWeaponSet in pairs(WeaponSets) do
			if tempString == engineerWeaponSet then
				if engineerWeaponSet ~= Config.engineerWeaponSet then
					updateWeaponSets = true;
					SettingsManager:update('engineerWeaponSet', tempString, temporary, batched);
				end
				break
			end
		end
	end

	if request.supportWeaponSet ~= nil then
		local tempString = request.supportWeaponSet;

		for _, supportWeaponSet in pairs(WeaponSets) do
			if tempString == supportWeaponSet then
				if supportWeaponSet ~= Config.supportWeaponSet then
					updateWeaponSets = true;
					SettingsManager:update('supportWeaponSet', tempString, temporary, batched);
				end
				break
			end
		end
	end

	if request.reconWeaponSet ~= nil then
		local tempString = request.reconWeaponSet;

		for _, reconWeaponSet in pairs(WeaponSets) do
			if tempString == reconWeaponSet then
				if reconWeaponSet ~= Config.reconWeaponSet then
					updateWeaponSets = true;
					SettingsManager:update('reconWeaponSet', tempString, temporary, batched);
				end
				break
			end
		end
	end

	-- expert
	if request.botFirstShotDelay ~= nil then
		local tempValue = tonumber(request.botFirstShotDelay);

		if tempValue >= 0 and tempValue <= 10.0 then
			SettingsManager:update('botFirstShotDelay', tempValue, temporary, batched);
		end
	end

	if request.botMinTimeShootAtPlayer ~= nil then
		local tempValue = tonumber(request.botMinTimeShootAtPlayer);

		if tempValue >= 0 and tempValue <= Config.botFireModeDuration then
			SettingsManager:update('botMinTimeShootAtPlayer', tempValue, temporary, batched);
		end
	end

	if request.botFireModeDuration ~= nil then
		local tempValue = tonumber(request.botFireModeDuration);

		if tempValue >= 0 and tempValue <= 30.0 then
			SettingsManager:update('botFireModeDuration', tempValue, temporary, batched);
		end
	end

	if request.maximunYawPerSec ~= nil then
		local tempValue = tonumber(request.maximunYawPerSec);

		if tempValue >= 3 and tempValue <= 1000 then
			SettingsManager:update('maximunYawPerSec', tempValue, temporary, batched);
			Globals.yawPerFrame = BotManager:calcYawPerFrame();
		end
	end

	if request.targetDistanceWayPoint ~= nil then
		local tempValue = tonumber(request.targetDistanceWayPoint);

		if tempValue >= 0 and tempValue <= 10 then
			SettingsManager:update('targetDistanceWayPoint', tempValue, temporary);
			Globals.yawPerFrame = BotManager:calcYawPerFrame();
		end
	end

	-- Other
	if request.disableChatCommands ~= nil then
		SettingsManager:update('disableChatCommands', (request.disableChatCommands == true), temporary, batched);
	end
	
	if request.traceUsageAllowed ~= nil then
		SettingsManager:update('traceUsageAllowed', (request.traceUsageAllowed == true), temporary, batched);
	end

	--UI
	if request.language ~= nil then	
		print('Lang changed to: ' .. request.language);
		NetEvents:SendTo('UI_Change_Language', player, request.language);
		SettingsManager:update('language', request.language, temporary, batched);
		Language:loadLanguage(request.language);
	end
	
	if request.settingsPassword ~= nil then
		if request.settingsPassword == "" then
			request.settingsPassword = nil;
		end
		
		if Config.settingsPassword == nil and request.settingsPassword ~= nil then
			ChatManager:Yell(Language:I18N('You can\'t change the password, if it\'s never set!'), 2.5);
		else
			if request.settingsPassword ~= nil and request.settingsPassword ~= "" then
				if request.settingsPassword == "NULL" or request.settingsPassword == "nil" then
					request.settingsPassword = DatabaseField.NULL;
				end
				
				SettingsManager:update('settingsPassword', request.settingsPassword, temporary, batched);
			end
		end
	end
	
	-- Call batched process
	if batched then
		Database:executeBatch();
	end

	if temporary then
		ChatManager:Yell(Language:I18N('Settings has been saved temporarily.'), 2.5);
	else
		ChatManager:Yell(Language:I18N('Settings has been saved.'), 2.5);
	end
	
	-- update Weapons if needed
	if updateWeapons then
		WeaponModification:ModifyAllWeapons(Config.botAimWorsening, Config.botSniperAimWorsening);
	end

	if updateWeaponSets then
		WeaponList:updateWeaponList()
	end
	
	NetEvents:BroadcastLocal('WriteClientSettings', Config, updateWeaponSets);

	if updateBotTeamAndNumber then
		BotSpawner:updateBotAmountAndTeam();
	end
	-- @ToDo create Error Array and dont hide if has values
	NetEvents:SendTo('UI_Settings', player, false);
end

if (g_FunBotUIServer == nil) then
	g_FunBotUIServer = FunBotUIServer();
end

return g_FunBotUIServer;
