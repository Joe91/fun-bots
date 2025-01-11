---@class PathSwitcher
---@overload fun():PathSwitcher
PathSwitcher = class('PathSwitcher')

require('__shared/Config')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type GameDirector
local m_GameDirector = require('GameDirector')
---@type Logger
local m_Logger = Logger("PathSwitcher", Debug.Server.PATH)
---@type Utilities
local m_Utilities = require('__shared/Utilities')

function PathSwitcher:__init()
	self.m_DummyData = 0
end

function PathSwitcher:GetPriorityOfPath(p_Node, p_TargetObjective)
	local s_Priority = -1
	-- This path has listed objectives.
	if p_Node.Data.Objectives ~= nil and p_TargetObjective ~= '' then
		-- Path with a single objective that matches mine, top priority.
		if #p_Node.Data.Objectives == 1 and p_Node.Data.Objectives[1] == p_TargetObjective then
			s_Priority = 4

			-- Consider path with other objective, in case everything else fails
		elseif #p_Node.Data.Objectives == 1 then
			s_Priority = 2
			-- Otherwise, check if the path has an objective I want.
		else -- more than one objective
			-- Loop through the path's objectives and compare to mine.
			for _, l_PathObjective in pairs(p_Node.Data.Objectives) do
				if p_TargetObjective == l_PathObjective then
					s_Priority = 3
					break
				end
			end
		end
	else
		s_Priority = 0
	end

	return s_Priority
end

