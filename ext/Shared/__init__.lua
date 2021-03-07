class('FunBotShared');

require('__shared/Debug');
require('__shared/Version');
require('__shared/WeaponList');
require('__shared/EbxEditUtils');

Language					= require('__shared/Language');

function FunBotShared:__init()
	Events:Subscribe('Extension:Loaded', self, self.OnUpdateCheck)
end

function FunBotShared:OnUpdateCheck()
	print('fun-bots ' .. VERSION .. ' (' .. BRANCH .. ')');
	
	if Debug.Globals.Globals then
		print('Checking for Updates...');
	end
	
	local response	= Net:GetHTTP('https://api.github.com/repos/Joe91/fun-bots/releases?per_page=1');
	local json		= json.decode(response.body);
	
	if 'V' .. VERSION ~= json[1].name then
		local isOlderVersion	= false
		local currentV			= VERSION:split('.')
		local latestV			= json[1].name:sub(2):split('.')

		for i = 1, #currentV do
			if (currentV[i] ~= latestV[i]) then
				isOlderVersion = (currentV[i] < latestV[i])
				break
			end
		end

		if (isOlderVersion) then
			print('++++++++++++++++++++++++++++++++++++++++++++++++++');
			print('New version available!');
			print('Installed Version: V' .. VERSION);
			print('Online Version: ' .. json[1].name);
			print('++++++++++++++++++++++++++++++++++++++++++++++++++');
		elseif Debug.Globals.Globals then
			print('You have already the newest version installed.');
		end
	elseif Debug.Globals.Globals then
		print('You have already the newest version installed.');
	end
	
	-- @ToDo adding new update-info on WebUI
end

-- Singleton.
if g_FunBotShared == nil then
	g_FunBotShared = FunBotShared();
end