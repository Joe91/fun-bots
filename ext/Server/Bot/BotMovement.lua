---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type NavRoutes
local m_NavRoutes = require('NavRoutes')


-- >>> SMART PATH OFFSET
-- Every bot walks with a lateral offset (left, center or right) next to the recorded path.
-- - The side is chosen once per life, not per path: a new side on every path-switch made the bots cross the path.
-- - The offset direction comes from the path tangent over a few meters: recorded paths are noisy, and the normal of a
--   single segment swung the offset points from one side to the other.
-- - The offset fades in and out instead of switching on and off, so the target point never jumps sideways.
local OFFSET_TANGENT_DISTANCE = 3.0  -- Meters of path before and after a node used for its tangent.
local OFFSET_TANGENT_MAX_NODES = 5   -- Max nodes walked to each side for the tangent.
local OFFSET_STEP_HEIGHT = 0.35      -- Height difference between two nodes that counts as stairs / step.
local OFFSET_FADE_IN_SPEED = 0.8     -- Offset-factor per second.
local OFFSET_FADE_OUT_SPEED = 3.0    -- Offset-factor per second. Fast: the path ahead needs the center soon.
local OFFSET_CENTER_TIME_STEEP = 2.0 -- Seconds to stay centered after stairs, so landings are not offset.
local OFFSET_CENTER_TIME_OBSTACLE = 3.0
local OFFSET_CACHE_SIZE = 4

-- Obstacle detection.
local OBSTACLE_STANDSTILL_SPEED = 0.3  -- Horizontal m/s below which the bot counts as standing.
local OBSTACLE_STANDSTILL_TIME = 0.4   -- Seconds of standstill before the obstacle-sequence starts.
local OBSTACLE_START_GRACE = 1.2       -- Seconds without standstill-check when the movement (re)starts: getting up, accelerating.
local OBSTACLE_NO_PROGRESS_TIME = 5.0  -- Seconds without getting closer to the target before the obstacle-sequence starts.
local OBSTACLE_MIN_PROGRESS = 0.5      -- Meters the bot has to get closer to count as progress.
local OBSTACLE_RESOLVED_PROGRESS = 1.0 -- Meters closer to the target than at the start of the sequence: obstacle overcome.

---@param p_Node Waypoint
---@param p_Step integer
---@return Waypoint|nil
local function _GetPathNeighbour(p_Node, p_Step)
	local s_Nodes = m_NodeCollection:Get(nil, p_Node.PathIndex)
	local s_Count = #s_Nodes
	local s_Index = p_Node.PointIndex + p_Step

	if s_Index < 1 or s_Index > s_Count then
		-- Only looping paths continue at the other end (see Bot:_GetWayIndex).
		if s_Count == 0 or s_Nodes[1].OptValue == 0xFF then
			return nil
		end
		s_Index = ((s_Index - 1) % s_Count) + 1
	end

	return s_Nodes[s_Index]
end

---Walks the path from p_Node until OFFSET_TANGENT_DISTANCE is reached.
---@return number x, number z of the last position
---@return boolean true if a step / stairs was found next to the node
local function _WalkPath(p_Node, p_Step)
	local s_LastPos = p_Node.Position
	local s_EndX = s_LastPos.x
	local s_EndZ = s_LastPos.z
	local s_Travelled = 0.0
	local s_Steep = false

	for i = 1, OFFSET_TANGENT_MAX_NODES do
		local s_Neighbour = _GetPathNeighbour(p_Node, i * p_Step)
		if s_Neighbour == nil then
			break
		end

		local s_Pos = s_Neighbour.Position
		if i == 1 and math.abs(s_Pos.y - s_LastPos.y) > OFFSET_STEP_HEIGHT then
			s_Steep = true
		end

		local s_DeltaX = s_Pos.x - s_EndX
		local s_DeltaZ = s_Pos.z - s_EndZ
		s_Travelled = s_Travelled + math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
		s_EndX = s_Pos.x
		s_EndZ = s_Pos.z
		s_LastPos = s_Pos

		if s_Travelled >= OFFSET_TANGENT_DISTANCE then
			break
		end
	end

	return s_EndX, s_EndZ, s_Steep
end

---Offset data of a node: the unit right-vector of the (smoothed) path and if the node must stay centered.
---Cached, the tangent only changes when the target node changes.
---@param p_Node table Waypoint or follow-point
---@param p_Direction integer 1 = forward along the path, -1 = inverted
---@param p_FallbackNext table|nil used for nodes without path (follow-points)
function Bot:_GetPathOffsetEntry(p_Node, p_Direction, p_FallbackNext)
	local s_Cache = self.m_PathOffsetCache
	for i = 1, #s_Cache do
		local l_Entry = s_Cache[i]
		if l_Entry.Node == p_Node and l_Entry.Direction == p_Direction then
			return l_Entry
		end
	end

	local s_Pos = p_Node.Position
	local s_TangentX = 0.0
	local s_TangentZ = 0.0
	local s_Steep = p_Node.ExtraMode == 1 -- jump-node

	if p_Node.PathIndex ~= nil and p_Node.PointIndex ~= nil then
		local s_AheadX, s_AheadZ, s_SteepAhead = _WalkPath(p_Node, p_Direction)
		local s_BehindX, s_BehindZ, s_SteepBehind = _WalkPath(p_Node, -p_Direction)
		s_TangentX = s_AheadX - s_BehindX
		s_TangentZ = s_AheadZ - s_BehindZ
		s_Steep = s_Steep or s_SteepAhead or s_SteepBehind
	elseif p_FallbackNext ~= nil then
		local s_NextPos = p_FallbackNext.Position
		s_TangentX = s_NextPos.x - s_Pos.x
		s_TangentZ = s_NextPos.z - s_Pos.z
		s_Steep = s_Steep or math.abs(s_NextPos.y - s_Pos.y) > OFFSET_STEP_HEIGHT
	end

	local s_Length = math.sqrt(s_TangentX * s_TangentX + s_TangentZ * s_TangentZ)
	local s_Entry = {
		Node = p_Node,
		Direction = p_Direction,
		-- right = (dir.z, 0, -dir.x)
		RightX = s_Length > 0.01 and (s_TangentZ / s_Length) or 0.0,
		RightZ = s_Length > 0.01 and (-s_TangentX / s_Length) or 0.0,
		Steep = s_Steep or s_Length <= 0.01,
		-- Action-nodes have to be reached exactly.
		Center = s_Steep or s_Length <= 0.01 or (p_Node.Data ~= nil and p_Node.Data.Action ~= nil),
		Offset = nil,
		Result = nil,
	}

	table.insert(s_Cache, 1, s_Entry)
	if #s_Cache > OFFSET_CACHE_SIZE then
		table.remove(s_Cache)
	end

	return s_Entry
end

---@param p_Entry table from _GetPathOffsetEntry
---@param p_Offset number meters to the right
local function _GetOffsetPoint(p_Entry, p_Offset)
	if p_Entry.Center or p_Offset == 0.0 then
		return p_Entry.Node
	end

	if p_Entry.Offset ~= p_Offset then
		-- All other fields (PathIndex, Data, ...) are read from the original node. Path-switches and actions need them.
		local s_Pos = p_Entry.Node.Position
		p_Entry.Result = setmetatable({
			Position = Vec3(s_Pos.x + p_Entry.RightX * p_Offset, s_Pos.y, s_Pos.z + p_Entry.RightZ * p_Offset),
			Original = p_Entry.Node,
		}, { __index = p_Entry.Node })
		p_Entry.Offset = p_Offset
	end

	return p_Entry.Result
end

---Holds the path-offset centered for the given time. The offset fades in again afterwards.
---@param p_Time number
function Bot:CenterPathOffset(p_Time)
	self.m_OffsetFactor = 0.0
	if p_Time > self.m_OffsetCenterTimer then
		self.m_OffsetCenterTimer = p_Time
	end
