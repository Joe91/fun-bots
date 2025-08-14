-- ext/Client/BotChatterClient.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- Bot chatter overlay with DebugRenderer (no WebUI, no ChatManager) top-left, left-aligned, newest on top.
-- Colored channel tag, colored speaker name, and substring color highlight when a line mentions YOU.

local Util = require('__shared/BotChatter/Util')  -- shared helpers (normalize_name_for_mentions, etc.)

local VIS = { Global = 0, Team = 1, Squad = 2 }

-- --------------- State & helpers ---------------
local messages = {}

local function now() return math.floor(SharedUtils:GetTimeMS()) / 1000.0 end
local function me() return PlayerManager:GetLocalPlayer() end

local function visible_to_me(vis, teamId, squadId)
  local p = me()
  if not p then return false end
  if vis == VIS.Team  then return p.teamId == teamId end
  if vis == VIS.Squad then return p.teamId == teamId and p.squadId == squadId end
  return true
end

-- ASCII sanitizer (curly quotes / dashes / ellipsis -> plain)
local function sanitize_ascii(s)
  if not s then return "" end
  s = tostring(s)
  s = s:gsub("\226\128\153", "'"):gsub("\226\128\156", "\""):gsub("\226\128\157", "\"")
       :gsub("\226\128\166", "..."):gsub("\226\128[\145\146\147\148]", "-")
       :gsub("[^\32-\126]", "")
  return s
end

-- Case-insensitive "does text contain player's (tag-stripped) name?"
local function find_mention_span(text)
  local p = me()
  if not p or not p.name or not text then return nil end
  local mine = Util.normalize_name_for_mentions(p.name):lower()
  if mine == "" then return nil end
  local low = text:lower()
  local s, e = low:find(mine, 1, true)  -- plain find
  return s, e
end

NetEvents:Subscribe('BotChatter:Say', function(botName, text, vis, teamId, squadId)
  if not visible_to_me(vis, teamId, squadId) then return end
  local chan = (vis == VIS.Team and "TEAM") or (vis == VIS.Squad and "SQUAD") or "ALL"

  local cleanText = sanitize_ascii(text or "")
  local s, e = find_mention_span(cleanText)

  messages[#messages+1] = {
    name      = sanitize_ascii(botName or "BOT"),
    text      = cleanText,
    chan      = chan,
    vis       = vis,
    teamId    = teamId,
    squadId   = squadId,
    t         = now(),
    mention_s = s,  -- start index in text (1-based)
    mention_e = e,  -- end index in text
  }

  -- keep a compact buffer
  local MAX_LINES = 10
  if #messages > MAX_LINES then table.remove(messages, 1) end
end)

Events:Subscribe('Level:Loaded',  function() messages = {} end)
Events:Subscribe('Level:Destroy', function() messages = {} end)

-- --------------- UI tuning ---------------
local function win() return ClientUtils:GetWindowSize() end

-- Placement (top-left)
local PAD_LEFT_RATIO = 0.05
local PAD_TOP_RATIO  = 0.05

