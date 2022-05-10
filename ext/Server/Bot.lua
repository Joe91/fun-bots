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

	--simple movement
	---@type BotMoveSpeeds
	self._BotSpeed = BotMoveSpeeds.NoMovement
	---@type Player|nil
	self._TargetPlayer = nil
end

-- =============================================
-- Events
-- =============================================

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

				-- old movement-modes -- remove one day?
				if self:IsStaticMovement() then
					m_BotMovement:UpdateStaticMovement(self)
					self:_UpdateInputs()
					self:_UpdateYaw()
					self._UpdateFastTimer = 0.0
					return
				end

				------------------ CODE OF BEHAVIOUR STARTS HERE ---------------------
				-- detect modes
				self:_SetActiveVars()
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
							m_BotWeaponHandling:UpdateWeaponSelection(self, true)
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
								self:_UpdateAttackStationaryAAVehicle()
							end
							self:_UpdateInputs()
							self._UpdateTimer = 0.0
						end
					else
						if self.m_OnVehicle then -- passenger of boat for example
							-- sync slow code with fast code. Therefore execute the slow code first
							if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
								-- common part
								self:_UpdateWeaponSelection()

								-- differ attacking
								if s_Attacking then
									self:_UpdateAttacking()
								else
									self:_UpdateDeployAndReload(false)
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
								-- self:_UpdateAiming()
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
									self:_UpdateAttackingVehicle()
									self:_UpdateShootMovementVehicle()
								else
									self:_UpdateReloadVehicle()
									if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- only if driver
										self:_UpdateNormalMovementVehicle()
									end
								end

								-- common things
								self:_UpdateSpeedOfMovementVehicle()
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
								if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
									m_VehicleAiming:UpdateAimingVehicleAdvanced(self)
								else
									m_VehicleAiming:UpdateAimingVehicle(self)
								end
							else
								if self.m_Player.controlledEntryId == 0 and not s_IsStationaryLauncher then -- only if driver
									self:_UpdateTargetMovementVehicle()
								else
									self:_UpdateVehicleLookAround(self._UpdateFastTimer)
								end
							end
							self:_UpdateYawVehicle(s_Attacking, s_IsStationaryLauncher)
						end
					end
				end
				self._UpdateFastTimer = 0.0
			end

			-- very fast code
			if not self.m_InVehicle then
				self:_UpdateYaw()
			end

		else -- alive, but no inputs allowed yet --> look around
			self._UpdateTimer = self._UpdateTimer + p_DeltaTime -- reusage of updateTimer
			if self._UpdateTimer > Registry.BOT.BOT_UPDATE_CYCLE then
				if self._SpawnProtectionTimer > 0.0 then
					self._SpawnProtectionTimer = self._SpawnProtectionTimer - Registry.BOT.BOT_UPDATE_CYCLE
				else
					self._SpawnProtectionTimer = 0.0
				end

				self:_UpdateYaw()
				self:_LookAround(Registry.BOT.BOT_UPDATE_CYCLE)
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
	if self.m_Kit == BotKits.Assault and p_Player.corpse ~= nil and not p_Player.corpse.isDead and not Globals.isGm then
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
	for l_Objective,_ in pairs(s_AllObjectives) do
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
			self:_AbortAttack()
			self._WeaponToUse = BotWeapons.Gadget1
			self._DeployTimer = 0.0
		end
	end
end

