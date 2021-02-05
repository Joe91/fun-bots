class('BotSpawner');

local BotManager	= require('BotManager');
local Globals		= require('Globals');
local WeaponList	= require('WeaponList');
local Utilities 	= require('__shared/Utilities')

function BotSpawner:__init()
	self._botSpawnTimer = 0
	self._botsToSpawn = 0

	self._playerVarOfBot = nil
	self._useRandomWay = false
	self._activeWayIndex = 1
	self._indexOnPath = 0
	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Bot:RespawnBot', self, self._onRespawnBot)
	Events:Subscribe('Player:KitPickup', self, self._onKitPickup)
	Events:Subscribe('Player:Joining', self, self._onPlayerJoining)
	Events:Subscribe('Player:Left', self, self._onPlayerLeft)
end

function BotSpawner:_onPlayerJoining()
	if Config.onlySpawnBotsWithPlayers and BotManager:getPlayerCount() == 0 then
		print("first player - spawn bots")
		self:onLevelLoaded(true)
	else
		--detect if we have to kick a bot for the next player
		if Config.keepOneSlotForPlayers then
			local playerlimt = Globals.maxPlayers - 1
			local amoutToDestroy = PlayerManager:GetPlayerCount() + 1 - playerlimt -- +1 because on join, player is not counted jet
			if amoutToDestroy > 0 then
				BotManager:destroyAmount(amoutToDestroy)
			end
		end

		if Config.incBotsWithPlayers then
			--detect amount
			local totalPlayers = PlayerManager:GetPlayerCount() + 1;	-- +1 for new player
			local playerCount = BotManager:getPlayerCount() + 1; 		-- +1 for new player
			local botCount = BotManager:getBotCount();
			local targetBotCount = Config.initNumberOfBots + ((playerCount-1) * Config.newBotsPerNewPlayer)
			local amountToSpawn = targetBotCount - botCount;
			local playerlimt = Globals.maxPlayers;
			if Config.keepOneSlotForPlayers then
				playerlimt = playerlimt - 1
			end
			local slotsLeft = playerlimt - totalPlayers;
			if amountToSpawn > slotsLeft then
				amountToSpawn = slotsLeft;
			end
			if amountToSpawn > 0 then
				self._botSpawnTimer = -5.0
				self:spawnWayBots(nil, amountToSpawn, true, 1);
			end
		end
	end
end

function BotSpawner:_onPlayerLeft(player)
	BotManager:onPlayerLeft(player)
	--remove all references of player
	if Config.onlySpawnBotsWithPlayers then
		if BotManager:getPlayerCount() == 1 then
			print("no player left - kill all bots")
			BotManager:destroyAllBots()
		end
	end
	if Config.incBotsWithPlayers then
		local playerCount = BotManager:getPlayerCount() - 1; -- -1 for leaving player
		local botCount = BotManager:getBotCount();
		local targetBotCount = Config.initNumberOfBots + ((playerCount - 1) * Config.newBotsPerNewPlayer)
		if targetBotCount < Config.initNumberOfBots then
			targetBotCount = Config.initNumberOfBots;
		end
		if targetBotCount < botCount then
			BotManager:destroyAmount(botCount - targetBotCount);
		end
	end
end

function BotSpawner:onLevelLoaded(forceSpawn)
	if not Config.onlySpawnBotsWithPlayers or BotManager:getPlayerCount() > 0 or (forceSpawn ~= nil and forceSpawn) then
		BotManager:configGlobas()

		local amountToSpawn = Config.initNumberOfBots
		if Config.incBotsWithPlayers then
			local playerCount = BotManager:getPlayerCount();
			if playerCount >= 1 then
				amountToSpawn = Config.initNumberOfBots + ((playerCount-1) * Config.newBotsPerNewPlayer)
			end
		end

		if BotManager:getBotCount() > amountToSpawn and not Config.incBotsWithPlayers then
			amountToSpawn = BotManager:getBotCount()
		end

		if amountToSpawn > MAX_NUMBER_OF_BOTS then
			amountToSpawn = MAX_NUMBER_OF_BOTS;
		end

		local team = BotManager:getBotTeam();
		for i = 1,amountToSpawn do
			BotManager:createBot(BotNames[i], team)
		end
		if BotManager:getBotCount() > amountToSpawn then --if bots have been added in between
			local numberToKick = BotManager:getBotCount() - amountToSpawn
			BotManager:destroyAmount(numberToKick)
		end

		-- create initial bots
		if Globals.activeTraceIndexes > 0 and Config.spawnOnLevelstart then
			--signal bot Spawner to do its stuff
			self._botSpawnTimer = -5.0
			self:spawnWayBots(nil, amountToSpawn, true, 1)
		end
	end
