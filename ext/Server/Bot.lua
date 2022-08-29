---@class Bot
Bot = class('Bot')

require('__shared/Config')
require('PidController')

---@type NodeCollection
local m_NodeCollection = require('__shared/NodeCollection')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type Vehicles
local m_Vehicles = require("Vehicles")
---@type AirTargets
local m_AirTargets = require("AirTargets")
---@type Logger
local m_Logger = Logger("Bot", Debug.Server.BOT)

local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')



---@param p_Player Player
function Bot:__init(p_Player)
	--Player Object
	---@type Player
	self.m_Player = p_Player
	---@type string
	self.m_Name = p_Player.name
	---@type integer
	self.m_Id = p_Player.id

	--common settings
	---@type BotSpawnModes
	self._SpawnMode = BotSpawnModes.NoRespawn
	---@type BotMoveModes
	self._MoveMode = BotMoveModes.Standstill
	---@type BotKits|nil
	self.m_Kit = nil
	-- only used in BotSpawner
	---@type BotColors|integer|nil
	self.m_Color = nil
	---@type Weapon|nil
	self.m_ActiveWeapon = nil
	self.m_ActiveVehicle = nil
	---@type Weapon|nil
	self.m_Primary = nil
	---@type Weapon|nil
	self.m_Pistol = nil
	---@type Weapon|nil
	self.m_PrimaryGadget = nil
	---@type Weapon|nil
	self.m_SecondaryGadget = nil
	---@type Weapon|nil
	self.m_Grenade = nil
	---@type Weapon|nil
	self.m_Knife = nil
	self._Respawning = false

	--timers
	self._UpdateTimer = 0.0
	self._UpdateFastTimer = 0.0
	self._SpawnDelayTimer = 0.0
	self._WayWaitTimer = 0.0
	self._VehicleWaitTimer = 0.0
	self._VehicleHealthTimer = 0.0
	self._VehicleSeatTimer = 0.0
	self._VehicleTakeoffTimer = 0.0
	self._WayWaitYawTimer = 0.0
	self._ObstaceSequenceTimer = 0.0
	self._StuckTimer = 0.0
	self._ShotTimer = 0.0
	self._ShootModeTimer = 0.0
	self._ReloadTimer = 0.0
	self._DeployTimer = 0.0
	self._AttackModeMoveTimer = 0.0
	self._MeleeCooldownTimer = 0.0
	self._ShootTraceTimer = 0.0
	self._ActionTimer = 0.0
	self._BrakeTimer = 0.0
	self._SpawnProtectionTimer = 0.0
	self._SidewardsTimer = 0.0

	--shared movement vars
	---@type BotMoveModes
	self.m_ActiveMoveMode = BotMoveModes.Standstill
	---@type BotMoveSpeeds
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self.m_KnifeMode = false
	self.m_InVehicle = false
	self.m_OnVehicle = false

	---@class ActiveInput
	---@field value number
	---@field reset boolean

	---@type table<integer|EntryInputActionEnum, ActiveInput>
	self.m_ActiveInputs = {}

	-- sidwards movement
	self.m_YawOffset = 0.0
	self.m_StrafeValue = 0.0

	--advanced movement
	---@type BotAttackModes
	self._AttackMode = BotAttackModes.RandomNotSet
	---@type BotActionFlags
	self._ActiveAction = BotActionFlags.NoActionActive
	-- TODO: add emmylua type
	self._CurrentWayPoint = nil
	self._TargetYaw = 0.0
	self._TargetPitch = 0.0
	-- TODO: add emmylua type
	self._TargetPoint = nil
	-- TODO: add emmylua type
	self._NextTargetPoint = nil
	self._PathIndex = 0
	self._LastWayDistance = 0.0
	self._InvertPathDirection = false
	self._ExitVehicleActive = false
	self._ObstacleRetryCounter = 0
	---@type BotMoveSpeeds
	self._ZombieSpeedValue = BotMoveSpeeds.NoMovement
	self._Objective = ''
	self._OnSwitch = false

	-- vehicle stuff
	---@type integer|nil
	self._VehicleMovableId = nil
	self._LastVehicleYaw = 0.0
	self._VehicleReadyToShoot = false
	self._FullVehicleSteering = false
	self._VehicleDirBackPositive = false
	self._JetAbortAttackActive = false
	self._ExitVehicleHealth = 0.0
	self._LastVehicleHealth = 0.0
	self._TargetHeightAttack = 0.0
	---@type ControllableEntity|nil
	self._RepairVehicleEntity = nil
	-- PID Controllers
	-- normal driving
	---@type PidController
	self._Pid_Drv_Yaw = PidController(5, 0.05, 0.2, 1.0)
	-- chopper / plane
	---@type PidController
	self._Pid_Drv_Throttle = PidController(5, 0.05, 0.2, 1.0)
	---@type PidController
	self._Pid_Drv_Tilt = PidController(5, 0.05, 0.2, 1.0)
	---@type PidController
	self._Pid_Drv_Roll = PidController(5, 0.05, 0.2, 1.0)
	-- guns
	---@type PidController
	self._Pid_Att_Yaw = PidController(7, 0.4, 0.2, 1.0)
	---@type PidController
	self._Pid_Att_Pitch = PidController(7, 0.4, 0.2, 1.0)

	--shooting
	self._Shoot = false
	---@type Player|nil
	self._ShootPlayer = nil
	---@type VehicleTypes
	self._ShootPlayerVehicleType = VehicleTypes.NoVehicle
	self._ShootPlayerName = ""
	self._DistanceToPlayer = 0.0
	---@type BotWeapons
	self._WeaponToUse = BotWeapons.Primary
	-- TODO: add emmylua type
	self._ShootWayPoints = {}
	---@type Vec3[]
	self._KnifeWayPositions = {}
	self._Skill = 0.0
	self._SkillSniper = 0.0
	self._SkillFound = false

	--simple movement
	---@type BotMoveSpeeds
	self._BotSpeed = BotMoveSpeeds.NoMovement
	---@type Player|nil
	self._TargetPlayer = nil
