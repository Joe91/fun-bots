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
local Util           = require('__shared/BotChatter/Util')  -- promoted to Shared

local norm = Util.normalize_name_for_mentions

-- Try to read BOT_TOKEN (for bot detection fallback)
local BOT_TOKEN = ""
-- Optional hard override from Registry (admin/server-level)
local ENABLE_OVERRIDE = nil
pcall(function()
  local ok, reg = pcall(require, '__shared/Registry/Registry')
  if ok and reg and reg.COMMON and reg.COMMON.BOT_TOKEN ~= nil then
    BOT_TOKEN = reg.COMMON.BOT_TOKEN or ""
  end
  -- If present, this wins over ChatCfg.enabled (kinda useful for server presets)
  if ok and reg and reg.COMMON and reg.COMMON.BOT_CHATTER_ENABLED ~= nil then
    ENABLE_OVERRIDE = reg.COMMON.BOT_CHATTER_ENABLED and true or false
  end
end)

-- ===== NEW: local normaliser =====
-- --- inline prefix scrubber (BOT_TOKEN + [TAG]/(TAG)/{TAG}) -------------------
local function _esc(s) return (s:gsub("([^%w])","%%%1")) end
local TOK = BOT_TOKEN or ""
local TOK_ESC   = (TOK ~= "" and _esc(TOK)) or nil      -- e.g. "BOT%_"
local TOK_ESC_L = TOK_ESC and TOK_ESC:lower() or nil    -- e.g. "bot%_"

-- ====== NEW: Chat frequency levels config ======
local LEVELS = {
  billiard = { rateMult = 0.5, cdMult = 1.6, multiWindow = 4.0, namedProb = 0.15, replyProb = 0.15 },
  cafe     = { rateMult = 1.0, cdMult = 1.0, multiWindow = 6.0, namedProb = 0.33, replyProb = 0.28 },
  twitch   = { rateMult = 1.7, cdMult = 0.6, multiWindow = 8.0, namedProb = 0.50, replyProb = 0.40 },
}
local function levelConf()
  local key = tostring(ChatCfg.chatterLevel or "cafe"):lower()
  return LEVELS[key] or LEVELS.cafe
end

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
-- Helper to check if chatter is currently enabled
local function bc_enabled()
  if ENABLE_OVERRIDE ~= nil then return ENABLE_OVERRIDE end
  return ChatCfg.enabled ~= false
end

