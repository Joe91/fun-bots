---@class BotWeaponHandling
---@overload fun():BotWeaponHandling
BotWeaponHandling = class('BotWeaponHandling')

---@type Utilities
local m_Utilities = require('__shared/Utilities')

function BotWeaponHandling:__init()
	-- Nothing to do.
end

function BotWeaponHandling:UpdateWeaponSelection(p_Bot)
	-- Select weapon-slot.
	if p_Bot._ActiveAction ~= BotActionFlags.MeleeActive and p_Bot.m_Player.soldier.weaponsComponent and p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
		p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
		p_Bot.m_ActiveWeapon = p_Bot.m_Knife
		p_Bot._ShotTimer = 0.0
	end
end

if g_BotWeaponHandling == nil then
	---@type BotWeaponHandling
	g_BotWeaponHandling = BotWeaponHandling()
end

return g_BotWeaponHandling
