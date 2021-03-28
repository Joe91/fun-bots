class('UI');

require('UI/Constants/Type');
require('UI/Constants/Position');
require('UI/Constants/Color');

function UI:__init()
	-- Disable WebInterface
	if Config.disableUserInterface == true then
		print('[UI] UserInterface is disabled by Configuration.');
		return;
	end
	
	-- Components that will be loaded
	self.boot	= {
		'Input',
		'Logo',
		'Menu',
		'View',
		'Alert',
		'Dialog',
		'Box'
	};
	
	-- Views that will be loaded
	self.load	= {
		'BotEditor',
		'WaypointEditor'
	};
	
	-- Do not modify here
	_G.Callbacks	= {};
	self.views		= {};
	self.booted		= 0;
	self.loaded		= 0;
	
	self.events = {
		ModuleLoaded	= Events:Subscribe('Extension:Loaded', self, self.__boot),
		EngineUpdate	= Events:Subscribe('Engine:Update', self, self.__update),
		UI				= NetEvents:Subscribe('UI', self, self.__action);
	};
end

function UI:GetView(name)
	if (self.views[name] ~= nil) then
		return self.views[name];
	end
	
	return nil;
end

function UI:__boot()
	print('[UI] Booting...');
	
	-- Load all required Components
	for _, component in pairs(self.boot) do
		local try = requireExists('UI/Components/' .. component);
		
		if (try ~= true) then
			print('[UI] ERROR: Can\'t load Component: ' .. component .. ' (' .. try .. ')');
		else
			print('[UI] Component "' .. component .. '" was loaded.');
			self.booted = self.booted + 1;
		end
	end
	
	-- Load Views
	for _, view in pairs(self.load) do
		local try = requireExists('UI/Views/' .. view);
		
		if (try ~= true) then
			print('[UI] ERROR: Can\'t load View: ' .. view .. ' (' .. try .. ')');
		else
			print('[UI] View "' .. view .. '" was loaded.');
		end
	end
end

function UI:__update()
	for _, view in pairs(self.load) do
		if (self.views[view] == nil) then
			if (_G[view] ~= nil) then
				local instance = _G[view](self);
				
				if (instance ~= nil) then
					if (instance['GetName'] ~= nil) then
						if (instance['InitializeComponent'] ~= nil) then
							instance:InitializeComponent();
						end
						
						self.views[view]	= instance;
						self.loaded			= self.loaded + 1;
					end
				end
			end
		end
	end

	if (self.booted == #self.boot and #self.load == self.loaded) then
		self.events.EngineUpdate:Unsubscribe();
	end
end

-- All UI Actions will be handled here
function UI:__action(player, type, destination, action, data)
	print('[UI] Action { Type=' .. tostring(type) .. ', Destination=' .. tostring(destination) ..', Action=' .. tostring(action) .. ', Data=' .. json.encode(data) .. '}');
	
	if (type == 'VIEW') then
		if (self.views[destination] == nil) then
			print('[UI] The View "' .. destination .. '" doesn\'t exists.');
			return;
		end
			
		local view = self.views[destination];
		
		if (action == 'SHOW' or action == 'SHOWING') then
			view:Show(player);
		elseif (action == 'HIDE' or action == 'HIDING') then
			view:Hide(player);
		elseif (action == 'TOGGLE') then
			view:Toggle(player);
		elseif (action == 'ACTIVATE') then
			view:Activate(player);
		elseif (action == 'DEACTIVATE') then
			view:Deactivate(player);
		elseif (action == 'ACTION' or action == 'CALL') then
			local element	= nil;
			local name		= nil;
			
			if string.find(data, '$') then
				local parts = data:split('$');
				element		= parts[1];
				name		= parts[2];
			else
				name		= data;
			end
			
			view:Call(player, element, name);
		end
	end
end

-- Singleton.
if g_UI == nil then
	g_UI = UI();
end

return g_UI;