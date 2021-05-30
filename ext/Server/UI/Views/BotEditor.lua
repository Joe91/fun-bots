--[[
	@class: BotEditor
	@extends: View
]]
class('BotEditor')

local m_BotSpawner = require('BotSpawner')
local m_BotManager = require('BotManager')

--[[
	@method: __init
]]
function BotEditor:__init(p_Core)
	self.m_View = View(p_Core, 'BotEditor')
	self.m_Bots = 1
	self.m_Team = 1
end

--[[
	@method: Show
]]
function BotEditor:Show(p_Player)
	if PermissionManager:HasPermission(p_Player, 'UserInterface.' .. self:GetName()) == false then
		return
	end

	self.m_View:Show(p_Player)
	self.m_View:Activate(p_Player)
end

--[[
	@method: Hide
]]
function BotEditor:Hide(p_Player)
	self.m_View:Hide(p_Player)
	self.m_View:Deactivate(p_Player)
end

--[[
	@method: Toggle
]]
function BotEditor:Toggle(p_Player)
	self.m_View:Toggle(p_Player)

	if (self.m_View:IsVisible()) then
		self.m_View:Activate(p_Player)
	else
		self.m_View:Deactivate(p_Player)
	end
end

--[[
	@method: Activate
]]
function BotEditor:Activate(p_Player)
	self.m_View:Activate(p_Player)
end

--[[
	@method: Deactivate
]]
function BotEditor:Deactivate(p_Player)
	self.m_View:Deactivate(p_Player)
end

--[[
	@method: Call
]]
function BotEditor:Call(p_Player, p_Element, p_Name)
	self.m_View:Call(p_Player, p_Element, p_Name)
end

--[[
	@method: GetName
]]
function BotEditor:GetName()
	return self.m_View:GetName()
end

