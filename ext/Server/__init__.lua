require('__shared/Config')
local Bots = require('bots')

local moveMode = 5 --standing, centerpoint, pointing
local speed = 3 -- standing 0, proning 1, couching 2, walking 3, running 4
local spawnMode = 0 -- center 1, line 2, ring 3

-- vars for each bot
local botSpawnModes = {}
local botSpeeds = {}
local botMoveModes = {}
local botTimeGones = {}
local botTargetPlayers = {}
local botTransforms = {}
local botYaws = {}
local botCurrentWayPoints = {}
local botWayIndexes = {}
local botTeams = {}

local botJumping = {}
local botAdading = {}
local botSwaying = {}
local botDieing = {}
local botRespawning = {}

-- vars for all bots
local jumping = false
local adading = false
local swaying = false
local dieing = false
local respawning = false
local team = TeamId.Team1
local squad = SquadId.SquadNone

local centerPointPeriod = 5
local centerPointElapsedTime = 0

local swayPeriod = 5
local swayElapsedTime = 0
local swayMaxDeviation = 1

local adadPeriod = 1
local adadElapsedTime = 0

local centerpoint = LinearTransform()
local ringSpacing = 25
local ringNrOfBots = 0

local activeWayIndex
local tracePlayers = {}
local traceTimesGone = {}
local wayPoints = {}
for i = 1, Config.maxTraceNumber do
    wayPoints[i] = {}
end

Events:Subscribe('Level:Loaded', function(levelName, gameMode)
    print("level "..levelName.."in Gamemode "..gameMode.." loaded")

end)

Events:Subscribe('Player:Killed', function(player)
    if Config.exploding then
        NetEvents:BroadcastLocal('Bot:Killed', player.soldier.worldTransform.trans)
    end
end)

Events:Subscribe('Engine:Update', function(dt)
    centerPointElapsedTime = centerPointElapsedTime + dt
    while centerPointElapsedTime >= centerPointPeriod do
        centerPointElapsedTime = centerPointElapsedTime - centerPointPeriod
    end

    swayElapsedTime = swayElapsedTime + dt
    while swayElapsedTime >= swayPeriod do
        swayElapsedTime = swayElapsedTime - swayPeriod
    end

    adadElapsedTime = adadElapsedTime + dt
    while adadElapsedTime >= adadPeriod do
        adadElapsedTime = 0
        adadPeriod = MathUtils:GetRandom(0.5, 2.5)
    end

    --trace way if wanted
    for i = 1, Config.maxTraceNumber do
        if tracePlayers[i] ~= nil and tracePlayers[i].input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then
            traceTimesGone[i] = traceTimesGone[i] + dt
            if traceTimesGone[i] >= Config.traceDelta then
                traceTimesGone[i] = 0
                local point = LinearTransform()
                point = tracePlayers[i].soldier.transform
                table.insert(wayPoints[i], point)
            end
        end
    end
end)

