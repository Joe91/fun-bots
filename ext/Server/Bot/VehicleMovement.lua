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

-- Obstacle detection of ground vehicles.
local VEHICLE_OBSTACLE_STANDSTILL_SPEED = 0.8     -- Horizontal m/s below which the vehicle counts as standing.
local VEHICLE_OBSTACLE_STANDSTILL_TIME = 1.5      -- Seconds of standstill before the obstacle-sequence starts.
local VEHICLE_OBSTACLE_RESOLVED_PROGRESS = 3.0    -- Meters closer to the target than at the start of the sequence.

function VehicleMovement:__init()
	-- Nothing to do.
end

---Detects a standing ground vehicle. A short standstill (starting, turning on the spot) is no obstacle.
---@param p_Bot Bot
---@param p_Vehicle ControllableEntity
---@param p_Distance number distance to the target point
---@param p_DeltaTime number
---@return boolean true if the obstacle-sequence has to start
function VehicleMovement:_DetectObstacle(p_Bot, p_Vehicle, p_Distance, p_DeltaTime)
	local s_Velocity = PhysicsEntity(p_Vehicle).velocity
	local s_Speed = math.sqrt(s_Velocity.x * s_Velocity.x + s_Velocity.z * s_Velocity.z)

	if s_Speed < VEHICLE_OBSTACLE_STANDSTILL_SPEED then
		p_Bot._LowSpeedTimer = p_Bot._LowSpeedTimer + p_DeltaTime
	else
		p_Bot._LowSpeedTimer = 0.0
	end

	if p_Bot._LowSpeedTimer >= VEHICLE_OBSTACLE_STANDSTILL_TIME then
		p_Bot._LowSpeedTimer = 0.0
		p_Bot._ObstacleStartDistance = p_Distance
		return true
	end

	return false
end

