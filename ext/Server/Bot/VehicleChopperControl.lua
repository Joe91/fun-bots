---@class VehicleChopperControl
---@overload fun():VehicleChopperControl
VehicleChopperControl = class('VehicleChopperControl')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles

-- Farther from the target than this (horizontal metres) the chopper flies at least CHOPPER_MIN_CLIMB metres above the
-- height it took off at, then it goes down to the target.
local CHOPPER_DESCEND_RANGE = 150.0
local CHOPPER_MIN_CLIMB = 40.0
-- The chopper keeps CHOPPER_CLEARANCE metres above the highest ground under its way the next CHOPPER_LOOKAHEAD metres
-- (towards its target), looked for with rays every CHOPPER_PROBE_INTERVAL seconds. Without, it flew into the slopes it
-- climbed too slowly for (XP3_Alborz: the Mi28 twice at the same spot 230 m from its pad, MP_013: Z-11w).
local CHOPPER_CLEARANCE = 30.0
local CHOPPER_LOOKAHEAD = { 25.0, 60.0, 100.0, 150.0 }
-- Not closer to the chopper than this: the ray hit the chopper itself, it climbed and climbed (1500 m on XP3_Alborz).
local CHOPPER_PROBE_MIN = 12.0
local CHOPPER_PROBE_INTERVAL = 0.5
local CHOPPER_PROBE_ABOVE = 300.0
local CHOPPER_PROBE_DEPTH = 600.0
-- Further below its target height than this, the chopper climbs before it flies on (little forward tilt).
local CHOPPER_CLIMB_FIRST = 25.0
local CHOPPER_TILT = -0.35 -- = 20 degrees
local CHOPPER_TILT_CLIMBING = -0.12 -- = 7 degrees
-- Each chopper flies to its own spot this far around the target point (by its id): to the same point they flew into
-- each other (XP3_Alborz: Ka-60 and Mi28 over D).
local CHOPPER_SPREAD = 35.0
local GOLDEN_ANGLE = 2.39996
-- Attacking, the nose follows the aim only this far down / up: diving at a target below (-40 to -70 degrees) the
-- choppers flew into the ground, nose up at +25 degrees one stalled.
local CHOPPER_ATTACK_TILT_MIN = -0.6 -- = -34 degrees
local CHOPPER_ATTACK_TILT_MAX = 0.35 -- = 20 degrees
-- Attacking closer than this above the ground ahead, or sinking faster: the pilot levels out and climbs for
-- CHOPPER_RECOVER_TIME seconds to CHOPPER_RECOVER_CLEARANCE above the ground (the gunner shoots on). The height target
-- of the movement stays as it was while attacking (XP3_Alborz: sank 10 m/s into the slope below its target).
local CHOPPER_ATTACK_CLEARANCE = 25.0
local CHOPPER_ATTACK_SINK = 10.0
local CHOPPER_ATTACK_LOOKAHEAD = 100.0
local CHOPPER_RECOVER_TIME = 2.5
local CHOPPER_RECOVER_CLEARANCE = 40.0
local CHOPPER_RECOVER_TILT = 0.05
-- Also not attacking: nose further down than this (hit by a rocket, XP3_Alborz: -50 to -76 degrees after a hit, the
-- chopper fell 60 m/s) or sinking faster than CHOPPER_ATTACK_SINK - level out and climb.
local CHOPPER_NOSE_DOWN_MAX = -0.7 -- = -40 degrees

function VehicleChopperControl:__init()
	-- Nothing to do.
end

