class('FunBotShared');

require('__shared/Version');
require('__shared/WeaponList');
require('__shared/EbxEditUtils');

Language					= require('__shared/Language');
local WeaponModification	= require('__shared/WeaponModification');

function FunBotShared:__init()
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded);
	Events:Subscribe('Extension:Loaded', self, self.OnUpdateCheck)
end

function FunBotShared:OnUpdateCheck()
	print('fun-bots ' .. VERSION .. ' (' .. BRANCH .. ')');
	print('Checking for Updates...');
	
	local response	= Net:GetHTTP('https://api.github.com/repos/Joe91/fun-bots/releases?per_page=1');
	local json		= json.decode(response.body);
	
	if 'V' .. VERSION ~= json[1].name then

		local isOlderVersion = false
		local currentV = VERSION:split('.')
		local latestV = json[1].name:sub(2):split('.')

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
		else
			print('You have already the newest version installed.');
		end
	else
		print('You have already the newest version installed.');
	end
	
	-- @ToDo adding new update-info on WebUI
end

function FunBotShared:OnPartitionLoaded(p_Partition)
	WeaponModification:OnPartitionLoaded(p_Partition);
end

-- Singleton.
if g_FunBotShared == nil then
	g_FunBotShared = FunBotShared();
end