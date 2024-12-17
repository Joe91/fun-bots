---@class StateOnVehicleAttacking
---@overload fun():StateOnVehicleAttacking
StateOnVehicleAttacking = class('StateOnVehicleAttacking')

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
local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

function StateOnVehicleAttacking:__init()
	-- Nothing to do.
end

---update in every frame
---@param p_Bot Bot
function StateOnVehicleAttacking:UpdatePrecheck(p_Bot)
	if not p_Bot.m_Player.soldier then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
	if p_Bot._ShootPlayer == nil then
		p_Bot:SetState(g_BotStates.States.OnVehicleIdle)
		return
	end
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleAttacking:Update(p_Bot, p_DeltaTime)
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- Common part.
	m_BotWeaponHandling:UpdateWeaponSelection(p_Bot)

	m_BotAttacking:UpdateAttacking(p_DeltaTime, p_Bot)

	p_Bot:_UpdateInputs(p_DeltaTime)


	if p_Bot.m_Player.controlledControllable ~= nil and not p_Bot.m_Player.controlledControllable:Is('ServerSoldierEntity') then
		p_Bot:SetState(g_BotStates.States.InVehicleMoving)
	elseif p_Bot.m_Player.attachedControllable ~= nil then
		-- already in this state - nothing to do
	else
		p_Bot:SetState(g_BotStates.States.Attacking)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleAttacking:UpdateFast(p_Bot, p_DeltaTime)
	m_BotAiming:UpdateAiming(p_Bot)
end

---update in every frame
---@param p_Bot Bot
function StateOnVehicleAttacking:UpdateVeryFast(p_Bot)
	-- update SingleStepEntry (Engine-requirement)
	p_Bot.m_Player.soldier:SingleStepEntry(p_Bot.m_Player.controlledEntryId)
	-- Update yaw of soldier every tick.
	m_BotMovement:UpdateYaw(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleAttacking:UpdateSlow(p_Bot, p_DeltaTime)
	p_Bot:_SetActiveVarsSlow()

	p_Bot:_CheckForVehicleActions(p_DeltaTime, true)
	p_Bot:_DoExitVehicle()
end

if g_StateOnVehicleAttacking == nil then
	---@type StateOnVehicleAttacking
	g_StateOnVehicleAttacking = StateOnVehicleAttacking()
end

return g_StateOnVehicleAttacking