end

-- =============================================
-- Events
-- =============================================

-- Update frame (every Cycle)
-- Update very fast (0.05) ? Needed? Aiming?
-- Update fast (0.1) ? Movement, Reactions
-- (Update medium? Maybe some things in between)
-- Update slow (1.0) ? Reload, Deploy, (Obstacle-Handling)

---@param p_DeltaTime number
function Bot:OnUpdatePassPostFrame(p_DeltaTime)
	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:SingleStepEntry(self.m_Player.controlledEntryId)
	end

	if self.m_Player.soldier == nil then -- player not alive
		self._UpdateTimer = self._UpdateTimer + p_DeltaTime -- reusage of updateTimer

		if self._UpdateTimer > Registry.BOT.BOT_UPDATE_CYCLE then
			self:_UpdateRespawn(Registry.BOT.BOT_UPDATE_CYCLE)
			self._UpdateTimer = 0.0
		end
	else -- player alive
		if Globals.IsInputAllowed and self._SpawnProtectionTimer <= 0.0 then
			-- update timer
			self._UpdateFastTimer = self._UpdateFastTimer + p_DeltaTime

			if self._UpdateFastTimer >= Registry.BOT.BOT_FAST_UPDATE_CYCLE then
				-- increment slow timer
				self._UpdateTimer = self._UpdateTimer + self._UpdateFastTimer

				-- detect modes
				self:_SetActiveVars()

				-- old movement-modes -- remove one day?
				if self:IsStaticMovement() then
					m_BotMovement:UpdateStaticMovement(self)
					self:_UpdateInputs()
					m_BotMovement:UpdateYaw(self)
					self._UpdateFastTimer = 0.0
					return
				end

				------------------ CODE OF BEHAVIOUR STARTS HERE ---------------------
				local s_Attacking = self._ShootPlayer ~= nil -- can be either attacking or reviving or enter of a vehicle with a player

				if not self.m_InVehicle and not self.m_OnVehicle then
					-- sync slow code with fast code. Therefore execute the slow code first
					if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
						-- common part
						m_BotWeaponHandling:UpdateWeaponSelection(self)

						-- differ attacking
						if s_Attacking then
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

						-- common things
						m_BotMovement:UpdateSpeedOfMovement(self)
						self:_UpdateInputs()

						self._UpdateTimer = 0.0
					end

					-- fast code
					if s_Attacking then
						m_BotAiming:UpdateAiming(self)
					else
						m_BotMovement:UpdateTargetMovement(self)
					end

				else -- bot in vehicle
					-- sataionary AA needs separate handling
					if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
						self:_UpdateStationaryAAVehicle(s_Attacking)

						if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
							-- common part
							self:_UpdateWeaponSelectionVehicle()

							-- differ attacking
							if s_Attacking then
								m_VehicleAttacking:UpdateAttackStationaryAAVehicle(self)
							end

							self:_UpdateInputs()
							self._UpdateTimer = 0.0
						end
					else
						if self.m_OnVehicle then -- passenger of boat for example
							-- sync slow code with fast code. Therefore execute the slow code first
							if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
								-- common part
								m_BotWeaponHandling:UpdateWeaponSelection(self)

								-- differ attacking
								if s_Attacking then
									m_BotAttacking:UpdateAttacking(self)
								else
									m_BotWeaponHandling:UpdateDeployAndReload(self, false)
								end

								self:_UpdateInputs()
								self:_CheckForVehicleActions(self._UpdateTimer)

								-- only exit at this point and abort afterwards
								if self:_DoExitVehicle() then
									return
								end

								self._UpdateTimer = 0.0
							end

							-- fast code
							if s_Attacking then
								m_BotAiming:UpdateAiming(self)
							else
								self:_UpdateLookAroundPassenger(Registry.BOT.BOT_FAST_UPDATE_CYCLE)
							end
						else -- normal vehicle --> self.m_InVehicle == true
							local s_IsStationaryLauncher = m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryLauncher)

							-- sync slow code with fast code. Therefore execute the slow code first
							if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
								-- common part
								self:_UpdateWeaponSelectionVehicle()

								-- differ attacking
								if s_Attacking then
									m_VehicleAttacking:UpdateAttackingVehicle(self)
									m_VehicleMovement:UpdateShootMovementVehicle(self)
								else
									self:_UpdateReloadVehicle()
									if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- only if driver
										m_VehicleMovement:UpdateNormalMovementVehicle(self)
									end
								end

								-- common things
								m_VehicleMovement:UpdateSpeedOfMovementVehicle(self)
								self:_UpdateInputs()
								self:_CheckForVehicleActions(self._UpdateTimer)

								-- only exit at this point and abort afterwards
								if self:_DoExitVehicle() then
									return
								end

								self._UpdateTimer = 0.0
							end

							-- fast code
							if s_Attacking then
								if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) or
									m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
									m_VehicleAiming:UpdateAimingVehicleAdvanced(self)
								else
									m_VehicleAiming:UpdateAimingVehicle(self)
								end
							else
								if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- only if driver
									m_VehicleMovement:UpdateTargetMovementVehicle(self)
								else
									m_VehicleMovement:UpdateVehicleLookAround(self, self._UpdateFastTimer)
								end
							end
							m_VehicleMovement:UpdateYawVehicle(self, s_Attacking, s_IsStationaryLauncher)
						end
					end
				end
				self._UpdateFastTimer = 0.0
			end

			-- very fast code
			if not self.m_InVehicle then
				m_BotMovement:UpdateYaw(self)
			end

		else -- alive, but no inputs allowed yet --> look around
			self._UpdateTimer = self._UpdateTimer + p_DeltaTime -- reusage of updateTimer

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
		end
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================

