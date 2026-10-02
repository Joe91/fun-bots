---@type Utilities
local m_Utilities = require('__shared/Utilities')

local QUARTER_PI = math.pi / 4

---@param p_Soldier SoldierEntity
---@param p_RecoilFactor number share of the recoil to compensate
---@param p_SpreadFactor number share of the spread to compensate (a human can't know it, bots can't aim down sights)
---@return number compensationPitch
---@return number compensationYaw
local function _CompensateRecoil(p_Soldier, p_RecoilFactor, p_SpreadFactor)
	local s_CurrentWeapon = p_Soldier.weaponsComponent.currentWeapon

	if not s_CurrentWeapon then
		return 0.0, 0.0
	end

	local s_WeaponFiring = s_CurrentWeapon.weaponFiring

	if not s_WeaponFiring then
		return 0.0, 0.0
	end

	local s_GunSway = s_WeaponFiring.gunSway

	if not s_GunSway then
		return 0.0, 0.0
	end

	local s_CurrentRecoilDeviation = s_GunSway.currentRecoilDeviation
	local s_CurrentDispersionDeviation = s_GunSway.currentDispersionDeviation
	-- currentLagDeviation is always zero, so it is not used.

	return s_CurrentRecoilDeviation.pitch * p_RecoilFactor + s_CurrentDispersionDeviation.pitch * p_SpreadFactor,
		s_CurrentRecoilDeviation.yaw * p_RecoilFactor + s_CurrentDispersionDeviation.yaw * p_SpreadFactor
end

-- Works on plain numbers: vector math and method calls on Vec3 allocate, this runs for every attacking bot.
---@param p_Bot Bot
---@param p_Speed number
---@param p_DiffX number target - bot
---@param p_DiffY number
---@param p_DiffZ number
---@param p_MoveX number target movement
---@param p_MoveY number
---@param p_MoveZ number
---@return number
local function _GetTimeToTravel(p_Bot, p_Speed, p_DiffX, p_DiffY, p_DiffZ, p_MoveX, p_MoveY, p_MoveZ)
	if p_Speed <= 0 then
		return 0.0
	end
	if Registry.BOT.USE_ADVANCED_AIMING then
		-- Calculate how long the distance is → time to travel.
		local A = (p_MoveX * p_MoveX + p_MoveY * p_MoveY + p_MoveZ * p_MoveZ) - p_Speed * p_Speed
		local B = 2.0 * (p_MoveX * p_DiffX + p_MoveY * p_DiffY + p_MoveZ * p_DiffZ)
		local C = p_DiffX * p_DiffX + p_DiffY * p_DiffY + p_DiffZ * p_DiffZ
		local s_Discriminant = B * B - 4 * A * C
		-- The projectile can't catch up with the target (slower and the target moves away): no solution, and sqrt
		-- would return NaN, which ends up in yaw and pitch. Aim with the plain flight-time instead.
		if s_Discriminant < 0 or A == 0 then
			return p_Bot._DistanceToPlayer / p_Speed
		end
		local s_Determinant = math.sqrt(s_Discriminant)
		local t1 = (-B + s_Determinant) / (2 * A)
		local t2 = (-B - s_Determinant) / (2 * A)

		if t1 > 0 then
			if t2 > 0 then
				return math.min(t1, t2)
			else
				return t1
			end
		else
			return math.max(t2, 0.0)
		end
	else
		return (p_Bot._DistanceToPlayer / p_Speed)
	end
end