---@param p_DeltaTime number
---@param p_Bot Bot
function VehicleChopperControl:UpdateMovementChopper(p_DeltaTime, p_Bot)
	if p_Bot._VehicleWaitTimer > 0.0 then
		p_Bot._VehicleWaitTimer = p_Bot._VehicleWaitTimer - p_DeltaTime
		if p_Bot._VehicleWaitTimer <= 0.0 then
			g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.controlledControllable.transform.trans:Clone(), false)
		else
			return
		end
	end

	if p_Bot._VehicleTakeoffTimer > 0.0 then
		p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - p_DeltaTime
	end

	local s_Vehicle = p_Bot.m_Player.controlledControllable
	local s_TargetPoint = g_GameDirector:GetActiveTargetPointPosition(p_Bot.m_Player.teamId,
		s_Vehicle and s_Vehicle.transform.trans):Clone()
	s_TargetPoint.y = s_TargetPoint.y + Registry.VEHICLES.CHOPPER_TARGET_HEIGHT
	-- Far from the target: not lower than CHOPPER_MIN_CLIMB above where the chopper took off. A target far below (the
	-- base on the mountain of MP_013, the MCOMs in the valley) gave no throttle at all, the chopper never took off.
	if s_Vehicle ~= nil then
		local s_Position = s_Vehicle.transform.trans
		if p_Bot._ChopperStartHeight == nil then
			p_Bot._ChopperStartHeight = s_Position.y
		end
		local s_Angle = p_Bot.m_Id * GOLDEN_ANGLE
		s_TargetPoint.x = s_TargetPoint.x + math.cos(s_Angle) * CHOPPER_SPREAD
		s_TargetPoint.z = s_TargetPoint.z + math.sin(s_Angle) * CHOPPER_SPREAD
		local s_DeltaX = s_TargetPoint.x - s_Position.x
		local s_DeltaZ = s_TargetPoint.z - s_Position.z
		local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
		if s_Distance > CHOPPER_DESCEND_RANGE then
			s_TargetPoint.y = math.max(s_TargetPoint.y, p_Bot._ChopperStartHeight + CHOPPER_MIN_CLIMB)
		end
		local s_Ground = self:GroundAhead(p_DeltaTime, p_Bot, s_Position, s_DeltaX, s_DeltaZ, s_Distance)
		if s_Ground ~= nil then
			s_TargetPoint.y = math.max(s_TargetPoint.y, s_Ground + CHOPPER_CLEARANCE)
		end
	end

	-- don't move along paths with planes
	local s_Waypoint = {
		Position = s_TargetPoint,
	}
	p_Bot._TargetPoint = s_Waypoint
end

---The highest ground under the way of the chopper the next CHOPPER_LOOKAHEAD metres towards its target, looked for every
---CHOPPER_PROBE_INTERVAL seconds. nil without a hit (or right above the target). Jets look farther (p_Lookahead).
---@param p_DeltaTime number
---@param p_Bot Bot
---@param p_Position Vec3
---@param p_DeltaX number towards the target
---@param p_DeltaZ number
---@param p_Distance number to the target (horizontal)
---@param p_Lookahead? number[] metres ahead (default CHOPPER_LOOKAHEAD)
---@return number|nil
function VehicleChopperControl:GroundAhead(p_DeltaTime, p_Bot, p_Position, p_DeltaX, p_DeltaZ, p_Distance, p_Lookahead)
	p_Bot._GroundProbeTime = p_Bot._GroundProbeTime - p_DeltaTime
	if p_Bot._GroundProbeTime > 0.0 then
		return p_Bot._GroundAhead
	end
	p_Bot._GroundProbeTime = CHOPPER_PROBE_INTERVAL
	local s_Flags = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.DontCheckWater
	---@cast s_Flags RayCastFlags
	local s_Highest = nil
	local s_Lookahead = p_Lookahead or CHOPPER_LOOKAHEAD
	for l_Index = 1, #s_Lookahead do
		local l_Ahead = math.min(s_Lookahead[l_Index], p_Distance)
		if l_Ahead < CHOPPER_PROBE_MIN then
			break
		end
		local s_X = p_Position.x + (p_Distance > 0.0 and p_DeltaX / p_Distance * l_Ahead or 0.0)
		local s_Z = p_Position.z + (p_Distance > 0.0 and p_DeltaZ / p_Distance * l_Ahead or 0.0)
		local s_Hit = RaycastManager:CollisionRaycast(Vec3(s_X, p_Position.y + CHOPPER_PROBE_ABOVE, s_Z),
			Vec3(s_X, p_Position.y - CHOPPER_PROBE_DEPTH, s_Z), 1, 0, s_Flags)[1]
		if s_Hit ~= nil and (s_Highest == nil or s_Hit.position.y > s_Highest) then
			s_Highest = s_Hit.position.y
		end
	end
	p_Bot._GroundAhead = s_Highest
	return s_Highest
