class('GameDirector');

require('Globals')
require('__shared/NodeCollection')

function GameDirector:__init()
	self.UpdateLast = -1
	self.UpdateInterval = 1.5 -- seconds interval

	self.BotsByTeam = {}

	self.MaxAssignedLimit = 8
	self.CurrentAssignedCount = {}

	self.AllObjectives = {}
	self.Translations = {}

	self.McomCounter = 0;
	self.ArmedMcoms = {}

	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)

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

function GameDirector:_onLevelLoaded(levelName, gameMode)
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

		self:_updateValidObjectives()
	end

	-- TODO, assign weights to each objective

	self.UpdateLast = 0
end

function GameDirector:_onMcomArmed(player)
	local objective = self:_translateObjective(player.soldier.worldTransform.trans);
	if self.ArmedMcoms[player.name] == nil then
		self.ArmedMcoms[player.name] = {}
	end
	table.insert(self.ArmedMcoms[player.name], objective.name)

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
				if mcomName == objective.name then
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
	local objective = self:_translateObjective(player.soldier.worldTransform.trans);
	if self.ArmedMcoms[player.name] ~= nil then
		for i,mcomName in pairs(elf.ArmedMcoms[player.name]) do
			if mcomName == objective.name then
				table.remove(self.ArmedMcoms[player.name], i)
				break;
			end
		end
	end
	self:_updateObjective(objective, {
		team = TeamId.TeamNeutral,--player.teamId,
		isAttacked = false,
		active = false
	})
	self.McomCounter = self.McomCounter + 1;
	self:_updateValidObjectives();
end


function GameDirector:initObjectives()
	self.AllObjectives = {}
	for objectiveName,_ in pairs(g_NodeCollection:GetKnownOjectives()) do
		local objective = {
			name = objectiveName,
			team = TeamId.TeamNeutral,
			isAttacked = false,
			isBase = false,
			active = true
		}
		if string.find(objectiveName:lower(), "base") ~= nil then
			objective.isBase = true;
			if string.find(objectiveName:lower(), "us") ~= nil then
				objective.team = TeamId.Team1
			else
				objective.team = TeamId.Team2
			end
		end
		table.insert(self.AllObjectives, objective)
	end
	print('self.AllObjectives -> '..g_Utilities:dump(self.AllObjectives, true))
end


function GameDirector:_updateValidObjectives()
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
		if not objective.isBase then
			if #fields > 1 then
				local index = tonumber(fields[2])
				for _,targetIndex in paris(mcomIndexes) do
					if index == targetIndex then
						active = true;
					end
				end
			end
		else
			if #fields > 2 then
				local index = tonumber(fields[3])
				if index == baseIndex then
					active = true;
				end
			end
		end
		objective.active = active;
	end
end

function GameDirector:getSpawnPath(team, squad, onlyBase)
	local possibleObjectives = {}
	local possibleBases = {}
	local pathsDone = {}
	for _,objective in pairs(self.AllObjectives) do
		if objective.team == team and objective.active then
			local allObjectives = g_NodeCollection:GetKnownOjectives();
			local pathsWithObjective = allObjectives[objective.name]
			for _,path in pairs(pathsWithObjective) do
				if not pathsDone[path] then
					local node = g_NodeCollection:Get(1, path)
					if node ~= nil and node.Data.Objectives ~= nil then
						if #node.Data.Objectives == 1 then --possible path
							if objective.isBase then
								table.insert(possibleBases, path)
							elseif not onlyBase then
								table.insert(possibleObjectives, path)
							end
						end
					end
					pathsDone[path] = true;
				end
			end
		end
	end
	if #possibleObjectives > 0 then
		return possibleObjectives[MathUtils:GetRandomInt(1, #possibleObjectives)];
	elseif #possibleBases > 0 then
		return possibleBases[MathUtils:GetRandomInt(1, #possibleBases)];
	else
		return 0;
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
							local distance = positon:Distance(node.Position)
							if closestDistance == nil or closestDistance > distance then
								closestObjective = objective;
								closestDistance = distance;
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

	print('GameDirector:_onCapture: '..objectiveName)
	print('self.CurrentAssignedCount: '..g_Utilities:dump(self.CurrentAssignedCount, true))

	local objective = self:getObjectiveObject(objectiveName)

	for botTeam, bots in pairs(self.BotsByTeam) do
		for i=1, #bots do
			if (bots[i]:getObjective() == objective.name and objective.team == botTeam) then
				print('Bot completed objective: '..bots[i].name..' (team: '..botTeam..') -> '..objective.name)
				bots[i]:setObjective()
				self.CurrentAssignedCount[botTeam..'_'..objective.name] = math.max(self.CurrentAssignedCount[botTeam..'_'..objective.name] - 1, 0)
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

function GameDirector:_onLost(capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name);
	self:_updateObjective(objectiveName, {
		team = flagEntity.team, --TeamId.TeamNeutral
		isAttacked = flagEntity.isAttacked
	})

	print('GameDirector:_onLost: '..objectiveName)
	print('self.CurrentAssignedCount: '..g_Utilities:dump(self.CurrentAssignedCount, true))
end

function GameDirector:_onPlayerEnterCapturePoint(player, capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objectiveName = self:_translateObjective(flagEntity.transform.trans, flagEntity.name);
	self:_updateObjective(objectiveName, {
		team = flagEntity.team,
		isAttacked = flagEntity.isAttacked
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

		self.CurrentAssignedCount = {}

		-- TODO: check for inactive objectives of bots
		-- check objective statuses
		for _,objective in pairs(self.AllObjectives) do
			for botTeam, bots in pairs(self.BotsByTeam) do
				for i=1, #bots do
					if (self.CurrentAssignedCount[botTeam..'_'..objective.name] == nil) then
						self.CurrentAssignedCount[botTeam..'_'..objective.name] = 0
					end

					if (bots[i]:getObjective() == objective.name) then
						self.CurrentAssignedCount[botTeam..'_'..objective.name] = self.CurrentAssignedCount[botTeam..'_'..objective.name] + 1
					end

					if (objective.team ~= botTeam and bots[i]:getObjective() == '' and self.CurrentAssignedCount[botTeam..'_'..objective.name] < self.MaxAssignedLimit) then

						print('Assigning bot to objective: '..bots[i].name..' (team: '..botTeam..') -> '..objective.name)

						bots[i]:setObjective(objective.name)
						self.CurrentAssignedCount[botTeam..'_'..objective.name] = self.CurrentAssignedCount[botTeam..'_'..objective.name] + 1
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