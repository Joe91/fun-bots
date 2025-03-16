---@class StateInVehicleChopperControl
---@overload fun():StateInVehicleChopperControl
StateInVehicleChopperControl = class('StateInVehicleChopperControl')


-- bot-methods
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_ChopperControl = require('Bot/VehicleChopperControl')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

function StateInVehicleChopperControl:__init()
	self.m_IsAttacking = false
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleChopperControl:UpdatePrecheck(p_Bot)
	if not p_Bot.m_Player.soldier then
		p_Bot:SetState(g_BotStates.States.Idle)
		return
	end
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleChopperControl:Update(p_Bot, p_DeltaTime)
	local s_IsAttacking = p_Bot._ShootPlayer ~= nil
	-- update state-timer
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

	-- Common part.
	m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(p_Bot)

	if s_IsAttacking then
		m_VehicleAttacking:UpdateAttackingVehicle(p_DeltaTime, p_Bot)
		m_VehicleMovement:UpdateShootMovementVehicle(p_Bot) -- todo: irrelevant for chopper?
	else
		m_VehicleMovement:UpdateNormalMovementVehicle(p_DeltaTime, p_Bot)
	end


	-- Common things.
	m_VehicleMovement:UpdateSpeedOfMovementVehicle(p_DeltaTime, p_Bot, false)
	p_Bot:_UpdateInputs(p_DeltaTime)

	-- transition
	if p_Bot.m_Player.controlledControllable == nil or (p_Bot.m_Player.controlledControllable and p_Bot.m_Player.controlledControllable:Is('ServerSoldierEntity')) then
		p_Bot:SetState(g_BotStates.States.Moving)
	end
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleChopperControl:UpdateFast(p_Bot, p_DeltaTime)
	local s_IsAttacking = p_Bot._ShootPlayer ~= nil
	if s_IsAttacking then
		m_VehicleAiming:UpdateAimingVehicle(p_Bot, true)
	else
		m_ChopperControl:UpdateTargetMovementChopper(p_Bot)
	end

	m_ChopperControl:UpdateYawChopperPilot(p_Bot, s_IsAttacking)
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleChopperControl:UpdateVeryFast(p_Bot)
	-- update SingleStepEntry (Engine-requirement)
	p_Bot.m_Player.soldier:SingleStepEntry(p_Bot.m_Player.controlledEntryId)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleChopperControl:UpdateSlow(p_Bot, p_DeltaTime)
	local s_IsAttacking = p_Bot._ShootPlayer ~= nil
	p_Bot:_CheckForVehicleActions(p_DeltaTime, true)
	if not s_IsAttacking then
		m_VehicleWeaponHandling:UpdateReloadVehicle(p_DeltaTime, p_Bot)
	end
	p_Bot:_DoExitVehicle()
end

if g_StateInVehicleChopperControl == nil then
	---@type StateInVehicleChopperControl
	g_StateInVehicleChopperControl = StateInVehicleChopperControl()
end

return g_StateInVehicleChopperControl
