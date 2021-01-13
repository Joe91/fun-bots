class('FunBotUIClient')

function FunBotUIClient:__init()
	self._webui = 0;
	
	Events:Subscribe('exitui', self, self._onExitUi);
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded);
	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput);
end

function FunBotUIClient:_onExitUi(player)
    if self._webui == 1 then
        self._webui = 0;
		print('Hide UI.');
    end
end

function FunBotUIClient:_onExtensionLoaded()
	WebUI:Init();
	WebUI:Hide();
end

function FunBotUIClient:_onUpdateInput(data)
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F1) then
		if (self._webui == 0) then
			WebUI:Show();
			WebUI:EnableMouse();
			WebUI:EnableKeyboard();	
			self._webui = 1;
			print('Show UI.');
		elseif (self._webui == 1) then
			WebUI:Hide();
			WebUI:ResetMouse();
			WebUI:ResetKeyboard();
			self._webui = 0;
			print('Hide UI.');
		end
	end

  	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F5) then
		NetEvents:Send('keypressF5');
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F6) then
		NetEvents:Send('keypressF6');
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F7) then
		NetEvents:Send('keypressF7');
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F8) then
		NetEvents:Send('keypressF8');
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F9) then
		NetEvents:Send('keypressF9');
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F10) then
		NetEvents:Send('keypressF10');
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F11) then
		NetEvents:Send('keypressF11');
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		NetEvents:Send('keypressF12');
	end
end

if (g_FunBotUIClient == nil) then
	g_FunBotUIClient = FunBotUIClient();
end

return g_FunBotUIClient;