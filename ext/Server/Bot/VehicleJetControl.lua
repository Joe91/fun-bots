---@class VehicleJetControl
---@overload fun():VehicleJetControl
VehicleJetControl = class('VehicleJetControl')

---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type AirTargets
local m_AirTargets = require('AirTargets')
---@type VehicleAttacking
local m_VehicleAttacking = require('Bot/VehicleAttacking')

function VehicleJetControl:__init()
	-- Nothing to do.
end

---Where a jet flies when it doesn't attack: above the active objective, offset by team.
---@param p_Bot Bot
---@param p_Position? Vec3 where the jet is (nil: read from its vehicle)
---@return Vec3
function VehicleJetControl:_GetPatrolPosition(p_Bot, p_Position)
	if p_Position == nil then
		p_Position = p_Bot.m_Player.controlledControllable and p_Bot.m_Player.controlledControllable.transform.trans
	end
	local s_TargetPosition = g_GameDirector:GetActiveTargetPointPosition(p_Bot.m_Player.teamId, p_Position):Clone()
	if not Globals.IsAirSuperiority then
		s_TargetPosition.y = s_TargetPosition.y + Registry.VEHICLES.JET_TARGET_HEIGHT
	end
	if (p_Bot.m_Player.teamId % 2) == 1 then
		s_TargetPosition.z = s_TargetPosition.z + 100
	else
		s_TargetPosition.z = s_TargetPosition.z - 100
	end
	return s_TargetPosition
end

---Another aircraft that would pass closer than JET_AVOID_DISTANCE within JET_AVOID_TIME: the point to break to (to
---the right, the higher one climbs, the lower one dives), else nil. Works on plain numbers, it runs often.
---@param p_Bot Bot
---@param p_Transform LinearTransform
---@param p_Velocity Vec3
---@return Vec3|nil
function VehicleJetControl:_GetEvasionPoint(p_Bot, p_Transform, p_Velocity)
	local s_Trans = p_Transform.trans
	local s_X, s_Y, s_Z = s_Trans.x, s_Trans.y, s_Trans.z
	local s_VelX, s_VelY, s_VelZ = p_Velocity.x, p_Velocity.y, p_Velocity.z
	local s_OwnId = p_Bot.m_Player.id
	local s_AvoidDistance = Registry.VEHICLES.JET_AVOID_DISTANCE
	local s_HeadOnDistance = Registry.VEHICLES.JET_AVOID_HEAD_ON_DISTANCE
	local s_HeadOnSpeed = Registry.VEHICLES.JET_AVOID_HEAD_ON_SPEED
	local s_AvoidTime = Registry.VEHICLES.JET_AVOID_TIME
	local s_Threat = nil
	local s_ThreatTime = s_AvoidTime

	local s_Targets = m_AirTargets._Targets
	for l_Index = 1, #s_Targets do
		local l_Id = s_Targets[l_Index]
		if l_Id ~= s_OwnId then
			local s_Player = PlayerManager:GetPlayerById(l_Id)
			local s_Other = s_Player and s_Player.controlledControllable
			if s_Other ~= nil and not s_Other:Is('ServerSoldierEntity') then
				local s_OtherTrans = s_Other.transform.trans
				local s_RX, s_RY, s_RZ = s_OtherTrans.x - s_X, s_OtherTrans.y - s_Y, s_OtherTrans.z - s_Z
				-- Cheap pre-check: out of reach within the avoid-time even at 300 m/s closing speed.
				local s_Reach = math.max(s_AvoidDistance, s_HeadOnDistance) + 300 * s_AvoidTime
				local s_RangeSq = s_RX * s_RX + s_RY * s_RY + s_RZ * s_RZ
				if s_RangeSq < s_Reach * s_Reach then
					local s_OtherVel = PhysicsEntity(s_Other).velocity
					local s_VX, s_VY, s_VZ = s_OtherVel.x - s_VelX, s_OtherVel.y - s_VelY, s_OtherVel.z - s_VelZ
					local s_SpeedSq = s_VX * s_VX + s_VY * s_VY + s_VZ * s_VZ
					if s_SpeedSq > 1.0 then
						-- Time and distance of the closest approach.
						local s_Time = -(s_RX * s_VX + s_RY * s_VY + s_RZ * s_VZ) / s_SpeedSq
						if s_Time > 0 and s_Time < s_ThreatTime then
							local s_MX, s_MY, s_MZ = s_RX + s_VX * s_Time, s_RY + s_VY * s_Time, s_RZ + s_VZ * s_Time
							-- Head-on (closing speed along the line between them): more room.
							local s_Closing = -(s_RX * s_VX + s_RY * s_VY + s_RZ * s_VZ) / math.sqrt(math.max(s_RangeSq, 1.0))
							local s_Limit = s_Closing > s_HeadOnSpeed and s_HeadOnDistance or s_AvoidDistance
							if s_MX * s_MX + s_MY * s_MY + s_MZ * s_MZ < s_Limit * s_Limit then
								s_ThreatTime = s_Time
								-- Who climbs: the higher one, on the same height the one with the higher id.
								s_Threat = s_RY < 0 or (s_RY == 0 and s_OwnId > l_Id)
							end
						end
					end
				end
			end
		end
	end

	if s_Threat == nil then
		return nil
	end

	local s_Forward = p_Transform.forward
	local s_Left = p_Transform.left
	local s_Vertical = s_Threat and 60 or -60
	return Vec3(s_X + s_Forward.x * 150 - s_Left.x * 150, s_Y + s_Forward.y * 150 + s_Vertical,
		s_Z + s_Forward.z * 150 - s_Left.z * 150)
