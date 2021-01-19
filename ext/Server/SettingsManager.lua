class('SettingsManager');

function SettingsManager:__init()
	-- Create Tables
end

function SettingsManager:onLoad()
    -- get Values from Config.lua
    -- Check SQL if Config.lua has changed
    -- if changed, update SETTINGS SQL
    
    -- Load Settings SQL and update Config.lua
end

-- Singleton.
if g_Settings == nil then
	g_Settings = SettingsManager();
end

return g_Settings;