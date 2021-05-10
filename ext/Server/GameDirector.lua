class('GameDirector')

local m_NodeCollection = require('__shared/NodeCollection')
local m_Logger = Logger("GameDirector", Debug.Server.GAMEDIRECTOR)

function GameDirector:__init()
	self:RegisterVars()
end

function GameDirector:RegisterVars()
	self.m_UpdateLast = -1
	self.m_UpdateInterval = 1.5 -- seconds interval

	self.m_BotsByTeam = {}

	self.m_MaxAssignedLimit = 8

	self.m_AllObjectives = {}
	self.m_Translations = {}

	self.m_McomCounter = 0
	self.m_OnlyOneMcom = false
	self.m_RushAttackingBase = ''
	self.m_ArmedMcoms = {}

end

-- =============================================
-- Events
-- =============================================

-- =============================================
	-- Level Events
-- =============================================

function GameDirector:OnLevelLoaded()
	self.m_AllObjectives = {}
	self.m_Translations = {}
	self:_RegisterMcomEventCallbacks()
	-- TODO, assign weights to each objective
	self.m_UpdateLast = 0
	self:_InitObjectives()
end

function GameDirector:OnRoundOver(p_RoundTime, p_WinningTeam)
	self.m_UpdateLast = -1
end

function GameDirector:OnRoundReset(p_RoundTime, p_WinningTeam)
	self.m_AllObjectives = {}
	self.m_UpdateLast = 0
end

-- =============================================
	-- CapturePoint Events
-- =============================================

function GameDirector:OnPlayerEnteredCapturePoint(p_Player, p_CapturePoint)
	p_CapturePoint = CapturePointEntity(p_CapturePoint)
	local s_ObjectiveName = self:_TranslateObjective(p_CapturePoint.transform.trans, p_CapturePoint.name)
	self:_UpdateObjective(s_ObjectiveName, {
		-- team = p_CapturePoint.team,
		isAttacked = p_CapturePoint.isAttacked
	})
end

function GameDirector:OnCapturePointCaptured(p_CapturePoint)
	p_CapturePoint = CapturePointEntity(p_CapturePoint)
	local s_ObjectiveName = self:_TranslateObjective(p_CapturePoint.transform.trans, p_CapturePoint.name)
	self:_UpdateObjective(s_ObjectiveName, {
		team = p_CapturePoint.team,
		isAttacked = p_CapturePoint.isAttacked
	})

	local s_Objective = self:_GetObjectiveObject(s_ObjectiveName)
	if s_Objective == nil then
		return
	end

	m_Logger:Write('GameDirector:_onCapture: '..s_ObjectiveName)
	m_Logger:Write('self.CurrentAssignedCount: '..g_Utilities:dump(s_Objective.assigned, true))

	for l_BotTeam, l_Bots in pairs(self.m_BotsByTeam) do
		for i = 1, #l_Bots do
			if (l_Bots[i]:getObjective() == s_Objective.name and s_Objective.team == l_BotTeam) then
				m_Logger:Write('Bot completed objective: '..l_Bots[i].m_Name..' (team: '..l_BotTeam..') -> '..s_Objective.name)

				l_Bots[i]:setObjective()
				s_Objective.assigned[l_BotTeam] = math.max(s_Objective.assigned[l_BotTeam] - 1, 0)
			end
		end
	end
end

function GameDirector:OnCapturePointLost(p_CapturePoint)
	p_CapturePoint = CapturePointEntity(p_CapturePoint)
	local s_ObjectiveName = self:_TranslateObjective(p_CapturePoint.transform.trans, p_CapturePoint.name)
	local s_IsAttacked = p_CapturePoint.flagLocation < 100.0 and p_CapturePoint.isControlled
	self:_UpdateObjective(s_ObjectiveName, {
		team = TeamId.TeamNeutral, --p_CapturePoint.team
		isAttacked = s_IsAttacked
	})

	m_Logger:Write('GameDirector:_onLost: ' .. s_ObjectiveName)
end

