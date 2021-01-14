class('FunBotServer')
require('__shared/config')
local BotManager = require('botManager')
local TraceManager = require('traceManager')
local BotSpawner = require('botSpawner')

function FunBotServer:__init()
    Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)
    Events:Subscribe('Player:Chat', self, self._onChat)

    NetEvents:Subscribe('keypressF5', self, self._onF5)
    NetEvents:Subscribe('keypressF6', self, self._onF6)
    NetEvents:Subscribe('keypressF7', self, self._onF7)
    NetEvents:Subscribe('keypressF8', self, self._onF8)
    NetEvents:Subscribe('keypressF9', self, self._onF9)
    NetEvents:Subscribe('keypressF10', self, self._onF10)
    NetEvents:Subscribe('keypressF11', self, self._onF11)
    NetEvents:Subscribe('keypressF12', self, self._onF12)
	
	NetEvents:Subscribe('spawnbots', self, self._uispawnbots)
	NetEvents:Subscribe('spawnrandombot', self, self._uispawnrandombot)
	NetEvents:Subscribe('kickallbots', self, self._uikickallbots)
	NetEvents:Subscribe('respawnbots', self, self._uibotrespawn)
end

--webui events -Bitcrusher

--spawn bots
function FunBotServer:_uispawnbots(player, spawnbots)
    local amount = tonumber(spawnbots)
    BotSpawner:spawnWayBots(player, amount, true)
    print(player.name .." spawning ".. spawnbots .." bot/s")
end

function FunBotServer:_uispawnrandombot(player, spawnbots)
    print("spawnrandombot - it worked!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
end

function FunBotServer:_uikickallbots(player, spawnbots)
    BotManager:destroyAllBots()
    print("Kicking Bots")
end

function FunBotServer:_uibotrespawn(player, spawnbots)
    BotManager:setOptionForAll("respawn", true)
    print("Bots will respawn")
end

function FunBotServer:_onLevelLoaded(levelName, gameMode)
    print("level "..levelName.." loaded...")
    TraceManager:onLevelLoaded(levelName, gameMode)
    BotSpawner:onLevelLoaded()
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
        BotManager:setStaticOption(player, "mode", 3)

    elseif parts[1] == '!mirror' then
        BotManager:setStaticOption(player, "mode", 4)

    elseif parts[1] == '!static' then
        BotManager:setStaticOption(player, "mode", 0)

    -- moving bots spawning
    elseif parts[1] == '!spawnline' then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        local spacing = tonumber(parts[3]) or 2
        BotSpawner:spawnLineBots(player, amount, spacing)

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

    elseif parts[1] == "!spawnbots" then
        if tonumber(parts[2]) == nil then
            return
        end
        local amount = tonumber(parts[2])
        BotSpawner:spawnWayBots(player, amount, true)

    -- respawn moving bots
    elseif parts[1] == '!respawn' then
        local respawning = true
        if tonumber(parts[2]) == 0 then
            respawning = false
        end
        Config.respawnWayBots = respawning
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

    elseif parts[1] == '!setbotcolor' then
        local botColor = tonumber(parts[2]) or 1
        if botColor <= #Colors and botColor >= 0 then
            Config.botColor = botColor
        end

    elseif parts[1] == '!setaim' then
        Config.deviationAdditionFactor = tonumber(parts[2]) or 1.0
    elseif parts[1] == '!bullet' then
        Config.bulletDamageBot = tonumber(parts[2]) or 1
    elseif parts[1] == '!sniper' then
        Config.bulletDamageBotSniper = tonumber(parts[2]) or 1
    elseif parts[1] == '!melee' then
        Config.meleeDamageBot = tonumber(parts[2]) or 1
    elseif parts[1] == '!shootback' then
        if tonumber(parts[2]) == 0 then
            Config.shootBackIfHit = false
        else
            Config.shootBackIfHit = true
        end
    elseif parts[1] == '!attackmelee' then
        if tonumber(parts[2]) == 0 then
            Config.meleeAttackIfClose = false
        else
            Config.meleeAttackIfClose = true
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

    elseif parts[1] == '!kickplayer' then
        BotManager:destroyPlayerBots(player)

    elseif parts[1] == '!kick' then
        local amount = tonumber(parts[2]) or 1
        BotManager:destroyAmount(amount)

    elseif parts[1] == '!kickteam' then
        local teamToKick = tonumber(parts[2]) or 1
        if teamToKick < 1 or teamToKick > 2 then
            return
        end
        local teamId = teamToKick == 1 and TeamId.Team1 or TeamId.Team2
        BotManager:destroyTeam(teamId)

    elseif parts[1] == '!kickall' then
        BotManager:destroyAllBots()

    elseif parts[1] == '!kill' then
        BotManager:killPlayerBots(player)

    elseif parts[1] == '!killall' then
        BotManager:killAll()

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
		ChatManager:Yell("!printtrans check server console", 2.5)
        print(player.soldier.worldTransform)
        print(player.soldier.worldTransform.trans.x)
        print(player.soldier.worldTransform.trans.y)
        print(player.soldier.worldTransform.trans.z)

    elseif parts[1] == '!savepaths' then
        TraceManager:savePaths()
    end
end

--Key pressess instead of commands -Bitcrusher
--Bot waypoint keys
function FunBotServer:_onF5(player, data)
	print(player.name .." pressed F5")
	local traceIndex = tonumber(0)
	TraceManager:startTrace(player, traceIndex)
end
function FunBotServer:_onF6(player, data)
	print(player.name .." pressed F6")
	TraceManager:endTrace(player)
end
function FunBotServer:_onF7(player, data)
	print(player.name .." pressed F7")
	local traceIndex = tonumber(0)
    TraceManager:clearTrace(traceIndex)
end
function FunBotServer:_onF8(player, data)
	print(player.name .." pressed F8")
	TraceManager:clearAllTraces()
end
function FunBotServer:_onF9(player, data)
	print(player.name .." pressed F9")
	TraceManager:savePaths()
end
function FunBotServer:_onF10(player, data)
	print(player.name .." pressed F10")
end
function FunBotServer:_onF11(player, data)
	print(player.name .." pressed F11")
end
function FunBotServer:_onF12(player, data)
	print(player.name .." pressed F12")
end
--Key pressess instead of commands -Bitcrusher


function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end


-- Singleton.
if g_FunBotServer == nil then
	g_FunBotServer = FunBotServer()
end

return g_FunBotServer