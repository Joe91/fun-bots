class 'ArrayMap';

function ArrayMap:__init()
	self._entries = {};
end

function ArrayMap:add(value)
	table.insert(self._entries, value);
end

function ArrayMap:deleteByIndex(index)
	table.remove(self._entries, index);
end

function ArrayMap:exists(value)
	local index = {};

	for key, data in pairs(self._entries) do
		index[data] = key;
	end

	if index[value] ~= nil then
		return true;
	end

	return false;
end

function ArrayMap:delete(value)
	local index = {};

	for key, data in pairs(self._entries) do
		index[data] = key;
	end

	if index[value] ~= nil then
		self:deleteByIndex(index[value]);
	end
end

function ArrayMap:isEmpty()
	return self:count() == 0;
end

function ArrayMap:count()
	return #self._entries;
end

function ArrayMap:getEntries()
	return self._entries;
end

function ArrayMap:join(character)
	return table.concat(self._entries, character)
end

function ArrayMap:_tostring()
	return '[ArrayList Count=' .. self:count() .. ', ' .. json.encode(self._entries) .. ']';
end

return ArrayMap;