Events:Subscribe('Bot:Update', function(bot, dt)
    -- increase performance with reduced update cycles
    local timeGone = botTimeGones[bot.name] + dt
    if timeGone < 0.1 then --(10 times per second?)
        botTimeGones[bot.name] = timeGone
        return
    end
    botTimeGones[bot.name] = 0
    local additionalMovementPossible = true

    local botIndex = tonumber(bot.name)
    local spawnMode = botSpawnModes[bot.name]
    local speed     = botSpeeds[bot.name]
    local moveMode =  botMoveModes[bot.name]
    local activePlayer = botTargetPlayers[bot.name]
    local team = botTeams[bot.name]
    local wayIndex = botWayIndexes[bot.name]

    local jumping = botJumping[bot.name]
    local adading = botAdading[bot.name]
    local swaying = botSwaying[bot.name]
    local dieing = botDieing[bot.name]
    local respawning = botRespawning[bot.name]

    --spawning 
    if respawning and bot.soldier == nil and spawnMode > 0 then
        if spawnMode == 1 then --spawnCenterpoint
            botYaws[bot.name] = MathUtils:GetRandom(0, 2*math.pi)
            spawnBot(bot.name, team, squad, centerpoint, false)
            bot.input.authoritativeAimingYaw = botYaws[bot.name]
        elseif spawnMode == 2 then  --spawnInLine
            spawnBot(bot.name, team, squad, botTransforms[bot.name], false)
        elseif spawnMode == 3 then  --spawnInRing around player
            if activePlayer ~= nil then
                if activePlayer.soldier  ~= nil then
                    local yaw = botIndex * (2 * math.pi / ringNrOfBots)
                    local transform = getYawOffsetTransform(activePlayer.soldier.transform, yaw, ringSpacing)
                    spawnBot(bot.name, team, squad, transform, false)
                end
            end
        elseif spawnMode == 4 then --spawn on way
            local randIdex = MathUtils:GetRandomInt(1, #wayPoints[wayIndex])
            botCurrentWayPoints[bot.name] = randIdex
            local transform = LinearTransform()
            transform = wayPoints[wayIndex][randIdex]
            spawnBot(bot.name, team, squad, transform, false)
        else
            spawnBot(bot.name, team, squad, botTransforms[bot.name], false)
        end
    end

    -- movement-mode of bots
    if bot.soldier ~= nil then
        if moveMode == 1 then -- centerpoint
            if centerPointElapsedTime <= (centerPointPeriod / 2) then
                bot.input.authoritativeAimingYaw = botYaws[bot.name]
            else
                bot.input.authoritativeAimingYaw = (botYaws[bot.name] < math.pi) and (botYaws[bot.name] + math.pi) or (botYaws[bot.name] - math.pi)
            end

        elseif moveMode == 2 and activePlayer ~= nil then
            if activePlayer.soldier  ~= nil then  -- pointing
                local dy = activePlayer.soldier.transform.trans.z - bot.soldier.transform.trans.z
                local dx = activePlayer.soldier.transform.trans.x - bot.soldier.transform.trans.x
                local yaw = (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2)
                if swaying then
                    local swayMod = (swayElapsedTime > swayPeriod / 2) and (((swayPeriod - swayElapsedTime) / swayPeriod - 0.25) * 4) or ((swayElapsedTime / swayPeriod - 0.25) * 4)
                    local swayedYaw = yaw + swayMod * swayMaxDeviation
                    swayedYaw = (swayedYaw > 2 * math.pi) and (swayedYaw - 2 * math.pi) or swayedYaw
                    swayedYaw = (swayedYaw < 0) and (swayedYaw + 2 * math.pi) or swayedYaw
                    bot.input.authoritativeAimingYaw = swayedYaw
                else
                    bot.input.authoritativeAimingYaw = yaw
                end
            end

        elseif moveMode == 3 and activePlayer ~= nil then  -- mimicking
            additionalMovementPossible = false
            for i = 0, 36 do
                bot.input:SetLevel(i, activePlayer.input:GetLevel(i))
            end
            bot.input.authoritativeAimingYaw = activePlayer.input.authoritativeAimingYaw
            bot.input.authoritativeAimingPitch = activePlayer.input.authoritativeAimingPitch
        elseif moveMode == 4 and activePlayer ~= nil then -- mirroring
            additionalMovementPossible = false
            for i = 0, 36 do
                bot.input:SetLevel(i, activePlayer.input:GetLevel(i))
            end
            bot.input.authoritativeAimingYaw = activePlayer.input.authoritativeAimingYaw + ((activePlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
            bot.input.authoritativeAimingPitch = activePlayer.input.authoritativeAimingPitch

        elseif moveMode == 5 then -- move along points
            -- get next point
            local activePointIndex = 1
            if botCurrentWayPoints[bot.name] == nil then
                botCurrentWayPoints[bot.name] = activePointIndex
            else
                activePointIndex = botCurrentWayPoints[bot.name]
                if #wayPoints[wayIndex] < activePointIndex then
                    activePointIndex = 1
                end
            end
            if #wayPoints > 0 then   -- check for reached point
                local transform = LinearTransform()
                transform = wayPoints[wayIndex][activePointIndex]
                local dy = transform.trans.z - bot.soldier.transform.trans.z
                local dx = transform.trans.x - bot.soldier.transform.trans.x
                local distanceFromTarget = math.sqrt(dx ^ 2 + dy ^ 2)
                if distanceFromTarget > 1 then
                    local yaw = (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2)
                    if swaying then
                        local swayMod = (swayElapsedTime > swayPeriod / 2) and (((swayPeriod - swayElapsedTime) / swayPeriod - 0.25) * 4) or ((swayElapsedTime / swayPeriod - 0.25) * 4)
                        local swayedYaw = yaw + swayMod * swayMaxDeviation
                        swayedYaw = (swayedYaw > 2 * math.pi) and (swayedYaw - 2 * math.pi) or swayedYaw
                        swayedYaw = (swayedYaw < 0) and (swayedYaw + 2 * math.pi) or swayedYaw
                        bot.input.authoritativeAimingYaw = swayedYaw
                    else
                        bot.input.authoritativeAimingYaw = yaw
                    end
                else  -- target reached
                    botCurrentWayPoints[bot.name] = activePointIndex + 1
                end
            end
        end

        -- additional movement
        if additionalMovementPossible then
            local speedVal = 0
            if moveMode > 0 then
                if speed == 1 then
                    speedVal = 0.25
                elseif speed == 2 then
                    speedVal = 0.5
                elseif speed >= 3 then
                    speedVal = 1.0
                end
            end

            if adading and moveMode > 0 then  -- movent sidewards
                if adadElapsedTime >= adadPeriod/2 then
                    bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, -speedVal)
                else
                    bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, speedVal)
                end
            else
                bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0)
            end

            if jumping and moveMode > 0 then
                local shouldJump = MathUtils:GetRandomInt(0, 1000)
                if shouldJump <= 15 then
                    bot.input:SetLevel(EntryInputActionEnum.EIAJump, 1.0)
                else
                    bot.input:SetLevel(EntryInputActionEnum.EIAJump, 0.0)
                end
            end

            -- movent speed
            if bot.soldier ~= nil then
                bot.input:SetLevel(EntryInputActionEnum.EIAThrottle, speedVal)
                if speed > 3 then
                    bot.input:SetLevel(EntryInputActionEnum.EIASprint, 1)
                else
                    bot.input:SetLevel(EntryInputActionEnum.EIASprint, 0)
                end
            end
        end

        -- dieing
        if dieing and activePlayer ~= nil and bot.soldier ~= nil then
            if activePlayer.soldier ~= nil then
                local dy = activePlayer.soldier.transform.trans.z - bot.soldier.transform.trans.z
                local dx = activePlayer.soldier.transform.trans.x - bot.soldier.transform.trans.x
                local distanceFromPlayer = math.sqrt(dx ^ 2 + dy ^ 2)
                if distanceFromPlayer < 1 then
                    bot.soldier:Kill()
                end
            end
        end
    end
end)

