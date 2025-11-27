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
		(p_Player and p_IsNewTarget) or -- if still the same enemy, you can trigger directly again
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

---@return integer
function Bot:_GetWayIndex(p_Increment)
	local s_ActivePointIndex = 1

	if self._CurrentWayPoint == nil then
		self._CurrentWayPoint = s_ActivePointIndex
	else
		s_ActivePointIndex = self._CurrentWayPoint + p_Increment

		-- Direction handling.
		local s_CountOfPoints = #m_NodeCollection:Get(nil, self._PathIndex)
		local s_FirstPoint = m_NodeCollection:GetFirst(self._PathIndex)

		if s_ActivePointIndex > s_CountOfPoints then
			if s_FirstPoint and s_FirstPoint.OptValue == 0xFF then -- Inversion needed.		
				s_ActivePointIndex = s_CountOfPoints
				self._InvertPathDirection = true
			else
				s_ActivePointIndex = 1
			end
		elseif s_ActivePointIndex < 1 then
			if s_FirstPoint and s_FirstPoint.OptValue == 0xFF then -- Inversion needed.
				s_ActivePointIndex = 1
				self._InvertPathDirection = false
			else
				s_ActivePointIndex = s_CountOfPoints
			end
		end
	end

	return s_ActivePointIndex
end
