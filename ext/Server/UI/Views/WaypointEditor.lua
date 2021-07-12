--[[
	@class: WaypointEditor
	@extends: View
]]
class('WaypointEditor')

local m_SettingsManager = require('SettingsManager')
--[[
	@method: __init
]]
function WaypointEditor:__init(p_Core)
	self.m_View = View(p_Core, 'WaypointEditor')
	self.m_Trace_Index = 0
	self.m_Tracing = false
	self.m_Interaction_Information = true
	self.m_Quick_Shortcuts = QuickShortcut('trace_controls')

	NetEvents:Subscribe('WaypointEditor:TraceToggle', self, function(p_UserData, p_Player, p_Data)
		if p_Data.Enabled ~= nil then
			self.m_Tracing = p_Data.Enabled
		end

		if p_Data.Distance ~= nil then
			NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = 'Entry',
				Name = 'trace_distance',
				Value = math.floor(p_Data.Distance) .. ' m'
			}))
		end

		if p_Data.Waypoints ~= nil then
			NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = 'Entry',
				Name = 'trace_waypoints',
				Value = p_Data.Waypoints
			}))
		end

		if p_Data.TraceIndex ~= nil then
			NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = 'Input',
				Name = 'trace_index',
				Value = p_Data.TraceIndex
			}))
		end

		if self.m_Tracing then
			self.recording:Show()

			NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = 'MenuItem',
				Name = 'trace_toggle',
				Text = 'Stop Trace',
				Icon = 'Assets/Icons/Stop.svg'
			}))
		else
			self.recording:Hide()

			NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = 'MenuItem',
				Name = 'trace_toggle',
				Text = 'Start Trace',
				Icon = 'Assets/Icons/Start.svg'
			}))
		end

		NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
			Type = self.recording:__class(),
			Name = self.recording:GetName(),
			Hidden = self.recording:IsHidden()
		}))
	end)
end

--[[
	@method: Show
]]
function WaypointEditor:Show(p_Player)
	Config.DebugTracePaths = true
	NetEvents:SendToLocal('UI_ClientNodeEditor_Enabled', p_Player, Config.DebugTracePaths)
	self.m_View:Show(p_Player)
	self:Deactivate(p_Player)
	self.m_View:GetCore():GetView('BotEditor'):Hide(p_Player)
end

--[[
	@method: Hide
]]
function WaypointEditor:Hide(p_Player)
	Config.DebugTracePaths = false
	NetEvents:SendToLocal('UI_ClientNodeEditor_Enabled', p_Player, Config.DebugTracePaths)

	self.m_View:Hide(p_Player)

	if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor') then
		self.m_View:GetCore():GetView('BotEditor'):Show(p_Player)
	end
end

--[[
	@method: UpdateNewPath
]]
function WaypointEditor:UpdateNewPath(p_Player)
	local s_Nodes = g_NodeCollection:Get(nil, self.m_Trace_Index)
	local s_Distance = 0

	-- Show the new path
	NetEvents:SendToLocal('NodeCollection:ShowPath', p_Player, self.m_Trace_Index)

	NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
		Type = 'Input',
		Name = 'trace_index',
		Value = self.m_Trace_Index
	}))

	NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
		Type = 'Entry',
		Name = 'trace_waypoints',
		Value = #s_Nodes
	}))

	-- @ToDo calculate distance of node collection
	NetEvents:SendToLocal('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
		Type = 'Entry',
		Name = 'trace_distance',
		Value = s_Distance .. ' m'
	}))
end

--[[
	@method: Activate
]]
function WaypointEditor:Activate(p_Player)
	self.m_View:Activate(p_Player)
end

--[[
	@method: Deactivate
]]
function WaypointEditor:Deactivate(p_Player)
	self.m_View:Deactivate(p_Player)
end

--[[
	@method: Toggle
]]
function WaypointEditor:Toggle(p_Player)
	self.m_View:Toggle(p_Player)
end

--[[
	@method: Call
]]
function WaypointEditor:Call(p_Player, p_Element, p_Name)
	self.m_View:Call(p_Player, p_Element, p_Name)
end

--[[
	@method: GetName
]]
function WaypointEditor:GetName()
	return self.m_View:GetName()
end

