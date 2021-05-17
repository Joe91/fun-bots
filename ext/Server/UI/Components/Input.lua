--[[
	@class: Input
	@extends: Component
]]
class('Input')

--[[
	@method: __init
]]
function Input:__init(p_Type, p_Name, p_Value)
	self.m_Type = p_Type or nil
	self.m_Name = p_Name or nil
	self.m_Value = p_Value or nil
	self.m_Disabled = false
	self.m_Arrows = {}
end

--[[
	@method: __class
]]
function Input:__class()
	return 'Input'
end

--[[
	@method: GetName
]]
function Input:GetName()
	return self.m_Name
end

--[[
	@method: GetItems
]]
function Input:GetItems()
	return self.m_Arrows
end

--[[
	@method: HasItems
]]
function Input:HasItems()
	return #self.m_Arrows >= 1
end

--[[
	@method: AddArrow
]]
function Input:AddArrow(p_Position, p_Character, p_Callback)
	if (_G['ArrowID'] == nil) then
		_G['ArrowID'] = 1
	end

	_G['ArrowID'] = _G['ArrowID'] + 1
	_G.Callbacks['Arrow#' .. _G['ArrowID']] = p_Callback

	table.insert(self.m_Arrows, {
		Type = 'Arrow',
		Name = 'Arrow#' .. _G['ArrowID'],
		Position = p_Position,
		Character = p_Character,
		Callback = p_Callback
	})
end

--[[
	@method: Enable
]]
function Input:Enable()
	self.m_Disabled = false
end

--[[
	@method: Disable
]]
function Input:Disable()
	self.m_Disabled = true
end

--[[
	@method: GetValue
]]
function Input:GetValue()
	return self.m_Value
end

--[[
	@method: SetValue
]]
function Input:SetValue(p_Value)
	self.m_Value = p_Value
end

--[[
	@method: Serialize
]]
function Input:Serialize()
	return {
		Type = self.m_Type,
		Name = self.m_Name,
		Value = self.m_Value,
		Disabled = self.m_Disabled,
		Arrows = self.m_Arrows
	}
end

return Input
