---@class Bot
---@overload fun(p_Player: Player):Bot
Bot = class('Bot')

require('Bot/BotAiming')
require('Bot/BotAimError')
require('Bot/BotAttacking')
require('Bot/BotMovement')
require('Bot/BotZoneMovement')
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
---@type NavZones
local m_NavZones = require('NavZones')

-- A passenger of a vehicle on the ground or in the water gets out at the objective only with a point of the mesh this
-- close (horizontal metres) at about the height of the vehicle (Bot:_CheckShouldExitVehicleIfPassenger), checked at
-- most this often (seconds).
local PASSENGER_EXIT_MESH_RANGE = 20.0
local PASSENGER_EXIT_MESH_HEIGHT = 2.5
local PASSENGER_EXIT_CHECK_TIME = 1.0

-- Create a new bot.
---@param p_Player Player
function Bot:__init(p_Player)
	-- Player Object.
	---@type Player
	self.m_Player = p_Player
	-- The input the BotManager created for this player (player.input is the same object). Use this instead of
	-- m_Player.input: every access of player.input creates a new wrapper object for the GC.
	---@type EntryInput
	self.m_Input = p_Player.input
	-- The ID of the player.
	---@type integer
	self.m_Id = p_Player.id

	-- statemachine-part
	-- The active state object.
	-- TODO: think about making use of subclasses which work like `class ("StateAttacking", BaseSoldierState)` & `class ("StateInVehicleAttacking", BaseInVehicleState)` & `class ("BaseInVehicleState", BaseVehicleState)`.
	---@type StateAttacking|StateIdle|StateInVehicleAttacking|StateInVehicleChopperControl|StateInVehicleJetControl|StateInVehicleMoving|StateInVehicleStationaryAAControl|StateMoving|StateOnVehicleAttacking|StateOnVehicleIdle
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
	-- 0 = fastest, 1 = slowest reaction.
	self.m_Reaction = 0.0
	-- 0 = best, 1 = worst aim.
	self.m_Inaccuracy = 0.0
	self.m_PrefWeapon = ""
	self.m_PrefVehicle = ""

	self._AttackPosition = Vec3.zero

	-- Common settings.
	---@type BotSpawnModes
	self._SpawnMode = BotSpawnModes.NoRespawn
	---@type BotMoveModes

	-- TODO: this whole block could be moved to an inner class `Bot.Loadout = class('Bot.Loadout')`.
	---@type BotKits|integer
	self.m_Kit = nil
	-- Kit of the name of the bot. The spawner uses it, as long as the kit-limits allow it.
	---@type BotKits|nil
	self.m_PreferredKit = nil
	-- The kit counts for the kit-limits: set on spawn, reset once the bot is deactivated (ResetVars).
	self._KitInUse = false
	-- Only used in BotSpawner.
	-- The bot color is the soldier camo (color).
	---@type BotColors|integer
	self.m_Color = nil
	-- Name of the squad-perk the bot got (BotSpawner:_GetUnlocks), so its squad doesn't have to read its unlocks.
	---@type string|nil
	self.m_SquadPerk = nil
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
	-- Seconds the driver waited for passengers so far (VehicleMovement).
	self._VehicleWaited = 0.0
	self._VehicleLookAroundTimer = 0.0
	self._LookAroundYawOffset = 0.0
	self._LookAroundYawGoal = 0.0
	self._LookAroundPitch = 0.0
	self._LookAroundPitchGoal = 0.0
	self._LookAroundSide = 1
	self._LookAroundBaseYaw = 0.0
	self._LookAroundLastTime = 0.0
	self._VehicleSeatTimer = 0.0
	self._VehicleTakeoffTimer = 0.0
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
	-- Off the mesh: where the bot walks to (end of its navigation path, or objective) and how close it got to it
	-- (GameDirector:_CheckProgressOffMesh, the time only counts without progress).
	---@type string|nil
	self._OffMeshTarget = nil
	---@type Waypoint|nil the node of the routes it walks to (GameDirector:_CheckProgressOffMesh)
	self._OffMeshEnd = nil
	-- The key of the path whose stretch it got stuck on (NavRoutes:BlockStretch), once per path.
	self._OffMeshBlocked = nil
	self._OffMeshBestDistance = math.huge
	---@type Vec3|nil where the soldier was at its last progress
	self._OffMeshMoved = nil
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

	-- Path-offset (see Bot:ApplyPathOffset).
	---@type integer|nil
	self.m_PathSide = nil
	self.m_OffsetDistance = 0.0
	self.m_OffsetFactor = 0.0
	self.m_OffsetCenterTimer = 0.0
	self.m_PathOffsetCache = {}

	-- Obstacle-detection (see Bot:_DetectObstacle).
	self._LowSpeedTimer = 0.0
	self._NoProgressTimer = 0.0
	self._ProgressNode = nil
	self._ProgressBestDistance = 0.0
	self._ProgressLastTime = 0.0
	self._ObstacleStartDistance = 0.0

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
	self._LastActionId = -1
	self._StuckRerouteCount = 0
	self._InvertPathDirection = false
	self._ExitVehicleActive = false
	self._ObstacleRetryCounter = 0
	self._Objective = ''
	self._ObjectiveMode = BotObjectiveModes.Default
	self._OnSwitch = false
	self._ActiveDelay = 0.0
	self._VehicleMoveWhileShooting = false
	self._MoveWhileShooting = false
	-- Rush: the attacker keeps going to its MCOM while shooting (StateAttacking, Bot:UpdatePushMovement).
	self._PushWhileShooting = false
	self._Pushing = false
	-- Shooting at a wall in the way (Bot:_TryBreach): { Position, Time, Fire }, and how often for which target.
	self._Breach = nil
	self._BreachKey = nil
	self._BreachCount = 0
	-- Out of a vehicle: onto the mesh once on the ground (VehicleActions, UpdateNormalMovement).
	self._MeshAfterExit = false
	self._MeshRetryTimer = 0.0
	-- The node of the paths the bot decided at last (NavRoutes:Step): it doesn't go straight back there.
	self._NavCame = nil
	self.m_RecentExits = nil
	-- Seconds the bot runs after the target of an action, and until when it uses no C4 (StateAttacking).
	self._ChaseTime = 0.0
	self._ChopperStartHeight = nil
	self._PassengerExitTime = nil
	-- The vehicle the bot got out of or didn't get to ("vehicle <id>"): it isn't sent to it again until then.
	self._LeftVehicle = nil
	self._LeftVehicleUntil = 0.0
	-- Seconds without an objective where no way leads on (GameDirector:_CheckStranded).
	self._StrandedTime = 0.0
	self._ChaseTarget = nil
	self._ChaseCooldown = 0.0
	-- Progress towards the objective and of the vehicle (GameDirector:_CheckObjectiveProgress, _CheckVehicleProgress).
	self._ProgressObjective = nil
	self._ProgressBest = math.huge
	self._ProgressTime = 0.0
	self._VehicleAnchor = nil
	self._VehicleGoal = nil
	self._VehicleStart = nil
	self._VehicleGoalBest = 0.0
	self._VehicleGoalTime = 0.0
	self._VehicleStuckTime = 0.0
	-- Where it got nowhere before it was respawned: not again close to there (BotSpawner).
	self._RespawnAway = nil
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
	-- When a passenger checks next whether it can get out here (_CheckShouldExitVehicleIfPassenger).
	self._PassengerExitCheck = 0.0
	self._LastVehicleHealth = 0.0
	self._VehicleWeaponSlotToUse = 1
	self._ActiveVehicleWeaponSlot = 0
	---@type ControllableEntity|nil
	self._RepairVehicleEntity = nil
	-- PID Controllers (Kp, Ki [1/s], Kd [s], Limit), see PidController.
	-- Normal driving (also chopper yaw).
	---@type PidController
	self._Pid_Drv_Yaw = PidController(5, 1.5, 0.007, 1.0)
	-- Plane (speed).
	---@type PidController
	self._Pid_Drv_Throttle = PidController(3, 1.5, 0.007, 1.0)
	-- Chopper (yaw, height, tilt, roll). Derivative on the measurement to damp the motion.
	---@type PidController
	self._Pid_Drv_YawChopper = PidController(3, 0.3, 1.2, 1.0, true)
	---@type PidController
	self._Pid_Drv_Height = PidController(1.0, 0.3, 1.0, 1.0)
	---@type PidController
	self._Pid_Drv_Tilt = PidController(3, 0.5, 1.0, 1.0)
	---@type PidController
	self._Pid_Drv_Roll = PidController(3, 0.5, 1.0, 1.0)
	-- Jet (pitch, rudder) while attacking: deviation to the lead-point.
	---@type PidController
	self._Pid_Jet_Pitch = PidController(5, 4.0, 0.4, 1.0)
	---@type PidController
	self._Pid_Jet_Yaw = PidController(5, 4.0, 0.4, 1.0)
	-- Measured acceleration of the jet-target (lead of turning targets), see VehicleAiming.
	self._JetTargetAcceleration = { TargetId = nil, LastX = 0.0, LastY = 0.0, LastZ = 0.0, X = 0.0, Y = 0.0, Z = 0.0 }
	-- Guns.
	---@type PidController
	self._Pid_Att_Yaw = PidController(10, 60, 0.067, 1.0)
	---@type PidController
	self._Pid_Att_Pitch = PidController(10, 60, 0.067, 1.0)
	-- movement

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
	-- Aim error (see BotAimError).
	self._AimAcquire = true
	self._AimDriftYaw = 0.0
	self._AimDriftPitch = 0.0
	self._AimAcquireYaw = 0.0
	self._AimAcquirePitch = 0.0
	self._AimFlinchYaw = 0.0
	self._AimFlinchPitch = 0.0
	-- Movement of the target as the bot perceives it.
	self._AimVelX = 0.0
	self._AimVelY = 0.0
	self._AimVelZ = 0.0
	-- Position of the target, when the bot saw it the last time.
	---@type Vec3|nil
	self._LastSeenPosition = nil
	-- Only one grenade-attempt per attack.
	self._GrenadeTried = false
	self._GrenadeTimer = 0.0
	---@type BotWeapons
	self._WeaponToUse = BotWeapons.Primary
	-- To-do: add emmylua type.
	self._ShootWayPoints = {}
	self._FollowWayPoints = {}
	---@type Vec3[]
	self._KnifeWayPositions = {}

	---@type Player|nil
	self._TargetPlayer = nil

	self._FollowTargetPlayer = nil
	self._FollowingTraceTimer = 0.0

	-- Free movement in the zone of the objective (BotZoneMovement), nil on the waypoints.
	---@type BotZoneState|nil
	self.m_Zone = nil
	-- Times the bot left the mesh after getting stuck, without reaching a goal or an exit in between.
	self.m_ZoneGiveUps = 0
	---@type { Position: Vec3, Time: number }[]|nil where and when it gave up its last ways (trapped: _ZoneGiveUpConnection)
	self.m_ZoneTrap = nil
	-- Its own route among similar ones, for a life (NavRoutes:Next).
	self.m_RouteSeed = math.random() * 1000.0
	-- Rush: left the combat area (the next stage isn't open yet), waits at the border (Bot:OnCombatAreaLeft).
	---@type { Left: number, Returned: number|nil, Inverted: boolean }|nil
	self.m_Border = nil
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
			if self.m_Player.controlledControllable:GetPlayerInEntry(1) ~= nil and not Config.ChopperDriversAttack then -- Don't attack if gunner available and config is false.
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

	-- Seats without an aimable part (-1) can't aim their weapon (passengers or fixed guns like on the M1128).
	-- Weapons aimed with the whole vehicle (chopper / jet main guns) use -2.
	-- Drivers of mobile artillery and light AA attack anyway: they switch to the gunner seat (_CheckForVehicleActions).
	if g_BotStates:IsInVehicleState(self.m_ActiveState) and self._VehicleMovableId == -1
		and not (self.m_Player.controlledEntryId == 0
			and (m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.MobileArtillery)
				or m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.LightAA)))
	then
		self._DontAttackPlayers = true
		return
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
			if math.random(0, 100) <= Registry.VEHICLES.VEHICLE_PROBABILITY_EXIT_LOW_HEALTH then
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
			-- UpdateVehicleMovableId resets the target: keep it, to attack it from the gunner seat.
			local s_ShootPlayer = self._ShootPlayer
			local s_ShootPlayerId = self._ShootPlayerId
			self.m_Player:EnterVehicle(s_VehicleEntity, s_DesiredSeat)
			self:UpdateVehicleMovableId()
			self._ShootPlayer = s_ShootPlayer
			self._ShootPlayerId = s_ShootPlayerId
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

	local s_ExitDistance = Registry.BOT.PASSENGER_EXIT_DISTANCE
	local s_ExitDistanceSquared = s_ExitDistance * s_ExitDistance
	local s_CurrentPosition = self.m_Player.soldier.worldTransform.trans
	local s_CurrentX = s_CurrentPosition.x
	local s_CurrentZ = s_CurrentPosition.z

	-- Horizontal (x/z) distance only, compared squared to avoid allocations and sqrt.
	local function _IsInExitRange(p_Position)
		local s_DeltaX = p_Position.x - s_CurrentX
		local s_DeltaZ = p_Position.z - s_CurrentZ
		return (s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ) < s_ExitDistanceSquared
	end

	-- At a capture point the team doesn't hold (where the pilot flies), not over the own ones on the way.
	local s_ShouldExit = false
	local s_TeamId = self.m_Player.teamId
	local s_AllCapturePoints = g_GameDirector:GetAllCapturePoints()
	for l_Index = 1, #s_AllCapturePoints do
		local l_CapturePoint = s_AllCapturePoints[l_Index]
		if l_CapturePoint.team ~= s_TeamId and _IsInExitRange(l_CapturePoint.transform.trans) then
			s_ShouldExit = true
			break
		end
	end

	if not s_ShouldExit then
		local s_ActiveMcoms = g_GameDirector:GetActiveMcomPositions()
		for l_Index = 1, #s_ActiveMcoms do
			if _IsInExitRange(s_ActiveMcoms[l_Index]) then
				s_ShouldExit = true
				break
			end
		end
	end

	-- On the ground or in the water: only where the soldiers get onto the mesh (a point close by, at the height of the
	-- vehicle). An AMTRAC in the canal below the quay (MP_017 Rush, 45 m from MCOM 1): the passengers got out in the
	-- water, stood at the wall for good, respawned in the AMTRAC and got out there again; stage 1 never fell.
	if s_ShouldExit and m_NavZones:GetMesh() ~= nil and not m_Vehicles:IsAirVehicle(self.m_ActiveVehicle) then
		local s_Now = SharedUtils:GetTime()
		if s_Now < self._PassengerExitCheck then
			return
		end
		self._PassengerExitCheck = s_Now + PASSENGER_EXIT_CHECK_TIME
		local s_Mesh = m_NavZones:GetMesh()
		---@cast s_Mesh -nil
		local s_Ground = p_VehicleEntity.transform.trans
		local s_Point = m_NavZones:Closest(s_Mesh, s_Ground, nil, PASSENGER_EXIT_MESH_RANGE)
		if s_Point == nil or math.abs(s_Mesh.Points[s_Point].Y - s_Ground.y) > PASSENGER_EXIT_MESH_HEIGHT then
			s_ShouldExit = false
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

	if self._FollowTargetPlayer == p_Player then
		self._FollowTargetPlayer = nil
		self._FollowWayPoints = {}
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
	self.m_Input = nil

	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:Destroy()
	end

	PlayerManager:DeletePlayer(self.m_Player)
	self.m_Player = nil
