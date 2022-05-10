---@class VehicleMovement
VehicleMovement = class('VehicleMovement')

---@type Logger
local m_Logger = Logger("Bot", Debug.Server.BOT)
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type NodeCollection
local m_NodeCollection = require('__shared/NodeCollection')

function VehicleMovement:__init()
	-- nothing to do
end


function VehicleMovement:UpdateNormalMovementVehicle(p_Bot)
	if p_Bot._VehicleTakeoffTimer > 0.0 then
		p_Bot._VehicleTakeoffTimer = p_Bot._VehicleTakeoffTimer - Registry.BOT.BOT_UPDATE_CYCLE
		if p_Bot._JetAbortAttackActive then
			local s_TargetPosition = p_Bot.m_Player.controlledControllable.transform.trans
			local s_Forward = p_Bot.m_Player.controlledControllable.transform.forward
			s_Forward.y = 0
			s_Forward:Normalize()
			s_TargetPosition = s_TargetPosition + (s_Forward*50)
			s_TargetPosition.y = s_TargetPosition.y + 50
			local s_Waypoint = {
				Position = s_TargetPosition
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
				-- check for other plane in front of bot
				local s_IsInfront = false
				for _, l_Jet in pairs(g_GameDirector:GetSpawnableVehicle(p_Bot.m_Player.teamId)) do
					local s_DistanceToJet = p_Bot.m_Player.controlledControllable.transform.trans:Distance(l_Jet.transform.trans)
					if s_DistanceToJet < 30 then
						local s_CompPos = p_Bot.m_Player.controlledControllable.transform.trans + p_Bot.m_Player.controlledControllable.transform.forward * s_DistanceToJet
						if l_Jet.transform.trans:Distance(s_CompPos) < 10 then
							s_IsInfront = true
						end
					end
				end
				if s_IsInfront then
					p_Bot._VehicleWaitTimer = 5.0 -- one more cycle
					return
				end
			end
			g_GameDirector:_SetVehicleObjectiveState(p_Bot.m_Player.soldier.worldTransform.trans, false)
		else
			return
		end
	end

	-- move along points
	if m_NodeCollection:Get(1, p_Bot._PathIndex) ~= nil then -- check for valid point
		-- get next point
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

		-- execute Action if needed
		if p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
			if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
				if s_Point.Data.Action.type == "exit" then
					p_Bot:_ResetActionFlag(BotActionFlags.OtherActionActive)
					local s_OnlyPassengers = false
					if s_Point.Data.Action.onlyPassengers ~= nil and s_Point.Data.Action.onlyPassengers == true then
						s_OnlyPassengers = true
					end

					-- let all other bots exit the vehicle
					local s_VehicleEntity = p_Bot.m_Player.controlledControllable
					if s_VehicleEntity ~= nil then
						for i = 1, (s_VehicleEntity.entryCount - 1) do
							local s_Player = s_VehicleEntity:GetPlayerInEntry(i)
							if s_Player ~= nil then
								Events:Dispatch('Bot:ExitVehicle', s_Player.name)
							end
						end
					end
					-- Exit Vehicle
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
				return --DONT EXECUTE ANYTHING ELSE
			else
				s_Point = s_NextPoint
			end
		end

		if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- movement
			p_Bot._WayWaitTimer = 0.0
			p_Bot._WayWaitYawTimer = 0.0
			p_Bot.m_ActiveSpeedValue = s_Point.SpeedMode --speed

			-- TODO: use vehicle transform also for trace?
			local s_DifferenceY = s_Point.Position.z - p_Bot.m_Player.soldier.worldTransform.trans.z
			local s_DifferenceX = s_Point.Position.x - p_Bot.m_Player.soldier.worldTransform.trans.x
			local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
			local s_HeightDistance = math.abs(s_Point.Position.y - p_Bot.m_Player.soldier.worldTransform.trans.y)

			--detect obstacle and move over or around TODO: Move before normal jump
			local s_CurrentWayPointDistance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)

			if s_CurrentWayPointDistance > p_Bot._LastWayDistance + 0.02 and p_Bot._ObstaceSequenceTimer == 0.0 then
				--skip one pooint
				s_DistanceFromTarget = 0
				s_HeightDistance = 0
			end

			p_Bot._TargetPoint = s_Point
			p_Bot._NextTargetPoint = s_NextPoint

			if math.abs(s_CurrentWayPointDistance - p_Bot._LastWayDistance) < 0.02 or p_Bot._ObstaceSequenceTimer ~= 0.0 then
				-- try to get around obstacle
				if p_Bot._ObstacleRetryCounter % 2 == 0 then
					if p_Bot._ObstaceSequenceTimer < 4.0 then
						p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Sprint -- full throttle
					end
				else
					if p_Bot._ObstaceSequenceTimer < 2.0 then
						p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.Backwards
					end
				end

				if (p_Bot.m_ActiveSpeedValue == BotMoveSpeeds.Backwards and p_Bot._ObstaceSequenceTimer > 3.0) or
				(p_Bot.m_ActiveSpeedValue ~= BotMoveSpeeds.Backwards and p_Bot._ObstaceSequenceTimer > 5.0) then
					p_Bot._ObstaceSequenceTimer = 0.0
					p_Bot._ObstacleRetryCounter = p_Bot._ObstacleRetryCounter + 1
				end

				p_Bot._ObstaceSequenceTimer = p_Bot._ObstaceSequenceTimer + Registry.BOT.BOT_UPDATE_CYCLE

				if p_Bot._ObstacleRetryCounter >= 4 then --try next waypoint
					p_Bot._ObstacleRetryCounter = 0

					s_DistanceFromTarget = 0
					s_HeightDistance = 0

					-- teleport if stuck
					if Config.TeleportIfStuck and
					m_Vehicles:IsNotVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) and
					m_Vehicles:IsNotVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) and
					(MathUtils:GetRandomInt(0,100) <= Registry.BOT.PROBABILITY_TELEPORT_IF_STUCK_IN_VEHICLE) then
						local s_Transform = p_Bot.m_Player.controlledControllable.transform:Clone()
						s_Transform.trans = p_Bot._TargetPoint.Position
						s_Transform:LookAtTransform(p_Bot._TargetPoint.Position, p_Bot._NextTargetPoint.Position)
						p_Bot.m_Player.controlledControllable.transform = s_Transform
						m_Logger:Write("tepeported in vehicle of "..p_Bot.m_Player.name)
					else
						if m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Plane) then
							s_PointIncrement = 1
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

			--check for reached target
			if s_DistanceFromTarget <= s_TargetDistanceSpeed and s_HeightDistance <= Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT then

				-- CHECK FOR ACTION
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

						return --DONT DO ANYTHING ELSE ANYMORE
					end
				end

				-- CHECK FOR PATH-SWITCHES
				local s_NewWaypoint = nil
				local s_SwitchPath = false
				s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(p_Bot.m_Name, s_Point, p_Bot._Objective, p_Bot.m_InVehicle, p_Bot.m_Player.teamId, p_Bot.m_ActiveVehicle.Terrain)

				if p_Bot.m_Player.soldier == nil then
					return
				end

				if s_SwitchPath == true and not p_Bot._OnSwitch then
					if p_Bot._Objective ~= '' then
						-- 'best' direction for objective on switch
						local s_Direction = m_NodeCollection:ObjectiveDirection(s_NewWaypoint, p_Bot._Objective, p_Bot.m_InVehicle)
						p_Bot._InvertPathDirection = (s_Direction == 'Previous')
					else
						-- random path direction on switch
						p_Bot._InvertPathDirection = MathUtils:GetRandomInt(1,2) == 1
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

				p_Bot._ObstaceSequenceTimer = 0.0
				p_Bot._LastWayDistance = 1000.0
			end
		else -- wait mode
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
	--else -- no point: do nothing
	end
end

function VehicleMovement:UpdateShootMovementVehicle(p_Bot)
	p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement -- no movement while attacking in vehicles
end


function VehicleMovement:UpdateSpeedOfMovementVehicle(p_Bot)
	if p_Bot.m_Player.soldier == nil or p_Bot._VehicleWaitTimer > 0.0 then
		return
	end

	if p_Bot.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
		p_Bot.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
	end

	if  m_Vehicles:IsNotVehicleTerrain(p_Bot.m_ActiveVehicle, VehicleTerrains.Air) then -- Air-Vehicles are handled in the yaw-function
		-- additional movement
		local s_SpeedVal = 0

		if p_Bot.m_ActiveMoveMode ~= BotMoveModes.Standstill then
			-- limit speed if full steering active
			if p_Bot._FullVehicleSteering and p_Bot.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
				p_Bot.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
			end

			-- normal values
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
		end

		-- movent speed
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


if g_VehicleMovement == nil then
	---@type VehicleMovement
	g_VehicleMovement = VehicleMovement()
end

return g_VehicleMovement