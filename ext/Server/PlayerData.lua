---@class PlayerData
---@overload fun():PlayerData
PlayerData = class('PlayerData')

---@class PlayerInformation
---@field Vehicle VehicleTypes|integer
---@field ShootPlayerName string


function PlayerData:__init()
	---@type PlayerInformation[]
	self._Players = {}
end

function PlayerData:SetPlayerData(p_Player)
	self._Players[p_Player.name] = {
		Vehicle = VehicleTypes.NoVehicle,
		ShootPlayerName = ''
	}
end

function PlayerData:Clear()
	self._Players = {}
end

---VEXT Server Vehicle:Enter Event
---@param p_VehicleEntity ControllableEntity @`ControllableEntity`
---@param p_Player Player
function PlayerData:OnVehicleEnter(p_VehicleEntity, p_Player)
	self:_UpdatePlayerData(p_Player.name, "Vehicle", g_Vehicles:GetVehicleByEntity(p_VehicleEntity).Type)
end

---VEXT Server Vehicle:Exit Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Player Player
function PlayerData:OnVehicleExit(p_VehicleEntity, p_Player)
	self:_UpdatePlayerData(p_Player.name, "Vehicle", VehicleTypes.NoVehicle)
end

function PlayerData:_UpdatePlayerData(p_PlayerName, p_Attribute, p_Value)
	self._Players[p_PlayerName][p_Attribute] = p_Value
end

function PlayerData:GetData(p_PlayerName)
	return self._Players[p_PlayerName]
end

if g_PlayerData == nil then
	---@type PlayerData
	g_PlayerData = PlayerData()
end

return g_PlayerData
