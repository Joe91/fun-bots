---@class BotAttacking
---@overload fun():BotAttacking
BotAttacking = class('BotAttacking')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")

function BotAttacking:__init()
	-- Nothing to do.
end

local function _Fire(p_Bot)
	p_Bot._SoundTimer = 0.0
	p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
end

---@param p_Bot Bot
local function _ReviveAttackingAction(p_Bot)
	-- Soldier alive again.
	if not p_Bot._ShootPlayer.corpse or p_Bot._ShootPlayer.corpse.isDead then
		p_Bot._WeaponToUse = BotWeapons.Primary
		p_Bot._TargetPitch = 0.0
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.ReviveActive)
		return
	end

	-- Revive.
	p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - Registry.BOT.BOT_UPDATE_CYCLE
	p_Bot.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- Movement-mode : revive.
	p_Bot._ReloadTimer = 0.0                    -- Reset reloading.

	-- Check for revive if close.
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

	-- Trace way back.
	if p_Bot._ShootTraceTimer > Registry.BOT.TRACE_DELTA_SHOOTING then
		-- Create a Trace to find way back.
		p_Bot._ShootTraceTimer = 0.0
		local s_Point = {
			Position = p_Bot.m_Player.soldier.worldTransform.trans:Clone(),
			SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
			ExtraMode = 0,
			OptValue = 0,
		}

		table.insert(p_Bot._ShootWayPoints, s_Point)
		if p_Bot.m_KnifeMode and p_Bot._ShootPlayer.soldier then
			local s_Trans = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
			if (#p_Bot._KnifeWayPositions == 0 or s_Trans:Distance(p_Bot._KnifeWayPositions[#p_Bot._KnifeWayPositions]) > Registry.BOT.TRACE_DELTA_SHOOTING) then
				table.insert(p_Bot._KnifeWayPositions, s_Trans)
			end
		end
	end

	p_Bot._ShootTraceTimer = p_Bot._ShootTraceTimer + Registry.BOT.BOT_UPDATE_CYCLE
end

---@param p_Bot Bot
local function _EnterVehicleAttackingAction(p_Bot)
	p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - Registry.BOT.BOT_UPDATE_CYCLE
	p_Bot.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- Movement-mode : revive.
	if not p_Bot._ShootPlayer.soldier then
		p_Bot._TargetPitch = 0.0
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
		return
	end
	-- Check for enter of vehicle if close.
	if p_Bot._ShootPlayer.soldier.worldTransform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 5 then
		p_Bot:_EnterVehicle(true)
		p_Bot._TargetPitch = 0.0
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
	end

	-- Abort this after some time.
	if p_Bot._ShootModeTimer <= 0.0 then
		p_Bot._TargetPitch = 0.0
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
	end
end

---@param p_Bot Bot
local function _RepairAttackingAction(p_Bot)
	p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - Registry.BOT.BOT_UPDATE_CYCLE
	p_Bot.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- Movement-mode : repair.

	if p_Bot._RepairVehicleEntity then
		local s_CurrentHealth = PhysicsEntity(p_Bot._RepairVehicleEntity).internalHealth

		-- Check for repair if close to vehicle.
		if p_Bot._RepairVehicleEntity.transform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 5 then
			if s_CurrentHealth ~= p_Bot._LastVehicleHealth then
				p_Bot._ShootModeTimer = 2.0 -- Continue for few seconds on progress.
			end

			p_Bot._LastVehicleHealth = s_CurrentHealth
			p_Bot._TargetPitch = 0.0
			p_Bot._AttackModeMoveTimer = 0.0 -- Don't jump any more.
			p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
		end
	end

	-- Abort conditions.
	if p_Bot._ShootModeTimer <= 0 or p_Bot._RepairVehicleEntity == nil then -- Abort this after some time.
		p_Bot._TargetPitch = 0.0
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.RepairActive)
		p_Bot._WeaponToUse = BotWeapons.Primary
	end
end