end

---@param p_DeltaTime number
---@param p_Bot Bot
function VehicleJetControl:UpdateMovementJet(p_DeltaTime, p_Bot)
	if p_Bot._VehicleWaitTimer > 0.0 then
		p_Bot._VehicleWaitTimer = p_Bot._VehicleWaitTimer - p_DeltaTime
		if p_Bot._VehicleWaitTimer <= 0.0 then
			-- Check for other plane in front of bot.
			local s_IsInfront = false
			for l_Index = 1, #g_GameDirector:GetSpawnableVehicle(p_Bot.m_Player.teamId) do
				local l_Jet = g_GameDirector:GetSpawnableVehicle(p_Bot.m_Player.teamId)[l_Index]
				local s_DistanceToJet = p_Bot.m_Player.controlledControllable.transform.trans:Distance(l_Jet.transform.trans)
				if s_DistanceToJet < 30 then
					local s_CompPos = p_Bot.m_Player.controlledControllable.transform.trans:Clone() +
						p_Bot.m_Player.controlledControllable.transform.forward:Clone() * s_DistanceToJet
					if l_Jet.transform.trans:Distance(s_CompPos) < 10 then
						s_IsInfront = true
					end
				end
			end
			if s_IsInfront then
				p_Bot._VehicleWaitTimer = 5.0 -- One more cycle.
				return
			end

			g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.controlledControllable.transform.trans:Clone(), false)
		else
			return
		end
	end

	local s_TargetPosition = self:_GetPatrolPosition(p_Bot)

	if p_Bot._VehicleTakeoffTimer > 0.0 and p_Bot._JetAbortAttackActive then
		-- Too far from the objective: end the extending early, at full throttle the jets flew out of the map.
		local s_Trans = p_Bot.m_Player.controlledControllable.transform.trans
		local s_DiffX = s_TargetPosition.x - s_Trans.x
		local s_DiffZ = s_TargetPosition.z - s_Trans.z
		local s_MaxDistance = Registry.VEHICLES.JET_EXTEND_MAX_DISTANCE
		if s_DiffX * s_DiffX + s_DiffZ * s_DiffZ > s_MaxDistance * s_MaxDistance then
			p_Bot._VehicleTakeoffTimer = 0.0
		end
	end

	if p_Bot._VehicleTakeoffTimer > 0.0 then
		p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - p_DeltaTime
		if p_Bot._JetTakeoffActive or
			(p_Bot._JetAbortAttackActive and (p_Bot.m_Player.controlledControllable.transform.trans.y < (s_TargetPosition.y - 45)))
		then
			s_TargetPosition = p_Bot.m_Player.controlledControllable.transform.trans:Clone()
			local s_Forward = p_Bot.m_Player.controlledControllable.transform.forward:Clone()
			s_Forward.y = 0
			s_Forward:Normalize()
			s_TargetPosition = s_TargetPosition + (s_Forward * 70)
			s_TargetPosition.y = s_TargetPosition.y + 70
			local s_Waypoint = {
				Position = s_TargetPosition,
			}
			p_Bot._TargetPoint = s_Waypoint
			return
		elseif p_Bot._JetAbortAttackActive then
			-- Extend after an attack: straight ahead on patrol-height, away from the target. Turned back to the patrol-
			-- point right away, the jet stayed in a turning fight close to its target and could never aim.
			local s_Trans = p_Bot.m_Player.controlledControllable.transform.trans
			local s_Forward = p_Bot.m_Player.controlledControllable.transform.forward:Clone()
			s_Forward.y = 0
			s_Forward:Normalize()
			local s_Height = s_TargetPosition.y
			s_TargetPosition = s_Trans + (s_Forward * 300)
			s_TargetPosition.y = s_Height
			local s_Waypoint = {
				Position = s_TargetPosition,
			}
			p_Bot._TargetPoint = s_Waypoint
			return
		end
	end

	p_Bot._JetTakeoffActive = false
	p_Bot._JetAbortAttackActive = false

	-- don't move along paths with planes
	local s_Waypoint = {
		Position = s_TargetPosition,
	}
	p_Bot._TargetPoint = s_Waypoint
