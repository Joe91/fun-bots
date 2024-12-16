---@class StateMoving
---@overload fun():StateMoving
StateMoving = class('StateMoving')

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

function StateMoving:__init()
	-- Nothing to do.
end

---update in every frame
---@param p_Bot Bot
function StateMoving:UpdatePrecheck(p_Bot)
	if not p_Bot.m_Player.soldier then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:Update(p_Bot, p_DeltaTime)
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- transition back to idle already outside

	-- default-handling
	m_BotWeaponHandling:UpdateWeaponSelection(p_Bot) -- TODO: maybe compbine with reload now?

	m_BotMovement:UpdateNormalMovement(p_DeltaTime, p_Bot)

	m_BotMovement:UpdateSpeedOfMovement(p_Bot)
	p_Bot:_UpdateInputs(p_DeltaTime)


	-- transition to attacking in fast-code
	-- TODO: transition to revive

	-- TODO: transition to repair

	-- TODO: transition to vehicle with enter-vehicle functions (this is not needed this way)
	if p_Bot.m_Player.controlledControllable ~= nil and not p_Bot.m_Player.controlledControllable:Is('ServerSoldierEntity') then
		p_Bot.m_InVehicle = true
		p_Bot.m_OnVehicle = false
		p_Bot:SetState(g_BotStates.States.InVehicleMoving)
	elseif p_Bot.m_Player.attachedControllable ~= nil then
		p_Bot.m_InVehicle = false
		p_Bot.m_OnVehicle = true
		p_Bot:SetState(g_BotStates.States.OnVehicleIdle)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:UpdateFast(p_Bot, p_DeltaTime)
	-- transition to attacking in fast-code
	if p_Bot._ShootPlayer ~= nil then
		p_Bot:SetState(g_BotStates.States.Attacking)
	end

	m_BotMovement:UpdateTargetMovement(p_Bot)
end

---update in every frame
---@param p_Bot Bot
function StateMoving:UpdateVeryFast(p_Bot)
	-- update SingleStepEntry (Engine-requirement)
	p_Bot.m_Player.soldier:SingleStepEntry(p_Bot.m_Player.controlledEntryId)
	-- Update yaw of soldier every tick.
	m_BotMovement:UpdateYaw(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:UpdateSlow(p_Bot, p_DeltaTime)
	m_BotWeaponHandling:UpdateDeployAndReload(p_DeltaTime, p_Bot, true)
end

if g_StateMoving == nil then
	---@type StateMoving
	g_StateMoving = StateMoving()
end

return g_StateMoving
