---@class Range
---@overload fun(p_Min, p_Max, p_Step):Range
Range = class('Range')

--[[
	@method: __init
]]
function Range:__init(p_Min, p_Max, p_Step)
	self.m_Min = p_Min or nil
	self.m_Max = p_Max or nil
	self.m_Step = p_Step or 1.0
end

--[[
	@method: __class
]]
function Range:__class()
	return 'Range'
end

--[[
	@method: GetMin
]]
function Range:GetMin()
	return self.m_Min
end

--[[
	@method: GetMax
]]
function Range:GetMax()
	return self.m_Max
end

--[[
	@method: GetStep
]]
function Range:GetStep()
	return self.m_Step
end

--[[
	@method: IsValid
]]
function Range:IsValid(p_Value)
	return p_Value >= self.m_Min and p_Value <= self.m_Max
end

--[[
	@method: Serialize
]]
function Range:Serialize()
	return {
		Min = self.m_Min,
		Max = self.m_Max,
		Step = self.m_Step
	}
end

return Range
