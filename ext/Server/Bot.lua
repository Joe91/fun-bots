---@class Bot
Bot = class('Bot')

require('__shared/Config')
require('PidController')

---@type NodeCollection
local m_NodeCollection = require('__shared/NodeCollection')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")
---@type AirTargets
local m_AirTargets = require("AirTargets")
---@type Logger
local m_Logger = Logger("Bot", Debug.Server.BOT)

---@param p_Player Player
function Bot:__init(p_Player)
	--Player Object
	self.m_Player = p_Player
	self.m_Name = p_Player.name
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
					self:_UpdateStaticMovement()
					self:_UpdateInputs()
					self:_UpdateYaw()
					self._UpdateFastTimer = 0.0
					return
				end

				------------------ CODE OF BEHAVIOUR STARTS HERE ---------------------
				-- detect modes
				self:_SetActiveVars()
				local s_Attacking = self._ShootPlayer ~= nil -- can be either attacking or reviving or enter of a vehicle with a player

				if not self.m_InVehicle then
					-- sync slow code with fast code. Therefore execute the slow code first
					if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
						-- common part
						self:_UpdateWeaponSelection()

						-- differ attacking
						if s_Attacking then
							self:_UpdateAttacking()
							if self._ActiveAction == BotActionFlags.ReviveActive or
							self._ActiveAction == BotActionFlags.EnterVehicleActive or
							self._ActiveAction == BotActionFlags.RepairActive or
							self._ActiveAction == BotActionFlags.C4Active then
								self:_UpdateMovementSprintToTarget()
							else
								self:_UpdateShootMovement()
							end
						else
							self:_UpdateDeployAndReload()
							self:_UpdateNormalMovement()
							if self.m_Player.soldier == nil then
								return
							end
						end

						-- common things
						self:_UpdateSpeedOfMovement()
						self:_UpdateInputs()
						self._UpdateTimer = 0.0
					end

					-- fast code
					if s_Attacking then
						self:_UpdateAiming()
					else
						self:_UpdateTargetMovement()
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
								if self.m_Player.controlledEntryId == 0 then -- only if driver
									self:_UpdateNormalMovementVehicle()
								end
							end

							-- common things
							self:_UpdateSpeedOfMovementVehicle()
							self:_UpdateInputs()
							self:_CheckForExitVehicle(self._UpdateTimer)
							self._UpdateTimer = 0.0
						end

						-- fast code
						if s_Attacking then
							if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
								self:_UpdateAimingVehicleAdvanced()
							else
								self:_UpdateAimingVehicle()
							end
						else
							if self.m_Player.controlledEntryId == 0 then -- only if driver
								self:_UpdateTargetMovementVehicle()
							else
								self:_UpdateVehicleLookAround(self._UpdateFastTimer)
							end
						end
						self:_UpdateYawVehicle(s_Attacking)
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
	if self.m_Kit == BotKits.Assault and p_Player.corpse ~= nil then
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
	if self.m_Kit == BotKits.Support or self.m_Kit == BotKits.Assault then
		if self.m_PrimaryGadget.type == WeaponTypes.Ammobag or self.m_PrimaryGadget.type == WeaponTypes.Medkit then
			self:_AbortAttack()
			self._WeaponToUse = BotWeapons.Gadget1
			self._DeployTimer = 0.0
		end
	end
end

function Bot:ExitVehicle()
	self:_AbortAttack()
	self.m_Player:ExitVehicle(false, false)
	local s_Node = g_GameDirector:FindClosestPath(self.m_Player.soldier.worldTransform.trans, false)

	if s_Node ~= nil then
		-- switch to foot
		self._InvertPathDirection = false
		self._PathIndex = s_Node.PathIndex
		self._CurrentWayPoint = s_Node.PointIndex
		self._LastWayDistance = 1000.0
	end
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
		if self.m_ActiveWeapon.type ~= WeaponTypes.Sniper then
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
	if not self:IsReadyToAttack() then
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
			self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)

			if self.m_KnifeMode then
				table.insert(self._KnifeWayPositions, p_Player.soldier.worldTransform.trans:Clone())
			end

			return true
		else
			self._ShootModeTimer = Config.BotFireModeDuration
			return false
		end
	end

	return false
end

---@param p_DeltaTime number
function Bot:_CheckForExitVehicle(p_DeltaTime)
	if self.m_InVehicle then
		self._VehicleHealthTimer = self._VehicleHealthTimer + p_DeltaTime
		if self._VehicleHealthTimer >= Registry.VEHICLES.VEHICLE_HEALTH_CYLCE_TIME then
			self._VehicleHealthTimer = 0
			local s_CurrentVehicleHealth = PhysicsEntity(self.m_Player.controlledControllable).internalHealth
			if s_CurrentVehicleHealth <= self._ExitVehicleHealth then
				if math.random(0, 100) <= Registry.VEHICLES.VEHICLE_PROPABILITY_EXIT_LOW_HEALTH then
					self:ExitVehicle()
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

	if self.m_ActiveWeapon.type == WeaponTypes.Sniper then
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

function Bot:_UpdateAimingVehicleAdvanced()
	if self._ShootPlayer == nil then
		return
	end

	if not self._Shoot or self._ShootPlayer.soldier == nil then
		return
	end

	--interpolate target-player movement
	local s_TargetVelocity = Vec3.zero
	local s_PitchCorrection = 0.0
	local s_FullPositionTarget = nil
	local s_FullPositionBot = nil

	if self._VehicleMovableId ~= nil then
		s_FullPositionBot = self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().trans
	else
		-- TODO: adjust for chopper-drivers?
		s_FullPositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false, false)
	end

	if self._ShootPlayerVehicleType == VehicleTypes.MavBot then
		s_FullPositionTarget = self._ShootPlayer.controlledControllable.transform.trans:Clone()
	else
		if self.m_Player.controlledEntryId == 0 and self._ShootPlayerVehicleType == VehicleTypes.NoVehicle and self._ShootPlayer.soldier.worldTransform.trans.y < s_FullPositionBot.y then
			-- add nothing --> aim for the feet of the target
			s_FullPositionTarget = self._ShootPlayer.soldier.worldTransform.trans:Clone() + Vec3(0.0, 0.1, 0.0)
		else
			s_FullPositionTarget = self._ShootPlayer.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self._ShootPlayer, true, false)
		end
	end

	if self._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
		s_TargetVelocity = PhysicsEntity(self._ShootPlayer.soldier).velocity
	else
		s_TargetVelocity = PhysicsEntity(self._ShootPlayer.controlledControllable).velocity
	end

	--calculate how long the distance is --> time to travel
	local s_Drop = 0.0
	local s_Speed = 0.0
	local s_VectorBetween = s_FullPositionTarget - s_FullPositionBot

	s_Speed, s_Drop = m_Vehicles:GetSpeedAndDrop(self.m_ActiveVehicle, self.m_Player.controlledEntryId)

	local A = s_TargetVelocity:Dot(s_TargetVelocity) - s_Speed * s_Speed
	local B = 2.0 * s_TargetVelocity:Dot(s_VectorBetween)
	local C = s_VectorBetween:Dot(s_VectorBetween)
	local s_Determinant = math.sqrt(B*B-4*A*C)
	local t1 = (-B + s_Determinant) / (2*A)
	local t2 = (-B - s_Determinant) / (2*A)
	local s_TimeToTravel = 0

	if t1 > 0 then
		if t2 > 0 then
			s_TimeToTravel = math.min(t1, t2)
		else
			s_TimeToTravel = t1
		end
	else
		s_TimeToTravel = math.max(t2, 0.0)
	end

	local s_AimAt = s_FullPositionTarget + (s_TargetVelocity * s_TimeToTravel)

	s_PitchCorrection = 0.375 * s_TimeToTravel * s_TimeToTravel * s_Drop  -- from theory 0.5. In real 0.25 works much better

	--calculate yaw and pitch
	local s_DifferenceZ = s_AimAt.z - s_FullPositionBot.z
	local s_DifferenceX = s_AimAt.x - s_FullPositionBot.x
	local s_DifferenceY = s_AimAt.y + s_PitchCorrection - s_FullPositionBot.y

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	--calculate pitch
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	self._TargetPitch = s_Pitch
	self._TargetYaw = s_Yaw


	-- abort attacking in chopper or jet if too steep or too low
	if (m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) and self.m_Player.controlledEntryId == 0 ) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		local s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi
		if math.abs(self._TargetPitch) > s_PitchHalf then
			self:_AbortAttack()
			return
		end
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) and s_FullPositionBot:Distance(s_FullPositionTarget) < Registry.VEHICLES.ABORT_ATTACK_AIR_DISTANCE_JET then
			self:_AbortAttack()
		end
		if self._ShootPlayerVehicleType ~= VehicleTypes.Chopper and self._ShootPlayerVehicleType ~= VehicleTypes.Plane then
			local s_DiffVertical = s_FullPositionBot.y - s_FullPositionTarget.y
			if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) then
				if s_DiffVertical < Registry.VEHICLES.ABORT_ATTACK_HEIGHT_CHOPPER then -- too low to the ground
					self:_AbortAttack()
				end
			elseif m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
				if s_DiffVertical < Registry.VEHICLES.ABORT_ATTACK_HEIGHT_JET then -- too low to the ground
					self:_AbortAttack()
				end
				if self._DistanceToPlayer < Registry.VEHICLES.ABORT_ATTACK_DISTANCE_JET then
					self:_AbortAttack()
				end
			end
			return
		end
	end
