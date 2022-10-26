---@class VehicleAttacking
---@overload fun():VehicleAttacking
VehicleAttacking = class('VehicleAttacking')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")

function VehicleAttacking:__init()
	-- nothing to do
end

function VehicleAttacking:UpdateAttackingVehicle(p_Bot)
	if p_Bot._ShootPlayer.soldier ~= nil and p_Bot._Shoot then
		if (p_Bot._ShootModeTimer < Config.BotVehicleFireModeDuration) then -- thre time the default duration

			p_Bot._ShootModeTimer = p_Bot._ShootModeTimer + Registry.BOT.BOT_UPDATE_CYCLE

			-- get amount of weaponslots
			local s_WeaponSlots = m_Vehicles:GetAvailableWeaponSlots(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId)

			p_Bot._ReloadTimer = 0.0 -- reset reloading

			if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
				local s_AttackMode = m_Vehicles:CheckForVehicleAttack(p_Bot._ShootPlayerVehicleType, p_Bot._DistanceToPlayer,
					p_Bot.m_SecondaryGadget, true, false)

				if s_AttackMode ~= VehicleAttackModes.NoAttack then
					if s_WeaponSlots > 1 then
						-- TODO more logic depending on vehicle and distance
						-- Chopper on Plane / Chopper --> weapon 2 (seaker)
						if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) or
							m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
							if p_Bot.m_Player.controlledEntryId == 0 and
								(p_Bot._ShootPlayerVehicleType == VehicleTypes.Chopper or p_Bot._ShootPlayerVehicleType == VehicleTypes.Plane) then
								p_Bot._VehicleWeaponSlotToUse = 2
							else
								p_Bot._VehicleWeaponSlotToUse = 1
							end
						else
							p_Bot._VehicleWeaponSlotToUse = 1
						end
					else
						p_Bot._VehicleWeaponSlotToUse = 1 -- primary
					end
				else
					p_Bot._ShootModeTimer = Config.BotVehicleFireModeDuration -- end attack
				end
			else -- Soldier
				if s_WeaponSlots > 1 then
					-- if in Tank and target == soldier and distance small enough --> LMG / HMG
					if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Tank) and
						p_Bot._DistanceToPlayer < Config.MaxShootDistanceSniper then
						p_Bot._VehicleWeaponSlotToUse = 2
					-- elseif m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.MobileArtillery) then --TODO: only do that when tere is an idication for ammo
					-- 	p_Bot._VehicleWeaponSlotToUse = 2
					else
						p_Bot._VehicleWeaponSlotToUse = 1
					end
				-- TODO more vehicles and more logic
				else
					p_Bot._VehicleWeaponSlotToUse = 1 -- primary
				end
			end


			--shooting sequence
			if p_Bot.m_ActiveWeapon ~= nil then
				if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.AntiAir) then
					if p_Bot._ShotTimer >= 5.0 then
						p_Bot._ShotTimer = 0.0
					end
					if p_Bot._ShotTimer >= 0.5 and p_Bot._VehicleReadyToShoot then
						p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
					end
				else
					if p_Bot._ShotTimer >= 0.6 then
						p_Bot._ShotTimer = 0.0
					end
					if p_Bot._ShotTimer >= 0.3 and p_Bot._VehicleReadyToShoot then
						p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
					end
				end
				p_Bot._ShotTimer = p_Bot._ShotTimer + Registry.BOT.BOT_UPDATE_CYCLE
			end
		else
			p_Bot._TargetPitch = 0.0
			p_Bot._VehicleWeaponSlotToUse = 1 -- primary
			p_Bot:AbortAttack()
			p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
			p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
		end
	elseif p_Bot._ShootPlayer.soldier == nil then -- reset if enemy is dead
		p_Bot:AbortAttack()
	end
end

function VehicleAttacking:UpdateAttackStationaryAAVehicle(p_Bot)
	if p_Bot._VehicleReadyToShoot then
		p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
	end
end

if g_VehicleAttacking == nil then
	---@type VehicleAttacking
	g_VehicleAttacking = VehicleAttacking()
end

return g_VehicleAttacking
