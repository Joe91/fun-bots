---@class VehicleChopperControl
---@overload fun():VehicleChopperControl
VehicleChopperControl = class('VehicleChopperControl')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles

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

	local s_TargetPoint = g_GameDirector:GetActiveTargetPointPosition(p_Bot.m_Player.teamId,
		p_Bot.m_Player.controlledControllable and p_Bot.m_Player.controlledControllable.transform.trans):Clone()
	s_TargetPoint.y = s_TargetPoint.y + Registry.VEHICLES.CHOPPER_TARGET_HEIGHT
	if (p_Bot.m_Player.teamId % 2) == 1 then
		s_TargetPoint.z = s_TargetPoint.z + 20
	else
		s_TargetPoint.z = s_TargetPoint.z - 20
	end

	-- don't move along paths with planes
	local s_Waypoint = {
		Position = s_TargetPoint,
	}
	p_Bot._TargetPoint = s_Waypoint
end

function VehicleChopperControl:UpdateTargetMovementChopper(p_Bot)
	if not p_Bot._TargetPoint or not p_Bot.m_Player.controlledControllable then
		return
	end
	local s_DifferenceY = p_Bot._TargetPoint.Position.z - p_Bot.m_Player.controlledControllable.transform.trans.z
	local s_DifferenceX = p_Bot._TargetPoint.Position.x - p_Bot.m_Player.controlledControllable.transform.trans.x
	local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
	p_Bot._TargetYaw = s_Yaw
end

---@param p_Bot Bot
---@param p_Attacking boolean
---@param p_DeltaTime number
function VehicleChopperControl:UpdateYawChopperPilot(p_Bot, p_Attacking, p_DeltaTime) -- only for the driver of the chopper
	if not p_Bot.m_Player.controlledControllable then
		return
	end

	-- Attitude straight from the axes of the transform (Euler angles couple roll and pitch at the forward tilt).
	local s_Transform = p_Bot.m_Player.controlledControllable.transform
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

	p_Bot.m_Player.input.authoritativeAimingYaw = p_Bot._TargetYaw -- Always set yaw to let the FOV work.

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
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, s_Output_Yaw)

	-- HEIGHT
	local s_Height = s_Transform.trans.y
	local s_Delta_Height = p_Bot._TargetPoint.Position.y - s_Height

	local s_Output_Throttle = p_Bot._Pid_Drv_Height:Update(s_Delta_Height, p_DeltaTime, s_Height)
	if s_Output_Throttle > 0 then
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	else
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	end

	-- FORWARD: fly with a constant forward tilt (scaling it by the distance between points didn't work well).
	local s_Target_Tilt = -0.35 -- = 20°
	if p_Attacking then
		s_Target_Tilt = p_Bot._TargetPitch
	end

	local s_Delta_Tilt = s_Target_Tilt - s_Current_Pitch
	local s_Output_Tilt = p_Bot._Pid_Drv_Tilt:Update(s_Delta_Tilt, p_DeltaTime, s_Current_Pitch)
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output_Tilt)

	-- ROLL: bank a little into the turn, proportional to the yaw error.
	-- s_DeltaYaw > 0 → yawing left → negative roll (left side down).
	local s_Target_Roll = math.max(-0.1, math.min(0.1, -0.2 * s_DeltaYaw))
	if not p_Attacking then
		-- Close to the target point the target yaw swings around. Fade out the bank there.
		local s_DiffX = p_Bot._TargetPoint.Position.x - s_Transform.trans.x
		local s_DiffZ = p_Bot._TargetPoint.Position.z - s_Transform.trans.z
		local s_DistanceSquared = s_DiffX * s_DiffX + s_DiffZ * s_DiffZ
		local s_FadeDistance = 50.0
		if s_DistanceSquared < s_FadeDistance * s_FadeDistance then
			s_Target_Roll = s_Target_Roll * math.sqrt(s_DistanceSquared) / s_FadeDistance
		end
	end

	local s_Delta_Roll = s_Target_Roll - s_Current_Roll
	local s_Output_Roll = p_Bot._Pid_Drv_Roll:Update(s_Delta_Roll, p_DeltaTime, s_Current_Roll)
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, s_Output_Roll)
end

if g_VehicleChopperControl == nil then
	---@type VehicleChopperControl
	g_VehicleChopperControl = VehicleChopperControl()
end

return g_VehicleChopperControl
