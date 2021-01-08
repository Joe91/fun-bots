require('__shared/Config')
local BotManager = require('botManager')

-- vars for each bot
local botSpawnModes = {}
local botCheckSwapTeam = {}
local botSpawnDelayTime = {}
local botSpeeds = {}
local botMoveModes = {}
local botTimeGones = {}
local botTargetPlayers = {}
local botTransforms = {}
local botCurrentWayPoints = {}
local botWayIndexes = {}
local botWayWaitTimes = {}

local botJumpTargetPoint = {}
local botJumpTriggerDistance = {}
local botLastWayDistance = {}
local botObstacleSequenceTimer = {}
local botObstacleRetryCounter = {}

local botTeams = {}
local botRespawning = {}
local botKits = {}
local botColors = {}
local botShooting = {}
local botShootPlayer = {}
local botShootTimer = {}
local botShootModeTimer = {}

-- vars for all bots
local dieing = false
local respawning = false
local team = TeamId.Team1
local squad = SquadId.SquadNone

local ringSpacing = 25
local ringNrOfBots = 0

local activeTraceIndexes = 0
local tracePlayers = {}
local traceTimesGone = {}
local traceWaitTime = {}
local wayPoints = {}
local mapName = ""
local fovHalf = Config.fovForShooting / 360 * math.pi * 2 / 2

for i = 1, Config.maxTraceNumber do
    wayPoints[i] = {}
end

--let users know of F1 key -Bictcrusher

Events:Subscribe("Player:TeamChange", function(player, team, squad)
    if player == nil then
        print("player has no name")
    else
        ChatManager:SendMessage("Welcome " .. player.name .. " press F1 key for some information", player)
    end
end)

--let users know of F1 key -Bictcrusher

NetEvents:Subscribe('BotShootAtPlayer', function(player, botname)
    local bot = PlayerManager:GetPlayerByName(botname)
    if bot == nil or bot.soldier == nil or player.soldier == nil then
        return
    end
    local oldYaw = bot.input.authoritativeAimingYaw
    local dy = player.soldier.transform.trans.z - bot.soldier.transform.trans.z
    local dx = player.soldier.transform.trans.x - bot.soldier.transform.trans.x
    local yaw = (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2)

    local dYaw = math.abs(oldYaw-yaw)
    if dYaw > math.pi then
        dYaw =math.pi * 2 - dYaw
    end

    if dYaw < fovHalf or ignoreYaw then
        if botShooting[botname] then
            if botShootModeTimer[botname] == nil or botShootModeTimer[botname] > 1 then
                botShootModeTimer[botname] = 0
                botShootPlayer[botname] = player
                botShootTimer[botname] = 0
            end
        else
            botShootModeTimer[botname] = Config.botFireModeDuration
        end
    end
end)

NetEvents:Subscribe('DamagePlayer', function(player, damage, shooterName)
    if player.soldier ~= nil then
        player.soldier.health = player.soldier.health - damage
    end
    --TODO: Increase Killcount of Bot, if health <= 0 ?
end)

Events:Subscribe('Player:Left', function(player)
    --remove all references
    for i = 1, Config.maxNumberOfBots do
        local botname = BotNames[i]
        if botShootPlayer[botname] == player then
            botShootPlayer[botname] = nil
        end
        if botTargetPlayers[botname] == player then
            botTargetPlayers[botname] = nil
        end
    end
end)

Events:Subscribe('Level:Loaded', function(levelName, gameMode)
    print("level "..levelName.." in Gamemode "..gameMode.." loaded")
    mapName = levelName.."_"..gameMode
    loadWayPoints()
    print(tostring(activeTraceIndexes).." paths have been loaded")
    Bots:destroyAllBots()
    -- create initial bots
    if activeTraceIndexes > 0 and Config.spawnOnLevelstart then
        local listOfVars = {
            spawnMode = 5,
            speed = 3,
            moveMode = 5,
            activeWayIndex = 0,
            respawning = true,
            shooting = true
        }
        for i = 1, Config.initNumberOfBots do
            createInitialBots(BotNames[i], team, squad, listOfVars)
        end
    end
    checkSwapBotTeams()
end)

