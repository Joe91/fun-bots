---@class VehicleAiming
---@overload fun():VehicleAiming
VehicleAiming = class('VehicleAiming')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")

function VehicleAiming:__init()
	-- Nothing to do.
end

---@param p_Bot Bot
---@param p_Speed number
---@param p_FullPositionBot Vec3
---@param p_FullPositionTarget Vec3
---@param p_TargetMovement Vec3
---@param p_AdvancedAlgorithm Boolean
---@return number
local function _GetTimeToTravel(p_Bot, p_Speed, p_FullPositionBot, p_FullPositionTarget, p_TargetMovement, p_AdvancedAlgorithm)
	if p_AdvancedAlgorithm then
		local s_VectorBetween = p_FullPositionTarget - p_FullPositionBot
		-- Calculate how long the distance is → time to travel.
		local A = p_TargetMovement:Dot(p_TargetMovement) - p_Speed * p_Speed
		local B = 2.0 * p_TargetMovement:Dot(s_VectorBetween)
		local C = s_VectorBetween:Dot(s_VectorBetween)
		local s_Determinant = math.sqrt(B * B - 4 * A * C)
		local t1 = (-B + s_Determinant) / (2 * A)
		local t2 = (-B - s_Determinant) / (2 * A)

		if t1 > 0 then
			if t2 > 0 then
				return math.min(t1, t2)
			else
				return t1
			end
		else
			return math.max(t2, 0.0)
		end
	else
		return (p_Bot._DistanceToPlayer / p_Speed)
	end
end

