---@class StateAttacking
---@overload fun():StateAttacking
StateAttacking = class('StateAttacking')

local m_Utilities = require('__shared/Utilities')


-- this class handles the following things:
-- - moving along paths
-- - overcome obstacles

-- transitions to:
-- - attacking
-- - enter vehicle
-- - idle (on death)

function StateAttacking:__init()
	-- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateAttacking:Update(p_Bot, p_DeltaTime)
	-- transitions
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
	if p_Bot._ShootPlayer == nil then
		p_Bot:SetState(g_BotStates.States.Moving)
		return
	end

	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- use state-timer to change bot movement during attack
	if p_Bot.m_StateTimer == 0.0 or p_Bot.m_StateTimer > 3.0 then
		p_Bot.m_StateTimer = 0.0
		if m_Utilities:CheckProbablity(Registry.BOT.PROBABILITY_STOP_TO_SHOOT) then
			p_Bot._MoveWhileShooting = false
		else
			p_Bot._MoveWhileShooting = true
		end
	end


	-- default-handling
	p_Bot:UpdateWeaponSelection(p_DeltaTime) -- TODO: maybe compbine with reload now?

	-- TODO: split revive, repari, c4 and so on
	p_Bot:UpdateAttacking(p_DeltaTime)
	if p_Bot._ActiveAction == BotActionFlags.ReviveActive or
		p_Bot._ActiveAction == BotActionFlags.EnterVehicleActive or
		p_Bot._ActiveAction == BotActionFlags.RepairActive or
		p_Bot._ActiveAction == BotActionFlags.C4Active then
		p_Bot:UpdateMovementSprintToTarget(p_DeltaTime)
	else
		p_Bot:UpdateShootMovement(p_DeltaTime)
	end


	p_Bot:UpdateSpeedOfMovement()
	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateAttacking:UpdateFast(p_Bot, p_DeltaTime)
	p_Bot:UpdateAiming()
end

---update in every frame
---@param p_Bot Bot
function StateAttacking:UpdateVeryFast(p_Bot)
	-- Update yaw of soldier every tick.
	p_Bot:UpdateYaw()
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
