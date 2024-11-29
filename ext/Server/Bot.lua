---@class Bot
---@overload fun(p_Player: Player):Bot
Bot = class('Bot')

require('BotUpdate.lua')
require('__shared/Config')
require('PidController')

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

---@param p_Player Player
function Bot:__init(p_Player)
	-- Player Object.
	---@type Player
	self.m_Player = p_Player
	---@type string
	self.m_Name = p_Player.name
	---@type integer
	self.m_Id = p_Player.id

	-- create some character proporties
	---@type BotBehavior
	self.m_Behavior = nil
	self.m_Reaction = 0.0
	self.m_Accuracy = 0.0
	self.m_Skill = 0.0
	self.m_PrefWeapon = ""
	self.m_PrefVehicle = ""

	-- Common settings.
	---@type BotSpawnModes
	self._SpawnMode = BotSpawnModes.NoRespawn
	---@type BotMoveModes
	self._MoveMode = BotMoveModes.Standstill
	self._ForcedMovement = false
	---@type BotKits|integer
	self.m_Kit = nil
	-- Only used in BotSpawner.
	---@type BotColors|integer
	self.m_Color = nil
	---@type Weapon|nil
	self.m_ActiveWeapon = nil
	self.m_ActiveVehicle = nil
	self.m_ActiveGmWeaponName = nil
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
	self.m_HasBeacon = false
	self.m_DontRevive = false
	self.m_AttackPriority = 1

	-- Timers.
	self._UpdateTimer = 0.0
	self._UpdateFastTimer = 0.0
	self._SpawnDelayTimer = 0.0
	self._WayWaitTimer = 0.0
	self._VehicleWaitTimer = 0.0
	self._VehicleHealthTimer = 0.0
	self._VehicleSeatTimer = 0.0
	self._VehicleTakeoffTimer = 0.0
	self._WayWaitYawTimer = 0.0
	self._ObstacleSequenceTimer = 0.0
	self._StuckTimer = 0.0
	self._ShotTimer = 0.0
	self._SoundTimer = 30.0
	self._VehicleSecondaryWeaponTimer = 0.0
	self._ShootModeTimer = 0.0
	self._ReloadTimer = 0.0
	self._DeployTimer = 0.0
	self._AttackModeMoveTimer = 0.0
	self._MeleeCooldownTimer = 0.0
	self._ShootTraceTimer = 0.0
	self._ActionTimer = 0.0
	self._BrakeTimer = 0.0
	self._SpawnProtectionTimer = 0.0
	self._DefendTimer = 0.0
	self._SidewardsTimer = 0.0
	self._KillYourselfTimer = 0.0

	-- Shared movement vars.
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
	self.m_DelayedInputs = {}

	-- Sidewards movement.
	self.m_YawOffset = 0.0
	self.m_StrafeValue = 0.0

	-- Advanced movement.
	---@type BotAttackModes
	self._AttackMode = BotAttackModes.RandomNotSet
	---@type BotActionFlags
	self._ActiveAction = BotActionFlags.NoActionActive
	---@type Waypoint|nil
	self._CurrentWayPoint = nil
	self._TargetYaw = 0.0
	self._TargetYawMovementVehicle = 0.0
	self._TargetPitch = 0.0
	---@type Waypoint|nil
	self._TargetPoint = nil
	---@type Waypoint|nil
	self._NextTargetPoint = nil
	self._PathIndex = 0
	self._LastWayDistance = 0.0
	self._InvertPathDirection = false
	self._ExitVehicleActive = false
	self._ObstacleRetryCounter = 0
	self._Objective = ''
	self._ObjectiveMode = BotObjectiveModes.Default
	self._OnSwitch = false
	self._ActiveDelay = 0.0

	-- Vehicle stuff.
	---@type integer|nil
	self._VehicleMovableId = -1
	self._LastVehicleYaw = 0.0
	self._VehicleReadyToShoot = false
	self._FullVehicleSteering = false
	self._VehicleDirBackPositive = false
	self._JetAbortAttackActive = false
	self._ExitVehicleHealth = 0.0
	self._LastVehicleHealth = 0.0
	self._TargetHeightAttack = 0.0
	self._VehicleWeaponSlotToUse = 1
	self._ActiveVehicleWeaponSlot = 0
	---@type ControllableEntity|nil
	self._RepairVehicleEntity = nil
	-- PID Controllers.
	-- Normal driving.
	---@type PidController
	self._Pid_Drv_Yaw = PidController(5, 0.05, 0.2, 1.0)
	-- Chopper / Plane
	---@type PidController
	self._Pid_Drv_Throttle = PidController(3, 0.05, 0.2, 1.0)
	---@type PidController
	self._Pid_Drv_Tilt = PidController(6, 0.1, 0.2, 1.0)
	---@type PidController
	self._Pid_Drv_Roll = PidController(6, 0.1, 0.2, 1.0)
	-- Guns.
	---@type PidController
	self._Pid_Att_Yaw = PidController(10, 2.0, 2.0, 1.0)
	---@type PidController
	self._Pid_Att_Pitch = PidController(10, 2.0, 2.0, 1.0)

	-- Shooting.
	self._Shoot = false
	---@type Player|nil
	self._ShootPlayer = nil
	self._ActiveShootDuration = 0.0
	self._DoneShootDuration = 0.0
	self._DontAttackPlayers = false
	---@type VehicleTypes
	self._ShootPlayerVehicleType = VehicleTypes.NoVehicle
	self._ShootPlayerName = ''
	self._DistanceToPlayer = 0.0
	---@type BotWeapons
	self._WeaponToUse = BotWeapons.Primary
	-- To-do: add emmylua type.
	self._ShootWayPoints = {}
	---@type Vec3[]
	self._KnifeWayPositions = {}
	self._Accuracy = 0.0
	self._AccuracySniper = 0.0
	self._SkillFound = false

	---@type Player|nil
	self._TargetPlayer = nil
