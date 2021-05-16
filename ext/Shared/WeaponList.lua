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
	local weapon = nil

	---------------------------
	-- shotguns
	weapon = Weapon('DAO-12', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Jackhammer', 'XP1', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Saiga20', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'Silencer'}, WeaponTypes.Shotgun, 'Weapons/SAIGA20K/U_SAIGA_20K')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SPAS12', 'XP2', {'Slug', 'Kobra', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Shotgun) --TODO: Get Damage-Values and Speed of other ammo
	table.insert(self._weapons, weapon)

	weapon = Weapon('USAS-12', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag', 'Weapons/Common/NoOptics'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1014', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag', 'Weapons/Common/NoOptics'}, WeaponTypes.Shotgun)
	table.insert(self._weapons, weapon)

	weapon = Weapon('870M', '', {'Weapons/Remington870/U_870_Slug', 'Weapons/Remington870/U_870_ExtendedMag', 'Weapons/Common/NoOptics'}, WeaponTypes.Shotgun, 'Weapons/Remington870/U_870')
	table.insert(self._weapons, weapon)

	---------------------------
	--assault
	weapon = Weapon('AEK971', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('AN94', '', {'Kobra', 'Foregrip', 'Flashsuppressor'}, WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('AK74M', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('SteyrAug', 'XP2', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('F2000', '', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('FAMAS', 'XP1', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('G3A3', '', {'Kobra', 'Target_Pointer', 'Foregrip'}, WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('KH2002', '', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('L85A2', 'XP1', {'Kobra', 'FlashSuppressor', 'Weapons/Common/NoSecondaryRail'},WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M16A4', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M416', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'},WeaponTypes.Assault)
	table.insert(self._weapons, weapon)

	weapon = Weapon('SCAR-L', 'XP2', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.Assault)
	table.insert(self._weapons, weapon)


	---------------------------
	-- PDW --------------------
	weapon = Weapon('ASVal', '', {'Kobra', 'ExtendedMag', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP7', '', {'Kobra', 'ExtendedMag', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('P90', '', {'Kobra', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('PP-19', 'XP1', {'IRNV', 'Silencer', 'TargetPointer', 'Weapons/Common/DefaultCamo'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('PP2000', '', {'Kobra', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('UMP45', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Flashlight', 'Weapons/Common/DefaultCamo'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP5K', 'XP2', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Flashlight'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MagpulPDR', '', {'Kobra', 'Flashsuppressor', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.PDW)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Crossbow', '', {}, WeaponTypes.PDW, 'Weapons/XP4_Crossbow_Prototype/U_Crossbow_Scoped_Cobra')
	table.insert(self._weapons, weapon)


	---------------------------
	--Carabines
	weapon = Weapon('A91', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('ACR', 'XP2', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('AKS74u', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('G36C', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('HK53', 'XP1', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M4A1', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MTAR', 'XP2', {'Kobra', 'Silencer', 'Foregrip'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('QBZ-95B', 'XP1', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('SCAR-H', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	weapon = Weapon('SG553LB', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Carabine)
	table.insert(self._weapons, weapon)

	---------------------------
	--LMG
	weapon = Weapon('L86', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('LSAT', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M249', '', {'Eotech', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M27IAR', '', {'Eotech', 'ExtendedMag', 'Weapons/Common/NoPrimaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M60', '', {'Ballistic_scope', 'Foregrip', 'TargetPointer'}, WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MG36', 'XP1', {'Ballistic_scope', 'Foregrip', 'ExtendedMag'}, WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Pecheneg', '', {'EOTech', 'Target_Pointer', 'Weapons/Common/NoPrimaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('QBB-95', 'XP1', {'EOTech', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Type88', '', {'EOTech', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	weapon = Weapon('RPK', '', {'Weapons/RPK/U_RPK_Kobra', 'Weapons/RPK/U_RPK_ExtendedMag', 'Weapons/RPK/U_RPK_Foregrip'},WeaponTypes.LMG, 'Weapons/RPK/U_RPK-74M')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M240', '', {'Eotech', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.LMG)
	table.insert(self._weapons, weapon)

	---------------------------
	-- Sniper
	weapon = Weapon('JNG90_6x', 'XP2', {'Rifle_Scope', 'StraightPull', 'Target_Pointer', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon)

	weapon = Weapon('JNG90_IRNV', 'XP2', {'IRNV', 'Silencer', 'StraightPull', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon)

	weapon = Weapon('JNG90_Balllistic', 'XP2', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon)

	weapon = Weapon('L96_Balllistic', 'XP1', {'Ballistic_20xScope', 'Bipod', 'FlashSuppressor', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon)

	weapon = Weapon('L96_6x', 'XP1', {'Rifle_6xScope', 'StraightPull', 'TargetPointer', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon)

	weapon = Weapon('L96_IRNV', 'XP1', {'IRNV', 'Silencer', 'StraightPull', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M39EBR', '', {'Ballistic_scope', 'Target_pointer', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/DefaultCamo'}, WeaponTypes.Sniper)
	table.insert(self._weapons, weapon)

	weapon = Weapon('M98B_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M98B_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M98B_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M40A5_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M40A5_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M40A5_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon)

	weapon = Weapon('HK417', 'XP2', {'Ballistic_Scope', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Sniper)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MK11', '', {'Ballistic_scope', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, WeaponTypes.Sniper)
	table.insert(self._weapons, weapon)

	weapon = Weapon('SKS_LongRange', '', {'PK-AS', 'Foregrip', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SKS_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SKS_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SV98', '', {'Ballistic_scope', 'StraightPull', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.Sniper)
	table.insert(self._weapons, weapon)

	weapon = Weapon('SVD_LongRange', '', {'PK-AS', 'Foregrip', 'FlashSuppressor'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SVD_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SVD_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon)


	---------------------------
	-- pistols
	weapon = Weapon('Glock17', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Glock17_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/Glock17/U_Glock17_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Glock18', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Glock18_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/Glock18/U_Glock18_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1911_Lit', '', {}, WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Lit')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1911_Silenced', '', {},WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1911_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Tactical')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M9', '', {}, WeaponTypes.Pistol, 'Weapons/M9/U_M9')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M9_Silenced', '', {},WeaponTypes.Pistol, 'Weapons/M9/U_M9_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M9_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/M9/U_M9_TacticalLight')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M93R', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP412Rex', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, weapon)

	weapon = Weapon('Taurus44', '', {}, WeaponTypes.Pistol)
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP443', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP443_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443_TacticalLight')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP443_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443_Silenced')
	table.insert(self._weapons, weapon)

	-- knifes
	weapon = Weapon('Razor', '', {}, WeaponTypes.Knife, 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Knife', '', {}, WeaponTypes.Knife)
	table.insert(self._weapons, weapon)

	---------------------------
	-- Sidearms
	weapon = Weapon('SMAW', '', {}, WeaponTypes.Rocket) -- only rockets supported for engineers right now
	table.insert(self._weapons, weapon)

	weapon = Weapon('RPG7', '', {}, WeaponTypes.Rocket) -- only rockets supported for engineers right now
	table.insert(self._weapons, weapon)

	weapon = Weapon('Repairtool', '', {}, WeaponTypes.Torch, 'Weapons/Gadgets/Repairtool/U_Repairtool')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Defib', '', {}, WeaponTypes.Defibrillator, 'Weapons/Gadgets/Defibrillator/U_Defib')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Medkit', '', {}, WeaponTypes.Medkit, 'Weapons/Gadgets/Medicbag/U_Medkit')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Ammobag', '', {}, WeaponTypes.Ammobag, 'Weapons/Gadgets/Ammobag/U_Ammobag')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Claymore', '', {}, WeaponTypes.Claymore, 'Weapons/Gadgets/Claymore/U_Claymore')
	table.insert(self._weapons, weapon)

	weapon = Weapon('C4', '', {}, WeaponTypes.C4, 'Weapons/Gadgets/C4/U_C4')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Tug', '', {}, WeaponTypes.Tugs, 'Weapons/Gadgets/T-UGS/U_UGS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Beacon', '', {}, WeaponTypes.Beacon, 'Weapons/Gadgets/RadioBeacon/U_RadioBeacon')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M67', '', {}, WeaponTypes.Grenade)
	table.insert(self._weapons, weapon)

	self:updateWeaponList()
end

function WeaponList:_isCustomWeapon(p_Class, p_Name)
	local customWeaponList = nil
	local isCustomWeapon = false
	if p_Class == BotKits.Assault then
		customWeaponList = CustomWeaponsAssault
	elseif p_Class == BotKits.Engineer then
		customWeaponList = CustomWeaponsEngineer
	elseif p_Class == BotKits.Support then
		customWeaponList = CustomWeaponsSupport
	elseif p_Class == BotKits.Recon then
		customWeaponList = CustomWeaponsRecon
	end

	for _,customName in pairs(customWeaponList) do
		if (customName == p_Name) then
			isCustomWeapon = true
			break
		end
	end

	return isCustomWeapon
end

function WeaponList:_useWeaponType(p_Class, p_Type, p_Name)
	local useThisWeapon = false
	local isClassWeapon = false
	local weaponSet = ""
	if p_Class == BotKits.Assault then
		weaponSet = Config.AssaultWeaponSet
		if p_Type == WeaponTypes.Assault then
			isClassWeapon = true
		end
	elseif p_Class == BotKits.Engineer then
		weaponSet = Config.EngineerWeaponSet
		if p_Type == WeaponTypes.Carabine then
			isClassWeapon = true
		end
	elseif p_Class == BotKits.Support then
		weaponSet = Config.SupportWeaponSet
		if p_Type == WeaponTypes.LMG then
			isClassWeapon = true
		end
	else --if p_Class == BotKits.Recon then
		weaponSet = Config.ReconWeaponSet
		if p_Type == WeaponTypes.Sniper then
			isClassWeapon = true
		end
	end

	-- check for custom-weapon
	if weaponSet == WeaponSets.Custom then
		useThisWeapon = self:_isCustomWeapon(p_Class, p_Name)
	else -- check for other p_Classes
		if p_Type == WeaponTypes.PDW then
			if weaponSet == WeaponSets.PDW or
			weaponSet == WeaponSets.Class_PDW or
			weaponSet == WeaponSets.Class_PDW_Shotgun or
			weaponSet == WeaponSets.PDW_Shotgun then
				useThisWeapon = true
			end
		elseif p_Type == WeaponTypes.Shotgun then
			if weaponSet == WeaponSets.Shotgun or
			weaponSet == WeaponSets.Class_Shotgun or
			weaponSet == WeaponSets.Class_PDW_Shotgun or
			weaponSet == WeaponSets.PDW_Shotgun then
				useThisWeapon = true
			end
		elseif p_Type == WeaponTypes.Assault or p_Type == WeaponTypes.Carabine or p_Type == WeaponTypes.LMG or p_Type == WeaponTypes.Sniper then
			if weaponSet == WeaponSets.Class or
			weaponSet == WeaponSets.Class_Shotgun or
			weaponSet == WeaponSets.Class_PDW_Shotgun or
			weaponSet == WeaponSets.Class_PDW then
				if isClassWeapon then
					useThisWeapon = true
				end
			end
		else
			-- for all other weapons - use p_Class-list
			useThisWeapon = self:_isCustomWeapon(p_Class, p_Name)
		end
	end
	return useThisWeapon
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

	for i=1, #self._weapons do
		local wep = self._weapons[i]
		table.insert(AllWeapons, wep.name)
		if (wep.type == WeaponTypes.Knife) then
			table.insert(KnifeWeapons, wep.name)
		elseif (wep.type == WeaponTypes.Pistol) then
			table.insert(PistoWeapons, wep.name)
		end

		if self:_useWeaponType(BotKits.Assault, wep.type, wep.name) then
			if (wep.type == WeaponTypes.Knife) then
				table.insert(AssaultKnife, wep.name)
			elseif (wep.type == WeaponTypes.Pistol) then
				table.insert(AssaultPistol, wep.name)
			elseif (wep.type == WeaponTypes.Grenade) then
				table.insert(AssaultGrenade, wep.name)
			elseif (wep.type == WeaponTypes.Medkit) then
				table.insert(AssaultGadget1, wep.name)
			elseif (wep.type == WeaponTypes.Defibrillator) then
				table.insert(AssaultGadget2, wep.name)
			else
				table.insert(AssaultPrimary, wep.name)
			end
		end
		if self:_useWeaponType(BotKits.Engineer, wep.type, wep.name) then
			if (wep.type == WeaponTypes.Knife) then
				table.insert(EngineerKnife, wep.name)
			elseif (wep.type == WeaponTypes.Pistol) then
				table.insert(EngineerPistol, wep.name)
			elseif (wep.type == WeaponTypes.Grenade) then
				table.insert(EngineerGrenade, wep.name)
			elseif (wep.type == WeaponTypes.Torch) then
				table.insert(EngineerGadget1, wep.name)
			elseif (wep.type == WeaponTypes.Rocket) then
				table.insert(EngineerGadget2, wep.name)
			else
				table.insert(EngineerPrimary, wep.name)
			end
		end
		if self:_useWeaponType(BotKits.Support, wep.type, wep.name) then
			if (wep.type == WeaponTypes.Knife) then
				table.insert(SupportKnife, wep.name)
			elseif (wep.type == WeaponTypes.Pistol) then
				table.insert(SupportPistol, wep.name)
			elseif (wep.type == WeaponTypes.Grenade) then
				table.insert(SupportGrenade, wep.name)
			elseif (wep.type == WeaponTypes.Ammobag) then
				table.insert(SupportGadget1, wep.name)
			elseif (wep.type == WeaponTypes.Claymore) or (wep.type == WeaponTypes.C4) then
				table.insert(SupportGadget2, wep.name)
			else
				table.insert(SupportPrimary, wep.name)
			end
		end
		if self:_useWeaponType(BotKits.Recon, wep.type, wep.name) then
			if (wep.type == WeaponTypes.Knife) then
				table.insert(ReconKnife, wep.name)
			elseif (wep.type == WeaponTypes.Pistol) then
				table.insert(ReconPistol, wep.name)
			elseif (wep.type == WeaponTypes.Grenade) then
				table.insert(ReconGrenade, wep.name)
			elseif (wep.type == WeaponTypes.Tugs) then
				table.insert(ReconGadget1, wep.name)
			elseif (wep.type == WeaponTypes.Beacon) then
				table.insert(ReconGadget2, wep.name)
			else
				table.insert(ReconPrimary, wep.name)
			end
		end
	end
end

function WeaponList:getWeapon(p_Name)
	local retWeapon = nil
	for _, weapon in pairs(self._weapons) do
		if weapon.name == p_Name then
			retWeapon = weapon
			break
		end
	end

	if (retWeapon == nil) then
		m_Logger:Warning('Weapon not found: '..tostring(p_Name))
	end

	return retWeapon
end

function WeaponList:onLevelLoaded()
	for _, weapon in pairs(self._weapons) do
		if weapon.needvalues then
			weapon:learnStatsValues()
		end
	end
end

if g_WeaponList == nil then
	g_WeaponList = WeaponList()
end

return g_WeaponList
