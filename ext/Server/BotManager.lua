class('BotManager');

require('Bot');

local Globals 	= require('Globals');
local Utilities = require('__shared/Utilities');

function BotManager:__init()
	self._bots = {}
	self._botsByName = {}
	self._botsByTeam = {{}, {}, {}, {}, {}} -- neutral, team1, team2, team3, team4
	self._botInputs = {}
	self._shooterBots = {}
	self._activePlayers = {}
	self._botAttackBotTimer = 0;
	self._destroyBotsTimer = 0;
	self._botsToDestroy = {};
	self._botCheckState = {};
	self._pendingAcceptRevives = {};
	self._lastBotCheckIndex = 1
	self._initDone = false;

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	NetEvents:Subscribe('BotShootAtPlayer', self, self._onShootAt)
	NetEvents:Subscribe('BotRevivePlayer', self, self._onRevivePlayer)
	NetEvents:Subscribe('BotShootAtBot', self, self._onBotShootAtBot)
	Events:Subscribe('ServerDamagePlayer', self, self._onServerDamagePlayer) 	--only triggered on false damage
	NetEvents:Subscribe('ClientDamagePlayer', self, self._onDamagePlayer)   	--only triggered on false damage
	Hooks:Install('Soldier:Damage', 100, self, self._onSoldierDamage)
	--Events:Subscribe('Soldier:HealthAction', self, self._onHealthAction)	-- use this for more options on revive. Not needed yet
	--Events:Subscribe('GunSway:Update', self, self._onGunSway)
	--Events:Subscribe('GunSway:UpdateRecoil', self, self._onGunSway)
	--Events:Subscribe('Player:Destroyed', self, self._onPlayerDestroyed) -- Player left is called first, so use this one instead
	Events:Subscribe('Player:Left', self, self._onPlayerLeft);
	--Events:Subscribe('Engine:Message', self, self._onEngineMessage); -- maybe us this later
end

function BotManager:registerActivePlayer(player)
	self._activePlayers[player.name] = true;
end

function BotManager:getBotTeam()
	if Config.botTeam ~= TeamId.TeamNeutral then
		return Config.botTeam;
	end
	local botTeam;
	local countPlayersTeam1 = 0;
	local countPlayersTeam2 = 0;
	local players = PlayerManager:GetPlayers()
	for i = 1, PlayerManager:GetPlayerCount() do
		if Utilities:isBot(players[i]) == false then
			if players[i].teamId == TeamId.Team1 then
				countPlayersTeam1 = countPlayersTeam1 + 1;
			else
				countPlayersTeam2 = countPlayersTeam2 + 1;
			end
		end
	end

	-- init global Vars
	if countPlayersTeam2 > countPlayersTeam1 then
		botTeam = TeamId.Team1;
	else -- if countPlayersTeam1 > countPlayersTeam2 then  --default case
		botTeam = TeamId.Team2;
	end

	return botTeam;
end

function BotManager:configGlobals()
	Globals.respawnWayBots 	= Config.respawnWayBots;
	Globals.attackWayBots 	= Config.attackWayBots;
	Globals.spawnMode		= Config.spawnMode;
	Globals.yawPerFrame 	= self:calcYawPerFrame()
	--self:killAll();
	local maxPlayers = RCON:SendCommand('vars.maxPlayers');
	maxPlayers = tonumber(maxPlayers[2]);
	if maxPlayers ~= nil and maxPlayers > 0 then
		Globals.maxPlayers = maxPlayers;
		
		if Debug.Server.BOT then
			print("there are "..maxPlayers.." slots on this server")
		end
	else
		Globals.maxPlayers = MAX_NUMBER_OF_BOTS; --only fallback
	end
	self._initDone = true;
end

function BotManager:calcYawPerFrame()
	local dt = 1.0/SharedUtils:GetTickrate();
	local degreePerDt = Config.maximunYawPerSec * dt;
	return (degreePerDt / 360.0) * 2 * math.pi