end

-- =============================================
-- Events
-- =============================================

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================

---@param p_Player Player
function Bot:Revive(p_Player)
	if self.m_Kit == BotKits.Assault and
		p_Player.corpse and
		not p_Player.corpse.isDead and
		not Globals.IsGm and
		not Globals.IsScavenger and
		self.m_Player.soldier ~= nil and
		self.m_Player.soldier.weaponsComponent.weapons[6] and
		string.find(self.m_Player.soldier.weaponsComponent.weapons[6].name, "Defibrillator") then
		if Config.BotsRevive then
			self._ActiveAction = BotActionFlags.ReviveActive
			self._ShootPlayer = nil
			self._ShootPlayerName = p_Player.name
		end
	end
end

---@param p_TimeDelay number
function Bot:FireFlareSmoke(p_TimeDelay)
	self:_SetDelayedInput(EntryInputActionEnum.EIAFireCountermeasure, 1, p_TimeDelay)
end

---@param p_Player Player
function Bot:Repair(p_Player)
	if self.m_Kit == BotKits.Engineer and p_Player.soldier ~= nil and p_Player.controlledControllable ~= nil then
		self._ActiveAction = BotActionFlags.RepairActive
		self._RepairVehicleEntity = p_Player.controlledControllable
		self._LastVehicleHealth = 0.0
		self._ShootPlayer = nil
		self._ShootPlayerName = p_Player.name
		self._ShootModeTimer = Registry.BOT.MAX_TIME_TRY_REPAIR
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
	self._ShootModeTimer = 12.0
end

function Bot:UpdateObjective(p_Objective, p_ObjectiveMode)
	local s_AllObjectives = m_NodeCollection:GetKnownObjectives()

	for l_Objective, _ in pairs(s_AllObjectives) do
		if l_Objective == p_Objective then
			self:SetObjective(p_Objective, p_ObjectiveMode)
			break
		end
	end
end

function Bot:DeployIfPossible()
	-- Deploy from time to time.
	if self.m_PrimaryGadget ~= nil and (self.m_Kit == BotKits.Support or self.m_Kit == BotKits.Assault) and not Globals.IsGm then
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
			-- Switch to foot.
			self._InvertPathDirection = false
			self._PathIndex = s_Node.PathIndex
			self._CurrentWayPoint = s_Node.PointIndex
			self._LastWayDistance = 1000.0
		end
		self._KillYourselfTimer = 0.0
		self._ExitVehicleActive = false
		self._DontAttackPlayers = false
		return true
	end

	return false
end

function Bot:ExitVehicle()
	self._ExitVehicleActive = true
end

---@param p_ShootBackAfterHit boolean
---@param p_Player Player | nil
---@param p_CheckShootTimer boolean
---@return boolean
function Bot:IsReadyToAttack(p_ShootBackAfterHit, p_Player, p_CheckShootTimer)
	-- update timers first
	if self._ShootPlayerName == '' then
		self._DoneShootDuration = 0.0
	elseif p_Player and self._ShootPlayerName == p_Player.name then
		self._DoneShootDuration = self._DoneShootDuration + (self._ActiveShootDuration - self._ShootModeTimer)
	end

	if self._ActiveAction == BotActionFlags.OtherActionActive or
		(self._ActiveAction == BotActionFlags.ReviveActive and not p_ShootBackAfterHit) or
		self._ActiveAction == BotActionFlags.RepairActive or
		self._ActiveAction == BotActionFlags.EnterVehicleActive or
		self._ActiveAction == BotActionFlags.GrenadeActive or
		self._DontAttackPlayers then
		return false
	end

	if not p_CheckShootTimer then
		return true
	end

	if self._ShootPlayerName == '' or
		(p_Player and p_Player.name == self._ShootPlayerName) or -- if still the same enemy, you can trigger directly again
		(self.m_InVehicle and (self._DoneShootDuration > Config.BotVehicleMinTimeShootAtPlayer)) or
		(not self.m_InVehicle and (self._DoneShootDuration > Config.BotMinTimeShootAtPlayer)) or
		(self.m_KnifeMode and self._ShootModeTimer > ((Config.BotMinTimeShootAtPlayer * 0.5))) then
		return true
	else
		return false
	end
end