end

function Bot:_UpdateAimingVehicle()
	if self._ShootPlayer == nil then
		return
	end

	if not self._Shoot or self._ShootPlayer.soldier == nil then
		return
	end

	--interpolate target-player movement
	local s_TargetMovement = Vec3.zero
	local s_PitchCorrection = 0.0
	local s_FullPositionTarget = nil
	local s_FullPositionBot = nil

	if self._VehicleMovableId ~= nil then
		s_FullPositionBot = self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().trans
	else
		-- TODO: adjust for chopper-drivers?
		s_FullPositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false, false)
	end

	if self._ShootPlayerVehicleType == VehicleTypes.MavBot then
		s_FullPositionTarget = self._ShootPlayer.controlledControllable.transform.trans:Clone()
	else
		if self.m_Player.controlledEntryId == 0 and self._ShootPlayerVehicleType == VehicleTypes.NoVehicle and self._ShootPlayer.soldier.worldTransform.trans.y < s_FullPositionBot.y then
			-- add nothing --> aim for the feet of the target (+0.1)
			s_FullPositionTarget = self._ShootPlayer.soldier.worldTransform.trans:Clone() + Vec3(0.0, 0.1, 0.0)
		else
			s_FullPositionTarget = self._ShootPlayer.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self._ShootPlayer, true, false)
		end
	end

	if self._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
		s_TargetMovement = PhysicsEntity(self._ShootPlayer.soldier).velocity
	else
		s_TargetMovement = PhysicsEntity(self._ShootPlayer.controlledControllable).velocity
	end

	--calculate how long the distance is --> time to travel
	self._DistanceToPlayer = s_FullPositionTarget:Distance(s_FullPositionBot)

	local s_Drop = 0.0
	local s_Speed = 0.0

	s_Speed, s_Drop = m_Vehicles:GetSpeedAndDrop(self.m_ActiveVehicle, self.m_Player.controlledEntryId)

	local s_TimeToTravel = (self._DistanceToPlayer / s_Speed)
	s_PitchCorrection = 0.375 * s_TimeToTravel * s_TimeToTravel * s_Drop  -- from theory 0.5. In real 0.25 works much better

	s_TargetMovement = (s_TargetMovement * s_TimeToTravel)


	local s_DifferenceY = 0
	local s_DifferenceX = 0
	local s_DifferenceZ = 0

	--calculate yaw and pitch
	s_DifferenceZ = s_FullPositionTarget.z + s_TargetMovement.z - s_FullPositionBot.z
	s_DifferenceX = s_FullPositionTarget.x + s_TargetMovement.x - s_FullPositionBot.x
	s_DifferenceY = s_FullPositionTarget.y + s_TargetMovement.y + s_PitchCorrection - s_FullPositionBot.y

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	--calculate pitch
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	self._TargetPitch = s_Pitch
	self._TargetYaw = s_Yaw


	-- abort attacking in chopper or jet if too steep or too low
	if (m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) and self.m_Player.controlledEntryId == 0 ) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		local s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi
		if math.abs(self._TargetPitch) > s_PitchHalf then
			self:_AbortAttack()
			return
		end
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) and s_FullPositionBot:Distance(s_FullPositionTarget) < Registry.VEHICLES.ABORT_ATTACK_AIR_DISTANCE_JET then
			self:_AbortAttack()
		end
		if self._ShootPlayerVehicleType ~= VehicleTypes.Chopper and self._ShootPlayerVehicleType ~= VehicleTypes.Plane then
			local s_DiffVertical = s_FullPositionBot.y - s_FullPositionTarget.y
			if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) then
				if s_DiffVertical < Registry.VEHICLES.ABORT_ATTACK_HEIGHT_CHOPPER then -- too low to the ground
					self:_AbortAttack()
				end
			elseif m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
				if s_DiffVertical < Registry.VEHICLES.ABORT_ATTACK_HEIGHT_JET then -- too low to the ground
					self:_AbortAttack()
				end
				if self._DistanceToPlayer < Registry.VEHICLES.ABORT_ATTACK_DISTANCE_JET then
					self:_AbortAttack()
				end
			end
			return
		end
	end
end