---@param p_Bot Bot
---@param p_BotSoldier SoldierEntity
---@param p_DeltaTime number
local function _DefaultAimingAction(p_Bot, p_BotSoldier, p_DeltaTime)
	if not p_Bot._Shoot or p_Bot.m_ActiveWeapon == nil then
		return
	end
	local s_ShootPlayer = p_Bot._ShootPlayer
	---@cast s_ShootPlayer -nil
	local s_TargetSoldier = s_ShootPlayer.soldier
	if s_TargetSoldier == nil then
		return
	end

	local s_ActiveWeaponType = p_Bot.m_ActiveWeapon.type
	-- Every access of an engine object and all Vec3 math allocate. Read each object once and calculate
	-- with plain numbers.
	local s_BotTrans = p_BotSoldier.worldTransform.trans
	local s_BotX = s_BotTrans.x
	local s_BotY = s_BotTrans.y + m_Utilities:getTargetHeight(p_BotSoldier, false, false)
	local s_BotZ = s_BotTrans.z

	-- Interpolate target-player movement.
	local s_PitchCorrection = 0.0
	local s_TargetX, s_TargetY, s_TargetZ

	if p_Bot._ShootPlayerVehicleType == VehicleTypes.MavBot or p_Bot._ShootPlayerVehicleType == VehicleTypes.MobileArtillery then
		---@diagnostic disable-next-line: need-check-nil
		local s_TargetTrans = s_ShootPlayer.controlledControllable.transform.trans
		s_TargetX, s_TargetY, s_TargetZ = s_TargetTrans.x, s_TargetTrans.y, s_TargetTrans.z
	else
		local s_AimForHead = false

		if s_ActiveWeaponType == WeaponTypes.Sniper then
			s_AimForHead = Config.AimForHeadSniper
		elseif s_ActiveWeaponType == WeaponTypes.LMG then
			s_AimForHead = Config.AimForHeadSupport
		else
			s_AimForHead = Config.AimForHead
		end

		local s_TargetTrans = s_TargetSoldier.worldTransform.trans
		s_TargetX = s_TargetTrans.x
		s_TargetY = s_TargetTrans.y + m_Utilities:getTargetHeight(s_TargetSoldier, true, s_AimForHead)
		s_TargetZ = s_TargetTrans.z
	end

	local s_Velocity
	if p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
		s_Velocity = s_TargetSoldier.velocity
	else
		---@diagnostic disable-next-line: need-check-nil
		s_Velocity = s_ShootPlayer.controlledControllable.velocity
	end
	local s_VelX, s_VelY, s_VelZ = s_Velocity.x, s_Velocity.y, s_Velocity.z
	local s_MoveX, s_MoveY, s_MoveZ = s_VelX, s_VelY, s_VelZ

	-- Calculate how long the distance is → time to travel.
	local s_DiffX = s_TargetX - s_BotX
	local s_DiffY = s_TargetY - s_BotY
	local s_DiffZ = s_TargetZ - s_BotZ
	p_Bot._DistanceToPlayer = math.sqrt(s_DiffX * s_DiffX + s_DiffY * s_DiffY + s_DiffZ * s_DiffZ)

	-- Aim error only for normal weapons. Not for nades, rockets, missiles, ...
	local s_UseAimError = s_ActiveWeaponType <= WeaponTypes.Sniper
	local s_SkillFactor = p_Bot:GetAimSkillFactor()
	local s_AimError = Config.BotAimError

	if s_ActiveWeaponType == WeaponTypes.Sniper then
		s_AimError = Config.BotSniperAimError
	elseif s_ActiveWeaponType == WeaponTypes.LMG then
		s_AimError = Config.BotSupportAimError
	end

	local s_ErrorScale = p_Bot:GetAimErrorScale(s_AimError)

	if not p_Bot.m_KnifeMode then
		-- Lead with the movement the bot perceives: it notices changes of the direction late, so the aim lags behind
		-- a strafing target: aim = target + seenVelocity * timeToTravel + (seenVelocity - velocity) * lag.
		local s_TrackingLag = 0.0
		if s_UseAimError then
			s_TrackingLag = Registry.BOT.AIM_TRACKING_LAG * (0.5 + 0.5 * s_SkillFactor) * s_ErrorScale
		end
		local s_SeenVelX, s_SeenVelY, s_SeenVelZ = p_Bot:UpdateSeenVelocity(p_DeltaTime, s_TrackingLag, s_VelX, s_VelY, s_VelZ)

		local s_Drop = 0.0
		local s_Speed = 0.0
		local s_TimeToTravel = 0.0
		s_Drop = p_Bot.m_ActiveWeapon.bulletDrop
		s_Speed = p_Bot.m_ActiveWeapon.bulletSpeed

		if s_ActiveWeaponType < WeaponTypes.Rocket then
			s_TimeToTravel = _GetTimeToTravel(p_Bot, s_Speed, s_DiffX, s_DiffY, s_DiffZ, s_SeenVelX, s_SeenVelY, s_SeenVelZ)
			s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop
		elseif s_ActiveWeaponType == WeaponTypes.Rocket then -- No idea why, but works this way...
			s_TimeToTravel = _GetTimeToTravel(p_Bot, s_Speed, s_DiffX, s_DiffY, s_DiffZ, s_SeenVelX, s_SeenVelY, s_SeenVelZ)
			s_PitchCorrection = 0.25 * s_TimeToTravel * s_TimeToTravel * s_Drop
		end

		s_MoveX = s_SeenVelX * s_TimeToTravel + (s_SeenVelX - s_VelX) * s_TrackingLag
		s_MoveY = s_SeenVelY * s_TimeToTravel + (s_SeenVelY - s_VelY) * s_TrackingLag
		s_MoveZ = s_SeenVelZ * s_TimeToTravel + (s_SeenVelZ - s_VelZ) * s_TrackingLag
	end

	local s_DifferenceY = 0
	local s_DifferenceX = 0
	local s_DifferenceZ = 0

	-- Calculate yaw and pitch.
	local s_LastSeen = p_Bot._LastSeenPosition
	local s_GrenadePitch = nil
	if s_ActiveWeaponType == WeaponTypes.Grenade and s_LastSeen then
		-- Throw at the position the target was seen last, not at where it is now.
		s_DifferenceZ = s_LastSeen.z - s_BotZ
		s_DifferenceX = s_LastSeen.x - s_BotX
		s_GrenadePitch = p_Bot:GetGrenadePitch(math.sqrt(s_DifferenceZ * s_DifferenceZ + s_DifferenceX * s_DifferenceX),
			s_LastSeen.y - s_BotTrans.y) or QUARTER_PI -- Out of reach: max range.
	elseif p_Bot.m_KnifeMode and #p_Bot._KnifeWayPositions > 0 then
		local s_KnifeWayPosition = p_Bot._KnifeWayPositions[1]
		s_DifferenceZ = s_KnifeWayPosition.z - s_BotTrans.z
		s_DifferenceX = s_KnifeWayPosition.x - s_BotTrans.x

		if s_BotTrans:Distance(s_KnifeWayPosition) < 1.5 then
			table.remove(p_Bot._KnifeWayPositions, 1)
		end
	else
		s_DifferenceZ = s_DiffZ + s_MoveZ
		s_DifferenceX = s_DiffX + s_MoveX
		s_DifferenceY = s_DiffY + s_MoveY + s_PitchCorrection
	end

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Pitch = 0.0

	if s_GrenadePitch then
		s_Pitch = s_GrenadePitch
	else
		local s_Distance = math.sqrt((s_DifferenceZ * s_DifferenceZ) + (s_DifferenceX * s_DifferenceX))
		s_Pitch = math.atan(s_DifferenceY, s_Distance)
	end

	-- Humanlike aim error: an angle (not a distance), so hits get rarer on greater distances.
	if s_UseAimError then
		local s_Registry = Registry.BOT

		-- Harder to aim while moving and at targets crossing the view fast. Only the movement of the target counts
		-- for that, the own movement is known and part of AIM_ERROR_SELF_SPEED.
		local s_BotVelocity = p_BotSoldier.velocity
		local s_BotVelX, s_BotVelZ = s_BotVelocity.x, s_BotVelocity.z
		local s_BotSpeed = math.sqrt(s_BotVelX * s_BotVelX + s_BotVelZ * s_BotVelZ)
		local s_AngularSpeed = m_Utilities:GetAngularSpeed(s_DiffX, s_DiffY, s_DiffZ, p_Bot._DistanceToPlayer,
			s_VelX, s_VelY, s_VelZ)

		-- More care on greater distances: the angle shrinks, the miss in m still grows (with the square root by default).
		local s_Distance = math.max(p_Bot._DistanceToPlayer, s_Registry.AIM_ERROR_MIN_DISTANCE)
		local s_DistanceFactor = (s_Registry.AIM_ERROR_REFERENCE_DISTANCE / s_Distance) ^ s_Registry.AIM_ERROR_DISTANCE_EXPONENT

		local s_Sigma = (s_AimError * 0.001 * s_DistanceFactor * (1.0 + s_Registry.AIM_ERROR_SELF_SPEED * s_BotSpeed) +
			s_AngularSpeed * s_Registry.AIM_TRACKING_ERROR * s_ErrorScale) * s_SkillFactor
		local s_ErrorYaw, s_ErrorPitch = p_Bot:UpdateAimError(p_DeltaTime, s_Sigma, s_ErrorScale, s_Yaw, s_Pitch, true)

		-- Better bots control the recoil better. The spread can't be known, only emulate aiming down sights: from the hip
		-- on short distances, down the sights on greater ones.
		local s_RecoilControl = Config.BotRecoilControlBest +
			(Config.BotRecoilControlWorst - Config.BotRecoilControlBest) * p_Bot.m_Inaccuracy
		local s_SightsShare = (s_Distance - s_Registry.AIM_SPREAD_COMPENSATION_NEAR_DISTANCE) /
			(s_Registry.AIM_SPREAD_COMPENSATION_FAR_DISTANCE - s_Registry.AIM_SPREAD_COMPENSATION_NEAR_DISTANCE)
		s_SightsShare = math.min(math.max(s_SightsShare, 0.0), 1.0)
		local s_SpreadCompensation = s_Registry.AIM_SPREAD_COMPENSATION_NEAR +
			(s_Registry.AIM_SPREAD_COMPENSATION_FAR - s_Registry.AIM_SPREAD_COMPENSATION_NEAR) * s_SightsShare
		local s_RecoilCompensationPitch, s_RecoilCompensationYaw = _CompensateRecoil(p_BotSoldier, s_RecoilControl,
			s_SpreadCompensation)

		-- Recoil from gunSway is negative → add recoil to yaw.
		s_Yaw = s_Yaw + s_ErrorYaw + s_RecoilCompensationYaw
		s_Pitch = s_Pitch + s_ErrorPitch + s_RecoilCompensationPitch
	end

	p_Bot._TargetPitch = s_Pitch
	p_Bot._TargetYaw = s_Yaw
