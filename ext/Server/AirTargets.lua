class('AirTargets')

local m_Utilities = require('__shared/Utilities')
local m_Vehicles = require("Vehicles")
local m_Logger = Logger("BotManager", Debug.Server.BOT)


function AirTargets:__init()
	self._Targets = {}
end

-- EVENTS
function AirTargets:OnLevelLoaded()
	self._Targets = {}
end

function AirTargets:OnLevelDestroy()
	self._Targets = {}
end

function AirTargets:OnVehicleEnter(p_VehicleEntiy, p_Player)
	self:_CreateTarget(p_Player)
end

function AirTargets:OnVehicleExit(p_VehicleEntiy, p_Player)
	self:_RemoveTarget(p_Player)
end

function AirTargets:OnPlayerKilled(p_Player)
    self:_RemoveTarget(p_Player)
end

function AirTargets:OnPlayerDestroyed(p_Player)
    self:_RemoveTarget(p_Player)
end

-- public functions
function AirTargets:GetTarget(p_Player)
	local s_Team = p_Player.teamId
	local s_ClosestDistance = nil
	local s_ClosestTarget = nil
	for _, l_Target in pairs(self._Targets) do
		local s_TargetPlayer = PlayerManager:GetPlayerByName(l_Target)
		if s_TargetPlayer ~= nil and (s_TargetPlayer.teamId % 2) ~= (s_Team % 2) and s_TargetPlayer.soldier ~= nil then
			local s_CurrentDistance = p_Player.controlledControllable.transform.trans:Distance(s_TargetPlayer.controlledControllable.transform.trans)
			if s_ClosestDistance == nil then
				if s_CurrentDistance < Config.MaxDistanceAABots then
					s_ClosestDistance = s_CurrentDistance
					s_ClosestTarget = s_TargetPlayer
				end
			else
				if s_CurrentDistance < s_ClosestDistance then
					s_ClosestDistance = s_CurrentDistance
					s_ClosestTarget = s_TargetPlayer
				end
			end
		end
	end
	return s_ClosestTarget
end

-- private functions

function AirTargets:_CreateTarget(p_Player)
	if p_Player.controlledEntryId == 0 then
		local s_Vehicle = m_Vehicles:GetVehicle(p_Player, 0)
		if m_Vehicles:IsVehicleType(s_Vehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(s_Vehicle, VehicleTypes.Plane) then
			table.insert(self._Targets, p_Player.name)
		end
	end
end

function AirTargets:_RemoveTarget(p_Player)
	for l_Index, l_Target in pairs(self._Targets) do
		if l_Target == p_Player.name then
			table.remove(self._Targets, l_Index)
			break
		end
	end
end


if g_AirTargets == nil then
	g_AirTargets = AirTargets()
end

return g_AirTargets