function Bot:_UpdateAiming()
	if self._ShootPlayer == nil then
		return
	end

	if self._ActiveAction ~= BotActionFlags.ReviveActive and self._ActiveAction ~= BotActionFlags.RepairActive then
		if not self._Shoot or self._ShootPlayer.soldier == nil or self.m_ActiveWeapon == nil then
			return
		end

		--interpolate target-player movement
		local s_TargetMovement = Vec3.zero
		local s_PitchCorrection = 0.0
		local s_FullPositionTarget = nil
		local s_FullPositionBot = nil

		s_FullPositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false, false)

		if self._ShootPlayerVehicleType == VehicleTypes.MavBot then
			s_FullPositionTarget = self._ShootPlayer.controlledControllable.transform.trans:Clone()
		else
			local s_AimForHead = false
			if self.m_ActiveWeapon.type == WeaponTypes.Sniper then
				s_AimForHead = Config.AimForHeadSniper
			elseif self.m_ActiveWeapon.type == WeaponTypes.LMG then
				s_AimForHead = Config.AimForHeadSupport
			else
				s_AimForHead = Config.AimForHead
			end

			s_FullPositionTarget = self._ShootPlayer.soldier.worldTransform.trans:Clone()
			s_FullPositionTarget = s_FullPositionTarget + m_Utilities:getCameraPos(self._ShootPlayer, true, s_AimForHead)
		end

		if self._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
			s_TargetMovement = PhysicsEntity(self._ShootPlayer.soldier).velocity
		else
			s_TargetMovement = PhysicsEntity(self._ShootPlayer.controlledControllable).velocity
		end

		local s_GrenadePitch = 0.0
		--calculate how long the distance is --> time to travel
		self._DistanceToPlayer = s_FullPositionTarget:Distance(s_FullPositionBot)

		if not self.m_KnifeMode then
			local s_Drop = 0.0
			local s_Speed = 0.0
			local s_TimeToTravel = 0.0
			s_Drop = self.m_ActiveWeapon.bulletDrop
			s_Speed = self.m_ActiveWeapon.bulletSpeed

			if self.m_ActiveWeapon.type == WeaponTypes.Grenade then
				if self._DistanceToPlayer < 3.0 then
					self._DistanceToPlayer = 3.0 -- don't throw them too close..
				end

				if self._DistanceToPlayer > 24.5 then s_GrenadePitch = 0.7504915783575616
				elseif self._DistanceToPlayer > 24.0 then s_GrenadePitch = 0.8569566627292158
				elseif self._DistanceToPlayer > 23.5 then s_GrenadePitch = 0.9023352232810685
				elseif self._DistanceToPlayer > 23.0 then s_GrenadePitch = 0.9372418083209549
				elseif self._DistanceToPlayer > 22.5 then s_GrenadePitch = 0.9651670763528643
				elseif self._DistanceToPlayer > 22.0 then s_GrenadePitch = 0.9913470151327791
				elseif self._DistanceToPlayer > 21.5 then s_GrenadePitch = 1.0157816246606999
				elseif self._DistanceToPlayer > 21.0 then s_GrenadePitch = 1.0367255756846316
				elseif self._DistanceToPlayer > 20.5 then s_GrenadePitch = 1.0559241974565694
				elseif self._DistanceToPlayer > 20.0 then s_GrenadePitch = 1.0751228192285072
				elseif self._DistanceToPlayer > 19.5 then s_GrenadePitch = 1.0943214410004447
				elseif self._DistanceToPlayer > 19.0 then s_GrenadePitch = 1.111774733520388
				elseif self._DistanceToPlayer > 18.5 then s_GrenadePitch = 1.1274826967883367
				elseif self._DistanceToPlayer > 18.0 then s_GrenadePitch = 1.143190660056286
				elseif self._DistanceToPlayer > 17.5 then s_GrenadePitch = 1.1588986233242349
				elseif self._DistanceToPlayer > 17.0 then s_GrenadePitch = 1.1746065865921838
				elseif self._DistanceToPlayer > 16.5 then s_GrenadePitch = 1.1885692206081382
				elseif self._DistanceToPlayer > 16.0 then s_GrenadePitch = 1.202531854624093
				elseif self._DistanceToPlayer > 15.5 then s_GrenadePitch = 1.2164944886400477
				elseif self._DistanceToPlayer > 15.0 then s_GrenadePitch = 1.2304571226560022
				elseif self._DistanceToPlayer > 14.5 then s_GrenadePitch = 1.2426744274199626
				elseif self._DistanceToPlayer > 14.0 then s_GrenadePitch = 1.2566370614359172
				elseif self._DistanceToPlayer > 13.5 then s_GrenadePitch = 1.2688543661998775
				elseif self._DistanceToPlayer > 13.0 then s_GrenadePitch = 1.281071670963838
				elseif self._DistanceToPlayer > 12.5 then s_GrenadePitch = 1.293288975727798
				elseif self._DistanceToPlayer > 12.0 then s_GrenadePitch = 1.3055062804917585
				elseif self._DistanceToPlayer > 11.5 then s_GrenadePitch = 1.3177235852557188
				elseif self._DistanceToPlayer > 11.0 then s_GrenadePitch = 1.3299408900196792
				elseif self._DistanceToPlayer > 10.5 then s_GrenadePitch = 1.3421581947836394
				elseif self._DistanceToPlayer > 10.0 then s_GrenadePitch = 1.3526301702956054
				elseif self._DistanceToPlayer > 9.5 then s_GrenadePitch = 1.3648474750595656
				elseif self._DistanceToPlayer > 9.0 then s_GrenadePitch = 1.377064779823526
				elseif self._DistanceToPlayer > 8.5 then s_GrenadePitch = 1.387536755335492
				elseif self._DistanceToPlayer > 8.0 then s_GrenadePitch = 1.3980087308474578
				elseif self._DistanceToPlayer > 7.5 then s_GrenadePitch = 1.4102260356114182
				elseif self._DistanceToPlayer > 7.0 then s_GrenadePitch = 1.4206980111233845
				elseif self._DistanceToPlayer > 6.5 then s_GrenadePitch = 1.43116998663535
				elseif self._DistanceToPlayer > 6.0 then s_GrenadePitch = 1.4433872913993104
				elseif self._DistanceToPlayer > 5.5 then s_GrenadePitch = 1.4538592669112764
				elseif self._DistanceToPlayer > 5.0 then s_GrenadePitch = 1.4643312424232426
				elseif self._DistanceToPlayer > 4.5 then s_GrenadePitch = 1.4748032179352084
				elseif self._DistanceToPlayer > 4.0 then s_GrenadePitch = 1.4852751934471744
				elseif self._DistanceToPlayer > 3.5 then s_GrenadePitch = 1.4957471689591406
				elseif self._DistanceToPlayer > 3.0 then s_GrenadePitch = 1.5079644737231006
				elseif self._DistanceToPlayer > 2.5 then s_GrenadePitch = 1.5184364492350666
				elseif self._DistanceToPlayer > 2.0 then s_GrenadePitch = 1.5289084247470324
				elseif self._DistanceToPlayer > 1.5 then s_GrenadePitch = 1.5393804002589986
				elseif self._DistanceToPlayer > 1.0 then s_GrenadePitch = 1.5498523757709646
				elseif self._DistanceToPlayer > 0.5 then s_GrenadePitch = 1.5603243512829308
				end
			else
				if Registry.BOT.USE_ADVANCED_AIMING then
					--calculate how long the distance is --> time to travel
					local s_VectorBetween = s_FullPositionTarget - s_FullPositionBot

					local A = s_TargetMovement:Dot(s_TargetMovement) - s_Speed * s_Speed
					local B = 2.0 * s_TargetMovement:Dot(s_VectorBetween)
					local C = s_VectorBetween:Dot(s_VectorBetween)
					local s_Determinant = math.sqrt(B*B-4*A*C)
					local t1 = (-B + s_Determinant) / (2*A)
					local t2 = (-B - s_Determinant) / (2*A)

					if t1 > 0 then
						if t2 > 0 then
							s_TimeToTravel = math.min(t1, t2)
						else
							s_TimeToTravel = t1
						end
					else
						s_TimeToTravel = math.max(t2, 0.0)
					end
				else
					s_TimeToTravel = (self._DistanceToPlayer / s_Speed)
				end

				s_PitchCorrection = 0.25 * s_TimeToTravel * s_TimeToTravel * s_Drop -- this correction (0.5 * 0.5) seems to be correct. No idea why.
			end

			s_TargetMovement = (s_TargetMovement * s_TimeToTravel)

		end

		local s_DifferenceY = 0
		local s_DifferenceX = 0
		local s_DifferenceZ = 0

		--calculate yaw and pitch
		if self.m_KnifeMode and #self._KnifeWayPositions > 0 then
			s_DifferenceZ = self._KnifeWayPositions[1].z - self.m_Player.soldier.worldTransform.trans.z
			s_DifferenceX = self._KnifeWayPositions[1].x - self.m_Player.soldier.worldTransform.trans.x

			if self.m_Player.soldier.worldTransform.trans:Distance(self._KnifeWayPositions[1]) < 1.5 then
				table.remove(self._KnifeWayPositions, 1)
			end
		else
			s_DifferenceZ = s_FullPositionTarget.z + s_TargetMovement.z - s_FullPositionBot.z
			s_DifferenceX = s_FullPositionTarget.x + s_TargetMovement.x - s_FullPositionBot.x
			s_DifferenceY = s_FullPositionTarget.y + s_TargetMovement.y + s_PitchCorrection - s_FullPositionBot.y
		end

		local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local s_Pitch = 0.0

		if self.m_ActiveWeapon.type == WeaponTypes.Grenade then
			s_Pitch = s_GrenadePitch
		else
			local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
			s_Pitch = math.atan(s_DifferenceY, s_Distance)
		end

		-- worsen yaw and pitch depending on bot-skill. Don't use Skill for Nades and Rockets.
		if self.m_ActiveWeapon.type ~= WeaponTypes.Grenade and self.m_ActiveWeapon.type ~= WeaponTypes.Rocket then
			local s_WorseningValue = (math.random()*self._Skill/self._DistanceToPlayer) -- value scaled in offset in 1m
			if MathUtils:GetRandomInt(0, 1) > 0 then
				s_WorseningValue = -s_WorseningValue --randomly use positive or negative values
			end
			s_Yaw = s_Yaw + s_WorseningValue
			s_Pitch = s_Pitch + s_WorseningValue
		end

		self._TargetPitch = s_Pitch
		self._TargetYaw = s_Yaw

	elseif self._ActiveAction == BotActionFlags.RepairActive then -- repair
		if self._ShootPlayer == nil or self._ShootPlayer.soldier == nil or self._RepairVehicleEntity == nil then
			return
		end
		local s_PositionTarget = self._RepairVehicleEntity.transform.trans:Clone() -- aim at vehicle
		local s_PositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false, false)

		local s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
		local s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
		local s_DifferenceY = s_PositionTarget.y - s_PositionBot.y

		local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
		local s_Pitch = math.atan(s_DifferenceY, s_Distance)

		self._TargetPitch = s_Pitch
		self._TargetYaw = s_Yaw

	else -- revive active
		if self._ShootPlayer.corpse == nil then
			return
		end

		local s_PositionTarget = self._ShootPlayer.corpse.worldTransform.trans:Clone()
		local s_PositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false, false)

		local s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
		local s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
		local s_DifferenceY = s_PositionTarget.y - s_PositionBot.y

		local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
		local s_Pitch = math.atan(s_DifferenceY, s_Distance)

		self._TargetPitch = s_Pitch
		self._TargetYaw = s_Yaw
	end