---@param p_Player Player
function Bot:Revive(p_Player)
	if self.m_Kit == BotKits.Assault and p_Player.corpse and not p_Player.corpse.isDead and not Globals.IsGm then
		if Config.BotsRevive then
			self._ActiveAction = BotActionFlags.ReviveActive
			self._ShootPlayer = nil
			self._ShootPlayerName = p_Player.name
		end
	end
end

---@param p_Player Player
function Bot:Repair(p_Player)
	if self.m_Kit == BotKits.Engineer and p_Player.soldier ~= nil and p_Player.controlledControllable ~= nil then
		self._ActiveAction = BotActionFlags.RepairActive
		self._RepairVehicleEntity = p_Player.controlledControllable
		self._LastVehicleHealth = 0.0
		self._ShootPlayer = nil
		self._ShootPlayerName = p_Player.name
	end
end

function Bot:ResetVehicleTimer()
	self._VehicleWaitTimer = 0.0
end

---@param p_Player Player
function Bot:EnterVehicleOfPlayer(p_Player)
	self._ActiveAction = BotActionFlags.EnterVehicleActive
	self._ShootPlayer = nil
	self._ShootPlayerName = p_Player.name
	self._ShootModeTimer = 0.0
end

function Bot:UpdateObjective(p_Objective)
	local s_AllObjectives = m_NodeCollection:GetKnownObjectives()

	for l_Objective, _ in pairs(s_AllObjectives) do
		if l_Objective == p_Objective then
			self:SetObjective(p_Objective)
			break
		end
	end
end

function Bot:DeployIfPossible()
	-- deploy from time to time
	if self.m_PrimaryGadget ~= nil and (self.m_Kit == BotKits.Support or self.m_Kit == BotKits.Assault) then
		if self.m_PrimaryGadget.type == WeaponTypes.Ammobag or self.m_PrimaryGadget.type == WeaponTypes.Medkit then
			self:AbortAttack()
			self._WeaponToUse = BotWeapons.Gadget1
			self._DeployTimer = 0.0
		end
	end
end

---@return boolean
function Bot:_DoExitVehicle()
	if self._ExitVehicleActive then
		self:AbortAttack()
		self.m_Player:ExitVehicle(false, false)
		local s_Node = g_GameDirector:FindClosestPath(self.m_Player.soldier.worldTransform.trans, false, true, nil)

		if s_Node ~= nil then
			-- switch to foot
			self._InvertPathDirection = false
			self._PathIndex = s_Node.PathIndex
			self._CurrentWayPoint = s_Node.PointIndex
			self._LastWayDistance = 1000.0
		end

		self._ExitVehicleActive = false
		return true
	end

	return false
end

function Bot:ExitVehicle()
	self._ExitVehicleActive = true
end

---@return boolean
function Bot:IsReadyToAttack()
	if self._ActiveAction == BotActionFlags.OtherActionActive or
		self._ActiveAction == BotActionFlags.ReviveActive or
		self._ActiveAction == BotActionFlags.RepairActive or
		self._ActiveAction == BotActionFlags.EnterVehicleActive or
		self._ActiveAction == BotActionFlags.GrenadeActive then
		return false
	end

	if self._ShootPlayer == nil or (self.m_InVehicle and (self._ShootModeTimer > Config.BotMinTimeShootAtPlayer * 2)) or
		(not self.m_InVehicle and (self._ShootModeTimer > Config.BotMinTimeShootAtPlayer)) or
		(self.m_KnifeMode and self._ShootModeTimer > (Config.BotMinTimeShootAtPlayer / 2)) then
		return true
	else
		return false
	end
end

---@return number
function Bot:GetAttackDistance()
	local s_AttackDistance = 0.0

	if not self.m_InVehicle then
		if self.m_ActiveWeapon == nil or self.m_ActiveWeapon.type ~= WeaponTypes.Sniper then
			s_AttackDistance = Config.MaxShootDistanceNoSniper
		else
			s_AttackDistance = Config.MaxRaycastDistance
		end
	else
		if m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) and
			m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) and
			m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.AntiAir) then
			s_AttackDistance = Config.MaxShootDistanceNoAntiAir
		else
			s_AttackDistance = Config.MaxRaycastDistanceVehicles
		end
	end

	return s_AttackDistance
end

