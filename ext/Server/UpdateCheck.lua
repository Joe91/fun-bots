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

local function UpdateFinished(p_CycleId, p_Success, p_UpdateAvailable, p_UpdateUrl, p_UpdateData, p_Log)
	-- Update the latest release date
	UpdateStatus.check_timestamp_any = os.time(os.date("!*t"))

	-- Check if the update was successfull
	if not p_Success then
		print('[UPDATE] Failed to check for an update.') -- @ToDo: Move this to a logger

		-- Update the hookable variables
		UpdateStatus.available = 99

		do return end
	end

	-- Update success timestamp
	UpdateStatus.check_timestamp_success = os.time(os.date("!*t"))

	-- Check if there is not an update available and that we are running the latest version
	if not p_UpdateAvailable then
		print('[UPDATE] You are running the latest version') -- @ToDo: Move this to a logger

		-- Update the hookable variables
		UpdateStatus.available = 2
		do return end
	end

	UpdateStatus.available = 1
	UpdateStatus.URL_download = p_UpdateUrl

	if p_UpdateData.relTimestamp ~= nil then
		print('[ + ] A new version for fun-bots was released on ' .. os.date('%d-%m-%Y %H:%M', ParseOffset(p_UpdateData.relTimestamp)) .. '!')
	else

		print('[ + ] A new version for fun-bots is available!')
	end

	print('[ + ] Upgrade from ' .. Config.Version.Tag .. ' to ' .. p_UpdateData.tag)
	print('[ + ] Download: ' .. p_UpdateUrl)
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
	local s_EndpointURL = ApiUrls.stable -- Defaulting to the stable URL
	local s_EndpointType = 0 -- A number we can track so we know which type we used

	if Config.AutoUpdater.ReleaseCycle == "RC" then -- Release Candidates (or pre-releases)
		s_EndpointURL = ApiUrls.pre_release
		s_EndpointType = 1
	end

	if Config.AutoUpdater.ReleaseCycle == "DEV" then -- Development builds (Github tags)
		s_EndpointURL = ApiUrls.dev
		s_EndpointType = 2
	end

	-- Make a HTTP request to the REST API
	local s_endpointResponse = Net:GetHTTP(s_EndpointURL)

	-- Check if response is not nil
	if s_endpointResponse == nil then
		UpdateFinished(s_EndpointType, false, false, nil, nil, nil) -- TODO: Awaiting the debugging refactor to make a throwable error
		do return end
	end

	-- Parse JSON
	local s_EndpointJSON = json.decode(s_endpointResponse.body)

	if s_EndpointJSON == nil then
		UpdateFinished(s_EndpointType, false, false, nil, nil, nil)
		do return end
	end

	-- Response is different based on the cycle request
	-- @ToDo: Make the current version better as it currently checks strings. It should check an incremental value instead.

 	-- Stable and release candidates follow the same body
	if (s_EndpointType == 0) then
		if Config.Version.Tag == s_EndpointJSON['tag_name'] then
			UpdateFinished(s_EndpointType, true, false, nil, nil, nil)
			do return end
		end

		UpdateFinished(s_EndpointType, true, true, s_EndpointJSON['html_url'], {tag = s_EndpointJSON['tag_name'], relTimestamp = s_EndpointJSON['published_at']}, nil)
	end

	if (s_EndpointType == 1) then
		if Config.Version.Tag == s_EndpointJSON[1]['tag_name'] then
			UpdateFinished(s_EndpointType, true, false, nil, nil, nil)
			do return end
		end

		UpdateFinished(s_EndpointType, true, true, s_EndpointJSON[1]['html_url'], {tag = s_EndpointJSON[1]['tag_name'], relTimestamp = s_EndpointJSON[1]['published_at']}, nil)
	end

	 -- Development builds (tags)
	if (s_EndpointType == 2) then
		if Config.Version.Tag:gsub("V", "") == s_EndpointJSON[1]['name']:gsub("V", "") then
			UpdateFinished(s_EndpointType, true, false, nil, nil, nil)
			do return end
		end

		UpdateFinished(s_EndpointType, true, true, s_EndpointJSON[1]['zipball_url'], {tag = s_EndpointJSON[1]['name']}, nil)
	end
end

return CheckVersion()