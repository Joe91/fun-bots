---@type Utilities
local m_Utilities = require('__shared/Utilities')

---@param p_Distance number
---@return number
local function _GetGrenadePitch(p_Distance)
	if p_Distance > 24.5 then
		return 0.7504915783575616
	elseif p_Distance > 24.0 then
		return 0.8569566627292158
	elseif p_Distance > 23.5 then
		return 0.9023352232810685
	elseif p_Distance > 23.0 then
		return 0.9372418083209549
	elseif p_Distance > 22.5 then
		return 0.9651670763528643
	elseif p_Distance > 22.0 then
		return 0.9913470151327791
	elseif p_Distance > 21.5 then
		return 1.0157816246606999
	elseif p_Distance > 21.0 then
		return 1.0367255756846316
	elseif p_Distance > 20.5 then
		return 1.0559241974565694
	elseif p_Distance > 20.0 then
		return 1.0751228192285072
	elseif p_Distance > 19.5 then
		return 1.0943214410004447
	elseif p_Distance > 19.0 then
		return 1.111774733520388
	elseif p_Distance > 18.5 then
		return 1.1274826967883367
	elseif p_Distance > 18.0 then
		return 1.143190660056286
	elseif p_Distance > 17.5 then
		return 1.1588986233242349
	elseif p_Distance > 17.0 then
		return 1.1746065865921838
	elseif p_Distance > 16.5 then
		return 1.1885692206081382
	elseif p_Distance > 16.0 then
		return 1.202531854624093
	elseif p_Distance > 15.5 then
		return 1.2164944886400477
	elseif p_Distance > 15.0 then
		return 1.2304571226560022
	elseif p_Distance > 14.5 then
		return 1.2426744274199626
	elseif p_Distance > 14.0 then
		return 1.2566370614359172
	elseif p_Distance > 13.5 then
		return 1.2688543661998775
	elseif p_Distance > 13.0 then
		return 1.281071670963838
	elseif p_Distance > 12.5 then
		return 1.293288975727798
	elseif p_Distance > 12.0 then
		return 1.3055062804917585
	elseif p_Distance > 11.5 then
		return 1.3177235852557188
	elseif p_Distance > 11.0 then
		return 1.3299408900196792
	elseif p_Distance > 10.5 then
		return 1.3421581947836394
	elseif p_Distance > 10.0 then
		return 1.3526301702956054
	elseif p_Distance > 9.5 then
		return 1.3648474750595656
	elseif p_Distance > 9.0 then
		return 1.377064779823526
	elseif p_Distance > 8.5 then
		return 1.387536755335492
	elseif p_Distance > 8.0 then
		return 1.3980087308474578
	elseif p_Distance > 7.5 then
		return 1.4102260356114182
	elseif p_Distance > 7.0 then
		return 1.4206980111233845
	elseif p_Distance > 6.5 then
		return 1.43116998663535
	elseif p_Distance > 6.0 then
		return 1.4433872913993104
	elseif p_Distance > 5.5 then
		return 1.4538592669112764
	elseif p_Distance > 5.0 then
		return 1.4643312424232426
	elseif p_Distance > 4.5 then
		return 1.4748032179352084
	elseif p_Distance > 4.0 then
		return 1.4852751934471744
	elseif p_Distance > 3.5 then
		return 1.4957471689591406
	elseif p_Distance > 3.0 then
		return 1.5079644737231006
	elseif p_Distance > 2.5 then
		return 1.5184364492350666
	elseif p_Distance > 2.0 then
		return 1.5289084247470324
	elseif p_Distance > 1.5 then
		return 1.5393804002589986
	elseif p_Distance > 1.0 then
		return 1.5498523757709646
	else
		return 1.5603243512829308
	end
end

