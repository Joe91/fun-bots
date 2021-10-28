class('PidController')

function PidController:__init(p_Kp, p_Ki, p_Kd, p_Limit)
	self._Integral = 0
	self._LastError = 0
	self._Kp = p_Kp
	self._Ki = p_Ki
	self._kd = p_Kd
	self._Limit = p_Limit
end

function PidController:Reset()
	self._Integral = 0
end

function PidController:Update(p_Error)
	local s_Proportional = self._Kp * p_Error
	local s_Derivative = (p_Error - self._LastError) * self._kd
	local s_IntegralInc = self._Ki * p_Error
	self._Integral = self._Integral + s_IntegralInc
	local s_Output = s_Proportional + s_Derivative + self._Integral
	self._LastError = p_Error

	-- anti wind up
	if s_Output > self._Limit then
		s_Output = self._Limit
		self._Integral = self._Integral - s_IntegralInc
	elseif s_Output < -self._Limit then
		s_Output = -self._Limit
		self._Integral = self._Integral - s_IntegralInc
	end

	-- clear Integral on dir-change
	if p_Error > 0 and self._Integral < 0 then
		self._Integral = 0
	elseif p_Error < 0 and self._Integral > 0 then
		self._Integral = 0
	end

	return s_Output
end


return PidController