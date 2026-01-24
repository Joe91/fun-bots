---@type NodeCollection
local m_NodeCollection = require('NodeCollection')

---@param p_State any
function Bot:SetState(p_State)
	self.m_ActiveState = p_State
	self.m_StateTimer = 0.0
end

---@param p_Player Player
function Bot:SetVarsStatic(p_Player)
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = p_Player
	self:SetState(g_BotStates.States.StaticMovement)
	self.m_ActiveMoveMode = BotMoveModes.Standstill
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

---@param p_MoveMode BotMoveModes|integer
function Bot:SetMoveMode(p_MoveMode)
	if not g_BotStates:IsStaticState(self.m_ActiveState) then
		self:SetState(g_BotStates.States.StaticMovement)
	end
	self.m_ActiveMoveMode = p_MoveMode
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
			local s_Direction, s_BestWaypoint = m_NodeCollection:ObjectiveDirection(s_Point, p_Objective, g_BotStates:IsInVehicleState(self.m_ActiveState))
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
			local s_Direction = m_NodeCollection:ObjectiveDirection(s_Point, self._Objective, g_BotStates:IsInVehicleState(self.m_ActiveState))
			if s_Direction then
				self._InvertPathDirection = (s_Direction == 'Previous')
			end
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

function Bot:_SetActiveVarsSlow()
	if self._ShootPlayer ~= nil then
		-- only needed on change
		local s_PlayerData = g_PlayerData:GetData(self._ShootPlayerId)
		if s_PlayerData then
			self._ShootPlayerVehicleType = s_PlayerData.Vehicle
		else
			self._ShootPlayerVehicleType = VehicleTypes.NoVehicle
		end
	end
end

function Bot:_SetActiveVars()
	if Config.BotWeapon == BotWeapons.Knife then
		self.m_KnifeMode = true
	else
		self.m_KnifeMode = false
	end
end

function Bot:SetActiveDelay(p_Time)
	self._ActiveDelay = p_Time
end

function Bot:ResetVehicleTimer()
	self._VehicleWaitTimer = 0.0
end

function Bot:ResetVars()
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._ActiveAction = BotActionFlags.NoActionActive
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = nil
	self._ShootPlayer = nil
	self._ShootPlayerId = -1
	self._InvertPathDirection = false
	self._ExitVehicleActive = false
	self._ShotTimer = 0.0
	self._SoundTimer = 30.0
	self._ActiveDelay = 0.0
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._KnifeWayPositions = {}
	self._ShootWayPoints = {}
	self._FollowWayPoints = {}
	self._SpawnDelayTimer = 0.0
	self._KillYourselfTimer = 0.0
	self._RocketCooldownTimer = 0.0
	self._SpawnProtectionTimer = 0.0
	self._Objective = ''
	self._WeaponToUse = BotWeapons.Primary
end

function Bot:ResetSpawnVars()
	-- Timers
	self._SpawnDelayTimer = 0.0
	self._WayWaitTimer = 0.0
	self._VehicleWaitTimer = 0.0
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
	self._RocketCooldownTimer = 0.0
	self._SpawnProtectionTimer = 2.0
	self._DeployTimer = MathUtils:GetRandomInt(1, Config.DeployCycle)

	self._ObstacleRetryCounter = 0
	self._LastWayDistance = 1000.0
	self._LastActionId = -1
	self._ShootPlayer = nil
	self._FollowTargetPlayer = nil
	self._DontAttackPlayers = false
	self._ShootPlayerId = -1
	self._AttackMode = BotAttackModes.RandomNotSet
	self._ShootWayPoints = {}
	self._FollowWayPoints = {}

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
	self._JetTakeoffActive = false
	self._VehicleReadyToShoot = false
	self._FullVehicleSteering = false
	self._VehicleDirBackPositive = false
	self._ExitVehicleActive = false
	self._OnSwitch = false
	self._VehicleMoveWhileShooting = false
	self._FireCycleModifier = 1.0 -- don't init it at all on spawn?

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
