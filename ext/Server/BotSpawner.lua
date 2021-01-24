class('BotSpawner');

local BotManager	= require('BotManager');
local Globals		= require('Globals');

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
end

function BotSpawner:_onPlayerJoining()
	if Config.onlySpawnBotsWithPlayers then
		if BotManager:getPlayerCount() == 0 then
			print("first player - spawn bots")
			self:onLevelLoaded(true)
		end
	end
end

function BotSpawner:onLevelLoaded(forceSpawn)
	if not Config.onlySpawnBotsWithPlayers or BotManager:getPlayerCount() > 0 or (forceSpawn ~= nil and forceSpawn) then
		BotManager:configGlobas()

		local amountToSpawn = Config.initNumberOfBots
		if BotManager:getBotCount() > amountToSpawn then
			amountToSpawn = BotManager:getBotCount()
		end

		for i = 1,amountToSpawn do
			BotManager:createBot(BotNames[i], Globals.botTeam)
		end
		if BotManager:getBotCount() > amountToSpawn then --if bots have been added in between
			local numberToKick = BotManager:getBotCount() - amountToSpawn
			BotManager:destroyAmount(numberToKick)
		end

		-- create initial bots
		if Globals.activeTraceIndexes > 0 and Config.spawnOnLevelstart then
			--signal bot Spawner to do its stuff
			self._botSpawnTimer = -2.5
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
		local wayIndex 			= bot:getWayIndex();
		local randIndex 		= MathUtils:GetRandomInt(1, #Globals.wayPoints[wayIndex]);
		local transform 		= LinearTransform();
		local inverseDirection 	= false;
		if Globals.wayPoints[wayIndex][1].optValue == 0xFF then
			inverseDirection = (MathUtils:GetRandomInt(0,1) == 1);
		end
		transform.trans = Globals.wayPoints[wayIndex][randIndex].trans;
		bot:setCurrentWayPoint(randIndex);
		bot:setDirectionInversion(inverseDirection);
		self:spawnBot(bot, transform, false);

	elseif spawnMode == 5 then --random Way
		local wayIndex = self:_getNewWayIndex()
		if wayIndex ~= 0 then
			local randIndex = MathUtils:GetRandomInt(1, #Globals.wayPoints[wayIndex])
			local transform = LinearTransform();
			local inverseDirection 	= false;
			if Globals.wayPoints[wayIndex][1].optValue == 0xFF then
				inverseDirection = (MathUtils:GetRandomInt(0,1) == 1);
			end
			bot:setWayIndex(wayIndex);
			bot:setCurrentWayPoint(randIndex);
			bot:setDirectionInversion(inverseDirection);
			transform.trans = Globals.wayPoints[wayIndex][randIndex].trans
			self:spawnBot(bot, transform, false)
		end
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
		BotManager:detectBotTeam();
		team = Globals.botTeam;
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

function BotSpawner:_spawnSigleWayBot(player, useRandomWay, activeWayIndex, indexOnPath)
	local name = BotManager:findNextBotName()
	local inverseDirection = false;
	if name ~= nil then
		if useRandomWay or activeWayIndex == nil or activeWayIndex == 0 then
			activeWayIndex = self:_getNewWayIndex()
			if activeWayIndex == 0 then
				return
			end
		end
		if Globals.wayPoints[activeWayIndex][1] == nil then
			return
		end
		--find out direction, if path has a return point
		if Globals.wayPoints[activeWayIndex][1].optValue == 0xFF then
			inverseDirection = (MathUtils:GetRandomInt(0,1) == 1);
		end

		if indexOnPath == nil or indexOnPath == 0 then
			indexOnPath = MathUtils:GetRandomInt(1, #Globals.wayPoints[activeWayIndex])
		end
		local transform = LinearTransform()
		transform.trans = Globals.wayPoints[activeWayIndex][indexOnPath].trans

		local bot = BotManager:createBot(name, self:getBotTeam(player, name))
		if bot ~= nil then
			bot:setVarsWay(player, useRandomWay, activeWayIndex, indexOnPath, inverseDirection)
			self:spawnBot(bot, transform, true)
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

function BotSpawner:getKitApperanceCustomization(team, kit, color)
	-- Create the loadouts
	local soldierKit = nil
	local appearance = nil
	local soldierCustomization = CustomizeSoldierData()

	local m1911 = ResourceManager:SearchForDataContainer('Weapons/M1911/U_M1911_Tactical')
	local knife = ResourceManager:SearchForDataContainer('Weapons/Knife/U_Knife')

	soldierCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	soldierCustomization.removeAllExistingWeapons = true

	local primaryWeapon = UnlockWeaponAndSlot()
	primaryWeapon.slot = WeaponSlot.WeaponSlot_0

	local gadget01 = UnlockWeaponAndSlot()
	gadget01.slot = WeaponSlot.WeaponSlot_2

	local gadget02 = UnlockWeaponAndSlot()
	gadget02.slot = WeaponSlot.WeaponSlot_5

	local secondaryWeapon = UnlockWeaponAndSlot()
	secondaryWeapon.weapon = SoldierWeaponUnlockAsset(m1911)
	secondaryWeapon.slot = WeaponSlot.WeaponSlot_1

	local meleeWeapon = UnlockWeaponAndSlot()
	meleeWeapon.weapon = SoldierWeaponUnlockAsset(knife)
	meleeWeapon.slot = WeaponSlot.WeaponSlot_7

	if kit == "Assault" then
		local m416 = ResourceManager:SearchForDataContainer('Weapons/M416/U_M416')
		local m416Attachments = { 'Weapons/M416/U_M416_Kobra', 'Weapons/M416/U_M416_HeavyBarrel' }
		primaryWeapon.weapon = SoldierWeaponUnlockAsset(m416)
		self:_setAttachments(primaryWeapon, m416Attachments)
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Medicbag/U_Medkit'))
		gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Defibrillator/U_Defib'))

	elseif kit == "Engineer" then --engineer
		local asval = ResourceManager:SearchForDataContainer('Weapons/ASVal/U_ASVal')
		local asvalAttachments = { 'Weapons/ASVal/U_ASVal_Kobra', 'Weapons/ASVal/U_ASVal_ExtendedMag' }
		primaryWeapon.weapon = SoldierWeaponUnlockAsset(asval)
		self:_setAttachments(primaryWeapon, asvalAttachments)
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Repairtool/U_Repairtool'))
		gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/SMAW/U_SMAW'))

	elseif kit == "Support" then --support
		local m249 = ResourceManager:SearchForDataContainer('Weapons/M249/U_M249')
		local m249Attachments = { 'Weapons/M249/U_M249_Eotech', 'Weapons/M249/U_M249_Bipod' }
		primaryWeapon.weapon = SoldierWeaponUnlockAsset(m249)
		self:_setAttachments(primaryWeapon, m249Attachments)
		gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Ammobag/U_Ammobag'))
		gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Claymore/U_Claymore'))

	else	--"Recon"
		local l96 = ResourceManager:SearchForDataContainer('Weapons/XP1_L96/U_L96')
		local l96Attachments = { 'Weapons/XP1_L96/U_L96_Rifle_6xScope', 'Weapons/XP1_L96/U_L96_StraightPull' }
		primaryWeapon.weapon = SoldierWeaponUnlockAsset(l96)
		self:_setAttachments(primaryWeapon, l96Attachments)
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
		if Config.maxAssaultBots >= 0 and kitCount > Config.maxAssaultBots then
			changeKit = true;
		end
	elseif botKit == "Engineer" then
		if Config.maxEngineerBots >= 0 and kitCount > Config.maxEngineerBots then
			changeKit = true;
		end
	elseif botKit == "Support" then
		if Config.maxSupportBots >= 0 and kitCount > Config.maxSupportBots then
			changeKit = true;
		end
	else -- botKit == "Support"
		if Config.maxReconBots >= 0 and kitCount > Config.maxReconBots then
			changeKit = true;
		end
	end

	if changeKit then
		local availableKitList = {};
		if (Config.maxAssaultBots == -1) and true or (BotManager:getKitCount("Assault") < Config.maxAssaultBots) then
			table.insert(availableKitList, "Assault")
		end
		if (Config.maxEngineerBots == -1) and true or (BotManager:getKitCount("Engineer") < Config.maxEngineerBots) then
			table.insert(availableKitList, "Engineer")
		end
		if (Config.maxSupportBots == -1) and true or (BotManager:getKitCount("Support") < Config.maxSupportBots) then
			table.insert(availableKitList, "Support")
		end
		if(Config.maxReconBots == -1) and true or (BotManager:getKitCount("Recon") < Config.maxReconBots) then
			table.insert(availableKitList, "Recon")
		end

		if #availableKitList > 0 then
			botKit = availableKitList[MathUtils:GetRandomInt(1, #availableKitList)];
		end
	end

	return botKit
end

function BotSpawner:spawnBot(bot, trans, setKit)
	local botColor = Config.botColor
	local botKit = Config.botKit

	if setKit or Config.botNewLoadoutOnSpawn then
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

	bot:resetSpawnVars()

	-- create kit and appearance
	local soldierBlueprint = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier')
	local soldierCustomization = nil
	local soldierKit = nil
	local appearance = nil
	soldierKit, appearance, soldierCustomization = self:getKitApperanceCustomization(bot.player.teamId, botKit, botColor)

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