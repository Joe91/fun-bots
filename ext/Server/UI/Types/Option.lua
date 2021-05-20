--[[
	@class: Option
]]
class('Option')

--[[
	@method: __init
]]
function Option:__init(p_Name, p_Text, p_Description)
	self.m_Name = p_Name
	self.m_Text = p_Text or p_Name
	self.m_Description = p_Description or nil
	self.m_Entry = ValueType()
end

--[[
	@method: __class
]]
function Option:__class()
	return 'Option'
end

--[[
	@method: GetName
]]
function Option:GetName()
	return self.m_Name
end

--[[
	@method: GetText
]]
function Option:GetText()
	return self.m_Text
end

--[[
	@method: GetDescription
]]
function Option:GetDescription()
	return self.m_Description
end

--[[
	@method: SetType
]]
function Option:SetType(p_Type)
	self.m_Entry:SetType(p_Type)
end

--[[
	@method: SetValue
]]
function Option:SetValue(p_Type)
	self.m_Entry:SetValue(p_Type)
end

--[[
	@method: SetDefault
]]
function Option:SetDefault(p_Type)
	self.m_Entry:SetDefault(p_Type)
end

--[[
	@method: SetReference
]]
function Option:SetReference(p_Type)
	self.m_Entry:SetReference(p_Type)
end

--[[
	@method: Serialize
]]
function Option:Serialize()
	return {
		Name = self.m_Name,
		Text = self.m_Text,
		Description = self.m_Description,
		Entry = self.m_Entry:Serialize()
	}
end

return Option
