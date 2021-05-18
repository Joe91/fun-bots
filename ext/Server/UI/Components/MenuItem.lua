--[[
	@class: MenuItem
	@extends: Component
]]
class('MenuItem')

--[[
	@method: __init
]]
function MenuItem:__init(p_Title, p_Name, p_Callback, p_Shortcut)
	self.m_Title = p_Title or nil
	self.m_Name = p_Name or nil
	self.m_Callback = p_Callback or nil
	self.m_Shortcut = p_Shortcut or nil
	self.m_Disabled = false
	self.m_Icon = nil
	self.m_Items = {}
	self.m_Inputs = {}
	self.m_Checkboxes = {}
	self.m_Permission = nil
end

--[[
	@method: __class
]]
function MenuItem:__class()
	return 'MenuItem'
end

--[[
	@method: BindPermission
]]
function MenuItem:BindPermission(p_Permission)
	self.m_Permission = p_Permission
end

--[[
	@method: GetPermission
]]
function MenuItem:GetPermission()
	return self.m_Permission
end

--[[
	@method: AddItem
]]
function MenuItem:AddItem(p_Item, p_Permission)
	if (p_Item == nil or p_Item['__class'] == nil) then
		-- Bad Item
		return self
	end

	if (p_Item:__class() ~= 'MenuItem' and p_Item:__class() ~= 'MenuSeparator') then
		-- Exception: Only Menu, MenuSeparator or MenuItem
		return self
	end

	if p_Permission ~= nil then
		p_Item:BindPermission(p_Permission)
	end

	table.insert(self.m_Items, p_Item)

	return self
end

--[[
	@method: SetIcon
]]
function MenuItem:SetIcon(p_File)
	self.m_Icon = p_File

	return self
end

--[[
	@method: GetItems
]]
function MenuItem:GetItems()
	return self.m_Items
end

--[[
	@method: HasItems
]]
function MenuItem:HasItems()
	return #self.m_Items >= 1
end

--[[
	@method: GetInputs
]]
function MenuItem:GetInputs()
	return self.m_Inputs
end

--[[
	@method: HasInputs
]]
function MenuItem:HasInputs()
	return #self.m_Inputs >= 1
end

--[[
	@method: GetCheckBoxes
]]
function MenuItem:GetCheckBoxes()
	return self.m_Checkboxes
end

--[[
	@method: HasCheckBoxes
]]
function MenuItem:HasCheckBoxes()
	return #self.m_Checkboxes >= 1
end

--[[
	@method: GetTitle
]]
function MenuItem:GetTitle()
	return self.m_Title
end

--[[
	@method: SetTitle
]]
function MenuItem:SetTitle(p_Title)
	self.m_Title = p_Title

	return self
end

--[[
	@method: GetName
]]
function MenuItem:GetName()
	return self.m_Name
end

--[[
	@method: SetName
]]
function MenuItem:SetName(p_Name)
	self.m_Name = p_Name

	return self
end

--[[
	@method: Enable
]]
function MenuItem:Enable()
	self.m_Disabled = false

	return self
end

--[[
	@method: Disable
]]
function MenuItem:Disable()
	self.m_Disabled = true

	return self
end

--[[
	@method: GetCallback
]]
function MenuItem:GetCallback()
	return self.m_Callback
end

--[[
	@method: SetCallback
]]
function MenuItem:SetCallback(p_Callback)
	self.m_Callback = p_Callback

	return self
end

--[[
	@method: FireCallback
]]
function MenuItem:FireCallback(p_Player)
	--if (self.m_Disabled) then
		-- print('MenuItem ' .. self.m_Name .. ' is disabled.')
		-- return
	--end

	if (self.m_Callback == nil) then
		--print('MenuItem ' .. self.m_Name .. ' has no Callback.')
		return
	end

	if (type(self.m_Callback) == 'string') then
		--print('MenuItem ' .. self.m_Name .. ' has an reference Callback.')
		return
	end

	if self.m_Permission ~= nil then
		if PermissionManager:HasPermission(p_Player, self.m_Permission) == false then
			ChatManager:SendMessage('You have no permissions for this action (' .. self.m_Permission .. ').', p_Player)
			return self
		end
	end

	self.m_Callback(p_Player)

	return self