---@param p_EnemyVehicleType VehicleTypes
---@return integer
function Bot:GetAttackPriority(p_EnemyVehicleType)
	local s_BotVehicleType = m_Vehicles:VehicleType(self.m_ActiveVehicle)

	if self.m_SecondaryGadget ~= nil then
		if self.m_SecondaryGadget.type == WeaponTypes.MissileAir
			and m_Vehicles:IsAirVehicleType(p_EnemyVehicleType)
		then
			return 2
		elseif self.m_SecondaryGadget.type == WeaponTypes.MissileLand
			and m_Vehicles:IsArmoredVehicleType(p_EnemyVehicleType)
		then
			return 2
		end
	end

	if m_Vehicles:IsAirVehicleType(s_BotVehicleType) then
		if m_Vehicles:IsAirVehicleType(p_EnemyVehicleType) then
			return 3
		elseif m_Vehicles:IsArmoredVehicleType(p_EnemyVehicleType) then
			return 2
		end
	end

	if m_Vehicles:IsArmoredVehicleType(s_BotVehicleType)
		and m_Vehicles:IsArmoredVehicleType(p_EnemyVehicleType)
	then
		return 2
	end

	return 1
end

---@return number
function Bot:GetAttackDistance(p_ShootBackAfterHit, p_VehicleAttackMode)
	local s_AttackDistance = 0.0

	if not self.m_InVehicle then
		local s_MissileAttack = false
		if p_VehicleAttackMode and (p_VehicleAttackMode == VehicleAttackModes.AttackWithMissileAir) then
			s_MissileAttack = true
		end
		if (self.m_ActiveWeapon and self.m_ActiveWeapon.type == WeaponTypes.Sniper) or s_MissileAttack then
			if p_ShootBackAfterHit then
				s_AttackDistance = Config.MaxDistanceShootBackSniper
			else
				s_AttackDistance = Config.MaxShootDistanceSniper
			end
		else
			if p_ShootBackAfterHit then
				s_AttackDistance = Config.MaxDistanceShootBack
			else
				s_AttackDistance = Config.MaxShootDistance
			end
		end
	else
		if not m_Vehicles:IsAirVehicle(self.m_ActiveVehicle)
			and m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.MobileArtillery)
			and not m_Vehicles:IsAAVehicle(self.m_ActiveVehicle)
		then
			if p_ShootBackAfterHit then
				s_AttackDistance = Config.MaxShootDistanceNoAntiAir * 2
			else
				s_AttackDistance = Config.MaxShootDistanceNoAntiAir
			end
		else
			if p_ShootBackAfterHit then
				s_AttackDistance = Config.MaxShootDistanceVehicles * 2
			else
				s_AttackDistance = Config.MaxShootDistanceVehicles
			end
		end
	end

	return s_AttackDistance
end

function Bot:UpdateDontAttackFlag()
	-- Don't attack as driver in some vehicles.
	if self.m_InVehicle and self.m_Player.controlledEntryId == 0 then
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) then
			if self._VehicleMovableId == -1 then
				self._DontAttackPlayers = true                                                                     -- Tranotort-choppers don't attack as driver.
				return
			elseif self.m_Player.controlledControllable:GetPlayerInEntry(1) ~= nil and not Config.ChopperDriversAttack then -- Don't attack if gunner available and config is false.
				self._DontAttackPlayers = true
				return
			end
		end

		-- If jet targets get assigned in another way.
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
			self._DontAttackPlayers = true
			return
		end

		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.NoArmorVehicle) then
			self._DontAttackPlayers = true
			return
		end

		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.LightVehicle) then
			self._DontAttackPlayers = true
			return
		end

		-- If stationary AA targets get assigned in another way.
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
			self._DontAttackPlayers = true
			return
		end
	end
	self._DontAttackPlayers = false
end

