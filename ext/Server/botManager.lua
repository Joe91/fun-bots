class('BotManager')
require('bot')
local Globals = require('globals')

function BotManager:__init()
    self._bots = {}
    self._botInputs = {}
    self._shooterBots = {}

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
    Events:Subscribe('Extension:Unloading', self, self._onUnloading)
    Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
    Events:Subscribe('Player:Left', self, self._onPlayerLeft)
    NetEvents:Subscribe('BotShootAtPlayer', self, self._onShootAt)
    Events:Subscribe('ServerDamagePlayer', self, self._onServerDamagePlayer)
    NetEvents:Subscribe('ClientDamagePlayer', self, self._onDamagePlayer)
    Hooks:Install('Soldier:Damage', 1, self, self._onSoldierDamage)
end

function BotManager:detectBotTeam()
    local countPlayerTeam = 0
    local countPlayers = 0
    local players = PlayerManager:GetPlayers()
    for i = 1, PlayerManager:GetPlayerCount() do
        if self:GetBotByName(players[i].name) == nil then
            countPlayers = countPlayers + 1
            if players[i].teamId ~= Config.botTeam then
                countPlayerTeam = countPlayerTeam + 1
            end
        end
    end

    if countPlayerTeam >= countPlayers/2 then
        if Config.botTeam == TeamId.Team1 and not Config.spawnInSameTeam then
            Config.botTeam = TeamId.Team2
        else
            Config.botTeam = TeamId.Team1
        end
    else
        if Config.botTeam == TeamId.Team1 and not Config.spawnInSameTeam then
            Config.botTeam = TeamId.Team1
        else
            Config.botTeam = TeamId.Team2
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

function BotManager:getBotCount()
    return #self._bots
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

function BotManager:_onPlayerLeft(player)
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
                print(giverInfo)
                print(giverInfo.weaponUnlock)
                print(giverInfo.weaponFiring)
                self:_onShootAt(giverInfo.giver, bot.name, true)
            end
        end
    end

    --find out, if a player was hit by the server:
    if soldier.player ~= nil then
        local bot = self:GetBotByName(soldier.player.name)
        if bot == nil then
            if giverInfo.giver == nil then
                bot = self:GetBotByName(self._shooterBots[soldier.player.name])
                if bot ~= nil and bot.player.soldier ~= nil then
                    print("damage player")
                    if info.damage == 1 then
                        info.isBulletDamage = true
                        if bot.kit == 4 then
                            info.damage = Config.bulletDamageBotSniper
                        else
                            info.damage = Config.bulletDamageBot
                        end
                    elseif info.damage == 2 then --melee
                        info.damage = Config.meleeDamageBot
                        info.isBulletDamage = false
                    end
                    info.boneIndex = 0
                    info.position = soldier.worldTransform.trans
                    info.direction = soldier.worldTransform.trans - bot.player.soldier.worldTransform.trans
                    info.origin = bot.player.soldier.worldTransform.trans
                    giverInfo.giver = bot.player
                    giverInfo.assistant = nil
                    giverInfo.weaponUnlock = bot.player.weapons[1]
                    giverInfo.weaponFiring = nil
                    giverInfo.giverControllable = bot.player.attachedControllable --attachedControllable --controlledControllable
                    giverInfo.giverCharacterCustomization = bot.player.customization
                    giverInfo.damageType = 0
                    hook:Pass(soldier, info, giverInfo)
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
    local damage = 1 --only trigger soldier-damage with this
    if meleeAttack then
        damage = 2 --signal melee damage with this value
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
    bot:shootAt(player, ignoreYaw)
end


function BotManager:_onUnloading()
	self:destroyAllBots()
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
    for i = 1, Config.maxNumberOfBots do
        local index = Config.maxNumberOfBots + 1 - i
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
    for i = 1, Config.maxNumberOfBots do
        local bot = self:GetBotByName(BotNames[i])
        if bot ~= nil then
            if bot.player.teamId == teamId then
                self:destroyBot(bot.name)
            end
        end
    end
end

function BotManager:destroyPlayerBots(player)
    for i = 1, Config.maxNumberOfBots do
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