---@class UISettings
---@overload fun():UISettings
UISettings = class 'UISettings'

require('__shared/ArrayMap')

function UISettings:__init()
	self._properties = ArrayMap()
end

function UISettings:getProperties()
	return self._properties
end

function UISettings:add(p_Category, p_Types, p_Name, p_Title, p_Value, p_Default, p_Description)
	self._properties:add({
		category = p_Category,
		types = p_Types,
		name = p_Name,
		title = p_Title,
		value = p_Value,
		default = p_Default,
		description = p_Description
	})
end

function UISettings:addList(p_Category, p_Name, p_Title, p_List, p_Value, p_Default, p_Description)
	self._properties:add({
		category = p_Category,
		types = 'List',
		name = p_Name,
		title = p_Title,
		list = p_List,
		value = p_Value,
		default = p_Default,
		description = p_Description
	})
end

function UISettings:getJSON()
	if self._properties ~= nil then
		return json.encode(self._properties:getEntries())
	end

	return '{}'
end

return UISettings
