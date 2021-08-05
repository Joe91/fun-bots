VehicleData = {

	-- Name, Type, Parttransforms, Bullet-Speeds, Drop, Offset-Vec
	["M1Abrams"] = {
		Name = "[M1 ABRAMS]",
		Type =  VehicleTypes.Tank,
		Parts = {25, 12, nil},  -- 25,26 -- 12 -- none
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81},
		Offset = {Vec3(0.0919998884201, -0.0385888814926, -1.02235937119), Vec3(0.00134825706482, 0.0728099346161, 0.929019987583), Vec3(0,0,0)}
	},
	["M1Abrams_AI_SP007"] = {Name = "[M1 ABRAMS]", Type =  VehicleTypes.Tank, Parts = {25, 12, nil}}, -- 25,26 -- 12 -- none
	["M1Abrams_SP007"] = {Name = "[M1 ABRAMS]", Type =  VehicleTypes.Tank, Parts = {25, 12, nil}}, -- 25,26 -- 12 -- none
	["M1Abrams_SP_Rail"] = {Name = "[M1 ABRAMS]", Type =  VehicleTypes.Tank, Parts = {25, 12, nil}}, -- 25,26 -- 12 -- none
	["T90"] = {
		Name = "[T-90A]", 
		Type =  VehicleTypes.Tank,
		Parts = {24, 41, nil},
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81},
		Offset = {Vec3(0.0, 0.0, -2.91700434685), Vec3(0.0425717830658, 0.0713469982147, 1.42420208454), Vec3(0,0,0)}
	}, -- 24,25
	["T90_SP007"] = {Name = "[T-90A]", Type =  VehicleTypes.Tank, Parts = {24, 41, nil}}, -- 24,25
	["T90_T55_SP007"] = {Name = "[T-90A]", Type =  VehicleTypes.Tank, Parts = {24, 41, nil}}, -- 24,25

	["LAV25"] = {
		Name = "[LAV-25]", 
		Type =  VehicleTypes.Tank, 
		Parts = {10, 25, nil, nil, nil, nil}, 
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}
	}, --10,19
	["LAV25_AI"] = {Name = "[LAV-25]", Type =  VehicleTypes.Tank, Parts = {10, 25, nil, nil, nil, nil}}, --10,19
	["LAV25_Paradrop"] = {Name = "[LAV-25]", Type =  VehicleTypes.Tank, Parts = {10, 25, nil, nil, nil, nil}}, --10,19
	["BMP2"] = {
		Name = "[BMP-2M]",
		Type =  VehicleTypes.Tank,
		Parts = {37, 49, nil, nil, nil, nil},
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}
	}, --37,38
	["BMP2_SP007"] = {
		Name = "[BMP-2M]",
		Type =  VehicleTypes.Tank,
		Parts = {37, 49, nil, nil, nil, nil},
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}
	}, --37,38

	["2S25_SPRUT-SD"] = {Name = "[SPRUT-SD]", Type =  VehicleTypes.Tank, Parts = {}},
	["M1128-Stryker"] = {Name = "[M1128]", Type =  VehicleTypes.Tank, Parts = {}},
	["VanModified"] = {Name = "[RHINO]", Type =  VehicleTypes.Tank, Parts = {}},

	-- AA Vehicle?
	["LAV_AD"] = {
		Name = "[LAV-AD]", 
		Type =  VehicleTypes.AntiAir,
		Parts = {1},
		Speed = {900},
		Drop = {0.0},
		Offset = {Vec3(0.156301766634, 0.0423104763031, 1.64426028728)}
	}, -- 0,1,5
	["9K22_Tunguska_M"] = {
		Name = "[9K22 TUNGUSKA-M]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {35},
		Speed = {900},
		Drop = {0.0},
		Offset = {Vec3(0,0,0)}
	},
	["9K22_Tunguska_M_AI"] = {
		Name = "[9K22 TUNGUSKA-M]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {35},
		Speed = {900},
		Drop = {0.0},
		Offset = {Vec3(0,0,0)}
	},

	["VodnikPhoenix"] = {Name = "[VODNIK AA]", Type =  VehicleTypes.AntiAir, Parts = {}},
	["AAV-7A1"] = {Name = "[AAV-7A1 AMTRAC]", Type =  VehicleTypes.AntiAir, Parts = {}},

	-- light Vehicle? maybe also AA?
	["HumveeArmored"] = {Name = "[M1114 HMMWV]", Type =  VehicleTypes.LightVehicle, Parts = {nil, 19, nil, nil}},
	["Humvee"] = {Name = "[M1114 HMMWV]", Type =  VehicleTypes.LightVehicle, Parts = {nil, 19, nil, nil}},
	["HumveeArmored_hmg"] = {Name = "[M1114 HMMWV]", Type =  VehicleTypes.LightVehicle, Parts = {nil, 19, nil, nil}},
	["GAZ-3937_Vodnik"] = {Name = "[GAZ-3937 VODNIK]", Type =  VehicleTypes.LightVehicle, Parts = {nil, 23, nil, nil}},

	["Humvee_ASRAD"] = {Name = "[HMMWV ASRAD]", Type =  VehicleTypes.LightVehicle, Parts = {}},
	["HIMARS"] = {Name = "[M142]", Type =  VehicleTypes.LightVehicle, Parts = {}},
	["BTR90"] = {Name = "[BTR-90]", Type =  VehicleTypes.LightVehicle, Parts = {}},
	["VodnikModified_V2"] = {Name = "[BARSUK]", Type =  VehicleTypes.LightVehicle, Parts = {}},
	["STAR_1466"] = {Name = "[BM-23]", Type =  VehicleTypes.LightVehicle, Parts = {}},
	["AC130"] = {Name = "[GUNSHIP]", Type =  VehicleTypes.LightVehicle, Parts = {}},

	-- Air vehicle
	["A10_THUNDERBOLT"] = {Name = "[A-10 THUNDERBOLT]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["A10_THUNDERBOLT_spjet"] = {Name = "[A-10 THUNDERBOLT]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["AH1Z"] = {Name = "[AH-1Z VIPER]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["AH1Z_coop"] = {Name = "[AH-1Z VIPER]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["AH6_Littlebird"] = {Name = "[AH-6J LITTLE BIRD]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["AH6_Littlebird_EQ"] = {Name = "[AH-6J LITTLE BIRD]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["F16"] = {Name = "[F/A-18E SUPER HORNET]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["F18_Wingman"] = {Name = "[F/A-18E SUPER HORNET]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Ka-60"] = {Name = "[KA-60 KASATKA]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Mi28"] = {Name = "[MI-28 HAVOC]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Su-25TM"] = {Name = "[SU-25TM FROGFOOT]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Su-35BM Flanker-E"] = {Name = "[SU-35BM FLANKER-E]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Su37"] = {Name = "[SU-37]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Venom"] = {Name = "[UH-1Y VENOM]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Venom_coop"] = {Name = "[UH-1Y VENOM]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Z-11w"] = {Name = "[Z-11W]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["Wz11_SP_Paris"] = {Name = "[Z-11W]", Type =  VehicleTypes.AirVehicle, Parts = {}},
	["F35B"] = {Name = "[F-35]", Type =  VehicleTypes.AirVehicle, Parts = {}},

	-- transport
	["GrowlerITV"] = {Name = "[GROWLER ITV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {nil, 47, nil}},
	["VDV Buggy"] = {Name = "[VDV Buggy]", Type =  VehicleTypes.NoArmorVehicle, Parts = {nil, 13, nil}},

	["CivilianCar_03_Vehicle"] = {Name = "[CIVILIAN CAR]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["CivilianCar_03_Vehicle_SPJet"] = {Name = "[CIVILIAN CAR]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["DeliveryVan_Vehicle"] = {Name = "[DELIVERY VAN]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["GrowlerITV_Valley"] = {Name = "[GROWLER ITV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["Paris_SUV"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["Paris_SUV_Coop"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["Sniper_SUV"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["PoliceVan_Vehicle"] = {Name = "[POLICE VAN]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["RHIB"] = {Name = "[RHIB BOAT]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["TechnicalTruck"] = {Name = "[TECHNICAL TRUCK]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["TechnicalTruck_Restricted"] = {Name = "[TECHNICAL TRUCK]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},

	["Villa_SUV"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["QuadBike"] = {Name = "[QUAD BIKE]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["C130"] = {Name = "[GUNSHIP]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["KLR650"] = {Name = "[DIRTBIKE]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["DPV"] = {Name = "[DPV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["SkidLoader"] = {Name = "[SKID LOADER]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},

	-- MAV / BOt
	["EODBot"] = {Name = "[EOD BOT]", Type =  VehicleTypes.MavBot, Parts = {}},
	["MAV"] = {Name = "[MAV]", Type =  VehicleTypes.MavBot, Parts = {}},
}
