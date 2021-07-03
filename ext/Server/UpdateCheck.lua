--[[ Global update hook ]]--
UpdateStatus = {
	available = 0, -- 0 if no update has been checked for, 1 if an update is available, 2 if an update is NOT available, 99 for technical issues
	URL_download = nil, -- URL to download the new update from
	check_timestamp_success = 0, -- unix timestamp of the last successfull check
	check_timestamp_any = 0 -- unix timestamp of the last check (either succesfull or unsuccessfull)
}

--[[ Auto updater check --]]
local ApiUrls = {
	stable = 'https://api.github.com/repos/Joe91/fun-bots/releases/latest?per_page=1',
	pre_release = 'https://api.github.com/repos/Joe91/fun-bots/releases?per_page=1',
	dev = 'https://api.github.com/repos/Joe91/fun-bots/tags?per_page=1'
}


local function updateFinished(cycleId, success, update_available, update_url, update_data, log)
	-- Check if the update was successfull
	if not success then
		print('[UPDATE] Failed to check for an update.') -- @ToDo: Move this to a logger
		NetEvents:Broadcast("updateChecker:finished", false, false, nil) -- success (bool), available (bool), logs (table)
		do return end
	end

	-- Check if there is not an update available and that we are running the latest version
	if not update_available then
		print('[UPDATE] You are running the latest version') -- @ToDo: Move this to a logger
		NetEvents:Broadcast("updateChecker:finished", false, true, nil)
		do return end
	end

	if update_data.relTimestamp ~= nil then

		print('[ + ] A new version for fun-bots was released on ' .. string.format(parseOffset(update_data.relTimestamp)) .. '!')
	else

		print('[ + ] A new version for fun-bots is available!')
	end

	print('[ + ] Upgrade from ' .. Config.Version.Tag .. ' to ' .. update_data.tag)
	print('[ + ] Download: ' .. update_url)
end

-- Check for the latest version
local function CheckVersion()
	-- Check if the user has it enabled in configuration file
	if not Config.AutoUpdater.Enabled then
		print('[UPDATE] You disabled checking for new updates in your configuration file.')
		do return end
	end

	print('[UPDATE] Checking for a newer version.')
	
	-- Get the appropriate URL for the API based on the user configurations input.
	-- Default to the stable URL
	local s_endpointURL = ApiUrls.stable -- Defaulting to the stable URL
	local s_endpointType = 0 -- A number we can track so we know which type we used

	if Config.AutoUpdater.ReleaseCycle == "RC" then -- Release Candidates (or pre-releases)
		s_endpointURL = ApiUrls.pre_release
		s_endpointType = 1
	end

	if Config.AutoUpdater.ReleaseCycle == "DEV" then -- Development builds (Github tags)
		s_endpointURL = ApiUrls.dev
		s_endpointType = 2
	end

	-- Make a HTTP request to the REST API
	local s_endpointResponse = Net:GetHTTP(s_endpointURL)

	-- Check if response is not nil
	if s_endpointResponse == nil then
		updateFinished(s_endpointType, false, false, nil, nil, nil) -- TODO: Awaiting the debugging refactor to make a throwable error
		do return end
	end

	-- Parse JSON
	local s_endpointJSON = json.decodes(s_endpointResponse.body)

	if s_endpointJSON == nil or s_endpointJSON[1] == nil then
		updateFinished(s_endpointType, false, false, nil, nil, nil)
		do return end
	end

	-- Response is different based on the cycle request
	if (s_endpointType == 0) then -- Stable
		if Config.Version.Tag == s_endpointJSON['tag_name'] then
			updateFinished(s_endpointType, true, false, nil, nil, nil)
			do return end
		end

		updateFinished(s_endpointType, true, false, s_endpointJSON['html_url'], {tag = s_endpointJSON['tag_name'], relTimestamp = s_endpointJSON['published_at']}, nil)
	end


	-- @ToDo adding new update-info on WebUI
end

return CheckVersion()
