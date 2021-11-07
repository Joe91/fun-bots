--[[ to extract vehicle-data you have to do the following steps:
1. get the vehicle-name with the "!car" chat command
2. go to the right vehicle in the txt dumb: "https://github.com/EmulatorNexus/Venice-EBX/tree/master/Vehicles"
3. search for the correct weapon using the "WeaponFiring" tags. The name of the gun is directly below
4. search for this navigate to the WeaponFiring file in the text-dumb
5. search for the "InitialSpeed::Vec3". This is the bullet-speed.
6. search for the "gravity" value. This is the bullet-drop.
7. identify the moving part, by checking the vehicle components ("!car" chat command) and looking at the y koordinate in different positions.
8. insert all data like shown below...
--]]

VehicleData = {

	-- Name, Type, Parttransforms, Bullet-Speeds, Drop, Offset-Vec
	["M1Abrams"] = {
		Name = "[M1 ABRAMS]",
		Type =  VehicleTypes.Tank,
		Parts = {25, 12, nil},  -- 25,26 -- 12 -- none
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81}},
	["M1Abrams_AI_SP007"] = {
		Name = "[M1 ABRAMS]",
		Type =  VehicleTypes.Tank,
		Parts = {25, 12, nil},  -- 25,26 -- 12 -- none
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81}},
	["M1Abrams_SP007"] = {
		Name = "[M1 ABRAMS]",
		Type =  VehicleTypes.Tank,
		Parts = {25, 12, nil},  -- 25,26 -- 12 -- none
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81}},
	["M1Abrams_SP_Rail"] = {
		Name = "[M1 ABRAMS]",
		Type =  VehicleTypes.Tank,
		Parts = {25, 12, nil},  -- 25,26 -- 12 -- none
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81}},
	["T90"] = {
		Name = "[T-90A]", 
		Type =  VehicleTypes.Tank,
		Parts = {24, 41, nil},
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81}}, -- 24,25
	["T90_SP007"] = {
		Name = "[T-90A]",
		Type =  VehicleTypes.Tank,
		Parts = {24, 41, nil},
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81}}, -- 24,25
	["T90_T55_SP007"] = {Name = "[T-90A]", 
		Type =  VehicleTypes.Tank,
		Parts = {24, 41, nil},
		Speed = {200, 600, 350},
		Drop = {9.81, 9.81, 9.81}}, -- 24,25
	["LAV25"] = {
		Name = "[LAV-25]", 
		Type =  VehicleTypes.Tank,
		Parts = {10, 25, nil, nil, nil, nil},
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}}, --10,19
	["LAV25_AI"] = {
		Name = "[LAV-25]",
		Type =  VehicleTypes.Tank,
		Parts = {10, 25, nil, nil, nil, nil},
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}}, --10,19
	["LAV25_Paradrop"] = {
		Name = "[LAV-25]",
		Type =  VehicleTypes.Tank,
		Parts = {10, 25, nil, nil, nil, nil},
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}}, --10,19
	["BTR90"] = {
		Name = "[BTR-90]",
		Type =  VehicleTypes.Tank,
		Parts = {4, 29, nil, nil, nil, nil},
		Speed = {200, 600, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}},
	["BMP2"] = {
		Name = "[BMP-2M]",
		Type =  VehicleTypes.Tank,
		Parts = {37, 49, nil, nil, nil, nil},
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}}, --37,38
	["BMP2_SP007"] = {
		Name = "[BMP-2M]",
		Type =  VehicleTypes.Tank,
		Parts = {37, 49, nil, nil, nil, nil},
		Speed = {200, 610, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81, 9.81}}, --37,38

		--TODO: search real weapon-stats
	["2S25_SPRUT-SD"] = {
		Name = "[SPRUT-SD]", 
		Type =  VehicleTypes.Tank,
		Parts = {16, nil, nil, nil, nil},
		Speed = {200, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81}},
	["M1128-Stryker"] = {
		Name = "[M1128]",
		Type =  VehicleTypes.Tank,
		Parts = {26, nil, nil, nil, nil},
		Speed = {200, 350, 350, 350, 350},
		Drop = {4.9, 9.81, 9.81, 9.81, 9.81}},
	["VanModified"] = {
		Name = "[RHINO]",
		Type =  VehicleTypes.Tank,
		Parts = {11, nil, nil, nil},
		Speed = {600, 350, 350, 350},
		Drop = {9.81, 9.81, 9.81, 9.81}},

	-- AA Vehicle?
	["LAV_AD"] = {
		Name = "[LAV-AD]", 
		Type =  VehicleTypes.AntiAir,
		Parts = {1},
		Speed = {900},
		Drop = {0.0}}, -- 0,1,5
	["9K22_Tunguska_M"] = {
		Name = "[9K22 TUNGUSKA-M]",
		Type =  VehicleTypes.AntiAir,
		Parts = {35},
		Speed = {900},
		Drop = {0.0}},
	["9K22_Tunguska_M_AI"] = {
		Name = "[9K22 TUNGUSKA-M]",
		Type =  VehicleTypes.AntiAir,
		Parts = {35},
		Speed = {900},
		Drop = {0.0}},
	["VodnikPhoenix"] = {
		Name = "[VODNIK AA]",
		Type =  VehicleTypes.AntiAir,
		Parts = {nil, 12, nil, nil},
		Speed = {300, 50, 300, 300},
		Drop = {9.81, 0.0, 9.82, 9.81}},

	-- light Vehicle? maybe also AA?
	["AAV-7A1"] = {
		Name = "[AAV-7A1 AMTRAC]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {nil, 23, nil, nil, nil, nil},
		Speed = {600, 80, 600, 600, 600, 600},
		Drop = {9.81, 7.0, 9.81, 9.81, 9.81, 9.81}},
	["HumveeArmored"] = {
		Name = "[M1114 HMMWV]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {nil, 19, nil, nil},
		Speed = {300, 610, 300, 300},
		Drop = {0.0, 9.81, 0.0, 0.0}},
	["Humvee"] = {
		Name = "[M1114 HMMWV]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {nil, 19, nil, nil},
		Speed = {300, 610, 300, 300},
		Drop = {0.0, 9.81, 0.0, 0.0}},
	["HumveeArmored_hmg"] = {
		Name = "[M1114 HMMWV]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {nil, 19, nil, nil},
		Speed = {300, 610, 300, 300},
		Drop = {0.0, 9.81, 0.0, 0.0}},
	["GAZ-3937_Vodnik"] = {
		Name = "[GAZ-3937 VODNIK]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {nil, 23, nil, nil},
		Speed = {300, 600, 300, 300},
		Drop = {0.0, 9.81, 0.0, 0.0}},
	["Humvee_ASRAD"] = {Name = "[HMMWV ASRAD]", Type =  VehicleTypes.LightVehicle, Parts = {}},
	["HIMARS"] = {Name = "[M142]", Type =  VehicleTypes.LightVehicle, Parts = {}},

	["VodnikModified_V2"] = {
		Name = "[BARSUK]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {nil, 6, 16},
		Speed = {300, 600, 80},
		Drop = {0.0, 15, 7.0}},
	["HumveeModified"] = {
		Name = "[PHOENIX]",
		Type =  VehicleTypes.LightVehicle,
		Parts = {nil, 1, 18},
		Speed = {300, 600, 80},
		Drop = {0.0, 15, 7.0}},
	["STAR_1466"] = {Name = "[BM-23]", Type =  VehicleTypes.LightVehicle, Parts = {}},
	["AC130"] = {Name = "[GUNSHIP]", Type =  VehicleTypes.LightVehicle, Parts = {}},

	-- Air vehicle
	-- Jets/Planes
	["A10_THUNDERBOLT"] = {
		Name = "[A-10 THUNDERBOLT]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["A10_THUNDERBOLT_spjet"] = {
		Name = "[A-10 THUNDERBOLT]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["F16"] = {
		Name = "[F/A-18E SUPER HORNET]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["F18_Wingman"] = {
		Name = "[F/A-18E SUPER HORNET]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["Su-25TM"] = {
		Name = "[SU-25TM FROGFOOT]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["Su-35BM Flanker-E"] = {
		Name = "[SU-35BM FLANKER-E]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["Su37"] = {
		Name = "[SU-37]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["F35B"] = {
		Name = "[F-35]",
		Type =  VehicleTypes.Plane,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	-- choppers
	["AH1Z"] = {
		Name = "[AH-1Z VIPER]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil, 1}, --0,1,14
		Speed = {300, 600},
		Drop = {0.0, 0.0}},
	["AH1Z_coop"] = {
		Name = "[AH-1Z VIPER]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil, 1}, --0,1,14
		Speed = {300, 600},
		Drop = {0.0, 0.0}},
	["AH6_Littlebird"] = {
		Name = "[AH-6J LITTLE BIRD]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil},
		Speed = {900},
		Drop = {0.0}},
	["AH6_Littlebird_EQ"] = {
		Name = "[AH-6J LITTLE BIRD]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil, nil, nil, nil},
		Speed = {900, 300, 300, 300},
		Drop = {0.0, 9.81, 9.81, 9.81}},
	["Ka-60"] = {
		Name = "[KA-60 KASATKA]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil, 18, 15, nil, nil},
		Speed = {350, 900, 900, 350, 350},
		Drop = {9.81, 0.0, 0.0, 9.81, 9.81}},
	["Mi28"] = {
		Name = "[MI-28 HAVOC]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil, 2}, --2,6},
		Speed = {350, 600},
		Drop = {9.81, 0.0}},
	["Venom"] = {
		Name = "[UH-1Y VENOM]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil, 19, 16, nil, nil},
		Speed = {350, 900, 900, 350, 350},
		Drop = {9.81, 0.0, 0.0, 9.81, 9.81}},
	["Venom_coop"] = {
		Name = "[UH-1Y VENOM]",
		Type =  VehicleTypes.Chopper,
		Parts = {nil, 19, 16, nil, nil},
		Speed = {350, 900, 900, 350, 350},
		Drop = {9.81, 0.0, 0.0, 9.81, 9.81}},
	["Z-11w"] = {Name = "[Z-11W]", Type =  VehicleTypes.Chopper, Parts = {}},
	["Wz11_SP_Paris"] = {Name = "[Z-11W]", Type =  VehicleTypes.Chopper, Parts = {}},

	-- transport
	["GrowlerITV"] = {
		Name = "[GROWLER ITV]",
		Type =  VehicleTypes.NoArmorVehicle,
		Parts = {nil, 47, nil},
		Speed = {300, 610, 300},
		Drop = {0.0, 9.81, 0.0}},
	["GrowlerITV_Valley"] = {
		Name = "[GROWLER ITV]",
		Type =  VehicleTypes.NoArmorVehicle,
		Parts = {nil, 47, nil},
		Speed = {300, 610, 300},
		Drop = {0.0, 9.81, 0.0}},
	["VDV Buggy"] = {
		Name = "[VDV Buggy]",
		Type =  VehicleTypes.NoArmorVehicle,
		Parts = {nil, 13, nil},
		Speed = {300, 610, 300},
		Drop = {0.0, 9.81, 0.0}},
	["DPV"] = {
		Name = "[DPV]", 
		Type =  VehicleTypes.NoArmorVehicle,
		Parts = {nil, 4, nil},
		Speed = {300, 610, 600},
		Drop = {0.0, 9.81, 15}},
	["CivilianCar_03_Vehicle"] = {Name = "[CIVILIAN CAR]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["CivilianCar_03_Vehicle_SPJet"] = {Name = "[CIVILIAN CAR]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["DeliveryVan_Vehicle"] = {Name = "[DELIVERY VAN]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["Paris_SUV"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["Paris_SUV_Coop"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["Sniper_SUV"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["PoliceVan_Vehicle"] = {Name = "[POLICE VAN]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["RHIB"] = {Name = "[RHIB BOAT]", Type =  VehicleTypes.NoArmorVehicle, Parts = {nil, nil, nil, nil}},
	["TechnicalTruck"] = {Name = "[TECHNICAL TRUCK]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["TechnicalTruck_Restricted"] = {Name = "[TECHNICAL TRUCK]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},

	["Villa_SUV"] = {Name = "[SUV]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["QuadBike"] = {Name = "[QUAD BIKE]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["C130"] = {Name = "[GUNSHIP]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["KLR650"] = {Name = "[DIRTBIKE]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},
	["SkidLoader"] = {Name = "[SKID LOADER]", Type =  VehicleTypes.NoArmorVehicle, Parts = {}},


	-- AA Stationary
	["Centurion_C-RAM"] = {
		Name = "[CENTURION_AA]",
		Type =  VehicleTypes.StationaryAA,
		Parts = {3},
		Speed = {900},
		Drop = {0.0},
		Team = 1
	}, --1,3,4
	["Centurion_C-RAM_Carrier"] = {
		Name = "[CENTURION_AA]",
		Type =  VehicleTypes.StationaryAA,
		Parts = {3},
		Speed = {900},
		Drop = {0.0},
		Team = 1
	}, --1,3,4
	["Pantsir-S1"] = {
		Name = "[PANTSIR_AA]",
		Type =  VehicleTypes.StationaryAA,
		Parts = {1},
		Speed = {900},
		Drop = {0.0},
		Team = 2
	}, --0,1

	-- MAV / BOt
	["EODBot"] = {Name = "[EOD BOT]", Type =  VehicleTypes.MavBot, Parts = {}},
	["MAV"] = {Name = "[MAV]", Type =  VehicleTypes.MavBot, Parts = {}},
}
