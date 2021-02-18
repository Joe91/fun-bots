class('BotManager');

require('Bot');

local Globals 	= require('Globals');
local Utilities = require('__shared/Utilities');
local damageHook = nil;

function BotManager:__init()
	self._bots = {}
	self._botInputs = {}
	self._shooterBots = {}
	self._botToBotConnections = {}
	self._botAttackBotTimer = 0;

	self._damageHookInstalled = false;
	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	NetEvents:Subscribe('BotShootAtPlayer', self, self._onShootAt)
	NetEvents:Subscribe('BotShootAtBot', self, self._onBotShootAtBot)
	Events:Subscribe('ServerDamagePlayer', self, self._onServerDamagePlayer) 	--only triggered on false damage
	NetEvents:Subscribe('ClientDamagePlayer', self, self._onDamagePlayer)   	--only triggered on false damage
end

function BotManager:getBotTeam()
	local botTeam;
	local countPlayersTeam1 = 0;
	local countPlayersTeam2 = 0;
	local players = PlayerManager:GetPlayers()
	for i = 1, PlayerManager:GetPlayerCount() do
		if self:GetBotByName(players[i].name) == nil then
			if players[i].teamId == TeamId.Team1 then
				countPlayersTeam1 = countPlayersTeam1 + 1;
			else
				countPlayersTeam2 = countPlayersTeam2 + 1;
			end
		end
	end

	-- init global Vars
	if countPlayersTeam1 > countPlayersTeam2 then
		botTeam = TeamId.Team2;
	elseif countPlayersTeam2 > countPlayersTeam1 then
		botTeam = TeamId.Team1;
	else
		botTeam = Config.botTeam;
	end

	return botTeam;
end

function BotManager:configGlobas()
	Globals.respawnWayBots 	= Config.respawnWayBots;
	Globals.attackWayBots 	= Config.attackWayBots;
	Globals.spawnMode		= Config.spawnMode;
	Globals.yawPerFrame 	= self:calcYawPerFrame()
	if not self._damageHookInstalled then
		damageHook = Hooks:Install('Soldier:Damage', 100, self, self._onSoldierDamage)
		self._damageHookInstalled = true;
	end
	self:killAll();
	local maxPlayers = RCON:SendCommand('vars.maxPlayers');
	maxPlayers = tonumber(maxPlayers[2]);
	if maxPlayers ~= nil and maxPlayers > 0 then
		Globals.maxPlayers = maxPlayers;
		print("there are "..maxPlayers.." slots on this server")
	else
		Globals.maxPlayers = MAX_NUMBER_OF_BOTS; --only fallback
	end
end

function BotManager:calcYawPerFrame()
	local dt = 1.0/SharedUtils:GetTickrate();
	local degreePerDt = Config.maximunYawPerSec * dt;
	return (degreePerDt / 360.0) * 2 * math.pi
end

function BotManager:findNextBotName()
	for i = 1, MAX_NUMBER_OF_BOTS do
		local name = BotNames[i]
		local bot = self:GetBotByName(name)
		if bot == nil then
			return name
		elseif bot.player.soldier == nil and bot:getSpawnMode() < 4 then
			return name
		end
	end
	return nil
end

function BotManager:getBotCount()
	return #self._bots;
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

	if Config.botsAttackBots then
		if self._botAttackBotTimer >= StaticConfig.botAttackBotCheckInterval then
			self._botAttackBotTimer = 0;
			self:_checkForBotBotAttack()
		end
		self._botAttackBotTimer = self._botAttackBotTimer + dt;
	end
end

