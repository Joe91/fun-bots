class('Weapon')

local m_Logger = Logger("Weapon", Debug.Shared.MODIFICATIONS)

function Weapon:__init(p_Name, p_Extension, p_Unlocks, p_Type, p_FullResource)
	self.name = p_Name
	self.extension = p_Extension
	self.unlocks = p_Unlocks
	self.type = p_Type
	self.fullResource = p_FullResource

	self.damage = 0
	self.endDamage = 0
	self.damageFalloffStartDistance = 0
	self.damageFalloffEndDistance = 0
	self.bulletSpeed= 0
	self.bulletDrop = 0
	self.fireCycle = 0
	self.pauseCycle = 0
	self.reload = 0
	self.delayed = false
	self.needvalues = true
end

function Weapon:learnStatsValues()
	local success = false
	local blueprint = nil
	local fireData = nil
	local aiData = nil
	local bulletData = nil

	blueprint, success = g_EbxEditUtils:GetWritableInstance(self:getResourcePath())

	if (not success) then
		m_Logger:Warning('No blueprint for: '..self.name)
		return
	end

	fireData, success = g_EbxEditUtils:GetWritableContainer(blueprint, 'Weapon.Object.WeaponFiring.PrimaryFire')
	if (not success) then
		m_Logger:Warning('No fireData for: '..self.name)
		return
	end

	aiData, success = g_EbxEditUtils:GetWritableContainer(blueprint, 'Weapon.Object.aiData')
	if (not success) then
		m_Logger:Warning('No aiData for: '..self.name)
		return
	end

	bulletData, success = g_EbxEditUtils:GetWritableContainer(fireData, 'shot.ProjectileData')
	if (not success) then
		m_Logger:Warning('No bulletData for: '..self.name)
		return
	end

	--m_Logger:Write(self.name..': '..tostring(aiData.name))

	-- stats depending on weapon-type
	local aiDataString = tostring(aiData.name)
	local fireDuration = 0
	local firePause = 0
	local delayedShot = false
	m_Logger:Write(self.name)
	if string.find(aiDataString, "_lmg_") ~= nil then
		m_Logger:Write("LMG")
		fireDuration = 1.5
		firePause = 0.5
		delayedShot = true
	elseif string.find(aiDataString, "_sni_") ~= nil then
		m_Logger:Write("sniper")
		fireDuration = 0.2
		firePause = 0.5
		delayedShot = true
	elseif string.find(aiDataString, "_snisemi_") ~= nil then
		m_Logger:Write("auto sniper")
		fireDuration = 0.2
		firePause = 0.2
		delayedShot = true
	elseif string.find(aiDataString, "_rif_") ~= nil then
		m_Logger:Write("rifle")
		fireDuration = 0.4
		firePause = 0.4
		delayedShot = false
	elseif string.find(aiDataString, "_shg_") ~= nil then
		m_Logger:Write("shotgun")
		fireDuration = 0.2
		firePause = 0.2
		delayedShot = false
	elseif string.find(aiDataString, "_smg_") ~= nil then
		m_Logger:Write("PDW")
		fireDuration = 0.3
		firePause = 0.2
		delayedShot = false
	elseif string.find(aiDataString, "_hg_") ~= nil or string.find(self.name, "MP443") ~= nil then -- "MP443 has no ai data"
		m_Logger:Write("pistol")
		fireDuration = 0.2
		firePause = 0.2
		delayedShot = false
	elseif string.find(aiDataString, "_kni_") ~= nil then
		m_Logger:Write("knife")
		fireDuration = 0.2
		firePause = 0.2
		delayedShot = false
	elseif string.find(aiDataString, "_at_") ~= nil then
		m_Logger:Write("Rocket")
		fireDuration = 0.2
		firePause = 0.4
		delayedShot = true
	elseif string.find(aiDataString, "_hgr_") ~= nil then
		m_Logger:Write("Grenade")
		fireDuration = 0.2
		firePause = 0.2
		delayedShot = false
	elseif self.name == "Repairtool" or self.name == "Claymore" or self.name == "C4" or self.name == "Tug" or self.name == "Beacon" then
		m_Logger:Write("other stuff")
		fireDuration = 0.2
		firePause = 0.2
		delayedShot = false
	else
		m_Logger:Warning("No data found for "..self.name..': '..tostring(aiData.name))
		fireDuration = 0.2
		firePause = 0.2
		delayedShot = false
	end

	self.damage = bulletData.startDamage
	self.endDamage = bulletData.endDamage
	self.damageFalloffStartDistance = bulletData.damageFalloffStartDistance
	self.damageFalloffEndDistance = bulletData.damageFalloffStartDistance
	self.bulletSpeed = fireData.shot.initialSpeed.z
	self.bulletDrop = (bulletData.gravity or 0) * -1
	self.fireCycle = fireDuration --aiData.minBurstCoolDownTime
	self.pauseCycle = firePause --(aiData.maxBurstCoolDownTime + aiData.minBurstCoolDownTime) / 2
	self.reload = math.floor(fireData.ammo.magazineCapacity * 0.2)
	self.delayed = delayedShot
	self.needvalues = false
end

function Weapon:getResourcePath(p_Unlock)
	local unl = ""
	if self.fullResource == nil then
		local ext = ""
		if p_Unlock ~= nil then

			if (string.starts(p_Unlock, 'Weapons/')) then
				return p_Unlock
			end

			unl = "_"..p_Unlock
		end
		if self.extension ~= '' then
			ext = self.extension.."_"
		end

		return "Weapons/"..ext..self.name.."/U_"..self.name..unl
	else
		if p_Unlock ~= nil then

			if (string.starts(p_Unlock, 'Weapons/')) then
				return p_Unlock
			end

			unl = "_"..p_Unlock
		end
		return self.fullResource..unl
	end
end

function Weapon:getAllAttachements()
	local attachmentList = {}
	for _, attachment in pairs(self.unlocks) do
		table.insert(attachmentList, self:getResourcePath(attachment))
	end
	return attachmentList
end

return Weapon
