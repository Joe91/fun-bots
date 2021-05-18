--[[
	@class: Menu
	@extends: Component
]]
class('Menu')

require('UI/Components/MenuItem')
require('UI/Components/MenuSeparator')

--[[
	@method: __init
]]
function Menu:__init()
	self.m_Items = {}
	self.m_Attributes = {}
end

--[[
	@method: __class
]]
function Menu:__class()
	return 'Menu'
end

--[[
	@method: GetAttributes
]]
function Menu:GetAttributes()
	return self.m_Attributes
end

--[[
	@method: AddItem
]]
function Menu:AddItem(p_Item, p_Permission)
	if (p_Item == nil or p_Item['__class'] == nil) then
		-- Bad Item
		return
	end

	if (p_Item:__class() ~= 'Menu' and p_Item:__class() ~= 'MenuItem' and p_Item:__class() ~= 'MenuSeparator') then
		-- Exception: Only Menu, MenuSeparator (-) or MenuItem
		return
	end

	if p_Permission ~= nil then
		p_Item:BindPermission(p_Permission)
	end

	table.insert(self.m_Items, p_Item)
end

--[[
	@method: SetPosition
]]
function Menu:SetPosition(p_Flag, p_Position)
	table.insert(self.m_Attributes, {
		Name = 'Position',
		Value = {
			Type = p_Flag,
			Position = p_Position
		}
	})
end

--[[
	@method: HasItems
]]
function Menu:HasItems()
	return #self.m_Items >= 1
end

--[[
	@method: GetItems
]]
function Menu:GetItems()
	return self.m_Items
end

--[[
	@method: Serialize
]]
function Menu:Serialize(p_Player)
	local s_Items = {}

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

	return {
		Items = s_Items
	}
end

return Menu
