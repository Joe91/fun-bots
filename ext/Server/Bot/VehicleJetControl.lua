---@class VehicleJetControl
---@overload fun():VehicleJetControl
VehicleJetControl = class('VehicleJetControl')

---@type Vehicles
local m_Vehicles = require('Vehicles')

function VehicleJetControl:__init()
	-- Nothing to do.
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
					local s_CompPos = p_Bot.m_Player.controlledControllable.transform.trans +
						p_Bot.m_Player.controlledControllable.transform.forward * s_DistanceToJet
					if l_Jet.transform.trans:Distance(s_CompPos) < 10 then
						s_IsInfront = true
					end
				end
			end
			if s_IsInfront then
				p_Bot._VehicleWaitTimer = 5.0 -- One more cycle.
				return
			end

			g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.controlledControllable.transform.trans, false)
		else
			return
		end
	end

	local s_TargetPosition = g_GameDirector:GetActiveTargetPointPosition(p_Bot.m_Player.teamId):Clone()
	if Globals.IsAirSuperiority then
		s_TargetPosition.y = s_TargetPosition.y + 0 -- no offset
	else
		s_TargetPosition.y = s_TargetPosition.y + Registry.VEHICLES.JET_TARGET_HEIGHT
	end
	if (p_Bot.m_Player.teamId % 2) == 1 then
		s_TargetPosition.z = s_TargetPosition.z + 100
	else
		s_TargetPosition.z = s_TargetPosition.z - 100
	end

	if p_Bot._VehicleTakeoffTimer > 0.0 then
		p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - p_DeltaTime
		if p_Bot._JetTakeoffActive or
			(p_Bot._JetAbortAttackActive and (p_Bot.m_Player.controlledControllable.transform.trans.y < (s_TargetPosition.y - 45)))
		then
			local s_TargetPosition = p_Bot.m_Player.controlledControllable.transform.trans:Clone()
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
			-- don't move along paths with planes
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
	-- Vector from start point to target point
	local toTarget = targetPoint - p_Transform.trans

	-- Normalize the vectors
	local normalizedDirection = p_Transform.forward
	local normalizedToTarget = toTarget:Normalize()

	-- Calculate the dot product
	local dotProduct = normalizedDirection:Dot(normalizedToTarget)

	-- Calculate the angle between the vectors - not needed
	-- local angle = math.acos(dotProduct)

	-- Calculate the cross product to determine the sign of the angle
	local crossProduct = normalizedDirection:Cross(normalizedToTarget)

	-- Calculate yaw deviation relative to the orientation
	local yawDeviation = math.atan(crossProduct:Dot(p_Transform.up), dotProduct)

	-- Calculate pitch deviation relative to the orientation
	local pitchDeviation = math.asin(crossProduct:Dot(p_Transform.left))

	return yawDeviation, pitchDeviation
end

---@param p_Bot Bot
---@param p_Attacking boolean
function VehicleJetControl:UpdateYawJet(p_Bot, p_Attacking)
	local s_DeltaYaw, s_DeltaPitch = 0, 0

	if p_Attacking then
		-- print({ p_Bot._AttackPosition, p_Bot.m_Player.controlledControllable.transform.trans })
		s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(p_Bot.m_Player.controlledControllable.transform:Clone(), p_Bot._AttackPosition)
		if p_Bot.m_Player.controlledControllable.transform.trans.y > p_Bot._TargetPoint.Position.y + 120 then
			p_Bot._JetTakeoffActive = false
			p_Bot:AbortAttack()
		elseif p_Bot.m_Player.controlledControllable.transform.trans.y < p_Bot._TargetPoint.Position.y - 75 then
			p_Bot._JetTakeoffActive = false
			p_Bot:AbortAttack()
		end
	elseif p_Bot._TargetPoint then
		s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(p_Bot.m_Player.controlledControllable.transform:Clone(), p_Bot._TargetPoint.Position)
	end

	-- local s_FacingDown = p_Bot.m_Player.controlledControllable.transform.forward.y < 0.2
	-- local s_FacingUp = p_Bot.m_Player.controlledControllable.transform.forward.y > 0.2
	-- local s_IsUpwards = p_Bot.m_Player.controlledControllable.transform.up.y > 0.0
	-- local s_IsBelowTarget = p_Bot.m_Player.controlledControllable.transform.up.y < s_TargetPosition.y
	-- if s_FacingDown then
	-- 	if math.abs(s_DeltaPitch) > math.pi / 2 then
	-- 		if s_IsBelowTarget then
	-- 			if s_IsUpwards and s_DeltaPitch < 0 then
	-- 				s_DeltaPitch = 2 * math.pi + s_DeltaPitch
	-- 			elseif not s_IsUpwards and s_DeltaPitch > 0 then
	-- 				s_DeltaPitch = -2 * math.pi + s_DeltaPitch
	-- 			end
	-- 		else
	-- 			if s_IsUpwards and s_DeltaPitch > 0 then
	-- 				s_DeltaPitch = -2 * math.pi + s_DeltaPitch
	-- 			elseif not s_IsUpwards and s_DeltaPitch < 0 then
	-- 				s_DeltaPitch = 2 * math.pi + s_DeltaPitch
	-- 			end
	-- 		end
	-- 	end
	-- end

	-- local s_Euler = p_Bot.m_Player.controlledControllable.transform:ToQuatTransform(false).rotation:ToEuler()
	-- local s_Roll = s_Euler.y

	-- s_Roll = s_Roll + math.pi

	-- local s_TargetRoll = math.pi
	-- local s_DelateRoll = s_TargetRoll - s_Roll

	-- Roll
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -3 * s_DeltaYaw) -- Use delta-yaw for this? s_DeltaRoll

	-- TILT
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, 3 * s_DeltaPitch)

	-- YAW
	-- No backwards in planes.
	p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, s_DeltaYaw)

	-- Throttle.
	-- Target velocity == 313 km/h → 86.9444 m/s
	local s_Delta_Speed = 86.9444 - PhysicsEntity(p_Bot.m_Player.controlledControllable).velocity.magnitude
	local s_Output_Throttle = p_Bot._Pid_Drv_Throttle:Update(s_Delta_Speed)
	if s_Output_Throttle > 0 then
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	else
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
	end

	if p_Attacking and math.abs(s_DeltaYaw) < 0.2 and math.abs(s_DeltaPitch) < 0.2 then
		p_Bot._VehicleReadyToShoot = true
	else
		p_Bot._VehicleReadyToShoot = false
	end
end

if g_VehicleJetControl == nil then
	---@type VehicleJetControl
	g_VehicleJetControl = VehicleJetControl()
end

return g_VehicleJetControl