---@param p_Bot Bot
---@param p_BotId integer
---@param p_Point Waypoint
---@param p_Objective string|nil
---@param p_InVehicle boolean
---@param p_TeamId TeamId
---@param p_ActiveVehicle VehicleDataInner|nil
---@returns boolean
---@returns Waypoint|nil
function PathSwitcher:GetNewPath(p_Bot, p_BotId, p_Point, p_Objective, p_InVehicle, p_TeamId, p_ActiveVehicle)
	-- Check if on base, or on path away from base. In this case: change path.
	local s_OnBasePath = false
	local s_CurrentPathFirst = m_NodeCollection:GetFirst(p_Point.PathIndex)
	local s_CurrentPathStatus = 0

	if s_CurrentPathFirst.Data ~= nil and s_CurrentPathFirst.Data.Objectives ~= nil then
		s_CurrentPathStatus = m_GameDirector:GetEnableStateOfPath(s_CurrentPathFirst.Data.Objectives)
		s_OnBasePath = m_GameDirector:IsBasePath(s_CurrentPathFirst.Data.Objectives)
	end

	if p_Point.Data == nil or p_Point.Data.Links == nil or #p_Point.Data.Links < 1 then
		return false
	end

	-- To-do: get all paths via links, assign priority, sort by priority.
	-- If multiple are top priority, choose at random.

	p_Objective = p_Objective or ''
	local s_OnVehicleEnterObjective = m_GameDirector:IsVehicleEnterPath(p_Objective)
	local s_ValidPaths = {}
	local s_HighestPriority = 0
	local s_CurrentPriority = 0

	local s_PossiblePaths = {}

	for i = 1, #p_Point.Data.Links do
		local s_NewPoint = m_NodeCollection:Get(p_Point.Data.Links[i])

		if s_NewPoint ~= nil then
			if not p_InVehicle then
				-- todo: prevent air-paths?
				table.insert(s_PossiblePaths, s_NewPoint)
			else
				local s_PathNode = m_NodeCollection:GetFirst(s_NewPoint.PathIndex)

				if s_PathNode.Data.Vehicles ~= nil and #s_PathNode.Data.Vehicles > 0 then -- Check for vehicle-type.
					if p_ActiveVehicle ~= nil and p_ActiveVehicle.Terrain ~= nil then
						local s_VehicleTerrain = p_ActiveVehicle.Terrain
						local s_isAirPath = false
						local s_isWaterPath = false

						for _, l_PathType in pairs(s_PathNode.Data.Vehicles) do
							if l_PathType:lower() == "air" then
								s_isAirPath = true
							end

							if l_PathType:lower() == "water" then
								s_isWaterPath = true
							end
						end
						if (s_VehicleTerrain == VehicleTerrains.Air and s_isAirPath) or
							(s_VehicleTerrain == VehicleTerrains.Water and s_isWaterPath) or
							(s_VehicleTerrain == VehicleTerrains.Land and not s_isWaterPath and not s_isAirPath) or
							(s_VehicleTerrain == VehicleTerrains.Amphibious and not s_isAirPath) then
							table.insert(s_PossiblePaths, s_NewPoint)
						end
					else
						-- Invalid Terrain. Insert path anyway.
						table.insert(s_PossiblePaths, s_NewPoint)
					end
				end
			end
		end
	end

	-- Loop through each possible path.
	s_CurrentPriority = self:GetPriorityOfPath(s_CurrentPathFirst, p_Objective)
	for i = 1, #s_PossiblePaths do
		local s_NewPoint = s_PossiblePaths[i]
		local s_PathNode = m_NodeCollection:GetFirst(s_NewPoint.PathIndex)
		local s_NewPathStatus = m_GameDirector:GetEnableStateOfPath(s_PathNode.Data.Objectives or {})
		local s_NewBasePath = m_GameDirector:IsBasePath(s_PathNode.Data.Objectives or {})

		if s_OnVehicleEnterObjective then
			if s_PathNode.Data.Objectives ~= nil and s_PathNode.Data.Objectives[1] == p_Objective then
				return true, s_NewPoint
			else
				goto skip
			end
		end

		if s_PathNode.Data.Objectives ~= nil and #s_PathNode.Data.Objectives == 1 then
			-- Check for vehicle usage.
			if Config.UseVehicles then
				if m_GameDirector:UseVehicle(p_TeamId, s_PathNode.Data.Objectives[1]) == true then
					return true, s_NewPoint
				end
			else
				if m_GameDirector:IsVehicleEnterPath(s_PathNode.Data.Objectives[1]) then
					goto skip
				end
			end

			-- Check for beacon
			if m_GameDirector:IsBeaconPath(s_PathNode.Data.Objectives[1]) then
				if p_Bot.m_SecondaryGadget.type == WeaponTypes.Beacon
					and not p_Bot.m_HasBeacon
					and m_Utilities:CheckProbablity(Registry.BOT.PROBABILITY_SWITCH_TO_BEACON_PATH)
				then
					return true, s_NewPoint
				end
			end

			if m_GameDirector:IsExplorePath(s_PathNode.Data.Objectives[1]) then
				if (p_Bot:AtObjectivePath()
					and MathUtils:GetRandomInt(1, 100) <= Registry.BOT.PROBABILITY_SWITCH_TO_EXPLORE_PATH)
					or MathUtils:GetRandomInt(1, 100) <= Registry.BOT.PROBABILITY_SWITCH_TO_EXPLORE_PATH / 2
				then
					return true, s_NewPoint
				end
			end
		end

		-- This path has listed objectives.
		if s_PathNode.Data.Objectives ~= nil and p_Objective ~= '' then
			-- Check for possible subObjective.
			if #s_PathNode.Data.Objectives == 1 then
				if m_GameDirector:UseSubobjective(p_BotId, p_TeamId, s_PathNode.Data.Objectives[1]) == true then
					return true, s_NewPoint
				end
			end
		end

		-- GET PRIORITY of path here
		local s_Priority = self:GetPriorityOfPath(s_PathNode, p_Objective)


		-- Check for base-Path or inactive path.
		local s_SwitchAnyways = false
		local s_CountOld = #(s_CurrentPathFirst.Data.Objectives or {})
		local s_CountNew = #(s_PathNode.Data.Objectives or {})

		if s_OnBasePath then -- If on base path, check for objective count.
			if not s_NewBasePath and s_NewPathStatus == 2 then
				s_SwitchAnyways = true
			elseif s_NewBasePath then
				if s_CountOld == 1 and s_CountNew > 1 and s_NewPathStatus == 2 then
					s_SwitchAnyways = true
				end
			end
		end

		if s_NewPathStatus > s_CurrentPathStatus then
			s_SwitchAnyways = true
		end

		if s_NewPathStatus == 0 and s_CurrentPathStatus == 0 and s_CountOld > s_CountNew and not s_NewBasePath then
			s_SwitchAnyways = true
		end

		if s_CountOld == 0 and s_CountNew > 0 then
			s_SwitchAnyways = true
		end

		-- Leave subObjective, if disabled.
		if Globals.IsRush then
			local s_TopObjective = m_GameDirector:_GetObjectiveFromSubObj(p_Objective)

			if s_TopObjective ~= nil and s_CurrentPathStatus == 0 and s_CountNew == 1 and
				s_TopObjective == s_PathNode.Data.Objectives[1] then
				s_SwitchAnyways = true
			end
		end

		if s_SwitchAnyways then
			s_Priority = 5
		else
			if s_CountOld == 1 and s_CountNew == 1 and p_Objective ~= "" and s_CurrentPathFirst.Data.Objectives[1] ~= p_Objective
				and
				s_CurrentPathFirst.Data.Objectives[1] == s_PathNode.Data.Objectives[1] then
				s_Priority = 1
			end
		end


		if s_Priority > s_HighestPriority then
			s_HighestPriority = s_Priority
		end

		-- evalute and insert to target path
		if s_CurrentPathStatus <= s_NewPathStatus and s_CurrentPriority <= s_Priority and (not s_NewBasePath or s_OnBasePath or s_Priority == 5) then
			table.insert(s_ValidPaths, {
				Priority = s_Priority,
				Point = s_NewPoint,
				State = s_NewPathStatus,
				Base = s_NewBasePath
			})
		end


		::skip::
	end

	if s_OnVehicleEnterObjective then
		return false
	end

	-- Remove paths below our highest priority.

	-- m_Logger:Write('Full List -> ' .. g_Utilities:dump(s_Paths, true, 2))

	-- m_Logger:Write('Trimmed Priority List -> ' .. g_Utilities:dump(s_ValidPaths, true, 2))
	-- m_Logger:Write('Current Priority -> ' .. s_CurrentPriority)
	-- m_Logger:Write('#s_Paths -> '..(#s_Paths))

	if #s_ValidPaths == 0 then
		return false
	end

	local s_Chance = Registry.GAME_DIRECTOR.PROBABILITY_SWITCH_SAME_PRIO
	local s_RandomNumber = MathUtils:GetRandomInt(0, 100)
	if s_CurrentPriority < s_HighestPriority then
		local s_HighestPrioPathsIndex = {}
		for i = 1, #s_ValidPaths do
			if s_ValidPaths[i].Priority == s_HighestPriority then
				table.insert(s_HighestPrioPathsIndex, i)
			end
		end
		local s_RandomIndex = MathUtils:GetRandomInt(1, #s_HighestPrioPathsIndex)
		local s_RandomPath = s_ValidPaths[s_HighestPrioPathsIndex[s_RandomIndex]]

		if (s_RandomPath == nil) then
			print("!!! was nil !!!")
			return false
		end

		m_Logger:Write('found path with higher priority s_ValidPaths | Priority: ( ' ..
			s_CurrentPriority .. ' | ' .. s_HighestPriority .. ' )')

		return true, s_RandomPath.Point
	elseif s_RandomNumber <= s_Chance then -- same priority, change by chance
		local s_RandomIndex = MathUtils:GetRandomInt(1, #s_ValidPaths)
		local s_RandomPath = s_ValidPaths[s_RandomIndex]
		m_Logger:Write('chose to switch at random (' .. s_RandomNumber .. ' <= ' .. s_Chance .. ') | Priority: ( ' .. s_CurrentPriority .. ' | ' .. s_RandomPath.Priority .. ' )')
		return true, s_RandomPath.Point
	else
		m_Logger:Write("don't change " .. s_CurrentPriority)
		return false
	end
end

if g_PathSwitcher == nil then
	---@type PathSwitcher
	g_PathSwitcher = PathSwitcher()
end

return g_PathSwitcher
