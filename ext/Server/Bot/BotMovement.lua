---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')

local flags = RayCastFlags.DontCheckWater |
	RayCastFlags.DontCheckCharacter |
	RayCastFlags.DontCheckRagdoll |
	RayCastFlags.CheckDetailMesh

-- >>> SMART PATH OFFSET (with zig-zag and stairs fixes)
function Bot:ApplyPathOffset(p_OriginalPoint, p_NextPoint, p_NextToNextPoint)
	-- PRIORITY 1: Recovery mode - disable offset
	if self.m_PathSide ~= 0 and self.m_OffsetRecoveryNodes and self.m_OffsetRecoveryNodes > 0 then
		self.m_OffsetRecoveryNodes = self.m_OffsetRecoveryNodes - 1
		-- if self.m_OffsetRecoveryNodes == 0 then - Stay on one side of one path
		-- 	self.m_PathSide = math.random(-1, 1)
		-- end
		return p_OriginalPoint, p_NextPoint
	end

	-- PRIORITY 2: Validate inputs
	if not p_OriginalPoint or not p_NextPoint or not p_NextToNextPoint or
		(p_OriginalPoint.Data and p_OriginalPoint.Data.Action) or
		(p_OriginalPoint.Data and p_OriginalPoint.Data.Links) then
		return p_OriginalPoint, p_NextPoint
	end

	-- No offset on subobjectives
	if Globals.IsRush and self._Objective ~= "" and g_GameDirector:IsOnSubobjectivePath(self._PathIndex, self._Objective) then
		return p_OriginalPoint, p_NextPoint
	end

	-- Initialize side once per path
	if not self.m_PathSide or self.m_LastPathIndex ~= self._PathIndex then
		self.m_PathSide = math.random(-1, 1)          -- -1 left, 0 center, 1 right
		self.m_LastPathIndex = self._PathIndex
		self.m_OffsetDistance = 0.8 + (math.random() * 0.4) -- 0.8-1.2m
		self.m_LastStuckCheck = 0
		self.m_ForceCenter = false
	end

	-- Emergency fallback
	if self._ObstacleSequenceTimer ~= 0 and self.m_PathSide ~= 0 then
		self.m_ForceCenter = true
		self.m_OffsetRecoveryNodes = 15
		return p_OriginalPoint, p_NextPoint
	end
	if self.m_ForceCenter and self._ObstacleSequenceTimer == 0 then
		self.m_ForceCenter = false
	end
	if self.m_PathSide == 0 or self.m_ForceCenter then
		return p_OriginalPoint, p_NextPoint
	end

	-- Calculate delta and direction for Node
	local delta = p_NextPoint.Position - p_OriginalPoint.Position
	local length2D = math.sqrt(delta.x * delta.x + delta.z * delta.z)
	if length2D < 0.01 then
		return p_OriginalPoint, p_NextPoint
	end

	local dir = Vec3(delta.x / length2D, 0, delta.z / length2D)
	local right = Vec3(dir.z, 0, -dir.x)

	-- Calculate delta and direction for NextNode
	local deltaNext = p_NextPoint.Position - p_OriginalPoint.Position
	local length2DNext = math.sqrt(deltaNext.x * deltaNext.x + deltaNext.z * deltaNext.z)
	if length2DNext < 0.01 then
		return p_OriginalPoint, p_NextPoint
	end

	local dirNext = Vec3(deltaNext.x / length2DNext, 0, deltaNext.z / length2DNext)
	local rightNext = Vec3(dirNext.z, 0, -dirNext.x)



	-- >>> FIX 2: stairs/passages vertical → center
	local verticalDelta = math.abs(p_NextPoint.Position.y - p_OriginalPoint.Position.y)
	if verticalDelta > 0.35 then
		self.m_OffsetRecoveryNodes = 15 -- force center for 10 cycles
		return p_OriginalPoint, p_NextPoint
	end

	-- Calculate offset position
	local offsetPosition = p_OriginalPoint.Position + right * (self.m_PathSide * self.m_OffsetDistance)
	local offsetPositionNext = p_NextPoint.Position + rightNext * (self.m_PathSide * self.m_OffsetDistance)


	-- -- Wall-slide check
	-- local rayOrigin = p_OriginalPoint.Position + Vec3(0, 0.5, 0)
	-- local sideCheck = RaycastManager:CollisionRaycast(
	-- 	rayOrigin + Vec3(0, 0.5, 0),
	-- 	offsetPosition + Vec3(0, 0.5, 0) + right * (self.m_PathSide * 0.4),
	-- 	1, 0,
	-- 	flags
	-- )
	-- if #sideCheck > 0 and sideCheck[1].position then
	-- 	-- local comfortableDistance = sideCheck[1].position:Distance(rayOrigin) - 0.4
	-- 	-- offsetPosition = p_OriginalPoint.Position + right * (self.m_PathSide * comfortableDistance)
	-- 	-- offsetPositionNext = p_NextPoint.Position + right * (self.m_PathSide * comfortableDistance)

	-- 	self.m_OffsetRecoveryNodes = 5 -- force center for 3 nodes
	-- 	return p_OriginalPoint, p_NextPoint
	-- end

	return {
			Position = offsetPosition,
			SpeedMode = p_OriginalPoint.SpeedMode,
			ExtraMode = p_OriginalPoint.ExtraMode,
			OptValue = p_OriginalPoint.OptValue,
			Data = p_OriginalPoint.Data
		},
		{
			Position = offsetPositionNext,
			SpeedMode = p_NextPoint.SpeedMode,
			ExtraMode = p_NextPoint.ExtraMode,
			OptValue = p_NextPoint.OptValue,
			Data = p_NextPoint.Data
		}
