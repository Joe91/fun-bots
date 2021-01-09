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
    BotManager:onLevelLoaded(TraceManager.activeTraceIndexes)
end


function FunBotServer:_onChat(player, recipientMask, message)

    if player == nil then
        return
    end

    local parts = string.lower(message):split(' ')

    --set team for bot-spawn
    if player.teamId == TeamId.Team1 then
        if Config.spawnInSameTeam then
            team = TeamId.Team1
        else
            team = TeamId.Team2
        end
    else
        if Config.spawnInSameTeam then
            team = TeamId.Team2
        else
            team = TeamId.Team1
        end
    end

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
        spawnBotTowerOnPlayer(player, height)

    elseif parts[1] == '!grid' then
        if tonumber(parts[2]) == nil then
            return
        end
        local rows = tonumber(parts[2])
        local columns = tonumber(parts[3]) or tonumber(parts[2])
        local spacing = tonumber(parts[4]) or 2
        spawnBotGridOnPlayer(player, rows, columns, spacing)

    -- static mode commands
    elseif parts[1] == '!mimic' then
        setBotVarForPlayerStatic(player, botMoveModes, 3, true)

    elseif parts[1] == '!mirror' then
        setBotVarForPlayerStatic(player, botMoveModes, 4, true)
    
    elseif parts[1] == '!static' then
        setBotVarForPlayerStatic(player, botMoveModes, 0, true)

    -- moving bots spawning
    elseif parts[1] == '!spawnline' then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        spawnLineBots(player, amount, spacing)

    elseif parts[1] == '!spawnring' then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 10
        spawnRingBots(player, amount, spacing)

    elseif parts[1] == '!spawnway' then
        if tonumber(parts[2]) == nil then
            return
        end
        local activeWayIndex = tonumber(parts[3]) or 1
        if activeWayIndex > Config.maxTraceNumber or activeWayIndex < 1 then
            activeWayIndex = 1
        end
        local amount = tonumber(parts[2])
        spawnWayBots(player, amount, false, activeWayIndex)

    elseif parts[1] == '!spawnrandway' or parts[1] == "!spawnbots" then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        spawnWayBots(player, amount, true, 1)

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
        respawning = true
        if tonumber(parts[2]) == 0 then
            respawning = false
        end
        setBotVarForAll(botRespawning, respawning)


    elseif parts[1] == '!shoot' then
        local shooting = true
        if tonumber(parts[2]) == 0 then
            shooting = false
        end
        setBotVarForAll(botShooting, shooting)

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
            setBotVarForAll(botKits, kitNumber)
        end

    elseif parts[1] == '!setbotColor' then
        local botColor = tonumber(parts[2]) or 1
        if botColor <= #Colors and botColor >= 0 then
            Config.botColor = botColor
            setBotVarForAll(botColors, Colors[botColor])
        end

    -- extra modes
    elseif parts[1] == '!die' then
        dieing = true
        if tonumber(parts[2]) == 0 then
            dieing = false
        end

    -- reset everything
    elseif parts[1] == '!stopall' then
        dieing = false
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            botSpeeds[name] = 0
            botMoveModes[name] = 0
            botSpawnModes[name] = 0
            botRespawning[name] = false
        end

    elseif parts[1] == '!stop' then
        dieing = false
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                botSpeeds[name] = 0
                botMoveModes[name] = 0
                botSpawnModes[name] = 0
                botRespawning[name] = false
            end
        end

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
        Bots:destroyAllBots()
        for i = 1, Config.maxNumberOfBots do
            botTargetPlayers[name] = nil
        end

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
        local traceIndex = tonumber(parts[2]) or 1
        if traceIndex > Config.maxTraceNumber then
            traceIndex = 1
        end
        print("!trace started")
		ChatManager:Yell("!trace "..traceIndex.." started", 5.5)
        clearPoints(traceIndex)
        traceTimesGone[traceIndex] = 0
        tracePlayers[traceIndex] = player

    elseif parts[1] == '!tracedone' then
		print("!trace done")
		ChatManager:Yell("!trace done", 5.5)
        activeTraceIndexes = activeTraceIndexes + 1
        for i = 1, Config.maxTraceNumber do
            if tracePlayers[i] == player then
                tracePlayers[i] = nil
            end
        end

    elseif parts[1] == '!setpoint' then
		print("!setpoint")
		ChatManager:Yell("!setpoint", 5.5)
        local traceIndex = tonumber(parts[2]) or 1
        setPoint(traceIndex, player)

    elseif parts[1] == '!cleartrace' then
        local traceIndex = tonumber(parts[2]) or 1
        print("!cleartrace")
		ChatManager:Yell("!cleartrace "..traceIndex, 5.5)
        clearPoints(traceIndex)
    
    elseif parts[1] == '!clearalltraces' then
		print("!clearalltraces")
		ChatManager:Yell("!clearalltraces", 5.5)
        for i = 1, Config.maxTraceNumber do
            clearPoints(i)
        end
        activeTraceIndexes = 0

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

    elseif parts[1] == '!printslot' then
		print("!printslot")
		ChatManager:Yell("!printslot", 5.5)
        print(player.soldier.weaponsComponent.currentWeaponSlot)
        
    elseif parts[1] == '!savepaths' then
        print("try to save paths")
		ChatManager:Yell("Trying to Save paths check console", 5.5)
        saveWayPoints()
        --local co = coroutine.create(function ()
        --    saveWayPoints()
        --end)
        --coroutine.resume(co)

    -- only experimental
    elseif parts[1] == '!mode' then --overwrite mode for all bots
        if tonumber(parts[2]) == nil then
            return
        end
        local moveMode = tonumber(parts[2])
        setBotVarForPlayer(player, botMoveModes, moveMode)

    -- vehicle stuff -- TODO: not tested jet
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
    end
