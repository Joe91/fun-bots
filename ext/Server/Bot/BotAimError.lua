-- Humanlike aim error, used by the soldier- and the vehicle-aiming. All angles in rad, all times in s.
-- The error is made of:
--   drift:       slow, smooth wandering of the crosshair around the target (Ornstein-Uhlenbeck noise with unit
--                variance, scaled with the current sigma, so a changing sigma does not make the aim jump)
--   acquisition: offset after acquiring a new target (under- or overshoot of the flick), decays over time
--   flinch:      short kick of the aim after the bot got hit
-- Besides that, the bot perceives the movement of its target with a delay (see Bot:UpdateSeenVelocity).

---@type Utilities
local m_Utilities = require('__shared/Utilities')

local TWO_PI = 2 * math.pi

---Normal distributed random number (Box-Muller).
---@return number
local function _Gaussian()
	local s_Random = math.random()

	if s_Random < 1e-9 then
		s_Random = 1e-9
	end

	return math.sqrt(-2.0 * math.log(s_Random)) * math.cos(TWO_PI * math.random())
end

---@param p_Value number
---@param p_Limit number
---@return number
local function _Clamp(p_Value, p_Limit)
	if p_Value > p_Limit then
		return p_Limit
	elseif p_Value < -p_Limit then
		return -p_Limit
	end

	return p_Value
end

---Multiplier of the aim error of this bot: (1 - spread) for the best, (1 + spread) for the worst bot.
---@return number
function Bot:GetAimSkillFactor()
	return math.max(1.0 + Config.BotAimErrorSpread * (2.0 * self.m_Inaccuracy - 1.0), 0.0)
end

---Time since the last aiming-update. A longer pause means the bot has to acquire its target again.
---@return number
function Bot:GetAimDeltaTime()
	local s_Now = SharedUtils:GetTime()
	local s_DeltaTime = s_Now - self._AimErrorTime
	self._AimErrorTime = s_Now

	if s_DeltaTime < 0.0 or s_DeltaTime > Registry.BOT.AIM_ERROR_MAX_GAP then
		self._AimAcquire = true
		return 0.0
	end

	return s_DeltaTime
end

---Movement of the target, as the bot perceives it. It follows the real movement with a delay, so the bot notices
---changes of the direction (strafing) late. Unknown on a new target. Call before Bot:UpdateAimError.
---@param p_DeltaTime number
---@param p_Lag number delay of the perception, 0 = perfect
---@param p_VelX number real velocity of the target
---@param p_VelY number
---@param p_VelZ number
---@return number
---@return number
---@return number
function Bot:UpdateSeenVelocity(p_DeltaTime, p_Lag, p_VelX, p_VelY, p_VelZ)
	if p_Lag <= 0.0 then
		self._AimVelX, self._AimVelY, self._AimVelZ = p_VelX, p_VelY, p_VelZ
	elseif self._AimAcquire then
		self._AimVelX, self._AimVelY, self._AimVelZ = 0.0, 0.0, 0.0
	else
		local s_Blend = 1.0 - math.exp(-p_DeltaTime / p_Lag)
		self._AimVelX = self._AimVelX + (p_VelX - self._AimVelX) * s_Blend
		self._AimVelY = self._AimVelY + (p_VelY - self._AimVelY) * s_Blend
		self._AimVelZ = self._AimVelZ + (p_VelZ - self._AimVelZ) * s_Blend
	end

	return self._AimVelX, self._AimVelY, self._AimVelZ
end

