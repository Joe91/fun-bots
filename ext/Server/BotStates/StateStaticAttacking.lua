---@class StateStaticAttacking
---@overload fun():StateStaticAttacking
StateStaticAttacking = class('StateStaticAttacking')

-- transitions to:
-- - static movement
-- - idle (on death)

function StateStaticAttacking:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateStaticAttacking:Update(p_Bot, p_DeltaTime)
	-- transitions
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
	if p_Bot._ShootPlayer == nil then
		p_Bot:SetState(g_BotStates.States.StaticMovement)
		return
	end



	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer - p_DeltaTime
	p_Bot._MoveWhileShooting = false -- don't move in static attack (only for weapon-testing)

	-- default-handling
	p_Bot:UpdateWeaponSelection(p_DeltaTime)

	p_Bot:UpdateAttacking(p_DeltaTime)
	p_Bot:UpdateShootMovement(p_DeltaTime)
	p_Bot:UpdateSpeedOfMovement(true)

	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateStaticAttacking:UpdateFast(p_Bot, p_DeltaTime)
	p_Bot:UpdateAiming()
end

---update in every frame
---@param p_Bot Bot
function StateStaticAttacking:UpdateVeryFast(p_Bot)
	-- Update yaw of soldier every tick.
	p_Bot:UpdateYaw()
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateStaticAttacking:UpdateSlow(p_Bot, p_DeltaTime)
	p_Bot:_SetActiveVarsSlow() -- is this needed?
end

if g_StateStaticAttacking == nil then
	---@type StateStaticAttacking
	g_StateStaticAttacking = StateStaticAttacking()
end

return g_StateStaticAttacking