end

function Bot:_UpdateTargetMovement()
	if self._TargetPoint ~= nil then
		local s_Distance = self.m_Player.soldier.worldTransform.trans:Distance(self._TargetPoint.Position)

		if s_Distance < 0.2 then
			self._TargetPoint = self._NextTargetPoint
		end

		local s_DifferenceY = self._TargetPoint.Position.z - self.m_Player.soldier.worldTransform.trans.z
		local s_DifferenceX = self._TargetPoint.Position.x - self.m_Player.soldier.worldTransform.trans.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		self._TargetYaw = s_Yaw
		self._TargetYaw = self._TargetYaw + self.m_YawOffset
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
		self:_UpdateAimingVehicleAdvanced()
		--self:_UpdateAimingVehicle()
	else
		-- just look a little around
		self:_UpdateVehicleLookAround(Registry.BOT.BOT_FAST_UPDATE_CYCLE)
	end
	self:_UpdateYawVehicle(true) --only gun --> therefore alsways gun-mode
end

function Bot:_UpdateAttackStationaryAAVehicle()
	if self._VehicleReadyToShoot then
		self:_SetInput(EntryInputActionEnum.EIAFire, 1)
	end
end

---@param p_Attacking boolean
function Bot:_UpdateYawVehicle(p_Attacking)
	local s_DeltaYaw = 0
	local s_DeltaPitch = 0
	local s_CorrectGunYaw = false

	local s_Pos = nil

	if not p_Attacking then
		if self.m_Player.controlledEntryId == 0 then
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
		local s_Delta_Height = self._TargetPoint.Position.y - self.m_Player.controlledControllable.transform.trans.y
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
		-- TODO: in strog steering: Roll a little
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
		if self.m_Player.controlledEntryId == 0 then -- driver
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

function Bot:_UpdateWeaponSelection()
	--select weapon-slot
	if self._ActiveAction ~= BotActionFlags.MeleeActive then
		if self.m_Player.soldier.weaponsComponent ~= nil then
			if self.m_KnifeMode then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
					self.m_ActiveWeapon = self.m_Knife
					self._ShotTimer = 0.0
				end
			elseif self._ActiveAction == BotActionFlags.ReviveActive or (self._WeaponToUse == BotWeapons.Gadget2 and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Gadget2 then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_5 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon5, 1)
					self.m_ActiveWeapon = self.m_SecondaryGadget
					self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)
				end
			elseif self._ActiveAction == BotActionFlags.RepairActive or (self._WeaponToUse == BotWeapons.Gadget1 and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Gadget1 then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_2 and self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_4 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon4, 1)
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon3, 1)
					self.m_ActiveWeapon = self.m_PrimaryGadget
					self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)
				end
			elseif self._ActiveAction == BotActionFlags.GrenadeActive or (self._WeaponToUse == BotWeapons.Grenade and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Grenade then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_6 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon6, 1)
					self.m_ActiveWeapon = self.m_Grenade
					self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)
				end
			elseif (self._WeaponToUse == BotWeapons.Pistol and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Pistol then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_1 then
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 1)
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon2, 1)
					self.m_ActiveWeapon = self.m_Pistol
					self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer, true)
				end
			elseif (self._WeaponToUse == BotWeapons.Primary and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Primary then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon1, 1)
					self.m_ActiveWeapon = self.m_Primary
					self._ShotTimer = 0.0
				end
			end
		end
	end
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

