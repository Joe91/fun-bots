local Bots = require('bots')

local maxNumberOfBots = 40
local activeWayPooints = 0

local k = 0

local BotConfig = {
    deltaTime = 0,
	moveMode = 2,
    speed = 3,
    spawnMode = 0,
    jumping = false,
    adading = false,
    swaying = false,
    updateTime = 0,
    currentPoint = 0,
    botTransform = 0,
    yaw = 0
}
local botConfigTable = {}

local moveMode = 5 --standing, centerpoint, pointing
local speed = 3 -- standing 0, proning 1, couching 2, walking 3, running 4
local spawnMode = 0 -- center 1, line 2, ring 3

local jumping = false

local adading = false
local swaying = false
local dieing = false
local exploding = false --yes
local respawning = false
local team = TeamId.Team1
local squad = SquadId.SquadNone

local activeBotCount = 0
local centerPointPeriod = 5
local centerPointElapsedTime = 0

local swayPeriod = 5
local swayElapsedTime = 0
local swayMaxDeviation = 1

local adadPeriod = 1
local adadElapsedTime = 0

local centerpoint = LinearTransform()
local activePlayer = nil
local ringSpacing = 25

local botTransforms = {}
local yaws = {}
local currentPoint = {}

local traceWay = false
local traceDelta = 0.5
local traceTimeGone = 0
local wayPoints = {}


Events:Subscribe('Level:Loaded', function(levelName, gameMode)
    print("level "..levelName.." loaded")
    --traceFile = io.open(levelName.."_"..gameMode..".lua", "a")

end)

Events:Subscribe('Player:Killed', function(player)
    if exploding then
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
    if traceWay and activePlayer and activePlayer.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then
        traceTimeGone = traceTimeGone + dt
        if traceTimeGone >= traceDelta then
            traceTimeGone = 0
            local point = LinearTransform()
            point = activePlayer.soldier.transform
            table.insert(wayPoints, point)
            activeWayPooints = activeWayPooints + 1
            --todo write position to file
        end
    end
end)

Events:Subscribe('Bot:Update', function(bot, dt)
    local botIndex = tonumber(bot.name)

    --spawning 
    if respawning and bot.soldier == nil and botIndex <= activeBotCount then
        if spawnMode == 1 then --spawnCenterpoint
            yaws[bot.name] = MathUtils:GetRandom(0, 2*math.pi)
            bot.input.authoritativeAimingYaw = yaws[bot.name]
            spawnBot(bot.name, team, squad, centerpoint)
        elseif spawnMode == 2 then  --spawnInLine
            spawnBot(bot.name, team, squad, botTransforms[bot.name])
        elseif spawnMode == 3 then  --spawnInRing around player
            if activePlayer ~= nil then
                local yaw = botIndex * (2 * math.pi / activeBotCount)
                local transform = getYawOffsetTransform(activePlayer.soldier.transform, yaw, ringSpacing)
                spawnBot(bot.name, team, squad, transform)
            end
        elseif spawnMode == 4 then --spawn on way
            local newIndex = MathUtils.GetRandomInt(1, #wayPoints)
            currentPoint[botIndex] = newIndex
            local transform = wayPoints[newIndex]
            spawnBot(bot.name, team, squad, transform)
            --todo:
        else
            spawnBot(bot.name, team, squad, botTransforms[bot.name])
        end
    end

    -- movement-mode of bots
    if bot.soldier ~= nil then
        if moveMode == 1 then -- centerpoint
            if bot.soldier ~= nil and centerPointElapsedTime <= (centerPointPeriod / 2) then
                bot.input.authoritativeAimingYaw = yaws[bot.name]
            elseif bot.soldier ~= nil then
                bot.input.authoritativeAimingYaw = (yaws[bot.name] < math.pi) and (yaws[bot.name] + math.pi) or (yaws[bot.name] - math.pi)
            end
            
        elseif moveMode == 2 and activePlayer and activePlayer.soldier then  -- pointing
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
        
        elseif moveMode == 3 and activePlayer then  -- mimicking
            for i = 0, 36 do
                bot.input:SetLevel(i, activePlayer.input:GetLevel(i))
            end
            bot.input.authoritativeAimingYaw = activePlayer.input.authoritativeAimingYaw
            bot.input.authoritativeAimingPitch = activePlayer.input.authoritativeAimingPitch
        elseif moveMode == 4 and activePlayer then -- mirroring
            for i = 0, 36 do
                bot.input:SetLevel(i, activePlayer.input:GetLevel(i))
            end
            bot.input.authoritativeAimingYaw = activePlayer.input.authoritativeAimingYaw + ((activePlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
            bot.input.authoritativeAimingPitch = activePlayer.input.authoritativeAimingPitch
            
        elseif moveMode == 5 then -- move along points
            -- get next point
            local activeWayIndex = 1
            if currentPoint[botIndex] == nil then
                currentPoint[botIndex] = activeWayIndex
            else
                activeWayIndex = currentPoint[botIndex]
                if activeWayPooints < activeWayIndex then
                    activeWayIndex = 1
                end
            end
            if activeWayPooints > 0 then   -- check for reached point
                local transform = LinearTransform()
                transform = wayPoints[activeWayIndex]
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
                    currentPoint[botIndex] = activeWayIndex + 1
                end
            end
        end

        -- additional movement
        local speedVal = 0
        if speed == 1 then
            speedVal = 0.25
        elseif speed == 2 then
            speedVal = 0.5
        elseif speed >= 3 then
            speedVal = 1.0
        end

        if adading then  -- movent sidewards
            if adadElapsedTime >= adadPeriod/2 then
                bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, -speedVal)
            else
                bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, speedVal)
            end
        else
            bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0)
        end

        if jumping then
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

        -- dieing
        if dieing and activePlayer.soldier and bot.soldier then
            local dy = activePlayer.soldier.transform.trans.z - bot.soldier.transform.trans.z
            local dx = activePlayer.soldier.transform.trans.x - bot.soldier.transform.trans.x
            local distanceFromPlayer = math.sqrt(dx ^ 2 + dy ^ 2)
            if distanceFromPlayer < 1 then
                bot.soldier:Kill()
            end
        end
    end
end)