end

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
							-- Switch to vehicle.
							p_Point = s_Node
							self._InvertPathDirection = false
							self._PathIndex = s_Node.PathIndex
							self._CurrentWayPoint = s_Node.PointIndex
							p_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(1), self._PathIndex)
							self._LastWayDistance = 1000.0
						end
					end
				end
				self:_ResetActionFlag(BotActionFlags.OtherActionActive)
			elseif p_Point.Data.Action.type == "beacon"
				and self.m_SecondaryGadget.type == WeaponTypes.Beacon
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
end

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

			-- TODO: look at target
			-- don't do anything else
			return
		elseif self._DefendTimer >= (s_TargetTime - 2) then
			self.m_ActiveSpeedValue = BotMoveSpeeds.Backwards
			local s_StrafeValue = 1.0
			if self.m_Id % 2 then
				s_StrafeValue = -1.0
			end
			self:_SetInput(EntryInputActionEnum.EIAStrafe, s_StrafeValue)
			return
		end
	else
		self._DefendTimer = 0.0
	end
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

function Bot:_ObstacleHandling(p_Velocity, p_DistanceSquared, p_HeightDistance, p_DeltaTime, p_PlayerPos)
	local s_SetTargetReached = false
	local s_IncrementNodes = 0

	if self._LastWayDistance == 1024 then
		s_SetTargetReached = true -- skip came from target-movement
		return { s_SetTargetReached, s_IncrementNodes }
	end

	-- handling on standstill
	if p_Velocity.magnitude < 0.3 or self._ObstacleSequenceTimer ~= 0 then -- use velocity instead of position
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
			self._ObstacleSequenceTimer = 0
			self._StuckTimer = 0.0
			self._ObstacleRetryCounter = 0
			self:_ResetActionFlag(BotActionFlags.MeleeActive)
			s_SetTargetReached = true
			return { s_SetTargetReached, s_IncrementNodes }
		end

		if self._ObstacleRetryCounter >= 2 then -- Try next waypoint.
			self._ObstacleRetryCounter = 0
			self:_ResetActionFlag(BotActionFlags.MeleeActive)
			s_SetTargetReached = true

			if Config.TeleportIfStuck and m_Utilities:CheckProbability(Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK) then
				local s_Transform = self.m_Player.soldier.worldTransform:Clone()
				s_Transform.trans = self._TargetPoint.Position
				s_Transform:LookAtTransform(self._TargetPoint.Position, self._NextTargetPoint.Position)
				self.m_Player.soldier:SetTransform(s_Transform)
				m_Logger:Write('teleported ' .. self.m_Player.name)
			else
				s_IncrementNodes = MathUtils:GetRandomInt(0, 4) -- Go up to 4 points further.
				if s_IncrementNodes == 0 then
					s_IncrementNodes = -2           -- Go backwards and try again.
				end

				if (Globals.IsConquest or Globals.IsRush) then
					if g_GameDirector:IsOnObjectivePath(self._PathIndex) then
						self._InvertPathDirection = m_Utilities:CheckProbability(Registry.BOT.PROBABILITY_CHANGE_DIRECTION_IF_STUCK)
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

