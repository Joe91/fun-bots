--[[
	@class: Box
	@extends: Component

	This component displays a colored box container in the UI, in which various components are displayed.
]]
class('Box')

--[[
	@method: __init
	@parameter: color:Color | The color of the box component
]]
function Box:__init(color)
	if (_G['BoxID'] == nil) then
		_G['BoxID'] = 1
	end

	_G['BoxID'] = _G['BoxID'] + 1

	self.attributes = {}
	self.items = {}
	self.name = 'Box#' .. _G['BoxID']
	self.color = color or Color.White
	self.hidden = false
end

--[[
	@method: __class
]]
function Box:__class()
	return 'Box'
end

--[[
	@method: GetName
	@returns: string
]]
function Box:GetName()
	return self.name
end

--[[
	@method: HasItems
	@returns: boolean

	Returns whether the box has components
]]
function Box:HasItems()
	return #self.items >= 1
end

--[[
	@method: GetItems
	@returns: table<Component>

	Returns the components of the box
]]
function Box:GetItems()
	return self.items
end

--[[
	@method: AddItem
	@parameter: item:Component | Component to be added (Only `Entry` or `Text`)

	Fügt eine Komponente zur Box hinzu
]]
function Box:AddItem(item)
	if (item == nil or item['__class'] == nil) then
		-- Bad Item
		return
	end

	if (item:__class() ~= 'Entry' and item:__class() ~= 'Text') then
		-- Exception: Only Menu, MenuSeparator (-) or MenuItem
		return
	end

	table.insert(self.items, item)
end

--[[
	@method: IsHidden
	@returns: boolean

	Checks if the box is visible or not
]]
function Box:IsHidden()
	return self.hidden
end

--[[
	@method: Hide
]]
function Box:Hide()
	self.hidden = true
end

--[[
	@method: Show
]]
function Box:Show()
	self.hidden = false
end

--[[
	@method: GetAttributes
]]
function Box:GetAttributes()
	return self.attributes
end

--[[
	@method: SetPosition
	@parameter: flag:Position
	@parameter: position:mixed | Some data for the position
]]
function Box:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name = 'Position',
		Value = {
			Type = flag,
			Position = position
		}
	})
end

--[[
	@method: Serialize
]]
function Box:Serialize()
	local items = {}

	for _, item in pairs(self.items) do
		table.insert(items, {
			Type = item:__class(),
			Data = item:Serialize()
		})
	end

	return {
		Color = self.color,
		Name = self.name,
		Items = items,
		Hidden = self.hidden
	}
end

return Box