--[[
	@method: InitializeComponent

	Here you can add/remove some Components from the Bot-Editor View
]]
function BotEditor:InitializeComponent()
	-- Logo
	local s_Logo = Logo('Bot-Editor', 'fun-bots')
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

	-- Bots
	local s_Bots = MenuItem('Bots', 'bots')
	s_Bots:SetIcon('Assets/Icons/Bot.svg')
		local s_Input_Bots = Input(Type.Integer, 'bots', self.m_Bots)

		s_Input_Bots:Disable()

		s_Input_Bots:AddArrow(Position.Left, '❰', function(p_Player)
			self.m_Bots = self.m_Bots - 1

			if (self.m_Bots < 0) then
				self.m_Bots = 0
			end

			s_Input_Bots:SetValue(self.m_Bots)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Input_Bots:__class(),
				Name = s_Input_Bots:GetName(),
				Value = s_Input_Bots:GetValue()
			}))
		end)

		s_Input_Bots:AddArrow(Position.Right, '❱', function(p_Player)
			self.m_Bots = self.m_Bots + 1

			if (self.m_Bots > 50) then
				self.m_Bots = 50
			end

			s_Input_Bots:SetValue(self.m_Bots)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Input_Bots:__class(),
				Name = s_Input_Bots:GetName(),
				Value = s_Input_Bots:GetValue()
			}))
		end)

		-- Submenu
		local s_Bot_Spawn_Default = MenuItem('Spawn Enemy Bots', 'bot_spawn_default', function(p_Player)
			Globals.SpawnMode = 'manual'

			if p_Player.teamId == TeamId.Team1 then
				m_BotSpawner:SpawnWayBots(p_Player, self.m_Bots, true, 0, 0, TeamId.Team2)
			else
				m_BotSpawner:SpawnWayBots(p_Player, self.m_Bots, true, 0, 0, TeamId.Team1)
			end
		end, 'F2')

		s_Bot_Spawn_Default:AddInput(Position.Left, s_Input_Bots)
		s_Bots:AddItem(s_Bot_Spawn_Default, 'UserInterface.BotEditor.SpawnEnemy')

		local s_Bot_Spawn_Friend = MenuItem('Spawn Friend Bots', 'bot_spawn_friend', function(p_Player)
			Globals.SpawnMode = 'manual'

			m_BotSpawner:SpawnWayBots(p_Player, self.m_Bots, true, 0, 0, p_Player.teamId)
		end)

		s_Bot_Spawn_Friend:AddInput(Position.Left, s_Input_Bots)
		s_Bots:AddItem(s_Bot_Spawn_Friend, 'UserInterface.BotEditor.SpawnFriend')

		s_Bots:AddItem(MenuSeparator())

		s_Bots:AddItem(MenuItem('Kick All', 'bot_kick_all', function(p_Player)
			Globals.SpawnMode = 'manual'

			m_BotManager:DestroyAll()
		end, 'F3'), 'UserInterface.BotEditor.KickAll')

		local s_Input_Team = Input(Type.Integer, 'team', self.m_Team)

		s_Input_Team:Disable()

		local s_Bot_Kick_Team = MenuItem('Kick Team', 'bot_kick_team', function(p_Player)
			Globals.SpawnMode = 'manual'

			m_BotManager:DestroyAll(nil, self.m_Team)
		end)

		s_Input_Team:AddArrow(Position.Left, '❰', function(p_Player)
			self.m_Team = self.m_Team - 1

			if (self.m_Team < TeamId.Team1) then
				self.m_Team = TeamId.TeamIdCount - 1
			end

			s_Input_Team:SetValue(self.m_Team)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Input_Team:__class(),
				Name = s_Input_Team:GetName(),
				Value = s_Input_Team:GetValue()
			}))
		end)

		s_Input_Team:AddArrow(Position.Right, '❱', function(p_Player)
			self.m_Team = self.m_Team + 1

			if (self.m_Team >= TeamId.TeamIdCount) then
				self.m_Team = TeamId.Team1
			end

			s_Input_Team:SetValue(self.m_Team)

			NetEvents:SendTo('UI', p_Player, 'VIEW', self.m_View:GetName(), 'UPDATE', json.encode({
				Type = s_Input_Team:__class(),
				Name = s_Input_Team:GetName(),
				Value = s_Input_Team:GetValue()
			}))
		end)

		s_Bot_Kick_Team:AddInput(Position.Left, s_Input_Team)
		s_Bots:AddItem(s_Bot_Kick_Team, 'UserInterface.BotEditor.KickTeam')

		s_Bots:AddItem(MenuItem('Kill All', 'bot_kill_all', function(p_Player)
			Globals.SpawnMode = 'manual'

			m_BotManager:KillAll()
		end, 'F4'), 'UserInterface.BotEditor.KillAll')

		s_Bots:AddItem(MenuSeparator())

		s_Bots:AddItem(MenuItem('Toggle Respawn', 'bot_respawn', function(p_Player)
			local s_Respawning = not Globals.RespawnWayBots
			Globals.RespawnWayBots = s_Respawning
			m_BotManager:SetOptionForAll('respawn', s_Respawning)

			if s_Respawning then
				ChatManager:Yell(Language:I18N('Bot respawn activated!'), 2.5)
			else
				ChatManager:Yell(Language:I18N('Bot respawn deactivated!'), 2.5)
			end
		end), 'UserInterface.BotEditor.ToggleRespawn')

		s_Bots:AddItem(MenuItem('Toggle Attack', 'bot_attack', function(p_Player)
			local s_Attack = not Globals.AttackWayBots
			Globals.AttackWayBots = s_Attack
			m_BotManager:SetOptionForAll('shoot', s_Attack)

			if s_Attack then
				ChatManager:Yell(Language:I18N('Bots will attack!'), 2.5)
			else
				ChatManager:Yell(Language:I18N('Bots will not attack!'), 2.5)
			end
		end), 'UserInterface.BotEditor.ToggleAttack')

	s_Navigation:AddItem(s_Bots)

	-- Waypoint-Editor
	s_Navigation:AddItem(MenuItem('Waypoint-Editor', 'waypoint-editor', 'UI:VIEW:WaypointEditor:SHOW'):SetIcon('Assets/Icons/WaypointEditor.svg'), 'UserInterface.WaypointEditor')

	-- Settings
	s_Navigation:AddItem(MenuItem('Settings', 'settings', function(player)
		self.m_View:GetCore():GetDialog('Settings', self.m_View):Open(self.m_View, player)
	end, 'F10'):SetIcon('Assets/Icons/Settings.svg'), 'UserInterface.Settings')

	-- Exit
	s_Navigation:AddItem(MenuItem('Exit', 'exit', 'UI:VIEW:' .. self.m_View:GetName() .. ':HIDE', 'F12'))

	self.m_View:AddComponent(s_Navigation)
end

return BotEditor
