class('Weapon');

function Weapon:__init(name, extension, unlocks, damage, bulletSpeed, bulletDrop, reload, fireCycle, pauseCycle, delayed, fullResource)
	self.name		= name;
	self.extension	= extension;
	self.unlocks 	= unlocks;
	self.damage		= damage;
	self.bulletSpeed= bulletSpeed;
	self.bulletDrop = bulletDrop;
	self.fireCycle	= fireCycle;
	self.pauseCycle	= pauseCycle;
	self.reload		= reload;
	self.delayed	= delayed;
	self.fullResource = fullResource;
end

function Weapon:getResourcePath(unlock)
	local unl = ""
	if self.fullResource == nil then
		local ext = ""
		if unlock ~= nil then
			unl = "_"..unlock;
		end
		if self.extension ~= '' then
			ext = self.extension.."_"
		end

		return	"Weapons/"..ext..self.name.."/U_"..self.name..unl;
	else
		if unlock ~= nil then
			unl = "_"..unlock;
		end
		return self.fullResource..unl;
	end
end

function Weapon:getAllAttachements()
	local attachmentList = {}
	for _, attachment in pairs(self.unlocks) do
		table.insert(attachmentList, self:getResourcePath(attachment));
	end
	return attachmentList;
end

return Weapon;