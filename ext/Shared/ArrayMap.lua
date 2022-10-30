---@class ArrayMap
---@overload fun():ArrayMap
ArrayMap = class 'ArrayMap'

function ArrayMap:__init()
	self._entries = {}
end

function ArrayMap:add(p_Value)
	table.insert(self._entries, p_Value)
end

function ArrayMap:deleteByIndex(p_Index)
	table.remove(self._entries, p_Index)
end

function ArrayMap:exists(p_Value)
	local s_Index = {}

	for l_Key, l_Data in pairs(self._entries) do
		s_Index[l_Data] = l_Key
	end

	if s_Index[p_Value] ~= nil then
		return true
	end

	return false
end

function ArrayMap:delete(p_Value)
	local s_Index = {}

	for l_Key, l_Data in pairs(self._entries) do
		s_Index[l_Data] = l_Key
	end

	if s_Index[p_Value] ~= nil then
		self:deleteByIndex(s_Index[p_Value])
	end
end

function ArrayMap:isEmpty()
	return self:count() == 0
end

function ArrayMap:clear()
	self._entries = {}
end

function ArrayMap:count()
	return #self._entries
end

function ArrayMap:getEntries()
	return self._entries
end

function ArrayMap:join(p_Character)
	return table.concat(self._entries, p_Character)
end

function ArrayMap:_tostring()
	return '[ArrayList Count=' .. self:count() .. ', ' .. json.encode(self._entries) .. ']'
end

return ArrayMap
