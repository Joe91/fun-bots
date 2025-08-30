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
-- Update very fast (0.05) ? Needed? Aiming?
-- Update fast (0.1) ? Movement, Reactions.
-- (Update medium? Maybe some things in between).
-- Update slow (1.0) ? Reload, Deploy, (Obstacle-Handling).

---@param p_DeltaTime number
function Bot:OnUpdatePassPostFrame(p_DeltaTime)
	local s_Soldier = self.m_Player.soldier

	-- Bot not alive, check for respawn
	if not s_Soldier then
		self._UpdateTimer = self._UpdateTimer + p_DeltaTime -- Reusage of updateTimer.

		if self._UpdateTimer > Registry.BOT.BOT_UPDATE_CYCLE then
			self:_UpdateRespawn(Registry.BOT.BOT_UPDATE_CYCLE)
			self._UpdateTimer = 0.0
		end

		return
	end

	s_Soldier:SingleStepEntry(self.m_Player.controlledEntryId)

	-- Bot cannot move yet.
	if not Globals.IsInputAllowed or self._SpawnProtectionTimer > 0.0 then
		-- Alive, but no inputs allowed yet → look around.
		self._UpdateTimer = self._UpdateTimer + p_DeltaTime -- Reusage of updateTimer.

		if self._UpdateTimer > Registry.BOT.BOT_UPDATE_CYCLE then
			if self._SpawnProtectionTimer > 0.0 then
				self._SpawnProtectionTimer = self._SpawnProtectionTimer - Registry.BOT.BOT_UPDATE_CYCLE
			else
				self._SpawnProtectionTimer = 0.0
			end

			m_BotMovement:UpdateYaw(self)
			m_BotMovement:LookAround(self, Registry.BOT.BOT_UPDATE_CYCLE)
			self:_UpdateInputs()
			self._UpdateTimer = 0.0
		end
		return
	end

	-- Update timer.
	self._UpdateFastTimer = self._UpdateFastTimer + p_DeltaTime

	if self._UpdateFastTimer >= Registry.BOT.BOT_FAST_UPDATE_CYCLE then
		-- Fast timer function will call the slow timer functions
		self:FastTimerUpdate(p_DeltaTime)
		self._UpdateFastTimer = 0.0
	end

	-- NOTE: Very fast code.
	-- Update yaw of soldier every tick.
	if not self.m_InVehicle then
		m_BotMovement:UpdateYaw(self)
	end
end

---comment
---@param p_DeltaTime number
function Bot:FastTimerUpdate(p_DeltaTime)
	-- Increment slow timer.
	self._UpdateTimer = self._UpdateTimer + self._UpdateFastTimer

	-- Detect modes.
	self:_SetActiveVars()

	-- Old movement-modes -- remove one day?
	if self:IsStaticMovement() then
		m_BotMovement:UpdateStaticMovement(self)
		self:_UpdateInputs()
		m_BotMovement:UpdateYaw(self)
		self._UpdateFastTimer = 0.0
		return
	end

	-- Timeout after revive. Do nothing.
	if self._ActiveDelay > 0.0 then
		self._ActiveDelay = self._ActiveDelay - p_DeltaTime
		if self._ActiveDelay <= 0.0 and self.m_Player.soldier ~= nil then
			-- accept revive
			self:_SetInput(EntryInputActionEnum.EIACycleRadioChannel, 1)
			self:_UpdateInputs()
			self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			self._SpawnDelayTimer = 0.0 --reset spawn-delay on revive
		end
		return
	end

	------------------ CODE OF BEHAVIOUR STARTS HERE ---------------------
	local s_IsAttacking = self._ShootPlayer ~= nil -- Can be either attacking or reviving or enter of a vehicle with a player.

	-- Bot is a Passenger of a boat, for example.
	if self.m_OnVehicle then
		self:OnVehicleFastTimerUpdate(s_IsAttacking)
		return
	end

	-- Bot is in a vehicle
	if self.m_InVehicle then
		self:InVehicleFastTimerUpdate(s_IsAttacking)
		return
	end

	-- Sync slow code with fast code. Therefore, execute the slow code first.
	if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
		self:SoldierSlowTimerUpdate(s_IsAttacking)
	end

	-- Fast code.
	if s_IsAttacking then
		m_BotAiming:UpdateAiming(self)
	else
		m_BotMovement:UpdateTargetMovement(self)
	end
end

