---@class FunBotShared
---@overload fun():FunBotShared
FunBotShared = class('FunBotShared')

require('__shared/Debug')

-- Load utils.
require('__shared/Utils/Logger')
require('__shared/Utils/Timestamp')

-- Load constants.
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/WeaponTypes')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/BotMoveSpeeds')
require('__shared/Constants/SpawnModes')
require('__shared/Constants/SpawnMethods')
require('__shared/Constants/TeamSwitchModes')
require('__shared/WeaponList')
require('__shared/EbxEditUtils')
require('__shared/Registry/Registry')

---@type Language
local m_Language = require('__shared/Language')
---@type RegistryManager
local m_Registry = require('__shared/Registry/RegistryManager')

local m_Logger = Logger("FunBotShared", Debug.Shared.INFO)

function FunBotShared:__init()
	Events:Subscribe('Partition:Loaded', function(p_Partition)
		if p_Partition.name ~= "characters/soldiers/mpsoldier" then
			return
		end

		local s_Blueprint = SoldierBlueprint(p_Partition.primaryInstance)
		s_Blueprint:MakeWritable()

		local s_PropertyCastEntityData = PropertyCastEntityData(Guid("51A231A1-CCBA-3DEF-1E3B-A28F5AE67188"))
		s_PropertyCastEntityData.isPropertyConnectionTarget = Realm.Realm_ClientAndServer
		s_PropertyCastEntityData.indexInBlueprint = 167
		p_Partition:AddInstance(s_PropertyCastEntityData)

		for i = #s_Blueprint.propertyConnections, 1, -1 do
			if s_Blueprint.propertyConnections[i].targetFieldId == MathUtils:FNVHash("SprintMultiplier") then
				s_Blueprint.propertyConnections[i].source = s_PropertyCastEntityData
				s_Blueprint.propertyConnections[i].sourceFieldId = MathUtils:FNVHash("CastToFloat")
			end
		end

		local s_SoldierEntityData = SoldierEntityData(s_Blueprint.object)
		s_SoldierEntityData:MakeWritable()
		s_SoldierEntityData.components:add(s_PropertyCastEntityData)
	end)

	if Registry.COMMON.USE_LOAD_BUNDLE_BUGFIX then
		Events:Subscribe('Level:LoadResources', self, self.OnLevelLoadResources) -- Load Resources.
		Events:Subscribe('Level:RegisterEntityResources', self, self.OnLevelRegisterEntityResources) -- Register Resource.
		Hooks:Install('ResourceManager:LoadBundles', 5, self, self.OnResourceManagerLoadBundle)
	end
end

function FunBotShared:OnResourceManagerLoadBundle(p_HookCtx, p_Bundles, p_Compartment)
	if #p_Bundles == 1 and p_Bundles[1] == SharedUtils:GetLevelName() then
		m_Logger:Write('Injecting bundles...')
		p_Bundles = {
			'Levels/MP_011/MP_011',
			p_Bundles[1],
		}
		p_HookCtx:Pass(p_Bundles, p_Compartment)
	end
end

-- Function for Weapon Disappear Workaround.
function FunBotShared:OnLevelLoadResources()
	m_Logger:Write('Mounting superbundle...')
	ResourceManager:MountSuperBundle('Levels/MP_011/MP_011') -- Mount Superbundles.
end

function FunBotShared:OnLevelRegisterEntityResources(p_LevelData)
	m_Logger:Write('Registering instances...')
	local s_aRegistry = RegistryContainer(ResourceManager:SearchForInstanceByGuid(Guid('D62726FF-B0E2-3619-E95F-57CC5F00D58B'))) -- Assets from: Levels/MP_011/MP_011
	ResourceManager:AddRegistry(s_aRegistry, ResourceCompartment.ResourceCompartment_Game)
end

if g_FunBotShared == nil then
	---@type FunBotShared
	g_FunBotShared = FunBotShared()
end

return g_FunBotShared
