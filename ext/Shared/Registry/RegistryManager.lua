class 'RegistryManager'

require('__shared/Registry/Registry')

-- The registry manager contains utils and functions to fetch variables from the registry.
-- @note Do not add functions here, please use the RegistryUtil for that.
-- @author Firjen
-- @release V2.2.0 - 22/08/21
local MODULE_NAME = "Registry Manager"


local m_registryUtil = nil

function RegistryManager:__init()
    local s_start = SharedUtils:GetTimeMS()
	
	m_registryUtil = require('__shared/Registry/RegistryUtil')

	print("Enabled \"" .. MODULE_NAME .. "\" in " .. ReadableTimetamp(SharedUtils:GetTimeMS() - s_start, TimeUnits.FIT, 1))
end

-- Get the Registry Util containing non-essential and non-core functions.
-- @return String - semantic version
-- @author Firjen <https://github.com/Firjens>
function RegistryManager:GetUtil()
	return m_registryUtil;
end

-- Check if a variable is currently in the registry, if not return the default value.
-- @param variable (object) - Type of variable you want to parse (Eg. Registry.BOT.SOMETHING)
-- @param default (object) - If the variable does not exist, what should be done as default
-- @param indispensable (bool) - If the variable does not exist but is indispensable, should a broken installation warning be shown?
-- @return object - either the value of the variable or default
-- @author Firjen <https://github.com/Firjens>
-- @todo Add indispensable
function RegistryManager:Get(variable, default, indispensable)
	if variable == nil then
		return default;
	end
	return default;
end

if g_Registry == nil then
	g_Registry = RegistryManager()
end

return g_Registry
