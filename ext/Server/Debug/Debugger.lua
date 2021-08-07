class('Debugger')

-- Basic debugger
-- Author: @Firjen on 12/07/21

-- The URL to the fun-bots report site
local DEBUG_REPORT_URL = "https://report.funbots.dev"

local DEBUG_ELIGIABLE_PATH = "/api/precheck"

local DEBUG_SUBMIT_PATH = "/api/submit"

local pp = nil

local s_CheckURL = "https://report.funbots.dev/api/precheck?uuid=a5bb3716-1768-4367-b1ba-6b6ab0b7fbb2"

function TestGetHTTPAsync()
    Net:GetHTTPAsync(s_CheckURL, function(p_HttpResponse)
        if p_HttpResponse == nil then
            print("[TestGetHTTPAsync] p_HttpResponse == nil")
        end

        if p_HttpResponse.status ~= 200 then
            print("[TestGetHTTPAsync] p_HttpResponse.status ~= 200")
        end

        local s_Json = json.decode(p_HttpResponse.body)

        print("[TestGetHTTPAsync]")
        print(s_Json)
    end)
end

-- Generate a bug report and send it to the fun-bots bug report server
function Debugger:GenerateReport(p_Player)
   TestGetHTTPAsync();
end

function GenerateReportCallback(httpRequest)
    -- @Todo: Figure out how to pass this variable with GenerateReportCallback
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
    local postData = {config = json.encode(Config)}
    print(postData)

    local s_String = "config=" .. json.encode(Config) .. "&version=2.2.0" .. "author=" .. p_Player.name

    -- Send post data
    Net:PostHTTPAsync(DEBUG_REPORT_URL .. DEBUG_REPORT_URL .. "?uuid=" .. RCON:GetServerGuid(), json.encode(Config), CreateReportCallback)
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