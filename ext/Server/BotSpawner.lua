class('BotSpawner');

require('Globals');
require('SpawnSet')
require('__shared/NodeCollection')

local BotManager	= require('BotManager');
local WeaponList	= require('__shared/WeaponList');
local Utilities 	= require('__shared/Utilities')
local FIRST_SPAWN_DELAY = 3.0 -- needs to be big enough to register the inputActiveEvents. 1 is too small

function BotSpawner:__init()
	self._botSpawnTimer = 0
	self._playerUpdateTimer = 0
	self._firstSpawnInLevel = true;
	self._firstSpawnDelay = FIRST_SPAWN_DELAY;
	self._updateActive = false;
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

function BotSpawner:_onTeamChange(player, team, squad)
	if Config.botTeam ~= TeamId.TeamNeutral then
		if player ~= nil then
			if player.onlineId ~= 0 then -- no bot
				local playerTeams = {}
				for i = 1, g_Globals.nrOfTeams do
					if Config.botTeam ~= i then
						table.insert(playerTeams, i)
					end
				end
				local playerTeam = playerTeams[MathUtils:GetRandomInt(1, #playerTeams)]
				if player ~= nil and team ~= nil and (team ~= playerTeam) then
					player.teamId = playerTeam;
					ChatManager:SendMessage(Language:I18N('CANT_JOIN_BOT_TEAM', player), player);
				end
			end
		end
    end
end

function BotSpawner:updateBotAmountAndTeam()
	-- keep Slot for next player
	if Config.keepOneSlotForPlayers then
		local playerlimt = g_Globals.maxPlayers - 1
		local amoutToDestroy = PlayerManager:GetPlayerCount() - playerlimt
		if amoutToDestroy > 0 then
			BotManager:destroyAll(amoutToDestroy)
		end
	end

	-- if update active do nothing
	if self._updateActive then
		return
	else
		self._updateActive = true;
	end

	-- find all needed vars
	local playerCount = BotManager:getPlayerCount();
	local botCount = BotManager:getActiveBotCount();

	-- kill and destroy bots, if no player left
	if (playerCount == 0) then
		if botCount > 0 then
			BotManager:killAll();
			self._updateActive = true;
		else
			self._updateActive = false;
		end
		return
	end

	local botTeam = BotManager:getBotTeam();
	local countPlayers = {}
	local teamCount = {}
	local countBots = {}
	local targetTeamCount = {}
	for i=1, g_Globals.nrOfTeams do
		countPlayers[i] = 0;
		countBots[i] = 0;
		targetTeamCount[i] = 0;
		local tempPlayers = PlayerManager:GetPlayersByTeam(i);
		teamCount[i] = #tempPlayers
		for _,player in pairs(tempPlayers) do
			if Utilities:isBot(player) then
				countBots[i] = countBots[i] + 1;
			else
				countPlayers[i] = countPlayers[i] + 1;
			end
		end
	end

	-- KEEP PLAYERCOUNT
	if g_Globals.spawnMode == 'keep_playercount' then
		for i=1, g_Globals.nrOfTeams do
			targetTeamCount[i] = Config.initNumberOfBots;
		end
		if Config.spawnInBothTeams then
			for i=1, g_Globals.nrOfTeams do
				targetTeamCount[i] = math.floor(Config.initNumberOfBots/g_Globals.nrOfTeams);
			end
		else
			for i=1, g_Globals.nrOfTeams do
				if botTeam ~= i then
					targetTeamCount[i] = 0;
				end
			end
		end

		for i=1, g_Globals.nrOfTeams do
			if teamCount[i] < targetTeamCount[i] then
				self:spawnWayBots(nil, targetTeamCount[i]-teamCount[i], true, 0, 0, i);
			elseif teamCount[i] > targetTeamCount[i] and botCount[i] > 0 then
				BotManager:killAll(teamCount[i]-targetTeamCount[i], i)
			end
		end

	-- BALANCED teams
	elseif g_Globals.spawnMode == 'balanced_teams' then
		local maxPlayersInOneTeam = 0;
		for i=1, g_Globals.nrOfTeams do
			if countPlayers[i] > maxPlayersInOneTeam then
				maxPlayersInOneTeam = countPlayers[i]
			end
		end
		local targetCount = Config.initNumberOfBots + ((maxPlayersInOneTeam-1) * Config.newBotsPerNewPlayer)
		-- TODO: limit in SDM
		for i=1, g_Globals.nrOfTeams do
			targetTeamCount[i] = targetCount;
		end

		for i=1, g_Globals.nrOfTeams do
			if teamCount[i] < targetTeamCount[i] then
				self:spawnWayBots(nil, targetTeamCount[i]-teamCount[i], true, 0, 0, i);
			elseif teamCount[i] > targetTeamCount[i] then
				BotManager:killAll(teamCount[i]-targetTeamCount[i], i)
			end
		end
	-- INCREMENT WITH PLAYER
	elseif g_Globals.spawnMode == 'increment_with_players' then
		if Config.spawnInBothTeams then
			for i=1, g_Globals.nrOfTeams do
				targetTeamCount[i] = 0;
				for j = 1, g_Globals.nrOfTeams do
					if i ~= j then
						if (countPlayers[j]) > 0 then
							targetTeamCount[i] =  Config.initNumberOfBots + ((countPlayers[j]-1) * Config.newBotsPerNewPlayer)
							break; --TODO: only use first team. Write algo for SDM as well
						end
					end
				end
			end

			for i=1, g_Globals.nrOfTeams do
				if teamCount[i] < targetTeamCount[i] then
					self:spawnWayBots(nil, targetTeamCount[i]-teamCount[i], true, 0, 0, i);
				elseif teamCount[i] > targetTeamCount[i] and botCount[i] > 0 then
					BotManager:killAll(teamCount[i]-targetTeamCount[i], i)
				end
			end

		else
			-- check for bots in wrong team
			for i=1, g_Globals.nrOfTeams do
				if i ~= botTeam and botCount[i] > 0 then
					BotManager:killAll(nil, i)
				end
			end

			local targetBotCount = Config.initNumberOfBots + ((playerCount-1) * Config.newBotsPerNewPlayer)
			local amountToSpawn = targetBotCount - botCount;
			if amountToSpawn > 0 then
				self._botSpawnTimer = -5.0
				self:spawnWayBots(nil, amountToSpawn, true, 0, 0, botTeam);
			end
			if amountToSpawn < 0 then
				BotManager:killAll(-amountToSpawn)
			end
		end

	-- FIXED NUMBER TO SPAWN
	elseif g_Globals.spawnMode == 'fixed_number' then
		if Config.spawnInBothTeams then
			local amoutPerTeam = math.floor(Config.initNumberOfBots/g_Globals.nrOfTeams);

			for i=1, g_Globals.nrOfTeams do
				if teamCount[i] < amoutPerTeam then
					self:spawnWayBots(nil, amoutPerTeam-teamCount[i], true, 0, 0, i);
				elseif teamCount[i] > amoutPerTeam and botCount[i] > 0 then
					BotManager:killAll(teamCount[i]-amoutPerTeam, i)
				end
			end
		else
			-- check for bots in wrong team
			for i=1, g_Globals.nrOfTeams do
				if i ~= botTeam and botCount[i] > 0 then
					BotManager:killAll(nil, i)
				end
			end

			local targetBotCount = Config.initNumberOfBots
			local amountToSpawn = targetBotCount - botCount;
			if amountToSpawn > 0 then
				self._botSpawnTimer = -5.0
				self:spawnWayBots(nil, amountToSpawn, true, 0, 0, botTeam);
			end
			if amountToSpawn < 0 then
				BotManager:killAll(-amountToSpawn)
			end
		end
	elseif g_Globals.spawnMode == 'manual' then
		if self._firstSpawnInLevel then
			for i=1, g_Globals.nrOfTeams do
				self:spawnWayBots(nil, teamCount[i] - countPlayers[i], true, 0, 0, i);
			end
		end
	end
end

function BotSpawner:_onLevelDestroy()
	self._spawnSets = {}
	self._updateActive = false;
	self._firstSpawnInLevel = true;
	self._firstSpawnDelay 	= FIRST_SPAWN_DELAY;
	self._playerUpdateTimer = 0;
end

function BotSpawner:_onPlayerJoining(name)
	if BotManager:getPlayerCount() == 0 then
		if Debug.Server.BOT then
			print("first player - spawn bots")
		end
		self:onLevelLoaded()
	end
	-- detect BOT-Names
	if string.find(name, BOT_TOKEN) == 1 then --check if name starts with bot-token
		table.insert(self._kickPlayers, name)
		if BotManager:getBotByName(name) ~= nil then
			table.insert(g_Globals.ignoreBotNames, name);
			BotManager:destroyBot(name)
		end
	end
end

function BotSpawner:onLevelLoaded()
	if Debug.Server.BOT then
		print("on level loaded on spawner")
	end
	self._firstSpawnInLevel = true;
	self._playerUpdateTimer = 0;
	self._firstSpawnDelay 	= FIRST_SPAWN_DELAY;
end

function BotSpawner:_onUpdate(dt, pass)
	if pass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	if self._firstSpawnInLevel then
		if self._firstSpawnDelay <= 0 then
			if BotManager:getPlayerCount() > 0 then
				BotManager:configGlobals()
				self:updateBotAmountAndTeam();
				self._playerUpdateTimer = 0;
				self._firstSpawnInLevel = false;
			end
		else
			self._firstSpawnDelay = self._firstSpawnDelay - dt;
		end
	else
		self._playerUpdateTimer = self._playerUpdateTimer + dt;
		if self._playerUpdateTimer > 2 then
			self._playerUpdateTimer = 0;
			self:updateBotAmountAndTeam();
		end
	end

	if #self._spawnSets > 0 then
		if self._botSpawnTimer > 0.2 then	--time to wait between spawn. 0.2 works
			self._botSpawnTimer = 0
			local spawnSet = table.remove(self._spawnSets);
			self:_spawnSigleWayBot(spawnSet.playerVarOfBot, spawnSet.useRandomWay, spawnSet.activeWayIndex, spawnSet.indexOnPath, nil, spawnSet.team)
		end
		self._botSpawnTimer = self._botSpawnTimer + dt
	else
		if self._updateActive then
			self._updateActive = false;
			if g_Globals.spawnMode ~= 'manual' then
				--garbage-collection of unwanted bots
				BotManager:destroyDisabledBots();
				BotManager:freshnTables();
			end
		end
	end

	--kick players named after bots
	if #self._kickPlayers > 0 then
		for index,playerName in pairs(self._kickPlayers) do
			local player = PlayerManager:GetPlayerByName(playerName)
			if player ~= nil then
				player:Kick("You used a BOT-Name. Please use a real name on Fun-Bot-Servers...")
				for index,name in pairs(g_Globals.ignoreBotNames) do
					if name == playerName then
						table.remove(g_Globals.ignoreBotNames, index)
					end
				end
				table.remove(self._kickPlayers, index)
				break;
			end
		end
	end
end

function BotSpawner:_onRespawnBot(botname)
	local bot = BotManager:getBotByName(botname)
	local spawnMode = bot:getSpawnMode();

	if spawnMode == 2 then --spawnInLine
		local transform = LinearTransform();
		transform = bot:getSpawnTransform();
		self:spawnBot(bot, transform, false);

	elseif spawnMode == 4 then	--fixed Way
		local wayIndex 		= bot:getWayIndex();
		local randIndex 	= MathUtils:GetRandomInt(1, #g_NodeCollection:Get(nil, wayIndex));
		self:_spawnSigleWayBot(nil, false, wayIndex, randIndex, bot)

	elseif spawnMode == 5 then --random Way
		self:_spawnSigleWayBot(nil, true, 0, 0, bot)
	end
end

function BotSpawner:spawnBotRow(player, length, spacing)
	for i = 1, length do
		local name = BotManager:findNextBotName()
		if name ~= nil then
			local transform = LinearTransform()
			transform.trans = player.soldier.worldTransform.trans + (player.soldier.worldTransform.forward * i * spacing)
			local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
			bot:setVarsStatic(player)
			self:spawnBot(bot, transform, true)
		end
	end
end

function BotSpawner:spawnBotTower(player, height)
	for i = 1, height do
		local name = BotManager:findNextBotName()
		if name ~= nil then
			local yaw = player.input.authoritativeAimingYaw
			local transform = LinearTransform()
			transform.trans.x = player.soldier.worldTransform.trans.x + (math.cos(yaw + (math.pi / 2)))
			transform.trans.y = player.soldier.worldTransform.trans.y + ((i - 1) * 1.8)
			transform.trans.z = player.soldier.worldTransform.trans.z + (math.sin(yaw + (math.pi / 2)))
			local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
			bot:setVarsStatic(player)
			self:spawnBot(bot, transform, true)
		end
	end
end

function BotSpawner:spawnBotGrid(player, rows, columns, spacing)
	for i = 1, rows do
		for j = 1, columns do
			local name = BotManager:findNextBotName()
			if name ~= nil then
				local yaw = player.input.authoritativeAimingYaw
				local transform = LinearTransform()
				transform.trans.x = player.soldier.worldTransform.trans.x + (i * math.cos(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.cos(yaw) * spacing)
				transform.trans.y = player.soldier.worldTransform.trans.y
				transform.trans.z = player.soldier.worldTransform.trans.z + (i * math.sin(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.sin(yaw) * spacing)
				local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
				bot:setVarsStatic(player)
				self:spawnBot(bot, transform, true)
			end
		end
	end
end

function BotSpawner:spawnLineBots(player, amount, spacing)
	 for i = 1, amount do
		local name = BotManager:findNextBotName()
		if name ~= nil then
			local transform = LinearTransform()
			transform.trans = player.soldier.worldTransform.trans + (player.soldier.worldTransform.forward * i * spacing)
			local bot = BotManager:createBot(name, BotManager:getBotTeam(), SquadId.SquadNone)
			bot:setVarsSimpleMovement(player, 2, transform)
			self:spawnBot(bot, transform, true)
		end
	end
end

function BotSpawner:_getSpawnPoint(team, squad)
	local activeWayIndex = 0;
	local indexOnPath = 0;

	local targetNode = nil
	local validPointFound = false;
	local targetDistance = Config.distanceToSpawnBots;
	local retryCounter = Config.maxTrysToSpawnAtDistance;
	local maximumTrys = 100;
	local trysDone = 0;

	-- CONQUEST
	-- spawn at base, squad-mate, captured flag
	if g_Globals.isConquest then
		activeWayIndex, indexOnPath = g_GameDirector:getSpawnPath(team, squad, false)

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
	elseif g_Globals.isRush then
		activeWayIndex, indexOnPath = g_GameDirector:getSpawnPath(team, squad, true)

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
			local playerNearby = false;
			local players = PlayerManager:GetPlayers()
			for i = 1, PlayerManager:GetPlayerCount() do
				local tempPlayer = players[i];
				if tempPlayer.alive then
					if team == nil or team ~= tempPlayer.teamId then
						local distance = tempPlayer.soldier.worldTransform.trans:Distance(spawnPoint)
						local heightDiff = math.abs(tempPlayer.soldier.worldTransform.trans.y - spawnPoint.y)
						if distance < targetDistance and heightDiff < Config.heightDistanceToSpawn then
							playerNearby = true;
							break;
						end
					end
				end
			end
			retryCounter = retryCounter - 1;
			trysDone = trysDone + 1;
			if retryCounter == 0 then
				retryCounter = Config.maxTrysToSpawnAtDistance;
				targetDistance = targetDistance - Config.distanceToSpawnReduction;
				if targetDistance < 0 then
					targetDistance = 0
				end
			end
			if not playerNearby then
				validPointFound = true;
			end
		end
	end
	return targetNode
end


function BotSpawner:getSquad(team)  --TODO: create a more advanced algorithm?
	if g_Globals.isSdm then
		if team % 2 == 1 then
			return 1;
		else
			return 0;  --TODO: only needed because of Vext-Bug
		end
	else
		for i = 1, SquadId.SquadIdCount - 1 do --for i = 9, SquadId.SquadIdCount - 1 do -- first 8 squads for real players
			if TeamSquadManager:GetSquadPlayerCount(team, i) < 4 then
				return i;
			end
		end
	end
	return 0;
end

function BotSpawner:_spawnSigleWayBot(player, useRandomWay, activeWayIndex, indexOnPath, existingBot, forcedTeam)
	local spawnPoint = nil
	local isRespawn = false;
	local name = nil;
	if existingBot ~= nil then
		isRespawn = true;
	else
		name = BotManager:findNextBotName()
	end
	local team = forcedTeam;
	local squad = SquadId.SquadNone
	if team == nil then
		team = BotManager:getBotTeam();
	end
	if isRespawn then
		team = existingBot.player.teamId;
		squad = existingBot.player.squadId;
	else
		squad = self:getSquad(team)
	end
	local inverseDirection = false;
	if name ~= nil or isRespawn then
		if Config.spawnMethod == SpawnMethod.Spawn then
			local s_Bot = self:GetBot(existingBot, name, team, squad)
			if s_Bot == nil then
				return
			end
			self:SelectLoadout(s_Bot)
			self:TriggerSpawn(s_Bot)
			table.insert(self._botsWithoutPath, s_Bot)
			return
		end
		-- find a spawnpoint
		if useRandomWay or activeWayIndex == nil or activeWayIndex == 0 then
			spawnPoint = self:_getSpawnPoint(team, squad);
		else
			spawnPoint = g_NodeCollection:Get(indexOnPath, activeWayIndex)
		end

		if spawnPoint == nil then
			return
		else
			indexOnPath = spawnPoint.PointIndex;
			activeWayIndex = spawnPoint.PathIndex;
		end

		--find out direction, if path has a return point
		if g_NodeCollection:Get(1, activeWayIndex).OptValue == 0xFF then
			inverseDirection = (MathUtils:GetRandomInt(0,1) == 1);
		end

		local transform = LinearTransform()
		if indexOnPath == nil or indexOnPath == 0 then
			indexOnPath = 1;
		end
		transform.trans = spawnPoint.Position

		if isRespawn then
			existingBot:setVarsWay(player, useRandomWay, activeWayIndex, indexOnPath, inverseDirection)
			self:spawnBot(existingBot, transform, false)
		else
			local bot = BotManager:createBot(name, team, squad)

			if bot ~= nil then
				-- check for first one in squad
				if (TeamSquadManager:GetSquadPlayerCount(team, squad) == 1) then
					bot.player:SetSquadLeader(true, false);  -- not private
				end

				bot:setVarsWay(player, useRandomWay, activeWayIndex, indexOnPath, inverseDirection)
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

function BotSpawner:SelectLoadout(p_Bot)
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

function BotSpawner:spawnWayBots(player, amount, useRandomWay, activeWayIndex, indexOnPath, teamId)
	if #g_NodeCollection:GetPaths() <= 0 then
		return
	end

	-- check for amount available
	local playerlimt = g_Globals.maxPlayers;
	if Config.keepOneSlotForPlayers then
		playerlimt = playerlimt - 1
	end

	local incactiveBots = BotManager:getBotCount() - BotManager:getActiveBotCount()
	local slotsLeft = playerlimt - (PlayerManager:GetPlayerCount() - incactiveBots);
	if amount > slotsLeft then
		amount = slotsLeft;
	end

	for i = 1, amount do
		local spawnSet = SpawnSet()
		spawnSet.playerVarOfBot 	= nil;
		spawnSet.useRandomWay 		= useRandomWay;
		spawnSet.activeWayIndex 	= activeWayIndex;
		spawnSet.indexOnPath 		= indexOnPath;
		spawnSet.team				= teamId;
		table.insert(self._spawnSets, spawnSet)
	end
end

-- Tries to find first available kit
-- @param teamName string Values: 'US', 'RU'
-- @param kitName string Values: 'Assault', 'Engineer', 'Support', 'Recon'
function BotSpawner:_findKit(teamName, kitName)

	local gameModeKits = {
		'', -- Standard
		'_GM', --Gun Master on XP2 Maps
		'_GM_XP4', -- Gun Master on XP4 Maps
		'_XP4', -- Copy of Standard for XP4 Maps
		'_XP4_SCV' -- Scavenger on XP4 Maps
	}

	for kitType=1, #gameModeKits do
		local properKitName = string.lower(kitName)
		properKitName = properKitName:gsub("%a", string.upper, 1)

		local fullKitName = string.upper(teamName)..properKitName..gameModeKits[kitType]
		local kit = ResourceManager:SearchForDataContainer('Gameplay/Kits/'..fullKitName)
		if kit ~= nil then
			return kit
		end
	end

	return
end

function BotSpawner:_findAppearance(teamName, kitName, color)
	local gameModeAppearances = {
		'MP/', -- Standard
		'MP_XP4/', --Gun Master on XP2 Maps
	}
	--'Persistence/Unlocks/Soldiers/Visual/MP[or:MP_XP4]/Us/MP_US_Assault_Appearance_'..color
	for _, gameMode in pairs(gameModeAppearances) do
		local appearanceString = gameMode..teamName..'/MP_'..string.upper(teamName)..'_'..kitName..'_Appearance_'..color
		local appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/'..appearanceString)
		if appearance ~= nil then
			return appearance
		end
	end

	return
end

function BotSpawner:_setAttachments(unlockWeapon, attachments)
	for _, attachment in pairs(attachments) do
		local asset = ResourceManager:SearchForDataContainer(attachment)
		if (asset == nil) then
			if Debug.Server.BOT then
				print('Warning! Attachment invalid ['..tostring(unlockWeapon.weapon.name)..']: '..tostring(attachment))
			end
		else
			unlockWeapon.unlockAssets:add(UnlockAsset(asset))
		end
	end
end

function BotSpawner:getKitApperanceCustomization(team, kit, color, primary, pistol, knife, gadget1, gadget2, grenade)
	-- Create the loadouts
	local soldierKit = nil
	local appearance = nil
	local soldierCustomization = CustomizeSoldierData()

	local pistolWeapon = ResourceManager:SearchForDataContainer(pistol:getResourcePath())
	local knifeWeapon = ResourceManager:SearchForDataContainer(knife:getResourcePath())
	local gadget1Weapon = ResourceManager:SearchForDataContainer(gadget1:getResourcePath())
	local gadget2Weapon = ResourceManager:SearchForDataContainer(gadget2:getResourcePath())
	local grenadeWeapon = ResourceManager:SearchForDataContainer(grenade:getResourcePath())

	soldierCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	soldierCustomization.removeAllExistingWeapons = true

	local primaryWeapon = UnlockWeaponAndSlot()
	primaryWeapon.slot = WeaponSlot.WeaponSlot_0

	local primaryWeaponResource = ResourceManager:SearchForDataContainer(primary:getResourcePath())
	primaryWeapon.weapon = SoldierWeaponUnlockAsset(primaryWeaponResource)
	self:_setAttachments(primaryWeapon, primary:getAllAttachements())

	local gadget01 = UnlockWeaponAndSlot()
	gadget01.weapon = SoldierWeaponUnlockAsset(gadget1Weapon)
	if kit == "Assault" or kit == "Support" then
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

	if team % 2 == 1 then -- US
		if kit == "Assault" then --assault
			appearance = self:_findAppearance('Us', 'Assault', color)
			soldierKit = self:_findKit('US', 'Assault')
		elseif kit == "Engineer" then --engineer
			appearance = self:_findAppearance('Us', 'Engi', color)
			soldierKit = self:_findKit('US', 'Engineer')
		elseif kit == "Support" then --support
			appearance = self:_findAppearance('Us', 'Support', color)
			soldierKit = self:_findKit('US', 'Support')
		else	--recon
			appearance = self:_findAppearance('Us', 'Recon', color)
			soldierKit = self:_findKit('US', 'Recon')
		end
	else -- RU
		if kit == "Assault" then --assault
			appearance = self:_findAppearance('RU', 'Assault', color)
			soldierKit = self:_findKit('RU', 'Assault')
		elseif kit == "Engineer" then --engineer
			appearance = self:_findAppearance('RU', 'Engi', color)
			soldierKit = self:_findKit('RU', 'Engineer')
		elseif kit == "Support" then --support
			appearance = self:_findAppearance('RU', 'Support', color)
			soldierKit = self:_findKit('RU', 'Support')
		else	--recon
			appearance = self:_findAppearance('RU', 'Recon', color)
			soldierKit = self:_findKit('RU', 'Recon')
		end
	end

	if Config.zombieMode then
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

function BotSpawner:_onKitPickup(player, newCustomization)
	if player.soldier ~= nil then
		if player.soldier.weaponsComponent.weapons[1] ~= nil then
			player.soldier.weaponsComponent.weapons[1].secondaryAmmo = 182;
		end
		if player.soldier.weaponsComponent.weapons[2] ~= nil then
			player.soldier.weaponsComponent.weapons[2].secondaryAmmo = 58;
		end
	end
end

function BotSpawner:_modifyWeapon(soldier)
	--soldier.weaponsComponent.currentWeapon.secondaryAmmo = 9999;
	if soldier.weaponsComponent.weapons[1] ~= nil then
		soldier.weaponsComponent.weapons[1].secondaryAmmo = 9999;
	end
	if soldier.weaponsComponent.weapons[2] ~= nil then
		soldier.weaponsComponent.weapons[2].secondaryAmmo = 9999;
	end
end

function BotSpawner:_getSpawnBotKit()
	local botKit = BotKits[MathUtils:GetRandomInt(2, #BotKits)];
	local changeKit = false;
	--find out, if possible
	local kitCount = BotManager:getKitCount(botKit);
	if botKit == "Assault" then
		if Config.maxAssaultBots >= 0 and kitCount >= Config.maxAssaultBots then
			changeKit = true;
		end
	elseif botKit == "Engineer" then
		if Config.maxEngineerBots >= 0 and kitCount >= Config.maxEngineerBots then
			changeKit = true;
		end
	elseif botKit == "Support" then
		if Config.maxSupportBots >= 0 and kitCount >= Config.maxSupportBots then
			changeKit = true;
		end
	else -- botKit == "Support"
		if Config.maxReconBots >= 0 and kitCount >= Config.maxReconBots then
			changeKit = true;
		end
	end

	if changeKit then
		local availableKitList = {};
		if (Config.maxAssaultBots == -1) or (BotManager:getKitCount("Assault") < Config.maxAssaultBots) then
			table.insert(availableKitList, "Assault")
		end
		if (Config.maxEngineerBots == -1) or (BotManager:getKitCount("Engineer") < Config.maxEngineerBots) then
			table.insert(availableKitList, "Engineer")
		end
		if (Config.maxSupportBots == -1) or (BotManager:getKitCount("Support") < Config.maxSupportBots) then
			table.insert(availableKitList, "Support")
		end
		if(Config.maxReconBots == -1) or (BotManager:getKitCount("Recon") < Config.maxReconBots) then
			table.insert(availableKitList, "Recon")
		end

		if #availableKitList > 0 then
			botKit = availableKitList[MathUtils:GetRandomInt(1, #availableKitList)];
		end
	end

	return botKit
end

function BotSpawner:setBotWeapons(bot, botKit, newWeapons)
	if newWeapons then
		if botKit == "Assault" then
			local weapon = Config.assaultWeapon;
			if Config.useRandomWeapon then
				weapon = AssaultPrimary[MathUtils:GetRandomInt(1, #AssaultPrimary)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
			bot.gadget2 = WeaponList:getWeapon(AssaultGadget2[MathUtils:GetRandomInt(1, #AssaultGadget2)]);
			bot.gadget1 = WeaponList:getWeapon(AssaultGadget1[MathUtils:GetRandomInt(1, #AssaultGadget1)]);
			bot.pistol = WeaponList:getWeapon(AssaultPistol[MathUtils:GetRandomInt(1, #AssaultPistol)]);
			bot.grenade = WeaponList:getWeapon(AssaultGrenade[MathUtils:GetRandomInt(1, #AssaultGrenade)]);
			bot.knife = WeaponList:getWeapon(AssaultKnife[MathUtils:GetRandomInt(1, #AssaultKnife)]);
		elseif botKit == "Engineer" then
			local weapon = Config.engineerWeapon;
			if Config.useRandomWeapon then
				weapon = EngineerPrimary[MathUtils:GetRandomInt(1, #EngineerPrimary)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
			bot.gadget2 = WeaponList:getWeapon(EngineerGadget2[MathUtils:GetRandomInt(1, #EngineerGadget2)]);
			bot.gadget1 = WeaponList:getWeapon(EngineerGadget1[MathUtils:GetRandomInt(1, #EngineerGadget1)]);
			bot.pistol = WeaponList:getWeapon(EngineerPistol[MathUtils:GetRandomInt(1, #EngineerPistol)]);
			bot.grenade = WeaponList:getWeapon(EngineerGrenade[MathUtils:GetRandomInt(1, #EngineerGrenade)]);
			bot.knife = WeaponList:getWeapon(EngineerKnife[MathUtils:GetRandomInt(1, #EngineerKnife)]);
		elseif botKit == "Support" then
			local weapon = Config.supportWeapon;
			if Config.useRandomWeapon then
				weapon = SupportPrimary[MathUtils:GetRandomInt(1, #SupportPrimary)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
			bot.gadget2 = WeaponList:getWeapon(SupportGadget2[MathUtils:GetRandomInt(1, #SupportGadget2)]);
			bot.gadget1 = WeaponList:getWeapon(SupportGadget1[MathUtils:GetRandomInt(1, #SupportGadget1)]);
			bot.pistol = WeaponList:getWeapon(SupportPistol[MathUtils:GetRandomInt(1, #SupportPistol)]);
			bot.grenade = WeaponList:getWeapon(SupportGrenade[MathUtils:GetRandomInt(1, #SupportGrenade)]);
			bot.knife = WeaponList:getWeapon(SupportKnife[MathUtils:GetRandomInt(1, #SupportKnife)]);
		else
			local weapon = Config.reconWeapon;
			if Config.useRandomWeapon then
				weapon = ReconPrimary[MathUtils:GetRandomInt(1, #ReconPrimary)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
			bot.gadget2 = WeaponList:getWeapon(ReconGadget2[MathUtils:GetRandomInt(1, #ReconGadget2)]);
			bot.gadget1 = WeaponList:getWeapon(ReconGadget1[MathUtils:GetRandomInt(1, #ReconGadget1)]);
			bot.pistol = WeaponList:getWeapon(ReconPistol[MathUtils:GetRandomInt(1, #ReconPistol)]);
			bot.grenade = WeaponList:getWeapon(ReconGrenade[MathUtils:GetRandomInt(1, #ReconGrenade)]);
			bot.knife = WeaponList:getWeapon(ReconKnife[MathUtils:GetRandomInt(1, #ReconKnife)]);
		end
	end

	if Config.botWeapon == "Primary" or Config.botWeapon == "Auto" then
		bot.activeWeapon = bot.primary;
	elseif Config.botWeapon == "Pistol" then
		bot.activeWeapon = bot.pistol;
	elseif Config.botWeapon == "Gadget2" then
		bot.activeWeapon = bot.gadget2;
	elseif Config.botWeapon == "Gadget1" then
		bot.activeWeapon = bot.gadget1;
	elseif Config.botWeapon == "Grenade" then
		bot.activeWeapon = bot.grenade;
	else
		bot.activeWeapon = bot.knife;
	end
end

function BotSpawner:spawnBot(bot, trans, setKit)
	local writeNewKit = (setKit or Config.botNewLoadoutOnSpawn)
	if not writeNewKit and (bot.color == "" or bot.kit == "" or bot.activeWeapon == nil) then
		writeNewKit = true;
	end
	local botColor = Config.botColor
	local botKit = Config.botKit

	if writeNewKit then
		if botColor == "RANDOM_COLOR" then
			botColor = BotColors[MathUtils:GetRandomInt(2, #BotColors)]
		end
		if botKit == "RANDOM_KIT" then
			botKit = self:_getSpawnBotKit();
		end
		bot.color = botColor
		bot.kit = botKit
	else
		botColor = bot.color
		botKit = bot.kit
	end

	self:setBotWeapons(bot, botKit, writeNewKit)

	bot:resetSpawnVars()

	-- create kit and appearance
	local soldierBlueprint = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier')
	local soldierCustomization = nil
	local soldierKit = nil
	local appearance = nil
	soldierKit, appearance, soldierCustomization = self:getKitApperanceCustomization(bot.player.teamId, botKit, botColor, bot.primary, bot.pistol, bot.knife, bot.gadget1, bot.gadget2, bot.grenade)

	-- Create the transform of where to spawn the bot at.
	local transform = LinearTransform()
	transform = trans

	-- And then spawn the bot. This will create and return a new SoldierEntity object.
	-- for Civilianizer-Mod
	if g_Globals.removeKitVisuals then
		BotManager:spawnBot(bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
	else
		BotManager:spawnBot(bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, { appearance })
	end
	bot.player.soldier:ApplyCustomization(soldierCustomization)
	self:_modifyWeapon(bot.player.soldier)

	-- for Civilianizer-mod:
	Events:Dispatch('Bot:SoldierEntity', bot.player.soldier)
end


-- Singleton.
if g_BotSpawner == nil then
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner