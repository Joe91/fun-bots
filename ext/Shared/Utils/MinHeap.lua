---Binary min-heap of (key, value) pairs in two arrays: no table per entry. The searches over the mesh (NavRoutes,
---NavZones:Route) push thousands of entries, a table for each fed the GC and took most of their time.
---@class MinHeap
---@field Keys number[]
---@field Values any[]
---@field Size integer
MinHeap = {}

---@return MinHeap
function MinHeap.New()
	return { Keys = {}, Values = {}, Size = 0 }
end

---@param p_Heap MinHeap
---@param p_Key number
---@param p_Value any
function MinHeap.Push(p_Heap, p_Key, p_Value)
	local s_Keys = p_Heap.Keys
	local s_Values = p_Heap.Values
	local s_Index = p_Heap.Size + 1
	p_Heap.Size = s_Index
	while s_Index > 1 do
		local s_Parent = s_Index // 2
		local s_ParentKey = s_Keys[s_Parent]
		if s_ParentKey <= p_Key then
			break
		end
		s_Keys[s_Index] = s_ParentKey
		s_Values[s_Index] = s_Values[s_Parent]
		s_Index = s_Parent
	end
	s_Keys[s_Index] = p_Key
	s_Values[s_Index] = p_Value
end

---The entry with the smallest key, removed. Only on a heap that isn't empty (Size > 0).
---@param p_Heap MinHeap
---@return number key, any value
function MinHeap.Pop(p_Heap)
	local s_Keys = p_Heap.Keys
	local s_Values = p_Heap.Values
	local s_Size = p_Heap.Size
	local s_TopKey = s_Keys[1]
	local s_TopValue = s_Values[1]
	local s_LastKey = s_Keys[s_Size]
	local s_LastValue = s_Values[s_Size]
	s_Keys[s_Size] = nil
	s_Values[s_Size] = nil
	s_Size = s_Size - 1
	p_Heap.Size = s_Size
	if s_Size > 0 then
		-- Move the last entry down from the top to its place.
		local s_Index = 1
		while true do
			local s_Child = 2 * s_Index
			if s_Child > s_Size then
				break
			end
			if s_Child < s_Size and s_Keys[s_Child + 1] < s_Keys[s_Child] then
				s_Child = s_Child + 1
			end
			if s_Keys[s_Child] >= s_LastKey then
				break
			end
			s_Keys[s_Index] = s_Keys[s_Child]
			s_Values[s_Index] = s_Values[s_Child]
			s_Index = s_Child
		end
		s_Keys[s_Index] = s_LastKey
		s_Values[s_Index] = s_LastValue
	end
	return s_TopKey, s_TopValue
end

return MinHeap
