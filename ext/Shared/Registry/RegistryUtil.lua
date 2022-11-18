---@class RegistryUtil
---@overload fun():RegistryUtil
RegistryUtil = class('RegistryUtil')

require('__shared/Registry/Registry')

-- Utils for the registry, only use it for important and essential functions.
-- @author Firjen
-- @release V2.2.0 - 22/08/21
local MODULE_NAME = "Registry Manager: Util"

function RegistryUtil:__init()
	self._StartTime = SharedUtils:GetTimeMS()
	print("Enabled \"" .. MODULE_NAME .. "\" in " .. ReadableTimetamp(SharedUtils:GetTimeMS() - self._StartTime, TimeUnits.FIT, 1))
end

-- Get the version of the current build as in a semantic format.
-- @return String - semantic version.
-- @author Firjen <https://github.com/Firjens>
function RegistryUtil:GetVersion()
	-- If there is no label, we return the MAJ.MIN.PATCH, otherwise we need to return the MAJ.MIN.PATCH-LABEL.
	if Registry.VERSION.VERSION_LABEL == nil or Registry.VERSION.VERSION_LABEL == "" or Registry.VERSION.VERSION_TYPE ==
		VersionType.Release then
		return "V" .. Registry.VERSION.VERSION_MAJ .. "." .. Registry.VERSION.VERSION_MIN .. "." .. Registry.VERSION.VERSION_PATCH;
	else
		MAJ_MIN_PATCH_LABEL = Registry.VERSION.VERSION_MAJ .. "." .. Registry.VERSION.VERSION_MIN .. "." .. Registry.VERSION.VERSION_PATCH .. "-" .. Registry.VERSION.VERSION_LABEL
		if Registry.VERSION.VERSION_TYPE == VersionType.DevBuild then
			return "v" .. MAJ_MIN_PATCH_LABEL
		elseif Registry.VERSION.VERSION_TYPE == VersionType.Stable then
			return "V" .. MAJ_MIN_PATCH_LABEL
		end
	end
end

if g_RegistryUtil == nil then
	---@type RegistryUtil
	g_RegistryUtil = RegistryUtil()
end

return g_RegistryUtil
