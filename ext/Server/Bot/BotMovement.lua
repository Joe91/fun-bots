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

function BotMovement:UpdateNormalMovement(p_Bot)
	-- Move along points.
	p_Bot._AttackModeMoveTimer = 0.0

	if m_NodeCollection:Get(1, p_Bot._PathIndex) ~= nil then -- Check for valid point.
		-- Get next point.
		local s_ActivePointIndex = p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint)

		local s_Point = nil
		local s_NextPoint = nil
		local s_PointIncrement = 1
		local s_NoStuckReset = false
		local s_UseShootWayPoint = false

		if #p_Bot._ShootWayPoints > 0 then -- We need to go back to path first.
			s_Point = p_Bot._ShootWayPoints[#p_Bot._ShootWayPoints]
			s_NextPoint = p_Bot._ShootWayPoints[#p_Bot._ShootWayPoints - 1]

			if s_NextPoint == nil then
				s_NextPoint = m_NodeCollection:Get(s_ActivePointIndex, p_Bot._PathIndex)

				--[[if Config.DebugTracePaths then
					NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', p_Bot._PathIndex, s_ActivePointIndex, p_Bot.m_Player.soldier.worldTransform.trans, (p_Bot._ObstaceSequenceTimer > 0.0), "Blue")
				end--]]
			end

			s_UseShootWayPoint = true
		else
			s_Point = m_NodeCollection:Get(s_ActivePointIndex, p_Bot._PathIndex)

			if not p_Bot._InvertPathDirection then
				s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint + 1), p_Bot._PathIndex)

			--[[if Config.DebugTracePaths then
					NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', p_Bot._PathIndex, p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint + 1), p_Bot.m_Player.soldier.worldTransform.trans, (p_Bot._ObstaceSequenceTimer > 0.0), "Green")
				end--]]
			else
				s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint - 1), p_Bot._PathIndex)

				--[[if Config.DebugTracePaths then
					NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', p_Bot._PathIndex, p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint - 1), p_Bot.m_Player.soldier.worldTransform.trans, (p_Bot._ObstaceSequenceTimer > 0.0), "Green")
				end--]]
			end
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			p_Bot._WayWaitTimer = 0.0
			p_Bot._WayWaitYawTimer = 0.0
			p_Bot.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			-- Zombie-Mode:
			-- TODO: Zombies: add more variation in speed
			if p_Bot._ZombieSpeedValue == BotMoveSpeeds.NoMovement then
				local zombieValue = MathUtils:GetRandomInt(0, 2)
				if zombieValue == 0 then
					p_Bot._ZombieSpeedValue = BotMoveSpeeds.SlowCrouch
				elseif zombieValue == 1 then
					p_Bot._ZombieSpeedValue = BotMoveSpeeds.VerySlowProne
				else
					p_Bot._ZombieSpeedValue = BotMoveSpeeds.Normal
				end
			end

			p_Bot.m_ActiveSpeedValue = p_Bot._ZombieSpeedValue

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
				p_Bot._SidewardsTimer = p_Bot._SidewardsTimer - Registry.BOT.BOT_UPDATE_CYCLE
			end

			local s_DifferenceY = s_Point.Position.z - p_Bot.m_Player.soldier.worldTransform.trans.z
			local s_DifferenceX = s_Point.Position.x - p_Bot.m_Player.soldier.worldTransform.trans.x
			local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
			local s_HeightDistance = math.abs(s_Point.Position.y - p_Bot.m_Player.soldier.worldTransform.trans.y)

			-- Detect obstacle and move over or around. To-do: Move before normal jump.
			local s_CurrentWayPointDistance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)

			if s_CurrentWayPointDistance > p_Bot._LastWayDistance + 0.02 and p_Bot._ObstaceSequenceTimer == 0 then
				-- Skip one point.
				s_DistanceFromTarget = 0
				s_HeightDistance = 0
			end

			p_Bot._TargetPoint = s_Point
			p_Bot._NextTargetPoint = s_NextPoint

			if math.abs(s_CurrentWayPointDistance - p_Bot._LastWayDistance) < 0.02 or p_Bot._ObstaceSequenceTimer ~= 0 then
				-- Try to get around obstacle.
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Always try to stand.

				if p_Bot._ObstaceSequenceTimer == 0 then -- Step 0
				elseif p_Bot._ObstaceSequenceTimer > 2.4 then -- Step 4 - repeat afterwards.
					p_Bot._ObstaceSequenceTimer = 0.0
					p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
					p_Bot._ObstacleRetryCounter = p_Bot._ObstacleRetryCounter + 1
				elseif p_Bot._ObstaceSequenceTimer > 1.0 then -- Step 3
					if not p_Bot.m_InVehicle then
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
					end
				elseif p_Bot._ObstaceSequenceTimer > 0.4 then -- Step 2
					p_Bot._TargetPitch = 0.0

					if (MathUtils:GetRandomInt(0, 1) == 1) then
						p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
					else
						p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
					end
				elseif p_Bot._ObstaceSequenceTimer > 0.0 then -- Step 1
					p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
				end

				p_Bot._ObstaceSequenceTimer = p_Bot._ObstaceSequenceTimer + Registry.BOT.BOT_UPDATE_CYCLE
				p_Bot._StuckTimer = p_Bot._StuckTimer + Registry.BOT.BOT_UPDATE_CYCLE

				if p_Bot._ObstacleRetryCounter >= 2 then -- Try next waypoint.
					p_Bot._ObstacleRetryCounter = 0
					p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
					s_DistanceFromTarget = 0
					s_HeightDistance = 0

					-- Teleport to target.
					s_NoStuckReset = true
					if Config.TeleportIfStuck and (MathUtils:GetRandomInt(0, 100) <= Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK) then
						local s_Transform = p_Bot.m_Player.soldier.worldTransform:Clone()
						s_Transform.trans = p_Bot._TargetPoint.Position
						s_Transform:LookAtTransform(p_Bot._TargetPoint.Position, p_Bot._NextTargetPoint.Position)
						p_Bot.m_Player.soldier:SetTransform(s_Transform)
						m_Logger:Write('teleported ' .. p_Bot.m_Player.name)
					else
						if not p_Bot.m_InVehicle then
							s_PointIncrement = MathUtils:GetRandomInt(-5, 5) -- Go 5 points further.
							-- Experimental.
							if s_PointIncrement == 0 then -- We can't have this.
								s_PointIncrement = -2 -- Go backwards and try again.
							end

							if (Globals.IsConquest or Globals.IsRush) then
								if g_GameDirector:IsOnObjectivePath(p_Bot._PathIndex) then
									p_Bot._InvertPathDirection = (
										MathUtils:GetRandomInt(0, 100) <= Registry.BOT.PROBABILITY_CHANGE_DIRECTION_IF_STUCK)
								end
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
			if p_Bot._ObstaceSequenceTimer == 0 then
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

				if not s_UseShootWayPoint then
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
					s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(p_Bot.m_Name, s_Point, p_Bot._Objective, p_Bot.m_InVehicle,
						p_Bot.m_Player.teamId, nil)

					if p_Bot.m_Player.soldier == nil then
						return
					end

					if s_SwitchPath == true and not p_Bot._OnSwitch then
						if p_Bot._Objective ~= '' then
							-- 'Best' direction for objective on switch.
							local s_Direction = m_NodeCollection:ObjectiveDirection(s_NewWaypoint, p_Bot._Objective, p_Bot.m_InVehicle)
							p_Bot._InvertPathDirection = (s_Direction == 'Previous')
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
				else
					for i = 1, s_PointIncrement do -- One already gets removed on start of way finding.
						table.remove(p_Bot._ShootWayPoints)
					end
				end

				p_Bot._ObstaceSequenceTimer = 0.0
				p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
				p_Bot._LastWayDistance = 1000.0
			end
		else -- Wait mode.
			p_Bot._WayWaitTimer = p_Bot._WayWaitTimer + Registry.BOT.BOT_UPDATE_CYCLE

			self:LookAround(p_Bot, Registry.BOT.BOT_UPDATE_CYCLE)

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

