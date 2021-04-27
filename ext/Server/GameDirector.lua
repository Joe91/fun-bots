class('GameDirector')

local m_NodeCollection = require('__shared/NodeCollection')
local m_Logger = Logger("GameDirector", Debug.Server.GAMEDIRECTOR)

function GameDirector:__init()
	self.UpdateLast = -1
	self.UpdateInterval = 1.5 -- seconds interval

	self.BotsByTeam = {}

	self.MaxAssignedLimit = 8

	self.AllObjectives = {}
	self.Translations = {}

	self.McomCounter = 0
	self.OnlyOneMcom = false
	self.RushAttackingBase = ''
	self.ArmedMcoms = {}
end

function GameDirector:onLevelLoaded()
	self.AllObjectives = {}
	self.Translations = {}

	if Globals.IsRush then
		self.McomCounter = 0
		self.ArmedMcoms = {}

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

	-- TODO, assign weights to each objective

	self.UpdateLast = 0
end

function GameDirector:initObjectives()
	self.AllObjectives = {}
	for objectiveName,_ in pairs(m_NodeCollection:GetKnownOjectives()) do
		local objective = {
			name = objectiveName,
			team = TeamId.TeamNeutral,
			isAttacked = false,
			isBase = false,
			isSpawnPath = false,
			isEnterVehiclePath = false,
			destroyed = false,
			active = true,
			subObjective = false,
			assigned = {}
		}
		if string.find(objectiveName:lower(), "base") ~= nil then
			objective.isBase = true
			if string.find(objectiveName:lower(), "us") ~= nil then
				objective.team = TeamId.Team1
			else
				objective.team = TeamId.Team2
			end
		end
		if string.find(objectiveName:lower(), "spawn") ~= nil then
			objective.isSpawnPath = true
			objective.active = false
		end
		if string.find(objectiveName:lower(), "vehicle") ~= nil then
			objective.isEnterVehiclePath = true
			objective.active = false
		end
		table.insert(self.AllObjectives, objective)
	end
	self:_initFlagTeams()
	self:_updateValidObjectives()
end

function GameDirector:_initFlagTeams()
	if Globals.IsConquest then --valid for all Conquest-types
		local it = EntityManager:GetIterator('ServerCapturePointEntity')
		local entity = it:Next()
		while entity ~= nil do
			local flagEntity = CapturePointEntity(entity)
			local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name)
			if objectiveName ~= "" then
				local objective = self:getObjectiveObject(objectiveName)
				if not objective.isBase then
					self:_updateObjective(objectiveName, {
						team = flagEntity.team,
						isAttacked = flagEntity.isAttacked
					})
				end
			end
			entity = it:Next()
		end
	end
end

function GameDirector:OnMcomArmed(p_Player)
	m_Logger:Write("mcom armed by "..p_Player.name)

	local objective = self:_translateObjective(p_Player.soldier.worldTransform.trans)
	if self.ArmedMcoms[p_Player.name] == nil then
		self.ArmedMcoms[p_Player.name] = {}
	end
	table.insert(self.ArmedMcoms[p_Player.name], objective)

	self:_updateObjective(objective, {
		team = p_Player.teamId,
		isAttacked = true
	})
end

function GameDirector:OnMcomDisarmed(p_Player)
	local objective = self:_translateObjective(p_Player.soldier.worldTransform.trans)
	-- remove information of armed mcom
	for playerMcom,mcomsOfPlayer in pairs(self.ArmedMcoms) do
		if mcomsOfPlayer ~= nil and #mcomsOfPlayer > 0 then
			for i,mcomName in pairs(mcomsOfPlayer) do
				if mcomName == objective then
					table.remove(self.ArmedMcoms[playerMcom], i)
					break
				end
			end
		end
	end
	self:_updateObjective(objective, {
		team = TeamId.TeamNeutral,--p_Player.teamId,
		isAttacked = false
	})
end

function GameDirector:OnMcomDestroyed(p_Player)
	m_Logger:Write("mcom destroyed by "..p_Player.name)

	local objective = ''
	if self.ArmedMcoms[p_Player.name] ~= nil then
		objective = self.ArmedMcoms[p_Player.name][1]
		table.remove(self.ArmedMcoms[p_Player.name], 1)
	end

	self.McomCounter = self.McomCounter + 1
	self:_updateObjective(objective, {
		team = TeamId.TeamNeutral,--p_Player.teamId,
		isAttacked = false,
		destroyed = true
	})
	local subObjective = self:getSubObjectiveFromObj(objective)
	local topObjective = self:getObjectiveFromSubObj(objective)
	if topObjective ~= nil then
		self:_updateObjective(topObjective, {
			destroyed = true
		})
	end
	if subObjective ~= nil then
		self:_updateObjective(subObjective, {
			destroyed = true
		})
	end
	self:_updateValidObjectives()
