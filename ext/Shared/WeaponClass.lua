---@class Weapon
---@overload fun(p_Name: string, p_Extension?: string, p_Unlocks: string[], p_Type: WeaponTypes, p_FullResource?: string):Weapon
Weapon = class('Weapon')

---@type Logger
local m_Logger = Logger("Weapon", Debug.Shared.MODIFICATIONS)

---@param p_Name string
---@param p_Extension string|'"XP1"'|'"XP2"'|nil
---@param p_Unlocks string[] @length 3 or 0
---@param p_Type WeaponTypes
---@param p_FullResource string|nil
function Weapon:__init(p_Name, p_Extension, p_Unlocks, p_Type, p_FullResource)
	self.name = p_Name
	self.extension = p_Extension
	self.unlocks = p_Unlocks
	self.type = p_Type
	self.fullResource = p_FullResource

	self.damage = 0.0
	self.endDamage = 0.0
	self.damageFalloffStartDistance = 0.0
	self.damageFalloffEndDistance = 0.0
	self.bulletSpeed = 0.0
	self.bulletDrop = 0.0
	self.fireCycle = 0.0
	self.pauseCycle = 0.0
	self.reload = 0
	self.delayed = false
	self.needvalues = true
end

function Weapon:learnStatsValues()
	local s_Success = false
	---@type SoldierWeaponBlueprint
	local s_Blueprint = nil
	---@type FiringFunctionData
	local s_FireData = nil
	---@type AIWeaponData
	local s_AiData = nil
	---@type BulletEntityData
	local s_BulletData = nil

	s_Blueprint, s_Success = g_EbxEditUtils:GetWritableInstance(self:getResourcePath())

	if not s_Success then
		m_Logger:Warning('No blueprint for: ' .. self.name)
		return
	end

	s_FireData, s_Success = g_EbxEditUtils:GetWritableContainer(s_Blueprint, 'Weapon.Object.WeaponFiring.PrimaryFire')

	if not s_Success then
		m_Logger:Warning('No fireData for: ' .. self.name)
		return
	end

	s_AiData, s_Success = g_EbxEditUtils:GetWritableContainer(s_Blueprint, 'Weapon.Object.aiData')

	if not s_Success then
		m_Logger:Warning('No aiData for: ' .. self.name)
		return
	end

	s_BulletData, s_Success = g_EbxEditUtils:GetWritableContainer(s_FireData, 'shot.ProjectileData')

	if not s_Success then
		m_Logger:Warning('No bulletData for: ' .. self.name)
		return
	end

	-- m_Logger:Write(self.name..': '..tostring(aiData.name))

	-- Stats depending on weapon-type.
	local s_AiDataString = tostring(s_AiData.name)
	local s_FireDuration = 0.0
	local s_FirePause = 0.0
	local s_DelayedShot = false
	m_Logger:Write(self.name)

	if string.find(s_AiDataString, "_lmg_") ~= nil then
		m_Logger:Write("LMG")
		s_FireDuration = 1.5
		s_FirePause = 0.3
		s_DelayedShot = true
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.LMG
		end
	elseif string.find(s_AiDataString, "_sni_") ~= nil then
		m_Logger:Write("sniper")
		s_FireDuration = 0.2
		s_FirePause = 0.3
		s_DelayedShot = true
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Sniper
		end
	elseif string.find(s_AiDataString, "_snisemi_") ~= nil then
		m_Logger:Write("auto sniper")
		s_FireDuration = 0.2
		s_FirePause = 0.3
		s_DelayedShot = true
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Sniper
		end
	elseif string.find(s_AiDataString, "_rif_") ~= nil then
		m_Logger:Write("rifle")
		s_FireDuration = 0.5
		s_FirePause = 0.3
		s_DelayedShot = false
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Assault
		end
	elseif string.find(s_AiDataString, "_shg_") ~= nil then
		m_Logger:Write("shotgun")
		s_FireDuration = 0.2
		s_FirePause = 0.2
		s_DelayedShot = false
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Shotgun
		end
	elseif string.find(s_AiDataString, "_smg_") ~= nil then
		m_Logger:Write("PDW")
		s_FireDuration = 0.3
		s_FirePause = 0.2
		s_DelayedShot = false
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.PDW
		end
	elseif string.find(s_AiDataString, "_hg_") ~= nil or string.find(self.name, "MP443") ~= nil then -- "MP443 has no AI data".
		m_Logger:Write("pistol")
		s_FireDuration = 0.1
		s_FirePause = 0.2
		s_DelayedShot = false
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Pistol
		end
	elseif string.find(s_AiDataString, "_kni_") ~= nil then
		m_Logger:Write("knife")
		s_FireDuration = 0.2
		s_FirePause = 0.2
		s_DelayedShot = false
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Knife
		end
	elseif string.find(s_AiDataString, "_at_") ~= nil then
		m_Logger:Write("Rocket")
		s_FireDuration = 0.2
		s_FirePause = 0.3
		s_DelayedShot = true
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Rocket
		end
	elseif string.find(s_AiDataString, "_hgr_") ~= nil then
		m_Logger:Write("Grenade")
		s_FireDuration = 0.2
		s_FirePause = 0.2
		s_DelayedShot = false
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.Grenade
		end
	elseif string.find(s_AiDataString, "_rgl_") ~= nil then
		m_Logger:Write("NadeLauncher")
		s_FireDuration = 0.2
		s_FirePause = 0.2
		s_DelayedShot = false
		if self.type == WeaponTypes.None then
			self.type = WeaponTypes.NadeLauncher
		end
	elseif self.type == WeaponTypes.Torch or self.type == WeaponTypes.Claymore or self.type == WeaponTypes.C4 or
		self.type == WeaponTypes.Tugs or self.type == WeaponTypes.Beacon or self.type == WeaponTypes.MissileAir or
		self.type == WeaponTypes.MissileLand then
		m_Logger:Write("other stuff")
		s_FireDuration = 0.2
		s_FirePause = 0.2
		s_DelayedShot = false
	else
		m_Logger:Warning("No data found for " .. self.name .. ': ' .. tostring(s_AiData.name))
		s_FireDuration = 0.2
		s_FirePause = 0.2
		s_DelayedShot = false
	end

	self.damage = s_BulletData.startDamage
	self.endDamage = s_BulletData.endDamage
	self.damageFalloffStartDistance = s_BulletData.damageFalloffStartDistance
	self.damageFalloffEndDistance = s_BulletData.damageFalloffStartDistance
	self.bulletSpeed = s_FireData.shot.initialSpeed.z
	self.bulletDrop = (s_BulletData.gravity or 0.0) * -1
	self.fireCycle = s_FireDuration -- aiData.minBurstCoolDownTime
	self.pauseCycle = s_FirePause -- (aiData.maxBurstCoolDownTime + aiData.minBurstCoolDownTime) / 2
	---@type integer
	self.reload = math.floor(s_FireData.ammo.magazineCapacity * 0.2)
	self.delayed = s_DelayedShot
	self.needvalues = false
end

---@param p_Unlock string|nil
---@return string
function Weapon:getResourcePath(p_Unlock)
	local s_Unl = ""

	if self.fullResource == nil then
		local s_Ext = ""

		if p_Unlock ~= nil then
			if string.starts(p_Unlock, 'Weapons/') then
				return p_Unlock
			end

			s_Unl = "_" .. p_Unlock
		end

		if self.extension ~= '' then
			s_Ext = self.extension .. "_"
		end

		return "Weapons/" .. s_Ext .. self.name .. "/U_" .. self.name .. s_Unl
	else
		if p_Unlock ~= nil then
			if string.starts(p_Unlock, 'Weapons/') then
				return p_Unlock
			end

			s_Unl = "_" .. p_Unlock
		end

		return self.fullResource .. s_Unl
	end
end

---@return string[]
function Weapon:getAllAttachments()
	---@type string[]
	local s_AttachmentList = {}

	for _, l_Attachment in pairs(self.unlocks) do
		table.insert(s_AttachmentList, self:getResourcePath(l_Attachment))
	end

	return s_AttachmentList
end

return Weapon
