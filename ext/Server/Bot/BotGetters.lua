---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')

---@param p_ShootBackAfterHit boolean
---@param p_Player Player | nil
---@param p_CheckShootTimer boolean
---@param p_IsNewTarget boolean
---@return boolean
function Bot:IsReadyToAttack(p_ShootBackAfterHit, p_Player, p_CheckShootTimer, p_IsNewTarget)
	-- update timers first
	if self._ShootPlayerId == -1 then
		self._DoneShootDuration = 0.0
	elseif p_Player and not p_IsNewTarget then
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

	local s_InVehicle = g_BotStates:IsInVehicleState(self.m_ActiveState)
	if self._ShootPlayerId == -1 or
		(p_Player and not p_IsNewTarget) or -- if still the same enemy, you can trigger directly again
		(s_InVehicle and (self._DoneShootDuration > Config.BotVehicleMinTimeShootAtPlayer)) or
		(not s_InVehicle and (self._DoneShootDuration > Config.BotMinTimeShootAtPlayer)) or
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

	-- attack as soldier
	if s_BotVehicleType == VehicleTypes.NoVehicle and self.m_PrimaryGadget ~= nil then
		if self.m_PrimaryGadget.type == WeaponTypes.MissileAir
			and m_Vehicles:IsAirVehicleType(p_EnemyVehicleType)
		then
			return 2
		elseif self.m_PrimaryGadget.type == WeaponTypes.MissileLand
			and m_Vehicles:IsArmoredVehicleType(p_EnemyVehicleType)
		then
			return 2
		end
	end

	-- attack as air-vehicle
	if m_Vehicles:IsAirVehicleType(s_BotVehicleType) then
		if m_Vehicles:IsAirVehicleType(p_EnemyVehicleType) then
			return 3
		elseif m_Vehicles:IsArmoredVehicleType(p_EnemyVehicleType) then
			return 2
		end
	end

	-- attack as ground-vehicle
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

	if not g_BotStates:IsInVehicleState(self.m_ActiveState) then
		if p_VehicleAttackMode and (p_VehicleAttackMode == VehicleAttackModes.AttackWithMissileAir) then
			s_AttackDistance = Config.MaxShootDistanceMissileAir
		elseif self.m_ActiveWeapon and self.m_ActiveWeapon.type == WeaponTypes.Sniper then
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
		if m_Vehicles:IsGunship(self.m_ActiveVehicle) then
			s_AttackDistance = Config.MaxShootDistanceGunship
		elseif not m_Vehicles:IsAirVehicle(self.m_ActiveVehicle)
			and m_Vehicles:IsNotVehicleType(self.m_ActiveVehicle, VehicleTypes.MobileArtillery)
			and not m_Vehicles:IsAAVehicle(self.m_ActiveVehicle) then
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

---@param p_DistanceToTarget number
---@param p_ReducedTiming boolean
---@param p_AngleToTarget number|nil angle between the aim and the target in rad
---@return number
function Bot:GetFirstShotDelay(p_DistanceToTarget, p_ReducedTiming, p_AngleToTarget)
	local s_Delay = (Config.BotFirstShotDelay + (Config.ReactionTime * MathUtils:GetRandom(0.8, 1.2) * self.m_Reaction))

	if p_ReducedTiming then
		s_Delay = s_Delay * 0.6
	end

	-- Slower reaction on greater distances. 100 m = 0.5 extra seconda.
	s_Delay = s_Delay + (p_DistanceToTarget * 0.005 * (1.0 + ((self.m_Reaction - 0.5) * 0.4))) -- +-20% depending on reaction-characteristic of bot

	-- Fitts' law: aiming at a target far off the crosshair takes longer, growing with log2 of the angle.
	if p_AngleToTarget and p_AngleToTarget > 0.0 then
		s_Delay = s_Delay + Registry.BOT.FIRST_SHOT_DELAY_PER_BIT *
			math.log(1.0 + p_AngleToTarget / Registry.BOT.FIRST_SHOT_TARGET_ANGLE, 2)
	end

	return s_Delay
end

local GRAVITY = 9.81
local MIN_GRENADE_DISTANCE = 3.0 -- Don't throw them too close.