---@param p_Player Player
---@param p_IgnoreYaw boolean
---@return boolean
function Bot:ShootAt(p_Player, p_IgnoreYaw)
	if p_IgnoreYaw and self._DefendTimer == 0.0 then -- was hit, not in defend-mode, check for special behavior
		if self.m_Behavior == BotBehavior.DontShootBackHide then
			self._ActionTimer = 7.0
			self._ActiveAction = BotActionFlags.HideOnAttack
			return false
		elseif self.m_Behavior == BotBehavior.DontShootBackBail then
			self._ActionTimer = 5.0
			self._ActiveAction = BotActionFlags.RunAway
			return false
		end
	end

	-- Don't shoot at teammates.
	if self.m_Player.teamId == p_Player.teamId then
		return false
	end

	if p_Player.soldier == nil or self.m_Player.soldier == nil then
		return false
	end

	-- Check for vehicles.
	local s_Type = m_Vehicles:FindOutVehicleType(p_Player)

	-- Don't shoot at stationary AA.
	if s_Type == VehicleTypes.StationaryAA then
		return false
	end

	local s_NewAttackPriority = self:GetAttackPriority(s_Type)

	local s_Ready = (s_NewAttackPriority > self.m_AttackPriority) or self:IsReadyToAttack(p_IgnoreYaw, p_Player, true)
	if not s_Ready or self._Shoot == false then
		return false
	end

	-- Don't shoot if too far away.
	self._DistanceToPlayer = 0.0
	local s_PlayerPos = nil
	local s_TargetPos = nil
	if s_Type == VehicleTypes.MavBot or s_Type == VehicleTypes.MobileArtillery then
		s_TargetPos = p_Player.controlledControllable.transform.trans:Clone()
	else
		s_TargetPos = p_Player.soldier.worldTransform.trans:Clone()
	end

	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.MobileArtillery) then
		s_PlayerPos = self.m_Player.controlledControllable.transform.trans:Clone()
	else
		s_PlayerPos = self.m_Player.soldier.worldTransform.trans:Clone()
	end

	self._DistanceToPlayer = s_TargetPos:Distance(s_PlayerPos)

	local s_IsSniper = false
	if (self.m_ActiveWeapon and self.m_ActiveWeapon.type == WeaponTypes.Sniper) then
		s_IsSniper = true
	end
	local s_VehicleAttackMode = nil
	if s_Type ~= VehicleTypes.NoVehicle then
		s_VehicleAttackMode = m_Vehicles:CheckForVehicleAttack(s_Type, self._DistanceToPlayer, self.m_SecondaryGadget,
			self.m_InVehicle, s_IsSniper)
		if s_VehicleAttackMode == VehicleAttackModes.NoAttack then
			return false
		end
	end

	local s_AttackDistance = self:GetAttackDistance(p_IgnoreYaw, s_VehicleAttackMode)

	-- Don't attack if too far away.
	if self._DistanceToPlayer > s_AttackDistance then
		return false
	end

	self._ShootPlayerVehicleType = s_Type

	local s_DifferenceYaw = 0
	local s_Pitch = 0
	local s_FovHalf = 0
	local s_PitchHalf = 0

	if self.m_InVehicle and m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.LightAA) and not m_Vehicles:IsAirVehicleType(s_Type) then
		return false
	end

	-- If target is air-vehicle and bot is in AA → ignore yaw.
	if m_Vehicles:IsAirVehicleType(s_Type) then
		if (self.m_InVehicle and m_Vehicles:IsAAVehicle(self.m_ActiveVehicle)) or
			(s_VehicleAttackMode == VehicleAttackModes.AttackWithMissileAir) then
			p_IgnoreYaw = true
		end
	end

	local s_Bot = g_BotManager:GetBotByName(p_Player.name)

	local s_SoundDistance = 100
	if s_Type == VehicleTypes.NoVehicle then
		s_SoundDistance = 50
	end

	if s_Bot ~= nil
		and s_Bot._SoundTimer <= 5.0
		and self._DistanceToPlayer < s_SoundDistance
	then
		p_IgnoreYaw = true
	end

	if not p_IgnoreYaw then
		local s_OldYaw = self.m_Player.input.authoritativeAimingYaw

		local s_DifferenceY = s_TargetPos.z - s_PlayerPos.z
		local s_DifferenceX = s_TargetPos.x - s_PlayerPos.x
		local s_DifferenceZ = s_TargetPos.y - s_PlayerPos.y

		local s_AtanYaw = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanYaw > math.pi / 2) and (s_AtanYaw - math.pi / 2) or (s_AtanYaw + 3 * math.pi / 2)

		local s_DistanceHoizontal = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
		s_Pitch = math.abs(math.atan(s_DifferenceZ, s_DistanceHoizontal))

		s_DifferenceYaw = math.abs(s_OldYaw - s_Yaw)

		if s_DifferenceYaw > math.pi then
			s_DifferenceYaw = math.pi * 2 - s_DifferenceYaw
		end

		if self.m_InVehicle then
			if m_Vehicles:IsAAVehicle(self.m_ActiveVehicle) then
				s_FovHalf = Config.FovVehicleAAForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleVehicleAAForShooting / 360 * math.pi
			elseif m_Vehicles:IsAirVehicle(self.m_ActiveVehicle) and
				self.m_Player.controlledEntryId == 0 then
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
			-- only reset ShotTimer, if not already attacking
			if self._ShootModeTimer <= 0 then
				self._ShotTimer = -self:GetFirstShotDelay(self._DistanceToPlayer, false)
			end
			if self.m_InVehicle then
				self._ShootModeTimer = Config.BotVehicleFireModeDuration
			else
				self._ShootModeTimer = Config.BotFireModeDuration
				if self.m_Behavior == BotBehavior.LongerAttacking then
					self._ShootModeTimer = Config.BotFireModeDuration * 1.7
				elseif self.m_Behavior == BotBehavior.AbortAttackFast then
					self._ShootModeTimer = Config.BotFireModeDuration * 0.5
				end
			end
			self._ActiveShootDuration = self._ShootModeTimer
			if self._ShootPlayerName ~= p_Player.name then
				self._DoneShootDuration = 0.0
			end
			self._ShootPlayerName = p_Player.name
			self._ShootPlayer = nil
			self._KnifeWayPositions = {}
			self._VehicleReadyToShoot = false

			if self.m_KnifeMode then
				table.insert(self._KnifeWayPositions, p_Player.soldier.worldTransform.trans:Clone())
			end

			if Globals.IsGm then
				-- check for changed weapon
				BotSpawner:UpdateGmWeapon(self)
			end
			self._KillYourselfTimer = 0.0
			self.m_AttackPriority = s_NewAttackPriority
			return true
		else
			self._ShootPlayerName = ''
			self._ShootPlayer = nil
			self._ShootModeTimer = 0.0
			return false
		end
	end

	return false
end

