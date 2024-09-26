---@class FunBotShared
---@overload fun():FunBotShared
FunBotShared = class('FunBotShared')

require('__shared/Registry/Registry')

require('__shared/Debug')
-- Load utils.
require('__shared/Utils/Logger')

-- Load constants.
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/RaycastData')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/WeaponTypes')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/BotMoveSpeeds')
require('__shared/Constants/SpawnModes')
require('__shared/Constants/SpawnMethods')
require('__shared/Constants/TeamSwitchModes')
require('__shared/WeaponList')
require('__shared/EbxEditUtils')


---@type Language
local m_Language = require('__shared/Language')

local m_Logger = Logger("FunBotShared", Debug.Shared.INFO)

function FunBotShared:__init()
	if Registry.COMMON.USE_LOAD_BUNDLE_BUGFIX then
		Events:Subscribe('Level:LoadResources', self, self.OnLevelLoadResources)               -- Load Resources.
		Events:Subscribe('Level:RegisterEntityResources', self, self.OnLevelRegisterEntityResources) -- Register Resource.
		Hooks:Install('ResourceManager:LoadBundles', 5, self, self.OnResourceManagerLoadBundle)
	end
end

function FunBotShared:OnResourceManagerLoadBundle(p_HookCtx, p_Bundles, p_Compartment)
	local s_LevelName = SharedUtils:GetLevelName()
	if s_LevelName == nil or string.find(s_LevelName:lower(), "/sp_") or string.find(s_LevelName:lower(), "/coop_") then
		return
	end
	if #p_Bundles == 1 and p_Bundles[1] == SharedUtils:GetLevelName() then
		m_Logger:Write('Injecting bundles...')
		if (SharedUtils:GetLevelName() == 'Levels/MP_Subway/MP_Subway') or (SharedUtils:GetLevelName() == 'Levels/MP_011/MP_011') then
			p_Bundles = {
				'Levels/MP_003/MP_003',
				p_Bundles[1],
			}
		else
			p_Bundles = {
				'Levels/MP_011/MP_011',
				p_Bundles[1],
			}
		end
		p_HookCtx:Pass(p_Bundles, p_Compartment)
	end
end

-- Function for Weapon Disappear Workaround.
function FunBotShared:OnLevelLoadResources()
	local s_LevelName = SharedUtils:GetLevelName()
	if s_LevelName == nil or string.find(s_LevelName:lower(), "/sp_") or string.find(s_LevelName:lower(), "/coop_") then
		return
	end

	m_Logger:Write('Mounting superbundle...')
	if (SharedUtils:GetLevelName() == 'Levels/MP_Subway/MP_Subway') or (SharedUtils:GetLevelName() == 'Levels/MP_011/MP_011') then
		ResourceManager:MountSuperBundle('Levels/MP_003/MP_003')
	else
		ResourceManager:MountSuperBundle('Levels/MP_011/MP_011') -- Mount Superbundles.
	end
end

function FunBotShared:OnLevelRegisterEntityResources(p_LevelData)
	local s_LevelName = SharedUtils:GetLevelName()
	if s_LevelName == nil or string.find(s_LevelName:lower(), "/sp_") or string.find(s_LevelName:lower(), "/coop_") then
		return
	end

	m_Logger:Write('Registering instances...')
	if (SharedUtils:GetLevelName() == 'Levels/MP_Subway/MP_Subway') or (SharedUtils:GetLevelName() == 'Levels/MP_011/MP_011') then
		local s_aRegistry = RegistryContainer(ResourceManager:SearchForInstanceByGuid(Guid('0B40AC87-7AFF-EDDE-949A-FCBF42CF7126'))) -- Assets from: Levels/MP_003/MP_003
		ResourceManager:AddRegistry(s_aRegistry, ResourceCompartment.ResourceCompartment_Game)
	else
		local s_aRegistry = RegistryContainer(ResourceManager:SearchForInstanceByGuid(Guid('D62726FF-B0E2-3619-E95F-57CC5F00D58B'))) -- Assets from: Levels/MP_011/MP_011
		ResourceManager:AddRegistry(s_aRegistry, ResourceCompartment.ResourceCompartment_Game)
	end
end

if g_FunBotShared == nil then
	---@type FunBotShared
	g_FunBotShared = FunBotShared()
end

return g_FunBotShared