---@return boolean
function Bot:_DoExitVehicle()
	if self._ExitVehicleActive then
		self:_AbortAttack()
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
	if
	self._ActiveAction == BotActionFlags.OtherActionActive or
	self._ActiveAction == BotActionFlags.ReviveActive or
	self._ActiveAction == BotActionFlags.RepairActive or
	self._ActiveAction == BotActionFlags.EnterVehicleActive or
	self._ActiveAction == BotActionFlags.GrenadeActive then
		return false
	end
	if self._ShootPlayer == nil or (self.m_InVehicle and (self._ShootModeTimer > Config.BotMinTimeShootAtPlayer * 2)) or
		(not self.m_InVehicle and (self._ShootModeTimer > Config.BotMinTimeShootAtPlayer)) or
		(self.m_KnifeMode and self._ShootModeTimer > (Config.BotMinTimeShootAtPlayer/2)) then
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
		self._DistanceToPlayer = p_Player.controlledControllable.transform.trans:Distance(self.m_Player.soldier.worldTransform.trans)
	else
		self._DistanceToPlayer = p_Player.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans)
	end

	local s_AttackDistance = self:GetAttackDistance()

	-- don't attack if too far away
	if not p_IgnoreYaw and self._DistanceToPlayer > s_AttackDistance then
		return false
	end

	if s_Type ~= VehicleTypes.NoVehicle and m_Vehicles:CheckForVehicleAttack(s_Type, self._DistanceToPlayer, self.m_SecondaryGadget, self.m_InVehicle) == VehicleAttackModes.NoAttack then
		return false
	end

	self._ShootPlayerVehicleType = s_Type

	local s_DifferenceYaw = 0
	local s_Pitch = 0
	local s_FovHalf = 0
	local s_PitchHalf = 0

	-- if target is air-vehicle and bot is in AA --> ignore yaw
	if self.m_InVehicle and (s_Type == VehicleTypes.Chopper or s_Type == VehicleTypes.Plane) and m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.AntiAir) then
		p_IgnoreYaw = true
	end

	-- don't attack if too close to ground in Plane
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		if self._ShootPlayerVehicleType ~= VehicleTypes.Chopper or self._ShootPlayerVehicleType ~= VehicleTypes.Plane then
			if (self.m_Player.soldier.worldTransform.trans.y - p_Player.soldier.worldTransform.trans.y) < Registry.VEHICLES.ABORT_ATTACK_HEIGHT_JET then
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

		local s_DistanceHoizontal = math.sqrt(s_DifferenceY^2 + s_DifferenceY^2)
		s_Pitch = math.abs(math.atan(s_DifferenceZ, s_DistanceHoizontal))

		s_DifferenceYaw = math.abs(s_OldYaw - s_Yaw)

		if s_DifferenceYaw > math.pi then
			s_DifferenceYaw = math.pi * 2 - s_DifferenceYaw
		end

		if self.m_InVehicle then
			if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.AntiAir) then
				s_FovHalf = Config.FovVehicleAAForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleVehicleAAForShooting / 360 * math.pi
			elseif (m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane)) and self.m_Player.controlledEntryId == 0 then -- chopper as driver
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
			self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer, false)

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
					self:_AbortAttack()
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
					self:_AbortAttack()
					self.m_Player:EnterVehicle(s_VehicleEntity, l_SeatIndex)
					self:_UpdateVehicleMovableId()
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
						self:_AbortAttack()
						self.m_Player:EnterVehicle(s_VehicleEntity, s_LowestSeatIndex)
						self:_UpdateVehicleMovableId()
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
	local s_Delay = (Config.BotFirstShotDelay + math.random()*self._Skill)
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
	if self._MoveMode == BotMoveModes.Standstill or self._MoveMode == BotMoveModes.Mirror or self._MoveMode == BotMoveModes.Mimic then
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

	if self.m_ActiveWeapon ~= nil and self.m_ActiveWeapon.type == WeaponTypes.Sniper then
		self._Skill = math.random()*Config.BotSniperWorseningSkill
	else
		self._Skill = math.random()*Config.BotWorseningSkill
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
function Bot:_LookAround(p_DeltaTime)
	-- move around a little
	local s_LastYawTimer = self._WayWaitYawTimer
	self._WayWaitYawTimer = self._WayWaitYawTimer + p_DeltaTime
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self._TargetPoint = nil
	self._TargetPitch = 0.0

	if self._WayWaitYawTimer > 6.0 then
		self._WayWaitYawTimer = 0.0
		self._TargetYaw = self._TargetYaw + 1.0 -- 60 ° rotation right

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 4.0 and s_LastYawTimer < 4.0 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60 ° rotation left

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 3.0 and s_LastYawTimer < 3.0 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60 ° rotation left

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 1.0 and s_LastYawTimer < 1.0 then
		self._TargetYaw = self._TargetYaw + 1.0 -- 60 ° rotation right

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	end
end

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

function Bot:_UpdateTargetMovementVehicle()
	if self._TargetPoint ~= nil then
		local s_Distance = self.m_Player.soldier.worldTransform.trans:Distance(self._TargetPoint.Position)

		if s_Distance < 3.0 then
			self._TargetPoint = self._NextTargetPoint
		end

		local s_DifferenceY = self._TargetPoint.Position.z - self.m_Player.soldier.worldTransform.trans.z
		local s_DifferenceX = self._TargetPoint.Position.x - self.m_Player.soldier.worldTransform.trans.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		self._TargetYaw = s_Yaw
	end
end