end)

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


function getYawOffsetTransform(transform, yaw, spacing)
    local offsetTransform = LinearTransform()
    offsetTransform.trans.x = transform.trans.x + (math.cos(yaw + (math.pi / 2)) * spacing)
    offsetTransform.trans.y = transform.trans.y
    offsetTransform.trans.z = transform.trans.z + (math.sin(yaw + (math.pi / 2)) * spacing)
    return offsetTransform
end

function isStaticBotMode(mode)
    if mode == 0 or mode == 3 or mode == 4 then
        return true
    else
        return false
    end
end

function setBotVarForPlayer(player, botVar, value)
    for i = 1, Config.maxNumberOfBots do
        local name = BotNames[i]
        if botTargetPlayers[name] == player then
            botVar[name] = value
        end
    end
end

function setBotVarForPlayerStatic(player, botVar, value, static)
    for i = 1, Config.maxNumberOfBots do
        local name = BotNames[i]
        if botTargetPlayers[name] == player then
            if isStaticBotMode(botMoveModes[name]) == static then
                botVar[name] = value
            end
        end
    end
end

function setBotVarForAll(botVar, value)
    for i = 1, Config.maxNumberOfBots do
        local name = BotNames[i]
        botVar[name] = value
    end
end

function setPoint(traceIndex, player)
    local transform = LinearTransform()
    transform = player.soldier.transform
    table.insert(wayPoints[traceIndex], transform)
end

function clearPoints(traceIndex)
    if traceIndex < 1 or traceIndex > Config.maxTraceNumber then
        return
    end
    if wayPoints[traceIndex][1] ~= nil then
        activeTraceIndexes = activeTraceIndexes - 1
    end
    wayPoints[traceIndex] = {}
end

function spawnBotRowOnPlayer(player, length, spacing)
    local listOfVars = {
        spawnMode = 0,
        speed = 0,
        moveMode = 0,
        activeWayIndex = 0,
        respawning = false,
        shooting = false
    }
    for i = 1, length do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = player.input.authoritativeAimingYaw
            local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true, listOfVars)
        end
    end
end

