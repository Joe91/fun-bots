class('WeaponList')

require('__shared/WeaponClass')
require('__shared/Config')
require('__shared/WeaponLists/CustomWeaponsAssault')
require('__shared/WeaponLists/CustomWeaponsEngineer')
require('__shared/WeaponLists/CustomWeaponsRecon')
require('__shared/WeaponLists/CustomWeaponsSupport')

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
	weapon = Weapon('DAO-12', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, 'Shotgun')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Jackhammer', 'XP1', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, 'Shotgun')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Saiga20', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'Silencer'}, 'Shotgun', 'Weapons/SAIGA20K/U_SAIGA_20K')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SPAS12', 'XP2', {'Slug', 'Kobra', 'Weapons/Common/NoPrimaryAccessory'}, 'Shotgun')   --TODO: Get Damage-Values and Speed of other ammo
	table.insert(self._weapons, weapon)

	weapon = Weapon('USAS-12', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag', 'Weapons/Common/NoOptics'}, 'Shotgun')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1014', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag', 'Weapons/Common/NoOptics'}, 'Shotgun')
	table.insert(self._weapons, weapon)

	weapon = Weapon('870M', '', {'Weapons/Remington870/U_870_Slug', 'Weapons/Remington870/U_870_ExtendedMag', 'Weapons/Common/NoOptics'}, 'Shotgun', 'Weapons/Remington870/U_870')
	table.insert(self._weapons, weapon)

	---------------------------
	--assault
	weapon = Weapon('AEK971', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, 'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('AN94', '', {'Kobra', 'Foregrip', 'Flashsuppressor'}, 'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('AK74M', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, 'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SteyrAug', 'XP2', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('F2000', '', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('FAMAS', 'XP1', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'}, 'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('G3A3', '', {'Kobra', 'Target_Pointer', 'Foregrip'}, 'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('KH2002', '', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'}, 'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('L85A2', 'XP1', {'Kobra', 'FlashSuppressor', 'Weapons/Common/NoSecondaryRail'},'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M16A4', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'}, 'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M416', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Weapons/Common/NoSecondaryRail'},'Assault')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SCAR-L', 'XP2', {'Kobra', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},'Assault')
	table.insert(self._weapons, weapon)


	---------------------------
	-- PDW --------------------
	weapon = Weapon('ASVal', '', {'Kobra', 'ExtendedMag', 'Weapons/Common/NoSecondaryAccessory'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP7', '', {'Kobra', 'ExtendedMag', 'Weapons/Common/NoPrimaryAccessory'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('P90', '', {'Kobra', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/NoSecondaryAccessory'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('PP-19', 'XP1', {'IRNV', 'Silencer', 'TargetPointer', 'Weapons/Common/DefaultCamo'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('PP2000', '', {'Kobra', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/NoSecondaryAccessory'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('UMP45', '', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Flashlight', 'Weapons/Common/DefaultCamo'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP5K', 'XP2', {'Kobra', 'Weapons/Common/NoSecondaryAccessory', 'Flashlight'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MagpulPDR', '', {'Kobra', 'Flashsuppressor', 'Weapons/Common/NoPrimaryAccessory'}, 'PDW')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Crossbow', '', {}, 'PDW', 'Weapons/XP4_Crossbow_Prototype/U_Crossbow_Scoped_Cobra')
	table.insert(self._weapons, weapon)


	---------------------------
	--Carabines
	weapon = Weapon('A91', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('ACR', 'XP2', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('AKS74u', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('G36C', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('HK53', 'XP1', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M4A1', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MTAR', 'XP2', {'Kobra', 'Silencer', 'Foregrip'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('QBZ-95B', 'XP1', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SCAR-H', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SG553LB', '', {'Kobra', 'Silencer', 'Weapons/Common/NoPrimaryAccessory'}, 'Carabine')
	table.insert(self._weapons, weapon)

	---------------------------
	--LMG
	weapon = Weapon('L86', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('LSAT', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M249', '', {'Eotech', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'},'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M27IAR', '', {'Eotech', 'ExtendedMag', 'Weapons/Common/NoPrimaryAccessory'},'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M60', '', {'Ballistic_scope', 'Foregrip', 'TargetPointer'}, 'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MG36', 'XP1', {'Ballistic_scope', 'Foregrip', 'ExtendedMag'}, 'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Pecheneg', '', {'EOTech', 'Target_Pointer', 'Weapons/Common/NoPrimaryAccessory'},'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('QBB-95', 'XP1', {'EOTech', 'Foregrip', 'Weapons/Common/NoSecondaryAccessory'},'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Type88', '', {'EOTech', 'ExtendedMag', 'Foregrip'},'LMG')
	table.insert(self._weapons, weapon)

	weapon = Weapon('RPK', '', {'Weapons/RPK/U_RPK_Kobra', 'Weapons/RPK/U_RPK_ExtendedMag', 'Weapons/RPK/U_RPK_Foregrip'},'LMG', 'Weapons/RPK/U_RPK-74M')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M240', '', {'Eotech', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, 'LMG')
	table.insert(self._weapons, weapon)

	---------------------------
	-- Sniper
	weapon = Weapon('JNG90_6x', 'XP2', {'Rifle_Scope', 'StraightPull', 'Target_Pointer', 'Weapons/Common/DefaultCamo'}, 'Sniper', 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon)

	weapon = Weapon('JNG90_IRNV', 'XP2', {'IRNV', 'Silencer', 'StraightPull', 'Weapons/Common/DefaultCamo'}, 'Sniper', 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon)

	weapon = Weapon('JNG90_Balllistic', 'XP2', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor', 'Weapons/Common/DefaultCamo'}, 'Sniper', 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon)

	weapon = Weapon('L96_Balllistic', 'XP1', {'Ballistic_20xScope', 'Bipod', 'FlashSuppressor', 'Weapons/Common/DefaultCamo'}, 'Sniper', 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon)

	weapon = Weapon('L96_6x', 'XP1', {'Rifle_6xScope', 'StraightPull', 'TargetPointer', 'Weapons/Common/DefaultCamo'}, 'Sniper', 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon)

	weapon = Weapon('L96_IRNV', 'XP1', {'IRNV', 'Silencer', 'StraightPull', 'Weapons/Common/DefaultCamo'}, 'Sniper', 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M39EBR', '', {'Ballistic_scope', 'Target_pointer', 'Weapons/Common/NoPrimaryAccessory', 'Weapons/Common/DefaultCamo'}, 'Sniper')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M98B_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, 'Sniper', 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M98B_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, 'Sniper', 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M98B_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, 'Sniper', 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M40A5_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, 'Sniper', 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M40A5_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, 'Sniper', 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M40A5_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, 'Sniper', 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon)

	weapon = Weapon('HK417', 'XP2', {'Ballistic_Scope', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, 'Sniper')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MK11', '', {'Ballistic_scope', 'TargetPointer', 'Weapons/Common/NoPrimaryAccessory'}, 'Sniper')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SKS_LongRange', '', {'PK-AS', 'Foregrip', 'Target_Pointer'}, 'Sniper', 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SKS_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, 'Sniper', 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SKS_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, 'Sniper', 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SV98', '', {'Ballistic_scope', 'StraightPull', 'Weapons/Common/NoSecondaryAccessory'}, 'Sniper')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SVD_LongRange', '', {'PK-AS', 'Foregrip', 'FlashSuppressor'}, 'Sniper', 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SVD_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, 'Sniper', 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon)

	weapon = Weapon('SVD_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, 'Sniper', 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon)


	---------------------------
	-- pistols
	weapon = Weapon('Glock17', '', {}, 'Pistol')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Glock17_Silenced', '', {}, 'Pistol', 'Weapons/Glock17/U_Glock17_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Glock18', '', {}, 'Pistol')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Glock18_Silenced', '', {}, 'Pistol', 'Weapons/Glock18/U_Glock18_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1911_Lit', '', {}, 'Pistol', 'Weapons/M1911/U_M1911_Lit')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1911_Silenced', '', {},'Pistol', 'Weapons/M1911/U_M1911_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M1911_Tactical', '', {}, 'Pistol', 'Weapons/M1911/U_M1911_Tactical')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M9', '', {}, 'Pistol', 'Weapons/M9/U_M9')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M9_Silenced', '', {},'Pistol', 'Weapons/M9/U_M9_Silenced')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M9_Tactical', '', {}, 'Pistol', 'Weapons/M9/U_M9_TacticalLight')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M93R', '', {}, 'Pistol')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP412Rex', '', {}, 'Pistol')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Taurus44', '', {}, 'Pistol')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP443', '', {}, 'Pistol', 'Weapons/MP443/U_MP443')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP443_Tactical', '', {}, 'Pistol', 'Weapons/MP443/U_MP443_TacticalLight')
	table.insert(self._weapons, weapon)

	weapon = Weapon('MP443_Silenced', '', {}, 'Pistol', 'Weapons/MP443/U_MP443_Silenced')
	table.insert(self._weapons, weapon)

	-- knifes
	weapon = Weapon('Razor', '', {}, 'Knife', 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Knife', '', {}, 'Knife')
	table.insert(self._weapons, weapon)

	---------------------------
	-- Sidearms
	weapon = Weapon('SMAW', '', {}, 'Rocket')		-- only rockets supported for engineers right now
	table.insert(self._weapons, weapon)

	weapon = Weapon('RPG7', '', {}, 'Rocket')		-- only rockets supported for engineers right now
	table.insert(self._weapons, weapon)

	weapon = Weapon('Repairtool', '', {}, 'Torch', 'Weapons/Gadgets/Repairtool/U_Repairtool')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Defib', '', {}, 'Defibrillator', 'Weapons/Gadgets/Defibrillator/U_Defib')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Medkit', '', {}, 'Medkit', 'Weapons/Gadgets/Medicbag/U_Medkit')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Ammobag', '', {}, 'Ammobag', 'Weapons/Gadgets/Ammobag/U_Ammobag')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Claymore', '', {}, 'Claymore', 'Weapons/Gadgets/Claymore/U_Claymore')
	table.insert(self._weapons, weapon)

	weapon = Weapon('C4', '', {}, 'C4', 'Weapons/Gadgets/C4/U_C4')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Tug', '', {}, 'Tug', 'Weapons/Gadgets/T-UGS/U_UGS')
	table.insert(self._weapons, weapon)

	weapon = Weapon('Beacon', '', {}, 'Beacon', 'Weapons/Gadgets/RadioBeacon/U_RadioBeacon')
	table.insert(self._weapons, weapon)

	weapon = Weapon('M67', '', {}, 'Grenade')
	table.insert(self._weapons, weapon)

	self:updateWeaponList()
end

function WeaponList:_isCustomWeapon(class, name)
	local customWeaponList = nil
	local isCustomWeapon = false
	if class == "Assault" then
		customWeaponList = CustomWeaponsAssault
	elseif class == "Engineer" then
		customWeaponList = CustomWeaponsEngineer
	elseif class == "Support" then
		customWeaponList = CustomWeaponsSupport
	elseif class == "Recon" then
		customWeaponList = CustomWeaponsRecon
	-- use thhis function for pistols as well
	elseif class == "Pistol" then
		customWeaponList = CustomWeaponsPistols
	end

	for _,customName in pairs(customWeaponList) do
		if (customName == name) then
			isCustomWeapon = true
			break
		end
	end

	return isCustomWeapon
end

function WeaponList:_useWeaponType(class, type, name)
	local useThisWeapon = false
	local isClassWeapon = false
	local weaponSet = ""
	if class == "Assault" then
		weaponSet = Config.AssaultWeaponSet
		if type == "Assault" then
			isClassWeapon = true
		end
	elseif class == "Engineer" then
		weaponSet = Config.EngineerWeaponSet
		if type == "Carabine" then
			isClassWeapon = true
		end
	elseif class == "Support" then
		weaponSet = Config.SupportWeaponSet
		if type == "LMG" then
			isClassWeapon = true
		end
	else --if class == "Recon" then
		weaponSet = Config.ReconWeaponSet
		if type == "Sniper" then
			isClassWeapon = true
		end
	end

	-- check for custom-weapon
	if weaponSet == "Custom" then
		useThisWeapon = self:_isCustomWeapon(class, name)
	else -- check for other classes
		if type == "PDW" then
			if weaponSet == "PDW" or
			weaponSet == "Class_PDW" or
			weaponSet == "Class_PDW_Shotgun" or
			weaponSet == "PDW_Shotgun" then
				useThisWeapon = true
			end
		elseif type == "Shotgun" then
			if weaponSet == "Shotgun" or
			weaponSet == "Class_Shotgun" or
			weaponSet == "Class_PDW_Shotgun" or
			weaponSet == "PDW_Shotgun" then
				useThisWeapon = true
			end
		elseif type == "Assault" or type == "Carabine" or type == "LMG" or type == "Sniper" then
			if weaponSet == "Class" or
			weaponSet == "Class_Shotgun" or
			weaponSet == "Class_PDW_Shotgun" or
			weaponSet == "Class_PDW" then
				if isClassWeapon then
					useThisWeapon = true
				end
			end
		else
			-- for all other weapons - use class-list
			useThisWeapon = self:_isCustomWeapon(class, name)
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
		if (wep.type == 'Knife') then
			table.insert(KnifeWeapons, wep.name)
		elseif (wep.type == 'Pistol') then
			table.insert(PistoWeapons, wep.name)
		end


		if self:_useWeaponType("Assault", wep.type, wep.name) then
			if (wep.type == 'Knife') then
				table.insert(AssaultKnife, wep.name)
			elseif (wep.type == 'Pistol') then
				table.insert(AssaultPistol, wep.name)
			elseif (wep.type == 'Grenade') then
				table.insert(AssaultGrenade, wep.name)
			elseif (wep.type == "Medkit") then
				table.insert(AssaultGadget1,  wep.name)
			elseif (wep.type == "Defibrillator") then
				table.insert(AssaultGadget2,  wep.name)
			else
				table.insert(AssaultPrimary, wep.name)
			end
		end
		if self:_useWeaponType("Engineer", wep.type, wep.name) then
			if (wep.type == 'Knife') then
				table.insert(EngineerKnife, wep.name)
			elseif (wep.type == 'Pistol') then
				table.insert(EngineerPistol, wep.name)
			elseif (wep.type == 'Grenade') then
				table.insert(EngineerGrenade, wep.name)
			elseif (wep.type == "Torch") then
				table.insert(EngineerGadget1,  wep.name)
			elseif (wep.type == "Rocket") then
				table.insert(EngineerGadget2,  wep.name)
			else
				table.insert(EngineerPrimary, wep.name)
			end
		end
		if self:_useWeaponType("Support", wep.type, wep.name) then
			if (wep.type == 'Knife') then
				table.insert(SupportKnife, wep.name)
			elseif (wep.type == 'Pistol') then
				table.insert(SupportPistol, wep.name)
			elseif (wep.type == 'Grenade') then
				table.insert(SupportGrenade, wep.name)
			elseif (wep.type == "Ammobag") then
				table.insert(SupportGadget1,  wep.name)
			elseif (wep.type == "Claymore") or (wep.type == "C4") then
				table.insert(SupportGadget2,  wep.name)
			else
				table.insert(SupportPrimary, wep.name)
			end
		end
		if self:_useWeaponType("Recon", wep.type, wep.name) then
			if (wep.type == 'Knife') then
				table.insert(ReconKnife, wep.name)
			elseif (wep.type == 'Pistol') then
				table.insert(ReconPistol, wep.name)
			elseif (wep.type == 'Grenade') then
				table.insert(ReconGrenade, wep.name)
			elseif (wep.type == "Tug") then
				table.insert(ReconGadget1,  wep.name)
			elseif (wep.type == "Beacon") then
				table.insert(ReconGadget2,  wep.name)
			else
				table.insert(ReconPrimary, wep.name)
			end
		end
	end
end

function WeaponList:getWeapon(name)
	local retWeapon = nil
	for _, weapon in pairs(self._weapons) do
		if weapon.name == name then
			retWeapon = weapon
			break
		end
	end

	if (retWeapon == nil) then
		if Debug.Shared.MODIFICATIONS then
			print('Warning! Weapon not found: '..tostring(name))
		end
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


if (g_WeaponList == nil) then
	g_WeaponList = WeaponList()
end

return g_WeaponList