-- Base sizing (we'll adapt per frame)
local LINE_PX_BASE    = 18
local FONT_SCALE_BASE = 1.0

-- Lifetime & fade (moved MAX_LINES to NetEvents:Subscribe)
local LIFETIME   = 10.0
local FADE_START = 7.0

-- Colors (RGBA 0..1). BF3-ish: Team1 ~ blue, Team2 ~ orange.
local COLOR_TAG_ALL    = Vec4(0.61, 0.82, 1.00, 0.95)
local COLOR_TAG_TEAM   = Vec4(0.49, 1.00, 0.61, 0.95)
local COLOR_TAG_SQUAD  = Vec4(1.00, 0.87, 0.48, 0.95)

local NAME_TEAM1       = Vec4(0.75, 0.85, 1.00, 0.98)
local NAME_TEAM2       = Vec4(1.00, 0.80, 0.55, 0.98)
local NAME_NEUTRAL     = Vec4(1.00, 1.00, 1.00, 0.98)

local TEXT_TEAM1       = Vec4(0.82, 0.90, 1.00, 0.96)
local TEXT_TEAM2       = Vec4(1.00, 0.88, 0.70, 0.96)
local TEXT_GLOBAL      = Vec4(0.90, 0.90, 0.90, 0.96)
local TEXT_SQUAD       = Vec4(0.85, 1.00, 0.78, 0.96)

local MENTION_HILITE   = Vec4(1.00, 0.95, 0.40, 1.00) -- bright yellow for mentions
local SHADOW           = Vec4(0, 0, 0, 0.85)

-- Char width estimate (pixels at scale=1). Keep integer math for crispness.
local CHAR_PX = 8

-- --------------- Drawing ---------------
-- NEW: Partial rewrite of how this works
Events:Subscribe('UI:DrawHud', function()
  if #messages == 0 then return end

  local res   = win()

  -- Adaptive scale: proportionally bigger on high res, clamp for legibility
  local scale = FONT_SCALE_BASE * math.min(1.5, math.max(0.95, (res.y / 1080.0) * 1.05))
  local step  = math.floor(LINE_PX_BASE * scale + 0.5)
  local baseX = math.floor(res.x * PAD_LEFT_RATIO + 0.5)
  local baseY = math.floor(res.y * PAD_TOP_RATIO  + 0.5)
  local tnow  = now()

  local function apply_a(v, a) return Vec4(v.x, v.y, v.z, v.w * a) end

  local y = baseY
  for i = #messages, 1, -1 do
    local m   = messages[i]
    local age = tnow - m.t
    if age > LIFETIME then
      table.remove(messages, i)
    else
      -- fade
      local fade = 1.0
      if age > FADE_START then
        local k = math.min(1.0, (age - FADE_START) / (LIFETIME - FADE_START))
        fade = 1.0 - 0.75 * k
      end

      local tagStr  = "[" .. m.chan .. "] "
      local nameStr = m.name .. ": "
      local textStr = m.text

      -- Colors for this line
      local tagColor =
        (m.chan == "TEAM"  and COLOR_TAG_TEAM)  or
        (m.chan == "SQUAD" and COLOR_TAG_SQUAD) or
        COLOR_TAG_ALL

      local nameColor =
        (m.teamId == TeamId.Team1 and NAME_TEAM1) or
        (m.teamId == TeamId.Team2 and NAME_TEAM2) or
        NAME_NEUTRAL

      local baseText =
        (m.vis == VIS.Squad and TEXT_SQUAD) or
        (m.teamId == TeamId.Team1 and TEXT_TEAM1) or
        (m.teamId == TeamId.Team2 and TEXT_TEAM2) or
        TEXT_GLOBAL

      local tagC = apply_a(tagColor,  fade)
      local nmC  = apply_a(nameColor, fade)
      local txC  = apply_a(baseText,  fade)
      local hiC  = apply_a(MENTION_HILITE, fade)
      local shC  = apply_a(SHADOW,    fade)

      -- left-aligned positions
      local char_px_scaled = math.floor(CHAR_PX * scale + 0.5)
      local x_tag  = baseX
      local x_name = x_tag  + (#tagStr  * char_px_scaled)
      local x_text = x_name + (#nameStr * char_px_scaled)

      -- split text into pre / hi / post using the stored span
      local pre, hi, post
      if m.mention_s and m.mention_e then
        pre  = textStr:sub(1, m.mention_s - 1)
        hi   = textStr:sub(m.mention_s, m.mention_e)
        post = textStr:sub(m.mention_e + 1)
      else
        pre, hi, post = textStr, "", ""
      end

      -- SHADOW pass
      DebugRenderer:DrawText2D(x_tag  + 1, y + 1, tagStr,  shC, scale)
      DebugRenderer:DrawText2D(x_name + 1, y + 1, nameStr, shC, scale)

      local x_pre = x_text
      DebugRenderer:DrawText2D(x_pre + 1, y + 1, pre,  shC, scale)
      local x_hi  = x_pre + (#pre * char_px_scaled)
      if hi   ~= "" then DebugRenderer:DrawText2D(x_hi + 1, y + 1, hi,   shC, scale) end
      local x_po  = x_hi  + (#hi  * char_px_scaled)
      if post ~= "" then DebugRenderer:DrawText2D(x_po + 1, y + 1, post, shC, scale) end

      -- MAIN pass
      DebugRenderer:DrawText2D(x_tag,  y, tagStr,  tagC, scale)
      DebugRenderer:DrawText2D(x_name, y, nameStr, nmC,  scale)

      DebugRenderer:DrawText2D(x_pre, y, pre,  txC, scale)
      if hi   ~= "" then DebugRenderer:DrawText2D(x_hi, y, hi,   hiC, scale) end
      if post ~= "" then DebugRenderer:DrawText2D(x_po, y, post, txC, scale) end

      y = y + step
      if ((y - baseY) / step) >= 10 then break end
    end
  end
end)
