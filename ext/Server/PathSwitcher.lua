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
			for l_Index = 1, #p_Node.Data.Objectives do
				local l_PathObjective = p_Node.Data.Objectives[l_Index]
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

---Whether soldiers may use a path. Paths with "Vehicles" are driven if they have no objectives (e.g. out of a base) or
---are a closed loop through several objectives (around the map), air paths anyway. The others are walkable as well: a
---loop around one objective, or a path between objectives.
---@param p_PathIndex integer
---@return boolean
function PathSwitcher:IsWalkable(p_PathIndex)
	local s_First = m_NodeCollection:GetFirst(p_PathIndex)

	if not s_First or type(s_First) == 'boolean' or s_First.Data == nil then
		return true
	end

	local s_Vehicles = s_First.Data.Vehicles

	if s_Vehicles == nil or #s_Vehicles == 0 then
		return true
	end

	for l_Index = 1, #s_Vehicles do
		if s_Vehicles[l_Index]:lower() == "air" then
			return false
		end
	end

	local s_ObjectiveCount = s_First.Data.Objectives and #s_First.Data.Objectives or 0

	if s_ObjectiveCount == 0 then
		return false
	elseif s_ObjectiveCount == 1 then
		return true
	end

	-- Closed: the ends meet (15 m, or 5 % of the length on long loops). The loop flag of old paths isn't reliable.
	local s_Nodes = m_NodeCollection:Get(nil, p_PathIndex)

	if s_Nodes == nil or #s_Nodes < 2 then
		return true
	end

	local s_Length = 0.0

	for l_Index = 2, #s_Nodes do
		s_Length = s_Length + s_Nodes[l_Index - 1].Position:Distance(s_Nodes[l_Index].Position)
	end

	local s_Gap = s_First.Position:Distance(s_Nodes[#s_Nodes].Position)
	return s_Gap > math.max(15.0, 0.05 * s_Length)
end

---Whether a path the bots have to leave (see GetNewPath) has a regular way out at any of its junctions: off a base-path
---a walkable path with all objectives active, but no base-path alone (no path with a base at all off a path out of a
---base), the way to a vehicle or a beacon. Off other paths one with all objectives active that leads to the objective.
---@param p_PathIndex integer
---@param p_Objective string
---@param p_OnBasePath boolean
---@return boolean
function PathSwitcher:_HasRegularExit(p_PathIndex, p_Objective, p_OnBasePath)
	local s_Nodes = m_NodeCollection:Get(nil, p_PathIndex) or {}
	local s_OnSpawnBasePath = p_OnBasePath and #m_NodeCollection:GetFirst(p_PathIndex).Data.Objectives == 1

	for l_Index = 1, #s_Nodes do
		local s_Links = s_Nodes[l_Index].Data and s_Nodes[l_Index].Data.Links

		for l_LinkIndex = 1, #(s_Links or {}) do
			local s_Target = m_NodeCollection:Get(s_Links[l_LinkIndex])

			if s_Target ~= nil and s_Target.PathIndex ~= p_PathIndex and self:IsWalkable(s_Target.PathIndex) then
				local s_First = m_NodeCollection:GetFirst(s_Target.PathIndex)
				local s_Objectives = s_First.Data and s_First.Data.Objectives or {}
				local s_Single = #s_Objectives == 1
				local s_IsBase = m_GameDirector:IsBasePath(s_Objectives)

				if m_GameDirector:GetEnableStateOfPath(s_Objectives) == 2 and not (s_Single
						and (m_GameDirector:IsVehicleEnterPath(s_Objectives[1]) or m_GameDirector:IsBeaconPath(s_Objectives[1]))) then
					if p_OnBasePath then
						if not s_IsBase or (s_OnSpawnBasePath and not s_Single) then
							return true
						end
					elseif not s_IsBase and table.has(s_Objectives, p_Objective) then
						return true
					end
				end
			end
		end
	end

	return false
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
	if p_Point.Data == nil or p_Point.Data.Links == nil or #p_Point.Data.Links < 1 then
		return false
	end

	-- Check if on base, or on path away from base. In this case: change path.
	local s_OnBasePath = false
	local s_CurrentPathFirst = m_NodeCollection:GetFirst(p_Point.PathIndex)
	local s_CurrentPathStatus = 0
	if s_CurrentPathFirst.Data ~= nil and s_CurrentPathFirst.Data.Objectives ~= nil then
		s_CurrentPathStatus = m_GameDirector:GetEnableStateOfPath(s_CurrentPathFirst.Data.Objectives)
		s_OnBasePath = m_GameDirector:IsBasePath(s_CurrentPathFirst.Data.Objectives)
	end
	p_Objective = p_Objective or ''

	-- Bots always leave a path of a base alone, where they spawn, a path out of a base at its end (else they walk it
	-- back to the base), the path of a destroyed MCOM, and the way to a vehicle that isn't their objective (of the other
	-- team, or gone). If the path has no regular way out, over any other path (see below).
	local s_LeavePath = false
	if s_OnBasePath then
		s_LeavePath = #s_CurrentPathFirst.Data.Objectives == 1 or p_Point.PointIndex == 1
			or p_Point.PointIndex == #m_NodeCollection:Get(nil, p_Point.PathIndex)
	elseif s_CurrentPathFirst.Data ~= nil and s_CurrentPathFirst.Data.Objectives ~= nil then
		local s_Objectives = s_CurrentPathFirst.Data.Objectives
		-- UseVehicle sends bots onto the way to a vehicle without changing their objective: they stay on it while
		-- the vehicle can be used by their team.
		s_LeavePath = m_GameDirector:IsDestroyedPath(s_Objectives) or (#s_Objectives == 1
			and s_Objectives[1] ~= p_Objective and m_GameDirector:IsVehicleEnterPath(s_Objectives[1])
			and not m_GameDirector:UseVehicle(p_TeamId, s_Objectives[1]))
	end
	local s_Exits = {}
	local s_BestExitScore = -1

	-- To-do: get all paths via links, assign priority, sort by priority.
	-- If multiple are top priority, choose at random.

	local s_OnVehicleEnterObjective = m_GameDirector:IsVehicleEnterPath(p_Objective)
	local s_ValidPaths = {}
	local s_HighestPriority = 0
	local s_CurrentPriority = 0

	local s_PossiblePaths = {}

	for i = 1, #p_Point.Data.Links do
		local s_NewPoint = m_NodeCollection:Get(p_Point.Data.Links[i])

		if s_NewPoint ~= nil then
			if not p_InVehicle then
				if self:IsWalkable(s_NewPoint.PathIndex) then
					s_PossiblePaths[#s_PossiblePaths + 1] = s_NewPoint
				end
			else
				local s_PathNode = m_NodeCollection:GetFirst(s_NewPoint.PathIndex)

				if s_PathNode.Data.Vehicles ~= nil and #s_PathNode.Data.Vehicles > 0 then -- Check for vehicle-type.
					if p_ActiveVehicle ~= nil and p_ActiveVehicle.Terrain ~= nil then
						local s_VehicleTerrain = p_ActiveVehicle.Terrain
						local s_isAirPath = false
						local s_isWaterPath = false

						for l_Index = 1, #s_PathNode.Data.Vehicles do
							local l_PathType = s_PathNode.Data.Vehicles[l_Index]
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
							s_PossiblePaths[#s_PossiblePaths + 1] = s_NewPoint
						end
					else
						-- Invalid Terrain. Insert path anyway.
						s_PossiblePaths[#s_PossiblePaths + 1] = s_NewPoint
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
			if Config.UseVehicles and m_GameDirector:UseVehicle(p_TeamId, s_PathNode.Data.Objectives[1]) == true then
				return true, s_NewPoint
			elseif m_GameDirector:IsVehicleEnterPath(s_PathNode.Data.Objectives[1]) then
				-- No vehicle of this team there (gone, taken, other team): a dead end. Bots took it by priority, found
				-- nothing at its end and lost their time until they got teleported.
				goto skip
			end

			-- Check for beacon
			if m_GameDirector:IsBeaconPath(s_PathNode.Data.Objectives[1]) then
				if p_Bot.m_SecondaryGadget ~= nil and p_Bot.m_SecondaryGadget.type == WeaponTypes.Beacon
					and not p_Bot.m_HasBeacon
					and m_Utilities:CheckProbability(Registry.BOT.PROBABILITY_SWITCH_TO_BEACON_PATH)
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

		-- Fallback way out: any path but a base-path alone, the way to a vehicle or a beacon, or another destroyed
		-- objective. Paths to the objective of the bot first, then the most active ones.
		if s_LeavePath then
			local s_NewObjectives = s_PathNode.Data.Objectives or {}
			local s_IsDeadEnd = #s_NewObjectives == 1 and (s_NewBasePath
				or m_GameDirector:IsVehicleEnterPath(s_NewObjectives[1])
				or m_GameDirector:IsBeaconPath(s_NewObjectives[1])
				or m_GameDirector:IsDestroyedPath(s_NewObjectives))

			if not s_IsDeadEnd then
				local s_Score = s_NewPathStatus
				if p_Objective ~= '' and table.has(s_NewObjectives, p_Objective) then
					s_Score = s_Score + 3
				end
				s_Exits[#s_Exits + 1] = { Point = s_NewPoint, Score = s_Score }
				if s_Score > s_BestExitScore then
					s_BestExitScore = s_Score
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


		-- evalute and insert to target path
		if s_CurrentPathStatus <= s_NewPathStatus and s_CurrentPriority <= s_Priority and (not s_NewBasePath or (s_OnBasePath and s_CountOld == 1) or s_Priority == 5) then
			-- Only valid paths count for the highest priority, so a filtered-out link
			-- can't hide a valid path with a higher priority than the current one.
			if s_Priority > s_HighestPriority then
				s_HighestPriority = s_Priority
			end

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

	-- No regular way out here (off a base-path: priority 5, else a better path), and nowhere else on the path: leave it
	-- anyways. Better than staying.
	local s_RegularExit = s_HighestPriority >= 5 or (not s_OnBasePath and s_HighestPriority > s_CurrentPriority)
	if s_LeavePath and not s_RegularExit and #s_Exits > 0
		and not self:_HasRegularExit(p_Point.PathIndex, p_Objective, s_OnBasePath) then
		local s_BestExits = {}
		for i = 1, #s_Exits do
			if s_Exits[i].Score == s_BestExitScore then
				s_BestExits[#s_BestExits + 1] = s_Exits[i].Point
			end
		end
		m_Logger:Write('no regular way out of the base-path or destroyed objective, leave it anyways')
		return true, s_BestExits[MathUtils:GetRandomInt(1, #s_BestExits)]
	end

	if #s_ValidPaths == 0 then
		return false
	end

	local s_Chance = Registry.GAME_DIRECTOR.PROBABILITY_SWITCH_SAME_PRIO
	local s_RandomNumber = MathUtils:GetRandomInt(0, 100)
	if s_CurrentPriority < s_HighestPriority then
		local s_HighestPrioPathsIndex = {}
		for i = 1, #s_ValidPaths do
			if s_ValidPaths[i].Priority == s_HighestPriority then
				s_HighestPrioPathsIndex[#s_HighestPrioPathsIndex + 1] = i
			end
		end
		local s_RandomIndex = MathUtils:GetRandomInt(1, #s_HighestPrioPathsIndex)
		local s_RandomPath = s_ValidPaths[s_HighestPrioPathsIndex[s_RandomIndex]]

		if (s_RandomPath == nil) then
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