---@param p_DeltaTime number
function Bot:_UpdateVehicleLookAround(p_DeltaTime)
	-- move around a little
	if self._VehicleMovableId ~= nil then
		local s_Pos = self.m_Player.controlledControllable.transform.forward
		local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
		self._TargetYaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		self._TargetPitch = 0.0

		self._VehicleWaitTimer = self._VehicleWaitTimer + p_DeltaTime

		if self._VehicleWaitTimer > 9.0 then
			self._VehicleWaitTimer = 0.0
		elseif self._VehicleWaitTimer >= 6.0 then
		elseif self._VehicleWaitTimer >= 3.0 then
			self._TargetYaw = self._TargetYaw - 1.0 -- 60 ° rotation left
			self._TargetPitch = 0.5

			if self._TargetYaw < 0.0 then
				self._TargetYaw = self._TargetYaw + (2 * math.pi)
			end
		elseif self._VehicleWaitTimer >= 0.0 then
			self._TargetYaw = self._TargetYaw + 1.0 -- 60 ° rotation right
			self._TargetPitch = -0.5

			if self._TargetYaw > (math.pi * 2) then
				self._TargetYaw = self._TargetYaw - (2 * math.pi)
			end
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
			self:_AbortAttack()
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
		self:_UpdateVehicleLookAround(Registry.BOT.BOT_FAST_UPDATE_CYCLE)
	end
	self:_UpdateYawVehicle(true, false) --only gun --> therefore alsways gun-mode
end

function Bot:_UpdateAttackStationaryAAVehicle()
	if self._VehicleReadyToShoot then
		self:_SetInput(EntryInputActionEnum.EIAFire, 1)
	end
end

