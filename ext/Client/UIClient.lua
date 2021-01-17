class 'FunBotUIClient';

require('UIViews');
require('UISettings');

function FunBotUIClient:__init()
	self._views = UIViews();
	
	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput);
	NetEvents:Subscribe('UI_Toggle', self, self._onUIToggle);
	Events:Subscribe('UI_Toggle', self, self._onUIToggle);
	NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent);
	Events:Subscribe('BotEditor', self, self._onBotEditorEvent);
	NetEvents:Subscribe('UI_Request_Password', self, self._onUIRequestPassword);
	NetEvents:Subscribe('UI_Request_Password_Error', self, self._onUIRequestPasswordError);
	NetEvents:Subscribe('UI_Password_Protection', self, self._onUIPasswordProtection);
	NetEvents:Subscribe('UI_Show_Toolbar', self, self._onUIShowToolbar);
	NetEvents:Subscribe('UI_Settings', self, self._onUISettings);
	Events:Subscribe('UI_Settings', self, self._onUISettings);
	Events:Subscribe('UI_Send_Password', self, self._onUISendPassword);
	
	-- Events from BotManager, TraceManager & Other
	NetEvents:Subscribe('Trace_Started', self, self._onTraceStarted);
	NetEvents:Subscribe('Trace_Stopped', self, self._onTraceStopped);
	
	self._views:setLanguage(Config.language);
end

-- Events
function FunBotUIClient:_onTraceStarted(index)
	self._views:execute('BotEditor.toggleTraceRun(true);');
end

function FunBotUIClient:_onTraceStopped(index)
	self._views:execute('BotEditor.toggleTraceRun(false);');
end

function FunBotUIClient:_onUIToggle()
	print('UIClient: UI_Toggle');
	
	if self._views:isVisible() then
		self._views:close();
	else
		self._views:open();
		self._views:focus();
	end
end

function FunBotUIClient:_onUISettings(data)
	print('UIClient: UI_Settings (' .. json.encode(data) .. ')');
	
	local settings = UISettings();
	
	--settings:add();
	self._views:execute('BotEditor.openSettings(\'' .. json.encode(settings:getProperties()) .. '\');');
end

function FunBotUIClient:_onBotEditorEvent(data)
	print('UIClient: BotEditor (' .. data .. ')');
	
	-- Redirect to Server
	NetEvents:Send('BotEditor', data);
end

function FunBotUIClient:_onUIShowToolbar(data)
	print('UIClient: UI_Show_Toolbar (' .. tostring(data) .. ')');
	
	if (data == 'true') then
		self._views:show('toolbar');
		self._views:focus();
	else
		self._views:hide('toolbar');
		self._views:blur();
	end
end

function FunBotUIClient:_onUIPasswordProtection(data)
	print('UIClient: UI_Password_Protection (' .. tostring(data) .. ')');
	
	if (data == 'true') then
		self._views:show('password_protection');
		self._views:focus();
	else
		self._views:hide('password_protection');
		self._views:blur();
	end
end

function FunBotUIClient:_onUIRequestPasswordError(data)
	print('UIClient: UI_Request_Password_Error');
	self._views:error('password', data);
end

function FunBotUIClient:_onUIRequestPassword(data)
	print('UIClient: UI_Request_Password (' .. tostring(data) .. ')');
	
	if (data == 'true') then
		self._views:show('password');
		self._views:focus();
	else
		self._views:hide('password');
		self._views:blur();
	end
end

function FunBotUIClient:_onUISendPassword(data)
	print('UIClient: UI_Send_Password (' .. data .. ')');
	NetEvents:Send('UI_Request_Open', data);
end


function FunBotUIClient:_onUpdateInput(data)
	-- Show or Hide the Bot-Editor by requesting permissions
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		print('Client send: UI_Request_Open');
		
		-- This request can use for UI-Toggle
		NetEvents:Send('UI_Request_Open');
	end
end

if (g_FunBotUIClient == nil) then
	g_FunBotUIClient = FunBotUIClient();
end

return g_FunBotUIClient;
