---@class VehicleChopperControl
---@overload fun():VehicleChopperControl
VehicleChopperControl = class('VehicleChopperControl')

---@type Vehicles
local m_Vehicles = require('Vehicles')

function VehicleChopperControl:__init()
	-- Nothing to do.
end

---@param p_DeltaTime number
---@param p_Bot Bot
function VehicleChopperControl:UpdateMovementChopper(p_DeltaTime, p_Bot)
	if p_Bot._VehicleWaitTimer > 0.0 then
		p_Bot._VehicleWaitTimer = p_Bot._VehicleWaitTimer - p_DeltaTime
		if p_Bot._VehicleWaitTimer <= 0.0 then
			g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.controlledControllable.transform.trans, false)
		else
			return
		end
	end

	if p_Bot._VehicleTakeoffTimer > 0.0 then
		p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - p_DeltaTime
	end

	local s_TargetPoint = g_GameDirector:GetActiveTargetPointPosition(p_Bot.m_Player.teamId):Clone()
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
	if not p_Bot._TargetPoint then
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
function VehicleChopperControl:UpdateYawChopperPilot(p_Bot, p_Attacking) -- only for the driver of the chopper
	local s_DeltaYaw = 0
	local s_DeltaPitch = 0
	local s_Current_Roll = 0
	local s_Current_Pitch = 0

	if not p_Attacking then
		local s_Euler = p_Bot.m_Player.controlledControllable.transform:ToQuatTransform(false).rotation:ToEuler()
		local s_Yaw = -s_Euler.x
		local s_Roll = s_Euler.y
		local s_Pitch = -s_Euler.z / math.cos(s_Roll)

		s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
		s_DeltaPitch = s_Pitch - p_Bot._TargetPitch
		s_Current_Roll = s_Roll
		s_Current_Pitch = s_Pitch
	else
		local s_Euler = p_Bot.m_Player.controlledControllable.transform:ToQuatTransform(false).rotation:ToEuler()

		local s_Yaw = -s_Euler.x
		local s_Roll = s_Euler.y
		local s_Pitch = -s_Euler.z / math.cos(s_Roll)

		s_DeltaPitch = s_Pitch - p_Bot._TargetPitch
		s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
		s_Current_Roll = s_Roll
		s_Current_Pitch = s_Pitch

		if p_Bot._TargetPitch > 0.5 then -- 30°
			p_Bot:AbortAttack()
		end
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
	if p_Bot.m_Player.controlledControllable == nil then
		return
	end

	-- YAW
	local s_Output_Yaw = p_Bot._Pid_Drv_Yaw:Update(s_DeltaYaw)
	-- No backwards in chopper.
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output_Yaw)

	-- HEIGHT
	local s_Delta_Height = 0.0

	s_Delta_Height = p_Bot._TargetPoint.Position.y - p_Bot.m_Player.controlledControllable.transform.trans.y

	local s_Output_Throttle = p_Bot._Pid_Drv_Throttle:Update(s_Delta_Height)
	if s_Output_Throttle > 0 then
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	else
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	end

	-- FORWARD (depending on speed).
	-- A: use distance horizontally between points for speed-value → not that good for that.
	-- local DeltaX = p_Bot._NextTargetPoint.Position.x - p_Bot._TargetPoint.Position.x
	-- local DeltaZ = p_Bot._NextTargetPoint.Position.z - p_Bot._TargetPoint.Position.z
	-- local Distance = math.sqrt(DeltaX*DeltaX + DeltaZ*DeltaZ)
	-- B: just fly with constant speed →

	local s_Delta_Tilt = 0
	if p_Attacking then
		s_Delta_Tilt = -s_DeltaPitch
	else
		local s_Tartget_Tilt = -0.35 -- = 20°
		s_Delta_Tilt = s_Tartget_Tilt - s_Current_Pitch
	end

	local s_Output_Tilt = p_Bot._Pid_Drv_Tilt:Update(s_Delta_Tilt)
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output_Tilt)

	-- ROLL (keep it zero).
	local s_Tartget_Roll = 0.0
	-- To-do: in strong steering: Roll a little?
	if p_Bot._FullVehicleSteering then
		if s_AbsDeltaYaw > 0 then
			s_Tartget_Roll = 0.1
		else
			s_Tartget_Roll = -0.1
		end
	end

	local s_Delta_Roll = s_Tartget_Roll - s_Current_Roll
	local s_Output_Roll = p_Bot._Pid_Drv_Roll:Update(s_Delta_Roll)
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, s_Output_Roll)
end

if g_VehicleChopperControl == nil then
	---@type VehicleChopperControl
	g_VehicleChopperControl = VehicleChopperControl()
end

return g_VehicleChopperControl
