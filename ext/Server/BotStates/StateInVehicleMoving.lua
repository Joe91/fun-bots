---@class StateInVehicleMoving
---@overload fun():StateInVehicleMoving
StateInVehicleMoving = class('StateInVehicleMoving')

-- this class handles the following things:
-- - moving along paths
-- - overcome obstacles

-- transitions to:
-- - attacking
-- - enter vehicle
-- - idle (on death)

---@type Utilities
local m_Utilities = require('__shared/Utilities')
-- bot-methods
local m_Vehicles = require('Vehicles')
local m_AirTargets = require('AirTargets')
local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

function StateInVehicleMoving:__init()
	-- Nothing to do.
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleMoving:UpdatePrecheck(p_Bot)
	if not p_Bot.m_Player.soldier then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleMoving:Update(p_Bot, p_DeltaTime)
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- Stationary AA needs separate handling.
	if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA) then
		-- Common part.
		m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(p_Bot)
		p_Bot:_UpdateInputs(p_DeltaTime)
		return
	end

	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryLauncher) or m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA)

	-- Common part.
	m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(p_Bot)
	if p_Bot.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
		m_VehicleMovement:UpdateNormalMovementVehicle(p_DeltaTime, p_Bot)
	end

	-- Common things.
	m_VehicleMovement:UpdateSpeedOfMovementVehicle(p_DeltaTime, p_Bot, false)
	p_Bot:_UpdateInputs(p_DeltaTime)


	-- transitions
	if p_Bot.m_Player.controlledControllable ~= nil and not p_Bot.m_Player.controlledControllable:Is('ServerSoldierEntity') then
		-- already in this state - nothing to do
	elseif p_Bot.m_Player.attachedControllable ~= nil then
		p_Bot.m_InVehicle = false
		p_Bot.m_OnVehicle = true
		p_Bot:SetState(g_BotStates.States.OnVehicleIdle)
	else
		p_Bot.m_InVehicle = false
		p_Bot.m_OnVehicle = false
		p_Bot:SetState(g_BotStates.States.Moving)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleMoving:UpdateFast(p_Bot, p_DeltaTime)
	-- transition to attacking
	if p_Bot._ShootPlayer ~= nil then
		p_Bot:SetState(g_BotStates.States.InVehicleAttacking)
	end

	-- Stationary AA needs separate handling.
	if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA) then
		p_Bot:_UpdateStationaryAAVehicle(p_DeltaTime, false)
		return
	end

	if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
		-- assign new target after some time
		if p_Bot._DeployTimer > (Config.BotVehicleFireModeDuration - 0.5) and p_Bot._VehicleTakeoffTimer <= 0.0 then
			local s_Target = m_AirTargets:GetTarget(p_Bot.m_Player, Registry.VEHICLES.MAX_ATTACK_DISTANCE_JET)

			if s_Target ~= nil and p_Bot._ShootPlayerName ~= s_Target.name then
				p_Bot._ShootPlayerName = s_Target.name
				p_Bot._ShootPlayer = PlayerManager:GetPlayerByName(p_Bot._ShootPlayerName)
				p_Bot._ShootPlayerVehicleType = g_PlayerData:GetData(p_Bot._ShootPlayerName).Vehicle
				p_Bot._ShootModeTimer = Config.BotVehicleFireModeDuration
			else
				p_Bot:AbortAttack()
			end

			p_Bot._DeployTimer = 0.0
		else
			p_Bot._DeployTimer = p_Bot._DeployTimer + p_DeltaTime
		end
	end

	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryLauncher) or m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA)

	-- Fast code.
	if p_Bot.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
		m_VehicleMovement:UpdateTargetMovementVehicle(p_Bot)
	else
		m_VehicleMovement:UpdateVehicleLookAround(p_Bot, p_DeltaTime)
	end

	m_VehicleMovement:UpdateYawVehicle(p_Bot, false, s_IsStationaryLauncher)
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleMoving:UpdateVeryFast(p_Bot)
	-- update SingleStepEntry (Engine-requirement)
	p_Bot.m_Player.soldier:SingleStepEntry(p_Bot.m_Player.controlledEntryId)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleMoving:UpdateSlow(p_Bot, p_DeltaTime)
	if m_Vehicles:IsNotVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA) then
		p_Bot:_CheckForVehicleActions(p_DeltaTime, false)
		m_VehicleWeaponHandling:UpdateReloadVehicle(p_DeltaTime, p_Bot)
	end
	p_Bot:_DoExitVehicle()
end

if g_StateInVehicleMoving == nil then
	---@type StateInVehicleMoving
	g_StateInVehicleMoving = StateInVehicleMoving()
end

return g_StateInVehicleMoving
