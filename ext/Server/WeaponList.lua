class('WeaponList');

require('WeaponClass');

function WeaponList:__init()
	self._weapons		= {};

	local weapon = nil

	-- shotguns
	weapon = Weapon('USAS-12', '', {'ExtendedMag', 'Frag'}, 33, 150, 15, 3, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('saiga20', '', {'Kobra', 'Silencer', 'Frag'}, 33, 150, 15, 3, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('Jackhammer', 'XP1', {'Kobra', 'TargetPointer', 'Frag'}, 33, 150, 15, 3, 3, 0.6, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('SPAS12', 'XP2', {'Kobra', 'Frag'}, 33, 150, 15, 3, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	-- others
	weapon = Weapon('M416', '', {'Kobra', 'HeavyBarrel'}, 25, 580, 15, 10, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('AEK971', '', {'Kobra', 'HeavyBarrel'}, 25, 580, 15, 10, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('ASVal', '', {'Kobra', 'ExtendedMag'}, 18, 333, 9.81, 10, 0.4, 0.4, false)
	table.insert(self._weapons, weapon);

	weapon = Weapon('M249', '', {'Eotech', 'Bipod'}, 25, 600, 15, 20, 0.4, 0.4, true)
	table.insert(self._weapons, weapon);

	weapon = Weapon('L96', 'XP1', {'6xScope', 'StraightPull'}, 80, 540, 9.81, 4, 0.4, 0.4, true)
	table.insert(self._weapons, weapon);

	-- pistols
	weapon = Weapon('M1911_Lit', '', {}, 34, 300, 4, 0.2, 0.2, false, 'Weapons/M1911/U_M1911_Lit')
	table.insert(self._weapons, weapon);

	weapon = Weapon('M1911_Lit', '', {}, 34, 300, 4, 0.2, 0.2, false, 'Weapons/M1911/U_M1911_Lit')
	table.insert(self._weapons, weapon);

	-- knifes
	weapon = Weapon('Razor', '', {}, 50, 0, 0, 0, 0, false, )
	table.insert(self._weapons, weapon);

	weapon = Weapon('Knife', '', {}, 50, 0, 0, 0, 0, false, 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor')
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