Events:Subscribe('Player:Chat', function(player, recipientMask, message)
    local parts = string.lower(message):split(' ')

    activePlayer = player
    
    if parts[1] == '!mimic' then
        moveMode = 3
    elseif parts[1] == '!mirror' then
        moveMode = 4
    elseif parts[1] == '!point' then
        moveMode = 2
    elseif parts[1] == '!run' then
        speed = 4
    elseif parts[1] == '!walk' then
        speed = 3
    elseif parts[1] == '!jump' then
        jumping = true
    elseif parts[1] == '!nice' then
        exploding = true
    elseif parts[1] == '!die' then
        dieing = true
    elseif parts[1] == '!respawn' then
        respawning = true
    elseif parts[1] == '!trace' then
        traceWay = true
    elseif parts[1] == '!tracedone' then
        traceWay = false
        -- todo: save file possible?
    elseif parts[1] == '!setpoint' then
        setPoint(player)
    elseif parts[1] == '!clearpoints' then
        clearPoints()
    elseif parts[1] == '!stop' then
        speed = 0
        moveMode = 0
        spawnMode = 0
        jumping = false
        adading = false
        swaying = false
        dieing = false
        exploding = false
        respawning = false
    elseif parts[1] == '!adad' then
        adading = true
        for i = 1, activeBotCount do
            local name = tostring(i)
            local level = MathUtils:GetRandomInt(-1, 1)
            local bot = PlayerManager:GetPlayerByName(name)
            bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, level)
        end
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

    elseif parts[1] == '!row' then
        if tonumber(parts[2]) == nil then
            return
        end
        local rows = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        spawnBotRowOnPlayer(player, rows, spacing)

   elseif parts[1] == '!speed' then
        if tonumber(parts[2]) == nil then
            return
        end
        speed = tonumber(parts[2])

    elseif parts[1] == '!mode' then
        if tonumber(parts[2]) == nil then
            return
        end
        moveMode = tonumber(parts[2])

    elseif parts[1] == '!setteam' then
        if tonumber(parts[2]) == nil then
            return
        end
        if tonumber(parts[2]) == 1 then
            team = TeamId.Team1
        else
            team = TeamId.Team2
        end

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
                k = k + 1
                local name = tostring(k)
                spawnBot(name, team, squad, player.soldier.transform)
                local bot = PlayerManager:GetPlayerByName(name)
                bot:EnterVehicle(vehicleEntity, entryId)
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
                    k = k + 1
                    local name = tostring(k)
                    spawnBot(name, team, squad, player.soldier.transform)
                    local bot = PlayerManager:GetPlayerByName(name)
                    bot:EnterVehicle(vehicleEntity, i)
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
        local amount = tonumber(parts[2])
        spawnWayBots(player, amount)

    elseif parts[1] == '!kick' then
        Bots:destroyAllBots()
        activeBotCount = 0
        k = 0

    elseif parts[1] == '!kill' then
        k = 0
        for i = 1, activeBotCount do
            local name = tostring(i)
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

