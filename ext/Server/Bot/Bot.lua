---@class Bot
---@overload fun(p_Player: Player):Bot
Bot = class('Bot')

require('Bot/BotAiming')
require('Bot/BotAttacking')
require('Bot/BotMovement')
require('Bot/BotWeaponHandling')

require('Bot/BotActions')
require('Bot/VehicleActions')

require('Bot/BotGetters')
require('Bot/BotSetters')

require('__shared/Config')
require('PidController')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)
---@type Vehicles
local m_Vehicles = require('Vehicles')

-- Create a new bot.
---@param p_Player Player
function Bot:__init(p_Player)
	-- Player Object.
	---@type Player
	self.m_Player = p_Player
	-- The ID of the player.
	---@type integer
	self.m_Id = p_Player.id

	-- statemachine-part
	-- The active state object.
	-- TODO: think about making use of subclasses which work like `class ("StateAttacking", BaseSoldierState)` & `class ("StateInVehicleAttacking", BaseInVehicleState)` & `class ("BaseInVehicleState", BaseVehicleState)`.
	---@type StateAttacking|StateIdle|StateInVehicleAttacking|StateInVehicleChopperControl|StateInVehicleIdle|StateInVehicleJetControl|StateInVehicleMoving|StateInVehicleStationaryAAControl|StateMoving|StateOnVehicleAttacking|StateOnVehicleIdle
	self.m_ActiveState = g_BotStates.States.Idle
	-- TODO: only used in StateInVehicleAttacking. Might make sense to move it to that class. Or move it to a BaseState class and inherit that in every other state as a subclass.
	-- The timer of the current state.
	self.m_StateTimer = 0.0

	--[[
		TODO: move this to an inner class. Like `Bot.Persona = class('Bot.Persona')` or `Bot.Attributes = class('Bot.Attributes')` and have there all the attributes.
		If it is going to be persona you can add even more stuff to it like name, clan tag, dog tags etc.
		Percentage kit choice, percentage weapon choice, behaviors like "TriesToRevengeAfterXDeaths" by pulling out the noobtube or "PlayForKills", "PlayForObjective" etc etc.
		This can get a huge thing in the future if it gets fed with data.
	]]
	-- create some character proporties
	---@type BotBehavior
	self.m_Behavior = nil
	self.m_Reaction = 0.0
	self.m_Accuracy = 0.0
	self.m_Skill = 0.0
	self.m_PrefWeapon = ""
	self.m_PrefVehicle = ""

	self._AttackPosition = Vec3.zero

	-- Common settings.
	---@type BotSpawnModes
	self._SpawnMode = BotSpawnModes.NoRespawn
	---@type BotMoveModes
	self._MoveMode = BotMoveModes.Standstill
	self._ForcedMovement = false

	-- TODO: this whole block could be moved to an inner class `Bot.Loadout = class('Bot.Loadout')`.
	---@type BotKits|integer
	self.m_Kit = nil
	-- Only used in BotSpawner.
	-- The bot color is the soldier camo (color).
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
	self._SpawnDelayTimer = 0.0
	self._WayWaitTimer = 0.0
	self._VehicleWaitTimer = 0.0
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
	self._RocketCooldownTimer = 0.0

	-- Shared movement vars.
	---@type BotMoveModes
	self.m_ActiveMoveMode = BotMoveModes.Standstill
	---@type BotMoveSpeeds
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self.m_KnifeMode = false

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
	self._LastWayDistance = 1000.0
	self._InvertPathDirection = false
	self._ExitVehicleActive = false
	self._ObstacleRetryCounter = 0
	self._Objective = ''
	self._ObjectiveMode = BotObjectiveModes.Default
	self._OnSwitch = false
	self._ActiveDelay = 0.0
	self._VehicleMoveWhileShooting = false
	self._MoveWhileShooting = false
	self._FireCycleModifier = 1.0

	-- Vehicle stuff.
	---@type integer|nil
	self._VehicleMovableId = -1
	self._LastVehicleYaw = 0.0
	self._VehicleReadyToShoot = false
	self._FullVehicleSteering = false
	self._VehicleDirBackPositive = false
	self._JetAbortAttackActive = false
	self._JetTakeoffActive = false
	self._ExitVehicleHealth = 0.0
	self._LastVehicleHealth = 0.0
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
	-- movement
	---@type PidController
	self._Pid_Move_Yaw = PidController(0.01, 0.005, 0.0, 1.0)

	-- Shooting.
	self._Shoot = false
	---@type Player|nil
	self._ShootPlayer = nil
	self._ActiveShootDuration = 0.0
	self._DoneShootDuration = 0.0
	self._DontAttackPlayers = false
	---@type VehicleTypes
	self._ShootPlayerVehicleType = VehicleTypes.NoVehicle
	self._ShootPlayerId = -1
	self._DistanceToPlayer = 0.0
	---@type BotWeapons
	self._WeaponToUse = BotWeapons.Primary
	-- To-do: add emmylua type.
	self._ShootWayPoints = {}
	self._FollowWayPoints = {}
	---@type Vec3[]
	self._KnifeWayPositions = {}
	self._Accuracy = 0.0
	self._AccuracySniper = 0.0
	self._SkillFound = false

	---@type Player|nil
	self._TargetPlayer = nil

	self._FollowTargetPlayer = nil
	self._FollowingTraceTimer = 0.0
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

