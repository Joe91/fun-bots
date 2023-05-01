---@class VehicleMovement
---@overload fun():VehicleMovement
VehicleMovement = class('VehicleMovement')

---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')

function VehicleMovement:__init()
	-- Nothing to do.
end

function VehicleMovement:UpdateNormalMovementVehicle(p_Bot)
	if p_Bot._VehicleTakeoffTimer > 0.0 then
		p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - Registry.BOT.BOT_UPDATE_CYCLE
		if p_Bot._JetAbortAttackActive then
			local s_TargetPosition = p_Bot.m_Player.controlledControllable.transform.trans
			local s_Forward = p_Bot.m_Player.controlledControllable.transform.forward
			s_Forward.y = 0
			s_Forward:Normalize()
			s_TargetPosition = s_TargetPosition + (s_Forward * 50)
			s_TargetPosition.y = s_TargetPosition.y + 50
			local s_Waypoint = {
				Position = s_TargetPosition,
			}
			p_Bot._TargetPoint = s_Waypoint
			return
		end
	end
	p_Bot._JetAbortAttackActive = false
	if p_Bot._VehicleWaitTimer > 0.0 then
		p_Bot._VehicleWaitTimer = p_Bot._VehicleWaitTimer - Registry.BOT.BOT_UPDATE_CYCLE
		if p_Bot._VehicleWaitTimer <= 0.0 then
			if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
				-- Check for other plane in front of bot.
				local s_IsInfront = false
				for _, l_Jet in pairs(g_GameDirector:GetSpawnableVehicle(p_Bot.m_Player.teamId)) do
					local s_DistanceToJet = p_Bot.m_Player.controlledControllable.transform.trans:Distance(l_Jet.transform.trans)
					if s_DistanceToJet < 30 then
						local s_CompPos = p_Bot.m_Player.controlledControllable.transform.trans +
							p_Bot.m_Player.controlledControllable.transform.forward * s_DistanceToJet
						if l_Jet.transform.trans:Distance(s_CompPos) < 10 then
							s_IsInfront = true
						end
					end
				end
				if s_IsInfront then
					p_Bot._VehicleWaitTimer = 5.0 -- One more cycle.
					return
				end
			end
			g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.controlledControllable.transform.trans, false)
		else
			return
		end
	end

	-- Move along points.
	if m_NodeCollection:Get(1, p_Bot._PathIndex) ~= nil then -- Check for valid point.
		-- Get next point.
		local s_ActivePointIndex = p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint)

		local s_Point = nil
		local s_NextPoint = nil
		local s_PointIncrement = 1

		s_Point = m_NodeCollection:Get(s_ActivePointIndex, p_Bot._PathIndex)

		if not p_Bot._InvertPathDirection then
			s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint + 1), p_Bot._PathIndex)
		else
			s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(p_Bot._CurrentWayPoint - 1), p_Bot._PathIndex)
		end

		-- Execute Action if needed.
		if p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
			if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
				if s_Point.Data.Action.type == 'exit' then
					p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
					local s_OnlyPassengers = false
					if s_Point.Data.Action.onlyPassengers ~= nil and s_Point.Data.Action.onlyPassengers == true then
						s_OnlyPassengers = true
					end

					-- Let all other bots exit the vehicle.
					local s_VehicleEntity = p_Bot.m_Player.controlledControllable
					if s_VehicleEntity ~= nil then
						for i = 1, (s_VehicleEntity.entryCount - 1) do
							local s_Player = s_VehicleEntity:GetPlayerInEntry(i)
							if s_Player ~= nil then
								Events:Dispatch('Bot:ExitVehicle', s_Player.name)
							end
						end
					end
					-- Exit Vehicle.
					if not s_OnlyPassengers then
						p_Bot:ExitVehicle()
					end
				elseif p_Bot._ActionTimer <= s_Point.Data.Action.time then
					for _, l_Input in pairs(s_Point.Data.Action.inputs) do
						p_Bot:_SetInput(l_Input, 1)
					end
				end
			else
				p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
			end

			p_Bot._ActionTimer = p_Bot._ActionTimer - Registry.BOT.BOT_UPDATE_CYCLE

			if p_Bot._ActionTimer <= 0.0 then
				p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
			end

			if p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
				return -- DON'T EXECUTE ANYTHING ELSE.
			else
				s_Point = s_NextPoint
			end
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- Movement.
			p_Bot._WayWaitTimer = 0.0
			p_Bot._WayWaitYawTimer = 0.0
			p_Bot.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			-- To-do: use vehicle transform also for trace?
			local s_DifferenceY = s_Point.Position.z - p_Bot.m_Player.controlledControllable.transform.trans.z
			local s_DifferenceX = s_Point.Position.x - p_Bot.m_Player.controlledControllable.transform.trans.x
			local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
			local s_HeightDistance = math.abs(s_Point.Position.y - p_Bot.m_Player.controlledControllable.transform.trans.y)

			-- Detect obstacle and move over or around.
			local s_CurrentWayPointDistance = p_Bot.m_Player.controlledControllable.transform.trans:Distance(s_Point.Position)

			if s_CurrentWayPointDistance > p_Bot._LastWayDistance + 0.02 and p_Bot._ObstacleSequenceTimer == 0 then
				-- Skip one point.
				s_DistanceFromTarget = 0
				s_HeightDistance = 0
			end

			p_Bot._TargetPoint = s_Point
			p_Bot._NextTargetPoint = s_NextPoint

			if math.abs(s_CurrentWayPointDistance - p_Bot._LastWayDistance) < 0.02 or p_Bot._ObstacleSequenceTimer ~= 0 then
				if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) or
					m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
					p_Bot._ObstacleRetryCounter = 0
					p_Bot._ObstacleSequenceTimer = 0
					s_DistanceFromTarget = 0
					s_HeightDistance = 0

					s_PointIncrement = 1
				else
					-- Try to get around obstacle.
					if p_Bot._ObstacleRetryCounter % 2 == 0 then
						if p_Bot._ObstacleSequenceTimer < 4.0 then
							p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- Full throttle.
						end
					else
						if p_Bot._ObstacleSequenceTimer < 2.0 then
							p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Backwards
						end
					end

					if (p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards and p_Bot._ObstacleSequenceTimer > 3.0) or
						(p_Bot.m_ActiveSpeedValue ~= BotMoveSpeeds.Backwards and p_Bot._ObstacleSequenceTimer > 5.0) then
						p_Bot._ObstacleSequenceTimer = 0
						p_Bot._ObstacleRetryCounter = p_Bot._ObstacleRetryCounter + 1
					end

					p_Bot._ObstacleSequenceTimer = p_Bot._ObstacleSequenceTimer + Registry.BOT.BOT_UPDATE_CYCLE

					if p_Bot._ObstacleRetryCounter >= 4 then -- Try next waypoint.
						p_Bot._ObstacleRetryCounter = 0

						s_DistanceFromTarget = 0
						s_HeightDistance = 0

						-- Teleport if stuck.
						if Config.TeleportIfStuck and
							(MathUtils:GetRandomInt(0, 100) <= Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK_IN_VEHICLE) then
							local s_Transform = p_Bot.m_Player.controlledControllable.transform:Clone()
							s_Transform.trans = p_Bot._TargetPoint.Position
							s_Transform:LookAtTransform(p_Bot._TargetPoint.Position, p_Bot._NextTargetPoint.Position)
							p_Bot.m_Player.controlledControllable.transform = s_Transform
							m_Logger:Write('teleported in vehicle of ' .. p_Bot.m_Player.name)
						else
							if MathUtils:GetRandomInt(1, 2) == 1 then
								s_PointIncrement = 1
							else
								s_PointIncrement = -1
							end
						end
					end
				end
			end

			p_Bot._LastWayDistance = s_CurrentWayPointDistance

			local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint * 5

			if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 6
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 4
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
				s_TargetDistanceSpeed = s_TargetDistanceSpeed * 3
			end

			-- Check for reached target.
			if s_DistanceFromTarget <= s_TargetDistanceSpeed and s_HeightDistance <= Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT then
				-- CHECK FOR ACTION.
				if s_Point.Data.Action ~= nil then
					local s_Action = s_Point.Data.Action

					if g_GameDirector:CheckForExecution(s_Point, p_Bot.m_Player.teamId, true) then
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
					p_Bot.m_Player.teamId, p_Bot.m_ActiveVehicle)

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

				p_Bot._ObstacleSequenceTimer = 0
				p_Bot._LastWayDistance = 1000.0
			end
		else -- Wait mode.
			p_Bot._WayWaitTimer = p_Bot._WayWaitTimer + Registry.BOT.BOT_UPDATE_CYCLE

			p_Bot:_LookAround(Registry.BOT.BOT_UPDATE_CYCLE)

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