function BotMovement:UpdateMovementSprintToTarget(p_Bot)
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
		p_Bot._AttackModeMoveTimer = p_Bot._AttackModeMoveTimer + Registry.BOT.BOT_UPDATE_CYCLE

		if p_Bot._AttackModeMoveTimer > 3.0 then
			p_Bot._AttackModeMoveTimer = 0.0
		elseif p_Bot._AttackModeMoveTimer > 2.5 then
			p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
			p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
		end
	end
end

function BotMovement:UpdateShootMovement(p_Bot)

	local s_TargetCycles = 1
	p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Run towards player.


	if Config.OverWriteBotAttackMode ~= BotMoveSpeeds.NoMovement then
		p_Bot.m_ActiveSpeedValue = Config.OverWriteBotAttackMode
	end

	if #p_Bot._ShootWayPoints > s_TargetCycles and Config.JumpWhileShooting then
		local s_DistanceDone = p_Bot._ShootWayPoints[#p_Bot._ShootWayPoints].Position:Distance(p_Bot._ShootWayPoints[
			#p_Bot._ShootWayPoints - s_TargetCycles].Position)
		if s_DistanceDone < 0.5 then -- No movement was possible. Try to jump over an obstacle.
			p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Normal
			p_Bot:_SetInput(EntryInputActionEnum.EIAJump, 1)
			p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
		end
	end

	-- Do some sidewards movement from time to time.
	if p_Bot._AttackModeMoveTimer > 20.0 then
		p_Bot._AttackModeMoveTimer = 0.0
	elseif p_Bot._AttackModeMoveTimer > 17.0 then
		p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, -0.5 * Config.SpeedFactorAttack)
	elseif p_Bot._AttackModeMoveTimer > 12.0 and p_Bot._AttackModeMoveTimer <= 13.0 then
		p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
	elseif p_Bot._AttackModeMoveTimer > 7.0 and p_Bot._AttackModeMoveTimer <= 9.0 then
		p_Bot:_SetInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
	end

	p_Bot._AttackModeMoveTimer = p_Bot._AttackModeMoveTimer + Registry.BOT.BOT_UPDATE_CYCLE

end

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

	-- Movent speed.
	if p_Bot.m_ActiveSpeedValue ~= BotMoveSpeeds.Sprint then
		p_Bot:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal * p_Bot._SpeedFactorMovement)
	else -- use full speed for sprinting
		p_Bot:_SetInput(EntryInputActionEnum.EIAThrottle, 1)
		p_Bot:_SetInput(EntryInputActionEnum.EIASprint, s_SpeedVal) -- * Config.SpeedFactor
	end
end

function BotMovement:UpdateTargetMovement(p_Bot)
	if p_Bot._TargetPoint ~= nil then
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

if g_BotMovement == nil then
	---@type BotMovement
	g_BotMovement = BotMovement()
end

return g_BotMovement