function Bot:UpdateDontAttackFlag()
	-- Don't attack as driver in some vehicles.
	if g_BotStates:IsInVehicleState(self.m_ActiveState) and self.m_Player.controlledEntryId == 0 then
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Chopper) then                               -- do not include ScoutChopper here (they can attack)
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

---@param p_DeltaTime number
function Bot:_CheckForVehicleActions(p_DeltaTime, p_AttackActive)
	local s_InVehicle = g_BotStates:IsInVehicleState(self.m_ActiveState)
	local s_OnVehicle = g_BotStates:IsOnVehicleState(self.m_ActiveState)

	local s_VehicleEntity = self.m_Player.controlledControllable
	if s_VehicleEntity and s_VehicleEntity.typeInfo.name == "ServerSoldierEntity" then
		s_VehicleEntity = self.m_Player.attachedControllable
	end
	-- No vehicle found.
	if not s_VehicleEntity then
		return
	end

	-- Check if exit of vehicle is needed (because of low health).
	if not self._ExitVehicleActive then
		local s_CurrentVehicleHealth = 0
		if s_VehicleEntity then
			s_CurrentVehicleHealth = PhysicsEntity(s_VehicleEntity).internalHealth
		end

		if s_CurrentVehicleHealth <= self._ExitVehicleHealth then
			if math.random(0, 100) <= Registry.VEHICLES.VEHICLE_PROPABILITY_EXIT_LOW_HEALTH then
				self:AbortAttack()
				self:ExitVehicle()
			end
		end
	end

	self:_CheckShouldExitVehicleIfPassenger(s_VehicleEntity, s_OnVehicle)

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

			if s_InVehicle and self.m_ActiveVehicle.Type ~= VehicleTypes.Gunship then -- In vehicle.
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
			elseif s_OnVehicle then -- Only passenger.
				local s_LowestSeatIndex = -1
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