---@param p_DeltaTime number
function Bot:_CheckForVehicleActions(p_DeltaTime, p_AttackActive)
	-- Check if exit of vehicle is needed (because of low health).
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

	local s_VehicleEntity = self.m_Player.controlledControllable
	if not s_VehicleEntity then
		return
	end

	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.MobileArtillery)
		or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.LightAA)
	then
		-- Change seat, for attack.
		local s_DesiredSeat = 0

		-- Switch to gunner seat
		if p_AttackActive then
			s_DesiredSeat = 1
		end

		if s_DesiredSeat ~= self.m_Player.controlledEntryId
			and s_VehicleEntity:GetPlayerInEntry(s_DesiredSeat) == nil
		then
			self.m_Player:EnterVehicle(s_VehicleEntity, s_DesiredSeat)
			self:UpdateVehicleMovableId()
		end
	else
		-- Check if better seat is available.
		self._VehicleSeatTimer = self._VehicleSeatTimer + p_DeltaTime
		if self._VehicleSeatTimer >= Registry.VEHICLES.VEHICLE_SEAT_CHECK_CYCLE_TIME then
			self._VehicleSeatTimer = 0

			if self.m_InVehicle and self.m_ActiveVehicle.Type ~= VehicleTypes.Gunship then -- In vehicle.
				for l_SeatIndex = 0, self.m_Player.controlledEntryId do
					if s_VehicleEntity:GetPlayerInEntry(l_SeatIndex) == nil then
						-- Better seat available → switch seats.
						m_Logger:Write('switch to better seat')
						self:AbortAttack()
						self.m_Player:EnterVehicle(s_VehicleEntity, l_SeatIndex)
						self:UpdateVehicleMovableId()
						break
					end
				end
			elseif self.m_OnVehicle then -- Only passenger.
				local s_VehicleEntity = self.m_Player.attachedControllable
				local s_LowestSeatIndex = -1

				if not s_VehicleEntity then
					return
				end

				for l_SeatIndex = 0, s_VehicleEntity.entryCount - 1 do
					if s_VehicleEntity:GetPlayerInEntry(l_SeatIndex) == nil then
						-- Maybe better seat available.
						s_LowestSeatIndex = l_SeatIndex
					else             -- Check if there is a gap.
						if s_LowestSeatIndex >= 0 then -- There is a better place.
							m_Logger:Write('switch to better seat')
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
end

function Bot:ResetVars()
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._ForcedMovement = false
	self._ActiveAction = BotActionFlags.NoActionActive
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = nil
	self._ShootPlayer = nil
	self._ShootPlayerName = ''
	self._InvertPathDirection = false
	self._ExitVehicleActive = false
	self._ShotTimer = 0.0
	self._SoundTimer = 30.0
	self._UpdateTimer = 0.0
	self._ActiveDelay = 0.0
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._KnifeWayPositions = {}
	self._ShootWayPoints = {}
	self._SpawnDelayTimer = 0.0
	self._KillYourselfTimer = 0.0
	self._SpawnProtectionTimer = 0.0
	self._Objective = ''
	self._WeaponToUse = BotWeapons.Primary
end

---@param p_DistanceToTarget number
---@param p_ReducedTiming boolean
---@return number
function Bot:GetFirstShotDelay(p_DistanceToTarget, p_ReducedTiming)
	local s_Delay = (Config.BotFirstShotDelay + (Config.ReactionTime * MathUtils:GetRandom(0.8, 1.2) * self.m_Reaction))

	if p_ReducedTiming then
		s_Delay = s_Delay * 0.6
	end

	-- Slower reaction on greater distances. 100 m = 0.5 extra seconda.
	s_Delay = s_Delay + (p_DistanceToTarget * 0.005 * (1.0 + ((self.m_Reaction - 0.5) * 0.4))) -- +-20% depending on reaction-characteristic of bot
	return s_Delay
end

---@param p_Player Player
function Bot:SetVarsStatic(p_Player)
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._ForcedMovement = true
	self._MoveMode = BotMoveModes.Standstill
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = p_Player
end

---@param p_Player Player|nil
---@param p_UseRandomWay boolean
---@param p_PathIndex integer
---@param p_CurrentWayPoint any To-do: add emmylua type
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

	self.m_ActiveMoveMode = BotMoveModes.Paths
	self._PathIndex = p_PathIndex
	self._CurrentWayPoint = p_CurrentWayPoint
	self._InvertPathDirection = p_InverseDirection
end

---@return boolean
function Bot:IsStaticMovement()
	if self._ForcedMovement and (self._MoveMode == BotMoveModes.Standstill or
			self._MoveMode == BotMoveModes.Mirror or
			self._MoveMode == BotMoveModes.Mimic) then
		return true
	else
		return false
	end
end

---@param p_MoveMode BotMoveModes|integer
function Bot:SetMoveMode(p_MoveMode)
	self._ForcedMovement = true
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

function Bot:SetObjectiveIfPossible(p_Objective, p_ObjectiveMode)
	if self._Objective ~= p_Objective and p_Objective ~= '' then
		local s_Point = m_NodeCollection:Get(self._CurrentWayPoint, self._PathIndex)

		if s_Point ~= nil then
			local s_Direction, s_BestWaypoint = m_NodeCollection:ObjectiveDirection(s_Point, p_Objective, self.m_InVehicle)
			if s_BestWaypoint then
				self._Objective = p_Objective
				self._ObjectiveMode = p_ObjectiveMode
				if s_Direction then
					self._InvertPathDirection = (s_Direction == 'Previous')
				end
				return true
			end
		end
	end
	return false
end

