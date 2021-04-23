class('Weapon')

function Weapon:__init(p_Name, p_Extension, p_Unlocks, p_Type, p_FullResource)
	self.name		= p_Name
	self.extension	= p_Extension
	self.unlocks 	= p_Unlocks
	self.type		= p_Type
	self.fullResource = p_FullResource

	self.damage		= 0
    self.endDamage = 0
    self.damageFalloffStartDistance	= 0
    self.damageFalloffEndDistance 	= 0
	self.bulletSpeed= 0
	self.bulletDrop = 0
	self.fireCycle	= 0
	self.pauseCycle	= 0
	self.reload		= 0
	self.delayed	= false
	self.needvalues	= true
end

function Weapon:learnStatsValues()
	local success = false
	local blueprint = nil
	local fireData = nil
	local aiData = nil
	local bulletData = nil

	blueprint, success = g_EbxEditUtils:GetWritableInstance(self:getResourcePath())

	if (not success) then
		if Debug.Shared.MODIFICATIONS then
			print('No blueprint for: '..self.name)
		end
		return
	end

	fireData, success = g_EbxEditUtils:GetWritableContainer(blueprint, 'Weapon.Object.WeaponFiring.PrimaryFire')
	if (not success) then
		if Debug.Shared.MODIFICATIONS then
			print('No fireData for: '..self.name)
		end
		return
	end

	aiData, success = g_EbxEditUtils:GetWritableContainer(blueprint, 'Weapon.Object.aiData')
	if (not success) then
		if Debug.Shared.MODIFICATIONS then
			print('No aiData for: '..self.name)
		end
		return
	end

	bulletData, success = g_EbxEditUtils:GetWritableContainer(fireData, 'shot.ProjectileData')
	if (not success) then
		if Debug.Shared.MODIFICATIONS then
			print('No bulletData for: '..self.name)
		end
		return
	end

	--if Debug.Shared.MODIFICATIONS then
	--	print(self.name..': '..tostring(aiData.name))
	--end

	-- stats depending on weapon-type
	local aiDataString = tostring(aiData.name)
	local fireDuration = 0
	local firePause = 0
	local delayedShot = false
	if Debug.Shared.MODIFICATIONS then
		print(self.name)
	end
	if string.find(aiDataString, "_lmg_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("LMG")
		end
		fireDuration 	= 1.5
		firePause		= 0.5
		delayedShot		= true
	elseif string.find(aiDataString, "_sni_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("sniper")
		end
		fireDuration 	= 0.2
		firePause		= 0.5
		delayedShot		= true
	elseif string.find(aiDataString, "_snisemi_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("auto sniper")
		end
		fireDuration 	= 0.2
		firePause		= 0.2
		delayedShot		= true
	elseif string.find(aiDataString, "_rif_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("rifle")
		end
		fireDuration 	= 0.4
		firePause		= 0.4
		delayedShot		= false
	elseif string.find(aiDataString, "_shg_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("shotgun")
		end
		fireDuration 	= 0.2
		firePause		= 0.2
		delayedShot		= false
	elseif string.find(aiDataString, "_smg_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("PDW")
		end
		fireDuration 	= 0.3
		firePause		= 0.2
		delayedShot		= false
	elseif string.find(aiDataString, "_hg_") ~= nil or string.find(self.name, "MP443") ~= nil then -- "MP443 has no ai data"
		if Debug.Shared.MODIFICATIONS then
			print("pistol")
		end
		fireDuration 	= 0.2
		firePause		= 0.2
		delayedShot		= false
	elseif string.find(aiDataString, "_kni_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("knife")
		end
		fireDuration 	= 0.2
		firePause		= 0.2
		delayedShot		= false
	elseif string.find(aiDataString, "_at_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("Rocket")
		end
		fireDuration 	= 0.2
		firePause		= 0.4
		delayedShot		= true
	elseif string.find(aiDataString, "_hgr_") ~= nil then
		if Debug.Shared.MODIFICATIONS then
			print("Grenade")
		end
		fireDuration 	= 0.2
		firePause		= 0.2
		delayedShot		= false
	else
		if Debug.Shared.MODIFICATIONS then
			print("No data found for "..self.name..': '..tostring(aiData.name))
		end
		fireDuration 	= 0.2
		firePause		= 0.2
		delayedShot		= false
	end

	self.damage 		= bulletData.startDamage
	self.endDamage 		= bulletData.endDamage
    self.damageFalloffStartDistance	= bulletData.damageFalloffStartDistance
	self.damageFalloffEndDistance 	= bulletData.damageFalloffStartDistance
	self.bulletSpeed 	= fireData.shot.initialSpeed.z
	self.bulletDrop 	= (bulletData.gravity or 0) * -1
	self.fireCycle 		= fireDuration --aiData.minBurstCoolDownTime
	self.pauseCycle 	= firePause --(aiData.maxBurstCoolDownTime + aiData.minBurstCoolDownTime) / 2
	self.reload			= math.floor(fireData.ammo.magazineCapacity * 0.2)
	self.delayed		= delayedShot
	self.needvalues 	= false
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

		return	"Weapons/"..ext..self.name.."/U_"..self.name..unl
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
