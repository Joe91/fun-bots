class('PathSwitcher')

local m_NodeCollection = require('__shared/NodeCollection')
local m_GameDirector = require('GameDirector')
local m_Logger = Logger("PathSwitcher", Debug.Server.PATH)

function PathSwitcher:__init()
	self.m_DummyData = 0
	self.m_KillYourselfCounter = {}
end

function PathSwitcher:GetNewPath(p_BotName, p_Point, p_Objective, p_InVehicle)
	-- check if on base, or on path away from base. In this case: change path
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

	if Globals.IsRush and not p_InVehicle then
		if self.m_KillYourselfCounter[p_BotName] == nil then
			self.m_KillYourselfCounter[p_BotName] = 0
		end

		if s_CurrentPathStatus == 0 then
			self.m_KillYourselfCounter[p_BotName] = self.m_KillYourselfCounter[p_BotName] + 1
		else
			self.m_KillYourselfCounter[p_BotName] = 0
		end

		if self.m_KillYourselfCounter[p_BotName] > 20 then
			local s_Bot = PlayerManager:GetPlayerByName(p_BotName)

			if s_Bot ~= nil and s_Bot.soldier ~= nil then
				s_Bot.soldier:Kill()
				self.m_KillYourselfCounter[p_BotName] = 0
				m_Logger:Write("kill "..p_BotName.." because of inactivity on wrong paths")
				return false
			end
		end
	end

	-- TODO get all paths via links, assign priority, sort by priority
	-- if multiple are top priority, choose at random

	p_Objective = p_Objective or ''
	local s_Paths = {}
	local s_HighestPriority = 0
	local s_CurrentPriority = 0

	local s_PossiblePaths = {}
	table.insert(s_PossiblePaths, p_Point) -- include our current path

	for i = 1, #p_Point.Data.Links do
		local s_NewPoint = m_NodeCollection:Get(p_Point.Data.Links[i])

		if s_NewPoint ~= nil then
			if not p_InVehicle then
				table.insert(s_PossiblePaths, s_NewPoint)
			else
				local s_PathNode = m_NodeCollection:GetFirst(s_NewPoint.PathIndex)

				if s_PathNode.Data.Vehicles ~= nil and #s_PathNode.Data.Vehicles > 0 then --TODO: check for vehicle-Type later
					table.insert(s_PossiblePaths, s_NewPoint)
				end
			end
		end
	end

	-- loop through each possible path
	for i = 1, #s_PossiblePaths do
		local s_NewPoint = s_PossiblePaths[i]
		local s_PathNode = m_NodeCollection:GetFirst(s_NewPoint.PathIndex)
		local s_NewPathStatus = m_GameDirector:GetEnableStateOfPath(s_PathNode.Data.Objectives or {})
		local s_NewBasePath = m_GameDirector:IsBasePath(s_PathNode.Data.Objectives or {})

		-- check for vehicle usage
		if s_PathNode.Data.Objectives ~= nil and #s_PathNode.Data.Objectives == 1 and s_NewPoint.ID ~= p_Point.ID then
			if m_GameDirector:UseVehicle(p_BotName, s_PathNode.Data.Objectives[1]) == true then
				return true, s_NewPoint
			end
		end

		-- this path has listed objectives
		if s_PathNode.Data.Objectives ~= nil and p_Objective ~= '' then
			-- check for possible subObjective
			if #s_PathNode.Data.Objectives == 1 and s_NewPoint.ID ~= p_Point.ID then
				if m_GameDirector:UseSubobjective(p_BotName, s_PathNode.Data.Objectives[1]) == true then
					return true, s_NewPoint
				end
			end

			-- path with a single objective that matches mine, top priority
			if #s_PathNode.Data.Objectives == 1 and s_PathNode.Data.Objectives[1] == p_Objective then
				if s_HighestPriority < 2 then
					s_HighestPriority = 2
				end

				table.insert(s_Paths, {
					Priority = 2,
					Point = s_NewPoint,
					State = s_NewPathStatus,
					Base = s_NewBasePath
				})

				if s_NewPoint.ID == p_Point.ID then
					s_CurrentPriority = 2
				end
			-- otherwise, check if the path has an objective i want
			else
				-- loop through the path's objectives and compare to mine
				for _, l_PathObjective in pairs(s_PathNode.Data.Objectives) do
					if p_Objective == l_PathObjective then
						if s_HighestPriority < 1 then
							s_HighestPriority = 1
						end

						table.insert(s_Paths, {
							Priority = 1,
							Point = s_NewPoint,
							State = s_NewPathStatus,
							Base = s_NewBasePath
						})

						if s_NewPoint.ID == p_Point.ID then
							s_CurrentPriority = 1
						end
					end
				end
			end
		else
			--path has no objectives, lowest priority
			table.insert(s_Paths, {
				Priority = 0,
				Point = s_NewPoint,
				State = s_NewPathStatus,
				Base = s_NewBasePath
			})

			if s_NewPoint.ID == p_Point.ID then
				s_CurrentPriority = 0
			end
		end

		-- check for base-Path or inactive path
		if s_NewPoint.ID ~= p_Point.ID then
			local s_SwitchAnyways = false
			local s_CountOld = #(s_CurrentPathFirst.Data.Objectives or {})
			local s_CountNew = #(s_PathNode.Data.Objectives or {})

			if s_OnBasePath then -- if on base path, check for objective count.
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

			if s_SwitchAnyways then
				if s_HighestPriority < 3 then
					s_HighestPriority = 3
				end

				table.insert(s_Paths, {
					Priority = 3,
					Point = s_NewPoint,
					State = s_NewPathStatus,
					Base = s_NewBasePath
				})
			else
				if s_CountOld == 1 and s_CountNew == 1 and p_Objective ~= "" and s_CurrentPathFirst.Data.Objectives[1] ~= p_Objective and
				s_CurrentPathFirst.Data.Objectives[1] == s_PathNode.Data.Objectives[1] then
					--path has same objective. Maybe a switch can help to find the new one
					table.insert(s_Paths, {
						Priority = 0,
						Point = s_NewPoint,
						State = s_NewPathStatus,
						Base = s_NewBasePath
					})
				end
			end
		end
	end

	-- remove paths below our highest priority
	local s_ValidPaths = {}

	for i = 1, #s_Paths do
		if s_Paths[i].Priority >= s_HighestPriority and s_Paths[i].State >= s_CurrentPathStatus then
			if s_OnBasePath or (not s_OnBasePath and s_Paths[i].Base == false) or s_CurrentPathStatus <= 0 then
				table.insert(s_ValidPaths, s_Paths[i])
			end
		end
	end

	--m_Logger:Write('Trimmed Priority List -> '..g_Utilities:dump(s_Paths, true, 2))
	--m_Logger:Write('Highest Priority -> '..s_HighestPriority)
	--m_Logger:Write('#s_Paths -> '..(#s_Paths))

	if #s_ValidPaths == 0 then
		return false
	end

	if #s_ValidPaths == 1 and s_CurrentPriority < s_ValidPaths[1].Priority then
		--m_Logger:Write('found single higher priority path ( '..s_CurrentPriority..' | '..s_ValidPaths[1].Priority..' )')
		return true, s_ValidPaths[1].Point
	end

	local s_LinkMode = tonumber(p_Point.Data.LinkMode) or 0

	if s_LinkMode == 0 then -- random path switch

		local s_Chance = tonumber(p_Point.Data.LinkChance) or 40
		local s_RandomNumber = MathUtils:GetRandomInt(0, 100)
		local s_RandomIndex = MathUtils:GetRandomInt(1, #s_ValidPaths)

		if s_CurrentPriority < s_HighestPriority then
			local s_RandomPath = s_ValidPaths[s_RandomIndex]

			if s_RandomPath == nil then
				m_Logger:Write('[A] s_ValidPaths['..s_RandomIndex..'] was nil : '..g_Utilities:dump(s_ValidPaths, true, 2))
				return false
			end

			m_Logger:Write('found multiple higher priority s_ValidPaths | Priority: ( '..s_CurrentPriority..' | '..s_HighestPriority..' )')

			return true, s_RandomPath.Point
		end

		if s_RandomNumber <= s_Chance then
			local s_RandomPath = s_ValidPaths[s_RandomIndex]

			if s_RandomPath == nil then
				m_Logger:Write('[B] s_ValidPaths['..s_RandomIndex..'] was nil : '..g_Utilities:dump(s_ValidPaths, true, 2))

				return false
			end

			--m_Logger:Write('chose to switch at random ('..s_RandomNumber..' >= '..s_Chance..') | Priority: ( '..s_CurrentPriority..' | '..s_RandomPath.Priority..' )')
			return true, s_RandomPath.Point
		end
	elseif s_LinkMode == 1 then -- some other kind of switching decision
		-- etc...
	end

	--m_Logger:Write('dont change')
	return false
end

if g_PathSwitcher == nil then
	g_PathSwitcher = PathSwitcher()
end

return g_PathSwitcher
