class('BotEditor')

local m_BotSpawner = require('BotSpawner')
local m_BotManager = require('BotManager')

function BotEditor:__init(core)
	self.view		= View(core, 'BotEditor')
	self.bots		= 1
	self.team		= 1
end

function BotEditor:Show(player)
	if PermissionManager:HasPermission(player, 'UserInterface.' .. self:GetName()) == false then
		return
	end

	self.view:Show(player)
	self.view:Activate(player)
end

function BotEditor:Hide(player)
	self.view:Hide(player)
	self.view:Deactivate(player)
end

function BotEditor:Toggle(player)
	self.view:Toggle(player)
	
	if (self.view:IsVisible()) then
		self.view:Activate(player)
	else
		self.view:Deactivate(player)
	end
end

function BotEditor:Activate(player)
	self.view:Activate(player)
end

function BotEditor:Deactivate(player)
	self.view:Deactivate(player)
end

function BotEditor:Call(player, element, name)
	self.view:Call(player, element, name)
end

function BotEditor:GetName()
	return self.view:GetName()
end

-- Here you can add/remove some Components from the Bot-Editor View
function BotEditor:InitializeComponent()
	-- Logo
	local logo = Logo('Bot-Editor', 'fun-bots')
	logo:SetPosition(Position.Absolute, {
		Top		= 20,
		Left	= 20
	})
	self.view:AddComponent(logo)

	-- Menu
	local navigation = Menu()

	navigation:SetPosition(Position.Absolute, {
		Top		= 20,
		Right	= 20
	})

	-- Bots
	local bots = MenuItem('Bots', 'bots')
	bots:SetIcon('Assets/Icons/Bot.svg')
		local input_bots = Input(Type.Integer, 'bots', self.bots)
		
		input_bots:Disable()
		
		input_bots:AddArrow(Position.Left, '❰', function(player)
			self.bots = self.bots - 1
			
			if (self.bots < 0) then
				self.bots = 0
			end
			
			input_bots:SetValue(self.bots)
			
			NetEvents:SendTo('UI', player, 'VIEW', self.view:GetName(), 'UPDATE', json.encode({
				Type	= input_bots:__class(),
				Name	= input_bots:GetName(),
				Value	= input_bots:GetValue()
			}))
		end)
		
		input_bots:AddArrow(Position.Right, '❱', function(player)
			self.bots = self.bots + 1
			
			if (self.bots > 50) then
				self.bots = 50
			end
			
			input_bots:SetValue(self.bots)
			
			NetEvents:SendTo('UI', player, 'VIEW', self.view:GetName(), 'UPDATE', json.encode({
				Type	= input_bots:__class(),
				Name	= input_bots:GetName(),
				Value	= input_bots:GetValue()
			}))
		end)
		
		-- Submenu
		local bot_spawn_default = MenuItem('Spawn Enemy Bots', 'bot_spawn_default', function(player)
			Globals.SpawnMode	= 'manual'
			
			if player.teamId == TeamId.Team1 then
				m_BotSpawner:SpawnWayBots(player, self.bots, true, 0, 0, TeamId.Team2)
			else
				m_BotSpawner:SpawnWayBots(player, self.bots, true, 0, 0, TeamId.Team1)
			end
		end, 'F2')
		
		bot_spawn_default:AddInput(Position.Left, input_bots)
		bots:AddItem(bot_spawn_default, 'UserInterface.BotEditor.SpawnEnemy')
		
		local bot_spawn_friend = MenuItem('Spawn Friend Bots', 'bot_spawn_friend', function(player)
			Globals.SpawnMode	= 'manual'
			
			m_BotSpawner:SpawnWayBots(player, self.bots, true, 0, 0, player.teamId)
		end)
		
		bot_spawn_friend:AddInput(Position.Left, input_bots)
		bots:AddItem(bot_spawn_friend, 'UserInterface.BotEditor.SpawnFriend')
		
		bots:AddItem(MenuSeparator())
		
		bots:AddItem(MenuItem('Kick All', 'bot_kick_all', function(player)
			Globals.SpawnMode	= 'manual'
			
			m_BotManager:destroyAll()
		end, 'F3'), 'UserInterface.BotEditor.KickAll')
		
		local input_team	= Input(Type.Integer, 'team', self.team)
		
		input_team:Disable()
		
		local bot_kick_team	= MenuItem('Kick Team', 'bot_kick_team', function(player)
			Globals.SpawnMode	= 'manual'
			
			m_BotManager:destroyAll(nil, self.team)
		end)
		
		input_team:AddArrow(Position.Left, '❰', function(player)
			self.team = self.team - 1
			
			if (self.team < TeamId.Team1) then
				self.team = TeamId.TeamIdCount - 1
			end
			
			input_team:SetValue(self.team)
			
			NetEvents:SendTo('UI', player, 'VIEW', self.view:GetName(), 'UPDATE', json.encode({
				Type	= input_team:__class(),
				Name	= input_team:GetName(),
				Value	= input_team:GetValue()
			}))
		end)
		
		input_team:AddArrow(Position.Right, '❱', function(player)
			self.team = self.team + 1
			
			if (self.team >= TeamId.TeamIdCount) then
				self.team = TeamId.Team1
			end
			
			input_team:SetValue(self.team)
			
			NetEvents:SendTo('UI', player, 'VIEW', self.view:GetName(), 'UPDATE', json.encode({
				Type	= input_team:__class(),
				Name	= input_team:GetName(),
				Value	= input_team:GetValue()
			}))
		end)
		
		bot_kick_team:AddInput(Position.Left, input_team)
		bots:AddItem(bot_kick_team, 'UserInterface.BotEditor.KickTeam')
		
		bots:AddItem(MenuItem('Kill All', 'bot_kill_all', function(player)
			Globals.SpawnMode	= 'manual'
			
			m_BotManager:killAll()
		end, 'F4'), 'UserInterface.BotEditor.KillAll')
		
		bots:AddItem(MenuSeparator())
		
		bots:AddItem(MenuItem('Toggle Respawn', 'bot_respawn', function(player)
			local respawning		= not Globals.RespawnWayBots
			Globals.RespawnWayBots	= respawning
			m_BotManager:setOptionForAll('respawn', respawning)
			
			if respawning then
				ChatManager:Yell(Language:I18N('Bot respawn activated!'), 2.5)
			else
				ChatManager:Yell(Language:I18N('Bot respawn deactivated!'), 2.5)
			end
		end), 'UserInterface.BotEditor.ToggleRespawn')
		
		bots:AddItem(MenuItem('Toggle Attack', 'bot_attack', function(player)
			local attack			= not Globals.AttackWayBots
			Globals.AttackWayBots	= attack
			m_BotManager:setOptionForAll('shoot', attack)
			
			if attack then
				ChatManager:Yell(Language:I18N('Bots will attack!'), 2.5)
			else
				ChatManager:Yell(Language:I18N('Bots will not attack!'), 2.5)
			end
		end), 'UserInterface.BotEditor.ToggleAttack')
	
	navigation:AddItem(bots)
	
	-- Waypoint-Editor
	navigation:AddItem(MenuItem('Waypoint-Editor', 'waypoint-editor', 'UI:VIEW:WaypointEditor:SHOW'):SetIcon('Assets/Icons/WaypointEditor.svg'), 'UserInterface.WaypointEditor')
	
	-- Settings
	navigation:AddItem(MenuItem('Settings', 'settings', function(player)
		self.view:GetCore():GetDialog('Settings'):Open(self.view, player)
	end, 'F10'):SetIcon('Assets/Icons/Settings.svg'), 'UserInterface.Settings')
	
	-- Exit
	navigation:AddItem(MenuItem('Exit', 'exit', 'UI:VIEW:' .. self.view:GetName() .. ':HIDE', 'F12'))
	
	self.view:AddComponent(navigation)
end

return BotEditor