Events:Subscribe('Player:Chat', function(player, recipientMask, message)
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

    -- static commands
    if parts[1] == '!mimic' then
        moveMode = 3
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                if  isStaticBotMode(botMoveModes[name]) then
                    botMoveModes[name] = moveMode
                end
            end
        end
    elseif parts[1] == '!mirror' then
        moveMode = 4
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                if  isStaticBotMode(botMoveModes[name]) then
                    botMoveModes[name] = moveMode
                end
            end
        end
    elseif parts[1] == '!run' then
        speed = 4
    elseif parts[1] == '!walk' then
        speed = 3
    elseif parts[1] == '!jump' then
        jumping = true
    elseif parts[1] == '!nice' then
        Config.exploding = true
    elseif parts[1] == '!die' then
        dieing = true
    elseif parts[1] == '!respawn' then
        respawning = true
    elseif parts[1] == '!stoprespawn' then
        respawning = false
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                botSpawnModes[name] = 0
            end
        end

    -- create waypoints
    elseif parts[1] == '!trace' then
        local traceIndex = tonumber(parts[2]) or 1
        if traceIndex > Config.maxTraceNumber then
            traceIndex = 1
        end
        clearPoints(traceIndex)
        traceTimesGone[traceIndex] = 0
        tracePlayers[traceIndex] = player

    elseif parts[1] == '!tracedone' then
        for i = 1, Config.maxTraceNumber do
            if tracePlayers[i] == player then
                tracePlayers[i] = nil
            end
        end
    elseif parts[1] == '!setpoint' then
        local traceIndex = tonumber(parts[2]) or 1
        setPoint(traceIndex, player)
    elseif parts[1] == '!clearpoints' then
        local traceIndex = tonumber(parts[2]) or 1
        clearPoints(traceIndex)

    -- reset everything
    elseif parts[1] == '!stopall' then
        speed = 0
        moveMode = 0
        spawnMode = 0
        jumping = false
        adading = false
        swaying = false
        dieing = false
        respawning = false
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            botSpeeds[name] = speed
            botMoveModes[name] = moveMode
            botSpawnModes[name] = spawnMode
        end
    elseif '!stop' then
        speed = 0
        moveMode = 0
        spawnMode = 0
        jumping = false
        adading = false
        swaying = false
        dieing = false
        respawning = false
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                botSpeeds[name] = speed
                botMoveModes[name] = moveMode
                botSpawnModes[name] = spawnMode
            end
        end

    elseif parts[1] == '!adad' then
        adading = true
    elseif parts[1] == '!sway' then
        swaying = true
        swayMaxDeviation = tonumber(parts[2]) or 1.5
        swayPeriod = tonumber(parts[3]) or 3

    elseif parts[1] == '!stand' then
        local spacing = tonumber(parts[2]) or 2
        spawnStandingBotOnPlayer(player, spacing)

    elseif parts[1] == '!crouch' then
        local spacing = tonumber(parts[2]) or 2
        spawnCrouchingBotOnPlayer(player, spacing)

   elseif parts[1] == '!speed' then --overwrite speed for all bots
        if tonumber(parts[2]) == nil then
            return
        end
        speed = tonumber(parts[2])
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                if not isStaticBotMode(botMoveModes[name]) then
                    botSpeeds[name] = speed
                end
            end
        end

    elseif parts[1] == '!mode' then --overwrite mode for all bots
        if tonumber(parts[2]) == nil then
            return
        end
        moveMode = tonumber(parts[2])
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                botMoveModes[name] = moveMode
            end
        end

    -- set spawn team
    elseif parts[1] == '!spawnsameteam' then
        Config.spawnInSameTeam = true
    elseif parts[1] == '!spawnotherteam' then
        Config.spawnInSameTeam = false

    elseif parts[1] == '!row' then
        if tonumber(parts[2]) == nil then
            return
        end
        local rows = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        speed = 0
        moveMode = 0
        spawnBotRowOnPlayer(player, rows, spacing)

    elseif parts[1] == '!tower' then
        if tonumber(parts[2]) == nil then
            return
        end
        local height = tonumber(parts[2])
        speed = 0
        moveMode = 0
        spawnBotTowerOnPlayer(player, height)

    elseif parts[1] == '!grid' then
        if tonumber(parts[2]) == nil then
            return
        end
        speed = 0
        moveMode = 0
        local rows = tonumber(parts[2])
        local columns = tonumber(parts[3]) or tonumber(parts[2])
        local spacing = tonumber(parts[4]) or 2
        spawnBotGridOnPlayer(player, rows, columns, spacing)

    elseif parts[1] == '!john' then
        speed = 0
        moveMode = 0
        spawnJohnOnPlayer(player)

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

    elseif parts[1] == '!spawncenterpoint' then
        if tonumber(parts[2]) == nil then
            return
        end
        speed = 3
        moveMode = 1

        local amount = tonumber(parts[2])
        local duration = tonumber(parts[3]) or 10
        spawnCenterpointBots(player, amount, duration)

    elseif parts[1] == '!spawnline' then
        if tonumber(parts[2]) == nil then
            return
        end
        speed = 3
        moveMode = 2

        local amount = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        spawnLineBots(player, amount, spacing)

    elseif parts[1] == '!spawnring' then
        if tonumber(parts[2]) == nil then
            return
        end
        speed = 3
        moveMode = 2

        local amount = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 10
        spawnRingBots(player, amount, spacing)

    elseif parts[1] == '!spawnway' then
        if tonumber(parts[2]) == nil then
            return
        end
        speed = 3
        moveMode = 5
        activeWayIndex = tonumber(parts[3]) or 1

        local amount = tonumber(parts[2])
        spawnWayBots(player, amount)

    elseif parts[1] == '!kick' then
        for i = 1, Config.maxNumberOfBots do
            local name = BotNames[i]
            if botTargetPlayers[name] == player then
                kickBot(name)
            end
        end

    elseif parts[1] == '!kickall' then
        Bots:destroyAllBots()

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
end
end)

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