end

---@param p_OriginalPoint table
---@param p_NextPoint table
---@param p_NextToNextPoint table
---@param p_DeltaTime number
function Bot:ApplyPathOffset(p_OriginalPoint, p_NextPoint, p_NextToNextPoint, p_DeltaTime)
	-- Side and distance once per life.
	if self.m_PathSide == nil then
		self.m_PathSide = MathUtils:GetRandomInt(-1, 1)          -- -1 left, 0 center, 1 right
		self.m_OffsetDistance = MathUtils:GetRandom(0.8, 1.2) -- meters
	end

	if self.m_PathSide == 0 then
		return p_OriginalPoint, p_NextPoint
	end

	-- Action-nodes are reached exactly.
	if p_OriginalPoint.Data and p_OriginalPoint.Data.Action then
		return p_OriginalPoint, p_NextPoint
	end

	local s_Direction = self._InvertPathDirection and -1 or 1
	local s_Entry = self:_GetPathOffsetEntry(p_OriginalPoint, s_Direction, p_NextPoint)
	local s_NextEntry = self:_GetPathOffsetEntry(p_NextPoint, s_Direction, p_NextToNextPoint)

	-- Stairs / steps ahead: center until a while after them.
	if s_Entry.Steep or s_NextEntry.Steep then
		self.m_OffsetCenterTimer = math.max(self.m_OffsetCenterTimer, OFFSET_CENTER_TIME_STEEP)
	end

	if self._ObstacleSequenceTimer ~= 0 then
		-- The offset might have moved the bot into the obstacle.
		self:CenterPathOffset(OFFSET_CENTER_TIME_OBSTACLE)
	end

	-- Fade the offset towards its target, never switch it.
	local s_TargetFactor = 1.0
	if self.m_OffsetCenterTimer > 0.0 then
		self.m_OffsetCenterTimer = self.m_OffsetCenterTimer - p_DeltaTime
		s_TargetFactor = 0.0
	elseif Globals.IsRush and self._Objective ~= '' and g_GameDirector:IsOnSubobjectivePath(self._PathIndex, self._Objective) then
		s_TargetFactor = 0.0
	end

	if self.m_OffsetFactor < s_TargetFactor then
		self.m_OffsetFactor = math.min(s_TargetFactor, self.m_OffsetFactor + OFFSET_FADE_IN_SPEED * p_DeltaTime)
	elseif self.m_OffsetFactor > s_TargetFactor then
		self.m_OffsetFactor = math.max(s_TargetFactor, self.m_OffsetFactor - OFFSET_FADE_OUT_SPEED * p_DeltaTime)
	end

	-- Rounded to cm: the offset points are only rebuilt when the offset changes.
	local s_Offset = math.floor(self.m_PathSide * self.m_OffsetDistance * self.m_OffsetFactor * 100 + 0.5) / 100

	return _GetOffsetPoint(s_Entry, s_Offset), _GetOffsetPoint(s_NextEntry, s_Offset)
end

---@return boolean true if the bot entered a vehicle
function Bot:_ExecuteActionIfNeeded(p_Point, p_DeltaTime)
	if self._ActiveAction == BotActionFlags.OtherActionActive then
		if p_Point.Data ~= nil and p_Point.Data.Action ~= nil then
			if p_Point.Data.Action.type == 'vehicle' then
				if Config.UseVehicles then
					local s_RetCode, s_Position = self:_EnterVehicle(false)
					if s_RetCode == 0 then
						---@cast s_Position -nil
						self:_ResetActionFlag(BotActionFlags.OtherActionActive)
						local s_Node = g_GameDirector:FindClosestPath(s_Position, true, false, self.m_ActiveVehicle.Terrain)

						if s_Node ~= nil then
							-- Switch to the vehicle path. The next update picks up the new point.
							self._InvertPathDirection = false
							self._PathIndex = s_Node.PathIndex
							self._CurrentWayPoint = s_Node.PointIndex
							self._LastWayDistance = 1000.0
						end
						self._LastActionId = p_Point.Index
						return true
					end
				end
				self:_ResetActionFlag(BotActionFlags.OtherActionActive)
			elseif p_Point.Data.Action.type == "beacon"
				and self.m_SecondaryGadget ~= nil and self.m_SecondaryGadget.type == WeaponTypes.Beacon
				and not self.m_HasBeacon
			then
				self._WeaponToUse = BotWeapons.Gadget2

				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_5 then
					if self.m_Player.soldier.weaponsComponent.weapons[6] and self.m_Player.soldier.weaponsComponent.weapons[6].primaryAmmo > 0 then
						self:_SetInput(EntryInputActionEnum.EIAFire, 1)
					else
						self:_SetInput(EntryInputActionEnum.EIAFire, 0)
						self:_ResetActionFlag(BotActionFlags.OtherActionActive)
					end
				end
			elseif p_Point.Data.Action.type == "beacon" then
				self:_ResetActionFlag(BotActionFlags.OtherActionActive)
			elseif self._ActionTimer <= p_Point.Data.Action.time then
				for l_Index = 1, #p_Point.Data.Action.inputs do
					local l_Input = p_Point.Data.Action.inputs[l_Index]
					self:_SetInput(l_Input, 1)
				end
			end
		else
			self:_ResetActionFlag(BotActionFlags.OtherActionActive)
		end

		self._ActionTimer = self._ActionTimer - p_DeltaTime

		if self._ActionTimer <= 0.0 then
			self:_ResetActionFlag(BotActionFlags.OtherActionActive)
		end

		if self._ActiveAction ~= BotActionFlags.OtherActionActive then -- action finished
			self._LastActionId = p_Point.Index                   -- remember last action node to continue from here
		end
	end

	return false
end

---@return boolean true if defending took over the movement this tick
function Bot:_HandleDefendingIfNeeded(p_DeltaTime)
	if self._ObjectiveMode == BotObjectiveModes.Defend and g_GameDirector:IsAtTargetObjective(self._PathIndex, self._Objective) then
		self._DefendTimer = self._DefendTimer + p_DeltaTime

		local s_TargetTime = self.m_Id % 5 + 4 -- min 2 sec on path, then 2 sec movement to side
		if self._DefendTimer >= s_TargetTime then
			-- look around
			self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement

			local s_DefendMode = self.m_Id % 3
			if s_DefendMode == 0 then
				if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
					self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
				end
			elseif s_DefendMode == 1 then
				if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
					self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				end
			else
				if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
					self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
				end
			end

			self:LookAround(p_DeltaTime)

			-- don't do anything else
			return true
		elseif self._DefendTimer >= (s_TargetTime - 2) then
			self.m_ActiveSpeedValue = BotMoveSpeeds.Backwards
			local s_StrafeValue = 1.0
			if self.m_Id % 2 == 0 then
				s_StrafeValue = -1.0
			end
			self:_SetInput(EntryInputActionEnum.EIAStrafe, s_StrafeValue)
			return true
		end
	else
		self._DefendTimer = 0.0
	end

	return false
end

function Bot:_ApplyReactionAction(p_DeltaTime)
	if self._ActiveAction == BotActionFlags.RunAway and self._ActionTimer > 0.0 then
		self._ActionTimer = self._ActionTimer - p_DeltaTime

		self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint
		if self._ActionTimer <= 0.0 then
			self:_ResetActionFlag(BotActionFlags.RunAway)
		end
	end

	if self._ActiveAction == BotActionFlags.HideOnAttack and self._ActionTimer > 0.0 then
		self._ActionTimer = self._ActionTimer - p_DeltaTime

		self.m_ActiveSpeedValue = BotMoveSpeeds.VerySlowProne
		if self._ActionTimer <= 0.0 then
			self:_ResetActionFlag(BotActionFlags.HideOnAttack)
		end
	end
