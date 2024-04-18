--[[ To extract vehicle-data, you have to do the following steps:
1. Get the vehicle-name with the "!car" chat command;
2. Go to the right vehicle in the txt dumb: "https://github.com/EmulatorNexus/Venice-EBX/tree/master/Vehicles";
3. Search for the correct weapon using the "WeaponFiring" tags. The name of the gun is directly below;
4. Search for this navigate to the WeaponFiring file in the text-dumb;
5. Search for the "InitialSpeed::Vec3". This is the bullet-speed;
6. Search for the "gravity" value. This is the bullet-drop;
7. Identify the moving part, by checking the vehicle components ("!cardiff" chat command after moving). This will plot you the difference of all parts to the "!car" command;
8. Insert all data as shown below...
9. For Offsets:
    - Enable the Debug-Option in the Registry to True ( Registry.Debug.VEHICLE_PROJECTILE_TRACE)
	- Shoot with selected weapon (don't look in default direction)
	- Without further moving, enter "!car" in the chat
	- Offset of the relevant Indexes will be printed out
--]]

---@class VehicleDataInner
---@field Name string
---@field Type VehicleTypes|integer
---@field Terrain VehicleTerrains|integer
---@field Parts table<integer, integer|nil>
---@field Speed integer[]
---@field Drop number[]
---@field Team TeamId|integer|nil

---@class VehicleData
---@type VehicleDataInner[]
VehicleData = {

	-- Name, Type, Parttransforms, Bullet-Speeds, Drop, Offset-Vec
	["M1Abrams"] = {
		Name = "[M1 ABRAMS]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 13, 13 }, 12, -1 },
		Speed = { { 200, 610 }, 600, 350 },
		Drop = { { 9.81, 9.81 }, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.438, -0.096, -0.742), Vec3(0.436, -0.060, -1.207) }, Vec3(0.253, -0.098, 0.450), Vec3(0, 0, 0) }
	},
	["M1Abrams_AI_SP007"] = {
		Name = "[M1 ABRAMS]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 13, 13 }, 12, -1 },
		Speed = { { 200, 610 }, 600, 350 },
		Drop = { { 9.81, 9.81 }, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.438, -0.096, -0.742), Vec3(0.436, -0.060, -1.207) }, Vec3(0.253, -0.098, 0.450), Vec3(0, 0, 0) }
	},
	["M1Abrams_SP007"] = {
		Name = "[M1 ABRAMS]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 13, 13 }, 12, -1 },
		Speed = { { 200, 610 }, 600, 350 },
		Drop = { { 9.81, 9.81 }, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.438, -0.096, -0.742), Vec3(0.436, -0.060, -1.207) }, Vec3(0.253, -0.098, 0.450), Vec3(0, 0, 0) }
	},
	["M1Abrams_SP_Rail"] = {
		Name = "[M1 ABRAMS]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 13, 13 }, 12, -1 },
		Speed = { { 200, 610 }, 600, 350 },
		Drop = { { 9.81, 9.81 }, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.438, -0.096, -0.742), Vec3(0.436, -0.060, -1.207) }, Vec3(0.253, -0.098, 0.450), Vec3(0, 0, 0) }
	},
	["T90"] = {
		Name = "[T-90A]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 9, 9 }, 41, -1 },
		Speed = { { 200, 610 }, 600, 350 },
		Drop = { { 9.81, 9.81 }, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.494, 0.671, -1.532), Vec3(0.506, 0.633, -1.667) }, Vec3(0.574, -0.196, 0.302), Vec3(0, 0, 0) }
	},
	["T90_SP007"] = {
		Name = "[T-90A]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 9, 9 }, 41, -1 },
		Speed = { { 200, 610 }, 600, 350 },
		Drop = { { 9.81, 9.81 }, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.494, 0.671, -1.532), Vec3(0.506, 0.633, -1.667) }, Vec3(0.574, -0.196, 0.302), Vec3(0, 0, 0) }
	},
	["T90_T55_SP007"] = {
		Name = "[T-90A]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 9, 9 }, 41, -1 },
		Speed = { { 200, 610 }, 600, 350 },
		Drop = { { 9.81, 9.81 }, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.494, 0.671, -1.532), Vec3(0.506, 0.633, -1.667) }, Vec3(0.574, -0.196, 0.302), Vec3(0, 0, 0) }
	},
	-- NOTE: IFV-Vehicles use the IFV-TOW as secondary weapon
	-- TODO: what speed to select for TOW-Missile?
	["LAV25"] = {
		Name = "[LAV-25]",
		Type = VehicleTypes.IFV,
		Terrain = VehicleTerrains.Amphibious,
		Parts = { { 10, 10 }, 25, -1, -1, -1, -1 },
		Speed = { { 200, 20 }, 610, 350, 350, 350, 350 },
		Drop = { { 4.9, 0.0 }, 9.81, 9.81, 9.81, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.365, 0.332, -0.558), Vec3(0.365, -0.328, -0.554) }, Vec3(0.252, -0.098, 0.450), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["LAV25_AI"] = {
		Name = "[LAV-25]",
		Type = VehicleTypes.IFV,
		Terrain = VehicleTerrains.Land,
		Parts = { { 10, 10 }, 25, -1, -1, -1, -1 },
		Speed = { { 200, 20 }, 610, 350, 350, 350, 350 },
		Drop = { { 4.9, 0.0 }, 9.81, 9.81, 9.81, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.365, 0.332, -0.558), Vec3(0.365, -0.328, -0.554) }, Vec3(0.252, -0.098, 0.450), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["LAV25_Paradrop"] = {
		Name = "[LAV-25]",
		Type = VehicleTypes.IFV,
		Terrain = VehicleTerrains.Land,
		Parts = { { 10, 10 }, 25, -1, -1, -1, -1 },
		Speed = { { 200, 20 }, 610, 350, 350, 350, 350 },
		Drop = { { 4.9, 0.0 }, 9.81, 9.81, 9.81, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.365, 0.332, -0.558), Vec3(0.365, -0.328, -0.554) }, Vec3(0.252, -0.098, 0.450), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["BTR90"] = {
		Name = "[BTR-90]",
		Type = VehicleTypes.IFV,
		Terrain = VehicleTerrains.Land,
		Parts = { { 4, 4 }, 29, -1, -1, -1, -1 },
		Speed = { { 200, 20 }, 600, 350, 350, 350, 350 },
		Drop = { { 4.9, 0.0 }, 9.81, 9.81, 9.81, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.454, 0.211, 0.247), Vec3(0.454, 0.211, 0.247) }, Vec3(0.493, 0.174, 0.368), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["BMP2"] = {
		Name = "[BMP-2M]",
		Type = VehicleTypes.IFV,
		Terrain = VehicleTerrains.Amphibious,
		Parts = { { 37, 6 }, 49, -1, -1, -1, -1 },
		Speed = { { 200, 20 }, 610, 350, 350, 350, 350 },
		Drop = { { 4.9, 0.0 }, 9.81, 9.81, 9.81, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.074, 0.377, -1.699), Vec3(0.0524, 0.134, 1.275) }, Vec3(0.573, 0.174, 0.368), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["BMP2_SP007"] = {
		Name = "[BMP-2M]",
		Type = VehicleTypes.IFV,
		Terrain = VehicleTerrains.Amphibious,
		Parts = { { 37, 6 }, 49, -1, -1, -1, -1 },
		Speed = { { 200, 20 }, 610, 350, 350, 350, 350 },
		Drop = { { 4.9, 0.0 }, 9.81, 9.81, 9.81, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { { Vec3(0.074, 0.377, -1.699), Vec3(0.0524, 0.134, 1.275) }, Vec3(0.573, 0.174, 0.368), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["2S25_SPRUT-SD"] = {
		Name = "[SPRUT-SD]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 16, 16 }, -1, -1, -1, -1 },
		Speed = { { 200, 610 }, 350, 350, 350, 350 },
		Drop = { { 4.9, 9.81 }, 9.81, 9.81, 9.81, 9.81 },
		Offset = { { Vec3(0.361, 0.431, -2.344), Vec3(0.344, 0.451, -2.508) }, Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["M1128-Stryker"] = {
		Name = "[M1128]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { { 26, 26 }, -1, -1, -1, -1 },
		Speed = { { 200, 610 }, 350, 350, 350, 350 },
		Drop = { { 4.9, 9.81 }, 9.81, 9.81, 9.81, 9.81 },
		Offset = { { Vec3(0.808, -0.140, -2.222), Vec3(0.783, -0.073, -2.340) }, Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["VanModified"] = {
		Name = "[RHINO]",
		Type = VehicleTypes.Tank,
		Terrain = VehicleTerrains.Land,
		Parts = { 11, -1, -1, -1 },
		Speed = { 600, 350, 350, 350 },
		Drop = { 9.81, 9.81, 9.81, 9.81 },
		Offset = { Vec3(0.574, 0.079, -0.204), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},

	-- AA Vehicle
	["LAV_AD"] = {
		Name = "[LAV-AD]",
		Type = VehicleTypes.AntiAir,
		Terrain = VehicleTerrains.Land,
		Parts = { 1 },
		Speed = { 900 },
		Drop = { 0.0 },
		Offset = { Vec3(0.574, 0.291, 0.429) }
	},
	["9K22_Tunguska_M"] = {
		Name = "[9K22 TUNGUSKA-M]",
		Type = VehicleTypes.AntiAir,
		Terrain = VehicleTerrains.Land,
		Parts = { 35 },
		Speed = { 900 },
		Drop = { 0.0 },
		Offset = { Vec3(0.169, 0.562, -1.230) }
	},
	["9K22_Tunguska_M_AI"] = {
		Name = "[9K22 TUNGUSKA-M]",
		Type = VehicleTypes.AntiAir,
		Terrain = VehicleTerrains.Land,
		Parts = { 35 },
		Speed = { 900 },
		Drop = { 0.0 },
		Offset = { Vec3(0.169, 0.562, -1.230) }
	},
	-- TODO: Handling of Light vehicle needed?
	["VodnikPhoenix"] = {
		Name = "[VODNIK AA]",
		Type = VehicleTypes.AntiAir,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 12, -1, -1 },
		Speed = { 300, 1000, 300, 300 },
		Drop = { 9.81, 0.0, 9.82, 9.81 },
		Offset = { Vec3(0, 0, 0), Vec3(0.0, 0.224, 0.670), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["Humvee_ASRAD"] = {
		Name = "[HMMWV ASRAD]",
		Type = VehicleTypes.AntiAir,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 25, -1, -1 },
		Speed = { 300, 1000, 300, 300 },
		Drop = { 300, 0.0, 300, 300 },
		Offset = { Vec3(0, 0, 0), Vec3(0.0, 0.0, 0.623), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},

	-- Light Vehicle
	["AAV-7A1"] = {
		Name = "[AAV-7A1 AMTRAC]",
		Type = VehicleTypes.LightVehicle,
		Terrain = VehicleTerrains.Amphibious,
		Parts = { -1, 23, -1, -1, -1, -1 },
		Speed = { 600, 80, 600, 600, 600, 600 },
		Drop = { 9.81, 7.0, 9.81, 9.81, 9.81, 9.81 },
		FirstPassengerSeat = 3,
		Offset = { Vec3(0, 0, 0), Vec3(-0.324, 0.213, -0.625), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["HumveeArmored"] = {
		Name = "[M1114 HMMWV]",
		Type = VehicleTypes.LightVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 19, -1, -1 },
		Speed = { 300, 610, 300, 300 },
		Drop = { 0.0, 9.81, 0.0, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(0.252, -0.098, 0.450), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["Humvee"] = {
		Name = "[M1114 HMMWV]",
		Type = VehicleTypes.LightVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 19, -1, -1 },
		Speed = { 300, 610, 300, 300 },
		Drop = { 0.0, 9.81, 0.0, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(0.252, -0.098, 0.450), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["HumveeArmored_hmg"] = {
		Name = "[M1114 HMMWV]",
		Type = VehicleTypes.LightVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 19, -1, -1 },
		Speed = { 300, 610, 300, 300 },
		Drop = { 0.0, 9.81, 0.0, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(0.252, -0.098, 0.450), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["GAZ-3937_Vodnik"] = {
		Name = "[GAZ-3937 VODNIK]",
		Type = VehicleTypes.LightVehicle,
		Terrain = VehicleTerrains.Amphibious,
		Parts = { -1, 23, -1, -1 },
		Speed = { 300, 600, 300, 300 },
		Drop = { 0.0, 9.81, 0.0, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(0.574, -0.196, 0.302), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["VodnikModified_V2"] = {
		Name = "[BARSUK]",
		Type = VehicleTypes.LightVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 6, 16 },
		Speed = { 300, 80, 600 },
		Drop = { 0.0, 7.0, 9.81 },
		Offset = { Vec3(0, 0, 0), Vec3(-0.003, 0.243, -0.492), Vec3(0.0, 0.272, -0.708) }
	},
	["HumveeModified"] = {
		Name = "[PHOENIX]",
		Type = VehicleTypes.LightVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 1, 18 },
		Speed = { 300, 600, 80 },
		Drop = { 0.0, 15, 7.0 },
		Offset = { Vec3(0, 0, 0), Vec3(-0.076, 0.285, -0.933), Vec3(-0.003, 0.243, -0.581) }
	},

	-- Mobile Artillery.
	["HIMARS"] = {
		Name = "[M142]",
		Type = VehicleTypes.MobileArtillery,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, { 13, 13 } },
		Speed = { 300, { 50, 50 } },
		Drop = { 0.0, { 25.0, 25.0 } },
		Offset = { Vec3(0, 0, 0), { Vec3(0, 0, 0), Vec3(0, 0, 0) } }
	},
	["STAR_1466"] = {
		Name = "[BM-23]",
		Type = VehicleTypes.MobileArtillery,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, { 1, 1 } },
		Speed = { 300, { 50, 50 } },
		Drop = { 0.0, { 25.0, 25.0 } },
		Offset = { Vec3(0, 0, 0), { Vec3(0, 0, 0), Vec3(0, 0, 0) } }
	},

	-- Air vehicle.
	-- Jets/Planes
	["A10_THUNDERBOLT"] = {
		Name = "[A-10 THUNDERBOLT]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(0.0, 1.534, 5.110), Vec3(0.0, 1.534, 5.110) } }
	},
	["A10_THUNDERBOLT_spjet"] = {
		Name = "[A-10 THUNDERBOLT]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(0.0, 1.534, 5.110), Vec3(0.0, 1.534, 5.110) } }
	},
	["F16"] = {
		Name = "[F/A-18E SUPER HORNET]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(0.0, 0.880, 6.540), Vec3(0.0, 0.880, 6.540) } }
	},
	["F18_Wingman"] = {
		Name = "[F/A-18E SUPER HORNET]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(0.0, 0.880, 6.540), Vec3(0.0, 0.880, 6.540) } }
	},
	["Su-25TM"] = {
		Name = "[SU-25TM FROGFOOT]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(0.0, 1.031, 3.853), Vec3(0.0, 1.031, 3.853) } }
	},
	["Su-35BM Flanker-E"] = {
		Name = "[SU-35BM FLANKER-E]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(0.0, 1.549, 8.190), Vec3(0.0, 1.549, 8.190) } }
	},
	["Su37"] = {
		Name = "[SU-37]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(0.0, 1.549, 8.190), Vec3(0.0, 1.549, 8.190) } }
	},
	["F35B"] = {
		Name = "[F-35]",
		Type = VehicleTypes.Plane,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 } },
		Speed = { { 900, 10000 } },
		Drop = { { 0.0, 0.0 } },
		Offset = { { Vec3(-0.001, 1.025, 5.963), Vec3(-0.001, 1.025, 5.963) } }
	},
	-- Choppers.
	["AH1Z"] = {
		Name = "[AH-1Z VIPER]",
		Type = VehicleTypes.Chopper,
		Terrain = VehicleTerrains.Air,
		Parts = { { -2, -2 }, { 14, 14 } },
		Speed = { { 300, 10000 }, { 600, 999 } },
		Drop = { { 0.0, 0.0 }, { 0.0, 0.0 } },
		Offset = { { Vec3(3.374, 0.258, 1.802), Vec3(3.374, 0.258, 1.802) }, { Vec3(0.0, 0.0, 0.345), Vec3(0.0, 0.0, 0.345) } }
	},
	["AH1Z_coop"] = {
		Name = "[AH-1Z VIPER]",
		Type = VehicleTypes.Chopper,
		Terrain = VehicleTerrains.Air,
		Parts = { { -2, -2 }, { 14, 14 } },
		Speed = { { 300, 10000 }, { 600, 999 } },
		Drop = { { 0.0, 0.0 }, { 0.0, 0.0 } },
		Offset = { { Vec3(3.374, 0.258, 1.802), Vec3(3.374, 0.258, 1.802) }, { Vec3(0.0, 0.0, 0.345), Vec3(0.0, 0.0, 0.345) } }
	},
	["AH6_Littlebird"] = {
		Name = "[AH-6J LITTLE BIRD]",
		Type = VehicleTypes.ScoutChopper,
		Terrain = VehicleTerrains.Air,
		Parts = { { -2, -2 }, -1, -1, -1 },
		Speed = { { 900, 10000 }, 300, 300, 300 },
		Drop = { { 0.0, 0.0 }, 9.81, 9.81, 9.81 },
		Offset = { { Vec3(0.453, -0.062, 0.848), Vec3(0.453, -0.062, 0.848) }, Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["AH6_Littlebird_EQ"] = {
		Name = "[AH-6J LITTLE BIRD]",
		Type = VehicleTypes.ScoutChopper,
		Terrain = VehicleTerrains.Air,
		Parts = { { -2, -2 }, -1, -1, -1 },
		Speed = { { 900, 10000 }, 300, 300, 300 },
		Drop = { { 0.0, 0.0 }, 9.81, 9.81, 9.81 },
		Offset = { { Vec3(0.453, -0.062, 0.848), Vec3(0.453, -0.062, 0.848) }, Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["Ka-60"] = {
		Name = "[KA-60 KASATKA]",
		Type = VehicleTypes.Chopper,
		Terrain = VehicleTerrains.Air,
		Parts = { -1, 18, 15, -1, -1 },
		Speed = { 350, 900, 900, 350, 350 },
		Drop = { 9.81, 0.0, 0.0, 9.81, 9.81 },
		Offset = { Vec3(0, 0, 0), Vec3(0.0, 0.191, -0.360), Vec3(0.0, 0.191, -0.360), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["Mi28"] = {
		Name = "[MI-28 HAVOC]",
		Type = VehicleTypes.Chopper,
		Terrain = VehicleTerrains.Air,
		Parts = { { -2, -2 }, { 6, 6 } },
		Speed = { { 300, 10000 }, { 600, 999 } },
		Drop = { { 0.0, 0.0 }, { 0.0, 0.0 } },
		Offset = { { Vec3(0.006, 0.499, 1.427), Vec3(0.006, 0.499, 1.427) }, { Vec3(0, -0.018, 0.427), Vec3(0, -0.018, 0.427) } }
	},
	["Venom"] = {
		Name = "[UH-1Y VENOM]",
		Type = VehicleTypes.Chopper,
		Terrain = VehicleTerrains.Air,
		Parts = { -1, 19, 16, -1, -1 },
		Speed = { 350, 900, 900, 350, 350 },
		Drop = { 9.81, 0.0, 0.0, 9.81, 9.81 },
		Offset = { Vec3(0, 0, 0), Vec3(0.0, 0.239, -0.650), Vec3(0.0, 0.239, -0.650), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["Venom_coop"] = {
		Name = "[UH-1Y VENOM]",
		Type = VehicleTypes.Chopper,
		Terrain = VehicleTerrains.Air,
		Parts = { -1, 19, 16, -1, -1 },
		Speed = { 350, 900, 900, 350, 350 },
		Drop = { 9.81, 0.0, 0.0, 9.81, 9.81 },
		Offset = { Vec3(0, 0, 0), Vec3(0.0, 0.239, -0.650), Vec3(0.0, 0.239, -0.650), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["Z-11w"] = {
		Name = "[Z-11W]",
		Type = VehicleTypes.ScoutChopper,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 }, -1, -1, -1 },
		Speed = { { 900, 10000 }, 350, 350, 350 },
		Drop = { { 0.0, 0.0 }, 9.81, 9.81, 9.81 },
		Offset = { { Vec3(0.495, -0.199, 2.158), Vec3(0.495, -0.199, 2.158) }, Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},
	["Wz11_SP_Paris"] = {
		Name = "[Z-11W]",
		Type = VehicleTypes.ScoutChopper,
		Terrain = VehicleTerrains.Air,
		Parts = { { -1, -1 }, -1, -1, -1 },
		Speed = { { 900, 10000 }, 350, 350, 350 },
		Drop = { { 0.0, 0.0 }, 9.81, 9.81, 9.81 },
		Offset = { { Vec3(0.495, -0.199, 2.158), Vec3(0.495, -0.199, 2.158) }, Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 0, 0) }
	},

	-- Transport.
	["GrowlerITV"] = {
		Name = "[GROWLER ITV]",
		Type = VehicleTypes.NoArmorVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 47, -1 },
		Speed = { 300, 610, 300 },
		Drop = { 0.0, 9.81, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(0, 0.239, -0.816), Vec3(0, 0, 0) }
	},
	["GrowlerITV_Valley"] = {
		Name = "[GROWLER ITV]",
		Type = VehicleTypes.NoArmorVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 47, -1 },
		Speed = { 300, 610, 300 },
		Drop = { 0.0, 9.81, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(0, 0.239, -0.816), Vec3(0, 0, 0) }
	},
	["VDV Buggy"] = {
		Name = "[VDV Buggy]",
		Type = VehicleTypes.NoArmorVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 7, -1 },
		Speed = { 300, 610, 300 },
		Drop = { 0.0, 9.81, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(-0.037, 0.096, -0.624), Vec3(0, 0, 0) }
	},
	["DPV"] = {
		Name = "[DPV]",
		Type = VehicleTypes.NoArmorVehicle,
		Terrain = VehicleTerrains.Land,
		Parts = { -1, 4, -1 },
		Speed = { 300, 610, 300 },
		Drop = { 0.0, 9.81, 0.0 },
		Offset = { Vec3(0, 0, 0), Vec3(-0.001, 0.189, -0.600), Vec3(0, 0, 0) }
	},

	["CivilianCar_03_Vehicle"] = { Name = "[CIVILIAN CAR]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["CivilianCar_03_Vehicle_SPJet"] = { Name = "[CIVILIAN CAR]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["DeliveryVan_Vehicle"] = { Name = "[DELIVERY VAN]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["Paris_SUV"] = { Name = "[SUV]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["Paris_SUV_Coop"] = { Name = "[SUV]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["Sniper_SUV"] = { Name = "[SUV]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["PoliceVan_Vehicle"] = { Name = "[POLICE VAN]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["RHIB"] = { Name = "[RHIB BOAT]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Water, Parts = { -1, -1, -1, -1 } },
	["TechnicalTruck"] = { Name = "[TECHNICAL TRUCK]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["TechnicalTruck_Restricted"] = { Name = "[TECHNICAL TRUCK]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },

	["Villa_SUV"] = { Name = "[SUV]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["QuadBike"] = { Name = "[QUAD BIKE]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["C130"] = { Name = "[GUNSHIP]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["KLR650"] = { Name = "[DIRTBIKE]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },
	["SkidLoader"] = { Name = "[SKID LOADER]", Type = VehicleTypes.NoArmorVehicle, Terrain = VehicleTerrains.Land, Parts = {} },

	["AC130"] = { Name = "[GUNSHIP]", Type = VehicleTypes.LightVehicle, Terrain = VehicleTerrains.Air, Parts = {} },

	-- AA Stationary.
	["Centurion_C-RAM"] = {
		Name = "[CENTURION_AA]",
		Type = VehicleTypes.StationaryAA,
		Terrain = VehicleTerrains.Land,
		Parts = { 3 },
		Speed = { 900 },
		Drop = { 0.0 },
		Team = 1
	},
	["Centurion_C-RAM_Carrier"] = {
		Name = "[CENTURION_AA]",
		Type = VehicleTypes.StationaryAA,
		Terrain = VehicleTerrains.Land,
		Parts = { 3 },
		Speed = { 900 },
		Drop = { 0.0 },
		Team = 1
	},
	["Pantsir-S1"] = {
		Name = "[PANTSIR_AA]",
		Type = VehicleTypes.StationaryAA,
		Terrain = VehicleTerrains.Land,
		Parts = { 1 },
		Speed = { 900 },
		Drop = { 0.0 },
		Team = 2
	},

	-- MAV / Bot
	["EODBot"] = { Name = "[EOD BOT]", Type = VehicleTypes.MavBot, Terrain = VehicleTerrains.Land, Parts = {} },
	["MAV"] = { Name = "[MAV]", Type = VehicleTypes.MavBot, Terrain = VehicleTerrains.Air, Parts = {} },

	-- Stationary Defence.
	["Kornet"] = {
		Name = "[Kornet]",
		Type = VehicleTypes.StationaryLauncher,
		Terrain = VehicleTerrains.Land,
		Parts = { 2 },
		Speed = { 20 },
		Drop = { 0.0 },
	},
	["TOW2"] = {
		Name = "[TOW2]",
		Type = VehicleTypes.StationaryLauncher,
		Terrain = VehicleTerrains.Land,
		Parts = { 2 },
		Speed = { 20 },
		Drop = { 0.0 },
	},

	-- Gadgets.
	["AGM-144_Hellfire_TV"] = { Name = "[Hellfire]", Type = VehicleTypes.Gadgets, Terrain = VehicleTerrains.Air, Parts = {} },
	["RadioBeacon_Projectile"] = { Name = "[RadioBeacon]", Type = VehicleTypes.Gadgets, Terrain = VehicleTerrains.Land, Parts = {} },
	["SOFLAM_Projectile"] = { Name = "[SOFLAM]", Type = VehicleTypes.Gadgets, Terrain = VehicleTerrains.Land, Parts = {} },
	["T-UGS_Vehicle"] = { Name = "[T-UGS]", Type = VehicleTypes.Gadgets, Terrain = VehicleTerrains.Land, Parts = {} },
}
