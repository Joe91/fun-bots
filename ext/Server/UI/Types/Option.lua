--[[
	@class: Option
]]
class('Option')

--[[
	@method: __init
]]
function Option:__init(name, text, description)
	self.name			= name;
	self.text			= text or name;
	self.description	= description or nil;
	self.entry			= ValueType();
end

--[[
	@method: __class
]]
function Option:__class()
	return 'Option';
end

--[[
	@method: GetName
]]
function Option:GetName()
	return self.name;
end

--[[
	@method: GetText
]]
function Option:GetText()
	return self.text;
end

--[[
	@method: GetDescription
]]
function Option:GetDescription()
	return self.description;
end

--[[
	@method: SetType
]]
function Option:SetType(type)
	self.entry:SetType(type);
end

--[[
	@method: SetValue
]]
function Option:SetValue(type)
	self.entry:SetValue(type);
end

--[[
	@method: SetDefault
]]
function Option:SetDefault(type)
	self.entry:SetDefault(type);
end

--[[
	@method: SetReference
]]
function Option:SetReference(type)
	self.entry:SetReference(type);
end

--[[
	@method: Serialize
]]
function Option:Serialize()
	return {
		Name 		= self.name,
		Text 		= self.text,
		Description = self.description,
		Entry		= self.entry:Serialize()
	}
end


return Option;