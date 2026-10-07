-- For vehicles to block missiles this fires a flare or smoke.
---@param p_TimeDelay number
function Bot:FireFlareSmoke(p_TimeDelay)
	self:_SetDelayedInput(EntryInputActionEnum.EIAFireCountermeasure, 1, p_TimeDelay)
end

---@return boolean
function Bot:_DoExitVehicle()
	if self._ExitVehicleActive then
		self:AbortAttack()
		local s_Vehicle = self.m_Player.controlledControllable
		if s_Vehicle ~= nil and s_Vehicle.typeInfo.name == "ServerSoldierEntity" then
			s_Vehicle = self.m_Player.attachedControllable
		end
		if s_Vehicle ~= nil then
			self._LeftVehicle = 'vehicle ' .. tostring(s_Vehicle.instanceId)
			self._LeftVehicleUntil = SharedUtils:GetTime() + Registry.GAME_DIRECTOR.LEFT_VEHICLE_TIME
		end
		self.m_Player:ExitVehicle(true, false)
		self:_OnFootAgain()
		return true
	end

	return false
end

---Out of the vehicle (got out, or the vehicle is gone): on foot again, on the closest path, onto the mesh where it lands.
function Bot:_OnFootAgain()
	self.m_ActiveVehicle = nil
	self._ChopperStartHeight = nil
	self._VehicleStart = nil
	self:SetState(g_BotStates.States.Moving)
	local s_Node = g_GameDirector:FindClosestPath(self.m_Player.soldier.worldTransform.trans:Clone(), false, true, nil)

	if s_Node ~= nil then
		-- Switch to foot.
		self._InvertPathDirection = false
		self._PathIndex = s_Node.PathIndex
		self._CurrentWayPoint = s_Node.PointIndex
		self._LastWayDistance = 1000.0
	end
	self._KillYourselfTimer = 0.0
	-- Onto the mesh where it lands (UpdateNormalMovement): the closest waypoint from the air can be far off.
	self._MeshAfterExit = true
	-- The stuck-handling of the vehicle must not continue on foot.
	self._StuckTimer = 0.0
	self._StuckRerouteCount = 0
	self._ObstacleRetryCounter = 0
	self:_ResetObstacleSequence()
	self._ExitVehicleActive = false
	self._DontAttackPlayers = false
end

function Bot:ExitVehicle()
	self._ExitVehicleActive = true
end