---@param p_Player Player
---@param p_IgnoreYaw boolean
---@return boolean
function Bot:ShootAt(p_Player, p_IgnoreYaw)
	if not self:IsReadyToAttack() or self._Shoot == false then
		return false
	end

	-- don't shoot at teammates
	if self.m_Player.teamId == p_Player.teamId then
		return false
	end

	if p_Player.soldier == nil or self.m_Player.soldier == nil then
		return false
	end

	-- don't attack as driver in some vehicles
	if self.m_InVehicle and self.m_Player.controlledEntryId == 0 then
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) then
			if self.m_Player.controlledControllable:GetPlayerInEntry(1) ~= nil then
				if not Config.ChopperDriversAttack then
					return false
				end
			end
		end

		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
			if self._VehicleTakeoffTimer > 0.0 then
				return false
			end
		end

		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.NoArmorVehicle) then
			return false
		end

		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.LightVehicle) then
			return false
		end

		-- if stationary AA targets get assigned in an other waay
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
			return false
		end
	end

	-- check for vehicles
	local s_Type = m_Vehicles:FindOutVehicleType(p_Player)

	-- don't shoot at stationary AA
	if s_Type == VehicleTypes.StationaryAA then
		return false
	end

	-- don't shoot if too far away
	self._DistanceToPlayer = 0.0

	if s_Type == VehicleTypes.MavBot then
		self._DistanceToPlayer = p_Player.controlledControllable.transform.trans:Distance(self.m_Player.soldier.worldTransform
			.trans)
	else
		self._DistanceToPlayer = p_Player.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans)
	end

	local s_AttackDistance = self:GetAttackDistance()

	-- don't attack if too far away
	if not p_IgnoreYaw and self._DistanceToPlayer > s_AttackDistance then
		return false
	end

	if s_Type ~= VehicleTypes.NoVehicle and
		m_Vehicles:CheckForVehicleAttack(s_Type, self._DistanceToPlayer, self.m_SecondaryGadget, self.m_InVehicle) ==
		VehicleAttackModes.NoAttack then
		return false
	end

	self._ShootPlayerVehicleType = s_Type

	local s_DifferenceYaw = 0
	local s_Pitch = 0
	local s_FovHalf = 0
	local s_PitchHalf = 0

	-- if target is air-vehicle and bot is in AA --> ignore yaw
	if self.m_InVehicle and (s_Type == VehicleTypes.Chopper or s_Type == VehicleTypes.Plane) and
		m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.AntiAir) then
		p_IgnoreYaw = true
	end

	-- don't attack if too close to ground in Plane
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		if self._ShootPlayerVehicleType ~= VehicleTypes.Chopper or self._ShootPlayerVehicleType ~= VehicleTypes.Plane then
			if (self.m_Player.soldier.worldTransform.trans.y - p_Player.soldier.worldTransform.trans.y) <
				Registry.VEHICLES.ABORT_ATTACK_HEIGHT_JET then
				return false
			end

			if self._DistanceToPlayer < Registry.VEHICLES.ABORT_ATTACK_DISTANCE_JET then
				return false
			end
		else
			p_IgnoreYaw = true
		end
	end

	if not p_IgnoreYaw then
		local s_OldYaw = self.m_Player.input.authoritativeAimingYaw
		local s_DifferenceY = 0.0
		local s_DifferenceX = 0.0
		local s_DifferenceZ = 0.0

		if s_Type == VehicleTypes.MavBot then
			s_DifferenceY = p_Player.controlledControllable.transform.trans.z - self.m_Player.soldier.worldTransform.trans.z
			s_DifferenceX = p_Player.controlledControllable.transform.trans.x - self.m_Player.soldier.worldTransform.trans.x
			s_DifferenceZ = p_Player.controlledControllable.transform.trans.y - self.m_Player.soldier.worldTransform.trans.y
		else
			s_DifferenceY = p_Player.soldier.worldTransform.trans.z - self.m_Player.soldier.worldTransform.trans.z
			s_DifferenceX = p_Player.soldier.worldTransform.trans.x - self.m_Player.soldier.worldTransform.trans.x
			s_DifferenceZ = p_Player.soldier.worldTransform.trans.y - self.m_Player.soldier.worldTransform.trans.y
		end

		local s_AtanYaw = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanYaw > math.pi / 2) and (s_AtanYaw - math.pi / 2) or (s_AtanYaw + 3 * math.pi / 2)

		local s_DistanceHoizontal = math.sqrt(s_DifferenceY ^ 2 + s_DifferenceY ^ 2)
		s_Pitch = math.abs(math.atan(s_DifferenceZ, s_DistanceHoizontal))

		s_DifferenceYaw = math.abs(s_OldYaw - s_Yaw)

		if s_DifferenceYaw > math.pi then
			s_DifferenceYaw = math.pi * 2 - s_DifferenceYaw
		end

		if self.m_InVehicle then
			if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.AntiAir) then
				s_FovHalf = Config.FovVehicleAAForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleVehicleAAForShooting / 360 * math.pi
			elseif (
				m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) or
					m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane)) and self.m_Player.controlledEntryId == 0 then -- chopper as driver
				s_FovHalf = Config.FovVehicleForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi
			else
				s_FovHalf = Config.FovVehicleForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleVehicleForShooting / 360 * math.pi
			end
		else
			s_FovHalf = Config.FovForShooting / 360 * math.pi
			s_PitchHalf = Config.FovVerticleForShooting / 360 * math.pi
		end
	end

	if p_IgnoreYaw or (s_DifferenceYaw < s_FovHalf and s_Pitch < s_PitchHalf) then
		if self._Shoot then
			self._ShootModeTimer = 0.0
			self._ShootPlayerName = p_Player.name
			self._ShootPlayer = nil
			self._KnifeWayPositions = {}
			self._VehicleReadyToShoot = false
			self._ShotTimer = -self:GetFirstShotDelay(self._DistanceToPlayer, false)

			if self.m_KnifeMode then
				table.insert(self._KnifeWayPositions, p_Player.soldier.worldTransform.trans:Clone())
			end

			return true
		else
			self._ShootPlayerName = ""
			self._ShootPlayer = nil
			self._ShootModeTimer = Config.BotFireModeDuration
			return false
		end
	end

	return false
