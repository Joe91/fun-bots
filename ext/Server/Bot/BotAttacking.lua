---@class BotAttacking
---@overload fun():BotAttacking
BotAttacking = class('BotAttacking')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")

function BotAttacking:__init()
	-- nothing to do
end

function BotAttacking:UpdateAttacking(p_Bot)
	if p_Bot._ShootPlayer.soldier ~= nil and
		p_Bot._ActiveAction ~= BotActionFlags.EnterVehicleActive and
		p_Bot._ActiveAction ~= BotActionFlags.RepairActive and
		p_Bot._ActiveAction ~= BotActionFlags.ReviveActive and
		p_Bot._Shoot then
		if (p_Bot._ShootModeTimer < Config.BotFireModeDuration) or
			(Config.ZombieMode and p_Bot._ShootModeTimer < (Config.BotFireModeDuration * 4)) then

			if p_Bot._ActiveAction ~= BotActionFlags.C4Active then
				p_Bot:_SetInput(EntryInputActionEnum.EIAZoom, 1) -- does not work yet :-/
				p_Bot.m_Player.input.zoomLevel = 1
			end

			if p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive then
				p_Bot._ShootModeTimer = p_Bot._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
			end

			p_Bot._ReloadTimer = 0.0 -- reset reloading

			--check for melee attack
			if Config.MeleeAttackIfClose and p_Bot._ActiveAction ~= BotActionFlags.MeleeActive and
				p_Bot._MeleeCooldownTimer <= 0.0 and
				p_Bot._ShootPlayer.soldier.worldTransform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 2 then
				p_Bot._ActiveAction = BotActionFlags.MeleeActive
				p_Bot.m_ActiveWeapon = p_Bot.m_Knife

				p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
				p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
				p_Bot:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
				p_Bot._MeleeCooldownTimer = Config.MeleeAttackCoolDown
			else
				if p_Bot._MeleeCooldownTimer < 0.0 then
					p_Bot._MeleeCooldownTimer = 0.0
				elseif p_Bot._MeleeCooldownTimer > 0.0 then
					p_Bot._MeleeCooldownTimer = p_Bot._MeleeCooldownTimer - Registry.BOT.BOT_UPDATE_CYCLE
					p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
					if p_Bot._MeleeCooldownTimer < (Config.MeleeAttackCoolDown - 0.8) then
						p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
					end
				end
			end

			if p_Bot._ActiveAction == BotActionFlags.GrenadeActive then -- throw grenade
				if p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 0 then
					p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 1
					p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
					p_Bot._ShootModeTimer = p_Bot._ShootModeTimer + 2 * Registry.BOT.BOT_UPDATE_CYCLE
				end
			end

			-- target in vehicle
			if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
				local s_AttackMode = m_Vehicles:CheckForVehicleAttack(p_Bot._ShootPlayerVehicleType, p_Bot._DistanceToPlayer,
					p_Bot.m_SecondaryGadget, false)

				if s_AttackMode ~= VehicleAttackModes.NoAttack then
					if s_AttackMode == VehicleAttackModes.AttackWithNade then -- grenade
						p_Bot._ActiveAction = BotActionFlags.GrenadeActive
					elseif s_AttackMode == VehicleAttackModes.AttackWithRocket or
						s_AttackMode == VehicleAttackModes.AttackWithMissileAir or
						s_AttackMode == WeaponTypes.AttackWithMissileLand then -- rockets and missiles
						p_Bot._WeaponToUse = BotWeapons.Gadget2

						if p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 0 then
							p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 1
						end
					elseif s_AttackMode == VehicleAttackModes.AttackWithC4 then -- C4
						p_Bot._WeaponToUse = BotWeapons.Gadget2
						p_Bot._ActiveAction = BotActionFlags.C4Active
					elseif s_AttackMode == VehicleAttackModes.AttackWithRifle then
						-- TODO: double code is not nice
						if p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive and
							p_Bot.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
							if p_Bot.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 then
								p_Bot._WeaponToUse = BotWeapons.Pistol
							else
								p_Bot._WeaponToUse = BotWeapons.Primary
							end
						end
					end
				else
					p_Bot._ShootModeTimer = Config.BotFireModeDuration -- end attack
				end
			else
				-- target not in vehicle
				-- refill rockets if empty
				if p_Bot.m_ActiveWeapon.type == WeaponTypes.Rocket then
					if p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 0 then
						p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 1
					end
				end

				if p_Bot.m_KnifeMode or p_Bot._ActiveAction == BotActionFlags.MeleeActive then
					p_Bot._WeaponToUse = BotWeapons.Knife
				elseif Globals.IsGm then
					p_Bot._WeaponToUse = BotWeapons.Primary
				else
					if p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive then
						-- check to use pistol
						if p_Bot.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
							if p_Bot.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 and
								p_Bot._DistanceToPlayer <= Config.MaxShootDistancePistol then
								p_Bot._WeaponToUse = BotWeapons.Pistol
							else
								if p_Bot.m_ActiveWeapon.type ~= WeaponTypes.Rocket then

									p_Bot._WeaponToUse = BotWeapons.Primary
									-- check to use rocket
									if p_Bot._ShootModeTimer <= Registry.BOT.BOT_UPDATE_CYCLE + 0.001 and
										p_Bot.m_SecondaryGadget ~= nil and p_Bot.m_SecondaryGadget.type == WeaponTypes.Rocket and
										MathUtils:GetRandomInt(1, 100) <= Registry.BOT.PROBABILITY_SHOOT_ROCKET then
										p_Bot._WeaponToUse = BotWeapons.Gadget2
									end
								end
							end
						end

					end
					-- use grenade from time to time
					if Config.BotsThrowGrenades then
						local s_TargetTimeValue = Config.BotFireModeDuration - (3 * Registry.BOT.BOT_UPDATE_CYCLE)

						if ((p_Bot._ShootModeTimer >= (s_TargetTimeValue - 0.001)) and
							(p_Bot._ShootModeTimer <= (s_TargetTimeValue + Registry.BOT.BOT_UPDATE_CYCLE + 0.001)) and
							p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive) or Config.BotWeapon == BotWeapons.Grenade then
							-- should be triggered only once per fireMode
							if MathUtils:GetRandomInt(1, 100) <= Registry.BOT.PROBABILITY_THROW_GRENADE then
								if p_Bot.m_Grenade ~= nil and p_Bot._DistanceToPlayer < 25.0 then -- algorith only works for up to 25 m
									p_Bot._ActiveAction = BotActionFlags.GrenadeActive
								end
							end
						end
					end
				end
			end

			--trace way back
			if (
				p_Bot.m_ActiveWeapon and p_Bot.m_ActiveWeapon.type ~= WeaponTypes.Sniper and
					p_Bot.m_ActiveWeapon.type ~= WeaponTypes.Rocket and p_Bot.m_ActiveWeapon.type ~= WeaponTypes.MissileAir and
					p_Bot.m_ActiveWeapon.type ~= WeaponTypes.MissileLand) or p_Bot.m_KnifeMode then
				if p_Bot._ShootTraceTimer > Registry.BOT.TRACE_DELTA_SHOOTING then
					--create a Trace to find way back
					p_Bot._ShootTraceTimer = 0.0
					local s_Point = {
						Position = p_Bot.m_Player.soldier.worldTransform.trans:Clone(),
						SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
						ExtraMode = 0,
						OptValue = 0,
					}

					table.insert(p_Bot._ShootWayPoints, s_Point)

					if p_Bot.m_KnifeMode then
						local s_Trans = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
						table.insert(p_Bot._KnifeWayPositions, s_Trans)
					end
				end

				p_Bot._ShootTraceTimer = p_Bot._ShootTraceTimer + Registry.BOT.BOT_UPDATE_CYCLE
			end

			--shooting sequence
			if Globals.IsGm then
				if p_Bot._ShotTimer >= (0.4) then
					p_Bot._ShotTimer = 0.0
				end
				if p_Bot._ShotTimer <= 0.2 then
					p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
				end

				p_Bot._ShotTimer = p_Bot._ShotTimer + Registry.BOT.BOT_UPDATE_CYCLE
			elseif p_Bot.m_ActiveWeapon ~= nil then
				if p_Bot.m_KnifeMode then
					-- nothing to do
					-- C4 Handling
				elseif p_Bot._ActiveAction == BotActionFlags.C4Active then
					if p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo > 0 then
						if p_Bot._ShotTimer >= (p_Bot.m_ActiveWeapon.fireCycle + p_Bot.m_ActiveWeapon.pauseCycle) then
							p_Bot._ShotTimer = 0.0
						end

						if p_Bot._DistanceToPlayer < 5.0 then
							if p_Bot._ShotTimer >= p_Bot.m_ActiveWeapon.pauseCycle then
								p_Bot:_SetInput(EntryInputActionEnum.EIAZoom, 1)
							end
						end
					else
						if p_Bot._ShotTimer >= (p_Bot.m_ActiveWeapon.fireCycle + p_Bot.m_ActiveWeapon.pauseCycle) then
							--TODO: run away from object now
							if p_Bot._ShotTimer >= ((p_Bot.m_ActiveWeapon.fireCycle * 2) + p_Bot.m_ActiveWeapon.pauseCycle) then
								p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
								p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 4
								p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
							end
						end
					end
				else
					if p_Bot._ShotTimer >= (p_Bot.m_ActiveWeapon.fireCycle + p_Bot.m_ActiveWeapon.pauseCycle) then
						p_Bot._ShotTimer = 0.0
					end

					if p_Bot._ShotTimer >= 0.0 and p_Bot._ActiveAction ~= BotActionFlags.MeleeActive then
						if p_Bot.m_ActiveWeapon.delayed == false then
							if p_Bot._ShotTimer <= p_Bot.m_ActiveWeapon.fireCycle then
								p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
							end
						else --start with pause Cycle
							if p_Bot._ShotTimer >= p_Bot.m_ActiveWeapon.pauseCycle then
								p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
							end
						end
					end
				end

				p_Bot._ShotTimer = p_Bot._ShotTimer + Registry.BOT.BOT_UPDATE_CYCLE
			end
		else
			p_Bot._TargetPitch = 0.0
			p_Bot._WeaponToUse = BotWeapons.Primary
			p_Bot:AbortAttack()
			p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
			p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
		end
	elseif p_Bot._ActiveAction == BotActionFlags.ReviveActive then
		if p_Bot._ShootPlayer.corpse ~= nil and not p_Bot._ShootPlayer.corpse.isDead then -- revive
			p_Bot._ShootModeTimer = p_Bot._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
			p_Bot.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : revive
			p_Bot._ReloadTimer = 0.0 -- reset reloading

			--check for revive if close
			if p_Bot._ShootPlayer.corpse.worldTransform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 3 then
				if p_Bot._ShotTimer >= (p_Bot.m_ActiveWeapon.fireCycle + p_Bot.m_ActiveWeapon.pauseCycle) then
					p_Bot._ShotTimer = 0.0
				end
				if p_Bot._ShotTimer <= p_Bot.m_ActiveWeapon.fireCycle then
					p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
				end
			else
				p_Bot._ShotTimer = 0.0
			end
			p_Bot._ShotTimer = p_Bot._ShotTimer + Registry.BOT.BOT_UPDATE_CYCLE

			--trace way back
			if p_Bot._ShootTraceTimer > Registry.BOT.TRACE_DELTA_SHOOTING then
				--create a Trace to find way back
				p_Bot._ShootTraceTimer = 0.0
				local s_Point = {
					Position = p_Bot.m_Player.soldier.worldTransform.trans:Clone(),
					SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
					ExtraMode = 0,
					OptValue = 0,
				}

				table.insert(p_Bot._ShootWayPoints, s_Point)
				if p_Bot.m_KnifeMode then
					local s_Trans = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
					table.insert(p_Bot._KnifeWayPositions, s_Trans)
				end
			end

			p_Bot._ShootTraceTimer = p_Bot._ShootTraceTimer + Registry.BOT.BOT_UPDATE_CYCLE
		else -- soldier alive again
			p_Bot._WeaponToUse = BotWeapons.Primary
			p_Bot._TargetPitch = 0.0
			p_Bot:AbortAttack()
			p_Bot:_ResetActionFlag(BotActionFlags.ReviveActive)
		end
	-- enter vehicle
	elseif p_Bot._ActiveAction == BotActionFlags.EnterVehicleActive and p_Bot._ShootPlayer ~= nil and
		p_Bot._ShootPlayer.soldier ~= nil then
		p_Bot._ShootModeTimer = p_Bot._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
		p_Bot.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : revive

		--check for enter of vehicle if close
		if p_Bot._ShootPlayer.soldier.worldTransform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 5 then
			p_Bot:_EnterVehicle(true)
			p_Bot._TargetPitch = 0.0
			p_Bot:AbortAttack()
			p_Bot:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
		end
		if p_Bot._ShootModeTimer > 12.0 then -- abort this after some time
			p_Bot._TargetPitch = 0.0
			p_Bot:AbortAttack()
			p_Bot:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
		end
	-- repair
	elseif p_Bot._ActiveAction == BotActionFlags.RepairActive and p_Bot._ShootPlayer ~= nil and
		p_Bot._ShootPlayer.soldier ~= nil and p_Bot._RepairVehicleEntity ~= nil then
		p_Bot._ShootModeTimer = p_Bot._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE
		p_Bot.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : repair

		local s_CurrentHealth = PhysicsEntity(p_Bot._RepairVehicleEntity).internalHealth

		--check for repair if close to vehicle
		if p_Bot._RepairVehicleEntity.transform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 5 then
			if s_CurrentHealth ~= p_Bot._LastVehicleHealth then
				p_Bot._ShootModeTimer = Registry.BOT.MAX_TIME_TRY_REPAIR - 2.0 -- continue for few seconds on progress
			end
			p_Bot._LastVehicleHealth = s_CurrentHealth
			p_Bot._TargetPitch = 0.0
			p_Bot._AttackModeMoveTimer = 0.0 -- don't jump anymore
			p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
		end

		-- Abort conditions
		if p_Bot._ShootModeTimer > Registry.BOT.MAX_TIME_TRY_REPAIR or p_Bot._RepairVehicleEntity == nil then -- abort this after some time
			p_Bot._TargetPitch = 0.0
			p_Bot:AbortAttack()
			p_Bot:_ResetActionFlag(BotActionFlags.RepairActive)
			p_Bot._WeaponToUse = BotWeapons.Primary
		end

	elseif p_Bot._ShootPlayer.soldier == nil or p_Bot._Shoot == false then -- reset if enemy is dead or attack is disabled
		p_Bot:AbortAttack()
	end
end

if g_BotAttacking == nil then
	---@type BotAttacking
	g_BotAttacking = BotAttacking()
end

return g_BotAttacking
