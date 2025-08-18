---@class Vehicles
---@overload fun():Vehicles
Vehicles = class("Vehicles")

require('__shared/Constants/VehicleData')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Logger
local m_Logger = Logger("Vehicles", Debug.Server.VEHICLES)

---@param p_Player Player
function Vehicles:FindOutVehicleType(p_Player)
	local s_VehicleType = VehicleTypes.NoVehicle -- No vehicle.

	if p_Player and p_Player.controlledControllable and not p_Player.controlledControllable:Is("ServerSoldierEntity") then
		local s_VehicleName = VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/", "")

		local s_VehicleData = VehicleData[s_VehicleName]
		if s_VehicleData and s_VehicleData.Type then
			s_VehicleType = s_VehicleData.Type
		end
	end

	return s_VehicleType
end

---@param p_Player Player
function Vehicles:GetVehicleName(p_Player)
	if p_Player.controlledControllable and not p_Player.controlledControllable:Is("ServerSoldierEntity") then
		return VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/", "")
	else
		return nil
	end
end

---@param p_Player Player
function Vehicles:GetVehicle(p_Player)
	local s_VehicleName = self:GetVehicleName(p_Player)
	if s_VehicleName == nil then
		return nil
	end
	m_Logger:Write("s_VehicleName: " .. s_VehicleName)
	return VehicleData[s_VehicleName]
end

---@param p_Entity ControllableEntity
function Vehicles:GetVehicleByEntity(p_Entity)
	local s_VehicleName = nil

	if p_Entity then
		s_VehicleName = VehicleEntityData(p_Entity.data).controllableType:gsub(".+/.+/", "")
	end

	if s_VehicleName == nil then
		return nil
	end

	local s_VehicleData = VehicleData[s_VehicleName]

	if s_VehicleData == nil then
		m_Logger:Warning(s_VehicleName .. " not found")
	end

	return s_VehicleData
end

---@param p_Entity ControllableEntity
---@param p_PlayerIsDriver boolean
function Vehicles:GetNrOfFreeSeats(p_Entity, p_PlayerIsDriver)
	local s_MaxEntries = p_Entity.entryCount
	local s_NrOfFreeSeats = 0
	local s_NumBotsInVehicle = 0

	if not p_Entity then
		return 0
	end

	local vehicleData = self:GetVehicle(p_Entity:GetPlayerInEntry(0))
	if not vehicleData then
		return 0
	end

	if vehicleData.Type == VehicleTypes.Gunship then
		s_MaxEntries = 2
	end
	if vehicleData.Type == VehicleTypes.MobileArtillery then
		s_MaxEntries = 1
	end
	-- The idea is to avoid the bots from seating in the 3rd slot of the tanks to be more useful somwhere else.
	if vehicleData.Type == VehicleTypes.Tank then
		s_MaxEntries = 2
	end

	if vehicleData.Type == VehicleTypes.TransportChopper then
		s_MaxEntries = 3
	end
	if vehicleData.Type == VehicleTypes.UnarmedGunship then
		return 0
	end

	if vehicleData.Type == VehicleTypes.LightAA then
		s_MaxEntries = 2
	end

	if Config.KeepVehicleSeatForPlayer and not p_PlayerIsDriver and s_MaxEntries > 2 then
		s_MaxEntries = s_MaxEntries - 1
	end

	for i = 0, s_MaxEntries - 1 do
		if p_Entity:GetPlayerInEntry(i) == nil then
			s_NrOfFreeSeats = s_NrOfFreeSeats + 1
		elseif m_Utilities:isBot(p_Entity:GetPlayerInEntry(i)) then
			s_NumBotsInVehicle = s_NumBotsInVehicle + 1
		end

		-- If we've reached the MaxBotsPerVehicle limit, stop counting free seats
		if s_NumBotsInVehicle >= Config.MaxBotsPerVehicle then
			s_NrOfFreeSeats = 0
			break
		end
	end

	-- Cap the number of free seats at MaxBotsPerVehicle - s_NumBotsInVehicle
	s_NrOfFreeSeats = math.min(s_NrOfFreeSeats, Config.MaxBotsPerVehicle - s_NumBotsInVehicle)

	return s_NrOfFreeSeats
end

---@param p_VehicleData VehicleDataInner
---@param p_Index integer
---@param p_WeaponSelection integer
function Vehicles:GetPartIdForSeat(p_VehicleData, p_Index, p_WeaponSelection)
	local s_Part = -1
	if p_VehicleData and p_VehicleData.Parts then
		local s_NewPart = nil
		if type(p_VehicleData.Parts[p_Index + 1]) == "table" then
			if p_WeaponSelection == 0 then
				s_NewPart = p_VehicleData.Parts[p_Index + 1][1]
			else
				s_NewPart = p_VehicleData.Parts[p_Index + 1][p_WeaponSelection]
			end
		else
			s_NewPart = p_VehicleData.Parts[p_Index + 1]
		end
		if s_NewPart then
			s_Part = s_NewPart
		end
	end
	return s_Part
end