---@param p_Attacking boolean
function Bot:_UpdateYawVehicle(p_Attacking, p_IsStationaryLauncher)
	local s_DeltaYaw = 0
	local s_DeltaPitch = 0
	local s_CorrectGunYaw = false

	local s_Pos = nil

	if not p_Attacking then
		if self.m_Player.controlledEntryId == 0 and not p_IsStationaryLauncher then
			s_Pos = self.m_Player.controlledControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			s_DeltaYaw = s_Yaw - self._TargetYaw

			if self._VehicleMovableId ~= nil then
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, 0)
				local s_DiffPos = s_Pos - self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().forward
				-- prepare for moving gun back
				self._LastVehicleYaw = s_Yaw

				if math.abs(s_DiffPos.x) > 0.08 or math.abs(s_DiffPos.z) > 0.08 then
					s_CorrectGunYaw = true
				end
			end
		else -- passenger
			if self._VehicleMovableId ~= nil then
				s_Pos = self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().forward
				local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
				local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
				local s_Pitch = math.asin(s_Pos.y / 1.0)
				s_DeltaPitch = s_Pitch - self._TargetPitch
				s_DeltaYaw = s_Yaw - self._TargetYaw
			end
		end
	else
		if self._VehicleMovableId ~= nil then
			s_Pos = self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			local s_Pitch = math.asin(s_Pos.y / 1.0)
			s_DeltaPitch = s_Pitch - self._TargetPitch
			s_DeltaYaw = s_Yaw - self._TargetYaw

			--detect direction for moving gun back
			local s_GunDeltaYaw = s_Yaw - self._LastVehicleYaw

			if s_GunDeltaYaw > math.pi then
				s_GunDeltaYaw = s_GunDeltaYaw - 2*math.pi
			elseif s_GunDeltaYaw < -math.pi then
				s_GunDeltaYaw = s_GunDeltaYaw + 2*math.pi
			end

			if s_GunDeltaYaw > 0 then
				self._VehicleDirBackPositive = false
			else
				self._VehicleDirBackPositive = true
			end
		elseif (m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) and self.m_Player.controlledEntryId == 0 ) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
			s_Pos = self.m_Player.controlledControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			local s_Pitch = math.asin(s_Pos.y / 1.0)
			s_DeltaPitch = s_Pitch - self._TargetPitch
			s_DeltaYaw = s_Yaw - self._TargetYaw
		end
	end

	if s_DeltaYaw > (math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw - 2*math.pi
	elseif s_DeltaYaw < -(math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw + 2*math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_AbsDeltaPitch = math.abs(s_DeltaPitch)

	self.m_Player.input.authoritativeAimingYaw = self._TargetYaw --alsways set yaw to let the FOV work

	if s_AbsDeltaYaw < 0.10 then
		self._FullVehicleSteering = false
		if p_Attacking and s_AbsDeltaPitch < 0.10 then
			self._VehicleReadyToShoot = true
		end
	else
		self._FullVehicleSteering = true
		self._VehicleReadyToShoot = false
	end

	-- chopper driver handling here
	if self.m_Player.controlledEntryId == 0 and m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) then
		if self._VehicleWaitTimer > 0.0 then
			return
		end
		if not p_Attacking and (self._TargetPoint == nil or self._NextTargetPoint == nil) then
			return
		end
		if self.m_Player.controlledControllable == nil then
			return
		end

		-- YAW
		local s_Output_Yaw = self._Pid_Drv_Yaw:Update(s_DeltaYaw)
		-- no backwards in chopper
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output_Yaw)

		-- HEIGHT
		local s_Delta_Height = 0.0
		if p_Attacking then
			s_Delta_Height = self._TargetHeightAttack - self.m_Player.controlledControllable.transform.trans.y
		else
			self._TargetHeightAttack = self._TargetPoint.Position.y
			s_Delta_Height = self._TargetPoint.Position.y - self.m_Player.controlledControllable.transform.trans.y
		end
		local s_Output_Throttle = self._Pid_Drv_Throttle:Update(s_Delta_Height)
		if s_Output_Throttle > 0 then
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
		else
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
		end

		-- FOREWARD (depending on speed)
		-- A: use distance horizontally between points for speed-value --> not that good for that
		-- local DeltaX = self._NextTargetPoint.Position.x - self._TargetPoint.Position.x
		-- local DeltaZ = self._NextTargetPoint.Position.z - self._TargetPoint.Position.z
		-- local Distance = math.sqrt(DeltaX*DeltaX + DeltaZ*DeltaZ)
		-- B: just fly with constant speed -->

		local s_Delta_Tilt = 0
		if p_Attacking then
			s_Delta_Tilt = -s_DeltaPitch
		else
			local s_Tartget_Tilt = -0.35 -- = 20 °
			local s_Current_Tilt = math.asin(self.m_Player.controlledControllable.transform.forward.y / 1.0)
			s_Delta_Tilt = s_Tartget_Tilt - s_Current_Tilt
		end

		local s_Output_Tilt = self._Pid_Drv_Tilt:Update(s_Delta_Tilt)
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output_Tilt)

		-- ROLL (keep it zero)
		local s_Tartget_Roll = 0.0
		-- TODO: in strog steering: Roll a little?
		-- if self._FullVehicleSteering then
		-- 	if s_AbsDeltaYaw > 0 then
		-- 		s_Tartget_Roll = 0.1
		-- 	else
		-- 		s_Tartget_Roll = -0.1
		-- 	end
		-- end

		local s_Current_Roll = math.asin(self.m_Player.controlledControllable.transform.left.y / 1.0)
		local s_Delta_Roll = s_Tartget_Roll - s_Current_Roll
		local s_Output_Roll = self._Pid_Drv_Roll:Update(s_Delta_Roll)
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, s_Output_Roll)

		return -- don't do anything else

	-- jet driver handling here
	elseif m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		if self._VehicleWaitTimer > 0.0 then
			return
		end
		if not p_Attacking and (self._TargetPoint == nil or self._NextTargetPoint == nil) then
			return
		end
		if self.m_Player.controlledControllable == nil then
			return
		end


		-- Calculat delta pitch
		local s_Delta_Tilt = 0
		local s_Current_Tilt = math.asin(self.m_Player.controlledControllable.transform.forward.y / 1.0)

		if p_Attacking then
			s_Delta_Tilt = -s_DeltaPitch
		else
			-- TODO: use angle between two nodes?

			local s_Delta_Height = self._TargetPoint.Position.y - self.m_Player.controlledControllable.transform.trans.y

			local s_Tartget_Tilt = 0.0
			local s_Abs_Delta_Height = math.abs(s_Delta_Height)
			s_Tartget_Tilt = 0.6 * s_Abs_Delta_Height/10 -- 45°=0.785 rad
			local s_LimitTilt = 0.5
			if s_Tartget_Tilt > s_LimitTilt then
				s_Tartget_Tilt = s_LimitTilt
			end
			if s_Delta_Height < 0 then
				s_Tartget_Tilt = -s_Tartget_Tilt
			end

			s_Delta_Tilt = s_Tartget_Tilt - s_Current_Tilt -- inverted tilt
			if s_Delta_Tilt > math.pi then
				s_Delta_Tilt = s_Delta_Tilt - 2*math.pi
			elseif s_Delta_Tilt < -math.pi then
				s_Delta_Tilt = s_Delta_Tilt + 2*math.pi
			end
		end

		-- Caclulate angle for roll
		local s_Target_Roll = 0
		s_Target_Roll = 1.57 * -s_DeltaYaw/1.0 --full roll on 60°
		local s_LimitRoll = 1.57
		if s_Target_Roll > s_LimitRoll then -- 80° = 1.4 . 60° = 1.0
			s_Target_Roll = s_LimitRoll
		elseif s_Target_Roll < -s_LimitRoll then
			s_Target_Roll = -s_LimitRoll
		end

		local s_Current_Roll = 0
		if self.m_Player.controlledControllable.transform.up.y > 0 then
			local s_ProjectedY = self.m_Player.controlledControllable.transform.left.y / math.cos(s_Current_Tilt)
			s_Current_Roll = math.asin(s_ProjectedY / 1.0)
		elseif self.m_Player.controlledControllable.transform.up.y < 0 then
			local s_ProjectedY = self.m_Player.controlledControllable.transform.up.y / math.cos(s_Current_Tilt)
			s_Current_Roll = math.asin(s_ProjectedY / 1.0) - math.pi/2
			if s_Current_Roll < -2* math.pi then
				s_Current_Roll = s_Current_Roll + 2* math.pi
			end
		end

		local s_Delta_Roll = s_Target_Roll - s_Current_Roll
		if s_Delta_Roll > math.pi then
			s_Delta_Roll = s_Delta_Roll - 2*math.pi
		elseif s_Delta_Roll < -math.pi then
			s_Delta_Roll = s_Delta_Roll + 2*math.pi
		end
		local s_Output_Roll = self._Pid_Drv_Roll:Update(s_Delta_Roll)
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, s_Output_Roll)

		-- trasform tilt and yaw to rotation of roll
		local s_TransformedInputYaw = math.cos(s_Current_Roll) * s_DeltaYaw + math.sin(s_Current_Roll) * s_Delta_Tilt
		local s_TransformedInputTilt = math.cos(s_Current_Roll) * s_Delta_Tilt - math.sin(s_Current_Roll) * s_DeltaYaw


		local s_Output_Tilt = self._Pid_Drv_Tilt:Update(s_TransformedInputTilt)
		local s_Output_Yaw = self._Pid_Drv_Yaw:Update(s_TransformedInputYaw)

		-- TILT
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output_Tilt)

		-- YAW
		-- no backwards in planes
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output_Yaw)


		-- Throttle
		-- target velocity == 313 km/h --> 86.9444 m/s
		local s_Delta_Speed = 86.9444 - PhysicsEntity(self.m_Player.controlledControllable).velocity.magnitude
		local s_Output_Throttle = self._Pid_Drv_Throttle:Update(s_Delta_Speed)
		if s_Output_Throttle > 0 then
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
		else
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
		end

		return -- don't do anything else
	end

	if not p_Attacking then
		if self.m_Player.controlledEntryId == 0 and not p_IsStationaryLauncher then -- driver
			local s_Output = self._Pid_Drv_Yaw:Update(s_DeltaYaw)

			if self.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, s_Output)
			else
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output)
			end

			if s_CorrectGunYaw then
				if self._VehicleDirBackPositive then
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 1)
				else
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -1)
				end
			else
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 0)
			end
		else -- passenger
			if self._VehicleMovableId ~= nil then
				local s_Output = self._Pid_Att_Yaw:Update(s_DeltaYaw)
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -s_Output)

				local s_Output = self._Pid_Att_Pitch:Update(s_DeltaPitch)
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output)
			end
		end
	else -- attacking
		-- yaw
		local s_Output = self._Pid_Att_Yaw:Update(s_DeltaYaw)

		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output) --doubles the output of stationary AA --> faster turret
		else
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0)
		end
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -s_Output)
		-- self.m_Player.input:SetLevel(EntryInputActionEnum.EIACameraYaw, -s_Output)

		-- pitch
		local s_Output = self._Pid_Att_Pitch:Update(s_DeltaPitch)
		self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output)
		-- self.m_Player.input:SetLevel(EntryInputActionEnum.EIACameraPitch, -s_Output)
	end
