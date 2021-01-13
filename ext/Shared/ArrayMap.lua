class('ArrayMap')

function ArrayMap:__init()
	self._entries = {};
end

function ArrayMap:add(value)
	table.insert(self._entries, value);
	
	-- DEBUG
	print('ArrayMap(' .. tostring(self:count()) .. ') - add: ' .. value);
	print('ArrayMap - Debug');
	
	for key, value in pairs(self._entries) do
		print(key, value);
	end
end

function ArrayMap:deleteByIndex(index)
	table.remove(self._entries, index);
	
	-- DEBUG
	print('ArrayMap(' .. tostring(self:count()) .. ') - remove Index: ' .. index);
	print('ArrayMap - Debug');
	
	for key, value in pairs(self._entries) do
		print(key, value);
	end
end

function ArrayMap:delete(value)
	print('ArrayMap(' .. tostring(self:count()) .. ') - remove: ' .. value);
	
	local index = {};
	
	for key, data in pairs(self._entries) do
	   index[data] = key;
	end
	
	if index[value] ~= nil then
		self:deleteByIndex(index[value]);
	else
		print('Index from ' .. value .. ' is nil.');
	end
end

function ArrayMap:isEmpty()
	return self:count() == 0;
end

function ArrayMap:count()
	return #self._entries;
end

return ArrayMap;