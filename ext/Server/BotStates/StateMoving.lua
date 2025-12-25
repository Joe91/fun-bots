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

function StateMoving:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:Update(p_Bot, p_DeltaTime)
	-- transition to other states:
	if p_Bot.m_Player.soldier == nil then
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
	p_Bot:UpdateWeaponSelection(p_DeltaTime) -- TODO: maybe compbine with reload now?

	p_Bot:UpdateNormalMovement(p_DeltaTime)

	p_Bot:UpdateSpeedOfMovement()
	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:UpdateFast(p_Bot, p_DeltaTime)
	p_Bot:UpdateTargetMovement()
end

---update in every frame
---@param p_Bot Bot
function StateMoving:UpdateVeryFast(p_Bot)
	-- Update yaw of soldier every tick.
	p_Bot:UpdateYaw()
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateMoving:UpdateSlow(p_Bot, p_DeltaTime)
	p_Bot:UpdateDeployAndReload(p_DeltaTime, true)
end

if g_StateMoving == nil then
	---@type StateMoving
	g_StateMoving = StateMoving()
end

return g_StateMoving