function spawnBotTowerOnPlayer(player, height)
    local listOfVars = {
        spawnMode = 0,
        speed = 0,
        moveMode = 0,
        activeWayIndex = 0,
        respawning = false,
        shooting = false
    }
    for i = 1, height do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = player.input.authoritativeAimingYaw
            local transform = LinearTransform()
            transform.trans.x = player.soldier.transform.trans.x + (math.cos(yaw + (math.pi / 2)))
            transform.trans.y = player.soldier.transform.trans.y + ((i - 1) * 1.8)
            transform.trans.z = player.soldier.transform.trans.z + (math.sin(yaw + (math.pi / 2)))
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true, listOfVars)
        end
    end
end

function spawnBotGridOnPlayer(player, rows, columns, spacing)
    local listOfVars = {
        spawnMode = 0,
        speed = 0,
        moveMode = 0,
        activeWayIndex = 0,
        respawning = false,
        shooting = false
    }
    for i = 1, rows do
        for j = 1, columns do
            local name = findNextBotName()
            if name ~= nil then
                local yaw = player.input.authoritativeAimingYaw
                local transform = LinearTransform()
                transform.trans.x = player.soldier.transform.trans.x + (i * math.cos(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.cos(yaw) * spacing)
                transform.trans.y = player.soldier.transform.trans.y
                transform.trans.z = player.soldier.transform.trans.z + (i * math.sin(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.sin(yaw) * spacing)
                botTargetPlayers[name] = player
                spawnBot(name, team, squad, transform, true, listOfVars)
            end
        end
    end
end

function spawnLineBots(player, amount, spacing)
    local listOfVars = {
        spawnMode = 2,
        speed = 3,
        moveMode = 2,
        activeWayIndex = 0,
        respawning = false,
        shooting = false
    }
    for i = 1, amount do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = player.input.authoritativeAimingYaw
            local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
            botTransforms[name] = transform
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true, listOfVars)
        end
    end
end

function spawnRingBots(player, amount, spacing)
    local listOfVars = {
        spawnMode = 3,
        speed = 3,
        moveMode = 2,
        activeWayIndex = 0,
        respawning = false,
        shooting = false
    }
    ringNrOfBots = amount

    ringSpacing = spacing
    for i = 1, amount do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = i * (2 * math.pi / amount)
            local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true, listOfVars)
        end
    end
end

function spawnWayBots(player, amount, randomIndex, activeWayIndex)
    local spawnMode = 4
    local shooting = false
    if randomIndex then
        spawnMode = 5
        shooting = true
    end
    local listOfVars = {
        spawnMode = spawnMode,
        speed = 3,
        moveMode = 5,
        activeWayIndex = activeWayIndex,
        respawning = false,
        shooting = shooting
    }
    if wayPoints[activeWayIndex][1] == nil or activeTraceIndexes <= 0 then
        return
    end
    for i = 1, amount do
        local name = findNextBotName()
        if name ~= nil then
            if randomIndex then
                activeWayIndex = getNewWayIndex()
                if activeWayIndex == 0 then
                    return
                end
            end
            local randIdex = MathUtils:GetRandomInt(1, #wayPoints[activeWayIndex])
            botCurrentWayPoints[name] = randIdex
            local transform = LinearTransform()
            transform.trans = wayPoints[activeWayIndex][randIdex].trans
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true, listOfVars)
        end
    end
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function getNewWayIndex()
    local newWayIdex = 0
    if activeTraceIndexes <= 0 then
        return newWayIdex
    end
    local targetWaypoint = MathUtils:GetRandomInt(1, activeTraceIndexes)
    local count = 0
    for i = 1, Config.maxTraceNumber do
        if wayPoints[i][1] ~= nil then
            count = count + 1
        end
        if count == targetWaypoint then
            newWayIdex = i
            return newWayIdex
        end
    end
    return newWayIdex
end

function findNextBotName()
    for i = 1, Config.maxNumberOfBots do
        local name = BotNames[i]
        local bot = PlayerManager:GetPlayerByName(name)
        if bot == nil then
            return name
        elseif bot.soldier == nil then
            return name
        end
    end
    return nil
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