end

function Bot:_UpdateYaw()
	local s_DeltaYaw = 0
	local s_DeltaPitch = 0
	s_DeltaYaw = self.m_Player.input.authoritativeAimingYaw - self._TargetYaw

	if s_DeltaYaw > math.pi then
		s_DeltaYaw = s_DeltaYaw - 2*math.pi
	elseif s_DeltaYaw < -math.pi then
		s_DeltaYaw = s_DeltaYaw + 2*math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_Increment = Globals.YawPerFrame

	if s_AbsDeltaYaw < s_Increment then
		self.m_Player.input.authoritativeAimingYaw = self._TargetYaw
		self.m_Player.input.authoritativeAimingPitch = self._TargetPitch
		return
	end

	if s_DeltaYaw > 0 then
		s_Increment = -s_Increment
	end

	local s_TempYaw = self.m_Player.input.authoritativeAimingYaw + s_Increment

	if s_TempYaw >= (math.pi * 2) then
		s_TempYaw = s_TempYaw - (math.pi * 2)
	elseif s_TempYaw < 0.0 then
		s_TempYaw = s_TempYaw + (math.pi * 2)
	end

	self.m_Player.input.authoritativeAimingYaw = s_TempYaw
	self.m_Player.input.authoritativeAimingPitch = self._TargetPitch

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
	self:_AbortAttack()
	if self._ActiveAction ~= BotActionFlags.OtherActionActive then
		self._TargetPitch = 0.0
	end

	self._ReloadTimer = self._ReloadTimer + Registry.BOT.BOT_UPDATE_CYCLE

	if self._ReloadTimer > 1.5 and self._ReloadTimer < 2.5 then
		self:_SetInput(EntryInputActionEnum.EIAReload, 1)
	end
end

