---@class StateInVehicleJetControl
---@overload fun():StateInVehicleJetControl
StateInVehicleJetControl = class('StateInVehicleJetControl')


-- bot-methods
local m_AirTargets = require('AirTargets')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_JetControl = require('Bot/VehicleJetControl')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

function StateInVehicleJetControl:__init()
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleJetControl:Update(p_Bot, p_DeltaTime)
	-- transitions
	if p_Bot.m_Player.soldier == nil then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end

	local s_IsAttacking = p_Bot._ShootPlayer ~= nil
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- Common part.
	m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(p_Bot)

	if s_IsAttacking then
		m_VehicleAttacking:UpdateAttackingVehicle(p_DeltaTime, p_Bot)
	else
		m_JetControl:UpdateMovementJet(p_DeltaTime, p_Bot)
	end

	-- Common things.
	p_Bot:_UpdateInputs(p_DeltaTime)

	-- transition
	if p_Bot.m_Player.controlledControllable == nil or (p_Bot.m_Player.controlledControllable and p_Bot.m_Player.controlledControllable:Is('ServerSoldierEntity')) then
		p_Bot:SetState(g_BotStates.States.Moving)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleJetControl:UpdateFast(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier == nil then
		return
	end

	local s_IsAttacking = p_Bot._ShootPlayer ~= nil

	-- assign new target after some time
	if p_Bot._DeployTimer > (Config.BotVehicleFireModeDuration - 0.5) and p_Bot._VehicleTakeoffTimer <= 0.0 then
		local s_Target = m_AirTargets:GetTarget(p_Bot.m_Player, Registry.VEHICLES.MAX_ATTACK_DISTANCE_JET)
		if s_Target ~= nil then
			p_Bot._ShootPlayerId = s_Target.id
			p_Bot._ShootPlayer = PlayerManager:GetPlayerById(p_Bot._ShootPlayerId)
			p_Bot._ShootPlayerVehicleType = g_PlayerData:GetData(p_Bot._ShootPlayerId).Vehicle
			p_Bot._ShootModeTimer = Config.BotVehicleFireModeDuration
		elseif s_IsAttacking then
			p_Bot:AbortAttack()
		end

		p_Bot._DeployTimer = 0.0
	else
		p_Bot._DeployTimer = p_Bot._DeployTimer + p_DeltaTime
	end

	if s_IsAttacking then
		m_VehicleAiming:UpdateAimingVehicle(p_Bot, true)
	end

	m_JetControl:UpdateYawJet(p_Bot, s_IsAttacking)
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleJetControl:UpdateVeryFast(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleJetControl:UpdateSlow(p_Bot, p_DeltaTime)
	if p_Bot.m_Player.soldier == nil then
		return
	end
	-- p_Bot:_CheckForVehicleActions(p_DeltaTime, true) -- don't exit vehicle on low health?
	p_Bot:_DoExitVehicle()
end

if g_StateInVehicleJetControl == nil then
	---@type StateInVehicleJetControl
	g_StateInVehicleJetControl = StateInVehicleJetControl()
end

return g_StateInVehicleJetControl