function Bot:SetObjective(p_Objective, p_ObjectiveMode)
	if self._Objective ~= p_Objective or p_ObjectiveMode ~= self._ObjectiveMode then
		self._Objective = p_Objective or ''
		self._ObjectiveMode = p_ObjectiveMode or BotObjectiveModes.Default
		local s_Point = m_NodeCollection:Get(self._CurrentWayPoint, self._PathIndex)

		if s_Point ~= nil then
			local s_Direction = m_NodeCollection:ObjectiveDirection(s_Point, self._Objective, self.m_InVehicle)
			if s_Direction then
				self._InvertPathDirection = (s_Direction == 'Previous')
			end
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

---@return integer|BotObjectiveModes
function Bot:GetObjectiveMode()
	return self._ObjectiveMode
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
	if self._ObstacleSequenceTimer ~= 0 then
		return true
	else
		return false
	end
end

function Bot:ResetSpawnVars()
	-- Timers
	self._UpdateTimer = 0.0
	self._UpdateFastTimer = 0.0
	self._SpawnDelayTimer = 0.0
	self._WayWaitTimer = 0.0
	self._VehicleWaitTimer = 0.0
	self._VehicleHealthTimer = 0.0
	self._VehicleSeatTimer = 0.0
	self._VehicleTakeoffTimer = 0.0
	self._WayWaitYawTimer = 0.0
	self._ObstacleSequenceTimer = 0.0
	self._StuckTimer = 0.0
	self._SoundTimer = 30.0
	self._ShotTimer = 0.0
	self._VehicleSecondaryWeaponTimer = 0.0
	self._ShootModeTimer = 0.0
	self._ReloadTimer = 0.0
	self._AttackModeMoveTimer = 0.0
	self._MeleeCooldownTimer = 0.0
	self._ShootTraceTimer = 0.0
	self._ActionTimer = 0.0
	self._BrakeTimer = 0.0
	self._DefendTimer = 0.0
	self._SidewardsTimer = 0.0
	self._KillYourselfTimer = 0.0
	self._SpawnProtectionTimer = 2.0
	self._DeployTimer = MathUtils:GetRandomInt(1, Config.DeployCycle)

	self._ObstacleRetryCounter = 0
	self._LastWayDistance = 1000.0
	self._ShootPlayer = nil
	self._ShootPlayerName = ''
	self._AttackMode = BotAttackModes.RandomNotSet
	self._ShootWayPoints = {}

	-- Skill.
	if not self._SkillFound then
		self._Accuracy = Config.BotWorseningSkill + Config.BotWorseningSkill * (self.m_Accuracy - 0.5)             -- up to 0.5 better or worse
		self._AccuracySniper = Config.BotSniperWorseningSkill + Config.BotSniperWorseningSkill * (self.m_Accuracy - 0.5) -- up to 0.5 better or worse
		self._SkillFound = true
	end

	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._ActiveAction = BotActionFlags.NoActionActive
	self._KnifeWayPositions = {}
	self._ActiveDelay = 0.0
	self._TargetPitch = 0.0
	self._Objective = '' -- Reset objective on spawn, as another spawn-point might have chosen...
	self._WeaponToUse = BotWeapons.Primary

	self.m_HasBeacon = false
	self.m_DontRevive = false
	self._JetAbortAttackActive = false
	self._VehicleReadyToShoot = false
	self._FullVehicleSteering = false
	self._VehicleDirBackPositive = false
	self._ExitVehicleActive = false
	self._OnSwitch = false

	self.m_AttackPriority = 1
	self.m_DelayedInputs = {}

	-- Reset all input-vars.
	---@type EntryInputActionEnum
	for l_EIA = 0, 36 do
		self.m_ActiveInputs[l_EIA] = {
			value = 0,
			reset = false,
		}
		self.m_Player.input:SetLevel(l_EIA, 0.0)
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
		self._ShootPlayerName = ''
	end
end

function Bot:Kill()
	self:ResetVars()

	if self.m_Player.soldier ~= nil then
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
			g_GameDirector:ReturnStationaryAaEntity(self.m_Player.controlledControllable, self.m_Player.teamId)
		end
		self.m_Player.soldier:Kill()
	end
end

function Bot:Destroy()
	self:ResetVars()
	self.m_Player.input = nil

	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:Destroy()
	end

	PlayerManager:DeletePlayer(self.m_Player)
	self.m_Player = nil
end

-- =============================================
-- Private Functions
-- =============================================

---@param p_DeltaTime number
function Bot:_UpdateLookAroundPassenger(p_DeltaTime)
	-- Move around a little.
	local s_Pos = self.m_Player.attachedControllable.transform.forward
	local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
	self._TargetYaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
	self._TargetPitch = 0.0

	self._VehicleWaitTimer = self._VehicleWaitTimer + p_DeltaTime

	if self._VehicleWaitTimer > 9.0 then
		self._VehicleWaitTimer = 0.0
	elseif self._VehicleWaitTimer >= 6.0 then
	elseif self._VehicleWaitTimer >= 3.0 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60° rotation left.
		self._TargetPitch = 0.2

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._VehicleWaitTimer >= 0.0 then
		self._TargetYaw = self._TargetYaw + 1.0 -- 60° rotation right.
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
		reset = p_Value == 0,
	}
end

