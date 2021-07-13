class('Debugger')

-- Basic debugger
-- Author: @Firjen on 12/07/21

-- The URL to the fun-bots report site
local DEBUG_REPORT_URL = "https://report.funbots.dev"

local DEBUG_ELIGIABLE_PATH = "/api/precheck"

local DEBUG_SUBMIT_PATH = "/api/submit"

local pp = nil

-- Generate a bug report and send it to the fun-bots bug report server
function Debugger:GenerateReport(p_Player)
    -- Before submitting a report, check if we are eligable to generate a bug report.
    -- Uneligable servers are outdated servers or those who've made too many reports in the past hour.

    ChatManager:Yell("Generating a new bug report...",  15.0, p_Player)
    print("[DEBUG] " .. p_Player.name .. " is generating a new bug report.")

    if RCON:GetServerGuid() == nil then
        print("[DEBUG] Bug report failed: Server GUID is unknown or not set.")
        ChatManager:Yell("Failed to create bug report. Server GUID unknown",  4.0, p_Player)
        do return end
    end

    -- Net:GetHTTPAsync(DEBUG_REPORT_URL .. DEBUG_ELIGIABLE_PATH .. "?uuid=" .. RCON:GetServerGuid(), Debugger:GenerateReportCallback())
    pp = p_Player
    Net:GetHTTPAsync("https://report.funbots.dev/api/precheck?uuid=a5bb3716-1768-4367-b1ba-6b6ab0b7fbb2", GenerateReportCallback)
end

function GenerateReportCallback(httpRequest)
    local p_Player = pp

    if httpRequest == nil then
        print("[DEBUG] Bug report failed: HTTP request failure")
        ChatManager:Yell("Failed to create bug report. HTTP request failure",  4.0, pp)
        do return end
    end

    -- Check code returned
    if httpRequest.status == 429 then 
        print("[DEBUG] Bug report failed: too many bug reports created. You can only create 2 reports per 24 hr.")
        ChatManager:Yell("Failed to create bug report. Report limit reached (max 2 per 24hr)", 4.0, p_Player)
        do return end
    elseif httpRequest.status ~= 429 and httpRequest.status ~= 200  then
        print("[DEBUG] Bug report failed: Report server returned error " .. httpRequest.status)
        ChatManager:Yell("Failed to create bug report. HTTP code " .. httpRequest.status, 4.0, p_Player)
        do return end
    end

    -- If code 200, we can ask the server to create our report.
    Debugger:CreateReport(p_Player)
end

-- Generate the report
function Debugger:CreateReport(p_Player)
    -- Generate POST data
    local postData = {}

    -- Add config to POST
    postData.insert("config", json.encode(Config))

    -- Send post data
    Net:PostHTTPAsync("https://report.funbots.dev/api/submit?uuid=a5bb3716-1768-4367-b1ba-6b6ab0b7fbb2", postData.tostring, CreateReportCallback)
end

function CreateReportCallback(httpRequest)
    if httpRequest == nil then
        print("[DEBUG] Bug report failed: HTTP request failure")
        ChatManager:Yell("Failed to create bug report. HTTP request failure 2",  4.0, pp)
        do return end
    end
    
    ChatManager:Yell("Bug report created?",  4.0, pp)
end

function Debugger:__init()
    local s_start = os.time(os.date("!*t"))

	print("Loaded debugger v2 in " .. os.time(os.date("!*t")) - s_start .. " ms")

    return true
end


return Debugger:__init()