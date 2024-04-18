---@class VehicleAttacking
---@overload fun():VehicleAttacking
VehicleAttacking = class('VehicleAttacking')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")

function VehicleAttacking:__init()
	-- Nothing to do.
end

function VehicleAttacking:UpdateAttackingVehicle(p_Bot)
	if p_Bot._ShootPlayer.soldier ~= nil and p_Bot._Shoot then
		-- jets should only attack other vehicles for now
		if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) and p_Bot._ShootPlayerVehicleType == VehicleTypes.NoVehicle then
			p_Bot:AbortAttack()
		end

		if (p_Bot._ShootModeTimer > 0) then -- Three times the default duration.
			p_Bot._ShootModeTimer = p_Bot._ShootModeTimer - Registry.BOT.BOT_UPDATE_CYCLE

			-- Get amount of weapon slots.
			local s_WeaponSlots = m_Vehicles:GetAvailableWeaponSlots(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId)

			p_Bot._ReloadTimer = 0.0 -- Reset reloading.

			if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
				local s_AttackMode = m_Vehicles:CheckForVehicleAttack(p_Bot._ShootPlayerVehicleType, p_Bot._DistanceToPlayer,
					p_Bot.m_SecondaryGadget, true, false)

				if s_AttackMode ~= VehicleAttackModes.NoAttack then
					if s_WeaponSlots > 1 then
						-- To-do more logic depending on vehicle and distance.
						-- Chopper on Plane / Chopper → weapon 2 (seaker).
						if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) then
							if p_Bot.m_Player.controlledEntryId == 0 and
								(p_Bot._ShootPlayerVehicleType == VehicleTypes.Chopper
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.ScoutChopper
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.Plane)
							then
								p_Bot._VehicleWeaponSlotToUse = 2
							elseif p_Bot.m_Player.controlledEntryId == 1 and
								(p_Bot._ShootPlayerVehicleType == VehicleTypes.Tank
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.IFV
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.MobileArtillery
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.AntiAir
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.LightVehicle
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.NoArmorVehicle
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.MavBot)
							then
								p_Bot._VehicleWeaponSlotToUse = 2
							else
								p_Bot._VehicleWeaponSlotToUse = 1
							end
						elseif m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.ScoutChopper) then
							if p_Bot.m_Player.controlledEntryId == 0 and
								(p_Bot._ShootPlayerVehicleType == VehicleTypes.Chopper
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.Plane
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.ScoutChopper)
							then
								p_Bot._VehicleWeaponSlotToUse = 1
							else
								p_Bot._VehicleWeaponSlotToUse = 2
							end
						elseif m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.IFV) then
							if p_Bot.m_Player.controlledEntryId == 0 and
								(p_Bot._ShootPlayerVehicleType == VehicleTypes.Tank
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.MobileArtillery
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.AntiAir
									or p_Bot._ShootPlayerVehicleType == VehicleTypes.IFV)
							then
								if p_Bot._VehicleSecondaryWeaponTimer == 0 then
									p_Bot._VehicleSecondaryWeaponTimer = 12.0
								end

								if p_Bot._VehicleSecondaryWeaponTimer >= 8.0 then
									p_Bot._VehicleWeaponSlotToUse = 2
								else
									p_Bot._VehicleWeaponSlotToUse = 1
								end
							else
								p_Bot._VehicleWeaponSlotToUse = 1
							end
						else
							p_Bot._VehicleWeaponSlotToUse = 1
						end
					else
						p_Bot._VehicleWeaponSlotToUse = 1 -- Primary.
					end
				else
					p_Bot._ShootModeTimer = 0.0 -- End attack.
				end
			else                 -- Infantery Soldier.
				if s_WeaponSlots > 1 then
					-- If in Tank and target == soldier and distance small enough → LMG / HMG
					if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Tank) and
						p_Bot._DistanceToPlayer < Config.MaxShootDistance then
						p_Bot._VehicleWeaponSlotToUse = 2
					else
						p_Bot._VehicleWeaponSlotToUse = 1
					end
					-- To-do more vehicles and more logic.
				else
					p_Bot._VehicleWeaponSlotToUse = 1 -- Primary.
				end
			end


			-- Shooting sequence.
			if p_Bot.m_ActiveWeapon ~= nil then
				if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.AntiAir) then
					if p_Bot._ShotTimer >= 5.0 then
						p_Bot._ShotTimer = 0.0
					end
					if p_Bot._ShotTimer >= 0.5 and p_Bot._VehicleReadyToShoot then
						p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
					end
				elseif m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
					if p_Bot._ShotTimer >= 1.6 then
						p_Bot._ShotTimer = 0.0
					end
					if p_Bot._ShotTimer >= 0.3 and p_Bot._VehicleReadyToShoot then
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
			p_Bot._VehicleWeaponSlotToUse = 1 -- Primary.
			p_Bot:AbortAttack()
			p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
			p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
		end
	elseif p_Bot._ShootPlayer.soldier == nil then -- Reset if enemy is dead.
		p_Bot:AbortAttack()
	end

	p_Bot._VehicleSecondaryWeaponTimer = math.max(p_Bot._VehicleSecondaryWeaponTimer - Registry.BOT.BOT_UPDATE_CYCLE, 0)
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
