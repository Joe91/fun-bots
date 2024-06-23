---@enum BotMoveModes
BotMoveModes = {
	Standstill = 0,
	Mirror = 3,
	Mimic = 4,
	Paths = 5,
	ReviveC4 = 8,
	Shooting = 9
}

---@enum BotSpawnModes
BotSpawnModes = {
	NoRespawn = 0,
	RespawnFixedPath = 4,
	RespawnRandomPath = 5
}

---@enum BotAttackingModes
BotAttackingModes = {
	NoAttack = 0,
	AttackWithRifle = 1,
	AttackWithC4 = 2,
	AttackWithKnife = 3,
	AttackWithGrenade = 4,
	RevivePlayer = 5,
	EnterVehicleOfPlayer = 6
}

---@enum BotObjectiveModes
BotObjectiveModes = {
	Default = 0,
	Attack = 1,
	Defend = 2
}

---@enum BotActionFlags
BotActionFlags = {
	NoActionActive = 0,
	MeleeActive = 1,
	ReviveActive = 2,
	EnterVehicleActive = 3,
	GrenadeActive = 4,
	C4Active = 5,
	RepairActive = 6,
	OtherActionActive = 7,
	RunAway = 8,
	HideOnAttack = 9
}

---@enum VehicleTypes
VehicleTypes = {
	NoVehicle = 0,
	Tank = 1,
	AntiAir = 2,
	LightVehicle = 3,
	Plane = 4,
	Chopper = 5,
	NoArmorVehicle = 6,
	MavBot = 7,
	StationaryAA = 8,
	StationaryLauncher = 9,
	MobileArtillery = 10,
	Gadgets = 11,
	IFV = 12,
	ScoutChopper = 13,
	Gunship = 14,
	LightAA = 15,
}

---@enum VehicleTerrains
VehicleTerrains = {
	Land = 1,
	Water = 2,
	Air = 3,
	Amphibious = 4
}

---@enum VehicleAttackModes
VehicleAttackModes = {
	NoAttack = 0,
	AttackWithRifle = 1,
	AttackWithNade = 2,
	AttackWithRocket = 3,
	AttackWithC4 = 4,
	AttackWithMissileAir = 5,
	AttackWithMissileLand = 6
}