function setPoint(traceIndex, player)
    local transform = LinearTransform()
    transform = player.soldier.transform
    table.insert(wayPoints[traceIndex], transform)
end

function clearPoints(traceIndex)
    wayPoints[traceIndex] = {}
end

function spawnStandingBotOnPlayer(player, spacing)
    spawnMode = 0
    local yaw = player.input.authoritativeAimingYaw
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
    local name = findNextBotName()
    botTransforms[name] = transform
    botTargetPlayers[name] = player
    spawnBot(name, team, squad, transform, true)
end

function spawnCrouchingBotOnPlayer(player, spacing)
    spawnMode = 0
    local yaw = player.input.authoritativeAimingYaw
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
    local name = findNextBotName()
    botTransforms[name] = transform
    botTargetPlayers[name] = player
    spawnBot(name, team, squad, transform, true)
end

function spawnBotRowOnPlayer(player, length, spacing)
    spawnMode = 0
    for i = 1, length do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = player.input.authoritativeAimingYaw
            local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true)
        end
    end
end

function spawnBotTowerOnPlayer(player, height)
    spawnMode = 0
    for i = 1, height do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = player.input.authoritativeAimingYaw
            local transform = LinearTransform()
            transform.trans.x = player.soldier.transform.trans.x + (math.cos(yaw + (math.pi / 2)))
            transform.trans.y = player.soldier.transform.trans.y + ((i - 1) * 1.8)
            transform.trans.z = player.soldier.transform.trans.z + (math.sin(yaw + (math.pi / 2)))
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true)
        end
    end