---@param p_DeltaTime number
---@param p_Bot Bot
function VehicleMovement:UpdateNormalMovementVehicle(p_DeltaTime, p_Bot)
	if p_Bot._VehicleWaitTimer > 0.0 then
		p_Bot._VehicleWaitTimer = p_Bot._VehicleWaitTimer - p_DeltaTime
		if p_Bot._VehicleWaitTimer <= 0.0 then
			g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.controlledControllable.transform.trans:Clone(), false)
		else
			return
		end
	end

	if p_Bot._VehicleTakeoffTimer > 0.0 then
		p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - p_DeltaTime
	end


	-- Move along points.
	if m_NodeCollection:Get(1, p_Bot._PathIndex) ~= nil then -- Check for valid point.
		-- Get next point.
		local s_ActivePointIndex = p_Bot:_GetWayIndex(0)

		local s_Point = nil
		local s_NextPoint = nil
		local s_PointIncrement = 1

		s_Point = m_NodeCollection:Get(s_ActivePointIndex, p_Bot._PathIndex)

		if not p_Bot._InvertPathDirection then
			s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(1), p_Bot._PathIndex)
		else
			s_NextPoint = m_NodeCollection:Get(p_Bot:_GetWayIndex(-1), p_Bot._PathIndex)
		end

		if s_Point == nil then
			return
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
							local s_IsPassenger = m_Vehicles:IsPassengerSeat(p_Bot.m_ActiveVehicle, i)
							local s_ShouldExit = not s_OnlyPassengers or s_IsPassenger

							if s_ShouldExit and s_Player ~= nil then
								Events:Dispatch('Bot:ExitVehicle', s_Player.id)
							end
						end
					end
					-- Exit Vehicle.
					if not s_OnlyPassengers then
						p_Bot:ExitVehicle()
					end
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
			p_Bot.m_ActiveSpeedValue = s_Point.SpeedMode -- Speed.

			-- To-do: use vehicle transform also for trace?
			local s_Vehicle = p_Bot.m_Player.controlledControllable
			local s_VehiclePos = s_Vehicle.transform.trans
			local s_DifferenceY = s_Point.Position.z - s_VehiclePos.z
			local s_DifferenceX = s_Point.Position.x - s_VehiclePos.x
			local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
			local s_HeightDistance = math.abs(s_Point.Position.y - s_VehiclePos.y)
			local s_StuckSkip = false

			-- Detect obstacle and move over or around.
			local s_CurrentWayPointDistance = s_VehiclePos:Distance(s_Point.Position)

			if s_CurrentWayPointDistance > p_Bot._LastWayDistance + 0.02 and p_Bot._ObstacleSequenceTimer == 0 then
				-- Skip one point.
				s_DistanceFromTarget = 0
				s_HeightDistance = 0
			end

			p_Bot._TargetPoint = s_Point
			p_Bot._NextTargetPoint = s_NextPoint

			if m_Vehicles:IsAirVehicle(p_Bot.m_ActiveVehicle) then
				if math.abs(s_CurrentWayPointDistance - p_Bot._LastWayDistance) < 0.02 or p_Bot._ObstacleSequenceTimer ~= 0 then
					p_Bot._ObstacleRetryCounter = 0
					p_Bot._ObstacleSequenceTimer = 0
					s_DistanceFromTarget = 0
					s_HeightDistance = 0

					s_PointIncrement = 1
				end
			elseif p_Bot._ObstacleSequenceTimer ~= 0 or self:_DetectObstacle(p_Bot, s_Vehicle, s_CurrentWayPointDistance, p_DeltaTime) then
				if p_Bot._ObstacleRetryCounter % 2 == 0 and
					s_CurrentWayPointDistance < p_Bot._ObstacleStartDistance - VEHICLE_OBSTACLE_RESOLVED_PROGRESS then
					-- Got along again (checked while driving forward, reversing increases the distance).
					-- The retry-counter is kept, so a vehicle that gets stuck at the same spot again still escalates.
					p_Bot._ObstacleSequenceTimer = 0
					p_Bot._LowSpeedTimer = 0.0
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

					p_Bot._ObstacleSequenceTimer = p_Bot._ObstacleSequenceTimer + p_DeltaTime
					p_Bot._StuckTimer = p_Bot._StuckTimer + p_DeltaTime

					if p_Bot._StuckTimer > Registry.BOT.VEHICLE_STUCK_EXIT_TIME then
						-- Nothing helped (flipped, stuck in terrain, ...): continue on foot.
						m_Logger:Write(p_Bot.m_Player.name .. ' got stuck in vehicle. Exit')
						p_Bot:ExitVehicle()
						return
					end

					if p_Bot._ObstacleRetryCounter >= 4 then -- Try next waypoint.
						p_Bot._ObstacleRetryCounter = 0
						s_StuckSkip = true

						s_DistanceFromTarget = 0
						s_HeightDistance = 0

						-- Teleport if stuck.
						if Config.TeleportIfStuck and
							m_Utilities:CheckProbability(Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK_IN_VEHICLE) then
							local s_Transform = s_Vehicle.transform:Clone()
							s_Transform.trans = p_Bot._TargetPoint.Position
							if p_Bot._NextTargetPoint then
								s_Transform:LookAtTransform(p_Bot._TargetPoint.Position, p_Bot._NextTargetPoint.Position)
							end
							s_Vehicle.transform = s_Transform
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

			if m_Vehicles:IsAirVehicle(p_Bot.m_ActiveVehicle) then
				s_TargetDistanceSpeed = Config.TargetDistanceWayPointAirVehicles
			end

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
				---@type Waypoint|nil
				local s_NewWaypoint = nil
				local s_SwitchPath = false
				s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(p_Bot, p_Bot.m_Id, s_Point, p_Bot._Objective, true,
					p_Bot.m_Player.teamId, p_Bot.m_ActiveVehicle)

				if p_Bot.m_Player.soldier == nil then
					return
				end

				if s_SwitchPath == true and not p_Bot._OnSwitch and s_NewWaypoint then
					if p_Bot._Objective ~= '' then
						-- 'Best' direction for objective on switch.
						local s_Direction = m_NodeCollection:ObjectiveDirection(s_NewWaypoint, p_Bot._Objective, true)
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

				if not s_StuckSkip then
					p_Bot._StuckTimer = 0.0
					p_Bot._ObstacleRetryCounter = 0
				end
				p_Bot._ObstacleSequenceTimer = 0
				p_Bot._LowSpeedTimer = 0.0
				p_Bot._LastWayDistance = 1000.0
			end
		else -- Wait mode.
			p_Bot._WayWaitTimer = p_Bot._WayWaitTimer + p_DeltaTime
			p_Bot._LowSpeedTimer = 0.0

			self:UpdateVehicleLookAround(p_Bot, p_DeltaTime)

			if p_Bot._WayWaitTimer > s_Point.OptValue then
				p_Bot._WayWaitTimer = 0.0

				if p_Bot._InvertPathDirection then
					p_Bot._CurrentWayPoint = s_ActivePointIndex - 1
				else
					p_Bot._CurrentWayPoint = s_ActivePointIndex + 1
				end
			end
		end
	end
end

