---@class BotMovement
---@overload fun():BotMovement
BotMovement = class('BotMovement')

---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')

function BotMovement:__init()
	-- Nothing to do.
end

local flags = RayCastFlags.DontCheckWater |
	RayCastFlags.DontCheckCharacter |
	RayCastFlags.DontCheckRagdoll |
	RayCastFlags.DontCheckTerrain

-- >>> SMART PATH OFFSET (with zig-zag and stairs fixes)
local function ApplyPathOffset(p_Bot, p_OriginalPoint, p_NextPoint)
	-- PRIORITY 1: Recovery mode - disable offset
	if p_Bot.m_PathSide == 0 and p_Bot.m_OffsetRecoveryNodes and p_Bot.m_OffsetRecoveryNodes > 0 then
		p_Bot.m_OffsetRecoveryNodes = p_Bot.m_OffsetRecoveryNodes - 1
		if p_Bot.m_OffsetRecoveryNodes == 0 then
			p_Bot.m_PathSide = math.random(-1, 1)
		end
		return p_OriginalPoint
	end

	-- PRIORITY 2: Validate inputs
	if not p_OriginalPoint or not p_NextPoint or
		(p_OriginalPoint.Data and (p_OriginalPoint.Data.Action or p_OriginalPoint.Data.Links)) then
		return p_OriginalPoint
	end

	-- Initialize side once per path
	if not p_Bot.m_PathSide or p_Bot.m_LastPathIndex ~= p_Bot._PathIndex then
		p_Bot.m_PathSide = math.random(-1, 1)          -- -1 left, 0 center, 1 right
		p_Bot.m_LastPathIndex = p_Bot._PathIndex
		p_Bot.m_OffsetDistance = 0.8 + (math.random() * 0.4) -- 0.8-1.2m
		p_Bot.m_LastStuckCheck = 0
		p_Bot.m_ForceCenter = false
		p_Bot.m_OffsetRight = nil
	end

	-- Emergency fallback
	if p_Bot._ObstacleSequenceTimer ~= 0 and p_Bot.m_PathSide ~= 0 then
		p_Bot.m_ForceCenter = true
		return p_OriginalPoint
	end
	if p_Bot.m_ForceCenter and p_Bot._ObstacleSequenceTimer == 0 then
		p_Bot.m_ForceCenter = false
	end
	if p_Bot.m_PathSide == 0 or p_Bot.m_ForceCenter then
		return p_OriginalPoint
	end

	-- Calculate delta and direction
	local delta = p_NextPoint.Position - p_OriginalPoint.Position
	local length2D = math.sqrt(delta.x * delta.x + delta.z * delta.z)
	if length2D < 0.1 then return p_OriginalPoint end

	local dir = Vec3(delta.x / length2D, 0, delta.z / length2D)
	local right = Vec3(dir.z, 0, -dir.x)

	-- >>> FIX 1: soften lateral direction (avoid zig-zag)
	if not p_Bot.m_OffsetRight then
		p_Bot.m_OffsetRight = right
	else
		local smoothed = Vec3(
			p_Bot.m_OffsetRight.x * 0.8 + right.x * 0.2,
			0,
			p_Bot.m_OffsetRight.z * 0.8 + right.z * 0.2
		)
		smoothed:Normalize()
		p_Bot.m_OffsetRight = smoothed
	end
	right = p_Bot.m_OffsetRight

	-- >>> FIX 2: stairs/passages vertical → center
	local verticalDelta = math.abs(p_NextPoint.Position.y - p_OriginalPoint.Position.y)
	if verticalDelta > 0.5 then
		p_Bot.m_OffsetRecoveryNodes = 3 -- force center for 3 nodes
		return p_OriginalPoint
	end


	-- >>> Smart check width (once per node or every 1s)
	local currentTime = SharedUtils:GetTimeMS()
	if currentTime - (p_Bot.m_LastStuckCheck or 0) > 1000 then
		p_Bot.m_LastStuckCheck = currentTime

		local rayOrigin = p_OriginalPoint.Position + Vec3(0, 0.5, 0)

		local leftHits = RaycastManager:CollisionRaycast(
			rayOrigin - right * 1.5,
			rayOrigin - right * 0.5,
			1, 0, flags
		)
		local rightHits = RaycastManager:CollisionRaycast(
			rayOrigin + right * 0.5,
			rayOrigin + right * 1.5,
			1, 0, flags
		)

		if #leftHits > 0 and #rightHits > 0 then
			return p_OriginalPoint -- narrow corridor → center
		end

		-- >>> FIX 3: limit offset based on free space
		local leftClear = (#leftHits > 0) and leftHits[1].distance or 2.0
		local rightClear = (#rightHits > 0) and rightHits[1].distance or 2.0
		local maxOffset = math.min(leftClear, rightClear) - 0.3
		if maxOffset < p_Bot.m_OffsetDistance then
			p_Bot.m_OffsetDistance = math.max(0.3, maxOffset)
		end
	end

	-- Calculate offset position
	local offsetPosition = p_OriginalPoint.Position + right * (p_Bot.m_PathSide * p_Bot.m_OffsetDistance)

	-- >>> FIX 4: check ground under the offset (avoid falling)
	local footOrigin = offsetPosition + Vec3(0, 0.2, 0)
	local footTarget = offsetPosition - Vec3(0, 2.0, 0)
	local downHits = RaycastManager:CollisionRaycast(footOrigin, footTarget, 1, 0, flags)
	if #downHits == 0 then
		p_Bot.m_OffsetRecoveryNodes = 2
		return p_OriginalPoint
	end

	-- Wall-slide check
	local sideCheck = RaycastManager:CollisionRaycast(
		p_OriginalPoint.Position + right * (p_Bot.m_PathSide * 0.3),
		offsetPosition,
		1, 0,
		flags
	)
	if #sideCheck > 0 and sideCheck[1].position then
		local comfortableDistance = 0.4
		offsetPosition = p_OriginalPoint.Position + right * (p_Bot.m_PathSide * comfortableDistance)
	end

	return {
		Position = offsetPosition,
		SpeedMode = p_OriginalPoint.SpeedMode,
		ExtraMode = p_OriginalPoint.ExtraMode,
		OptValue = p_OriginalPoint.OptValue,
		Data = p_OriginalPoint.Data
	}
end
---comment
---@param p_DeltaTime number
---@param p_Bot Bot
function BotMovement:UpdateNormalMovement(p_DeltaTime, p_Bot)
	-- Move along points.
	p_Bot._AttackModeMoveTimer = 0.0

	if m_NodeCollection:Get(1, p_Bot._PathIndex) ~= nil then -- Check for valid point.
		-- Get next point.
		local s_ActivePointIndex = p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint)

		local s_Point = nil
		local s_NextPoint = nil
		local s_PointIncrement = 1
		local s_NoStuckReset = false

		if #p_Bot._ShootWayPoints > 0 then -- We need to go back to the path first.		
			s_Point = m_NodeCollection:Get(s_ActivePointIndex, p_Bot._PathIndex)
			local s_ClosestDistance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)
			local s_ClosestNode = s_ActivePointIndex
			for i = 1, Registry.BOT.NUMBER_NODES_TO_SCAN_AFTER_ATTACK, 2 do
				s_Point = m_NodeCollection:Get(s_ActivePointIndex - i, p_Bot._PathIndex)
				if s_Point and p_Bot.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position) < s_ClosestDistance then
					s_ClosestNode = s_ActivePointIndex - i
				end
				s_Point = m_NodeCollection:Get(s_ActivePointIndex + i, p_Bot._PathIndex)
				if s_Point and p_Bot.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position) < s_ClosestDistance then
					s_ClosestNode = s_ActivePointIndex + i
				end
			end
			if s_ClosestDistance < 5.0 then
				p_Bot._CurrentWayPoint = s_ClosestNode
				s_ActivePointIndex = s_ClosestNode
			end
			p_Bot._ShootWayPoints = {}
		end
		s_Point = m_NodeCollection:Get(s_ActivePointIndex, p_Bot._PathIndex)

		if not p_Bot._InvertPathDirection then
			s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint + 1), p_Bot._PathIndex)
		else
			s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint - 1), p_Bot._PathIndex)
		end

		if s_Point == nil then
			return
		end

		if s_Point and s_NextPoint then
			s_Point = ApplyPathOffset(p_Bot, s_Point, s_NextPoint) or s_Point
		end

		-- Do defense, if needed
		if p_Bot._ObjectiveMode == BotObjectiveModes.Defend and g_GameDirector:IsAtTargetObjective(p_Bot._PathIndex, p_Bot._Objective) then
			p_Bot._DefendTimer = p_Bot._DefendTimer + p_DeltaTime

			local s_TargetTime = p_Bot.m_Id % 5 + 4 -- min 2 sec on path, then 2 sec movement to side
			if p_Bot._DefendTimer >= s_TargetTime then
				-- look around
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement

				local s_DefendMode = p_Bot.m_Id % 3
				if s_DefendMode == 0 then
					if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
						p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
					end
				elseif s_DefendMode == 1 then
					if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
						p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
					end
				else
					if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
						p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
					end
				end

				self:LookAround(p_Bot, p_DeltaTime)

				-- TODO: look at target
				-- don't do anything else
				return
			elseif p_Bot._DefendTimer >= (s_TargetTime - 2) then
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Backwards
				local s_StrafeValue = 1.0
				if p_Bot.m_Id % 2 then
					s_StrafeValue = -1.0
				end
				p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, s_StrafeValue)
				return
			end
		else
			p_Bot._DefendTimer = 0.0
		end


		-- Execute Action if needed.
		if p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
			if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
				if s_Point.Data.Action.type == 'vehicle' then
					if Config.UseVehicles then
						local s_RetCode, s_Position = p_Bot:_EnterVehicle(false)
						if s_RetCode == 0 then
							p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
							local s_Node = g_GameDirector:FindClosestPath(s_Position, true, false, p_Bot.m_ActiveVehicle.Terrain)

							if s_Node ~= nil then
								-- Switch to vehicle.
								s_Point = s_Node
								p_Bot._InvertPathDirection = false
								p_Bot._PathIndex = s_Node.PathIndex
								p_Bot._CurrentWayPoint = s_Node.PointIndex
								s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint + 1), p_Bot._PathIndex)
								p_Bot._LastWayDistance = 1000.0
							end
						end
					end
					p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
				elseif s_Point.Data.Action.type == "beacon"
					and p_Bot.m_SecondaryGadget.type == WeaponTypes.Beacon
					and not p_Bot.m_HasBeacon
				then
					p_Bot._WeaponToUse = BotWeapons.Gadget2

					if p_Bot.m_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_5 then
						if p_Bot.m_Player.soldier.weaponsComponent.weapons[6] and p_Bot.m_Player.soldier.weaponsComponent.weapons[6].primaryAmmo > 0 then
							p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
						else
							p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 0)
							p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
						end
					end
				elseif s_Point.Data.Action.type == "beacon" then
					p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
				elseif p_Bot._ActionTimer <= s_Point.Data.Action.time then
					for l_Index = 1, #s_Point.Data.Action.inputs do
						local l_Input = s_Point.Data.Action.inputs[l_Index]
						p_Bot:_SetInput(l_Input, 1)
					end
				end
			else
				p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
			end

			p_Bot._ActionTimer = p_Bot._ActionTimer - p_DeltaTime

			if p_Bot._ActionTimer <= 0.0 then
				p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
			end

			if p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
				return -- DON'T EXECUTE ANYTHING ELSE.
			else
				if s_NextPoint then
					s_Point = s_NextPoint
				end
			end
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			p_Bot._WayWaitTimer = 0.0
			p_Bot._WayWaitYawTimer = 0.0
			p_Bot.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			if p_Bot._ActiveAction == BotActionFlags.RunAway and p_Bot._ActionTimer > 0.0 then
				p_Bot._ActionTimer = p_Bot._ActionTimer - p_DeltaTime

				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint
				if p_Bot._ActionTimer <= 0.0 then
					p_Bot:_ResetActionFlag(BotActionFlags.RunAway)
				end
			end

			if p_Bot._ActiveAction == BotActionFlags.HideOnAttack and p_Bot._ActionTimer > 0.0 then
				p_Bot._ActionTimer = p_Bot._ActionTimer - p_DeltaTime

				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.VerySlowProne
				if p_Bot._ActionTimer <= 0.0 then
					p_Bot:_ResetActionFlag(BotActionFlags.HideOnAttack)
				end
			end

			if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement then
				p_Bot.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
			end

			-- Sidewards movement.
			if Config.MoveSidewards then
				if p_Bot._SidewardsTimer <= 0.0 then
					if p_Bot.m_StrafeValue ~= 0 then
						p_Bot._SidewardsTimer = MathUtils:GetRandom(Config.MinMoveCycle, Config.MaxStraigtCycle)
						p_Bot.m_StrafeValue = 0.0
						p_Bot.m_YawOffset = 0.0
					else
						p_Bot._SidewardsTimer = MathUtils:GetRandom(Config.MinMoveCycle, Config.MaxSideCycle)
						if MathUtils:GetRandomInt(0, 1) > 0 then -- Random direction.
							p_Bot.m_StrafeValue = 1.0
						else
							p_Bot.m_StrafeValue = -1.0
						end
						if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
							p_Bot.m_YawOffset = 0.3927 * -p_Bot.m_StrafeValue
						else
							p_Bot.m_YawOffset = 0.7854 * -p_Bot.m_StrafeValue
						end
					end
				end
				p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, p_Bot.m_StrafeValue)
				p_Bot._SidewardsTimer = p_Bot._SidewardsTimer - p_DeltaTime
			end

			-- Use parachute if needed.
			local s_VelocityFalling = PhysicsEntity(p_Bot.m_Player.soldier).velocity.y
			if s_VelocityFalling < -25.0 then
				p_Bot:_SetInput(EntryInputActionEnum.EIAToggleParachute, 1)
			end

			local s_DifferenceY = s_Point.Position.z - p_Bot.m_Player.soldier.worldTransform.trans.z
			local s_DifferenceX = s_Point.Position.x - p_Bot.m_Player.soldier.worldTransform.trans.x
			local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
			local s_HeightDistance = math.abs(s_Point.Position.y - p_Bot.m_Player.soldier.worldTransform.trans.y)

			-- Detect obstacle and move over or around. To-do: Move before normal jump.
			local s_CurrentWayPointDistance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)

			-- >>> OFFSET-AWARE STUCK RECOVERY (improved)
			-- >>> PATCH: Hard reroute when stuck
			if p_Bot._StuckTimer > 6.0 then
				local soldier = p_Bot.m_Player.soldier
				if soldier ~= nil then
					local s_Node = g_GameDirector:FindClosestPath(soldier.worldTransform.trans, false, true, nil)

					if s_Node ~= nil then
						p_Bot._InvertPathDirection = false
						p_Bot._PathIndex = s_Node.PathIndex
						p_Bot._CurrentWayPoint = s_Node.PointIndex
						p_Bot._LastWayDistance = 1000.0
					end

					p_Bot.m_PathSide = 0 -- reset offset
					p_Bot.m_OffsetRecoveryNodes = 10 -- lock center for a while
					p_Bot._StuckTimer = 0.0

					-- print("Bot rerouted " .. p_Bot.m_Name)
					return
				end
			end
			-- >>> END OFFSET RECOVERY

			if s_CurrentWayPointDistance > p_Bot._LastWayDistance + 0.02 and p_Bot._ObstacleSequenceTimer == 0 then
				-- Skip one point.
				s_DistanceFromTarget = 0
				s_HeightDistance = 0
			end

			p_Bot._TargetPoint = s_Point
			p_Bot._NextTargetPoint = s_NextPoint

			if math.abs(s_CurrentWayPointDistance - p_Bot._LastWayDistance) < 0.02 or p_Bot._ObstacleSequenceTimer ~= 0 then
				-- Try to get around obstacle.
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Always try to stand.

				if p_Bot._ObstacleSequenceTimer == 0 then -- Step 0
				elseif p_Bot._ObstacleSequenceTimer > 2.4 then -- Step 4 - repeat afterwards.
					p_Bot._ObstacleSequenceTimer = 0
					p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
					p_Bot._ObstacleRetryCounter = p_Bot._ObstacleRetryCounter + 1
				elseif p_Bot._ObstacleSequenceTimer > 1.0 then -- Step 3
					if p_Bot._ObstacleRetryCounter == 0 then
						if p_Bot._ActiveAction ~= BotActionFlags.MeleeActive then
							p_Bot._ActiveAction = BotActionFlags.MeleeActive
							p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
							p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
							p_Bot:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
							p_Bot.m_ActiveWeapon = p_Bot.m_Knife
							p_Bot._MeleeCooldownTimer = Config.MeleeAttackCoolDown -- Set time to ensure bot exit knife-mode when attack starts.
						else
							p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
						end
					else
						p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
					end
				elseif p_Bot._ObstacleSequenceTimer > 0.4 then -- Step 2
					p_Bot._TargetPitch = 0.0

					if (MathUtils:GetRandomInt(0, 1) == 1) then
						p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
					else
						p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
					end
				elseif p_Bot._ObstacleSequenceTimer > 0.0 then -- Step 1
					p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
				end

				p_Bot._ObstacleSequenceTimer = p_Bot._ObstacleSequenceTimer + p_DeltaTime
				p_Bot._StuckTimer = p_Bot._StuckTimer + p_DeltaTime
				-- >>> PATCH 2: vertical stuck acceleration
				local soldierPos = p_Bot.m_Player.soldier.worldTransform.trans
				if s_Point and (s_Point.Position.y - soldierPos.y > 1.5) then
					-- If bot is too low compared to target (stairs/roof cases), speed up stuck timer
					p_Bot._StuckTimer = p_Bot._StuckTimer + (p_DeltaTime * 2.0)
				end
				-- <<< END PATCH 2

				if p_Bot._ObstacleRetryCounter >= 2 then -- Try next waypoint.
					p_Bot._ObstacleRetryCounter = 0
					p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
					s_DistanceFromTarget = 0
					s_HeightDistance = 0

					-- Teleport to target.
					s_NoStuckReset = true
					if Config.TeleportIfStuck and m_Utilities:CheckProbablity(Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK) then
						local s_Transform = p_Bot.m_Player.soldier.worldTransform:Clone()
						s_Transform.trans = p_Bot._TargetPoint.Position
						s_Transform:LookAtTransform(p_Bot._TargetPoint.Position, p_Bot._NextTargetPoint.Position)
						p_Bot.m_Player.soldier:SetTransform(s_Transform)
						m_Logger:Write('teleported ' .. p_Bot.m_Player.name)
					else
						s_PointIncrement = MathUtils:GetRandomInt(-5, 5) -- Go 5 points further.
						-- Experimental.
						if s_PointIncrement == 0 then  -- We can't have this.
							s_PointIncrement = -2      -- Go backwards and try again.
						end

						if (Globals.IsConquest or Globals.IsRush) then
							if g_GameDirector:IsOnObjectivePath(p_Bot._PathIndex) then
								p_Bot._InvertPathDirection = m_Utilities:CheckProbablity(Registry.BOT.PROBABILITY_CHANGE_DIRECTION_IF_STUCK)
							end
						end
					end
				end

				if p_Bot._StuckTimer > 15.0 then
					p_Bot.m_Player.soldier:Kill()

					m_Logger:Write(p_Bot.m_Player.name .. ' got stuck. Kill')

					return
				end
			else
				p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
			end

			p_Bot._LastWayDistance = s_CurrentWayPointDistance

			-- Jump detection. Much more simple now, but works fine -)
			if p_Bot._ObstacleSequenceTimer == 0 then
				if (s_Point.Position.y - p_Bot.m_Player.soldier.worldTransform.trans.y) > 0.3 and Config.JumpWhileMoving then
					-- Detect, if a jump was recorded or not.
					local s_TimeForwardBackwardJumpDetection = 1.1 -- 1.5 s ahead and back.
					local s_JumpValid = false

					for i = 1, math.floor(s_TimeForwardBackwardJumpDetection / Config.TraceDelta) do
						local s_PointBefore = m_NodeCollection:Get(s_ActivePointIndex - i, p_Bot._PathIndex)
						local s_PointAfter = m_NodeCollection:Get(s_ActivePointIndex + i, p_Bot._PathIndex)

						if (s_PointBefore ~= nil and s_PointBefore.ExtraMode == 1) or
							(s_PointAfter ~= nil and s_PointAfter.ExtraMode == 1) then
							s_JumpValid = true
							break
						end
					end

					if s_JumpValid then
						p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
						p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					end
				end
			end

			local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint

			if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 1.5
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.7
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.5
			end

			-- Check for reached target.
			if s_DistanceFromTarget <= s_TargetDistanceSpeed and s_HeightDistance <= Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT then
				if not s_NoStuckReset then
					p_Bot._StuckTimer = 0.0
				end


				-- CHECK FOR ACTION.
				if s_Point.Data.Action ~= nil then
					local s_Action = s_Point.Data.Action

					if g_GameDirector:CheckForExecution(s_Point, p_Bot.m_Player.teamId, false) then
						p_Bot._ActiveAction = BotActionFlags.OtherActionActive

						if s_Action.time ~= nil then
							p_Bot._ActionTimer = s_Action.time
						else
							p_Bot._ActionTimer = 0.0
						end

						if s_Action.yaw ~= nil then
							p_Bot._TargetYaw = s_Action.yaw
						end

						if s_Action.pitch ~= nil then
							p_Bot._TargetPitch = s_Action.pitch
						end

						return -- DON'T DO ANYTHING ELSE ANY MORE.
					end
				end

				-- CHECK FOR PATH-SWITCHES.
				local s_NewWaypoint = nil
				local s_SwitchPath = false
				s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(p_Bot, p_Bot.m_Id, s_Point, p_Bot._Objective, false,
					p_Bot.m_Player.teamId, nil)

				if p_Bot.m_Player.soldier == nil then
					return
				end

				if s_SwitchPath == true and not p_Bot._OnSwitch and s_NewWaypoint then
					if p_Bot._Objective ~= '' then
						-- 'Best' direction for objective on switch.
						local s_Direction = m_NodeCollection:ObjectiveDirection(s_NewWaypoint, p_Bot._Objective, false)
						if s_Direction then
							p_Bot._InvertPathDirection = (s_Direction == 'Previous')
						end
					else
						-- Random path direction on switch.
						p_Bot._InvertPathDirection = MathUtils:GetRandomInt(1, 2) == 1
					end

					p_Bot._PathIndex = s_NewWaypoint.PathIndex
					p_Bot._CurrentWayPoint = s_NewWaypoint.PointIndex
					p_Bot._OnSwitch = true
				else
					p_Bot._OnSwitch = false

					if p_Bot._InvertPathDirection then
						p_Bot._CurrentWayPoint = s_ActivePointIndex - s_PointIncrement
					else
						p_Bot._CurrentWayPoint = s_ActivePointIndex + s_PointIncrement
					end
				end

				p_Bot._ObstacleSequenceTimer = 0
				p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
				p_Bot._LastWayDistance = 1000.0
			end
		else -- Wait mode.
			p_Bot._WayWaitTimer = p_Bot._WayWaitTimer + p_DeltaTime

			self:LookAround(p_Bot, p_DeltaTime)

			if p_Bot._WayWaitTimer > s_Point.OptValue then
				p_Bot._WayWaitTimer = 0.0

				if p_Bot._InvertPathDirection then
					p_Bot._CurrentWayPoint = s_ActivePointIndex - 1
				else
					p_Bot._CurrentWayPoint = s_ActivePointIndex + 1
				end
			end
		end
		-- else -- no point: do nothing.
	end