end

function GameDirector:_updateValidObjectives()
	if Globals.IsConquest then -- nothing to do in conquest
		return
	end

	if (self.McomCounter % 2) == 0 then
		self.OnlyOneMcom = false
		local baseIndex = 0
		local mcomIndexes = {0, 0}
		if self.McomCounter < 2 then
			baseIndex = 1
			mcomIndexes = {1, 2}
		elseif self.McomCounter < 4 then
			baseIndex = 2
			mcomIndexes = {3, 4}
		elseif self.McomCounter < 6 then
			baseIndex = 3
			mcomIndexes = {5, 6}
		elseif self.McomCounter < 8 then
			baseIndex = 4
			mcomIndexes = {7, 8}
		elseif self.McomCounter < 10 then
			baseIndex = 5
			mcomIndexes = {9, 10}
		else
			baseIndex = 6
			mcomIndexes = {11, 12}
		end

		for _,objective in pairs(self.AllObjectives) do
			local fields = objective.name:split(" ")
			local active = false
			local subObjective = false
			if not objective.isSpawnPath and not objective.isEnterVehiclePath then
				if not objective.isBase then
					if #fields > 1 then
						local index = tonumber(fields[2])
						for _,targetIndex in pairs(mcomIndexes) do
							if index == targetIndex then
								active = true
							end
						end
						if #fields > 2 then -- "mcom N interact"
							subObjective = true
						end
					end
				else
					if #fields > 2 then
						local index = tonumber(fields[3])
						if index == baseIndex then
							active = true
						end
						if index == baseIndex - 1 then
							self.RushAttackingBase = objective.name
						end
					end
				end
				objective.active = active
				objective.subObjective = subObjective
			end
		end
	else
		self.OnlyOneMcom = true
	end
end

function GameDirector:checkForExecution(p_Point, p_TeamId)
	local execute = false
	if p_Point.Data.Action ~= nil then
		local action = p_Point.Data.Action
		if action.type == "mcom" then
			local mcom = self:_translateObjective(p_Point.Position)
			if mcom ~= nil then
				local objective = self:getObjectiveObject(mcom)
				if objective ~= nil then
					if objective.active and not objective.destroyed then
						if p_TeamId == TeamId.Team1 and objective.team == TeamId.TeamNeutral then
							execute = true --Attacking Team
						elseif p_TeamId == TeamId.Team2 and objective.isAttacked then
							execute = true --Defending Team
						end
					end
				end
			end
		else
			execute = true
		end
	end
	return execute
end

function GameDirector:OnVehicleEnter(p_VehicleEntiy, p_Player)
	if not Utilities:isBot(p_Player) then
		local s_Entity = ControllableEntity(p_VehicleEntiy)
		self:_SetVehicleObjectiveState(s_Entity.transform.trans, false)
	end
end

function GameDirector:OnVehicleSpawnDone(p_VehicleEntiy)
	local s_Entity = ControllableEntity(p_VehicleEntiy)
	self:_SetVehicleObjectiveState(s_Entity.transform.trans, true)
end

