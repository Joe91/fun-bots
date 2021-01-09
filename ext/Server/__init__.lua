class('FunBotServer')
require('__shared/Config')
local BotManager = require('botManager')
local TraceManager = require('traceManager')
local BotSpawner = require('botSpawner')

function FunBotServer:__init()
    Events:Subscribe("Player:TeamChange", self, self._onTeamChange)
    Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)
    Events:Subscribe('Player:Chat', self, self._onChat)
end

function FunBotServer:_onTeamChange(player, team, squad)
    if player == nil then
        print("player has no name")
    else
        ChatManager:SendMessage("Welcome " .. player.name .. " press F1 key for some information", player)
    end
end

function FunBotServer:_onLevelLoaded(levelName, gameMode)
    TraceManager:onLevelLoaded(levelName, gameMode)
    BotManager:onLevelLoaded()
end


function FunBotServer:_onChat(player, recipientMask, message)

    if player == nil then
        return
    end

    local parts = string.lower(message):split(' ')

    if parts[1] == '!row' then
        if tonumber(parts[2]) == nil then
            return
        end
        local length = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        BotSpawner:spawnBotRow(player, length, spacing)

    elseif parts[1] == '!tower' then
        if tonumber(parts[2]) == nil then
            return
        end
        local height = tonumber(parts[2])
        BotSpawner:spawnBotTower(player, height)

    elseif parts[1] == '!grid' then
        if tonumber(parts[2]) == nil then
            return
        end
        local rows = tonumber(parts[2])
        local columns = tonumber(parts[3]) or tonumber(parts[2])
        local spacing = tonumber(parts[4]) or 2
        BotSpawner:spawnBotGrid(player, rows, columns, spacing)

    -- static mode commands
    elseif parts[1] == '!mimic' then
        BotManager:setStaticMovement(player, 3)

    elseif parts[1] == '!mirror' then
        BotManager:setStaticMovement(player, 4)
    
    elseif parts[1] == '!static' then
        BotManager:setStaticMovement(player, 0)

    -- moving bots spawning
    elseif parts[1] == '!spawnline' then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        BotSpawner:spawnLineBots(player, amount, spacing)

    elseif parts[1] == '!spawnring' then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 10
        BotSpawner:spawnRingBots(player, amount, spacing)

    elseif parts[1] == '!spawnway' then
        if tonumber(parts[2]) == nil then
            return
        end
        local activeWayIndex = tonumber(parts[3]) or 1
        if activeWayIndex > Config.maxTraceNumber or activeWayIndex < 1 then
            activeWayIndex = 1
        end
        local amount = tonumber(parts[2])
        BotSpawner:spawnWayBots(player, amount, false, activeWayIndex)

    elseif parts[1] == '!spawnrandway' or parts[1] == "!spawnbots" then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        BotSpawner:spawnWayBots(player, amount, true)

    -- moving bots movement settings
    elseif parts[1] == '!run' then
        setBotVarForPlayerStatic(player, botSpeeds, 4, false)

    elseif parts[1] == '!walk' then
        setBotVarForPlayerStatic(player, botSpeeds, 3, false)
    
    elseif parts[1] == '!speed' then --overwrite speed for all moving bots
        if tonumber(parts[2]) == nil then
            return
        end
        local speed = tonumber(parts[2])
        setBotVarForPlayerStatic(player, botSpeeds, speed, false)


    -- respawn moving bots
    elseif parts[1] == '!respawn' then
        local respawning = true
        if tonumber(parts[2]) == 0 then
            respawning = false
        end
        BotManager:setOptionForAll("respawn", respawning)

    elseif parts[1] == '!shoot' then
        local shooting = true
        if tonumber(parts[2]) == 0 then
            shooting = false
        end
        BotManager:setOptionForAll("shoot", shooting)

    -- spawn team settings
    elseif parts[1] == '!spawnsameteam' then
        Config.spawnInSameTeam = true
        if tonumber(parts[2]) == 0 then
            Config.spawnInSameTeam = false
        end

    elseif parts[1] == '!setbotkit' then
        local kitNumber = tonumber(parts[2]) or 1
        if kitNumber <= 4 and kitNumber >= 0 then
            Config.botKit = kitNumber
        end

    elseif parts[1] == '!setbotColor' then
        local botColor = tonumber(parts[2]) or 1
        if botColor <= #Colors and botColor >= 0 then
            Config.botColor = botColor
        end

    -- reset everything
    elseif parts[1] == '!stopall' then
        BotManager:setOptionForAll("shoot", false)
        BotManager:setOptionForAll("respawning", false)
        BotManager:setOptionForAll("moveMode", 0)

    elseif parts[1] == '!stop' then
        BotManager:setOptionForPlayer(player, "shoot", false)
        BotManager:setOptionForPlayer(player, "respawning", false)
        BotManager:setOptionForPlayer(player, "moveMode", 0)
 
    elseif parts[1] == '!kick' then
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                kickBot(name)
            end
        end

    elseif parts[1] == '!kickteam' then
        local teamToKick = tonumber(parts[2]) or 1
        if teamToKick < 1 or teamToKick > 2 then
            return
        end
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTeams[name] == TeamId.Team1 and teamToKick == 1 then
                kickBot(name)
            elseif botTeams[name] == TeamId.Team2 and teamToKick == 2 then
                kickBot(name)
            end
        end

    elseif parts[1] == '!kickall' then
        BotManager:destroyAllBots()

    elseif parts[1] == '!kill' then
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                botMoveModes[name] = 0
                botSpeeds[name] = 0
                botSpawnModes[name] = 0
                local bot = PlayerManager:GetPlayerByName(name)
                if bot and bot.soldier then
                    bot.soldier:Kill()
                end
            end
        end

    elseif parts[1] == '!killall' then
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            botMoveModes[name] = 0
            botSpeeds[name] = 0
            botSpawnModes[name] = 0
            local bot = PlayerManager:GetPlayerByName(name)
            if bot and bot.soldier then
                bot.soldier:Kill()
            end
        end

    -- waypoint stuff
    elseif parts[1] == '!trace' then
        local traceIndex = tonumber(parts[2]) or 0
        TraceManager:startTrace(player, traceIndex)

    elseif parts[1] == '!tracedone' then
        TraceManager:endTrace(player)

    elseif parts[1] == '!setpoint' then
        local traceIndex = tonumber(parts[2]) or 1
        TraceManager:setPoint(player, traceIndex)

    elseif parts[1] == '!cleartrace' then
        local traceIndex = tonumber(parts[2]) or 1
        TraceManager:clearTrace(traceIndex)

    elseif parts[1] == '!clearalltraces' then
		TraceManager:clearAllTraces()

    elseif parts[1] == '!printtrans' then
		print("!printtrans")
		ChatManager:Yell("!printtrans", 5.5)
        print(player.soldier.transform)
        print(player.soldier.transform.trans.x)
        print(player.soldier.transform.trans.y)
        print(player.soldier.transform.trans.z)
		ChatManager:SendMessage(player.soldier.transform)
		ChatManager:SendMessage(player.soldier.transform.trans.x)
		ChatManager:SendMessage(player.soldier.transform.trans.y)
		ChatManager:SendMessage(player.soldier.transform.trans.z)

    elseif parts[1] == '!savepaths' then
        TraceManager:savePaths()

    --[[-- vehicle stuff -- TODO: not tested jet
    elseif parts[1] == '!enter' then
        local vehicleHint = parts[2] or ""
        local entryId = tonumber(parts[3]) or 1

        local iterator = EntityManager:GetIterator("ServerVehicleEntity")
        local vehicleEntity = iterator:Next()
        while vehicleEntity ~= nil do
            local vehicleName = VehicleEntityData(vehicleEntity.data).controllableType

            if string.lower(vehicleName):match(string.lower(vehicleHint)) then
                local name = findNextBotName()
                if name ~= nil then
                    spawnBot(name, team, squad, player.soldier.transform, true)
                    local bot = PlayerManager:GetPlayerByName(name)
                    bot:EnterVehicle(vehicleEntity, entryId)
                end
            end
            vehicleEntity = iterator:Next()
        end

    elseif parts[1] == '!fill' then
        local vehicleHint = parts[2] or ""
        local number = tonumber(parts[3]) or 2

        local iterator = EntityManager:GetIterator("ServerVehicleEntity")
        local vehicleEntity = iterator:Next()
        while vehicleEntity ~= nil do
            local vehicleName = VehicleEntityData(vehicleEntity.data).controllableType

            if string.lower(vehicleName):match(string.lower(vehicleHint)) then
                for i = 0, number do
                    local name = findNextBotName()
                        if name ~= nil then
                        spawnBot(name, team, squad, player.soldier.transform, true)
                        local bot = PlayerManager:GetPlayerByName(name)
                        bot:EnterVehicle(vehicleEntity, i)
                    end
                end
            end
            vehicleEntity = iterator:Next()
        end
    end--]]
