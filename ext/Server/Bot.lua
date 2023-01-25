---@class Bot
---@overload fun(p_Player: Player):Bot
Bot = class('Bot')

require('__shared/Config')
require('PidController')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)

local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')

---@param p_Player Player
function Bot:__init(p_Player)
	-- Player Object.
	---@type Player
	self.m_Player = p_Player
	---@type string
	self.m_Name = p_Player.name
	---@type integer
	self.m_Id = p_Player.id

	-- Common settings.
	---@type BotSpawnModes
	self._SpawnMode = BotSpawnModes.NoRespawn
	---@type BotMoveModes
	self._MoveMode = BotMoveModes.Standstill
	self._ForcedMovement = false
	---@type BotKits|nil
	self.m_Kit = nil
	-- Only used in BotSpawner.
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
	self._ShootModeTimer = 0.0
	self._ReloadTimer = 0.0
	self._AttackModeMoveTimer = 0.0
	self._MeleeCooldownTimer = 0.0
	self._ShootTraceTimer = 0.0
	self._ActionTimer = 0.0
	self._BrakeTimer = 0.0
	self._SpawnProtectionTimer = 0.0
	self._SidewardsTimer = 0.0
	self._KnifeWayPointTimer = 0.0

	-- Zombie Stuff
	self._SpeedFactorMovement = 1.0

	-- Shared movement vars.
	---@type BotMoveModes
	self.m_ActiveMoveMode = BotMoveModes.Standstill
	---@type BotMoveSpeeds
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self.m_InVehicle = false
	self.m_OnVehicle = false

	---@class ActiveInput
	---@field value number
	---@field reset boolean

	---@type table<integer|EntryInputActionEnum, ActiveInput>
	self.m_ActiveInputs = {}

	-- Sidewards movement.
	self.m_YawOffset = 0.0
	self.m_StrafeValue = 0.0

	-- Advanced movement.
	---@type BotAttackModes
	self._AttackMode = BotAttackModes.RandomNotSet
	---@type BotActionFlags
	self._ActiveAction = BotActionFlags.NoActionActive
	-- To-do: add emmylua type.
	self._CurrentWayPoint = nil
	self._TargetYaw = 0.0
	self._TargetPitch = 0.0
	-- To-do: add emmylua type.
	self._TargetPoint = nil
	-- To-do: add emmylua type.
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

	-- Shooting.
	self._Shoot = false
	---@type Player|nil
	self._ShootPlayer = nil
	self._ShootPlayerName = ''
	self._DistanceToPlayer = 0.0
	---@type BotWeapons
	self._WeaponToUse = BotWeapons.Primary
	-- To-do: add emmylua type.
	self._ShootWayPoints = {}
	---@type Vec3[]
	self._KnifeWayPositions = {}

	---@type Player|nil
	self._TargetPlayer = nil
end

-- =============================================
-- Events
-- =============================================

-- Update frame (every Cycle).
-- Update very fast (0.05) ? Needed? Aiming?
-- Update fast (0.1) ? Movement, Reactions.
-- (Update medium? Maybe some things in between).
-- Update slow (1.0) ? Reload, Deploy, (Obstacle-Handling).

---@param p_DeltaTime number
function Bot:OnUpdatePassPostFrame(p_DeltaTime)
	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:SingleStepEntry(self.m_Player.controlledEntryId)
	end

	if self.m_Player.soldier == nil then -- Player not alive.
		self._UpdateTimer = self._UpdateTimer + p_DeltaTime -- Reusage of updateTimer.

		if self._UpdateTimer > Registry.BOT.BOT_UPDATE_CYCLE then
			self:_UpdateRespawn(Registry.BOT.BOT_UPDATE_CYCLE)
			self._UpdateTimer = 0.0
		end
	else -- Player alive.
		if Globals.IsInputAllowed and self._SpawnProtectionTimer <= 0.0 then
			-- Update timer.
			self._UpdateFastTimer = self._UpdateFastTimer + p_DeltaTime

			if self._UpdateFastTimer >= Registry.BOT.BOT_FAST_UPDATE_CYCLE then
				-- Increment slow timer.
				self._UpdateTimer = self._UpdateTimer + self._UpdateFastTimer

				-- Detect modes.
				self:_SetActiveVars()

				------------------ CODE OF BEHAVIOUR STARTS HERE ---------------------
				local s_Attacking = self._ShootPlayer ~= nil -- Can be either attacking or reviving or enter of a vehicle with a player.

				-- Sync slow code with fast code. Therefore, execute the slow code first.
				if self._UpdateTimer >= Registry.BOT.BOT_UPDATE_CYCLE then
					-- Common part.
					m_BotWeaponHandling:UpdateWeaponSelection(self)

					-- Differ attacking.
					if s_Attacking then
						m_BotAttacking:UpdateAttacking(self)

						m_BotMovement:UpdateShootMovement(self)
					else
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

				-- Fast code.
				if s_Attacking then
					m_BotAiming:UpdateAiming(self)
				else
					m_BotMovement:UpdateTargetMovement(self)
				end

				self._UpdateFastTimer = 0.0
			end

			-- Very fast code.
			if not self.m_InVehicle then
				m_BotMovement:UpdateYaw(self)
			end

		else -- Alive, but no inputs allowed yet → look around.
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
		end
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================



