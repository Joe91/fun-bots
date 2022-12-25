---@class VehicleWeaponHandling
---@overload fun():VehicleWeaponHandling
VehicleWeaponHandling = class('VehicleWeaponHandling')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")

function VehicleWeaponHandling:__init()
	-- Nothing to do.
end

function VehicleWeaponHandling:UpdateReloadVehicle(p_Bot)
	p_Bot._VehicleWeaponSlotToUse = 1 -- Primary.
	p_Bot:AbortAttack()

	if p_Bot._ActiveAction ~= BotActionFlags.OtherActionActive then
		p_Bot._TargetPitch = 0.0
	end

	p_Bot._ReloadTimer = p_Bot._ReloadTimer + Registry.BOT.BOT_UPDATE_CYCLE

	if p_Bot._ReloadTimer > 1.5 and p_Bot._ReloadTimer < 2.5 then
		p_Bot:_SetInput(EntryInputActionEnum.EIAReload, 1)
	end
end

function VehicleWeaponHandling:UpdateWeaponSelectionVehicle(p_Bot)
	-- Select weapon-slot.
	p_Bot._WeaponToUse = BotWeapons.Primary -- For exit.

	-- Select weapon-slot.
	local s_AvailableWeaponSlots = m_Vehicles:GetAvailableWeaponSlots(p_Bot.m_ActiveVehicle,
		p_Bot.m_Player.controlledEntryId)
	if s_AvailableWeaponSlots > 1 then -- More than one weapon to select from.
		-- Not set yet.
		if p_Bot._ActiveVehicleWeaponSlot == 0 then
			p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon1, 1)
			p_Bot._ActiveVehicleWeaponSlot = 1
		end

		-- Select inputs.
		if p_Bot._ActiveVehicleWeaponSlot ~= p_Bot._VehicleWeaponSlotToUse then
			p_Bot._VehicleMovableId = m_Vehicles:GetPartIdForSeat(p_Bot.m_ActiveVehicle, p_Bot.m_Player.controlledEntryId,
				p_Bot._ActiveVehicleWeaponSlot)
			p_Bot._ActiveVehicleWeaponSlot = p_Bot._VehicleWeaponSlotToUse
			p_Bot._ShotTimer = 0.0

			-- To-do: how long to press? How to switch?
			if p_Bot._VehicleWeaponSlotToUse == 1 then
				p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon1, 1)
			elseif p_Bot._VehicleWeaponSlotToUse == 2 then
				p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon2, 1)
			elseif p_Bot._VehicleWeaponSlotToUse == 3 then
				p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon3, 1)
			elseif p_Bot._VehicleWeaponSlotToUse == 4 then
				p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon4, 1)
			end
		end
	end
end

if g_VehicleWeaponHandling == nil then
	---@type VehicleWeaponHandling
	g_VehicleWeaponHandling = VehicleWeaponHandling()
end

return g_VehicleWeaponHandling