function GameDirector:OnEngineUpdate(p_DeltaTime)
	if self.m_UpdateLast >= 0 then
		self.m_UpdateLast = self.m_UpdateLast + p_DeltaTime
	end
	if self.m_UpdateLast < self.m_UpdateInterval then
		return
	end
	self.m_UpdateLast = 0

	--update bot -> team list
	local s_BotList = g_BotManager:getBots()
	self.m_BotsByTeam = {}
	for i = 1, #s_BotList do
		if not s_BotList[i]:isInactive() and s_BotList[i].m_Player ~= nil then
			if self.m_BotsByTeam[s_BotList[i].m_Player.teamId] == nil then
				self.m_BotsByTeam[s_BotList[i].m_Player.teamId] = {}
			end

			table.insert(self.m_BotsByTeam[s_BotList[i].m_Player.teamId], s_BotList[i])
		end
	end

	local s_MaxAssigns = {}
	for i = 1, Globals.NrOfTeams do
		s_MaxAssigns[i] = 0
		if self.m_BotsByTeam[i] ~= nil then
			s_MaxAssigns[i] = math.floor((#self.m_BotsByTeam[i] / Globals.NrOfTeams) + 1)
			if (#self.m_BotsByTeam[i] % 2) == 1 then
				s_MaxAssigns[i] = s_MaxAssigns[i] + 1
			end
		end
		if s_MaxAssigns[i] > self.m_MaxAssignedLimit then
			s_MaxAssigns[i] = self.m_MaxAssignedLimit
		end
		if self.m_OnlyOneMcom then
			if self.m_BotsByTeam[i] ~= nil then
				s_MaxAssigns[i] = #self.m_BotsByTeam[i]
			end
		end
	end

	-- check objective statuses
	for l_BotTeam, l_Bots in pairs(self.m_BotsByTeam) do
		for _, l_Objective in pairs(self.m_AllObjectives) do
			l_Objective.assigned[l_BotTeam] = 0
		end
	end

	for l_BotTeam, l_Bots in pairs(self.m_BotsByTeam) do
		for _, l_Bot in pairs(l_Bots) do
			if l_Bot:getObjective() == '' then
				if not l_Bot.m_Player.alive then
					goto continue_inner_loop
				end
				-- find closest objective for bot
				local s_ClosestDistance = nil
				local s_ClosestObjective = nil
				for _, l_Objective in pairs(self.m_AllObjectives) do
					if l_Objective.subObjective then
						goto continue_inner_inner_loop
					end
					if l_Objective.isBase or not l_Objective.active or l_Objective.destroyed or l_Objective.isEnterVehiclePath then
						goto continue_inner_inner_loop
					end
					if l_Objective.team == l_BotTeam then
						goto continue_inner_inner_loop
					end
					if l_Objective.assigned[l_BotTeam] < s_MaxAssigns[l_BotTeam] then
						local s_Distance = self:_GetDistanceFromObjective(l_Objective.name, l_Bot.m_Player.soldier.worldTransform.trans)
						if s_ClosestDistance == nil or s_ClosestDistance > s_Distance then
							s_ClosestDistance = s_Distance
							s_ClosestObjective = l_Objective.name
						end
					end
					::continue_inner_inner_loop::
				end
				if s_ClosestObjective ~= nil then
					local s_Objective = self:_GetObjectiveObject(s_ClosestObjective)
					l_Bot:setObjective(s_ClosestObjective)
					m_Logger:Write("Team "..tostring(l_BotTeam).." with "..l_Bot.m_Name.." gets this objective: "..s_ClosestObjective)
					s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] + 1
				end
			else
				if not l_Bot.m_Player.alive then
					l_Bot:setObjective() -- reset objective on death
					goto continue_inner_loop
				end
				local s_Objective = self:_GetObjectiveObject(l_Bot:getObjective())
				local s_ParentObjective = self:_GetObjectiveFromSubObj(s_Objective.name)
				s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] + 1
				if s_ParentObjective ~= nil then
					local s_TempObjective = self:_GetObjectiveObject(s_ParentObjective)
					if s_TempObjective.active and not s_TempObjective.destroyed then
						s_TempObjective.assigned[l_BotTeam] = s_TempObjective.assigned[l_BotTeam] + 1
						-- check for leave of subObjective
						if not self:_UseSubobjective(l_BotTeam, s_Objective.name) then
							l_Bot:setObjective(s_ParentObjective)
						end
					end
				end
				if s_Objective.isBase or not s_Objective.active or s_Objective.destroyed or s_Objective.team == l_BotTeam then
					l_Bot:setObjective()
				end
			end
			::continue_inner_loop::
		end
	end
end

-- =============================================
	-- MCOM Events
-- =============================================

function GameDirector:OnMcomArmed(p_Player)
	m_Logger:Write("mcom armed by "..p_Player.name)

	local s_Objective = self:_TranslateObjective(p_Player.soldier.worldTransform.trans)
	if self.m_ArmedMcoms[p_Player.name] == nil then
		self.m_ArmedMcoms[p_Player.name] = {}
	end
	table.insert(self.m_ArmedMcoms[p_Player.name], s_Objective)

	self:_UpdateObjective(s_Objective, {
		team = p_Player.teamId,
		isAttacked = true
	})
end

function GameDirector:OnMcomDisarmed(p_Player)
	local s_Objective = self:_TranslateObjective(p_Player.soldier.worldTransform.trans)
	-- remove information of armed mcom
	for l_PlayerName, l_McomsOfPlayer in pairs(self.m_ArmedMcoms) do
		if l_McomsOfPlayer ~= nil and #l_McomsOfPlayer > 0 then
			for i, l_McomName in pairs(l_McomsOfPlayer) do
				if l_McomName == s_Objective then
					table.remove(self.m_ArmedMcoms[l_PlayerName], i)
					break
				end
			end
		end
	end
	self:_UpdateObjective(s_Objective, {
		team = TeamId.TeamNeutral,--p_Player.teamId,
		isAttacked = false
	})
end

function GameDirector:OnMcomDestroyed(p_Player)
	m_Logger:Write("mcom destroyed by "..p_Player.name)

	local s_Objective = ''
	if self.m_ArmedMcoms[p_Player.name] ~= nil then
		s_Objective = self.m_ArmedMcoms[p_Player.name][1]
		table.remove(self.m_ArmedMcoms[p_Player.name], 1)
	end

	self.m_McomCounter = self.m_McomCounter + 1
	self:_UpdateObjective(s_Objective, {
		team = TeamId.TeamNeutral,--p_Player.teamId,
		isAttacked = false,
		destroyed = true
	})
	local s_SubObjective = self:_GetSubObjectiveFromObj(s_Objective)
	local s_TopObjective = self:_GetObjectiveFromSubObj(s_Objective)
	if s_TopObjective ~= nil then
		self:_UpdateObjective(s_TopObjective, {
			destroyed = true
		})
	end
	if s_SubObjective ~= nil then
		self:_UpdateObjective(s_SubObjective, {
			destroyed = true
		})
	end
	self:_UpdateValidObjectives()
end

-- =============================================
	-- Vehicle Events
-- =============================================

function GameDirector:OnVehicleSpawnDone(p_Entity)
	p_Entity = ControllableEntity(p_Entity)
	self:_SetVehicleObjectiveState(p_Entity.transform.trans, true)
end

function GameDirector:OnVehicleEnter(p_Entity, p_Player)
	if not Utilities:isBot(p_Player) then
		p_Entity = ControllableEntity(p_Entity)
		self:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================

function GameDirector:CheckForExecution(p_Point, p_TeamId)
	if p_Point.Data.Action == nil then
		return false
	end
	local s_Action = p_Point.Data.Action
	if s_Action.type ~= "mcom" then
		return true
	end
	local s_Mcom = self:_TranslateObjective(p_Point.Position)
	if s_Mcom == nil then
		return false
	end
	local s_Objective = self:_GetObjectiveObject(s_Mcom)
	if s_Objective == nil then
		return false
	end
	if s_Objective.active and not s_Objective.destroyed then
		if p_TeamId == TeamId.Team1 and s_Objective.team == TeamId.TeamNeutral then
			return true -- Attacking Team
		elseif p_TeamId == TeamId.Team2 and s_Objective.isAttacked then
			return true -- Defending Team
		end
	end
	return false
end

function GameDirector:FindClosestPath(p_Trans, p_VehiclePath)
	local s_ClosestPathNode = nil
	local s_Paths = m_NodeCollection:GetPaths()
	if s_Paths ~= nil then
		local s_ClosestDistance = nil
		for _, l_Waypoints in pairs(s_Paths) do
			if (p_VehiclePath and l_Waypoints[1].Data.Vehicles ~= nil) or not p_VehiclePath then
				local s_NewDistance = l_Waypoints[1].Position:Distance(p_Trans)
				if s_ClosestDistance == nil then
					s_ClosestDistance = s_NewDistance
					s_ClosestPathNode = l_Waypoints[1]
				else
					if s_NewDistance < s_ClosestDistance then
						s_ClosestDistance = s_NewDistance
						s_ClosestPathNode = l_Waypoints[1]
					end
				end
			end
		end
	end
	return s_ClosestPathNode
end

function GameDirector:GetSpawnPath(p_TeamId, p_SquadId, p_OnlyBase)
	-- find referece-objective
	local s_ReferenceObjective = nil
	for _, l_ReferenceObjective in pairs(self.m_AllObjectives) do
		if not l_ReferenceObjective.isEnterVehiclePath and not l_ReferenceObjective.IsBasePath and not l_ReferenceObjective.isSpawnPath then
			if l_ReferenceObjective.team == TeamId.TeamNeutral then
				s_ReferenceObjective = l_ReferenceObjective
				break
			elseif l_ReferenceObjective.team ~= p_TeamId then
				s_ReferenceObjective = l_ReferenceObjective
			end
		end
	end

	local s_PossibleObjectives = {}
	local s_AttackedObjectives = {}
	local s_ClosestObjective = nil
	local s_ClosestDistance = nil
	local s_PossibleBases = {}
	local s_RushConvertedBases = {}
	local s_PathsDone = {}
	for _, l_Objective in pairs(self.m_AllObjectives) do
		local s_AllObjectives = m_NodeCollection:GetKnownOjectives()
		local s_PathsWithObjective = s_AllObjectives[l_Objective.name]

		if s_PathsWithObjective == nil then
			-- can only happen if the collection was cleared. So don't spawn in this case
			return 0 , 0
		end

		for _, l_Path in pairs(s_PathsWithObjective) do
			if s_PathsDone[l_Path] then
				goto continue_paths_loop
			end
			local s_Node = m_NodeCollection:Get(1, l_Path)
			if s_Node == nil or s_Node.Data.Objectives == nil or #s_Node.Data.Objectives ~= 1 then
				goto continue_paths_loop
			end
			-- possible path
			if l_Objective.team == p_TeamId and l_Objective.active then
				if l_Objective.isBase then
					table.insert(s_PossibleBases, l_Path)
				elseif not p_OnlyBase then
					if l_Objective.isAttacked then
						table.insert(s_AttackedObjectives, {name = l_Objective.name, path = l_Path})
					else
						table.insert(s_PossibleObjectives, {name = l_Objective.name, path = l_Path})
					end
					if s_ReferenceObjective ~= nil and s_ReferenceObjective.position ~= nil and l_Objective.position ~= nil then
						local s_DistanceToRef = s_ReferenceObjective.position:Distance(l_Objective.position)
						if s_ClosestDistance == nil or s_DistanceToRef < s_ClosestDistance then
							s_ClosestDistance = s_DistanceToRef
							s_ClosestObjective = {name = l_Objective.name, path = l_Path}
						end
					end
				end
			elseif l_Objective.team ~= p_TeamId and l_Objective.isBase and not l_Objective.active and l_Objective.name == self.m_RushAttackingBase then --rush attacking team
				table.insert(s_RushConvertedBases, l_Path)
			end
			s_PathsDone[l_Path] = true
			::continue_paths_loop::
		end
	end

	-- spawn in base from time to time to get a vehicle
	-- TODO: do this dependant of vehicle available
	if not p_OnlyBase and #s_PossibleBases > 0 and MathUtils:GetRandomInt(0, 100) < 10 then
		m_Logger:Write("spwawn at base because of randomness")
		local s_PathIndex = s_PossibleBases[MathUtils:GetRandomInt(1, #s_PossibleBases)]
		return s_PathIndex, MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_PathIndex))
	end

	-- spawn in order of priority
	if #s_AttackedObjectives > 0 then
		m_Logger:Write("spawn at attaced objective")
		return self:GetSpawnPathOfObjectives(s_AttackedObjectives)
	elseif s_ClosestObjective ~= nil then
		m_Logger:Write("spwawn at closest objective")
		return self:GetSpawnPathOfObjectives({s_ClosestObjective})
	elseif #s_PossibleObjectives > 0 then
		m_Logger:Write("spwawn at random objective")
		return self:GetSpawnPathOfObjectives(s_PossibleObjectives)
	elseif #s_PossibleBases > 0 then
		m_Logger:Write("spwawn at base")
		local s_PathIndex = s_PossibleBases[MathUtils:GetRandomInt(1, #s_PossibleBases)]
		return s_PathIndex, MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_PathIndex))
	elseif #s_RushConvertedBases > 0 then
		local s_PathIndex = s_RushConvertedBases[MathUtils:GetRandomInt(1, #s_RushConvertedBases)]
		return s_PathIndex, MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_PathIndex))
	else
		return 0, 0
	end
end

function GameDirector:GetSpawnPathOfObjectives(p_PossibleObjectives)
	local s_TempObject = p_PossibleObjectives[MathUtils:GetRandomInt(1, #p_PossibleObjectives)]
	local s_AvailableSpawnPaths = nil
	for _, l_Objective in pairs(self.m_AllObjectives) do
		if l_Objective.isSpawnPath and string.find(l_Objective.name, s_TempObject.name) ~= nil then
			s_AvailableSpawnPaths = l_Objective.name
			break
		end
	end
	-- check for spawn objectives
	if s_AvailableSpawnPaths ~= nil then
		local s_AllObjectives = m_NodeCollection:GetKnownOjectives()
		local s_PathsWithObjective = s_AllObjectives[s_AvailableSpawnPaths]
		return s_PathsWithObjective[MathUtils:GetRandomInt(1, #s_PathsWithObjective)], 1
	else
		return s_TempObject.path, MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_TempObject.path))
	end
end

function GameDirector:IsBasePath(p_ObjectiveNames)
	local s_IsBase = false
	for _, l_ObjectiveName in pairs(p_ObjectiveNames) do
		local s_Objective = self:_GetObjectiveObject(l_ObjectiveName)
		if s_Objective ~= nil and s_Objective.isBase then
			s_IsBase = true
			break
		end
	end
	return s_IsBase
end

-- 0 = all inactive
-- 1 = partly inactive
-- 2 = all active
function GameDirector:GetEnableStateOfPath(p_ObjectiveNamesOfPath)
	local s_ActiveCount = 0
	for _, l_ObjectiveName in pairs(p_ObjectiveNamesOfPath) do
		local s_Objective = self:_GetObjectiveObject(l_ObjectiveName)
		if s_Objective ~= nil and s_Objective.active then
			s_ActiveCount = s_ActiveCount + 1
		end
	end
	if s_ActiveCount == 0 then
		return 0
	elseif s_ActiveCount < #p_ObjectiveNamesOfPath then
		return 1
	else
		return 2
	end
end

function GameDirector:UseVehicle(p_BotName, p_Objective)
	local s_TempObjective = self:_GetObjectiveObject(p_Objective)
	if s_TempObjective ~= nil and s_TempObjective.active and s_TempObjective.isEnterVehiclePath then
		s_TempObjective.active = false
		return true
	end
	return false
end

function GameDirector:UseSubobjective(p_BotName, p_Objective)
	local s_TempObjective = self:_GetObjectiveObject(p_Objective)
	if s_TempObjective ~= nil and s_TempObjective.subObjective then -- is valid getSubObjective
		if s_TempObjective.active and not s_TempObjective.destroyed then
			local s_Bot = g_BotManager:getBotByName(p_BotName)
			local s_BotTeam = s_Bot.m_Player.teamId
			if self:_UseSubobjective(s_BotTeam, p_Objective) then
				if s_TempObjective.assigned[s_BotTeam] < 2 then
					s_TempObjective.assigned[s_BotTeam] = s_TempObjective.assigned[s_BotTeam] + 1
					s_Bot:setObjective(p_Objective)
					return true
				end
			end
		end
	end
	return false
end

-- =============================================
-- Private Functions
-- =============================================

function GameDirector:_RegisterMcomEventCallbacks()
	if not Globals.IsRush then
		return
	end
	self.m_McomCounter = 0
	self.m_ArmedMcoms = {}

	local s_Iterator = EntityManager:GetIterator("EventSplitterEntity")
	local s_Entity = s_Iterator:Next()
	while s_Entity do
		if s_Entity.data == nil then
			goto continue_entity_loop
		end
		if s_Entity.data.instanceGuid == Guid("87E78B77-78F9-4DE0-82FF-904CDC2F7D03") then
			s_Entity:RegisterEventCallback(function(p_Entity, p_EntityEvent)
				Events:Dispatch('MCOM:Armed', p_EntityEvent.player)
			end)
		elseif s_Entity.data.instanceGuid == Guid("74B7AD6D-8EB5-40B1-BB53-C0CFB956048E") then
			s_Entity:RegisterEventCallback(function(p_Entity, p_EntityEvent)
				Events:Dispatch('MCOM:Disarmed', p_EntityEvent.player)
			end)
		elseif s_Entity.data.instanceGuid == Guid("70B36E2F-0B6F-40EC-870B-1748239A63A8") then
			s_Entity:RegisterEventCallback(function(p_Entity, p_EntityEvent)
				Events:Dispatch('MCOM:Destroyed', p_EntityEvent.player)
			end)
		end
		::continue_entity_loop::
		s_Entity = s_Iterator:Next()
	end
end

function GameDirector:_InitObjectives()
	self.m_AllObjectives = {}
	for l_ObjectiveName, _ in pairs(m_NodeCollection:GetKnownOjectives()) do
		local s_Objective = {
			name = l_ObjectiveName,
			team = TeamId.TeamNeutral,
			position = nil,
			isAttacked = false,
			isBase = false,
			isSpawnPath = false,
			isEnterVehiclePath = false,
			destroyed = false,
			active = true,
			subObjective = false,
			assigned = {}
		}
		if string.find(l_ObjectiveName:lower(), "base") ~= nil then
			s_Objective.isBase = true
			if string.find(l_ObjectiveName:lower(), "us") ~= nil then
				s_Objective.team = TeamId.Team1
			else
				s_Objective.team = TeamId.Team2
			end
		end
		if string.find(l_ObjectiveName:lower(), "spawn") ~= nil then
			s_Objective.isSpawnPath = true
			s_Objective.active = false
		end
		if string.find(l_ObjectiveName:lower(), "vehicle") ~= nil then
			s_Objective.isEnterVehiclePath = true
			s_Objective.active = false
		end
		table.insert(self.m_AllObjectives, s_Objective)
	end
	self:_InitFlagTeams()
	self:_UpdateValidObjectives()
end

function GameDirector:_InitFlagTeams()
	if not Globals.IsConquest then -- valid for all Conquest-types
		return
	end
	local s_Iterator = EntityManager:GetIterator('ServerCapturePointEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		s_Entity = CapturePointEntity(s_Entity)
		local s_ObjectiveName = self:_TranslateObjective(s_Entity.transform.trans, s_Entity.name)
		if s_ObjectiveName ~= "" then
			local s_Objective = self:_GetObjectiveObject(s_ObjectiveName)
			if not s_Objective.isBase then
				self:_UpdateObjective(s_ObjectiveName, {
					team = s_Entity.team,
					isAttacked = s_Entity.isAttacked
				})
			end
		end
		s_Entity = s_Iterator:Next()
	end
end

function GameDirector:_UpdateValidObjectives()
	if Globals.IsConquest then -- nothing to do in conquest
		return
	end

	if (self.m_McomCounter % 2) == 0 then
		self.m_OnlyOneMcom = false
		local s_BaseIndex = 0
		local s_McomIndexes = {0, 0}
		if self.m_McomCounter < 2 then
			s_BaseIndex = 1
			s_McomIndexes = {1, 2}
		elseif self.m_McomCounter < 4 then
			s_BaseIndex = 2
			s_McomIndexes = {3, 4}
		elseif self.m_McomCounter < 6 then
			s_BaseIndex = 3
			s_McomIndexes = {5, 6}
		elseif self.m_McomCounter < 8 then
			s_BaseIndex = 4
			s_McomIndexes = {7, 8}
		elseif self.m_McomCounter < 10 then
			s_BaseIndex = 5
			s_McomIndexes = {9, 10}
		else
			s_BaseIndex = 6
			s_McomIndexes = {11, 12}
		end

		for _, l_Objective in pairs(self.m_AllObjectives) do
			local s_Fields = l_Objective.name:split(" ")
			local s_Active = false
			local s_SubObjective = false
			if l_Objective.isSpawnPath or l_Objective.isEnterVehiclePath then
				goto continue_objective_loop
			end
			if not l_Objective.isBase then
				if #s_Fields > 1 then
					local s_Index = tonumber(s_Fields[2])
					for _, l_TargetIndex in pairs(s_McomIndexes) do
						if s_Index == l_TargetIndex then
							s_Active = true
						end
					end
					if #s_Fields > 2 then -- "mcom N interact"
						s_SubObjective = true
					end
				end
			else
				if #s_Fields > 2 then
					local s_Index = tonumber(s_Fields[3])
					if s_Index == s_BaseIndex then
						s_Active = true
					end
					if s_Index == s_BaseIndex - 1 then
						self.m_RushAttackingBase = l_Objective.name
					end
				end
			end
			l_Objective.active = s_Active
			l_Objective.subObjective = s_SubObjective
			::continue_objective_loop::
		end
	else
		self.m_OnlyOneMcom = true
	end
end

function GameDirector:_SetVehicleObjectiveState(p_Position, p_Value)
	local s_Paths = m_NodeCollection:GetPaths()
	if s_Paths == nil then
		return
	end
	local s_ClosestDistance = nil
	local s_ClosestVehicleEnterObjective = nil
	for _, l_Waypoints in pairs(s_Paths) do
		if l_Waypoints[1].Data ~= nil and l_Waypoints[1].Data.Objectives ~= nil and #l_Waypoints[1].Data.Objectives == 1 then
			local s_ObjectiveObject = self:_GetObjectiveObject(l_Waypoints[1].Data.Objectives[1])
			if s_ObjectiveObject ~= nil and s_ObjectiveObject.active ~= p_Value and s_ObjectiveObject.isEnterVehiclePath then  -- only check disabled objectives
				-- check position of first and last node
				local s_FirstNode = l_Waypoints[1]
				local s_LastNode = l_Waypoints[#l_Waypoints]
				local s_TempDistanceFirst = s_FirstNode.Position:Distance(p_Position)
				local s_TempDistanceLast = s_LastNode.Position:Distance(p_Position)
				local s_CloserDistance = s_TempDistanceFirst
				if s_TempDistanceLast < s_TempDistanceFirst then
					s_CloserDistance = s_TempDistanceLast
				end
				if s_ClosestDistance == nil or s_CloserDistance < s_ClosestDistance then
					s_ClosestDistance = s_CloserDistance
					s_ClosestVehicleEnterObjective = s_ObjectiveObject
				end
			end
		end
	end
	if s_ClosestVehicleEnterObjective ~= nil and s_ClosestDistance < 5 then
		s_ClosestVehicleEnterObjective.active = p_Value
	end
end

function GameDirector:_UpdateObjective(p_Name, p_Data)
	for _, l_Objective in pairs(self.m_AllObjectives) do
		if l_Objective.name == p_Name then
			for l_Key, l_Value in pairs(p_Data) do
				l_Objective[l_Key] = l_Value
			end
			break
		end
	end
end

function GameDirector:_GetDistanceFromObjective(p_Objective, p_Position)
	local s_Distance = math.huge
	if p_Objective == '' then
		return s_Distance
	end
	local s_AllObjectives = m_NodeCollection:GetKnownOjectives()
	local s_Paths = s_AllObjectives[p_Objective]
	for _, l_Path in pairs(s_Paths) do
		local s_Node = m_NodeCollection:Get(1, l_Path)
		if s_Node ~= nil and s_Node.Data.Objectives ~= nil then
			if #s_Node.Data.Objectives == 1 then
				s_Distance = p_Position:Distance(s_Node.Position)
				break
			end
		end
	end
	return s_Distance
end

function GameDirector:_TranslateObjective(p_Position, p_Name)
	if p_Name ~= nil and self.m_Translations[p_Name] ~= nil then
		return self.m_Translations[p_Name]
	end
	local s_AllObjectives = m_NodeCollection:GetKnownOjectives()
	local s_PathsDone = {}
	local s_ClosestObjective = ""
	local s_ClosestDistance = nil
	for l_Objective, l_Paths in pairs(s_AllObjectives) do
		for _, l_Path in pairs(l_Paths) do
			if s_PathsDone[l_Path] then
				goto continue_paths_loop
			end
			local s_Node = m_NodeCollection:Get(1, l_Path)
			if s_Node == nil or s_Node.Data.Objectives == nil or #s_Node.Data.Objectives ~= 1 then
				goto continue_paths_loop
			end
			-- possible objective
			local s_TempObject = self:_GetObjectiveObject(l_Objective)
			if s_TempObject == nil or (not s_TempObject.isSpawnPath and not s_TempObject.isEnterVehiclePath) then -- or not s_TempObject.isBase
				local s_Distance = p_Position:Distance(s_Node.Position)
				if s_ClosestDistance == nil or s_ClosestDistance > s_Distance then
					s_ClosestObjective = s_TempObject
					s_ClosestDistance = s_Distance
				end
			end
			s_PathsDone[l_Path] = true
			::continue_paths_loop::
		end
	end
	if p_Name ~= nil then
		self.m_Translations[p_Name] = s_ClosestObjective.name
		s_ClosestObjective.position = p_Position
	end
	return s_ClosestObjective.name
end

function GameDirector:_GetObjectiveObject(p_Name)
	for _, l_Objective in pairs(self.m_AllObjectives) do
		if l_Objective.name == p_Name then
			return l_Objective
		end
	end
end

function GameDirector:_GetSubObjectiveFromObj(p_Objective)
	for _, l_TempObjective in pairs(self.m_AllObjectives) do
		if l_TempObjective.subObjective then
			local s_Name = l_TempObjective.name:lower()
			if string.find(s_Name, p_Objective:lower()) ~= nil then
				return l_TempObjective.name
			end
		end
	end
end

function GameDirector:_GetObjectiveFromSubObj(p_SubObjective)
	for _, l_TempObjective in pairs(self.m_AllObjectives) do
		if not l_TempObjective.subObjective then
			local s_Name = l_TempObjective.name:lower()
			if string.find(p_SubObjective:lower(), s_Name) ~= nil then
				return l_TempObjective.name
			end
		end
	end
end

function GameDirector:_UseSubobjective(p_BotTeam, p_ObjectiveName)
	local s_Use = false
	local s_Objective = self:_GetObjectiveObject(p_ObjectiveName)
	if s_Objective ~= nil and s_Objective.subObjective then
		if s_Objective.active and not s_Objective.destroyed then
			if p_BotTeam == TeamId.Team1 and s_Objective.team == TeamId.TeamNeutral then
				s_Use = true --Attacking Team
			elseif p_BotTeam == TeamId.Team2 and s_Objective.isAttacked then
				s_Use = true --Defending Team
			end
		end
	end
	return s_Use
end

if g_GameDirector == nil then
	g_GameDirector = GameDirector()
end

return g_GameDirector
