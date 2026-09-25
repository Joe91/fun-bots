---@class PidController
---@overload fun(p_Kp: number, p_Ki: number, p_Kd: number, p_Limit: number, p_IsAngle: boolean|nil):PidController
PidController = class('PidController')

-- Gains are time-based, so the behaviour does not depend on the update rate:
-- Kp: output per unit of error.
-- Ki: output per (unit of error * second).
-- Kd: output per (unit of error / second).
---@param p_Kp number
---@param p_Ki number
---@param p_Kd number
---@param p_Limit number
---@param p_IsAngle boolean|nil @measurement is an angle that wraps around (like yaw), the change is wrapped to [-pi, pi]
function PidController:__init(p_Kp, p_Ki, p_Kd, p_Limit, p_IsAngle)
	self._Integral = 0
	self._LastError = nil
	self._LastMeasurement = nil
	self._Kp = p_Kp
	self._Ki = p_Ki
	self._Kd = p_Kd
	self._Limit = p_Limit
	self._IsAngle = p_IsAngle == true
end

function PidController:Reset()
	self._Integral = 0
	-- nil = no history, so the first update after a reset has no derivative kick.
	self._LastError = nil
	self._LastMeasurement = nil
end

---@param p_Error number @target - measurement (or the inverse, the sign just flips the output)
---@param p_DeltaTime number @time since the last update in seconds
---@param p_Measurement number|nil @optional: the measured value (error = target - measurement). If given, the
--- derivative is taken on the measurement instead of the error. This avoids kicks on target-changes and damps
--- the motion of the controlled object itself. For values that wrap (like yaw) create the controller with p_IsAngle.
---@return number
function PidController:Update(p_Error, p_DeltaTime, p_Measurement)
	local s_Derivative = 0
	if p_DeltaTime > 0 then
		if p_Measurement ~= nil then
			if self._LastMeasurement ~= nil then
				local s_Change = p_Measurement - self._LastMeasurement
				if self._IsAngle then
					if s_Change > math.pi then
						s_Change = s_Change - 2 * math.pi
					elseif s_Change < -math.pi then
						s_Change = s_Change + 2 * math.pi
					end
				end
				s_Derivative = -self._Kd * s_Change / p_DeltaTime
			end
		elseif self._LastError ~= nil then
			s_Derivative = self._Kd * (p_Error - self._LastError) / p_DeltaTime
		end
	end
	self._LastError = p_Error
	self._LastMeasurement = p_Measurement

	local s_Proportional = self._Kp * p_Error
	local s_IntegralInc = self._Ki * p_Error * p_DeltaTime
	self._Integral = self._Integral + s_IntegralInc
	local s_Output = s_Proportional + s_Derivative + self._Integral

	-- Anti wind up.
	if s_Output > self._Limit then
		s_Output = self._Limit
		self._Integral = self._Integral - s_IntegralInc
	elseif s_Output < -self._Limit then
		s_Output = -self._Limit
		self._Integral = self._Integral - s_IntegralInc
	end

	-- Clear Integral on dir-change.
	if p_Error > 0 and self._Integral < 0 then
		self._Integral = 0
	elseif p_Error < 0 and self._Integral > 0 then
		self._Integral = 0
	end

	return s_Output
end

return PidController
