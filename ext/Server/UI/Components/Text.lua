--[[
	@class: Text
	@extends: Component
]]
class('Text');

--[[
	@method: __init
]]
function Text:__init(name, text)
	self.name		= name or nil;
	self.text		= text or nil;
	self.icon		= nil;
	self.disabled	= false;
	self.attributes	= {};
end

--[[
	@method: __class
]]
function Text:__class()
	return 'Text';
end

--[[
	@method: GetAttributes
]]
function Text:GetAttributes()
	return self.attributes;
end

--[[
	@method: SetPosition
]]
function Text:SetPosition(flag, position)
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
	@method: GetName
]]
function Text:GetName()
	return self.name;
end

--[[
	@method: GetText
]]
function Text:GetText()
	return self.text;
end

--[[
	@method: SetText
]]
function Text:SetText(text)
	self.text = text;
	
	return self;
end

--[[
	@method: Enable
]]
function Text:Enable()
	self.disabled = false;
	
	return self;
end

--[[
	@method: Disable
]]
function Text:Disable()
	self.disabled = true;
	
	return self;
end

--[[
	@method: SetIcon
]]
function Text:SetIcon(icon)
	self.icon = icon;
	
	return self;
end

--[[
	@method: Serialize
]]
function Text:Serialize()
	return {
		Name		= self.name,
		Text		= self.text,
		Icon		= self.icon,
		Disabled	= self.disabled
	};
end

return Text;