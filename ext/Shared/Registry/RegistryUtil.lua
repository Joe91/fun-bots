class 'RegistryUtil'

require('__shared/Registry/Registry')

-- Utils for the registry, only use it for important and essential functions.
-- @author Firjen
-- @release V2.2.0 - 22/08/21
local MODULE_NAME = "Registry Manager: Util"

function RegistryUtil:__init()
    local s_start = SharedUtils:GetTimeMS()

	print("Enabled \"" .. MODULE_NAME .. "\" in " .. ReadableTimetamp(SharedUtils:GetTimeMS() - s_start, TimeUnits.FIT, 1))
end

-- Get the version of the current build as in a semantic format.
-- @return String - semantic version
-- @author Firjen <https://github.com/Firjens>
function RegistryUtil:GetVersion()
	-- If there is no label, we return the MAJ.MIN.PATCH, otherwise we need
	-- to return the MAJ.MIN.PATCH-LABEL.
	if Registry.VERSION.VERSION_LABEL == nil then
		return Registry.VERSION.VERSION_MAJ .. "." .. Registry.VERSION.VERSION_MIN .. "." .. Registry.VERSION.VERSION_PATCH;
	end

	return Registry.VERSION.VERSION_MAJ .. "." .. Registry.VERSION.VERSION_MIN .. "." .. Registry.VERSION.VERSION_PATCH .. "-" .. Registry.VERSION.VERSION_LABEL;
end

if g_Registry == nil then
	g_Registry = RegistryUtil()
end

return g_Registry
