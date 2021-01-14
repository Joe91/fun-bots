class 'FunBotUIClient';

require('UIViews');

function FunBotUIClient:__init()
	self._views = UIViews();
	
	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput);

	-- New Events
	NetEvents:Subscribe('UI_Toggle', self, self._onUIToggle);
	NetEvents:Subscribe('UI_Request_Password', self, self._onUIRequestPassword);
	NetEvents:Subscribe('UI_Request_Password_Error', self, self._onUIRequestPasswordError);
	NetEvents:Subscribe('UI_Show_Toolbar', self, self._onUIShowToolbar);
	Events:Subscribe('UI_Send_Password', self, self._onUISendPassword);
end

function FunBotUIClient:_onUIToggle()
	print('UIClient: UI_Toggle');
	
	if self._views:_isVisible() then
		self._views:_hide();
	else
		self._views:_show();
	end
end

function FunBotUIClient:_onUIShowToolbar(data)
	print('UIClient: UI_Show_Toolbar (' .. tostring(data) .. ')');
	
	if (data == 'true') then
		self._views:show('toolbar');
	else
		self._views:hide('toolbar');
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
		NetEvents:Send('UI_Request_Open');
	end
end

if (g_FunBotUIClient == nil) then
	g_FunBotUIClient = FunBotUIClient();
end

return g_FunBotUIClient;