---@param p_VehicleData VehicleDataInner
---@param p_Index integer
function Vehicles:IsPassengerSeat(p_VehicleData, p_Index)
	if p_VehicleData and p_VehicleData.FirstPassengerSeat then
		return p_Index >= p_VehicleData.FirstPassengerSeat - 1
	end

	-- By default all except the driver
	return p_Index > 0;
end

---@param p_VehicleData VehicleDataInner
---@param p_VehicleTerrain VehicleTerrains
function Vehicles:IsVehicleTerrain(p_VehicleData, p_VehicleTerrain)
	if p_VehicleData and p_VehicleData.Terrain then
		return p_VehicleData.Terrain == p_VehicleTerrain
	else
		return false
	end
end

---@param p_VehicleData VehicleDataInner
---@param p_VehicleTerrain VehicleTerrains
function Vehicles:IsNotVehicleTerrain(p_VehicleData, p_VehicleTerrain)
	if p_VehicleData and p_VehicleData.Terrain then
		return p_VehicleData.Terrain ~= p_VehicleTerrain
	else
		return false
	end
end

---@param p_VehicleData VehicleDataInner|nil
---@return VehicleTypes
function Vehicles:VehicleType(p_VehicleData)
	if p_VehicleData and p_VehicleData.Type then
		return p_VehicleData.Type
	end

	return VehicleTypes.NoVehicle
end

---@param p_VehicleData VehicleDataInner
---@param p_VehicleType VehicleTypes
function Vehicles:IsVehicleType(p_VehicleData, p_VehicleType)
	return self:VehicleType(p_VehicleData) == p_VehicleType
end

---@param p_VehicleData VehicleDataInner
function Vehicles:IsTransportChopper(p_VehicleData)
	return self:IsVehicleType(p_VehicleData, VehicleTypes.TransportChopper)
end

---@param p_VehicleData VehicleDataInner
function Vehicles:IsChopper(p_VehicleData)
	return self:IsVehicleType(p_VehicleData, VehicleTypes.Chopper)
		or self:IsVehicleType(p_VehicleData, VehicleTypes.ScoutChopper)
		or self:IsVehicleType(p_VehicleData, VehicleTypes.TransportChopper)
end

---@param p_VehicleData VehicleDataInner
function Vehicles:IsAirVehicle(p_VehicleData)
	return self:IsChopper(p_VehicleData)
		or self:IsVehicleType(p_VehicleData, VehicleTypes.Gunship)
		or self:IsVehicleType(p_VehicleData, VehicleTypes.Plane)
end

---@param p_VehicleData VehicleDataInner
function Vehicles:IsGunship(p_VehicleData)
	return self:IsVehicleType(p_VehicleData, VehicleTypes.Gunship)
		or self:IsVehicleType(p_VehicleData, VehicleTypes.UnarmedGunship)
end

---@param p_VehicleData VehicleDataInner
function Vehicles:IsAAVehicle(p_VehicleData)
	return self:IsVehicleType(p_VehicleData, VehicleTypes.AntiAir)
		or self:IsVehicleType(p_VehicleData, VehicleTypes.LightAA)
end

---@param p_VehicleType VehicleTypes
function Vehicles:IsAirVehicleType(p_VehicleType)
	return p_VehicleType == VehicleTypes.Chopper
		or p_VehicleType == VehicleTypes.ScoutChopper
		or p_VehicleType == VehicleTypes.Plane
		or p_VehicleType == VehicleTypes.Gunship
		or p_VehicleType == VehicleTypes.TransportChopper
end

---@param p_VehicleType VehicleTypes
function Vehicles:IsArmoredVehicleType(p_VehicleType)
	return p_VehicleType == VehicleTypes.Tank
		or p_VehicleType == VehicleTypes.IFV
		or p_VehicleType == VehicleTypes.MobileArtillery
		or p_VehicleType == VehicleTypes.LightAA
end

---@param p_VehicleType VehicleTypes
function Vehicles:IsNotVehicleType(p_VehicleData, p_VehicleType)
	if p_VehicleData and p_VehicleData.Type then
		return p_VehicleData.Type ~= p_VehicleType
	else
		return false
	end
end

---@param p_VehicleData VehicleDataInner
---@param p_Index integer
function Vehicles:GetAvailableWeaponSlots(p_VehicleData, p_Index)
	if p_VehicleData then
		if type(p_VehicleData.Parts[p_Index + 1]) == "table" then
			return #p_VehicleData.Parts[p_Index + 1]
		else
			if not p_VehicleData.Parts[p_Index + 1] or p_VehicleData.Parts[p_Index + 1] < 0 then
				return 0
			else
				return 1
			end
		end
	end
	return 0
end

---@param p_VehicleData VehicleDataInner
---@param p_Index integer
---@param p_WeaponSelection integer
function Vehicles:GetOffsets(p_VehicleData, p_Index, p_WeaponSelection)
	local s_Offset = Vec3.zero

	if p_VehicleData and p_VehicleData.Offset then
		s_Offset = p_VehicleData.Offset[p_Index + 1]
		if type(s_Offset) == "table" then
			if p_WeaponSelection ~= 0 then
				s_Offset = s_Offset[p_WeaponSelection]
			else
				s_Offset = s_Offset[1]
			end
		end
	end

	return s_Offset
