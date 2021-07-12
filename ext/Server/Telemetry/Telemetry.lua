class('Telemetry')

require('__shared/Config')

-- Telemetry sends statistics and server information to fun-bots telemetry servers
-- Author: @Firjen on 12/07/21
-- Telemetry version: v1

-- Is telemetry allowed on this build?
local TELEMETRY_ALLOWED = false

-- Is telemetry enabled?
local TELEMETRY_ENABLED = false

-- URL to the telemetry server
local TELEMETRY_URL = "https://telemetry.funbots.dev"

-- Telemetry API version
local TELEMETRY_VERSION = "v1"

-- URL to the telemetry configuration location
local TELEMETRY_EXTERNAL_CONFIGURATION = TELEMETRY_URL .. "/" .. TELEMETRY_VERSION .. "/".. "config"

-- A global cache for telemetry data
local TelemetryCache = {}

-- Telemetry hot cache
local TelemetryHotCache = {}

function Telemetry:__init()
    if not TELEMETRY_ALLOWED then
        print("[TELEMETRY] Telemetry is not allowed on this build.")
        do return end
    end

	print("[TELEMETRY] Loading telemetry...")
    local s_start = os.time(os.date("!*t"))

    ReachExternalConfiguration()

	print("[TELEMETRY] Loaded -> " .. os.time(os.date("!*t")) - s_start .. " ms")

    return true
end

function ReachExternalConfiguration()
    print(TELEMETRY_EXTERNAL_CONFIGURATION)

    -- Check the external configuration
    local s_externalConfigHTTP = Net:GetHTTP(TELEMETRY_EXTERNAL_CONFIGURATION)
    if s_externalConfigHTTP == nil then
        print("[TELEMETRY] Failed to reach the server.")
        TELEMETRY_ENABLED = false
        return false
    end

    -- Read the incoming JSON
    local s_externalConfigJSON = json.decode(s_externalConfigHTTP.body)
    if not s_externalConfigJSON then
        print("[TELEMETRY] Failed to decode config JSON")
        TELEMETRY_ENABLED = false
        return false
    end

    print("[TELEMETRY] Found: " .. s_externalConfigHTTP.body)

    TelemetryCache.insert(externalConf, s_externalConfigJSON)
    TELEMETRY_ENABLED = true
    return true
end



-- Send advanced telemetry
function SendAdvanced()
    -- Check if advanced telemetry is enabled

end

-- Initiate telemetry
return Telemetry:__init()