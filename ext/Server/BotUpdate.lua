---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type AirTargets
local m_AirTargets = require('AirTargets')
---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)

local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

-- Update frame (every Cycle).
-- Update very fast (0.03) ? Needed? Aiming?
-- Update fast (0.1) ? Movement, Reactions.
-- (Update medium? Maybe some things in between).
-- Update slow (0.5) ? Reload, Deploy, (Obstacle-Handling).

-- -- Old movement-modes -- remove one day?
-- if self:IsStaticMovement() then
-- 	m_BotMovement:UpdateStaticMovement(self)
-- 	self:_UpdateInputs(p_DeltaTime)
-- 	m_BotMovement:UpdateYaw(self)
-- 	self._UpdateFastTimer = 0.0
-- 	return
-- end

-- update L0, called every tick
function Bot:UpdateL0()
	self.m_ActiveState.UpdateVeryFast(self.m_ActiveState, self)

	-- local s_Soldier = self.m_Player.soldier
	-- if not s_Soldier then
	-- 	return
	-- end

	-- s_Soldier:SingleStepEntry(self.m_Player.controlledEntryId)

	-- -- Update yaw of soldier every tick.
	-- if not self.m_InVehicle then
	-- 	m_BotMovement:UpdateYaw(self)
	-- end
end

-- very fast Bot-Code
function Bot:UpdateL1(p_DeltaTime)
	self.m_ActiveState.UpdateFast(self.m_ActiveState, self, p_DeltaTime)


	local s_Soldier = self.m_Player.soldier
	-- don't do stuff if not alive or not allowed to move
	if not s_Soldier or not Globals.IsInputAllowed or self._SpawnProtectionTimer > 0.0 then
		return
	end

	self:_SetActiveVars()

	-- -- Timeout after revive. Do nothing.
	-- if self._ActiveDelay > 0.0 then
	-- 	self._ActiveDelay = self._ActiveDelay - p_DeltaTime
	-- 	if self._ActiveDelay <= 0.0 and self.m_Player.soldier ~= nil then
	-- 		-- accept revive
	-- 		self:_SetInput(EntryInputActionEnum.EIACycleRadioChannel, 1)
	-- 		self:_UpdateInputs(p_DeltaTime)
	-- 		self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
	-- 		self._SpawnDelayTimer = 0.0 --reset spawn-delay on revive
	-- 	end
	-- 	return
	-- end

	local s_IsAttacking = self._ShootPlayer ~= nil

	-- Bot is a Passenger of a boat, for example.
	if self.m_OnVehicle then
		self:OnVehicleFastTimerUpdate(p_DeltaTime, s_IsAttacking)
	elseif self.m_InVehicle then -- Bot is in a vehicle
		self:InVehicleFastTimerUpdate(p_DeltaTime, s_IsAttacking)
	else                      -- soldier
		-- -- Fast code.
		-- if s_IsAttacking then
		-- 	m_BotAiming:UpdateAiming(self)
		-- else
		-- 	m_BotMovement:UpdateTargetMovement(self)
		-- end
	end
end

-- normal fast Bot-Code
function Bot:UpdateL2(p_DeltaTime)
	self.m_ActiveState.Update(self.m_ActiveState, self, p_DeltaTime)

	-- local s_Soldier = self.m_Player.soldier
	-- -- Bot not alive, check for respawn
	-- if not s_Soldier then
	-- 	self:_UpdateRespawn(p_DeltaTime)
	-- 	return
	-- end

	-- -- Bot cannot move yet.
	-- if not Globals.IsInputAllowed or self._SpawnProtectionTimer > 0.0 then
	-- 	if self._SpawnProtectionTimer > 0.0 then
	-- 		self._SpawnProtectionTimer = self._SpawnProtectionTimer - p_DeltaTime
	-- 	end

	-- 	m_BotMovement:UpdateYaw(self)
	-- 	m_BotMovement:LookAround(self, p_DeltaTime)
	-- 	self:_UpdateInputs(p_DeltaTime)
	-- 	return
	-- end

	-- -- Bot waiting for revive
	-- if self._ActiveDelay > 0 then
	-- 	return
	-- end

	local s_IsAttacking = self._ShootPlayer ~= nil

	-- Bot is a Passenger of a boat, for example.
	if self.m_OnVehicle then
		self:OnVehicleSlowTimerUpdate(p_DeltaTime, s_IsAttacking)
	elseif self.m_InVehicle then -- Bot is in a vehicle
		self:InVehicleSlowTimerUpdate(p_DeltaTime, s_IsAttacking)
		-- else                      -- soldier
		-- 	self:SoldierSlowTimerUpdate(p_DeltaTime, s_IsAttacking)
	end
