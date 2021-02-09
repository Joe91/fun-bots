class('BotManager');

require('Bot');

local Globals 	= require('Globals');
local Utilities = require('__shared/Utilities')

function BotManager:__init()
	self._bots = {}
	self._botInputs = {}
	self._shooterBots = {}

	self._lastYaw = 0.0

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	NetEvents:Subscribe('BotShootAtPlayer', self, self._onShootAt)
	Hooks:Install('Soldier:Damage', 100, self, self._onSoldierDamage)
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
		if  Config.spawnInSameTeam then
			botTeam = TeamId.Team1;
		else
			botTeam = TeamId.Team2;
		end
	elseif countPlayersTeam2 > countPlayersTeam1 then
		if Config.spawnInSameTeam then
			botTeam = TeamId.Team2;
		else
			botTeam = TeamId.Team1;
		end
	else
		botTeam = Config.botTeam;
	end

	return botTeam;
end

function BotManager:configGlobas()
	Globals.respawnWayBots 	= Config.respawnWayBots;
	Globals.attackWayBots 	= Config.attackWayBots;
	Globals.yawPerFrame 	= self:calcYawPerFrame()
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
end

function BotManager:onPlayerLeft(player)
	--remove all references of player
	for _, bot in pairs(self._bots) do
		bot:clearPlayer(player)
	end
end

function BotManager:_getDamageValue(damage, bot, fake)
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

	if not fake then
		return damage * damageFactor;
	else -- fake melee damage?
		if damage == 1 then
			return bot.knife.damage * Config.damageFactorKnife;
		end
	end
end

function BotManager:_onSoldierDamage(hook, soldier, info, giverInfo)
	-- soldier -> soldier damage only
	if soldier.player == nil or giverInfo.giver == nil then
		return
	end

	local soldierIsBot = Utilities:isBot(soldier.player.name);
	if soldierIsBot then
		--detect if we need to shoot back
		if Config.shootBackIfHit and info.damage > 0 then
			self:_onShootAt(giverInfo.giver, soldier.player.name, true)
		end

		-- prevent bots from killing themselves. Bad bot, no suicide.
		if not Config.botCanKillHimself and soldier.player == giverInfo.giver then
			info.damage = 0;
		end
	end

	if not soldierIsBot then
		--valid bot-damage?
		local bot = self:GetBotByName(giverInfo.giver.name)
		if bot ~= nil and bot.player.soldier ~= nil then
			-- giver was a bot (with explosives)
			info.damage = self:_getDamageValue(info.damage, bot, false);
		end
	end

	hook:Pass(soldier, info, giverInfo)
end

function BotManager:_onShootAt(player, botname, ignoreYaw)
	local bot = self:GetBotByName(botname)
	if bot == nil or bot.player == nil or bot.player.soldier == nil or player == nil then
		return
	end
	bot:shootAt(player, ignoreYaw)
end

function BotManager:_onLevelDestroy()
	print("destroyLevel")
	self:killAll()
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

function BotManager:destroyTeam(teamId)
	for i = 1, MAX_NUMBER_OF_BOTS do
		local bot = self:GetBotByName(BotNames[i])
		if bot ~= nil then
			if bot.player.teamId == teamId then
				self:destroyBot(bot.name)
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