end

function Bot:_HandleSidwardsMovement(p_DeltaTime)
	if Config.MoveSidewards then
		if self._ObstacleSequenceTimer ~= 0 then
			self.m_YawOffset = 0.0
		else
			if self._SidewardsTimer <= 0.0 then
				if self.m_StrafeValue ~= 0 then
					self._SidewardsTimer = MathUtils:GetRandom(Config.MinMoveCycle, Config.MaxStraigtCycle)
					self.m_StrafeValue = 0.0
					self.m_YawOffset = 0.0
				else
					self._SidewardsTimer = MathUtils:GetRandom(Config.MinMoveCycle, Config.MaxSideCycle)
					if MathUtils:GetRandomInt(0, 1) > 0 then -- Random direction.
						self.m_StrafeValue = 1.0
					else
						self.m_StrafeValue = -1.0
					end
					if self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
						self.m_YawOffset = 0.3927 * -self.m_StrafeValue
					else
						self.m_YawOffset = 0.7854 * -self.m_StrafeValue
					end
				end
			end
			self:_SetInput(EntryInputActionEnum.EIAStrafe, self.m_StrafeValue)
			self._SidewardsTimer = self._SidewardsTimer - p_DeltaTime
		end
	end
end

---Detects if the bot does not get along: standing still for a moment, or no progress towards the target for longer
---(running against a wall while strafing, circling around a node, ...).
---@return boolean true if the obstacle-sequence has to start
function Bot:_DetectObstacle(p_Velocity, p_DeltaTime, p_PlayerPos)
	local s_TargetPos = self._TargetPoint.Position
	local s_DeltaX = s_TargetPos.x - p_PlayerPos.x
	local s_DeltaZ = s_TargetPos.z - p_PlayerPos.z
	local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
	local s_Node = self._TargetPoint.Original or self._TargetPoint
	local s_Now = m_Utilities:GetTime()

	-- The movement (re)starts after a pause (spawn, attack, defending, action, ...): the bot might have to stand up
	-- from prone first and has to accelerate, so no standstill-check for a moment.
	if s_Now - self._ProgressLastTime > 1.0 then
		self._ProgressNode = nil
		self._LowSpeedTimer = -OBSTACLE_START_GRACE
	end

	-- Restart the progress-check for a new target.
	if s_Node ~= self._ProgressNode then
		self._ProgressNode = s_Node
		self._ProgressBestDistance = s_Distance
		self._NoProgressTimer = 0.0
	elseif s_Distance < self._ProgressBestDistance - OBSTACLE_MIN_PROGRESS then
		self._ProgressBestDistance = s_Distance
		self._NoProgressTimer = 0.0
	else
		self._NoProgressTimer = self._NoProgressTimer + p_DeltaTime
	end
	self._ProgressLastTime = s_Now

	-- Horizontal speed only: jumping in front of a wall is no movement.
	local s_Speed = math.sqrt(p_Velocity.x * p_Velocity.x + p_Velocity.z * p_Velocity.z)
	if s_Speed < OBSTACLE_STANDSTILL_SPEED then
		self._LowSpeedTimer = self._LowSpeedTimer + p_DeltaTime
	else
		self._LowSpeedTimer = 0.0 -- Moving again, this also ends the start-grace.
	end

	-- A short standstill (spawn, landing, turning) is no obstacle.
	if self._LowSpeedTimer >= OBSTACLE_STANDSTILL_TIME or self._NoProgressTimer >= OBSTACLE_NO_PROGRESS_TIME then
		self._ObstacleStartDistance = s_Distance
		return true
	end

	return false
end

---Stops a running obstacle-sequence when something else takes over the movement (defending, action, waiting).
function Bot:_StopObstacleSequence()
	if self._ObstacleSequenceTimer ~= 0 then
		self:_ResetObstacleSequence()
	end
end

---Resets the obstacle-sequence, e.g. when the bot got along again.
function Bot:_ResetObstacleSequence()
	self._ObstacleSequenceTimer = 0
	self._LowSpeedTimer = 0.0
	self._NoProgressTimer = 0.0
	self._ProgressNode = nil
	self:_ResetActionFlag(BotActionFlags.MeleeActive)
end

function Bot:_ObstacleHandling(p_Velocity, p_DistanceSquared, p_HeightDistance, p_DeltaTime, p_PlayerPos)
	local s_SetTargetReached = false
	local s_IncrementNodes = 0

	if self._LastWayDistance == 1024 then
		s_SetTargetReached = true -- skip came from target-movement
		return { s_SetTargetReached, s_IncrementNodes }
	end

	-- In the sequence: got along again? Check the progress towards the target, the strafing alone moves the bot.
	if self._ObstacleSequenceTimer ~= 0 then
		local s_TargetPos = self._TargetPoint.Position
		local s_DeltaX = s_TargetPos.x - p_PlayerPos.x
		local s_DeltaZ = s_TargetPos.z - p_PlayerPos.z
		if math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ) < self._ObstacleStartDistance - OBSTACLE_RESOLVED_PROGRESS then
			self:_ResetObstacleSequence()
			return { s_SetTargetReached, s_IncrementNodes }
		end
	end

	-- handling on standstill
	if self._ObstacleSequenceTimer ~= 0 or self:_DetectObstacle(p_Velocity, p_DeltaTime, p_PlayerPos) then
		-- Try to get around obstacle.
		self.m_ActiveSpeedValue = BotMoveSpeeds.Normal                  -- Always try to stand.
		if p_HeightDistance > 1.5 then                                  -- no change to get there, so skip the obstacle-stuff
			self._ObstacleRetryCounter = 10
			goto skip
		end

		if self._ObstacleSequenceTimer == 0 then -- Step 0
			local s_P = Vec2(p_PlayerPos.x, p_PlayerPos.z)
			local s_A = Vec2(self._TargetPoint.Position.x, self._TargetPoint.Position.z)
			local s_B = Vec2(self._NextTargetPoint.Position.x, self._NextTargetPoint.Position.z)
			local s_Cross = (s_B.x - s_A.x) * (s_P.y - s_A.y) - (s_B.y - s_A.y) * (s_P.x - s_A.x)
			if s_Cross > 0 then
				-- target on left side
				self.m_StrafeValue = -1.0
			else
				-- target on right side
				self.m_StrafeValue = 1.0
			end
			self._TargetPitch = 0.0
			self.m_YawOffset = 0.0
		end

		if self._ObstacleSequenceTimer > 2.6 then -- Step 4 - repeat afterwards.
			self._ObstacleSequenceTimer = 0
			self:_ResetActionFlag(BotActionFlags.MeleeActive)
			self._ObstacleRetryCounter = self._ObstacleRetryCounter + 1
		elseif self._ObstacleSequenceTimer > 1.6 then -- Step 3
			if self._ObstacleRetryCounter == 0 then
				if self._ActiveAction ~= BotActionFlags.MeleeActive then
					self._ActiveAction = BotActionFlags.MeleeActive
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
					self:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
					self:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
					self.m_ActiveWeapon = self.m_Knife
					self._MeleeCooldownTimer = Config.MeleeAttackCoolDown -- Set time to ensure bot exit knife-mode when attack starts.
				else
					self:_SetInput(EntryInputActionEnum.EIAFire, 1)
				end
			else
				self:_SetInput(EntryInputActionEnum.EIAFire, 1)
			end
		elseif self._ObstacleSequenceTimer > 1.3 then -- Step 2
			if self._ObstacleSequenceTimer <= 1.3 + p_DeltaTime then
				self.m_StrafeValue = self.m_StrafeValue * -1.0
			end
			self:_SetInput(EntryInputActionEnum.EIAStrafe, self.m_StrafeValue)
		elseif self._ObstacleSequenceTimer > 1.0 then -- Step 2
			self:_SetInput(EntryInputActionEnum.EIAStrafe, self.m_StrafeValue)
		elseif self._ObstacleSequenceTimer > 0.7 then -- Step 2
			self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
			self:_SetInput(EntryInputActionEnum.EIAJump, 1)
			self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Always try to stand.
		elseif self._ObstacleSequenceTimer >= 0.0 then -- Step 0
			self:_SetInput(EntryInputActionEnum.EIAStrafe, self.m_StrafeValue)
			self.m_ActiveSpeedValue = BotMoveSpeeds.Slow
		end

		::skip::
		self._ObstacleSequenceTimer = self._ObstacleSequenceTimer + p_DeltaTime
		self._StuckTimer = self._StuckTimer + p_DeltaTime

		if p_Velocity.magnitude > 3.5 and math.abs(p_Velocity.y) < 0.5 then -- more than full strafe
			self:_ResetObstacleSequence()
			self._StuckTimer = 0.0
			self._ObstacleRetryCounter = 0
			s_SetTargetReached = true
			return { s_SetTargetReached, s_IncrementNodes }
		end

		if self._ObstacleRetryCounter >= 2 then -- Try next waypoint.
			self._ObstacleRetryCounter = 0
			-- Fresh start for the next target. The stuck-timer keeps running, it resets only on a reached waypoint.
			self:_ResetObstacleSequence()
			s_SetTargetReached = true

			if Config.TeleportIfStuck and m_Utilities:CheckProbability(Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK) then
				-- Teleport onto the path itself, the offset-point might be inside a wall.
				local s_TargetPosition = (self._TargetPoint.Original or self._TargetPoint).Position
				local s_NextPosition = self._NextTargetPoint and (self._NextTargetPoint.Original or self._NextTargetPoint).Position
				local s_Transform = self.m_Player.soldier.worldTransform:Clone()
				s_Transform.trans = s_TargetPosition
				if s_NextPosition then
					s_Transform:LookAtTransform(s_TargetPosition, s_NextPosition)
				end
				self.m_Player.soldier:SetTransform(s_Transform)
				m_Logger:Write('teleported ' .. self.m_Player.name)
			else
				s_IncrementNodes = MathUtils:GetRandomInt(0, 4) -- Go up to 4 points further.
				if s_IncrementNodes == 0 then
					s_IncrementNodes = -2           -- Go backwards and try again.
				end

				if (Globals.IsConquest or Globals.IsRush) then
					if g_GameDirector:IsOnObjectivePath(self._PathIndex)
						and m_Utilities:CheckProbability(Registry.BOT.PROBABILITY_CHANGE_DIRECTION_IF_STUCK)
					then
						self._InvertPathDirection = not self._InvertPathDirection
					end
				end
			end
		end

		if self._StuckTimer > 15.0 then
			return nil
		end

		return { s_SetTargetReached, s_IncrementNodes }
	else
		self:_ResetActionFlag(BotActionFlags.MeleeActive)
		return { s_SetTargetReached, s_IncrementNodes }
	end
