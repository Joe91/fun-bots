class('WeaponList');

require('WeaponClass');

function WeaponList:__init()
	self._weapons		= {};

	local weapon = nil
	weapon = Weapon('USAS-12', '', {'ExtendedMag', 'Frag'} , true, 0.4, 0.4)
	table.insert(self._weapons, weapon);

	weapon = Weapon('saiga20', '', {'Kobra', 'Silencer', 'Frag'} , true, 0.4, 0.4)
	table.insert(self._weapons, weapon);

	weapon = Weapon('Jackhammer', 'XP1', {'Kobra', 'TargetPointer', 'Frag'} , true, 3, 0.6)
	table.insert(self._weapons, weapon);

	weapon = Weapon('SPAS12', 'XP2', {'Kobra', 'Frag'} , true, 0.4, 0.4)
	table.insert(self._weapons, weapon);

	weapon = Weapon('M416', '', {'Kobra', 'HeavyBarrel'} , false, 0.4, 0.4)
	table.insert(self._weapons, weapon);

	weapon = Weapon('AEK971', '', {'Kobra', 'HeavyBarrel'} , false, 0.4, 0.4)
	table.insert(self._weapons, weapon);

	weapon = Weapon('ASVal', '', {'Kobra', 'ExtendedMag'} , false, 0.4, 0.4)
	table.insert(self._weapons, weapon);

	weapon = Weapon('M249', '', {'Eotech', 'Bipod'} , false, 0.4, 0.4)
	table.insert(self._weapons, weapon);

	weapon = Weapon('L96', 'XP1', {'6xScope', 'StraightPull'} , false, 0.4, 0.4)
	table.insert(self._weapons, weapon);
end

function WeaponList:getWeapon(name)
	local retWeapon = nil;
	for _, weapon in self._weapons do
		if weapon.name == name then
			retWeapon = weapon;
			break;
		end
	end
	return retWeapon;
end

