--[[
	@class: Confirmation
	@extends: Dialog
]]
class('Confirmation')

--[[
	@method: __init
]]
function Confirmation:__init()
	self.m_Button_Yes = nil
	self.m_Button_No = nil
	self.m_Dialog = Dialog('confirmation', 'Confirmation')
end

--[[
	@method: __class
]]
function Confirmation:__class()
	return 'Confirmation'
end

--[[
	@method: SetTitle
]]
function Confirmation:SetTitle(p_Title)
	self.m_Dialog:SetTitle(p_Title)
end

--[[
	@method: SetContent
]]
function Confirmation:SetContent(p_Content)
	self.m_Dialog:SetContent(p_Content)
end

--[[
	@method: SetYes
]]
function Confirmation:SetYes(p_Callback)
	self.m_Button_Yes:SetCallback(p_Callback)
end

--[[
	@method: SetNo
]]
function Confirmation:SetNo(p_Callback)
	self.m_Button_No:SetCallback(p_Callback)
end

--[[
	@method: InitializeComponent
]]
function Confirmation:InitializeComponent()
	self.m_Button_Yes = Button('button_confirmation_yes', 'Yes')
	self.m_Dialog:AddButton(self.m_Button_Yes, Position.Left)

	self.m_Button_No = Button('button_confirmation_no', 'No')
	self.m_Dialog:AddButton(self.m_Button_No, Position.Right)
end

--[[
	@method: Serialize
]]
function Confirmation:Serialize(p_Player)
	return self.m_Dialog:Serialize(p_Player)
end

--[[
	@method: Open
]]
function Confirmation:Open(p_View, p_Player)
	p_View:Push(p_Player, self.m_Dialog)
end

--[[
	@method: Hide
]]
function Confirmation:Hide(p_View, p_Player)
	p_View:Remove(p_Player, self.m_Dialog)
end

return Confirmation
