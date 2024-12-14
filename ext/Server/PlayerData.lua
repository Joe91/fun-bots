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

function PlayerData:SetPlayerData(p_PlayerName, p_Data)
	self._Players[p_PlayerName] = p_Data
end

function PlayerData:UpdatePlayerData(p_PlayerName, p_Attribute, p_Value)
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
