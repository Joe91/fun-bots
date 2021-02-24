class('GameDirector');


function GameDirector:__init()
	self.currentLevel = ''
	self.currentGameMode = ''

	self.UpdateLast = -1
	self.UpdateInterval = 1.5 -- seconds interval

	self.BotsByTeam = {}

	self.Objectives = {}
	self.MaxAssignedLimit = 8
	self.CurrentAssignedCount = {}

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

	self.UpdateLast = 0
end

function GameDirector:_onCapture(capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	print('GameDirector:_onCapture: '..flagEntity.name)

	self.LevelObjectives[flagEntity.name] = flagEntity.team
	print('self.Objectives: '..g_Utilities:dump(self.Objectives, true))
	print('self.CurrentAssignedCount: '..g_Utilities:dump(self.CurrentAssignedCount, true))


	for botTeam, bot in pairs(self.BotsByTeam) do
		if (bot:getObjective() == flagEntity.name) then
			print('Bot completed objective: '..bot.name..' -> '..flagEntity.name)
			bot:setObjective()
			self.CurrentAssignedCount[flagEntity.name] = math.max(self.CurrentAssignedCount[flagEntity.name] - 1, 0)
		end
	end
end

function GameDirector:_onLost(capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
	print('GameDirector:_onLost: '..flagEntity.name)

	self.LevelObjectives[flagEntity.name] = TeamId.TeamNeutral
	print('self.Objectives: '..g_Utilities:dump(self.Objectives, true))
	print('self.CurrentAssignedCount: '..g_Utilities:dump(self.CurrentAssignedCount, true))
end

function GameDirector:_onPlayerEnterCapturePoint(player, capturePoint)
	local flagEntity = CapturePointEntity(capturePoint)
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

				self.BotsByTeam[botList[i].player.teamId] = botList[i]
			end
		end

		self.CurrentAssignedCount = {}

		-- check objective statuses
		for objectiveName,objectiveTeam in pairs(self.LevelObjectives) do
			for botTeam, bot in pairs(self.BotsByTeam) do

				if (self.CurrentAssignedCount[objectiveName] == nil) then
					self.CurrentAssignedCount[objectiveName] = 0
				end

				if (bot:getObjective() == objectiveName) then
					self.CurrentAssignedCount[objectiveName] = self.CurrentAssignedCount[objectiveName] + 1
				end

				if (objectiveTeam ~= botTeam and bot:getObjective() == '' and self.CurrentAssignedCount[objectiveName] < self.MaxAssignedLimit) then

					print('Assigning bot to objective: '..bot.name..' -> '..objectiveName)

					bot:setObjective(objectiveName)
					self.CurrentAssignedCount[objectiveName] = self.CurrentAssignedCount[objectiveName] + 1
				end
			end
		end
	end
end

if (g_GameDirector == nil) then
	g_GameDirector = GameDirector()
end
return g_GameDirector