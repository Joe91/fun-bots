local ApiUrls = {
	release = 'https://api.github.com/repos/Joe91/fun-bots/releases/latest?per_page=1',
	stable = 'https://api.github.com/repos/Joe91/fun-bots/releases?per_page=1',
	dev = 'https://api.github.com/repos/Joe91/fun-bots/tags?per_page=1'
}

local function UpdateFinished(p_Success, p_UpdateAvailable, p_UpdateUrl, p_UpdateData, p_Log)
	-- Check if the update was successfull
	if not p_Success then
		print('[UPDATE] Failed to check for an update.') -- @ToDo: Move this to a logger
		do return end
	end

	-- Check if there is not an update available and that we are running the latest version
	if not p_UpdateAvailable then
		print('[UPDATE] You are running the latest version') -- @ToDo: Move this to a logger
		do return end
	end

	if p_UpdateData.relTimestamp ~= nil then
		print('[ + ] A new version for fun-bots was released on ' .. os.date('%d-%m-%Y %H:%M', ParseOffset(p_UpdateData.relTimestamp)) .. '!')
	else
		print('[ + ] A new version for fun-bots is available!')
	end

	print('[ + ] Upgrade to ' .. p_UpdateData.tag)
	print('[ + ] Download: ' .. p_UpdateUrl)
end

-- Callback for updateCheck async request.
local function updateCheckCB(httpRequest)
	-- Parse JSON
	local s_EndpointJSON = json.decode(httpRequest.body)
	if s_EndpointJSON == nil then
		UpdateFinished(false, false, nil, nil, nil)
		do return end
	end

	-- Response is different based on the cycle request
	-- @ToDo: Make the current version better as it currently checks strings. It should check an incremental value instead.

	-- Stable and release candidates follow the same body
	if Registry.VERSION.UPDATE_CHANNEL == VersionType.Release then
		if "V" .. RegistryManager:GetUtil():GetVersion() == s_EndpointJSON['tag_name'] then
			UpdateFinished(true, false, nil, nil, nil)
			do return end
		end

		UpdateFinished(true, true, s_EndpointJSON['html_url'], {tag = s_EndpointJSON['tag_name'], relTimestamp = s_EndpointJSON['published_at']}, nil)
		do return end
	elseif Registry.VERSION.UPDATE_CHANNEL == VersionType.Stable then
		if "V" .. RegistryManager:GetUtil():GetVersion() == s_EndpointJSON[1]['tag_name'] then
			UpdateFinished(true, false, nil, nil, nil)
			do return end
		end

		UpdateFinished(true, true, s_EndpointJSON[1]['html_url'], {tag = s_EndpointJSON[1]['tag_name'], relTimestamp = s_EndpointJSON[1]['published_at']}, nil)
		do return end
	else
		-- Development builds
		if RegistryManager:GetUtil():GetVersion() == s_EndpointJSON[1]['name']:gsub("v", "", 1) then
			UpdateFinished(true, false, nil, nil, nil)
			do return end
		end

		UpdateFinished(true, true, s_EndpointJSON[1]['zipball_url'], {tag = s_EndpointJSON[1]['name']}, nil)
	end
end

-- Async check for newer updates
-- Return: tba
local function UpdateCheck()

	-- Calculate the URL to get from.
	local s_EndpointURL = ApiUrls.release

	-- If development builds are enabled, get latest tags
	if Registry.VERSION.UPDATE_CHANNEL == VersionType.DevBuild then
		s_EndpointURL = ApiUrls.dev
	elseif Registry.VERSION.UPDATE_CHANNEL == VersionType.Stable then
		s_EndpointURL = ApiUrls.stable
	end

	Net:GetHTTPAsync(s_EndpointURL, updateCheckCB)
end

return UpdateCheck()