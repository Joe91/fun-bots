class('BotSpawner')

require('SpawnSet')
require('__shared/NodeCollection')

local BotManager	= require('BotManager')
local WeaponList	= require('__shared/WeaponList')
local Utilities 	= require('__shared/Utilities')
local FIRST_SPAWN_DELAY = 3.0 -- needs to be big enough to register the inputActiveEvents. 1 is too small

function BotSpawner:__init()
	self._botSpawnTimer = 0
	self._playerUpdateTimer = 0
	self._firstSpawnInLevel = true
	self._firstSpawnDelay = FIRST_SPAWN_DELAY
	self._updateActive = false
	self._spawnSets = {}
	self._kickPlayers = {}
	self._botsWithoutPath = {}

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Bot:RespawnBot', self, self._onRespawnBot)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	Events:Subscribe('Player:KitPickup', self, self._onKitPickup)
	Events:Subscribe('Player:Joining', self, self._onPlayerJoining)
	Events:Subscribe('Player:TeamChange', self, self._onTeamChange)
end

function BotSpawner:_onTeamChange(p_Player, p_TeamId, p_SquadId)
	if Config.BotTeam ~= TeamId.TeamNeutral then
		if p_Player ~= nil then
			if p_Player.onlineId ~= 0 then -- no bot
				local playerTeams = {}
				for i = 1, Globals.NrOfTeams do
					if Config.BotTeam ~= i then
						table.insert(playerTeams, i)
					end
				end
				local playerTeam = playerTeams[MathUtils:GetRandomInt(1, #playerTeams)]
				if p_Player ~= nil and p_TeamId ~= nil and (p_TeamId ~= playerTeam) then
					p_Player.teamId = playerTeam
					ChatManager:SendMessage(Language:I18N('CANT_JOIN_BOT_TEAM', p_Player), p_Player)
				end
			end
		end
    end
end

function BotSpawner:updateBotAmountAndTeam()
	-- keep Slot for next player
	if Config.KeepOneSlotForPlayers then
		local playerlimt = Globals.MaxPlayers - 1
		local amoutToDestroy = PlayerManager:GetPlayerCount() - playerlimt
		if amoutToDestroy > 0 then
			BotManager:destroyAll(amoutToDestroy)
		end
	end

	-- if update active do nothing
	if self._updateActive then
		return
	else
		self._updateActive = true
	end

	-- find all needed vars
	local playerCount = BotManager:getPlayerCount()
	local botCount = BotManager:getActiveBotCount()

	-- kill and destroy bots, if no player left
	if (playerCount == 0) then
		if botCount > 0 then
			BotManager:killAll()
			self._updateActive = true
		else
			self._updateActive = false
		end
		return
	end

	local botTeam = BotManager:getBotTeam()
	local countPlayers = {}
	local teamCount = {}
	local countBots = {}
	local targetTeamCount = {}
	for i=1, Globals.NrOfTeams do
		countPlayers[i] = 0
		countBots[i] = 0
		targetTeamCount[i] = 0
		local tempPlayers = PlayerManager:GetPlayersByTeam(i)
		teamCount[i] = #tempPlayers
		for _,player in pairs(tempPlayers) do
			if Utilities:isBot(player) then
				countBots[i] = countBots[i] + 1
			else
				countPlayers[i] = countPlayers[i] + 1
			end
		end
	end

	-- KEEP PLAYERCOUNT
	if Globals.SpawnMode == 'keep_playercount' then
		for i=1, Globals.NrOfTeams do
			targetTeamCount[i] = Config.InitNumberOfBots
		end
		if Config.SpawnInBothTeams then
			for i=1, Globals.NrOfTeams do
				targetTeamCount[i] = math.floor(Config.InitNumberOfBots/Globals.NrOfTeams)
			end
		else
			for i=1, Globals.NrOfTeams do
				if botTeam ~= i then
					targetTeamCount[i] = 0
				end
			end
		end

		for i=1, Globals.NrOfTeams do
			if teamCount[i] < targetTeamCount[i] then
				self:spawnWayBots(nil, targetTeamCount[i]-teamCount[i], true, 0, 0, i)
			elseif teamCount[i] > targetTeamCount[i] and botCount[i] > 0 then
				BotManager:killAll(teamCount[i]-targetTeamCount[i], i)
			end
		end

	-- BALANCED teams
	elseif Globals.SpawnMode == 'balanced_teams' then
		local maxPlayersInOneTeam = 0
		for i=1, Globals.NrOfTeams do
			if countPlayers[i] > maxPlayersInOneTeam then
				maxPlayersInOneTeam = countPlayers[i]
			end
		end
		local targetCount = Config.InitNumberOfBots + ((maxPlayersInOneTeam-1) * Config.NewBotsPerNewPlayer)
		-- TODO: limit in SDM
		for i=1, Globals.NrOfTeams do
			targetTeamCount[i] = targetCount
		end

		for i=1, Globals.NrOfTeams do
			if teamCount[i] < targetTeamCount[i] then
				self:spawnWayBots(nil, targetTeamCount[i]-teamCount[i], true, 0, 0, i)
			elseif teamCount[i] > targetTeamCount[i] then
				BotManager:killAll(teamCount[i]-targetTeamCount[i], i)
			end
		end
	-- INCREMENT WITH PLAYER
	elseif Globals.SpawnMode == 'increment_with_players' then
		if Config.SpawnInBothTeams then
			for i=1, Globals.NrOfTeams do
				targetTeamCount[i] = 0
				for j = 1, Globals.NrOfTeams do
					if i ~= j then
						if (countPlayers[j]) > 0 then
							targetTeamCount[i] =  Config.InitNumberOfBots + ((countPlayers[j]-1) * Config.NewBotsPerNewPlayer)
							break --TODO: only use first team. Write algo for SDM as well
						end
					end
				end
			end

			for i=1, Globals.NrOfTeams do
				if teamCount[i] < targetTeamCount[i] then
					self:spawnWayBots(nil, targetTeamCount[i]-teamCount[i], true, 0, 0, i)
				elseif teamCount[i] > targetTeamCount[i] and botCount[i] > 0 then
					BotManager:killAll(teamCount[i]-targetTeamCount[i], i)
				end
			end

		else
			-- check for bots in wrong team
			for i=1, Globals.NrOfTeams do
				if i ~= botTeam and botCount[i] > 0 then
					BotManager:killAll(nil, i)
				end
			end

			local targetBotCount = Config.InitNumberOfBots + ((playerCount-1) * Config.NewBotsPerNewPlayer)
			local amountToSpawn = targetBotCount - botCount
			if amountToSpawn > 0 then
				self._botSpawnTimer = -5.0
				self:spawnWayBots(nil, amountToSpawn, true, 0, 0, botTeam)
			end
			if amountToSpawn < 0 then
				BotManager:killAll(-amountToSpawn)
			end
		end

	-- FIXED NUMBER TO SPAWN
	elseif Globals.SpawnMode == 'fixed_number' then
		if Config.SpawnInBothTeams then
			local amoutPerTeam = math.floor(Config.InitNumberOfBots/Globals.NrOfTeams)

			for i=1, Globals.NrOfTeams do
				if teamCount[i] < amoutPerTeam then
					self:spawnWayBots(nil, amoutPerTeam-teamCount[i], true, 0, 0, i)
				elseif teamCount[i] > amoutPerTeam and botCount[i] > 0 then
					BotManager:killAll(teamCount[i]-amoutPerTeam, i)
				end
			end
		else
			-- check for bots in wrong team
			for i=1, Globals.NrOfTeams do
				if i ~= botTeam and botCount[i] > 0 then
					BotManager:killAll(nil, i)
				end
			end

			local targetBotCount = Config.InitNumberOfBots
			local amountToSpawn = targetBotCount - botCount
			if amountToSpawn > 0 then
				self._botSpawnTimer = -5.0
				self:spawnWayBots(nil, amountToSpawn, true, 0, 0, botTeam)
			end
			if amountToSpawn < 0 then
				BotManager:killAll(-amountToSpawn)
			end
		end
	elseif Globals.SpawnMode == 'manual' then
		if self._firstSpawnInLevel then
			for i=1, Globals.NrOfTeams do
				self:spawnWayBots(nil, teamCount[i] - countPlayers[i], true, 0, 0, i)
			end
		end
	end
end

function BotSpawner:_onLevelDestroy()
	self._spawnSets = {}
	self._updateActive = false
	self._firstSpawnInLevel = true
	self._firstSpawnDelay 	= FIRST_SPAWN_DELAY
	self._playerUpdateTimer = 0
end

function BotSpawner:_onPlayerJoining(p_Name)
	if BotManager:getPlayerCount() == 0 then
		if Debug.Server.BOT then
			print("first player - spawn bots")
		end
		self:onLevelLoaded()
	end
	-- detect BOT-Names
	if string.find(p_Name, BOT_TOKEN) == 1 then --check if name starts with bot-token
		table.insert(self._kickPlayers, p_Name)
		if BotManager:getBotByName(p_Name) ~= nil then
			table.insert(Globals.IgnoreBotNames, p_Name)
			BotManager:destroyBot(p_Name)
		end
	end
end

function BotSpawner:onLevelLoaded()
	if Debug.Server.BOT then
		print("on level loaded on spawner")
	end
	self._firstSpawnInLevel = true
	self._playerUpdateTimer = 0
	self._firstSpawnDelay 	= FIRST_SPAWN_DELAY
end

function BotSpawner:_onUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	if self._firstSpawnInLevel then
		if self._firstSpawnDelay <= 0 then
			if BotManager:getPlayerCount() > 0 then
				BotManager:configGlobals()
				self:updateBotAmountAndTeam()
				self._playerUpdateTimer = 0
				self._firstSpawnInLevel = false
			end
		else
			self._firstSpawnDelay = self._firstSpawnDelay - p_DeltaTime
		end
	else
		self._playerUpdateTimer = self._playerUpdateTimer + p_DeltaTime
		if self._playerUpdateTimer > 2 then
			self._playerUpdateTimer = 0
			self:updateBotAmountAndTeam()
		end
	end

	if #self._spawnSets > 0 then
		if self._botSpawnTimer > 0.2 then	--time to wait between spawn. 0.2 works
			self._botSpawnTimer = 0
			local spawnSet = table.remove(self._spawnSets)
			self:_spawnSigleWayBot(spawnSet.playerVarOfBot, spawnSet.useRandomWay, spawnSet.activeWayIndex, spawnSet.indexOnPath, nil, spawnSet.team)
		end
		self._botSpawnTimer = self._botSpawnTimer + p_DeltaTime
	else
		if self._updateActive then
			self._updateActive = false
			if Globals.SpawnMode ~= 'manual' then
				--garbage-collection of unwanted bots
				BotManager:destroyDisabledBots()
				BotManager:freshnTables()
			end
		end
	end

	--kick players named after bots
	if #self._kickPlayers > 0 then
		for index,playerName in pairs(self._kickPlayers) do
			local player = PlayerManager:GetPlayerByName(playerName)
			if player ~= nil then
				player:Kick("You used a BOT-Name. Please use a real name on Fun-Bot-Servers...")
				for index,name in pairs(Globals.IgnoreBotNames) do
					if name == playerName then
						table.remove(Globals.IgnoreBotNames, index)
					end
				end
				table.remove(self._kickPlayers, index)
				break
			end
		end
	end

	if #self._botsWithoutPath > 0 then
		for index, bot in pairs(self._botsWithoutPath) do
			if bot == nil then
				table.remove(self._botsWithoutPath, index)
				break
			end
			if bot.player.soldier ~= nil then
				local trans = bot.player.soldier.worldTransform.trans:Clone()
				local pathIndex = g_GameDirector:findClosestPath(trans)
				bot:setVarsWay(nil, true, pathIndex, 1, false)
				table.remove(self._botsWithoutPath, index)
				local soldierCustomization = nil
				local soldierKit = nil
				local appearance = nil
				soldierKit, appearance, soldierCustomization = self:getKitApperanceCustomization(bot.player.teamId, bot.kit, bot.color, bot.primary, bot.pistol, bot.knife, bot.gadget1, bot.gadget2, bot.grenade)
				bot.player:SelectUnlockAssets(soldierKit, appearance)
				bot.player.soldier:ApplyCustomization(soldierCustomization)
				self:_modifyWeapon(bot.player.soldier)
				-- for Civilianizer-mod:
				Events:Dispatch('Bot:SoldierEntity', bot.player.soldier)
				break
			end
		end
	end
end

function BotSpawner:_onRespawnBot(p_BotName)
	local bot = BotManager:getBotByName(p_BotName)
	local spawnMode = bot:getSpawnMode()

	if spawnMode == 2 then --spawnInLine
		local transform = LinearTransform()
		transform = bot:getSpawnTransform()
		self:spawnBot(bot, transform, false)

	elseif spawnMode == 4 then	--fixed Way
		local wayIndex 		= bot:getWayIndex()
		local randIndex 	= MathUtils:GetRandomInt(1, #g_NodeCollection:Get(nil, wayIndex))
		self:_spawnSigleWayBot(nil, false, wayIndex, randIndex, bot)

	elseif spawnMode == 5 then --random Way
		self:_spawnSigleWayBot(nil, true, 0, 0, bot)
	end
end

function BotSpawner:spawnBotRow(p_Player, p_Length, p_Spacing)
	for i = 1, p_Length do
		local name = BotManager:findNextBotName()
		if name ~= nil then
			local transform = LinearTransform()
			transform.trans = p_Player.soldier.worldTransform.trans + (p_Player.soldier.worldTransform.forward * i * p_Spacing)
			local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
			bot:setVarsStatic(p_Player)
			self:spawnBot(bot, transform, true)
		end
	end
end

function BotSpawner:spawnBotTower(p_Player, p_Height)
	for i = 1, p_Height do
		local name = BotManager:findNextBotName()
		if name ~= nil then
			local yaw = p_Player.input.authoritativeAimingYaw
			local transform = LinearTransform()
			transform.trans.x = p_Player.soldier.worldTransform.trans.x + (math.cos(yaw + (math.pi / 2)))
			transform.trans.y = p_Player.soldier.worldTransform.trans.y + ((i - 1) * 1.8)
			transform.trans.z = p_Player.soldier.worldTransform.trans.z + (math.sin(yaw + (math.pi / 2)))
			local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
			bot:setVarsStatic(p_Player)
			self:spawnBot(bot, transform, true)
		end
	end
end

function BotSpawner:spawnBotGrid(p_Player, p_Rows, p_Columns, p_Spacing)
	for i = 1, p_Rows do
		for j = 1, p_Columns do
			local name = BotManager:findNextBotName()
			if name ~= nil then
				local yaw = p_Player.input.authoritativeAimingYaw
				local transform = LinearTransform()
				transform.trans.x = p_Player.soldier.worldTransform.trans.x + (i * math.cos(yaw + (math.pi / 2)) * p_Spacing) + ((j - 1) * math.cos(yaw) * p_Spacing)
				transform.trans.y = p_Player.soldier.worldTransform.trans.y
				transform.trans.z = p_Player.soldier.worldTransform.trans.z + (i * math.sin(yaw + (math.pi / 2)) * p_Spacing) + ((j - 1) * math.sin(yaw) * p_Spacing)
				local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
				bot:setVarsStatic(p_Player)
				self:spawnBot(bot, transform, true)
			end
		end
	end
end

function BotSpawner:spawnLineBots(p_Player, p_Amount, p_Spacing)
	 for i = 1, p_Amount do
		local name = BotManager:findNextBotName()
		if name ~= nil then
			local transform = LinearTransform()
			transform.trans = p_Player.soldier.worldTransform.trans + (p_Player.soldier.worldTransform.forward * i * p_Spacing)
			local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
			bot:setVarsSimpleMovement(p_Player, 2, transform)
			self:spawnBot(bot, transform, true)
		end
	end
end

function BotSpawner:_getSpawnPoint(p_TeamId, p_SquadId)
	local activeWayIndex = 0
	local indexOnPath = 0

	local targetNode = nil
	local validPointFound = false
	local targetDistance = Config.DistanceToSpawnBots
	local retryCounter = Config.MaxTrysToSpawnAtDistance
	local maximumTrys = 100
	local trysDone = 0

	-- CONQUEST
	-- spawn at base, squad-mate, captured flag
	if Globals.IsConquest then
		activeWayIndex, indexOnPath = g_GameDirector:getSpawnPath(p_TeamId, p_SquadId, false)

		if activeWayIndex == 0 then
			-- something went wrong. use random path
			if Debug.Server.BOT then
				print("no base or capturepoint found to spawn")
			end
			return
		end

		targetNode = g_NodeCollection:Get(indexOnPath, activeWayIndex)


	-- RUSH
	-- spawn at base (of zone) or squad-mate
	elseif Globals.IsRush then
		activeWayIndex, indexOnPath = g_GameDirector:getSpawnPath(p_TeamId, p_SquadId, true)

		if activeWayIndex == 0 then
			-- something went wrong. use random path
			if Debug.Server.BOT then
				print("no base found to spawn")
			end
			return
		end

		targetNode = g_NodeCollection:Get(indexOnPath, activeWayIndex)


	-- TDM / GM / SCAVANGER
	-- spawn away from other team
	else
		while not validPointFound and trysDone < maximumTrys do
			-- get new point
			activeWayIndex = MathUtils:GetRandomInt(1, #g_NodeCollection:GetPaths())
			if activeWayIndex == 0 then
				return
			end
			indexOnPath = MathUtils:GetRandomInt(1, #g_NodeCollection:Get(nil, activeWayIndex))
			if g_NodeCollection:Get(1, activeWayIndex) == nil then
				return
			end

			targetNode = g_NodeCollection:Get(indexOnPath, activeWayIndex)
			local spawnPoint = targetNode.Position

			--check for nearby player
			local playerNearby = false
			local players = PlayerManager:GetPlayers()
			for i = 1, PlayerManager:GetPlayerCount() do
				local tempPlayer = players[i]
				if tempPlayer.alive then
					if p_TeamId == nil or p_TeamId ~= tempPlayer.teamId then
						local distance = tempPlayer.soldier.worldTransform.trans:Distance(spawnPoint)
						local heightDiff = math.abs(tempPlayer.soldier.worldTransform.trans.y - spawnPoint.y)
						if distance < targetDistance and heightDiff < Config.HeightDistanceToSpawn then
							playerNearby = true
							break
						end
					end
				end
			end
			retryCounter = retryCounter - 1
			trysDone = trysDone + 1
			if retryCounter == 0 then
				retryCounter = Config.MaxTrysToSpawnAtDistance
				targetDistance = targetDistance - Config.DistanceToSpawnReduction
				if targetDistance < 0 then
					targetDistance = 0
				end
			end
			if not playerNearby then
				validPointFound = true
			end
		end
	end
	return targetNode
end


function BotSpawner:getSquad(p_TeamId)  --TODO: create a more advanced algorithm?
	if Globals.IsSdm then
		if p_TeamId % 2 == 1 then
			return 1
		else
			return 0  --TODO: only needed because of Vext-Bug
		end
	else
		for i = 1, SquadId.SquadIdCount - 1 do --for i = 9, SquadId.SquadIdCount - 1 do -- first 8 squads for real players
			if TeamSquadManager:GetSquadPlayerCount(p_TeamId, i) < 4 then
				return i
			end
		end
	end
	return 0
end

function BotSpawner:_spawnSigleWayBot(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_ExistingBot, p_ForcedTeam)
	local spawnPoint = nil
	local isRespawn = false
	local name = nil
	if p_ExistingBot ~= nil then
		isRespawn = true
	else
		name = BotManager:findNextBotName()
	end
	local team = p_ForcedTeam
	local squad = SquadId.SquadNone
	if team == nil then
		team = BotManager:getBotTeam()
	end
	if isRespawn then
		team = p_ExistingBot.player.teamId
		squad = p_ExistingBot.player.squadId
	else
		squad = self:getSquad(team)
	end
	local inverseDirection = false
	if name ~= nil or isRespawn then
		if Config.SpawnMethod == SpawnMethod.Spawn then
			local s_Bot = self:GetBot(p_ExistingBot, name, team, squad)
			if s_Bot == nil then
				return
			end
			self:SelectLoadout(s_Bot, true)
			self:TriggerSpawn(s_Bot)
			table.insert(self._botsWithoutPath, s_Bot)
			return
		end
		-- find a spawnpoint
		if p_UseRandomWay or p_ActiveWayIndex == nil or p_ActiveWayIndex == 0 then
			spawnPoint = self:_getSpawnPoint(team, squad)
		else
			spawnPoint = g_NodeCollection:Get(p_IndexOnPath, p_ActiveWayIndex)
		end

		if spawnPoint == nil then
			return
		else
			p_IndexOnPath = spawnPoint.PointIndex
			p_ActiveWayIndex = spawnPoint.PathIndex
		end

		--find out direction, if path has a return point
		if g_NodeCollection:Get(1, p_ActiveWayIndex).OptValue == 0xFF then
			inverseDirection = (MathUtils:GetRandomInt(0,1) == 1)
		end

		local transform = LinearTransform()
		if p_IndexOnPath == nil or p_IndexOnPath == 0 then
			p_IndexOnPath = 1
		end
		transform.trans = spawnPoint.Position

		if isRespawn then
			p_ExistingBot:setVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, inverseDirection)
			self:spawnBot(p_ExistingBot, transform, false)
		else
			local bot = BotManager:createBot(name, team, squad)

			if bot ~= nil then
				-- check for first one in squad
				if (TeamSquadManager:GetSquadPlayerCount(team, squad) == 1) then
					bot.player:SetSquadLeader(true, false)  -- not private
				end

				bot:setVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, inverseDirection)
				self:spawnBot(bot, transform, true)
			end
		end
	end
end

function BotSpawner:GetBot(p_ExistingBot, p_Name, p_TeamId, p_SquadId)
	if p_ExistingBot ~= nil then
		return p_ExistingBot
	else
		local s_Bot = BotManager:createBot(p_Name, p_TeamId, p_SquadId)
		if s_Bot == nil then
			print("[BotSpawner] Error - Failed to create bot")
			return nil
		end
		if (TeamSquadManager:GetSquadPlayerCount(p_TeamId, p_SquadId) == 1) then
			s_Bot.player:SetSquadLeader(true, false)
		end
		return s_Bot
	end
end

function BotSpawner:SelectLoadout(p_Bot, p_SetKit)
	local writeNewKit = (p_SetKit or Config.BotNewLoadoutOnSpawn)
	if not writeNewKit and (p_Bot.color == "" or p_Bot.kit == "" or p_Bot.activeWeapon == nil) then
		writeNewKit = true
	end
	local botColor = Config.BotColor
	local botKit = Config.BotKit

	if writeNewKit then
		if botColor == "RANDOM_COLOR" then
			botColor = BotColors[MathUtils:GetRandomInt(2, #BotColors)]
		end
		if botKit == "RANDOM_KIT" then
			botKit = self:_getSpawnBotKit()
		end
		p_Bot.color = botColor
		p_Bot.kit = botKit
	else
		botColor = p_Bot.color
		botKit = p_Bot.kit
	end

	p_Bot:resetSpawnVars()
	self:setBotWeapons(p_Bot, botKit, writeNewKit)
	if p_Bot.player.selectedKit == nil then
		-- SoldierBlueprint
		p_Bot.player.selectedKit = ResourceManager:SearchForInstanceByGuid(Guid('261E43BF-259B-41D2-BF3B-9AE4DDA96AD2'))
	end
	-- TODO: do it properly
	local s_SoldierKit = ResourceManager:SearchForInstanceByGuid(Guid('47949491-F672-4CD6-998A-101B7740F919'))
	local s_SoldierPersistance = ResourceManager:SearchForInstanceByGuid(Guid('23CFF61F-F1E2-4306-AECE-2819E35484D2'))
	p_Bot.player:SelectUnlockAssets(s_SoldierKit, {s_SoldierPersistance})
	p_Bot.player:SelectWeapon(WeaponSlot.WeaponSlot_0, ResourceManager:SearchForInstanceByGuid(Guid('A7278B05-8D76-4A40-B65D-4414490F6886')), {})
end

function BotSpawner:TriggerSpawn(p_Bot)
	local s_CurrentGameMode = SharedUtils:GetCurrentGameMode()
	if s_CurrentGameMode:match("DeathMatch") or
	s_CurrentGameMode:match("Domination") or
	s_CurrentGameMode:match("GunMaster") or
	s_CurrentGameMode:match("Scavenger") or
	s_CurrentGameMode:match("TankSuperiority") or
	s_CurrentGameMode:match("CaptureTheFlag") then
		self:DeathMatchSpawn(p_Bot)
	elseif s_CurrentGameMode:match("Rush") then
		-- seems to be the same as DeathMatchSpawn
		-- but it has vehicles
		self:RushSpawn(p_Bot)
	elseif s_CurrentGameMode:match("Conquest") then
		-- event + target spawn ("ID_H_US_B", "_ID_H_US_HQ", etc.)
		self:ConquestSpawn(p_Bot)
	end
end

function BotSpawner:DeathMatchSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.player, true, false, false, false, false, false, p_Bot.player.teamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCharacterSpawnEntity")
	local s_Entity = s_EntityIterator:Next()
	while s_Entity do
		if s_Entity.data:Is('CharacterSpawnReferenceObjectData') then
			if CharacterSpawnReferenceObjectData(s_Entity.data).team == p_Bot.player.teamId then
				s_Entity:FireEvent(s_Event)
				return
			end
		end
		s_Entity = s_EntityIterator:Next()
	end
end

function BotSpawner:RushSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.player, true, false, false, false, false, false, p_Bot.player.teamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCharacterSpawnEntity")
	local s_Entity = s_EntityIterator:Next()
	while s_Entity do
		if s_Entity.data:Is('CharacterSpawnReferenceObjectData') then
			if CharacterSpawnReferenceObjectData(s_Entity.data).team == p_Bot.player.teamId then
				-- skip if it is a vehiclespawn
				for i, l_Entity in pairs(s_Entity.bus.entities) do
					if l_Entity:Is("ServerVehicleSpawnEntity") then
						goto skip
					end
				end
				s_Entity:FireEvent(s_Event)
				return
			end
		end
		::skip::
		s_Entity = s_EntityIterator:Next()
	end
end

function BotSpawner:ConquestSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.player, true, false, false, false, false, false, p_Bot.player.teamId)
	local s_BestSpawnPoint = self:FindAttackedSpawnPoint(p_Bot.player.teamId)
	if s_BestSpawnPoint == nil then
		s_BestSpawnPoint = self:FindFarestSpawnPoint(p_Bot.player.teamId)
	end
	if s_BestSpawnPoint == nil then
		print("[BotSpawner] Error - No valid spawn point found")
		return
	end
	s_BestSpawnPoint:FireEvent(s_Event)
end

function BotSpawner:FindAttackedSpawnPoint(p_TeamId)
	local s_BestSpawnPoint = nil
	local s_LowestFlagLocation = 1
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
	local s_Entity = s_EntityIterator:Next()
	while s_Entity do
		s_Entity = CapturePointEntity(s_Entity)
		if s_Entity.team ~= p_TeamId then
			goto endOfLoop
		end
		for i, l_Entity in pairs(s_Entity.bus.entities) do
			if l_Entity:Is('ServerCharacterSpawnEntity') then
				if CharacterSpawnReferenceObjectData(l_Entity.data).team == p_TeamId
				or CharacterSpawnReferenceObjectData(l_Entity.data).team == 0 then
					if s_Entity.isFlagMoving and s_Entity.isControlled then
						if s_BestSpawnPoint == nil then
							s_BestSpawnPoint = l_Entity
							s_LowestFlagLocation = s_Entity.flagLocation
						elseif s_Entity.flagLocation < s_LowestFlagLocation then
							s_BestSpawnPoint = l_Entity
							s_LowestFlagLocation = s_Entity.flagLocation
						end
					end
					goto endOfLoop
				end
			end
		end
		::endOfLoop::
		s_Entity = s_EntityIterator:Next()
	end
	return s_BestSpawnPoint
end

function BotSpawner:FindFarestSpawnPoint(p_TeamId)
	local s_BestSpawnPoint = nil
	local s_HighestDistance = 0
	local s_BaseLocation = self:GetBaseLocation(p_TeamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
	local s_Entity = s_EntityIterator:Next()
	while s_Entity do
		s_Entity = CapturePointEntity(s_Entity)
		if s_Entity.team ~= p_TeamId then
			goto endOfLoop
		end
		for i, l_Entity in pairs(s_Entity.bus.entities) do
			if l_Entity:Is('ServerCharacterSpawnEntity') then
				if CharacterSpawnReferenceObjectData(l_Entity.data).team == p_TeamId
				or CharacterSpawnReferenceObjectData(l_Entity.data).team == 0 then
					if s_Entity.isControlled then
						if s_BestSpawnPoint == nil then
							s_BestSpawnPoint = l_Entity
							s_HighestDistance = s_BaseLocation:Distance(s_Entity.transform.trans)
						elseif s_HighestDistance < s_BaseLocation:Distance(s_Entity.transform.trans) then
							s_BestSpawnPoint = l_Entity
							s_HighestDistance = s_BaseLocation:Distance(s_Entity.transform.trans)
						end
					end
					goto endOfLoop
				end
			end
		end
		::endOfLoop::
		s_Entity = s_EntityIterator:Next()
	end
	return s_BestSpawnPoint
end

function BotSpawner:GetBaseLocation(p_TeamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
	local s_Entity = s_EntityIterator:Next()
	while s_Entity do
		s_Entity = CapturePointEntity(s_Entity)
		if s_Entity.team ~= p_TeamId then
			goto endOfLoop
		end
		for i, l_Entity in pairs(s_Entity.bus.entities) do
			if l_Entity:Is('ServerCharacterSpawnEntity') then
				if CharacterSpawnReferenceObjectData(l_Entity.data).team == 0 then
					return s_Entity.transform.trans
				end
				goto endOfLoop
			end
		end
		::endOfLoop::
		s_Entity = s_EntityIterator:Next()
	end
end

function BotSpawner:spawnWayBots(p_Player, p_Amount, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_TeamId)
	if #g_NodeCollection:GetPaths() <= 0 then
		return
	end

	-- check for amount available
	local playerlimt = Globals.MaxPlayers
	if Config.KeepOneSlotForPlayers then
		playerlimt = playerlimt - 1
	end

	local incactiveBots = BotManager:getBotCount() - BotManager:getActiveBotCount()
	local slotsLeft = playerlimt - (PlayerManager:GetPlayerCount() - incactiveBots)
	if p_Amount > slotsLeft then
		p_Amount = slotsLeft
	end

	for i = 1, p_Amount do
		local spawnSet = SpawnSet()
		spawnSet.playerVarOfBot 	= nil
		spawnSet.useRandomWay 		= p_UseRandomWay
		spawnSet.activeWayIndex 	= p_ActiveWayIndex
		spawnSet.indexOnPath 		= p_IndexOnPath
		spawnSet.team				= p_TeamId
		table.insert(self._spawnSets, spawnSet)
	end
end

-- Tries to find first available kit
-- @param teamName string Values: 'US', 'RU'
-- @param kitName string Values: 'Assault', 'Engineer', 'Support', 'Recon'
function BotSpawner:_findKit(p_TeamName, p_KitName)

	local gameModeKits = {
		'', -- Standard
		'_GM', --Gun Master on XP2 Maps
		'_GM_XP4', -- Gun Master on XP4 Maps
		'_XP4', -- Copy of Standard for XP4 Maps
		'_XP4_SCV' -- Scavenger on XP4 Maps
	}

	for kitType=1, #gameModeKits do
		local properKitName = string.lower(p_KitName)
		properKitName = properKitName:gsub("%a", string.upper, 1)

		local fullKitName = string.upper(p_TeamName)..properKitName..gameModeKits[kitType]
		local kit = ResourceManager:SearchForDataContainer('Gameplay/Kits/'..fullKitName)
		if kit ~= nil then
			return kit
		end
	end

	return
end

function BotSpawner:_findAppearance(p_TeamName, p_KitName, p_Color)
	local gameModeAppearances = {
		'MP/', -- Standard
		'MP_XP4/', --Gun Master on XP2 Maps
	}
	--'Persistence/Unlocks/Soldiers/Visual/MP[or:MP_XP4]/Us/MP_US_Assault_Appearance_'..p_Color
	for _, gameMode in pairs(gameModeAppearances) do
		local appearanceString = gameMode..p_TeamName..'/MP_'..string.upper(p_TeamName)..'_'..p_KitName..'_Appearance_'..p_Color
		local appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/'..appearanceString)
		if appearance ~= nil then
			return appearance
		end
	end

	return
end

function BotSpawner:_setAttachments(p_UnlockWeapon, p_Attachments)
	for _, attachment in pairs(p_Attachments) do
		local asset = ResourceManager:SearchForDataContainer(attachment)
		if (asset == nil) then
			if Debug.Server.BOT then
				print('Warning! Attachment invalid ['..tostring(p_UnlockWeapon.weapon.name)..']: '..tostring(attachment))
			end
		else
			p_UnlockWeapon.unlockAssets:add(UnlockAsset(asset))
		end
	end
end

function BotSpawner:getKitApperanceCustomization(p_TeamId, p_Kit, p_Color, p_Primary, p_Pistol, p_Knife, p_Gadget1, p_Gadget2, p_Grenade)
	-- Create the loadouts
	local soldierKit = nil
	local appearance = nil
	local soldierCustomization = CustomizeSoldierData()

	local pistolWeapon = ResourceManager:SearchForDataContainer(p_Pistol:getResourcePath())
	local knifeWeapon = ResourceManager:SearchForDataContainer(p_Knife:getResourcePath())
	local gadget1Weapon = ResourceManager:SearchForDataContainer(p_Gadget1:getResourcePath())
	local gadget2Weapon = ResourceManager:SearchForDataContainer(p_Gadget2:getResourcePath())
	local grenadeWeapon = ResourceManager:SearchForDataContainer(p_Grenade:getResourcePath())

	soldierCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	soldierCustomization.removeAllExistingWeapons = true

	local primaryWeapon = UnlockWeaponAndSlot()
	primaryWeapon.slot = WeaponSlot.WeaponSlot_0

	local primaryWeaponResource = ResourceManager:SearchForDataContainer(p_Primary:getResourcePath())
	primaryWeapon.weapon = SoldierWeaponUnlockAsset(primaryWeaponResource)
	self:_setAttachments(primaryWeapon, p_Primary:getAllAttachements())

	local gadget01 = UnlockWeaponAndSlot()
	gadget01.weapon = SoldierWeaponUnlockAsset(gadget1Weapon)
	if p_Kit == "Assault" or p_Kit == "Support" then
		gadget01.slot = WeaponSlot.WeaponSlot_4
	else
		gadget01.slot = WeaponSlot.WeaponSlot_2
	end

	local gadget02 = UnlockWeaponAndSlot()
	gadget02.weapon = SoldierWeaponUnlockAsset(gadget2Weapon)
	gadget02.slot = WeaponSlot.WeaponSlot_5

	local thrownWeapon = UnlockWeaponAndSlot()
	thrownWeapon.weapon = SoldierWeaponUnlockAsset(grenadeWeapon)
	thrownWeapon.slot = WeaponSlot.WeaponSlot_6

	local secondaryWeapon = UnlockWeaponAndSlot()
	secondaryWeapon.weapon = SoldierWeaponUnlockAsset(pistolWeapon)
	secondaryWeapon.slot = WeaponSlot.WeaponSlot_1

	local meleeWeapon = UnlockWeaponAndSlot()
	meleeWeapon.weapon = SoldierWeaponUnlockAsset(knifeWeapon)
	meleeWeapon.slot = WeaponSlot.WeaponSlot_7

	if p_TeamId % 2 == 1 then -- US
		if p_Kit == "Assault" then --assault
			appearance = self:_findAppearance('Us', 'Assault', p_Color)
			soldierKit = self:_findKit('US', 'Assault')
		elseif p_Kit == "Engineer" then --engineer
			appearance = self:_findAppearance('Us', 'Engi', p_Color)
			soldierKit = self:_findKit('US', 'Engineer')
		elseif p_Kit == "Support" then --support
			appearance = self:_findAppearance('Us', 'Support', p_Color)
			soldierKit = self:_findKit('US', 'Support')
		else	--recon
			appearance = self:_findAppearance('Us', 'Recon', p_Color)
			soldierKit = self:_findKit('US', 'Recon')
		end
	else -- RU
		if p_Kit == "Assault" then --assault
			appearance = self:_findAppearance('RU', 'Assault', p_Color)
			soldierKit = self:_findKit('RU', 'Assault')
		elseif p_Kit == "Engineer" then --engineer
			appearance = self:_findAppearance('RU', 'Engi', p_Color)
			soldierKit = self:_findKit('RU', 'Engineer')
		elseif p_Kit == "Support" then --support
			appearance = self:_findAppearance('RU', 'Support', p_Color)
			soldierKit = self:_findKit('RU', 'Support')
		else	--recon
			appearance = self:_findAppearance('RU', 'Recon', p_Color)
			soldierKit = self:_findKit('RU', 'Recon')
		end
	end

	if Config.ZombieMode then
		soldierCustomization.activeSlot = WeaponSlot.WeaponSlot_7
		soldierCustomization.weapons:add(meleeWeapon)
	else
		soldierCustomization.weapons:add(primaryWeapon)
		soldierCustomization.weapons:add(secondaryWeapon)
		soldierCustomization.weapons:add(gadget01)
		soldierCustomization.weapons:add(gadget02)
		soldierCustomization.weapons:add(thrownWeapon)
		soldierCustomization.weapons:add(meleeWeapon)
	end

	return soldierKit, appearance, soldierCustomization
end

function BotSpawner:_onKitPickup(p_Player, p_NewCustomization)
	if p_Player.soldier ~= nil then
		if p_Player.soldier.weaponsComponent.weapons[1] ~= nil then
			p_Player.soldier.weaponsComponent.weapons[1].secondaryAmmo = 182
		end
		if p_Player.soldier.weaponsComponent.weapons[2] ~= nil then
			p_Player.soldier.weaponsComponent.weapons[2].secondaryAmmo = 58
		end
	end
end

function BotSpawner:_modifyWeapon(p_Soldier)
	--p_Soldier.weaponsComponent.currentWeapon.secondaryAmmo = 9999
	if p_Soldier.weaponsComponent.weapons[1] ~= nil then
		p_Soldier.weaponsComponent.weapons[1].secondaryAmmo = 9999
	end
	if p_Soldier.weaponsComponent.weapons[2] ~= nil then
		p_Soldier.weaponsComponent.weapons[2].secondaryAmmo = 9999
	end
end

function BotSpawner:_getSpawnBotKit()
	local botKit = BotKits[MathUtils:GetRandomInt(2, #BotKits)]
	local changeKit = false
	--find out, if possible
	local kitCount = BotManager:getKitCount(botKit)
	if botKit == "Assault" then
		if Config.MaxAssaultBots >= 0 and kitCount >= Config.MaxAssaultBots then
			changeKit = true
		end
	elseif botKit == "Engineer" then
		if Config.MaxEngineerBots >= 0 and kitCount >= Config.MaxEngineerBots then
			changeKit = true
		end
	elseif botKit == "Support" then
		if Config.MaxSupportBots >= 0 and kitCount >= Config.MaxSupportBots then
			changeKit = true
		end
	else -- botKit == "Support"
		if Config.MaxReconBots >= 0 and kitCount >= Config.MaxReconBots then
			changeKit = true
		end
	end

	if changeKit then
		local availableKitList = {}
		if (Config.MaxAssaultBots == -1) or (BotManager:getKitCount("Assault") < Config.MaxAssaultBots) then
			table.insert(availableKitList, "Assault")
		end
		if (Config.MaxEngineerBots == -1) or (BotManager:getKitCount("Engineer") < Config.MaxEngineerBots) then
			table.insert(availableKitList, "Engineer")
		end
		if (Config.MaxSupportBots == -1) or (BotManager:getKitCount("Support") < Config.MaxSupportBots) then
			table.insert(availableKitList, "Support")
		end
		if(Config.MaxReconBots == -1) or (BotManager:getKitCount("Recon") < Config.MaxReconBots) then
			table.insert(availableKitList, "Recon")
		end

		if #availableKitList > 0 then
			botKit = availableKitList[MathUtils:GetRandomInt(1, #availableKitList)]
		end
	end

	return botKit
end

function BotSpawner:setBotWeapons(p_Bot, p_BotKit, p_NewWeapons)
	if p_NewWeapons then
		if p_BotKit == "Assault" then
			local weapon = Config.AssaultWeapon
			if Config.UseRandomWeapon then
				weapon = AssaultPrimary[MathUtils:GetRandomInt(1, #AssaultPrimary)]
			end
			p_Bot.primary = WeaponList:getWeapon(weapon)
			p_Bot.gadget2 = WeaponList:getWeapon(AssaultGadget2[MathUtils:GetRandomInt(1, #AssaultGadget2)])
			p_Bot.gadget1 = WeaponList:getWeapon(AssaultGadget1[MathUtils:GetRandomInt(1, #AssaultGadget1)])
			p_Bot.pistol = WeaponList:getWeapon(AssaultPistol[MathUtils:GetRandomInt(1, #AssaultPistol)])
			p_Bot.grenade = WeaponList:getWeapon(AssaultGrenade[MathUtils:GetRandomInt(1, #AssaultGrenade)])
			p_Bot.knife = WeaponList:getWeapon(AssaultKnife[MathUtils:GetRandomInt(1, #AssaultKnife)])
		elseif p_BotKit == "Engineer" then
			local weapon = Config.EngineerWeapon
			if Config.UseRandomWeapon then
				weapon = EngineerPrimary[MathUtils:GetRandomInt(1, #EngineerPrimary)]
			end
			p_Bot.primary = WeaponList:getWeapon(weapon)
			p_Bot.gadget2 = WeaponList:getWeapon(EngineerGadget2[MathUtils:GetRandomInt(1, #EngineerGadget2)])
			p_Bot.gadget1 = WeaponList:getWeapon(EngineerGadget1[MathUtils:GetRandomInt(1, #EngineerGadget1)])
			p_Bot.pistol = WeaponList:getWeapon(EngineerPistol[MathUtils:GetRandomInt(1, #EngineerPistol)])
			p_Bot.grenade = WeaponList:getWeapon(EngineerGrenade[MathUtils:GetRandomInt(1, #EngineerGrenade)])
			p_Bot.knife = WeaponList:getWeapon(EngineerKnife[MathUtils:GetRandomInt(1, #EngineerKnife)])
		elseif p_BotKit == "Support" then
			local weapon = Config.SupportWeapon
			if Config.UseRandomWeapon then
				weapon = SupportPrimary[MathUtils:GetRandomInt(1, #SupportPrimary)]
			end
			p_Bot.primary = WeaponList:getWeapon(weapon)
			p_Bot.gadget2 = WeaponList:getWeapon(SupportGadget2[MathUtils:GetRandomInt(1, #SupportGadget2)])
			p_Bot.gadget1 = WeaponList:getWeapon(SupportGadget1[MathUtils:GetRandomInt(1, #SupportGadget1)])
			p_Bot.pistol = WeaponList:getWeapon(SupportPistol[MathUtils:GetRandomInt(1, #SupportPistol)])
			p_Bot.grenade = WeaponList:getWeapon(SupportGrenade[MathUtils:GetRandomInt(1, #SupportGrenade)])
			p_Bot.knife = WeaponList:getWeapon(SupportKnife[MathUtils:GetRandomInt(1, #SupportKnife)])
		else
			local weapon = Config.ReconWeapon
			if Config.UseRandomWeapon then
				weapon = ReconPrimary[MathUtils:GetRandomInt(1, #ReconPrimary)]
			end
			p_Bot.primary = WeaponList:getWeapon(weapon)
			p_Bot.gadget2 = WeaponList:getWeapon(ReconGadget2[MathUtils:GetRandomInt(1, #ReconGadget2)])
			p_Bot.gadget1 = WeaponList:getWeapon(ReconGadget1[MathUtils:GetRandomInt(1, #ReconGadget1)])
			p_Bot.pistol = WeaponList:getWeapon(ReconPistol[MathUtils:GetRandomInt(1, #ReconPistol)])
			p_Bot.grenade = WeaponList:getWeapon(ReconGrenade[MathUtils:GetRandomInt(1, #ReconGrenade)])
			p_Bot.knife = WeaponList:getWeapon(ReconKnife[MathUtils:GetRandomInt(1, #ReconKnife)])
		end
	end

	if Config.BotWeapon == "Primary" or Config.BotWeapon == "Auto" then
		p_Bot.activeWeapon = p_Bot.primary
	elseif Config.BotWeapon == "Pistol" then
		p_Bot.activeWeapon = p_Bot.pistol
	elseif Config.BotWeapon == "Gadget2" then
		p_Bot.activeWeapon = p_Bot.gadget2
	elseif Config.BotWeapon == "Gadget1" then
		p_Bot.activeWeapon = p_Bot.gadget1
	elseif Config.BotWeapon == "Grenade" then
		p_Bot.activeWeapon = p_Bot.grenade
	else
		p_Bot.activeWeapon = p_Bot.knife
	end
end

function BotSpawner:spawnBot(p_Bot, p_Trans, p_SetKit)
	local writeNewKit = (p_SetKit or Config.BotNewLoadoutOnSpawn)
	if not writeNewKit and (p_Bot.color == "" or p_Bot.kit == "" or p_Bot.activeWeapon == nil) then
		writeNewKit = true
	end
	local botColor = Config.BotColor
	local botKit = Config.BotKit

	if writeNewKit then
		if botColor == "RANDOM_COLOR" then
			botColor = BotColors[MathUtils:GetRandomInt(2, #BotColors)]
		end
		if botKit == "RANDOM_KIT" then
			botKit = self:_getSpawnBotKit()
		end
		p_Bot.color = botColor
		p_Bot.kit = botKit
	else
		botColor = p_Bot.color
		botKit = p_Bot.kit
	end

	self:setBotWeapons(p_Bot, botKit, writeNewKit)

	p_Bot:resetSpawnVars()

	-- create kit and appearance
	local soldierBlueprint = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier')
	local soldierCustomization = nil
	local soldierKit = nil
	local appearance = nil
	soldierKit, appearance, soldierCustomization = self:getKitApperanceCustomization(p_Bot.player.teamId, botKit, botColor, p_Bot.primary, p_Bot.pistol, p_Bot.knife, p_Bot.gadget1, p_Bot.gadget2, p_Bot.grenade)

	-- Create the transform of where to spawn the bot at.
	local transform = LinearTransform()
	transform = p_Trans

	-- And then spawn the bot. This will create and return a new SoldierEntity object.
	-- for Civilianizer-Mod
	if Globals.RemoveKitVisuals then
		BotManager:spawnBot(p_Bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
	else
		BotManager:spawnBot(p_Bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, { appearance })
	end
	p_Bot.player.soldier:ApplyCustomization(soldierCustomization)
	self:_modifyWeapon(p_Bot.player.soldier)

	-- for Civilianizer-mod:
	Events:Dispatch('Bot:SoldierEntity', p_Bot.player.soldier)
end

-- Singleton.
if g_BotSpawner == nil then
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner
