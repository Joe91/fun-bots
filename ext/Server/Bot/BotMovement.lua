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
	if self.m_PathSide == 0 and self.m_OffsetRecoveryNodes and self.m_OffsetRecoveryNodes > 0 then
		self.m_OffsetRecoveryNodes = self.m_OffsetRecoveryNodes - 1
		if self.m_OffsetRecoveryNodes == 0 then
			self.m_PathSide = math.random(-1, 1)
		end
		return p_OriginalPoint, p_NextPoint
	end

	-- PRIORITY 2: Validate inputs
	if not p_OriginalPoint or not p_NextPoint or not p_NextToNextPoint or
		(p_OriginalPoint.Data and p_OriginalPoint.Data.Action) or
		(p_OriginalPoint.Data and p_OriginalPoint.Data.Links) then
		return p_OriginalPoint, p_NextPoint
	end

	-- Initialize side once per path
	if not self.m_PathSide or self.m_LastPathIndex ~= self._PathIndex then
		self.m_PathSide = math.random(-1, 1) -- -1 left, 0 center, 1 right
		self.m_LastPathIndex = self._PathIndex
		-- print('Bot ' .. self.m_Player.name .. ' path offset side: ' .. tostring(self.m_PathSide))
		self.m_OffsetDistance = 0.8 + (math.random() * 0.4) -- 0.8-1.2m
		self.m_LastStuckCheck = 0
		self.m_ForceCenter = false
	end

	-- Emergency fallback
	if self._ObstacleSequenceTimer ~= 0 and self.m_PathSide ~= 0 then
		self.m_ForceCenter = true
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
		self.m_OffsetRecoveryNodes = 5 -- force center for 5 nodes
		-- print("return - vertical")
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