function Bot:_UpdateDeployAndReload()
	if self._ActiveAction == BotActionFlags.MeleeActive then
		return
	end
	self._WeaponToUse = BotWeapons.Primary
	self:_ResetActionFlag(BotActionFlags.C4Active)
	self:_ResetActionFlag(BotActionFlags.ReviveActive)
	self:_ResetActionFlag(BotActionFlags.RepairActive)
	self:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
	self:_ResetActionFlag(BotActionFlags.GrenadeActive)
	self:_AbortAttack()

	if self._ActiveAction ~= BotActionFlags.OtherActionActive then
		self._TargetPitch = 0.0
	end

	self._ReloadTimer = self._ReloadTimer + Registry.BOT.BOT_UPDATE_CYCLE

	if self._ReloadTimer > 1.5 and self._ReloadTimer < 2.5 and self.m_Player.soldier.weaponsComponent.currentWeapon.primaryAmmo <= self.m_ActiveWeapon.reload then
		self:_SetInput(EntryInputActionEnum.EIAReload, 1)
	end

	-- deploy from time to time
	if Config.BotsDeploy then
		if self.m_Kit == BotKits.Support or self.m_Kit == BotKits.Assault then
			if self.m_PrimaryGadget.type == WeaponTypes.Ammobag or self.m_PrimaryGadget.type == WeaponTypes.Medkit then
				self._DeployTimer = self._DeployTimer + Registry.BOT.BOT_UPDATE_CYCLE

				if self._DeployTimer > Config.DeployCycle then
					self._DeployTimer = 0.0
				end

				if self._DeployTimer < 0.7 then
					self._WeaponToUse = BotWeapons.Gadget1
				end
			end
		end
	end
end

function Bot:_UpdateAttacking()
	if self._ShootPlayer.soldier ~= nil and
	self._ActiveAction ~= BotActionFlags.EnterVehicleActive and
	self._ActiveAction ~= BotActionFlags.RepairActive and
	self._Shoot then
		if (self._ShootModeTimer < Config.BotFireModeDuration) or
			(Config.ZombieMode and self._ShootModeTimer < (Config.BotFireModeDuration * 4)) then

			if self._ActiveAction ~= BotActionFlags.C4Active then
				self:_SetInput(EntryInputActionEnum.EIAZoom, 1) -- does not work yet :-/
			end

			if self._ActiveAction ~= BotActionFlags.GrenadeActive then
				self._ShootModeTimer = self._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
			end

			self._ReloadTimer = 0.0 -- reset reloading

			--check for melee attack
			if Config.MeleeAttackIfClose and self._ActiveAction ~= BotActionFlags.MeleeActive and self._MeleeCooldownTimer <= 0.0 and self._ShootPlayer.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 2 then
				self._ActiveAction = BotActionFlags.MeleeActive
				self.m_ActiveWeapon = self.m_Knife

				self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
				self:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
				self:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
				self._MeleeCooldownTimer = Config.MeleeAttackCoolDown

				if not Registry.COMMON.USE_REAL_DAMAGE then
					Events:DispatchLocal("Server:DamagePlayer", self._ShootPlayer.name, self.m_Player.name, true)
				end
			else
				if self._MeleeCooldownTimer < 0.0 then
					self._MeleeCooldownTimer = 0.0
				elseif self._MeleeCooldownTimer > 0.0 then
					self._MeleeCooldownTimer = self._MeleeCooldownTimer - Registry.BOT.BOT_UPDATE_CYCLE
					self:_SetInput(EntryInputActionEnum.EIAFire, 1)
					if self._MeleeCooldownTimer < (Config.MeleeAttackCoolDown - 0.8) then
						self:_ResetActionFlag(BotActionFlags.MeleeActive)
					end
				end
			end

			if self._ActiveAction == BotActionFlags.GrenadeActive then -- throw grenade
				if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 0 then
					self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 1
					self:_ResetActionFlag(BotActionFlags.GrenadeActive)
					self._ShootModeTimer = self._ShootModeTimer + 2* Registry.BOT.BOT_UPDATE_CYCLE
				end
			end

			if self.m_ActiveWeapon.type == WeaponTypes.Rocket then
				if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 0 then
					self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 1
				end
			end

			if self._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
				local s_AttackMode = m_Vehicles:CheckForVehicleAttack(self._ShootPlayerVehicleType, self._DistanceToPlayer, self.m_SecondaryGadget, false)

				if s_AttackMode ~= VehicleAttackModes.NoAttack then
					if s_AttackMode == VehicleAttackModes.AttackWithNade then -- grenade
						self._ActiveAction = BotActionFlags.GrenadeActive
					elseif s_AttackMode == VehicleAttackModes.AttackWithRocket then -- rocket
						self._WeaponToUse = BotWeapons.Gadget2

						if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 2 then
							self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 3
						end
					elseif s_AttackMode == VehicleAttackModes.AttackWithC4 then -- C4
						self._WeaponToUse = BotWeapons.Gadget2
						self._ActiveAction = BotActionFlags.C4Active
					elseif s_AttackMode == VehicleAttackModes.AttackWithRifle then
						-- TODO: double code is not nice
						if self._ActiveAction ~= BotActionFlags.GrenadeActive and self.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
							if self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 then
								self._WeaponToUse = BotWeapons.Pistol
							else
								self._WeaponToUse = BotWeapons.Primary
							end
						end
					end
				else
					self._ShootModeTimer = Config.BotFireModeDuration -- end attack
				end
			else
				if self.m_KnifeMode or self._ActiveAction == BotActionFlags.MeleeActive then
					self._WeaponToUse = BotWeapons.Knife
				elseif Globals.IsGm then
					self._WeaponToUse = BotWeapons.Primary
				else
					if self._ActiveAction ~= BotActionFlags.GrenadeActive then
						-- check to use pistol
						if self.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
							if self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 and self._DistanceToPlayer <= Config.MaxShootDistancePistol then
								self._WeaponToUse = BotWeapons.Pistol
							else
								if self.m_ActiveWeapon ~= nil and self.m_ActiveWeapon.type ~= WeaponTypes.Rocket then

									self._WeaponToUse = BotWeapons.Primary
									-- check to use rocket
									if self._ShootModeTimer <= Registry.BOT.BOT_UPDATE_CYCLE + 0.001 and
									self.m_SecondaryGadget ~= nil and self.m_SecondaryGadget.type == WeaponTypes.Rocket and
									MathUtils:GetRandomInt(1, 100) <= Registry.BOT.PROBABILITY_SHOOT_ROCKET then
										self._WeaponToUse = BotWeapons.Gadget2
									end
								end
							end
						end

					end
					-- use grenade from time to time
					if Config.BotsThrowGrenades then
						local s_TargetTimeValue = Config.BotMinTimeShootAtPlayer - Registry.BOT.BOT_UPDATE_CYCLE

						if ((self._ShootModeTimer >= s_TargetTimeValue - 0.001) and
						(self._ShootModeTimer <= (s_TargetTimeValue + Registry.BOT.BOT_UPDATE_CYCLE + 0.001)) and
						self._ActiveAction ~= BotActionFlags.GrenadeActive) or Config.BotWeapon == BotWeapons.Grenade then
							-- should be triggered only once per fireMode
							if MathUtils:GetRandomInt(1,100) <= Registry.BOT.PROBABILITY_THROW_GRENADE then
								if self.m_Grenade ~= nil and self._DistanceToPlayer < 27.0 then -- algorith only works for up to 22 m
									self._ActiveAction = BotActionFlags.GrenadeActive
								end
							end
						end
					end
				end
			end

			--trace way back
			if (self.m_ActiveWeapon ~= nil and self.m_ActiveWeapon.type ~= WeaponTypes.Sniper and self.m_ActiveWeapon.type ~= WeaponTypes.Rocket) or self.m_KnifeMode then
				if self._ShootTraceTimer > Registry.BOT.TRACE_DELTA_SHOOTING then
					--create a Trace to find way back
					self._ShootTraceTimer = 0.0
					local s_Point = {
						Position = self.m_Player.soldier.worldTransform.trans:Clone(),
						SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
						ExtraMode = 0,
						OptValue = 0,
					}

					table.insert(self._ShootWayPoints, s_Point)

					if self.m_KnifeMode then
						local s_Trans = self._ShootPlayer.soldier.worldTransform.trans:Clone()
						table.insert(self._KnifeWayPositions, s_Trans)
					end
				end

				self._ShootTraceTimer = self._ShootTraceTimer + Registry.BOT.BOT_UPDATE_CYCLE
			end

			--shooting sequence
			if self.m_ActiveWeapon ~= nil then
				if self.m_KnifeMode then
					-- nothing to do
				-- C4 Handling
				elseif self._ActiveAction == BotActionFlags.C4Active then
					if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo > 0 then
						if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
							self._ShotTimer = 0.0
						end

						if self._DistanceToPlayer < 5.0 then
							if self._ShotTimer >= self.m_ActiveWeapon.pauseCycle then
								self:_SetInput(EntryInputActionEnum.EIAZoom, 1)
							end
						end
					else
						if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
							--TODO: run away from object now
							if self._ShotTimer >= ((self.m_ActiveWeapon.fireCycle * 2) + self.m_ActiveWeapon.pauseCycle) then
								self:_SetInput(EntryInputActionEnum.EIAFire, 1)
								self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 4
								self:_ResetActionFlag(BotActionFlags.C4Active)
							end
						end
					end
				else
					if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
						self._ShotTimer = 0.0
					end

					if self._ShotTimer >= 0.0 and self._ActiveAction ~= BotActionFlags.MeleeActive then
						if self.m_ActiveWeapon.delayed == false then
							if self._ShotTimer <= self.m_ActiveWeapon.fireCycle then
								self:_SetInput(EntryInputActionEnum.EIAFire, 1)
							end
						else --start with pause Cycle
							if self._ShotTimer >= self.m_ActiveWeapon.pauseCycle then
								self:_SetInput(EntryInputActionEnum.EIAFire, 1)
							end
						end
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
	elseif self._ActiveAction == BotActionFlags.ReviveActive then
		if self._ShootPlayer.corpse ~= nil then -- revive
			self._ShootModeTimer = self._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
			self.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : revive
			self._ReloadTimer = 0.0 -- reset reloading

			--check for revive if close
			if self._ShootPlayer.corpse.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 3 then
				self:_SetInput(EntryInputActionEnum.EIAFire, 1)
			end

			--trace way back
			if self._ShootTraceTimer > Registry.BOT.TRACE_DELTA_SHOOTING then
				--create a Trace to find way back
				self._ShootTraceTimer = 0.0
				local s_Point = {
					Position = self.m_Player.soldier.worldTransform.trans:Clone(),
					SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
					ExtraMode = 0,
					OptValue = 0,
				}

				table.insert(self._ShootWayPoints, s_Point)
				if self.m_KnifeMode then
					local s_Trans = self._ShootPlayer.soldier.worldTransform.trans:Clone()
					table.insert(self._KnifeWayPositions, s_Trans)
				end
			end

			self._ShootTraceTimer = self._ShootTraceTimer + Registry.BOT.BOT_UPDATE_CYCLE
		else
			self._WeaponToUse = BotWeapons.Primary
			self._TargetPitch = 0.0
			self:_AbortAttack()
			self:_ResetActionFlag(BotActionFlags.ReviveActive)
		end
	-- enter vehicle
	elseif self._ActiveAction == BotActionFlags.EnterVehicleActive and self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil then
		self._ShootModeTimer = self._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
		self.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : revive

		--check for enter of vehicle if close
		if self._ShootPlayer.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 5 then
			self:_EnterVehicle(true)
			self._TargetPitch = 0.0
			self:_AbortAttack()
			self:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
		end
		if self._ShootModeTimer > 12.0 then -- abort this after some time
			self._TargetPitch = 0.0
			self:_AbortAttack()
			self:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
		end
	-- repair
	elseif self._ActiveAction == BotActionFlags.RepairActive and self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil and self._RepairVehicleEntity ~= nil then
		self._ShootModeTimer = self._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
		self.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : repair

		local s_CurrentHealth = PhysicsEntity(self._RepairVehicleEntity).internalHealth

		--check for repair if close to vehicle
		if self._RepairVehicleEntity.transform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 5 then
			if s_CurrentHealth ~= self._LastVehicleHealth then
				self._ShootModeTimer = Registry.BOT.MAX_TIME_TRY_REPAIR - 2.0 -- continue for few seconds on progress
			end
			self._LastVehicleHealth = s_CurrentHealth
			self._TargetPitch = 0.0
			self._AttackModeMoveTimer = 0.0 -- don't jump anymore
			self:_SetInput(EntryInputActionEnum.EIAFire, 1)
		end

		-- Abort conditions
		if self._ShootModeTimer > Registry.BOT.MAX_TIME_TRY_REPAIR or self._RepairVehicleEntity == nil then -- abort this after some time
			self._TargetPitch = 0.0
			self:_AbortAttack()
			self:_ResetActionFlag(BotActionFlags.RepairActive)
			self._WeaponToUse = BotWeapons.Primary
		end

	elseif self._ShootPlayer.soldier == nil then -- reset if enemy is dead
		self:_AbortAttack()
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
	local s_Node = g_GameDirector:FindClosestPath(p_Position, true)
	if s_Node ~= nil then
		-- switch to vehicle
		self._InvertPathDirection = false
		self._PathIndex = s_Node.PathIndex
		self._CurrentWayPoint = s_Node.PointIndex
		self._LastWayDistance = 1000.0
	end
