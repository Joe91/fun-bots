---@class StateInVehicleAttacking
---@overload fun():StateInVehicleAttacking
StateInVehicleAttacking = class('StateInVehicleAttacking')

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
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')
local m_Utilities = require('__shared/Utilities')

function StateInVehicleAttacking:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleAttacking:Update(p_Bot, p_DeltaTime)
	-- transitions
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
	if p_Bot._ShootPlayer == nil then
		p_Bot:SetState(g_BotStates.States.InVehicleMoving)
		return
	end

	-- use state-timer to change vehicle movement during attack
	if not m_Vehicles:IsGunship(p_Bot.m_ActiveVehicle) then
		if p_Bot.m_StateTimer == 0.0 or p_Bot.m_StateTimer > 5.0 then
			p_Bot.m_StateTimer = 0.0
			if m_Utilities:CheckProbablity(Registry.VEHICLES.PROBABILITY_VEHICLE_STOP_TO_SHOOT) then
				p_Bot._VehicleMoveWhileShooting = false
			else
				p_Bot._VehicleMoveWhileShooting = true
			end
		end
	else
		p_Bot._VehicleMoveWhileShooting = true
	end

	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryLauncher)

	-- Common part.
	m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(p_Bot)

	m_VehicleAttacking:UpdateAttackingVehicle(p_DeltaTime, p_Bot)
	if p_Bot._VehicleMoveWhileShooting and m_Vehicles:IsNotVehicleTerrain(p_Bot.m_ActiveVehicle, VehicleTerrains.Air) then
		if p_Bot.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
			m_VehicleMovement:UpdateNormalMovementVehicle(p_DeltaTime, p_Bot)
		else
			m_VehicleMovement:UpdateShootMovementVehicle(p_Bot)
		end
	else
		m_VehicleMovement:UpdateShootMovementVehicle(p_Bot)
	end

	-- Common things.
	m_VehicleMovement:UpdateSpeedOfMovementVehicle(p_DeltaTime, p_Bot, true)
	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleAttacking:UpdateFast(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier == nil then
		return
	end

	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryLauncher)

	-- Fast code.
	if m_Vehicles:IsAirVehicle(p_Bot.m_ActiveVehicle) then -- TODO: simplyfy once Gunship has own state and handling
		m_VehicleAiming:UpdateAimingVehicle(p_Bot, true)
	else
		if p_Bot._VehicleMoveWhileShooting and m_Vehicles:IsNotVehicleTerrain(p_Bot.m_ActiveVehicle, VehicleTerrains.Air) then
			if p_Bot.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
				-- also update movement
				m_VehicleMovement:UpdateTargetMovementVehicle(p_Bot, p_DeltaTime)
			end
		end
		m_VehicleAiming:UpdateAimingVehicle(p_Bot, false)
	end

	m_VehicleMovement:UpdateYawVehicle(p_Bot, true, s_IsStationaryLauncher)
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleAttacking:UpdateVeryFast(p_Bot)

end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleAttacking:UpdateSlow(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier then
		p_Bot:_CheckForVehicleActions(p_DeltaTime, true)
		p_Bot:_DoExitVehicle()
		return
	end
end

if g_StateInVehicleAttacking == nil then
	---@type StateInVehicleAttacking
	g_StateInVehicleAttacking = StateInVehicleAttacking()
end

return g_StateInVehicleAttacking