end

---@param p_DeltaTime number
---@param p_Bot Bot
function BotMovement:UpdateMovementSprintToTarget(p_DeltaTime, p_Bot)
	p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Run to target.

	if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
		p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
	end

	local s_Jump = true

	if p_Bot._ShootPlayer ~= nil and p_Bot._ShootPlayer.corpse ~= nil then
		if p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Bot._ShootPlayer.corpse.worldTransform.trans) < 2 then
			p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			s_Jump = false
		end
	end

	-- To-do: obstacle detection.
	if s_Jump == true then
		p_Bot._AttackModeMoveTimer = p_Bot._AttackModeMoveTimer + p_DeltaTime

		if p_Bot._AttackModeMoveTimer > 3.0 then
			p_Bot._AttackModeMoveTimer = 0.0
		elseif p_Bot._AttackModeMoveTimer > 2.5 then
			p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
			p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
		end
	end
end

---@param p_DeltaTime number
---@param p_Bot Bot
function BotMovement:UpdateShootMovement(p_DeltaTime, p_Bot)
	p_Bot._DefendTimer = 0.0
	-- Shoot MoveMode.
	if p_Bot._AttackMode == BotAttackModes.RandomNotSet then
		if Config.BotAttackMode ~= BotAttackModes.RandomNotSet then
			p_Bot._AttackMode = Config.BotAttackMode
		else -- Random.
			if MathUtils:GetRandomInt(0, 1) == 1 then
				p_Bot._AttackMode = BotAttackModes.Stand
			else
				p_Bot._AttackMode = BotAttackModes.Crouch
			end
		end
	end

	if (p_Bot.m_ActiveWeapon and (p_Bot.m_ActiveWeapon.type == WeaponTypes.Sniper or
				p_Bot.m_ActiveWeapon.type == WeaponTypes.MissileAir or
				p_Bot.m_ActiveWeapon.type == WeaponTypes.MissileLand or
				p_Bot.m_ActiveWeapon.type == WeaponTypes.LMG) and
			not p_Bot.m_KnifeMode) then -- Don't move while shooting some weapons.
		if p_Bot._AttackMode == BotAttackModes.Crouch then
			if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		else
			if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		end

		p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	else
		local s_TargetTime = 5.0
		local s_TargetCycles = math.floor(s_TargetTime / Registry.BOT.TRACE_DELTA_SHOOTING)

		if p_Bot.m_KnifeMode then                  -- Knife Only Mode.
			s_TargetCycles = 1
			p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Run towards player.
		else
			if p_Bot._AttackMode == BotAttackModes.Crouch then
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			else
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Normal
			end
		end

		if Config.OverWriteBotAttackMode ~= BotMoveSpeeds.NoMovement then
			p_Bot.m_ActiveSpeedValue = Config.OverWriteBotAttackMode
		end

		if #p_Bot._ShootWayPoints > s_TargetCycles and Config.JumpWhileShooting then
			local s_DistanceDone = p_Bot._ShootWayPoints[#p_Bot._ShootWayPoints].Position:Distance(p_Bot._ShootWayPoints[
			#p_Bot._ShootWayPoints - s_TargetCycles].Position)
			if s_DistanceDone < 0.5 and p_Bot._DistanceToPlayer > 1.0 then -- No movement was possible. Try to jump over an obstacle.
				table.remove(p_Bot._ShootWayPoints)
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Normal
				p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
				p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
			end
		end

		-- Do some sidewards movement from time to time.
		local movementIntensity = Config.SpeedFactorAttack

		-- wrap timer every 15 s (keeps the old behaviour)
		if p_Bot._AttackModeMoveTimer >= 15.0 then
			p_Bot._AttackModeMoveTimer = p_Bot._AttackModeMoveTimer - 15.0
		end

		-- which 2.5-second sub-cycle are we in?  (0-2.499, 2.5-4.999 …)
		local cycle  = p_Bot._AttackModeMoveTimer % 2.5
		local inMove = (cycle <= 1.0) -- we move for the first 1 s

		-- store the direction for the whole 1-second window
		if p_Bot._MoveDirection == nil then
			p_Bot._MoveDirection = 1 -- init once
		end

		-- entering a new 1-second window?  pick a new random direction
		local justEntered = (cycle - p_DeltaTime <= 0.0)
		if justEntered then
			p_Bot._MoveDirection = (math.random() < 0.5) and 1 or -1
		end

		-- apply movement
		if inMove then
			p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe,
				p_Bot._MoveDirection * movementIntensity)
		end
		p_Bot._AttackModeMoveTimer = p_Bot._AttackModeMoveTimer + p_DeltaTime
	end