--[[
	@method: InitializeComponent
]]
function WaypointEditor:InitializeComponent()
	self.m_Quick_Shortcuts:SetPosition(Position.Center_Right)
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K1, 'Remove')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K2, 'Unlink')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K3, 'Add')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K4, 'Move')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K5, 'Select')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K6, 'Input')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K7, 'Merge')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K8, 'Link')
	self.m_Quick_Shortcuts:AddNumpad(Numpad.K9, 'Split')
	self.m_Quick_Shortcuts:AddHelp(InputDeviceKeys.IDK_F12, 'Settings')
	self.m_Quick_Shortcuts:AddHelp(InputDeviceKeys.IDK_Q, 'Quick Select')
	self.m_Quick_Shortcuts:AddHelp(InputDeviceKeys.IDK_Backspace, 'Clear Select')
	self.m_Quick_Shortcuts:AddHelp(InputDeviceKeys.IDK_Insert, 'Spawn Bot')


	self.recording = Box(Color.Red)
	self.recording:SetPosition(Position.Absolute, {
		Top = 182,
		Left = 16
	})

	self.recording:AddItem(Text('recording_text', 'Recording...'):SetIcon('Assets/Icons/Stop.svg'))
	self.m_View:AddComponent(self.recording)
	self.recording:Hide()

	-- Logo
	local s_Logo = Logo('Waypoint-Editor', 'fun-bots')
	s_Logo:SetPosition(Position.Absolute, {
		Top = 20,
		Left = 20
	})
	self.m_View:AddComponent(s_Logo)

	-- Menu
	local s_Navigation = Menu()

	s_Navigation:SetPosition(Position.Absolute, {
		Top = 20,
		Right = 20
	})

	-- Waypoints
	local s_Client = MenuItem('Client', 'client')
		s_Client:SetIcon('Assets/Icons/Client.svg')

		s_Client:AddItem(MenuItem('Load', 'waypoints_client_load', function(p_Player)
			local expectedAmount = g_NodeCollection:Get()
			NetEvents:SendToLocal('ClientNodeEditor:ReceiveNodes', p_Player, (#expectedAmount))
		end):SetIcon('Assets/Icons/Reload.svg'))

		s_Client:AddItem(MenuItem('Save', 'waypoints_client_save', function(p_Player)
			NetEvents:SendToLocal('ClientNodeEditor:SaveNodes', p_Player)
		end):SetIcon('Assets/Icons/Save.svg'))

	s_Navigation:AddItem(s_Client, 'UserInterface.WaypointEditor.Nodes.Client')

	local s_Server = MenuItem('Server', 'server')
		s_Server:SetIcon('Assets/Icons/Server.svg')

		s_Server:AddItem(MenuItem('Load', 'waypoints_server_load', function(p_Player)
			g_NodeCollection:Load()
		end):SetIcon('Assets/Icons/Reload.svg'))

		s_Server:AddItem(MenuItem('Save', 'waypoints_server_save', function(p_Player)
			g_NodeCollection:Save()
		end):SetIcon('Assets/Icons/Save.svg'))
	s_Navigation:AddItem(s_Server, 'UserInterface.WaypointEditor.Nodes.Server')

	-- View
	local s_View = MenuItem('View', 'view')
		s_View:SetIcon('Assets/Icons/View.svg')

		local s_Checkbox_SpawnPoints = CheckBox('view_spawnpoints', Config.DrawSpawnPoints)
		local s_Checkbox_Lines = CheckBox('view_lines', Config.DrawWaypointLines)
		local s_Checkbox_Labels = CheckBox('view_labels', Config.DrawWaypointIDs)
		local s_Checkbox_Interaction = CheckBox('view_interaction', self.m_Interaction_Information)
		local s_Checkbox_Shortcuts = CheckBox('view_shortcuts', self.m_Quick_Shortcuts:IsEnabled())

		s_View:AddItem(MenuSeparator('Editor'))

		s_View:AddItem(MenuItem('Spawn-Points', 'spawnpoints', function(p_Player)
			Config.DrawSpawnPoints = not Config.DrawSpawnPoints

			s_Checkbox_SpawnPoints:SetChecked(Config.DrawSpawnPoints)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Checkbox_SpawnPoints:__class(),
				Name = s_Checkbox_SpawnPoints:GetName(),
				IsChecked = s_Checkbox_SpawnPoints:IsChecked()
			}))
			m_SettingsManager:UpdateSetting('DrawSpawnPoints', tostring(Config.DrawSpawnPoints))
		end):AddCheckBox(Position.Left, s_Checkbox_SpawnPoints))

		s_View:AddItem(MenuItem('Lines', 'lines', function(p_Player)
			Config.DrawWaypointLines = not Config.DrawWaypointLines

			s_Checkbox_Lines:SetChecked(Config.DrawWaypointLines)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Checkbox_Lines:__class(),
				Name = s_Checkbox_Lines:GetName(),
				IsChecked = s_Checkbox_Lines:IsChecked()
			}))
			m_SettingsManager:UpdateSetting('DrawWaypointLines', tostring(Config.DrawWaypointLines))
		end):AddCheckBox(Position.Left, s_Checkbox_Lines))

		s_View:AddItem(MenuItem('Labels', 'labels', function(p_Player)
			Config.DrawWaypointIDs = not Config.DrawWaypointIDs

			s_Checkbox_Labels:SetChecked(Config.DrawWaypointIDs)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Checkbox_Labels:__class(),
				Name = s_Checkbox_Labels:GetName(),
				IsChecked = s_Checkbox_Labels:IsChecked()
			}))
			m_SettingsManager:UpdateSetting('DrawWaypointIDs', tostring(Config.DrawWaypointIDs))
		end):AddCheckBox(Position.Left, s_Checkbox_Labels))

		s_View:AddItem(MenuSeparator('User Interface'))

		s_View:AddItem(MenuItem('Interaction Info', 'interaction_information', function(p_Player)
			self.m_Interaction_Information = not self.m_Interaction_Information

			s_Checkbox_Interaction:SetChecked(self.m_Interaction_Information)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Checkbox_Interaction:__class(),
				Name = s_Checkbox_Interaction:GetName(),
				IsChecked = s_Checkbox_Interaction:IsChecked()
			}))

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = 'Text',
				Name = 'interaction_information',
				Disabled = not s_Checkbox_Interaction:IsChecked()
			}))
		end):AddCheckBox(Position.Left, s_Checkbox_Interaction))

		s_View:AddItem(MenuItem('Quick Shortcuts', 'quick_shortcuts', function(p_Player)
			if self.m_Quick_Shortcuts:IsEnabled() then
				self.m_Quick_Shortcuts:Disable()
			else
				self.m_Quick_Shortcuts:Enable()
			end

			s_Checkbox_Shortcuts:SetChecked(self.m_Quick_Shortcuts:IsEnabled())

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Checkbox_Shortcuts:__class(),
				Name = s_Checkbox_Shortcuts:GetName(),
				IsChecked = s_Checkbox_Shortcuts:IsChecked()
			}))

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = self.m_Quick_Shortcuts:__class(),
				Name = self.m_Quick_Shortcuts:GetName(),
				Disabled = not self.m_Quick_Shortcuts:IsEnabled()
			}))
		end):AddCheckBox(Position.Left, s_Checkbox_Shortcuts))

	s_Navigation:AddItem(s_View, 'UserInterface.WaypointEditor.View')

	s_Navigation:AddItem(MenuItem('Back', 'back', 'UI:VIEW:' .. self.m_View:GetName() .. ':HIDE', 'F12'))

	-- Tools-Menu
	local s_Tools = Menu()

	s_Tools:AddItem(MenuItem('Start Trace', 'trace_toggle', function(p_Player)
		if self.m_Tracing then
			NetEvents:SendToLocal('ClientNodeEditor:EndTrace', p_Player)
		else
			NetEvents:SendToLocal('ClientNodeEditor:StartTrace', p_Player)
		end
	end):SetIcon('Assets/Icons/Start.svg'), 'UserInterface.WaypointEditor.Tracing')

	s_Tools:AddItem(MenuItem('Save Trace', 'trace_save', function(p_Player)
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', p_Player)
	end):SetIcon('Assets/Icons/Save.svg'), 'UserInterface.WaypointEditor.TraceSaving')

	s_Tools:AddItem(MenuItem('Spawn Bot on Way', 'bot_spawn_path', function(p_Player)
		print('bot_spawn_path Executed')
		-- @ToDo
	end):SetIcon('Assets/Icons/SpawnBotWay.svg'), 'UserInterface.WaypointEditor.SpawnBot')

	s_Tools:AddItem(MenuItem('Clear Trace', 'trace_clear', function(p_Player)
		local s_Confirmation = self.m_View:GetCore():GetDialog('Confirmation')
		s_Confirmation:SetTitle('Clear Trace - Confirmation')
		s_Confirmation:SetContent('Do you really want to clear the actual Trace #' .. self.m_Trace_Index .. '?')
		s_Confirmation:SetNo(function(player)
			s_Confirmation:Hide(self.m_View, player)
		end)
		s_Confirmation:SetYes(function(p_Player)
			NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', p_Player)
			s_Confirmation:Hide(self.m_View, p_Player)
		end)
		s_Confirmation:Open(self.m_View, p_Player)
	end):Disable():SetIcon('Assets/Icons/Clear.svg'), 'UserInterface.WaypointEditor.TraceClear')

	s_Tools:AddItem(MenuItem('Reset all Traces', 'trace_reset_all', function(p_Player)
		local s_Confirmation = self.m_View:GetCore():GetDialog('Confirmation')
		s_Confirmation:SetTitle('Reset all Traces- Confirmation')
		s_Confirmation:SetContent('Do you really want to reset all Traces?')
		s_Confirmation:SetNo(function(p_Player)
			s_Confirmation:Hide(self.m_View, p_Player)
		end)
		s_Confirmation:SetYes(function(p_Player)
			g_NodeCollection:Clear()
			NetEvents:BroadcastLocal('NodeCollection:Clear')
			s_Confirmation:Hide(self.m_View, p_Player)
		end)
		s_Confirmation:Open(self.m_View, p_Player)
	end):SetIcon('Assets/Icons/Trash.svg'), 'UserInterface.WaypointEditor.TraceReset')

	s_Navigation:AddItem(s_Tools)

	self.m_View:AddComponent(s_Navigation)

	local s_Status = Box(Color.Blue)

	s_Status:SetPosition(Position.Absolute, {
		Top = 75,
		Left = 15
	})

	local s_Input_Trace_Index = Input(Type.Integer, 'trace_index', self.m_Trace_Index)

	s_Input_Trace_Index:Disable()

	s_Input_Trace_Index:AddArrow(Position.Left, '❰', function(p_Player)
		-- Hide the old path
		--NetEvents:SendToLocal('NodeCollection:HidePath', player, self.trace_index)

		self.m_Trace_Index = self.m_Trace_Index - 1

		if (self.m_Trace_Index < 0) then
			local s_LastNode = g_NodeCollection:GetLast()

			if s_LastNode == nil then
				self.m_Trace_Index = 0
			else
				self.m_Trace_Index = s_LastNode.PathIndex
			end
		end

		NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
			Type = 'MenuItem',
			Name = 'trace_clear',
			Disabled = (self.m_Trace_Index == 0)
		}))

		s_Input_Trace_Index:SetValue(self.m_Trace_Index)
		self:UpdateNewPath(p_Player)
	end)

	s_Input_Trace_Index:AddArrow(Position.Right, '❱', function(p_Player)
		-- Hide the old path
		NetEvents:SendToLocal('NodeCollection:HidePath', p_Player, self.m_Trace_Index)

		self.m_Trace_Index = self.m_Trace_Index + 1
		local s_LastNode = g_NodeCollection:GetLast()

		if s_LastNode == nil or self.m_Trace_Index > s_LastNode.PathIndex then
			self.m_Trace_Index = 0
		end

		NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
			Type = 'MenuItem',
			Name = 'trace_clear',
			Disabled = (self.m_Trace_Index == 0)
		}))

		s_Input_Trace_Index:SetValue(self.m_Trace_Index)
		self:UpdateNewPath(p_Player)
	end)

	s_Status:AddItem(Entry('trace_index', 'Current Trace Index', s_Input_Trace_Index))
	s_Status:AddItem(Entry('trace_waypoints', 'Waypoints', '' .. #g_NodeCollection:Get(nil, self.m_Trace_Index)))
	s_Status:AddItem(Entry('trace_distance', 'Total Distance', '0 m'))

	self.m_View:AddComponent(s_Status)

	self.m_View:AddComponent(self.m_Quick_Shortcuts)
	self.m_View:AddComponent(Text('interaction_information', 'Press for interaction with the Editor'):SetPosition(Position.Bottom_Center):SetIcon('Assets/Keys/Q.svg'))
end

return WaypointEditor
