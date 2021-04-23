class('FunBotShared')

require('__shared/Debug')
require('__shared/Version')
require('__shared/WeaponList')
require('__shared/EbxEditUtils')

local m_Language = require('__shared/Language')

function FunBotShared:__init()
	Events:Subscribe('Extension:Loaded', self, self.OnUpdateCheck)
end

function FunBotShared:OnUpdateCheck()
	print('fun-bots ' .. VERSION .. ' (' .. BRANCH .. ')')

	if Debug.Globals.UPDATE then
		print('Checking for Updates...')
	end

	local response	= Net:GetHTTP('https://api.github.com/repos/Joe91/fun-bots/releases?per_page=1')
	local json		= json.decode(response.body)

	if json == nil or json[1] == nil then
		if Debug.Globals.UPDATE then
			print('Can\'t fetch the latest Version from GitHub.')
		end
	elseif 'V' .. VERSION ~= json[1].name then
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
			print('++++++++++++++++++++++++++++++++++++++++++++++++++')
			print('New version available!')
			print('Installed Version: V' .. VERSION)
			print('Online Version: ' .. json[1].name)
			print('++++++++++++++++++++++++++++++++++++++++++++++++++')
		elseif Debug.Globals.UPDATE then
			print('You have already the newest version installed.')
		end
	elseif Debug.Globals.UPDATE then
		print('You have already the newest version installed.')
	end

	-- @ToDo adding new update-info on WebUI
end

-- Singleton.
if g_FunBotShared == nil then
	g_FunBotShared = FunBotShared()
end
