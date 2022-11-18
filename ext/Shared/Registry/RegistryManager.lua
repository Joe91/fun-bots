---@class RegistryManager
---@overload fun():RegistryManager
RegistryManager = class('RegistryManager')

require('__shared/Registry/Registry')

-- The registry manager contains utils and functions to fetch variables from the registry.
-- @note Do not add functions here, please use the RegistryUtil for that.
-- @author Firjen
-- @release V2.2.0 - 22/08/21
local MODULE_NAME = "Registry Manager"


function RegistryManager:__init()
	self._StartTime = SharedUtils:GetTimeMS()
	self._RegistryUtil = require('__shared/Registry/RegistryUtil')
	print("Enabled \"" .. MODULE_NAME .. "\" in " .. ReadableTimetamp(SharedUtils:GetTimeMS() - self._StartTime, TimeUnits.FIT, 1))
end

-- Get the Registry Util containing non-essential and non-core functions.
-- @return String - semantic version.
-- @author Firjen <https://github.com/Firjens>
function RegistryManager:GetUtil()
	return self._RegistryUtil
end

-- Check if a variable is currently in the registry, if not return the default value.
-- @param variable (object) - Type of variable you want to parse (E.g. Registry.BOT.SOMETHING).
-- @param default (object) - If the variable does not exist, what should be done as default.
-- @param indispensable (bool) - If the variable does not exist but is indispensable, should a broken installation warning be shown?
-- @return object - either the value of the variable or default.
-- @author Firjen <https://github.com/Firjens>
-- To-do: Add indispensable.
function RegistryManager:Get(variable, default, indispensable)
	if variable == nil then
		return default
	else
		return variable
	end
end

if g_RegistryManager == nil then
	g_RegistryManager = RegistryManager()
end

return g_RegistryManager
