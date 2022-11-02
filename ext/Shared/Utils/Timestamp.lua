-- Parse ISO 8601 timestamp (https://stackoverflow.com/questions/7911322/lua-iso-8601-datetime-parsing-pattern). 
-- @author Firjen <https://github.com/Firjens> 
function ParseOffset(p_String)
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

-- Enums for different time units used to convert milliseconds into a readable format to the clients. 
-- @author Firjen <https://github.com/Firjens> 
---@class TimeUnits
TimeUnits = {
	FIT = 99,
	DAYS = 4,
	HOURS = 3,
	MINUTES = 2,
	SECONDS = 1,
}

-- Trim a large number to a smaller number with specified degree (numbers behind the comma). 
-- @param degree (integer) - Total numbers. 
-- @param number (integer) - number to trim. 
-- @author Firjen <https://github.com/Firjens> 
-- @return String - [Double-like] (E.g. 2.1, 1.6, 0.5). 
function Trim(degree, number)
	return string.format("%.1f", number)
end

-- Convert to a readable format (e.g. 5 minutes, 12 seconds, etc.). 
-- @author Firjen <https://github.com/Firjens> 
-- @return String - Readable time format (E.g. Permanent, 12 Seconds, 5 Minutes). 
function ReadableTimetamp(p_Time, p_TimeUnit, p_Trim)
	-- Anything less than 0 (E.g. time is -1), it's considered permanent. 
	if p_Time < 0 then
		return "Permanent"
	end

	-- If it fits, pick the best time unit. 
	if p_TimeUnit == TimeUnits.FIT then
		if p_Time < 60000 then
			p_TimeUnit = TimeUnits.SECONDS
		elseif p_Time < 3600000 then
			p_TimeUnit = TimeUnits.MINUTES
		elseif p_Time < 86400000 then
			p_TimeUnit = TimeUnits.HOURS
		else
			p_TimeUnit = TimeUnits.DAYS
		end
	end

	if p_TimeUnit == TimeUnits.DAYS then
		return Trim(p_Trim, p_Time / 8.64E7) .. " Days"
	elseif p_TimeUnit == TimeUnits.HOURS then
		return Trim(p_Trim, p_Time / 3600000) .. " Hours"
	elseif p_TimeUnit == TimeUnits.MINUTES then
		return Trim(p_Trim, p_Time / 60000.) .. " Minutes"
	elseif p_TimeUnit == TimeUnits.SECONDS then
		return Trim(p_Trim, p_Time / 1000) .. " Seconds"

	else
		return Trim(p_Trim, p_Time) .. " Milliseconds"
	end
end
