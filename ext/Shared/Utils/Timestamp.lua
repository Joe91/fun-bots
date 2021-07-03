-- Parse ISO 8601 timestamp (https://stackoverflow.com/questions/7911322/lua-iso-8601-datetime-parsing-pattern)
function parseOffset(str)
    local pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%-])(%d?%d?)%:?(%d?%d?)"
    local year, month, day, hour, minute, 
        seconds, offsetsign, offsethour, offsetmin = str:match(pattern)
    local timestamp = os.time{year = year, month = month, 
        day = day, hour = hour, min = minute, sec = seconds}
    local offset = 0
    if offsetsign ~= 'Z' then
      offset = tonumber(offsethour) * 60 + tonumber(offsetmin)
      if xoffset == "-" then offset = offset * -1 end
    end
    
    return timestamp + offset
end