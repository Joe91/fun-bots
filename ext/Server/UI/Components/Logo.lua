--[[
	@class: Logo
	@extends: Component
]]
class('Logo');

--[[
	@method: __init
]]
function Logo:__init(title, subtitle)
	self.title		= title or nil;
	self.subtitle	= subtitle or nil;
	self.attributes	= {};
end

--[[
	@method: __class
]]
function Logo:__class()
	return 'Logo';
end

--[[
	@method: GetAttributes
]]
function Logo:GetAttributes()
	return self.attributes;
end

--[[
	@method: SetPosition
]]
function Logo:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= {
			Type		= flag,
			Position	= position
		}
	});
end

--[[
	@method: Serialize
]]
function Logo:Serialize()
	return {
		Title		= self.title,
		Subtitle	= self.subtitle
	};
end

return Logo;