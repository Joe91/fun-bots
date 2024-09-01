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
function AirTargets:GetTarget(p_Player, p_MaxDistance)
	local s_Team = p_Player.teamId
	local s_ClosestDistance = nil
	local s_ClosestTarget = nil
	local s_ClosestTarget2 = nil
	local s_ClosestTarget3 = nil

	for _, l_Target in pairs(self._Targets) do
		local s_TargetPlayer = PlayerManager:GetPlayerByName(l_Target)

		if s_TargetPlayer ~= nil and s_TargetPlayer.teamId ~= s_Team and s_TargetPlayer.soldier ~= nil then
			local s_CurrentDistance = p_Player.controlledControllable.transform.trans:Distance(s_TargetPlayer.controlledControllable
				.transform.trans)

			if s_ClosestDistance == nil then
				if s_CurrentDistance < p_MaxDistance then
					s_ClosestDistance = s_CurrentDistance
					s_ClosestTarget = s_TargetPlayer
				end
			else
				if s_CurrentDistance < s_ClosestDistance then
					s_ClosestDistance = s_CurrentDistance
					s_ClosestTarget3 = s_ClosestTarget2
					s_ClosestTarget2 = s_ClosestTarget
					s_ClosestTarget = s_TargetPlayer
				end
			end
		end
	end

	local s_RandomValue = MathUtils:GetRandomInt(0, 100)
	if s_ClosestTarget3 and s_RandomValue <= Registry.VEHICLES.VEHICLE_PROPABILITY_THIRD_AIRTARGET then
		return s_ClosestTarget3
	end
	if s_ClosestTarget2 and s_RandomValue <= Registry.VEHICLES.VEHICLE_PROPABILITY_SECOND_AIRTARGET then
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
		if s_Vehicle and m_Vehicles:IsAirVehicle(s_Vehicle) then
			table.insert(self._Targets, p_Player.name)
		end
	end
end

---@param p_Player Player
function AirTargets:_RemoveTarget(p_Player)
	for l_Index, l_Target in pairs(self._Targets) do
		if l_Target == p_Player.name then
			table.remove(self._Targets, l_Index)
			break
		end
	end
end

if g_AirTargets == nil then
	---@type AirTargets
	g_AirTargets = AirTargets()
end

return g_AirTargets
