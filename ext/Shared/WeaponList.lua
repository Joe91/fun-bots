---@class WeaponList
---@overload fun():WeaponList
WeaponList = class('WeaponList')

require('__shared/WeaponClass')
require('__shared/Config')
require('__shared/Constants/WeaponTypes')
require('__shared/WeaponLists/CustomWeapons')

---@type Logger
local m_Logger = Logger("WeaponList", Debug.Shared.MODIFICATIONS)

-- Create globals.
Weapons = {}

AssaultPrimary = {}
EngineerPrimary = {}
SupportPrimary = {}
ReconPrimary = {}
KnifeWeapons = {}
PistolWeapons = {}
ScavengerWeapons = {}

function WeaponList:__init()
	self._weapons = {
		---------------------------
		-- Knifes.
		Weapon('Razor', '', {}, WeaponTypes.Knife, 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor'),
		Weapon('Knife', '', {}, WeaponTypes.Knife),
	}
end

function WeaponList:_isCustomWeapon(p_Class, p_Name, p_Team)
	local s_CustomWeaponList = CustomWeapons
	local s_IsCustomWeapon = false

	for _, l_CustomName in pairs(s_CustomWeaponList) do
		if l_CustomName == p_Name or string.find(p_Name, l_CustomName .. "_") ~= nil then -- Use all fitting weapon-variants of this type.
			s_IsCustomWeapon = true
			break
		end
	end

	return s_IsCustomWeapon
end

function WeaponList:UpdateWeaponList()
	KnifeWeapons = {}
	Weapons = {}

	for i = 1, #self._weapons do
		local s_Wep = self._weapons[i]

		if (s_Wep.type == WeaponTypes.Knife) then
			table.insert(KnifeWeapons, s_Wep.name)
			table.insert(Weapons, s_Wep.name)
		end
	end
end

function WeaponList:getWeapon(p_Name)
	local s_RetWeapon = nil
	local s_AllPossibleWeapons = {}

	if p_Name == nil then
		m_Logger:Warning('Invalid Parameter')
		return nil
	end

	for _, l_Weapon in pairs(self._weapons) do
		if string.find(l_Weapon.name, p_Name .. "_") ~= nil then -- Check for weapon-variant.
			table.insert(s_AllPossibleWeapons, l_Weapon)
		end

		if l_Weapon.name == p_Name then
			s_RetWeapon = l_Weapon
			break
		end
	end

	if s_RetWeapon ~= nil then
		return s_RetWeapon
	elseif #s_AllPossibleWeapons > 0 then
		return s_AllPossibleWeapons[MathUtils:GetRandomInt(1, #s_AllPossibleWeapons)]
	else
		m_Logger:Warning('Weapon not found: ' .. tostring(p_Name))
		return nil
	end
end

function WeaponList:OnLevelLoaded()
	for _, l_Weapon in pairs(self._weapons) do
		if l_Weapon.needvalues then
			l_Weapon:learnStatsValues()
		end
	end
end

if g_WeaponList == nil then
	---@type WeaponList
	g_WeaponList = WeaponList()
end

return g_WeaponList
