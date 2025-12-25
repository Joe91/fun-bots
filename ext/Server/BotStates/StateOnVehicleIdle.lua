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

function StateOnVehicleIdle:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleIdle:Update(p_Bot, p_DeltaTime)
	-- transitions
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end

	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime


	p_Bot:UpdateWeaponSelection(p_DeltaTime)

	p_Bot:UpdateDeployAndReload(p_DeltaTime, false)

	p_Bot:_UpdateInputs(p_DeltaTime)

	-- TODO: this seems to be little broken. Set absolute yaws and not relative ones
	p_Bot:_UpdateLookAroundPassenger(p_DeltaTime)
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
	-- Update yaw of soldier every tick.
	p_Bot:UpdateYaw()
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleIdle:UpdateSlow(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier == nil then
		return
	end
	p_Bot:_CheckForVehicleActions(p_DeltaTime, false)
	p_Bot:_DoExitVehicle()
end

if g_StateOnVehicleIdle == nil then
	---@type StateOnVehicleIdle
	g_StateOnVehicleIdle = StateOnVehicleIdle()
end

return g_StateOnVehicleIdle