Events:Subscribe('Engine:Update', function(dt)
    --trace way if wanted
    for i = 1, Config.maxTraceNumber do
        if tracePlayers[i] ~= nil then
            traceTimesGone[i] = traceTimesGone[i] + dt
            if traceTimesGone[i] >= Config.traceDelta then
                traceTimesGone[i] = 0
                local player = tracePlayers[i]

                local MoveMode = 0 -- 0 = wait, 1 = prone ... (4 Bits)
                local MoveAddon = 0 -- 0 = nothing, 1 = jump ... (4 Bits)
                local vlaue = 0 -- waittime in 0.5 s (0-255) (8 Bits)

                local point = {trans = Vec3(), inputVar = 0x0}
                point.trans = player.soldier.transform.trans

                --trace movement with primary weapon
                if player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_0 then
                    traceWaitTime[i] = 0
                    if player.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then --record only if moving
                        if tracePlayers[i].soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
                            MoveMode = 1
                        elseif tracePlayers[i].soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
                            MoveMode = 2
                        else
                            MoveMode = 3
                            if player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
                                MoveMode = 4
                            end
                        end

                        if player.input:GetLevel(EntryInputActionEnum.EIAJump) == 1 then
                            MoveAddon = 1
                        end
                        
                        local inputVar = MoveMode + (MoveAddon << 4) + (vlaue << 8)
                        point.inputVar = inputVar
                        table.insert(wayPoints[i], point)
                    end
                -- trace wait time with secondary weapon
                elseif player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_1 then
                    if traceWaitTime[i] == 0 or traceWaitTime[i] == nil then
                        traceWaitTime[i] = 0
                        table.insert(wayPoints[i], point)
                    end
                    traceWaitTime[i] =  traceWaitTime[i] + Config.traceDelta
                    local inputVar = 0 + (math.floor(tonumber(traceWaitTime[i])) & 0xFF) << 8
                    wayPoints[i][#wayPoints[i]].inputVar = inputVar
                end
            end
        end
    end
end)

Events:Subscribe('Bot:Update', function(bot, dt)
    -- increase performance with reduced update cycles
    local timeGone = botTimeGones[bot.name] + dt
    if timeGone < Config.botUpdateCycle then
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

    local respawning = botRespawning[bot.name]
    local shooting = botShooting[bot.name]

    --spawning 
    if respawning and bot.soldier == nil and spawnMode > 0 then
        -- wait for respawn-delay gone
        if botSpawnDelayTime[bot.name] < Config.spawnDelayBots then
            botSpawnDelayTime[bot.name] = botSpawnDelayTime[bot.name] + Config.botUpdateCycle
            return
        end
        -- check for swap of team on levelstart
        local setvarsOnRespawn = false
        if botCheckSwapTeam[bot.name] then
            botCheckSwapTeam[bot.name] = false
            setvarsOnRespawn = true
            if bot.teamId ~= botTeams[bot.name] then
                botTeams[bot.name] = bot.teamId
                team = bot.teamId
            end
        end
        local listOfVars = {
            spawnMode = spawnMode,
            speed = speed,
            moveMode = moveMode,
            activeWayIndex = wayIndex,
            respawning = respawning,
            shooting = shooting
        }

        if spawnMode == 2 then  --spawnInLine
            spawnBot(bot.name, team, squad, botTransforms[bot.name], setvarsOnRespawn, listOfVars)

        elseif spawnMode == 3 then  --spawnInRing around player
            if activePlayer ~= nil then
                if activePlayer.soldier  ~= nil then
                    local yaw = botIndex * (2 * math.pi / ringNrOfBots)
                    local transform = getYawOffsetTransform(activePlayer.soldier.transform, yaw, ringSpacing)
                    spawnBot(bot.name, team, squad, transform, setvarsOnRespawn, listOfVars)
                end
            end

        elseif spawnMode == 4 then --spawn on way
            local randIdex = MathUtils:GetRandomInt(1, #wayPoints[wayIndex])
            botCurrentWayPoints[bot.name] = randIdex
            local transform = LinearTransform()
            transform.trans = wayPoints[wayIndex][randIdex].trans
            spawnBot(bot.name, team, squad, transform, setvarsOnRespawn, listOfVars)

        elseif spawnMode == 5 then --spawn on random way
            local newWayIdex = getNewWayIndex()
            if newWayIdex ~= 0 then
                local randIdex = MathUtils:GetRandomInt(1, #wayPoints[newWayIdex])
                botCurrentWayPoints[bot.name] = randIdex
                local transform = LinearTransform()
                transform.trans = wayPoints[newWayIdex][randIdex].trans
                botWayIndexes[bot.name] = newWayIdex
                listOfVars.activeWayIndex = newWayIdex
                wayIndex = newWayIdex
                spawnBot(bot.name, team, squad, transform, setvarsOnRespawn, listOfVars)
            end
        else
            spawnBot(bot.name, team, squad, botTransforms[bot.name], false)
        end
    end

    -- shooting
    if shooting and bot.soldier ~= nil then  --and not isStaticBotMode(moveMode) then
        if botShootPlayer[bot.name] ~= nil and botShootPlayer[bot.name].soldier ~= nil then
            local shootAt = botShootPlayer[bot.name]
            if botShootModeTimer[bot.name] < Config.botFireModeDuration then
                botShootModeTimer[bot.name] = botShootModeTimer[bot.name] + Config.botUpdateCycle
                -- move slower
                if speed > 0 then
                    speed = speed - 1
                end
                moveMode = 9 -- continue last movement
                --calculate yaw and pith
                local dz = shootAt.soldier.transform.trans.z - bot.soldier.transform.trans.z
                local dx = shootAt.soldier.transform.trans.x - bot.soldier.transform.trans.x
                local dy = shootAt.soldier.transform.trans.y + getCameraHight(shootAt.soldier) - bot.soldier.transform.trans.y - getCameraHight(bot.soldier)
                local yaw = (math.atan(dz, dx) > math.pi / 2) and (math.atan(dz, dx) - math.pi / 2) or (math.atan(dz, dx) + 3 * math.pi / 2)
                --calculate pitch
                local distance = shootAt.soldier.transform.trans:Distance(bot.soldier.transform.trans)
                local pitch = math.asin(dy / distance)
                bot.input.authoritativeAimingPitch = pitch
                bot.input.authoritativeAimingYaw = yaw
                
                bot.input:SetLevel(EntryInputActionEnum.EIAZoom, 1)

                if botShootTimer[bot.name] >= (Config.botFireDuration + Config.botFirePause) then
                    botShootTimer[bot.name] = 0
                end
                if botShootTimer[bot.name] >= Config.botFireDuration then
                    bot.input:SetLevel(EntryInputActionEnum.EIAFire, 0)
                else
                    bot.input:SetLevel(EntryInputActionEnum.EIAFire, 1)
                end
                botShootTimer[bot.name] = botShootTimer[bot.name] + Config.botUpdateCycle

            else
                bot.input:SetLevel(EntryInputActionEnum.EIAFire, 0)
                botShootPlayer[bot.name] = nil
            end
        else
            bot.input:SetLevel(EntryInputActionEnum.EIAZoom, 0)
            bot.input:SetLevel(EntryInputActionEnum.EIAFire, 0)
            botShootPlayer[bot.name] = nil
            botShootModeTimer[bot.name] = nil
        end
    end

    -- movement-mode of bots
    if bot.soldier ~= nil then
        if moveMode == 2 and activePlayer ~= nil then
            if activePlayer.soldier  ~= nil then  -- pointing
                local dy = activePlayer.soldier.transform.trans.z - bot.soldier.transform.trans.z
                local dx = activePlayer.soldier.transform.trans.x - bot.soldier.transform.trans.x
                local yaw = (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2)
                bot.input.authoritativeAimingYaw = yaw
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
            if wayPoints[wayIndex][1] ~= nil then   -- check for reached point
                local inputVar = wayPoints[wayIndex][activePointIndex].inputVar
                if (inputVar & 0x000F) > 0 then -- movement
                    botWayWaitTimes[bot.name] = 0
                    speed = inputVar & 0x000F  --speed
                    local trans = Vec3()
                    trans = wayPoints[wayIndex][activePointIndex].trans
                    local dy = trans.z - bot.soldier.transform.trans.z
                    local dx = trans.x - bot.soldier.transform.trans.x
                    local distanceFromTarget = math.sqrt(dx ^ 2 + dy ^ 2)

                    --detect obstacle and move over or around TODO: Move before normal jump
                    local currentWayPontDistance = math.abs(trans.x - bot.soldier.transform.trans.x) + math.abs(trans.z - bot.soldier.transform.trans.z)
                    if currentWayPontDistance >= botLastWayDistance[bot.name] or botObstacleSequenceTimer[bot.name] ~= 0 then
                        -- try to get around obstacle
                        speed = 3 --always stand
                        if botObstacleSequenceTimer[bot.name] == 0 then  --step 0
                            bot.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                            bot.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        elseif botObstacleSequenceTimer[bot.name] > 1.0 then  --step 4 - repeat afterwards
                            bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0)
                            botObstacleSequenceTimer[bot.name] = 0.1
                            botObstacleRetryCounter[bot.name] = botObstacleRetryCounter[bot.name] + 1
                        elseif botObstacleSequenceTimer[bot.name] > 0.6 then  --step 3
                            bot.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                            bot.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                            bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, 1.0)
                        elseif botObstacleSequenceTimer[bot.name] > 0.4 then --step 2
                            bot.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                            bot.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        elseif botObstacleSequenceTimer[bot.name] > 0.0 then --step 1
                            bot.input:SetLevel(EntryInputActionEnum.EIAJump, 1)
                            bot.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
                        end
                        botObstacleSequenceTimer[bot.name] = botObstacleSequenceTimer[bot.name] + Config.botUpdateCycle

                        if botObstacleRetryCounter[bot.name] >= 2 then --tried twice, try next waypoint
                            botObstacleRetryCounter[bot.name] = 0
                            distanceFromTarget = 0
                        end
                    else
                        botLastWayDistance[bot.name] = currentWayPontDistance
                        bot.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                        bot.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0)
                    end

                    -- jup on command
                    if ((inputVar & 0x00F0) >> 4) == 1 and botJumpTargetPoint[bot.name] == nil then
                        botJumpTargetPoint[bot.name] = trans
                        botJumpTriggerDistance[bot.name] = math.abs(trans.x - bot.soldier.transform.trans.x) + math.abs(trans.z - bot.soldier.transform.trans.z)
                    elseif botJumpTargetPoint[bot.name] ~= nil then
                        local currentJumpDistance = math.abs(botJumpTargetPoint[bot.name].x - bot.soldier.transform.trans.x) + math.abs(botJumpTargetPoint[bot.name].z - bot.soldier.transform.trans.z)
                        if currentJumpDistance > botJumpTriggerDistance[bot.name] then
                            --now we are really close to the Jump-Point --> Jump
                            bot.input:SetLevel(EntryInputActionEnum.EIAJump, 1)
                            bot.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
                            botJumpTargetPoint[bot.name] = nil
                        else
                            botJumpTriggerDistance[bot.name] = currentJumpDistance
                        end
                    else
                        bot.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        bot.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                    end
                         
                    if distanceFromTarget > 1 then
                        local yaw = (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2)
                        bot.input.authoritativeAimingYaw = yaw
                    else  -- target reached
                        botCurrentWayPoints[bot.name] = activePointIndex + 1
                        botObstacleSequenceTimer[bot.name] = 0
                        botLastWayDistance[bot.name] = 1000
                    end
                else -- wait mode
                    botWayWaitTimes[bot.name] = botWayWaitTimes[bot.name] + Config.botUpdateCycle
                    speed = 0
                    -- TODO: Move yaw while waiting?
                    if  botWayWaitTimes[bot.name] > (inputVar >> 8) then
                        botCurrentWayPoints[bot.name] = activePointIndex + 1
                        botWayWaitTimes[bot.name] = 0
                    end
                end
            end
        end

        -- additional movement
        if additionalMovementPossible then
            local speedVal = 0
            if moveMode > 0 then
                if speed == 1 then
                    speedVal = 1.0
                    if bot.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
                        bot.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
                    end
                elseif speed == 2 then
                    speedVal = 1.0
                    if bot.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
                        bot.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
                    end
                elseif speed >= 3 then
                    speedVal = 1.0
                    if bot.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
                        bot.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
                    end
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
        local rows = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        spawnBotRowOnPlayer(player, rows, spacing)

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

function createInitialBots(name, teamId, squadId, listOfVars) 
    local existingPlayer = PlayerManager:GetPlayerByName(name)
	local bot = nil

    if existingPlayer ~= nil then
        bot = existingPlayer
		bot.teamId = teamId
		bot.squadId = squadId
    else
        botTimeGones[name] = 0
        bot = Bots:createBot(name, teamId, squadId)
        bot.input.flags = EntryInputFlags.AuthoritativeAiming
    end

    --set vars
    botSpawnDelayTime[name] = 0.0
    botSpawnModes[name] = listOfVars.spawnMode
    botSpeeds[name] = listOfVars.speed
    botMoveModes[name] = listOfVars.moveMode
    botTeams[name] = teamId
    botWayIndexes[name] = listOfVars.activeWayIndex
    botRespawning[name] = listOfVars.respawning
    botShooting[name] = listOfVars.shooting

    local botColor = Colors[Config.botColor]
    local kitNumber = Config.botKit
    if Config.botColor == 0 then
        botColor = Colors[MathUtils:GetRandomInt(1, #Colors)]
    end
    if kitNumber == 0 then
        kitNumber = MathUtils:GetRandomInt(1, 4)
    end
    botColors[name] = botColor
    botKits[name] = kitNumber
end

-- Tries to find first available kit
-- @param teamName string Values: 'US', 'RU'
-- @param kitName string Values: 'Assault', 'Engineer', 'Support', 'Recon'
function findKit(teamName, kitName)

    local gameModeKits = {
        '', -- Standard
        '_GM', --Gun Master on XP2 Maps
        '_GM_XP4', -- Gun Master on XP4 Maps
        '_XP4', -- Copy of Standard for XP4 Maps
        '_XP4_SCV' -- Scavenger on XP4 Maps
    }

    for kitType=1, #gameModeKits do
        local properKitName = string.lower(kitName)
        properKitName = properKitName:gsub("%a", string.upper, 1)

        local fullKitName = string.upper(teamName)..properKitName..gameModeKits[kitType]
        local kit = ResourceManager:SearchForDataContainer('Gameplay/Kits/'..fullKitName)
        if kit ~= nil then
            return kit
        end
    end

    return
end

function spawnBot(name, teamId, squadId, trans, setvars, listOfVars)
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

    local botColor = Colors[Config.botColor]
    local kitNumber = Config.botKit
    if setvars or Config.botNewLoadoutOnSpawn then
        if Config.botColor == 0 then
            botColor = Colors[MathUtils:GetRandomInt(1, #Colors)]
        end
        if kitNumber == 0 then
            kitNumber = MathUtils:GetRandomInt(1, 4)
        end
        botColors[name] = botColor
        botKits[name] = kitNumber
    else
        botColor = botColors[name]
        kitNumber = botKits[name]
    end

    -- Create the loadouts
    local m1911 = ResourceManager:SearchForDataContainer('Weapons/M1911/U_M1911_Tactical')
    local knife = ResourceManager:SearchForDataContainer('Weapons/Knife/U_Knife')

	local soldierCustomization = CustomizeSoldierData()
	soldierCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	soldierCustomization.removeAllExistingWeapons = true

    local primaryWeapon = UnlockWeaponAndSlot()
    primaryWeapon.slot = WeaponSlot.WeaponSlot_0

    local gadget01 = UnlockWeaponAndSlot()
    gadget01.slot = WeaponSlot.WeaponSlot_2

    local gadget02 = UnlockWeaponAndSlot()
    gadget02.slot = WeaponSlot.WeaponSlot_5

	local secondaryWeapon = UnlockWeaponAndSlot()
	secondaryWeapon.weapon = SoldierWeaponUnlockAsset(m1911)
    secondaryWeapon.slot = WeaponSlot.WeaponSlot_1

	local meleeWeapon = UnlockWeaponAndSlot()
	meleeWeapon.weapon = SoldierWeaponUnlockAsset(knife)
    meleeWeapon.slot = WeaponSlot.WeaponSlot_7
    
    -- create loadouts
    local function setAttachments(unlockWeapon, attachments)
		for _, attachment in pairs(attachments) do
			local unlockAsset = UnlockAsset(ResourceManager:SearchForDataContainer(attachment))
			unlockWeapon.unlockAssets:add(unlockAsset)
		end
	end
    if kitNumber == 1 then --assault
        local m416 = ResourceManager:SearchForDataContainer('Weapons/M416/U_M416')
        local m416Attachments = { 'Weapons/M416/U_M416_Kobra', 'Weapons/M416/U_M416_Silencer' }
        primaryWeapon.weapon = SoldierWeaponUnlockAsset(m416)
        setAttachments(primaryWeapon, m416Attachments)
        gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Medicbag/U_Medkit'))
        gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Defibrillator/U_Defib'))
        
    elseif kitNumber == 2 then --engineer
        local asval = ResourceManager:SearchForDataContainer('Weapons/ASVal/U_ASVal')
        local asvalAttachments = { 'Weapons/ASVal/U_ASVal_Kobra', 'Weapons/ASVal/U_ASVal_ExtendedMag' }
        primaryWeapon.weapon = SoldierWeaponUnlockAsset(asval)
        setAttachments(primaryWeapon, asvalAttachments)
        gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Repairtool/U_Repairtool'))
        gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/SMAW/U_SMAW'))

    elseif kitNumber == 3 then --support
        local m249 = ResourceManager:SearchForDataContainer('Weapons/M249/U_M249')
        local m249Attachments = { 'Weapons/M249/U_M249_Eotech', 'Weapons/M249/U_M249_Bipod' }
        primaryWeapon.weapon = SoldierWeaponUnlockAsset(m249)
        setAttachments(primaryWeapon, m249Attachments)
        gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Ammobag/U_Ammobag'))
        gadget02.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/Claymore/U_Claymore'))
        
    else    --recon
        local l96 = ResourceManager:SearchForDataContainer('Weapons/XP1_L96/U_L96')
        local l96Attachments = { 'Weapons/XP1_L96/U_L96_Rifle_6xScope' }
        primaryWeapon.weapon = SoldierWeaponUnlockAsset(l96)
        setAttachments(primaryWeapon, l96Attachments)
        gadget01.weapon = SoldierWeaponUnlockAsset(ResourceManager:SearchForDataContainer('Weapons/Gadgets/RadioBeacon/U_RadioBeacon'))
        --no second gadget
    end

    -- create kit and appearance
    local soldierBlueprint = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier')
    local soldierKit = nil
    local appearance = nil

    if teamId == TeamId.Team1 then -- US
        if kitNumber == 1 then --assault
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Assault_Appearance_'..botColor)
            soldierKit = findKit('US', 'Assault')
        elseif kitNumber == 2 then --engineer
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Engi_Appearance_'..botColor)
            soldierKit = findKit('US', 'Engineer')
        elseif kitNumber == 3 then --support
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Support_Appearance_'..botColor)
            soldierKit = findKit('US', 'Support')
        else    --recon
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Recon_Appearance_'..botColor)
            soldierKit = findKit('US', 'Recon')
        end
    else -- RU
        if kitNumber == 1 then --assault
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Assault_Appearance_'..botColor)
            soldierKit = findKit('RU', 'Assault')
        elseif kitNumber == 2 then --engineer
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Engi_Appearance_'..botColor)
            soldierKit = findKit('RU', 'Engineer')
        elseif kitNumber == 3 then --support
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Support_Appearance_'..botColor)
            soldierKit = findKit('RU', 'Support')
        else    --recon
            appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Recon_Appearance_'..botColor)
            soldierKit = findKit('RU', 'Recon')
        end
    end

	-- Create the transform of where to spawn the bot at.
	local transform = LinearTransform()
    transform = trans

    botSpawnDelayTime[name] = 0.0
    botObstacleSequenceTimer[bot.name] = 0
    botObstacleRetryCounter[bot.name] = 0
    botLastWayDistance[bot.name] = 1000
    botShootPlayer[name] = nil
    botShootModeTimer[name] = nil
	-- And then spawn the bot. This will create and return a new SoldierEntity object.
    Bots:spawnBot(bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, { appearance })

    soldierCustomization.weapons:add(primaryWeapon)
    soldierCustomization.weapons:add(secondaryWeapon)
    soldierCustomization.weapons:add(gadget01)
    soldierCustomization.weapons:add(gadget02)
	soldierCustomization.weapons:add(meleeWeapon)
    bot.soldier:ApplyCustomization(soldierCustomization)
    
    --bot.soldier.weaponsComponent.currentWeapon.primaryAmmo = 9999 --magazine Size
    bot.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 9999
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.minDispersionAngle = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.dispersionAngle = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.randomAngle = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.randomRadius = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.suppressionMinDispersionAngleFactor = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.gunSway.crossHairDispersionFactor = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.recoilAngleZ = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.recoilAngleY = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.recoilAngleX = 0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.recoilTimer = 0.0
    bot.soldier.weaponsComponent.currentWeapon.weaponFiring.recoilFovAngle = 0

    -- set vars
    if setvars then
        botCheckSwapTeam[name] = false
        botTeams[name] = teamId
        botSpawnModes[name] = listOfVars.spawnMode
        botSpeeds[name] = listOfVars.speed
        botMoveModes[name] = listOfVars.moveMode
        botWayIndexes[name] = listOfVars.activeWayIndex
        botRespawning[name] = listOfVars.respawning
        botShooting[name] = listOfVars.shooting
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

function getCameraHight(soldier)
    local camereaHight = 1.6 --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand
    if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
        camereaHight = 0.3
    elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
        camereaHight = 1.0
    end
    return camereaHight
end


