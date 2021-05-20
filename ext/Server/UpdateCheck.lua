local function CheckVersion()
	print('fun-bots ' .. VERSION .. ' (' .. BRANCH .. ')')

	if Debug.Globals.UPDATE then
		print('Checking for Updates...')
	end

	local s_Response = Net:GetHTTP('https://api.github.com/repos/Joe91/fun-bots/releases?per_page=1')
	local s_JSON = json.decode(s_Response.body)

	if s_JSON == nil or s_JSON[1] == nil then
		if Debug.Globals.UPDATE then
			print('Can\'t fetch the latest Version from GitHub.')
		end
	elseif 'V' .. VERSION ~= s_JSON[1].name then
		local s_IsOlderVersion = false
		local s_CurrentVersion = VERSION:split('.')
		local s_LatestVersion = s_JSON[1].name:sub(2):split('.')

		for i = 1, #s_CurrentVersion do
			if s_CurrentVersion[i] == nil or s_LatestVersion[i] == nil then
				print("failed to check")
				break
			end
			if s_CurrentVersion[i] ~= s_LatestVersion[i] then
				s_IsOlderVersion = (s_CurrentVersion[i] < s_LatestVersion[i])
				break
			end
		end

		if s_IsOlderVersion then
			print('++++++++++++++++++++++++++++++++++++++++++++++++++')
			print('New version available!')
			print('Installed Version: V' .. VERSION)
			print('Online Version: ' .. s_JSON[1].name)
			print('++++++++++++++++++++++++++++++++++++++++++++++++++')
		elseif Debug.Globals.UPDATE then
			print('You have already the newest version installed.')
		end
	elseif Debug.Globals.UPDATE then
		print('You have already the newest version installed.')
	end

	-- @ToDo adding new update-info on WebUI
end

return CheckVersion()