function VehicleMovement:UpdateShootMovementVehicle(p_Bot)
	p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement -- No movement while attacking in vehicles.
end

function VehicleMovement:UpdateSpeedOfMovementVehicle(p_Bot, p_Attacking)
	if p_Bot.m_Player.soldier == nil or p_Bot._VehicleWaitTimer > 0.0 then
		return
	end

	if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
		p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
	end

	if m_Vehicles:IsNotVehicleTerrain(p_Bot.m_ActiveVehicle, VehicleTerrains.Air) then -- Air-Vehicles are handled in the yaw-function.
		-- Additional movement.
		local s_SpeedVal = 0

		if p_Bot.m_ActiveMoveMode ~= BotMoveModes.Standstill then
			-- Limit speed if full steering active.
			if p_Bot._FullVehicleSteering and p_Bot.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			end

			-- Normal values.
			if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
				s_SpeedVal = 0.25
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
				s_SpeedVal = 0.5
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Normal then
				s_SpeedVal = 0.8
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
				s_SpeedVal = 1.0
			elseif p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				s_SpeedVal = -0.7
			end

			-- Reduce speed while attacking
			if p_Attacking then
				s_SpeedVal = s_SpeedVal * Config.SpeedFactorVehicleAttack
			end
		end

		-- Movent speed.
		if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
			p_Bot:_SetInput(EntryInputActionEnum.EIABrake, -s_SpeedVal)
		elseif p_Bot.m_ActiveSpeedValue ~= BotMoveSpeeds.NoMovement then
			p_Bot._BrakeTimer = 0.7
			p_Bot:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal)
		else
			if p_Bot._BrakeTimer > 0.0 then
				p_Bot:_SetInput(EntryInputActionEnum.EIABrake, 1)
			end

			p_Bot._BrakeTimer = p_Bot._BrakeTimer - Registry.BOT.BOT_UPDATE_CYCLE
		end
	end
