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
	self.items = {}
	self.attributes = {}
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
	return self.attributes
end

--[[
	@method: AddItem
]]
function Menu:AddItem(item, permission)
	if (item == nil or item['__class'] == nil) then
		-- Bad Item
		return
	end

	if (item:__class() ~= 'Menu' and item:__class() ~= 'MenuItem' and item:__class() ~= 'MenuSeparator') then
		-- Exception: Only Menu, MenuSeparator (-) or MenuItem
		return
	end

	if permission ~= nil then
		item:BindPermission(permission)
	end

	table.insert(self.items, item)
end

--[[
	@method: SetPosition
]]
function Menu:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name = 'Position',
		Value = {
			Type = flag,
			Position = position
		}
	})
end

--[[
	@method: HasItems
]]
function Menu:HasItems()
	return #self.items >= 1
end

--[[
	@method: GetItems
]]
function Menu:GetItems()
	return self.items
end

--[[
	@method: Serialize
]]
function Menu:Serialize(player)
	local items = {}

	for _, item in pairs(self.items) do
		if item['GetPermission'] ~= nil then
			if item:GetPermission() == nil then
				table.insert(items, {
					Type = item:__class(),
					Data = item:Serialize(player)
				})
			elseif PermissionManager:HasPermission(player, item:GetPermission()) then
				table.insert(items, {
					Type = item:__class(),
					Data = item:Serialize(player)
				})
			end
		else
			table.insert(items, {
				Type = item:__class(),
				Data = item:Serialize(player)
			})
		end
	end

	return {
		Items = items
	}
end

return Menu
