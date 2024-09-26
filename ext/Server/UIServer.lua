---@class FunBotUIServer
---@overload fun():FunBotUIServer
FunBotUIServer = class 'FunBotUIServer'

require('__shared/ArrayMap')
require('__shared/Config')

---@type Language
Language = require('__shared/Language')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type SettingsManager
local m_SettingsManager = require('SettingsManager')
-- @type NodeEditor
local m_NodeEditor = require('NodeEditor')

---@type BotManager
local BotManager = require('BotManager')
---@type BotSpawner
local BotSpawner = require('BotSpawner')
---@type WeaponList
local WeaponList = require('__shared/WeaponList')

function FunBotUIServer:__init()
	-- To-do: remove? Unused.
	self.m_NavigaionPath = {}
	self.m_InPathMenu = false


	if Config.DisableUserInterface ~= true then
		NetEvents:Subscribe('UI_Request_Open', self, self._onUIRequestOpen)
		NetEvents:Subscribe('UI_Request_Save_Settings', self, self._onUIRequestSaveSettings)
		NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent)
		Events:Subscribe('BotEditor', self, self._onBotEditorEvent)
		NetEvents:Subscribe('UI_Request_CommoRose_Show', self, self._onUIRequestCommoRoseShow)
	end
end

function FunBotUIServer:_onBotEditorEvent(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	local request = json.decode(p_Data)

	-- Comm Screen.
	if request.action == 'exit_vehicle' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		BotManager:ExitVehicle(p_Player)
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif request.action == 'drop_ammo' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		BotManager:Deploy(p_Player, "ammo")
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif request.action == 'drop_medkit' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		BotManager:Deploy(p_Player, "medkit")
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif request.action == 'enter_vehicle' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		BotManager:EnterVehicle(p_Player)
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif request.action == 'repair_vehicle' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		BotManager:RepairVehicle(p_Player)
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif request.action == 'attack_objective' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		-- Change Commo-rose.
		NetEvents:SendTo('UI_CommoRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'attack_a',
					Label = Language:I18N('A')
				},
				{
					Action = 'attack_b',
					Label = Language:I18N('B')
				},
				{
					Action = 'attack_c',
					Label = Language:I18N('C')
				},
				{
					Action = 'attack_d',
					Label = Language:I18N('D')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Attack') -- Or "Unselect".
			},
			Right = {
				{
					Action = 'attack_e',
					Label = Language:I18N('E')
				},
				{
					Action = 'attack_f',
					Label = Language:I18N('F')
				},
				{
					Action = 'attack_g',
					Label = Language:I18N('G')
				},
				{
					Action = 'attack_h',
					Label = Language:I18N('H')
				}
			},
			Bottom = {
				Action = 'back_to_comm',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif request.action == 'defend_objective' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		NetEvents:SendTo('UI_CommoRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'defend_a',
					Label = Language:I18N('A')
				},
				{
					Action = 'defend_b',
					Label = Language:I18N('B')
				},
				{
					Action = 'defend_c',
					Label = Language:I18N('C')
				},
				{
					Action = 'defend_d',
					Label = Language:I18N('D')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Defend') -- Or "Unselect".
			},
			Right = {
				{
					Action = 'defend_e',
					Label = Language:I18N('E')
				},
				{
					Action = 'defend_f',
					Label = Language:I18N('F')
				},
				{
					Action = 'defend_g',
					Label = Language:I18N('G')
				},
				{
					Action = 'defend_h',
					Label = Language:I18N('H')
				}
			},
			Bottom = {
				Action = 'back_to_comm',
				Label = Language:I18N('Back'),
			}
		})
		return
	elseif string.find(request.action, 'attack_') ~= nil then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local s_Objective = request.action:split('_')[2]
		BotManager:Attack(p_Player, s_Objective)
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif string.find(request.action, "defend_") ~= nil then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local s_Objective = request.action:split('_')[2]
		BotManager:Attack(p_Player, s_Objective)
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif request.action == 'back_to_comm' then
		if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		self:_onUIRequestCommoRoseShow(p_Player)
		return
	end

	-- General Commands.
	if PermissionManager:HasPermission(p_Player, 'UserInterface') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	-- Settings.
	if request.action == 'request_settings' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.Settings') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		if Config.Language == nil then
			Config.Language = 'en_US'
		end

		-- request.opened
		NetEvents:SendTo('UI_Settings', p_Player, Config)
		return
		-- Bots.
	elseif request.action == 'bot_spawn_default' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.Spawn') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local amount = tonumber(request.value)
		if amount == nil then
			return
		end
		local team = p_Player.teamId
		Globals.SpawnMode = "manual"

		if team == TeamId.Team1 then
			BotSpawner:SpawnWayBots(amount, true, 0, 0, TeamId.Team2)
		else
			BotSpawner:SpawnWayBots(amount, true, 0, 0, TeamId.Team1)
		end
		return
	elseif request.action == 'bot_spawn_friend' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.Spawn') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local amount = tonumber(request.value)
		Globals.SpawnMode = "manual"
		if amount then
			BotSpawner:SpawnWayBots(amount, true, 0, 0, p_Player.teamId)
		end
		return
	elseif request.action == 'bot_spawn_path' then -- To-do: what's the difference? Make a function to spawn bots on a fixed way instead?
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.Spawn') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local amount = 1
		local indexOnPath = tonumber(request.pointindex) or 1
		local index = tonumber(request.value)
		Globals.SpawnMode = "manual"
		local s_TeamId = p_Player.teamId + 1

		if s_TeamId > Globals.NrOfTeams then
			s_TeamId = s_TeamId - Globals.NrOfTeams
		end

		BotSpawner:SpawnWayBots(amount, false, index, indexOnPath, s_TeamId)
		return
	elseif request.action == 'bot_kick_all' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.KickAll') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		Globals.SpawnMode = "manual"
		BotManager:DestroyAll()
		return
	elseif request.action == 'bot_kick_team' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.KickTeam') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		Globals.SpawnMode = "manual"
		local teamNumber = tonumber(request.value)

		if teamNumber == 1 then
			BotManager:DestroyAll(nil, TeamId.Team1)
		elseif teamNumber == 2 then
			BotManager:DestroyAll(nil, TeamId.Team2)
		end
		return
	elseif request.action == 'bot_kill_all' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.KillAll') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		Globals.SpawnMode = "manual"
		BotManager:KillAll()
		return
	elseif request.action == 'bot_respawn' then -- Toggle this function.
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.ToggleOption') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local respawning = not Globals.RespawnWayBots
		Globals.RespawnWayBots = respawning
		BotManager:SetOptionForAll('respawn', respawning)

		if respawning then
			ChatManager:Yell(Language:I18N('Bot respawn activated!', request.action), 2.5)
		else
			ChatManager:Yell(Language:I18N('Bot respawn deactivated!', request.action), 2.5)
		end
		return
	elseif request.action == 'bot_attack' then -- Toggle this function.
		if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor.ToggleOption') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local attack = not Globals.AttackWayBots
		Globals.AttackWayBots = attack
		BotManager:SetOptionForAll('shoot', attack)

		if attack then
			ChatManager:Yell(Language:I18N('Bots will attack!', request.action), 2.5)
		else
			ChatManager:Yell(Language:I18N('Bots will not attack!', request.action), 2.5)
		end
		return

		-- Trace.
	elseif request.action == 'trace_start' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.Tracing') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		m_NodeEditor:StartTrace(p_Player)
		return
	elseif request.action == 'trace_end' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.Tracing') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		m_NodeEditor:EndTrace(p_Player)
		return
	elseif request.action == 'trace_save' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.Tracing') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		local s_Index = tonumber(request.value)
		if s_Index then
			m_NodeEditor:SaveTrace(p_Player, s_Index)
		end
		return
	elseif request.action == 'trace_clear' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.Tracing') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		m_NodeEditor:ClearTrace(p_Player)
		return
	elseif request.action == 'trace_reset_all' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.Reset') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		m_NodeCollection:Clear()
		NetEvents:BroadcastLocal('NodeCollection:Clear')
		return
	elseif request.action == 'waypoints_server_load' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.SaveLoad') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		m_NodeCollection:Load()
		return
	elseif request.action == 'waypoints_server_save' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.SaveLoad') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		m_NodeCollection:Save()
		return
	elseif request.action == 'waypoints_show_spawns' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.View') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		Config.DrawSpawnPoints = not Config.DrawSpawnPoints
		NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, false)
		return
	elseif request.action == 'waypoints_show_lines' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.View') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		Config.DrawWaypointLines = not Config.DrawWaypointLines
		NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, false)
		return
	elseif request.action == 'waypoints_show_labels' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor.View') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		Config.DrawWaypointIDs = not Config.DrawWaypointIDs
		NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, false)
		return
		-- Waypoints-Editor
	elseif request.action == 'request_waypoints_editor' then
		if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
			ChatManager:SendMessage('You have no permissions for this action.', p_Player)
			return
		end
		m_NodeEditor:OnOpenEditor(p_Player)
		NetEvents:SendTo('UI_Waypoints_Editor', p_Player, true)
		return
	elseif request.action == 'disable_waypoint_editor' then
		-- always allow to close editor
		m_NodeEditor:OnCloseEditor(p_Player)
		NetEvents:SendTo('UI_Waypoints_Disable', p_Player)
		return
	elseif request.action == 'hide_waypoints_editor' then
		-- always allow to hide editor
		m_NodeEditor:OnCloseEditor(p_Player)
		NetEvents:SendTo('UI_Waypoints_Editor', p_Player, false)
		return
	else
		ChatManager:Yell(Language:I18N('%s is currently not implemented', request.action), 2.5)
	end
