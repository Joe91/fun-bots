--[[
	@class: Button
	@extends: Component

	Creates an button
]]
class('Button')

function Button:__init(p_Name, p_Title, p_Callback)
	if (_G['ButtonID'] == nil) then
		_G['ButtonID'] = 1
	end

	_G['ButtonID'] = _G['ButtonID'] + 1
	self.m_Id = _G['ButtonID']
	self.m_Name = p_Name or nil
	self.m_Title = p_Title or nil
	self.m_Callback = p_Callback or nil
	self.m_Permission = nil
	self.m_Disabled = false

	if self.m_Callback ~= nil then
		_G.Callbacks['Button#' .. self.m_Name .. self.m_Id]	= self.m_Callback
	end
end

function Button:__class()
	return 'Button'
end

function Button:GetName()
	return self.m_Name
end

function Button:GetPermission()
	return self.m_Permission
end

function Button:SetCallback(p_Callback)
	self.m_Callback = p_Callback
	_G.Callbacks['Button#' .. self.m_Name .. self.m_Id]	= self.m_Callback
end

function Button:BindPermission(p_Permission)
	self.m_Permission = p_Permission
end

function Button:Enable()
	self.m_Disabled = false
end

function Button:Disable()
	self.m_Disabled = true
end

function Button:Serialize()
	return {
		Name = 'Button#' .. self.m_Name .. self.m_Id,
		Title = self.m_Title,
		Disabled = self.m_Disabled,
		Permission = self.m_Permission
	}
end

return Button
