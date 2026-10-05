---@class SpikeTracer
---@overload fun():SpikeTracer
SpikeTracer = class('SpikeTracer')

-- Debug: finds single calls that block the server for long (Registry.DEBUG.SPIKE_TRACE_MS > 0).
-- Wraps every method of the classes of the mod and prints each call that takes longer than the threshold, with its
-- callers above it (indented by depth). The timer of the server has a resolution of 1 ms.
-- Steps of the garbage collector run inside whatever function allocates: a spike in a trivial function is the GC.
-- "GC ran" is only shown when it freed memory (sweep), not for its marking steps.

local SKIP_CLASSES = {
	Logger = true, Profiler = true, FunctionProfiler = true, SpikeTracer = true, Range = true, ArrayMap = true,
}

local s_Depth = 0
-- Calls above the threshold of the current top-level call, printed together when it returns.
local s_Pending = {}
-- Lua memory at the start of the top-level call: less at the end means the GC ran inside.
local s_TopMem = 0
-- Time of the top-level calls in the current frame, by name.
local s_FrameCalls = {}
local s_FrameModMs = 0
-- Hang detection: the names of the wrapped calls running now and when the top-level one started. A wrapped call more
-- than HANG_SECONDS after that errors out with them (an endless loop that calls any method of the mod).
local HANG_SECONDS = 10
local s_Stack = {}
local s_TopStart = 0

---@param p_Name string
---@param p_Function function
---@return function
local function _Wrap(p_Name, p_Function)
	local function _Done(p_Start, ...)
		s_Stack[s_Depth] = nil
		s_Depth = s_Depth - 1
		local s_Ms = (SharedUtils:GetTimeNS() - p_Start) / 1000000
		if s_Ms >= Registry.DEBUG.SPIKE_TRACE_MS then
			s_Pending[#s_Pending + 1] = string.rep("  ", s_Depth) .. string.format("%s %.0f ms", p_Name, s_Ms)
		end
		if s_Depth == 0 then
			s_FrameModMs = s_FrameModMs + s_Ms
			s_FrameCalls[p_Name] = (s_FrameCalls[p_Name] or 0) + s_Ms
		end
		if s_Depth == 0 and #s_Pending > 0 then
			-- Children return first: reverse to print the callers on top.
			local s_Lines = {}
			for l_Index = #s_Pending, 1, -1 do
				s_Lines[#s_Lines + 1] = s_Pending[l_Index]
			end
			local s_MemDiff = collectgarbage("count") - s_TopMem
			print(string.format("[SpikeTracer] (mem %+.0f KB%s)\n", s_MemDiff, s_MemDiff < 0 and ", GC ran" or "")
				.. table.concat(s_Lines, "\n"))
			s_Pending = {}
		end
		return ...
	end

	return function(...)
		local s_Now = SharedUtils:GetTimeNS()
		if s_Depth == 0 then
			s_TopMem = collectgarbage("count")
			s_TopStart = s_Now
		elseif s_Now - s_TopStart > HANG_SECONDS * 1e9 then
			s_TopStart = s_Now
			local s_Message = '[SpikeTracer] HANG in ' .. table.concat(s_Stack, ' > ', 1, s_Depth) .. ' > ' .. p_Name
			print(s_Message)
			error(s_Message)
		end
		s_Depth = s_Depth + 1
		s_Stack[s_Depth] = p_Name
		return _Done(SharedUtils:GetTimeNS(), p_Function(...))
	end
end

---Wraps the methods of a middleclass-class. Setting them on the class updates its instances and subclasses too.
---@param p_Class table
---@param p_Name string
---@return integer
local function _WrapClass(p_Class, p_Name)
	local s_Keys = {}
	for l_Key, l_Value in pairs(p_Class.__declaredMethods) do
		if type(l_Key) == 'string' and type(l_Value) == 'function' and string.sub(l_Key, 1, 2) ~= '__' then
			s_Keys[#s_Keys + 1] = l_Key
		end
	end
	for _, l_Key in ipairs(s_Keys) do
		p_Class[l_Key] = _Wrap(p_Name .. ':' .. l_Key, p_Class.__declaredMethods[l_Key])
	end
	return #s_Keys
end

function SpikeTracer:__init()
	if (Registry.DEBUG.SPIKE_TRACE_MS or 0) <= 0 then
		return
	end

	local s_Count = 0
	for l_Name, l_Value in pairs(_G) do
		if type(l_Name) == 'string' and type(l_Value) == 'table' and not SKIP_CLASSES[l_Name]
			and type(rawget(l_Value, '__declaredMethods')) == 'table' then
			s_Count = s_Count + _WrapClass(l_Value, l_Name)
		end
	end

	-- A call that errored never returns: reset once per frame. Also print long frames, to see which spikes come
	-- from the mod at all.
	local s_LastFrame = nil
	Events:Subscribe('Engine:Update', function()
		s_Depth = 0
		s_Stack = {}
		s_Pending = {}
		local s_Now = SharedUtils:GetTimeNS()
		if s_LastFrame ~= nil then
			local s_Ms = (s_Now - s_LastFrame) / 1000000
			if s_Ms >= 5 * Registry.DEBUG.SPIKE_TRACE_MS then
				local s_Calls = {}
				for l_Name, l_Ms in pairs(s_FrameCalls) do
					s_Calls[#s_Calls + 1] = { l_Name, l_Ms }
				end
				table.sort(s_Calls, function(a, b) return a[2] > b[2] end)
				local s_Parts = {}
				for l_Index = 1, math.min(4, #s_Calls) do
					s_Parts[#s_Parts + 1] = string.format("%s %.0f", s_Calls[l_Index][1], s_Calls[l_Index][2])
				end
				print(string.format("[SpikeTracer] frame %.0f ms, mod %.0f ms (%s)", s_Ms, s_FrameModMs,
					table.concat(s_Parts, ", ")))
			end
		end
		s_LastFrame = s_Now
		s_FrameModMs = 0
		s_FrameCalls = {}
	end)

	print('[SpikeTracer] ' .. s_Count .. ' functions wrapped, threshold ' .. Registry.DEBUG.SPIKE_TRACE_MS .. ' ms')
end

if g_SpikeTracer == nil then
	---@type SpikeTracer
	g_SpikeTracer = SpikeTracer()
end

return g_SpikeTracer