function Bot:_UpdateAttackingVehicle()
	if self._ShootPlayer.soldier ~= nil and self._Shoot then
		if (self._ShootModeTimer < Config.BotFireModeDuration * 3) then -- thre time the default duration

			self._ReloadTimer = 0.0 -- reset reloading

			if self._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
				local s_AttackMode = m_Vehicles:CheckForVehicleAttack(self._ShootPlayerVehicleType, self._DistanceToPlayer, self.m_SecondaryGadget, true)

				if s_AttackMode ~= VehicleAttackModes.NoAttack then
					self._WeaponToUse = BotWeapons.Primary
				else
					self._ShootModeTimer = Config.BotFireModeDuration -- end attack
				end
			else
				self._WeaponToUse = BotWeapons.Primary
			end


			--shooting sequence
			if self.m_ActiveWeapon ~= nil then
				if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.AntiAir) then
					if self._ShotTimer >= 5.0 then
						self._ShotTimer = 0.0
					end
					if self._ShotTimer >= 0.5 and self._VehicleReadyToShoot then
						self:_SetInput(EntryInputActionEnum.EIAFire, 1)
					end
				else
					if self._ShotTimer >= 0.6 then
						self._ShotTimer = 0.0
					end
					if self._ShotTimer >= 0.3 and self._VehicleReadyToShoot then
						self:_SetInput(EntryInputActionEnum.EIAFire, 1)
					end
				end
				self._ShotTimer = self._ShotTimer + Registry.BOT.BOT_UPDATE_CYCLE
			end
		else
			self._TargetPitch = 0.0
			self._WeaponToUse = BotWeapons.Primary
			self:_AbortAttack()
			self:_ResetActionFlag(BotActionFlags.C4Active)
			self:_ResetActionFlag(BotActionFlags.GrenadeActive)
		end
	elseif self._ShootPlayer.soldier == nil then -- reset if enemy is dead
		self:_AbortAttack()
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

function Bot:_UpdateVehicleMovableId()
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
		if not Config.UseAirVehicles and (s_VehicleData.Type == VehicleTypes.Plane or s_VehicleData.Type == VehicleTypes.Chopper) then
			return -3 -- not allowed to use
		end
		-- keep one seat free, if enough available
		local s_MaxEntries = p_Entity.entryCount
		if not p_PlayerIsDriver and s_MaxEntries > 2 then
			s_MaxEntries = s_MaxEntries -1
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

