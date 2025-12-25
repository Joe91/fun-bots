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

function StateOnVehicleAttacking:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleAttacking:Update(p_Bot, p_DeltaTime)
	-- transitions
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
	if p_Bot._ShootPlayer == nil then
		p_Bot:SetState(g_BotStates.States.OnVehicleIdle)
		return
	end

	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- Common part.
	p_Bot:UpdateWeaponSelection(p_DeltaTime)

	p_Bot:UpdateAttacking(p_DeltaTime)

	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleAttacking:UpdateFast(p_Bot, p_DeltaTime)
	p_Bot:UpdateAiming()
end

---update in every frame
---@param p_Bot Bot
function StateOnVehicleAttacking:UpdateVeryFast(p_Bot)
	-- Update yaw of soldier every tick.
	p_Bot:UpdateYaw()
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateOnVehicleAttacking:UpdateSlow(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier == nil then
		return
	end
	p_Bot:_SetActiveVarsSlow()

	p_Bot:_CheckForVehicleActions(p_DeltaTime, true)
	p_Bot:_DoExitVehicle()
end

if g_StateOnVehicleAttacking == nil then
	---@type StateOnVehicleAttacking
	g_StateOnVehicleAttacking = StateOnVehicleAttacking()
end

return g_StateOnVehicleAttacking