---@param p_DeltaTime number
function Bot:UpdateNormalMovement(p_DeltaTime)
	-- Move along points.
	self._AttackModeMoveTimer = 0.0

	if m_NodeCollection:Get(1, self._PathIndex) ~= nil then -- Check for valid point.
		-- Get next point.
		local s_ActivePointIndex = self:_GetWayIndex(self._CurrentWayPoint)

		local s_Point = nil
		local s_NextPoint = nil
		local s_NextToNextPoint = nil
		local s_PointIncrement = 1
		local s_NoStuckReset = false

		if #self._ShootWayPoints > 0 then -- We need to go back to the path first.		
			s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)
			---@cast s_Point -nil
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
		s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)
		if s_Point == nil then
			return
		end

		if not self._InvertPathDirection then
			s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 1), self._PathIndex)
			if s_NextPoint then
				s_NextToNextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 2), self._PathIndex)
			end
		else
			s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint - 1), self._PathIndex)
			if s_NextPoint then
				s_NextToNextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint - 2), self._PathIndex)
			end
		end



		if Registry.BOT.USE_PATH_OFFSETS and s_Point and s_NextPoint and s_NextToNextPoint then
			s_Point, s_NextPoint = self:ApplyPathOffset(s_Point, s_NextPoint, s_NextToNextPoint)
		end

		-- Do defense, if needed
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


		-- Execute Action if needed.
		if self._ActiveAction == BotActionFlags.OtherActionActive then
			if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
				if s_Point.Data.Action.type == 'vehicle' then
					if Config.UseVehicles then
						local s_RetCode, s_Position = self:_EnterVehicle(false)
						if s_RetCode == 0 then
							---@cast s_Position -nil
							self:_ResetActionFlag(BotActionFlags.OtherActionActive)
							local s_Node = g_GameDirector:FindClosestPath(s_Position, true, false, self.m_ActiveVehicle.Terrain)

							if s_Node ~= nil then
								-- Switch to vehicle.
								s_Point = s_Node
								self._InvertPathDirection = false
								self._PathIndex = s_Node.PathIndex
								self._CurrentWayPoint = s_Node.PointIndex
								s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 1), self._PathIndex)
							end
						end
					end
					self:_ResetActionFlag(BotActionFlags.OtherActionActive)
				elseif s_Point.Data.Action.type == "beacon"
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
				elseif s_Point.Data.Action.type == "beacon" then
					self:_ResetActionFlag(BotActionFlags.OtherActionActive)
				elseif self._ActionTimer <= s_Point.Data.Action.time then
					for l_Index = 1, #s_Point.Data.Action.inputs do
						local l_Input = s_Point.Data.Action.inputs[l_Index]
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

			if self._ActiveAction == BotActionFlags.OtherActionActive then
				return -- DON'T EXECUTE ANYTHING ELSE.
			else
				if s_NextPoint then
					s_Point = s_NextPoint
				end
			end
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			self._WayWaitTimer = 0.0
			self._WayWaitYawTimer = 0.0
			self.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

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

			if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement then
				self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
			end

			-- Sidewards movement.
			if Config.MoveSidewards then
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

					self.m_PathSide = 0 -- reset offset
					self.m_OffsetRecoveryNodes = 10 -- lock center for a while
					self._StuckTimer = 0.0

					-- print("Bot rerouted " .. self.m_Name)
					return
				end
			end
			-- >>> END OFFSET RECOVERY

			self._TargetPoint = s_Point
			self._NextTargetPoint = s_NextPoint

			if s_Velocity.magnitude < 0.3 or self._ObstacleSequenceTimer ~= 0 then -- use velocity instead of position
				-- Try to get around obstacle.
				self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint            -- Always try to stand.
				if s_HeightDistance > 1.5 then                            -- no change to get there, so skip the obstacle-stuff
					self._ObstacleRetryCounter = 10
					goto skip
				end

				if self._ObstacleSequenceTimer == 0 then -- Step 0
				elseif self._ObstacleSequenceTimer > 3.4 then -- Step 4 - repeat afterwards.
					self._ObstacleSequenceTimer = 0
					self:_ResetActionFlag(BotActionFlags.MeleeActive)
					self._ObstacleRetryCounter = self._ObstacleRetryCounter + 1
				elseif self._ObstacleSequenceTimer > 2.0 then -- Step 3
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
				elseif self._ObstacleSequenceTimer > 1.4 then -- Step 2
					if self._ObstacleSequenceTimer <= 1.4 + p_DeltaTime then
						self.m_StrafeValue = self.m_StrafeValue * -1.0
					end
					self:_SetInput(EntryInputActionEnum.EIAStrafe, self.m_StrafeValue * Config.SpeedFactor)
				elseif self._ObstacleSequenceTimer > 0.4 then -- Step 2
					self._TargetPitch = 0.0

					if self.m_StrafeValue == 0 then
						if (MathUtils:GetRandomInt(0, 1) == 1) then
							self.m_StrafeValue = 1.0
						else
							self.m_StrafeValue = -1.0
						end
					end
					self:_SetInput(EntryInputActionEnum.EIAStrafe, self.m_StrafeValue * Config.SpeedFactor)
				elseif self._ObstacleSequenceTimer > 0.0 then -- Step 1
					self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					self:_SetInput(EntryInputActionEnum.EIAJump, 1)
				end

				::skip::
				self._ObstacleSequenceTimer = self._ObstacleSequenceTimer + p_DeltaTime
				self._StuckTimer = self._StuckTimer + p_DeltaTime

				if self._ObstacleRetryCounter >= 2 then -- Try next waypoint.
					self._ObstacleRetryCounter = 0
					self:_ResetActionFlag(BotActionFlags.MeleeActive)
					s_DistanceFromTargetSquared = 0
					s_HeightDistance = 0

					-- Teleport to target.
					s_NoStuckReset = true
					if Config.TeleportIfStuck and m_Utilities:CheckProbablity(Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK) then
						local s_Transform = self.m_Player.soldier.worldTransform:Clone()
						s_Transform.trans = self._TargetPoint.Position
						s_Transform:LookAtTransform(self._TargetPoint.Position, self._NextTargetPoint.Position)
						self.m_Player.soldier:SetTransform(s_Transform)
						m_Logger:Write('teleported ' .. self.m_Player.name)
					else
						s_PointIncrement = MathUtils:GetRandomInt(0, 4) -- Go up to 4 points further.
						if s_PointIncrement == 0 then
							s_PointIncrement = -2     -- Go backwards and try again.
						end

						if (Globals.IsConquest or Globals.IsRush) then
							if g_GameDirector:IsOnObjectivePath(self._PathIndex) then
								self._InvertPathDirection = m_Utilities:CheckProbablity(Registry.BOT.PROBABILITY_CHANGE_DIRECTION_IF_STUCK)
							end
						end
					end
				end

				if self._StuckTimer > 15.0 then
					self.m_Player.soldier:Kill()

					m_Logger:Write(self.m_Player.name .. ' got stuck. Kill')

					return
				end
			else
				self:_ResetActionFlag(BotActionFlags.MeleeActive)
			end

			-- Jump detection. Much more simple now, but works fine -)
			if self._ObstacleSequenceTimer == 0 then
				if (s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y) > 0.3 and Config.JumpWhileMoving then
					-- Detect, if a jump was recorded or not.
					local s_TimeForwardBackwardJumpDetection = 1.1 -- 1.5 s ahead and back.
					local s_JumpValid = false

					for i = 1, math.floor(s_TimeForwardBackwardJumpDetection / Config.TraceDelta) do
						local s_PointBefore = m_NodeCollection:Get(s_ActivePointIndex - i, self._PathIndex)
						local s_PointAfter = m_NodeCollection:Get(s_ActivePointIndex + i, self._PathIndex)

						if (s_PointBefore ~= nil and s_PointBefore.ExtraMode == 1) or
							(s_PointAfter ~= nil and s_PointAfter.ExtraMode == 1) then
							s_JumpValid = true
							break
						end
					end

					if s_JumpValid then
						self:_SetInput(EntryInputActionEnum.EIAJump, 1)
						self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					end
				end
			end

			local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint

			if self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 1.5
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.7
			elseif self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.5
			end
			local s_TargetDistanceSpeedSquared = s_TargetDistanceSpeed * s_TargetDistanceSpeed -- use squared values to avoid sqrt

			-- Check for reached target.
			if s_DistanceFromTargetSquared <= s_TargetDistanceSpeedSquared and s_HeightDistance <= Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT then
				if not s_NoStuckReset then
					self._StuckTimer = 0.0
				end


				-- CHECK FOR ACTION.
				if s_Point.Data.Action ~= nil then
					local s_Action = s_Point.Data.Action

					if g_GameDirector:CheckForExecution(s_Point, self.m_Player.teamId, false) then
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

						return -- DON'T DO ANYTHING ELSE ANY MORE.
					end
				end

				-- CHECK FOR PATH-SWITCHES.
				local s_NewWaypoint = nil
				local s_SwitchPath = false
				s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(self, self.m_Id, s_Point, self._Objective, false,
					self.m_Player.teamId, nil)

				if self.m_Player.soldier == nil then
					return
				end

				if s_SwitchPath == true and not self._OnSwitch and s_NewWaypoint then
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
					self._OnSwitch = true
				else
					self._OnSwitch = false

					if self._InvertPathDirection then
						self._CurrentWayPoint = s_ActivePointIndex - s_PointIncrement
					else
						self._CurrentWayPoint = s_ActivePointIndex + s_PointIncrement
					end
				end

				self._ObstacleSequenceTimer = 0
				self:_ResetActionFlag(BotActionFlags.MeleeActive)
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
		-- else -- no point: do nothing.
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
				self.m_ActiveWeapon.type == WeaponTypes.MissileLand) and
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

