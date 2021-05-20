--[[
	@class: Dialog
	@extends: Component
]]
class('Dialog')

--[[
	@method: __init
]]
function Dialog:__init(p_Name, p_Title)
	self.m_Name = p_Name or nil
	self.m_Title = p_Title or nil
	self.m_Buttons = {}
	self.m_Content = nil
end

--[[
	@method: GetName
]]
function Dialog:GetName()
	return self.m_Name
end

--[[
	@method: __class
]]
function Dialog:__class()
	return 'Dialog'
end

--[[
	@method: AddButton
]]
function Dialog:AddButton(p_Button, p_Position, p_Permission)
	if (p_Button == nil or p_Button['__class'] == nil) then
		-- Bad Item
		return
	end

	if (p_Button:__class() ~= 'Button') then
		-- Exception: Only Button
		return
	end

	if p_Position ~= nil then

	end

	if p_Permission ~= nil then
		p_Button:BindPermission(p_Permission)
	end

	table.insert(self.m_Buttons, p_Button)
end

--[[
	@method: SetTitle
]]
function Dialog:SetTitle(p_Title)
	self.m_Title = p_Title
end

--[[
	@method: SetContent
]]
function Dialog:SetContent(p_Content)
	self.m_Content = p_Content
end

--[[
	@method: Serialize
]]
function Dialog:Serialize()
	local s_Buttons = {}

	for _, l_Button in pairs(self.m_Buttons) do
		table.insert(s_Buttons, {
			Type = l_Button:__class(),
			Data = l_Button:Serialize()
		})
	end

	return {
		Name = self.m_Name,
		Title = self.m_Title,
		Content = self.m_Content,
		Buttons = s_Buttons
	}
end

return Dialog
