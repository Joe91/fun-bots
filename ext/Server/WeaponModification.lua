class('WeaponModification')

require('__shared/Config')
local m_Logger = Logger("WeaponModification", Debug.Shared.MODIFICATIONS)


function WeaponModification:__init()
	self.m_alreadyLoaded = false
	self.m_WeaponInstances = {}

	self.m_maxAngles = {}
	self.m_minAngles = {}
	self.m_incPerShot = {}

	self.m_minAnglesStand = {}
	self.m_maxAnglesStand = {}
	self.m_incPerShotStand = {}

	self.m_maxRecoilPitch = {}
	self.m_recoilIncShot = {}
	self.m_maxRecoilYaw = {}
	self.m_recoilIncShotMin = {}
	self.m_recoilIncShotMax = {}
	self.m_recoilDecrease = {}


	self.m_stand_maxAngles = {}
	self.m_stand_minAngles = {}
	self.m_stand_incPerShot = {}

	self.m_stand_minAnglesStand = {}
	self.m_stand_maxAnglesStand = {}
	self.m_stand_incPerShotStand = {}

	self.m_stand_maxRecoilPitch = {}
	self.m_stand_recoilIncShot = {}
	self.m_stand_maxRecoilYaw = {}
	self.m_stand_recoilIncShotMin = {}
	self.m_stand_recoilIncShotMax = {}
	self.m_stand_recoilDecrease = {}

	--self.crouch = (Config.BotAttackMode == "Crouch")
	--[[local isBot = {}
	isBot["voteban_flash"] = true
	Events:Subscribe('GunSway:Update', function(gunSway, weapon, weaponFiring, deltaTime)
		if weapon == nil then
			return
		end
		local soldier = SoldierEntity(weapon.bus.parent.entities[26])
		if soldier == nil or soldier.player == nil then
			return
		end
		if isBot[soldier.player.name] ~= nil then
			local gunSwayData = GunSwayData(gunSway.data)
			if soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
				gunSway.dispersionAngle = gunSwayData.stand.zoom.baseValue.minAngle
			elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
				gunSway.dispersionAngle = gunSwayData.crouch.zoom.baseValue.minAngle

			elseif soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
				gunSway.dispersionAngle = gunSwayData.prone.zoom.baseValue.minAngle
			else
				return
			end
		end
	end)--]]
end

function WeaponModification:_resetAll()
	self.m_alreadyLoaded = false
	self.m_WeaponInstances = {}

	self.m_maxAngles = {}
	self.m_minAngles = {}
	self.m_incPerShot = {}

	self.m_minAnglesStand = {}
	self.m_maxAnglesStand = {}
	self.m_incPerShotStand = {}

	self.m_maxRecoilPitch = {}
	self.m_recoilIncShot = {}
	self.m_maxRecoilYaw = {}
	self.m_recoilIncShotMin = {}
	self.m_recoilIncShotMax = {}
	self.m_recoilDecrease = {}


	self.m_stand_maxAngles = {}
	self.m_stand_minAngles = {}
	self.m_stand_incPerShot = {}

	self.m_stand_minAnglesStand = {}
	self.m_stand_maxAnglesStand = {}
	self.m_stand_incPerShotStand = {}

	self.m_stand_maxRecoilPitch = {}
	self.m_stand_recoilIncShot = {}
	self.m_stand_maxRecoilYaw = {}
	self.m_stand_recoilIncShotMin = {}
	self.m_stand_recoilIncShotMax = {}
	self.m_stand_recoilDecrease = {}
end

function WeaponModification:OnPartitionLoaded(p_Partition)
	local s_Instances = p_Partition.instances

	for _, s_Instance in pairs(s_Instances) do
		if s_Instance ~= nil and s_Instance.typeInfo.name == 'SoldierWeaponData' then
			local s_SoldierWeaponData = _G[s_Instance.typeInfo.name](s_Instance)

			if s_SoldierWeaponData.soldierWeaponBlueprint ~= nil then
				if self.m_alreadyLoaded then
					self:_resetAll()
				end

				table.insert(self.m_WeaponInstances, s_SoldierWeaponData)
			end
		end
	end
end