---High-arc throw-pitch to hit a point, so the grenade gets over cover.
---@param p_Distance number horizontal distance to the target
---@param p_Height number height of the target relative to the bot (feet to feet)
---@return number|nil pitch nil if the target is out of reach
function Bot:GetGrenadePitch(p_Distance, p_Height)
	local s_Speed2 = Registry.BOT.GRENADE_THROW_SPEED * Registry.BOT.GRENADE_THROW_SPEED
	local s_Distance = math.max(p_Distance, MIN_GRENADE_DISTANCE)
	local s_Root = s_Speed2 * s_Speed2 - GRAVITY * (GRAVITY * s_Distance * s_Distance + 2.0 * p_Height * s_Speed2)
	if s_Root < 0.0 then
		return nil
	end
	return math.atan((s_Speed2 + math.sqrt(s_Root)) / (GRAVITY * s_Distance))
end

---@param p_RelativeYaw number radians from bot center, normalized
---@param p_RelativePitch number radians from bot center, normalized
---@param p_HalfHfov number half horizontal FOV in radians
---@param p_HalfVfov number half vertical FOV in radians
---@param p_Distance number distance to target in meters
---@param p_AttackDistance number max attack distance in meters
---@return boolean true if enemy should be missed (edge of FOV and distance), false if detected
function Bot:WillMissEnemyAtFovEdge(p_RelativeYaw, p_RelativePitch, p_HalfHfov, p_HalfVfov, p_Distance, p_AttackDistance)
	-- Calculate how far from center the target is (0.0 = center, 1.0 = at edge)
	local s_HorizontalDeviation = 0.90 * math.abs(p_RelativeYaw) / p_HalfHfov -- weight to 0.90
	local s_VerticalDeviation = 0.33 * math.abs(p_RelativePitch) / p_HalfVfov -- weight to 0.33
	-- Calculate distance factor (0.0 at close range, 1.0 at max attack distance)
	local s_DistanceFactor = 0.50 * p_Distance / p_AttackDistance          -- weight to 0.50

	-- Use the maximum deviation as the FOV edge factor (target at edge = 1.0, at center = 0.0)
	local s_MissProbabilityFactor = math.max(s_HorizontalDeviation, s_VerticalDeviation, s_DistanceFactor)

	-- At edge (FOV edge factor = 1) and max distance, probability = Registry.BOT.FOV_EDGE_DISTANCE_MISS_FACTOR
	local s_MissProbability = s_MissProbabilityFactor * Registry.BOT.FOV_EDGE_DISTANCE_MISS_FACTOR

	-- Decide whether to miss the enemy
	return MathUtils:GetRandom(0.0, 100.0) < s_MissProbability
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

---In a vehicle or on one: Player:EnterVehicle fails silently now and then (the seat taken in the same frame), the
---soldier stays on foot.
---@return boolean
function Bot:IsSeated()
	local s_Controllable = self.m_Player.controlledControllable
	return (s_Controllable ~= nil and not s_Controllable:Is('ServerSoldierEntity')) or self.m_Player.attachedControllable ~= nil
end

---@return integer
---@return boolean
function Bot:_GetWayIndex(p_Increment)
	local s_ActivePointIndex = 1
	local s_InvertPathDirection = self._InvertPathDirection

	if self._CurrentWayPoint == nil then
		self._CurrentWayPoint = s_ActivePointIndex
	else
		s_ActivePointIndex = self._CurrentWayPoint + p_Increment

		-- Direction handling.
		local s_CountOfPoints = #m_NodeCollection:Get(nil, self._PathIndex)
		local s_Loops = m_NodeCollection:Loops(self._PathIndex)

		if s_ActivePointIndex > s_CountOfPoints then
			if not s_Loops then -- Inversion needed.
				s_ActivePointIndex = s_CountOfPoints
				s_InvertPathDirection = true
			else
				s_ActivePointIndex = 1
			end
		elseif s_ActivePointIndex < 1 then
			if not s_Loops then -- Inversion needed.
				s_ActivePointIndex = 1
				s_InvertPathDirection = false
			else
				s_ActivePointIndex = s_CountOfPoints
			end
		end
	end

	return s_ActivePointIndex, s_InvertPathDirection
end
