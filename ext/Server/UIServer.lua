class 'FunBotUIServer'

require('__shared/ArrayMap')
require('__shared/Config')

local m_NodeCollection = require('__shared/NodeCollection')
local m_SettingsManager = require('SettingsManager')

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

function FunBotUIServer:_onBotEditorEvent(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print('UIServer: BotEditor (' .. tostring(p_Data) .. ')')
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(p_Player.accountGuid) ~= true) then
			if Debug.Server.UI then
				print(p_Player.name .. ' has no permissions for Bot-Editor.')
			end

			ChatManager:Yell(Language:I18N('You are not permitted to change Bots. Please press F12 for authenticate!'), 2.5)
		return
	end

	local request = json.decode(p_Data)

	-- Settings
	if request.action == 'request_settings' then
		if Config.Language == nil then
			Config.Language = 'en_US'
		end

		-- request.opened
		NetEvents:SendTo('UI_Settings', p_Player, Config)

	-- Bots
	elseif request.action == 'bot_spawn_default' then
		local amount = tonumber(request.value)
		local team = p_Player.teamId
		Globals.SpawnMode		= "manual"
		if team == TeamId.Team1 then
			BotSpawner:spawnWayBots(p_Player, amount, true, 0, 0, TeamId.Team2)
		else
			BotSpawner:spawnWayBots(p_Player, amount, true, 0, 0, TeamId.Team1)
		end

	elseif request.action == 'bot_spawn_friend' then
		local amount = tonumber(request.value)
		Globals.SpawnMode		= "manual"
		BotSpawner:spawnWayBots(p_Player, amount, true, 0, 0, p_Player.teamId)

	elseif request.action == 'bot_spawn_path' then --todo: whats the difference? make a function to spawn bots on a fixed way instead?
		local amount		= 1
		local indexOnPath	= tonumber(request.pointindex) or 1
		local index			= tonumber(request.value)
		Globals.SpawnMode	= "manual"
		BotSpawner:spawnWayBots(p_Player, amount, false, index, indexOnPath)

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
		NetEvents:SendToLocal('ClientNodeEditor:StartTrace', p_Player)

	elseif request.action == 'trace_end' then
		NetEvents:SendToLocal('ClientNodeEditor:EndTrace', p_Player)

	elseif request.action == 'trace_save' then
		local index = tonumber(request.value)
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', p_Player, index)

	elseif request.action == 'trace_clear' then
		NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', p_Player)

	elseif request.action == 'trace_reset_all' then
		m_NodeCollection:Clear()
		NetEvents:BroadcastLocal('NodeCollection:Clear')

	elseif request.action == 'waypoints_client_load' then
		local expectedAmount = m_NodeCollection:Get()
		NetEvents:SendToLocal('ClientNodeEditor:ReceiveNodes', p_Player, (#expectedAmount))

	elseif request.action == 'waypoints_client_save' then
		NetEvents:SendToLocal('ClientNodeEditor:SaveNodes', p_Player)

	elseif request.action == 'waypoints_server_load' then
		m_NodeCollection:Load()

	elseif request.action == 'waypoints_server_save' then
		m_NodeCollection:Save()

	-- Waypoints-Editor
	elseif request.action == 'request_waypoints_editor' then
		-- @ToDo Create/check Permissions to use the Wapoints-Editor?
		NetEvents:SendTo('UI_Waypoints_Editor', p_Player, true)
	elseif request.action == 'hide_waypoints_editor' then
		-- @ToDo Create/check Permissions to use the Wapoints-Editor?
		NetEvents:SendTo('UI_Waypoints_Editor', p_Player, false)
	else
		ChatManager:Yell(Language:I18N('%s is currently not implemented.', request.action), 2.5)
	end
end

function FunBotUIServer:_onPlayerLeft(p_Player)
	if Config.DisableUserInterface == true then
		return
	end

	-- @ToDo current fix for auth-check after rejoin, remove it later or make it as configuration!
	self._authenticated:delete(tostring(p_Player.accountGuid))
end

function FunBotUIServer:_onUIRequestSaveSettings(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting to save settings.')
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(p_Player.accountGuid) ~= true) then
		if Debug.Server.UI then
			print(p_Player.name .. ' has no permissions for Bot-Editor.')
		end

		ChatManager:Yell(Language:I18N('You are not permitted to change Bots. Please press F12 for authenticate!'), 2.5)
		return
	end

	local request = json.decode(p_Data)

	self:_writeSettings(p_Player, request)
end

function FunBotUIServer:_onUIRequestCommonRoseShow(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(p_Player.accountGuid) ~= true) then
		if Debug.Server.UI then
			print(p_Player.name .. ' has no permissions for Waypoint-Editor.')
		end

		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting show CommonRose.')
	end

	NetEvents:SendTo('UI_CommonRose', p_Player, {
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

function FunBotUIServer:_onUIRequestCommonRoseHide(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if (Config.SettingsPassword ~= nil and self:_isAuthenticated(p_Player.accountGuid) ~= true) then
		if Debug.Server.UI then
			print(p_Player.name .. ' has no permissions for Waypoint-Editor.')
		end

		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting hide CommonRose.')
	end

	NetEvents:SendTo('UI_CommonRose', p_Player, 'false')
end

function FunBotUIServer:_onUIRequestOpen(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting open Bot-Editor.')
	end

	if (Config.SettingsPassword == nil or self:_isAuthenticated(p_Player.accountGuid)) then
		if (Config.SettingsPassword == nil) then
			ChatManager:Yell(Language:I18N('The Bot-Editor is not protected by an password!'), 2.5)
			NetEvents:SendTo('UI_Password_Protection', p_Player, 'true')
		end

		if Debug.Server.UI then
			print('Open Bot-Editor for ' .. p_Player.name .. '.')
		end

		NetEvents:SendTo('UI_Toggle', p_Player)
		NetEvents:SendTo('UI_Show_Toolbar', p_Player, 'true')
	else
		if (p_Data == nil) then
			if Debug.Server.UI then
				print('Ask ' .. p_Player.name .. ' for Bot-Editor password.')
			end

			ChatManager:Yell(Language:I18N('Please authenticate with password!'), 2.5)
			NetEvents:SendTo('UI_Request_Password', p_Player, 'true')
		else
			local form = json.decode(p_Data)

			if (form.password ~= nil or form.password ~= '') then
				if Debug.Server.UI then
					print(p_Player.name .. ' has entered following Password: ' .. form.password)
				end

				if (form.password == Config.SettingsPassword) then
					self._authenticated:add(tostring(p_Player.accountGuid))
					if Debug.Server.UI then
						print('accountGuid: ' .. tostring(p_Player.accountGuid))
					end
					ChatManager:Yell(Language:I18N('Successfully authenticated.'), 2.5)
					NetEvents:SendTo('UI_Request_Password', p_Player, 'false')
					NetEvents:SendTo('UI_Show_Toolbar', p_Player, 'true')
				else
					if Debug.Server.UI then
						print(p_Player.name .. ' has entered a bad password.')
					end

					NetEvents:SendTo('UI_Request_Password_Error', p_Player, Language:I18N('The password you entered is not correct!'))
					ChatManager:Yell('Bad password.', 2.5)
				end
			else
				if Debug.Server.UI then
					print(p_Player.name .. ' has entered an empty password.')
				end

				NetEvents:SendTo('UI_Request_Password_Error', p_Player, Language:I18N('The password you entered is not correct!'))
				ChatManager:Yell('Please enter a password!', 2.5)
			end
		end
	end
end

function FunBotUIServer:_isAuthenticated(p_Guid)
	if Config.DisableUserInterface == true then
		return false
	end

	if self._authenticated:isEmpty() then
		return false
	end

	return self._authenticated:exists(tostring(p_Guid))
end

function FunBotUIServer:_writeSingleSetting(p_Name, p_Request, p_Type, p_Temporary, p_Batched, p_Min, p_Max)
	local changed = false
	if p_Type == "bool" then
		if p_Request[p_Name] ~= nil then
			local newValue = (p_Request[p_Name] == true)
			if newValue ~= Config[p_Name] then
				changed = true
			end
			m_SettingsManager:update(p_Name, newValue, p_Temporary, p_Batched)
		end
	elseif p_Type == "number" then
		if p_Request[p_Name] ~= nil then
			local tempValue = tonumber(p_Request[p_Name])
			if (p_Min == nil or tempValue >= p_Min) and (p_Max == nil or tempValue <= p_Max) then
				if math.abs(tempValue - Config[p_Name]) > 0.001 then --only update on change
					m_SettingsManager:update(p_Name, tempValue, p_Temporary, p_Batched)
					changed = true
				end
			end
		end
	elseif p_Type == "team" then
		if p_Request[p_Name] ~= nil then
			local tempValue = tonumber(p_Request[p_Name])
			if Config[p_Name] ~= tempValue then
				changed = true
			end
			if tempValue == 0 then
				m_SettingsManager:update(p_Name, TeamId.TeamNeutral, p_Temporary, p_Batched)
			elseif tempValue == 1 then
				m_SettingsManager:update(p_Name, TeamId.Team1, p_Temporary, p_Batched)
			elseif tempValue == 2 then
				m_SettingsManager:update(p_Name, TeamId.Team2, p_Temporary, p_Batched)
			end
		end
	end
	return changed
end

function FunBotUIServer:_writeSingleSettingList(p_Name, p_Request, p_List, p_Temporary, p_Batched)
	local changed = false
	if p_Request[p_Name] ~= nil then
		local tempString = p_Request[p_Name]

		for _, item in pairs(p_List) do
			if tempString == item then
				if tempString ~= Config[p_Name] then
					changed = true
				end
				m_SettingsManager:update(p_Name, tempString, p_Temporary, p_Batched)
				break
			end
		end
	end
	return changed
end

function FunBotUIServer:_writeSettings(p_Player, p_Request)
	if Config.DisableUserInterface == true then
		return
	end

	local temporary					= false
	local updateWeapons				= false
	local updateBotTeamAndNumber	= false
	local updateWeaponSets			= false
	local calcYawPerFrame			= false
	local batched					= true

	if p_Request.subaction ~= nil then
		temporary = (p_Request.subaction == 'temp')
	end

	--global settings
	self:_writeSingleSettingList('botWeapon', p_Request, BotWeapons, temporary, batched)
	self:_writeSingleSettingList('botAttackMode', p_Request, BotAttackModes, temporary, batched)
	self:_writeSingleSettingList('botKit', p_Request, BotKits, temporary, batched)
	self:_writeSingleSettingList('botColor', p_Request, BotColors, temporary, batched)
	self:_writeSingleSetting('zombieMode', p_Request, 'bool', temporary, batched)

	-- difficluty
	if self:_writeSingleSetting('botAimWorsening', p_Request, 'number', temporary, batched, 0, 10) then updateWeapons = true end
	if self:_writeSingleSetting('botSniperAimWorsening', p_Request, 'number', temporary, batched, 0, 10) then	updateWeapons = true end
	self:_writeSingleSetting('aimForHead', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('headShotFactorBots', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorAssault', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorCarabine', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorLMG', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorPDW', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorSniper', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorShotgun', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorPistol', p_Request, 'number', temporary, batched, 0)
	self:_writeSingleSetting('damageFactorKnife', p_Request, 'number', temporary, batched, 0)

	-- advanced
	self:_writeSingleSetting('fovForShooting', p_Request, 'number', temporary, batched, 0, 360)
	self:_writeSingleSetting('shootBackIfHit', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('maxRaycastDistance', p_Request, 'number', temporary, batched, 0, 500)
	self:_writeSingleSetting('maxShootDistanceNoSniper', p_Request, 'number', temporary, batched, 0, 500)
	self:_writeSingleSetting('distanceForDirectAttack', p_Request, 'number', temporary, batched, 0, 15)
	self:_writeSingleSetting('botsAttackBots', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('maxBotAttackBotDistance', p_Request, 'number', temporary, batched, 0, 100)

	self:_writeSingleSetting('meleeAttackIfClose', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('botCanKillHimself', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('attackWayBots', p_Request, 'bool', temporary, batched)

	self:_writeSingleSetting('meleeAttackCoolDown', p_Request, 'number', temporary, batched, 0, 10)
	self:_writeSingleSetting('jumpWhileShooting', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('jumpWhileMoving', p_Request, 'bool', temporary, batched)

	self:_writeSingleSetting('overWriteBotSpeedMode', p_Request, 'number', temporary, batched, 0, 5)
	self:_writeSingleSetting('overWriteBotAttackMode', p_Request, 'number', temporary, batched, 0, 5)

	self:_writeSingleSetting('speedFactor', p_Request, 'number', temporary, batched, 0, 2)
	self:_writeSingleSetting('speedFactorAttack', p_Request, 'number', temporary, batched, 0, 2)

	--spawnning
	if self:_writeSingleSettingList('spawnMode', p_Request, SpawnModes, temporary, batched) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('spawnInBothTeams', p_Request, 'bool', temporary, batched) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('initNumberOfBots', p_Request, 'number', temporary, batched, 0, MAX_NUMBER_OF_BOTS) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('newBotsPerNewPlayer', p_Request, 'number', temporary, batched, 0, 20) then updateBotTeamAndNumber = true end
	if self:_writeSingleSetting('keepOneSlotForPlayers', p_Request, 'bool', temporary, batched) then updateBotTeamAndNumber = true end
	self:_writeSingleSetting('spawnDelayBots', p_Request, 'number', temporary, batched, 0, 60)
	self:_writeSingleSetting('botTeam', p_Request, 'team', temporary, batched)
	self:_writeSingleSetting('respawnWayBots', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('botNewLoadoutOnSpawn', p_Request, 'bool', temporary, batched)

	self:_writeSingleSetting('maxAssaultBots', p_Request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)
	self:_writeSingleSetting('maxEngineerBots', p_Request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)
	self:_writeSingleSetting('maxSupportBots', p_Request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)
	self:_writeSingleSetting('maxReconBots', p_Request, 'number', temporary, batched, -1, MAX_NUMBER_OF_BOTS)

	self:_writeSingleSetting('distanceToSpawnBots', p_Request, 'number', temporary, batched, 0, 100)
	self:_writeSingleSetting('heightDistanceToSpawn', p_Request, 'number', temporary, batched, 0, 20)
	self:_writeSingleSetting('distanceToSpawnReduction', p_Request, 'number', temporary, batched, 0, 100)
	self:_writeSingleSetting('maxTrysToSpawnAtDistance', p_Request, 'number', temporary, batched, 0, 20)

	-- weapons
	self:_writeSingleSetting('useRandomWeapon', p_Request, 'bool', temporary, batched)
	self:_writeSingleSettingList('pistol', p_Request, PistoWeapons, temporary, batched)
	self:_writeSingleSettingList('knife', p_Request, KnifeWeapons, temporary, batched)
	self:_writeSingleSettingList('assaultWeapon', p_Request, AssaultPrimary, temporary, batched)
	self:_writeSingleSettingList('engineerWeapon', p_Request, EngineerPrimary, temporary, batched)
	self:_writeSingleSettingList('supportWeapon', p_Request, SupportPrimary, temporary, batched)
	self:_writeSingleSettingList('reconWeapon', p_Request, ReconPrimary, temporary, batched)

	-- trace
	self:_writeSingleSetting('debugTracePaths', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('waypointRange', p_Request, 'number', temporary, batched, 0, 1000)
	self:_writeSingleSetting('drawWaypointLines', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('lineRange', p_Request, 'number', temporary, batched, 0, 1000)
	self:_writeSingleSetting('drawWaypointIDs', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('textRange', p_Request, 'number', temporary, batched, 0, 1000)
	self:_writeSingleSetting('debugSelectionRaytraces', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('traceDelta', p_Request, 'number', temporary, batched, 0, 10)

	if self:_writeSingleSettingList('assaultWeaponSet', p_Request, WeaponSets, temporary, batched) then updateWeaponSets = true end
	if self:_writeSingleSettingList('engineerWeaponSet', p_Request, WeaponSets, temporary, batched) then updateWeaponSets = true end
	if self:_writeSingleSettingList('supportWeaponSet', p_Request, WeaponSets, temporary, batched) then updateWeaponSets = true end
	if self:_writeSingleSettingList('reconWeaponSet', p_Request, WeaponSets, temporary, batched) then updateWeaponSets = true end

	-- expert
	self:_writeSingleSetting('botFirstShotDelay', p_Request, 'number', temporary, batched, 0, 5)
	self:_writeSingleSetting('botFireModeDuration', p_Request, 'number', temporary, batched, 0, 60)
	self:_writeSingleSetting('botMinTimeShootAtPlayer', p_Request, 'number', temporary, batched, 0, Config.BotFireModeDuration)
	if self:_writeSingleSetting('maximunYawPerSec', p_Request, 'number', temporary, batched, 3, 1000) then calcYawPerFrame = true end
	self:_writeSingleSetting('targetDistanceWayPoint', p_Request, 'number', temporary, batched, 0, 10)


	-- Other
	self:_writeSingleSetting('disableChatCommands', p_Request, 'bool', temporary, batched)
	self:_writeSingleSetting('traceUsageAllowed', p_Request, 'bool', temporary, batched)

	--UI
	if p_Request.language ~= nil then
		if Debug.Server.UI then
			print('Lang changed to: ' .. p_Request.language)
		end

		NetEvents:SendTo('UI_Change_Language', p_Player, p_Request.language)
		m_SettingsManager:update('language', p_Request.language, temporary, batched)
		Language:loadLanguage(p_Request.language)
	end

	if p_Request.settingsPassword ~= nil then
		if p_Request.settingsPassword == "" then
			p_Request.settingsPassword = nil
		end

		if Config.SettingsPassword == nil and p_Request.settingsPassword ~= nil then
			ChatManager:Yell(Language:I18N('You can\'t change the password, if it\'s never set!'), 2.5)
		else
			if p_Request.settingsPassword ~= nil and p_Request.settingsPassword ~= "" then
				if p_Request.settingsPassword == "NULL" or p_Request.settingsPassword == "nil" then
					p_Request.settingsPassword = DatabaseField.NULL
				end

				m_SettingsManager:update('settingsPassword', p_Request.settingsPassword, temporary, batched)
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
	NetEvents:SendTo('UI_Settings', p_Player, false)
end

if (g_FunBotUIServer == nil) then
	g_FunBotUIServer = FunBotUIServer()
end

return g_FunBotUIServer
