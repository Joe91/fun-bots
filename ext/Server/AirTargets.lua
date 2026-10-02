---@class AirTargets
---@overload fun():AirTargets
AirTargets = class('AirTargets')
---@type Vehicles
local m_Vehicles = require('Vehicles')

function AirTargets:__init()
	self._Targets = {}
end

-- EVENTS
function AirTargets:OnLevelLoaded()
	self._Targets = {}
end

---VEXT Shared Level:Destroy Event
function AirTargets:OnLevelDestroy()
	self._Targets = {}
end

---VEXT Server Vehicle:Enter Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Player Player
function AirTargets:OnVehicleEnter(p_VehicleEntity, p_Player)
	self:_CreateTarget(p_Player)
end

---VEXT Server Vehicle:Exit Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Player Player
function AirTargets:OnVehicleExit(p_VehicleEntity, p_Player)
	self:_RemoveTarget(p_Player)
end

---VEXT Server Player:Killed Event
---@param p_Player Player
function AirTargets:OnPlayerKilled(p_Player)
	self:_RemoveTarget(p_Player)
end

---VEXT Server Player:Destroyed Event
---@param p_Player Player
function AirTargets:OnPlayerDestroyed(p_Player)
	self:_RemoveTarget(p_Player)
end

-- Public functions
---@param p_Player Player
---@param p_MaxDistance number
---@param p_AnglePenalty number|nil metres added to the distance per radian the target is away from the nose (prefer targets in front)
function AirTargets:GetTarget(p_Player, p_MaxDistance, p_AnglePenalty)
	local s_Team = p_Player.teamId
	-- The three best targets, sorted.
	local s_ClosestDistance, s_ClosestDistance2, s_ClosestDistance3 = nil, nil, nil
	local s_ClosestTarget = nil
	local s_ClosestTarget2 = nil
	local s_ClosestTarget3 = nil

	local s_OwnTransform = p_Player.controlledControllable.transform
	local s_OwnPos = s_OwnTransform.trans
	local s_Forward = s_OwnTransform.forward

	for l_Index = 1, #self._Targets do
		local l_Target = self._Targets[l_Index]
		local s_TargetPlayer = PlayerManager:GetPlayerById(l_Target)

		if s_TargetPlayer ~= nil and s_TargetPlayer.teamId ~= s_Team and s_TargetPlayer.soldier ~= nil
			and s_TargetPlayer.controlledControllable ~= nil then
			local s_TargetPos = s_TargetPlayer.controlledControllable.transform.trans
			local s_RealDistance = s_OwnPos:Distance(s_TargetPos)
			local s_CurrentDistance = s_RealDistance

			if p_AnglePenalty and p_AnglePenalty > 0 and s_RealDistance > 0 then
				local s_Dot = (s_Forward.x * (s_TargetPos.x - s_OwnPos.x) + s_Forward.y * (s_TargetPos.y - s_OwnPos.y)
					+ s_Forward.z * (s_TargetPos.z - s_OwnPos.z)) / s_RealDistance
				s_CurrentDistance = s_RealDistance + p_AnglePenalty * math.acos(math.max(-1.0, math.min(1.0, s_Dot)))
			end

			if s_RealDistance < p_MaxDistance then
				if s_ClosestDistance == nil or s_CurrentDistance < s_ClosestDistance then
					s_ClosestDistance3, s_ClosestTarget3 = s_ClosestDistance2, s_ClosestTarget2
					s_ClosestDistance2, s_ClosestTarget2 = s_ClosestDistance, s_ClosestTarget
					s_ClosestDistance, s_ClosestTarget = s_CurrentDistance, s_TargetPlayer
				elseif s_ClosestDistance2 == nil or s_CurrentDistance < s_ClosestDistance2 then
					s_ClosestDistance3, s_ClosestTarget3 = s_ClosestDistance2, s_ClosestTarget2
					s_ClosestDistance2, s_ClosestTarget2 = s_CurrentDistance, s_TargetPlayer
				elseif s_ClosestDistance3 == nil or s_CurrentDistance < s_ClosestDistance3 then
					s_ClosestDistance3, s_ClosestTarget3 = s_CurrentDistance, s_TargetPlayer
				end
			end
		end
	end

	local s_RandomValue = MathUtils:GetRandomInt(0, 100)
	if s_ClosestTarget3 and s_RandomValue <= Registry.VEHICLES.VEHICLE_PROBABILITY_THIRD_AIRTARGET then
		return s_ClosestTarget3
	end
	if s_ClosestTarget2 and s_RandomValue <= Registry.VEHICLES.VEHICLE_PROBABILITY_SECOND_AIRTARGET then
		return s_ClosestTarget2
	end

	return s_ClosestTarget
end

-- Private functions
---comment
---@param p_Player Player
function AirTargets:_CreateTarget(p_Player)
	if p_Player.controlledEntryId == 0 then
		local s_Vehicle = m_Vehicles:GetVehicle(p_Player)
		-- Enter can fire without a matching exit (e.g. seat changes). Never add a player twice.
		if s_Vehicle and m_Vehicles:IsAirVehicle(s_Vehicle) and not table.has(self._Targets, p_Player.id) then
			self._Targets[#self._Targets + 1] = p_Player.id
		end
	end
end

---@param p_Player Player
function AirTargets:_RemoveTarget(p_Player)
	for l_Index = #self._Targets, 1, -1 do
		if self._Targets[l_Index] == p_Player.id then
			table.remove(self._Targets, l_Index)
		end
	end
end

---@return integer
function AirTargets:GetTargetCount()
	return #self._Targets
end

if g_AirTargets == nil then
	---@type AirTargets
	g_AirTargets = AirTargets()
end

return g_AirTargets
