class('BotSpawner');

require('Globals');
require('SpawnSet')
require('__shared/NodeCollection')

local BotManager	= require('BotManager');
local WeaponList	= require('__shared/WeaponList');
local Utilities 	= require('__shared/Utilities')

function BotSpawner:__init()
	self._botSpawnTimer = 0
	self._firstSpawnInLevel = true;
	self._firstSpawnDelay = 5;
	self._updateActive = false;
	self._spawnSets = {}

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Bot:RespawnBot', self, self._onRespawnBot)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	Events:Subscribe('Player:KitPickup', self, self._onKitPickup)
	Events:Subscribe('Player:Joining', self, self._onPlayerJoining)
	Events:Subscribe('Player:Left', self, self._onPlayerLeft)
	Events:Subscribe('Player:Respawn', self, self._onPlayerRespawn)
end

function BotSpawner:updateBotAmountAndTeam()
	-- keep Slot for next player
	if Config.keepOneSlotForPlayers then
		local playerlimt = g_Globals.maxPlayers - 1
		local amoutToDestroy = PlayerManager:GetPlayerCount() - playerlimt
		if amoutToDestroy > 0 then
			BotManager:destroyAmount(amoutToDestroy)
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
	local countPlayersTeam1 = 0;
	local countPlayersTeam2 = 0;
	local botTeam = BotManager:getBotTeam();
	local players = PlayerManager:GetPlayers()
	for i = 1, PlayerManager:GetPlayerCount() do
		if BotManager:getBotByName(players[i].name) == nil then
			if players[i].teamId == TeamId.Team1 then
				countPlayersTeam1 = countPlayersTeam1 + 1;
			else
				countPlayersTeam2 = countPlayersTeam2 + 1;
			end
		end
	end
	local botCountTeam1 = BotManager:getActiveBotCount(TeamId.Team1);
	local botCountTeam2 = BotManager:getActiveBotCount(TeamId.Team2);
	local team1Count = countPlayersTeam1 + botCountTeam1;
	local team2Count = countPlayersTeam2 + botCountTeam2;

	-- KEEP PLAYERCOUNT
	if g_Globals.spawnMode == 'keep_playercount' then
		local targetTeam1 = Config.initNumberOfBots;
		local targetTeam2 = Config.initNumberOfBots;
		if Config.spawnInBothTeams then
			targetTeam1 = math.floor(Config.initNumberOfBots/2);
			targetTeam2 = math.floor(Config.initNumberOfBots/2);
		else
			if botTeam == TeamId.Team1 then
				targetTeam2 = 0;
			else
				targetTeam1 = 0;
			end
		end

		if team1Count < targetTeam1 then
			self:spawnWayBots(nil, targetTeam1-team1Count, true, 0, 0, TeamId.Team1);
		end
		if team2Count < targetTeam2 then
			self:spawnWayBots(nil, targetTeam2-team2Count, true, 0, 0, TeamId.Team2);
		end

		if botCount > 0 then
			if team1Count > targetTeam1 then
				BotManager:killTeam(TeamId.Team1, team1Count-targetTeam1)
			end
			if team2Count > targetTeam2 then
				BotManager:killTeam(TeamId.Team2, team2Count-targetTeam2)
			end
		end

	-- BALANCED teams
	elseif g_Globals.spawnMode == 'balanced_teams' then
		local targetBotCountTeam1 = 0;
		local targetBotCountTeam2 = 0;

		if countPlayersTeam1 > 0 then
			targetBotCountTeam2 = Config.initNumberOfBots + ((countPlayersTeam1-1) * Config.newBotsPerNewPlayer)
		end
		if countPlayersTeam2 > 0 then
			targetBotCountTeam1 = Config.initNumberOfBots + ((countPlayersTeam2-1) * Config.newBotsPerNewPlayer)
		end

		local targetTeam1 = countPlayersTeam1 + targetBotCountTeam1
		local targetTeam2 = countPlayersTeam2 + targetBotCountTeam2
		if targetTeam1 > targetTeam2 then
			targetTeam2 = targetTeam1;
		elseif targetTeam2 > targetTeam1 then
			targetTeam1 = targetTeam2;
		end
		targetTeam1 = targetTeam1 - countPlayersTeam1;
		targetTeam2 = targetTeam2 - countPlayersTeam2;

		local amountToSpawnTeam1 = targetTeam1 - botCountTeam1;
		local amountToSpawnTeam2 = targetTeam2 - botCountTeam2;

		if amountToSpawnTeam1 > 0 then
			self:spawnWayBots(nil, amountToSpawnTeam1, true, 0, 0, TeamId.Team1);
		end
		if amountToSpawnTeam2 > 0 then
			self:spawnWayBots(nil, amountToSpawnTeam2, true, 0, 0, TeamId.Team2);
		end
		if amountToSpawnTeam1 < 0 then
			BotManager:killTeam(TeamId.Team1, -amountToSpawnTeam1)
		end
		if amountToSpawnTeam2 < 0 then
			BotManager:killTeam(TeamId.Team2, -amountToSpawnTeam2)
		end

	-- INCREMENT WITH PLAYER
	elseif g_Globals.spawnMode == 'increment_with_players' then
		if Config.spawnInBothTeams then
			local targetBotCountTeam1 = 0;
			local targetBotCountTeam2 = 0;

			if countPlayersTeam1 > 0 then
				targetBotCountTeam2 = Config.initNumberOfBots + ((countPlayersTeam1-1) * Config.newBotsPerNewPlayer)
			end
			if countPlayersTeam2 > 0 then
				targetBotCountTeam1 = Config.initNumberOfBots + ((countPlayersTeam2-1) * Config.newBotsPerNewPlayer)
			end
			local amountToSpawnTeam1 = targetBotCountTeam1 - botCountTeam1;
			local amountToSpawnTeam2 = targetBotCountTeam2 - botCountTeam2;

			if amountToSpawnTeam1 > 0 then
				self:spawnWayBots(nil, amountToSpawnTeam1, true, 0, 0, TeamId.Team1);
			end
			if amountToSpawnTeam2 > 0 then
				self:spawnWayBots(nil, amountToSpawnTeam2, true, 0, 0, TeamId.Team2);
			end
			if amountToSpawnTeam1 < 0 then
				BotManager:killTeam(TeamId.Team1, -amountToSpawnTeam1)
			end
			if amountToSpawnTeam2 < 0 then
				BotManager:killTeam(TeamId.Team2, -amountToSpawnTeam2)
			end

		else
			-- check for bots in wrong team
			if botTeam == TeamId.Team1 and botCountTeam2 > 0 then
				BotManager:killTeam(TeamId.Team2)
			elseif botTeam == TeamId.Team2 and botCountTeam1 > 0 then
				BotManager:killTeam(TeamId.Team1)
			end

			local targetBotCount = Config.initNumberOfBots + ((playerCount-1) * Config.newBotsPerNewPlayer)
			local amountToSpawn = targetBotCount - botCount;
			if amountToSpawn > 0 then
				self._botSpawnTimer = -5.0
				self:spawnWayBots(nil, amountToSpawn, true, 0, 0, botTeam);
			end
			if amountToSpawn < 0 then
				BotManager:killAmount(-amountToSpawn)
			end
		end

	-- FIXED NUMBER TO SPAWN
	elseif g_Globals.spawnMode == 'fixed_number' then
		if Config.spawnInBothTeams then
			local amoutPerTeam = math.floor(Config.initNumberOfBots/2);
			-- check for too many bots in one team
			if botCountTeam2 > amoutPerTeam then
				BotManager:killTeam(TeamId.Team2, botCountTeam2-amoutPerTeam)
			end
			if botCountTeam1 > amoutPerTeam then
				BotManager:killTeam(TeamId.Team1, botCountTeam1-amoutPerTeam)
			end

			if botCountTeam2 < amoutPerTeam then
				self:spawnWayBots(nil, amoutPerTeam - botCountTeam2, true, 0, 0, TeamId.Team2);
			end
			if botCountTeam1 < amoutPerTeam then
				self:spawnWayBots(nil, amoutPerTeam - botCountTeam1, true, 0, 0, TeamId.Team1);
			end
		else
			-- check for bots in wrong team
			if botTeam == TeamId.Team1 and botCountTeam2 > 0 then
				BotManager:killTeam(TeamId.Team2)
			elseif botTeam == TeamId.Team2 and botCountTeam1 > 0 then
				BotManager:killTeam(TeamId.Team1)
			end

			if botTeam == TeamId.Team1 then
				if Config.initNumberOfBots > botCountTeam1 then
					self:spawnWayBots(nil, Config.initNumberOfBots-botCountTeam1, true, 0, 0, TeamId.Team1);
				end
			else
				if Config.initNumberOfBots > botCountTeam2 then
					self:spawnWayBots(nil, Config.initNumberOfBots-botCountTeam2, true, 0, 0, TeamId.Team2);
				end
			end
		end
	elseif g_Globals.spawnMode == 'manual' then
		if self._firstSpawnInLevel then
			local team1TempCount = #PlayerManager:GetPlayersByTeam(TeamId.Team1) - countPlayersTeam1;
			local team2TempCount = #PlayerManager:GetPlayersByTeam(TeamId.Team2) - countPlayersTeam2;
			self:spawnWayBots(nil, team2TempCount, true, 0, 0, TeamId.Team2);
			self:spawnWayBots(nil, team1TempCount, true, 0, 0, TeamId.Team1);
		end
	end
