class('Weapon');

function Weapon:__init(name, extension, unlocks, isShotgun, fireCycle, pauseCycle)
	self.name		= name;
	self.extension	= extension;
	self.unlocks 	= unlocks;
	self.isShotgun	= isShotgun;
	self.fireCycle	= fireCycle;
	self.pauseCycle	= pauseCycle;
end

function Weapon:getResourcePath(unlock)
	local ext = ""
	local unl = ""
	if unlock ~= nil or unlock ~= "" then
		unl = "_"..unlock;
	end
	if self.extension ~= '' then
		ext = self.extension.."_"
	end

	return	"Weapons/"..ext..self.name.."/U_"..self.name..unl;
end

return Weapon;