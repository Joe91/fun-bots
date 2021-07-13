--[[
	@class: QuickShortcut
	@extends: Component
]]
class('QuickShortcut')

--[[
	@method: __init
]]
function QuickShortcut:__init(p_Name)
	self.m_Name = p_Name or nil
	self.m_Enabled = true
	self.m_Numpad = {}
	self.m_Help = {}
	self.m_Attributes = {}
end

--[[
	@method: __class
]]
function QuickShortcut:__class()
	return 'QuickShortcut'
end

--[[
	@method: GetAttributes
]]
function QuickShortcut:GetAttributes()
	return self.m_Attributes
end

--[[
	@method: GetName
]]
function QuickShortcut:GetName()
    return self.m_Name
end

--[[
	@method: SetPosition
]]
function QuickShortcut:SetPosition(p_Flag, p_Position)
	table.insert(self.m_Attributes, {
		Name = 'Position',
		Value = {
			Type = p_Flag,
			Position = p_Position
		}
	})

	return self
end

--[[
	@method: IsEnabled
]]
function QuickShortcut:IsEnabled()
	return self.m_Enabled
end

--[[
	@method: Enable
]]
function QuickShortcut:Enable()
	self.m_Enabled = true
end

--[[
	@method: Disable
]]
function QuickShortcut:Disable()
	self.m_Enabled = false
end

--[[
	@method: AddNumpad
]]
function QuickShortcut:AddNumpad(p_Key, p_Text)
	table.insert(self.m_Numpad, {
		Key = p_Key,
		Text = p_Text
	})
end

--[[
	@method: ClearNumpad
]]
function QuickShortcut:ClearNumpad()
	self.m_Numpad = {}
end

--[[
	@method: AddHelp
]]
function QuickShortcut:AddHelp(p_Key, p_Text)
	table.insert(self.m_Help, {
		Key = p_Key,
		Text = p_Text
	})
end

--[[
	@method: ClearHelp
]]
function QuickShortcut:ClearHelp()
	self.m_Help = {}
end

--[[
	@method: Serialize
]]
function QuickShortcut:Serialize()
	return {
		Name = self.m_Name,
		Disabled = not self.m_Enabled,
		Numpad = self.m_Numpad,
		Help = self.m_Help
	}
end

return QuickShortcut
