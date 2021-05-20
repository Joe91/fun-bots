--[[
	@class: Entry
	@extends: Component
]]
class('Entry')

--[[
	@method: __init
]]
function Entry:__init(p_Name, p_Text, p_Value)
	self.m_Name = p_Name or nil
	self.m_Text = p_Text or nil
	self.m_Value = p_Value or nil
end

--[[
	@method: __class
]]
function Entry:__class()
	return 'Entry'
end

--[[
	@method: GetText
]]
function Entry:GetText()
	return self.m_Text
end

--[[
	@method: SetText
]]
function Entry:SetText(p_Text)
	self.m_Text = p_Text
end

--[[
	@method: GetName
]]
function Entry:GetName()
	return self.m_Name
end

--[[
	@method: GetValue
]]
function Entry:GetValue()
	return self.m_Name
end

--[[
	@method: Serialize
]]
function Entry:Serialize()
	local s_Value = nil

	if (type(self.m_Value) == 'string') then
		s_Value = self.m_Value
	elseif (self.m_Value['Serialize'] ~= nil) then
		s_Value = self.m_Value:Serialize()
	end

	return {
		Name = self.m_Name,
		Text = self.m_Text,
		Value = s_Value
	}
end

return Entry