end

-- Function to calculate the yaw and pitch deviation relative to the orientation of a reference object
function VehicleJetControl:CalculateDeviationRelativeToOrientation(p_Transform, targetPoint)
	return m_Utilities:GetDeviationToTarget(p_Transform, targetPoint)
end

---@param p_Bot Bot
---@param p_Attacking boolean
---@param p_DeltaTime number
function VehicleJetControl:UpdateYawJet(p_Bot, p_Attacking, p_DeltaTime)
	-- Every access of an engine object (controlledControllable, transform, input, ...) allocates. Read each one once.
	local s_Vehicle = p_Bot._TargetPoint and p_Bot.m_Player.controlledControllable
	if s_Vehicle == nil then
		return
	end
	local s_Transform = s_Vehicle.transform
	local s_Input = p_Bot.m_Input
	-- Attacking: the takeoff is over (no attacks during JET_TAKEOFF_TIME). UpdateMovementJet, which ends it otherwise,
	-- doesn't run while attacking: the flag stayed set and turned off the evasion and the ground avoidance (XP3_Valley:
	-- the first head-on pass after the takeoff ended in a collision).
	if p_Attacking then
		p_Bot._JetTakeoffActive = false
	end

	local s_Trans = s_Transform.trans
	-- Once per call: it goes over all capture points.
	local s_PatrolHeight = self:_GetPatrolPosition(p_Bot, s_Trans).y

	local s_DeltaYaw, s_DeltaPitch = 0, 0
	if p_Attacking then
		-- Aim with the gun, not with the center of the jet: from the muzzle, corrected by the angle of the gun.
		local s_EntryId = p_Bot.m_Player.controlledEntryId
		local s_Slot = p_Bot._ActiveVehicleWeaponSlot
		local s_Offset = m_Vehicles:GetOffsets(p_Bot.m_ActiveVehicle, s_EntryId, s_Slot)
		local s_OffX, s_OffY, s_OffZ = s_Offset.x, s_Offset.y, s_Offset.z
		local s_Left = s_Transform.left
		local s_Up = s_Transform.up
		local s_Forward = s_Transform.forward
		local s_Target = p_Bot._AttackPosition
		local s_DirX = s_Target.x - (s_Trans.x + s_Left.x * s_OffX + s_Up.x * s_OffY + s_Forward.x * s_OffZ)
		local s_DirY = s_Target.y - (s_Trans.y + s_Left.y * s_OffX + s_Up.y * s_OffY + s_Forward.y * s_OffZ)
		local s_DirZ = s_Target.z - (s_Trans.z + s_Left.z * s_OffX + s_Up.z * s_OffY + s_Forward.z * s_OffZ)
		s_DeltaYaw, s_DeltaPitch = m_Utilities:GetDeviationFromTransform(s_Transform, s_DirX, s_DirY, s_DirZ)
		local s_AimOffsetYaw, s_AimOffsetPitch = m_Vehicles:GetAimOffsets(p_Bot.m_ActiveVehicle, s_EntryId, s_Slot)
		s_DeltaYaw = s_DeltaYaw - s_AimOffsetYaw
		s_DeltaPitch = s_DeltaPitch - s_AimOffsetPitch

		-- Stay in a band around the patrol-height. Not _TargetPoint: UpdateMovementJet doesn't run while attacking, it
		-- still held an old point (often the climb-point right above the jet), so jets climbed higher with every attack.
		local s_Height = s_Trans.y
		if s_Height > s_PatrolHeight + 120 or s_Height < s_PatrolHeight - 75 then
			p_Bot._JetTakeoffActive = false
			p_Bot:AbortAttack()
		end
	else
		s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(s_Transform, p_Bot._TargetPoint.Position)
	end

	-- Break away from aircraft on collision course, before anything else. No shots meanwhile.
	-- Not while taking off: the jets parked next to the runway count as aircraft too, the jets broke right on the runway.
	local s_Velocity = PhysicsEntity(s_Vehicle).velocity
	local s_Evasion = nil
	if not p_Bot._JetTakeoffActive then
		s_Evasion = self:_GetEvasionPoint(p_Bot, s_Transform, s_Velocity)
	end
	if s_Evasion ~= nil then
		s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(s_Transform, s_Evasion)
		if p_Attacking then
			-- The pass is over: extend (see UpdateMovementJet), then a new run with enough distance to aim.
			p_Bot:AbortAttack()
		end
		p_Attacking = false
	end

	-- Ground avoidance, above everything else (not while taking off). Diving after ground-targets, often rolled over,
	-- the jets pulled "up" through a split-S into the ground. Roll upright first (bank-angle: 0 level, > 0 banked
	-- right, +-pi inverted), pull up once the jet isn't upside down any more.
	local s_GroundHeight = s_PatrolHeight
	if not Globals.IsAirSuperiority then
		s_GroundHeight = s_GroundHeight - Registry.VEHICLES.JET_TARGET_HEIGHT
	end
	if not p_Bot._JetTakeoffActive and s_Trans.y + math.min(s_Velocity.y, 0.0) * Registry.VEHICLES.JET_PULL_OUT_TIME
		< s_GroundHeight + Registry.VEHICLES.JET_MIN_ALTITUDE then
		if p_Attacking then
			p_Bot:AbortAttack()
		end
		local s_Bank = math.atan(s_Transform.left.y, s_Transform.up.y)
		s_Input:SetLevel(EntryInputActionEnum.EIARoll, math.max(-1.0, math.min(1.0, -2 * s_Bank)))
		-- Nose up is a negative pitch-input (as 3 * deltaPitch below: a target above gives a negative deviation).
		s_Input:SetLevel(EntryInputActionEnum.EIAPitch, math.abs(s_Bank) < 1.2 and -1.0 or 0.0)
		s_Input:SetLevel(EntryInputActionEnum.EIAYaw, 0.0)
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, 1.0)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
		p_Bot._VehicleReadyToShoot = false
		return
	end

	-- Roll
	s_Input:SetLevel(EntryInputActionEnum.EIARoll, -3 * s_DeltaYaw) -- Roll into the turn.

	-- TILT and YAW
	-- No backwards in planes. s_DeltaYaw > 0 → target on the left → negative yaw-input (same convention as chopper / ground).
	if p_Attacking then
		-- The lead-point moves all the time (both jets fly fast), with P only the nose lagged behind it and swung across
		-- it. The I-part removes the lag, the D-part damps. The rudder does the fine corrections, rolling is too coarse.
		s_Input:SetLevel(EntryInputActionEnum.EIAPitch, p_Bot._Pid_Jet_Pitch:Update(s_DeltaPitch, p_DeltaTime))
		s_Input:SetLevel(EntryInputActionEnum.EIAYaw, p_Bot._Pid_Jet_Yaw:Update(-s_DeltaYaw, p_DeltaTime))
	else
		s_Input:SetLevel(EntryInputActionEnum.EIAPitch, 3 * s_DeltaPitch)
		s_Input:SetLevel(EntryInputActionEnum.EIAYaw, math.max(-1.0, math.min(1.0, -s_DeltaYaw)))
	end

	-- Throttle.
	-- Target velocity == 313 km/h → 86.9444 m/s. Full throttle while extending after an attack: more distance.
	local s_Delta_Speed = 86.9444 - s_Velocity.magnitude
	local s_Output_Throttle = p_Bot._Pid_Drv_Throttle:Update(s_Delta_Speed, p_DeltaTime)
	if p_Bot._JetAbortAttackActive and not p_Attacking then
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, 1.0)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	elseif s_Output_Throttle > 0 then
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	else
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
	end

	-- Fire once the shot passes the lead-point close enough: wide angle when close, narrow when far away.
	-- Fired here and not in the (slower) attack-update: no bursts, the gun fires as long as the target is in the window.
	if p_Attacking then
		local s_Distance = math.max(p_Bot._DistanceToPlayer, 1.0)
		local s_FireAngle = math.max(Registry.VEHICLES.JET_FIRE_MIN_ANGLE,
			math.min(Registry.VEHICLES.JET_FIRE_MAX_ANGLE, math.atan(Registry.VEHICLES.JET_FIRE_HIT_RADIUS, s_Distance)))
		p_Bot._VehicleReadyToShoot = (s_DeltaYaw * s_DeltaYaw + s_DeltaPitch * s_DeltaPitch) < s_FireAngle * s_FireAngle
		if p_Bot._VehicleReadyToShoot then
			m_VehicleAttacking:Fire(p_Bot)
		end
	else
		p_Bot._VehicleReadyToShoot = false
	end
end

if g_VehicleJetControl == nil then
	---@type VehicleJetControl
	g_VehicleJetControl = VehicleJetControl()
end

return g_VehicleJetControl
