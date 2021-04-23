class 'FunBotUIServer'

require('__shared/ArrayMap')
require('__shared/Config')
require('__shared/NodeCollection')
require('SettingsManager')

Language					= require('__shared/Language')
local BotManager			= require('BotManager')
local BotSpawner			= require('BotSpawner')
local WeaponModification	= require('WeaponModification')
local WeaponList			= require('__shared/WeaponList')

function FunBotUIServer:__init()
	self._webui			= 0
	self._authenticated	= ArrayMap()

	if Config.DisableUserInterface ~= true then
		Events:Subscribe('Player:Left', self, self._onPlayerLeft)
		NetEvents:Subscribe('UI_Request_Open', self, self._onUIRequestOpen)
		NetEvents:Subscribe('UI_Request_Save_Settings', self, self._onUIRequestSaveSettings)
		NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent)
		NetEvents:Subscribe('UI_Request_CommoRose_Show', self, self._onUIRequestCommonRoseShow)
		NetEvents:Subscribe('UI_Request_CommoRose_Hide', self, self._onUIRequestCommonRoseHide)
	end
end

function FunBotUIServer:_onBotEditorEvent(player, data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print('UIServer: BotEditor (' .. tostring(data) .. ')')
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
			if Debug.Server.UI then
				print(player.name .. ' has no permissions for Bot-Editor.')
			end

			ChatManager:Yell(Language:I18N('You are not permitted to change Bots. Please press F12 for authenticate!'), 2.5)
		return
	end

	local request = json.decode(data)

	-- Settings
	if request.action == 'request_settings' then
		if Config.Language == nil then
			Config.Language = 'en_US'
		end

		-- request.opened
		NetEvents:SendTo('UI_Settings', player, Config)

	-- Bots
	elseif request.action == 'bot_spawn_default' then
		local amount = tonumber(request.value)
		local team = player.teamId
		Globals.SpawnMode		= "manual"
		if team == TeamId.Team1 then
			BotSpawner:spawnWayBots(player, amount, true, 0, 0, TeamId.Team2)
		else
			BotSpawner:spawnWayBots(player, amount, true, 0, 0, TeamId.Team1)
		end

	elseif request.action == 'bot_spawn_friend' then
		local amount = tonumber(request.value)
		Globals.SpawnMode		= "manual"
		BotSpawner:spawnWayBots(player, amount, true, 0, 0, player.teamId)

	elseif request.action == 'bot_spawn_path' then --todo: whats the difference? make a function to spawn bots on a fixed way instead?
		local amount		= 1
		local indexOnPath	= tonumber(request.pointindex) or 1
		local index			= tonumber(request.value)
		Globals.SpawnMode	= "manual"
		BotSpawner:spawnWayBots(player, amount, false, index, indexOnPath)

	elseif request.action == 'bot_kick_all' then
		Globals.SpawnMode	= "manual"
		BotManager:destroyAll()

	elseif request.action == 'bot_kick_team' then
		Globals.SpawnMode	= "manual"
		local teamNumber = tonumber(request.value)
		if teamNumber == 1 then
			BotManager:destroyAll(nil, TeamId.Team1)
		elseif teamNumber == 2 then
			BotManager:destroyAll(nil, TeamId.Team2)
		end

	elseif request.action == 'bot_kill_all' then
		Globals.SpawnMode	= "manual"
		BotManager:killAll()

	elseif request.action == 'bot_respawn' then  --toggle this function
		local respawning		= not Globals.RespawnWayBots
		Globals.RespawnWayBots	= respawning
		BotManager:setOptionForAll('respawn', respawning)
		if respawning then
			ChatManager:Yell(Language:I18N('Bot respawn activated!', request.action), 2.5)
		else
			ChatManager:Yell(Language:I18N('Bot respawn deactivated!', request.action), 2.5)
		end

	elseif request.action == 'bot_attack' then  --toggle this function
		local attack			= not Globals.AttackWayBots
		Globals.AttackWayBots	= attack
		BotManager:setOptionForAll('shoot', attack)
		if attack then
			ChatManager:Yell(Language:I18N('Bots will attack!', request.action), 2.5)
		else
			ChatManager:Yell(Language:I18N('Bots will not attack!', request.action), 2.5)
		end

	-- Trace
	elseif request.action == 'trace_start' then
		NetEvents:SendToLocal('ClientNodeEditor:StartTrace', player)

	elseif request.action == 'trace_end' then
		NetEvents:SendToLocal('ClientNodeEditor:EndTrace', player)

	elseif request.action == 'trace_save' then
		local index = tonumber(request.value)
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', player, index)

	elseif request.action == 'trace_clear' then
		NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', player)

	elseif request.action == 'trace_reset_all' then
		g_NodeCollection:Clear()
		NetEvents:BroadcastLocal('NodeCollection:Clear')

	elseif request.action == 'waypoints_client_load' then
		local expectedAmount = g_NodeCollection:Get()
		NetEvents:SendToLocal('ClientNodeEditor:ReceiveNodes', player, (#expectedAmount))

	elseif request.action == 'waypoints_client_save' then
		NetEvents:SendToLocal('ClientNodeEditor:SaveNodes', player)

	elseif request.action == 'waypoints_server_load' then
		g_NodeCollection:Load()

	elseif request.action == 'waypoints_server_save' then
		g_NodeCollection:Save()

	-- Waypoints-Editor
	elseif request.action == 'request_waypoints_editor' then
		-- @ToDo Create/check Permissions to use the Wapoints-Editor?
		NetEvents:SendTo('UI_Waypoints_Editor', player, true)
	elseif request.action == 'hide_waypoints_editor' then
		-- @ToDo Create/check Permissions to use the Wapoints-Editor?
		NetEvents:SendTo('UI_Waypoints_Editor', player, false)
	else
		ChatManager:Yell(Language:I18N('%s is currently not implemented.', request.action), 2.5)
	end
end

function FunBotUIServer:_onPlayerLeft(player)
	if Config.DisableUserInterface == true then
		return
	end

	-- @ToDo current fix for auth-check after rejoin, remove it later or make it as configuration!
	self._authenticated:delete(tostring(player.accountGuid))
end

function FunBotUIServer:_onUIRequestSaveSettings(player, data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(player.name .. ' requesting to save settings.')
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
		if Debug.Server.UI then
			print(player.name .. ' has no permissions for Bot-Editor.')
		end

		ChatManager:Yell(Language:I18N('You are not permitted to change Bots. Please press F12 for authenticate!'), 2.5)
		return
	end

	local request = json.decode(data)

	self:_writeSettings(player, request)
end

function FunBotUIServer:_onUIRequestCommonRoseShow(player, data)
	if Config.DisableUserInterface == true then
		return
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
		if Debug.Server.UI then
			print(player.name .. ' has no permissions for Waypoint-Editor.')
		end

		return
	end

	if Debug.Server.UI then
		print(player.name .. ' requesting show CommonRose.')
	end

	NetEvents:SendTo('UI_CommonRose', player, {
		Top = {
			Action	= 'cr_save',
			Label	= Language:I18N('Save'),
			Confirm	= true
		},
		Left = {
			{
				Action	= 'cr_merge',
				Label	= Language:I18N('Merge')
			}, {
				Action	= 'cr_move',
				Label	= Language:I18N('Move')
			}, {
				Action	= 'cr_delete',
				Label	= Language:I18N('Delete')
			}
		},
		Center = {
			Action	= 'cr_select',
			Label	= Language:I18N('Select') -- or "Unselect"
		},
		Right = {
			{
				Action	= 'cr_split',
				Label	= Language:I18N('Split')
			}, {
				Action	= 'cr_set_input',
				Label	= Language:I18N('Set Input'),
				Confirm	= true
			}, {
				Action	= 'cr_create',
				Label	= Language:I18N('Create')
			}
		},
		Bottom = {
			Action	= 'cr_load',
			Label	= Language:I18N('Load'),
			Confirm	= true
		}
	})
end

function FunBotUIServer:_onUIRequestCommonRoseHide(player, data)
	if Config.DisableUserInterface == true then
		return
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(player.accountGuid) ~= true) then
		if Debug.Server.UI then
			print(player.name .. ' has no permissions for Waypoint-Editor.')
		end

		return
	end

	if Debug.Server.UI then
		print(player.name .. ' requesting hide CommonRose.')
	end

	NetEvents:SendTo('UI_CommonRose', player, 'false')
end

function FunBotUIServer:_onUIRequestOpen(player, data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(player.name .. ' requesting open Bot-Editor.')
	end

	if (Config.SettingsPassword == nil or self:_isAuthenticated(player.accountGuid)) then
		if (Config.SettingsPassword == nil) then
			ChatManager:Yell(Language:I18N('The Bot-Editor is not protected by an password!'), 2.5)
			NetEvents:SendTo('UI_Password_Protection', player, 'true')
		end

		if Debug.Server.UI then
			print('Open Bot-Editor for ' .. player.name .. '.')
		end

		NetEvents:SendTo('UI_Toggle', player)
		NetEvents:SendTo('UI_Show_Toolbar', player, 'true')
	else
		if (data == nil) then
			if Debug.Server.UI then
				print('Ask ' .. player.name .. ' for Bot-Editor password.')
			end

			ChatManager:Yell(Language:I18N('Please authenticate with password!'), 2.5)
			NetEvents:SendTo('UI_Request_Password', player, 'true')
		else
			local form = json.decode(data)

			if (form.password ~= nil or form.password ~= '') then
				if Debug.Server.UI then
					print(player.name .. ' has entered following Password: ' .. form.password)
				end

				if (form.password == Config.SettingsPassword) then
					self._authenticated:add(tostring(player.accountGuid))
					if Debug.Server.UI then
						print('accountGuid: ' .. tostring(player.accountGuid))
					end
					ChatManager:Yell(Language:I18N('Successfully authenticated.'), 2.5)
					NetEvents:SendTo('UI_Request_Password', player, 'false')
					NetEvents:SendTo('UI_Show_Toolbar', player, 'true')
				else
					if Debug.Server.UI then
						print(player.name .. ' has entered a bad password.')
					end

					NetEvents:SendTo('UI_Request_Password_Error', player, Language:I18N('The password you entered is not correct!'))
					ChatManager:Yell('Bad password.', 2.5)
				end
			else
				if Debug.Server.UI then
					print(player.name .. ' has entered an empty password.')
				end

				NetEvents:SendTo('UI_Request_Password_Error', player, Language:I18N('The password you entered is not correct!'))
				ChatManager:Yell('Please enter a password!', 2.5)
			end
		end
	end
end

function FunBotUIServer:_isAuthenticated(guid)
	if Config.DisableUserInterface == true then
		return false
	end

	if self._authenticated:isEmpty() then
		return false
	end

	return self._authenticated:exists(tostring(guid))
end

function FunBotUIServer:_writeSingleSetting(name, request, type, temporary, batched, min, max)
	local changed = false
	if type == "bool" then
		if request[name] ~= nil then
			local newValue = (request[name] == true)
			if newValue ~= Config[name] then
				changed = true
			end
			SettingsManager:update(name, newValue, temporary, batched)
		end
	elseif type == "number" then
		if request[name] ~= nil then
			local tempValue = tonumber(request[name])
			if (min == nil or tempValue >= min) and (max == nil or tempValue <= max) then
				if math.abs(tempValue - Config[name]) > 0.001 then --only update on change
					SettingsManager:update(name, tempValue, temporary, batched)
					changed = true
				end
			end
		end
	elseif type == "team" then
		if request[name] ~= nil then
			local tempValue = tonumber(request[name])
			if Config[name] ~= tempValue then
				changed = true
			end
			if tempValue == 0 then
				SettingsManager:update(name, TeamId.TeamNeutral, temporary, batched)
			elseif tempValue == 1 then
				SettingsManager:update(name, TeamId.Team1, temporary, batched)
			elseif tempValue == 2 then
				SettingsManager:update(name, TeamId.Team2, temporary, batched)
			end
		end
	end
	return changed
end

function FunBotUIServer:_writeSingleSettingList(name, request, list, temporary, batched)
	local changed = false
	if request[name] ~= nil then
		local tempString = request[name]

		for _, item in pairs(list) do
			if tempString == item then
				if tempString ~= Config[name] then
					changed = true
				end
				SettingsManager:update(name, tempString, temporary, batched)
				break
			end
		end
	end
	return changed
end

function FunBotUIServer:_writeSettings(player, request)
	if Config.DisableUserInterface == true then
		return
	end

	local temporary					= false
	local updateWeapons				= false
	local updateBotTeamAndNumber	= false
	local updateWeaponSets			= false
	local calcYawPerFrame			= false
	local batched					= true

	if request.subaction ~= nil then
		temporary = (request.subaction == 'temp')
	end

	--global settings
	self:_writeSingleSettingList('botWeapon', request, BotWeapons, temporary, batched)
	self:_writeSingleSettingList('botAttackMode', request, BotAttackModes, temporary, batched)
	self:_writeSingleSettingList('botKit', request, BotKits, temporary, batched)
	self:_writeSingleSettingList('botColor', request, BotColors, temporary, batched)
	self:_writeSingleSetting('zombieMode', request, 'bool', temporary, batched)

	-- difficluty
	if self:_writeSingleSetting('botAimWorsening', request, 'number', temporary, batched, 0, 10) then updateWeapons = true end
	if self:_writeSingleSetting('botSniperAimWorsening', request, 'number', temporary, batched, 0, 10) then	updateWeapons = true end
	self:_writeSingleSetting('aimForHead', request, 'bool', temporary, batched)
	self:_writeSingleSetting('headShotFactorBots', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorAssault', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorCarabine', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorLMG', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorPDW', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorSniper', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorShotgun', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorPistol', request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorKnife', request, 'number', temporary, batched, 0)

	-- advanced
	self:_writeSingleSetting('fovForShooting', request, 'number', temporary, batched, 0, 360)
	self:_writeSingleSetting('shootBackIfHit', request, 'bool', temporary, batched)
	self:_writeSingleSetting('maxRaycastDistance', request, 'number', temporary, batched, 0, 500)
	self:_writeSingleSetting('maxShootDistanceNoSniper', request, 'number', temporary, batched, 0, 500)
	self:_writeSingleSetting('distanceForDirectAttack', request, 'number', temporary, batched, 0, 15)
	self:_writeSingleSetting('botsAttackBots', request, 'bool', temporary, batched)
	self:_writeSingleSetting('maxBotAttackBotDistance', request, 'number', temporary, batched, 0, 100)

	self:_writeSingleSetting('meleeAttackIfClose', request, 'bool', temporary, batched)
	self:_writeSingleSetting('botCanKillHimself', request, 'bool', temporary, batched)
	self:_writeSingleSetting('attackWayBots', request, 'bool', temporary, batched)

	self:_writeSingleSetting('meleeAttackCoolDown', request, 'number', temporary, batched, 0, 10)
	self:_writeSingleSetting('jumpWhileShooting', request, 'bool', temporary, batched)
	self:_writeSingleSetting('jumpWhileMoving', request, 'bool', temporary, batched)

	self:_writeSingleSetting('overWriteBotSpeedMode', request, 'number', temporary, batched, 0, 5)
	self:_writeSingleSetting('overWriteBotAttackMode', request, 'number', temporary, batched, 0, 5)

	self:_writeSingleSetting('speedFactor', request, 'number', temporary, batched, 0, 2)
	self:_writeSingleSetting('speedFactorAttack', request, 'number', temporary, batched, 0, 2)

	--spawnning
	if self:_writeSingleSettingList('spawnMode', request, SpawnModes, temporary, batched) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('spawnInBothTeams', request, 'bool', temporary, batched) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('initNumberOfBots', request, 'number', temporary, batched, 0, MAX_NUMBER_OF_BOTS) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('newBotsPerNewPlayer', request, 'number', temporary, batched, 0, 20) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('keepOneSlotForPlayers', request, 'bool', temporary, batched) then updateBotTeamAndNumber = true end
	self:_writeSingleSetting('spawnDelayBots', request, 'number', temporary, batched, 0, 60)
	self:_writeSingleSetting('botTeam', request, 'team', temporary, batched)
	self:_writeSingleSetting('respawnWayBots', request, 'bool', temporary, batched)
	self:_writeSingleSetting('botNewLoadoutOnSpawn', request, 'bool', temporary, batched)

	self:_writeSingleSetting('maxAssaultBots', request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)
	self:_writeSingleSetting('maxEngineerBots', request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)
	self:_writeSingleSetting('maxSupportBots', request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)
	self:_writeSingleSetting('maxReconBots', request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)

	self:_writeSingleSetting('distanceToSpawnBots', request, 'number', temporary, batched, 0, 100)
	self:_writeSingleSetting('heightDistanceToSpawn', request, 'number', temporary, batched, 0, 20)
	self:_writeSingleSetting('distanceToSpawnReduction', request, 'number', temporary, batched, 0, 100)
	self:_writeSingleSetting('maxTrysToSpawnAtDistance', request, 'number', temporary, batched, 0, 20)

	-- weapons
	self:_writeSingleSetting('useRandomWeapon', request, 'bool', temporary, batched)
	self:_writeSingleSettingList('pistol', request, PistoWeapons, temporary, batched)
	self:_writeSingleSettingList('knife', request, KnifeWeapons, temporary, batched)
	self:_writeSingleSettingList('assaultWeapon', request, AssaultPrimary, temporary, batched)
	self:_writeSingleSettingList('engineerWeapon', request, EngineerPrimary, temporary, batched)
	self:_writeSingleSettingList('supportWeapon', request, SupportPrimary, temporary, batched)
	self:_writeSingleSettingList('reconWeapon', request, ReconPrimary, temporary, batched)

	-- trace
	self:_writeSingleSetting('debugTracePaths', request, 'bool', temporary, batched)
	self:_writeSingleSetting('waypointRange', request, 'number', temporary, batched, 0, 1000)
	self:_writeSingleSetting('drawWaypointLines', request, 'bool', temporary, batched)
	self:_writeSingleSetting('lineRange', request, 'number', temporary, batched, 0, 1000)
	self:_writeSingleSetting('drawWaypointIDs', request, 'bool', temporary, batched)
	self:_writeSingleSetting('textRange', request, 'number', temporary, batched, 0, 1000)
	self:_writeSingleSetting('debugSelectionRaytraces', request, 'bool', temporary, batched)
	self:_writeSingleSetting('traceDelta', request, 'number', temporary, batched, 0, 10)

	if self:_writeSingleSettingList('assaultWeaponSet', request, WeaponSets, temporary, batched) then updateWeaponSets = true end
	if self:_writeSingleSettingList('engineerWeaponSet', request, WeaponSets, temporary, batched) then updateWeaponSets = true end
	if self:_writeSingleSettingList('supportWeaponSet', request, WeaponSets, temporary, batched) then updateWeaponSets = true end
	if self:_writeSingleSettingList('reconWeaponSet', request, WeaponSets, temporary, batched) then updateWeaponSets = true end

	-- expert
	self:_writeSingleSetting('botFirstShotDelay', request, 'number', temporary, batched, 0, 5)
	self:_writeSingleSetting('botFireModeDuration', request, 'number', temporary, batched, 0, 60)
	self:_writeSingleSetting('botMinTimeShootAtPlayer', request, 'number', temporary, batched, 0, Config.BotFireModeDuration)
	if self:_writeSingleSetting('maximunYawPerSec', request, 'number', temporary, batched, 3, 1000) then calcYawPerFrame = true end
	self:_writeSingleSetting('targetDistanceWayPoint', request, 'number', temporary, batched, 0, 10)


	-- Other
	self:_writeSingleSetting('disableChatCommands', request, 'bool', temporary, batched)
	self:_writeSingleSetting('traceUsageAllowed', request, 'bool', temporary, batched)

	--UI
	if request.language ~= nil then
		if Debug.Server.UI then
			print('Lang changed to: ' .. request.language)
		end

		NetEvents:SendTo('UI_Change_Language', player, request.language)
		SettingsManager:update('language', request.language, temporary, batched)
		Language:loadLanguage(request.language)
	end

	if request.settingsPassword ~= nil then
		if request.settingsPassword == "" then
			request.settingsPassword = nil
		end

		if Config.SettingsPassword == nil and request.settingsPassword ~= nil then
			ChatManager:Yell(Language:I18N('You can\'t change the password, if it\'s never set!'), 2.5)
		else
			if request.settingsPassword ~= nil and request.settingsPassword ~= "" then
				if request.settingsPassword == "NULL" or request.settingsPassword == "nil" then
					request.settingsPassword = DatabaseField.NULL
				end

				SettingsManager:update('settingsPassword', request.settingsPassword, temporary, batched)
			end
		end
	end

	-- Call batched process
	if batched then
		Database:executeBatch()
	end

	if temporary then
		ChatManager:Yell(Language:I18N('Settings has been saved temporarily.'), 2.5)
	else
		ChatManager:Yell(Language:I18N('Settings has been saved.'), 2.5)
	end

	-- update Weapons if needed
	if updateWeapons then
		WeaponModification:ModifyAllWeapons(Config.BotAimWorsening, Config.BotSniperAimWorsening)
	end

	if updateWeaponSets then
		WeaponList:updateWeaponList()
	end

	if calcYawPerFrame then
		Globals.YawPerFrame = BotManager:calcYawPerFrame()
	end

	NetEvents:BroadcastLocal('WriteClientSettings', Config, updateWeaponSets)

	if updateBotTeamAndNumber then
		Globals.SpawnMode		= Config.SpawnMode
		BotSpawner:updateBotAmountAndTeam()
	end
	-- @ToDo create Error Array and dont hide if has values
	NetEvents:SendTo('UI_Settings', player, false)
end

if (g_FunBotUIServer == nil) then
	g_FunBotUIServer = FunBotUIServer()
end

return g_FunBotUIServer