end

function BotManager:findNextBotName()
	for i = 1, MAX_NUMBER_OF_BOTS do
		local name = BOT_TOKEN..BotNames[i]
		local skipName = false;
		for _,ignoreName in pairs(g_Globals.ignoreBotNames) do
			if name == ignoreName then
				skipName = true;
				break;
			end
		end
		if not skipName then
			local bot = self:getBotByName(name)
			if bot == nil and PlayerManager:GetPlayerByName(name) == nil then
				return name
			elseif bot ~= nil and bot.player.soldier == nil and bot:getSpawnMode() < 4 then
				return name
			end
		end
	end
	return nil
end

function BotManager:getBots(teamId)
	if (teamId ~= nil) then
		return self._botInfo.team[teamId+1]
	else
		return self._bots
	end
end

function BotManager:getBotCount()
	return #self._bots;
end

function BotManager:getActiveBotCount(teamId)
	local count = 0;
	for _, bot in pairs(self._bots) do
		if not bot:isInactive() then
			if teamId == nil or bot.player.teamId == teamId then
				count = count + 1
			end
		end
	end
	return count
end

function BotManager:getPlayers()
	local allPlayers = PlayerManager:GetPlayers()
	local players = {}

	for i=1, #allPlayers do
		if not Utilities:isBot(allPlayers[i]) then
			table.insert(players, allPlayers[i])
		end
	end
	return players
end

function BotManager:getPlayerCount()
	return PlayerManager:GetPlayerCount() - #self._bots;
end

function BotManager:getKitCount(kit)
	local count = 0;
	for _, bot in pairs(self._bots) do
		if bot.kit == kit then
			count = count + 1;
		end
	end
	return count;
end

function BotManager:resetAllBots()
	for _, bot in pairs(self._bots) do
		bot:resetVars()
	end
end

function BotManager:setStaticOption(player, option, value)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == player then
			if bot:isStaticMovement() then
				if option == "mode" then
					bot:setMoveMode(value)
				elseif option == "speed" then
					bot:setSpeed(value)
				end
			end
		end
	end
end

function BotManager:setOptionForAll(option, value)
	for _, bot in pairs(self._bots) do
		if option == "shoot" then
			bot:setShoot(value)
		elseif option == "respawn" then
			bot:setRespawn(value)
		elseif option == "moveMode" then
			bot:setMoveMode(value)
		end
	end
end

function BotManager:setOptionForPlayer(player, option, value)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == player then
			if option == "shoot" then
				bot:setShoot(value)
			elseif option == "respawn" then
				bot:setRespawn(value)
			elseif option == "moveMode" then
				bot:setMoveMode(value)
			end
		end
	end
end

function BotManager:_onUpdate(dt, pass)
	if pass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	for _, bot in pairs(self._bots) do
		bot:onUpdate(dt)
	end

	if Config.botsAttackBots and self._initDone then
		if self._botAttackBotTimer >= StaticConfig.botAttackBotCheckInterval then
			self._botAttackBotTimer = 0;
			self:_checkForBotBotAttack()
		end
		self._botAttackBotTimer = self._botAttackBotTimer + dt;
	end

	if #self._botsToDestroy > 0 then
		if self._destroyBotsTimer >= 0.05 then
			self._destroyBotsTimer = 0;
			self:destroyBot(table.remove(self._botsToDestroy))
		end
		self._destroyBotsTimer = self._destroyBotsTimer + dt;
	end

	-- accept revives
	for i, botname in pairs(self._pendingAcceptRevives) do
        local botPlayer = self:getBotByName(botname)
        if botPlayer ~= nil and botPlayer.player.soldier ~= nil then
            if botPlayer.player.soldier.health == 20 then
                botPlayer.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
                self._pendingAcceptRevives[i] = nil
            end
        else
			self._pendingAcceptRevives[i] = nil
        end
    end