end

---@param p_DeltaTime number
function Bot:_CheckForVehicleActions(p_DeltaTime)
	-- check if exit of vehicle is needed (because of low health)
	if not self._ExitVehicleActive then
		self._VehicleHealthTimer = self._VehicleHealthTimer + p_DeltaTime

		if self._VehicleHealthTimer >= Registry.VEHICLES.VEHICLE_HEALTH_CYLCE_TIME then
			self._VehicleHealthTimer = 0
			local s_CurrentVehicleHealth = 0

			if self.m_InVehicle then
				s_CurrentVehicleHealth = PhysicsEntity(self.m_Player.controlledControllable).internalHealth
			elseif self.m_OnVehicle then
				s_CurrentVehicleHealth = PhysicsEntity(self.m_Player.attachedControllable).internalHealth
			end

			if s_CurrentVehicleHealth <= self._ExitVehicleHealth then
				if math.random(0, 100) <= Registry.VEHICLES.VEHICLE_PROPABILITY_EXIT_LOW_HEALTH then
					self:AbortAttack()
					self:ExitVehicle()
				end
			end
		end
	end

	-- check if better seat is available
	self._VehicleSeatTimer = self._VehicleSeatTimer + p_DeltaTime

	if self._VehicleSeatTimer >= Registry.VEHICLES.VEHICLE_SEAT_CHECK_CYCLE_TIME then
		self._VehicleSeatTimer = 0

		if self.m_InVehicle then --in vehicle
			local s_VehicleEntity = self.m_Player.controlledControllable

			for l_SeatIndex = 0, self.m_Player.controlledEntryId do
				if s_VehicleEntity:GetPlayerInEntry(l_SeatIndex) == nil then
					-- better seat available --> swich seats
					m_Logger:Write("switch to better seat")
					self:AbortAttack()
					self.m_Player:EnterVehicle(s_VehicleEntity, l_SeatIndex)
					self:UpdateVehicleMovableId()
					break
				end
			end
		elseif self.m_OnVehicle then --only passenger.
			local s_VehicleEntity = self.m_Player.attachedControllable
			local s_LowestSeatIndex = -1

			for l_SeatIndex = 0, s_VehicleEntity.entryCount - 1 do
				if s_VehicleEntity:GetPlayerInEntry(l_SeatIndex) == nil then
					-- maybe better seat available
					s_LowestSeatIndex = l_SeatIndex
				else -- check if there is a gap
					if s_LowestSeatIndex >= 0 then -- there is a better place
						m_Logger:Write("switch to better seat")
						self:AbortAttack()
						self.m_Player:EnterVehicle(s_VehicleEntity, s_LowestSeatIndex)
						self:UpdateVehicleMovableId()
						break
					end
				end
			end
		end
	end
end

function Bot:ResetVars()
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._MoveMode = BotMoveModes.Standstill
	self._ActiveAction = BotActionFlags.NoActionActive
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = nil
	self._ShootPlayer = nil
	self._ShootPlayerName = ""
	self._InvertPathDirection = false
	self._ExitVehicleActive = false
	self._ShotTimer = 0.0
	self._UpdateTimer = 0.0
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._KnifeWayPositions = {}
	self._ShootWayPoints = {}
	self._ZombieSpeedValue = BotMoveSpeeds.NoMovement
	self._SpawnDelayTimer = 0.0
	self._SpawnProtectionTimer = 0.0
	self._Objective = ''
	self._WeaponToUse = BotWeapons.Primary
end

---@param p_DistanceToTarget number
---@param p_ReducedTiming boolean
---@return number
function Bot:GetFirstShotDelay(p_DistanceToTarget, p_ReducedTiming)
	local s_Delay = (Config.BotFirstShotDelay + (math.random() * self._Skill)) -- slower reaction with lower skill. Always use "Skill" for this (independant of Sniper)

	if p_ReducedTiming then
		s_Delay = s_Delay * 0.6
	end

	-- slower reaction on greater distances. 100m = 1 extra second
	s_Delay = s_Delay + (p_DistanceToTarget * 0.01)
	return s_Delay
end

---@param p_Player Player
function Bot:SetVarsStatic(p_Player)
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._MoveMode = BotMoveModes.Standstill
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = p_Player
end

---@param p_Player Player
---@param p_UseRandomWay boolean
---@param p_PathIndex integer
---@param p_CurrentWayPoint any @TODO add emmylua type
---@param p_InverseDirection boolean
function Bot:SetVarsWay(p_Player, p_UseRandomWay, p_PathIndex, p_CurrentWayPoint, p_InverseDirection)
	if p_UseRandomWay then
		self._SpawnMode = BotSpawnModes.RespawnRandomPath
		self._TargetPlayer = nil
		self._Shoot = Globals.AttackWayBots
		self._Respawning = Globals.RespawnWayBots
	else
		self._SpawnMode = BotSpawnModes.RespawnFixedPath
		self._TargetPlayer = p_Player
		self._Shoot = false
		self._Respawning = false
	end

	self._BotSpeed = BotMoveSpeeds.Normal
	self._MoveMode = BotMoveModes.Paths
	self._PathIndex = p_PathIndex
	self._CurrentWayPoint = p_CurrentWayPoint
	self._InvertPathDirection = p_InverseDirection
end