function BotManager:_checkForBotBotAttack()
	local players = PlayerManager:GetPlayers()
	local playerCount = self:getPlayerCount();
	local playerIndex = 1;
	local playersUsed = 0;
	if playerCount > 0 then
		for _, bot in pairs(self._bots) do
			for _, bot2 in pairs(self._bots) do
				if bot.player ~= bot2.player then
					if bot.player.TeamId ~= bot2.player.teamId then
						if bot.player.alive and bot2.player.alive then
							if self._botToBotConnections[bot.player.name..bot2.player.name] == nil and self._botToBotConnections[bot2.player.name..bot.player.name] == nil then
								if bot.player.soldier.worldTransform.trans:Distance(bot2.player.soldier.worldTransform.trans) <= Config.maxBotAttackBotDistance then
									for i = playerIndex, playerCount do
										if self:GetBotByName(players[i].name) == nil then
											-- check this bot view. Let one client do it
											NetEvents:SendToLocal('CheckBotBotAttack', players[i], bot.player.soldier.worldTransform.trans, bot2.player.soldier.worldTransform.trans, bot.player.name, bot2.player.name)
											self._botToBotConnections[bot.player.name..bot2.player.name] = true;
											playerIndex = i + 1;
											break
										end
									end
									playersUsed = playersUsed + 1;
									if playersUsed >= playerCount then
										return
									end
								end
							end
						end
					end
				end
			end
		end
	end
	--clear connections, if all are checked
	self._botToBotConnections = {}
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
	elseif bot.activeWeapon.type ~= "Shotgun" then
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

	local soldierIsBot = Utilities:isBot(soldier.player.name);
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
			local bot = self:GetBotByName(self._shooterBots[soldier.player.name])
			if bot ~= nil and bot.player.soldier ~= nil then
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
			local bot = self:GetBotByName(giverInfo.giver.name)
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
	local bot = self:GetBotByName(shooterName)
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
	local bot = self:GetBotByName(botname)
	if bot == nil or bot.player == nil or bot.player.soldier == nil or player == nil then
		return
	end
	bot:shootAt(player, ignoreYaw)
end

function BotManager:_onBotShootAtBot(player, botname1, botname2)
	local bot1 = self:GetBotByName(botname1)
	local bot2 = self:GetBotByName(botname2)
	if bot1 == nil or bot1.player == nil or  bot2 == nil or bot2.player == nil then
		return
	end
	bot1:shootAt(bot2.player, false)
	bot2:shootAt(bot1.player, false)
end


function BotManager:_onLevelDestroy()
	print("destroyLevel")
	if damageHook ~= nil then
		damageHook:Uninstall();
	end
	self._damageHookInstalled = false;
	--self:killAll() -- this crashes when the server ended. do it on levelstart instead
end

function BotManager:GetBotByName(name)
	local returnBot = nil
	for _, bot in pairs(self._bots) do
		if bot.name == name then
			returnBot = bot
			break
		end
	end
	return returnBot
end

function BotManager:createBot(name, team)
	local bot = self:GetBotByName(name)
	if bot ~= nil then
		bot.player.teamId = team
		bot:resetVars()
		return bot
	end

	-- check for max-players
	local playerlimt = Globals.maxPlayers
	if Config.keepOneSlotForPlayers then
		playerlimt = playerlimt - 1;
	end
	if playerlimt <=  PlayerManager:GetPlayerCount() then
		print("playerlimit reached")
		return
	end

	-- Create a player for this bot.
	local botPlayer = PlayerManager:CreatePlayer(name, team, SquadId.SquadNone)
	if botPlayer == nil then
		print("cant create more players on this team")
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
		local bot = self:GetBotByName(BotNames[index])
		if bot ~= nil then
			self:destroyBot(bot.name)
			count = count + 1
		end
		if count >= number then
			return
		end
	end
end

function BotManager:destroyTeam(teamId, amount)
	for i = 1, MAX_NUMBER_OF_BOTS do
		local index = MAX_NUMBER_OF_BOTS + 1 - i
		local bot = self:GetBotByName(BotNames[index])
		if bot ~= nil then
			if bot.player.teamId == teamId then
				self:destroyBot(bot.name)
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

function BotManager:destroyPlayerBots(player)
	for i = 1, MAX_NUMBER_OF_BOTS do
		local bot = self:GetBotByName(BotNames[i])
		if bot ~= nil then
			if bot:getTargetPlayer() == player then
				self:destroyBot(bot.name)
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

	local bot = self:GetBotByName(botName)
	local botId = bot.id
	bot:destroy()
	self._botInputs[botId] = nil
	table.remove(self._bots, idx)
end

function BotManager:destroyAllBots()
	for _, bot in pairs(self._bots) do
		bot:destroy()
	end
	self._bots = {}
	self._botInputs = {}
end


-- Singleton.
if g_BotManager == nil then
	g_BotManager = BotManager()
end

return g_BotManager