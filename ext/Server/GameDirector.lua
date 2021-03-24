class('GameDirector');

require('Globals')
require('__shared/NodeCollection')

function GameDirector:__init()
	self.UpdateLast = -1
	self.UpdateInterval = 1.5 -- seconds interval

	self.BotsByTeam = {}

	self.MaxAssignedLimit = 8

	self.AllObjectives = {}
	self.Translations = {}

	self.McomCounter = 0;
	self.OnlyOneMcom = false;
	self.RushAttackingBase = ''
	self.ArmedMcoms = {}

	Events:Subscribe('CapturePoint:Lost', self, self._onLost)
	Events:Subscribe('CapturePoint:Captured', self, self._onCapture)
	Events:Subscribe('Player:EnteredCapturePoint', self, self._onPlayerEnterCapturePoint)

	Events:Subscribe('Server:RoundOver', self, self._onRoundOver)
	Events:Subscribe('Server:RoundReset', self, self._onRoundReset)

	Events:Subscribe('Engine:Update', self, self._onUpdate)

	Events:Subscribe('MCOM:Armed', self, self._onMcomArmed)
	Events:Subscribe('MCOM:Disarmed', self, self._onMcomDisarmed)
	Events:Subscribe('MCOM:Destroyed', self, self._onMcomDestroyed)
end

function GameDirector:onLevelLoaded()
	self.AllObjectives = {}
	self.Translations = {}

	if g_Globals.isRush then
		self.McomCounter = 0;
		self.ArmedMcoms = {}

		local mcomIterator = EntityManager:GetIterator("EventSplitterEntity")
		local mcomEntity = mcomIterator:Next()

		while mcomEntity do
			mcomEntity = Entity(mcomEntity)
			mcomEntity:RegisterEventCallback(function(ent, entityEvent)
				if ent.data.instanceGuid == Guid("87E78B77-78F9-4DE0-82FF-904CDC2F7D03") then
					Events:Dispatch('MCOM:Armed', entityEvent.player)
				end
				if ent.data.instanceGuid == Guid("74B7AD6D-8EB5-40B1-BB53-C0CFB956048E") then
					Events:Dispatch('MCOM:Disarmed', entityEvent.player)
				end
				if ent.data.instanceGuid == Guid("70B36E2F-0B6F-40EC-870B-1748239A63A8") then
					Events:Dispatch('MCOM:Destroyed', entityEvent.player)
				end
			end)
			mcomEntity = mcomIterator:Next()
		end
	end

	-- TODO, assign weights to each objective

	self.UpdateLast = 0
end

function GameDirector:initObjectives()
	self.AllObjectives = {}
	for objectiveName,_ in pairs(g_NodeCollection:GetKnownOjectives()) do
		local objective = {
			name = objectiveName,
			team = TeamId.TeamNeutral,
			isAttacked = false,
			isBase = false,
			isSpawnPath = false,
			destroyed = false,
			active = true,
			subObjective = false,
			assigned = {},
			bots = {}
		}
		if string.find(objectiveName:lower(), "base") ~= nil then
			objective.isBase = true;
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
		if g_Globals.isAssault then
			if not objective.isBase then
				objective.team = TeamId.Team2
			end
		end
		table.insert(self.AllObjectives, objective)
	end
	self:_updateValidObjectives()
end

function GameDirector:_onMcomArmed(player)
	if Debug.Server.GAMEDIRECTOR then
		print("mcom armed by "..player.name)
	end
	
	local objective = self:_translateObjective(player.soldier.worldTransform.trans);
	if self.ArmedMcoms[player.name] == nil then
		self.ArmedMcoms[player.name] = {}
	end
	table.insert(self.ArmedMcoms[player.name], objective)

	self:_updateObjective(objective, {
		team = player.teamId,
		isAttacked = true
	})
end