function VehicleAiming:UpdateAimingVehicle(p_Bot, p_AdvancedAlgorithm)
	if p_Bot._ShootPlayer == nil then
		return
	end

	if not p_Bot._Shoot or p_Bot._ShootPlayer.soldier == nil then
		return
	end

	-- Interpolate target-player movement.
	local s_TargetMovement = Vec3.zero
	local s_PitchCorrection = 0.0
	local s_FullPositionTarget = nil
	local s_FullPositionBot = nil
	local s_IsAirVehicle = m_Vehicles:IsAirVehicle(p_Bot.m_ActiveVehicle)


	if p_Bot._VehicleMovableId >= 0 then
		local s_VehicleTrans = p_Bot.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):ToLinearTransform()
		local s_Offsets = m_Vehicles:GetOffsets(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId, p_Bot._ActiveVehicleWeaponSlot)
		s_FullPositionBot = s_VehicleTrans.trans + (s_VehicleTrans.left * s_Offsets.x) + (s_VehicleTrans.up * s_Offsets.y) + (s_VehicleTrans.forward * s_Offsets.z)
	elseif s_IsAirVehicle and p_Bot.m_Player.controlledEntryId == 0 then
		-- main weapon of chopper or jet
		local s_VehicleTrans = p_Bot.m_Player.controlledControllable.transform
		local s_Offsets = m_Vehicles:GetOffsets(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId, p_Bot._ActiveVehicleWeaponSlot)
		s_FullPositionBot = s_VehicleTrans.trans + (s_VehicleTrans.left * s_Offsets.x) + (s_VehicleTrans.up * s_Offsets.y) + (s_VehicleTrans.forward * s_Offsets.z)
	else
		s_FullPositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
			m_Utilities:getCameraPos(p_Bot.m_Player, false, false)
	end

	if p_Bot._ShootPlayerVehicleType == VehicleTypes.MavBot or p_Bot._ShootPlayerVehicleType == VehicleTypes.MobileArtillery then
		s_FullPositionTarget = p_Bot._ShootPlayer.controlledControllable.transform.trans:Clone()
	else
		if p_Bot.m_Player.controlledEntryId == 0 and p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle and
			p_Bot._ActiveVehicleWeaponSlot == 1 then
			-- Add nothing (0.1) → aim for the feet of the target.
			s_FullPositionTarget = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
			s_FullPositionTarget.y = s_FullPositionTarget.y + 0.1
		else
			s_FullPositionTarget = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone() +
				m_Utilities:getCameraPos(p_Bot._ShootPlayer, true, false)
		end
	end

	if p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
		s_TargetMovement = PhysicsEntity(p_Bot._ShootPlayer.soldier).velocity
	else
		s_TargetMovement = PhysicsEntity(p_Bot._ShootPlayer.controlledControllable).velocity
	end

	p_Bot._DistanceToPlayer = s_FullPositionTarget:Distance(s_FullPositionBot)

	local s_Drop = 0.0
	local s_Speed = 0.0
	local s_TimeToTravel = 0.0

	s_Speed, s_Drop = m_Vehicles:GetSpeedAndDrop(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId,
		p_Bot._ActiveVehicleWeaponSlot)

	s_TimeToTravel = _GetTimeToTravel(p_Bot, s_Speed, s_FullPositionBot, s_FullPositionTarget, s_TargetMovement, p_AdvancedAlgorithm)

	s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop

	s_TargetMovement = (s_TargetMovement * s_TimeToTravel)



	-- Calculate yaw and pitch.
	local s_DifferenceZ = s_FullPositionTarget.z + s_TargetMovement.z - s_FullPositionBot.z
	local s_DifferenceX = s_FullPositionTarget.x + s_TargetMovement.x - s_FullPositionBot.x
	local s_DifferenceY = s_FullPositionTarget.y + s_TargetMovement.y + s_PitchCorrection - s_FullPositionBot.y

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	local s_WorseningPitch = 0.0
	local s_WorseningYaw = 0.0
	local s_WorseningValue = 0.0

	if s_IsAirVehicle then
		s_WorseningValue = Config.VehicleAimWorsening
	else
		s_WorseningValue = Config.VehicleAirAimWorsening
	end
	if s_WorseningValue > 0 then
		local s_SkillDistanceFactor = 1 / (p_Bot._DistanceToPlayer * Registry.BOT.WORSENING_FACOTR_DISTANCE)
		s_WorseningValue = s_WorseningValue * s_SkillDistanceFactor
		s_WorseningPitch = (MathUtils:GetRandom(-1.0, 1.0) * s_WorseningValue)
		s_WorseningYaw = (MathUtils:GetRandom(-1.0, 1.0) * s_WorseningValue)
	end

	p_Bot._TargetPitch = s_Pitch + s_WorseningPitch
	p_Bot._TargetYaw = s_Yaw + s_WorseningYaw

	-- Abort attacking in chopper or jet if too steep or too low.
	if s_IsAirVehicle and p_Bot.m_Player.controlledEntryId == 0 then

		-- Abort attacking if behind only if not an air vehicle
		if not m_Vehicles.IsAirVehicleType(p_Bot._ShootPlayerVehicleType) then
			local s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi

			if math.abs(p_Bot._TargetPitch) > s_PitchHalf then
				p_Bot:AbortAttack()
				return
			end
		end

		if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) and
			s_FullPositionBot:Distance(s_FullPositionTarget) < Registry.VEHICLES.ABORT_ATTACK_AIR_DISTANCE_JET then
			p_Bot:AbortAttack()
		end
		if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.Chopper
			and p_Bot._ShootPlayerVehicleType ~= VehicleTypes.ScoutChopper
			and p_Bot._ShootPlayerVehicleType ~= VehicleTypes.Plane
		then
			local s_DiffVertical = s_FullPositionBot.y - s_FullPositionTarget.y
			if m_Vehicles:IsChopper(p_Bot.m_ActiveVehicle) then
				if s_DiffVertical < Registry.VEHICLES.ABORT_ATTACK_HEIGHT_CHOPPER then -- Too low to the ground.
					p_Bot:AbortAttack()
				end
			elseif m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
				if s_DiffVertical < Registry.VEHICLES.ABORT_ATTACK_HEIGHT_JET then -- Too low to the ground.
					p_Bot:AbortAttack()
				end
				if p_Bot._DistanceToPlayer < Registry.VEHICLES.ABORT_ATTACK_DISTANCE_JET then
					p_Bot:AbortAttack()
				end
			end
			return
		end
	end
end

if g_VehicleAiming == nil then
	---@type VehicleAiming
	g_VehicleAiming = VehicleAiming()
end

return g_VehicleAiming