function WeaponModification:ModifyAllWeapons(p_AimWorseningNormal, p_AimWorseningSniper)
	m_Logger:Write(#self.m_WeaponInstances .. ' loaded weapons to modify')

	for i, weaponInstance in pairs(self.m_WeaponInstances) do
		self:_ModifyWeapon(weaponInstance , i, p_AimWorseningNormal, p_AimWorseningSniper)
	end

	self.m_alreadyLoaded = true
end

function WeaponModification:_ModifyWeapon(p_SoldierWeaponData, p_Index, p_AimWorseningNormal, p_AimWorseningSniper)
	local s_SoldierWeaponData = self:_MakeWritable(p_SoldierWeaponData)
	local s_WeaponFiringData = self:_MakeWritable(s_SoldierWeaponData.weaponFiring)

	if s_WeaponFiringData.weaponSway == nil then
		return
	end

	local botAimWorsening = p_AimWorseningNormal
	local isReconWeapon = false
	-- check for sniper rifles:
	--https://docs.veniceunleashed.net/vext/ref/fb/weaponclassenum/ and EBX-Dumb
	local class = s_SoldierWeaponData.weaponClass
	local aiData = s_SoldierWeaponData.aiData
	local nameOfAiData = tostring(aiData.name)
	if string.find(nameOfAiData ,"Handheld_sni_AI_Weapon") ~= nil
	or string.find(nameOfAiData ,"Handheld_snisemi_AI_Weapon") ~= nil then
		botAimWorsening = p_AimWorseningSniper
		isReconWeapon = true
	end
	local recoilFactor = botAimWorsening

	local s_GunSwayData = self:_MakeWritable(s_WeaponFiringData.weaponSway)
	-- From here on, you can modify everything in GunSwayData
	--if self.crouch then
	local s_Crouch = GunSwayCrouchProneData(s_GunSwayData.crouch)

	if s_Crouch ~= nil then
		local s_CrouchNoZoom = GunSwayBaseMoveData(s_Crouch.noZoom)

		--HipFire - no zoom - crouching
		if s_CrouchNoZoom ~= nil then
			--Only modify movemode of bots
			local s_MovingValue = GunSwayDispersionData(s_CrouchNoZoom.moving)

			if s_MovingValue ~= nil then
				if self.m_maxAngles[p_Index] == nil then
					self.m_minAngles[p_Index] = s_MovingValue.minAngle
					self.m_maxAngles[p_Index] = s_MovingValue.maxAngle
					self.m_incPerShot[p_Index] = s_MovingValue.increasePerShot
				end

				s_MovingValue.minAngle = self.m_minAngles[p_Index] * botAimWorsening/3
				s_MovingValue.maxAngle = self.m_maxAngles[p_Index] * botAimWorsening
				s_MovingValue.increasePerShot = self.m_incPerShot[p_Index] * botAimWorsening
				--decreasePerSecond float
			end

			local s_RecoilData = GunSwayRecoilData(s_CrouchNoZoom.recoil)

			if s_RecoilData ~= nil then
				if self.m_maxRecoilPitch[p_Index] == nil then
					self.m_maxRecoilPitch[p_Index] = s_RecoilData.recoilAmplitudeMax
					self.m_recoilIncShot[p_Index] = s_RecoilData.recoilAmplitudeIncPerShot
					self.m_maxRecoilYaw[p_Index] = s_RecoilData.horizontalRecoilAmplitudeMax
					self.m_recoilIncShotMin[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin
					self.m_recoilIncShotMax[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax
					self.m_recoilDecrease[p_Index] = s_RecoilData.recoilAmplitudeDecreaseFactor
				end

				s_RecoilData.recoilAmplitudeMax = self.m_maxRecoilPitch[p_Index] * recoilFactor
				s_RecoilData.recoilAmplitudeIncPerShot = self.m_recoilIncShot[p_Index] * recoilFactor/2
				s_RecoilData.horizontalRecoilAmplitudeMax = self.m_maxRecoilYaw[p_Index] * recoilFactor
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin = self.m_recoilIncShotMin[p_Index] * recoilFactor/3
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax = self.m_recoilIncShotMax[p_Index] * recoilFactor
				--s_RecoilData.recoilAmplitudeDecreaseFactor = self.m_recoilDecrease[p_Index] * (1/(recoilFactor + 0.0001))
			end

			--if isReconWeapon then --only for recon in standing as well.
			local s_StandingValue = GunSwayDispersionData(s_CrouchNoZoom.baseValue)

			if s_MovingValue ~= nil then
				if self.m_maxAnglesStand[p_Index] == nil then
					self.m_minAnglesStand[p_Index] = s_StandingValue.minAngle
					self.m_maxAnglesStand[p_Index] = s_StandingValue.maxAngle
					self.m_incPerShotStand[p_Index] = s_StandingValue.increasePerShot
				end

				s_StandingValue.minAngle = self.m_minAnglesStand[p_Index] * botAimWorsening/3
				s_StandingValue.maxAngle = self.m_maxAnglesStand[p_Index] * botAimWorsening
				s_StandingValue.increasePerShot = self.m_incPerShotStand[p_Index] * botAimWorsening
				--decreasePerSecond 	float
			end
			--end
		end
	end
	--else
	local s_Stand = GunSwayStandData(s_GunSwayData.stand)

	if s_Stand ~= nil then
		local s_StandNoZoom = GunSwayBaseMoveJumpData(s_Stand.noZoom)

		--HipFire - no zoom - crouching
		if s_StandNoZoom ~= nil then
			--Only modify movemode of bots
			local s_MovingValue = GunSwayDispersionData(s_StandNoZoom.moving)

			if s_MovingValue ~= nil then
				if self.m_stand_maxAngles[p_Index] == nil then
					self.m_stand_minAngles[p_Index] = s_MovingValue.minAngle
					self.m_stand_maxAngles[p_Index] = s_MovingValue.maxAngle
					self.m_stand_incPerShot[p_Index] = s_MovingValue.increasePerShot
				end

				s_MovingValue.minAngle = self.m_stand_minAngles[p_Index] * botAimWorsening/3
				s_MovingValue.maxAngle = self.m_stand_maxAngles[p_Index] * botAimWorsening
				s_MovingValue.increasePerShot = self.m_stand_incPerShot[p_Index] * botAimWorsening
				--decreasePerSecond float
			end

			local s_RecoilData = GunSwayRecoilData(s_StandNoZoom.recoil)

			if s_RecoilData ~= nil then
				if self.m_stand_maxRecoilPitch[p_Index] == nil then
					self.m_stand_maxRecoilPitch[p_Index] = s_RecoilData.recoilAmplitudeMax
					self.m_stand_recoilIncShot[p_Index] = s_RecoilData.recoilAmplitudeIncPerShot
					self.m_stand_maxRecoilYaw[p_Index] = s_RecoilData.horizontalRecoilAmplitudeMax
					self.m_stand_recoilIncShotMin[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin
					self.m_stand_recoilIncShotMax[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax
					self.m_stand_recoilDecrease[p_Index] = s_RecoilData.recoilAmplitudeDecreaseFactor
				end

				s_RecoilData.recoilAmplitudeMax = self.m_stand_maxRecoilPitch[p_Index] * recoilFactor
				s_RecoilData.recoilAmplitudeIncPerShot = self.m_stand_recoilIncShot[p_Index] * recoilFactor/2
				s_RecoilData.horizontalRecoilAmplitudeMax = self.m_stand_maxRecoilYaw[p_Index] * recoilFactor
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin = self.m_stand_recoilIncShotMin[p_Index] * botAimWorsening/3
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax = self.m_stand_recoilIncShotMax[p_Index] * recoilFactor
				--s_RecoilData.recoilAmplitudeDecreaseFactor = self.m_stand_recoilDecrease[p_Index] * (1/(recoilFactor + 0.0001))
			end

			--if isReconWeapon then --only for recon in standing as well.
			local s_StandingValue = GunSwayDispersionData(s_StandNoZoom.baseValue)

			if s_MovingValue ~= nil then
				if self.m_stand_maxAnglesStand[p_Index] == nil then
					self.m_stand_minAnglesStand[p_Index] = s_StandingValue.minAngle
					self.m_stand_maxAnglesStand[p_Index] = s_StandingValue.maxAngle
					self.m_stand_incPerShotStand[p_Index] = s_StandingValue.increasePerShot
				end

				s_StandingValue.minAngle = self.m_stand_minAnglesStand[p_Index] * botAimWorsening/3
				s_StandingValue.maxAngle = self.m_stand_maxAnglesStand[p_Index] * botAimWorsening
				s_StandingValue.increasePerShot = self.m_stand_incPerShotStand[p_Index] * botAimWorsening
				--decreasePerSecond float
			end
			--end
		end
	end
	--end
end

function WeaponModification:_MakeWritable(p_Instance)
	if p_Instance == nil then
		return
	end

	local s_Instance = _G[p_Instance.typeInfo.name](p_Instance)

	if p_Instance.isLazyLoaded == true then
		m_Logger:Write('The instance ' .. tostring(p_Instance.instanceGuid) .. ' was modified, even though its lazyloaded')

		return
	end

	if p_Instance.isReadOnly == nil then
		-- If .isReadOnly is nil it means that its not a DataContainer, it's a Structure. We return it casted
		m_Logger:Write('The instance ' .. p_Instance.typeInfo.name .. ' is not a DataContainer, it\'s a Structure')

		return s_Instance
	end

	if not p_Instance.isReadOnly then
		return s_Instance
	end

	s_Instance:MakeWritable()

	return s_Instance
end

if g_WeaponModification == nil then
	g_WeaponModification = WeaponModification()
end

return g_WeaponModification
