---@class StateAttacking
---@overload fun():StateAttacking
StateAttacking = class('StateAttacking')

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

function StateAttacking:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateAttacking:Update(p_Bot, p_DeltaTime)
	-- transitions
	if not p_Bot.m_Player.soldier then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
	if p_Bot._ShootPlayer == nil then
		p_Bot:SetState(g_BotStates.States.Moving)
		return
	end

	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- default-handling
	m_BotWeaponHandling:UpdateWeaponSelection(p_Bot) -- TODO: maybe compbine with reload now?

	-- TODO: split revive, repari, c4 and so on
	m_BotAttacking:UpdateAttacking(p_DeltaTime, p_Bot)
	if p_Bot._ActiveAction == BotActionFlags.ReviveActive or
		p_Bot._ActiveAction == BotActionFlags.EnterVehicleActive or
		p_Bot._ActiveAction == BotActionFlags.RepairActive or
		p_Bot._ActiveAction == BotActionFlags.C4Active then
		m_BotMovement:UpdateMovementSprintToTarget(p_DeltaTime, p_Bot)
	else
		m_BotMovement:UpdateShootMovement(p_DeltaTime, p_Bot)
	end


	m_BotMovement:UpdateSpeedOfMovement(p_Bot)
	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateAttacking:UpdateFast(p_Bot, p_DeltaTime)
	m_BotAiming:UpdateAiming(p_Bot)
end

---update in every frame
---@param p_Bot Bot
function StateAttacking:UpdateVeryFast(p_Bot)
	if p_Bot.m_Player.soldier == nil then
		return
	end
	-- update SingleStepEntry (Engine-requirement)
	p_Bot.m_Player.soldier:SingleStepEntry(p_Bot.m_Player.controlledEntryId)
	-- Update yaw of soldier every tick.
	m_BotMovement:UpdateYaw(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateAttacking:UpdateSlow(p_Bot, p_DeltaTime)
	p_Bot:_SetActiveVarsSlow()
end

if g_StateAttacking == nil then
	---@type StateAttacking
	g_StateAttacking = StateAttacking()
end

return g_StateAttacking
