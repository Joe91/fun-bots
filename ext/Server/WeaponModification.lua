---@class WeaponModification
WeaponModification = class('WeaponModification')

require('__shared/Config')
---@type Logger
local m_Logger = Logger("WeaponModification", Debug.Shared.MODIFICATIONS)


function WeaponModification:__init()
	self:RegisterVars()
end

function WeaponModification:RegisterVars()
	self.m_AlreadyLoaded = false
	self.m_WeaponInstances = {}

	self.m_MaxAngles = {}
	self.m_MinAngles = {}
	self.m_IncPerShot = {}

	self.m_MinAnglesStand = {}
	self.m_MaxAnglesStand = {}
	self.m_IncPerShotStand = {}

	self.m_MaxRecoilPitch = {}
	self.m_RecoilIncShot = {}
	self.m_MaxRecoilYaw = {}
	self.m_RecoilIncShotMin = {}
	self.m_RecoilIncShotMax = {}
	self.m_RecoilDecrease = {}

	self.m_Stand_MaxAngles = {}
	self.m_Stand_MinAngles = {}
	self.m_Stand_IncPerShot = {}

	self.m_Stand_MinAnglesStand = {}
	self.m_Stand_MaxAnglesStand = {}
	self.m_Stand_IncPerShotStand = {}

	self.m_Stand_MaxRecoilPitch = {}
	self.m_Stand_RecoilIncShot = {}
	self.m_Stand_MaxRecoilYaw = {}
	self.m_Stand_RecoilIncShotMin = {}
	self.m_Stand_RecoilIncShotMax = {}
	self.m_Stand_RecoilDecrease = {}
end

-- =============================================
-- Events
-- =============================================

---VEXT Shared Partition:Loaded Event
---@param p_Partition DatabasePartition
function WeaponModification:OnPartitionLoaded(p_Partition)
	if not p_Partition.primaryInstance:Is('SoldierWeaponBlueprint') then
		return
	end

	---@type SoldierWeaponData
	for _, p_Instance in pairs(p_Partition.instances) do
		if p_Instance ~= nil and p_Instance:Is('SoldierWeaponData') then
			p_Instance = SoldierWeaponData(p_Instance)

			if p_Instance.soldierWeaponBlueprint == nil then
				return
			end

			if self.m_AlreadyLoaded then
				self:RegisterVars() --reset all vars
			end

			table.insert(self.m_WeaponInstances, p_Instance)
			return
		end
	end
end

-- =============================================
-- Functions
-- =============================================

