---@class Vehicles
Vehicles = class("Vehicles")

require('__shared/Constants/VehicleData')
---@type Logger
local m_Logger = Logger("Vehicles", Debug.Server.VEHICLES)

function Vehicles:FindOutVehicleType(p_Player)
	local s_VehicleType = VehicleTypes.NoVehicle -- no vehicle

	if p_Player.controlledControllable ~= nil and not p_Player.controlledControllable:Is("ServerSoldierEntity") then
		local s_VehicleName = VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/","")

		local s_VehicleData = VehicleData[s_VehicleName]
		if s_VehicleData ~= nil and s_VehicleData.Type ~= nil then
			s_VehicleType = s_VehicleData.Type
		end
	end

	return s_VehicleType
end

function Vehicles:GetVehicleName(p_Player)
	if p_Player.controlledControllable ~= nil and not p_Player.controlledControllable:Is("ServerSoldierEntity") then
		return VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/","")
	else
		return nil
	end
end

function Vehicles:GetVehicle(p_Player, p_Index)
	local s_VehicleName = self:GetVehicleName(p_Player)
	m_Logger:Write("s_VehicleName")
	if s_VehicleName == nil then
		return nil
	end
	return VehicleData[s_VehicleName]
end

function Vehicles:GetVehicleByEntity(p_Entity)
	local s_VehicleName = nil
	if p_Entity ~= nil then
		s_VehicleName = VehicleEntityData(p_Entity.data).controllableType:gsub(".+/.+/","")
	end
	if s_VehicleName == nil then
		return nil
	end
	local s_VehicleData = VehicleData[s_VehicleName]
	if s_VehicleData == nil then
		m_Logger:Warning(s_VehicleName.." not found")
	end
	return s_VehicleData
end

function Vehicles:GetNrOfFreeSeats(p_Entity, p_PlayerIsDriver)
	local s_NrOfFreeSeats = 0
	local s_MaxEntries = p_Entity.entryCount
	-- keep one seat free, if enough available
	if not p_PlayerIsDriver and s_MaxEntries > 2 then
		s_MaxEntries = s_MaxEntries -1
	end

	for i = 0, s_MaxEntries - 1 do
		if p_Entity:GetPlayerInEntry(i) == nil then
			s_NrOfFreeSeats = s_NrOfFreeSeats + 1
		end
	end
	return s_NrOfFreeSeats
end

function Vehicles:GetPartIdForSeat(p_VehicleData, p_Index)
	if p_VehicleData ~= nil and p_VehicleData.Parts ~= nil then
		return p_VehicleData.Parts[p_Index + 1]
	else
		return nil
	end
end

function Vehicles:IsVehicleType(p_VehicleData, p_VehicleType)
	if p_VehicleData ~= nil and p_VehicleData.Type ~= nil then
		return p_VehicleData.Type == p_VehicleType
	else
		return false
	end
end

function Vehicles:IsNotVehicleType(p_VehicleData, p_VehicleType)
	if p_VehicleData ~= nil and p_VehicleData.Type ~= nil then
		return p_VehicleData.Type ~= p_VehicleType
	else
		return false
	end
end

function Vehicles:GetSpeedAndDrop(p_VehicleData, p_Index)
	local s_Drop = nil
	local s_Speed = nil

	if p_VehicleData ~= nil and p_VehicleData.Speed ~= nil then
		s_Speed = p_VehicleData.Speed[p_Index + 1]
	end
	if p_VehicleData ~= nil and p_VehicleData.Drop ~= nil then
		s_Drop = p_VehicleData.Drop[p_Index + 1]
	end
	if s_Speed == nil then
		s_Speed = 500
	end
	if s_Drop == nil then
		s_Drop = 9.81
	end

	return s_Speed, s_Drop
end


function Vehicles:CheckForVehicleAttack(p_VehicleType, p_Distance, p_Gadget, p_InVehicle)
	local s_AttackMode = VehicleAttackModes.NoAttack -- no attack

	if p_VehicleType == VehicleTypes.MavBot then
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with rifle
	elseif p_VehicleType == VehicleTypes.NoArmorVehicle then
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with rifle
	elseif p_VehicleType == VehicleTypes.Chopper then --don't attack planes. Too fast...
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with rifle
	elseif (p_VehicleType == VehicleTypes.LightVehicle or p_VehicleType == VehicleTypes.AntiAir) and p_Distance < 35 then
		s_AttackMode = VehicleAttackModes.AttackWithNade -- attack with grenade
	end

	if p_VehicleType ~= VehicleTypes.MavBot then -- MAV or EOD always with rifle
		if p_Gadget ~= nil and p_Gadget.type == WeaponTypes.Rocket then
			s_AttackMode = VehicleAttackModes.AttackWithRocket -- always use rocket if possible
		elseif p_Gadget ~= nil and p_Gadget.type == WeaponTypes.C4 and p_Distance < 25 then
			if p_VehicleType ~= VehicleTypes.Chopper and p_VehicleType ~= VehicleTypes.Plane then -- no air vehicles
				s_AttackMode = VehicleAttackModes.AttackWithC4 -- always use c4 if possible
			end
		end
	end

	if p_InVehicle then
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with main-weapon
	end

	return s_AttackMode
end

if g_Vehicles == nil then
	---@type Vehicles
	g_Vehicles = Vehicles()
end

return g_Vehicles
