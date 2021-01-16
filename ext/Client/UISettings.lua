class 'UISettings';

require('__shared/ArrayMap');

function UISettings:__init()
	self._properties = ArrayMap();
	
	self._properties:add("Test");
end

function UISettings:getProperties()
	return self._properties;
end

function UISettings:toJSON()
	if self._properties == nil then
		return "{}";
	end
	
	return json.encode(self._properties);
end

return UISettings;