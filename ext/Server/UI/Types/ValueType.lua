--[[
	@class: ValueType
]]
class('ValueType')

--[[
	@method: __init
]]
function ValueType:__init()
	self.m_Type = nil
	self.m_Value = nil
	self.m_Default = nil
	self.m_Reference = nil
end

--[[
	@method: __class
]]
function ValueType:__class()
	return 'ValueType'
end

--[[
	@method: GetType
]]
function ValueType:GetType()
	return self.m_Type
end

--[[
	@method: SetType
]]
function ValueType:SetType(p_Type)
	self.m_Type = p_Type
end

--[[
	@method: GetValue
]]
function ValueType:GetValue()
	return self.m_Value
end

--[[
	@method: SetValue
]]
function ValueType:SetValue(p_Value)
	self.m_Value = p_Value
end

--[[
	@method: GetDefault
]]
function ValueType:GetDefault()
	return self.m_Default
end

--[[
	@method: SetDefault
]]
function ValueType:SetDefault(p_Default)
	self.m_Default = p_Default
end

--[[
	@method: GetReference
]]
function ValueType:GetReference()
	return self.m_Reference
end

--[[
	@method: SetReference
]]
function ValueType:SetReference(p_Reference)
	self.m_Reference = p_Reference
end

--[[
	@method: Serialize
]]
function ValueType:Serialize()
	return {
		Type = self.m_Type,
		Value = self.m_Value,
		Default = self.m_Default,
		Reference = self.m_Reference
	}
end

return ValueType