end

function Bot:_UpdateVehicleMovableId()
	self._VehicleMovableId = m_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, self.m_Player.controlledEntryId)
	if self.m_Player.controlledEntryId == 0 then
		self:FindVehiclePath(self.m_Player.soldier.worldTransform.trans)
	end
end

---@param p_Entity ControllableEntity
---@param p_PlayerIsDriver boolean
---@return integer
---@return Vec3|nil
function Bot:_EnterVehicleEntity(p_Entity, p_PlayerIsDriver)
	if p_Entity ~= nil then
		local s_Position = p_Entity.transform.trans

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
				self.m_ActiveVehicle = m_Vehicles:GetVehicle(self.m_Player, i)
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

function Bot:_UpdateStaticMovement()
	-- mimicking
	if self.m_ActiveMoveMode == BotMoveModes.Mimic and self._TargetPlayer ~= nil then
		---@type EntryInputActionEnum|integer
		for i = 0, 36 do
			self:_SetInput(i, self._TargetPlayer.input:GetLevel(i))
		end

		self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw
		self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch

	-- mirroring
	elseif self.m_ActiveMoveMode == BotMoveModes.Mirror and self._TargetPlayer ~= nil then
		---@type EntryInputActionEnum|integer
		for i = 0, 36 do
			self:_SetInput(i, self._TargetPlayer.input:GetLevel(i))
		end

		self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw + ((self._TargetPlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
		self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch
	end
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
				s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(self.m_Name, s_Point, self._Objective, self.m_InVehicle, self.m_Player.teamId)

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

function Bot:_UpdateNormalMovement()
	-- move along points
	self._AttackModeMoveTimer = 0.0

	if m_NodeCollection:Get(1, self._PathIndex) ~= nil then -- check for valid point
		-- get next point
		local s_ActivePointIndex = self:_GetWayIndex(self._CurrentWayPoint)

		local s_Point = nil
		local s_NextPoint = nil
		local s_PointIncrement = 1
		local s_NoStuckReset = false
		local s_UseShootWayPoint = false

		if #self._ShootWayPoints > 0 then --we need to go back to path first
			s_Point = self._ShootWayPoints[#self._ShootWayPoints]
			s_NextPoint = self._ShootWayPoints[#self._ShootWayPoints - 1]

			if s_NextPoint == nil then
				s_NextPoint = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)

				--[[if Config.DebugTracePaths then
					NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, s_ActivePointIndex, self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0.0), "Blue")
				end--]]
			end

			s_UseShootWayPoint = true
		else
			s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)

			if not self._InvertPathDirection then
				s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 1), self._PathIndex)

				--[[if Config.DebugTracePaths then
					NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, self:_GetWayIndex(self._CurrentWayPoint + 1), self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0.0), "Green")
				end--]]
			else
				s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint - 1), self._PathIndex)

				--[[if Config.DebugTracePaths then
					NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, self:_GetWayIndex(self._CurrentWayPoint - 1), self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0.0), "Green")
				end--]]
			end
		end

		-- execute Action if needed
		if self._ActiveAction == BotActionFlags.OtherActionActive then
			if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
				if s_Point.Data.Action.type == "vehicle" then
					if Config.UseVehicles then
						local s_RetCode, s_Position = self:_EnterVehicle(false)
						if s_RetCode == 0 then
							self:_ResetActionFlag(BotActionFlags.OtherActionActive)
							local s_Node = g_GameDirector:FindClosestPath(s_Position, true)

							if s_Node ~= nil then
								-- switch to vehicle
								s_Point = s_Node
								self._InvertPathDirection = false
								self._PathIndex = s_Node.PathIndex
								self._CurrentWayPoint = s_Node.PointIndex
								s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 1), self._PathIndex)
								self._LastWayDistance = 1000.0
							end
						end
					end
					self:_ResetActionFlag(BotActionFlags.OtherActionActive)
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

			if Config.ZombieMode then
				if self._ZombieSpeedValue == BotMoveSpeeds.NoMovement then
					if MathUtils:GetRandomInt(0,1) == 1 then
						self._ZombieSpeedValue = BotMoveSpeeds.SlowCrouch
					else
						self._ZombieSpeedValue = BotMoveSpeeds.VerySlowProne
					end
				end

				self.m_ActiveSpeedValue = self._ZombieSpeedValue
			end

			if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement and not self.m_InVehicle then
				self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
			end

			-- sidwareds movement
			if Config.MoveSidewards then
				if self._SidewardsTimer <= 0.0 then
					if self.m_StrafeValue ~= 0.0 then
						self._SidewardsTimer = MathUtils:GetRandom(Config.MinMoveCycle, Config.MaxStraigtCycle)
						self.m_StrafeValue = 0.0
						self.m_YawOffset = 0.0
					else
						self._SidewardsTimer = MathUtils:GetRandom(Config.MinMoveCycle, Config.MaxSideCycle)
						if MathUtils:GetRandomInt(0, 1) > 0 then-- random direction
							self.m_StrafeValue = 1.0
						else
							self.m_StrafeValue = -1.0
						end
						if self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
							self.m_YawOffset = 0.3927 * -self.m_StrafeValue
						else
							self.m_YawOffset = 0.7854 * -self.m_StrafeValue
						end
					end
				end
				self:_SetInput(EntryInputActionEnum.EIAStrafe, self.m_StrafeValue)
				self._SidewardsTimer = self._SidewardsTimer - Registry.BOT.BOT_UPDATE_CYCLE
			end

			-- use parachute if needed
			local s_VelocityFalling = PhysicsEntity(self.m_Player.soldier).velocity.y
			if s_VelocityFalling < -50.0 then
				self:_SetInput(EntryInputActionEnum.EIAToggleParachute, 1)
			end

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
				self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint --always try to stand

				if self._ObstaceSequenceTimer == 0.0 then --step 0
				elseif self._ObstaceSequenceTimer > 2.4 then --step 4 - repeat afterwards
					self._ObstaceSequenceTimer = 0.0
					self:_ResetActionFlag(BotActionFlags.MeleeActive)
					self._ObstacleRetryCounter = self._ObstacleRetryCounter + 1
				elseif self._ObstaceSequenceTimer > 1.0 then --step 3
					if not self.m_InVehicle then
						if self._ObstacleRetryCounter == 0 then
							if self._ActiveAction ~= BotActionFlags.MeleeActive then
								self._ActiveAction = BotActionFlags.MeleeActive
								self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
								self:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
								self:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
								self.m_ActiveWeapon = self.m_Knife
							else
								self:_SetInput(EntryInputActionEnum.EIAFire, 1)
							end
						else
							self:_SetInput(EntryInputActionEnum.EIAFire, 1)
						end
					end
				elseif self._ObstaceSequenceTimer > 0.4 then --step 2
					self._TargetPitch = 0.0

					if (MathUtils:GetRandomInt(0,1) == 1) then
						self:_SetInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
					else
						self:_SetInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
					end
				elseif self._ObstaceSequenceTimer > 0.0 then --step 1
					self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					self:_SetInput(EntryInputActionEnum.EIAJump, 1)
				end

				self._ObstaceSequenceTimer = self._ObstaceSequenceTimer + Registry.BOT.BOT_UPDATE_CYCLE
				self._StuckTimer = self._StuckTimer + Registry.BOT.BOT_UPDATE_CYCLE

				if self._ObstacleRetryCounter >= 2 then --try next waypoint
					self._ObstacleRetryCounter = 0
					self:_ResetActionFlag(BotActionFlags.MeleeActive)
					s_DistanceFromTarget = 0
					s_HeightDistance = 0

					-- teleport to target
					s_NoStuckReset = true
					if Config.TeleportIfStuck and (MathUtils:GetRandomInt(0,100) <= Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK) then
						local s_Transform = self.m_Player.soldier.worldTransform:Clone()
						s_Transform.trans = self._TargetPoint.Position
						s_Transform:LookAtTransform(self._TargetPoint.Position, self._NextTargetPoint.Position)
						self.m_Player.soldier:SetTransform(s_Transform)
						m_Logger:Write("tepeported "..self.m_Player.name)
					else
						if not self.m_InVehicle then
							s_PointIncrement = MathUtils:GetRandomInt(-5,5) -- go 5 points further
							-- experimental
							if s_PointIncrement == 0 then -- we can't have this
								s_PointIncrement = -2 --go backwards and try again
							end

							if (Globals.IsConquest or Globals.IsRush) then
								if g_GameDirector:IsOnObjectivePath(self._PathIndex) then
									self._InvertPathDirection = (MathUtils:GetRandomInt(0,100) <= Registry.BOT.PROBABILITY_CHANGE_DIRECTION_IF_STUCK)
								end
							end
						end
					end
				end

				if self._StuckTimer > 15.0 then
					self.m_Player.soldier:Kill()

					m_Logger:Write(self.m_Player.name.." got stuck. Kill")

					return
				end
			else
				self:_ResetActionFlag(BotActionFlags.MeleeActive)
			end

			self._LastWayDistance = s_CurrentWayPointDistance

			-- jump detection. Much more simple now, but works fine -)
			if self._ObstaceSequenceTimer == 0.0 then
				if (s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y) > 0.3 and Config.JumpWhileMoving then
					--detect, if a jump was recorded or not
					local s_TimeForwardBackwardJumpDetection = 1.1 -- 1.5 s ahead and back
					local s_JumpValid = false

					for i = 1, math.floor(s_TimeForwardBackwardJumpDetection / Config.TraceDelta) do
						local s_PointBefore = m_NodeCollection:Get(s_ActivePointIndex - i, self._PathIndex)
						local s_PointAfter = m_NodeCollection:Get(s_ActivePointIndex + i, self._PathIndex)

						if (s_PointBefore ~= nil and s_PointBefore.ExtraMode == 1) or (s_PointAfter ~= nil and s_PointAfter.ExtraMode == 1) then
							s_JumpValid = true
							break
						end
					end

					if s_JumpValid then
						self:_SetInput(EntryInputActionEnum.EIAJump, 1)
						self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					end
				end
			end

			local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint

			if self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 1.5
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.7
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.5
			end

			--check for reached target
			if s_DistanceFromTarget <= s_TargetDistanceSpeed and s_HeightDistance <= Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT then
				if not s_NoStuckReset then
					self._StuckTimer = 0.0
				end

				if not s_UseShootWayPoint then
					-- CHECK FOR ACTION
					if s_Point.Data.Action ~= nil then
						local s_Action = s_Point.Data.Action

						if g_GameDirector:CheckForExecution(s_Point, self.m_Player.teamId, false) then
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
					s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(self.m_Name, s_Point, self._Objective, self.m_InVehicle, self.m_Player.teamId)

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
				else
					for i = 1, s_PointIncrement do --one already gets removed on start of wayfinding
						table.remove(self._ShootWayPoints)
					end
				end

				self._ObstaceSequenceTimer = 0.0
				self:_ResetActionFlag(BotActionFlags.MeleeActive)
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