function GameDirector:_onMcomDisarmed(player)
	local objective = self:_translateObjective(player.soldier.worldTransform.trans);
	-- remove information of armed mcom
	for playerMcom,mcomsOfPlayer in pairs(self.ArmedMcoms) do
		if mcomsOfPlayer ~= nil and #mcomsOfPlayer > 0 then
			for i,mcomName in pairs(mcomsOfPlayer) do
				if mcomName == objective then
					table.remove(self.ArmedMcoms[playerMcom], i)
					break;
				end
			end
		end
	end
	self:_updateObjective(objective, {
		team = TeamId.TeamNeutral,--player.teamId,
		isAttacked = false
	})
end

function GameDirector:_onMcomDestroyed(player)
	if Debug.Server.GAMEDIRECTOR then
		print("mcom destroyed by "..player.name)
	end
	
	local objective = '';
	if self.ArmedMcoms[player.name] ~= nil then
		objective = self.ArmedMcoms[player.name][1]
		table.remove(self.ArmedMcoms[player.name], 1)
	end
	
	self.McomCounter = self.McomCounter + 1;
	self:_updateObjective(objective, {
		team = TeamId.TeamNeutral,--player.teamId,
		isAttacked = false,
		destroyed = true
	})
	local subObjective = self:getSubObjectiveFromObj(objective);
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
	self:_updateValidObjectives();
end

function GameDirector:_updateValidObjectives()
	if g_Globals.isConquest then
		return
	end

	if (self.McomCounter % 2) == 0 then
		self.OnlyOneMcom = false;
		local baseIndex = 0;
		local mcomIndexes = {0, 0};
		if self.McomCounter < 2 then
			baseIndex = 1;
			mcomIndexes = {1, 2};
		elseif self.McomCounter < 4 then
			baseIndex = 2;
			mcomIndexes = {3, 4};
		elseif self.McomCounter < 6 then
			baseIndex = 3;
			mcomIndexes = {5, 6};
		elseif self.McomCounter < 8 then
			baseIndex = 4;
			mcomIndexes = {7, 8};
		elseif self.McomCounter < 10 then
			baseIndex = 5;
			mcomIndexes = {9, 10};
		else
			baseIndex = 6;
			mcomIndexes = {11, 12};
		end

		for _,objective in pairs(self.AllObjectives) do
			local fields = objective.name:split(" ")
			local active = false;
			local subObjective = false;
			if not objective.isBase and not objective.isSpawnPath then
				if #fields > 1 then
					local index = tonumber(fields[2])
					for _,targetIndex in pairs(mcomIndexes) do
						if index == targetIndex then
							active = true;
						end
					end
					if #fields > 2 then
						subObjective = true;
					end
				end
			else
				if #fields > 2 then
					local index = tonumber(fields[3])
					if index == baseIndex then
						active = true;
					end
					if index == baseIndex - 1 then
						self.RushAttackingBase = objective.name;
					end
				end
			end
			objective.active = active;
			objective.subObjective = subObjective;
		end
	else
		self.OnlyOneMcom = true;
	end
end

function GameDirector:checkForExecution(point, team)
	local execute = false;
	if point.Data.Action ~= nil then
		local action = point.Data.Action;
		if action.type == "mcom" then
			local mcom = self:_translateObjective(point.Position)
			if mcom ~= nil then
				local objective = self:getObjectiveObject(mcom);
				if objective ~= nil then
					if objective.active then
						if team == TeamId.Team1 and objective.team == TeamId.TeamNeutral then
							execute = true;	--Attacking Team
						elseif team == TeamId.Team2 and objective.isAttacked then
							execute = true;	--Defending Team
						end
					end
				end
			end
		end
	end
	return execute;
end