function WeaponModification:ModifyAllWeapons(p_AimWorseningNormal, p_AimWorseningSniper, p_AimWorseningSupport)
	m_Logger:Write(#self.m_WeaponInstances .. ' loaded weapons to modify')

	for i, p_WeaponInstance in pairs(self.m_WeaponInstances) do
		self:_ModifyWeapon(p_WeaponInstance , i, p_AimWorseningNormal, p_AimWorseningSniper, p_AimWorseningSupport)
	end

	self.m_AlreadyLoaded = true
end

function WeaponModification:_ModifyWeapon(p_SoldierWeaponData, p_Index, p_AimWorseningNormal, p_AimWorseningSniper, p_AimWorseningSupport)
	local s_SoldierWeaponData = self:_MakeWritable(p_SoldierWeaponData)
	local s_WeaponFiringData = self:_MakeWritable(s_SoldierWeaponData.weaponFiring)

	if s_WeaponFiringData.weaponSway == nil then
		return
	end

	local s_BotAimWorsening = p_AimWorseningNormal
	-- check for sniper rifles:
	--https://docs.veniceunleashed.net/vext/ref/fb/weaponclassenum/ and EBX-Dumb
	local s_Class = s_SoldierWeaponData.weaponClass
	local s_AiData = s_SoldierWeaponData.aiData
	local s_NameOfAiData = tostring(s_AiData.name)

	if string.find(s_NameOfAiData ,"Handheld_sni_AI_Weapon") ~= nil
	or string.find(s_NameOfAiData ,"Handheld_snisemi_AI_Weapon") ~= nil then
		s_BotAimWorsening = p_AimWorseningSniper
	elseif string.find(s_NameOfAiData ,"Handheld_lmg_AI_Weapon") ~= nil then
		s_BotAimWorsening = p_AimWorseningSupport
	end

	local s_RecoilFactor = s_BotAimWorsening

	local s_GunSwayData = self:_MakeWritable(s_WeaponFiringData.weaponSway)
	-- From here on, you can modify everything in GunSwayData
	--if self.m_Crouch then
	local s_Crouch = GunSwayCrouchProneData(s_GunSwayData.crouch)

	if s_Crouch ~= nil then
		local s_CrouchNoZoom = GunSwayBaseMoveData(s_Crouch.noZoom)

		--HipFire - no zoom - crouching
		if s_CrouchNoZoom ~= nil then
			--Only modify movemode of bots
			local s_MovingValue = GunSwayDispersionData(s_CrouchNoZoom.moving)

			if s_MovingValue ~= nil then
				if self.m_MaxAngles[p_Index] == nil then
					self.m_MinAngles[p_Index] = s_MovingValue.minAngle
					self.m_MaxAngles[p_Index] = s_MovingValue.maxAngle
					self.m_IncPerShot[p_Index] = s_MovingValue.increasePerShot
				end

				s_MovingValue.minAngle = self.m_MinAngles[p_Index] * s_BotAimWorsening/3
				s_MovingValue.maxAngle = self.m_MaxAngles[p_Index] * s_BotAimWorsening
				s_MovingValue.increasePerShot = self.m_IncPerShot[p_Index] * s_BotAimWorsening
				--decreasePerSecond float
			end

			local s_RecoilData = GunSwayRecoilData(s_CrouchNoZoom.recoil)

			if s_RecoilData ~= nil then
				if self.m_MaxRecoilPitch[p_Index] == nil then
					self.m_MaxRecoilPitch[p_Index] = s_RecoilData.recoilAmplitudeMax
					self.m_RecoilIncShot[p_Index] = s_RecoilData.recoilAmplitudeIncPerShot
					self.m_MaxRecoilYaw[p_Index] = s_RecoilData.horizontalRecoilAmplitudeMax
					self.m_RecoilIncShotMin[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin
					self.m_RecoilIncShotMax[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax
					self.m_RecoilDecrease[p_Index] = s_RecoilData.recoilAmplitudeDecreaseFactor
				end

				s_RecoilData.recoilAmplitudeMax = self.m_MaxRecoilPitch[p_Index] * s_RecoilFactor
				s_RecoilData.recoilAmplitudeIncPerShot = self.m_RecoilIncShot[p_Index] * s_RecoilFactor / 2
				s_RecoilData.horizontalRecoilAmplitudeMax = self.m_MaxRecoilYaw[p_Index] * s_RecoilFactor
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin = self.m_RecoilIncShotMin[p_Index] * s_RecoilFactor / 3
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax = self.m_RecoilIncShotMax[p_Index] * s_RecoilFactor
				--s_RecoilData.recoilAmplitudeDecreaseFactor = self.m_RecoilDecrease[p_Index] * (1 / (s_RecoilFactor + 0.0001))
			end

			local s_StandingValue = GunSwayDispersionData(s_CrouchNoZoom.baseValue)

			if s_MovingValue ~= nil then
				if self.m_MaxAnglesStand[p_Index] == nil then
					self.m_MinAnglesStand[p_Index] = s_StandingValue.minAngle
					self.m_MaxAnglesStand[p_Index] = s_StandingValue.maxAngle
					self.m_IncPerShotStand[p_Index] = s_StandingValue.increasePerShot
				end

				s_StandingValue.minAngle = self.m_MinAnglesStand[p_Index] * s_BotAimWorsening / 3
				s_StandingValue.maxAngle = self.m_MaxAnglesStand[p_Index] * s_BotAimWorsening
				s_StandingValue.increasePerShot = self.m_IncPerShotStand[p_Index] * s_BotAimWorsening
				--decreasePerSecond float
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
				if self.m_Stand_MaxAngles[p_Index] == nil then
					self.m_Stand_MinAngles[p_Index] = s_MovingValue.minAngle
					self.m_Stand_MaxAngles[p_Index] = s_MovingValue.maxAngle
					self.m_Stand_IncPerShot[p_Index] = s_MovingValue.increasePerShot
				end

				s_MovingValue.minAngle = self.m_Stand_MinAngles[p_Index] * s_BotAimWorsening / 3
				s_MovingValue.maxAngle = self.m_Stand_MaxAngles[p_Index] * s_BotAimWorsening
				s_MovingValue.increasePerShot = self.m_Stand_IncPerShot[p_Index] * s_BotAimWorsening
				--decreasePerSecond float
			end

			local s_RecoilData = GunSwayRecoilData(s_StandNoZoom.recoil)

			if s_RecoilData ~= nil then
				if self.m_Stand_MaxRecoilPitch[p_Index] == nil then
					self.m_Stand_MaxRecoilPitch[p_Index] = s_RecoilData.recoilAmplitudeMax
					self.m_Stand_RecoilIncShot[p_Index] = s_RecoilData.recoilAmplitudeIncPerShot
					self.m_Stand_MaxRecoilYaw[p_Index] = s_RecoilData.horizontalRecoilAmplitudeMax
					self.m_Stand_RecoilIncShotMin[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin
					self.m_Stand_RecoilIncShotMax[p_Index] = s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax
					self.m_Stand_RecoilDecrease[p_Index] = s_RecoilData.recoilAmplitudeDecreaseFactor
				end

				s_RecoilData.recoilAmplitudeMax = self.m_Stand_MaxRecoilPitch[p_Index] * s_RecoilFactor
				s_RecoilData.recoilAmplitudeIncPerShot = self.m_Stand_RecoilIncShot[p_Index] * s_RecoilFactor / 2
				s_RecoilData.horizontalRecoilAmplitudeMax = self.m_Stand_MaxRecoilYaw[p_Index] * s_RecoilFactor
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMin = self.m_Stand_RecoilIncShotMin[p_Index] * s_BotAimWorsening / 3
				s_RecoilData.horizontalRecoilAmplitudeIncPerShotMax = self.m_Stand_RecoilIncShotMax[p_Index] * s_RecoilFactor
				--s_RecoilData.recoilAmplitudeDecreaseFactor = self.m_Stand_RecoilDecrease[p_Index] * (1 / (s_RecoilFactor + 0.0001))
			end

			local s_StandingValue = GunSwayDispersionData(s_StandNoZoom.baseValue)

			if s_MovingValue ~= nil then
				if self.m_Stand_MaxAnglesStand[p_Index] == nil then
					self.m_Stand_MinAnglesStand[p_Index] = s_StandingValue.minAngle
					self.m_Stand_MaxAnglesStand[p_Index] = s_StandingValue.maxAngle
					self.m_Stand_IncPerShotStand[p_Index] = s_StandingValue.increasePerShot
				end

				s_StandingValue.minAngle = self.m_Stand_MinAnglesStand[p_Index] * s_BotAimWorsening / 3
				s_StandingValue.maxAngle = self.m_Stand_MaxAnglesStand[p_Index] * s_BotAimWorsening
				s_StandingValue.increasePerShot = self.m_Stand_IncPerShotStand[p_Index] * s_BotAimWorsening
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
	---@type WeaponModification
	g_WeaponModification = WeaponModification()
end

return g_WeaponModification
