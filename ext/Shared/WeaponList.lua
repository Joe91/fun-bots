class('WeaponList');

require('__shared/WeaponClass');
require('__shared/Config');

-- create globals
AllWeapons = {}
KnifeWeapons = {}
PistoWeapons = {}
WeaponsAssault = {}
WeaponsEngineer = {}
WeaponsRecon = {}
WeaponsSupport = {}

function WeaponList:__init()
	self._weapons = {};

	local weapon = nil

	---------------------------
	-- shotguns
	weapon = Weapon('DAO-12', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, 'Shotgun')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Jackhammer', 'XP1', {'Weapons/Common/12gBuckshot', 'Kobra', 'TargetPointer'}, 'Shotgun')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Saiga20', '', {'Weapons/Common/12gBuckshot', 'Kobra', 'Silencer'}, 'Shotgun', 'Weapons/SAIGA20K/U_SAIGA_20K')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SPAS12', 'XP2', {'Slug', 'Kobra'}, 'Shotgun')   --TODO: Get Damage-Values and Speed of other ammo
	table.insert(self._weapons, weapon);

	weapon = Weapon('USAS-12', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag'}, 'Shotgun')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1014', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag'}, 'Shotgun')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1014', '', {'Weapons/Common/12gBuckshot', 'ExtendedMag'}, 'Shotgun')
	table.insert(self._weapons, weapon);

	weapon = Weapon('870M', '', {'Weapons/Remington870/U_870_Slug', 'Weapons/Remington870/U_870_ExtendedMag'}, 'Shotgun', 'Weapons/Remington870/U_870')
	table.insert(self._weapons, weapon);

	---------------------------
	--assault
	weapon = Weapon('AEK971', '', {'Kobra'}, 'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('AN94', '', {'Kobra', 'Foregrip'}, 'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('AK74M', '', {'Kobra'}, 'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SteyrAug', 'XP2', {'Kobra', 'Foregrip'},'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('F2000', '', {'Kobra', 'Foregrip'},'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('FAMAS', 'XP1', {'Kobra', 'Foregrip'}, 'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('G3A3', '', {'Kobra', 'Target_Pointer', 'Foregrip'}, 'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('KH2002', '', {'Kobra', 'Foregrip'}, 'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('L85A2', 'XP1', {'Kobra', 'FlashSuppressor'},'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M16A4', '', {'Kobra'}, 'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M416', '', {'Kobra'},'Assault')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SCAR-L', 'XP2', {'Kobra', 'Foregrip'},'Assault')
	table.insert(self._weapons, weapon);


	---------------------------
	-- PDW --------------------
	weapon = Weapon('ASVal', '', {'Kobra', 'ExtendedMag'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('MP7', '', {'Kobra', 'ExtendedMag'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('P90', '', {'Kobra'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('PP-19', 'XP1', {'IRNV', 'Silencer', 'TargetPointer'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('PP2000', '', {'Kobra'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('UMP45', '', {'Kobra', 'Flashlight'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('MP5K', 'XP2', {'Kobra', 'Flashlight'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('MagpulPDR', '', {'Kobra', 'Flashsuppressor'}, 'PDW')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Crossbow', '', {}, 'PDW', 'Weapons/XP4_Crossbow_Prototype/U_Crossbow_Scoped_Cobra')
	table.insert(self._weapons, weapon);


	---------------------------
	--Carabines
	weapon = Weapon('A91', '', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);
	
	weapon = Weapon('ACR', 'XP2', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('AKS74u', '', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('G36C', '', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('HK53', 'XP1', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M4A1', '', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('MTAR', 'XP2', {'Kobra', 'Silencer', 'Foregrip'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('QBZ-95B', 'XP1', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SCAR-H', '', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SG553LB', '', {'Kobra', 'Silencer'}, 'Carabine')
	table.insert(self._weapons, weapon);

	-- comment these lines if you don't like rockets
	weapon = Weapon('SMAW', '', {}, 'Carabine')
	table.insert(self._weapons, weapon)

	weapon = Weapon('RPG7', '', {}, 'Carabine')
	table.insert(self._weapons, weapon)

	---------------------------
	--LMG
	weapon = Weapon('L86', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('LSAT', 'XP2', {'EOTech', 'ExtendedMag', 'Foregrip'},'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M249', '', {'Eotech', 'TargetPointer'},'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M27IAR', '', {'Eotech', 'ExtendedMag'},'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M60', '', {'Ballistic_scope', 'Foregrip', 'TargetPointer'}, 'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('MG36', 'XP1', {'Ballistic_scope', 'Foregrip', 'ExtendedMag'}, 'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Pecheneg', '', {'EOTech', 'Target_Pointer'},'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('QBB-95', 'XP1', {'EOTech', 'Foregrip'},'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Type88', '', {'EOTech', 'ExtendedMag', 'Foregrip'},'LMG')
	table.insert(self._weapons, weapon);

	weapon = Weapon('RPK', '', {'Weapons/RPK/U_RPK_Kobra', 'Weapons/RPK/U_RPK_ExtendedMag', 'Weapons/RPK/U_RPK_Foregrip'},'LMG', 'Weapons/RPK/U_RPK-74M')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M240', '', {'Eotech', 'TargetPointer'}, 'LMG')  -- not usable, because it has the same ammo as some sniper rifles
	table.insert(self._weapons, weapon);

	---------------------------
	-- Sniper
	weapon = Weapon('JNG90_6x', 'XP2', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, 'Sniper', 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon);

	weapon = Weapon('JNG90_IRNV', 'XP2', {'IRNV', 'Silencer', 'StraightPull'}, 'Sniper', 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon);

	weapon = Weapon('JNG90_Balllistic', 'XP2', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, 'Sniper', 'Weapons/XP2_JNG90/U_JNG90')
	table.insert(self._weapons, weapon);

	weapon = Weapon('L96_Balllistic', 'XP1', {'Ballistic_20xScope', 'Bipod', 'FlashSuppressor'}, 'Sniper', 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon);

	weapon = Weapon('L96_6x', 'XP1', {'Rifle_6xScope', 'StraightPull', 'TargetPointer'}, 'Sniper', 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon);

	weapon = Weapon('L96_IRNV', 'XP1', {'IRNV', 'Silencer', 'StraightPull'}, 'Sniper', 'Weapons/XP1_L96/U_L96')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M39EBR', '', {'Ballistic_scope', 'Target_pointer'}, 'Sniper')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M98B_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, 'Sniper', 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M98B_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, 'Sniper', 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M98B_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, 'Sniper', 'Weapons/Model98B/U_M98B')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M40A5_Balllistic', '', {'Ballistic_Scope', 'Bipod', 'Flash_Suppressor'}, 'Sniper', 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M40A5_6x', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, 'Sniper', 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M40A5_IRNV', '', {'IRNV', 'Silencer', 'StraightPull'}, 'Sniper', 'Weapons/M40A5/U_M40A5')
	table.insert(self._weapons, weapon);

	weapon = Weapon('HK417', 'XP2', {'Ballistic_Scope', 'TargetPointer'}, 'Sniper')
	table.insert(self._weapons, weapon);
	
	weapon = Weapon('MK11', '', {'Ballistic_scope', 'TargetPointer'}, 'Sniper')
	table.insert(self._weapons, weapon);
	
	weapon = Weapon('SKS_LongRange', '', {'PK-AS', 'Foregrip'}, 'Sniper', 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SKS_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, 'Sniper', 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SKS_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, 'Sniper', 'Weapons/SKS/U_SKS')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SV98', '', {'Ballistic_scope', 'StraightPull'}, 'Sniper')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SVD_LongRange', '', {'PK-AS', 'Foregrip', 'FlashSuppressor'}, 'Sniper', 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SVD_Tryhard', '', {'Kobra', 'Foregrip', 'Target_Pointer'}, 'Sniper', 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon);

	weapon = Weapon('SVD_IRNV', '', {'IRNV', 'Foregrip', 'Silencer'}, 'Sniper', 'Weapons/SVD/U_SVD')
	table.insert(self._weapons, weapon);


	---------------------------
	-- pistols
	weapon = Weapon('Glock17', '', {}, 'Pistol')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Glock17_Silenced', '', {}, 'Pistol', 'Weapons/Glock17/U_Glock17_Silenced')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Glock18', '', {}, 'Pistol')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Glock18_Silenced', '', {}, 'Pistol', 'Weapons/Glock18/U_Glock18_Silenced')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1911_Lit', '', {}, 'Pistol', 'Weapons/M1911/U_M1911_Lit')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1911_Silenced', '', {},'Pistol', 'Weapons/M1911/U_M1911_Silenced')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1911_Tactical', '', {}, 'Pistol', 'Weapons/M1911/U_M1911_Tactical')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M9', '', {}, 'Pistol', 'Weapons/M9/U_M9')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M9_Silenced', '', {},'Pistol', 'Weapons/M9/U_M9_Silenced')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M9_Tactical', '', {}, 'Pistol', 'Weapons/M9/U_M9_TacticalLight')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M93R', '', {}, 'Pistol')
	table.insert(self._weapons, weapon);

	weapon = Weapon('MP412Rex', '', {}, 'Pistol')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Taurus44', '', {}, 'Pistol')
	table.insert(self._weapons, weapon);

	weapon = Weapon('MP443', '', {}, 'Pistol') --TODO: find out why not working
	table.insert(self._weapons, weapon);

	-- knifes
	weapon = Weapon('Razor', '', {}, 'Knife', 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor')
	table.insert(self._weapons, weapon);

	weapon = Weapon('Knife', '', {}, 'Knife')
	table.insert(self._weapons, weapon);

	self:updateWeaponList();
end

function WeaponList:_useWeaponType(class, type)
	local useThisWeapon = false;
	local isClassWeapon = false;
	local weaponSet = ""
	if class == "Assault" then
		weaponSet = Config.assaultWeaponSet;
		if type == "Assault" then
			isClassWeapon = true;
		end
	elseif class == "Engineer" then
		weaponSet = Config.engineerWeaponSet;
		if type == "Carabine" then
			isClassWeapon = true;
		end
	elseif class == "Support" then
		weaponSet = Config.supportWeaponSet;
		if type == "LMG" then
			isClassWeapon = true;
		end
	else --if class == "Recon" then
		weaponSet = Config.reconWeaponSet;
		if type == "Sniper" then
			isClassWeapon = true;
		end
	end
	if type == "PDW" then
		if weaponSet == "PDW" or
		weaponSet == "Class_PDW" or
		weaponSet == "Class_PDW_Shotgun" or
		weaponSet == "PDW_Shotgun" then
			useThisWeapon = true;
		end
	elseif type == "Shotgun" then
		if weaponSet == "Shotgun" or
		weaponSet == "Class_Shotgun" or
		weaponSet == "Class_PDW_Shotgun" or
		weaponSet == "PDW_Shotgun" then
			useThisWeapon = true;
		end
	else
		if weaponSet == "Class" or
		weaponSet == "Class_Shotgun" or
		weaponSet == "Class_PDW_Shotgun" or
		weaponSet == "Class_PDW" then
			if isClassWeapon then
				useThisWeapon = true;
			end
		end
	end
	return useThisWeapon;
end

function WeaponList:updateWeaponList()
	AllWeapons = {}
	KnifeWeapons = {}
	PistoWeapons = {}
	WeaponsAssault = {}
	WeaponsEngineer = {}
	WeaponsRecon = {}
	WeaponsSupport = {}

	for i=1, #self._weapons do
		local wep = self._weapons[i]
		table.insert(AllWeapons, wep.name)

		if (wep.type == 'Knife') then
			table.insert(KnifeWeapons, wep.name)

		elseif (wep.type == 'Pistol') then
			table.insert(PistoWeapons, wep.name)

		else --'PDW' 'Shotgun' 'Assault' 'Carabine' 'LMG' 'Sniper'
			if self:_useWeaponType("Assault", wep.type) then
				table.insert(WeaponsAssault, wep.name)
			end
			if self:_useWeaponType("Engineer", wep.type) then
				table.insert(WeaponsEngineer, wep.name)
			end
			if self:_useWeaponType("Support", wep.type) then
				table.insert(WeaponsSupport, wep.name)
			end
			if self:_useWeaponType("Recon", wep.type) then
				table.insert(WeaponsRecon, wep.name)
			end
		end
	end
end

function WeaponList:getWeapon(name)
	local retWeapon = nil;
	for _, weapon in pairs(self._weapons) do
		if weapon.name == name then
			retWeapon = weapon;
			break;
		end
	end

	if (retWeapon == nil) then
		print('Warning! Weapon not found: '..tostring(name))
	end

	return retWeapon;
end

function WeaponList:onLevelLoaded()
	for _, weapon in pairs(self._weapons) do
		if weapon.needvalues then
			weapon:learnStatsValues();
		end
	end
end


if (g_WeaponList == nil) then
	g_WeaponList = WeaponList();
end

return g_WeaponList;