end

-- =============================================
-- Private Functions
-- =============================================

---Human-like scanning: glance at a random point, hold it for a moment, then pan smoothly to the next one.
---Glances mostly alternate sides, so left and right both get covered, with an occasional check straight ahead.
---Updates self._LookAroundYawOffset (relative to the vehicle forward or the soldier's base yaw) and self._LookAroundPitch (absolute).
---@param p_DeltaTime number
---@param p_MaxYaw number max yaw offset to either side in rad
---@param p_MaxPitch number max pitch deviation from the horizon in rad
function Bot:UpdateLookAroundGlance(p_DeltaTime, p_MaxYaw, p_MaxPitch)
	self._VehicleLookAroundTimer = self._VehicleLookAroundTimer - p_DeltaTime

	if self._VehicleLookAroundTimer <= 0.0 then
		if MathUtils:GetRandom(0.0, 1.0) < 0.2 then
			-- Check the front again.
			self._LookAroundYawGoal = MathUtils:GetRandom(-0.15, 0.15)
			self._VehicleLookAroundTimer = MathUtils:GetRandom(1.0, 2.5)
		else
			-- Usually switch sides, sometimes take a second look at the same side.
			if MathUtils:GetRandom(0.0, 1.0) < 0.75 then
				self._LookAroundSide = -self._LookAroundSide
			end

			self._LookAroundYawGoal = self._LookAroundSide * MathUtils:GetRandom(0.3 * p_MaxYaw, p_MaxYaw)
			self._VehicleLookAroundTimer = MathUtils:GetRandom(1.5, 4.0)
		end

		-- Mostly scan the horizon, slightly more below than above.
		self._LookAroundPitchGoal = MathUtils:GetRandom(-p_MaxPitch, 0.5 * p_MaxPitch)
	end

	-- Ease towards the goal: fast start, slow settle, capped turn rate.
	local s_Ease = math.min(1.0, p_DeltaTime * 3.0)
	local s_MaxStep = 1.2 * p_DeltaTime -- ~70°/s
	local s_YawStep = (self._LookAroundYawGoal - self._LookAroundYawOffset) * s_Ease

	if s_YawStep > s_MaxStep then
		s_YawStep = s_MaxStep
	elseif s_YawStep < -s_MaxStep then
		s_YawStep = -s_MaxStep
	end

	self._LookAroundYawOffset = self._LookAroundYawOffset + s_YawStep
	self._LookAroundPitch = self._LookAroundPitch + (self._LookAroundPitchGoal - self._LookAroundPitch) * s_Ease
end

---@param p_DeltaTime number
function Bot:_UpdateLookAroundPassenger(p_DeltaTime)
	-- Can be nil while the bot enters or leaves the vehicle.
	if self.m_Player.attachedControllable == nil then
		return
	end

	self:UpdateLookAroundGlance(p_DeltaTime, 1.4, 0.12)

	local s_Pos = self.m_Player.attachedControllable.transform.forward
	local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
	s_Yaw = s_Yaw + self._LookAroundYawOffset

	if s_Yaw < 0.0 then
		s_Yaw = s_Yaw + (2 * math.pi)
	elseif s_Yaw > (2 * math.pi) then
		s_Yaw = s_Yaw - (2 * math.pi)
	end

	self._TargetYaw = s_Yaw
	self._TargetPitch = self._LookAroundPitch
end

---@param p_DeltaTime number
function Bot:_UpdateInputs(p_DeltaTime)
	local s_Input = self.m_Input
	local s_ActiveInputs = self.m_ActiveInputs
	---@type EntryInputActionEnum
	for i = 0, 36 do
		local s_ActiveInput = s_ActiveInputs[i]
		if s_ActiveInput.reset then
			s_Input:SetLevel(i, 0)
			s_ActiveInput.value = 0
			s_ActiveInput.reset = false
		elseif s_ActiveInput.value ~= 0 then
			s_Input:SetLevel(i, s_ActiveInput.value)
			s_ActiveInput.reset = true
		end
	end

	-- Apply every expired delayed input in insertion order and keep the rest, compacting the list in place.
	local s_DelayedInputs = self.m_DelayedInputs
	local s_Count = #s_DelayedInputs
	local s_Remaining = 0

	for l_Index = 1, s_Count do
		local l_DelayedInput = s_DelayedInputs[l_Index]
		l_DelayedInput.delay = l_DelayedInput.delay - p_DeltaTime

		if l_DelayedInput.delay <= 0 then
			self:_SetInput(l_DelayedInput.input, l_DelayedInput.value)
		else
			s_Remaining = s_Remaining + 1
			s_DelayedInputs[s_Remaining] = l_DelayedInput
		end
	end

	for l_Index = s_Count, s_Remaining + 1, -1 do
		s_DelayedInputs[l_Index] = nil
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
			self:FindVehiclePath(self.m_Player.soldier.worldTransform.trans:Clone())
		end
	end
	self:UpdateDontAttackFlag()
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
		self._Pid_Jet_Pitch:Reset()
		self._Pid_Jet_Yaw:Reset()
		self._JetTargetAcceleration.TargetId = nil
	end

	self.m_Input.zoomLevel = 0
	self._ShootPlayerId = -1
	self._ShootPlayer = nil
	self._ShootModeTimer = 0.0
	self._AttackMode = BotAttackModes.RandomNotSet
	self.m_AttackPriority = 1
end

return Bot
