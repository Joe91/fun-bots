class('WeaponModification')

function WeaponModification:__init()
	self.m_WeaponInstances = {}
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
end

function WeaponModification:OnPartitionLoaded(p_Partition)
	local s_Instances = p_Partition.instances
	for _, s_Instance in pairs(s_Instances) do
		if s_Instance ~= nil and s_Instance.typeInfo.name == "SoldierWeaponData" then
			local s_SoldierWeaponData = _G[s_Instance.typeInfo.name](s_Instance)
			if s_SoldierWeaponData.soldierWeaponBlueprint ~= nil then
				table.insert(self.m_WeaponInstances, s_SoldierWeaponData)
			end
		end
	end
end

function WeaponModification:OnLevelLoaded(p_Map, p_GameMode) --Server
    self:ModifyAllBotWeapons()
end
function WeaponModification:OnEngineMessage(p_Message) -- Client
    if p_Message.type == MessageType.ClientLevelFinalizedMessage then
		self:ModifyAllBotWeapons()
	end
end

function WeaponModification:ModifyAllBotWeapons()
	print(#self.m_WeaponInstances)
	for _, weaponInstance in pairs(self.m_WeaponInstances) do
		self:ModifyWeapon(weaponInstance)
		-- check if bot weapons?
		-- modify only bot weapon
	end
end

function WeaponModification:ModifyWeapon(p_SoldierWeaponData)
	local s_SoldierWeaponData = self:MakeWritable(p_SoldierWeaponData)
	local s_WeaponFiringData = self:MakeWritable(s_SoldierWeaponData.weaponFiring)
	if s_WeaponFiringData.weaponSway == nil then
		return
	end
	local s_GunSwayData = self:MakeWritable(s_WeaponFiringData.weaponSway)
	print("modify sway")
	-- From here on, you can modify everything in GunSwayData
	--s_GunSwayData.deviationScaleFactorZoom = 7
	--s_GunSwayData.gameplayDeviationScaleFactorZoom = 7
	--s_GunSwayData.deviationScaleFactorNoZoom = 0.0
	--s_GunSwayData.gameplayDeviationScaleFactorNoZoom = 0.0
	--s_GunSwayData.shootingRecoilDecreaseScale = 0
	--s_GunSwayData.firstShotRecoilMultiplier = 0

	--[[local s_Stand = GunSwayStandData(s_GunSwayData.stand)
	if s_Stand ~= nil then
		print("modify stand")
		local s_NoZoom = GunSwayBaseMoveJumpData(s_Stand.noZoom)
		--local s_Zoom = GunSwayBaseMoveJumpData(s_Stand.zoom)
		--HipFire 
		if s_NoZoom ~= nil then
			local s_BaseValue = GunSwayDispersionData(s_NoZoom.baseValue)
			if s_BaseValue ~= nil then
				s_BaseValue.minAngle = s_BaseValue.minAngle * 0.0
				s_BaseValue.maxAngle = s_BaseValue.maxAngle * 0.0
			end
			local s_MovingValue = GunSwayDispersionData(s_NoZoom.moving)
			if s_MovingValue ~= nil then
				s_MovingValue.minAngle = s_MovingValue.minAngle * 0.0
				s_MovingValue.maxAngle = s_MovingValue.maxAngle * 0.0
			end
			--[[local s_Recoil = GunSwayRecoilData(s_NoZoom.recoil)
			if s_Recoil ~= nil then
				s_Recoil.recoilAmplitudeMax = 0
				s_Recoil.recoilAmplitudeIncPerShot = 0
			end--]]
		end
		if s_Zoom ~= nil then
			-- do nothing, as bots don't zoom
		end
	end--]]

	local s_Crouch = GunSwayCrouchProneData(s_GunSwayData.crouch)
	if s_Crouch ~= nil then
		print("modify crouch")
		local s_CrouchNoZoom = GunSwayBaseMoveData(s_Crouch.noZoom)
		--local s_CrouchZoom = GunSwayBaseMoveData(s_Crouch.zoom)
		--HipFire 
		if s_CrouchNoZoom ~= nil then
			local s_BaseValue = GunSwayDispersionData(s_CrouchNoZoom.baseValue)
			if s_BaseValue ~= nil then
				print("modify crouching")
				s_BaseValue.minAngle = s_BaseValue.minAngle * 0.0
				s_BaseValue.maxAngle = s_BaseValue.maxAngle * 0.0
			end--]]
			local s_MovingValue = GunSwayDispersionData(s_CrouchNoZoom.moving)
			if s_MovingValue ~= nil then
				s_MovingValue.minAngle = s_MovingValue.minAngle * 0.0
				s_MovingValue.maxAngle = s_MovingValue.maxAngle * 0.0
			end
			--[[local s_Recoil = GunSwayRecoilData(s_CrouchNoZoom.recoil)
			if s_Recoil ~= nil then
				s_Recoil.recoilAmplitudeMax = 0
				s_Recoil.recoilAmplitudeIncPerShot = 0
			end--]]
		end
	end--]]
end

function WeaponModification:MakeWritable(p_Instance)
	if p_Instance == nil then
		return
	end

	local s_Instance = _G[p_Instance.typeInfo.name](p_Instance)
	if p_Instance.isLazyLoaded == true then
		print('The instance '..tostring(p_Instance.instanceGuid).." was modified, even though its lazyloaded")
		return
	end

	if p_Instance.isReadOnly == nil then
		-- If .isReadOnly is nil it means that its not a DataContainer, it's a Structure. We return it casted
		print('The instance '..p_Instance.typeInfo.name.." is not a DataContainer, it's a Structure")
		return s_Instance
	end

	if not p_Instance.isReadOnly then
		return s_Instance
	end

	s_Instance:MakeWritable()
	return s_Instance
end

-- Singleton.
if g_WeaponModification == nil then
	g_WeaponModification = WeaponModification()
end

return g_WeaponModification