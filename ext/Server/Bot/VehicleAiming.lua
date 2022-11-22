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

function VehicleAiming:UpdateAimingVehicleAdvanced(p_Bot)
	if p_Bot._ShootPlayer == nil then
		return
	end

	if not p_Bot._Shoot or p_Bot._ShootPlayer.soldier == nil then
		return
	end

	-- Interpolate target-player movement.
	local s_TargetVelocity = Vec3.zero
	local s_PitchCorrection = 0.0
	local s_FullPositionTarget = nil
	local s_FullPositionBot = nil

	if p_Bot._VehicleMovableId >= 0 then
		s_FullPositionBot = p_Bot.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):
			ToLinearTransform().trans
	else
		-- To-do: adjust for chopper-drivers?
		s_FullPositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
			m_Utilities:getCameraPos(p_Bot.m_Player, false, false)
	end

	if p_Bot._ShootPlayerVehicleType == VehicleTypes.MavBot or p_Bot._ShootPlayerVehicleType == VehicleTypes.MobileArtillery then
		s_FullPositionTarget = p_Bot._ShootPlayer.controlledControllable.transform.trans:Clone()
	else
		if p_Bot.m_Player.controlledEntryId == 0 and p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
			-- Add nothing (0.1) → aim for the feet of the target.
			s_FullPositionTarget = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
			s_FullPositionTarget.y = s_FullPositionTarget.y + 0.1
		else
			s_FullPositionTarget = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone() +
				m_Utilities:getCameraPos(p_Bot._ShootPlayer, true, false)
		end
	end

	if p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
		s_TargetVelocity = PhysicsEntity(p_Bot._ShootPlayer.soldier).velocity
	else
		s_TargetVelocity = PhysicsEntity(p_Bot._ShootPlayer.controlledControllable).velocity
	end

	-- Calculate how long the distance is → time to travel.
	local s_Drop = 0.0
	local s_Speed = 0.0
	local s_VectorBetween = s_FullPositionTarget - s_FullPositionBot

	s_Speed, s_Drop = m_Vehicles:GetSpeedAndDrop(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId,
		p_Bot._ActiveVehicleWeaponSlot)

	local A = s_TargetVelocity:Dot(s_TargetVelocity) - s_Speed * s_Speed
	local B = 2.0 * s_TargetVelocity:Dot(s_VectorBetween)
	local C = s_VectorBetween:Dot(s_VectorBetween)
	local s_Determinant = math.sqrt(B * B - 4 * A * C)
	local t1 = (-B + s_Determinant) / (2 * A)
	local t2 = (-B - s_Determinant) / (2 * A)
	local s_TimeToTravel = 0

	if t1 > 0 then
		if t2 > 0 then
			s_TimeToTravel = math.min(t1, t2)
		else
			s_TimeToTravel = t1
		end
	else
		s_TimeToTravel = math.max(t2, 0.0)
	end

	local s_AimAt = s_FullPositionTarget + (s_TargetVelocity * s_TimeToTravel)

	s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop -- From theory 0.5. In real, 0.375 works much better.

	-- Calculate yaw and pitch.
	local s_DifferenceZ = s_AimAt.z - s_FullPositionBot.z
	local s_DifferenceX = s_AimAt.x - s_FullPositionBot.x
	local s_DifferenceY = s_AimAt.y + s_PitchCorrection - s_FullPositionBot.y

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	p_Bot._TargetPitch = s_Pitch
	p_Bot._TargetYaw = s_Yaw


	-- Abort attacking in chopper or jet if too steep or too low.
	if (m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) and p_Bot.m_Player.controlledEntryId == 0) or
		m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
		local s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi
		if math.abs(p_Bot._TargetPitch) > s_PitchHalf then
			p_Bot:AbortAttack()
			return
		end
		if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) and
			s_FullPositionBot:Distance(s_FullPositionTarget) < Registry.VEHICLES.ABORT_ATTACK_AIR_DISTANCE_JET then
			p_Bot:AbortAttack()
		end
		if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.Chopper and p_Bot._ShootPlayerVehicleType ~= VehicleTypes.Plane then
			local s_DiffVertical = s_FullPositionBot.y - s_FullPositionTarget.y
			if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) then
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

function VehicleAiming:UpdateAimingVehicle(p_Bot)
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

	if p_Bot._VehicleMovableId >= 0 then
		s_FullPositionBot = p_Bot.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):
			ToLinearTransform().trans
	else
		-- To-do: adjust for chopper-drivers?
		s_FullPositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
			m_Utilities:getCameraPos(p_Bot.m_Player, false, false)
	end

	if p_Bot._ShootPlayerVehicleType == VehicleTypes.MavBot or p_Bot._ShootPlayerVehicleType == VehicleTypes.MobileArtillery then
		s_FullPositionTarget = p_Bot._ShootPlayer.controlledControllable.transform.trans:Clone()
	else
		if p_Bot.m_Player.controlledEntryId == 0 and p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle and
			p_Bot._ActiveVehicleWeaponSlot == 1 then
			-- Add nothing → aim for the feet of the target.
			s_FullPositionTarget = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
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

	-- Calculate how long the distance is → time to travel.
	p_Bot._DistanceToPlayer = s_FullPositionTarget:Distance(s_FullPositionBot)

	local s_Drop = 0.0
	local s_Speed = 0.0

	s_Speed, s_Drop = m_Vehicles:GetSpeedAndDrop(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId,
		p_Bot._ActiveVehicleWeaponSlot)

	local s_TimeToTravel = (p_Bot._DistanceToPlayer / s_Speed)
	s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop -- From theory 0.5. In real, 0.375 works much better.

	s_TargetMovement = (s_TargetMovement * s_TimeToTravel)


	local s_DifferenceY = 0
	local s_DifferenceX = 0
	local s_DifferenceZ = 0

	-- Calculate yaw and pitch.
	s_DifferenceZ = s_FullPositionTarget.z + s_TargetMovement.z - s_FullPositionBot.z
	s_DifferenceX = s_FullPositionTarget.x + s_TargetMovement.x - s_FullPositionBot.x
	s_DifferenceY = s_FullPositionTarget.y + s_TargetMovement.y + s_PitchCorrection - s_FullPositionBot.y

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	p_Bot._TargetPitch = s_Pitch
	p_Bot._TargetYaw = s_Yaw


	-- Abort attacking in chopper or jet if too steep or too low.
	if (m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) and p_Bot.m_Player.controlledEntryId == 0) or
		m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
		local s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi
		if math.abs(p_Bot._TargetPitch) > s_PitchHalf then
			p_Bot:AbortAttack()
			return
		end
		if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) and
			s_FullPositionBot:Distance(s_FullPositionTarget) < Registry.VEHICLES.ABORT_ATTACK_AIR_DISTANCE_JET then
			p_Bot:AbortAttack()
		end
		if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.Chopper and p_Bot._ShootPlayerVehicleType ~= VehicleTypes.Plane then
			local s_DiffVertical = s_FullPositionBot.y - s_FullPositionTarget.y
			if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) then
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