function Bot:UpdateSpeedOfMovement()
	-- Additional movement.
	if self.m_Player.soldier == nil then
		return
	end

	if self._ActiveAction == BotActionFlags.OtherActionActive then
		return
	end

	local s_SpeedVal = 0

	if self.m_ActiveMoveMode ~= BotMoveModes.Standstill then
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
		if self._MoveWhileShooting then
			s_SpeedVal = s_SpeedVal * Config.SpeedFactorAttack
		else
			s_SpeedVal = 0
		end
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

		if s_Distance < 0.2 then
			self._TargetPoint = self._NextTargetPoint
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

	if self._WayWaitYawTimer > 6.0 then
		self._WayWaitYawTimer = 0.0
		self._TargetYaw = self._TargetYaw + 1.0 -- 60° rotation right.

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 4.0 and s_LastYawTimer < 4.0 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60° rotation left.

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 3.0 and s_LastYawTimer < 3.0 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60° rotation left.

		if self._TargetYaw < 0.0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 1.0 and s_LastYawTimer < 1.0 then
		self._TargetYaw = self._TargetYaw + 1.0 -- 60° rotation right.

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

-- VU-safe 3-D distance (squared-root is already provided by MathUtils)
local function GetDistance3D(v1, v2)
	local dx = v1.x - v2.x
	local dy = v1.y - v2.y
	local dz = v1.z - v2.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function GetDistance2D(a, b)
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

local NARROW_RADIUS = 0.7
local DOOR_THRESHOLD = 0.8
local CAPSULE_H = 0.2
local RAYS = 8

