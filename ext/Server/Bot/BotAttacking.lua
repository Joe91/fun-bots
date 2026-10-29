---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")
---@type ServerRaycasts
local m_ServerRaycasts = require('ServerRaycasts')

local GRAVITY = 9.81
-- Number of raycasts along the flight-path of a grenade.
local GRENADE_ARC_SEGMENTS = 4

local function _Fire(p_Bot)
	p_Bot._SoundTimer = 0.0
	p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
end

---@param p_Bot Bot
local function _StartGrenade(p_Bot)
	p_Bot._ActiveAction = BotActionFlags.GrenadeActive
	p_Bot._GrenadeTimer = 0.0
end

-- Checks the flight-path of the grenade for obstacles (ceilings, roofs over the target, ...).
---@param p_Soldier SoldierEntity
---@param p_Pitch number
---@param p_DiffX number horizontal difference to the target
---@param p_DiffZ number
---@param p_Distance number horizontal distance to the target
---@return boolean
local function _IsGrenadeArcFree(p_Soldier, p_Pitch, p_DiffX, p_DiffZ, p_Distance)
	local s_Eye = p_Soldier.worldTransform.trans:Clone()
	s_Eye.y = s_Eye.y + m_Utilities:getTargetHeight(p_Soldier, false, false)

	local s_SpeedHorizontal = Registry.BOT.GRENADE_THROW_SPEED * math.cos(p_Pitch)
	local s_SpeedVertical = Registry.BOT.GRENADE_THROW_SPEED * math.sin(p_Pitch)
	local s_FlightTime = p_Distance / s_SpeedHorizontal
	local s_DirX = p_DiffX / p_Distance
	local s_DirZ = p_DiffZ / p_Distance

	local s_From = s_Eye
	for l_Segment = 1, GRENADE_ARC_SEGMENTS do
		local s_Time = s_FlightTime * l_Segment / GRENADE_ARC_SEGMENTS
		local s_Horizontal = s_SpeedHorizontal * s_Time
		local s_To = Vec3(
			s_Eye.x + s_DirX * s_Horizontal,
			s_Eye.y + s_SpeedVertical * s_Time - 0.5 * GRAVITY * s_Time * s_Time,
			s_Eye.z + s_DirZ * s_Horizontal)
		if not m_ServerRaycasts:CheckSight(s_From, s_To, false, nil, 'grenade') then
			return false
		end
		s_From = s_To
	end

	return true
end

-- Decides if the bot throws a grenade at the last known position of the target.
---@param p_Bot Bot
---@param p_Soldier SoldierEntity
---@param p_Weapons SoldierWeapon[]
---@return boolean
local function _ShouldThrowGrenade(p_Bot, p_Soldier, p_Weapons)
	local s_LastSeen = p_Bot._LastSeenPosition
	if s_LastSeen == nil or p_Bot.m_Grenade == nil then
		p_Bot._GrenadeTried = true
		return false
	end

	-- Grenades are not refilled during an attack, so no need to check again.
	local s_Grenade = p_Weapons[7]
	if not s_Grenade or s_Grenade.primaryAmmo <= 0 then
		p_Bot._GrenadeTried = true
		return false
	end

	local s_Trans = p_Soldier.worldTransform.trans
	local s_DiffX = s_LastSeen.x - s_Trans.x
	local s_DiffZ = s_LastSeen.z - s_Trans.z
	local s_Distance = math.sqrt(s_DiffX * s_DiffX + s_DiffZ * s_DiffZ)
	if s_Distance <= Registry.BOT.MIN_DISTANCE_NADE then
		return false
	end

	local s_Pitch = p_Bot:GetGrenadePitch(s_Distance, s_LastSeen.y - s_Trans.y)
	if s_Pitch == nil then -- Out of reach.
		return false
	end

	-- Only decide once per attack. The raycasts are only done after that.
	p_Bot._GrenadeTried = true

	local s_ProbabilityGrenade = Registry.BOT.PROBABILITY_THROW_GRENADE
	if p_Bot.m_Behavior == BotBehavior.LovesExplosives then
		s_ProbabilityGrenade = Registry.BOT.PROBABILITY_THROW_GRENADE_PRIO
	end
	if not m_Utilities:CheckProbability(s_ProbabilityGrenade) then
		return false
	end

	return _IsGrenadeArcFree(p_Soldier, s_Pitch, s_DiffX, s_DiffZ, s_Distance)
