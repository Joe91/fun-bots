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

---An attack is promising while the target is still in an aircraft, in range and not behind the jet.
---@param p_Bot Bot
---@return boolean
local function _IsAttackPromising(p_Bot)
	local s_Target = p_Bot._ShootPlayer
	local s_TargetVehicle = s_Target and s_Target.soldier and s_Target.controlledControllable
	if s_TargetVehicle == nil or s_TargetVehicle:Is('ServerSoldierEntity') then
		return false
	end

	local s_Transform = p_Bot.m_Player.controlledControllable.transform
	local s_Trans = s_Transform.trans
	local s_TargetTrans = s_TargetVehicle.transform.trans
	local s_DiffX, s_DiffY, s_DiffZ = s_TargetTrans.x - s_Trans.x, s_TargetTrans.y - s_Trans.y, s_TargetTrans.z - s_Trans.z
	local s_Distance = math.sqrt(s_DiffX * s_DiffX + s_DiffY * s_DiffY + s_DiffZ * s_DiffZ)
	if s_Distance > Registry.VEHICLES.MAX_ATTACK_DISTANCE_JET then
		return false
	end
	if s_Distance < 1.0 then
		return true
	end

	local s_Forward = s_Transform.forward
	local s_Cos = (s_Forward.x * s_DiffX + s_Forward.y * s_DiffY + s_Forward.z * s_DiffZ) / s_Distance
	return s_Cos > math.cos(Registry.VEHICLES.JET_ATTACK_KEEP_ANGLE)
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

	-- Without a target scan often, to attack as soon as possible. While attacking keep the target (a new one right
	-- when the jet lined up spoiled the attack): go on while the attack is promising, else abort. A new target only
	-- after the abort (and the extending).
	local s_ScanInterval = s_IsAttacking and (Config.BotVehicleFireModeDuration - 0.5) or Registry.VEHICLES.JET_TARGET_SCAN_INTERVAL
	if p_Bot._DeployTimer > s_ScanInterval and p_Bot._VehicleTakeoffTimer <= 0.0 then
		if s_IsAttacking then
			if _IsAttackPromising(p_Bot) then
				p_Bot._ShootModeTimer = Config.BotVehicleFireModeDuration
			else
				p_Bot:AbortAttack()
			end
		else
			local s_Target = m_AirTargets:GetTarget(p_Bot.m_Player, Registry.VEHICLES.MAX_ATTACK_DISTANCE_JET,
				Registry.VEHICLES.JET_TARGET_ANGLE_PENALTY)
			local s_TargetData = s_Target and g_PlayerData:GetData(s_Target.id)
			if s_Target ~= nil and s_TargetData ~= nil then
				p_Bot._Pid_Jet_Pitch:Reset()
				p_Bot._Pid_Jet_Yaw:Reset()
				p_Bot._ShootPlayerId = s_Target.id
				p_Bot._ShootPlayer = PlayerManager:GetPlayerById(p_Bot._ShootPlayerId)
				p_Bot._ShootPlayerVehicleType = s_TargetData.Vehicle
				p_Bot._ShootModeTimer = Config.BotVehicleFireModeDuration
			end
		end

		p_Bot._DeployTimer = 0.0
	else
		p_Bot._DeployTimer = p_Bot._DeployTimer + p_DeltaTime
	end

	if s_IsAttacking then
		m_VehicleAiming:UpdateAimingVehicle(p_Bot, true, p_DeltaTime)
	end

	m_JetControl:UpdateYawJet(p_Bot, s_IsAttacking, p_DeltaTime)
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
	p_Bot:_DoExitVehicle()
end

if g_StateInVehicleJetControl == nil then
	---@type StateInVehicleJetControl
	g_StateInVehicleJetControl = StateInVehicleJetControl()
end

return g_StateInVehicleJetControl