function setPoint(player)
    activeWayPooints = activeWayPooints + 1
    wayPoints[activeWayPooints] = player.soldier.transform
end

function clearPoints()
    activeWayPooints = 0
    wayPoints = {}
end

function spawnStandingBotOnPlayer(player, spacing)
    local yaw = player.input.authoritativeAimingYaw
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
    k = k + 1
    activeBotCount = k
    local name = tostring(k)
    botTransforms[name] = transform
    spawnBot(name, team, squad, transform)
end

function spawnCrouchingBotOnPlayer(player, spacing)
    local yaw = player.input.authoritativeAimingYaw
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
    k = k + 1
    activeBotCount = k
    local name = tostring(k)
    botTransforms[name] = transform
    spawnBot(name, team, squad, transform)
end

function spawnWayBots(player, amount)
    for i = 1, amount do
        local name = tostring(i)
        local newIndex = MathUtils.GetRandomInt(1, #wayPoints)
        currentPoint[i] = newIndex
        local transform = wayPoints[newIndex]
        spawnBot(name, team, squad, transform)
    end
end

function spawnBotRowOnPlayer(player, length, spacing)
    for i = 1, length do
        local name = tostring(i)
        local yaw = player.input.authoritativeAimingYaw
        local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
        spawnBot(name, team, squad, transform)
    end
end

function spawnBotTowerOnPlayer(player, height)
    for i = 1, height do
        local name = tostring(i)
        local yaw = player.input.authoritativeAimingYaw
        local transform = LinearTransform()
        transform.trans.x = player.soldier.transform.trans.x + (math.cos(yaw + (math.pi / 2)))
        transform.trans.y = player.soldier.transform.trans.y + ((i - 1) * 1.8)
        transform.trans.z = player.soldier.transform.trans.z + (math.sin(yaw + (math.pi / 2)))
        spawnBot(name, team, squad, transform)
    end
end

function spawnBotGridOnPlayer(player, rows, columns, spacing)
    for i = 1, rows do
        for j = 1, columns do
            local name = tostring((i - 1) * columns + j)
            local yaw = player.input.authoritativeAimingYaw
            local transform = LinearTransform()
            transform.trans.x = player.soldier.transform.trans.x + (i * math.cos(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.cos(yaw) * spacing)
            transform.trans.y = player.soldier.transform.trans.y
            transform.trans.z = player.soldier.transform.trans.z + (i * math.sin(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.sin(yaw) * spacing)
            spawnBot(name, team, squad, transform)
        end
    end
end

function spawnCenterpointBots(player, amount, duration)
    spawnMode = 1

    activeBotCount = amount
    centerpoint = player.soldier.transform
    centerPointPeriod = duration
    centerPointElapsedTime = (duration / 4)
    for i = 1, amount do
        local name = tostring(i)
        yaws[name] = MathUtils:GetRandom(0, 2 * math.pi)
        spawnBot(name, team, squad, centerpoint)
        local bot = PlayerManager:GetPlayerByName(name)
        bot.input.authoritativeAimingYaw = yaws[name]
    end
end

function spawnLineBots(player, amount, spacing)
    spawnMode = 2

    activeBotCount = amount
    for i = 1, amount do
        local name = tostring(i)
        local yaw = player.input.authoritativeAimingYaw
        local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
        botTransforms[name] = transform
        spawnBot(name, team, squad, transform)
    end
end

function spawnRingBots(player, amount, spacing)
    spawnMode = 3

    activeBotCount = amount
    ringSpacing = spacing
    for i = 1, amount do
        local name = tostring(i)
        local yaw = i * (2 * math.pi / amount)
        local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
        spawnBot(name, team, squad, transform)
    end
end

function spawnJohnOnPlayer(player)
    local name = "1"
    local yaw = player.input.authoritativeAimingYaw
    
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, -1)
    spawnBot(name, team, squad, transform)
    local bot = PlayerManager:GetPlayerByName(name)
    bot.input.authoritativeAimingYaw = yaw
    bot.input:SetLevel(EntryInputActionEnum.EIAFire, 1)
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function spawnBot(name, teamId, squadId, trans)
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
