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

-- bot-methods
local m_Vehicles = require('Vehicles')
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

	if p_Bot._ShootPlayer ~= nil then
		p_Bot:SetState(g_BotStates.States.InVehicleAttacking)
		return
	end
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleMoving:Update(p_Bot, p_DeltaTime)
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime


	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryLauncher)

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
		-- already in this state, nothing to do
	elseif p_Bot.m_Player.attachedControllable ~= nil then
		p_Bot:SetState(g_BotStates.States.OnVehicleIdle)
	else
		p_Bot:SetState(g_BotStates.States.Moving)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleMoving:UpdateFast(p_Bot, p_DeltaTime)
	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryLauncher)

	-- Fast code.
	if p_Bot.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
		m_VehicleMovement:UpdateTargetMovementVehicle(p_Bot, p_DeltaTime)
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
	p_Bot:_CheckForVehicleActions(p_DeltaTime, false)
	m_VehicleWeaponHandling:UpdateReloadVehicle(p_DeltaTime, p_Bot)

	p_Bot:_DoExitVehicle()
end

if g_StateInVehicleMoving == nil then
	---@type StateInVehicleMoving
	g_StateInVehicleMoving = StateInVehicleMoving()
end

return g_StateInVehicleMoving