function GameDirector:getSpawnPath(team, squad, onlyBase)
	local possibleObjectives = {}
	local possibleBases = {}
	local pathsDone = {}
	for _,objective in pairs(self.AllObjectives) do
		local allObjectives = g_NodeCollection:GetKnownOjectives();
		local pathsWithObjective = allObjectives[objective.name]
		for _,path in pairs(pathsWithObjective) do
			if not pathsDone[path] then
				local node = g_NodeCollection:Get(1, path)
				if node ~= nil and node.Data.Objectives ~= nil then
					if #node.Data.Objectives == 1 then --possible path
						if objective.team == team and objective.active then
							if objective.isBase then
								table.insert(possibleBases, path)
							elseif not onlyBase then
								table.insert(possibleObjectives, {name = objective.name, path = path})
							end
						elseif objective.team ~= team and objective.isBase and not objective.active and objective.name == self.RushAttackingBase then --rush attacking team
							table.insert(possibleBases, path)
						end
					end
				end
				pathsDone[path] = true;
			end
		end
	end
	if #possibleObjectives > 0 then
		local tempObj = possibleObjectives[MathUtils:GetRandomInt(1, #possibleObjectives)];
		local availableSpawnPaths = nil
		for _,objective in pairs(self.AllObjectives) do
			if objective.isSpawnPath and string.find(objective.name, tempObj.name) ~= nil then
				availableSpawnPaths = objective.name;
				break;
			end
		end
		-- check for spawn objectives
		if availableSpawnPaths ~= nil then
			local allObjectives = g_NodeCollection:GetKnownOjectives();
			local pathsWithObjective = allObjectives[availableSpawnPaths]
			return pathsWithObjective[MathUtils:GetRandomInt(1, #pathsWithObjective)], 1;
		else
			return tempObj.path, MathUtils:GetRandomInt(1, #g_NodeCollection:Get(nil, tempObj.path));
		end
	elseif #possibleBases > 0 then
		local pathIndex = possibleBases[MathUtils:GetRandomInt(1, #possibleBases)]
		return pathIndex, MathUtils:GetRandomInt(1, #g_NodeCollection:Get(nil, pathIndex));
	else
		return 0 , 0;
	end
end

function GameDirector:_updateObjective(name, data)
	for _,objective in pairs(self.AllObjectives) do
		if objective.name == name then
			for key, value in pairs(data) do
				objective[key] = value;
			end
			break;
		end
	end
end

function GameDirector:_translateObjective(positon, name)
	if name == nil or self.Translations[name] == nil then
		local allObjectives = g_NodeCollection:GetKnownOjectives();
		local pathsDone = {}
		local closestObjective = ""
		local closestDistance = nil
		for objective, paths in pairs(allObjectives) do
			for _,path in pairs(paths) do
				if not pathsDone[path] then
					local node = g_NodeCollection:Get(1, path)
					if node ~= nil and node.Data.Objectives ~= nil then
						if #node.Data.Objectives == 1 then --possible objective
							local valid = true;
							local tempObj = self:getObjectiveObject(objective)
							if tempObj.isSpawnPath or tempObj.isBase then
								valid = false;
							end
							if valid then
								local distance = positon:Distance(node.Position)
								if closestDistance == nil or closestDistance > distance then
									closestObjective = objective;
									closestDistance = distance;
								end
							end
						end
					end
					pathsDone[path] = true;
				end
			end
		end
		if name ~= nil then
			self.Translations[name] = closestObjective;
		end
		return closestObjective;
	else
		return self.Translations[name];
	end
end

function GameDirector:_onCapture(capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name);
	self:_updateObjective(objectiveName, {
		team = flagEntity.team,
		isAttacked = flagEntity.isAttacked
	})

	local objective = self:getObjectiveObject(objectiveName)
	if objective == nil then
		return
	end

	if Debug.Server.GAMEDIRECTOR then
		print('GameDirector:_onCapture: '..objectiveName)
		print('self.CurrentAssignedCount: '..g_Utilities:dump(objective.assigned, true))
	end
	
	for botTeam, bots in pairs(self.BotsByTeam) do
		for i=1, #bots do
			if (bots[i]:getObjective() == objective.name and objective.team == botTeam) then
				if Debug.Server.GAMEDIRECTOR then
					print('Bot completed objective: '..bots[i].name..' (team: '..botTeam..') -> '..objective.name)
				end
				
				bots[i]:setObjective()
				objective.assigned[botTeam] = math.max(objective.assigned[botTeam] - 1, 0)
			end
		end
	end
end

function GameDirector:getObjectiveObject(name)
	for _,objective in pairs(self.AllObjectives) do
		if objective.name == name then
			return objective
		end
	end
end

function GameDirector:isBasePath(ObjectiveNames)
	local isBase = false;
	for _,name in pairs(ObjectiveNames) do
		local objective = self:getObjectiveObject(name)
		if objective ~= nil and objective.isBase then
			isBase = true;
			break;
		end
	end
	return isBase;
end

-- 0 = all inactive
-- 1 = partly inactive
-- 2 = all active
function GameDirector:getEnableSateOfPath(ObjectiveNamesOfPath)
	local activeCount = 0;
	for _,name in pairs(ObjectiveNamesOfPath) do
		local objective = self:getObjectiveObject(name)
		if objective ~= nil and objective.active then
			activeCount = activeCount + 1;
		end
	end
	if activeCount == 0 then
		return 0;
	elseif activeCount < #ObjectiveNamesOfPath then
		return 1;
	else
		return 2;
	end
end

function GameDirector:getSubObjectiveFromObj(objective)
	for _,tempObjective in pairs(self.AllObjectives) do
		if tempObjective.subObjective then
			local name = tempObjective.name:lower()
			if string.find(name, objective:lower()) ~= nil then
				return tempObjective.name
			end
		end
	end
end

function GameDirector:getObjectiveFromSubObj(subObjective)
	for _,tempObjective in pairs(self.AllObjectives) do
		if not tempObjective.subObjective then
			local name = tempObjective.name:lower()
			if string.find(subObjective:lower(), name) ~= nil then
				return tempObjective.name
			end
		end
	end
end

function GameDirector:notifyBotAtObjective(botname, objectiveName, onObjective)
	local objective = self:getObjectiveObject(objectiveName)
	if objective ~= nil and objective.active then
		if onObjective then
			local found = false;
			for _,bot in pairs(objective.bots) do
				if bot == botname then
					found = true;
					break; -- dont insert bot, if already in
				end
			end
			if not found then
				table.insert(objective.bots, botname)
			end
		else
			self:_removeBotFromObjective(botname)
		end
	end
end

function GameDirector:_removeBotFromObjective(botname)
	for _,singleObjective in pairs(self.AllObjectives) do
		for pos,bot in pairs(singleObjective.bots) do
			if bot == botname then
				table.remove(singleObjective.bots, pos)
				break;
			end
		end
	end
end

function GameDirector:_useSubobjective(botTeam, objectiveName)
	local use = false;
	local objective = self:getObjectiveObject(objectiveName);
	if objective ~= nil then
		if objective.active then
			if botTeam == TeamId.Team1 and objective.team == TeamId.TeamNeutral then
				use = true;	--Attacking Team
			elseif botTeam == TeamId.Team2 and objective.isAttacked then
				use = true;	--Defending Team
			end
		end
	end
	return use;
end

function GameDirector:_onLost(capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name);
	self:_updateObjective(objectiveName, {
		team = TeamId.TeamNeutral, --flagEntity.team
		isAttacked = flagEntity.isAttacked
	})

	if Debug.Server.GAMEDIRECTOR then
		print('GameDirector:_onLost: '..objectiveName)
	end
end

function GameDirector:_onPlayerEnterCapturePoint(player, capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name);
	self:_updateObjective(objectiveName, {
		isAttacked = flagEntity.isAttacked  --		team = flagEntity.team,
	})
end

function GameDirector:_onRoundOver(roundTime, winningTeam)
	self.UpdateLast = -1
end

function GameDirector:_onRoundReset(roundTime, winningTeam)
	self.AllObjectives = {}
	self.UpdateLast = 0
end

function GameDirector:_onUpdate(delta)
	if (self.UpdateLast >= 0) then
		self.UpdateLast = self.UpdateLast + delta
	end

	if (self.UpdateLast >= self.UpdateInterval) then
		self.UpdateLast = 0

		--update bot -> team list
		local botList = g_BotManager:getBots()
		self.BotsByTeam = {}
		for i=1, #botList do
			if not botList[i]:isInactive() and botList[i].player ~= nil then
				if (self.BotsByTeam[botList[i].player.teamId] == nil) then
					self.BotsByTeam[botList[i].player.teamId] = {}
				end

				table.insert(self.BotsByTeam[botList[i].player.teamId], botList[i])
			end
		end

		local maxAssings = {0,0}
		for i = 1, 2 do
			if self.BotsByTeam[i] ~= nil then
				maxAssings[i] = math.floor(#self.BotsByTeam[i] / 2);
				if (#self.BotsByTeam[i] % 2) == 1 then
					maxAssings[i] = maxAssings[i] + 1;
				end
			end
			if maxAssings[i] > self.MaxAssignedLimit then
				maxAssings[i] = self.MaxAssignedLimit;
			end
			if self.OnlyOneMcom then
				if self.BotsByTeam[i] ~= nil then
					maxAssings[i] = #self.BotsByTeam[i];
				end
			end
		end

		-- TODO: check for inactive objectives of bots
		-- check objective statuses
		for _,objective in pairs(self.AllObjectives) do
			local parentObjective = self:getObjectiveFromSubObj(objective.name)
			local subObjective = self:getSubObjectiveFromObj(objective.name)
			if not objective.isBase and objective.active and not objective.destroyed then

				for botTeam, bots in pairs(self.BotsByTeam) do
					objective.assigned[botTeam] = 0;

					if objective.subObjective then
						if self:_useSubobjective(botTeam, objective.name) then
							local parentObject = self:getObjectiveObject(parentObjective)
							for i=1, #bots do
								local botPossible = false;
								for _,botname in pairs(parentObject.bots) do
									if bots[i].name == botname then
										botPossible = true;
										if (bots[i]:getObjective() == objective.name) then
											objective.assigned[botTeam] = objective.assigned[botTeam] + 1
										end

										if (bots[i]:getObjective() == parentObjective and objective.assigned[botTeam] < 2) then
											if Debug.Server.GAMEDIRECTOR then
												print('Assigning bot to objective: '..bots[i].name..' (team: '..botTeam..') -> '..objective.name)
											end
											
											bots[i]:setObjective(objective.name)
											objective.assigned[botTeam] = objective.assigned[botTeam] + 1
										end
									end
								end
								if not botPossible and bots[i]:getObjective() == objective.name then
									if Debug.Server.GAMEDIRECTOR then
										print('Assigning bot to objective: '..bots[i].name..' (team: '..botTeam..') -> '..parentObjective)
									end
									
									bots[i]:setObjective(parentObjective)
								end
							end
						else
							-- unassign bots
							for i=1, #bots do
								if (bots[i]:getObjective() == objective.name) then
									if Debug.Server.GAMEDIRECTOR then
										print('Assigning bot to objective: '..bots[i].name..' (team: '..botTeam..') -> '..parentObjective)
									end
									
									bots[i]:setObjective(parentObjective)
								end
							end
						end
					else
						for i=1, #bots do
							if (bots[i]:getObjective() == objective.name or bots[i]:getObjective() == subObjective) then
								objective.assigned[botTeam] = objective.assigned[botTeam] + 1
							end

							if (objective.team ~= botTeam and bots[i]:getObjective() == '' and objective.assigned[botTeam] < maxAssings[botTeam]) then

								if Debug.Server.GAMEDIRECTOR then
									print('Assigning bot to objective: '..bots[i].name..' (team: '..botTeam..') -> '..objective.name)
								end
								
								bots[i]:setObjective(objective.name)
								objective.assigned[botTeam] = objective.assigned[botTeam] + 1
							end
						end
					end
				end
			else
				-- remove bots from this objective
				for _,bot in pairs(botList) do
					if bot:getObjective() == objective.name then
						bot:setObjective();	-- clear objective
					end
				end
			end
		end
	end
end

if (g_GameDirector == nil) then
	g_GameDirector = GameDirector()
end
return g_GameDirector