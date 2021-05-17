--[[
	@class: ValueType
]]
class('ValueType')

--[[
	@method: __init
]]
function ValueType:__init()
	self.type = nil
	self.value = nil
	self.default = nil
	self.reference = nil
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
	return self.type
end

--[[
	@method: SetType
]]
function ValueType:SetType(type)
	self.type = type
end

--[[
	@method: GetValue
]]
function ValueType:GetValue()
	return self.value
end

--[[
	@method: SetValue
]]
function ValueType:SetValue(value)
	self.value = value
end

--[[
	@method: GetDefault
]]
function ValueType:GetDefault()
	return self.default
end

--[[
	@method: SetDefault
]]
function ValueType:SetDefault(default)
	self.default = default
end

--[[
	@method: GetReference
]]
function ValueType:GetReference()
	return self.reference
end

--[[
	@method: SetReference
]]
function ValueType:SetReference(reference)
	self.reference = reference
end

--[[
	@method: Serialize
]]
function ValueType:Serialize()
	return {
		Type = self.type,
		Value = self.value,
		Default = self.default,
		Reference = self.reference
	}
end

return ValueType
