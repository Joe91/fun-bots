function contains(list, search)
	if list == nil then
		return false;
	end
	
	if #list == 0 then
		return false;
	end
	
	for index, entry in pairs(list) do
		if entry == search then
			return true;
		end
	end
	
	return false;
end

function containsKey(list, search)
	if list == nil then
		return false;
	end
	
	if #list == 0 then
		return false;
	end
	
	return list[search] ~= nil;
end

function deleteArray(list, search)
	if list == nil then
		return;
	end
	
	if #list == 0 then
		return;
	end
	
	local index = {};
	
	for key, value in pairs(list) do
	   index[value] = key;
	end
	
	if index[search] ~= nil then
		table.remove(list, index[search]);
	end
end