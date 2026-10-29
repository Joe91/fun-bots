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

-- Works on plain numbers: vector math and method calls on Vec3 allocate, this runs for every attacking vehicle bot.
---@param p_Bot Bot
---@param p_Speed number
---@param p_DiffX number target - bot
---@param p_DiffY number
---@param p_DiffZ number
---@param p_MoveX number target movement
---@param p_MoveY number
---@param p_MoveZ number
---@param p_AdvancedAlgorithm boolean
---@return number
local function _GetTimeToTravel(p_Bot, p_Speed, p_DiffX, p_DiffY, p_DiffZ, p_MoveX, p_MoveY, p_MoveZ, p_AdvancedAlgorithm)
	if p_Speed <= 0 then
		return 0.0
	end
	if p_AdvancedAlgorithm then
		-- Calculate how long the distance is → time to travel.
		local A = (p_MoveX * p_MoveX + p_MoveY * p_MoveY + p_MoveZ * p_MoveZ) - p_Speed * p_Speed
		local B = 2.0 * (p_MoveX * p_DiffX + p_MoveY * p_DiffY + p_MoveZ * p_DiffZ)
		local C = p_DiffX * p_DiffX + p_DiffY * p_DiffY + p_DiffZ * p_DiffZ
		local s_Discriminant = B * B - 4 * A * C
		-- No solution (the projectile can't catch up): sqrt would return NaN, use the plain flight-time instead.
		if s_Discriminant < 0 or A == 0 then
			return p_Bot._DistanceToPlayer / p_Speed
		end
		local s_Determinant = math.sqrt(s_Discriminant)
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

---Acceleration of the target, from the change of its velocity and smoothed (the velocity is noisy). Restarts on a
---new target (Bot:AbortAttack clears the target-id).
---@param p_Bot Bot
---@param p_Velocity Vec3 velocity of the target
---@param p_DeltaTime number
---@return number, number, number
local function _UpdateTargetAcceleration(p_Bot, p_Velocity, p_DeltaTime)
	local s_Data = p_Bot._JetTargetAcceleration
	local s_VelX, s_VelY, s_VelZ = p_Velocity.x, p_Velocity.y, p_Velocity.z

	if s_Data.TargetId ~= p_Bot._ShootPlayerId or p_DeltaTime <= 0 then
		s_Data.TargetId = p_Bot._ShootPlayerId
		s_Data.LastX, s_Data.LastY, s_Data.LastZ = s_VelX, s_VelY, s_VelZ
		s_Data.X, s_Data.Y, s_Data.Z = 0.0, 0.0, 0.0
		return 0.0, 0.0, 0.0
	end

	local s_AccX = (s_VelX - s_Data.LastX) / p_DeltaTime
	local s_AccY = (s_VelY - s_Data.LastY) / p_DeltaTime
	local s_AccZ = (s_VelZ - s_Data.LastZ) / p_DeltaTime
	s_Data.LastX, s_Data.LastY, s_Data.LastZ = s_VelX, s_VelY, s_VelZ

	local s_Alpha = math.min(1.0, p_DeltaTime / Registry.VEHICLES.JET_TARGET_ACCELERATION_SMOOTHING)
	local s_X = s_Data.X + (s_AccX - s_Data.X) * s_Alpha
	local s_Y = s_Data.Y + (s_AccY - s_Data.Y) * s_Alpha
	local s_Z = s_Data.Z + (s_AccZ - s_Data.Z) * s_Alpha

	-- Limit spikes (collisions, respawns).
	local s_Max = Registry.VEHICLES.JET_TARGET_ACCELERATION_MAX
	local s_Magnitude = math.sqrt(s_X * s_X + s_Y * s_Y + s_Z * s_Z)
	if s_Magnitude > s_Max then
		local s_Scale = s_Max / s_Magnitude
		s_X, s_Y, s_Z = s_X * s_Scale, s_Y * s_Scale, s_Z * s_Scale
	end
	s_Data.X, s_Data.Y, s_Data.Z = s_X, s_Y, s_Z

	return s_X, s_Y, s_Z
end

---@param p_Bot Bot
---@param p_AdvancedAlgorithm boolean
---@param p_DeltaTime number
function VehicleAiming:UpdateAimingVehicle(p_Bot, p_AdvancedAlgorithm, p_DeltaTime)
	-- Every access of an engine object (soldier, transform, trans, ...) and all Vec3 math allocate.
	-- Read each object once and calculate with plain numbers.
	local s_Player = p_Bot.m_Player
	local s_ShootPlayer = p_Bot._ShootPlayer
	if s_ShootPlayer == nil then
		return
	end
	local s_Soldier = s_Player.soldier
	if s_Soldier == nil then
		return
	end

	if not p_Bot._Shoot then
		return
	end
	local s_TargetSoldier = s_ShootPlayer.soldier
	if s_TargetSoldier == nil then
		return
	end

	-- Interpolate target-player movement.
	local s_IsAirVehicle = m_Vehicles:IsAirVehicle(p_Bot.m_ActiveVehicle)
	local s_EntryId = s_Player.controlledEntryId
	local s_BotX, s_BotY, s_BotZ

	local s_VehicleTrans = nil
	if p_Bot._VehicleMovableId >= 0 then
		s_VehicleTrans = s_Player.controlledControllable.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):ToLinearTransform()
	elseif s_IsAirVehicle and s_EntryId == 0 then
		-- main weapon of chopper or jet
		s_VehicleTrans = s_Player.controlledControllable.transform
	end

	if s_VehicleTrans then
		-- Weapon position = trans + left * offset.x + up * offset.y + forward * offset.z
		local s_Offsets = m_Vehicles:GetOffsets(p_Bot.m_ActiveVehicle, s_EntryId, p_Bot._ActiveVehicleWeaponSlot)
		local s_OffX, s_OffY, s_OffZ = s_Offsets.x, s_Offsets.y, s_Offsets.z
		local s_Trans = s_VehicleTrans.trans
		local s_Left = s_VehicleTrans.left
		local s_Up = s_VehicleTrans.up
		local s_Forward = s_VehicleTrans.forward
		s_BotX = s_Trans.x + s_Left.x * s_OffX + s_Up.x * s_OffY + s_Forward.x * s_OffZ
		s_BotY = s_Trans.y + s_Left.y * s_OffX + s_Up.y * s_OffY + s_Forward.y * s_OffZ
		s_BotZ = s_Trans.z + s_Left.z * s_OffX + s_Up.z * s_OffY + s_Forward.z * s_OffZ
	else
		local s_Trans = s_Soldier.worldTransform.trans
		s_BotX = s_Trans.x
		s_BotY = s_Trans.y + m_Utilities:getTargetHeight(s_Soldier, false, false)
		s_BotZ = s_Trans.z
	end

	local s_TargetX, s_TargetY, s_TargetZ
	if p_Bot._ShootPlayerVehicleType == VehicleTypes.MavBot or p_Bot._ShootPlayerVehicleType == VehicleTypes.MobileArtillery then
		local s_Trans = s_ShootPlayer.controlledControllable.transform.trans
		s_TargetX, s_TargetY, s_TargetZ = s_Trans.x, s_Trans.y, s_Trans.z
	else
		local s_Trans = s_TargetSoldier.worldTransform.trans
		s_TargetX, s_TargetZ = s_Trans.x, s_Trans.z
		if s_EntryId == 0 and p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle and
			p_Bot._ActiveVehicleWeaponSlot == 1 then
			-- Add nothing (0.1) → aim for the feet of the target.
			s_TargetY = s_Trans.y + 0.1
		else
			s_TargetY = s_Trans.y + m_Utilities:getTargetHeight(s_TargetSoldier, true, false)
		end
	end

	local s_Velocity
	if p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
		s_Velocity = PhysicsEntity(s_TargetSoldier).velocity
	else
		s_Velocity = PhysicsEntity(s_ShootPlayer.controlledControllable).velocity
	end
	local s_MoveX, s_MoveY, s_MoveZ = s_Velocity.x, s_Velocity.y, s_Velocity.z

	-- Jets, turning targets: the lead includes their acceleration, with a straight lead the shots passed behind them.
	local s_AccX, s_AccY, s_AccZ = 0.0, 0.0, 0.0
	if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
		s_AccX, s_AccY, s_AccZ = _UpdateTargetAcceleration(p_Bot, s_Velocity, p_DeltaTime)
	end

	local s_DiffX = s_TargetX - s_BotX
	local s_DiffY = s_TargetY - s_BotY
	local s_DiffZ = s_TargetZ - s_BotZ
	p_Bot._DistanceToPlayer = math.sqrt(s_DiffX * s_DiffX + s_DiffY * s_DiffY + s_DiffZ * s_DiffZ)

	local s_Speed, s_Drop = m_Vehicles:GetSpeedAndDrop(p_Bot.m_ActiveVehicle, s_EntryId,
		p_Bot._ActiveVehicleWeaponSlot)

	local s_TimeToTravel = _GetTimeToTravel(p_Bot, s_Speed, s_DiffX, s_DiffY, s_DiffZ, s_MoveX, s_MoveY, s_MoveZ, p_AdvancedAlgorithm)

	local s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop

	local s_HalfTimeSq = 0.5 * s_TimeToTravel * s_TimeToTravel
	s_MoveX = s_MoveX * s_TimeToTravel + s_AccX * s_HalfTimeSq
	s_MoveY = s_MoveY * s_TimeToTravel + s_AccY * s_HalfTimeSq
	s_MoveZ = s_MoveZ * s_TimeToTravel + s_AccZ * s_HalfTimeSq

	-- only for jet aiming for now
	p_Bot._AttackPosition = Vec3(s_TargetX + s_MoveX, s_TargetY + s_MoveY + s_PitchCorrection, s_TargetZ + s_MoveZ)

	-- Calculate yaw and pitch.
	local s_DifferenceZ = s_DiffZ + s_MoveZ
	local s_DifferenceX = s_DiffX + s_MoveX
	local s_DifferenceY = s_DiffY + s_MoveY + s_PitchCorrection

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	-- Humanlike aim error (see BotAimError): an angle, so hits get rarer on greater distances.
	local s_AimError = 0.0

	if not s_IsAirVehicle then
		s_AimError = Config.VehicleAimError
	elseif m_Vehicles:IsAAVehicle(p_Bot.m_ActiveVehicle) then
		s_AimError = Config.VehicleAAAimError
	elseif m_Vehicles:IsGunship(p_Bot.m_ActiveVehicle) then
		s_AimError = Config.VehicleGunshipAimError
	elseif m_Vehicles:IsChopper(p_Bot.m_ActiveVehicle) then
		s_AimError = Config.VehicleChopperAimError
	else
		s_AimError = Config.VehiclePlaneAimError
	end

	-- Targets crossing the view fast are harder to track. Only the own movement of the target: the own vehicle
	-- (jets) would dominate, and its movement is part of the flying.
	local s_AngularSpeed = m_Utilities:GetAngularSpeed(s_DiffX, s_DiffY, s_DiffZ, p_Bot._DistanceToPlayer,
		s_Velocity.x, s_Velocity.y, s_Velocity.z)
	local s_ErrorScale = p_Bot:GetAimErrorScale(s_AimError)
	local s_Sigma = (s_AimError * 0.001 + s_AngularSpeed * Registry.BOT.AIM_TRACKING_ERROR * s_ErrorScale) *
		p_Bot:GetAimSkillFactor()
	local s_ErrorYaw, s_ErrorPitch = p_Bot:UpdateAimError(p_DeltaTime, s_Sigma, s_ErrorScale, s_Yaw, s_Pitch, false)

	-- Chopper main-guns are aimed with the whole chopper: point the nose so that the shot (AimOffset relative to the
	-- nose) hits. Yaw decreases to the left, AimOffset-yaw > 0 is left → nose further right. Same for pitch.
	-- Parts and jets correct the AimOffset in their local frame (VehicleMovement / VehicleJetControl).
	if s_IsAirVehicle and s_EntryId == 0 and p_Bot._VehicleMovableId < 0 and
		not m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
		local s_AimOffsetYaw, s_AimOffsetPitch = m_Vehicles:GetAimOffsets(p_Bot.m_ActiveVehicle, s_EntryId, p_Bot._ActiveVehicleWeaponSlot)
		s_Yaw = s_Yaw + s_AimOffsetYaw
		s_Pitch = s_Pitch + s_AimOffsetPitch
	end

	p_Bot._TargetPitch = s_Pitch + s_ErrorPitch
	p_Bot._TargetYaw = s_Yaw + s_ErrorYaw

	-- Abort attacking in chopper or jet if too steep or too low.
	if s_IsAirVehicle and s_EntryId == 0 then
		-- Abort attacking if behind only if not an air vehicle
		if not m_Vehicles:IsAirVehicleType(p_Bot._ShootPlayerVehicleType) then
			local s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi

			if math.abs(p_Bot._TargetPitch) > s_PitchHalf then
				p_Bot:AbortAttack()
				return
			end
		end

		if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) and
			p_Bot._DistanceToPlayer < Registry.VEHICLES.ABORT_ATTACK_AIR_DISTANCE_JET then
			p_Bot:AbortAttack()
		end
		if not m_Vehicles:IsAirVehicleType(p_Bot._ShootPlayerVehicleType) then
			local s_DiffVertical = s_BotY - s_TargetY
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