end

---@param p_Bot Bot
function BotMovement:UpdateSpeedOfMovement(p_Bot)
	-- Additional movement.
	if p_Bot.m_Player.soldier == nil then
		return
	end

	if p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
		return
	end

	local s_SpeedVal = 0

	if p_Bot.m_ActiveMoveMode ~= BotMoveModes.Standstill then
		if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
			s_SpeedVal = 1.0

			if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
				p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
			end
		elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
			s_SpeedVal = 1.0

			if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
		elseif p_Bot.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
			s_SpeedVal = 1.0

			if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
		end
	end

	-- Do not reduce speed if sprinting.
	if s_SpeedVal > 0 and p_Bot._ShootPlayer ~= nil and p_Bot._ShootPlayer.soldier ~= nil and
		p_Bot.m_ActiveSpeedValue <= BotMoveSpeeds.Normal then
		if p_Bot._OnFootStopMovingWhenAttacking then -- Check for stats to stop for shoot
			s_SpeedVal = 0
		else
			s_SpeedVal = s_SpeedVal * Config.SpeedFactorAttack
		end
	end

	-- Movent speed.
	if p_Bot.m_ActiveSpeedValue ~= BotMoveSpeeds.Sprint then
		p_Bot:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal * Config.SpeedFactor)
	else
		p_Bot:_SetInput(EntryInputActionEnum.EIAThrottle, 1)
		p_Bot:_SetInput(EntryInputActionEnum.EIASprint, s_SpeedVal * Config.SpeedFactor)
	end