end

function BotSpawner:_onUpdate(dt, pass)
	if pass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	if self._botsToSpawn > 0 then
		if self._botSpawnTimer > 0.1 then	--time to wait between spawn. 0.2 works
			self._botSpawnTimer = 0
			self._botsToSpawn = self._botsToSpawn - 1
			self:_spawnSigleWayBot(self._playerVarOfBot, self._useRandomWay, self._activeWayIndex, self._indexOnPath)
		end
		self._botSpawnTimer = self._botSpawnTimer + dt
	end
end

function BotSpawner:_onRespawnBot(botname)
	local bot = BotManager:GetBotByName(botname)
	local spawnMode = bot:getSpawnMode();

	if spawnMode == 2 then --spawnInLine
		local transform = LinearTransform();
		transform = bot:getSpawnTransform();
		self:spawnBot(bot, transform, false);

	elseif spawnMode == 4 then	--fixed Way
		local wayIndex 		= bot:getWayIndex();
		local randIndex 	= MathUtils:GetRandomInt(1, #Globals.wayPoints[wayIndex]);
		self:_spawnSigleWayBot(nil, false, wayIndex, randIndex, bot)

	elseif spawnMode == 5 then --random Way
		self:_spawnSigleWayBot(nil, true, 0, 0, bot)
	end
end

function BotSpawner:getBotTeam(player)
	local team;
	if player ~= nil then
		if Config.spawnInSameTeam then
			team = player.teamId
		else
			if player.teamId == TeamId.Team1 then
				team = TeamId.Team2
			else
				team = TeamId.Team1
			end
		end
	else
		team = BotManager:getBotTeam();
	end
	return team
end

function BotSpawner:spawnBotRow(player, length, spacing)
	for i = 1, length do
		local name = BotManager:findNextBotName()
		if name ~= nil then
			local transform = LinearTransform()
			transform.trans = player.soldier.worldTransform.trans + (player.soldier.worldTransform.forward * i * spacing)
			local bot = BotManager:createBot(name, self:getBotTeam(player))
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
			local bot = BotManager:createBot(name, self:getBotTeam(player))
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
				local bot = BotManager:createBot(name, self:getBotTeam(player))
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
			local bot = BotManager:createBot(name, self:getBotTeam(player))
			bot:setVarsSimpleMovement(player, 2, transform)
			self:spawnBot(bot, transform, true)
		end
	end
end

function BotSpawner:_spawnSigleWayBot(player, useRandomWay, activeWayIndex, indexOnPath, existingBot)
	local isRespawn = false;
	local name = nil;
	if existingBot ~= nil then
		isRespawn = true;
	else
		name = BotManager:findNextBotName()
	end
	local inverseDirection = false;
	if name ~= nil or isRespawn then

		-- find a spawnpoint away from players
		if useRandomWay or activeWayIndex == nil or activeWayIndex == 0 then
			local validPointFound = false;
			local targetDistance = Config.distanceToSpawnBots;
			local retryCounter = Config.maxTrysToSpawnAtDistance;
			while not validPointFound do
				-- get new point
				activeWayIndex = self:_getNewWayIndex()
				if activeWayIndex == 0 then
					return
				end
				indexOnPath = MathUtils:GetRandomInt(1, #Globals.wayPoints[activeWayIndex])
				if Globals.wayPoints[activeWayIndex][1] == nil then
					return
				end
				local spawnPoint = Globals.wayPoints[activeWayIndex][indexOnPath].trans

				--check for nearby player
				local playerNearby = false;
				local players = PlayerManager:GetPlayers()
				for i = 1, PlayerManager:GetPlayerCount() do
					local tempPlayer = players[i];
					if not Utilities:isBot(tempPlayer.name) then
						--real player
						if tempPlayer.alive then
							local distance = tempPlayer.soldier.worldTransform.trans:Distance(spawnPoint)
							if distance < targetDistance then
								playerNearby = true;
								break;
							end
						end
					end
				end
				retryCounter = retryCounter - 1;
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

		if Globals.wayPoints[activeWayIndex][1] == nil then
			return
		end
		--find out direction, if path has a return point
		if Globals.wayPoints[activeWayIndex][1].optValue == 0xFF then
			inverseDirection = (MathUtils:GetRandomInt(0,1) == 1);
		end

		local transform = LinearTransform()
		if indexOnPath == nil or indexOnPath == 0 then
			indexOnPath = 1;
		end
		transform.trans = Globals.wayPoints[activeWayIndex][indexOnPath].trans

		if isRespawn then
			existingBot:setVarsWay(player, useRandomWay, activeWayIndex, indexOnPath, inverseDirection)
			self:spawnBot(existingBot, transform, false)
		else
			local bot = BotManager:createBot(name, self:getBotTeam(player, name))
			if bot ~= nil then
				bot:setVarsWay(player, useRandomWay, activeWayIndex, indexOnPath, inverseDirection)
				self:spawnBot(bot, transform, true)
			end
		end
	end
end

function BotSpawner:spawnWayBots(player, amount, useRandomWay, activeWayIndex, indexOnPath)
	if Globals.activeTraceIndexes <= 0 then
		return
	end
	self._botsToSpawn = amount
	self._playerVarOfBot = player
	self._useRandomWay = useRandomWay
	self._activeWayIndex = activeWayIndex
	self._indexOnPath = indexOnPath
end

function BotSpawner:_getNewWayIndex()
	local newWayIdex = 0
	if Globals.activeTraceIndexes <= 0 then
		return newWayIdex
	end
	local targetWaypoint = MathUtils:GetRandomInt(1, Globals.activeTraceIndexes)
	local count = 0
	for i = 1, MAX_TRACE_NUMBERS do
		if Globals.wayPoints[i][1] ~= nil then
			count = count + 1
		end
		if count == targetWaypoint then
			newWayIdex = i
			return newWayIdex
		end
	end
	return newWayIdex
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
		local unlockAsset = UnlockAsset(ResourceManager:SearchForDataContainer(attachment))
		unlockWeapon.unlockAssets:add(unlockAsset)
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
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/RadioBeacon/U_RadioBeacon'))
		--no second gadget
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

	soldierCustomization.weapons:add(primaryWeapon)
	soldierCustomization.weapons:add(secondaryWeapon)
	soldierCustomization.weapons:add(gadget01)
	soldierCustomization.weapons:add(gadget02)
	soldierCustomization.weapons:add(thrownWeapon)
	soldierCustomization.weapons:add(meleeWeapon)

	return soldierKit, appearance, soldierCustomization
end

function BotSpawner:_onKitPickup(player, newCustomization)
	if player.soldier ~= nil then
		player.soldier.weaponsComponent.weapons[1].secondaryAmmo = 182;
		player.soldier.weaponsComponent.weapons[2].secondaryAmmo = 58;
	end
end

function BotSpawner:_modifyWeapon(soldier)
	--soldier.weaponsComponent.currentWeapon.secondaryAmmo = 9999;
	soldier.weaponsComponent.weapons[1].secondaryAmmo = 9999;
	soldier.weaponsComponent.weapons[2].secondaryAmmo = 9999;
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
			if not Config.useShotgun then
				bot.primary = WeaponList:getWeapon(Config.assaultWeapon)
			else
				bot.primary = WeaponList:getWeapon(Config.assaultShotgun)
			end
		elseif botKit == "Engineer" then
			if not Config.useShotgun then
				bot.primary = WeaponList:getWeapon(Config.engineerWeapon)
			else
				bot.primary = WeaponList:getWeapon(Config.engineerShotgun)
			end
		elseif botKit == "Support" then
			if not Config.useShotgun then
				bot.primary = WeaponList:getWeapon(Config.supportWeapon)
			else
				bot.primary = WeaponList:getWeapon(Config.supportShotgun)
			end
		else
			if not Config.useShotgun then
				bot.primary = WeaponList:getWeapon(Config.reconWeapon)
			else
				bot.primary = WeaponList:getWeapon(Config.reconShotgun)
			end
		end
		bot.pistol = WeaponList:getWeapon(Config.pistol)
		bot.knife = WeaponList:getWeapon(Config.knife)
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