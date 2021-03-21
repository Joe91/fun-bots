class('BotEditor');

function BotEditor:__init(core)
	self.view	= View(core, 'BotEditor');
	self.bots	= 1;
end

function BotEditor:Show(player)
	self.view:Show(player);
	self.view:Activate(player);
end

function BotEditor:Hide(player)
	self.view:Hide(player);
	self.view:Deactivate(player);
end

function BotEditor:Toggle(player)
	self.view:Toggle(player);
end

function BotEditor:Call(element, name)
	self.view:Call(element, name);
end

function BotEditor:GetName()
	return self.view:GetName();
end

-- Here you can add/remove some Components from the Bot-Editor View
function BotEditor:InitializeComponent()
	-- Logo
	local logo = Logo('Bot-Editor', 'fun-bots');
	logo:SetPosition(Position.Absolute, {
		Top		= 20,
		Left	= 20
	});
	self.view:AddComponent(logo);
	
	-- Menu
	local navigation = Menu();
	
	navigation:SetPosition(Position.Absolute, {
		Top		= 20,
		Right	= 20
	});
	
	-- Bots
	local bots = MenuItem('Bots', 'bots');
	bots:SetIcon('Assets/Icons/Bot.svg');
		local input_number = Input(Type.Integer, 'bots', 1);
		
		input_number:AddArrow(Position.Left, '❰', function()
			self.bots = self.bots - 1;
			
			if (self.bots < 0) then
				self.bots = 0;
			end
			
			input_number:SetValue(self.bots);
			
			NetEvents:Broadcast('UI', 'VIEW', self.view:GetName(), 'UPDATE', json.encode({
				Type	= input_number:__class(),
				Name	= input_number:GetName(),
				Value	= input_number:GetValue()
			}));
		end);
		
		input_number:AddArrow(Position.Right, '❱', function()
			self.bots = self.bots + 1;
			
			if (self.bots > 50) then
				self.bots = 50;
			end
			
			input_number:SetValue(self.bots);
			
			NetEvents:Broadcast('UI', 'VIEW', self.view:GetName(), 'UPDATE', json.encode({
				Type	= input_number:__class(),
				Name	= input_number:GetName(),
				Value	= input_number:GetValue()
			}));
		end);
		
		-- Submenu
		local bot_spawn_default = MenuItem('Spawn Enemy Bots', 'bot_spawn_default', function()
			print('bot_spawn_default Executed');
		end, 'F2');
		
		bot_spawn_default:AddInput(Position.Left, input_number);
		bots:AddItem(bot_spawn_default);
		
		local bot_spawn_friend = MenuItem('Spawn Friend Bots', 'bot_spawn_friend', function()
			print('bot_spawn_friend Executed');
		end);
		
		bot_spawn_friend:AddInput(Position.Left, input_number);
		bots:AddItem(bot_spawn_friend);
		
		bots:AddItem(MenuSeparator());
		
		bots:AddItem(MenuItem('Kick All', 'bot_kick_all', function()
			print('bot_kick_all Executed');
		end, 'F3'));
		
		bots:AddItem(MenuItem('Kick Team', 'bot_kick_team', function()
			print('bot_kick_team Executed');
		end));
		
		bots:AddItem(MenuItem('Kill All', 'bot_kill_all', function()
			print('bot_kill_all Executed');
		end, 'F4'));
		
		bots:AddItem(MenuSeparator());
		
		bots:AddItem(MenuItem('Toggle Respawn', 'bot_respawn', function()
			print('bot_respawn Executed');
		end));
		
		bots:AddItem(MenuItem('Toggle Attack', 'bot_attack', function()
			print('bot_attack Executed');
		end));
	
	navigation:AddItem(bots);
	
	-- Waypoint-Editor
	navigation:AddItem(MenuItem('Waypoint-Editor', 'waypoint-editor', 'UI:VIEW:WaypointEditor:SHOW'):SetIcon('Assets/Icons/WaypointEditor.svg'));
	
	-- Settings
	navigation:AddItem(MenuItem('Settings', 'settings', function()
		print('Open Settings');
	end, 'F10'):SetIcon('Assets/Icons/Settings.svg'));
	
	-- Exit
	navigation:AddItem(MenuItem('Exit', 'exit', 'UI:VIEW:' .. self.view:GetName() .. ':HIDE', 'F12'));
	
	self.view:AddComponent(navigation);
end

return BotEditor;