end

---@param p_Bot Bot
function BotMovement:UpdateTargetMovement(p_Bot)
	if p_Bot._TargetPoint and p_Bot.m_Player.soldier then
		local s_Distance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Bot._TargetPoint.Position)

		if s_Distance < 0.2 then
			p_Bot._TargetPoint = p_Bot._NextTargetPoint
		end

		local s_DifferenceY = p_Bot._TargetPoint.Position.z - p_Bot.m_Player.soldier.worldTransform.trans.z
		local s_DifferenceX = p_Bot._TargetPoint.Position.x - p_Bot.m_Player.soldier.worldTransform.trans.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		p_Bot._TargetYaw = s_Yaw
		p_Bot._TargetYaw = p_Bot._TargetYaw + p_Bot.m_YawOffset
	end
end

---@param p_Bot Bot
---@param p_DeltaTime number
function BotMovement:LookAround(p_Bot, p_DeltaTime)
	-- Move around a little.
	local s_LastYawTimer = p_Bot._WayWaitYawTimer
	p_Bot._WayWaitYawTimer = p_Bot._WayWaitYawTimer + p_DeltaTime
	p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	p_Bot._TargetPoint = nil
	p_Bot._TargetPitch = 0.0

	if p_Bot._WayWaitYawTimer > 6.0 then
		p_Bot._WayWaitYawTimer = 0.0
		p_Bot._TargetYaw = p_Bot._TargetYaw + 1.0 -- 60° rotation right.

		if p_Bot._TargetYaw > (math.pi * 2) then
			p_Bot._TargetYaw = p_Bot._TargetYaw - (2 * math.pi)
		end
	elseif p_Bot._WayWaitYawTimer >= 4.0 and s_LastYawTimer < 4.0 then
		p_Bot._TargetYaw = p_Bot._TargetYaw - 1.0 -- 60° rotation left.

		if p_Bot._TargetYaw < 0.0 then
			p_Bot._TargetYaw = p_Bot._TargetYaw + (2 * math.pi)
		end
	elseif p_Bot._WayWaitYawTimer >= 3.0 and s_LastYawTimer < 3.0 then
		p_Bot._TargetYaw = p_Bot._TargetYaw - 1.0 -- 60° rotation left.

		if p_Bot._TargetYaw < 0.0 then
			p_Bot._TargetYaw = p_Bot._TargetYaw + (2 * math.pi)
		end
	elseif p_Bot._WayWaitYawTimer >= 1.0 and s_LastYawTimer < 1.0 then
		p_Bot._TargetYaw = p_Bot._TargetYaw + 1.0 -- 60° rotation right.

		if p_Bot._TargetYaw > (math.pi * 2) then
			p_Bot._TargetYaw = p_Bot._TargetYaw - (2 * math.pi)
		end
	end