end

---@param p_Bot Bot
local function _ReviveAimingAction(p_Bot)
	if p_Bot._ShootPlayer.corpse == nil or p_Bot._ShootPlayer.corpse.physicsEntityBase == nil
		or p_Bot._ShootPlayer.corpse.physicsEntityBase.position == nil then
		return
	end

	local s_PositionTarget = p_Bot._ShootPlayer.corpse.physicsEntityBase.position:Clone()
	local s_PositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
		m_Utilities:getCameraPos(p_Bot.m_Player, false, false)

	local s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
	local s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
	local s_DifferenceY = s_PositionTarget.y - s_PositionBot.y

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	p_Bot._TargetPitch = s_Pitch
	p_Bot._TargetYaw = s_Yaw
end

---@param p_Bot Bot
local function _RepairAimingAction(p_Bot)
	if p_Bot:UpdateRepairVehicleEntity() == nil then
		return
	end

	-- Aim at vehicle.
	local s_PositionTarget = p_Bot._RepairVehicleEntity.transform.trans:Clone()
	local s_PositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(p_Bot.m_Player, false, false)

	local s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
	local s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
	local s_DifferenceY = s_PositionTarget.y - s_PositionBot.y

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	p_Bot._TargetPitch = s_Pitch
	p_Bot._TargetYaw = s_Yaw
end

---@param p_DeltaTime number
function Bot:UpdateAiming(p_DeltaTime)
	local s_Soldier = self._ShootPlayer and self.m_Player.soldier
	if not s_Soldier then
		return
	end

	if self._ActiveAction == BotActionFlags.ReviveActive then
		_ReviveAimingAction(self)
	elseif self._ActiveAction == BotActionFlags.RepairActive then
		_RepairAimingAction(self)
	else
		_DefaultAimingAction(self, s_Soldier, p_DeltaTime)
	end
end
