class('WeaponList')

require('__shared/WeaponClass')
require('__shared/Config')
require('__shared/Constants/WeaponTypes')
require('__shared/WeaponLists/CustomWeaponsAssault')
require('__shared/WeaponLists/CustomWeaponsEngineer')
require('__shared/WeaponLists/CustomWeaponsRecon')
require('__shared/WeaponLists/CustomWeaponsSupport')

local m_Logger = Logger("WeaponList", Debug.Shared.MODIFICATIONS)

-- create globals
AllWeapons = {}
KnifeWeapons = {}
PistoWeapons = {}

AssaultPrimary = {}
AssaultPistol = {}
AssaultKnife = {}
AssaultGadget1 = {}
AssaultGadget2 = {}
AssaultGrenade = {}
EngineerPrimary = {}
EngineerPistol = {}
EngineerKnife = {}
EngineerGadget1 = {}
EngineerGadget2 = {}
EngineerGrenade = {}
SupportPrimary = {}
SupportPistol = {}
SupportKnife = {}
SupportGadget1 = {}
SupportGadget2 = {}
SupportGrenade = {}
ReconPrimary = {}
ReconPistol = {}
ReconKnife = {}
ReconGadget1 = {}
ReconGadget2 = {}
ReconGrenade = {}

function WeaponList:__init()
	self._weapons = {}
	local s_Weapon = nil

	---------------------------
	-- shotguns
	s_Weapon = Weapon('DAO-12', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Jackhammer', 'XP1', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Saiga20', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'Silencer'}, WeaponTypes.Shotgun, 'Weapons/SAIGA20K/U_SAIGA_20K')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SPAS12', 'XP2', {'Slug', 'Kobra', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Shotgun) --TODO: Get Damage-Values and Speed of other ammo
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('USAS-12', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag', 'Weapons/Common/NoOptics'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M1014', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag', 'Weapons/Common/NoOptics'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('870M', '', {'Weapons/Remington870/U_870_Slug', 'Weapons/Remington870/U_870_ExtendedMag', 'Weapons/Common/NoOptics'}, WeaponTypes.Shotgun, 'Weapons/Remington870/U_870')
	table.insert(self._weapons, s_Weapon)

	---------------------------
	--assault
	s_Weapon = Weapon('AEK971', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('AN94', '', {'Kobra', 'Foregrip', 'Flashsuppressor'}, WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('AK74M', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SteyrAug', 'XP2', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('F2000', '', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('FAMAS', 'XP1', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('G3A3', '', {'Kobra', 'Target_Pointer', 'Foregrip'}, WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('KH2002', '', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('L85A2', 'XP1', {'Kobra', 'FlashSuppressor', 'Weapons/Common/NoSecondaryRail'},WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M16A4', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M416', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'},WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SCAR-L', 'XP2', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.Assault)
	table.insert(self._weapons, s_Weapon)


	---------------------------
	-- PDW --------------------
	s_Weapon = Weapon('ASVal', '', {'Kobra', 'ExtendedMag', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MP7', '', {'Kobra', 'ExtendedMag', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('P90', '', {'Kobra', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('PP-19', 'XP1', {'IRNV', 'Silencer', 'TargetPointer', 'Weapons/Common/DefaultCamo'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('PP2000', '', {'Kobra', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('UMP45', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Flashlight', 'Weapons/Common/DefaultCamo'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MP5K', 'XP2', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Flashlight'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MagpulPDR', '', {'Kobra', 'Flashsuppressor', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Crossbow', '', {}, WeaponTypes.PDW, 'Weapons/XP4_Crossbow_Prototype/U_Crossbow_Scoped_Cobra')
	table.insert(self._weapons, s_Weapon)


	---------------------------
	--Carabines
	s_Weapon = Weapon('A91', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('ACR', 'XP2', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('AKS74u', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('G36C', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('HK53', 'XP1', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M4A1', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MTAR', 'XP2', {'Kobra', 'Silencer', 'Foregrip'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('QBZ-95B', 'XP1', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SCAR-H', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SG553LB', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, s_Weapon)

	---------------------------
	--LMG
	s_Weapon = Weapon('L86', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('LSAT', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M249', '', {'Eotech', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M27IAR', '', {'Eotech', 'ExtendedMag', 'Weapons/Common/NoPrimaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M60', '', {'Ballistic_scope', 'Foregrip', 'TargetPointer'}, WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MG36', 'XP1', {'Ballistic_scope', 'Foregrip', 'ExtendedMag'}, WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Pecheneg', '', {'EOTech', 'Target_Pointer', 'Weapons/Common/NoPrimaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('QBB-95', 'XP1', {'EOTech', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Type88', '', {'EOTech', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('RPK', '', {'Weapons/RPK/U_RPK_Kobra', 'Weapons/RPK/U_RPK_ExtendedMag', 'Weapons/RPK/U_RPK_Foregrip'},WeaponTypes.LMG, 'Weapons/RPK/U_RPK-74M')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M240', '', {'Eotech', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.LMG)
	table.insert(self._weapons, s_Weapon)

	---------------------------
	-- Sniper
	s_Weapon = Weapon('JNG90_6x', 'XP2', {'Rifle_Scope', 'StraightPull', 'Target_Pointer', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('JNG90_IRNV', 'XP2', {'IRNV', 'Silencer', 'StraightPull', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('JNG90_Balllistic', 'XP2', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('L96_Balllistic', 'XP1', {'Ballistic_20xScope', 'Bipod', 'FlashSuppressor', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('L96_6x', 'XP1', {'Rifle_6xScope', 'StraightPull', 'TargetPointer', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('L96_IRNV', 'XP1', {'IRNV', 'Silencer', 'StraightPull', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M39EBR', '', {'Ballistic_scope', 'Target_pointer', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M98B_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M98B_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M98B_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M40A5_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M40A5_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M40A5_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('HK417', 'XP2', {'Ballistic_Scope', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Sniper)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MK11', '', {'Ballistic_scope', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Sniper)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SKS_LongRange', '', {'PK-AS', 'Foregrip', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SKS_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SKS_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SV98', '', {'Ballistic_scope', 'StraightPull', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.Sniper)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SVD_LongRange', '', {'PK-AS', 'Foregrip', 'FlashSuppressor'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SVD_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('SVD_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, s_Weapon)


	---------------------------
	-- pistols
	s_Weapon = Weapon('Glock17', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Glock17_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/Glock17/U_Glock17_Silenced')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Glock18', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Glock18_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/Glock18/U_Glock18_Silenced')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M1911_Lit', '', {}, WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Lit')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M1911_Silenced', '', {},WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Silenced')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M1911_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Tactical')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M9', '', {}, WeaponTypes.Pistol, 'Weapons/M9/U_M9')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M9_Silenced', '', {},WeaponTypes.Pistol, 'Weapons/M9/U_M9_Silenced')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M9_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/M9/U_M9_TacticalLight')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M93R', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MP412Rex', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Taurus44', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MP443', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MP443_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443_TacticalLight')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('MP443_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443_Silenced')
	table.insert(self._weapons, s_Weapon)

	-- knifes
	s_Weapon = Weapon('Razor', '', {}, WeaponTypes.Knife, 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Knife', '', {}, WeaponTypes.Knife)
	table.insert(self._weapons, s_Weapon)

	---------------------------
	-- Sidearms
	s_Weapon = Weapon('SMAW', '', {}, WeaponTypes.Rocket) -- only rockets supported for engineers right now
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('RPG7', '', {}, WeaponTypes.Rocket) -- only rockets supported for engineers right now
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Repairtool', '', {}, WeaponTypes.Torch, 'Weapons/Gadgets/Repairtool/U_Repairtool')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Defib', '', {}, WeaponTypes.Defibrillator, 'Weapons/Gadgets/Defibrillator/U_Defib')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Medkit', '', {}, WeaponTypes.Medkit, 'Weapons/Gadgets/Medicbag/U_Medkit')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Ammobag', '', {}, WeaponTypes.Ammobag, 'Weapons/Gadgets/Ammobag/U_Ammobag')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Claymore', '', {}, WeaponTypes.Claymore, 'Weapons/Gadgets/Claymore/U_Claymore')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('C4', '', {}, WeaponTypes.C4, 'Weapons/Gadgets/C4/U_C4')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Tug', '', {}, WeaponTypes.Tugs, 'Weapons/Gadgets/T-UGS/U_UGS')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('Beacon', '', {}, WeaponTypes.Beacon, 'Weapons/Gadgets/RadioBeacon/U_RadioBeacon')
	table.insert(self._weapons, s_Weapon)

	s_Weapon = Weapon('M67', '', {}, WeaponTypes.Grenade)
	table.insert(self._weapons, s_Weapon)

	self:updateWeaponList()
end

function WeaponList:_isCustomWeapon(p_Class, p_Name)
	local s_CustomWeaponList = nil
	local s_IsCustomWeapon = false

	if p_Class == BotKits.Assault then
		s_CustomWeaponList = CustomWeaponsAssault
	elseif p_Class == BotKits.Engineer then
		s_CustomWeaponList = CustomWeaponsEngineer
	elseif p_Class == BotKits.Support then
		s_CustomWeaponList = CustomWeaponsSupport
	elseif p_Class == BotKits.Recon then
		s_CustomWeaponList = CustomWeaponsRecon
	end

	for _, l_CustomName in pairs(s_CustomWeaponList) do
		if l_CustomName == p_Name then
			s_IsCustomWeapon = true
			break
		end
	end

	return s_IsCustomWeapon
end

function WeaponList:_useWeaponType(p_Class, p_Type, p_Name)
	local s_UseThisWeapon = false
	local s_IsClassWeapon = false
	local s_WeaponSet = ""

	if p_Class == BotKits.Assault then
		s_WeaponSet = Config.AssaultWeaponSet

		if p_Type == WeaponTypes.Assault then
			s_IsClassWeapon = true
		end
	elseif p_Class == BotKits.Engineer then
		s_WeaponSet = Config.EngineerWeaponSet

		if p_Type == WeaponTypes.Carabine then
			s_IsClassWeapon = true
		end
	elseif p_Class == BotKits.Support then
		s_WeaponSet = Config.SupportWeaponSet

		if p_Type == WeaponTypes.LMG then
			s_IsClassWeapon = true
		end
	else --if p_Class == BotKits.Recon then
		s_WeaponSet = Config.ReconWeaponSet

		if p_Type == WeaponTypes.Sniper then
			s_IsClassWeapon = true
		end
	end

	-- check for custom-weapon
	if s_WeaponSet == WeaponSets.Custom then
		s_UseThisWeapon = self:_isCustomWeapon(p_Class, p_Name)
	else -- check for other p_Classes
		if p_Type == WeaponTypes.PDW then
			if s_WeaponSet == WeaponSets.PDW or
			s_WeaponSet == WeaponSets.Class_PDW or
			s_WeaponSet == WeaponSets.Class_PDW_Shotgun or
			s_WeaponSet == WeaponSets.PDW_Shotgun then
				s_UseThisWeapon = true
			end
		elseif p_Type == WeaponTypes.Shotgun then
			if s_WeaponSet == WeaponSets.Shotgun or
			s_WeaponSet == WeaponSets.Class_Shotgun or
			s_WeaponSet == WeaponSets.Class_PDW_Shotgun or
			s_WeaponSet == WeaponSets.PDW_Shotgun then
				s_UseThisWeapon = true
			end
		elseif p_Type == WeaponTypes.Assault or p_Type == WeaponTypes.Carabine or p_Type == WeaponTypes.LMG or p_Type == WeaponTypes.Sniper then
			if s_WeaponSet == WeaponSets.Class or
			s_WeaponSet == WeaponSets.Class_Shotgun or
			s_WeaponSet == WeaponSets.Class_PDW_Shotgun or
			s_WeaponSet == WeaponSets.Class_PDW then
				if s_IsClassWeapon then
					s_UseThisWeapon = true
				end
			end
		else
			-- for all other weapons - use p_Class-list
			s_UseThisWeapon = self:_isCustomWeapon(p_Class, p_Name)
		end
	end

	return s_UseThisWeapon
end

function WeaponList:updateWeaponList()
	AllWeapons = {}
	KnifeWeapons = {}
	PistoWeapons = {}

	AssaultPrimary = {}
	AssaultPistol = {}
	AssaultKnife = {}
	AssaultGadget1 = {}
	AssaultGadget2 = {}
	AssaultGrenade = {}
	EngineerPrimary = {}
	EngineerPistol = {}
	EngineerKnife = {}
	EngineerGadget1 = {}
	EngineerGadget2 = {}
	EngineerGrenade = {}
	SupportPrimary = {}
	SupportPistol = {}
	SupportKnife = {}
	SupportGadget1 = {}
	SupportGadget2 = {}
	SupportGrenade = {}
	ReconPrimary = {}
	ReconPistol = {}
	ReconKnife = {}
	ReconGadget1 = {}
	ReconGadget2 = {}
	ReconGrenade = {}

	for i = 1, #self._weapons do
		local s_Wep = self._weapons[i]
		table.insert(AllWeapons, s_Wep.name)

		if (s_Wep.type == WeaponTypes.Knife) then
			table.insert(KnifeWeapons, s_Wep.name)
		elseif (s_Wep.type == WeaponTypes.Pistol) then
			table.insert(PistoWeapons, s_Wep.name)
		end

		if self:_useWeaponType(BotKits.Assault, s_Wep.type, s_Wep.name) then
			if (s_Wep.type == WeaponTypes.Knife) then
				table.insert(AssaultKnife, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Pistol) then
				table.insert(AssaultPistol, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Grenade) then
				table.insert(AssaultGrenade, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Medkit) then
				table.insert(AssaultGadget1, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Defibrillator) then
				table.insert(AssaultGadget2, s_Wep.name)
			else
				table.insert(AssaultPrimary, s_Wep.name)
			end
		end

		if self:_useWeaponType(BotKits.Engineer, s_Wep.type, s_Wep.name) then
			if (s_Wep.type == WeaponTypes.Knife) then
				table.insert(EngineerKnife, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Pistol) then
				table.insert(EngineerPistol, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Grenade) then
				table.insert(EngineerGrenade, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Torch) then
				table.insert(EngineerGadget1, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Rocket) then
				table.insert(EngineerGadget2, s_Wep.name)
			else
				table.insert(EngineerPrimary, s_Wep.name)
			end
		end

		if self:_useWeaponType(BotKits.Support, s_Wep.type, s_Wep.name) then
			if (s_Wep.type == WeaponTypes.Knife) then
				table.insert(SupportKnife, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Pistol) then
				table.insert(SupportPistol, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Grenade) then
				table.insert(SupportGrenade, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Ammobag) then
				table.insert(SupportGadget1, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Claymore) or (s_Wep.type == WeaponTypes.C4) then
				table.insert(SupportGadget2, s_Wep.name)
			else
				table.insert(SupportPrimary, s_Wep.name)
			end
		end

		if self:_useWeaponType(BotKits.Recon, s_Wep.type, s_Wep.name) then
			if (s_Wep.type == WeaponTypes.Knife) then
				table.insert(ReconKnife, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Pistol) then
				table.insert(ReconPistol, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Grenade) then
				table.insert(ReconGrenade, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Tugs) then
				table.insert(ReconGadget1, s_Wep.name)
			elseif (s_Wep.type == WeaponTypes.Beacon) then
				table.insert(ReconGadget2, s_Wep.name)
			else
				table.insert(ReconPrimary, s_Wep.name)
			end
		end
	end
end

function WeaponList:getWeapon(p_Name)
	local s_RetWeapon = nil
	for _, l_Weapon in pairs(self._weapons) do
		if l_Weapon.name == p_Name then
			s_RetWeapon = l_Weapon
			break
		end
	end

	if s_RetWeapon == nil then
		m_Logger:Warning('Weapon not found: '..tostring(p_Name))
	end

	return s_RetWeapon
end

function WeaponList:onLevelLoaded()
	for _, l_Weapon in pairs(self._weapons) do
		if l_Weapon.needvalues then
			l_Weapon:learnStatsValues()
		end
	end
end

if g_WeaponList == nil then
	g_WeaponList = WeaponList()
end

return g_WeaponList