function GameDirector:_SetVehicleObjectiveState(p_Position, p_Value)
	local s_Paths = m_NodeCollection:GetPaths()
	if s_Paths ~= nil then
		local s_ClosestDistance = nil
		local s_ClosestVehicleEnterObjective = nil
		for _,waypoints in pairs(s_Paths) do
			if waypoints[1].Data.Objectives ~= nil and #waypoints[1].Data.Objectives == 1 then
				local s_ObjectiveObject = self:getObjectiveObject(waypoints[1].Data.Objectives[1])
				if s_ObjectiveObject ~= nil and s_ObjectiveObject.active ~= p_Value and s_ObjectiveObject.isEnterVehiclePath then  -- only check disabled objectives
					-- check position of first and last node
					local s_FirstNode = waypoints[1]
					local s_LastNode = waypoints[#waypoints]
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
			print("updated vehicle spawn-path")
			print("new value = "..tostring(p_Value))
		end
	end
end

function GameDirector:findClosestPath(p_Trans, p_VehiclePath)
	local closestPathNode = nil
	local paths = m_NodeCollection:GetPaths()
	if paths ~= nil then
		local closestDistance = nil
		for _,waypoints in pairs(paths) do
			if (p_VehiclePath and waypoints[1].Data.Vehicles ~= nil) or not p_VehiclePath then
				local newDistance = waypoints[1].Position:Distance(p_Trans)
				if closestDistance == nil then
					closestDistance = newDistance
					closestPathNode = waypoints[1]
				else
					if newDistance < closestDistance then
						closestDistance = newDistance
						closestPathNode = waypoints[1]
					end
				end
			end
		end
	end
	return closestPathNode
end

function GameDirector:getSpawnPath(p_TeamId, p_SquadId, p_OnlyBase)
	local possibleObjectives = {}
	local possibleBases = {}
	local rushConvertedBases = {}
	local pathsDone = {}
	for _,objective in pairs(self.AllObjectives) do
		local allObjectives = m_NodeCollection:GetKnownOjectives()
		local pathsWithObjective = allObjectives[objective.name]

		if pathsWithObjective == nil then
			-- can only happen if the collection was cleared. So don't spawn in this case
			return 0 , 0
		end

		for _,path in pairs(pathsWithObjective) do
			if not pathsDone[path] then
				local node = m_NodeCollection:Get(1, path)
				if node ~= nil and node.Data.Objectives ~= nil then
					if #node.Data.Objectives == 1 then --possible path
						if objective.team == p_TeamId and objective.active then
							if objective.isBase then
								table.insert(possibleBases, path)
							elseif not p_OnlyBase then
								table.insert(possibleObjectives, {name = objective.name, path = path})
							end
						elseif objective.team ~= p_TeamId and objective.isBase and not objective.active and objective.name == self.RushAttackingBase then --rush attacking team
							table.insert(rushConvertedBases, path)
						end
					end
				end
				pathsDone[path] = true
			end
		end
	end
	if #possibleObjectives > 0 then
		local tempObj = possibleObjectives[MathUtils:GetRandomInt(1, #possibleObjectives)]
		local availableSpawnPaths = nil
		for _,objective in pairs(self.AllObjectives) do
			if objective.isSpawnPath and string.find(objective.name, tempObj.name) ~= nil then
				availableSpawnPaths = objective.name
				break
			end
		end
		-- check for spawn objectives
		if availableSpawnPaths ~= nil then
			local allObjectives = m_NodeCollection:GetKnownOjectives()
			local pathsWithObjective = allObjectives[availableSpawnPaths]
			return pathsWithObjective[MathUtils:GetRandomInt(1, #pathsWithObjective)], 1
		else
			return tempObj.path, MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, tempObj.path))
		end
	elseif #possibleBases > 0 then
		local pathIndex = possibleBases[MathUtils:GetRandomInt(1, #possibleBases)]
		return pathIndex, MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, pathIndex))
	elseif #rushConvertedBases > 0 then
		local pathIndex = rushConvertedBases[MathUtils:GetRandomInt(1, #rushConvertedBases)]
		return pathIndex, MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, pathIndex))
	else
		return 0 , 0
	end
end

function GameDirector:_updateObjective(p_Name, p_Data)
	for _,objective in pairs(self.AllObjectives) do
		if objective.name == p_Name then
			for key, value in pairs(p_Data) do
				objective[key] = value
			end
			break
		end
	end
end

function GameDirector:_getDistanceFromObjective(p_Objective, p_Position)
	local distance = 0
	local allObjectives = m_NodeCollection:GetKnownOjectives()
	local paths = allObjectives[p_Objective]
	for _,path in pairs(paths) do
		local node = m_NodeCollection:Get(1, path)
		if node ~= nil and node.Data.Objectives ~= nil then
			if #node.Data.Objectives == 1 then
				distance = p_Position:Distance(node.Position)
				break
			end
		end
	end
	return distance
end

function GameDirector:_translateObjective(p_Position, p_Name)
	if p_Name == nil or self.Translations[p_Name] == nil then
		local allObjectives = m_NodeCollection:GetKnownOjectives()
		local pathsDone = {}
		local closestObjective = ""
		local closestDistance = nil
		for objective, paths in pairs(allObjectives) do
			for _,path in pairs(paths) do
				if not pathsDone[path] then
					local node = m_NodeCollection:Get(1, path)
					if node ~= nil and node.Data.Objectives ~= nil then
						if #node.Data.Objectives == 1 then --possible objective
							local valid = true
							local tempObj = self:getObjectiveObject(objective)
							if tempObj ~= nil and (tempObj.isSpawnPath or tempObj.isEnterVehiclePath) then -- or tempObj.isBase
								valid = false
							end
							if valid then
								local distance = p_Position:Distance(node.Position)
								if closestDistance == nil or closestDistance > distance then
									closestObjective = objective
									closestDistance = distance
								end
							end
						end
					end
					pathsDone[path] = true
				end
			end
		end
		if p_Name ~= nil then
			self.Translations[p_Name] = closestObjective
		end
		return closestObjective
	else
		return self.Translations[p_Name]
	end
end

function GameDirector:OnCapturePointCapture(p_CapturePoint)
	local flagEntity = CapturePointEntity(p_CapturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name)
	self:_updateObjective(objectiveName, {
		team = flagEntity.team,
		isAttacked = flagEntity.isAttacked
	})

	local objective = self:getObjectiveObject(objectiveName)
	if objective == nil then
		return
	end

	m_Logger:Write('GameDirector:_onCapture: '..objectiveName)
	m_Logger:Write('self.CurrentAssignedCount: '..g_Utilities:dump(objective.assigned, true))

	for botTeam, bots in pairs(self.BotsByTeam) do
		for i=1, #bots do
			if (bots[i]:getObjective() == objective.name and objective.team == botTeam) then
				m_Logger:Write('Bot completed objective: '..bots[i].m_Name..' (team: '..botTeam..') -> '..objective.name)

				bots[i]:setObjective()
				objective.assigned[botTeam] = math.max(objective.assigned[botTeam] - 1, 0)
			end
		end
	end
end

function GameDirector:getObjectiveObject(p_Name)
	for _,objective in pairs(self.AllObjectives) do
		if objective.name == p_Name then
			return objective
		end
	end
end

function GameDirector:isBasePath(p_ObjectiveNames)
	local isBase = false
	for _,name in pairs(p_ObjectiveNames) do
		local objective = self:getObjectiveObject(name)
		if objective ~= nil and objective.isBase then
			isBase = true
			break
		end
	end
	return isBase
end

-- 0 = all inactive
-- 1 = partly inactive
-- 2 = all active
function GameDirector:getEnableSateOfPath(p_ObjectiveNamesOfPath)
	local activeCount = 0
	for _,name in pairs(p_ObjectiveNamesOfPath) do
		local objective = self:getObjectiveObject(name)
		if objective ~= nil and objective.active then
			activeCount = activeCount + 1
		end
	end
	if activeCount == 0 then
		return 0
	elseif activeCount < #p_ObjectiveNamesOfPath then
		return 1
	else
		return 2
	end
end

function GameDirector:getSubObjectiveFromObj(p_Objective)
	for _,tempObjective in pairs(self.AllObjectives) do
		if tempObjective.subObjective then
			local name = tempObjective.name:lower()
			if string.find(name, p_Objective:lower()) ~= nil then
				return tempObjective.name
			end
		end
	end
end

function GameDirector:getObjectiveFromSubObj(p_SubObjective)
	for _,tempObjective in pairs(self.AllObjectives) do
		if not tempObjective.subObjective then
			local name = tempObjective.name:lower()
			if string.find(p_SubObjective:lower(), name) ~= nil then
				return tempObjective.name
			end
		end
	end
end

function GameDirector:_useSubobjective(p_BotTeam, p_ObjectiveName)
	local use = false
	local objective = self:getObjectiveObject(p_ObjectiveName)
	if objective ~= nil and objective.subObjective then
		if objective.active and not objective.destroyed then
			if p_BotTeam == TeamId.Team1 and objective.team == TeamId.TeamNeutral then
				use = true --Attacking Team
			elseif p_BotTeam == TeamId.Team2 and objective.isAttacked then
				use = true --Defending Team
			end
		end
	end
	return use
end

function GameDirector:OnCapturePointLost(p_CapturePoint)
	local flagEntity = CapturePointEntity(p_CapturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name)
	self:_updateObjective(objectiveName, {
		team = TeamId.TeamNeutral, --flagEntity.team
		isAttacked = flagEntity.isAttacked
	})

	m_Logger:Write('GameDirector:_onLost: '..objectiveName)
end

function GameDirector:OnPlayerEnterCapturePoint(p_Player, p_CapturePoint)
	local flagEntity = CapturePointEntity(p_CapturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name)
	self:_updateObjective(objectiveName, {
		isAttacked = flagEntity.isAttacked  -- team = flagEntity.team,
	})
end

function GameDirector:OnRoundOver(p_RoundTime, p_WinningTeam)
	self.UpdateLast = -1
end

function GameDirector:OnRoundReset(p_RoundTime, p_WinningTeam)
	self.AllObjectives = {}
	self.UpdateLast = 0
end

function GameDirector:OnEngineUpdate(p_DeltaTime)
	if (self.UpdateLast >= 0) then
		self.UpdateLast = self.UpdateLast + p_DeltaTime
	end

	if (self.UpdateLast >= self.UpdateInterval) then
		self.UpdateLast = 0

		--update bot -> team list
		local botList = g_BotManager:getBots()
		self.BotsByTeam = {}
		for i=1, #botList do
			if not botList[i]:isInactive() and botList[i].m_Player ~= nil then
				if (self.BotsByTeam[botList[i].m_Player.teamId] == nil) then
					self.BotsByTeam[botList[i].m_Player.teamId] = {}
				end

				table.insert(self.BotsByTeam[botList[i].m_Player.teamId], botList[i])
			end
		end

		local maxAssings = {0,0}
		for i = 1, 2 do
			if self.BotsByTeam[i] ~= nil then
				maxAssings[i] = math.floor(#self.BotsByTeam[i] / 2)
				if (#self.BotsByTeam[i] % 2) == 1 then
					maxAssings[i] = maxAssings[i] + 1
				end
			end
			if maxAssings[i] > self.MaxAssignedLimit then
				maxAssings[i] = self.MaxAssignedLimit
			end
			if self.OnlyOneMcom then
				if self.BotsByTeam[i] ~= nil then
					maxAssings[i] = #self.BotsByTeam[i]
				end
			end
		end


		-- check objective statuses
		for botTeam, bots in pairs(self.BotsByTeam) do
			for _,objective in pairs(self.AllObjectives) do
				objective.assigned[botTeam] = 0
			end
		end

		for botTeam, bots in pairs(self.BotsByTeam) do
			for _,bot in pairs(bots) do
				if bot:getObjective() == '' then
					if bot.m_Player.alive then
						-- find closest objective for bot
						local closestDistance = nil
						local closestObjective = nil
						for _,objective in pairs(self.AllObjectives) do
							if not objective.subObjective then
								if not objective.isBase and objective.active and not objective.destroyed then
									if objective.team ~= botTeam then
										if objective.assigned[botTeam] < maxAssings[botTeam] then
											local distance = self:_getDistanceFromObjective(objective.name, bot.m_Player.soldier.worldTransform.trans)
											if closestDistance == nil or closestDistance > distance then
												closestDistance = distance
												closestObjective = objective.name
											end
										end
									end
								end
							end
						end
						if (closestObjective ~= nil) then
							local objective = self:getObjectiveObject(closestObjective)
							bot:setObjective(closestObjective)
							objective.assigned[botTeam] = objective.assigned[botTeam] + 1
						end
					end
				else
					local objective = self:getObjectiveObject(bot:getObjective())
					local parentObjective = self:getObjectiveFromSubObj(objective.name)
					objective.assigned[botTeam] = objective.assigned[botTeam] + 1
					if parentObjective ~= nil then
						local tempObjective = self:getObjectiveObject(parentObjective)
						if tempObjective.active and not tempObjective.destroyed then
							tempObjective.assigned[botTeam] = tempObjective.assigned[botTeam] + 1
							-- check for leave of subObjective
							if not self:_useSubobjective(botTeam, objective.name) then
								bot:setObjective(parentObjective)
							end
						end
					end
					if objective.isBase or not objective.active or objective.destroyed or objective.team == botTeam then
						bot:setObjective()
					end
				end
			end
		end
	end
end

function GameDirector:useVehicle(p_BotName, p_Objective)
	local tempObjective = self:getObjectiveObject(p_Objective)
	if tempObjective ~= nil and tempObjective.active and tempObjective.isEnterVehiclePath then
		local bot = g_BotManager:getBotByName(p_BotName)
		bot:setObjective(p_Objective)
		tempObjective.active = false --TODO: enable again if destroyed
		print("enter vehicle")
		return true
	end
	return false
end

function GameDirector:useSubobjective(p_BotName, p_Objective)
	local tempObjective = self:getObjectiveObject(p_Objective)
	if tempObjective ~= nil and tempObjective.subObjective then -- is valid getSubObjective
		if tempObjective.active and not tempObjective.destroyed then
			local bot = g_BotManager:getBotByName(p_BotName)
			local botTeam = bot.m_Player.teamId
			if self:_useSubobjective(botTeam, p_Objective) then
				if tempObjective.assigned[botTeam] < 2 then
					tempObjective.assigned[botTeam] = tempObjective.assigned[botTeam] + 1
					bot:setObjective(p_Objective)
					return true
				end
			end
		end
	end
	return false
end

if g_GameDirector == nil then
	g_GameDirector = GameDirector()
end

return g_GameDirector
