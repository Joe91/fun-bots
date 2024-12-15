---@class StateIdle
---@overload fun():StateIdle
StateIdle = class('StateIdle')

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

function StateIdle:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot any
---@param p_DeltaTime any
function StateIdle:Update(p_Bot, p_DeltaTime)
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime


	local s_Soldier = p_Bot.m_Player.soldier
	-- Bot not alive, check for respawn
	if not s_Soldier then
		p_Bot:_UpdateRespawn(p_DeltaTime)
		return
	end

	-- Bot cannot move yet.
	if not Globals.IsInputAllowed or p_Bot._SpawnProtectionTimer > 0.0 then
		if p_Bot._SpawnProtectionTimer > 0.0 then
			p_Bot._SpawnProtectionTimer = p_Bot._SpawnProtectionTimer - p_DeltaTime
		end

		m_BotMovement:UpdateYaw(p_Bot)
		m_BotMovement:LookAround(p_Bot, p_DeltaTime)
		p_Bot:_UpdateInputs(p_DeltaTime)
		return
	end

	-- Bot waiting for revive
	if p_Bot._ActiveDelay > 0 then
		p_Bot._ActiveDelay = p_Bot._ActiveDelay - p_DeltaTime
		if p_Bot._ActiveDelay <= 0.0 and p_Bot.m_Player.soldier ~= nil then
			-- accept revive
			p_Bot:_SetInput(EntryInputActionEnum.EIACycleRadioChannel, 1)
			p_Bot:_UpdateInputs(p_DeltaTime)
			p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			p_Bot._SpawnDelayTimer = 0.0 --reset spawn-delay on revive
		end
		return
	end

	-- transition to moving
	p_Bot.m_ActiveState = g_BotStates.States.Moving
	p_Bot.m_StateTimer = 0.0
end

---fast update-function
---@param p_Bot any
---@param p_DeltaTime any
function StateIdle:UpdateFast(p_Bot, p_DeltaTime)
	-- nothing to do in idle
end

---update in every frame
---@param p_Bot any
function StateIdle:UpdateVeryFast(p_Bot)
	if not p_Bot.m_Player.soldier then return end

	-- update SingleStepEntry (Engine-requirement)
	p_Bot.m_Player.soldier:SingleStepEntry(p_Bot.m_Player.controlledEntryId)
	-- Update yaw of soldier every tick.
	m_BotMovement:UpdateYaw(p_Bot)
end

---slow update-function
---@param p_Bot any
---@param p_DeltaTime any
function StateIdle:UpdateSlow(p_Bot, p_DeltaTime)
	-- nothing to do in idle
end

if g_StateIdle == nil then
	---@type StateIdle
	g_StateIdle = StateIdle()
end

return g_StateIdle