---@param p_Soldier SoldierEntity
---@param p_Skill number
---@return number compensationPitch
---@return number compensationYaw
local function _CompensateRecoil(p_Soldier, p_Skill)
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

	local s_CurrentRecoilDeviationPitch = s_CurrentRecoilDeviation.pitch + s_CurrentDispersionDeviation.pitch
	local s_CurrentRecoilDeviationYaw = s_CurrentRecoilDeviation.yaw + s_CurrentDispersionDeviation.yaw

	-- Worsen compensation dependant on skill?
	local s_SkillFactorRecoil = (1.0 - p_Skill) -- only use range from 0.5 to 1.0

	if s_SkillFactorRecoil < 0 then
		s_SkillFactorRecoil = 0.0
	end

	return s_CurrentRecoilDeviationPitch * s_SkillFactorRecoil, s_CurrentRecoilDeviationYaw * s_SkillFactorRecoil
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
	if Registry.BOT.USE_ADVANCED_AIMING then
		-- Calculate how long the distance is → time to travel.
		local A = (p_MoveX * p_MoveX + p_MoveY * p_MoveY + p_MoveZ * p_MoveZ) - p_Speed * p_Speed
		local B = 2.0 * (p_MoveX * p_DiffX + p_MoveY * p_DiffY + p_MoveZ * p_DiffZ)
		local C = p_DiffX * p_DiffX + p_DiffY * p_DiffY + p_DiffZ * p_DiffZ
		local s_Determinant = math.sqrt(B * B - 4 * A * C)
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
local function _DefaultAimingAction(p_Bot, p_BotSoldier)
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
	local s_MoveX, s_MoveY, s_MoveZ = s_Velocity.x, s_Velocity.y, s_Velocity.z

	-- Calculate how long the distance is → time to travel.
	local s_DiffX = s_TargetX - s_BotX
	local s_DiffY = s_TargetY - s_BotY
	local s_DiffZ = s_TargetZ - s_BotZ
	p_Bot._DistanceToPlayer = math.sqrt(s_DiffX * s_DiffX + s_DiffY * s_DiffY + s_DiffZ * s_DiffZ)

	if not p_Bot.m_KnifeMode then
		local s_Drop = 0.0
		local s_Speed = 0.0
		local s_TimeToTravel = 0.0
		s_Drop = p_Bot.m_ActiveWeapon.bulletDrop
		s_Speed = p_Bot.m_ActiveWeapon.bulletSpeed

		if s_ActiveWeaponType == WeaponTypes.Grenade then
			if p_Bot._DistanceToPlayer < 3.0 then
				p_Bot._DistanceToPlayer = 3.0 -- Don't throw them too close.
			end
		elseif s_ActiveWeaponType < WeaponTypes.Rocket then
			s_TimeToTravel = _GetTimeToTravel(p_Bot, s_Speed, s_DiffX, s_DiffY, s_DiffZ, s_MoveX, s_MoveY, s_MoveZ)
			s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop
		elseif s_ActiveWeaponType == WeaponTypes.Rocket then -- No idea why, but works this way...
			s_TimeToTravel = _GetTimeToTravel(p_Bot, s_Speed, s_DiffX, s_DiffY, s_DiffZ, s_MoveX, s_MoveY, s_MoveZ)
			s_PitchCorrection = 0.25 * s_TimeToTravel * s_TimeToTravel * s_Drop
		end

		s_MoveX = s_MoveX * s_TimeToTravel
		s_MoveY = s_MoveY * s_TimeToTravel
		s_MoveZ = s_MoveZ * s_TimeToTravel
	end

	local s_DifferenceY = 0
	local s_DifferenceX = 0
	local s_DifferenceZ = 0

	-- Calculate yaw and pitch.
	if p_Bot.m_KnifeMode and #p_Bot._KnifeWayPositions > 0 then
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

	if s_ActiveWeaponType == WeaponTypes.Grenade then
		s_Pitch = _GetGrenadePitch(p_Bot._DistanceToPlayer)
	else
		local s_Distance = math.sqrt((s_DifferenceZ * s_DifferenceZ) + (s_DifferenceX * s_DifferenceX))
		s_Pitch = math.atan(s_DifferenceY, s_Distance)
	end

	-- Worsen yaw and pitch depending on bot-skill. Don't use Skill for Nades, Rockets, Missiles, ...
	if s_ActiveWeaponType <= WeaponTypes.Sniper then -- All normal weapons.
		-- Skaling: Worsening of 1.0 should be up to 1 meter off of target without modifier.
		local s_DistanceFactor = 1.0 / (p_Bot._DistanceToPlayer * Registry.BOT.WORSENING_FACTOR_DISTANCE)

		-- Determine base worsening factor based on weapon type and class
		local s_AimWorseningBase = Config.BotAimWorsening
		local s_SkillCompensation = Config.BotWorseningSkill * p_Bot.m_Accuracy -- full range from 0.0 to Max-Skill for Recoul-Compensation

		if s_ActiveWeaponType == WeaponTypes.Sniper then
			s_AimWorseningBase = Config.BotSniperAimWorsening
			s_SkillCompensation = Config.BotSniperWorseningSkill * p_Bot.m_Accuracy -- full range from 0.0 to Max-Skill for Recoul-Compensation
		elseif s_ActiveWeaponType == WeaponTypes.LMG then
			s_AimWorseningBase = Config.BotSupportAimWorsening
		end

		-- Apply accuracy modifier (±50% based on bot accuracy)
		local s_AimWorseningSkill = s_AimWorseningBase + s_AimWorseningBase * (p_Bot.m_Accuracy - 0.5)

		local s_SkillFactor = s_AimWorseningSkill * s_DistanceFactor
		local s_WorseningSkillX = (MathUtils:GetRandom(-1.0, 1.0) * s_SkillFactor)
		local s_WorseningSkillY = (MathUtils:GetRandom(-1.0, 1.0) * s_SkillFactor)

		-- Compensate for recoil based on accuracy
		local s_RecoilCompensationPitch, s_RecoilCompensationYaw = _CompensateRecoil(p_BotSoldier, s_SkillCompensation)

		-- Recoil from gunSway is negative → add recoil to yaw.
		s_Yaw = s_Yaw + s_WorseningSkillX + s_RecoilCompensationYaw
		s_Pitch = s_Pitch + s_WorseningSkillY + s_RecoilCompensationPitch
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

function Bot:UpdateAiming()
	local s_Soldier = self._ShootPlayer and self.m_Player.soldier
	if not s_Soldier then
		return
	end

	if self._ActiveAction == BotActionFlags.ReviveActive then
		_ReviveAimingAction(self)
	elseif self._ActiveAction == BotActionFlags.RepairActive then
		_RepairAimingAction(self)
	else
		_DefaultAimingAction(self, s_Soldier)
	end
end