---comment
---@param p_IsAttacking boolean
function Bot:SoldierSlowTimerUpdate(p_IsAttacking)
	-- Common part.
	m_BotWeaponHandling:UpdateWeaponSelection(self)

	-- Differ attacking.
	if p_IsAttacking then
		m_BotAttacking:UpdateAttacking(self)
		if self._ActiveAction == BotActionFlags.ReviveActive or
			self._ActiveAction == BotActionFlags.EnterVehicleActive or
			self._ActiveAction == BotActionFlags.RepairActive or
			self._ActiveAction == BotActionFlags.C4Active then
			m_BotMovement:UpdateMovementSprintToTarget(self)
		else
			m_BotMovement:UpdateShootMovement(self)
		end
	else
		m_BotWeaponHandling:UpdateDeployAndReload(self, true)
		m_BotMovement:UpdateNormalMovement(self)
		if self.m_Player.soldier == nil then
			return
		end
	end

	-- Common things.
	m_BotMovement:UpdateSpeedOfMovement(self)
	self:_UpdateInputs()

	self._UpdateTimer = 0.0
end

---comment
---@param p_IsAttacking boolean
function Bot:OnVehicleFastTimerUpdate(p_IsAttacking)
	-- Sync slow code with fast code. Therefore, execute the slow code first.
	if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
		-- Common part.
		m_BotWeaponHandling:UpdateWeaponSelection(self)

		-- Differ attacking.
		if p_IsAttacking then
			m_BotAttacking:UpdateAttacking(self)
		else
			m_BotWeaponHandling:UpdateDeployAndReload(self, false)
		end

		self:_UpdateInputs()
		self:_CheckForVehicleActions(self._UpdateTimer, p_IsAttacking)

		-- Only exit at this point and abort afterwards.
		if self:_DoExitVehicle() then
			return
		end

		self._UpdateTimer = 0.0
	end

	-- Fast code.
	if p_IsAttacking then
		m_BotAiming:UpdateAiming(self)
	else
		self:_UpdateLookAroundPassenger(Registry.BOT.BOT_FAST_UPDATE_CYCLE)
	end
end

---comment
---@param p_IsAttacking boolean
function Bot:InVehicleFastTimerUpdate(p_IsAttacking)
	-- Stationary AA needs separate handling.
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
		self:_UpdateStationaryAAVehicle(p_IsAttacking)

		if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
			-- Common part.
			m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(self)

			-- Differ attacking.
			if p_IsAttacking then
				m_VehicleAttacking:UpdateAttackStationaryAAVehicle(self)
			end

			self:_UpdateInputs()
			self._UpdateTimer = 0.0

			self:_DoExitVehicle()
		end

		return
	end

	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		-- assign new target after some time
		if self._DeployTimer > (Config.BotVehicleFireModeDuration - 0.5) and self._VehicleTakeoffTimer <= 0.0 then
			local s_Target = m_AirTargets:GetTarget(self.m_Player, Registry.VEHICLES.MAX_ATTACK_DISTANCE_JET)

			if s_Target ~= nil then
				self._ShootPlayerName = s_Target.name
				self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
				self._ShootPlayerVehicleType = m_Vehicles:FindOutVehicleType(self._ShootPlayer)
				self._ShootModeTimer = Config.BotVehicleFireModeDuration
			else
				self:AbortAttack()
			end

			self._DeployTimer = 0.0
		else
			self._DeployTimer = self._DeployTimer + Registry.BOT.BOT_FAST_UPDATE_CYCLE
		end
	end

	local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryLauncher) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA)

	-- Sync slow code with fast code. Therefore, execute the slow code first.
	if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
		-- Common part.
		m_VehicleWeaponHandling:UpdateWeaponSelectionVehicle(self)

		-- Differ attacking.
		if p_IsAttacking then
			m_VehicleAttacking:UpdateAttackingVehicle(self)
			if Config.VehicleMoveWhileShooting and m_Vehicles:IsNotVehicleTerrain(self.m_ActiveVehicle, VehicleTerrains.Air) then
				if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
					m_VehicleMovement:UpdateNormalMovementVehicle(self)
				else
					m_VehicleMovement:UpdateShootMovementVehicle(self)
				end
			else
				m_VehicleMovement:UpdateShootMovementVehicle(self)
			end
		else
			m_VehicleWeaponHandling:UpdateReloadVehicle(self)
			if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- Only if driver.
				m_VehicleMovement:UpdateNormalMovementVehicle(self)
			end
		end

		-- Common things.
		m_VehicleMovement:UpdateSpeedOfMovementVehicle(self, p_IsAttacking)
		self:_UpdateInputs()
		self:_CheckForVehicleActions(self._UpdateTimer, p_IsAttacking)

		-- Only exit at this point and abort afterwards.
		if self:_DoExitVehicle() then
			return
		end

		self._UpdateTimer = 0.0
	end

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
			m_VehicleMovement:UpdateVehicleLookAround(self, self._UpdateFastTimer)
		end
	end

	m_VehicleMovement:UpdateYawVehicle(self, p_IsAttacking, s_IsStationaryLauncher)
end