end

---@param p_DeltaTime number
---@param p_Bot Bot
local function _ReviveAttackingAction(p_DeltaTime, p_Bot)
	-- Soldier alive again.
	if not p_Bot._ShootPlayer.corpse or p_Bot._ShootPlayer.corpse.isDead then
		p_Bot._WeaponToUse = BotWeapons.Primary
		p_Bot._TargetPitch = 0.0
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.ReviveActive)
		return
	end

	-- Revive.
	p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - p_DeltaTime
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

	p_Bot._ShotTimer = p_Bot._ShotTimer + p_DeltaTime

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

		p_Bot._ShootWayPoints[#p_Bot._ShootWayPoints + 1] = s_Point
		if p_Bot.m_KnifeMode and p_Bot._ShootPlayer.soldier then
			local s_Trans = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
			if (#p_Bot._KnifeWayPositions == 0 or s_Trans:Distance(p_Bot._KnifeWayPositions[#p_Bot._KnifeWayPositions]) > Registry.BOT.TRACE_DELTA_SHOOTING) then
				p_Bot._KnifeWayPositions[#p_Bot._KnifeWayPositions + 1] = s_Trans
			end
		end
	end

	p_Bot._ShootTraceTimer = p_Bot._ShootTraceTimer + p_DeltaTime
end

---@param p_DeltaTime number
---@param p_Bot Bot
local function _EnterVehicleAttackingAction(p_DeltaTime, p_Bot)
	p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - p_DeltaTime
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

---@param p_DeltaTime number
---@param p_Bot Bot
local function _RepairAttackingAction(p_DeltaTime, p_Bot)
	p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - p_DeltaTime
	p_Bot.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- Movement-mode : repair.

	if p_Bot:UpdateRepairVehicleEntity() then
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

---@param p_DeltaTime number
---@param p_Bot Bot
local function _DefaultAttackingAction(p_DeltaTime, p_Bot)
	-- Every access of an engine object (soldier, weaponsComponent, weapons, input, ...) allocates.
	-- Read each one once.
	local s_TargetSoldier = p_Bot._ShootPlayer.soldier
	if not s_TargetSoldier or not p_Bot._Shoot or p_Bot._ShootModeTimer <= 0.0 then
		p_Bot._TargetPitch = 0.0
		p_Bot._WeaponToUse = BotWeapons.Primary
		p_Bot:AbortAttack()
		p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
		p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
		return
	end

	local s_Soldier = p_Bot.m_Player.soldier
	local s_Weapons = s_Soldier.weaponsComponent.weapons

	if p_Bot._ActiveAction ~= BotActionFlags.C4Active then
		p_Bot:_SetInput(EntryInputActionEnum.EIAZoom, 1) -- Does not work yet :-/
		p_Bot.m_Input.zoomLevel = 1
	end

	if p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive then
		p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - p_DeltaTime
	end

	p_Bot._ReloadTimer = 0.0 -- Reset reloading.

	-- Check for melee attack.
	if Registry.COMMON.USE_BUGGED_HITBOXES and Config.MeleeAttackIfClose and p_Bot._ActiveAction ~= BotActionFlags.MeleeActive
		and p_Bot._MeleeCooldownTimer <= 0.0
		and s_TargetSoldier.worldTransform.trans:Distance(s_Soldier.worldTransform.trans) < 2 then
		p_Bot._ActiveAction = BotActionFlags.MeleeActive
		p_Bot.m_ActiveWeapon = p_Bot.m_Knife

		p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
		p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
		p_Bot:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
		p_Bot._MeleeCooldownTimer = Registry.BOT.MELEE_ATTACK_COOLDOWN
	else
		if p_Bot._MeleeCooldownTimer < 0.0 then
			p_Bot._MeleeCooldownTimer = 0.0
		elseif p_Bot._MeleeCooldownTimer > 0.0 then
			p_Bot._MeleeCooldownTimer = p_Bot._MeleeCooldownTimer - p_DeltaTime
			if p_Bot._MeleeCooldownTimer < (Registry.BOT.MELEE_ATTACK_COOLDOWN - 0.8) then
				p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
			else
				p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
			end
		end
	end

	if p_Bot._ActiveAction == BotActionFlags.GrenadeActive then -- Throw grenade.
		p_Bot._GrenadeTimer = p_Bot._GrenadeTimer + p_DeltaTime
		local s_Grenade = s_Weapons[7]
		-- Thrown, or give up if the throw does not happen.
		if not s_Grenade or s_Grenade.primaryAmmo <= 0 or p_Bot._GrenadeTimer > Registry.BOT.GRENADE_THROW_TIMEOUT then
			p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
		end
	end

	-- Target in vehicle.
	if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
		local s_AttackMode = m_Vehicles:CheckForVehicleAttack(p_Bot._ShootPlayerVehicleType, p_Bot)

		if s_AttackMode ~= VehicleAttackModes.NoAttack then
			if s_AttackMode == VehicleAttackModes.AttackWithNade then -- Grenade.
				_StartGrenade(p_Bot)
			elseif s_AttackMode == VehicleAttackModes.AttackWithRocket or
				s_AttackMode == VehicleAttackModes.AttackWithMissileAir or
				s_AttackMode == VehicleAttackModes.AttackWithMissileLand then -- Rockets and missiles.
				p_Bot._WeaponToUse = BotWeapons.Gadget1

				local s_Launcher = s_Weapons[3]
				if s_Launcher and s_Launcher.secondaryAmmo <= 0 then
					s_Launcher.secondaryAmmo = 3
					p_Bot._RocketCooldownTimer = Registry.BOT.ROCKET_RELOAD_COOLDOWN
					p_Bot._WeaponToUse = BotWeapons.Primary
				end
			elseif s_AttackMode == VehicleAttackModes.AttackWithC4 and p_Bot._ChaseCooldown > SharedUtils:GetTime() then
				-- Ran after the vehicle too long with C4 (StateAttacking): the primary weapon for a while.
				p_Bot._WeaponToUse = BotWeapons.Primary
			elseif s_AttackMode == VehicleAttackModes.AttackWithC4 then -- C4
				p_Bot._WeaponToUse = BotWeapons.Gadget2
				p_Bot._ActiveAction = BotActionFlags.C4Active
			elseif s_AttackMode == VehicleAttackModes.AttackWithRifle then
				local s_Primary = p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive and s_Weapons[1]
				if s_Primary then
					if s_Primary.primaryAmmo == 0 then
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
			local s_Launcher = s_Weapons[3]
			if s_Launcher and s_Launcher.secondaryAmmo <= 0 then
				s_Launcher.secondaryAmmo = 3
				p_Bot._RocketCooldownTimer = Registry.BOT.ROCKET_RELOAD_COOLDOWN
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
				local s_Primary = s_Weapons[1]
				if s_Primary then
					if p_Bot._DistanceToPlayer <= Config.MaxShootDistancePistol and
						(s_Primary.primaryAmmo == 0 or
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
								(p_Bot._ShootModeTimer >= (s_TargetTimeValueRocket - p_DeltaTime - 0.001)) and
								p_Bot.m_PrimaryGadget ~= nil and p_Bot.m_PrimaryGadget.type == WeaponTypes.Rocket and
								p_Bot._RocketCooldownTimer <= 0.0 and
								m_Utilities:CheckProbability(s_ProbabilityRocket)
							then
								p_Bot._WeaponToUse = BotWeapons.Gadget1
							end
						end
					end
				end
			end
			-- Throw a grenade at the last known position, when the target is out of sight for a while.
			-- Every sighting resets the shoot-mode-timer, so the elapsed time is the time since the last sighting.
			-- Cheap checks first: engine objects are only read, once all of them pass.
			if Config.BotsThrowGrenades and p_Bot._ActiveAction ~= BotActionFlags.GrenadeActive then
				if Config.BotWeapon == BotWeapons.Grenade then
					local s_Grenade = p_Bot.m_Grenade ~= nil and s_Weapons[7]
					if s_Grenade and s_Grenade.primaryAmmo > 0 then
						_StartGrenade(p_Bot)
					end
				elseif not p_Bot._GrenadeTried and p_Bot._WeaponToUse ~= BotWeapons.Gadget2 and
					(p_Bot._ActiveShootDuration - p_Bot._ShootModeTimer) >= Registry.BOT.GRENADE_LOST_SIGHT_TIME and
					_ShouldThrowGrenade(p_Bot, s_Soldier, s_Weapons) then
					_StartGrenade(p_Bot)
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
				Position = s_Soldier.worldTransform.trans:Clone(),
				SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
				ExtraMode = 0,
				OptValue = 0,
			}

			p_Bot._ShootWayPoints[#p_Bot._ShootWayPoints + 1] = s_Point

			if p_Bot.m_KnifeMode then
				local s_Trans = s_TargetSoldier.worldTransform.trans:Clone()
				p_Bot._KnifeWayPositions[#p_Bot._KnifeWayPositions + 1] = s_Trans
			end
		end

		p_Bot._ShootTraceTimer = p_Bot._ShootTraceTimer + p_DeltaTime
	end

	-- Shooting sequence.
	if p_Bot.m_ActiveWeapon ~= nil then
		if p_Bot.m_KnifeMode then
			-- Nothing to do.
			-- C4 Handling.
		elseif p_Bot._ActiveAction == BotActionFlags.C4Active and s_Weapons[6] then
			if s_Weapons[6].secondaryAmmo > 0 then
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
						s_Weapons[6].secondaryAmmo = 4
						p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
					end
				end
			end
		else
			if p_Bot._ShotTimer >= ((p_Bot.m_ActiveWeapon.fireCycle + p_Bot.m_ActiveWeapon.pauseCycle) * p_Bot._FireCycleModifier) then
				p_Bot._ShotTimer = 0.0
				p_Bot._FireCycleModifier = 0.8 + (math.random() * 0.8) -- between 0.8 and 1.6
			end

			if p_Bot._ShotTimer >= 0.0 and p_Bot._ActiveAction ~= BotActionFlags.MeleeActive then
				if p_Bot.m_ActiveWeapon.delayed == false then
					if p_Bot._ShotTimer <= (p_Bot.m_ActiveWeapon.fireCycle * p_Bot._FireCycleModifier) then
						_Fire(p_Bot)
					end
				else -- Start with pause Cycle.
					if p_Bot._ShotTimer >= (p_Bot.m_ActiveWeapon.pauseCycle * p_Bot._FireCycleModifier) then
						_Fire(p_Bot)
					end
				end
			end
		end

		p_Bot._ShotTimer = p_Bot._ShotTimer + p_DeltaTime
		p_Bot._SoundTimer = math.min(p_Bot._SoundTimer + p_DeltaTime, 30.0)
	end
end

---@param p_DeltaTime number
function Bot:UpdateAttacking(p_DeltaTime)
	-- Reset if enemy is dead or attack is disabled.
	if not self._ShootPlayer then
		self:AbortAttack()
		return
	end

	if self._ActiveAction == BotActionFlags.ReviveActive then
		_ReviveAttackingAction(p_DeltaTime, self)
	elseif self._ActiveAction == BotActionFlags.EnterVehicleActive then
		_EnterVehicleAttackingAction(p_DeltaTime, self)
	elseif self._ActiveAction == BotActionFlags.RepairActive then
		_RepairAttackingAction(p_DeltaTime, self)
	else
		_DefaultAttackingAction(p_DeltaTime, self)
	end
end
