class('FunBotUIServer')

require('__shared/Utils')
local TraceManager = require('traceManager');

function FunBotUIServer:__init()
	self._webui			= 0;
	self._authenticated	= {};

	NetEvents:Subscribe('UI_Request_Open', self, self._onUIRequestOpen);
end

function FunBotUIServer:_onUIRequestOpen(player, data)
	print(player.name .. ' requesting open Bot-Editor.');

	if (Config.settingsPassword == nil or self._isAuthenticated(player.accountGuid)) then
		print('Open Bot-Editor for ' .. player.name .. '.');
	else
		if (data == nil) then
			print('Ask ' .. player.name .. ' for Bot-Editor password.');
			ChatManager:Yell('Please authenticate with password!', 2.5);
			NetEvents:SendTo('UI_Request_Password', player, 'true');
		else
			local form = json.decode(data);
			
			if (form.password ~= nil or form.password ~= '') then
				print(player.name .. ' has entered following Password: ' .. form.password);
				
				if (form.password == Config.settingsPassword) then
					table.insert(self._authenticated, tostring(player.accountGuid));
					print('accountGuid: ' .. tostring(player.accountGuid));
					ChatManager:Yell('Successfully authenticated.', 2.5);
					NetEvents:SendTo('UI_Request_Password', player, 'false');
					NetEvents:SendTo('UI_Show_Toolbar', player, 'true');
				else
					NetEvents:SendTo('UI_Request_Password_Error', player, 'The password you entered is not correct!');
					ChatManager:Yell('Bad password.', 2.5);
				end
			else
				NetEvents:SendTo('UI_Request_Password_Error', player, 'The password you entered is not correct!');
				ChatManager:Yell('Please enter a password!', 2.5);
			end
		end
	end
end

function FunBotUIServer:_isAuthenticated(guid)
	return contains(self._authenticated, tostring(guid));
end

if (g_FunBotUIServer == nil) then
	g_FunBotUIServer = FunBotUIServer();
end

return g_FunBotUIServer;