local function MeasureFreeRadius(botPos)
	local CAPSULE_H = 0.2
	local RAYS = 8 -- cardinal + diagonal
	local minFree = 999

	for i = 0, RAYS - 1 do
		local ang = math.rad(i * 360 / RAYS)
		local dir = Vec3(math.sin(ang), 0, math.cos(ang))
		local from = botPos + Vec3(0, CAPSULE_H, 0)
		local to = from + dir * 5.0
		local hits = RaycastManager:CollisionRaycast(from, to, 0.2, 0,
			RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter)
		local dist = #hits > 0 and GetDistance2D(from, hits[1].position) or 5.0
		minFree = math.min(minFree, dist)
	end

	return minFree
end

---@param p_DeltaTime number
function Bot:UpdateFollowingMovement(p_DeltaTime)
	if self._FollowTargetPlayer == nil or
		self._FollowTargetPlayer.id == nil or
		self._FollowTargetPlayer.alive == false or
		self._FollowTargetPlayer.soldier == nil then
		return
	end

	local s_TargetPlayer        = self._FollowTargetPlayer
	local s_BotPosition         = self.m_Player.soldier.worldTransform.trans
	local s_PlayerPosition      = s_TargetPlayer.soldier.worldTransform.trans

	-- initialize anchor if needed
	self._FollowAnchor          = self._FollowAnchor or Vec3(s_PlayerPosition.x, s_PlayerPosition.y, s_PlayerPosition.z)
	self._FollowAnchorTime      = self._FollowAnchorTime or SharedUtils:GetTime()

	local ANCHOR_TIMEOUT        = 5.0
	local PLAYER_MOVE_THRESHOLD = 3.0

	local playerMoved           = GetDistance2D(s_PlayerPosition, self._FollowAnchor) > PLAYER_MOVE_THRESHOLD
	local anchorExpired         = (SharedUtils:GetTime() - self._FollowAnchorTime) >= ANCHOR_TIMEOUT

	if playerMoved or anchorExpired then
		self._FollowAnchor = Vec3(s_PlayerPosition.x, s_PlayerPosition.y, s_PlayerPosition.z)
		self._FollowAnchorTime = SharedUtils:GetTime()
		self._FollowAngle = math.random() * 360
	end

	-- measure free space
	local freeRadius = MeasureFreeRadius(s_BotPosition)

	-- desired follow radius
	local desiredRadius = self._FollowDistance or (2.5 + math.random() * 3.0)
	local clampedRadius = math.min(desiredRadius, freeRadius - 0.3)

	local s_TargetPosition = nil

	-- Tight corridor / door snap
	local DOOR_THRESHOLD = 0.8
	if clampedRadius < DOOR_THRESHOLD then
		local plyYaw = s_TargetPlayer.input.authoritativeAimingYaw
		local back = Vec3(-math.sin(plyYaw), 0, math.cos(plyYaw))

		-- side offset so multiple bots don’t stack
		local sideOffset = 0
		if self._FollowAngle then
			sideOffset = math.cos(math.rad(self._FollowAngle)) * 0.3
		end

		s_TargetPosition = s_PlayerPosition + back * 0.9 + Vec3(sideOffset, 0, 0)
		self._FollowDistance = 0.6
	else
		local angleRad = math.rad(self._FollowAngle or math.random() * 360)
		s_TargetPosition = Vec3(
			self._FollowAnchor.x + math.cos(angleRad) * clampedRadius,
			self._FollowAnchor.y,
			self._FollowAnchor.z + math.sin(angleRad) * clampedRadius
		)
		self._FollowDistance = clampedRadius
	end

	local s_Direction = s_TargetPosition - s_BotPosition
	local s_Distance  = math.sqrt(s_Direction.x ^ 2 + s_Direction.y ^ 2 + s_Direction.z ^ 2)

	-- defensive if close
	if s_Distance <= 0.8 then
		self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
		self:UpdateFollowingDefensive(self, p_DeltaTime)
		return
	end

	if s_Distance > 0.1 then
		s_Direction.x = s_Direction.x / s_Distance
		s_Direction.y = s_Direction.y / s_Distance
		s_Direction.z = s_Direction.z / s_Distance

		-- speed
		if s_Distance > 8.0 then
			self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint
		elseif s_Distance > 3.0 then
			self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
		else
			self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
		end

		-- obstacle check
		local flags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter |
			RayCastFlags.DontCheckRagdoll | RayCastFlags.DontCheckTerrain
		local rayOrigin = s_BotPosition + Vec3(0, 0.5, 0)
		local rayTarget = s_TargetPosition + Vec3(0, 0.5, 0)
		local s_ObstacleHits = RaycastManager:CollisionRaycast(rayOrigin, rayTarget, 1, 0, flags)

		-- jump only when appropriate
		local canJump = false
		if #s_ObstacleHits > 0 then
			local firstHit = s_ObstacleHits[1]
			local distToHit = GetDistance2D(s_BotPosition, firstHit.position)
			local heightDiff = firstHit.position.y - s_BotPosition.y
			if distToHit < 1.0 and heightDiff < 0.7 then
				canJump = true
			end
		end

		if canJump or math.abs(s_TargetPosition.y - s_BotPosition.y) > 1.5 or self._ObstacleSequenceTimer ~= 0 then
			self._ObstacleSequenceTimer = self._ObstacleSequenceTimer + p_DeltaTime
			self._StuckTimer = self._StuckTimer + p_DeltaTime

			-- quick jump
			if self._ObstacleSequenceTimer <= 0.2 then
				self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
				self:_SetInput(EntryInputActionEnum.EIAJump, 1)
				self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint
			elseif self._ObstacleSequenceTimer <= 1.0 then
				self._TargetPitch = 0
				if MathUtils:GetRandomInt(0, 1) == 1 then
					self:_SetInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
				else
					self:_SetInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
				end
			elseif self._ObstacleSequenceTimer <= 0.8 then
				if self._ObstacleRetryCounter == 0 then
					self:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
					self:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
					self.m_ActiveWeapon = self.m_Knife
				else
					self:_SetInput(EntryInputActionEnum.EIAFire, 1)
				end
			end

			self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint

			if self._ObstacleSequenceTimer > 0.8 then
				self._ObstacleSequenceTimer = 0
				self:_ResetActionFlag(BotActionFlags.MeleeActive)
				self._ObstacleRetryCounter = self._ObstacleRetryCounter + 1
			end

			return
		else
			-- clear obstacle state
			self._ObstacleSequenceTimer = 0
			self:_ResetActionFlag(BotActionFlags.MeleeActive)
			self._ObstacleRetryCounter = 0
			self._StuckTimer = 0
		end

		-- compute yaw
		local s_AtanDzDx = math.atan(s_TargetPosition.z - s_BotPosition.z, s_TargetPosition.x - s_BotPosition.x)
		self._TargetYaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		-- alive behaviors
		self:UpdateFollowingBehaviors(p_DeltaTime, s_Distance)
	else
		-- defensive if in place
		self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
		self:UpdateFollowingDefensive(p_DeltaTime)
	end
