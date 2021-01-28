class('BotManager');

require('Bot');

local Globals = require('Globals');

function BotManager:__init()
	self._bots = {}
	self._botInputs = {}
	self._shooterBots = {}

	self._lastYaw = 0.0

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	NetEvents:Subscribe('BotShootAtPlayer', self, self._onShootAt)
	Events:Subscribe('ServerDamagePlayer', self, self._onServerDamagePlayer)
	NetEvents:Subscribe('ClientDamagePlayer', self, self._onDamagePlayer)
	Hooks:Install('Soldier:Damage', 1, self, self._onSoldierDamage)
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
		elseif bot.player.soldier == nil then
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

function BotManager:_onSoldierDamage(hook, soldier, info, giverInfo)
	--detect if we need to shoot back
	if Config.shootBackIfHit then
		if giverInfo.giver ~= nil and soldier.player ~= nil then
			local bot = self:GetBotByName(soldier.player.name)
			if soldier ~= nil and bot ~= nil then
				self:_onShootAt(giverInfo.giver, bot.name, true)
			end
		end
	end

	--find out, if a player was hit by the server:
	if soldier.player ~= nil then
		local bot = self:GetBotByName(soldier.player.name)
		if bot == nil then
			if giverInfo.giver == nil then
				local newGiverInfo = DamageGiverInfo()
				bot = self:GetBotByName(self._shooterBots[soldier.player.name])
				if bot ~= nil and bot.player.soldier ~= nil then
					newGiverInfo.giver = bot.player;
					--newGiverInfo.weaponUnlock = nil;
					--newGiverInfo.weaponFiring = nil;
					if info.damage > 0.09 and info.damage < 0.11 then
						info.isBulletDamage = true
						if bot.kit == "Recon" and Config.botWeapon ~= "Pistol" then
							info.damage = Config.bulletDamageBotSniper
						else
							info.damage = Config.bulletDamageBot
						end
					elseif info.damage > 0.19 and info.damage < 0.21 then --melee
						info.damage = Config.meleeDamageBot
						info.isBulletDamage = false
					end
					--[[info.isBulletDamage = false;
					info.isExplosionDamage = false;
					info.isDemolitionDamage = true;
					info.shouldForceDamage = false;
					info.isClientDamage = false;--]]

					info.boneIndex = 0
					info.position = Vec3(soldier.worldTransform.trans.x, soldier.worldTransform.trans.y + 1, soldier.worldTransform.trans.z)
					info.direction = soldier.worldTransform.trans - bot.player.soldier.worldTransform.trans
					info.origin = bot.player.soldier.worldTransform.trans
					hook:Pass(soldier, info, newGiverInfo)
				end
			end
		end
	end
end


function BotManager:_onServerDamagePlayer(playerName, shooterName, meleeAttack)
	local player = PlayerManager:GetPlayerByName(playerName)
	if player ~= nil then
		self:_onDamagePlayer(player, shooterName, meleeAttack)
	end
end

function BotManager:_onDamagePlayer(player, shooterName, meleeAttack)
	local bot = self:GetBotByName(shooterName)
	if not player.alive or bot == nil then
		return
	end
	local damage = 0.1 --only trigger soldier-damage with this
	if meleeAttack then
		damage = 0.2 --signal melee damage with this value
	end
	--save potential killer bot
	self._shooterBots[player.name] = shooterName

	if player.soldier ~= nil then
		player.soldier.health = player.soldier.health - damage
	end
end



function BotManager:_onShootAt(player, botname, ignoreYaw)
	local bot = self:GetBotByName(botname)
	if bot == nil or bot.player.soldier == nil or player.soldier == nil then
		return
	end
	if bot.player.teamId ~= player.teamId then
		bot:shootAt(player, ignoreYaw)
	end
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