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
function Box:__init(p_Color)
	if (_G['BoxID'] == nil) then
		_G['BoxID'] = 1
	end

	_G['BoxID'] = _G['BoxID'] + 1

	self.m_Attributes = {}
	self.m_Items = {}
	self.m_Name = 'Box#' .. _G['BoxID']
	self.m_Color = p_Color or Color.White
	self.m_Hidden = false
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
	return self.m_Name
end

--[[
	@method: HasItems
	@returns: boolean

	Returns whether the box has components
]]
function Box:HasItems()
	return #self.m_Items >= 1
end

--[[
	@method: GetItems
	@returns: table<Component>

	Returns the components of the box
]]
function Box:GetItems()
	return self.m_Items
end

--[[
	@method: AddItem
	@parameter: item:Component | Component to be added (Only `Entry` or `Text`)

	Fügt eine Komponente zur Box hinzu
]]
function Box:AddItem(p_Item)
	if (p_Item == nil or p_Item['__class'] == nil) then
		-- Bad Item
		return
	end

	if (p_Item:__class() ~= 'Entry' and p_Item:__class() ~= 'Text') then
		-- Exception: Only Menu, MenuSeparator (-) or MenuItem
		return
	end

	table.insert(self.m_Items, p_Item)
end

--[[
	@method: IsHidden
	@returns: boolean

	Checks if the box is visible or not
]]
function Box:IsHidden()
	return self.m_Hidden
end

--[[
	@method: Hide
]]
function Box:Hide()
	self.m_Hidden = true
end

--[[
	@method: Show
]]
function Box:Show()
	self.m_Hidden = false
end

--[[
	@method: GetAttributes
]]
function Box:GetAttributes()
	return self.m_Attributes
end

--[[
	@method: SetPosition
	@parameter: flag:Position
	@parameter: position:mixed | Some data for the position
]]
function Box:SetPosition(p_Flag, p_Position)
	table.insert(self.m_Attributes, {
		Name = 'Position',
		Value = {
			Type = p_Flag,
			Position = p_Position
		}
	})
end

--[[
	@method: Serialize
]]
function Box:Serialize()
	local s_Items = {}

	for _, l_Item in pairs(self.m_Items) do
		table.insert(s_Items, {
			Type = l_Item:__class(),
			Data = l_Item:Serialize()
		})
	end

	return {
		Color = self.m_Color,
		Name = self.m_Name,
		Items = s_Items,
		Hidden = self.m_Hidden
	}
end

return Box
