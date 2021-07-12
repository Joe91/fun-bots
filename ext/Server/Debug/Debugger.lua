class('Debugger')

-- Basic debugger
-- Author: @Firjen on 12/07/21

-- The URL to the fun-bots report site
local DEBUG_REPORT_URL = "https://report.funbots.dev"

local DEBUG_ELIGIABLE_PATH = "/api/precheck"

local DEBUG_SUBMIT_PATH = "/api/submit"

-- Generate a bug report and send it to the fun-bots bug report server
function Debugger:GenerateReport(p_Player)
    -- Before submitting a report, check if we are eligable to generate a bug report.
    -- Uneligable servers are outdated servers or those who've made too many reports in the past hour.

    ChatManager:Yell("Generating a new bug report...",  10.0, p_Player)
    print("[DEBUG] " .. p_Player.name .. " is generating a new bug report.")

    if RCON:GetServerGuid() == nil then
        print("[DEBUG] Bug report failed: Server GUID is unknown or not set.")
        ChatManager:Yell("Failed to create bug report. Server GUID unknown.",  5.0, p_Player)
        do return end
    end

    -- Net:GetHTTPAsync(DEBUG_REPORT_URL .. DEBUG_ELIGIABLE_PATH .. "?uuid=" .. RCON:GetServerGuid(), Debugger:GenerateReportCallback())
    -- Net:GetHTTPAsync("https://report.funbots.dev/api/precheck?uuid=a5bb3716-1768-4367-b1ba-6b6ab0b7fbb2", GenerateReportCallback)

    local s_content = Net:GetHTTP("https://report.funbots.dev/api/precheck?uuid=a5bb3716-1768-4367-b1ba-6b6ab0b7fbb2")
    GenerateReportCallback(s_content)
end

function GenerateReportCallback(HttpRequest)

    -- @Todo: Broadcast a message to all users with permission

    print("[DEBUG] Code: " .. HttpRequest.status)
end

function Debugger:__init()
    local s_start = os.time(os.date("!*t"))

	print("Loaded debugger v2 in " .. os.time(os.date("!*t")) - s_start .. " ms")

    return true
end


return Debugger:__init()