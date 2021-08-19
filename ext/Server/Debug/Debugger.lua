class('Debugger')

-- Create a bug report using an in-game !bugreport command.
-- A bug report is required in order to create a new issue on the Github.
-- Author: @Firjen on 12/07/21
-- Debugger version: 1

-- The URL to the fun-bots report site
local DEBUG_REPORT_URL = "https://report.funbots.dev"

-- Pre-check path (checks if a report can be made)
local DEBUG_ELIGIABLE_PATH = "/api/precheck"

-- Path to submit a bug report
local DEBUG_SUBMIT_PATH = "/api/submit"

-- Timestamp of the latest report
local DEBUG_LAST_REPORT = 0

-- Cooldown between bug reports in milliesconds
local DEBUG_REPORT_COOLDOWN = 60*1000*2.5 -- 2.5 minutes cooldown

-- Ran with the !bugreport command.
-- p_Player - User who initiated the request
function Debugger:GenerateReport(p_Player)
    -- Check cooldown
    if DEBUG_LAST_REPORT ~= nil and (DEBUG_LAST_REPORT - SharedUtils:GetTimeMS() > 0) then 
        ChatManager:Yell("A report was recently made, please wait " .. ReadableTimetamp((DEBUG_LAST_REPORT-SharedUtils:GetTimeMS()), TimeUnits.FIT, 1) .. " before creating a new report", 5.0, p_Player)
        do return end
    end

    -- Set the cooldown
    DEBUG_LAST_REPORT = SharedUtils:GetTimeMS() + DEBUG_REPORT_COOLDOWN

    -- Check that the server GUID is set (required)
    if RCON:GetServerGuid() == nil then
        ChatManager:Yell("Failed to create bug report. Server GUID is null", 5.0, p_Player)
        print("[Debugger: Report] Failure to create a bug report. Server GUID is null.");
        print("[Debugger: Report] This is not a fun-bots bug, please contact Venice Unleashed.");
        do return end
    end

    -- Create a pre-check check.
    print("[Debugger: Report] " .. p_Player.name .. " is creating a new bug report.");
    ChatManager:Yell("Creating a new bug report...", 5.0, p_Player) -- Yell gets overwritten by a newer yell if available.

    local s_CheckURL = DEBUG_REPORT_URL .. DEBUG_ELIGIABLE_PATH .. "?uuid=" .. RCON:GetServerGuid():ToString("D");
    Net:GetHTTPAsync(s_CheckURL, function(p_HttpResponse)
        if p_HttpResponse == nil then
            ChatManager:Yell("Failed to create bug report. Unable to contact report server.", 5.0, p_Player)
            print("[Debugger: Report] Failure to precheck for a bug report. Unable to contact report server. Please check your internet connection and try again later.");
            do return end
        end

		local s_Json = json.decode(p_HttpResponse.body)

        -- Too many requests, try again later
        if p_HttpResponse.status == 429 then 
            ChatManager:Yell("Too many bug reports created, try again in " .. ReadableTimetamp(s_Json.try_again, TimeUnits.FIT, 1), 5.0, p_Player)
            print("[Debugger: Report] Failure to precheck for a bug report. Too many bug reports created, try again in " .. ReadableTimetamp(s_Json.try_again, TimeUnits.FIT, 0));
            do return end
        end

        -- Not cooldown and not 200
        if p_HttpResponse.status ~= 200 then
            ChatManager:Yell("Failed to create bug report. Returned HTTP code " .. p_HttpResponse.status, 5.0, p_Player)
            print("[Debugger: Report] Failure to precheck for a bug report. Returned HTTP code " .. p_HttpResponse.status);
            do return end
        end


        -- Report can be created as server returned error 200.
        local s_SubmitURL = DEBUG_REPORT_URL .. DEBUG_SUBMIT_PATH .. "?uuid=" .. RCON:GetServerGuid():ToString("D");

        -- Parse JSON data to POST
        local s_ReportData = {
            config = Config
        }

        --[[
            
            author_name = p_Player.name,
            author_guid = p_Player.guid,
            map_id = SharedUtils:GetLevelName(),
            gamemode_id = SharedUtils:GetCurrentGameMode(),
            tps = SharedUtils:GetTickrate(),
            players_online = PlayerManager.GetPlayerCount()
        ]]

        Net:PostHTTPAsync(s_SubmitURL, json.encode(s_ReportData), function(p_HttpResponse)
            if p_HttpResponse == nil then
                ChatManager:Yell("Failed to create bug report. Unable to contact report server.", 5.0, p_Player)
                print("[Debugger: Report] Failure to post for a bug report. Unable to contact report server. Please check your internet connection and try again later.");
                do return end
            end

            -- Not cooldown and not 200
            if p_HttpResponse.status ~= 200 then
                ChatManager:Yell("Failed to create bug report. Returned HTTP code " .. p_HttpResponse.status, 5.0, p_Player)
                print("[Debugger: Report] Failure to post a bug report. Returned HTTP code " .. p_HttpResponse.status);
                do return end
            end

            print(p_HttpResponse.status)
            print(p_HttpResponse.body)
        end)

    end)
 end

function Debugger:__init()
    local s_start = SharedUtils:GetTimeMS()

	print("Loaded debugger v2 in " .. ReadableTimetamp(os.time(os.date("!*t")) - s_start, TimeUnits.FIT, 1) .. " ms")

    return true
end

return Debugger:__init()