end

function VehicleMovement:UpdateTargetMovementVehicle(p_Bot)
	if p_Bot._TargetPoint ~= nil then
		local s_Distance = p_Bot.m_Player.controlledControllable.transform.trans:Distance(p_Bot._TargetPoint.Position)

		if s_Distance < 3.0 then
			p_Bot._TargetPoint = p_Bot._NextTargetPoint
		end

		local s_DifferenceY = p_Bot._TargetPoint.Position.z - p_Bot.m_Player.controlledControllable.transform.trans.z
		local s_DifferenceX = p_Bot._TargetPoint.Position.x - p_Bot.m_Player.controlledControllable.transform.trans.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		p_Bot._TargetYaw = s_Yaw
		p_Bot._TargetYawMovementVehicle = s_Yaw
	end
end

---@param p_DeltaTime number
function VehicleMovement:UpdateVehicleLookAround(p_Bot, p_DeltaTime)
	-- Move around a little.
	if p_Bot._VehicleMovableId >= 0 then
		local s_Pos = p_Bot.m_Player.controlledControllable.transform.forward
		local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
		p_Bot._TargetYaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		p_Bot._TargetPitch = 0.0

		p_Bot._VehicleWaitTimer = p_Bot._VehicleWaitTimer + p_DeltaTime

		if p_Bot._VehicleWaitTimer > 9.0 then
			p_Bot._VehicleWaitTimer = 0.0
		elseif p_Bot._VehicleWaitTimer >= 6.0 then
		elseif p_Bot._VehicleWaitTimer >= 3.0 then
			p_Bot._TargetYaw = p_Bot._TargetYaw - 1.0 -- 60° rotation left.
			p_Bot._TargetPitch = 0.5

			if p_Bot._TargetYaw < 0.0 then
				p_Bot._TargetYaw = p_Bot._TargetYaw + (2 * math.pi)
			end
		elseif p_Bot._VehicleWaitTimer >= 0.0 then
			p_Bot._TargetYaw = p_Bot._TargetYaw + 1.0 -- 60° rotation right.
			p_Bot._TargetPitch = -0.5

			if p_Bot._TargetYaw > (math.pi * 2) then
				p_Bot._TargetYaw = p_Bot._TargetYaw - (2 * math.pi)
			end
		end
	end
end

