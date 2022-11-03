---@class ArrayMap
---@overload fun():ArrayMap
ArrayMap = class('ArrayMap')

function ArrayMap:__init()
	self._Entries = {}
end

function ArrayMap:add(p_Value)
	table.insert(self._Entries, p_Value)
end

function ArrayMap:deleteByIndex(p_Index)
	table.remove(self._Entries, p_Index)
end

function ArrayMap:exists(p_Value)
	for l_Key, l_Data in pairs(self._Entries) do
        if p_Value == l_Data then
            return true
        end
    end
	return false
end

function ArrayMap:delete(p_Value)
	for l_Key, l_Data in pairs(self._Entries) do
        if p_Value == l_Data then
            self:deleteByIndex(l_Key)
        end
    end
end

function ArrayMap:isEmpty()
	return self:count() == 0
end

function ArrayMap:clear()
	self._Entries = {}
end

function ArrayMap:count()
	return #self._Entries
end

function ArrayMap:getEntries()
	return self._Entries
end

function ArrayMap:join(p_Character)
	return table.concat(self._Entries, p_Character)
end

function ArrayMap:_tostring()
	return '[ArrayList Count=' .. self:count() .. ', ' .. json.encode(self._Entries) .. ']'
end

return ArrayMap
