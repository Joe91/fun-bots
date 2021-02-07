class('WeaponList');

require('WeaponClass');

function WeaponList:__init()
	self._weapons		= {};

	local weapon = nil
	-- shotguns
	weapon = Weapon('USAS-12', '', {'ExtendedMag', 'Frag'}, 'Shotgun')
	weapon:setStatsValues(20, 150, 15, 3, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('saiga20', '', {'Kobra', 'Silencer', 'Frag'}, 'Shotgun', 'Weapons/SAIGA20K/U_SAIGA_20K')
	weapon:setStatsValues(20, 150, 15, 3, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('Jackhammer', 'XP1', {'Kobra', 'TargetPointer', 'Frag'}, 'Shotgun')
	weapon:setStatsValues(20, 150, 15, 3, 3, 0.6, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('DAO-12', '', {'Kobra', 'TargetPointer', 'Frag'}, 'Shotgun')
	weapon:setStatsValues(20, 150, 15, 3, 0.2, 0.2, false);
	table.insert(self._weapons, weapon);

	weapon = Weapon('SPAS12', 'XP2', {'Kobra', 'Frag'}, 'Shotgun')
	weapon:setStatsValues(37.5, 150, 15, 2, 0.4, 0.4, false);
	table.insert(self._weapons, weapon);

	-- others
	--assault
	weapon = Weapon('M416', '', {'Kobra', 'HeavyBarrel'},'Assault')
	weapon:setStatsValues(25, 580, 15, 10, 0.4, 0.4, false);
	table.insert(self._weapons, weapon);

	weapon = Weapon('AEK971', '', {'Kobra', 'HeavyBarrel'}, 'Assault')
	weapon:setStatsValues(25, 580, 15, 10, 0.4, 0.4, false);
	table.insert(self._weapons, weapon);

	--engi
	weapon = Weapon('ASVal', '', {'Kobra', 'ExtendedMag'}, 'Carabine')
	weapon:setStatsValues(18, 333, 9.81, 10, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('M4A1', '', {'Kobra', 'Silencer'}, 'Carabine')
	weapon:setStatsValues(25, 580, 15, 10, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('SCAR-H', '', {'Kobra', 'Silencer'}, 'Carabine')
	weapon:setStatsValues(30, 420, 15, 10, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	--support
	weapon = Weapon('M249', '', {'Eotech', 'Bipod'},'LMG')
	weapon:setStatsValues( 25, 620, 15, 20, 2.0, 0.6, true)
	table.insert(self._weapons, weapon);

	weapon = Weapon('M240', '', {'Eotech', 'Bipod'}, 'LMG')
	weapon:setStatsValues(34, 610, 15, 20, 2.0, 0.6, true)
	table.insert(self._weapons, weapon);

	-- recon
	weapon = Weapon('L96', 'XP1', {'Rifle_6xScope', 'StraightPull'}, 'Sniper')
	weapon:setStatsValues(80, 540, 9.81, 3, 0.2, 0.5, true);
	table.insert(self._weapons, weapon);

	weapon = Weapon('M98B', '', {'Ballistic_Scope', 'StraightPull'}, 'Sniper', 'Weapons/Model98B/U_M98B')
	weapon:setStatsValues(95, 650, 9.81, 3, 0.2, 0.5, true);
	table.insert(self._weapons, weapon);

	weapon = Weapon('SKS', '', {'Rifle_Scope', 'Target_Pointer'}, 'Sniper')
	weapon:setStatsValues(43, 440, 15, 3, 0.2, 0.2, true);
	table.insert(self._weapons, weapon);

	-- pistols
	weapon = Weapon('M1911_Lit', '', {}, 'Pistol', 'Weapons/M1911/U_M1911_Lit')
	weapon:setStatsValues(34, 300, 15, 4, 0.2, 0.2, false);
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1911_Silenced', '', {},'Pistol', 'Weapons/M1911/U_M1911_Silenced')
	weapon:setStatsValues(34, 300, 15, 4, 0.2, 0.2, false);
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1911_Tactical', '', {}, 'Pistol', 'Weapons/M1911/U_M1911_Tactical')
	weapon:setStatsValues(34, 300, 15, 4, 0.2, 0.2, false);
	table.insert(self._weapons, weapon);

	weapon = Weapon('MP412Rex', '', {}, 'Pistol')
	weapon:setStatsValues(50, 300, 15, 2, 0.2, 0.2, false);
	table.insert(self._weapons, weapon);

	weapon = Weapon('Taurus44', '', {}, 'Pistol')
	weapon:setStatsValues(60, 460, 15, 2, 0.2, 0.2, false);
	table.insert(self._weapons, weapon);

	-- knifes
	weapon = Weapon('Razor', '', {}, 'Knife', 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor')
	weapon:setStatsValues(70, 0, 0, 0, 1, 0, false);
	table.insert(self._weapons, weapon);

	weapon = Weapon('Knife', '', {}, 'Knife')
	weapon:setStatsValues( 50, 0, 0, 0, 1, 0, false);
	table.insert(self._weapons, weapon);
end

function WeaponList:getWeapon(name)
	local retWeapon = nil;
	for _, weapon in pairs(self._weapons) do
		if weapon.name == name then
			retWeapon = weapon;
			break;
		end
	end
	return retWeapon;
end


if (g_WeaponList == nil) then
	g_WeaponList = WeaponList();
end

return g_WeaponList;