end

function VehicleChopperControl:UpdateTargetMovementChopper(p_Bot)
	local s_Vehicle = p_Bot._TargetPoint and p_Bot.m_Player.controlledControllable
	if not s_Vehicle then
		return
	end
	local s_VehiclePos = s_Vehicle.transform.trans
	local s_TargetPos = p_Bot._TargetPoint.Position
	local s_DifferenceY = s_TargetPos.z - s_VehiclePos.z
	local s_DifferenceX = s_TargetPos.x - s_VehiclePos.x
	local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
	p_Bot._TargetYaw = s_Yaw
end

---@param p_Bot Bot
---@param p_Attacking boolean
---@param p_DeltaTime number
function VehicleChopperControl:UpdateYawChopperPilot(p_Bot, p_Attacking, p_DeltaTime) -- only for the driver of the chopper
	-- Every access of an engine object (controlledControllable, input, trans, ...) allocates. Read each one once.
	local s_Vehicle = p_Bot.m_Player.controlledControllable
	if not s_Vehicle then
		return
	end
	local s_Input = p_Bot.m_Input

	-- Attitude straight from the axes of the transform (Euler angles couple roll and pitch at the forward tilt).
	local s_Transform = s_Vehicle.transform
	local s_Yaw, s_Current_Pitch, s_Current_Roll = m_Utilities:GetYawPitchRoll(s_Transform)

	local s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
	local s_DeltaPitch = s_Current_Pitch - p_Bot._TargetPitch

	if p_Attacking and p_Bot._TargetPitch > 0.5 then -- 30°
		p_Bot:AbortAttack()
	end

	if s_DeltaYaw > (math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw - 2 * math.pi
	elseif s_DeltaYaw < -(math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw + 2 * math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_AbsDeltaPitch = math.abs(s_DeltaPitch)

	s_Input.authoritativeAimingYaw = p_Bot._TargetYaw -- Always set yaw to let the FOV work.

	local s_TargetRangeForShooting = 0.15
	if s_AbsDeltaYaw < s_TargetRangeForShooting then
		p_Bot._FullVehicleSteering = false
		if p_Attacking and s_AbsDeltaPitch < s_TargetRangeForShooting then
			p_Bot._VehicleReadyToShoot = true
		end
	else
		p_Bot._FullVehicleSteering = true
		p_Bot._VehicleReadyToShoot = false
	end

	-- Chopper driver handling here.
	if p_Bot._VehicleWaitTimer > 0.0 then
		return
	end
	if not p_Bot._TargetPoint then
		return
	end

	-- YAW
	-- Error as target - measurement (= -s_DeltaYaw) to get the damping on the measured yaw right.
	local s_Output_Yaw = p_Bot._Pid_Drv_YawChopper:Update(-s_DeltaYaw, p_DeltaTime, s_Yaw)
	-- No backwards in chopper.
	s_Input:SetLevel(EntryInputActionEnum.EIAYaw, s_Output_Yaw)

	-- HEIGHT
	local s_VehiclePos = s_Transform.trans
	local s_Height = s_VehiclePos.y
	local s_Delta_Height = p_Bot._TargetPoint.Position.y - s_Height

	-- Attacking low over the ground, sinking fast or nose far down (also after a hit): level out and climb a while.
	local s_Ground = nil
	if p_Attacking then
		local s_Forward = s_Transform.forward
		s_Ground = self:GroundAhead(p_DeltaTime, p_Bot, s_VehiclePos, s_Forward.x * CHOPPER_ATTACK_LOOKAHEAD,
			s_Forward.z * CHOPPER_ATTACK_LOOKAHEAD, CHOPPER_ATTACK_LOOKAHEAD * math.sqrt(s_Forward.x ^ 2 + s_Forward.z ^ 2))
		if s_Ground ~= nil and s_Height - s_Ground < CHOPPER_ATTACK_CLEARANCE then
			p_Bot._ChopperRecoverTime = CHOPPER_RECOVER_TIME
		end
		-- The height target of the movement is from before the attack: at least CHOPPER_RECOVER_CLEARANCE above the
		-- ground ahead (XP3_Alborz: a damaged AH1Z, nose up, sank 3 m/s into the ground while it shot).
		if s_Ground ~= nil then
			s_Delta_Height = math.max(s_Delta_Height, s_Ground + CHOPPER_RECOVER_CLEARANCE - s_Height)
		end
	end
	if s_Current_Pitch < CHOPPER_NOSE_DOWN_MAX or PhysicsEntity(s_Vehicle).velocity.y < -CHOPPER_ATTACK_SINK then
		p_Bot._ChopperRecoverTime = CHOPPER_RECOVER_TIME
	end
	local s_Recovering = p_Bot._ChopperRecoverTime > 0.0
	if s_Recovering then
		p_Bot._ChopperRecoverTime = p_Bot._ChopperRecoverTime - p_DeltaTime
		s_Ground = s_Ground or p_Bot._GroundAhead
		if s_Ground ~= nil then
			s_Delta_Height = math.max(s_Delta_Height, s_Ground + CHOPPER_RECOVER_CLEARANCE - s_Height)
		end
		s_Delta_Height = math.max(s_Delta_Height, CHOPPER_CLIMB_FIRST)
	end

	local s_Output_Throttle = p_Bot._Pid_Drv_Height:Update(s_Delta_Height, p_DeltaTime, s_Height)
	if s_Output_Throttle > 0 then
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	else
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	end

	-- FORWARD: fly with a constant forward tilt (scaling it by the distance between points didn't work well). Far below
	-- the height it has to be at (a slope ahead, just took off): mostly up first.
	local s_Target_Tilt = s_Delta_Height > CHOPPER_CLIMB_FIRST and CHOPPER_TILT_CLIMBING or CHOPPER_TILT
	if s_Recovering then
		s_Target_Tilt = CHOPPER_RECOVER_TILT
	elseif p_Attacking then
		s_Target_Tilt = math.max(CHOPPER_ATTACK_TILT_MIN, math.min(CHOPPER_ATTACK_TILT_MAX, p_Bot._TargetPitch))
	end

	local s_Delta_Tilt = s_Target_Tilt - s_Current_Pitch
	local s_Output_Tilt = p_Bot._Pid_Drv_Tilt:Update(s_Delta_Tilt, p_DeltaTime, s_Current_Pitch)
	s_Input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output_Tilt)

	-- ROLL: bank a little into the turn, proportional to the yaw error.
	-- s_DeltaYaw > 0 → yawing left → negative roll (left side down).
	local s_Target_Roll = math.max(-0.1, math.min(0.1, -0.2 * s_DeltaYaw))
	if not p_Attacking then
		-- Close to the target point the target yaw swings around. Fade out the bank there.
		local s_TargetPos = p_Bot._TargetPoint.Position
		local s_DiffX = s_TargetPos.x - s_VehiclePos.x
		local s_DiffZ = s_TargetPos.z - s_VehiclePos.z
		local s_DistanceSquared = s_DiffX * s_DiffX + s_DiffZ * s_DiffZ
		local s_FadeDistance = 50.0
		if s_DistanceSquared < s_FadeDistance * s_FadeDistance then
			s_Target_Roll = s_Target_Roll * math.sqrt(s_DistanceSquared) / s_FadeDistance
		end
	end

	local s_Delta_Roll = s_Target_Roll - s_Current_Roll
	local s_Output_Roll = p_Bot._Pid_Drv_Roll:Update(s_Delta_Roll, p_DeltaTime, s_Current_Roll)
	s_Input:SetLevel(EntryInputActionEnum.EIARoll, s_Output_Roll)
end

if g_VehicleChopperControl == nil then
	---@type VehicleChopperControl
	g_VehicleChopperControl = VehicleChopperControl()
end

return g_VehicleChopperControl