---@param p_Input EntryInputActionEnum|integer
---@param p_Value number
---@param p_Delay number
function Bot:_SetDelayedInput(p_Input, p_Value, p_Delay)
	table.insert(self.m_DelayedInputs, {
		input = p_Input,
		delay = p_Delay,
		value = p_Value,
	})
end

function Bot:_UpdateInputs()
	---@type EntryInputActionEnum
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

	for l_Index, l_DelayedInput in ipairs(self.m_DelayedInputs) do
		l_DelayedInput.delay = l_DelayedInput.delay - Registry.BOT.BOT_UPDATE_CYCLE
		if l_DelayedInput.delay <= 0 then
			self.m_ActiveInputs[l_DelayedInput.input] = {
				value = l_DelayedInput.value,
				reset = l_DelayedInput.value == 0,
			}
			table.remove(self.m_DelayedInputs, l_Index)
			break
		end
	end
end

---@param p_DeltaTime number
function Bot:_UpdateRespawn(p_DeltaTime)
	if not self._Respawning or self._SpawnMode == BotSpawnModes.NoRespawn then
		return
	end

	-- Wait for respawn-delay gone.
	if self._SpawnDelayTimer < (Globals.RespawnDelay + Config.AdditionalBotSpawnDelay) then
		self._SpawnDelayTimer = self._SpawnDelayTimer + p_DeltaTime
	else
		self._SpawnDelayTimer = 0.0 -- Prevent triggering again.
		Events:DispatchLocal('Bot:RespawnBot', self.m_Id)
	end
end

---@param p_Attacking boolean
function Bot:_UpdateStationaryAAVehicle(p_Attacking)
	-- Get new target if needed.
	if self._DeployTimer > 1.0 then
		local s_Target = m_AirTargets:GetTarget(self.m_Player, Config.MaxDistanceAABots)

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

	if p_Attacking then -- Target available.
		-- Aim at target.
		m_VehicleAiming:UpdateAimingVehicle(self, true)
	else
		-- Just look a little around.
		m_VehicleMovement:UpdateVehicleLookAround(self, Registry.BOT.BOT_FAST_UPDATE_CYCLE)
	end
	m_VehicleMovement:UpdateYawVehicle(self, true, true) -- Only gun → therefore always gun-mode.
end

---@param p_Position Vec3
function Bot:FindVehiclePath(p_Position)
	local s_Node = g_GameDirector:FindClosestPath(p_Position, true, true, self.m_ActiveVehicle.Terrain)

	if s_Node ~= nil then
		-- Switch to vehicle.
		self._InvertPathDirection = false
		self._PathIndex = s_Node.PathIndex
		self._CurrentWayPoint = s_Node.PointIndex
		self._LastWayDistance = 1000.0
		-- Set path.
		self._TargetPoint = s_Node
		self._NextTargetPoint = s_Node
		-- Only for choppers.
		self._TargetHeightAttack = p_Position.y
	end
end

function Bot:UpdateVehicleMovableId()
	self:_SetActiveVars() -- Update if "on vehicle" or "in vehicle".

	if self.m_OnVehicle then
		self._VehicleMovableId = -1
	elseif self.m_InVehicle then
		self._ActiveVehicleWeaponSlot = 0
		self._VehicleMovableId = m_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, self.m_Player.controlledEntryId,
			self._ActiveVehicleWeaponSlot)

		if self.m_Player.controlledEntryId == 0 then
			self:FindVehiclePath(self.m_Player.soldier.worldTransform.trans)
		end
	end
	self:UpdateDontAttackFlag()
end

---@param p_Entity ControllableEntity|nil
---@param p_PlayerIsDriver boolean
---@return integer
---@return Vec3|nil
function Bot:_EnterVehicleEntity(p_Entity, p_PlayerIsDriver)
	if not p_Entity then
		return -2
	end

	local s_Position = p_Entity.transform.trans
	local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_Entity)

	if not s_VehicleData then
		return -2
	end

	if not Config.UseAirVehicles and m_Vehicles:IsAirVehicle(s_VehicleData) then
		return -3 -- Not allowed to use.
	end

	if not Config.UseJets and m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.Plane) then
		return -3 -- Not allowed to use.
	end

	-- Keep one seat free, if enough available.
	local s_MaxEntries = p_Entity.entryCount
	if s_VehicleData.Type == VehicleTypes.Gunship then
		s_MaxEntries = 2
	end
	if s_VehicleData.Type == VehicleTypes.MobileArtillery then
		s_MaxEntries = 1
	end

	if not p_PlayerIsDriver then
		-- Leave a place for a player if more than two seats are available.
		if s_MaxEntries > 2 then
			s_MaxEntries = s_MaxEntries - 1
		end
		-- Limit the bots per vehicle, if no player is the driver.
		if s_MaxEntries > Config.MaxBotsPerVehicle then
			s_MaxEntries = Config.MaxBotsPerVehicle
		end
	else
		-- Allow one more bot, if driver is player.
		if s_MaxEntries > (Config.MaxBotsPerVehicle + 1) then
			s_MaxEntries = Config.MaxBotsPerVehicle + 1
		end
	end

	for seatIndex = 0, s_MaxEntries - 1 do
		if s_VehicleData.Type == VehicleTypes.Gunship then
			seatIndex = seatIndex + 1
		end
		if p_Entity:GetPlayerInEntry(seatIndex) == nil then
			self.m_Player:EnterVehicle(p_Entity, seatIndex)
			self._ExitVehicleHealth = PhysicsEntity(p_Entity).internalHealth * (Registry.VEHICLES.VEHICLE_EXIT_HEALTH / 100.0)

			-- Get ID.
			self.m_ActiveVehicle = s_VehicleData
			self._ActiveVehicleWeaponSlot = 0
			self._VehicleMovableId = m_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, seatIndex, self._ActiveVehicleWeaponSlot)
			-- m_Logger:Write(self.m_ActiveVehicle)

			if seatIndex == 0 then
				if seatIndex == s_MaxEntries - 1 then
					self._VehicleWaitTimer = 0.5 -- Always wait a short time to check for free start.
					self._VehicleTakeoffTimer = Registry.VEHICLES.JET_TAKEOFF_TIME
					g_GameDirector:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
				else
					self._VehicleWaitTimer = Config.VehicleWaitForPassengersTime
					self._BrakeTimer = 0.0
				end
			else
				self._VehicleWaitTimer = 0.0

				if seatIndex == s_MaxEntries - 1 then
					-- Last seat taken: Disable vehicle and abort, wait for passengers.
					local s_Driver = p_Entity:GetPlayerInEntry(0)

					if s_Driver ~= nil then
						Events:Dispatch('Bot:AbortWait', s_Driver.id)
						g_GameDirector:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
					end
				end
			end
			self:_SetActiveVars() -- Update if "on vehicle" or "in vehicle".
			return 0, s_Position -- Everything fine.
		end
	end

	-- No place left.
	return -2
