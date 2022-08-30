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
		if (p_Bot._ShootModeTimer < Config.BotFireModeDuration * 3) then -- thre time the default duration

			p_Bot._ReloadTimer = 0.0 -- reset reloading

			if p_Bot._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
				local s_AttackMode = m_Vehicles:CheckForVehicleAttack(p_Bot._ShootPlayerVehicleType, p_Bot._DistanceToPlayer,
					p_Bot.m_SecondaryGadget, true)

				if s_AttackMode ~= VehicleAttackModes.NoAttack then
					p_Bot._WeaponToUse = BotWeapons.Primary
				else
					p_Bot._ShootModeTimer = Config.BotFireModeDuration -- end attack
				end
			else
				p_Bot._WeaponToUse = BotWeapons.Primary
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
			p_Bot._WeaponToUse = BotWeapons.Primary
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
