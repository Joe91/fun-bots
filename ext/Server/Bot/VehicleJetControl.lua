---@class VehicleJetControl
---@overload fun():VehicleJetControl
VehicleJetControl = class('VehicleJetControl')

---@type Vehicles

---@type Utilities
local m_Utilities = require('__shared/Utilities')

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

	local s_TargetPosition = g_GameDirector:GetActiveTargetPointPosition(p_Bot.m_Player.teamId,
		p_Bot.m_Player.controlledControllable and p_Bot.m_Player.controlledControllable.transform.trans):Clone()
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

	local s_DeltaYaw, s_DeltaPitch = 0, 0
	if p_Attacking then
		s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(s_Transform, p_Bot._AttackPosition)
		local s_Height = s_Transform.trans.y
		if s_Height > p_Bot._TargetPoint.Position.y + 120 then
			p_Bot._JetTakeoffActive = false
			p_Bot:AbortAttack()
		elseif s_Height < p_Bot._TargetPoint.Position.y - 75 then
			p_Bot._JetTakeoffActive = false
			p_Bot:AbortAttack()
		end
	else
		s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(s_Transform, p_Bot._TargetPoint.Position)
	end

	-- Roll
	s_Input:SetLevel(EntryInputActionEnum.EIARoll, -3 * s_DeltaYaw) -- Roll into the turn.

	-- TILT
	s_Input:SetLevel(EntryInputActionEnum.EIAPitch, 3 * s_DeltaPitch)

	-- YAW
	-- No backwards in planes. s_DeltaYaw > 0 → target on the left → negative yaw-input (same convention as chopper / ground).
	s_Input:SetLevel(EntryInputActionEnum.EIAYaw, -s_DeltaYaw)

	-- Throttle.
	-- Target velocity == 313 km/h → 86.9444 m/s
	local s_Delta_Speed = 86.9444 - PhysicsEntity(s_Vehicle).velocity.magnitude
	local s_Output_Throttle = p_Bot._Pid_Drv_Throttle:Update(s_Delta_Speed, p_DeltaTime)
	if s_Output_Throttle > 0 then
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
	else
		s_Input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
		s_Input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
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