local function now() return SharedUtils:GetTime() end
local function pick(tbl) return tbl[rnd(#tbl)] end

local VIS = { Global = 0, Team = 1, Squad = 2 }

local function visibilityKeyToEnum(key)
  if key == "team"  then return VIS.Team end
  if key == "squad" then return VIS.Squad end
  return VIS.Global
end

-- Send overlay fallbacks incase ChatManager.Yell does nothing
local function announce(text, dur)
  dur = dur or 3.0

  -- Preferred: ServerChatManager on server
  local ok = false
  if ServerChatManager and ServerChatManager.Yell then
    local ok1 = pcall(function() ServerChatManager:Yell(text, dur) end)
    if ok1 then ok = true end
  end

  -- Legacy/alt: ChatManager (sometimes client-only; keep as fallback)
  if not ok and ChatManager and ChatManager.Yell then
    local ok2 = pcall(function() ChatManager:Yell(text, dur) end)
    if ok2 then ok = true end
  end

  -- RCON fallback (works on dedicated)
  if not ok and RCON and RCON.SendCommand then
    local ok3 = pcall(function()
      local d = tostring(math.floor(dur + 0.5))
      RCON:SendCommand('server.yell', { text, d, 'all' })
    end)
    if not ok3 then
      ok3 = pcall(function() RCON:SendCommand('server.say', { text, 'all' }) end)  -- promoted to ok3 variable
    end
    ok = ok3   -- <-- only mark success if one of these actually worked
  end

  -- Absolute last resort: overlay (only if currently enabled)
  if not ok and bc_enabled() then
    -- neutral/global message via your own channel
    pcall(function()
      NetEvents:BroadcastUnreliable('BotChatter:Say', "SERVER", text, VIS.Global, TeamId.Team1, SquadId.SquadNone)
    end)
  end
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
  local prof = levelConf()  -- NEW: chat frequency levels
  local win  = conf.windowSec or 8
  local maxN = math.max(1, math.floor((conf.maxPerWindow or 2) * prof.rateMult + 0.0001))  -- NEW: chat frequency levels
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
  local prof = levelConf()  -- NEW: chat frequency levels
  local cdMap = {
    onKill    = 10,
    onDeath   = 12,
    onSpawn   = 20,
    onSpecial = 8
  }
  local base = cdMap[category] or cdMap.onSpecial  -- NEW: chat frequency levels
  local cd   = base * (prof.cdMult or 1.0)  -- NEW: chat frequency levels
  local last = lastSpeak[name][category] or -1e9
  if now() - last >= cd then
    lastSpeak[name][category] = now()
    return true
  end
  return false
end

-- chooseFrom: pack + persona + optional named line
-- returns (text, pack, usedNamed:boolean)
local function chooseFrom(category, botName, enemyName, preferNamed)
  local prof    = levelConf()
  local pack    = packForName(botName)
  local persona = pickPersonality(botName)

  local base     = (pack.Lines and pack.Lines[category]) or
                   (ActiveDefaultPack.Lines and ActiveDefaultPack.Lines[category]) or {}
  local personaL = (Personalities[persona] and Personalities[persona][category]) or {}

  if preferNamed and enemyName then
    local namedKey  = category .. "Named"
    local namedBase = (pack.Lines and pack.Lines[namedKey]) or
                      (ActiveDefaultPack.Lines and ActiveDefaultPack.Lines[namedKey])
    local namedProb = (prof and prof.namedProb) or 0.33
    if namedBase and #namedBase > 0 and rnd() < namedProb then
      local enemyClean = norm(enemyName)                 -- strip BOT_TOKEN + clan tags
      local txt = pick(namedBase):gsub("{enemy}", enemyClean)
      txt = txt:gsub("%s+", " "):gsub(" %.", "."):gsub(" ,", ",")
      return txt, pack, true
    end
  end

  local pool = Util.merge_arrays(base, personaL, nil)
  if #pool == 0 then return nil, pack, false end
  return pick(pool), pack, false
end

-- NEW: chooseReply - victim/bystander replies (with named variants)
-- returns (text, pack)
local function chooseReply(category, botName, enemyName, preferNamed)
  local prof = levelConf()
  local pack = packForName(botName)

  local base  = (pack.Replies and pack.Replies[category]) or
                (ActiveDefaultPack.Replies and ActiveDefaultPack.Replies[category]) or {}
  local named = (pack.RepliesNamed and pack.RepliesNamed[category]) or
                (ActiveDefaultPack.RepliesNamed and ActiveDefaultPack.RepliesNamed[category]) or {}

  if preferNamed and enemyName and #named > 0 then
    local namedProb = (prof and prof.namedProb) or 0.33
    if rnd() < namedProb then
      local enemyClean = norm(enemyName)                 -- strip BOT_TOKEN + clan tags
      return pick(named):gsub("{enemy}", enemyClean), pack
    end
  end

  if #base > 0 then return pick(base), pack end
  return nil, pack
end

-- finalizeLine: scrub -> casing -> distort
local function finalizeLine(raw, pack)
  raw = raw or ""
  -- defense-in-depth: nuke any inline BOT_TOKEN or [TAG]/(TAG)/{TAG} that slipped into the text
  raw = Util.scrub_inline_prefixes(raw)

  local casing = (pack.Tweaks and pack.Tweaks.casing) or
                 (ActiveDefaultPack.Tweaks and ActiveDefaultPack.Tweaks.casing) or "lower"
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
  if not bc_enabled() then
    -- if disabled, drain timers quickly and do nothing
    if #_Timers > 0 then _Timers = {} end
    return
  end
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
  if not bc_enabled() then return end  -- kill early
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
  if not bc_enabled() then return end  -- kill early
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
  if not bc_enabled() or not levelLoaded or not isBot(player) then return end  -- added bc_enabled conditional
  local botName = humanName(player)
  if rateAllow(botName) and canSpeak(botName, 'onSpawn') then
    local line, pack = chooseFrom('Spawn', botName, nil, false)
    if line then sendLine(finalizeLine(line, pack), player, "team") end
  end
end)

-- Vehicle enter/exit (light noise, rate-limited by onSpecial)
Events:Subscribe('Vehicle:Enter', function(vehicle, player)
  if not bc_enabled() or not levelLoaded or not isBot(player) then return end  -- added bc_enabled conditional
  local botName = humanName(player)
  if rateAllow(botName) and canSpeak(botName, 'onSpecial') then
    local line, pack = chooseFrom('VehEnter', botName, nil, false)
    if line then sendLine(finalizeLine(line, pack), player, "team") end
  end
end)

Events:Subscribe('Vehicle:Exit', function(vehicle, player)
  if not bc_enabled() or not levelLoaded or not isBot(player) then return end  -- added bc_enabled conditional
  local botName = humanName(player)
  if rateAllow(botName) and canSpeak(botName, 'onSpecial') then
    local line, pack = chooseFrom('VehExit', botName, nil, false)
    if line then sendLine(finalizeLine(line, pack), player, "team") end
  end
end)

-- Kills
Events:Subscribe('Player:Killed',
function(victim, inflictor, position, weapon, roadKill, headshot, victimInRevive)
  if not bc_enabled() or not levelLoaded then return end  -- added bc_enabled conditional

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
  local killer         = inflictor
  local knameHuman     = humanName(killer)              -- shown as speaker (keeps tag)
  local victimHuman    = humanName(victim)              -- shown if needed (keeps tag)
  local victimMention  = norm(victimHuman)  -- NEW: strip both bot token AND tag
  local killerMention  = norm(knameHuman)  -- NEW: strip both bot token AND tag
  local wpn            = tostring(weapon or "")
  local tnow           = now()
  local prof           = levelConf()  -- NEW: chat frequency levels

  -- Anti-spam guard first
  if not rateAllow(knameHuman) then return end

  -- Multi-kill tracking
  local isMulti = false
  multiCount[knameHuman] = multiCount[knameHuman] or 0
  local chainWindow = prof.multiWindow or 6.0  -- NEW: chat frequency levels
  if lastKillTime[knameHuman] and (tnow - lastKillTime[knameHuman] <= chainWindow) then  -- NEW: chat frequency levels
    multiCount[knameHuman] = multiCount[knameHuman] + 1
    isMulti = (multiCount[knameHuman] >= 2)
  else
    multiCount[knameHuman] = 1
  end
  lastKillTime[knameHuman] = tnow

  -- Streak tracking
  streakCount[knameHuman] = (streakCount[knameHuman] or 0) + 1
  local hitStreak = (streakCount[knameHuman] == 6)

  local said, usedNamedAny = false, false  -- NEW: usedNamedAny: for reply boost

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
  local wasRevenge = false   -- NEW: Bot response update
  if not said and victim and victim.name then
    local killerOfMe = lastKillerOf[knameHuman]
    if killerOfMe and killerOfMe == victimHuman and canSpeak(knameHuman, 'onSpecial') then
      local line, pack, usedNamed = chooseFrom('Revenge', knameHuman, victimMention, true)   -- NEW: Bot response update
      if line then
        sendLine(finalizeLine(line, pack), killer, "global")
        said, wasRevenge, usedNamedAny = true, true, (usedNamedAny or usedNamed)   -- NEW: Bot response update
      end
    end
  end

  -- Priority 3: headshot / longshot
  local wasLong = false   -- NEW: Bot response update
  if not said and headshot and canSpeak(knameHuman, 'onSpecial') then
    local long = isLongshot(killer, position); wasLong = long   -- NEW: Bot response update
    local cat  = long and 'Longshot' or 'Headshot'
    local line, pack, usedNamed = chooseFrom(cat, knameHuman, victimMention, true)   -- NEW: Bot response update
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
      said, usedNamedAny = true, (usedNamedAny or usedNamed)   -- NEW: Bot response update
    end
  end

  -- Priority 4: vehicle/roadkill
  local wasRoad = false   -- NEW: Bot response update
  if not said and isVehicleKill(weapon, roadKill) and canSpeak(knameHuman, 'onSpecial') then
    wasRoad = roadKill and true or false   -- NEW: Bot response update
    local cat = roadKill and 'Roadkill' or 'VehicleKill'
    local line, pack, usedNamed = chooseFrom(cat, knameHuman, victimMention, true)   -- NEW: Bot response update
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
      said, usedNamedAny = true, (usedNamedAny or usedNamed)   -- NEW: Bot response update
    end
  end

  -- Priority 5: streak hype (doesn't block normal kill)
  if hitStreak and canSpeak(knameHuman, 'onSpecial') then
    local line, pack = chooseFrom('Streak', knameHuman, nil, false)
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
    end
  end

  -- Fallback: generic kill (occasionally named)
  if canSpeak(knameHuman, 'onKill') then
    local line, pack, usedNamed = chooseFrom('Kill', knameHuman, victimMention, true)   -- NEW: Bot response update
    if line then
      sendLine(finalizeLine(line, pack), killer, "global")
      usedNamedAny = usedNamedAny or usedNamed   -- NEW: Bot response update
    end
  end

  -- ======================
  -- NEW: Bot response update (victim + bystander)
  -- ======================
  -- Helper: pick one random bot on a team (excluding some names)
  local function pickRandomBotOnTeam(teamId, exclude)
    exclude = exclude or {}
    local pool = {}
    for _, p in ipairs(PlayerManager:GetPlayers()) do
      if p and isBot(p) and p.teamId == teamId then
        local nm = humanName(p)
        if nm ~= "" and not exclude[nm] then
          pool[#pool+1] = p
        end
      end
    end
    if #pool == 0 then return nil end
    return pool[rnd(#pool)]
  end

  -- victim reply (only if victim is a bot)
  if victim and isBot(victim) and victim.name then
    local vName = victim.name
    local baseProb = (prof.replyProb or 0.25)
    -- boost if killer used a named line (i.e., mentioned victim), or if long/revenge/road
    local boost = 1.0
    if usedNamedAny then boost = boost * 2.4 end
    if wasLong or wasRevenge or wasRoad then boost = boost * 1.25 end
    local pVictim = math.min(0.95, baseProb * boost)

    if rnd() < pVictim and rateAllow(vName) and canSpeak(vName, 'onDeath') then
      local replyKey =
        (wasRevenge and 'VictimRevenge') or
        (wasRoad    and 'VictimRoadkill') or
        (wasLong    and 'VictimLongshot') or
        (headshot   and 'VictimHeadshot') or
        'VictimKilled'

      -- slight delay so it "feels" like a reply
      Timer(0.8, function()
        if not bc_enabled() then return end
        local rLine, rPack = chooseReply(replyKey, vName, killerMention, true)
        if rLine then
          sendLine(finalizeLine(rLine, rPack), victim, "global")
        end
      end)
    end
  end

  -- bystander reply (one ally of victim OR killer, not both; low chance)
  do
    local pBase = ((prof.replyProb or 0.25) * 0.6)  -- lower than victim reply
    if usedNamedAny then pBase = pBase * 1.3 end

    -- 50/50 whether we try victim-team sympathy or killer-team cheer
    local doAlly = (rnd() < 0.5)
    local teamId = doAlly and (victim and victim.teamId) or (killer and killer.teamId)

    if teamId ~= nil and rnd() < pBase then
      local exclude = {}
      exclude[humanName(victim) or ""] = true
      exclude[humanName(killer) or ""] = true
      local by = pickRandomBotOnTeam(teamId, exclude)
      if by and rateAllow(humanName(by)) and canSpeak(humanName(by), 'onSpecial') then
        local key, targetName
        if doAlly then
          key, targetName = 'AllyDown', norm(victimHuman)
        else
          key, targetName = 'Cheer', norm(knameHuman)
        end
        Timer(doAlly and 1.1 or 1.3, function()
          if not bc_enabled() then return end
          local rLine, rPack = chooseReply(key, humanName(by), targetName, true)
          if rLine then
            sendLine(finalizeLine(rLine, rPack), by, "global")
          end
        end)
      end
    end
  end
end)

-- Admin chat commands:
--   !bc on|off|toggle|status
--   !bcpack <PackId>
-- ENABLE_OVERRIDE lets a server owner force the state in Shared/Registry/Registry.lua, like:
--   COMMON = {
--     BOT_CHATTER_ENABLED = true, -- or false to hard-disable
--     BOT_TOKEN = "..." (blah blah etc etc)
--   }
Events:Subscribe('Player:Chat', function(p, mask, msg)
  msg = tostring(msg or "")
  local low = msg:lower()
  -- pack switch: always allowed (even if disabled) so testing is easy
  if low:sub(1,8) == "!bcpack " then
    local want = msg:sub(9):gsub("%s+$","")
    if want ~= "" then
      ActiveDefaultPack = PackLoader.Reload(want)
      LoadedPacks = { [ActiveDefaultPack.id] = ActiveDefaultPack } -- reset cache
      ChatManager:Yell("BotChatter pack: " .. ActiveDefaultPack.id, 3.0)
    end
    return
  end
  -- ---- BotChatter on/off/status ----
  if msg:sub(1,3):lower() == "!bc" then
    local arg = msg:sub(4):gsub("^%s+", ""):lower()
  
    if arg == "on" then
      ChatCfg.enabled = true
      NetEvents:Broadcast('BotChatter:Enable', true)
      announce("BotChatter: ON")
  
    elseif arg == "off" then
      -- Announce first, in case overlay will be disabled right after
      announce("BotChatter: OFF")
      ChatCfg.enabled = false
      _Timers = {}
      resetRoundState()
      NetEvents:Broadcast('BotChatter:Enable', false)
      NetEvents:Broadcast('BotChatter:Clear')
  
    elseif arg == "toggle" or arg == "" then
      local newState = not bc_enabled()
      -- If we’re turning OFF, announce before disabling
      if not newState then announce("BotChatter: OFF") end
      ChatCfg.enabled = newState
      if not newState then _Timers = {}; resetRoundState() end
      NetEvents:Broadcast('BotChatter:Enable', newState)
      if not newState then NetEvents:Broadcast('BotChatter:Clear') end
      if newState then announce("BotChatter: ON") end
  
    elseif arg == "status" then
      announce("BotChatter: " .. (bc_enabled() and "ON" or "OFF"))
    end
    return
  end
end)

-- command to switch levels at runtime
Events:Subscribe('Player:Chat', function(p, mask, msg)
  msg = tostring(msg or "")
  local prefix = (ChatCfg.commands and ChatCfg.commands.prefix) or "!bc"

  if msg:sub(1, #prefix+7) == prefix.." level " then
    local want = msg:sub(#prefix+8):lower():gsub("%s+$","")
    if LEVELS[want] then
      ChatCfg.chatterLevel = want
      ChatManager:Yell("BotChatter: level set to "..want, 3.0)
    else
      ChatManager:Yell("BotChatter: levels = billiard | cafe | twitch", 4.0)
    end
  end

  if msg == prefix.." level" then
    ChatManager:Yell("BotChatter: level is "..(ChatCfg.chatterLevel or "cafe"), 3.0)
  end
end)
