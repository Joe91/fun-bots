---@class StateInVehicleStationaryAAControl
---@overload fun():StateInVehicleStationaryAAControl
StateInVehicleStationaryAAControl = class('StateInVehicleStationaryAAControl')

-- this class handles the following things:
-- - moving along paths
-- - overcome obstacles

-- transitions to:
-- - attacking
-- - enter vehicle
-- - idle (on death)

-- bot-methods
local m_Vehicles = require('Vehicles')
local m_AirTargets = require('AirTargets')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

function StateInVehicleStationaryAAControl:__init()
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleStationaryAAControl:Update(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end

	local s_IsAttacking = p_Bot._ShootPlayer ~= nil
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- Common part.
	m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(p_Bot)

	if s_IsAttacking then
		-- Differ attacking.
		m_VehicleAttacking:UpdateAttackStationaryAAVehicle(p_Bot)
	end

	p_Bot:_UpdateInputs(p_DeltaTime)

	-- transition
	if p_Bot.m_Player.controlledControllable == nil or (p_Bot.m_Player.controlledControllable and p_Bot.m_Player.controlledControllable:Is('ServerSoldierEntity')) then
		p_Bot:SetState(g_BotStates.States.Moving)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleStationaryAAControl:UpdateFast(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier == nil then
		return
	end

	local s_IsAttacking = p_Bot._ShootPlayer ~= nil
	-- Stationary AA needs separate handling.

	-- Get new target if needed.
	if p_Bot._DeployTimer > 3.0 then
		local s_Target = m_AirTargets:GetTarget(p_Bot.m_Player, Config.MaxDistanceAABots)
		if s_Target ~= nil then
			p_Bot._ShootPlayerId = s_Target.id
			p_Bot._ShootPlayer = PlayerManager:GetPlayerById(p_Bot._ShootPlayerId)
			p_Bot._ShootPlayerVehicleType = g_PlayerData:GetData(p_Bot._ShootPlayerId).Vehicle
		elseif s_IsAttacking then
			p_Bot:AbortAttack()
		end

		p_Bot._DeployTimer = 0.0
	else
		p_Bot._DeployTimer = p_Bot._DeployTimer + p_DeltaTime
	end


	-- Fast code.
	if s_IsAttacking then
		m_VehicleAiming:UpdateAimingVehicle(p_Bot, true)
	else
		m_VehicleMovement:UpdateVehicleLookAround(p_Bot, p_DeltaTime)
	end

	m_VehicleMovement:UpdateYawVehicle(p_Bot, s_IsAttacking, true)
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleStationaryAAControl:UpdateVeryFast(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleStationaryAAControl:UpdateSlow(p_Bot, p_DeltaTime)
	p_Bot:_DoExitVehicle()
end

if g_StateInVehicleStationaryAAControl == nil then
	---@type StateInVehicleStationaryAAControl
	g_StateInVehicleStationaryAAControl = StateInVehicleStationaryAAControl()
end

return g_StateInVehicleStationaryAAControl