end

--[[
	@method: GetShortcut
]]
function MenuItem:GetShortcut()
	return self.m_Shortcut
end

--[[
	@method: SetShortcut
]]
function MenuItem:SetShortcut(p_Shortcut)
	self.m_Shortcut = p_Shortcut

	return self
end

--[[
	@method: HasShortcut
]]
function MenuItem:HasShortcut()
	return (self.m_Shortcut ~= nil)
end

--[[
	@method: AddCheckBox
]]
function MenuItem:AddCheckBox(p_Position, p_Checkbox)
	if (p_Checkbox == nil or p_Checkbox['__class'] == nil) then
		-- Bad Item
		return self
	end

	if (p_Checkbox:__class() ~= 'CheckBox') then
		-- Exception: Only Menu, Separator (-) or MenuItem
		return self
	end

	table.insert(self.m_Checkboxes, {
		Position = p_Position,
		CheckBox = p_Checkbox
	})

	return self
end

--[[
	@method: AddInput
]]
function MenuItem:AddInput(p_Position, p_Input)
	if (p_Input == nil or p_Input['__class'] == nil) then
		-- Bad Item
		return self
	end

	if (p_Input:__class() ~= 'Input') then
		-- Exception: Only Menu, Separator (-) or MenuItem
		return self
	end

	table.insert(self.m_Inputs, {
		Position = p_Position,
		Input = p_Input
	})

	return self
end

--[[
	@method: Serialize
]]
function MenuItem:Serialize(p_Player)
	local s_Items = {}
	local s_Inputs = {}
	local s_Checkboxes = {}
	local s_Callback = nil

	if (type(self.m_Callback) == 'function') then
		s_Callback = 'MenuItem$' .. self.m_Name
	else
		s_Callback = self.m_Callback
	end

	for _, l_Item in pairs(self.m_Items) do
		if l_Item['GetPermission'] ~= nil then
			if l_Item:GetPermission() == nil then
				table.insert(s_Items, {
					Type = l_Item:__class(),
					Data = l_Item:Serialize(p_Player)
				})
			elseif PermissionManager:HasPermission(p_Player, l_Item:GetPermission()) then
				table.insert(s_Items, {
					Type = l_Item:__class(),
					Data = l_Item:Serialize(p_Player)
				})
			end
		else
			table.insert(s_Items, {
				Type = l_Item:__class(),
				Data = l_Item:Serialize(p_Player)
			})
		end
	end

	for _, l_Data in pairs(self.m_Inputs) do
		table.insert(s_Inputs, {
			Type = l_Data.Input:__class(),
			Data = l_Data.Input:Serialize(),
			Position = l_Data.Position
		})
	end

	for _, l_Data in pairs(self.m_Checkboxes) do
		table.insert(s_Checkboxes, {
			Type = l_Data.CheckBox:__class(),
			Data = l_Data.CheckBox:Serialize(),
			Position = l_Data.Position
		})
	end

	if (#s_Items >= 1) then
		return {
			Title = self.m_Title,
			Name = self.m_Name,
			Icon = self.m_Icon,
			Items = s_Items,
			Disabled = self.m_Disabled,
			Permission = self.m_Permission
		}
	end

	return {
		Title = self.m_Title,
		Name = self.m_Name,
		Icon = self.m_Icon,
		Callback = s_Callback,
		Shortcut = self.m_Shortcut,
		Inputs = s_Inputs,
		CheckBoxes = s_Checkboxes,
		Disabled = self.m_Disabled,
		Permission = self.m_Permission
	}
end

return MenuItem