---@param p_DeltaTime number
---@param p_Sigma number standard deviation of the drift (already scaled with skill and situation)
---@param p_Yaw number yaw the bot needs to hit, to measure the flick on a new target
---@param p_Pitch number
---@param p_UseFlick boolean false: the current aim is no measure for the flick (vehicles)
---@return number yawError
---@return number pitchError
function Bot:UpdateAimError(p_DeltaTime, p_Sigma, p_Yaw, p_Pitch, p_UseFlick)
	local s_Registry = Registry.BOT
	local s_SkillFactor = self:GetAimSkillFactor()

	if self._AimAcquire then
		self._AimAcquire = false
		-- Start the drift somewhere in its normal range.
		self._AimDriftYaw = _Gaussian()
		self._AimDriftPitch = _Gaussian()

		-- The flick to a new target mostly undershoots, sometimes overshoots. The bigger the turn, the bigger the miss.
		local s_AcquireYaw = 0.0
		local s_AcquirePitch = 0.0

		if p_UseFlick then
			local s_Input = self.m_Input
			local s_Factor = s_Registry.AIM_ACQUISITION_ERROR * s_SkillFactor * MathUtils:GetRandom(0.5, 1.5)

			if math.random() * 100 < s_Registry.AIM_PROBABILITY_OVERSHOOT then
				s_Factor = -s_Factor
			end

			-- Undershoot: the aim stays on the side the bot came from.
			s_AcquireYaw = -m_Utilities:NormalizeAngleRad(p_Yaw - s_Input.authoritativeAimingYaw) * s_Factor
			s_AcquirePitch = -(p_Pitch - s_Input.authoritativeAimingPitch) * s_Factor
		end

		-- Even without a turn, the aim needs to settle on a new target.
		local s_MaxError = s_Registry.AIM_ACQUISITION_MAX_ERROR
		self._AimAcquireYaw = _Clamp(s_AcquireYaw + _Gaussian() * p_Sigma * 2.0, s_MaxError)
		self._AimAcquirePitch = _Clamp(s_AcquirePitch + _Gaussian() * p_Sigma * 2.0, s_MaxError)
	elseif p_DeltaTime > 0.0 then
		-- Exact discretization of the Ornstein-Uhlenbeck process: stays at unit variance for every time-step.
		local s_Decay = math.exp(-p_DeltaTime / s_Registry.AIM_ERROR_DRIFT_TIME)
		local s_Noise = math.sqrt(1.0 - s_Decay * s_Decay)
		self._AimDriftYaw = self._AimDriftYaw * s_Decay + _Gaussian() * s_Noise
		self._AimDriftPitch = self._AimDriftPitch * s_Decay + _Gaussian() * s_Noise

		-- Worse bots need longer to settle on the target.
		local s_AcquireDecay = math.exp(-p_DeltaTime / (s_Registry.AIM_ACQUISITION_TIME * (0.5 + 0.5 * s_SkillFactor)))
		self._AimAcquireYaw = self._AimAcquireYaw * s_AcquireDecay
		self._AimAcquirePitch = self._AimAcquirePitch * s_AcquireDecay

		local s_FlinchDecay = math.exp(-p_DeltaTime / s_Registry.AIM_FLINCH_TIME)
		self._AimFlinchYaw = self._AimFlinchYaw * s_FlinchDecay
		self._AimFlinchPitch = self._AimFlinchPitch * s_FlinchDecay
	end

	local s_YawError = self._AimDriftYaw * p_Sigma + self._AimAcquireYaw + self._AimFlinchYaw
	local s_PitchError = self._AimDriftPitch * p_Sigma * s_Registry.AIM_ERROR_PITCH_FACTOR + self._AimAcquirePitch +
		self._AimFlinchPitch

	return s_YawError, s_PitchError
end

---The bot got hit: kick its aim, mostly upwards.
function Bot:AddAimFlinch()
	local s_Flinch = Registry.BOT.AIM_FLINCH
	local s_Max = s_Flinch * 3.0
	self._AimFlinchYaw = _Clamp(self._AimFlinchYaw + MathUtils:GetRandom(-1.0, 1.0) * s_Flinch, s_Max)
	self._AimFlinchPitch = _Clamp(self._AimFlinchPitch + MathUtils:GetRandom(0.3, 1.0) * s_Flinch, s_Max)
end
