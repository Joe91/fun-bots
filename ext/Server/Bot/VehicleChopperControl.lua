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
	-- if p_Bot._VehicleWaitTimer > 0.0 then
	-- 	p_Bot._VehicleWaitTimer = p_Bot._VehicleWaitTimer - p_DeltaTime
	-- 	if p_Bot._VehicleWaitTimer <= 0.0 then
	-- 		-- Check for other plane in front of bot.
	-- 		local s_IsInfront = false
	-- 		for l_Index = 1, #g_GameDirector:GetSpawnableVehicle(p_Bot.m_Player.teamId) do
	-- 			local l_Jet = g_GameDirector:GetSpawnableVehicle(p_Bot.m_Player.teamId)[l_Index]
	-- 			local s_DistanceToJet = p_Bot.m_Player.controlledControllable.transform.trans:Distance(l_Jet.transform.trans)
	-- 			if s_DistanceToJet < 30 then
	-- 				local s_CompPos = p_Bot.m_Player.controlledControllable.transform.trans +
	-- 					p_Bot.m_Player.controlledControllable.transform.forward * s_DistanceToJet
	-- 				if l_Jet.transform.trans:Distance(s_CompPos) < 10 then
	-- 					s_IsInfront = true
	-- 				end
	-- 			end
	-- 		end
	-- 		if s_IsInfront then
	-- 			p_Bot._VehicleWaitTimer = 5.0 -- One more cycle.
	-- 			return
	-- 		end

	-- 		g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.controlledControllable.transform.trans, false)
	-- 	else
	-- 		return
	-- 	end
	-- end



	-- p_Bot._JetMidPosition = g_GameDirector._MidMapPoint:Clone()
	-- p_Bot._JetMidPosition.y = p_Bot._JetMidPosition.y + Registry.VEHICLES.JET_TARGET_HEIGHT
	-- if (p_Bot.m_Player.teamId % 2) == 1 then
	-- 	p_Bot._JetMidPosition.z = p_Bot._JetMidPosition.z + 100
	-- else
	-- 	p_Bot._JetMidPosition.z = p_Bot._JetMidPosition.z - 100
	-- end

	-- if p_Bot._VehicleTakeoffTimer > 0.0 then
	-- 	p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - p_DeltaTime
	-- 	if p_Bot._JetTakeoffActive or
	-- 		(p_Bot._JetAbortAttackActive and (p_Bot.m_Player.controlledControllable.transform.trans.y < (p_Bot._JetMidPosition.y - 45)))
	-- 	then
	-- 		local s_TargetPosition = p_Bot.m_Player.controlledControllable.transform.trans:Clone()
	-- 		local s_Forward = p_Bot.m_Player.controlledControllable.transform.forward:Clone()
	-- 		s_Forward.y = 0
	-- 		s_Forward:Normalize()
	-- 		s_TargetPosition = s_TargetPosition + (s_Forward * 70)
	-- 		s_TargetPosition.y = s_TargetPosition.y + 70
	-- 		local s_Waypoint = {
	-- 			Position = s_TargetPosition,
	-- 		}
	-- 		p_Bot._TargetPoint = s_Waypoint
	-- 		return
	-- 	elseif p_Bot._JetAbortAttackActive then
	-- 		-- don't move along paths with planes
	-- 		local s_Waypoint = {
	-- 			Position = p_Bot._JetMidPosition,
	-- 		}
	-- 		p_Bot._TargetPoint = s_Waypoint
	-- 		return
	-- 	end
	-- end

	-- p_Bot._JetTakeoffActive = false
	-- p_Bot._JetAbortAttackActive = false

	-- -- don't move along paths with planes
	-- local s_Waypoint = {
	-- 	Position = p_Bot._JetMidPosition,
	-- }
	-- p_Bot._TargetPoint = s_Waypoint
end

function VehicleChopperControl:UpdateTargetMovementChopper(p_Bot)
	local s_TargetPoint = g_GameDirector:GetActiveTargetPointPosition(p_Bot.m_Player.teamId)
	s_TargetPoint.y = s_TargetPoint.y + Registry.VEHICLES.CHOPPER_TARGET_HEIGHT
	if (p_Bot.m_Player.teamId % 2) == 1 then
		s_TargetPoint.z = s_TargetPoint.z + 20
	else
		s_TargetPoint.z = s_TargetPoint.z - 20
	end

	local s_DifferenceY = s_TargetPoint.z - p_Bot.m_Player.controlledControllable.transform.trans.z
	local s_DifferenceX = s_TargetPoint.x - p_Bot.m_Player.controlledControllable.transform.trans.x
	local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
	p_Bot._TargetYaw = s_Yaw
	p_Bot._TargetYawMovementVehicle = s_Yaw
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
	if p_Bot.m_Player.controlledEntryId == 0 then
		if p_Bot._VehicleWaitTimer > 0.0 then
			return
		end
		if not p_Attacking and (p_Bot._TargetPoint == nil or p_Bot._NextTargetPoint == nil) then
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
		if p_Attacking then
			s_Delta_Height = p_Bot._TargetHeightAttack - p_Bot.m_Player.controlledControllable.transform.trans.y
		else
			p_Bot._TargetHeightAttack = p_Bot._TargetPoint.Position.y
			s_Delta_Height = p_Bot._TargetPoint.Position.y - p_Bot.m_Player.controlledControllable.transform.trans.y
		end
		local s_Output_Throttle = p_Bot._Pid_Drv_Throttle:Update(s_Delta_Height)
		if s_Output_Throttle > 0 then
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
		else
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
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
end

if g_VehicleChopperControl == nil then
	---@type VehicleChopperControl
	g_VehicleChopperControl = VehicleChopperControl()
end

return g_VehicleChopperControl