---@return boolean
function Bot:IsStaticMovement()
	if self._MoveMode == BotMoveModes.Standstill or self._MoveMode == BotMoveModes.Mirror or
		self._MoveMode == BotMoveModes.Mimic then
		return true
	else
		return false
	end
end

---@param p_MoveMode BotMoveModes|integer
function Bot:SetMoveMode(p_MoveMode)
	self._MoveMode = p_MoveMode
end

---@param p_Respawn boolean
function Bot:SetRespawn(p_Respawn)
	self._Respawning = p_Respawn
end

---@param p_Shoot boolean
function Bot:SetShoot(p_Shoot)
	self._Shoot = p_Shoot
end

---@param p_Speed integer|BotMoveSpeeds
function Bot:SetSpeed(p_Speed)
	self._BotSpeed = p_Speed
end

function Bot:SetObjective(p_Objective)
	if self._Objective ~= p_Objective then
		self._Objective = p_Objective or ''
		local s_Point = m_NodeCollection:Get(self._CurrentWayPoint, self._PathIndex)

		if s_Point ~= nil then
			local s_Direction = m_NodeCollection:ObjectiveDirection(s_Point, self._Objective, self.m_InVehicle)
			self._InvertPathDirection = (s_Direction == 'Previous')
		end
	end
end

function Bot:ResetSkill()
	self._SkillFound = false
end

---@return string
function Bot:GetObjective()
	return self._Objective
end

---@return integer|BotSpawnModes
function Bot:GetSpawnMode()
	return self._SpawnMode
end

---@return integer
function Bot:GetWayIndex()
	return self._PathIndex
end

---@return integer
function Bot:GetPointIndex()
	return self._CurrentWayPoint
end

---@return Player|nil
function Bot:GetTargetPlayer()
	return self._TargetPlayer
end

---@return boolean
function Bot:IsInactive()
	if self.m_Player.soldier ~= nil or self._SpawnMode ~= BotSpawnModes.NoRespawn then
		return false
	else
		return true
	end
end

---@return boolean
function Bot:IsStuck()
	if self._ObstaceSequenceTimer ~= 0.0 then
		return true
	else
		return false
	end
end

function Bot:ResetSpawnVars()
	self._SpawnDelayTimer = 0.0
	self._ObstaceSequenceTimer = 0.0
	self._ObstacleRetryCounter = 0
	self._LastWayDistance = 1000.0
	self._ShootPlayer = nil
	self._ShootPlayerName = ""
	self._ShootModeTimer = 0.0
	self._MeleeCooldownTimer = 0.0
	self._ShootTraceTimer = 0.0
	self._ReloadTimer = 0.0
	self._BrakeTimer = 0.0
	self._DeployTimer = MathUtils:GetRandomInt(1, Config.DeployCycle)
	self._AttackModeMoveTimer = 0.0
	self._AttackMode = BotAttackModes.RandomNotSet
	self._ShootWayPoints = {}

	-- skill
	if not self._SkillFound then
		local s_TempSkillValue = math.random()
		self._Skill = Config.BotWorseningSkill * s_TempSkillValue
		self._SkillSniper = Config.BotSniperWorseningSkill * s_TempSkillValue
		self._SkillFound = true
	end

	self._ShotTimer = 0.0
	self._UpdateTimer = 0.0
	self._StuckTimer = 0.0
	self._SpawnProtectionTimer = 2.0
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._ActiveAction = BotActionFlags.NoActionActive
	self._KnifeWayPositions = {}
	self._ZombieSpeedValue = BotMoveSpeeds.NoMovement
	self._OnSwitch = false
	self._TargetPitch = 0.0
	self._Objective = '' --reset objective on spawn, as an other spawn-point might have chosen...
	self._WeaponToUse = BotWeapons.Primary

	-- reset all input-vars
	---@type EntryInputActionEnum|integer
	for i = 0, 36 do
		self.m_ActiveInputs[i] = {
			value = 0,
			reset = false
		}
		self.m_Player.input:SetLevel(i, 0.0)
	end
end

---@param p_Player Player
function Bot:ClearPlayer(p_Player)
	if self._ShootPlayer == p_Player then
		self._ShootPlayer = nil
	end

	if self._TargetPlayer == p_Player then
		self._TargetPlayer = nil
	end

	local s_CurrentShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)

	if s_CurrentShootPlayer == p_Player then
		self._ShootPlayerName = ""
	end
end

function Bot:Kill()
	self:ResetVars()

	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:Kill()
	end
end

function Bot:Destroy()
	self:ResetVars()
	self.m_Player.input = nil

	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:Destroy()
	end

	if self.m_Player.corpse ~= nil then
		self.m_Player.corpse:Destroy()
	end

	PlayerManager:DeletePlayer(self.m_Player)
	self.m_Player = nil
end

-- =============================================
-- Private Functions
-- =============================================

---@param p_DeltaTime number
function Bot:_UpdateLookAroundPassenger(p_DeltaTime)
	-- move around a little
	local s_Pos = self.m_Player.attachedControllable.transform.forward
	local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
	self._TargetYaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
	self._TargetPitch = 0.0

	self._VehicleWaitTimer = self._VehicleWaitTimer + p_DeltaTime

	if self._VehicleWaitTimer > 9.0 then
		self._VehicleWaitTimer = 0.0
	elseif self._VehicleWaitTimer >= 6.0 then
	elseif self._VehicleWaitTimer >= 3.0 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60 ° rotation left
		self._TargetPitch = 0.2

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._VehicleWaitTimer >= 0.0 then
		self._TargetYaw = self._TargetYaw + 1.0 -- 60 ° rotation right
		self._TargetPitch = -0.2

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	end
end

