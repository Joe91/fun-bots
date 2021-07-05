-- Parse ISO 8601 timestamp (https://stackoverflow.com/questions/7911322/lua-iso-8601-datetime-parsing-pattern)
function ParseOffset(p_String)
	local s_Pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%-])(%d?%d?)%:?(%d?%d?)"
	local s_Year, s_Month, s_Day, s_Hour, s_Minute,
		s_Seconds, s_Offsetsign, s_Offsethour, s_Offsetmin = p_String:match(s_Pattern)
	local s_Timestamp = os.time{year = s_Year, month = s_Month,
		day = s_Day, hour = s_Hour, min = s_Minute, sec = s_Seconds}
	local s_Offset = 0
	if s_Offsetsign ~= 'Z' then
		s_Offset = tonumber(s_Offsethour) * 60 + tonumber(s_Offsetmin)
		if s_Offset == "-" then s_Offset = s_Offset * -1 end
		end

	return s_Timestamp + s_Offset
end