class("Vehicles")

function Vehicles:FindOutVehicleType(p_Player)
	local s_VehicleType = VehicleTypes.NoVehicle -- no vehicle

	if p_Player.controlledControllable ~= nil and not p_Player.controlledControllable:Is("ServerSoldierEntity") then
		local s_VehicleName = VehicleTable[VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/","")]

		-- Tank
		if s_VehicleName == "[LAV-25]" or
		s_VehicleName == "[SPRUT-SD]" or
		s_VehicleName == "[BMP-2M]" or
		s_VehicleName == "[M1 ABRAMS]" or
		s_VehicleName == "[T-90A]" or
		s_VehicleName == "[M1128]" or
		s_VehicleName == "[RHINO]"
		then
			s_VehicleType = VehicleTypes.Tank
		end

		-- light Vehicle
		if s_VehicleName == "[AAV-7A1 AMTRAC]" or
		s_VehicleName == "[9K22 TUNGUSKA-M]" or
		s_VehicleName == "[GAZ-3937 VODNIK]" or
		s_VehicleName == "[LAV-AD]" or
		s_VehicleName == "[M1114 HMMWV]" or
		s_VehicleName == "[HMMWV ASRAD]" or
		s_VehicleName == "[GUNSHIP]" or
		s_VehicleName == "[M142]" or
		s_VehicleName == "[BM-23]" or
		s_VehicleName == "[BARSUK]" or
		s_VehicleName == "[VODNIK AA]" or
		s_VehicleName == "[BTR-90]"
		then
			s_VehicleType = VehicleTypes.LightVehicle
		end

		-- Air vehicles
		if s_VehicleName == "[A-10 THUNDERBOLT]" or
		s_VehicleName == "[AH-1Z VIPER]" or
		s_VehicleName == "[AH-6J LITTLE BIRD]" or
		s_VehicleName == "[F/A-18E SUPER HORNET]" or
		s_VehicleName == "[KA-60 KASATKA]" or
		s_VehicleName == "[MI-28 HAVOC]" or
		s_VehicleName == "[SU-25TM FROGFOOT]" or
		s_VehicleName == "[SU-35BM FLANKER-E]" or
		s_VehicleName == "[SU-37]" or
		s_VehicleName == "[UH-1Y VENOM]" or
		s_VehicleName == "[Z-11W]" or
		s_VehicleName == "[F-35]"
		then
			s_VehicleType = VehicleTypes.AirVehicle
		end

		-- no armor at all
		if s_VehicleName == "[GROWLER ITV]" or
		s_VehicleName == "[CIVILIAN CAR]" or
		s_VehicleName == "[DELIVERY VAN]" or
		s_VehicleName == "[SUV]" or
		s_VehicleName == "[POLICE VAN]" or
		s_VehicleName == "[RHIB BOAT]" or
		s_VehicleName == "[TECHNICAL TRUCK]" or
		s_VehicleName == "[VDV Buggy]" or
		s_VehicleName == "[QUAD BIKE]" or
		s_VehicleName == "[DIRTBIKE]" or
		s_VehicleName == "[DPV]" or
		s_VehicleName == "[SKID LOADER]"
		then
			s_VehicleType = VehicleTypes.NoArmorVehicle
		end

		if s_VehicleName == "[EOD BOT]" or
		s_VehicleName == "[MAV]"
		then
			s_VehicleType = VehicleTypes.MavBot
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
