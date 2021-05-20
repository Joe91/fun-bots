--[[
	@class: CheckBox
	@extends: Component
]]
class('CheckBox')

--[[
	@method: __init
	@parameter: name:string
	@parameter: checked:boolean
]]
function CheckBox:__init(p_Name, p_Checked)
	self.m_Name = p_Name or nil
	self.m_Checked = p_Checked or false
	self.m_Disabled = false
end

--[[
	@method: __class
	@returns: string
]]
function CheckBox:__class()
	return 'CheckBox'
end

--[[
	@method: GetName
	@returns: string
]]
function CheckBox:GetName()
	return self.m_Name
end

--[[
	@method: Enable
]]
function CheckBox:Enable()
	self.m_Disabled = false
end

--[[
	@method: Disable
]]
function CheckBox:Disable()
	self.m_Disabled = true
end

--[[
	@method: IsChecked
]]
function CheckBox:IsChecked()
	return self.m_Checked
end

--[[
	@method: SetChecked
	@parameter: checked:boolean
]]
function CheckBox:SetChecked(p_Checked)
	self.m_Checked = p_Checked
end

--[[
	@method: Serialize
]]
function CheckBox:Serialize()
	return {
		Name = self.m_Name,
		IsChecked = self.m_Checked,
		Disabled = self.m_Disabled
	}
end

return CheckBox