---@param p_Attacking boolean
function VehicleMovement:UpdateYawVehicle(p_Bot, p_Attacking, p_IsStationaryLauncher)
	local s_DeltaYaw = 0
	local s_DeltaPitch = 0
	local s_CorrectGunYaw = false

	local s_Pos = nil

	if not p_Attacking then
		if p_Bot.m_Player.controlledEntryId == 0 and not p_IsStationaryLauncher then
			s_Pos = p_Bot.m_Player.controlledControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			s_DeltaYaw = s_Yaw - p_Bot._TargetYaw

			if p_Bot._VehicleMovableId >= 0 then
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, 0)
				local s_DiffPos = s_Pos -
					p_Bot.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):ToLinearTransform()
					.forward
				-- Prepare for moving gun back.
				p_Bot._LastVehicleYaw = s_Yaw

				if math.abs(s_DiffPos.x) > 0.08 or math.abs(s_DiffPos.z) > 0.08 then
					s_CorrectGunYaw = true
				end
			end
		else -- Passenger.
			if p_Bot._VehicleMovableId >= 0 then
				s_Pos = p_Bot.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):
				ToLinearTransform().forward
				local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
				local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
				local s_Pitch = math.asin(s_Pos.y / 1.0)
				s_DeltaPitch = s_Pitch - p_Bot._TargetPitch
				s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
			end
		end
	else
		if p_Bot._VehicleMovableId >= 0 then
			s_Pos = p_Bot.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):
			ToLinearTransform().forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			local s_Pitch = math.asin(s_Pos.y / 1.0)
			s_DeltaPitch = s_Pitch - p_Bot._TargetPitch
			s_DeltaYaw = s_Yaw - p_Bot._TargetYaw

			-- Detect direction for moving gun back.
			local s_GunDeltaYaw = s_Yaw - p_Bot._LastVehicleYaw

			if s_GunDeltaYaw > math.pi then
				s_GunDeltaYaw = s_GunDeltaYaw - 2 * math.pi
			elseif s_GunDeltaYaw < -math.pi then
				s_GunDeltaYaw = s_GunDeltaYaw + 2 * math.pi
			end

			if s_GunDeltaYaw > 0 then
				p_Bot._VehicleDirBackPositive = false
			else
				p_Bot._VehicleDirBackPositive = true
			end
		elseif (
				m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) and p_Bot.m_Player.controlledEntryId == 0) or
			m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
			s_Pos = p_Bot.m_Player.controlledControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			local s_Pitch = math.asin(s_Pos.y / 1.0)
			s_DeltaPitch = s_Pitch - p_Bot._TargetPitch
			s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
		end
	end

	if s_DeltaYaw > (math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw - 2 * math.pi
	elseif s_DeltaYaw < -(math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw + 2 * math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_AbsDeltaPitch = math.abs(s_DeltaPitch)

	p_Bot.m_Player.input.authoritativeAimingYaw = p_Bot._TargetYaw -- Always set yaw to let the FOV work.

	local s_TargetRangeForShooting = 0.10
	if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
		s_TargetRangeForShooting = 0.20
	end
	if s_AbsDeltaYaw < s_TargetRangeForShooting then
		p_Bot._FullVehicleSteering = false
		if p_Attacking and s_AbsDeltaPitch < s_TargetRangeForShooting then
			p_Bot._VehicleReadyToShoot = true
		end
	else
		p_Bot._FullVehicleSteering = true
		p_Bot._VehicleReadyToShoot = false
	end

	-- Chopper driver handling here.
	if p_Bot.m_Player.controlledEntryId == 0 and m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) then
		if p_Bot._VehicleWaitTimer > 0.0 then
			return
		end
		if not p_Attacking and (p_Bot._TargetPoint == nil or p_Bot._NextTargetPoint == nil) then
			return
		end
		if p_Bot.m_Player.controlledControllable == nil then
			return
		end

		-- YAW
		local s_Output_Yaw = p_Bot._Pid_Drv_Yaw:Update(s_DeltaYaw)
		-- No backwards in chopper.
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output_Yaw)

		-- HEIGHT
		local s_Delta_Height = 0.0
		if p_Attacking then
			s_Delta_Height = p_Bot._TargetHeightAttack - p_Bot.m_Player.controlledControllable.transform.trans.y
		else
			p_Bot._TargetHeightAttack = p_Bot._TargetPoint.Position.y
			s_Delta_Height = p_Bot._TargetPoint.Position.y - p_Bot.m_Player.controlledControllable.transform.trans.y
		end
		local s_Output_Throttle = p_Bot._Pid_Drv_Throttle:Update(s_Delta_Height)
		if s_Output_Throttle > 0 then
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
		else
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
		end

		-- FORWARD (depending on speed).
		-- A: use distance horizontally between points for speed-value → not that good for that.
		-- local DeltaX = p_Bot._NextTargetPoint.Position.x - p_Bot._TargetPoint.Position.x
		-- local DeltaZ = p_Bot._NextTargetPoint.Position.z - p_Bot._TargetPoint.Position.z
		-- local Distance = math.sqrt(DeltaX*DeltaX + DeltaZ*DeltaZ)
		-- B: just fly with constant speed →

		local s_Delta_Tilt = 0
		if p_Attacking then
			s_Delta_Tilt = -s_DeltaPitch
		else
			local s_Tartget_Tilt = -0.35 -- = 20°
			local s_Current_Tilt = math.asin(p_Bot.m_Player.controlledControllable.transform.forward.y / 1.0)
			s_Delta_Tilt = s_Tartget_Tilt - s_Current_Tilt
		end

		local s_Output_Tilt = p_Bot._Pid_Drv_Tilt:Update(s_Delta_Tilt)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output_Tilt)

		-- ROLL (keep it zero).
		local s_Tartget_Roll = 0.0
		-- To-do: in strong steering: Roll a little?
		-- if p_Bot._FullVehicleSteering then
		-- 	if s_AbsDeltaYaw > 0 then
		-- 		s_Tartget_Roll = 0.1
		-- 	else
		-- 		s_Tartget_Roll = -0.1
		-- 	end
		-- end

		local s_Current_Roll = math.asin(p_Bot.m_Player.controlledControllable.transform.left.y / 1.0)
		local s_Delta_Roll = s_Tartget_Roll - s_Current_Roll
		local s_Output_Roll = p_Bot._Pid_Drv_Roll:Update(s_Delta_Roll)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, s_Output_Roll)

		return -- Don't do anything else.

		-- Jet driver handling here.
	elseif m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
		if p_Bot._VehicleWaitTimer > 0.0 then
			return
		end
		if not p_Attacking and (p_Bot._TargetPoint == nil or p_Bot._NextTargetPoint == nil) then
			return
		end
		if p_Bot.m_Player.controlledControllable == nil then
			return
		end

		-- Calculate delta pitch.
		local s_Delta_Tilt = 0
		local s_Current_Tilt = math.asin(p_Bot.m_Player.controlledControllable.transform.forward.y / 1.0)

		if p_Attacking then
			s_Delta_Tilt = -s_DeltaPitch
		else
			-- To-do: use angle between two nodes?

			local s_Delta_Height = p_Bot._TargetPoint.Position.y - p_Bot.m_Player.controlledControllable.transform.trans.y

			local s_Tartget_Tilt = 0.0
			local s_Abs_Delta_Height = math.abs(s_Delta_Height)
			s_Tartget_Tilt = 0.6 * s_Abs_Delta_Height / 10 -- 45°=0.785 rad
			local s_LimitTilt = 0.5
			if s_Tartget_Tilt > s_LimitTilt then
				s_Tartget_Tilt = s_LimitTilt
			end
			if s_Delta_Height < 0 then
				s_Tartget_Tilt = -s_Tartget_Tilt
			end

			s_Delta_Tilt = s_Tartget_Tilt - s_Current_Tilt -- Inverted tilt.
			if s_Delta_Tilt > math.pi then
				s_Delta_Tilt = s_Delta_Tilt - 2 * math.pi
			elseif s_Delta_Tilt < -math.pi then
				s_Delta_Tilt = s_Delta_Tilt + 2 * math.pi
			end
		end

		-- Calculate angle for roll.
		local s_Target_Roll = 0
		s_Target_Roll = 1.57 * -s_DeltaYaw / 1.0 -- Full roll on 60°
		local s_LimitRoll = 1.57
		if s_Target_Roll > s_LimitRoll then -- 80° = 1.4. 60° = 1.0
			s_Target_Roll = s_LimitRoll
		elseif s_Target_Roll < -s_LimitRoll then
			s_Target_Roll = -s_LimitRoll
		end

		local s_Current_Roll = 0
		if p_Bot.m_Player.controlledControllable.transform.up.y > 0 then
			local s_ProjectedY = p_Bot.m_Player.controlledControllable.transform.left.y / math.cos(s_Current_Tilt)
			s_Current_Roll = math.asin(s_ProjectedY / 1.0)
		elseif p_Bot.m_Player.controlledControllable.transform.up.y < 0 then
			local s_ProjectedY = p_Bot.m_Player.controlledControllable.transform.up.y / math.cos(s_Current_Tilt)
			s_Current_Roll = math.asin(s_ProjectedY / 1.0) - math.pi / 2
			if s_Current_Roll < -2 * math.pi then
				s_Current_Roll = s_Current_Roll + 2 * math.pi
			end
		end

		local s_Delta_Roll = s_Target_Roll - s_Current_Roll
		if s_Delta_Roll > math.pi then
			s_Delta_Roll = s_Delta_Roll - 2 * math.pi
		elseif s_Delta_Roll < -math.pi then
			s_Delta_Roll = s_Delta_Roll + 2 * math.pi
		end
		local s_Output_Roll = p_Bot._Pid_Drv_Roll:Update(s_Delta_Roll)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, s_Output_Roll)

		-- Trasform tilt and yaw to rotation of roll.
		local s_TransformedInputYaw = math.cos(s_Current_Roll) * s_DeltaYaw + math.sin(s_Current_Roll) * s_Delta_Tilt
		local s_TransformedInputTilt = math.cos(s_Current_Roll) * s_Delta_Tilt - math.sin(s_Current_Roll) * s_DeltaYaw

		local s_Output_Tilt = p_Bot._Pid_Drv_Tilt:Update(s_TransformedInputTilt)
		local s_Output_Yaw = p_Bot._Pid_Drv_Yaw:Update(s_TransformedInputYaw)

		-- TILT
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output_Tilt)

		-- YAW
		-- No backwards in planes.
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output_Yaw)

		-- Throttle.
		-- Target velocity == 313 km/h → 86.9444 m/s
		local s_Delta_Speed = 86.9444 - PhysicsEntity(p_Bot.m_Player.controlledControllable).velocity.magnitude
		local s_Output_Throttle = p_Bot._Pid_Drv_Throttle:Update(s_Delta_Speed)
		if s_Output_Throttle > 0 then
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, s_Output_Throttle)
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, 0.0)
		else
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0.0)
			p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIABrake, -s_Output_Throttle)
		end

		return -- Don't do anything else.
	end

	if not p_Attacking then
		if p_Bot.m_Player.controlledEntryId == 0 and not p_IsStationaryLauncher then -- Driver.
			local s_Output = p_Bot._Pid_Drv_Yaw:Update(s_DeltaYaw)

			if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, s_Output)
			else
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output)
			end

			if s_CorrectGunYaw then
				if p_Bot._VehicleDirBackPositive then
					p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 1)
				else
					p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -1)
				end
			else
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 0)
			end
		else -- Passenger.
			if p_Bot._VehicleMovableId >= 0 then
				local s_Output = p_Bot._Pid_Att_Yaw:Update(s_DeltaYaw)
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -s_Output)

				local s_Output = p_Bot._Pid_Att_Pitch:Update(s_DeltaPitch)
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output)
			end
		end
	else -- Attacking.
		-- Yaw
		local s_Output = p_Bot._Pid_Att_Yaw:Update(s_DeltaYaw)
		if Config.VehicleMoveWhileShooting and p_Bot.m_Player.controlledEntryId == 0 and not p_IsStationaryLauncher then -- Driver.
			s_Pos = p_Bot.m_Player.controlledControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			local s_DeltaYawDriving = s_Yaw - p_Bot._TargetYawMovementVehicle

			if s_DeltaYawDriving > (math.pi + 0.2) then
				s_DeltaYawDriving = s_DeltaYawDriving - 2 * math.pi
			elseif s_DeltaYawDriving < -(math.pi + 0.2) then
				s_DeltaYawDriving = s_DeltaYawDriving + 2 * math.pi
			end

			local s_OutputDriving = p_Bot._Pid_Drv_Yaw:Update(s_DeltaYawDriving)

			if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, s_OutputDriving)
			else
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_OutputDriving)
			end
		else
			if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA) then
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output) -- Doubles the output of stationary AA → faster turret.
			else
				p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0)
			end
		end

		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -s_Output)
		-- p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIACameraYaw, -s_Output)

		-- Pitch.
		local s_Output = p_Bot._Pid_Att_Pitch:Update(s_DeltaPitch)
		p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output)
		-- p_Bot.m_Player.input:SetLevel(EntryInputActionEnum.EIACameraPitch, -s_Output)
	end
end

if g_VehicleMovement == nil then
	---@type VehicleMovement
	g_VehicleMovement = VehicleMovement()
end

return g_VehicleMovement
