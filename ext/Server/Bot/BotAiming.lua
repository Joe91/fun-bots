---@class BotAiming
BotAiming = class('BotAiming')

---@type Utilities
local m_Utilities = require('__shared/Utilities')

function BotAiming:__init()
	-- nothing to do
end

function BotAiming:UpdateAiming(p_Bot)
	if p_Bot._ShootPlayer == nil then
		return
	end

	if p_Bot._ActiveAction ~= BotActionFlags.ReviveActive and p_Bot._ActiveAction ~= BotActionFlags.RepairActive then
		if not p_Bot._Shoot or p_Bot._ShootPlayer.soldier == nil or p_Bot.m_ActiveWeapon == nil then
			return
		end

		--interpolate target-player movement
		local s_TargetMovement = Vec3.zero
		local s_PitchCorrection = 0.0
		local s_FullPositionTarget = nil
		local s_FullPositionBot = nil

		s_FullPositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
			m_Utilities:getCameraPos(p_Bot.m_Player, false, false)

		if p_Bot._ShootPlayerVehicleType == VehicleTypes.MavBot then
			s_FullPositionTarget = p_Bot._ShootPlayer.controlledControllable.transform.trans:Clone()
		else
			local s_AimForHead = false
			local s_AdditionalOffset = Vec3.zero
			if p_Bot.m_ActiveWeapon.type == WeaponTypes.Sniper then
				s_AimForHead = Config.AimForHeadSniper
			elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.LMG then
				s_AimForHead = Config.AimForHeadSupport
			else
				s_AimForHead = Config.AimForHead
			end

			s_FullPositionTarget = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
			s_FullPositionTarget = s_FullPositionTarget + m_Utilities:getCameraPos(p_Bot._ShootPlayer, true, s_AimForHead) +
				s_AdditionalOffset
		end

		if p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
			s_TargetMovement = PhysicsEntity(p_Bot._ShootPlayer.soldier).velocity
		else
			s_TargetMovement = PhysicsEntity(p_Bot._ShootPlayer.controlledControllable).velocity
		end

		local s_GrenadePitch = 0.0
		--calculate how long the distance is --> time to travel
		p_Bot._DistanceToPlayer = s_FullPositionTarget:Distance(s_FullPositionBot)

		if not p_Bot.m_KnifeMode then
			local s_Drop = 0.0
			local s_Speed = 0.0
			local s_TimeToTravel = 0.0
			s_Drop = p_Bot.m_ActiveWeapon.bulletDrop
			s_Speed = p_Bot.m_ActiveWeapon.bulletSpeed

			if p_Bot.m_ActiveWeapon.type == WeaponTypes.Grenade then
				if p_Bot._DistanceToPlayer < 3.0 then
					p_Bot._DistanceToPlayer = 3.0 -- don't throw them too close..
				end

				if p_Bot._DistanceToPlayer > 24.5 then s_GrenadePitch = 0.7504915783575616
				elseif p_Bot._DistanceToPlayer > 24.0 then s_GrenadePitch = 0.8569566627292158
				elseif p_Bot._DistanceToPlayer > 23.5 then s_GrenadePitch = 0.9023352232810685
				elseif p_Bot._DistanceToPlayer > 23.0 then s_GrenadePitch = 0.9372418083209549
				elseif p_Bot._DistanceToPlayer > 22.5 then s_GrenadePitch = 0.9651670763528643
				elseif p_Bot._DistanceToPlayer > 22.0 then s_GrenadePitch = 0.9913470151327791
				elseif p_Bot._DistanceToPlayer > 21.5 then s_GrenadePitch = 1.0157816246606999
				elseif p_Bot._DistanceToPlayer > 21.0 then s_GrenadePitch = 1.0367255756846316
				elseif p_Bot._DistanceToPlayer > 20.5 then s_GrenadePitch = 1.0559241974565694
				elseif p_Bot._DistanceToPlayer > 20.0 then s_GrenadePitch = 1.0751228192285072
				elseif p_Bot._DistanceToPlayer > 19.5 then s_GrenadePitch = 1.0943214410004447
				elseif p_Bot._DistanceToPlayer > 19.0 then s_GrenadePitch = 1.111774733520388
				elseif p_Bot._DistanceToPlayer > 18.5 then s_GrenadePitch = 1.1274826967883367
				elseif p_Bot._DistanceToPlayer > 18.0 then s_GrenadePitch = 1.143190660056286
				elseif p_Bot._DistanceToPlayer > 17.5 then s_GrenadePitch = 1.1588986233242349
				elseif p_Bot._DistanceToPlayer > 17.0 then s_GrenadePitch = 1.1746065865921838
				elseif p_Bot._DistanceToPlayer > 16.5 then s_GrenadePitch = 1.1885692206081382
				elseif p_Bot._DistanceToPlayer > 16.0 then s_GrenadePitch = 1.202531854624093
				elseif p_Bot._DistanceToPlayer > 15.5 then s_GrenadePitch = 1.2164944886400477
				elseif p_Bot._DistanceToPlayer > 15.0 then s_GrenadePitch = 1.2304571226560022
				elseif p_Bot._DistanceToPlayer > 14.5 then s_GrenadePitch = 1.2426744274199626
				elseif p_Bot._DistanceToPlayer > 14.0 then s_GrenadePitch = 1.2566370614359172
				elseif p_Bot._DistanceToPlayer > 13.5 then s_GrenadePitch = 1.2688543661998775
				elseif p_Bot._DistanceToPlayer > 13.0 then s_GrenadePitch = 1.281071670963838
				elseif p_Bot._DistanceToPlayer > 12.5 then s_GrenadePitch = 1.293288975727798
				elseif p_Bot._DistanceToPlayer > 12.0 then s_GrenadePitch = 1.3055062804917585
				elseif p_Bot._DistanceToPlayer > 11.5 then s_GrenadePitch = 1.3177235852557188
				elseif p_Bot._DistanceToPlayer > 11.0 then s_GrenadePitch = 1.3299408900196792
				elseif p_Bot._DistanceToPlayer > 10.5 then s_GrenadePitch = 1.3421581947836394
				elseif p_Bot._DistanceToPlayer > 10.0 then s_GrenadePitch = 1.3526301702956054
				elseif p_Bot._DistanceToPlayer > 9.5 then s_GrenadePitch = 1.3648474750595656
				elseif p_Bot._DistanceToPlayer > 9.0 then s_GrenadePitch = 1.377064779823526
				elseif p_Bot._DistanceToPlayer > 8.5 then s_GrenadePitch = 1.387536755335492
				elseif p_Bot._DistanceToPlayer > 8.0 then s_GrenadePitch = 1.3980087308474578
				elseif p_Bot._DistanceToPlayer > 7.5 then s_GrenadePitch = 1.4102260356114182
				elseif p_Bot._DistanceToPlayer > 7.0 then s_GrenadePitch = 1.4206980111233845
				elseif p_Bot._DistanceToPlayer > 6.5 then s_GrenadePitch = 1.43116998663535
				elseif p_Bot._DistanceToPlayer > 6.0 then s_GrenadePitch = 1.4433872913993104
				elseif p_Bot._DistanceToPlayer > 5.5 then s_GrenadePitch = 1.4538592669112764
				elseif p_Bot._DistanceToPlayer > 5.0 then s_GrenadePitch = 1.4643312424232426
				elseif p_Bot._DistanceToPlayer > 4.5 then s_GrenadePitch = 1.4748032179352084
				elseif p_Bot._DistanceToPlayer > 4.0 then s_GrenadePitch = 1.4852751934471744
				elseif p_Bot._DistanceToPlayer > 3.5 then s_GrenadePitch = 1.4957471689591406
				elseif p_Bot._DistanceToPlayer > 3.0 then s_GrenadePitch = 1.5079644737231006
				elseif p_Bot._DistanceToPlayer > 2.5 then s_GrenadePitch = 1.5184364492350666
				elseif p_Bot._DistanceToPlayer > 2.0 then s_GrenadePitch = 1.5289084247470324
				elseif p_Bot._DistanceToPlayer > 1.5 then s_GrenadePitch = 1.5393804002589986
				elseif p_Bot._DistanceToPlayer > 1.0 then s_GrenadePitch = 1.5498523757709646
				elseif p_Bot._DistanceToPlayer > 0.5 then s_GrenadePitch = 1.5603243512829308
				end
			else
				if Registry.BOT.USE_ADVANCED_AIMING then
					--calculate how long the distance is --> time to travel
					local s_VectorBetween = s_FullPositionTarget - s_FullPositionBot

					local A = s_TargetMovement:Dot(s_TargetMovement) - s_Speed * s_Speed
					local B = 2.0 * s_TargetMovement:Dot(s_VectorBetween)
					local C = s_VectorBetween:Dot(s_VectorBetween)
					local s_Determinant = math.sqrt(B * B - 4 * A * C)
					local t1 = (-B + s_Determinant) / (2 * A)
					local t2 = (-B - s_Determinant) / (2 * A)

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
					s_TimeToTravel = (p_Bot._DistanceToPlayer / s_Speed)
				end

				s_PitchCorrection = 0.25 * s_TimeToTravel * s_TimeToTravel * s_Drop -- this correction (0.5 * 0.5) seems to be correct. No idea why.
			end

			s_TargetMovement = (s_TargetMovement * s_TimeToTravel)

		end

		local s_DifferenceY = 0
		local s_DifferenceX = 0
		local s_DifferenceZ = 0

		--calculate yaw and pitch
		if p_Bot.m_KnifeMode and #p_Bot._KnifeWayPositions > 0 then
			s_DifferenceZ = p_Bot._KnifeWayPositions[1].z - p_Bot.m_Player.soldier.worldTransform.trans.z
			s_DifferenceX = p_Bot._KnifeWayPositions[1].x - p_Bot.m_Player.soldier.worldTransform.trans.x

			if p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Bot._KnifeWayPositions[1]) < 1.5 then
				table.remove(p_Bot._KnifeWayPositions, 1)
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

		if p_Bot.m_ActiveWeapon.type == WeaponTypes.Grenade then
			s_Pitch = s_GrenadePitch
		else
			local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
			s_Pitch = math.atan(s_DifferenceY, s_Distance)
		end

		-- worsen yaw and pitch depending on bot-skill. Don't use Skill for Nades and Rockets.
		if p_Bot.m_ActiveWeapon.type ~= WeaponTypes.Grenade and p_Bot.m_ActiveWeapon.type ~= WeaponTypes.Rocket then
			local s_SkillFactor = p_Bot._Skill / p_Bot._DistanceToPlayer
			local s_WorseningSkillX = (MathUtils:GetRandom(-1.0, 1.0) * s_SkillFactor) -- value scaled in offset in 1m
			local s_WorseningSkillY = (MathUtils:GetRandom(-1.0, 1.0) * s_SkillFactor) -- value scaled in offset in 1m

			local s_WorseningClassFactor = 0
			if p_Bot.m_Kit == BotKits.Support then
				s_WorseningClassFactor = Config.BotSupportAimWorsening
			elseif p_Bot.m_Kit == BotKits.Recon then
				s_WorseningClassFactor = Config.BotSniperAimWorsening
			else
				s_WorseningClassFactor = Config.BotAimWorsening
			end
			s_WorseningClassFactor = s_WorseningClassFactor / p_Bot._DistanceToPlayer

			local s_WorseningClassX = (MathUtils:GetRandom(-1.0, 1.0) * s_WorseningClassFactor)
			local s_WorseningClassY = (MathUtils:GetRandom(-1.0, 1.0) * s_WorseningClassFactor)

			local s_RecoilPitch = 0.0
			local s_RecoilYaw = 0.0
			-- compensate recoil
			if p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway ~= nil then
				s_RecoilPitch = p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.currentRecoilDeviation.pitch
				s_RecoilYaw = p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.currentRecoilDeviation.yaw
			end
			-- recoil is negative --> add them
			--print(s_RecoilPitch)

			s_Yaw = s_Yaw + s_WorseningSkillX + s_WorseningClassX + s_RecoilYaw
			s_Pitch = s_Pitch + s_WorseningSkillY + s_WorseningClassY + s_RecoilPitch
		end

		p_Bot._TargetPitch = s_Pitch
		p_Bot._TargetYaw = s_Yaw

	elseif p_Bot._ActiveAction == BotActionFlags.RepairActive then -- repair
		if p_Bot._ShootPlayer == nil or p_Bot._ShootPlayer.soldier == nil or p_Bot._RepairVehicleEntity == nil then
			return
		end
		local s_PositionTarget = p_Bot._RepairVehicleEntity.transform.trans:Clone() -- aim at vehicle
		local s_PositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
			m_Utilities:getCameraPos(p_Bot.m_Player, false, false)

		local s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
		local s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
		local s_DifferenceY = s_PositionTarget.y - s_PositionBot.y

		local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
		local s_Pitch = math.atan(s_DifferenceY, s_Distance)

		p_Bot._TargetPitch = s_Pitch
		p_Bot._TargetYaw = s_Yaw

	else -- revive active
		if p_Bot._ShootPlayer.corpse == nil then
			return
		end

		local s_PositionTarget = p_Bot._ShootPlayer.corpse.worldTransform.trans:Clone()
		local s_PositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
			m_Utilities:getCameraPos(p_Bot.m_Player, false, false)

		local s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
		local s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
		local s_DifferenceY = s_PositionTarget.y - s_PositionBot.y

		local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
		local s_Pitch = math.atan(s_DifferenceY, s_Distance)

		p_Bot._TargetPitch = s_Pitch
		p_Bot._TargetYaw = s_Yaw
	end
end

if g_BotAiming == nil then
	---@type BotAiming
	g_BotAiming = BotAiming()
end

return g_BotAiming
