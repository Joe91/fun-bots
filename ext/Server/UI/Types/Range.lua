--[[
	@class: Range
]]
class('Range')

--[[
	@method: __init
]]
function Range:__init(min, max, step)
	self.min = min or nil
	self.max = max or nil
	self.step = step or 1.0
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
	return self.min
end

--[[
	@method: GetMax
]]
function Range:GetMax()
	return self.max
end

--[[
	@method: GetStep
]]
function Range:GetStep()
	return self.step
end

--[[
	@method: IsValid
]]
function Range:IsValid(value)
	return value >= self.min and value <= self.max
end

--[[
	@method: Serialize
]]
function Range:Serialize()
	return {
		Min = self.min,
		Max = self.max,
		Step = self.step
	}
end

return Range