function Bot:_UpdateShootMovement()
	-- Shoot MoveMode
	if self._AttackMode == BotAttackModes.RandomNotSet then
		if Config.BotAttackMode ~= BotAttackModes.RandomNotSet then
			self._AttackMode = Config.BotAttackMode
		else -- random
			if MathUtils:GetRandomInt(0, 1) == 1 then
				self._AttackMode = BotAttackModes.Stand
			else
				self._AttackMode = BotAttackModes.Crouch
			end
		end
	end

	--crouch moving (only mode with modified gun)
	if ((self.m_ActiveWeapon.type == WeaponTypes.Sniper or self.m_ActiveWeapon.type == WeaponTypes.Rocket) and not self.m_KnifeMode) then --don't move while shooting in a vehicle
		if self._AttackMode == BotAttackModes.Crouch then
			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		else
			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		end

		self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	else
		local s_TargetTime = 5.0
		local s_TargetCycles = math.floor(s_TargetTime / Registry.BOT.TRACE_DELTA_SHOOTING)

		if self.m_KnifeMode then --Knife Only Mode
			s_TargetCycles = 1
			self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint --run towards player
		else
			if self._AttackMode == BotAttackModes.Crouch then
				self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			else
				self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
			end
		end

		if Config.OverWriteBotAttackMode ~= BotMoveSpeeds.NoMovement then
			self.m_ActiveSpeedValue = Config.OverWriteBotAttackMode
		end

		if #self._ShootWayPoints > s_TargetCycles and Config.JumpWhileShooting then
			local s_DistanceDone = self._ShootWayPoints[#self._ShootWayPoints].Position:Distance(self._ShootWayPoints[#self._ShootWayPoints-s_TargetCycles].Position)
			if s_DistanceDone < 0.5 then --no movement was possible. Try to jump over obstacle
				self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
				self:_SetInput(EntryInputActionEnum.EIAJump, 1)
				self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
			end
		end

		-- do some sidwards movement from time to time
		if self._AttackModeMoveTimer > 20.0 then
			self._AttackModeMoveTimer = 0.0
		elseif self._AttackModeMoveTimer > 17.0 then
			self:_SetInput(EntryInputActionEnum.EIAStrafe, -0.5 * Config.SpeedFactorAttack)
		elseif self._AttackModeMoveTimer > 12.0 and self._AttackModeMoveTimer <= 13.0 then
			self:_SetInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
		elseif self._AttackModeMoveTimer > 7.0 and self._AttackModeMoveTimer <= 9.0 then
			self:_SetInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
		end

		self._AttackModeMoveTimer = self._AttackModeMoveTimer + Registry.BOT.BOT_UPDATE_CYCLE
	end
end

function Bot:_UpdateMovementSprintToTarget()
	self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint --run to target

	if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
		self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
	end

	local s_Jump = true

	if self._ShootPlayer ~= nil and self._ShootPlayer.corpse ~= nil then
		if self.m_Player.soldier.worldTransform.trans:Distance(self._ShootPlayer.corpse.worldTransform.trans) < 2 then
			self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			s_Jump = false
		end
	end

	--TODO: obstacle detection
	if s_Jump == true then
		self._AttackModeMoveTimer = self._AttackModeMoveTimer + Registry.BOT.BOT_UPDATE_CYCLE

		if self._AttackModeMoveTimer > 3.0 then
			self._AttackModeMoveTimer = 0.0
		elseif self._AttackModeMoveTimer > 2.5 then
			self:_SetInput(EntryInputActionEnum.EIAJump, 1)
			self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
		end
	end
end

function Bot:_UpdateSpeedOfMovementVehicle()
	if self.m_Player.soldier == nil or self._VehicleWaitTimer > 0.0 then
		return
	end

	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
		-- This is solved this in the yaw-function
		if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
			self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
		end
	else
		-- additional movement
		local s_SpeedVal = 0

		if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
			self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
		end

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

function Bot:_UpdateSpeedOfMovement()
	-- additional movement
	if self.m_Player.soldier == nil then
		return
	end

	if self._ActiveAction == BotActionFlags.OtherActionActive then
		return
	end

	local s_SpeedVal = 0

	if self.m_ActiveMoveMode ~= BotMoveModes.Standstill then
		if self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
			s_SpeedVal = 1.0

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
			end
		elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
			s_SpeedVal = 1.0

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		elseif self.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
			s_SpeedVal = 1.0

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		end
	end

	-- do not reduce speed if sprinting
	if s_SpeedVal > 0 and self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil and self.m_ActiveSpeedValue <= BotMoveSpeeds.Normal then
		s_SpeedVal = s_SpeedVal * Config.SpeedFactorAttack
	end

	-- movent speed
	if self.m_ActiveSpeedValue ~= BotMoveSpeeds.Sprint then
		self:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal * Config.SpeedFactor)
	else
		self:_SetInput(EntryInputActionEnum.EIAThrottle, 1)
		self:_SetInput(EntryInputActionEnum.EIASprint, s_SpeedVal * Config.SpeedFactor)
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
	else
		self.m_InVehicle = false
	end

	if Config.BotWeapon == BotWeapons.Knife or Config.ZombieMode then
		self.m_KnifeMode = true
	else
		self.m_KnifeMode = false
	end
end

return Bot