end

---@param p_DeltaTime number
---@param p_Distance number
function Bot:UpdateFollowingBehaviors(p_DeltaTime, p_Distance)
	-- Strafing behavior
	self._FollowStrafeTimer = (self._FollowStrafeTimer or 0) + p_DeltaTime

	if p_Distance < 3.0 and self._FollowStrafeTimer > 3.0 then
		self._FollowStrafeTimer = 0.0

		-- Random strafe for variety
		if math.random() < 0.3 then
			local s_StrafeDirection = (math.random() < 0.5) and 1.0 or -1.0
			self:_SetInput(EntryInputActionEnum.EIAStrafe, s_StrafeDirection)

			-- Update follow angle
			self._FollowAngle = ((self._FollowAngle or 0) + (s_StrafeDirection * 15)) % 360
		end
	end

	-- Look around behavior
	self._FollowLookTimer = (self._FollowLookTimer or 0) + p_DeltaTime

	if self._FollowLookTimer > 5.0 then
		self._FollowLookTimer = 0.0

		-- Random look around
		if math.random() < 0.4 then
			local s_LookOffset = (math.random() - 0.5) * 1.0
			self._TargetYaw = self._TargetYaw + s_LookOffset
		end
	end
end

---@param p_DeltaTime number
function Bot:UpdateFollowingDefensive(p_DeltaTime)
	-- Defensive behaviors when in position

	-- Occasional stance changes
	if math.random() < 0.005 then
		local s_RandomPose = math.random(0, 2)
		if s_RandomPose == 0 then
			self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
		elseif s_RandomPose == 1 then
			self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
		else
			self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
		end
	end

	-- Periodic scanning
	if math.random() < 0.003 then
		local s_ScanOffset = (math.random() - 0.5) * 2.0
		self._TargetYaw = self._TargetYaw + s_ScanOffset
	end
end