end

function Bot:_JumpDetection(p_Point, p_ActivePointIndex)
	if self._ObstacleSequenceTimer == 0 then
		if (p_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y) > 0.3 and Config.JumpWhileMoving then
			-- Detect, if a jump was recorded or not.
			local s_JumpValid = false
			if p_Point.ExtraMode == 1 then
				s_JumpValid = true
			else
				for i = 1, 2 do
					local s_PointBefore = m_NodeCollection:Get(p_ActivePointIndex - i, self._PathIndex)
					local s_PointAfter = m_NodeCollection:Get(p_ActivePointIndex + i, self._PathIndex)

					if
						(s_PointBefore ~= nil and s_PointBefore.ExtraMode == 1) or
						(s_PointAfter ~= nil and s_PointAfter.ExtraMode == 1) then
						s_JumpValid = true
						break
					end
				end
			end

			if s_JumpValid then
				self:_SetInput(EntryInputActionEnum.EIAJump, 1)
				self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
			end
		end
	end
end

function Bot:_IsTargetDistanceReached(p_DistanceFromTargetSquared, p_HeightDistance)
	-- apply speed values
	local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint
	if self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
		s_TargetDistanceSpeed = s_TargetDistanceSpeed * 1.5
	elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch or self.m_ActiveSpeedValue == BotMoveSpeeds.Slow then
		s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.7
	elseif self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
		s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.5
	end
	local s_TargetDistanceSpeedSquared = s_TargetDistanceSpeed * s_TargetDistanceSpeed -- use squared values to avoid sqrt

	-- Target-Reached handling
	if p_DistanceFromTargetSquared <= s_TargetDistanceSpeedSquared and p_HeightDistance <= Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT then
		return true
	else
		return false
	end
end

function Bot:_CheckForAction(p_Point)
	-- CHECK FOR ACTION.
	if p_Point.Data and p_Point.Data.Action ~= nil then
		local s_Action = p_Point.Data.Action

		if g_GameDirector:CheckForExecution(p_Point, self.m_Player.teamId, false) then
			self._ActiveAction = BotActionFlags.OtherActionActive

			if s_Action.time ~= nil then
				self._ActionTimer = s_Action.time
			else
				self._ActionTimer = 0.0
			end

			if s_Action.yaw ~= nil then
				self._TargetYaw = s_Action.yaw
			end

			if s_Action.pitch ~= nil then
				self._TargetPitch = s_Action.pitch
			end

			return true
		end
	end
	return false
end

function Bot:_CheckAndDoPathSwitch(p_Point)
	-- On a navigation path the bot walks on to the zone at its end, the route goes on from there (NavRoutes). Only for
	-- other objectives (a vehicle, a beacon) it may switch.
	if (self._Objective == '' or m_NavRoutes:Knows(self._Objective)) and m_NavRoutes:GetPath(self._PathIndex) ~= nil then
		self._OnSwitch = false
		return
	end

	-- CHECK FOR PATH-SWITCHES.
	local s_NewWaypoint = nil
	local s_SwitchPath = false
	s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(self, self.m_Id, p_Point, self._Objective, false,
		self.m_Player.teamId, nil)

	if s_SwitchPath and not self._OnSwitch and s_NewWaypoint then
		if self._Objective ~= '' then
			-- 'Best' direction for objective on switch.
			local s_Direction = m_NodeCollection:ObjectiveDirection(s_NewWaypoint, self._Objective, false)
			if s_Direction then
				self._InvertPathDirection = (s_Direction == 'Previous')
			end
		else
			-- Random path direction on switch.
			self._InvertPathDirection = MathUtils:GetRandomInt(1, 2) == 1
		end

		self._PathIndex = s_NewWaypoint.PathIndex
		self._CurrentWayPoint = s_NewWaypoint.PointIndex
		self._TargetPoint = s_NewWaypoint
		if self._InvertPathDirection then
			self._NextTargetPoint = m_NodeCollection:Get(self:_GetWayIndex(-1), self._PathIndex)
		else
			self._NextTargetPoint = m_NodeCollection:Get(self:_GetWayIndex(1), self._PathIndex)
		end
		self._OnSwitch = true
	else
		self._OnSwitch = false
	end
end

