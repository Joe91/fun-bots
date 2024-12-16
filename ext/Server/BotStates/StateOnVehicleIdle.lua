---@class StateOnVehicleIdle
---@overload fun():StateOnVehicleIdle
StateOnVehicleIdle = class('StateOnVehicleIdle')

-- this class handles the following things:
-- - waiting for action
-- - waiting for revive
-- - waiting for respawn

-- transitions to:
-- - moving
-- (- vehicle-idle?)

---@type Utilities
local m_Utilities = require('__shared/Utilities')
-- bot-methods
local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

function StateOnVehicleIdle:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleIdle:Update(p_Bot, p_DeltaTime)
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime


	m_BotWeaponHandling:UpdateWeaponSelection(p_Bot)

	m_BotWeaponHandling:UpdateDeployAndReload(p_DeltaTime, p_Bot, false)

	p_Bot:_UpdateInputs(p_DeltaTime)

	-- TODO: this seems to be little broken. Set absolute yaws and not relative ones
	p_Bot:_UpdateLookAroundPassenger(p_DeltaTime)

	-- transitions
	if p_Bot.m_Player.controlledControllable ~= nil and not p_Bot.m_Player.controlledControllable:Is('ServerSoldierEntity') then
		p_Bot.m_InVehicle = true
		p_Bot.m_OnVehicle = false
		p_Bot:SetState(g_BotStates.States.InVehicleMoving)
	elseif p_Bot.m_Player.attachedControllable ~= nil then
		-- already in this state - nothing to do
	else
		p_Bot.m_InVehicle = false
		p_Bot.m_OnVehicle = false
		p_Bot:SetState(g_BotStates.States.Moving)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleIdle:UpdateFast(p_Bot, p_DeltaTime)
	-- trasition to attack
	if p_Bot._ShootPlayer ~= nil then
		p_Bot:SetState(g_BotStates.States.OnVehicleAttacking)
	end
end

---update in every frame
---@param p_Bot Bot
function StateOnVehicleIdle:UpdateVeryFast(p_Bot)
	-- update SingleStepEntry (Engine-requirement)
	p_Bot.m_Player.soldier:SingleStepEntry(p_Bot.m_Player.controlledEntryId)
	-- Update yaw of soldier every tick.
	m_BotMovement:UpdateYaw(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleIdle:UpdateSlow(p_Bot, p_DeltaTime)
	p_Bot:_CheckForVehicleActions(p_DeltaTime, false)
	p_Bot:_DoExitVehicle()
end

if g_StateOnVehicleIdle == nil then
	---@type StateOnVehicleIdle
	g_StateOnVehicleIdle = StateOnVehicleIdle()
end

return g_StateOnVehicleIdle
