---@class StateStaticMovement
---@overload fun():StateStaticMovement
StateStaticMovement = class('StateStaticMovement')

-- transitions to:
-- - static attacking
-- - idle (on death)

function StateStaticMovement:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateStaticMovement:Update(p_Bot, p_DeltaTime)
	-- transition to other states:
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end

	if p_Bot._ShootPlayer ~= nil then
		p_Bot:SetState(g_BotStates.States.StaticAttacking)
		return
	end

	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- default-handling
	p_Bot:UpdateWeaponSelection(p_DeltaTime) -- TODO: maybe compbine with reload now?

	p_Bot:UpdateStaticMovement()

	-- p_Bot:UpdateSpeedOfMovement() -- is this needed?
	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateStaticMovement:UpdateFast(p_Bot, p_DeltaTime)
	-- p_Bot:UpdateTargetMovement()
end

---update in every frame
---@param p_Bot Bot
function StateStaticMovement:UpdateVeryFast(p_Bot)
	-- Update yaw of soldier every tick.
	p_Bot:UpdateYaw()
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateStaticMovement:UpdateSlow(p_Bot, p_DeltaTime)
	-- p_Bot:UpdateDeployAndReload(p_DeltaTime, true) -- don't deploy in static movement
end

if g_StateStaticMovement == nil then
	---@type StateStaticMovement
	g_StateStaticMovement = StateStaticMovement()
end

return g_StateStaticMovement