end

function spawnBotGridOnPlayer(player, rows, columns, spacing)
    spawnMode = 0
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
                spawnBot(name, team, squad, transform, true)
            end
        end
    end
end

function spawnCenterpointBots(player, amount, duration)
    spawnMode = 1
    centerpoint = player.soldier.transform
    centerPointPeriod = duration
    centerPointElapsedTime = (duration / 4)
    for i = 1, amount do
        local name = findNextBotName()
        if name ~= nil then
            botYaws[name] = MathUtils:GetRandom(0, 2 * math.pi)
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, centerpoint, true)
            local bot = PlayerManager:GetPlayerByName(name)
            bot.input.authoritativeAimingYaw = botYaws[name]
        end
    end
end

function spawnLineBots(player, amount, spacing)
    spawnMode = 2

    for i = 1, amount do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = player.input.authoritativeAimingYaw
            local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
            botTransforms[name] = transform
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true)
        end
    end
end

function spawnRingBots(player, amount, spacing)
    spawnMode = 3
    ringNrOfBots = amount

    ringSpacing = spacing
    for i = 1, amount do
        local name = findNextBotName()
        if name ~= nil then
            local yaw = i * (2 * math.pi / amount)
            local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true)
        end
    end
end

function spawnWayBots(player, amount)
    spawnMode = 4
    for i = 1, amount do
        local name = findNextBotName()
        if name ~= nil then
            local randIdex = MathUtils:GetRandomInt(1, #wayPoints[activeWayIndex])
            botCurrentWayPoints[name] = randIdex
            local transform = LinearTransform()
            transform = wayPoints[activeWayIndex][randIdex]
            botTargetPlayers[name] = player
            spawnBot(name, team, squad, transform, true)
        end
    end
end

function spawnJohnOnPlayer(player)
    local name = findNextBotName()
    if name ~= nil then
        local yaw = player.input.authoritativeAimingYaw

        local transform = getYawOffsetTransform(player.soldier.transform, yaw, -1)
        botTargetPlayers[name] = player
        spawnBot(name, team, squad, transform, true)
        local bot = PlayerManager:GetPlayerByName(name)
        bot.input.authoritativeAimingYaw = yaw
        bot.input:SetLevel(EntryInputActionEnum.EIAFire, 1)
    end
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
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

function spawnBot(name, teamId, squadId, trans, setvars)
	local existingPlayer = PlayerManager:GetPlayerByName(name)
	local bot = nil

	if existingPlayer ~= nil then
		-- If a player with this name exists and it's not a bot then error out.
		if not Bots:isBot(existingPlayer) then
			return
		end
		bot = existingPlayer
		bot.teamId = teamId
		bot.squadId = squadId
    else
        botTimeGones[name] = 0
        bot = Bots:createBot(name, teamId, squadId)
        bot.input.flags = EntryInputFlags.AuthoritativeAiming
	end
	-- Get the default MpSoldier blueprint and the US assault kit.
	local soldierBlueprint = ResourceManager:SearchForInstanceByGuid(Guid('261E43BF-259B-41D2-BF3B-9AE4DDA96AD2'))
	local soldierKit = ResourceManager:SearchForInstanceByGuid(Guid('A15EE431-88B8-4B35-B69A-985CEA934855'))

	-- Create the transform of where to spawn the bot at.
	local transform = LinearTransform()
    transform = trans

	-- And then spawn the bot. This will create and return a new SoldierEntity object.
    Bots:spawnBot(bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})

    -- set vars
    if setvars then
        botSpawnModes[name] = spawnMode
        botSpeeds[name] = speed
        botMoveModes[name] = moveMode
        botTeams[name] = teamId
        botWayIndexes[name] = activeWayIndex

        botJumping[name] = jumping
        botAdading[name] = adading
        botSwaying[name] = swaying
        botDieing[name] = dieing
        botRespawning[name] = respawning
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