end

---@param p_Bot Bot
function BotMovement:UpdateYaw(p_Bot)
	local s_DeltaYaw = 0
	s_DeltaYaw = p_Bot.m_Player.input.authoritativeAimingYaw - p_Bot._TargetYaw

	if s_DeltaYaw > math.pi then
		s_DeltaYaw = s_DeltaYaw - 2 * math.pi
	elseif s_DeltaYaw < -math.pi then
		s_DeltaYaw = s_DeltaYaw + 2 * math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_Increment = Globals.YawPerFrame

	if s_AbsDeltaYaw < s_Increment then
		p_Bot.m_Player.input.authoritativeAimingYaw = p_Bot._TargetYaw
		p_Bot.m_Player.input.authoritativeAimingPitch = p_Bot._TargetPitch
		return
	end

	if s_DeltaYaw > 0 then
		s_Increment = -s_Increment
	end

	local s_TempYaw = p_Bot.m_Player.input.authoritativeAimingYaw + s_Increment

	if s_TempYaw >= (math.pi * 2) then
		s_TempYaw = s_TempYaw - (math.pi * 2)
	elseif s_TempYaw < 0.0 then
		s_TempYaw = s_TempYaw + (math.pi * 2)
	end

	p_Bot.m_Player.input.authoritativeAimingYaw = s_TempYaw
	p_Bot.m_Player.input.authoritativeAimingPitch = p_Bot._TargetPitch
