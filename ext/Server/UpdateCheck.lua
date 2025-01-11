require('__shared/Utilities.lua')

local ApiUrls = {
	release = 'https://api.github.com/repos/Joe91/fun-bots/releases/latest?per_page=1',
	stable = 'https://api.github.com/repos/Joe91/fun-bots/releases?per_page=1',
	dev = 'https://api.github.com/repos/Joe91/fun-bots/tags?per_page=1'
}


-- Parse ISO 8601 timestamp (https://stackoverflow.com/questions/7911322/lua-iso-8601-datetime-parsing-pattern).
-- @author Firjen <https://github.com/Firjens>
local function ParseOffset(p_String)
	local s_Pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%-])(%d?%d?)%:?(%d?%d?)"
	local s_Year, s_Month, s_Day, s_Hour, s_Minute, s_Seconds, s_Offsetsign, s_Offsethour, s_Offsetmin = p_String:match(s_Pattern)
	local s_Timestamp = os.time { year = s_Year, month = s_Month,
		day = s_Day, hour = s_Hour, min = s_Minute, sec = s_Seconds }
	local s_Offset = 0

	if s_Offsetsign ~= 'Z' then
		s_Offset = tonumber(s_Offsethour) * 60 + tonumber(s_Offsetmin)

		if s_Offset == "-" then s_Offset = s_Offset * -1 end
	end

	return s_Timestamp + s_Offset
end

---comment
---@param p_Result integer
---@param p_UpdateUrl string|nil
---@param p_RemoteVersion string|nil
---@param p_RemoteTimestamp string|nil
---@param p_CurrentVersion string|nil
local function UpdateFinished(p_Result, p_UpdateUrl, p_RemoteVersion, p_RemoteTimestamp, p_CurrentVersion)
	-- Check if the update was successful.
	if p_Result < 0 then
		print('[UPDATE] Failed to check for an update.') --To-do: Move this to a logger.
		do return end
	end

	-- Check if there is not an update available and that we are running the latest version.
	if p_Result == 0 then
		print('[UPDATE] You are running the latest version') --To-do: Move this to a logger.
		do return end
	end

	if p_Result == 1 then
		print('[UPDATE] Your version is newer than the one on the selected Update-Channel') --To-do: Move this to a logger.
		print('[UPDATE] Your version is ' .. p_CurrentVersion)
		do return end
	end

	if p_Result == 2 then
		if p_RemoteTimestamp ~= nil then
			print('[ + ] A new version for fun-bots was released on ' ..
				os.date('%d-%m-%Y %H:%M', ParseOffset(p_RemoteTimestamp)) .. '!')
		else
			print('[ + ] A new version for fun-bots is available!')
		end

		print('[ + ] Upgrade to ' .. p_RemoteVersion)
		print('[ + ] Download: ' .. p_UpdateUrl)
	end

	if p_Result == 3 then
		print('[UPDATE] You are running the latest version')        --To-do: Move this to a logger.
		print('[UPDATE] There might be a new version on another Channel') --To-do: Move this to a logger.
	end
end