end

--Key pressess instead of commands -Bitcrusher
NetEvents:Subscribe('keypressF5', function(player, data)
    local traceIndex = 1
    for i = 1, Config.maxTraceNumber do
        if wayPoints[i][1] == nil then
            traceIndex = i
        end
    end
    print("Bot trace "..traceIndex.." started")
    ChatManager:Yell("Bot trace Nr. "..traceIndex.." started", 2.5)
    clearPoints(traceIndex)
    traceTimesGone[traceIndex] = 0
    tracePlayers[traceIndex] = player
end)
NetEvents:Subscribe('keypressF6', function(player, data)
    print("Bot trace done")
    ChatManager:Yell("Bot trace done", 2.5)
    activeTraceIndexes = activeTraceIndexes + 1
    for i = 1, Config.maxTraceNumber do
        if tracePlayers[i] == player then
            tracePlayers[i] = nil
        end
    end
end)
NetEvents:Subscribe('keypressF7', function(player, data)
    print("Point set")
    ChatManager:Yell("Point set", 2.5)
    local traceIndex = 1
    setPoint(traceIndex, player)
end)
NetEvents:Subscribe('keypressF8', function(player, data)
    print("Points Clear")
    ChatManager:Yell("Points Clear", 2.5)
    local traceIndex = 1
    clearPoints(traceIndex)
end)
NetEvents:Subscribe('keypressF9', function(player, data)
    print("clear all traces")
    ChatManager:Yell("clear all traces", 2.5)
    for i = 1, Config.maxTraceNumber do
        clearPoints(i)
    end
    activeTraceIndexes = 0
end)
NetEvents:Subscribe('keypressF10', function(player, data)
    print("printtrans")
    ChatManager:Yell("printtrans", 2.5)
    print(player.soldier.transform)
    print(player.soldier.transform.trans.x)
    print(player.soldier.transform.trans.y)
    print(player.soldier.transform.trans.z)
    ChatManager:Yell("Check server console", 2.5)
end)
NetEvents:Subscribe('keypressF11', function(player, data)
    print("printslot")
    ChatManager:Yell("printslot", 2.5)
    print(player.soldier.weaponsComponent.currentWeaponSlot)
end)
NetEvents:Subscribe('keypressF12', function(player, data)
    print("Trying to Save paths")
    ChatManager:Yell("Trying to Save paths", 2.5)
    saveWayPoints()
end)
--Key pressess instead of commands -Bitcrusher