---@param p_DeltaTime number
function Bot:UpdateNormalMovement(p_DeltaTime)
	-- Move along points.
	self._AttackModeMoveTimer = 0.0


	if self._FollowTargetPlayer == nil then -- default movement
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
			local s_ClosestDistance = self.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)
			local s_ClosestNode = s_ActivePointIndex
			for i = 1, Registry.BOT.NUMBER_NODES_TO_SCAN_AFTER_ATTACK, 2 do
				s_Point = m_NodeCollection:Get(s_ActivePointIndex - i, self._PathIndex)
				if s_Point and self.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position) < s_ClosestDistance then
					s_ClosestNode = s_ActivePointIndex - i
				end
				s_Point = m_NodeCollection:Get(s_ActivePointIndex + i, self._PathIndex)
				if s_Point and self.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position) < s_ClosestDistance then
					s_ClosestNode = s_ActivePointIndex + i
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
			s_Point, s_NextPoint = self:ApplyPathOffset(s_Point, s_NextPoint, s_NextToNextPoint)
		end

		self:_HandleDefendingIfNeeded(p_DeltaTime)
		self:_ExecuteActionIfNeeded(s_Point, p_DeltaTime)
		-- return if action executed
		if self._ActiveAction == BotActionFlags.OtherActionActive then
			local s_DifferenceY = s_Point.Position.z - self.m_Player.soldier.worldTransform.trans.z
			local s_DifferenceX = s_Point.Position.x - self.m_Player.soldier.worldTransform.trans.x
			local s_DistanceFromTargetSquared = s_DifferenceX ^ 2 + s_DifferenceY ^ 2

			if s_Point.Data and s_Point.Data.Action and s_Point.Data.Action.type == 'mcom' and s_DistanceFromTargetSquared < (1.7 * 1.7) then
				if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
					self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
				end
			else
				if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
					self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				end
			end

			if s_DistanceFromTargetSquared > (0.3 * 0.3) then
				self:_SetInput(EntryInputActionEnum.EIAThrottle, 1)
			end
			return -- DON'T DO ANYTHING ELSE.
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			self._WayWaitTimer = 0.0
			self._WayWaitYawTimer = 0.0
			self.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			self:_ApplyReactionAction(p_DeltaTime)

			if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement then
				self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
			end

			-- Sidewards movement.
			self:_HandleSidwardsMovement(p_DeltaTime)

			-- Use parachute if needed.
			local s_Velocity = PhysicsEntity(self.m_Player.soldier).velocity
			local s_VelocityFalling = s_Velocity.y
			if s_VelocityFalling < -25.0 then
				self:_SetInput(EntryInputActionEnum.EIAToggleParachute, 1)
			end

			local s_DifferenceY = s_Point.Position.z - self.m_Player.soldier.worldTransform.trans.z
			local s_DifferenceX = s_Point.Position.x - self.m_Player.soldier.worldTransform.trans.x
			local s_DistanceFromTargetSquared = s_DifferenceX ^ 2 + s_DifferenceY ^ 2
			local s_HeightDistance = math.abs(s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y)

			-- Detect obstacle and move over or around.

			-- >>> OFFSET-AWARE STUCK RECOVERY (improved)
			-- >>> PATCH: Hard reroute when stuck
			if self._StuckTimer > 6.0 then
				local soldier = self.m_Player.soldier
				if soldier ~= nil then
					local s_Node = g_GameDirector:FindClosestPath(soldier.worldTransform.trans, false, true, nil)
					if s_Node ~= nil then
						self._InvertPathDirection = false
						self._PathIndex = s_Node.PathIndex
						self._CurrentWayPoint = s_Node.PointIndex
					end

					self.m_OffsetRecoveryNodes = 25 -- lock center for a while
					self._StuckTimer = 0.0
					return
				end
			end
			-- >>> END OFFSET RECOVERY

			self._TargetPoint = s_Point
			self._NextTargetPoint = s_NextPoint

			-- do the obstacle-handling
			local s_Result = self:_ObstacleHandling(s_Velocity, s_DistanceFromTargetSquared, s_HeightDistance, p_DeltaTime, self.m_Player.soldier.worldTransform.trans)
			if s_Result == nil then
				self.m_Player.soldier:Kill()
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

				self._StuckTimer = 0.0
				self._ObstacleRetryCounter = 0
				self:_ResetActionFlag(BotActionFlags.MeleeActive)
				self._LastWayDistance = 1000.0
			end
		else -- Wait mode.
			self._WayWaitTimer = self._WayWaitTimer + p_DeltaTime

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
			local s_PlayerPos = s_TracePlayer.soldier.worldTransform.trans
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
						for l_Rounds = 1, s_IndexToRemoveTo do
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

			local s_Node = g_GameDirector:FindClosestPath(self.m_Player.soldier.worldTransform.trans, false, true, nil)
			if s_Node ~= nil then
				self._InvertPathDirection = false
				self._PathIndex = s_Node.PathIndex
				self._CurrentWayPoint = s_Node.PointIndex
			end
			return
		end

		if Registry.BOT.USE_PATH_OFFSETS and s_Point and s_NextPoint and s_NextToNextPoint then
			s_Point, s_NextPoint = self:ApplyPathOffset(s_Point, s_NextPoint, s_NextToNextPoint)
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			self._WayWaitTimer = 0.0
			self._WayWaitYawTimer = 0.0
			self.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			self:_ApplyReactionAction(p_DeltaTime)

			if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement then
				self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
			end

			-- Sidewards movement.
			self:_HandleSidwardsMovement(p_DeltaTime)

			-- Use parachute if needed.
			local s_Velocity = PhysicsEntity(self.m_Player.soldier).velocity
			local s_VelocityFalling = s_Velocity.y
			if s_VelocityFalling < -25.0 then
				self:_SetInput(EntryInputActionEnum.EIAToggleParachute, 1)
			end

			local s_DifferenceY = s_Point.Position.z - self.m_Player.soldier.worldTransform.trans.z
			local s_DifferenceX = s_Point.Position.x - self.m_Player.soldier.worldTransform.trans.x
			local s_DistanceFromTargetSquared = s_DifferenceX ^ 2 + s_DifferenceY ^ 2
			local s_HeightDistance = math.abs(s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y)

			self._TargetPoint = s_Point
			self._NextTargetPoint = s_NextPoint

			local s_Result = self:_ObstacleHandling(s_Velocity, 0, s_HeightDistance, p_DeltaTime, self.m_Player.soldier.worldTransform.trans)
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
				end

				self._OnSwitch = false

				for l_Runs = 1, math.abs(s_PointIncrement) do
					if #self._FollowWayPoints > 1 then
						table.remove(self._FollowWayPoints, 1)
					end
				end

				self._ObstacleSequenceTimer = 0
				self._ObstacleRetryCounter = 0
				self:_ResetActionFlag(BotActionFlags.MeleeActive)
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
		if self._AttackMode == BotAttackModes.Crouch then
			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		else
			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
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