function Bot:UpdateObjective(p_Objective)
	local s_AllObjectives = m_NodeCollection:GetKnownObjectives()

	for l_Objective, _ in pairs(s_AllObjectives) do
		if l_Objective == p_Objective then
			self:SetObjective(p_Objective)
			break
		end
	end
end

---@return boolean
function Bot:IsReadyToAttack()
	if self._ShootPlayer == nil or self._ShootModeTimer > Config.BotMinTimeAttackOnePlayer then
		return true
	else
		return false
	end
end

---@param p_Player Player
---@param p_IgnoreYaw boolean
---@return boolean
function Bot:ShootAt(p_Player, p_IgnoreYaw)
	if not self:IsReadyToAttack() or self._Shoot == false then
		return false
	end

	-- Don't shoot at teammates.
	if self.m_Player.teamId == p_Player.teamId then
		return false
	end

	if p_Player.soldier == nil or self.m_Player.soldier == nil then
		return false
	end

	-- Don't shoot if too far away.
	self._DistanceToPlayer = 0.0

	local s_TargetPos = p_Player.soldier.worldTransform.trans:Clone()
	local s_PlayerPos = self.m_Player.soldier.worldTransform.trans:Clone()

	self._DistanceToPlayer = s_TargetPos:Distance(s_PlayerPos)

	local s_IsSniper = (self.m_ActiveWeapon and self.m_ActiveWeapon.type == WeaponTypes.Sniper)
	local s_VehicleAttackMode = nil

	local s_AttackDistance = 0.0
	if p_IgnoreYaw then
		s_AttackDistance = Config.MaxDistanceShootBack
	else
		s_AttackDistance = Config.MaxShootDistance
	end

	-- Don't attack if too far away.
	if self._DistanceToPlayer > s_AttackDistance then
		return false
	end


	local s_DifferenceYaw = 0
	local s_Pitch = 0
	local s_FovHalf = 0
	local s_PitchHalf = 0

	-- Check for vehicles.
	local s_Type = m_Vehicles:FindOutVehicleType(p_Player)
	-- If target is air-vehicle, should we handle this case?
	if (s_Type == VehicleTypes.Chopper or s_Type == VehicleTypes.Plane) then
		-- TODO: Abort attack?
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

		s_FovHalf = Config.FovForShooting / 360 * math.pi
		s_PitchHalf = Config.FovVerticleForShooting / 360 * math.pi
	end

	if p_IgnoreYaw or (s_DifferenceYaw < s_FovHalf and s_Pitch < s_PitchHalf) then
		if self._Shoot then
			self._ShootModeTimer = 0.0
			self._ShootPlayerName = p_Player.name
			self._ShootPlayer = nil
			self._KnifeWayPositions = {}
			self._ShootWayPoints = {}
			self._ShotTimer = 0.0
			table.insert(self._KnifeWayPositions, p_Player.soldier.worldTransform.trans:Clone())

			return true
		else
			self._ShootPlayerName = ''
			self._ShootPlayer = nil
			self._ShootModeTimer = Config.BotAttackDuration
			return false
		end
	end

	return false
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

---@param p_Player Player
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