end

---@param p_Bot Bot
function BotMovement:UpdateStaticMovement(p_Bot)
	-- Mimicking.
	if p_Bot.m_ActiveMoveMode == BotMoveModes.Mimic and p_Bot._TargetPlayer ~= nil then
		---@type EntryInputActionEnum|integer
		for i = 0, 36 do
			p_Bot:_SetInput(i, p_Bot._TargetPlayer.input:GetLevel(i))
		end

		p_Bot._TargetYaw = p_Bot._TargetPlayer.input.authoritativeAimingYaw
		p_Bot._TargetPitch = p_Bot._TargetPlayer.input.authoritativeAimingPitch

		-- Mirroring.
	elseif p_Bot.m_ActiveMoveMode == BotMoveModes.Mirror and p_Bot._TargetPlayer ~= nil then
		---@type EntryInputActionEnum|integer
		for i = 0, 36 do
			p_Bot:_SetInput(i, p_Bot._TargetPlayer.input:GetLevel(i))
		end

		p_Bot._TargetYaw = p_Bot._TargetPlayer.input.authoritativeAimingYaw +
			(
				(p_Bot._TargetPlayer.input.authoritativeAimingYaw > math.pi) and
				-math.pi or
				math.pi
			)
		p_Bot._TargetPitch = p_Bot._TargetPlayer.input.authoritativeAimingPitch
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
---@param p_Bot Bot
function BotMovement:UpdateFollowingMovement(p_DeltaTime, p_Bot)
	if p_Bot._FollowTargetPlayer == nil or
		p_Bot._FollowTargetPlayer.id == nil or
		p_Bot._FollowTargetPlayer.alive == false or
		p_Bot._FollowTargetPlayer.soldier == nil then
		return
	end

	local s_TargetPlayer        = p_Bot._FollowTargetPlayer
	local s_BotPosition         = p_Bot.m_Player.soldier.worldTransform.trans
	local s_PlayerPosition      = s_TargetPlayer.soldier.worldTransform.trans

	-- initialize anchor if needed
	p_Bot._FollowAnchor         = p_Bot._FollowAnchor or Vec3(s_PlayerPosition.x, s_PlayerPosition.y, s_PlayerPosition.z)
	p_Bot._FollowAnchorTime     = p_Bot._FollowAnchorTime or SharedUtils:GetTime()

	local ANCHOR_TIMEOUT        = 5.0
	local PLAYER_MOVE_THRESHOLD = 3.0

	local playerMoved           = GetDistance2D(s_PlayerPosition, p_Bot._FollowAnchor) > PLAYER_MOVE_THRESHOLD
	local anchorExpired         = (SharedUtils:GetTime() - p_Bot._FollowAnchorTime) >= ANCHOR_TIMEOUT

	if playerMoved or anchorExpired then
		p_Bot._FollowAnchor = Vec3(s_PlayerPosition.x, s_PlayerPosition.y, s_PlayerPosition.z)
		p_Bot._FollowAnchorTime = SharedUtils:GetTime()
		p_Bot._FollowAngle = math.random() * 360
	end

	-- measure free space
	local freeRadius = MeasureFreeRadius(s_BotPosition)

	-- desired follow radius
	local desiredRadius = p_Bot._FollowDistance or (2.5 + math.random() * 3.0)
	local clampedRadius = math.min(desiredRadius, freeRadius - 0.3)

	local s_TargetPosition = nil

	-- Tight corridor / door snap
	local DOOR_THRESHOLD = 0.8
	if clampedRadius < DOOR_THRESHOLD then
		local plyYaw = s_TargetPlayer.input.authoritativeAimingYaw
		local back = Vec3(-math.sin(plyYaw), 0, math.cos(plyYaw))

		-- side offset so multiple bots don’t stack
		local sideOffset = 0
		if p_Bot._FollowAngle then
			sideOffset = math.cos(math.rad(p_Bot._FollowAngle)) * 0.3
		end

		s_TargetPosition = s_PlayerPosition + back * 0.9 + Vec3(sideOffset, 0, 0)
		p_Bot._FollowDistance = 0.6
	else
		local angleRad = math.rad(p_Bot._FollowAngle or math.random() * 360)
		s_TargetPosition = Vec3(
			p_Bot._FollowAnchor.x + math.cos(angleRad) * clampedRadius,
			p_Bot._FollowAnchor.y,
			p_Bot._FollowAnchor.z + math.sin(angleRad) * clampedRadius
		)
		p_Bot._FollowDistance = clampedRadius
	end

	local s_Direction = s_TargetPosition - s_BotPosition
	local s_Distance  = math.sqrt(s_Direction.x ^ 2 + s_Direction.y ^ 2 + s_Direction.z ^ 2)

	-- defensive if close
	if s_Distance <= 0.8 then
		p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
		self:UpdateFollowingDefensive(p_Bot, p_DeltaTime)
		return
	end

	if s_Distance > 0.1 then
		s_Direction.x = s_Direction.x / s_Distance
		s_Direction.y = s_Direction.y / s_Distance
		s_Direction.z = s_Direction.z / s_Distance

		-- speed
		if s_Distance > 8.0 then
			p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint
		elseif s_Distance > 3.0 then
			p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Normal
		else
			p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
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

		if canJump or math.abs(s_TargetPosition.y - s_BotPosition.y) > 1.5 or p_Bot._ObstacleSequenceTimer ~= 0 then
			p_Bot._ObstacleSequenceTimer = p_Bot._ObstacleSequenceTimer + p_DeltaTime
			p_Bot._StuckTimer = p_Bot._StuckTimer + p_DeltaTime

			-- quick jump
			if p_Bot._ObstacleSequenceTimer <= 0.2 then
				p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
				p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint
			elseif p_Bot._ObstacleSequenceTimer <= 1.0 then
				p_Bot._TargetPitch = 0
				if MathUtils:GetRandomInt(0, 1) == 1 then
					p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
				else
					p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
				end
			elseif p_Bot._ObstacleSequenceTimer <= 0.8 then
				if p_Bot._ObstacleRetryCounter == 0 then
					p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
					p_Bot:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
					p_Bot.m_ActiveWeapon = p_Bot.m_Knife
				else
					p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
				end
			end

			p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint

			if p_Bot._ObstacleSequenceTimer > 0.8 then
				p_Bot._ObstacleSequenceTimer = 0
				p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
				p_Bot._ObstacleRetryCounter = p_Bot._ObstacleRetryCounter + 1
			end

			return
		else
			-- clear obstacle state
			p_Bot._ObstacleSequenceTimer = 0
			p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
			p_Bot._ObstacleRetryCounter = 0
			p_Bot._StuckTimer = 0
		end

		-- compute yaw
		local s_AtanDzDx = math.atan(s_TargetPosition.z - s_BotPosition.z, s_TargetPosition.x - s_BotPosition.x)
		p_Bot._TargetYaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		-- alive behaviors
		self:UpdateFollowingBehaviors(p_Bot, p_DeltaTime, s_Distance)
	else
		-- defensive if in place
		p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
		self:UpdateFollowingDefensive(p_Bot, p_DeltaTime)
	end
