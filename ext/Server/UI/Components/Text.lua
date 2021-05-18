--[[
	@class: Text
	@extends: Component
]]
class('Text')

--[[
	@method: __init
]]
function Text:__init(p_Name, p_Text)
	self.m_Name = p_Name or nil
	self.m_Text = p_Text or nil
	self.m_Icon = nil
	self.m_Disabled = false
	self.m_Attributes = {}
end

--[[
	@method: __class
]]
function Text:__class()
	return 'Text'
end

--[[
	@method: GetAttributes
]]
function Text:GetAttributes()
	return self.m_Attributes
end

--[[
	@method: SetPosition
]]
function Text:SetPosition(p_Flag, p_Position)
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
	@method: GetName
]]
function Text:GetName()
	return self.m_Name
end

--[[
	@method: GetText
]]
function Text:GetText()
	return self.m_Text
end

--[[
	@method: SetText
]]
function Text:SetText(p_Text)
	self.m_Text = p_Text

	return self
end

--[[
	@method: Enable
]]
function Text:Enable()
	self.m_Disabled = false

	return self
end

--[[
	@method: Disable
]]
function Text:Disable()
	self.m_Disabled = true

	return self
end

--[[
	@method: SetIcon
]]
function Text:SetIcon(p_Icon)
	self.m_Icon = p_Icon

	return self
end

--[[
	@method: Serialize
]]
function Text:Serialize()
	return {
		Name = self.m_Name,
		Text = self.m_Text,
		Icon = self.m_Icon,
		Disabled = self.m_Disabled
	}
end

return Text
