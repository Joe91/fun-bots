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
function CheckBox:__init(name, checked)
	self.name = name or nil
	self.checked = checked or false
	self.disabled = false
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
	return self.name
end

--[[
	@method: Enable
]]
function CheckBox:Enable()
	self.disabled = false
end

--[[
	@method: Disable
]]
function CheckBox:Disable()
	self.disabled = true
end

--[[
	@method: IsChecked
]]
function CheckBox:IsChecked()
	return self.checked
end

--[[
	@method: SetChecked
	@parameter: checked:boolean
]]
function CheckBox:SetChecked(checked)
	self.checked = checked
end

--[[
	@method: Serialize
]]
function CheckBox:Serialize()
	return {
		Name = self.name,
		IsChecked = self.checked,
		Disabled = self.disabled
	}
end

return CheckBox
