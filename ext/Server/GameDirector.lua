class('GameDirector');

require('Globals')
require('__shared/NodeCollection')

function GameDirector:__init()
	self.currentLevel = ''
	self.currentGameMode = ''

	self.UpdateLast = -1
	self.UpdateInterval = 1.5 -- seconds interval

	self.BotsByTeam = {}

	self.Objectives = {}
	self.MaxAssignedLimit = 8
	self.CurrentAssignedCount = {}

	self.AllObjectives = {}
	self.Translatinos = {}

	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)

	Events:Subscribe('CapturePoint:Lost', self, self._onLost)
	Events:Subscribe('CapturePoint:Captured', self, self._onCapture)
	Events:Subscribe('Player:EnteredCapturePoint', self, self._onPlayerEnterCapturePoint)

	Events:Subscribe('Server:RoundOver', self, self._onRoundOver)
	Events:Subscribe('Server:RoundReset', self, self._onRoundReset)

	Events:Subscribe('Engine:Update', self, self._onUpdate)
end

function GameDirector:_onLevelLoaded(levelName, gameMode)
	self.currentLevel = levelName
	self.currentGameMode = gameMode

	self.Objectives[levelName] = {}
	self.Objectives[levelName][gameMode] = {}
	self.LevelObjectives = self.Objectives[levelName][gameMode]

	self.AllObjectives = {}
	self.Translatinos = {}

	-- TODO, assign weights to each objective

	self.UpdateLast = 0
end

function GameDirector:initObjectives()
	self.AllObjectives = {}
	for objectiveName,_ in pairs(g_NodeCollection:GetKnownOjectives()) do
		local objective = {
			name = objectiveName,
			belongs = TeamId.TeamNeutral,
			isAttacked = false,
			zone = 0
		}
		table.insert(self.AllObjectives, objective)
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

function GameDirector:_translateObjective(flagEntity)
	if self.Translatinos[flagEntity.name] == nil then
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
							local distance = flagEntity.transform.trans:Distance(node.Position)
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
		self.Translatinos[flagEntity.name] = closestObjective;
	end
	return self.Translatinos[flagEntity.name];
end

function GameDirector:_onCapture(capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objective = self:_translateObjective(flagEntity);
	self:_updateObjective(objective, {
		belongs = flagEntity.team,
		isAttacked = flagEntity.isAttacked
	})

	print('GameDirector:_onCapture: '..flagEntity.name)

	self.LevelObjectives[flagEntity.name] = flagEntity.team
	print('self.Objectives: '..g_Utilities:dump(self.Objectives, true))
	print('self.CurrentAssignedCount: '..g_Utilities:dump(self.CurrentAssignedCount, true))


	for botTeam, bots in pairs(self.BotsByTeam) do
		for i=1, #bots do
			if (bots[i]:getObjective() == flagEntity.name and flagEntity.team == botTeam) then
				print('Bot completed objective: '..bots[i].name..' (team: '..botTeam..') -> '..flagEntity.name)
				bots[i]:setObjective()
				self.CurrentAssignedCount[botTeam..'_'..flagEntity.name] = math.max(self.CurrentAssignedCount[botTeam..'_'..flagEntity.name] - 1, 0)
			end
		end
	end
end

function GameDirector:_onLost(capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objective = self:_translateObjective(flagEntity);
	self:_updateObjective(objective, {
		belongs = flagEntity.team,
		isAttacked = flagEntity.isAttacked
	})

	print('GameDirector:_onLost: '..flagEntity.name)

	self.LevelObjectives[flagEntity.name] = TeamId.TeamNeutral
	print('self.Objectives: '..g_Utilities:dump(self.Objectives, true))
	print('self.CurrentAssignedCount: '..g_Utilities:dump(self.CurrentAssignedCount, true))
end

function GameDirector:_onPlayerEnterCapturePoint(player, capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	local objective = self:_translateObjective(flagEntity);
	self:_updateObjective(objective, {
		belongs = flagEntity.team,
		isAttacked = flagEntity.isAttacked
	})

	--print('GameDirector:_onPlayerEnterCapturePoint: '..player.name..' -> '..flagEntity.name)
	self.LevelObjectives[flagEntity.name] = flagEntity.team
end

function GameDirector:_onRoundOver(roundTime, winningTeam)
	self.UpdateLast = -1
end

function GameDirector:_onRoundReset(roundTime, winningTeam)
	self.Objectives[self.currentLevel] = {}
	self.Objectives[self.currentLevel][self.currentGameMode] = {}
	self.LevelObjectives = self.Objectives[self.currentLevel][self.currentGameMode]
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

		-- check objective statuses
		for objectiveName,objectiveTeam in pairs(self.LevelObjectives) do
			for botTeam, bots in pairs(self.BotsByTeam) do
				for i=1, #bots do
					if (self.CurrentAssignedCount[botTeam..'_'..objectiveName] == nil) then
						self.CurrentAssignedCount[botTeam..'_'..objectiveName] = 0
					end

					if (bots[i]:getObjective() == objectiveName) then
						self.CurrentAssignedCount[botTeam..'_'..objectiveName] = self.CurrentAssignedCount[botTeam..'_'..objectiveName] + 1
					end

					if (objectiveTeam ~= botTeam and bots[i]:getObjective() == '' and self.CurrentAssignedCount[botTeam..'_'..objectiveName] < self.MaxAssignedLimit) then

						print('Assigning bot to objective: '..bots[i].name..' (team: '..botTeam..') -> '..objectiveName)

						bots[i]:setObjective(objectiveName)
						self.CurrentAssignedCount[botTeam..'_'..objectiveName] = self.CurrentAssignedCount[botTeam..'_'..objectiveName] + 1
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