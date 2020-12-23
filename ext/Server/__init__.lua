local Bots = require('bots')

local numberOfBots = 30

local soldierBlueprint = nil
local soldierKit = nil

local k = 0

local walking = false
local running = false
local jumping = false
local pointing = false

local adading = false
local swaying = false
local dieing = false
local exploding = false --yes

local mimicking = false
local mirroring = false

local spawnCenterpoint = false
local spawnInLine = false
local spawnInRing = false
local respawning = false

local direction = 0
local activeBotCount = 5
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
local rowBots = {}

Events:Subscribe('Level:Loaded', function()

    Bots:destroyAllBots()

    print("creating bots")

    soldierBlueprint = ResourceManager:SearchForInstanceByGuid(Guid('261E43BF-259B-41D2-BF3B-9AE4DDA96AD2'))
    soldierKit = ResourceManager:SearchForInstanceByGuid(Guid('A15EE431-88B8-4B35-B69A-985CEA934855'))

    for i = 1, numberOfBots do
        rowBots[i] = Bots:createBot(tostring(i), TeamId.Team1, SquadId.Squad1)
        rowBots[i].input.flags = EntryInputFlags.AuthoritativeAiming
    end
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
end)

Events:Subscribe('Bot:Update', function(bot, dt)

    if spawnAroundPoint and tonumber(bot.name) <= activeBotCount then
        if respawning and bot.soldier == nil then
            yaws[bot.name] = MathUtils:GetRandom(0, 2*math.pi)
            bot.input.authoritativeAimingYaw = yaws[bot.name]
            Bots:spawnBot(bot, centerpoint, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
        end

        if bot.soldier ~= nil and centerPointElapsedTime <= (centerPointPeriod / 2) then
            bot.input.authoritativeAimingYaw = yaws[bot.name]
        elseif bot.soldier ~= nil then
            bot.input.authoritativeAimingYaw = (yaws[bot.name] < math.pi) and (yaws[bot.name] + math.pi) or (yaws[bot.name] - math.pi)
        end

    elseif spawnInLine and tonumber(bot.name) <= activeBotCount then
        if respawning and bot.soldier == nil then
            Bots:spawnBot(bot, botTransforms[bot.name], CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
        end

    elseif spawnInRing and tonumber(bot.name) <= activeBotCount then
        if respawning and bot.soldier == nil then
            local yaw = tonumber(bot.name) * (2 * math.pi / activeBotCount)
            local transform = getYawOffsetTransform(activePlayer.soldier.transform, yaw, ringSpacing)
            Bots:spawnBot(bot, transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
        end

    elseif respawning and bot.soldier == nil and tonumber(bot.name) <= activeBotCount then
        Bots:spawnBot(bot, botTransforms[tonumber(bot.name)], CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
    end

    if mimicking then
        for i = 0, 36 do
            bot.input:SetLevel(i, activePlayer.input:GetLevel(i))
        end

        bot.input.authoritativeAimingYaw = activePlayer.input.authoritativeAimingYaw
        bot.input.authoritativeAimingPitch = activePlayer.input.authoritativeAimingPitch

    elseif mirroring then
        for i = 0, 36 do
            bot.input:SetLevel(i, activePlayer.input:GetLevel(i))
        end

        bot.input.authoritativeAimingYaw = activePlayer.input.authoritativeAimingYaw + ((activePlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
        bot.input.authoritativeAimingPitch = activePlayer.input.authoritativeAimingPitch

    elseif pointing and activePlayer.soldier and bot.soldier then
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

    if adading then
        if adadElapsedTime >= adadPeriod/2 then
            bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, -1.0)
        else
            bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, 1.0)
        end
    else
        bot.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0)
    end

    if walking then
        if bot.soldier ~= nil then
            bot.input:SetLevel(EntryInputActionEnum.EIAThrottle, 1)
            bot.input:SetLevel(EntryInputActionEnum.EIASprint, 0)
        end
    elseif running then
        if bot.soldier ~= nil then
            bot.input:SetLevel(EntryInputActionEnum.EIAThrottle, 1)
            bot.input:SetLevel(EntryInputActionEnum.EIASprint, 1)
        end
    else
        if bot.soldier ~= nil then
            bot.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0)
            bot.input:SetLevel(EntryInputActionEnum.EIASprint, 0)
        end
    end

    if jumping then
        local shouldJump = MathUtils:GetRandomInt(0, 1000)
        if shouldJump <= 15 then
            bot.input:SetLevel(EntryInputActionEnum.EIAJump, 1.0)
        else
            bot.input:SetLevel(EntryInputActionEnum.EIAJump, 0.0)
        end
    end

    if dieing and activePlayer.soldier and bot.soldier then
        local dy = activePlayer.soldier.transform.trans.z - bot.soldier.transform.trans.z
        local dx = activePlayer.soldier.transform.trans.x - bot.soldier.transform.trans.x
        local distanceFromPlayer = math.sqrt(dx ^ 2 + dy ^ 2)
        if distanceFromPlayer < 1 then
            bot.soldier:Kill()
        end
    end
end)

Events:Subscribe('Player:Chat', function(player, recipientMask, message)
    local parts = string.lower(message):split(' ')

    activePlayer = player

    if parts[1] == '!mimic' then
        pointing = false
        mimicking = true
        mirroring = false
        spawnCenterpoint = false
        spawnInLine = false
        spawnInRing = false
    elseif parts[1] == '!mirror' then
        pointing = false
        mimicking = false
        mirroring = true
        spawnCenterpoint = false
        spawnInLine = false
        spawnInRing = false
    elseif parts[1] == '!point' then
        pointing = true
        mimicking = false
        mirroring = false
        spawnCenterpoint = false
        spawnInLine = false
        spawnInRing = false
    elseif parts[1] == '!run' then
        walking = false
        running = true
    elseif parts[1] == '!walk' then
        walking = true
        running = false
    elseif parts[1] == '!jump' then
        jumping = true
    elseif parts[1] == '!nice' then
        exploding = true
    elseif parts[1] == '!die' then
        dieing = true
    elseif parts[1] == '!respawn' then
        respawning = true
    elseif parts[1] == '!stop' then
        walking = false
        running = false
        jumping = false
        pointing = false
        adading = false
        swaying = false
        dieing = false
        exploding = false
        mimicking = false
        mirroring = false
        spawnCenterpoint = false
        spawnInLine = false
        spawnInRing = false
        respawning = false
    elseif parts[1] == '!adad' then
        adading = true
        for i = 1, activeBotCount do
            local level = MathUtils:GetRandomInt(-1, 1)
            rowBots[i].input:SetLevel(EntryInputActionEnum.EIAStrafe, level)
        end
    elseif parts[1] == '!sway' then
        pointing = true
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
        spawnBotGridOnPlayer(player, rows, columns)

    elseif parts[1] == '!john' then
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
                Bots:spawnBot(rowBots[k], player.soldier.transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
                rowBots[k]:EnterVehicle(vehicleEntity, entryId)
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
                    Bots:spawnBot(rowBots[k], player.soldier.transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
                    rowBots[k]:EnterVehicle(vehicleEntity, i)
                end
            end
            vehicleEntity = iterator:Next()
        end

    elseif parts[1] == '!spawncenterpoint' then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        local duration = tonumber(parts[3]) or 10
        spawnCenterpointBots(player, amount, duration)

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

    elseif parts[1] == '!kill' then
        k = 0
        for i = 1, numberOfBots do
            if rowBots[i].soldier ~= nil then
                rowBots[i].soldier:Kill()
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

function spawnStandingBotOnPlayer(player, spacing)
    local yaw = player.input.authoritativeAimingYaw
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
    k = k + 1
    botTransforms[k] = transform
    activeBotCount = k
    Bots:spawnBot(rowBots[k], transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
end

function spawnCrouchingBotOnPlayer(player, spacing)
    local yaw = player.input.authoritativeAimingYaw
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
    k = k + 1
    botTransforms[k] = transform
    activeBotCount = k
    Bots:spawnBot(rowBots[k], transform, CharacterPoseType.CharacterPoseType_Crouch, soldierBlueprint, soldierKit, {})
end

function spawnBotRowOnPlayer(player, length, spacing)
    for i = 1, length do
        local yaw = player.input.authoritativeAimingYaw
        local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
        Bots:spawnBot(rowBots[i], transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
    end
end

function spawnBotTowerOnPlayer(player, height)
    for i = 1, height do
        local yaw = player.input.authoritativeAimingYaw
        local transform = LinearTransform()
        transform.trans.x = player.soldier.transform.trans.x + (math.cos(yaw + (math.pi / 2)))
        transform.trans.y = player.soldier.transform.trans.y + ((i - 1) * 1.8)
        transform.trans.z = player.soldier.transform.trans.z + (math.sin(yaw + (math.pi / 2)))
        Bots:spawnBot(rowBots[i], transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
    end
end

function spawnBotGridOnPlayer(player, rows, columns)
    for i = 1, rows do
        for j = 1, columns do
            local yaw = player.input.authoritativeAimingYaw
            local transform = LinearTransform()
            transform.trans.x = player.soldier.transform.trans.x + (i * math.cos(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.cos(yaw) * spacing)
            transform.trans.y = player.soldier.transform.trans.y
            transform.trans.z = player.soldier.transform.trans.z + (i * math.sin(yaw + (math.pi / 2)) * spacing) + ((j - 1) * math.sin(yaw) * spacing)
            Bots:spawnBot(rowBots[(i - 1) * columns + j], transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
        end
    end
end

function spawnCenterpointBots(player, amount, duration)
    mimicking = false
    mirroring = false
    pointing = false
    spawnInLine = false
    spawnInRing = false
    spawnCenterpoint = true
    walking = true

    activeBotCount = amount
    centerpoint = player.soldier.transform
    centerPointPeriod = duration
    centerPointElapsedTime = (duration / 4)

    for i = 1, amount do
        yaws[rowBots[i].name] = MathUtils:GetRandom(0, 2 * math.pi)
        rowBots[i].input.authoritativeAimingYaw = yaws[rowBots[i].name]
        Bots:spawnBot(rowBots[i], centerpoint, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
    end
end

function spawnLineBots(player, amount, spacing)
    mimicking = false
    mirroring = false
    spawnCenterpoint = false
    spawnInRing = false
    pointing = true
    spawnInLine = true
    walking = true

    activeBotCount = amount
    for i = 1, amount do
        local yaw = player.input.authoritativeAimingYaw
        local transform = getYawOffsetTransform(player.soldier.transform, yaw, i * spacing)
        botTransforms[rowBots[i].name] = transform
        Bots:spawnBot(rowBots[i], transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
    end
end

function spawnRingBots(player, amount, spacing)
    mimicking = false
    mirroring = false
    spawnCenterpoint = false
    spawnInLine = false
    pointing = true
    walking = true
    spawnInRing = true

    activeBotCount = amount
    ringSpacing = spacing
    for i = 1, amount do
        local yaw = i * (2 * math.pi / amount)
        local transform = getYawOffsetTransform(player.soldier.transform, yaw, spacing)
        Bots:spawnBot(rowBots[i], transform, CharacterPoseType.CharacterPoseType_Stand, soldierBlueprint, soldierKit, {})
    end
end

function spawnJohnOnPlayer(player)
    local yaw = player.input.authoritativeAimingYaw
    local transform = getYawOffsetTransform(player.soldier.transform, yaw, -1)
    Bots:spawnBot(rowBots[numberOfBots], transform, CharacterPoseType.CharacterPoseType_Crouch, soldierBlueprint, soldierKit, {})
    rowBots[numberOfBots].input.authoritativeAimingYaw = yaw
    rowBots[numberOfBots].input:SetLevel(EntryInputActionEnum.EIAFire, 1)
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end