---@param p_Bot Bot
function VehicleMovement:UpdateShootMovementVehicle(p_Bot)
	p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement -- No movement while attacking in vehicles.
end

---@param p_DeltaTime number
---@param p_Bot Bot
---@param p_Attacking boolean
function VehicleMovement:UpdateSpeedOfMovementVehicle(p_DeltaTime, p_Bot, p_Attacking)
	if p_Bot._VehicleWaitTimer > 0.0 then
		return
	end
	local s_Soldier = p_Bot.m_Player.soldier
	if s_Soldier == nil then
		return
	end

	if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
		s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
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

			p_Bot._BrakeTimer = p_Bot._BrakeTimer - p_DeltaTime
		end
	end
end

---@param p_Bot Bot
function VehicleMovement:UpdateTargetMovementVehicle(p_Bot, p_DeltaTime)
	if p_Bot._TargetPoint ~= nil then
		local s_VehiclePos = p_Bot.m_Player.controlledControllable.transform.trans
		local s_Distance = s_VehiclePos:Distance(p_Bot._TargetPoint.Position)

		if s_Distance < 3.0 then
			p_Bot._TargetPoint = p_Bot._NextTargetPoint

			if p_Bot._TargetPoint == nil then
				return
			end
		end

		local s_TargetPos = p_Bot._TargetPoint.Position
		local s_DifferenceY = s_TargetPos.z - s_VehiclePos.z
		local s_DifferenceX = s_TargetPos.x - s_VehiclePos.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		p_Bot._TargetYaw = s_Yaw
		p_Bot._TargetYawMovementVehicle = s_Yaw
	end
end

---@param p_Bot Bot
---@param p_DeltaTime number
function VehicleMovement:UpdateVehicleLookAround(p_Bot, p_DeltaTime)
	-- Move around a little.
	if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Gunship) then
		p_Bot._VehicleLookAroundTimer = p_Bot._VehicleLookAroundTimer + p_DeltaTime

		local s_TargetPosition = p_Bot.m_Player.controlledControllable.transform.trans:Clone()
		local s_Forward = p_Bot.m_Player.controlledControllable.transform.left:Clone()
		s_TargetPosition = s_TargetPosition + (s_Forward * 100)
		s_TargetPosition.y = s_TargetPosition.y - 50
		local s_Waypoint = {
			Position = s_TargetPosition,
		}

		p_Bot._TargetPoint = s_Waypoint
	else
		if p_Bot._VehicleMovableId >= 0 then
			p_Bot:UpdateLookAroundGlance(p_DeltaTime, 1.9, 0.08)

			local s_Pos = p_Bot.m_Player.controlledControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			s_Yaw = s_Yaw + p_Bot._LookAroundYawOffset

			if s_Yaw < 0.0 then
				s_Yaw = s_Yaw + (2 * math.pi)
			elseif s_Yaw > (2 * math.pi) then
				s_Yaw = s_Yaw - (2 * math.pi)
			end

			p_Bot._TargetYaw = s_Yaw
			p_Bot._TargetPitch = p_Bot._LookAroundPitch
		end
	end
end

-- Function to calculate the yaw and pitch deviation relative to the orientation of a reference object
function VehicleMovement:CalculateDeviationRelativeToOrientation(p_Transform, targetPoint)
	return m_Utilities:GetDeviationToTarget(p_Transform, targetPoint)
end

function VehicleMovement:rotate_vector(v, axis, angle)
	local cos_theta = math.cos(angle)
	local sin_theta = math.sin(angle)
	local dot = v:Dot(axis)
	local cross = v:Cross(axis)
	return (v * cos_theta + cross * sin_theta + axis * dot * (1 - cos_theta)):Normalize()
end

