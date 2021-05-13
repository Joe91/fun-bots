--[[
	@class: QuickShortcut
	@extends: Component
]]
class('QuickShortcut');

--[[
	@method: __init
]]
function QuickShortcut:__init(name)
	self.name		= name or nil;
	self.enabled	= true;
	self.numpad		= {};
	self.help		= {};
	self.attributes	= {};
end

--[[
	@method: __class
]]
function QuickShortcut:__class()
	return 'QuickShortcut';
end

--[[
	@method: GetAttributes
]]
function QuickShortcut:GetAttributes()
	return self.attributes;
end

--[[
	@method: SetPosition
]]
function QuickShortcut:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= {
			Type		= flag,
			Position	= position
		}
	});
	
	return self;
end

--[[
	@method: IsEnabled
]]
function QuickShortcut:IsEnabled()
	return self.enabled;
end

--[[
	@method: Enable
]]
function QuickShortcut:Enable()
	self.enabled = true;
end

--[[
	@method: Disable
]]
function QuickShortcut:Disable()
	self.enabled = false;
end

--[[
	@method: AddNumpad
]]
function QuickShortcut:AddNumpad(key, text)
	table.insert(self.numpad, {
		Key		= key,
		Text	= text
	});
end

--[[
	@method: AddHelp
]]
function QuickShortcut:AddHelp(key, text)
	table.insert(self.help, {
		Key		= key,
		Text	= text
	});
end

--[[
	@method: Serialize
]]
function QuickShortcut:Serialize()
	return {
		Name		= self.name,
		Disabled	= not self.enabled,
		Numpad		= self.numpad,
		Help		= self.help
	};
end

return QuickShortcut;