function Bot:SetObjectiveIfPossible(p_Objective)
	if self._Objective ~= p_Objective and p_Objective ~= '' then
		local s_Point = m_NodeCollection:Get(self._CurrentWayPoint, self._PathIndex)

		if s_Point ~= nil then
			local s_Direction, s_BestWaypoint = m_NodeCollection:ObjectiveDirection(s_Point, p_Objective, self.m_InVehicle)
			if s_BestWaypoint then
				self._Objective = p_Objective
				self._InvertPathDirection = (s_Direction == 'Previous')
				return true
			end
		end
	end
	return false
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
	if self.m_Player.soldier ~= nil or self.m_Player.corpse ~= nil then
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
	self._SpawnDelayTimer = 0.0
	self._ObstacleSequenceTimer = 0.0
	self._ObstacleRetryCounter = 0
	self._LastWayDistance = 1000.0
	self._ShootPlayer = nil
	self._ShootPlayerName = ''
	self._ShootModeTimer = 0.0
	self._MeleeCooldownTimer = 0.0
	self._ShootTraceTimer = 0.0
	self._ReloadTimer = 0.0
	self._BrakeTimer = 0.0
	self._AttackModeMoveTimer = 0.0
	self._AttackMode = BotAttackModes.RandomNotSet
	self._ShootWayPoints = {}
	self._SpeedFactorMovement = MathUtils:GetRandom(0.3, 0.9)

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
	self._Objective = '' -- Reset objective on spawn, as another spawn-point might have chosen...
	self._WeaponToUse = BotWeapons.Primary

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
end

---@param p_DeltaTime number
function Bot:_UpdateRespawn(p_DeltaTime)
	if not self._Respawning or self._SpawnMode == BotSpawnModes.NoRespawn then
		return
	end

	if self.m_Player.soldier == nil then
		-- Wait for respawn-delay gone.
		if self._SpawnDelayTimer < (Globals.RespawnDelay + Config.AdditionalBotSpawnDelay) then
			self._SpawnDelayTimer = self._SpawnDelayTimer + p_DeltaTime
		else
			self._SpawnDelayTimer = 0.0 -- Prevent triggering again.
			Events:DispatchLocal('Bot:RespawnBot', self.m_Name)
		end
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
end

---@param p_Entity ControllableEntity
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

	if not Config.UseAirVehicles and
		(s_VehicleData.Type == VehicleTypes.Plane or s_VehicleData.Type == VehicleTypes.Chopper) then
		return -3 -- Not allowed to use.
	end

	-- Keep one seat free, if enough available.
	local s_MaxEntries = p_Entity.entryCount
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

	for i = 0, s_MaxEntries - 1 do
		if p_Entity:GetPlayerInEntry(i) == nil then
			self.m_Player:EnterVehicle(p_Entity, i)
			self._ExitVehicleHealth = PhysicsEntity(p_Entity).internalHealth * (Registry.VEHICLES.VEHILCE_EXIT_HEALTH / 100.0)

			-- Get ID.
			self.m_ActiveVehicle = s_VehicleData
			self._ActiveVehicleWeaponSlot = 0
			self._VehicleMovableId = m_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, i, self._ActiveVehicleWeaponSlot)
			m_Logger:Write(self.m_ActiveVehicle)

			if i == 0 then
				if i == s_MaxEntries - 1 then
					self._VehicleWaitTimer = 0.5 -- Always wait a short time to check for free start.
					self._VehicleTakeoffTimer = Registry.VEHICLES.JET_TAKEOFF_TIME
					g_GameDirector:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
				else
					self._VehicleWaitTimer = Config.VehicleWaitForPassengersTime
					self._BrakeTimer = 0.0
				end
			else
				self._VehicleWaitTimer = 0.0

				if i == s_MaxEntries - 1 then
					-- Last seat taken: Disable vehicle and abort, wait for passengers.
					local s_Driver = p_Entity:GetPlayerInEntry(0)

					if s_Driver ~= nil then
						Events:Dispatch('Bot:AbortWait', s_Driver.name)
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

function Bot:AbortAttack()
	self.m_Player.input.zoomLevel = 0
	self._ShootPlayerName = ''
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
	if self._ShootPlayerName ~= '' then
		self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
	else
		self._ShootPlayer = nil
	end

	if self._ForcedMovement then
		self.m_ActiveMoveMode = self._MoveMode
	end

	self.m_InVehicle = false
	self.m_OnVehicle = false
end

return Bot