---@param p_Bot Bot
---@param p_Attacking boolean
---@param p_IsStationaryLauncher boolean
---@param p_DeltaTime number
function VehicleMovement:UpdateYawVehicle(p_Bot, p_Attacking, p_IsStationaryLauncher, p_DeltaTime)
	local s_DeltaYaw = 0
	local s_DeltaPitch = 0
	local s_CorrectGunYaw = false

	local s_Pos = nil

	-- Every access of an engine object (input, controlledControllable, ...) allocates. Read each one once.
	local s_Player = p_Bot.m_Player
	local s_Input = p_Bot.m_Input
	local s_Vehicle = s_Player.controlledControllable
	local s_EntryId = s_Player.controlledEntryId

	if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Gunship) then
		local s_Transform = s_Vehicle.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId):ToLinearTransform()

		-- now rotate corresponding to the gun-alignment
		-- now modify the orientation as needed
		local s_forward = s_Transform.forward
		local s_left = s_Transform.left
		local s_up = s_Transform.up

		local s_Corrections = m_Vehicles:GetRotationOffsets(p_Bot.m_ActiveVehicle, s_EntryId, p_Bot._ActiveVehicleWeaponSlot)
		local s_YawCorr = -s_Corrections.x + Debug.Vars[6]
		local s_PitchCorr = -s_Corrections.y + Debug.Vars[7]

		local s_NewForward = self:rotate_vector(s_forward, s_up, s_YawCorr)
		local s_NewLeft = self:rotate_vector(s_left, s_up, s_YawCorr)

		local s_AdjustedForward = self:rotate_vector(s_NewForward, s_NewLeft, s_PitchCorr)
		local s_AdjustedUp = self:rotate_vector(s_up, s_NewLeft, s_PitchCorr)

		local s_LinearTransformNew = LinearTransform(s_NewLeft, s_AdjustedUp, s_AdjustedForward, s_Transform.trans)

		local s_Direction = Vec3.zero
		if p_Attacking then
			s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(s_LinearTransformNew, p_Bot._AttackPosition)
			s_Direction = p_Bot._AttackPosition - s_LinearTransformNew.trans
		elseif p_Bot._TargetPoint then
			s_DeltaYaw, s_DeltaPitch = self:CalculateDeviationRelativeToOrientation(s_LinearTransformNew, p_Bot._TargetPoint.Position)
			s_Direction = p_Bot._TargetPoint.Position - s_LinearTransformNew.trans
		end

		-- Intentionally NOT the atan - pi/2 convention used elsewhere: the gunship's gunner entries are oriented
		-- differently in the engine, and the raw atan(dz, dx) is what lines up in-game (verified; see B49).
		p_Bot._TargetYaw = math.atan(s_Direction.z, s_Direction.x)
		p_Bot._TargetPitch = 0.0
	else
		if not p_Attacking then
			if s_EntryId == 0 and not p_IsStationaryLauncher then
				local s_Euler = s_Vehicle.transform:ToQuatTransform(false).rotation:ToEuler()
				local s_Yaw = -s_Euler.x
				local s_Pitch = m_Utilities:GetPitchFromEuler(s_Euler)

				s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
				s_DeltaPitch = s_Pitch - p_Bot._TargetPitch

				if p_Bot._VehicleMovableId >= 0 then
					s_Input:SetLevel(EntryInputActionEnum.EIAPitch, 0)
					local s_EulerGun = s_Vehicle.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId).rotation:ToEuler()
					local s_DiffPos = s_Euler.x - s_EulerGun.x
					-- Prepare for moving gun back.
					p_Bot._LastVehicleYaw = s_Yaw

					if math.abs(s_DiffPos) > 0.08 then
						s_CorrectGunYaw = true
					end
				end
			else -- Passenger.
				if p_Bot._VehicleMovableId >= 0 then
					local s_Euler = s_Vehicle.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId).rotation:ToEuler()
					local s_Yaw = -s_Euler.x
					local s_Pitch = m_Utilities:GetPitchFromEuler(s_Euler)

					s_DeltaPitch = s_Pitch - p_Bot._TargetPitch
					s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
				end
			end
		else
			if p_Bot._VehicleMovableId >= 0 then
				local s_GunQuatTransform = s_Vehicle.physicsEntityBase:GetPartTransform(p_Bot._VehicleMovableId) --[[@as QuatTransform]]
				local s_Euler = s_GunQuatTransform.rotation:ToEuler()
				local s_Yaw = -s_Euler.x

				-- Compute the deviation in the gun's local frame. Turret/gun inputs rotate around the (tilted) vehicle axes,
				-- so comparing world yaw/pitch fails on slopes. Target direction is rebuilt from the world yaw/pitch
				-- (inverse of atan(dz, dx) - pi/2 used in VehicleAiming), which keeps the aim-error.
				local s_CosPitch = math.cos(p_Bot._TargetPitch)
				local s_GunTransform = s_GunQuatTransform:ToLinearTransform()
				s_DeltaYaw, s_DeltaPitch = m_Utilities:GetDeviationFromTransform(s_GunTransform,
					-math.sin(p_Bot._TargetYaw) * s_CosPitch, math.sin(p_Bot._TargetPitch), math.cos(p_Bot._TargetYaw) * s_CosPitch)
				-- The shot does not leave exactly along the part-forward (AimOffset = shot relative to part).
				local s_AimOffsetYaw, s_AimOffsetPitch = m_Vehicles:GetAimOffsets(p_Bot.m_ActiveVehicle, s_EntryId, p_Bot._ActiveVehicleWeaponSlot)
				s_DeltaYaw = s_DeltaYaw - s_AimOffsetYaw
				s_DeltaPitch = s_DeltaPitch - s_AimOffsetPitch

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
			elseif m_Vehicles:IsAirVehicle(p_Bot.m_ActiveVehicle) and s_EntryId == 0 then
				local s_Yaw, s_Pitch = m_Utilities:GetYawPitchRoll(s_Vehicle.transform)

				s_DeltaPitch = s_Pitch - p_Bot._TargetPitch
				s_DeltaYaw = s_Yaw - p_Bot._TargetYaw
			end
		end
	end

	if s_DeltaYaw > (math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw - 2 * math.pi
	elseif s_DeltaYaw < -(math.pi + 0.2) then
		s_DeltaYaw = s_DeltaYaw + 2 * math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_AbsDeltaPitch = math.abs(s_DeltaPitch)

	s_Input.authoritativeAimingYaw = p_Bot._TargetYaw -- Always set yaw to let the FOV work.

	local s_TargetRangeForShooting = 0.15
	if s_AbsDeltaYaw < s_TargetRangeForShooting then
		p_Bot._FullVehicleSteering = false
		if p_Attacking and s_AbsDeltaPitch < s_TargetRangeForShooting then
			p_Bot._VehicleReadyToShoot = true
		end
	else
		p_Bot._FullVehicleSteering = true
		p_Bot._VehicleReadyToShoot = false
	end

	if not p_Attacking then
		if s_EntryId == 0 and not p_IsStationaryLauncher then -- Driver.
			local s_Output = p_Bot._Pid_Drv_Yaw:Update(s_DeltaYaw, p_DeltaTime)

			if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				s_Input:SetLevel(EntryInputActionEnum.EIAYaw, s_Output)
			else
				s_Input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output)
			end

			if s_CorrectGunYaw then
				if p_Bot._VehicleDirBackPositive then
					s_Input:SetLevel(EntryInputActionEnum.EIARoll, 1)
				else
					s_Input:SetLevel(EntryInputActionEnum.EIARoll, -1)
				end
			else
				s_Input:SetLevel(EntryInputActionEnum.EIARoll, 0)
			end
		else -- Passenger.
			if p_Bot._VehicleMovableId >= 0 then
				local s_Output = p_Bot._Pid_Att_Yaw:Update(s_DeltaYaw, p_DeltaTime)
				s_Input:SetLevel(EntryInputActionEnum.EIARoll, -s_Output)

				s_Output = p_Bot._Pid_Att_Pitch:Update(s_DeltaPitch, p_DeltaTime)
				s_Input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output)
			end
		end
	else -- Attacking.
		-- Yaw
		local s_Output = p_Bot._Pid_Att_Yaw:Update(s_DeltaYaw, p_DeltaTime)

		if p_Bot._VehicleMoveWhileShooting and s_EntryId == 0 and not p_IsStationaryLauncher then -- Driver
			s_Pos = s_Vehicle.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			local s_DeltaYawDriving = s_Yaw - p_Bot._TargetYawMovementVehicle

			if s_DeltaYawDriving > (math.pi + 0.2) then
				s_DeltaYawDriving = s_DeltaYawDriving - 2 * math.pi
			elseif s_DeltaYawDriving < -(math.pi + 0.2) then
				s_DeltaYawDriving = s_DeltaYawDriving + 2 * math.pi
			end

			local s_OutputDriving = p_Bot._Pid_Drv_Yaw:Update(s_DeltaYawDriving, p_DeltaTime)

			if p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				s_Input:SetLevel(EntryInputActionEnum.EIAYaw, s_OutputDriving)
			else
				s_Input:SetLevel(EntryInputActionEnum.EIAYaw, -s_OutputDriving)
			end
		else
			if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA) then
				s_Input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output) -- Doubles the output of stationary AA → faster turret.
			else
				s_Input:SetLevel(EntryInputActionEnum.EIAYaw, 0)
			end
		end

		s_Input:SetLevel(EntryInputActionEnum.EIARoll, -s_Output)

		-- Pitch.
		s_Output = p_Bot._Pid_Att_Pitch:Update(s_DeltaPitch, p_DeltaTime)
		s_Input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output)
	end
end

if g_VehicleMovement == nil then
	---@type VehicleMovement
	g_VehicleMovement = VehicleMovement()
end

return g_VehicleMovement
