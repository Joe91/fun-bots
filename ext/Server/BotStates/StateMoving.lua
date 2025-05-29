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

-- bot-methods
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')

function StateMoving:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:Update(p_Bot, p_DeltaTime)
	-- transition to other states:
	if not p_Bot.m_Player.soldier then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end

	if p_Bot._ShootPlayer ~= nil then
		p_Bot:SetState(g_BotStates.States.Attacking)
		return
	end

	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- default-handling
	m_BotWeaponHandling:UpdateWeaponSelection(p_Bot) -- TODO: maybe compbine with reload now?

	m_BotMovement:UpdateNormalMovement(p_DeltaTime, p_Bot)

	m_BotMovement:UpdateSpeedOfMovement(p_Bot)
	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:UpdateFast(p_Bot, p_DeltaTime)
	m_BotMovement:UpdateTargetMovement(p_Bot)
end

---update in every frame
---@param p_Bot Bot
function StateMoving:UpdateVeryFast(p_Bot)
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
function StateMoving:UpdateSlow(p_Bot, p_DeltaTime)
	m_BotWeaponHandling:UpdateDeployAndReload(p_DeltaTime, p_Bot, true)
end

if g_StateMoving == nil then
	---@type StateMoving
	g_StateMoving = StateMoving()
end

return g_StateMoving
