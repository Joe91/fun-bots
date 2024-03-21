---@class BotWeaponHandling
---@overload fun():BotWeaponHandling
BotWeaponHandling = class('BotWeaponHandling')

---@type Utilities
local m_Utilities = require('__shared/Utilities')

function BotWeaponHandling:__init()
	-- Nothing to do.
end

function BotWeaponHandling:UpdateDeployAndReload(p_Bot, p_Deploy)
	if p_Bot._ActiveAction == BotActionFlags.MeleeActive or p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
		return
	end
	p_Bot._WeaponToUse = BotWeapons.Primary
	p_Bot:_ResetActionFlag(BotActionFlags.C4Active)
	p_Bot:_ResetActionFlag(BotActionFlags.ReviveActive)
	p_Bot:_ResetActionFlag(BotActionFlags.RepairActive)
	p_Bot:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
	p_Bot:_ResetActionFlag(BotActionFlags.GrenadeActive)
	p_Bot:AbortAttack()

	if p_Bot._ActiveAction ~= BotActionFlags.OtherActionActive then
		p_Bot._TargetPitch = 0.0
	end

	p_Bot._ReloadTimer = p_Bot._ReloadTimer + Registry.BOT.BOT_UPDATE_CYCLE

	if p_Bot.m_ActiveWeapon ~= nil and p_Bot._ReloadTimer > 1.5 and p_Bot._ReloadTimer < 2.5 and
		p_Bot.m_Player.soldier.weaponsComponent.currentWeapon.primaryAmmo <= p_Bot.m_ActiveWeapon.reload then
		p_Bot:_SetInput(EntryInputActionEnum.EIAReload, 1)
	end

	-- Deploy from time to time.
	if Config.BotsDeploy and p_Deploy and not Globals.IsScavenger then
		if p_Bot.m_PrimaryGadget ~= nil and (p_Bot.m_Kit == BotKits.Support or p_Bot.m_Kit == BotKits.Assault) then
			if p_Bot.m_PrimaryGadget.type == WeaponTypes.Ammobag or p_Bot.m_PrimaryGadget.type == WeaponTypes.Medkit then
				p_Bot._DeployTimer = p_Bot._DeployTimer + Registry.BOT.BOT_UPDATE_CYCLE

				if p_Bot._DeployTimer > Config.DeployCycle then
					p_Bot._DeployTimer = 0.0
				end

				if p_Bot._DeployTimer < 0.7 then
					p_Bot._WeaponToUse = BotWeapons.Gadget1
				end
			end
		end
	end
end

function BotWeaponHandling:UpdateWeaponSelection(p_Bot)
	-- Select weapon-slot.
	if p_Bot._ActiveAction ~= BotActionFlags.MeleeActive then
		if p_Bot.m_Player.soldier.weaponsComponent ~= nil then
			if p_Bot.m_KnifeMode then
				if p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
					p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
					p_Bot.m_ActiveWeapon = p_Bot.m_Knife
					p_Bot._ShotTimer = 0.0
				end
			elseif p_Bot._ActiveAction == BotActionFlags.ReviveActive or
				(p_Bot._WeaponToUse == BotWeapons.Gadget2 and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Gadget2 then
				if p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_5 then
					p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon5, 1)
					p_Bot.m_ActiveWeapon = p_Bot.m_SecondaryGadget
					p_Bot._ShotTimer = -p_Bot:GetFirstShotDelay(p_Bot._DistanceToPlayer, false)
				end
			elseif p_Bot._ActiveAction == BotActionFlags.RepairActive or
				(p_Bot._WeaponToUse == BotWeapons.Gadget1 and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Gadget1 then
				if p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_2 and
					p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_4 then
					p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon4, 1)
					p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon3, 1)
					p_Bot.m_ActiveWeapon = p_Bot.m_PrimaryGadget
					p_Bot._ShotTimer = -p_Bot:GetFirstShotDelay(p_Bot._DistanceToPlayer, false)
				end
			elseif p_Bot._ActiveAction == BotActionFlags.GrenadeActive or
				(p_Bot._WeaponToUse == BotWeapons.Grenade and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Grenade then
				if p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_6 then
					p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon6, 1)
					p_Bot.m_ActiveWeapon = p_Bot.m_Grenade
					p_Bot._ShotTimer = -p_Bot:GetFirstShotDelay(p_Bot._DistanceToPlayer, false)
				end
			elseif (p_Bot._WeaponToUse == BotWeapons.Pistol and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Pistol then
				if p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_1 then
					p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon2, 1)
					p_Bot.m_ActiveWeapon = p_Bot.m_Pistol
					p_Bot._ShotTimer = -p_Bot:GetFirstShotDelay(p_Bot._DistanceToPlayer, true)
				end
				if p_Bot.m_Player.soldier.weaponsComponent.weapons[2] ~= nil and
					p_Bot.m_Player.soldier.weaponsComponent.weapons[2].secondaryAmmo <
					p_Bot.m_Player.soldier.weaponsComponent.weapons[2].primaryAmmo + 1 then
					p_Bot.m_Player.soldier.weaponsComponent.weapons[2].secondaryAmmo = p_Bot.m_Player.soldier.weaponsComponent.weapons[
					2].primaryAmmo + 3
				end
			elseif (p_Bot._WeaponToUse == BotWeapons.Primary and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Primary then
				if p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
					p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon1, 1)
					p_Bot.m_ActiveWeapon = p_Bot.m_Primary
					p_Bot._ShotTimer = -0.05
				end
				if p_Bot.m_Player.soldier.weaponsComponent.weapons[1] ~= nil and
					p_Bot.m_Player.soldier.weaponsComponent.weapons[1].secondaryAmmo <
					p_Bot.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo + 1 then
					p_Bot.m_Player.soldier.weaponsComponent.weapons[1].secondaryAmmo = p_Bot.m_Player.soldier.weaponsComponent.weapons[
					1].primaryAmmo + 3
				end
			end
		end
	end
end

if g_BotWeaponHandling == nil then
	---@type BotWeaponHandling
	g_BotWeaponHandling = BotWeaponHandling()
end

return g_BotWeaponHandling