function Bot:_UpdateNormalMovementVehicle()
	if self._VehicleTakeoffTimer > 0.0 then
		self._VehicleTakeoffTimer = self._VehicleTakeoffTimer - Registry.BOT.BOT_UPDATE_CYCLE
		if self._JetAbortAttackActive then
			local s_TargetPosition = self.m_Player.controlledControllable.transform.trans
			local s_Forward = self.m_Player.controlledControllable.transform.forward
			s_Forward.y = 0
			s_Forward:Normalize()
			s_TargetPosition = s_TargetPosition + (s_Forward*50)
			s_TargetPosition.y = s_TargetPosition.y + 50
			local s_Waypoint = {
				Position = s_TargetPosition
			}
			self._TargetPoint = s_Waypoint
			return
		end
	end
	self._JetAbortAttackActive = false
	if self._VehicleWaitTimer > 0.0 then
		self._VehicleWaitTimer = self._VehicleWaitTimer - Registry.BOT.BOT_UPDATE_CYCLE
		if self._VehicleWaitTimer <= 0.0 then
			if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
				-- check for other plane in front of bot
				local s_IsInfront = false
				for _, l_Jet in pairs(g_GameDirector:GetSpawnableVehicle(self.m_Player.teamId)) do
					local s_DistanceToJet = self.m_Player.controlledControllable.transform.trans:Distance(l_Jet.transform.trans)
					if s_DistanceToJet < 30 then
						local s_CompPos = self.m_Player.controlledControllable.transform.trans + self.m_Player.controlledControllable.transform.forward * s_DistanceToJet
						if l_Jet.transform.trans:Distance(s_CompPos) < 10 then
							s_IsInfront = true
						end
					end
				end
				if s_IsInfront then
					self._VehicleWaitTimer = 5.0 -- one more cycle
					return
				end
			end
			g_GameDirector:_SetVehicleObjectiveState(self.m_Player.soldier.worldTransform.trans, false)
		else
			return
		end
	end

	-- move along points
	if m_NodeCollection:Get(1, self._PathIndex) ~= nil then -- check for valid point
		-- get next point
		local s_ActivePointIndex = self:_GetWayIndex(self._CurrentWayPoint)

		local s_Point = nil
		local s_NextPoint = nil
		local s_PointIncrement = 1

		s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)

		if not self._InvertPathDirection then
			s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 1), self._PathIndex)
		else
			s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint - 1), self._PathIndex)
		end

		-- execute Action if needed
		if self._ActiveAction == BotActionFlags.OtherActionActive then
			if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
				if s_Point.Data.Action.type == "exit" then
					self:_ResetActionFlag(BotActionFlags.OtherActionActive)
					local s_OnlyPassengers = false
					if s_Point.Data.Action.onlyPassengers ~= nil and s_Point.Data.Action.onlyPassengers == true then
						s_OnlyPassengers = true
					end

					-- let all other bots exit the vehicle
					local s_VehicleEntity = self.m_Player.controlledControllable
					if s_VehicleEntity ~= nil then
						for i = 1, (s_VehicleEntity.entryCount - 1) do
							local s_Player = s_VehicleEntity:GetPlayerInEntry(i)
							if s_Player ~= nil then
								Events:Dispatch('Bot:ExitVehicle', s_Player.name)
							end
						end
					end
					-- Exit Vehicle
					if not s_OnlyPassengers then
						self:ExitVehicle()
					end
				elseif self._ActionTimer <= s_Point.Data.Action.time then
					for _, l_Input in pairs(s_Point.Data.Action.inputs) do
						self:_SetInput(l_Input, 1)
					end
				end
			else
				self:_ResetActionFlag(BotActionFlags.OtherActionActive)
			end

			self._ActionTimer = self._ActionTimer - Registry.BOT.BOT_UPDATE_CYCLE

			if self._ActionTimer <= 0.0 then
				self:_ResetActionFlag(BotActionFlags.OtherActionActive)
			end

			if self._ActiveAction == BotActionFlags.OtherActionActive then
				return --DONT EXECUTE ANYTHING ELSE
			else
				s_Point = s_NextPoint
			end
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- movement
			self._WayWaitTimer = 0.0
			self._WayWaitYawTimer = 0.0
			self.m_ActiveSpeedValue = s_Point.SpeedMode --speed

			-- TODO: use vehicle transform also for trace?
			local s_DifferenceY = s_Point.Position.z - self.m_Player.soldier.worldTransform.trans.z
			local s_DifferenceX = s_Point.Position.x - self.m_Player.soldier.worldTransform.trans.x
			local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
			local s_HeightDistance = math.abs(s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y)

			--detect obstacle and move over or around TODO: Move before normal jump
			local s_CurrentWayPointDistance = self.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)

			if s_CurrentWayPointDistance > self._LastWayDistance + 0.02 and self._ObstaceSequenceTimer == 0.0 then
				--skip one pooint
				s_DistanceFromTarget = 0
				s_HeightDistance = 0
			end

			self._TargetPoint = s_Point
			self._NextTargetPoint = s_NextPoint

			if math.abs(s_CurrentWayPointDistance - self._LastWayDistance) < 0.02 or self._ObstaceSequenceTimer ~= 0.0 then
				-- try to get around obstacle
				if self._ObstacleRetryCounter % 2 == 0 then
					if self._ObstaceSequenceTimer < 4.0 then
						self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- full throttle
					end
				else
					if self._ObstaceSequenceTimer < 2.0 then
						self.m_ActiveSpeedValue = BotMoveSpeeds.Backwards
					end
				end

				if (self.m_ActiveSpeedValue == BotMoveSpeeds.Backwards and self._ObstaceSequenceTimer > 3.0) or
				(self.m_ActiveSpeedValue ~= BotMoveSpeeds.Backwards and self._ObstaceSequenceTimer > 5.0) then
					self._ObstaceSequenceTimer = 0.0
					self._ObstacleRetryCounter = self._ObstacleRetryCounter + 1
				end

				self._ObstaceSequenceTimer = self._ObstaceSequenceTimer + Registry.BOT.BOT_UPDATE_CYCLE

				if self._ObstacleRetryCounter >= 4 then --try next waypoint
					self._ObstacleRetryCounter = 0

					s_DistanceFromTarget = 0
					s_HeightDistance = 0

					-- teleport if stuck
					if Config.TeleportIfStuck and
					m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) and
					m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) and
					(MathUtils:GetRandomInt(0,100) <= Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK_IN_VEHICLE) then
						local s_Transform = self.m_Player.controlledControllable.transform:Clone()
						s_Transform.trans = self._TargetPoint.Position
						s_Transform:LookAtTransform(self._TargetPoint.Position, self._NextTargetPoint.Position)
						self.m_Player.controlledControllable.transform = s_Transform
						m_Logger:Write("tepeported in vehicle of "..self.m_Player.name)
					else
						if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
							s_PointIncrement = 1
						else
							if MathUtils:GetRandomInt(1, 2) == 1 then
								s_PointIncrement = 1
							else
								s_PointIncrement = -1
							end
						end
					end
				end
			end

			self._LastWayDistance = s_CurrentWayPointDistance


			local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint * 5

			if self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 6
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 4
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 3
			end

			--check for reached target
			if s_DistanceFromTarget <= s_TargetDistanceSpeed and s_HeightDistance <= Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT then

				-- CHECK FOR ACTION
				if s_Point.Data.Action ~= nil then
					local s_Action = s_Point.Data.Action

					if g_GameDirector:CheckForExecution(s_Point, self.m_Player.teamId, true) then
						self._ActiveAction = BotActionFlags.OtherActionActive

						if s_Action.time ~= nil then
							self._ActionTimer = s_Action.time
						else
							self._ActionTimer = 0.0
						end

						if s_Action.yaw ~= nil then
							self._TargetYaw = s_Action.yaw
						end

						if s_Action.pitch ~= nil then
							self._TargetPitch = s_Action.pitch
						end

						return --DONT DO ANYTHING ELSE ANYMORE
					end
				end

				-- CHECK FOR PATH-SWITCHES
				local s_NewWaypoint = nil
				local s_SwitchPath = false
				s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(self.m_Name, s_Point, self._Objective, self.m_InVehicle, self.m_Player.teamId, self.m_ActiveVehicle.Terrain)

				if self.m_Player.soldier == nil then
					return
				end

				if s_SwitchPath == true and not self._OnSwitch then
					if self._Objective ~= '' then
						-- 'best' direction for objective on switch
						local s_Direction = m_NodeCollection:ObjectiveDirection(s_NewWaypoint, self._Objective, self.m_InVehicle)
						self._InvertPathDirection = (s_Direction == 'Previous')
					else
						-- random path direction on switch
						self._InvertPathDirection = MathUtils:GetRandomInt(1,2) == 1
					end

					self._PathIndex = s_NewWaypoint.PathIndex
					self._CurrentWayPoint = s_NewWaypoint.PointIndex
					self._OnSwitch = true
				else
					self._OnSwitch = false

					if self._InvertPathDirection then
						self._CurrentWayPoint = s_ActivePointIndex - s_PointIncrement
					else
						self._CurrentWayPoint = s_ActivePointIndex + s_PointIncrement
					end
				end

				self._ObstaceSequenceTimer = 0.0
				self._LastWayDistance = 1000.0
			end
		else -- wait mode
			self._WayWaitTimer = self._WayWaitTimer + Registry.BOT.BOT_UPDATE_CYCLE

			self:_LookAround(Registry.BOT.BOT_UPDATE_CYCLE)

			if self._WayWaitTimer > s_Point.OptValue then
				self._WayWaitTimer = 0.0

				if self._InvertPathDirection then
					self._CurrentWayPoint = s_ActivePointIndex - 1
				else
					self._CurrentWayPoint = s_ActivePointIndex + 1
				end
			end
		end
	--else -- no point: do nothing
	end
