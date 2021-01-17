class 'UISettings';

require('__shared/ArrayMap');

function UISettings:__init()
	self._properties = ArrayMap();
end

function UISettings:getProperties()
	return self._properties;
end

function UISettings:add(category, types, name, title, value, default, description)
	self._properties:add({
		category	= category,
		types		= types,
		name		= name,
		title		= title,
		value		= value,
		default		= default,
		description = description
	});
end

function UISettings:addList(category, name, title, list, value, default, description)
	self._properties:add({
		category	= category,
		types		= 'List',
		name		= name,
		title		= title,
		list		= list,
		value		= value,
		default		= default,
		description	= description
	});
end

function UISettings:getJSON()
	if self._properties ~= nil then
		return json.encode(self._properties:getEntries());		
	end
	
	return "{}";
end

return UISettings;