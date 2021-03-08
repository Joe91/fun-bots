class('BotManager');

require('Bot');

local Globals 	= require('Globals');
local Utilities = require('__shared/Utilities');

function BotManager:__init()
	self._bots = {}
	self._botInputs = {}
	self._shooterBots = {}
	self._activePlayers = {}
	self._botAttackBotTimer = 0;
	self._destroyBotsTimer = 0;
	self._botsToDestroy = {};
	self._initDone = false;

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	NetEvents:Subscribe('BotShootAtPlayer', self, self._onShootAt)
	NetEvents:Subscribe('BotShootAtBot', self, self._onBotShootAtBot)
	Events:Subscribe('ServerDamagePlayer', self, self._onServerDamagePlayer) 	--only triggered on false damage
	NetEvents:Subscribe('ClientDamagePlayer', self, self._onDamagePlayer)   	--only triggered on false damage
	Hooks:Install('Soldier:Damage', 100, self, self._onSoldierDamage)

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
		if self:getBotByName(players[i].name) == nil then
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
		local name = BotNames[i]
		local bot = self:getBotByName(name)
		if bot == nil then
			return name
		elseif bot.player.soldier == nil and bot:getSpawnMode() < 4 then
			return name
		end
	end
	return nil
end

function BotManager:getBots()
	return self._bots
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
end

function BotManager:_checkForBotBotAttack()
	local players = self:getPlayers()
	local botConnections = {}
	if #players > 0 and #self._bots > 0 then
		for _, bot in pairs(self._bots) do

			-- bot has player and hasn't found that special someone yet
			if (bot.player and not botConnections[bot.player.name]) then

				for _, bot2 in pairs(self._bots) do

					-- don't match self, and make sure it's living
					-- don't check if bot2 already has a target
					if (bot.player ~= bot2.player and bot.player.alive and bot2.player.alive) then

						local distance = bot.player.soldier.worldTransform.trans:Distance(bot2.player.soldier.worldTransform.trans)
						if distance <= Config.maxBotAttackBotDistance then

							-- choose a player at random, try until an active player is found
							for i = math.random(1, #players), #players do
								if self._activePlayers[players[i].name] then

									-- check this bot view. Let one client do it
									local pos1 = bot.player.soldier.worldTransform.trans:Clone()
									local pos2 = bot2.player.soldier.worldTransform.trans:Clone()

									NetEvents:SendUnreliableToLocal('CheckBotBotAttack', players[i], pos1, pos2, bot.player.name, bot2.player.name)
									botConnections[bot.player.name] = true
									botConnections[bot2.player.name] = true
									break
								end
							end
						end
					end
				end
			end
		end
	end
end

function BotManager:onPlayerLeft(player)
	--remove all references of player
	for _, bot in pairs(self._bots) do
		bot:clearPlayer(player)
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

function BotManager:_onBotShootAtBot(player, botname1, botname2)
	local bot1 = self:getBotByName(botname1)
	local bot2 = self:getBotByName(botname2)
	if bot1 == nil or bot1.player == nil or  bot2 == nil or bot2.player == nil then
		return
	end
	bot1:shootAt(bot2.player, false)
	bot2:shootAt(bot1.player, false)
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
	local returnBot = nil
	for _, bot in pairs(self._bots) do
		if bot.name == name then
			returnBot = bot
			break
		end
	end
	return returnBot
end

function BotManager:createBot(name, team, squad)
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
	botPlayer.input = botInput

	bot = Bot(botPlayer)

	table.insert(self._bots, bot)
	self._botInputs[botPlayer.id] = botInput
	bot.player.input.flags = EntryInputFlags.AuthoritativeAiming

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

function BotManager:killAll()
	for _, bot in pairs(self._bots) do
		bot:resetVars()
		if bot.player.alive then
			bot.player.soldier:Kill()
		end
	end
end

function BotManager:destroyAmount(number)
	local count = 0
	for i = 1, MAX_NUMBER_OF_BOTS do
		local index = MAX_NUMBER_OF_BOTS + 1 - i
		local bot = self:getBotByName(BotNames[index])
		if bot ~= nil then
			table.insert(self._botsToDestroy, bot.name)
			count = count + 1
		end
		if count >= number then
			return
		end
	end
end

function BotManager:killAmount(number)
	local count = 0
	-- TODO: try to kill dead bots first
	for _, bot in pairs(self._bots) do
		bot:resetVars()
		if bot.player.alive then
			bot.player.soldier:Kill()
		end
		count = count + 1
		if count >= number then
			return
		end
	end
end

function BotManager:destroyTeam(teamId, amount)
	for i = 1, MAX_NUMBER_OF_BOTS do
		local index = MAX_NUMBER_OF_BOTS + 1 - i
		local bot = self:getBotByName(BotNames[index])
		if bot ~= nil then
			if bot.player.teamId == teamId then
				table.insert(self._botsToDestroy, bot.name)
				if amount ~= nil then
					amount = amount - 1;
					if amount <= 0 then
						return
					end
				end
			end
		end
	end
end

function BotManager:killTeam(teamId, amount)
	-- TODO: try to kill dead bots first
	for _, bot in pairs(self._bots) do
		if bot.player.teamId == teamId then
			bot:resetVars()
			if bot.player.alive then
				bot.player.soldier:Kill()
			end
			if amount ~= nil then
				amount = amount - 1;
				if amount <= 0 then
					return
				end
			end
		end
	end
end

function BotManager:destroyDisabledBots()
	local numberOfBots = #self._bots
	for i = 1,  numberOfBots do
		local index = numberOfBots + 1 - i
		local bot = self._bots[index]
		if bot ~= nil then
			if bot:isInactive() then
				table.insert(self._botsToDestroy, bot.name)
			end
		end
	end
end

function BotManager:destroyPlayerBots(player)
	for i = 1, MAX_NUMBER_OF_BOTS do
		local bot = self:getBotByName(BotNames[i])
		if bot ~= nil then
			if bot:getTargetPlayer() == player then
				table.insert(self._botsToDestroy, bot.name)
			end
		end
	end
end

function BotManager:destroyBot(botName)
	-- Find index of this bot.
	local idx = nil

	for i, bot in pairs(self._bots) do
		if botName == bot.name then
			idx = i
			break
		end
	end

	-- Bot was not found.
	if idx == nil then
		return
	end

	local bot = self:getBotByName(botName)
	local botId = bot.id
	bot:resetVars()
	bot:destroy()
	self._botInputs[botId] = nil
	table.remove(self._bots, idx)
end

function BotManager:destroyAllBots(forced)
	if forced then
		for _, bot in pairs(self._bots) do
			bot:resetVars()
			bot:destroy()
		end
		self._bots = {}
		self._botInputs = {}
	else
		for _, bot in pairs(self._bots) do
			table.insert(self._botsToDestroy, bot.name)
		end
	end
end


-- Singleton.
if g_BotManager == nil then
	g_BotManager = BotManager()
end

return g_BotManager