---@param p_Bot Bot
local function _DefaultAttackingAction(p_Bot)
	if not p_Bot._ShootPlayer.soldier or not p_Bot._Shoot or p_Bot._ShootModeTimer <= 0.0 then
		p_Bot._TargetPitch = 0.0
		p_Bot._WeaponToUse = BotWeapons.Primary
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
		p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
		return
	end

	if p_Bot._ActiveAction ~= BotActionFlags.C4Active then
		p_Bot:_SetInput(EntryInputActionEnum.EIAZoom, 1) -- Does not work yet :-/
		p_Bot.m_Player.input.zoomLevel = 1
	end

	if p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive then
		p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - Registry.BOT.BOT_UPDATE_CYCLE
	end

	p_Bot._ReloadTimer = 0.0 -- Reset reloading.

	-- Check for melee attack.
	if Registry.COMMON.USE_BUGGED_HITBOXES and Config.MeleeAttackIfClose and p_Bot._ActiveAction ~= BotActionFlags.MeleeActive
		and p_Bot._MeleeCooldownTimer <= 0.0
		and p_Bot._ShootPlayer.soldier.worldTransform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 2 then
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
			if p_Bot._MeleeCooldownTimer < (Config.MeleeAttackCoolDown - 0.8) then
				p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
			else
				p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
			end
		end
	end

	if p_Bot._ActiveAction == BotActionFlags.GrenadeActive then -- Throw grenade.
		if p_Bot.m_Player.soldier.weaponsComponent.weapons[7].primaryAmmo <= 0 then
			p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
		end
	end

	-- Target in vehicle.
	if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
		local s_IsSniper = false
		if (p_Bot.m_ActiveWeapon and p_Bot.m_ActiveWeapon.type == WeaponTypes.Sniper) then
			s_IsSniper = true
		end
		local s_AttackMode = m_Vehicles:CheckForVehicleAttack(p_Bot._ShootPlayerVehicleType, p_Bot._DistanceToPlayer,
			p_Bot.m_SecondaryGadget, false, s_IsSniper)

		if s_AttackMode ~= VehicleAttackModes.NoAttack then
			if s_AttackMode == VehicleAttackModes.AttackWithNade then -- Grenade.
				p_Bot._ActiveAction = BotActionFlags.GrenadeActive
			elseif s_AttackMode == VehicleAttackModes.AttackWithRocket or
				s_AttackMode == VehicleAttackModes.AttackWithMissileAir or
				s_AttackMode == VehicleAttackModes.AttackWithMissileLand then -- Rockets and missiles.
				p_Bot._WeaponToUse = BotWeapons.Gadget2
				if p_Bot.m_Player.soldier.weaponsComponent.weapons[3] and p_Bot.m_Player.soldier.weaponsComponent.weapons[3].secondaryAmmo <= 0 then
					p_Bot.m_Player.soldier.weaponsComponent.weapons[3].secondaryAmmo = 3
					p_Bot._WeaponToUse = BotWeapons.Primary
				end
			elseif s_AttackMode == VehicleAttackModes.AttackWithC4 then -- C4
				p_Bot._WeaponToUse = BotWeapons.Gadget2
				p_Bot._ActiveAction = BotActionFlags.C4Active
			elseif s_AttackMode == VehicleAttackModes.AttackWithRifle then
				if p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive and
					p_Bot.m_Player.soldier.weaponsComponent.weapons[1] then
					if p_Bot.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 then
						p_Bot._WeaponToUse = BotWeapons.Pistol
					else
						p_Bot._WeaponToUse = BotWeapons.Primary
					end
				end
			end
		else
			p_Bot._ShootModeTimer = 0.0 -- End attack.
		end
	else
		-- Target not in vehicle.
		-- Refill rockets if empty.
		if p_Bot.m_ActiveWeapon and p_Bot.m_ActiveWeapon.type == WeaponTypes.Rocket and not Globals.IsGm then
			if p_Bot.m_Player.soldier.weaponsComponent.weapons[3] and p_Bot.m_Player.soldier.weaponsComponent.weapons[3].primaryAmmo <= 0 then
				p_Bot.m_Player.soldier.weaponsComponent.weapons[3].primaryAmmo = 1
				p_Bot.m_Player.soldier.weaponsComponent.weapons[3].secondaryAmmo = 3
				p_Bot._WeaponToUse = BotWeapons.Primary
			end
		end
		if p_Bot.m_KnifeMode or p_Bot._ActiveAction == BotActionFlags.MeleeActive then
			p_Bot._WeaponToUse = BotWeapons.Knife
		elseif Globals.IsGm then
			p_Bot._WeaponToUse = BotWeapons.Primary
		else
			if p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive then
				-- Check to use pistol.
				if p_Bot.m_Player.soldier.weaponsComponent.weapons[1] then
					if p_Bot._DistanceToPlayer <= Config.MaxShootDistancePistol and
						(p_Bot.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 or
							p_Bot.m_Behavior == BotBehavior.LovesPistols)
					then
						p_Bot._WeaponToUse = BotWeapons.Pistol
					else
						if p_Bot.m_ActiveWeapon.type ~= WeaponTypes.Rocket then
							p_Bot._WeaponToUse = BotWeapons.Primary
							-- Check to use rocket.
							local s_TargetTimeValueRocket = p_Bot._ActiveShootDuration * 0.4 -- after 60 % of attack-time
							local s_ProbabilityRocket = Registry.BOT.PROBABILITY_SHOOT_ROCKET
							if p_Bot.m_Behavior == BotBehavior.LovesExplosives then
								s_ProbabilityRocket = Registry.BOT.PROBABILITY_SHOOT_ROCKET_PRIO
							end
							if (p_Bot._ShootModeTimer <= (s_TargetTimeValueRocket + 0.001)) and
								(p_Bot._ShootModeTimer >= (s_TargetTimeValueRocket - Registry.BOT.BOT_UPDATE_CYCLE - 0.001)) and
								p_Bot.m_SecondaryGadget ~= nil and p_Bot.m_SecondaryGadget.type == WeaponTypes.Rocket and
								m_Utilities:CheckProbablity(s_ProbabilityRocket)
							then
								p_Bot._WeaponToUse = BotWeapons.Gadget2
							end
						end
					end
				end
			end
			-- Use grenade from time to time.
			if Config.BotsThrowGrenades then
				local s_TargetTimeValue = p_Bot._ActiveShootDuration * 0.25 -- after 75 % of the attack-time
				local s_ProbabilityGrenade = Registry.BOT.PROBABILITY_THROW_GRENADE
				if p_Bot.m_Behavior == BotBehavior.LovesExplosives then
					s_ProbabilityGrenade = Registry.BOT.PROBABILITY_THROW_GRENADE_PRIO
				end

				if p_Bot._WeaponToUse ~= BotWeapons.Gadget2 and
					((p_Bot._ShootModeTimer <= (s_TargetTimeValue + 0.001)) and
						(p_Bot._ShootModeTimer >= (s_TargetTimeValue - Registry.BOT.BOT_UPDATE_CYCLE - 0.001)) and
						(p_Bot.m_Player.soldier.weaponsComponent.weapons[7] and p_Bot.m_Player.soldier.weaponsComponent.weapons[7].primaryAmmo > 0) and
						p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive) or Config.BotWeapon == BotWeapons.Grenade then
					-- Should be triggered only once per fireMode.
					if m_Utilities:CheckProbablity(s_ProbabilityGrenade) then
						if p_Bot.m_Grenade ~= nil
							and p_Bot._DistanceToPlayer > Registry.BOT.MIN_DISTANCE_NADE
							and p_Bot._DistanceToPlayer < 25.0 then -- Algorithm only works for up to 25 m.
							p_Bot._ActiveAction = BotActionFlags.GrenadeActive
						end
					end
				end
			end
		end
	end

	-- Trace way back.
	if (p_Bot.m_ActiveWeapon and p_Bot.m_ActiveWeapon.type ~= WeaponTypes.Sniper and
			p_Bot.m_ActiveWeapon.type ~= WeaponTypes.MissileAir and
			p_Bot.m_ActiveWeapon.type ~= WeaponTypes.MissileLand) or p_Bot.m_KnifeMode then
		if p_Bot._ShootTraceTimer > Registry.BOT.TRACE_DELTA_SHOOTING then
			-- Create a Trace to find way back.
			p_Bot._ShootTraceTimer = 0.0
			local s_Point = {
				Position = p_Bot.m_Player.soldier.worldTransform.trans:Clone(),
				SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
				ExtraMode = 0,
				OptValue = 0,
			}

			table.insert(p_Bot._ShootWayPoints, s_Point)

			if p_Bot.m_KnifeMode and p_Bot._ShootPlayer.soldier then
				local s_Trans = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
				table.insert(p_Bot._KnifeWayPositions, s_Trans)
			end
		end

		p_Bot._ShootTraceTimer = p_Bot._ShootTraceTimer + Registry.BOT.BOT_UPDATE_CYCLE
	end

	-- Shooting sequence.
	if p_Bot.m_ActiveWeapon ~= nil then
		if p_Bot.m_KnifeMode then
			-- Nothing to do.
			-- C4 Handling.
		elseif p_Bot._ActiveAction == BotActionFlags.C4Active and p_Bot.m_Player.soldier.weaponsComponent.weapons[6] then
			if p_Bot.m_Player.soldier.weaponsComponent.weapons[6].secondaryAmmo > 0 then
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
					-- To-do: run away from object now.
					if p_Bot._ShotTimer >= ((p_Bot.m_ActiveWeapon.fireCycle * 2) + p_Bot.m_ActiveWeapon.pauseCycle) then
						p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
						p_Bot.m_Player.soldier.weaponsComponent.weapons[6].secondaryAmmo = 4
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
						_Fire(p_Bot)
					end
				else -- Start with pause Cycle.
					if p_Bot._ShotTimer >= p_Bot.m_ActiveWeapon.pauseCycle then
						_Fire(p_Bot)
					end
				end
			end
		end

		p_Bot._ShotTimer = p_Bot._ShotTimer + Registry.BOT.BOT_UPDATE_CYCLE
		p_Bot._SoundTimer = math.min(p_Bot._SoundTimer + Registry.BOT.BOT_UPDATE_CYCLE, 30.0)
	end
end

---@param p_Bot Bot
function BotAttacking:UpdateAttacking(p_Bot)
	-- Reset if enemy is dead or attack is disabled.
	if not p_Bot._ShootPlayer then
		p_Bot:AbortAttack()
		return
	end

	if p_Bot._ActiveAction == BotActionFlags.ReviveActive then
		_ReviveAttackingAction(p_Bot)
	elseif p_Bot._ActiveAction == BotActionFlags.EnterVehicleActive then
		_EnterVehicleAttackingAction(p_Bot)
	elseif p_Bot._ActiveAction == BotActionFlags.RepairActive then
		_RepairAttackingAction(p_Bot)
	else
		_DefaultAttackingAction(p_Bot)
	end
end

if g_BotAttacking == nil then
	---@type BotAttacking
	g_BotAttacking = BotAttacking()
end

return g_BotAttacking
