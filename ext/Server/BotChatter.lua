-- ext/Server/BotChatter.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- Core server logic for modular bot chatter
-- Packs, personalities, distortion & config are under:
--   __shared/BotChatterConfig.lua
--   ext/Server/BotChatter/{PackLoader.lua, Personalities.lua, Distort.lua, Util.lua, Packs/*.lua}

local rnd = math.random

-- ====== Module imports ======
local ChatCfg        = require('__shared/BotChatterConfig')
local PackLoader     = require('BotChatter/PackLoader')
local Personalities  = require('BotChatter/Personalities')
local Distort        = require('BotChatter/Distort')
local Util           = require('BotChatter/Util')

-- Try to read BOT_TOKEN (for bot detection fallback)
local BOT_TOKEN = ""
pcall(function()
  local ok, reg = pcall(require, '__shared/Registry/Registry')
  if ok and reg and reg.COMMON and reg.COMMON.BOT_TOKEN ~= nil then
    BOT_TOKEN = reg.COMMON.BOT_TOKEN or ""
  end
end)

-- ====== Local state ======
local ActiveDefaultPack = PackLoader.Load(ChatCfg.defaultPack)
local LoadedPacks       = { [ActiveDefaultPack.id] = ActiveDefaultPack }

local levelLoaded = false
local roundStartDone = false

-- Kill/multi/streak/revenge tracking
local lastSpeak     = {}  -- [botName] = { onKill=ts, onDeath=ts, onSpawn=ts, onSpecial=ts }
local lastKillTime  = {}  -- [botName] = timestamp of last kill
local multiCount    = {}  -- [botName] = multi count within window
local streakCount   = {}  -- [botName] = kills since last death
local lastKillerOf  = {}  -- [victimName] = killerName (for Revenge detection)
local Rate = {}           -- per-bot spam control: [botName] = { times = {t1,t2,...} }

-- ====== Utility ======
local function now() return SharedUtils:GetTime() end
local function pick(tbl) return tbl[rnd(#tbl)] end

local VIS = { Global = 0, Team = 1, Squad = 2 }

local function visibilityKeyToEnum(key)
  if key == "team"  then return VIS.Team end
  if key == "squad" then return VIS.Squad end
  return VIS.Global
end

local function isBot(p)
  if p == nil then return false end
  if p.onlineId == 0 then return true end  -- Fun-Bots signature
  if p.isBot == true then return true end
  if BOT_TOKEN ~= "" and p.name then
    if string.sub(p.name, 1, #BOT_TOKEN) == BOT_TOKEN then
      return true
    end
  end
  return false
end

local function getPackById(id)
  if LoadedPacks[id] then return LoadedPacks[id] end
  local p = PackLoader.Load(id)
  LoadedPacks[p.id] = p
  return p
end

local _packCache = {}
local function packForName(name)
  if not ChatCfg.allowPerBotPackByTag then return ActiveDefaultPack end
  if _packCache[name] then return _packCache[name] end
  local upper = (name or ""):upper()
  for tag, packId in pairs(ChatCfg.tagToPack) do
    if upper:find(tag:upper(), 1, true) == 1 then
      local p = getPackById(packId)
      _packCache[name] = p
      return p
    end
  end
  _packCache[name] = ActiveDefaultPack
  return ActiveDefaultPack
end

-- Personality selection
local personas = { "Chill", "Cocky", "Tactical", "Sassy" }
local personaFor = {}

local function pickPersonality(botName)
  local pack = packForName(botName)
  local bias = (pack and pack.PersonalityBias) or {}

  if ChatCfg.personalityMode == "single" then
    return ChatCfg.forcedPersonality or "Tactical"
  end

  if ChatCfg.personalityMode == "seeded" then
    if not personaFor[botName] then
      -- build weighted list once per bot, using bias
      local weights = { Chill = 1, Cocky = 1, Tactical = 1, Sassy = 1 }
      for k,v in pairs(bias) do weights[k] = math.max(0.01, (weights[k] or 1) * v) end
      -- deterministic pick
      local h = Util.simple_hash(botName or "BOT", ChatCfg.seed or 1337)
      local total = (weights.Chill or 0) + (weights.Cocky or 0) + (weights.Tactical or 0) + (weights.Sassy or 0)
      local roll = (h % 10000) / 10000 * total
      local acc = 0
      for _,key in ipairs({"Chill","Tactical","Cocky","Sassy"}) do
        acc = acc + (weights[key] or 0)
        if roll <= acc then personaFor[botName] = key; break end
      end
      personaFor[botName] = personaFor[botName] or "Tactical"
    end
    return personaFor[botName]
  end

  -- randomEachEvent with bias
  local weights = { Chill = 1, Cocky = 1, Tactical = 1, Sassy = 1 }
  for k,v in pairs(bias) do weights[k] = math.max(0.01, (weights[k] or 1) * v) end
  local total = 0; for _,k in ipairs({"Chill","Tactical","Cocky","Sassy"}) do total = total + (weights[k] or 0) end
  local roll = math.random() * total; local acc = 0
  for _,k in ipairs({"Chill","Tactical","Cocky","Sassy"}) do acc = acc + (weights[k] or 0); if roll <= acc then return k end end
  return "Tactical"
end

-- Rate-limit per bot (anti-spam)
local function rateAllow(botName)
  local conf = ChatCfg.rateLimit or { windowSec = 8, maxPerWindow = 2 }
  local win  = conf.windowSec or 8
  local maxN = conf.maxPerWindow or 2
  local tnow = now()

  Rate[botName] = Rate[botName] or { times = {} }
  local times = Rate[botName].times

  -- prune old
  local j = 1
  for i=1,#times do if tnow - times[i] <= win then times[j] = times[i]; j = j + 1 end end
  for k=j,#times do times[k] = nil end

  if #times >= maxN then return false end
  times[#times+1] = tnow
  return true
end

-- Cooldown per category (legacy, per-bot)
local function canSpeak(name, category)
  if not name then return false end
  lastSpeak[name] = lastSpeak[name] or {}
  local cdMap = {
    onKill    = 10,
    onDeath   = 12,
    onSpawn   = 20,
    onSpecial = 8
  }
  local cd = cdMap[category] or cdMap.onSpecial
  local last = lastSpeak[name][category] or -1e9
  if now() - last >= cd then
    lastSpeak[name][category] = now()
    return true
  end
  return false
end

-- Line selection (pack + personality + optional named variants)
local function chooseFrom(category, botName, enemyName, preferNamed)
  local pack     = packForName(botName)
  local persona  = pickPersonality(botName)

  local base     = (pack.Lines and pack.Lines[category]) or (ActiveDefaultPack.Lines and ActiveDefaultPack.Lines[category]) or {}
  local personaL = (Personalities[persona] and Personalities[persona][category]) or {}

  local namedText = nil
  if preferNamed and enemyName then
    local namedKey  = category .. "Named"
    local namedBase = (pack.Lines and pack.Lines[namedKey]) or (ActiveDefaultPack.Lines and ActiveDefaultPack.Lines[namedKey])
    if namedBase and #namedBase > 0 and rnd() < 0.33 then
      namedText = pick(namedBase):gsub("{enemy}", enemyName)
    end
  end

  if namedText then
    return namedText, pack
  end

  local pool = Util.merge_arrays(base, personaL, nil)
  if #pool == 0 then return nil, pack end
  return pick(pool), pack
end

-- Distortion + casing
local function finalizeLine(raw, pack)
  raw = raw or ""
  local casing = (pack.Tweaks and pack.Tweaks.casing) or (ActiveDefaultPack.Tweaks and ActiveDefaultPack.Tweaks.casing) or "lower"
  if casing == "lower" then raw = raw:lower() end
  raw = Distort.apply(raw, ChatCfg.distort, pack.Tweaks)
  return raw
end

local function humanName(p)
  if not p then return "" end
  return p.name or ""
end

-- Vehicle kill heuristic
local function isVehicleKill(weapon, roadKill)
  if roadKill then return true end
  local lw = string.lower(tostring(weapon or ""))
  local hints = {
    "tank","mbt","ifv","lav","apc","buggy","jeep","vodnik","humvee","boat",
    "jet","f18","f-18","su-","mig","flanker","hornet",
    "heli","helicopter","ah-","ka-","z-11","viper","havoc","littlebird","scout",
    "stationary","aa","igla","stinger"
  }
  for _,h in ipairs(hints) do
    if string.find(lw, h, 1, true) then return true end
  end
  return false
end

-- Longshot (distance) check - robust & VU-friendly
local function isLongshot(inflictor, victimPos)
  -- Guard: VU gives a Vec3 here; ensure it's sane
  if not victimPos or victimPos.x == nil then
    return false
  end

  -- Try to get the killer's current world position.
  -- On server, soldier is the safest source.
  local pos = nil
  local ok = pcall(function()
    if inflictor ~= nil and inflictor.soldier ~= nil and inflictor.soldier.worldTransform ~= nil then
      pos = inflictor.soldier.worldTransform.trans -- Vec3
    end
  end)
  if not ok or pos == nil then
    return false
  end

  -- Vec3 has no :Length(); use .magnitude or :Distance()
  local d = (pos - victimPos).magnitude
  return d >= 80.0 -- ~80m threshold
end

-- tiny one-shot timer
local _Timers = {}
local function Timer(sec, fn) table.insert(_Timers, {t = now() + sec, fn = fn}) end
Events:Subscribe('Engine:Update', function()
  if #_Timers == 0 then return end
  local t = now()
  for i = #_Timers, 1, -1 do
    if t >= _Timers[i].t then
      local fn = _Timers[i].fn
      table.remove(_Timers, i)
      pcall(fn)
    end
  end
end)

-- reset per-round state helper to avoid drift
local function resetRoundState()
  lastSpeak, lastKillTime, multiCount, streakCount, lastKillerOf, Rate = {}, {}, {}, {}, {}, {}
  _packCache, personaFor = {}, {}
  roundStartDone = false
end

-- ====== Server->Client emitter ======
local function sendLine(text, speakerPlayer, visKey)
  local name = "SERVER"
  local teamId = TeamId.Team1
  local squadId = SquadId.SquadNone
  if speakerPlayer and speakerPlayer.name then name = speakerPlayer.name end
  if speakerPlayer and speakerPlayer.teamId ~= nil then teamId = speakerPlayer.teamId end
  if speakerPlayer and speakerPlayer.squadId ~= nil then squadId = speakerPlayer.squadId end
  local vis = visibilityKeyToEnum(visKey or "global")
  NetEvents:BroadcastUnreliable('BotChatter:Say', name, text, vis, teamId, squadId)
end

-- ====== Round lifecycle ======
Events:Subscribe('Extension:Loaded', function()
  math.randomseed(os.time() % 2147483647)
end)

Events:Subscribe('Level:Loaded', function()
  levelLoaded = true
  resetRoundState()

  -- Round start: try a few times to find any bot so we can attribute the line
  local tries = 8
  for i = 1, tries do
    Timer(i, function()
      if not levelLoaded or roundStartDone then return end
      local all = PlayerManager:GetPlayers()
      local speaker
      for _, p in ipairs(all) do if isBot(p) then speaker = p; break end end
      if speaker then
        local botName = humanName(speaker)
        if rateAllow(botName) and canSpeak(botName, 'onSpecial') then
          local line, pack = chooseFrom('RoundStartGlobal', botName, nil, false)
          if line then
            sendLine(finalizeLine(line, pack), speaker, "global")
            roundStartDone = true
          end
        end
      end
    end)
  end
end)

Events:Subscribe('Level:Destroy', function()
  if not levelLoaded then return end
  levelLoaded = false

  -- Round end
  local all = PlayerManager:GetPlayers()
  local speaker = nil
  for _, p in ipairs(all) do if isBot(p) then speaker = p; break end end
  if speaker then
    local botName = humanName(speaker)
    if rateAllow(botName) and canSpeak(botName, 'onSpecial') then
      local line, pack = chooseFrom('RoundEndGlobal', botName, nil, false)
      if line then sendLine(finalizeLine(line, pack), speaker, "global") end
    end
  end
  resetRoundState()
end)

-- ====== Events ======
-- Spawn
Events:Subscribe('Player:Respawn', function(player)
  if not levelLoaded or not isBot(player) then return end
  local botName = humanName(player)
  if rateAllow(botName) and canSpeak(botName, 'onSpawn') then
    local line, pack = chooseFrom('Spawn', botName, nil, false)
    if line then sendLine(finalizeLine(line, pack), player, "team") end
  end
end)

-- Vehicle enter/exit (light noise, rate-limited by onSpecial)
Events:Subscribe('Vehicle:Enter', function(vehicle, player)
  if not levelLoaded or not isBot(player) then return end
  local botName = humanName(player)
  if rateAllow(botName) and canSpeak(botName, 'onSpecial') then
    local line, pack = chooseFrom('VehEnter', botName, nil, false)
    if line then sendLine(finalizeLine(line, pack), player, "team") end
  end
end)

Events:Subscribe('Vehicle:Exit', function(vehicle, player)
  if not levelLoaded or not isBot(player) then return end
  local botName = humanName(player)
  if rateAllow(botName) and canSpeak(botName, 'onSpecial') then
    local line, pack = chooseFrom('VehExit', botName, nil, false)
    if line then sendLine(finalizeLine(line, pack), player, "team") end
  end
end)

-- Kills
Events:Subscribe('Player:Killed',
function(victim, inflictor, position, weapon, roadKill, headshot, victimInRevive)
  if not levelLoaded then return end

  -- Track last killer for revenge
  if victim and inflictor then
    lastKillerOf[humanName(victim)] = humanName(inflictor)
  end

  -- Reset victim streak if victim is bot
  if isBot(victim) and victim.name then
    streakCount[victim.name] = 0
  end

  -- Only emit chatter for bot killer
  if not isBot(inflictor) then return end
  local killer      = inflictor
  local knameHuman  = humanName(killer)                 -- shown as speaker (keeps tag)
  local victimHuman = humanName(victim)                 -- shown if needed (keeps tag)
  local victimMention = Util.strip_tags(victimHuman)    -- used in {enemy} substitutions
  local wpn         = tostring(weapon or "")
  local tnow        = now()

  -- Anti-spam guard first
  if not rateAllow(knameHuman) then return end

  -- Multi-kill tracking
  local isMulti = false
  multiCount[knameHuman] = multiCount[knameHuman] or 0
  if lastKillTime[knameHuman] and (tnow - lastKillTime[knameHuman] <= 6.0) then
    multiCount[knameHuman] = multiCount[knameHuman] + 1
    isMulti = (multiCount[knameHuman] >= 2)
  else
    multiCount[knameHuman] = 1
  end
  lastKillTime[knameHuman] = tnow

  -- Streak tracking
  streakCount[knameHuman] = (streakCount[knameHuman] or 0) + 1
  local hitStreak = (streakCount[knameHuman] == 6)

  local said = false

  -- Priority 1: multi-kill
  if isMulti and canSpeak(knameHuman, 'onSpecial') then
    local cat = (multiCount[knameHuman] >= 4) and 'Multi4' or (multiCount[knameHuman] == 3 and 'Multi3' or 'Multi2')
    local line, pack = chooseFrom(cat, knameHuman, victimMention, false)
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
      said = true
    end
  end

  -- Priority 2: revenge (if victim previously killed this bot recently)
  if not said and victim and victim.name then
    local killerOfMe = lastKillerOf[knameHuman]
    if killerOfMe and killerOfMe == victimHuman and canSpeak(knameHuman, 'onSpecial') then
      local line, pack = chooseFrom('Revenge', knameHuman, victimMention, true)
      if line then
        sendLine(finalizeLine(line, pack), killer, "global")
        said = true
      end
    end
  end

  -- Priority 3: headshot
  if not said and headshot and canSpeak(knameHuman, 'onSpecial') then
    local long = isLongshot(killer, position)
    local cat  = long and 'Longshot' or 'Headshot'
    local line, pack = chooseFrom(cat, knameHuman, victimMention, true)
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
      said = true
    end
  end

  -- Priority 4: vehicle/roadkill
  if not said and isVehicleKill(weapon, roadKill) and canSpeak(knameHuman, 'onSpecial') then
    local cat = roadKill and 'Roadkill' or 'VehicleKill'
    local line, pack = chooseFrom(cat, knameHuman, victimMention, true)
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
      said = true
    end
  end

  -- Priority 5: streak hype (doesn't block normal kill)
  if hitStreak and canSpeak(knameHuman, 'onSpecial') then
    local line, pack = chooseFrom('Streak', knameHuman, nil, false)
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
      -- (no 'said = true'; allow regular kill line too)
    end
  end

  -- Fallback: generic kill (occasionally named)
  if canSpeak(knameHuman, 'onKill') then
    local line, pack = chooseFrom('Kill', knameHuman, victimMention, true)
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
    end
  end
end)

-- Optional simple command to switch default pack at runtime: !bcpack PackId
Events:Subscribe('Player:Chat', function(p, mask, msg)
  msg = tostring(msg or "")
  if msg:sub(1,8) == "!bcpack " then
    local want = msg:sub(9):gsub("%s+$","")
    ActiveDefaultPack = PackLoader.Reload(want)
    LoadedPacks = { [ActiveDefaultPack.id] = ActiveDefaultPack } -- reset cache
    ChatManager:Yell("BotChatter pack: " .. ActiveDefaultPack.id, 3.0)
  end
end)
