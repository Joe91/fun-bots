---@class FunBotShared
---@overload fun():FunBotShared
FunBotShared = class('FunBotShared')

require('__shared/Debug')

-- Load utils
require('__shared/Utils/Logger')
require('__shared/Utils/Timestamp')

-- Load constants
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
	if Registry.COMMON.USE_LOAD_BUNDLE_BUGFIX then
		Events:Subscribe('Level:LoadResources', self, self.OnLevelLoadResources) -- Load Resources
		Events:Subscribe('Level:RegisterEntityResources', self, self.OnLevelRegisterEntityResources) -- Register Resource
		Hooks:Install('ResourceManager:LoadBundles', 100, self, self.OnResourceManagerLoadBundle) -- Inject Bundles
	end

	-- TIMEOUT -Settings

	ResourceManager:RegisterInstanceLoadHandler(Guid('C4DCACFF-ED8F-BC87-F647-0BC8ACE0D9B4'),
		Guid('B479A8FA-67FF-8825-9421-B31DE95B551A'), self, self._modifyClientTimeoutSettings)
	ResourceManager:RegisterInstanceLoadHandler(Guid('C4DCACFF-ED8F-BC87-F647-0BC8ACE0D9B4'),
		Guid('818334B3-CEA6-FC3F-B524-4A0FED28CA35'), self, self._modifyServerTimeoutSettings)

	Hooks:Install('ResourceManager:LoadBundles', 1, function(p_HookCtx, p_Bundles, p_Compartment)
		print(p_Compartment)
		if p_Compartment == 3 then
			p_HookCtx:Call()
			local s_ServerSettings = ResourceManager:GetSettings("ServerSettings")

			if s_ServerSettings then
				self:_modifyServerTimeoutSettings(s_ServerSettings)
			end

			local s_ClientSettings = ResourceManager:GetSettings("ClientSettings")

			if s_ClientSettings then
				self:_modifyClientTimeoutSettings(s_ClientSettings)
			end

			local s_NetworkSettings = ResourceManager:GetSettings("NetworkSettings")

			if s_NetworkSettings then
				s_NetworkSettings = NetworkSettings(s_NetworkSettings)
				s_NetworkSettings:MakeWritable()
				s_NetworkSettings.connectTimeout = 172800.0
			end
		end
	end)
end

-- function for Weapon Dissaper Workaround
function FunBotShared:OnLevelLoadResources()
	m_Logger:Write('Mounting superbundle...')
	ResourceManager:MountSuperBundle('Levels/MP_011/MP_011') -- Mount Superbundles
end

function FunBotShared:OnLevelRegisterEntityResources(p_LevelData)
	m_Logger:Write('Registering instances...')
	local s_aRegistry = RegistryContainer(ResourceManager:SearchForInstanceByGuid(Guid('D62726FF-B0E2-3619-E95F-57CC5F00D58B'))) -- Assets from: Levels/MP_011/MP_011
	ResourceManager:AddRegistry(s_aRegistry, ResourceCompartment.ResourceCompartment_Game)
end

function FunBotShared:OnResourceManagerLoadBundle(hook, bundles, compartment)
	if #bundles == 1 and bundles[1] == SharedUtils:GetLevelName() then
		m_Logger:Write('Injecting bundles...')
		bundles = {
			'Levels/MP_011/MP_011',
			bundles[1],
		}
		hook:Pass(bundles, compartment)
	end
end

function FunBotShared:_modifyClientTimeoutSettings(p_Instance)
	p_Instance = ClientSettings(p_Instance)
	p_Instance:MakeWritable()
	p_Instance.ingameTimeout = 172800.0
end

function FunBotShared:_modifyServerTimeoutSettings(p_Instance)
	p_Instance = ServerSettings(p_Instance)
	p_Instance:MakeWritable()
	p_Instance.ingameTimeout = 172800.0
end

return FunBotShared()