end

-- slow Bot-Code TODO: fill some slow stuff here
function Bot:UpdateL3(p_DeltaTime)
	self.m_ActiveState.UpdateSlow(self.m_ActiveState, self, p_DeltaTime)


	-- local s_Soldier = self.m_Player.soldier
	-- if not s_Soldier or self._ActiveDelay > 0 or not Globals.IsInputAllowed or self._SpawnProtectionTimer > 0.0 then
	-- 	return
	-- end

	-- self:_SetActiveVarsSlow()

	local s_IsAttacking = self._ShootPlayer ~= nil
	if self.m_OnVehicle then
		self:_CheckForVehicleActions(p_DeltaTime, s_IsAttacking)
		self:_DoExitVehicle()
	elseif self.m_InVehicle then -- Bot is in a vehicle#
		if m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
			self:_CheckForVehicleActions(p_DeltaTime, s_IsAttacking)
			if not s_IsAttacking then
				m_VehicleWeaponHandling:UpdateReloadVehicle(p_DeltaTime, self)
			end
		end
		self:_DoExitVehicle()
	else -- soldier
		-- if not s_IsAttacking then
		-- 	m_BotWeaponHandling:UpdateDeployAndReload(p_DeltaTime, self, true)
		-- end
	end
end

---@param p_DeltaTime number
---@param p_IsAttacking boolean
function Bot:SoldierSlowTimerUpdate(p_DeltaTime, p_IsAttacking)
	-- -- Common part.
	-- m_BotWeaponHandling:UpdateWeaponSelection(self)

	-- Differ attacking.
	if p_IsAttacking then
		-- m_BotAttacking:UpdateAttacking(p_DeltaTime, self)
		-- if self._ActiveAction == BotActionFlags.ReviveActive or
		-- 	self._ActiveAction == BotActionFlags.EnterVehicleActive or
		-- 	self._ActiveAction == BotActionFlags.RepairActive or
		-- 	self._ActiveAction == BotActionFlags.C4Active then
		-- 	m_BotMovement:UpdateMovementSprintToTarget(p_DeltaTime, self)
		-- else
		-- 	m_BotMovement:UpdateShootMovement(p_DeltaTime, self)
		-- end
		-- else
		-- 	m_BotMovement:UpdateNormalMovement(p_DeltaTime, self)
		-- 	if self.m_Player.soldier == nil then
		-- 		return
		-- 	end
	end

	-- -- Common things.
	-- m_BotMovement:UpdateSpeedOfMovement(self)
	-- self:_UpdateInputs(p_DeltaTime)
end

---@param p_DeltaTime number
---@param p_IsAttacking boolean
function Bot:OnVehicleSlowTimerUpdate(p_DeltaTime, p_IsAttacking)
	-- Common part.
	m_BotWeaponHandling:UpdateWeaponSelection(self)

	-- Differ attacking.
	if p_IsAttacking then
		m_BotAttacking:UpdateAttacking(p_DeltaTime, self)
	else
		m_BotWeaponHandling:UpdateDeployAndReload(p_DeltaTime, self, false)
	end

	self:_UpdateInputs(p_DeltaTime)
end