---comment
---@param p_VehicleEntity ControllableEntity
---@param p_OnVehicle boolean
function Bot:_CheckShouldExitVehicleIfPassenger(p_VehicleEntity, p_OnVehicle)
	if self._ExitVehicleActive then
		return
	end

	if not p_OnVehicle
		and not m_Vehicles:IsPassengerSeat(self.m_ActiveVehicle, self.m_Player.controlledEntryId)
	then
		return
	end

	-- don't exit near objectives if the driver is a real-player
	local s_PlayerInDriverSeat = p_VehicleEntity:GetPlayerInEntry(0)
	if s_PlayerInDriverSeat and s_PlayerInDriverSeat.onlineId ~= 0 then
		return
	end

	local s_ShouldExit = false
	local s_ExitDistance = Registry.BOT.PASSENGER_EXIT_DISTANCE
	local s_AllCapturePoints = g_GameDirector:GetAllCapturePoints()
	local s_ActiveMcoms = g_GameDirector:GetActiveMcomPositions()
	local s_CurrentPosition = self.m_Player.soldier.worldTransform.trans:Clone()
	s_CurrentPosition.y = 0

	s_Coordinates = {}
	for l_Index = 1, #s_AllCapturePoints do
		s_Coordinates[#s_Coordinates + 1] = s_AllCapturePoints[l_Index].transform.trans
	end
	for l_Index = 1, #s_ActiveMcoms do
		s_Coordinates[#s_Coordinates + 1] = s_ActiveMcoms[l_Index]
	end

	for l_Index = 1, #s_Coordinates do
		local l_Coord = s_Coordinates[l_Index]
		local s_Position = l_Coord:Clone()
		s_Position.y = 0

		if s_Position:Distance(s_CurrentPosition) < s_ExitDistance then
			s_ShouldExit = true
			break
		end
	end

	if s_ShouldExit then
		self:AbortAttack()
		self:ExitVehicle()
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

	local s_CurrentShootPlayer = PlayerManager:GetPlayerById(self._ShootPlayerId)

	if s_CurrentShootPlayer == p_Player then
		self._ShootPlayerId = -1
		self._ShootPlayer = nil
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
	-- TODO: why is this check needed sometimes?
	if self.m_Player.attachedControllable == nil then
		return
	end

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

---@param p_DeltaTime number
function Bot:_UpdateInputs(p_DeltaTime)
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

	for l_Index = 1, #self.m_DelayedInputs do
		local l_DelayedInput = self.m_DelayedInputs[l_Index]
		l_DelayedInput.delay = l_DelayedInput.delay - p_DeltaTime
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
		g_BotSpawner:TriggerRespawnBot(self)
	end
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
	end
end

function Bot:UpdateVehicleMovableId()
	local s_InVehicle = false
	local s_OnVehicle = false
	self:ResetSpawnVars() -- TODO: this might be too hard? Better solution? Only Inputs relevant?
	if self.m_Player.controlledControllable ~= nil and not self.m_Player.controlledControllable:Is('ServerSoldierEntity') then
		s_InVehicle = true
		s_OnVehicle = false

		-- transition to vehicle state
		if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.Plane) then
			self:SetState(g_BotStates.States.InVehicleJetControl)
		elseif m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.StationaryAA) then
			self:SetState(g_BotStates.States.InVehicleStationaryAaControl)
		elseif m_Vehicles:IsChopper(self.m_ActiveVehicle) and self.m_Player.controlledEntryId == 0 then
			self:SetState(g_BotStates.States.InVehicleChopperControl)
		else
			self:SetState(g_BotStates.States.InVehicleMoving)
		end
	elseif self.m_Player.attachedControllable ~= nil then
		s_InVehicle = false
		s_OnVehicle = true
		self:SetState(g_BotStates.States.OnVehicleIdle)
	end

	if s_OnVehicle then
		self._VehicleMovableId = -1
	elseif s_InVehicle then
		self._ActiveVehicleWeaponSlot = 0
		self._VehicleMovableId = m_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, self.m_Player.controlledEntryId,
			self._ActiveVehicleWeaponSlot)

		if self.m_Player.controlledEntryId == 0 then
			self:FindVehiclePath(self.m_Player.soldier.worldTransform.trans)
		end
	end
	self:UpdateDontAttackFlag()
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
		self._ShootPlayerId ~= -1 then
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
	self._ShootPlayerId = -1
	self._ShootPlayer = nil
	self._ShootModeTimer = 0.0
	self._AttackMode = BotAttackModes.RandomNotSet
	self.m_AttackPriority = 1
end

return Bot