function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

-- use this function, if you want to spawn new bots anyway
function freeNumberOfBots(number)
    if number > Config.maxNumberOfBots then
        return
    end
    local counter = 0
    for i = 1, Config.maxNumberOfBots do
        local name = BotNames[i]
        local bot = PlayerManager:GetPlayerByName(name)
        if bot == nil then
            counter = counter + 1
        elseif  bot.soldier == nil then
            counter = counter + 1
        end
        if counter >= number then
            return
        end
    end
    -- not enough bots available. Now free some random bots
    local botsToFree = number - counter
    while botsToFree > 0 do
        local name = BotNames[MathUtils:GetRandomInt(1, Config.maxNumberOfBots)]
        local bot = PlayerManager:GetPlayerByName(name)
        if bot ~= nil and bot.soldier ~= nil then
            botSpawnModes[name] = 0
            botMoveModes[name] = 0
            bot.soldier:Kill()
            botsToFree = botsToFree-1
        end
    end
end

function checkSwapBotTeams()
    for i = 1, Config.maxNumberOfBots do
        local name = BotNames[i]
        local bot = PlayerManager:GetPlayerByName(name)
        if bot ~= nil then
            botCheckSwapTeam[name] = true
        end
    end
end



function kickBot(name)
	local bot = PlayerManager:GetPlayerByName(name)
	if bot == nil then
		return
	end
	if not Bots:isBot(bot) then
		return
	end
	Bots:destroyBot(bot)
end



-- Singleton.
if g_FunBotServer == nil then
	g_FunBotServer = FunBotServer()
end

return g_FunBotServer