end

function BotManager:_onHealthAction(soldier, action)
	if action == HealthStateAction.OnRevive then --7
		if soldier.player ~= nil then
			if Utilities:isBot(soldier.player.name) then
				table.insert(self._pendingAcceptRevives, soldier.player.name)
			end
		end
    end
end

function BotManager:_onGunSway(gunSway, weapon, weaponFiring, deltaTime)
    if weapon == nil then
        return
    end
	local soldier = nil
	for _,entity in pairs(weapon.bus.parent.entities) do
		if entity:Is('ServerSoldierEntity') then
			soldier = SoldierEntity(entity)
			break
		end
	end
    if soldier == nil or soldier.player == nil then
		return
	end
	local bot = self:getBotByName(soldier.player.name)
	if bot ~= nil then
		local gunSwayData = GunSwayData(gunSway.data)
		if soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
			gunSway.dispersionAngle = gunSwayData.stand.zoom.baseValue.minAngle
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			gunSway.dispersionAngle = gunSwayData.crouch.zoom.baseValue.minAngle
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			gunSway.dispersionAngle = gunSwayData.prone.zoom.baseValue.minAngle
		else
			return
		end
	end
end

function BotManager:_checkForBotBotAttack()

	-- not enough on either team and no players to use
	if (#self._botsByTeam[2] < 1 or #self._botsByTeam[3] < 1) then
		return
	end

	local players = self:getPlayers()
	local playerCount = #players

	if (playerCount < 1) then
		return
	end

	local raycasts = 0
	local nextPlayerIndex = 1

	for i=self._lastBotCheckIndex, #self._bots do

		local bot = self._bots[i]

		-- bot has player, is alive, and hasn't found that special someone yet
		if (bot ~= nil and bot.player and bot.player.alive and not self._botCheckState[bot.player.name]) then

			local opposingTeams = {}
			for t = 1, g_Globals.nrOfTeams do
				if bot.player.teamId ~= t then
					table.insert(opposingTeams, t);
				end
			end
			for _,opposingTeam in pairs(opposingTeams) do
				-- search only opposing team
				for _, bot2 in pairs(self._botsByTeam[opposingTeam]) do

					-- make sure it's living and has no target
					if (bot2 ~= nil and bot2.player ~= nil and bot2.player.alive and not self._botCheckState[bot2.player.name]) then

						local distance = bot.player.soldier.worldTransform.trans:Distance(bot2.player.soldier.worldTransform.trans)
						if distance <= Config.maxBotAttackBotDistance then

							-- choose a player at random, try until an active player is found
							for playerIndex = nextPlayerIndex, playerCount do
								if self._activePlayers[players[playerIndex].name] then

									-- check this bot view. Let one client do it
									local pos1 = bot.player.soldier.worldTransform.trans:Clone()
									local pos2 = bot2.player.soldier.worldTransform.trans:Clone()
									local inVehicle =  (bot.player.attachedControllable ~= nil or bot2.player.attachedControllable ~= nil)

									NetEvents:SendUnreliableToLocal('CheckBotBotAttack', players[playerIndex], pos1, pos2, bot.player.name, bot2.player.name, inVehicle)
									raycasts = raycasts + 1
									nextPlayerIndex = playerIndex + 1;
									break
								end
							end

							if (raycasts >= playerCount) then
								-- leave the function early for this cycle
								self._lastBotCheckIndex = i+1
								return
							end
						end
					end
				end
			end
		end
		self._lastBotCheckIndex = i
	end
	-- should only reach here if every connection has been checked
	-- clear the cache and start over
	self._lastBotCheckIndex = 1
	self._botCheckState = {}
end

function BotManager:_onPlayerLeft(player)
	--remove all references of player
	if player ~= nil then
		for _, bot in pairs(self._bots) do
			bot:clearPlayer(player)
		end
	end
end

function BotManager:_getDamageValue(damage, bot, soldier, fake)
	local resultDamage = 0;
	local damageFactor = 1.0;

	if bot.activeWeapon.type == "Shotgun" then
		damageFactor = Config.damageFactorShotgun;
	elseif bot.activeWeapon.type == "Assault" then
		damageFactor = Config.damageFactorAssault;
	elseif bot.activeWeapon.type == "Carabine" then
		damageFactor = Config.damageFactorCarabine;
	elseif bot.activeWeapon.type == "PDW" then
		damageFactor = Config.damageFactorPDW;
	elseif bot.activeWeapon.type == "LMG" then
		damageFactor = Config.damageFactorLMG;
	elseif bot.activeWeapon.type == "Sniper" then
		damageFactor = Config.damageFactorSniper;
	elseif bot.activeWeapon.type == "Pistol" then
		damageFactor = Config.damageFactorPistol;
	elseif bot.activeWeapon.type == "Knife" then
		damageFactor = Config.damageFactorKnife;
	end

	if not fake then -- frag mode
		resultDamage = damage * damageFactor;
	else
		if damage <= 2 then
			local distance = bot.player.soldier.worldTransform.trans:Distance(soldier.worldTransform.trans)
			if distance >= bot.activeWeapon.damageFalloffEndDistance then
				resultDamage = bot.activeWeapon.endDamage;
			elseif distance <= bot.activeWeapon.damageFalloffStartDistance then
				resultDamage =  bot.activeWeapon.damage;
			else --extrapolate damage
				local relativePosion = (distance-bot.activeWeapon.damageFalloffStartDistance)/(bot.activeWeapon.damageFalloffEndDistance - bot.activeWeapon.damageFalloffStartDistance)
				resultDamage = bot.activeWeapon.damage - (relativePosion * (bot.activeWeapon.damage-bot.activeWeapon.endDamage));
			end
			if damage == 2 then
				resultDamage = resultDamage * Config.headShotFactorBots;
			end

			resultDamage = resultDamage * damageFactor;
		elseif damage == 3 then --melee
			resultDamage = bot.knife.damage * Config.damageFactorKnife;
		end
	end
	return resultDamage;
end

function BotManager:_onSoldierDamage(hook, soldier, info, giverInfo)
	-- soldier -> soldier damage only
	if soldier.player == nil then
		return
	end

	local soldierIsBot = Utilities:isBot(soldier.player);
	if soldierIsBot and giverInfo.giver ~= nil then
		--detect if we need to shoot back
		if Config.shootBackIfHit and info.damage > 0 then
			self:_onShootAt(giverInfo.giver, soldier.player.name, true)
		end

		-- prevent bots from killing themselves. Bad bot, no suicide.
		if not Config.botCanKillHimself and soldier.player == giverInfo.giver then
			info.damage = 0;
		end
	end

	--find out, if a player was hit by the server:
	if not soldierIsBot then
		if giverInfo.giver == nil then
			local bot = self:getBotByName(self._shooterBots[soldier.player.name])
			if bot ~= nil and bot.player.soldier ~= nil and info.damage > 0 then
				info.damage = self:_getDamageValue(info.damage, bot, soldier, true);
				info.boneIndex = 0;
				info.isBulletDamage = true;
				info.position = Vec3(soldier.worldTransform.trans.x, soldier.worldTransform.trans.y + 1, soldier.worldTransform.trans.z)
				info.direction = soldier.worldTransform.trans - bot.player.soldier.worldTransform.trans
				info.origin = bot.player.soldier.worldTransform.trans
				if (soldier.health - info.damage) <= 0 then
					if Globals.isTdm then
						local enemyTeam = TeamId.Team1;
						if soldier.player.teamId == TeamId.Team1 then
							enemyTeam = TeamId.Team2;
						end
						TicketManager:SetTicketCount(enemyTeam, (TicketManager:GetTicketCount(enemyTeam) + 1));
					end
				end
			end
		else
			--valid bot-damage?
			local bot = self:getBotByName(giverInfo.giver.name)
			if bot ~= nil and bot.player.soldier ~= nil then
				-- giver was a bot
				info.damage = self:_getDamageValue(info.damage, bot, soldier, false);
			end
		end
	end
	hook:Pass(soldier, info, giverInfo)
end

function BotManager:_onServerDamagePlayer(playerName, shooterName, meleeAttack)
	local player = PlayerManager:GetPlayerByName(playerName)
	if player ~= nil then
		self:_onDamagePlayer(player, shooterName, meleeAttack, false)
	end
end

function BotManager:_onDamagePlayer(player, shooterName, meleeAttack, isHeadShot)
	local bot = self:getBotByName(shooterName)
	if not player.alive or bot == nil then
		return
	end
	if player.teamId == bot.player.teamId then
		return
	end
	local damage = 1 --only trigger soldier-damage with this
	if isHeadShot then
		damage = 2	-- singal Headshot
	elseif meleeAttack then
		damage = 3 --signal melee damage with this value
	end
	--save potential killer bot
	self._shooterBots[player.name] = shooterName

	if player.soldier ~= nil then
		player.soldier.health = player.soldier.health - damage
	end
end

function BotManager:_onShootAt(player, botname, ignoreYaw)
	local bot = self:getBotByName(botname)
	if bot == nil or bot.player == nil or bot.player.soldier == nil or player == nil then
		return
	end
	bot:shootAt(player, ignoreYaw)
end

function BotManager:_onRevivePlayer(player, botname)
	local bot = self:getBotByName(botname)
	if bot == nil or bot.player == nil or bot.player.soldier == nil or player == nil then
		return
	end
	bot:revive(player)
end

function BotManager:_onBotShootAtBot(player, botname1, botname2)
	local bot1 = self:getBotByName(botname1)
	local bot2 = self:getBotByName(botname2)
	if bot1 == nil or bot1.player == nil or  bot2 == nil or bot2.player == nil then
		return
	end
	if bot1:shootAt(bot2.player, false) or bot2:shootAt(bot1.player, false) then
		self._botCheckState[bot1.player.name] = bot2.player.name
		self._botCheckState[bot2.player.name] = bot1.player.name
	else
		self._botCheckState[bot1.player.name] = nil
		self._botCheckState[bot2.player.name] = nil
	end
end

function BotManager:_onLevelDestroy()
	if Debug.Server.INFO then
		print("destroyLevel")
	end
	
	self:resetAllBots();
	self._activePlayers = {};
	self._initDone = false;
	--self:killAll() -- this crashes when the server ended. do it on levelstart instead
end

function BotManager:getBotByName(name)
	return self._botsByName[name]
end

function BotManager:createBot(name, team, squad)

	--print('botsByTeam['..#self._botsByTeam[2]..'|'..#self._botsByTeam[3]..']')

	local bot = self:getBotByName(name)
	if bot ~= nil then
		bot.player.teamId = team
		bot.player.squadId = squad
		bot:resetVars()
		return bot
	end

	-- check for max-players
	local playerlimt = Globals.maxPlayers
	if Config.keepOneSlotForPlayers then
		playerlimt = playerlimt - 1;
	end
	if playerlimt <=  PlayerManager:GetPlayerCount() then
		if Debug.Server.BOT then
			print("playerlimit reached")
		end
		return
	end

	-- Create a player for this bot.
	local botPlayer = PlayerManager:CreatePlayer(name, team, squad)
	if botPlayer == nil then
		if Debug.Server.BOT then
			print("cant create more players on this team")
		end
		return
	end

	-- Create input for this bot.
	local botInput = EntryInput()
	botInput.deltaTime = 1.0 / SharedUtils:GetTickrate()
	botInput.flags = EntryInputFlags.AuthoritativeAiming
	botPlayer.input = botInput

	bot = Bot(botPlayer)

	local teamLookup = bot.player.teamId+1
	table.insert(self._bots, bot)
	self._botsByTeam[teamLookup] = self._botsByTeam[teamLookup] or {}
	table.insert(self._botsByTeam[teamLookup], bot)
	self._botsByName[name] = bot
	self._botInputs[botPlayer.id] = botInput -- bot inputs are stored to prevent garbage collection
	return bot
end


function BotManager:spawnBot(bot, transform, pose, soldierBp, kit, unlocks)
	if bot.player.soldier ~= nil then
		bot.player.soldier:Kill()
	end

	bot.player:SelectUnlockAssets(kit, unlocks)
	local botSoldier = bot.player:CreateSoldier(soldierBp, transform)
	bot.player:SpawnSoldierAt(botSoldier, transform, pose)
	bot.player:AttachSoldier(botSoldier)

	return botSoldier
end

function BotManager:killPlayerBots(player)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == player then
			bot:resetVars()
			if bot.player.alive then
				bot.player.soldier:Kill()
			end
		end
	end
end

function BotManager:resetAllBots()
	for _, bot in pairs(self._bots) do
		bot:resetVars()
	end
end

function BotManager:killAll(amount, teamId)

	local botTable = self._bots
	if (teamId ~= nil) then
		botTable = self._botsByTeam[teamId+1]
	end

	amount = amount or #botTable

	for _, bot in pairs(botTable) do

		bot:kill()
		
		amount = amount - 1;
		if amount <= 0 then
			return
		end
	end
end

function BotManager:destroyAll(amount, teamId, force)

	local botTable = self._bots
	if (teamId ~= nil) then
		botTable = self._botsByTeam[teamId+1]
	end

	amount = amount or #botTable

	for _, bot in pairs(botTable) do

		if (force) then
			self:destroyBot(bot)
		else
			table.insert(self._botsToDestroy, bot.name)
		end
		
		amount = amount - 1;
		if amount <= 0 then
			return
		end
	end
end

function BotManager:destroyDisabledBots()
	for _, bot in pairs(self._bots) do
		if bot:isInactive() then
			table.insert(self._botsToDestroy, bot.name)
		end
	end
end

function BotManager:destroyPlayerBots(player)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == player then
			table.insert(self._botsToDestroy, bot.name)
		end
	end
end

function BotManager:freshnTables()
	local newTeamsTable = {{},{},{},{},{}}
	local newBotTable = {}
	local newBotbyNameTable = {}

	for _,bot in pairs(self._bots) do
		if bot.player ~= nil then
			table.insert(newBotTable, bot);
			table.insert(newTeamsTable[bot.player.teamId + 1], bot)
			newBotbyNameTable[bot.player.name] = bot;
		end
	end

	self._bots = newBotTable;
	self._botsByTeam = newTeamsTable;
	self._botsByName = newBotbyNameTable;
end

function BotManager:destroyBot(bot)

	if (type(bot) == 'string') then
		bot = self._botsByName[bot]
	end

	-- Bot was not found.
	if bot == nil then
		return
	end

	-- Find index of this bot.
	local newTable = {}
	for i, checkBot in pairs(self._bots) do
		if bot.name ~= checkBot.name then
			table.insert(newTable, checkBot)
		end
		checkBot:clearPlayer(bot.player)
	end
	self._bots = newTable


	local newTeamsTable = {}
	for i, checkBot in pairs(self._botsByTeam[bot.player.teamId+1]) do
		if bot.name ~= checkBot.name then
			table.insert(newTeamsTable, checkBot)
		end
	end
	self._botsByTeam[bot.player.teamId+1] = newTeamsTable
	self._botsByName[bot.name] = nil
	self._botInputs[bot.id] = nil

	bot:destroy()
	bot = nil
end

-- Singleton.
if g_BotManager == nil then
	g_BotManager = BotManager()
end

return g_BotManager