end

---@param p_Bot Bot
---@param p_DeltaTime number
---@param p_Distance number
function BotMovement:UpdateFollowingBehaviors(p_Bot, p_DeltaTime, p_Distance)
	-- Strafing behavior
	p_Bot._FollowStrafeTimer = (p_Bot._FollowStrafeTimer or 0) + p_DeltaTime

	if p_Distance < 3.0 and p_Bot._FollowStrafeTimer > 3.0 then
		p_Bot._FollowStrafeTimer = 0.0

		-- Random strafe for variety
		if math.random() < 0.3 then
			local s_StrafeDirection = (math.random() < 0.5) and 1.0 or -1.0
			p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, s_StrafeDirection)

			-- Update follow angle
			p_Bot._FollowAngle = ((p_Bot._FollowAngle or 0) + (s_StrafeDirection * 15)) % 360
		end
	end

	-- Look around behavior
	p_Bot._FollowLookTimer = (p_Bot._FollowLookTimer or 0) + p_DeltaTime

	if p_Bot._FollowLookTimer > 5.0 then
		p_Bot._FollowLookTimer = 0.0

		-- Random look around
		if math.random() < 0.4 then
			local s_LookOffset = (math.random() - 0.5) * 1.0
			p_Bot._TargetYaw = p_Bot._TargetYaw + s_LookOffset
		end
	end
end

---@param p_Bot Bot
---@param p_DeltaTime number
function BotMovement:UpdateFollowingDefensive(p_Bot, p_DeltaTime)
	-- Defensive behaviors when in position

	-- Occasional stance changes
	if math.random() < 0.005 then
		local s_RandomPose = math.random(0, 2)
		if s_RandomPose == 0 then
			p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
		elseif s_RandomPose == 1 then
			p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
		else
			p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
		end
	end

	-- Periodic scanning
	if math.random() < 0.003 then
		local s_ScanOffset = (math.random() - 0.5) * 2.0
		p_Bot._TargetYaw = p_Bot._TargetYaw + s_ScanOffset
	end
end

if g_BotMovement == nil then
	---@type BotMovement
	g_BotMovement = BotMovement()
end

return g_BotMovement
