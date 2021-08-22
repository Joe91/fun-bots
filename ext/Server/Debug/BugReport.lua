class('BugReport')

-- Create a bug report using an in-game !bugreport command.
-- A bug report is required in order to create a new issue on the Github.
-- Abuse of the bug reporting system will lead into getting suspended from all fun-bots services, including support.
-- Do not change this without input from @Firjens (unless minor or text changes) to prevent unwanted behavior.
-- @author Firjen
-- @release V2.2.0 - 21/08/21

local MODULE_NAME = "Bug Report"

-- The version used for API related things. The moment new features are required for debugging the REST API end-point will know that this is a newer or older version.
local DEBUG_VERSION = 1

-- The URL to the official reporting website.
local DEBUG_REPORT_URL = "https://report.funbots.dev"

-- Pre-check path (checks if a report can be made)
local DEBUG_ELIGIABLE_PATH = "/api/precheck"

-- Path to submit a bug report
local DEBUG_SUBMIT_PATH = "/api/submit"

-- Timestamp of the latest report created by anyone with permission. Uesd for reporting cooldown
local DEBUG_LAST_REPORT = 0

-- Cooldown between bug reports in milliseconds. You are limited to a certain reports per 24 hours, and it's useless to create a new report when no major changes were made.
local DEBUG_REPORT_COOLDOWN = 60*1000*3 -- 3 minutes cooldown

-- This function is solely run by someone with permissions running the in-game !bugreport command.
-- Param: p_Player - User who initiated the request
function BugReport:GenerateReport(p_Player)
    -- Check if there is a current cooldown active, if so, return and tell the user.
    if DEBUG_LAST_REPORT ~= nil and (DEBUG_LAST_REPORT - SharedUtils:GetTimeMS() > 0) then 
        ChatManager:Yell("A report was recently made, please wait " .. ReadableTimetamp((DEBUG_LAST_REPORT-SharedUtils:GetTimeMS()), TimeUnits.FIT, 1) .. " before creating a new report", 5.0, p_Player)
        do return end
    end

    -- Set the current cooldown. There is no point in spamming it if the servers are down.
    DEBUG_LAST_REPORT = SharedUtils:GetTimeMS() + DEBUG_REPORT_COOLDOWN

    -- Check that the server GUID is correctly set.
    if RCON:GetServerGuid() == nil then
        ChatManager:Yell("Failed to create bug report. Server GUID is null", 5.0, p_Player)
        print("[Debugger: Report] Failure to create a bug report. Server GUID is null.");
        print("[Debugger: Report] This is not a fun-bots bug, please contact Venice Unleashed.");
        do return end
    end

    -- Notify the user that we are creating a new bug report 
    print("[Debugger: Report] " .. p_Player.name .. " is creating a new bug report.");
    ChatManager:Yell("Creating a new bug report...", 5.0, p_Player)

    -- Contact the eligiable end point to see if we are allowed to even make a bug report. We may be rate limited? We may be suspended because we abused it?
    -- No need to send the whole config to one end point as this can use precious server resources and networking.
    local s_CheckURL = DEBUG_REPORT_URL .. DEBUG_ELIGIABLE_PATH .. "?uuid=" .. RCON:GetServerGuid():ToString("D");
    Net:GetHTTPAsync(s_CheckURL, function(p_HttpResponse)
        -- Check if the server has answered, even upon an error a JSON payload is returned with a message, if this isn't the case it's most likely the server that failed to contact it.
        if p_HttpResponse == nil then
            ChatManager:Yell("Failed to create bug report. Unable to contact report server.", 5.0, p_Player)
            print("[Debugger: Report] Failure to precheck for a bug report. Unable to contact report server. Please check your internet connection and try again later.");
            do return end
        end

		local s_Json = json.decode(p_HttpResponse.body)

        -- Rate limiting, a limited amount of reports are allowed to be made within 24 hours.
        if p_HttpResponse.status == 429 then 
            ChatManager:Yell("Too many bug reports created, try again in " .. ReadableTimetamp(s_Json.try_again, TimeUnits.FIT, 1), 5.0, p_Player)
            print("[Debugger: Report] Failure to precheck for a bug report. Too many bug reports created, try again in " .. ReadableTimetamp(s_Json.try_again, TimeUnits.FIT, 0));
            do return end
        end

        -- Other than rate limiting or OK means that the server has some kind of issue.
        if p_HttpResponse.status ~= 200 then
            ChatManager:Yell("Failed to create bug report. Returned HTTP code " .. p_HttpResponse.status, 5.0, p_Player)
            print("[Debugger: Report] Failure to precheck for a bug report. Returned HTTP code " .. p_HttpResponse.status);
            do return end
        end

        print("[Debugger: Report] You can make " .. s_Json.reports_left .. " more bug-reports.");

        -- Report can be created as server returned error 200.
        local s_SubmitURL = DEBUG_REPORT_URL .. DEBUG_SUBMIT_PATH .. "?uuid=" .. RCON:GetServerGuid():ToString("D");

        -- This should not be modified as the server checks everything, parses it and validates it.
        -- When something misses or gets added the server will reject the request.
        local s_ReportData = {
            config = Config,
            registry = Registry,
            version = RegistryManager:GetUtil():GetVersion(),
            author_name = p_Player.name,
            author_guid = p_Player.guid,
            map_id = SharedUtils:GetLevelName(),
            gamemode_id = SharedUtils:GetCurrentGameMode()
        }

        -- Post the bug report information to the server
        Net:PostHTTPAsync(s_SubmitURL, json.encode(s_ReportData), function(p_HttpResponse)
            if p_HttpResponse == nil then
                ChatManager:Yell("Failed to create bug report. Unable to contact report server.", 5.0, p_Player)
                print("[Debugger: Report] Failure to post for a bug report. Unable to contact report server. Please check your internet connection and try again later.");
                do return end
            end

            local s_Json = json.decode(p_HttpResponse.body)

            -- 403 forbidden contains a message why it's forbidden. Show to user.
            if p_HttpResponse.status == 403 then
                ChatManager:Yell("Failed to create bug report. Server returned: " .. s_Json.message, 5.0, p_Player)
                print("[Debugger: Report] Failure to post a bug report. Returned HTTP code " .. p_HttpResponse.status .. " with message: " .. s_Json.message);
                do return end
            end

            -- If token fetch token and return token to user
            if p_HttpResponse.status == 200 and s_Json.token ~= nil then
                ChatManager:Yell("Success! Your report token is: " .. s_Json.token, 45.0, p_Player)
                ChatManager:SendMessage("Bug report created: report.funbots.dev/" .. s_Json.token, p_Player)
                print("[Debugger: Report] A new bug report is created and can be viewed on: report.funbots.dev/" .. s_Json.token);
                do return end
            end

            ChatManager:Yell("Failed to create bug report. Returned HTTP code " .. p_HttpResponse.status, 5.0, p_Player)
            print("[Debugger: Report] Failure to post a bug report. Returned HTTP code " .. p_HttpResponse.status .. " with message: " .. s_Json.message);
        end)
    end)
 end

function BugReport:__init()
    local s_start = SharedUtils:GetTimeMS()

	print("[INIT] (Server) Enabled " .. MODULE_NAME .. " in " .. ReadableTimetamp(SharedUtils:GetTimeMS() - s_start, TimeUnits.FIT, 1))
end

return BugReport:__init()