end

function FunBotUIServer:_onUIRequestSaveSettings(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting to save settings.')
	end

	if PermissionManager:HasPermission(p_Player, 'UserInterface.Settings') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	local request = json.decode(p_Data)

	self:_writeSettings(p_Player, request)
end

function FunBotUIServer:_onUIRequestCommoRoseShow(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting show CommoRose.')
	end

	NetEvents:SendTo('UI_CommoRose', p_Player, {
		Top = {
			Action = 'not_implemented',
			Label = Language:I18N(''),
		},
		Left = {
			{
				Action = 'exit_vehicle',
				Label = Language:I18N('Exit Vehicle')
			},
			{
				Action = 'enter_vehicle',
				Label = Language:I18N('Enter Vehicle')
			},
			{
				Action = 'drop_ammo',
				Label = Language:I18N('Drop Ammo')
			},
			{
				Action = 'drop_medkit',
				Label = Language:I18N('Drop Medkit')
			}
		},
		Center = {
			Action = 'not_implemented',
			Label = Language:I18N('Commands') -- Or "Unselect".
		},
		Right = {
			{
				Action = 'attack_objective',
				Label = Language:I18N('Attack Objective')
			},
			{
				Action = 'defend_objective',
				Label = Language:I18N('Defend Objective'),
			},
			{
				Action = 'repair_vehicle',
				Label = Language:I18N('Repair Vehicle')
			},
			{
				Action = 'not_implemented',
				Label = Language:I18N('')
			}
		},
		Bottom = {
			Action = 'not_implemented',
			Label = Language:I18N(''),
		}
	})
end

function FunBotUIServer:_onUIRequestCommoRoseHide(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting hide CommoRose.')
	end

	NetEvents:SendTo('UI_CommoRose', p_Player, 'false')
end

function FunBotUIServer:_onUIRequestOpen(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting open Bot-Editor.')
	end

	if PermissionManager:HasPermission(p_Player, 'UserInterface') then
		if Debug.Server.UI then
			print('Open Bot-Editor for ' .. p_Player.name .. '.')
		end

		NetEvents:SendTo('UI_Toggle', p_Player)
		NetEvents:SendTo('UI_Show_Toolbar', p_Player, 'true')
	else
		ChatManager:SendMessage('You have no permissions to open the UI', p_Player)
	end
end

function FunBotUIServer:_writeSettings(p_Player, p_Request)
	if Config.DisableUserInterface == true then
		return
	end

	local temporary = false
	local updateBotTeamAndNumber = false
	local updateWeaponSets = false
	local resetSkill = false
	local calcYawPerFrame = false
	local updateLanguage = false
	local updateMaxBots = false
	local updateBotNames = false
	local batched = true

	if p_Request.subaction ~= nil then
		temporary = (p_Request.subaction == 'temp')
	end

	for _, l_Item in pairs(SettingsDefinition.Elements) do
		-- Validate requests.
		if p_Request[l_Item.Name] ~= nil then
			local s_Changed = false
			local s_Value = nil
			local s_Valid = false

			if l_Item.Type == Type.Enum then
				-- Convert value back.
				for l_Key, l_Value in pairs(l_Item.Reference) do
					if l_Key == p_Request[l_Item.Name] and l_Key ~= "Count" then
						s_Value = l_Value
						s_Valid = true

						if s_Value ~= Config[l_Item.Name] then
							s_Changed = true
						end

						break
					end
				end
			elseif l_Item.Type == Type.List then
				for _, l_Value in pairs(l_Item.Reference) do
					if l_Value == p_Request[l_Item.Name] then
						s_Value = l_Value
						s_Valid = true

						if s_Value ~= Config[l_Item.Name] then
							s_Changed = true
						end

						break
					end
				end
			elseif l_Item.Type == Type.DynamicList then
				local s_Reference = _G[l_Item.Reference]

				for _, l_Value in pairs(s_Reference) do
					if l_Value == p_Request[l_Item.Name] then
						s_Value = l_Value
						s_Valid = true
						if s_Value ~= Config[l_Item.Name] then
							s_Changed = true
						end
						break
					end
				end
			elseif l_Item.Type == Type.Integer or l_Item.Type == Type.Float then
				s_Value = tonumber(p_Request[l_Item.Name])
				---@type Range
				local s_Reference = l_Item.Reference

				if s_Reference:IsValid(s_Value) then
					s_Valid = true
					if math.abs(s_Value - Config[l_Item.Name]) > 0.001 then
						s_Changed = true
					end
				end
			elseif l_Item.Type == Type.Boolean then
				s_Value = p_Request[l_Item.Name] == true
				s_Valid = true

				if s_Value ~= Config[l_Item.Name] then
					s_Changed = true
				end
			end

			-- Update with value or with current Config. Update is needed to not lose Config Values.
			if s_Valid then
				m_SettingsManager:Update(l_Item.Name, s_Value, temporary, batched)
			else
				m_SettingsManager:Update(l_Item.Name, Config[l_Item.Name], temporary, batched)
			end

			-- Check for update flags.
			if s_Changed then
				if l_Item.UpdateFlag == UpdateFlag.WeaponSets then
					updateWeaponSets = true
				elseif l_Item.UpdateFlag == UpdateFlag.Skill then
					resetSkill = true
				elseif l_Item.UpdateFlag == UpdateFlag.YawPerSec then
					calcYawPerFrame = true
				elseif l_Item.UpdateFlag == UpdateFlag.AmountAndTeam then
					updateBotTeamAndNumber = true
				elseif l_Item.UpdateFlag == UpdateFlag.Language then
					updateLanguage = true
				elseif l_Item.UpdateFlag == UpdateFlag.MaxBots then
					updateMaxBots = true
				elseif l_Item.UpdateFlag == UpdateFlag.BotNames then
					updateBotNames = true
				end
			end
		end
	end

	-- Language of UI.
	if updateLanguage then
		Language:loadLanguage(Config.Language)
		NetEvents:SendTo('UI_Change_Language', p_Player, Config.Language)
	end

	-- Call batched process.
	if batched then
		Database:ExecuteBatch()
	end

	if temporary then
		ChatManager:Yell(Language:I18N('Settings has been saved temporarily'), 2.5)
	else
		ChatManager:Yell(Language:I18N('Settings has been saved'), 2.5)
	end

	-- Update Weapons if needed.
	if updateWeaponSets then
		WeaponList:UpdateWeaponList()
	end

	if resetSkill then
		BotManager:ResetSkills()
	end

	if calcYawPerFrame then
		Globals.YawPerFrame = BotManager:CalcYawPerFrame()
	end

	if updateMaxBots then
		g_FunBotServer:SetMaxBotsPerTeam(Globals.GameMode)
	end

	if updateBotNames then
		BotSpawner:UpdateBotNames()
	end
	NetEvents:BroadcastLocal('WriteClientSettings', Config, updateWeaponSets)

	if updateBotTeamAndNumber then
		Globals.SpawnMode = Config.SpawnMode
		BotSpawner:UpdateBotAmountAndTeam()
	end

	-- To-do: create Error Array and don't hide if it has values.
	NetEvents:SendTo('UI_Settings', p_Player, false)
end

if g_FunBotUIServer == nil then
	---@type FunBotUIServer
	g_FunBotUIServer = FunBotUIServer()
end

return g_FunBotUIServer