function Bot:UpdateSpeedOfMovement(p_InAttackMode)
	-- Additional movement.
	if self.m_Player.soldier == nil then
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

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
			end
		elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
			s_SpeedVal = 1.0

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Slow then
			s_SpeedVal = 0.7

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		elseif self.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
			s_SpeedVal = 1.0

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
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
	if self._TargetPoint and self.m_Player.soldier then
		local s_Distance = self.m_Player.soldier.worldTransform.trans:Distance(self._TargetPoint.Position)

		if self._NextTargetPoint then
			if s_Distance < 0.2 then
				self._TargetPoint = self._NextTargetPoint
				self._LastWayDistance = 1024 -- value to signal skip of one node
			else
				-- skip node, if node was passed
				if s_Distance > (self._LastWayDistance + 0.001) and self._ObstacleSequenceTimer == 0 then
					self._TargetPoint = self._NextTargetPoint
					self._LastWayDistance = 1024 -- value to signal skip of one node
				else
					self._LastWayDistance = s_Distance
				end
			end
		end

		local s_DifferenceY = self._TargetPoint.Position.z - self.m_Player.soldier.worldTransform.trans.z
		local s_DifferenceX = self._TargetPoint.Position.x - self.m_Player.soldier.worldTransform.trans.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		self._TargetYaw = s_Yaw
		self._TargetYaw = self._TargetYaw + self.m_YawOffset
	end