---@param p_Input EntryInputActionEnum|integer
---@param p_Value number
function Bot:_SetInput(p_Input, p_Value)
	self.m_ActiveInputs[p_Input] = {
		value = p_Value,
		reset = p_Value == 0.0
	}
end

function Bot:_UpdateInputs()
	---@type EntryInputActionEnum|integer
	for i = 0, 36 do
		if self.m_ActiveInputs[i].reset then
			self.m_Player.input:SetLevel(i, 0)
			self.m_ActiveInputs[i].value = 0
			self.m_ActiveInputs[i].reset = false
		elseif self.m_ActiveInputs[i].value ~= 0 then
			self.m_Player.input:SetLevel(i, self.m_ActiveInputs[i].value)
			self.m_ActiveInputs[i].reset = true
		end
	end
end

---@param p_DeltaTime number
function Bot:_UpdateRespawn(p_DeltaTime)
	if not self._Respawning or self._SpawnMode == BotSpawnModes.NoRespawn then
		return
	end

	if self.m_Player.soldier == nil then
		-- wait for respawn-delay gone
		if self._SpawnDelayTimer < (Globals.RespawnDelay + Config.AdditionalBotSpawnDelay) then
			self._SpawnDelayTimer = self._SpawnDelayTimer + p_DeltaTime
		else
			self._SpawnDelayTimer = 0.0 -- prevent triggering again.
			Events:DispatchLocal('Bot:RespawnBot', self.m_Name)
		end
	end
end

---@param p_Attacking boolean
function Bot:_UpdateStationaryAAVehicle(p_Attacking)
	-- get new target if needed
	if self._DeployTimer > 1.0 then
		local s_Target = m_AirTargets:GetTarget(self.m_Player)

		if s_Target ~= nil then
			self._ShootPlayerName = s_Target.name
			self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
			self._ShootPlayerVehicleType = m_Vehicles:FindOutVehicleType(self._ShootPlayer)
		else
			self:AbortAttack()
		end

		self._DeployTimer = 0.0
	else
		self._DeployTimer = self._DeployTimer + Registry.BOT.BOT_FAST_UPDATE_CYCLE
	end

	if p_Attacking then -- target available
		-- aim at target
		m_VehicleAiming:UpdateAimingVehicleAdvanced(self)
	else
		-- just look a little around
		m_VehicleMovement:UpdateVehicleLookAround(self, Registry.BOT.BOT_FAST_UPDATE_CYCLE)
	end
	m_VehicleMovement:UpdateYawVehicle(self, true, false) --only gun --> therefore alsways gun-mode
end

function Bot:_UpdateWeaponSelectionVehicle()
	--select weapon-slot (rn always primary in vehicle)
	if self.m_Player.soldier.weaponsComponent ~= nil then
		if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
			self:_SetInput(EntryInputActionEnum.EIASelectWeapon1, 1)
			self.m_ActiveWeapon = self.m_Primary
			self._ShotTimer = 0.0
		end
	end
end

function Bot:_UpdateReloadVehicle()
	self._WeaponToUse = BotWeapons.Primary
	self:AbortAttack()

	if self._ActiveAction ~= BotActionFlags.OtherActionActive then
		self._TargetPitch = 0.0
	end

	self._ReloadTimer = self._ReloadTimer + Registry.BOT.BOT_UPDATE_CYCLE

	if self._ReloadTimer > 1.5 and self._ReloadTimer < 2.5 then
		self:_SetInput(EntryInputActionEnum.EIAReload, 1)
	end
end

---@param p_Position Vec3
function Bot:FindVehiclePath(p_Position)
	local s_Node = g_GameDirector:FindClosestPath(p_Position, true, true, self.m_ActiveVehicle.Terrain)

	if s_Node ~= nil then
		-- switch to vehicle
		self._InvertPathDirection = false
		self._PathIndex = s_Node.PathIndex
		self._CurrentWayPoint = s_Node.PointIndex
		self._LastWayDistance = 1000.0
		-- set path
		self._TargetPoint = s_Node
		self._NextTargetPoint = s_Node
		-- only for choppers
		self._TargetHeightAttack = p_Position.y
	end
end

function Bot:UpdateVehicleMovableId()
	self:_SetActiveVars() -- update if "on vehicle" or "in vehicle"

	if self.m_OnVehicle then
		self._VehicleMovableId = nil
	elseif self.m_InVehicle then
		self._VehicleMovableId = m_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, self.m_Player.controlledEntryId)

		if self.m_Player.controlledEntryId == 0 then
			self:FindVehiclePath(self.m_Player.soldier.worldTransform.trans)
		end
	end
end