local function CompareVersion(p_CurrentVersion, p_ExternalVersion)
	-- Extract the digits.
	if p_CurrentVersion == p_ExternalVersion then
		return 0
	else
		-- Compare numbers.
		local s_TempVersion = p_CurrentVersion:gsub("V", "", 1):gsub("v", "", 1)
		local s_NumericPartsCurrentVersion = s_TempVersion:split("-")[1]:split(".")
		-- print(s_NumericPartsCurrentVersion)
		s_TempVersion = p_ExternalVersion:gsub("V", "", 1):gsub("v", "", 1)
		local s_NumericPartsRemoteVersion = s_TempVersion:split("-")[1]:split(".")

		-- print(s_NumericPartsRemoteVersion)
		for i = 1, #s_NumericPartsCurrentVersion do
			local s_NumberCurrent = tonumber(s_NumericPartsCurrentVersion[i])
			local s_NumberRemote = tonumber(s_NumericPartsRemoteVersion[i])

			if s_NumberCurrent ~= nil and s_NumberRemote ~= nil then
				if s_NumberCurrent > s_NumberRemote then
					return 1
				elseif s_NumberCurrent < s_NumberRemote then
					return 2
				end
			end
		end

		-- Compare dev-version.
		if string.find(p_CurrentVersion, "dev") ~= nil and string.find(p_ExternalVersion, "dev") ~= nil then
			local s_CurrentDev = p_CurrentVersion:split("dev")[2]
			local s_RemoteDev = p_ExternalVersion:split("dev")[2]

			if s_CurrentDev ~= nil and s_RemoteDev ~= nil then
				if tonumber(s_CurrentDev) > tonumber(s_RemoteDev) then
					return 1
				elseif tonumber(s_CurrentDev) < tonumber(s_RemoteDev) then
					return 2
				end
			end
		end

		-- Compare RC-version.
		if string.find(p_CurrentVersion, "RC") ~= nil and string.find(p_ExternalVersion, "RC") ~= nil then
			local s_CurrentRc = p_CurrentVersion:split("RC")[2]
			local s_RemoteRc = p_ExternalVersion:split("RC")[2]

			if s_CurrentRc ~= nil and s_RemoteRc ~= nil then
				if tonumber(s_CurrentRc) > tonumber(s_RemoteRc) then
					return 1
				elseif tonumber(s_CurrentRc) < tonumber(s_RemoteRc) then
					return 2
				end
			end
		end

		return 3
	end
end

-- Callback for updateCheck async request.
---@param httpRequest HttpResponse|nil
local function updateCheckCB(httpRequest)
	if httpRequest == nil then
		UpdateFinished(-1, nil, nil, nil, nil)
		return
	end
	-- Parse JSON.
	local s_EndpointJSON = json.decode(httpRequest.body)

	if s_EndpointJSON == nil then
		UpdateFinished(-1, nil, nil, nil, nil)
		do return end
	end

	-- Response is different based on the cycle request.
	--To-do: Make the current version better, as it currently checks strings. It should check an incremental value instead.
	local s_CurrentVersion = Registry.GetVersion()
	local s_RemoteVersion = nil
	local s_RemoteTimestamp = nil
	local s_RemoteUrl = nil

	if Registry.VERSION.UPDATE_CHANNEL == VersionType.Release then
		s_RemoteVersion = s_EndpointJSON['tag_name']
		s_RemoteTimestamp = s_EndpointJSON['published_at']
		s_RemoteUrl = s_EndpointJSON['html_url']
	elseif Registry.VERSION.UPDATE_CHANNEL == VersionType.Stable then
		s_RemoteVersion = s_EndpointJSON[1]['tag_name']
		s_RemoteTimestamp = s_EndpointJSON[1]['published_at']
		s_RemoteUrl = s_EndpointJSON[1]['html_url']
	elseif Registry.VERSION.UPDATE_CHANNEL == VersionType.DevBuild then
		s_RemoteVersion = s_EndpointJSON[1]['name']
	end

	local s_Result = CompareVersion(s_CurrentVersion, s_RemoteVersion)

	UpdateFinished(s_Result, s_RemoteUrl, s_RemoteVersion, s_RemoteTimestamp, s_CurrentVersion)
end

-- Async check for newer updates.
-- Return: tba.
local function UpdateCheck()
	-- Calculate the URL to get from.
	local s_EndpointURL = ApiUrls.release

	-- If development builds are enabled, get latest tags.
	if Registry.VERSION.UPDATE_CHANNEL == VersionType.DevBuild then
		s_EndpointURL = ApiUrls.dev
	elseif Registry.VERSION.UPDATE_CHANNEL == VersionType.Stable then
		s_EndpointURL = ApiUrls.stable
	end

	Net:GetHTTPAsync(s_EndpointURL, updateCheckCB)
end

return UpdateCheck()