end

---@param p_DeltaTime number
function Bot:LookAround(p_DeltaTime)
	-- Move around a little.
	local s_LastYawTimer = self._WayWaitYawTimer
	self._WayWaitYawTimer = self._WayWaitYawTimer + p_DeltaTime
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self._TargetPoint = nil
	self._TargetPitch = 0.0

	if self._WayWaitYawTimer > 8.0 then
		self._WayWaitYawTimer = 0.0 + MathUtils:GetRandom(0.0, 0.5)       -- randomize delay a bit
		self._TargetYaw = self._TargetYaw + 1.0 + MathUtils:GetRandom(0.0, 0.6) -- 60° rotation right.

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 5.5 and s_LastYawTimer < 5.5 then
		self._WayWaitYawTimer = self._WayWaitYawTimer + MathUtils:GetRandom(0.0, 1.0) -- randomize delay a bit
		self._TargetYaw = self._TargetYaw - 1.0 - MathUtils:GetRandom(0.0, 0.6) -- 60° rotation left.

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 4.0 and s_LastYawTimer < 4.0 then
		self._WayWaitYawTimer = self._WayWaitYawTimer + MathUtils:GetRandom(0.0, 0.5) -- randomize delay a bit
		self._TargetYaw = self._TargetYaw - 1.0 - MathUtils:GetRandom(0.0, 0.6) -- 60° rotation left.

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 1.5 and s_LastYawTimer < 1.5 then
		self._WayWaitYawTimer = self._WayWaitYawTimer + MathUtils:GetRandom(0.0, 0.5) -- randomize delay a bit
		self._TargetYaw = self._TargetYaw + 1.0 + MathUtils:GetRandom(0.0, 0.6) -- 60° rotation right.

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	end
end

function Bot:UpdateYaw()
	local s_DeltaYaw = 0
	s_DeltaYaw = self.m_Player.input.authoritativeAimingYaw - self._TargetYaw

	if s_DeltaYaw > math.pi then
		s_DeltaYaw = s_DeltaYaw - 2 * math.pi
	elseif s_DeltaYaw < -math.pi then
		s_DeltaYaw = s_DeltaYaw + 2 * math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_Increment = Globals.YawPerFrame

	if s_AbsDeltaYaw < s_Increment then
		self.m_Player.input.authoritativeAimingYaw = self._TargetYaw
		self.m_Player.input.authoritativeAimingPitch = self._TargetPitch
		return
	end

	if s_DeltaYaw > 0 then
		s_Increment = -s_Increment
	end

	local s_TempYaw = self.m_Player.input.authoritativeAimingYaw + s_Increment

	if s_TempYaw >= (math.pi * 2) then
		s_TempYaw = s_TempYaw - (math.pi * 2)
	elseif s_TempYaw < 0.0 then
		s_TempYaw = s_TempYaw + (math.pi * 2)
	end

	self.m_Player.input.authoritativeAimingYaw = s_TempYaw
	self.m_Player.input.authoritativeAimingPitch = self._TargetPitch
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