end

---@param p_PlayerIsDriver boolean
---@return integer
---@return Vec3|nil
function Bot:_EnterVehicle(p_PlayerIsDriver)
	local s_Iterator = EntityManager:GetIterator('ServerVehicleEntity')
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

	return -3 -- No vehicle found.
end

---@param p_CurrentWayPoint integer|nil
---@return integer
function Bot:_GetWayIndex(p_CurrentWayPoint)
	local s_ActivePointIndex = 1

	if p_CurrentWayPoint == nil then
		p_CurrentWayPoint = s_ActivePointIndex
	else
		s_ActivePointIndex = p_CurrentWayPoint

		-- Direction handling.
		local s_CountOfPoints = #m_NodeCollection:Get(nil, self._PathIndex)
		local s_FirstPoint = m_NodeCollection:GetFirst(self._PathIndex)

		if s_ActivePointIndex > s_CountOfPoints then
			if s_FirstPoint.OptValue == 0xFF then -- Inversion needed.
				s_ActivePointIndex = s_CountOfPoints
				self._InvertPathDirection = true
			else
				s_ActivePointIndex = 1
			end
		elseif s_ActivePointIndex < 1 then
			if s_FirstPoint.OptValue == 0xFF then -- Inversion needed.
				s_ActivePointIndex = 1
				self._InvertPathDirection = false
			else
				s_ActivePointIndex = s_CountOfPoints
			end
		end
	end

	return s_ActivePointIndex
end

function Bot:AtObjectivePath()
	local s_FirstPoint = m_NodeCollection:GetFirst(self._PathIndex)

	if #s_FirstPoint.Data.Objectives == 1 and s_FirstPoint.Data.Objectives[1] == self._Objective then
		return true
	end

	return false
end

function Bot:AbortAttack()
	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) and
		self._ShootPlayerName ~= '' then
		if self._ShootPlayerVehicleType ~= VehicleTypes.Plane then
			self._VehicleTakeoffTimer = Registry.VEHICLES.JET_ABORT_ATTACK_TIME
		else
			self._VehicleTakeoffTimer = Registry.VEHICLES.JET_ABORT_JET_ATTACK_TIME
		end

		self._JetAbortAttackActive = true
		self._Pid_Drv_Yaw:Reset()
		self._Pid_Drv_Tilt:Reset()
		self._Pid_Drv_Roll:Reset()
	end

	self.m_Player.input.zoomLevel = 0
	self._ShootPlayerName = ''
	self._ShootPlayer = nil
	self._ShootModeTimer = 0.0
	self._AttackMode = BotAttackModes.RandomNotSet
	self.m_AttackPriority = 1
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
	if self._ShootPlayerName ~= '' then
		self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
		self._ShootPlayerVehicleType = m_Vehicles:FindOutVehicleType(self._ShootPlayer)
	else
		self._ShootPlayer = nil
	end

	if self._ForcedMovement then
		self.m_ActiveMoveMode = self._MoveMode
	end

	if self.m_Player.controlledControllable ~= nil and not self.m_Player.controlledControllable:Is('ServerSoldierEntity') then
		self.m_InVehicle = true
		self.m_OnVehicle = false
	elseif self.m_Player.attachedControllable ~= nil then
		self.m_InVehicle = false
		self.m_OnVehicle = true
	else
		self.m_InVehicle = false
		self.m_OnVehicle = false
	end

	if Config.BotWeapon == BotWeapons.Knife then
		self.m_KnifeMode = true
	else
		self.m_KnifeMode = false
	end
end

function Bot:SetActiveDelay(p_Time)
	self._ActiveDelay = p_Time
end

return Bot