---@param p_DeltaTime number
---@param p_IsAttacking boolean
function Bot:OnVehicleFastTimerUpdate(p_DeltaTime, p_IsAttacking)
	-- Fast code.
	if p_IsAttacking then
		m_BotAiming:UpdateAiming(self)
	else
		self:_UpdateLookAroundPassenger(p_DeltaTime)
	end
end

---@param p_DeltaTime number
---@param p_IsAttacking boolean
function Bot:InVehicleSlowTimerUpdate(p_DeltaTime, p_IsAttacking)
	-- Stationary AA needs separate handling.
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
		-- Common part.
		m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(self)

		-- Differ attacking.
		if p_IsAttacking then
			m_VehicleAttacking:UpdateAttackStationaryAAVehicle(self)
		end

		self:_UpdateInputs(p_DeltaTime)
		return
	end


	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryLauncher) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA)

	-- Sync slow code with fast code. Therefore, execute the slow code first.

	-- Common part.
	m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(self)

	-- Differ attacking.
	if p_IsAttacking then
		m_VehicleAttacking:UpdateAttackingVehicle(p_DeltaTime, self)
		if Config.VehicleMoveWhileShooting and m_Vehicles:IsNotVehicleTerrain(self.m_ActiveVehicle, VehicleTerrains.Air) then
			if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
				m_VehicleMovement:UpdateNormalMovementVehicle(p_DeltaTime, self)
			else
				m_VehicleMovement:UpdateShootMovementVehicle(self)
			end
		else
			m_VehicleMovement:UpdateShootMovementVehicle(self)
		end
	else
		if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
			m_VehicleMovement:UpdateNormalMovementVehicle(p_DeltaTime, self)
		end
	end

	-- Common things.
	m_VehicleMovement:UpdateSpeedOfMovementVehicle(p_DeltaTime, self, p_IsAttacking)
	self:_UpdateInputs(p_DeltaTime)
end

---@param p_DeltaTime number
---@param p_IsAttacking boolean
function Bot:InVehicleFastTimerUpdate(p_DeltaTime, p_IsAttacking)
	-- Stationary AA needs separate handling.
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
		self:_UpdateStationaryAAVehicle(p_DeltaTime, p_IsAttacking)
		return
	end

	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		-- assign new target after some time
		if self._DeployTimer > (Config.BotVehicleFireModeDuration - 0.5) and self._VehicleTakeoffTimer <= 0.0 then
			local s_Target = m_AirTargets:GetTarget(self.m_Player, Registry.VEHICLES.MAX_ATTACK_DISTANCE_JET)

			if s_Target ~= nil and self._ShootPlayerName ~= s_Target.name then
				self._ShootPlayerName = s_Target.name
				self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
				self._ShootPlayerVehicleType = g_PlayerData:GetData(self._ShootPlayerName).Vehicle
				self._ShootModeTimer = Config.BotVehicleFireModeDuration
			else
				self:AbortAttack()
			end

			self._DeployTimer = 0.0
		else
			self._DeployTimer = self._DeployTimer + p_DeltaTime
		end
	end

	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryLauncher) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA)

	-- Fast code.
	if p_IsAttacking then
		if m_Vehicles:IsAirVehicle(self.m_ActiveVehicle) then
			m_VehicleAiming:UpdateAimingVehicle(self, true)
		else
			if Config.VehicleMoveWhileShooting and m_Vehicles:IsNotVehicleTerrain(self.m_ActiveVehicle, VehicleTerrains.Air) then
				if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
					-- also update movement
					m_VehicleMovement:UpdateTargetMovementVehicle(self)
				end
			end
			m_VehicleAiming:UpdateAimingVehicle(self, false)
		end
	else
		if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
			m_VehicleMovement:UpdateTargetMovementVehicle(self)
		else
			m_VehicleMovement:UpdateVehicleLookAround(self, p_DeltaTime)
		end
	end

	m_VehicleMovement:UpdateYawVehicle(self, p_IsAttacking, s_IsStationaryLauncher)
end