end

function BotSpawner:_onPlayerRespawn(player)
	if not Utilities:isBot(player.name) then
		if not self._firstSpawnInLevel then
			self:updateBotAmountAndTeam();
		end
	end
end

function BotSpawner:_onLevelDestroy()
	self._spawnSets = {}
	self._updateActive = false;
	self._firstSpawnInLevel = true;
	self._firstSpawnDelay 	= 5;
end

function BotSpawner:_onPlayerJoining()
	if BotManager:getPlayerCount() == 0 then
		print("first player - spawn bots")
		self:onLevelLoaded()
	end
end

function BotSpawner:_onPlayerLeft(player)
	BotManager:onPlayerLeft(player)
	--remove all references of player
	if BotManager:getPlayerCount() == 1 then
		print("no player left - kick all bots")
		BotManager:destroyAllBots();
	end
end

function BotSpawner:onLevelLoaded()
	print("on level loaded on spawner")
	self._firstSpawnInLevel = true;
	self._firstSpawnDelay 	= 5;
end

function BotSpawner:_onUpdate(dt, pass)
	if pass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	if self._firstSpawnInLevel then
		if self._firstSpawnDelay <= 0 then
			if BotManager:getPlayerCount() > 0 then
				BotManager:configGlobas()
				self:updateBotAmountAndTeam();
				self._firstSpawnInLevel = false;
			end
		else
			self._firstSpawnDelay = self._firstSpawnDelay - dt;
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
			--garbage-collection of unwanted bots
			BotManager:destroyDisabledBots();
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
		activeWayIndex = g_GameDirector:getSpawnPath(team, squad, false)

		if activeWayIndex == 0 then
			-- something went wrong. use random path
			print("no base or capturepoint found to spawn")
			activeWayIndex = MathUtils:GetRandomInt(1, #g_NodeCollection:GetPaths())
		end
		indexOnPath = MathUtils:GetRandomInt(1, #g_NodeCollection:Get(nil, activeWayIndex))

		targetNode = g_NodeCollection:Get(indexOnPath, activeWayIndex)


	-- RUSH
	-- spawn at base (of zone) or squad-mate
	elseif g_Globals.isRush then
		activeWayIndex = g_GameDirector:getSpawnPath(team, squad, true)

		if activeWayIndex == 0 then
			-- something went wrong. use random path
			print("no base found to spawn")
			activeWayIndex = MathUtils:GetRandomInt(1, #g_NodeCollection:GetPaths())
		end
		indexOnPath = MathUtils:GetRandomInt(1, #g_NodeCollection:Get(nil, activeWayIndex))

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
	for i = 1, SquadId.SquadIdCount - 1 do --for i = 9, SquadId.SquadIdCount - 1 do -- first 8 squads for real players
		if TeamSquadManager:GetSquadPlayerCount(team, i) < 4 then
			return i
		end
	end
	return 0
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
				bot:setVarsWay(player, useRandomWay, activeWayIndex, indexOnPath, inverseDirection)
				self:spawnBot(bot, transform, true)
			end
		end
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
			print('Warning! Attachment invalid ['..tostring(unlockWeapon.weapon.name)..']: '..tostring(attachment))
		else
			unlockWeapon.unlockAssets:add(UnlockAsset(asset))
		end
	end
end

function BotSpawner:getKitApperanceCustomization(team, kit, color, primary, pistol, knife)
	-- Create the loadouts
	local soldierKit = nil
	local appearance = nil
	local soldierCustomization = CustomizeSoldierData()

	local pistolWeapon = ResourceManager:SearchForDataContainer(pistol:getResourcePath())
	local knifeWeapon = ResourceManager:SearchForDataContainer(knife:getResourcePath())
	local grenadeWeapon = ResourceManager:SearchForDataContainer('Weapons/M67/U_M67')

	soldierCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	soldierCustomization.removeAllExistingWeapons = true

	local primaryWeapon = UnlockWeaponAndSlot()
	primaryWeapon.slot = WeaponSlot.WeaponSlot_0

	local primaryWeaponResource = ResourceManager:SearchForDataContainer(primary:getResourcePath())
	primaryWeapon.weapon = SoldierWeaponUnlockAsset(primaryWeaponResource)
	self:_setAttachments(primaryWeapon, primary:getAllAttachements())

	local gadget01 = UnlockWeaponAndSlot()
	gadget01.slot = WeaponSlot.WeaponSlot_2

	local gadget02 = UnlockWeaponAndSlot()
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


	if kit == "Assault" then
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Medicbag/U_Medkit'))
		gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Defibrillator/U_Defib'))

	elseif kit == "Engineer" then --engineer
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Repairtool/U_Repairtool'))
		gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/SMAW/U_SMAW'))

	elseif kit == "Support" then --support
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Ammobag/U_Ammobag'))
		gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Claymore/U_Claymore'))

	else	--"Recon"
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/T-UGS/U_UGS'))
		gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/RadioBeacon/U_RadioBeacon'))
	end

	if Config.zombieMode then
		kit = "Engineer";
		color = "Ninja";
	end

	if team == TeamId.Team1 then -- US
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
				weapon = WeaponsAssault[MathUtils:GetRandomInt(1, #WeaponsAssault)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
		elseif botKit == "Engineer" then
			local weapon = Config.engineerWeapon;
			if Config.useRandomWeapon then
				weapon = WeaponsEngineer[MathUtils:GetRandomInt(1, #WeaponsEngineer)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
		elseif botKit == "Support" then
			local weapon = Config.supportWeapon;
			if Config.useRandomWeapon then
				weapon = WeaponsSupport[MathUtils:GetRandomInt(1, #WeaponsSupport)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
		else
			local weapon = Config.reconWeapon;
			if Config.useRandomWeapon then
				weapon = WeaponsRecon[MathUtils:GetRandomInt(1, #WeaponsRecon)]
			end
			bot.primary = WeaponList:getWeapon(weapon)
		end
		local knife = Config.knife;
		local pistol = Config.pistol
		if Config.useRandomWeapon then
			knife = KnifeWeapons[MathUtils:GetRandomInt(1, #KnifeWeapons)]
			pistol = PistoWeapons[MathUtils:GetRandomInt(1, #PistoWeapons)]
		end
		bot.pistol = WeaponList:getWeapon(pistol)
		bot.knife = WeaponList:getWeapon(knife)
	end

	if Config.botWeapon == "Primary" then
		bot.activeWeapon = bot.primary;
	elseif Config.botWeapon == "Pistol" then
		bot.activeWeapon = bot.pistol;
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
	soldierKit, appearance, soldierCustomization = self:getKitApperanceCustomization(bot.player.teamId, botKit, botColor, bot.primary, bot.pistol, bot.knife)

	-- Create the transform of where to spawn the bot at.
	local transform = LinearTransform()
	transform = trans

	-- And then spawn the bot. This will create and return a new SoldierEntity object.
	BotManager:spawnBot(bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, { appearance })
	bot.player.soldier:ApplyCustomization(soldierCustomization)
	self:_modifyWeapon(bot.player.soldier)
end


-- Singleton.
if g_BotSpawner == nil then
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner