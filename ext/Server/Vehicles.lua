class("Vehicles")

require('__shared/Constants/VehicleData')

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

function Vehicles:CheckForVehicleAttack(p_VehicleType, p_Distance)
	local s_AttackMode = VehicleAttackModes.NoAttack -- no attack

	if p_VehicleType == VehicleTypes.MavBot then
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with rifle
	elseif p_VehicleType == VehicleTypes.NoArmorVehicle and p_Distance < Config.MaxRaycastDistance then
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with rifle
	elseif p_VehicleType == VehicleTypes.AirVehicle and p_Distance < Config.MaxRaycastDistance then
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with rifle
	elseif (p_VehicleType == VehicleTypes.LightVehicle or p_VehicleType == VehicleTypes.AntiAir) and p_Distance < 35 then
		s_AttackMode = VehicleAttackModes.AttackWithNade -- attack with grenade
	end

	if p_VehicleType ~= VehicleTypes.MavBot then -- MAV or EOD always with rifle
		if self.m_SecondaryGadget.type == WeaponTypes.Rocket then
			s_AttackMode = VehicleAttackModes.AttackWithRocket -- always use rocket if possible
		elseif self.m_SecondaryGadget.type == WeaponTypes.C4 and p_Distance < 25 then
			if p_VehicleType ~= VehicleTypes.AirVehicle then -- no air vehicles
				s_AttackMode = VehicleAttackModes.AttackWithC4 -- always use c4 if possible
			end
		end
	end

	if self.m_InVehicle then
		s_AttackMode = VehicleAttackModes.AttackWithRifle -- attack with main-weapon
	end

	return s_AttackMode
end

if g_Vehicles == nil then
	g_Vehicles = Vehicles()
end

return g_Vehicles
