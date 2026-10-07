---@class StateAttacking
---@overload fun():StateAttacking
StateAttacking = class('StateAttacking')

local m_Utilities = require('__shared/Utilities')

-- Seconds a bot runs after the target of an action (C4, repair, revive, into a vehicle) at most: a moving target (a
-- vehicle driving on) made it run around it without end. Then C4 isn't used for CHASE_COOLDOWN seconds.
local CHASE_MAX = 8.0
local CHASE_COOLDOWN = 20.0


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
		p_Bot._Pushing = false
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
	if p_Bot._ShootPlayer == nil then
		p_Bot._Pushing = false
		p_Bot:SetState(g_BotStates.States.Moving)
		return
	end

	-- use state-timer to change bot movement during attack
	if p_Bot.m_StateTimer <= 0.0 then
		p_Bot.m_StateTimer = 3.0 + MathUtils:GetRandom(-1.0, 2.0)
		if m_Utilities:CheckProbability(Registry.BOT.PROBABILITY_STOP_TO_SHOOT) then
			p_Bot._MoveWhileShooting = false
		else
			p_Bot._MoveWhileShooting = true
		end
		p_Bot._PushWhileShooting = m_Utilities:CheckProbability(Registry.BOT.RUSH_PUSH_PROBABILITY)
	end
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer - p_DeltaTime


	-- default-handling
	p_Bot:UpdateWeaponSelection(p_DeltaTime) -- TODO: maybe combine with reload now?
	-- In an MCOM-zone: arm / disarm also when the fight started there (BotZoneMovement).
	p_Bot:UpdateZoneSubObjective(p_DeltaTime)

	local s_Action = p_Bot._ActiveAction
	-- The time counts per target: the action is broken off and started again now and then.
	if p_Bot._ChaseTarget ~= p_Bot._ShootPlayer then
		p_Bot._ChaseTarget = p_Bot._ShootPlayer
		p_Bot._ChaseTime = 0.0
	end
	if s_Action == BotActionFlags.ReviveActive or s_Action == BotActionFlags.EnterVehicleActive or
		s_Action == BotActionFlags.RepairActive or s_Action == BotActionFlags.C4Active then
		p_Bot._ChaseTime = p_Bot._ChaseTime + p_DeltaTime
		if p_Bot._ChaseTime > CHASE_MAX then
			p_Bot._ChaseTime = 0.0
			p_Bot._ChaseCooldown = SharedUtils:GetTime() + CHASE_COOLDOWN
			p_Bot:_ResetActionFlag(s_Action)
			p_Bot._WeaponToUse = BotWeapons.Primary
			p_Bot._TargetPitch = 0.0
			p_Bot:AbortAttack()
			return
		end
	end

	-- TODO: split revive, repari, c4 and so on
	p_Bot:UpdateAttacking(p_DeltaTime)
	local s_Pushing = false
	if p_Bot._ActiveAction == BotActionFlags.ReviveActive or
		p_Bot._ActiveAction == BotActionFlags.EnterVehicleActive or
		p_Bot._ActiveAction == BotActionFlags.RepairActive or
		p_Bot._ActiveAction == BotActionFlags.C4Active then
		p_Bot:UpdateMovementSprintToTarget(p_DeltaTime)
	elseif p_Bot._ShootPlayer ~= nil and p_Bot:ShouldPushWhileShooting() then
		-- Rush: on to the MCOM while shooting.
		p_Bot:UpdatePushMovement(p_DeltaTime)
		s_Pushing = true
	else
		p_Bot:UpdateShootMovement(p_DeltaTime)
	end
	p_Bot._Pushing = s_Pushing

	if not s_Pushing then
		p_Bot:UpdateSpeedOfMovement(true)
	end
	p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateAttacking:UpdateFast(p_Bot, p_DeltaTime)
	p_Bot:UpdateAiming(p_DeltaTime)
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