---Teleports the bot onto a node of another path and walks on there, heading for its objective (GameDirector, for bots
---on paths they can't leave).
---@param p_Node Waypoint
function Bot:TeleportToPath(p_Node)
	local s_Soldier = self.m_Player.soldier
	if s_Soldier == nil then
		return
	end

	local s_Transform = s_Soldier.worldTransform:Clone()
	s_Transform.trans = p_Node.Position:Clone()
	s_Soldier:SetTransform(s_Transform)

	self._PathIndex = p_Node.PathIndex
	self._CurrentWayPoint = p_Node.PointIndex
	if self._Objective ~= '' then
		local s_Direction = m_NodeCollection:ObjectiveDirection(p_Node, self._Objective, false)
		if s_Direction then
			self._InvertPathDirection = (s_Direction == 'Previous')
		end
	end

	self:CenterPathOffset(4.0)
	self._StuckTimer = 0.0
	self._ObstacleRetryCounter = 0
	self:_ResetObstacleSequence()
	self._LastWayDistance = 1000.0
end

---@param p_DeltaTime number
function Bot:UpdateNormalMovement(p_DeltaTime)
	-- Move along points.
	self._AttackModeMoveTimer = 0.0


	if self._FollowTargetPlayer == nil then -- default movement
		-- In the zone of the objective the bot walks the network of the zone (BotZoneMovement).
		if self.m_Zone ~= nil and self:UpdateZoneMovement(p_DeltaTime) then
			return
		end

		local s_ActivePointIndex, s_InvertPathDirection = self:_GetWayIndex(0)
		self._CurrentWayPoint = s_ActivePointIndex
		self._InvertPathDirection = s_InvertPathDirection

		local s_Point = nil
		local s_NextPoint = nil
		local s_NextToNextPoint = nil
		local s_PointIncrement = 1
		local s_NoStuckReset = false

		if #self._ShootWayPoints > 0 then -- We need to go back to the path first.		
			s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)
			---@cast s_Point -nil
			if s_Point == nil then
				return
			end
			local s_SoldierPos = self.m_Player.soldier.worldTransform.trans
			local s_ClosestDistance = s_SoldierPos:Distance(s_Point.Position)
			local s_ClosestNode = s_ActivePointIndex
			for i = 1, Registry.BOT.NUMBER_NODES_TO_SCAN_AFTER_ATTACK do
				for _, l_Index in ipairs({ s_ActivePointIndex - i, s_ActivePointIndex + i }) do
					s_Point = m_NodeCollection:Get(l_Index, self._PathIndex)
					if s_Point then
						local s_Distance = s_SoldierPos:Distance(s_Point.Position)
						if s_Distance < s_ClosestDistance then
							s_ClosestDistance = s_Distance
							s_ClosestNode = l_Index
						end
					end
				end
			end
			if s_ClosestDistance < 5.0 then
				self._CurrentWayPoint = s_ClosestNode
				s_ActivePointIndex = s_ClosestNode
			end
			self._ShootWayPoints = {}
		end

		-- get all nodes
		s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)
		if s_Point == nil then
			return
		end
		if not self._InvertPathDirection then
			s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(1), self._PathIndex)
			if s_NextPoint then
				s_NextToNextPoint = m_NodeCollection:Get(self:_GetWayIndex(2), self._PathIndex)
			end
		else
			s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(-1), self._PathIndex)
			if s_NextPoint then
				s_NextToNextPoint = m_NodeCollection:Get(self:_GetWayIndex(-2), self._PathIndex)
			end
		end

		if Registry.BOT.USE_PATH_OFFSETS and s_Point and s_NextPoint and s_NextToNextPoint then
			s_Point, s_NextPoint = self:ApplyPathOffset(s_Point, s_NextPoint, s_NextToNextPoint, p_DeltaTime)
		end

		if self:_HandleDefendingIfNeeded(p_DeltaTime) then
			-- Standing / moving aside on purpose. A running obstacle-sequence would stay frozen otherwise.
			self:_StopObstacleSequence()
			return -- DON'T DO ANYTHING ELSE.
		end
		if self:_ExecuteActionIfNeeded(s_Point, p_DeltaTime) then
			-- In a vehicle now: the point belongs to the foot path. Reaching it would switch to a linked foot path
			-- or overwrite the point on the vehicle path, and the vehicle can't leave a foot path any more.
			return
		end
		-- return if action executed
		if self._ActiveAction == BotActionFlags.OtherActionActive then
			self:_StopObstacleSequence()
			local s_Soldier = self.m_Player.soldier
			local s_SoldierPos = s_Soldier.worldTransform.trans
			local s_DifferenceY = s_Point.Position.z - s_SoldierPos.z
			local s_DifferenceX = s_Point.Position.x - s_SoldierPos.x
			local s_DistanceFromTargetSquared = s_DifferenceX ^ 2 + s_DifferenceY ^ 2

			if s_Point.Data and s_Point.Data.Action and s_Point.Data.Action.type == 'mcom' and s_DistanceFromTargetSquared < (1.7 * 1.7) then
				if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
					s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
				end
			else
				if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
					s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				end
			end

			if s_DistanceFromTargetSquared > (0.3 * 0.3) then
				self:_SetInput(EntryInputActionEnum.EIAThrottle, 1)
			end
			return -- DON'T DO ANYTHING ELSE.
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			self._WayWaitTimer = 0.0
			self.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			self:_ApplyReactionAction(p_DeltaTime)

			if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement then
				self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
			end

			-- Sidewards movement.
			self:_HandleSidwardsMovement(p_DeltaTime)

			-- Use parachute if needed.
			-- Every access of an engine object allocates. Read soldier and position once.
			local s_Soldier = self.m_Player.soldier
			local s_SoldierPos = s_Soldier.worldTransform.trans
			local s_Velocity = PhysicsEntity(s_Soldier).velocity
			local s_VelocityFalling = s_Velocity.y
			if s_VelocityFalling < -25.0 then
				self:_SetInput(EntryInputActionEnum.EIAToggleParachute, 1)
			end

			local s_DifferenceY = s_Point.Position.z - s_SoldierPos.z
			local s_DifferenceX = s_Point.Position.x - s_SoldierPos.x
			local s_DistanceFromTargetSquared = s_DifferenceX ^ 2 + s_DifferenceY ^ 2
			local s_HeightDistance = math.abs(s_Point.Position.y - s_SoldierPos.y)

			-- Hard reroute to the closest path when stuck for long (skipping nodes did not help).
			-- (See also Bot:TeleportToPath for bots on paths they can't leave.)
			-- Only a limited number of times: after that the stuck timer keeps running,
			-- so _ObstacleHandling kills the bot at 15 s.
			if self._StuckTimer > 6.0 and self._StuckRerouteCount < Registry.BOT.MAX_STUCK_REROUTES then
				if s_Soldier ~= nil then
					local s_Node = g_GameDirector:FindClosestPath(s_SoldierPos, false, true, nil)
					if s_Node ~= nil then
						self._PathIndex = s_Node.PathIndex
						self._CurrentWayPoint = s_Node.PointIndex

						-- Keep heading for the objective on the new path.
						if self._Objective ~= '' then
							local s_Direction = m_NodeCollection:ObjectiveDirection(s_Node, self._Objective, false)
							if s_Direction then
								self._InvertPathDirection = (s_Direction == 'Previous')
							end
						end
					end

					self._StuckRerouteCount = self._StuckRerouteCount + 1
					self:CenterPathOffset(4.0)
					self._StuckTimer = 0.0
					self._ObstacleRetryCounter = 0
					self:_ResetObstacleSequence()
					self._LastWayDistance = 1000.0
					return
				end
			end

			self._TargetPoint = s_Point
			self._NextTargetPoint = s_NextPoint

			-- do the obstacle-handling
			local s_Result = self:_ObstacleHandling(s_Velocity, s_DistanceFromTargetSquared, s_HeightDistance, p_DeltaTime, s_SoldierPos)
			if s_Result == nil then
				s_Soldier:Kill()
				m_Logger:Write(self.m_Player.name .. ' got stuck. Kill')
				return
			else
				if s_Result[1] == true then
					s_DistanceFromTargetSquared = 0
					s_HeightDistance = 0
					if s_Result[2] ~= 0 then
						s_NoStuckReset = true
						s_PointIncrement = s_Result[2]
					end
				end
			end

			self:_JumpDetection(s_Point, s_ActivePointIndex)

			-- Target-Reached handling
			if self:_IsTargetDistanceReached(s_DistanceFromTargetSquared, s_HeightDistance) then
				if not s_NoStuckReset then
					self._StuckTimer = 0.0
					self._StuckRerouteCount = 0
				end

				if s_PointIncrement > 0 then
					for i = 1, s_PointIncrement do
						if i > 1 then
							if self._InvertPathDirection then
								s_Point = m_NodeCollection:Get(self:_GetWayIndex(-i), self._PathIndex)
							else
								s_Point = m_NodeCollection:Get(self:_GetWayIndex(i), self._PathIndex)
							end
							if s_Point == nil then
								break
							end
						end
						if s_Point.Index ~= self._LastActionId and self:_CheckForAction(s_Point) then
							self._CurrentWayPoint = s_Point.PointIndex
							return -- DON'T DO ANYTHING ELSE ANY MORE.
						end

						if self:_CheckForZoneEntry(s_Point) then
							self._CurrentWayPoint = s_Point.PointIndex
							return
						end

						self:_CheckAndDoPathSwitch(s_Point)
						if self._OnSwitch then
							self._ObstacleSequenceTimer = 0
							self._ObstacleRetryCounter = 0
							self._LastActionId = -1
							self:_ResetActionFlag(BotActionFlags.MeleeActive)
							self._LastWayDistance = 1000.0
							return
						end
					end
				end

				if self._InvertPathDirection then
					self._CurrentWayPoint = s_ActivePointIndex - s_PointIncrement
				else
					self._CurrentWayPoint = s_ActivePointIndex + s_PointIncrement
				end

				self._ObstacleRetryCounter = 0
				self:_ResetObstacleSequence()
				self._LastWayDistance = 1000.0

				-- Head for the next point right away. Otherwise the fast target-update steers back to the reached
				-- point until the next movement-update.
				if s_PointIncrement == 1 and s_NextPoint ~= nil then
					self._TargetPoint = s_NextPoint
					self._NextTargetPoint = nil
				end
			end
		else -- Wait mode.
			self._WayWaitTimer = self._WayWaitTimer + p_DeltaTime
			self:_StopObstacleSequence()

			self:LookAround(p_DeltaTime)

			if self._WayWaitTimer > s_Point.OptValue then
				self._WayWaitTimer = 0.0

				if self._InvertPathDirection then
					self._CurrentWayPoint = s_ActivePointIndex - 1
				else
					self._CurrentWayPoint = s_ActivePointIndex + 1
				end
			end
		end
	else -- following movement
		local s_Point = nil
		local s_NextPoint = nil
		local s_NextToNextPoint = nil
		local s_PointIncrement = 1
		local s_NoStuckReset = false

		if self._FollowTargetPlayer and self._FollowTargetPlayer.soldier then
			local s_TracePlayer = self._FollowTargetPlayer
			self._FollowingTraceTimer = self._FollowingTraceTimer + p_DeltaTime
			local s_PlayerPos = s_TracePlayer.soldier.worldTransform.trans:Clone()
			if self._FollowingTraceTimer > Config.TraceDelta then
				if #self._FollowWayPoints == 0 or self._FollowWayPoints[#self._FollowWayPoints].Position:Distance(s_PlayerPos) > 0.2 then
					self._FollowingTraceTimer = 0.0
					local s_SpeedInput = math.abs(s_TracePlayer.input:GetLevel(EntryInputActionEnum.EIAThrottle))
					local s_Speed = BotMoveSpeeds.Normal
					if s_SpeedInput > 0 then
						if s_TracePlayer.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
							s_Speed = BotMoveSpeeds.Sprint
						end
					elseif s_SpeedInput == 0 then
						s_Speed = BotMoveSpeeds.SlowCrouch
					end

					self._FollowWayPoints[#self._FollowWayPoints + 1] = {
						SpeedMode = s_Speed,
						Position = s_PlayerPos:Clone(),
					}

					local s_IndexToRemoveTo = 0
					local s_NumberOfNodes = #self._FollowWayPoints
					for l_Index = s_NumberOfNodes - 1, 1, -1 do
						local l_Node = self._FollowWayPoints[l_Index]
						if s_PlayerPos:Distance(l_Node.Position) < 0.5 then
							s_IndexToRemoveTo = l_Index
						end
					end

					if s_IndexToRemoveTo > 0 then
						for _ = 1, s_IndexToRemoveTo do
							table.remove(self._FollowWayPoints, 1)
						end
					end
				end
			end
			local s_NodeCount = #self._FollowWayPoints
			if s_NodeCount > 1 then
				s_Point = self._FollowWayPoints[1]
				s_NextPoint = self._FollowWayPoints[2]
				if s_NodeCount > 2 then
					s_NextToNextPoint = self._FollowWayPoints[3]
				end
			else
				-- just wait
				s_Point = {
					SpeedMode = BotMoveSpeeds.NoMovement,
					OptValue = 0x128,
					Position = s_PlayerPos:Clone(),
				}
			end
		else
			self._FollowTargetPlayer = nil
			self._FollowWayPoints = {}

			local s_Node = g_GameDirector:FindClosestPath(self.m_Player.soldier.worldTransform.trans:Clone(), false, true, nil)
			if s_Node ~= nil then
				self._InvertPathDirection = false
				self._PathIndex = s_Node.PathIndex
				self._CurrentWayPoint = s_Node.PointIndex
			end
			return
		end

		if Registry.BOT.USE_PATH_OFFSETS and s_Point and s_NextPoint and s_NextToNextPoint then
			s_Point, s_NextPoint = self:ApplyPathOffset(s_Point, s_NextPoint, s_NextToNextPoint, p_DeltaTime)
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			self._WayWaitTimer = 0.0
			self.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			self:_ApplyReactionAction(p_DeltaTime)

			if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement then
				self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
			end

			-- Sidewards movement.
			self:_HandleSidwardsMovement(p_DeltaTime)

			-- Use parachute if needed.
			-- Every access of an engine object allocates. Read soldier and position once.
			local s_Soldier = self.m_Player.soldier
			local s_SoldierPos = s_Soldier.worldTransform.trans
			local s_Velocity = PhysicsEntity(s_Soldier).velocity
			local s_VelocityFalling = s_Velocity.y
			if s_VelocityFalling < -25.0 then
				self:_SetInput(EntryInputActionEnum.EIAToggleParachute, 1)
			end

			local s_DifferenceY = s_Point.Position.z - s_SoldierPos.z
			local s_DifferenceX = s_Point.Position.x - s_SoldierPos.x
			local s_DistanceFromTargetSquared = s_DifferenceX ^ 2 + s_DifferenceY ^ 2
			local s_HeightDistance = math.abs(s_Point.Position.y - s_SoldierPos.y)

			self._TargetPoint = s_Point
			self._NextTargetPoint = s_NextPoint

			local s_Result = self:_ObstacleHandling(s_Velocity, 0, s_HeightDistance, p_DeltaTime, s_SoldierPos)
			if s_Result == nil then
				self._StuckTimer = 0.0
				return
			else
				if s_Result[1] == true then
					s_DistanceFromTargetSquared = 0
					s_HeightDistance = 0
					if s_Result[2] ~= 0 then
						s_NoStuckReset = true
						s_PointIncrement = s_Result[2]
					end
				end
			end

			if self:_IsTargetDistanceReached(s_DistanceFromTargetSquared, s_HeightDistance) then
				if not s_NoStuckReset then
					self._StuckTimer = 0.0
					self._StuckRerouteCount = 0
				end

				self._OnSwitch = false

				for _ = 1, math.abs(s_PointIncrement) do
					if #self._FollowWayPoints > 1 then
						table.remove(self._FollowWayPoints, 1)
					end
				end

				self._ObstacleRetryCounter = 0
				self:_ResetObstacleSequence()
				self._LastWayDistance = 1000.0

				if s_PointIncrement == 1 and s_NextPoint ~= nil then
					self._TargetPoint = s_NextPoint
					self._NextTargetPoint = nil
				end
			end
		else
			self:LookAround(p_DeltaTime)
		end
	end
end

---@param p_DeltaTime number
function Bot:UpdateMovementSprintToTarget(p_DeltaTime)
	self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Run to target.

	if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
		self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
	end

	local s_Jump = true

	if self._ShootPlayer ~= nil and self._ShootPlayer.corpse ~= nil then
		if self.m_Player.soldier.worldTransform.trans:Distance(self._ShootPlayer.corpse.worldTransform.trans) < 2 then
			self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			s_Jump = false
		end
	end

	-- To-do: obstacle detection.
	if s_Jump == true then
		self._AttackModeMoveTimer = self._AttackModeMoveTimer + p_DeltaTime

		if self._AttackModeMoveTimer > 3.0 then
			self._AttackModeMoveTimer = 0.0
		elseif self._AttackModeMoveTimer > 2.5 then
			self:_SetInput(EntryInputActionEnum.EIAJump, 1)
			self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
		end
	end
end

---@param p_DeltaTime number
function Bot:UpdateShootMovement(p_DeltaTime)
	self._DefendTimer = 0.0
	-- Shoot MoveMode.
	if self._AttackMode == BotAttackModes.RandomNotSet then
		if Config.BotAttackMode ~= BotAttackModes.RandomNotSet then
			self._AttackMode = Config.BotAttackMode
		else -- Random.
			if MathUtils:GetRandomInt(0, 1) == 1 then
				self._AttackMode = BotAttackModes.Stand
			else
				self._AttackMode = BotAttackModes.Crouch
			end
		end
	end

	if (self.m_ActiveWeapon and (self.m_ActiveWeapon.type == WeaponTypes.Sniper or
				self.m_ActiveWeapon.type == WeaponTypes.MissileAir or
				self.m_ActiveWeapon.type == WeaponTypes.MissileLand or not self._MoveWhileShooting) and
			not self.m_KnifeMode) then -- Don't move while shooting some weapons.
		local s_Soldier = self.m_Player.soldier
		if self._AttackMode == BotAttackModes.Crouch then
			if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		else
			if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		end

		self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	else
		local s_TargetTime = 5.0
		local s_TargetCycles = math.floor(s_TargetTime / Registry.BOT.TRACE_DELTA_SHOOTING)

		if self.m_KnifeMode then                  -- Knife Only Mode.
			s_TargetCycles = 1
			self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Run towards player.
		else
			if self._AttackMode == BotAttackModes.Crouch then
				self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			else
				self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
			end
		end

		if Config.OverWriteBotAttackMode ~= BotMoveSpeeds.NoMovement then
			self.m_ActiveSpeedValue = Config.OverWriteBotAttackMode
		end

		if #self._ShootWayPoints > s_TargetCycles and Config.JumpWhileShooting then
			local s_DistanceDone = self._ShootWayPoints[#self._ShootWayPoints].Position:Distance(self._ShootWayPoints[
			#self._ShootWayPoints - s_TargetCycles].Position)
			if s_DistanceDone < 0.5 and self._DistanceToPlayer > 1.0 then -- No movement was possible. Try to jump over an obstacle.
				table.remove(self._ShootWayPoints)
				self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
				self:_SetInput(EntryInputActionEnum.EIAJump, 1)
				self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
			end
		end

		-- Do some sidewards movement from time to time.
		local movementIntensity = Config.SpeedFactorAttack

		-- wrap timer every 15 s (keeps the old behaviour)
		if self._AttackModeMoveTimer >= 15.0 then
			self._AttackModeMoveTimer = self._AttackModeMoveTimer - 15.0
		end

		-- which 2.5-second sub-cycle are we in?  (0-2.499, 2.5-4.999 …)
		local cycle  = self._AttackModeMoveTimer % 2.5
		local inMove = (cycle <= 1.0) -- we move for the first 1 s

		-- store the direction for the whole 1-second window
		if self._MoveDirection == nil then
			self._MoveDirection = 1 -- init once
		end

		-- entering a new 1-second window?  pick a new random direction
		local justEntered = (cycle - p_DeltaTime <= 0.0)
		if justEntered then
			self._MoveDirection = (math.random() < 0.5) and 1 or -1
		end

		-- apply movement
		if inMove then
			self:_SetInput(EntryInputActionEnum.EIAStrafe,
				self._MoveDirection * movementIntensity)
		end
		self._AttackModeMoveTimer = self._AttackModeMoveTimer + p_DeltaTime
	end
end

---Rush: whether the attacker keeps going to its MCOM while shooting: by chance (decided now and then in StateAttacking),
---and always close to the MCOM unless the enemy is close as well.
---@return boolean
function Bot:ShouldPushWhileShooting()
	if not Globals.IsRush or self.m_Player.teamId ~= TeamId.Team1 or self.m_KnifeMode or self.m_Player.soldier == nil
		or self._Objective:lower():sub(1, 4) ~= 'mcom' then
		return false
	end
	local s_Weapon = self.m_ActiveWeapon
	if s_Weapon == nil or s_Weapon.type == WeaponTypes.Sniper or s_Weapon.type == WeaponTypes.MissileAir or
		s_Weapon.type == WeaponTypes.MissileLand then
		return false
	end
	if self._PushWhileShooting then
		return true
	end
	return self._DistanceToPlayer > Registry.BOT.RUSH_PUSH_MIN_ENEMY_DISTANCE and
		g_GameDirector:_GetDistanceFromObjective(self._Objective, self.m_Player.soldier.worldTransform.trans) <
		Registry.BOT.RUSH_PUSH_OBJECTIVE_DISTANCE
end

---While shooting: on along the path or the mesh (as Bot:UpdateNormalMovement), aiming at the enemy. Walks towards the
---next target with throttle and strafe, relative to where the bot aims.
---@param p_DeltaTime number
function Bot:UpdatePushMovement(p_DeltaTime)
	-- The bot stays on its way: no way back to it after the fight (only after shooting without pushing).
	if self._Pushing then
		self._ShootWayPoints = {}
	end
	-- The normal movement turns the bot to the target (looking around in a zone, obstacles): it aims at the enemy.
	local s_Yaw = self._TargetYaw
	local s_Pitch = self._TargetPitch
	self:UpdateNormalMovement(p_DeltaTime)
	self._TargetYaw = s_Yaw
	self._TargetPitch = s_Pitch

	local s_Soldier = self.m_Player.soldier
	local s_Target = self._TargetPoint
	self:_SetInput(EntryInputActionEnum.EIASprint, 0)
	if s_Soldier == nil or s_Target == nil or self.m_ActiveSpeedValue == BotMoveSpeeds.NoMovement or
		self._ActiveAction == BotActionFlags.OtherActionActive then
		self:_SetInput(EntryInputActionEnum.EIAThrottle, 0)
		self:_SetInput(EntryInputActionEnum.EIAStrafe, 0)
		return
	end

	local s_Pose = CharacterPoseType.CharacterPoseType_Stand
	if self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch or self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
		s_Pose = CharacterPoseType.CharacterPoseType_Crouch
	end
	if s_Soldier.pose ~= s_Pose then
		s_Soldier:SetPose(s_Pose, true, true)
	end

	-- Yaw grows clockwise (seen from above), strafe is positive to the right.
	local s_Position = s_Soldier.worldTransform.trans
	local s_Atan = math.atan(s_Target.Position.z - s_Position.z, s_Target.Position.x - s_Position.x)
	local s_MoveYaw = (s_Atan > math.pi / 2) and (s_Atan - math.pi / 2) or (s_Atan + 3 * math.pi / 2)
	local s_Delta = s_MoveYaw - self.m_Input.authoritativeAimingYaw
	local s_Speed = Config.SpeedFactor * Config.SpeedFactorAttack
	self:_SetInput(EntryInputActionEnum.EIAThrottle, math.cos(s_Delta) * s_Speed)
	self:_SetInput(EntryInputActionEnum.EIAStrafe, math.sin(s_Delta) * s_Speed)
end

function Bot:UpdateSpeedOfMovement(p_InAttackMode)
	-- Additional movement.
	local s_Soldier = self.m_Player.soldier
	if s_Soldier == nil then
		return
	end

	if self._ActiveAction == BotActionFlags.OtherActionActive then
		return
	end

	local s_SpeedVal = 0
	local s_StopForShooting = p_InAttackMode and not self._MoveWhileShooting

	if self.m_ActiveMoveMode ~= BotMoveModes.Standstill and not s_StopForShooting then
		if self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
			s_SpeedVal = 1.0

			if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
			end
		elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
			s_SpeedVal = 1.0

			if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Slow then
			s_SpeedVal = 0.7

			if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		elseif self.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
			s_SpeedVal = 1.0

			if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		end
	end

	-- Do not reduce speed if sprinting.
	if s_SpeedVal > 0 and self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil and
		self.m_ActiveSpeedValue <= BotMoveSpeeds.Normal then
		s_SpeedVal = s_SpeedVal * Config.SpeedFactorAttack
	end

	-- Movement speed.
	if self.m_ActiveSpeedValue ~= BotMoveSpeeds.Sprint then
		self:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal * Config.SpeedFactor)
	else
		self:_SetInput(EntryInputActionEnum.EIAThrottle, 1)
		self:_SetInput(EntryInputActionEnum.EIASprint, s_SpeedVal * Config.SpeedFactor)
	end
end

function Bot:UpdateTargetMovement()
	local s_Soldier = self._TargetPoint and self.m_Player.soldier
	if s_Soldier then
		local s_SoldierPos = s_Soldier.worldTransform.trans
		local s_Distance = s_SoldierPos:Distance(self._TargetPoint.Position)

		local s_NextTargetPoint = self._NextTargetPoint
		if s_NextTargetPoint then
			local s_Skip = s_Distance < 0.2

			-- Skip the node, if it was passed: the distance grows and the bot is already beyond the node, seen in the
			-- direction of the next node. The distance alone also grows while turning or strafing far from the node.
			if not s_Skip and s_Distance > (self._LastWayDistance + 0.001) and self._ObstacleSequenceTimer == 0 then
				local s_TargetPos = self._TargetPoint.Position
				local s_NextPos = s_NextTargetPoint.Position
				s_Skip = (s_SoldierPos.x - s_TargetPos.x) * (s_NextPos.x - s_TargetPos.x) +
					(s_SoldierPos.z - s_TargetPos.z) * (s_NextPos.z - s_TargetPos.z) > 0
			end

			if s_Skip then
				self._TargetPoint = s_NextTargetPoint
				-- Only one skip per movement-update. It sets the following node.
				self._NextTargetPoint = nil
				self._LastWayDistance = 1024 -- value to signal skip of one node
			else
				self._LastWayDistance = s_Distance
			end
		end

		local s_TargetPos = self._TargetPoint.Position
		local s_DifferenceY = s_TargetPos.z - s_SoldierPos.z
		local s_DifferenceX = s_TargetPos.x - s_SoldierPos.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		self._TargetYaw = s_Yaw
		self._TargetYaw = self._TargetYaw + self.m_YawOffset
	end
end

---@param p_DeltaTime number
function Bot:LookAround(p_DeltaTime)
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self._TargetPoint = nil

	-- A new look-around phase: scan around the direction the bot was facing when it stopped.
	local s_Now = m_Utilities:GetTime()

	if s_Now - self._LookAroundLastTime > 0.5 then
		self._LookAroundBaseYaw = self._TargetYaw
		self._LookAroundYawOffset = 0.0
		self._LookAroundYawGoal = 0.0
		self._LookAroundPitchGoal = 0.0
		self._VehicleLookAroundTimer = MathUtils:GetRandom(0.3, 1.2) -- short settle before the first glance
	end

	self._LookAroundLastTime = s_Now

	self:UpdateLookAroundGlance(p_DeltaTime, 2.2, 0.15)

	local s_Yaw = self._LookAroundBaseYaw + self._LookAroundYawOffset

	if s_Yaw < 0.0 then
		s_Yaw = s_Yaw + (2 * math.pi)
	elseif s_Yaw >= (2 * math.pi) then
		s_Yaw = s_Yaw - (2 * math.pi)
	end

	self._TargetYaw = s_Yaw
	self._TargetPitch = self._LookAroundPitch
end

function Bot:UpdateYaw()
	-- Runs every tick for every bot: use the stored input, every access of player.input allocates.
	local s_Input = self.m_Input
	---@cast s_Input -nil
	local s_CurrentYaw = s_Input.authoritativeAimingYaw
	local s_TargetYaw = self._TargetYaw
	local s_DeltaYaw = s_CurrentYaw - s_TargetYaw

	if s_DeltaYaw > math.pi then
		s_DeltaYaw = s_DeltaYaw - 2 * math.pi
	elseif s_DeltaYaw < -math.pi then
		s_DeltaYaw = s_DeltaYaw + 2 * math.pi
	end

	local s_Increment = Globals.YawPerFrame

	-- Pitch turns with the same max speed as yaw, humans don't snap vertically either.
	local s_TargetPitch = self._TargetPitch
	local s_DeltaPitch = s_TargetPitch - s_Input.authoritativeAimingPitch

	if s_DeltaPitch > s_Increment then
		s_TargetPitch = s_Input.authoritativeAimingPitch + s_Increment
	elseif s_DeltaPitch < -s_Increment then
		s_TargetPitch = s_Input.authoritativeAimingPitch - s_Increment
	end

	s_Input.authoritativeAimingPitch = s_TargetPitch

	if math.abs(s_DeltaYaw) < s_Increment then
		s_Input.authoritativeAimingYaw = s_TargetYaw
		return
	end

	if s_DeltaYaw > 0 then
		s_Increment = -s_Increment
	end

	local s_TempYaw = s_CurrentYaw + s_Increment

	if s_TempYaw >= (math.pi * 2) then
		s_TempYaw = s_TempYaw - (math.pi * 2)
	elseif s_TempYaw < 0.0 then
		s_TempYaw = s_TempYaw + (math.pi * 2)
	end

	s_Input.authoritativeAimingYaw = s_TempYaw
end

function Bot:UpdateStaticMovement()
	-- Mimicking.
	if self.m_ActiveMoveMode == BotMoveModes.Mimic and self._TargetPlayer ~= nil then
		---@type EntryInputActionEnum|integer
		for i = 0, 36 do
			self:_SetInput(i, self._TargetPlayer.input:GetLevel(i))
		end

		self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw
		self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch

		-- Mirroring.
	elseif self.m_ActiveMoveMode == BotMoveModes.Mirror and self._TargetPlayer ~= nil then
		---@type EntryInputActionEnum|integer
		for i = 0, 36 do
			self:_SetInput(i, self._TargetPlayer.input:GetLevel(i))
		end

		self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw +
			(
				(self._TargetPlayer.input.authoritativeAimingYaw > math.pi) and
				-math.pi or
				math.pi
			)
		self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch
	end
end