end

function Bot:_UpdateShootMovementVehicle()
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement -- no movement while attacking in vehicles
end


function Bot:_UpdateSpeedOfMovementVehicle()
	if self.m_Player.soldier == nil or self._VehicleWaitTimer > 0.0 then
		return
	end

	if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
		self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
	end

	if  m_Vehicles:IsNotVehicleTerrain(self.m_ActiveVehicle, VehicleTerrains.Air) then -- Air-Vehicles are handled in the yaw-function
		-- additional movement
		local s_SpeedVal = 0

		if self.m_ActiveMoveMode ~= BotMoveModes.Standstill then
			-- limit speed if full steering active
			if self._FullVehicleSteering and self.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
				self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			end

			-- normal values
			if self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
				s_SpeedVal = 0.25
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
				s_SpeedVal = 0.5
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Normal then
				s_SpeedVal = 0.8
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
				s_SpeedVal = 1.0
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				s_SpeedVal = -0.7
			end
		end

		-- movent speed
		if self.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
			self:_SetInput(EntryInputActionEnum.EIABrake, -s_SpeedVal)
		elseif self.m_ActiveSpeedValue ~= BotMoveSpeeds.NoMovement then
			self._BrakeTimer = 0.7
			self:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal)
		else
			if self._BrakeTimer > 0.0 then
				self:_SetInput(EntryInputActionEnum.EIABrake, 1)
			end

			self._BrakeTimer = self._BrakeTimer - Registry.BOT.BOT_UPDATE_CYCLE
		end
	end
end

function Bot:_AbortAttack()
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) and self._ShootPlayerName ~= "" then
		self._VehicleTakeoffTimer = Registry.VEHICLES.JET_ABORT_ATTACK_TIME
		self._JetAbortAttackActive = true
		self._Pid_Drv_Yaw:Reset()
		self._Pid_Drv_Tilt:Reset()
		self._Pid_Drv_Roll:Reset()
	end
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