---@param p_Entity ControllableEntity
---@param p_PlayerIsDriver boolean
---@return integer
---@return Vec3|nil
function Bot:_EnterVehicleEntity(p_Entity, p_PlayerIsDriver)
	if p_Entity ~= nil then
		local s_Position = p_Entity.transform.trans
		local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_Entity)

		if not Config.UseAirVehicles and
			(s_VehicleData.Type == VehicleTypes.Plane or s_VehicleData.Type == VehicleTypes.Chopper) then
			return -3 -- not allowed to use
		end

		-- keep one seat free, if enough available
		local s_MaxEntries = p_Entity.entryCount

		if not p_PlayerIsDriver and s_MaxEntries > 2 then
			s_MaxEntries = s_MaxEntries - 1
		end

		for i = 0, s_MaxEntries - 1 do
			if p_Entity:GetPlayerInEntry(i) == nil then
				self.m_Player:EnterVehicle(p_Entity, i)
				self._ExitVehicleHealth = PhysicsEntity(p_Entity).internalHealth * (Registry.VEHICLES.VEHILCE_EXIT_HEALTH / 100.0)

				-- get ID
				self.m_ActiveVehicle = s_VehicleData
				self._VehicleMovableId = m_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, i)
				m_Logger:Write(self.m_ActiveVehicle)

				if i == 0 then
					if i == s_MaxEntries - 1 then
						self._VehicleWaitTimer = 0.5 -- always wait a short time to check for free start
						self._VehicleTakeoffTimer = Registry.VEHICLES.JET_TAKEOFF_TIME
						g_GameDirector:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
					else
						self._VehicleWaitTimer = Config.VehicleWaitForPassengersTime
						self._BrakeTimer = 0.0
					end
				else
					self._VehicleWaitTimer = 0.0

					if i == s_MaxEntries - 1 then
						-- last seat taken: Disable vehicle and abort wait for passengers:
						local s_Driver = p_Entity:GetPlayerInEntry(0)

						if s_Driver ~= nil then
							Events:Dispatch('Bot:AbortWait', s_Driver.name)
							g_GameDirector:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
						end
					end
				end

				return 0, s_Position -- everything fine
			end
		end

		--no place left
		return -2
	end
end

---@param p_PlayerIsDriver boolean
---@return integer
---@return Vec3|nil
function Bot:_EnterVehicle(p_PlayerIsDriver)
	local s_Iterator = EntityManager:GetIterator("ServerVehicleEntity")
	---@type ControllableEntity
	local s_Entity = s_Iterator:Next()

	local s_ClosestEntity = nil
	local s_ClosestDistance = Registry.VEHICLES.MIN_DISTANCE_VEHICLE_ENTER

	while s_Entity ~= nil do
		s_Entity = ControllableEntity(s_Entity)
		local s_Position = s_Entity.transform.trans
		local s_Distance = s_Position:Distance(self.m_Player.soldier.worldTransform.trans)

		if s_Distance < s_ClosestDistance then
			s_ClosestEntity = s_Entity
			s_ClosestDistance = s_Distance
		end

		s_Entity = s_Iterator:Next()
	end

	if s_ClosestEntity ~= nil then
		return self:_EnterVehicleEntity(s_ClosestEntity, p_PlayerIsDriver)
	end

	return -3 -- no vehicle found
end

---@param p_CurrentWayPoint integer|nil
---@return integer
function Bot:_GetWayIndex(p_CurrentWayPoint)
	local s_ActivePointIndex = 1

	if p_CurrentWayPoint == nil then
		p_CurrentWayPoint = s_ActivePointIndex
	else
		s_ActivePointIndex = p_CurrentWayPoint

		-- direction handling
		local s_CountOfPoints = #m_NodeCollection:Get(nil, self._PathIndex)
		local s_FirstPoint = m_NodeCollection:GetFirst(self._PathIndex)

		if s_ActivePointIndex > s_CountOfPoints then
			if s_FirstPoint.OptValue == 0xFF then --inversion needed
				s_ActivePointIndex = s_CountOfPoints
				self._InvertPathDirection = true
			else
				s_ActivePointIndex = 1
			end
		elseif s_ActivePointIndex < 1 then
			if s_FirstPoint.OptValue == 0xFF then --inversion needed
				s_ActivePointIndex = 1
				self._InvertPathDirection = false
			else
				s_ActivePointIndex = s_CountOfPoints
			end
		end
	end

	return s_ActivePointIndex
end

function Bot:AbortAttack()
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) and self._ShootPlayerName ~= "" then
		self._VehicleTakeoffTimer = Registry.VEHICLES.JET_ABORT_ATTACK_TIME
		self._JetAbortAttackActive = true
		self._Pid_Drv_Yaw:Reset()
		self._Pid_Drv_Tilt:Reset()
		self._Pid_Drv_Roll:Reset()
	end

	self.m_Player.input.zoomLevel = 0
	self._ShootPlayerName = ""
	self._ShootPlayer = nil
	self._ShootModeTimer = 0.0
	self._AttackMode = BotAttackModes.RandomNotSet
end

---@param p_FlagValue integer|BotActionFlags|nil
function Bot:_ResetActionFlag(p_FlagValue)
	if p_FlagValue == nil then
		self._ActiveAction = BotActionFlags.NoActionActive
	else
		if self._ActiveAction == p_FlagValue then
			self._ActiveAction = BotActionFlags.NoActionActive
		end
	end
end

function Bot:_SetActiveVars()
	if self._ShootPlayerName ~= "" then
		self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
	else
		self._ShootPlayer = nil
	end

	self.m_ActiveMoveMode = self._MoveMode
	self.m_ActiveSpeedValue = self._BotSpeed

	if self.m_Player.controlledControllable ~= nil and not self.m_Player.controlledControllable:Is("ServerSoldierEntity") then
		self.m_InVehicle = true
		self.m_OnVehicle = false
	elseif self.m_Player.attachedControllable ~= nil then
		self.m_InVehicle = false
		self.m_OnVehicle = true
	else
		self.m_InVehicle = false
		self.m_OnVehicle = false
	end

	if Config.BotWeapon == BotWeapons.Knife or Config.ZombieMode then
		self.m_KnifeMode = true
	else
		self.m_KnifeMode = false
	end
end

return Bot