end

---@param p_VehicleData VehicleDataInner
---@param p_Index integer
---@param p_WeaponSelection integer
function Vehicles:GetRotationOffsets(p_VehicleData, p_Index, p_WeaponSelection)
	local s_Offset = Vec3.zero

	if p_VehicleData and p_VehicleData.RotationOffset then
		s_Offset = p_VehicleData.RotationOffset[p_Index + 1]
		if type(s_Offset) == "table" then
			if p_WeaponSelection ~= 0 then
				s_Offset = s_Offset[p_WeaponSelection]
			else
				s_Offset = s_Offset[1]
			end
		end
	end

	return s_Offset
end

---@param p_VehicleData VehicleDataInner
---@param p_Index integer
---@param p_WeaponSelection integer
function Vehicles:GetSpeedAndDrop(p_VehicleData, p_Index, p_WeaponSelection)
	local s_Drop = nil
	local s_Speed = nil

	if p_VehicleData and p_VehicleData.Speed then
		s_Speed = p_VehicleData.Speed[p_Index + 1]
		if type(s_Speed) == "table" then
			if p_WeaponSelection ~= 0 then
				s_Speed = s_Speed[p_WeaponSelection]
			else
				s_Speed = s_Speed[1]
			end
		end
	end
	if p_VehicleData and p_VehicleData.Drop then
		s_Drop = p_VehicleData.Drop[p_Index + 1]
		if type(s_Drop) == "table" then
			if p_WeaponSelection ~= 0 then
				s_Drop = s_Drop[p_WeaponSelection]
			else
				s_Drop = s_Drop[1]
			end
		end
	end
	if s_Speed == nil then
		s_Speed = 10000
	end
	if s_Drop == nil then
		s_Drop = 0.0
	end

	return s_Speed, s_Drop
end

---@param p_VehicleType VehicleTypes
---@param p_Bot Bot
function Vehicles:CheckForVehicleAttack(p_VehicleType, p_Bot)
	local s_InVehicle = g_BotStates:IsInVehicleState(p_Bot.m_ActiveState)
	if s_InVehicle then
		return VehicleAttackModes.AttackWithRifle -- Attack with main-weapon.
	end

	local s_Distance = p_Bot._DistanceToPlayer
	local s_Gadget1 = p_Bot.m_PrimaryGadget
	local s_Gadget2 = p_Bot.m_SecondaryGadget
	local s_IsSniper = false
	if (p_Bot.m_ActiveWeapon and p_Bot.m_ActiveWeapon.type == WeaponTypes.Sniper) then
		s_IsSniper = true
	end

	local s_AttackMode = VehicleAttackModes.NoAttack -- No attack.
	if p_VehicleType == VehicleTypes.MavBot or
		p_VehicleType == VehicleTypes.NoArmorVehicle or
		p_VehicleType == VehicleTypes.StationaryLauncher or
		p_VehicleType == VehicleTypes.Gadgets then                                               -- No idea what this might be.
		s_AttackMode = VehicleAttackModes.AttackWithRifle                                        -- Attack with rifle.
	end
	if (s_IsSniper and p_VehicleType == VehicleTypes.Chopper and Config.SnipersAttackChoppers) then -- Don't attack planes. Too fast...
		if m_Utilities:CheckProbablity(Registry.BOT.PROBABILITY_ATTACK_CHOPPER_WITH_RIFLE) then
			s_AttackMode = VehicleAttackModes.AttackWithRifle                                    -- Attack with rifle.
		end
	end

	if p_VehicleType ~= VehicleTypes.MavBot then      -- MAV or EOD always with rifle.
		if s_Gadget1 and s_Gadget1.type == WeaponTypes.Rocket and p_Bot._RocketCooldownTimer <= 0 then
			s_AttackMode = VehicleAttackModes.AttackWithRocket -- Always use rocket if possible.
		elseif s_Gadget2 and s_Gadget2.type == WeaponTypes.C4 and s_Distance < 25 then
			if not self:IsAirVehicleType(p_VehicleType) then
				s_AttackMode = VehicleAttackModes.AttackWithC4 -- Always use C4 if possible.
			end
		elseif s_Gadget1 and s_Gadget1.type == WeaponTypes.MissileAir and p_Bot._RocketCooldownTimer <= 0 then
			if self:IsAirVehicleType(p_VehicleType) then
				s_AttackMode = VehicleAttackModes.AttackWithMissileAir
			end
		elseif s_Gadget1 and s_Gadget1.type == WeaponTypes.MissileLand and p_Bot._RocketCooldownTimer <= 0 then
			if not self:IsAirVehicleType(p_VehicleType) then
				s_AttackMode = VehicleAttackModes.AttackWithMissileLand
			end
		end
	end

	return s_AttackMode
end

if g_Vehicles == nil then
	---@type Vehicles
	g_Vehicles = Vehicles()
end

return g_Vehicles
