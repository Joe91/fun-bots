require('os')

---@class Profiler
Profiler = class "Profiler"


function Profiler:__init()
	self.m_Stats = {}
end

function Profiler:Start(p_EventName)
	self.m_PrintFrequency = 600

	if not self.m_Stats[p_EventName] then
		self.m_Stats[p_EventName] = {
			count = 0,
			total_time = 0,
			start_time = 0,
		}
	end
	self.m_Stats[p_EventName].start_time = os.clock()
end

function Profiler:End(p_EventName)
	if not self.m_Stats[p_EventName] then
		return
	end

	local s_EndTime = os.clock()
	local s_ElapsedTime = s_EndTime - self.m_Stats[p_EventName].start_time
	local s_Data = self.m_Stats[p_EventName]


	s_Data.count = s_Data.count + 1
	s_Data.total_time = s_Data.total_time + s_ElapsedTime

	if s_Data.count % self.m_PrintFrequency == 0 then
		self:PrintStats(p_EventName)
		s_Data.count = 0
		s_Data.total_time = 0
	end
end

function Profiler:PrintStats(p_EventName)
	local s_Data = self.m_Stats[p_EventName]
	local s_AvgTime = s_Data.total_time / s_Data.count * 1000
	local s_TotalTime = s_Data.total_time * 1000
	print(string.format(
		"Event: %s - Called: %d times, Total Time: %.6f ms, Avg Time: %.6f ms",
		p_EventName, s_Data.count, s_TotalTime, s_AvgTime
	))
end

if g_Profiler == nil then
	g_Profiler = Profiler()
end

return g_Profiler
