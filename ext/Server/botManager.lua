class('BotManager')
require('bot')
local Globals = require('globals')

function BotManager:__init()
    self._bots = {}
    self._botInputs = {}

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
    Events:Subscribe('Extension:Unloading', self, self._onUnloading)
    Events:Subscribe('Player:Left', self, self._onPlayerLeft)
    NetEvents:Subscribe('BotShootAtPlayer', self, self._onShootAt)
    NetEvents:Subscribe('DamagePlayer', self, self._onDamagePlayer)
end

function BotManager:onLevelLoaded()
    --find team to spawn bots in
    local listOfTeams = {}
    local botTeam = TeamId.Team2
    for _, bot in pairs(self._bots) do
        table.insert(listOfTeams, bot.player.teamId)
    end
    local countOfBotTeam = 0
    for i = 1, #listOfTeams do
        if listOfTeams[i] == botTeam then
            countOfBotTeam = countOfBotTeam + 1
        end
    end
    if countOfBotTeam < #listOfTeams then
        botTeam = TeamId.Team1
    end
    Globals.botTeam = botTeam

    self:destroyAllBots()
    -- create initial bots
    if Globals.activeTraceIndexes > 0 and Config.spawnOnLevelstart then
        for i = 1, Config.initNumberOfBots do
            local bot = self:createBot(BotNames[i], botTeam)
            bot:setVarsDefault()
        end
    end
end

function BotManager:findNextBotName()
    for i = 1, Config.maxNumberOfBots do
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

function BotManager:_onPlayerLeft(player)
    --remove all references of player
    for _, bot in pairs(self._bots) do
        bot:clearPlayer(player)
    end
end

function BotManager:_onDamagePlayer(player, shooterName)
    local bot = self:GetBotByName(shooterName)
    if not player.alive or bot == nil then
        return
    end
    local damage = (bot.kit == 4) and Config.bulletDamageBotSniper or Config.bulletDamageBot

    if player.soldier ~= nil then
        player.soldier.health = player.soldier.health - damage
    end
    --[[if player.soldier == nil then 
        local killerBot = self:GetBotByName(shooterName)
        killerBot.player.kills = killerBot.player.kills + 1  --not writable
    end--]]
end

function BotManager:_onShootAt(player, botname, ignoreYaw)
    local bot = self:GetBotByName(botname)
    if bot == nil or bot.player.soldier == nil or player.soldier == nil then
        return
    end
    bot:shootAt(player, ignoreYaw)
end


function BotManager:_onUnloading()
	self:destroyAllBots()
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
        return bot
    end

    -- Create a player for this bot.
    local botPlayer = PlayerManager:CreatePlayer(name, team, SquadId.SquadNone)

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
            bot.player.soldier:Kill()
        end
    end
end

function BotManager:killAll()
    for _, bot in pairs(self._bots) do
        bot:resetVars()
        bot.player.soldier:Kill()
    end
end

function BotManager:destroyTeam(teamId)
    for i = 1, Config.maxNumberOfBots do
        local bot = self:GetBotByName(BotNames[i])
        if bot.player.teamId == teamId then
            self:destroyBot(bot.name)
        end
    end
end

function BotManager:destroyPlayerBots(player)
    for i = 1, Config.maxNumberOfBots do
        local bot = self:GetBotByName(BotNames[i])
        if bot:getTargetPlayer() == player then
            self:destroyBot(bot.name)
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