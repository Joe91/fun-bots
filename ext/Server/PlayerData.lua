---@class PlayerData
---@overload fun():PlayerData
PlayerData = class('PlayerData')

---@class PlayerInformation
---@field Vehicle VehicleTypes|integer
---@field ShootPlayerName string
---@field Team TeamId

function PlayerData:__init()
	---@type PlayerInformation[]
	self._Players = {}
end

---comment
---@param p_Player Player -- Server class
function PlayerData:SetPlayerData(p_Player)
	self._Players[p_Player.id] = {
		Vehicle = VehicleTypes.NoVehicle,
		ShootPlayerName = '',
		Team = p_Player.teamId
	}
end

function PlayerData:Clear()
	self._Players = {}
end

---VEXT Server Vehicle:Enter Event
---@param p_VehicleEntity ControllableEntity | Entity @`ControllableEntity`
---@param p_Player Player
function PlayerData:OnVehicleEnter(p_VehicleEntity, p_Player)
	self:_UpdatePlayerData(p_Player, "Vehicle", g_Vehicles:GetVehicleByEntity(p_VehicleEntity).Type)
end

---VEXT Server Vehicle:Exit Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Player Player
function PlayerData:OnVehicleExit(p_VehicleEntity, p_Player)
	self:_UpdatePlayerData(p_Player, "Vehicle", VehicleTypes.NoVehicle)
end

function PlayerData:_UpdatePlayerData(p_Player, p_Attribute, p_Value)
	if self._Players[p_Player.id] == nil then
		self:SetPlayerData(p_Player)
	end
	self._Players[p_Player.id][p_Attribute] = p_Value
end

---comment
---@param p_PlayerId integer
---@return PlayerInformation
function PlayerData:GetData(p_PlayerId)
	return self._Players[p_PlayerId]
end

if g_PlayerData == nil then
	---@type PlayerData
	g_PlayerData = PlayerData()
end

return g_PlayerData
