class('FunBotUIClient')

local ArrayMap = require('__shared/ArrayMap');

function FunBotUIClient:__init()
	self._webui = 0;
	self._views = ArrayMap();

	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded);
	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput);

	-- New Events
	Events:Subscribe('UI_Close', self, self._onUIClose);
	NetEvents:Subscribe('UI_Request_Password', self, self._onUIRequestPassword);
	NetEvents:Subscribe('UI_Request_Password_Error', self, self._onUIRequestPasswordError);
	NetEvents:Subscribe('UI_Show_Toolbar', self, self._onUIShowToolbar);
	Events:Subscribe('UI_Send_Password', self, self._onUISendPassword);
end

function FunBotUIClient:_onUIShowToolbar(data)
	print('UIClient: UI_Show_Toolbar (' .. tostring(data) .. ')');
	
	if (data == 'true') then
		self._views:add('toolbar');
		WebUI:ExecuteJS('BotEditor.show(\'toolbar\');');	
	else
		self._views:delete('toolbar');
		WebUI:ExecuteJS('BotEditor.hide(\'toolbar\');');
	end
	
	if self._views:isEmpty() then
		self:_hide();
	else
		self:_show();
	end
end

function FunBotUIClient:_onUIRequestPasswordError(data)
	print('UIClient: UI_Request_Password_Error');
	WebUI:ExecuteJS('BotEditor.error(\'password\', \'' .. data .. '\');');
end

function FunBotUIClient:_onUIRequestPassword(data)
	print('UIClient: UI_Request_Password (' .. tostring(data) .. ')');
	
	if (data == 'true') then
		self._views:add('password');
		WebUI:ExecuteJS('BotEditor.show(\'password\');');	
	else
		self._views:delete('password');
		WebUI:ExecuteJS('BotEditor.hide(\'password\');');
	end
	
	if self._views:isEmpty() then
		self:_hide();
	else
		self:_show();
	end
end

function FunBotUIClient:_onUISendPassword(data)
	print('UIClient: UI_Send_Password (' .. data .. ')');
	NetEvents:Send('UI_Request_Open', data);
end

function FunBotUIClient:_onUIClose(player)
	if self:_isVisible() then
		if self._views:isEmpty() then
			self:_hide();
		else
			self:_show();
		end
	end
end

function FunBotUIClient:_onExtensionLoaded()
	WebUI:Init();
	WebUI:Hide();
end

function FunBotUIClient:_show()
	WebUI:Show();
	WebUI:EnableMouse();
	WebUI:EnableKeyboard();
	self._webui = 1;
	print('Show UI.');
end

function FunBotUIClient:_hide()
	WebUI:Hide();
	WebUI:ResetMouse();
	WebUI:ResetKeyboard();
	self._webui = 0;
	print('Hide UI.');
end

function FunBotUIClient:_toggle()
	if (self:_isVisible()) then
		self:_hide();
	else
		if self._views:isEmpty() then
			self:_hide();
		else
			self:_show();
		end
	end
end

function FunBotUIClient:_isVisible()
	return (self._webui == 1);
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
