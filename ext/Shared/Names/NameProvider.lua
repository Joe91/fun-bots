-- ext/Shared/Names/NameProvider.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- Modular name provider with pack mixing, uniqueness, and legacy exports.

local M = {}

-- Try to read Fun-Bots token for optional stripping
local BOT_TOKEN = ""
pcall(function()
  local ok, reg = pcall(require, "__shared/Registry/Registry")
  if ok and reg and reg.COMMON and reg.COMMON.BOT_TOKEN ~= nil then
    BOT_TOKEN = reg.COMMON.BOT_TOKEN or ""
  end
end)

-- ---------------- User configuration ----------------
-- Choose packs and weights. Higher weight = more frequent.
-- Add/remove packs by adding a require below.
local PACK_CATALOG = {
  ["global_default"]      = function() return require("__shared/Names/packs/global_default") end,
  ["au"]                  = function() return require("__shared/Names/packs/au") end,
  ["nz"]                  = function() return require("__shared/Names/packs/nz") end,
  ["uk"]                  = function() return require("__shared/Names/packs/uk") end,
  ["ca"]                  = function() return require("__shared/Names/packs/ca") end,
  ["mil_us"]              = function() return require("__shared/Names/packs/mil_us") end,
  ["mil_ru"]              = function() return require("__shared/Names/packs/mil_ru") end,
  ["gamer_tags"]          = function() return require("__shared/Names/packs/gamer_tags") end,
  ["legacy_common"]       = function() return require("__shared/Names/packs/legacy_common") end,  -- from the legacy BotNames.lua
  ["legacy_devs"]         = function() return require("__shared/Names/packs/legacy_devs") end,  -- from the legacy BotNames.lua
  ["legacy_contributors"] = function() return require("__shared/Names/packs/legacy_contributors") end,  -- from the legacy BotNames.lua
  ["legacy_supporters"]   = function() return require("__shared/Names/packs/legacy_supporters") end,  -- from the legacy BotNames.lua
  ["legacy_handles"]      = function() return require("__shared/Names/packs/legacy_handles") end,  -- from the legacy BotNames.lua
  ["mil_us_legacy"]       = function() return require("__shared/Names/packs/mil_us_legacy") end,  -- from the legacy BotNames.lua
  ["mil_ru_legacy"]       = function() return require("__shared/Names/packs/mil_ru_legacy") end,  -- from the legacy BotNames.lua
}

-- Active mix (order doesn’t matter)
local ACTIVE_PACKS = {
  { id = "global_default", weight = 0.6 },
  { id = "gamer_tags",     weight = 0.25 },
  { id = "au",             weight = 0.35 },
  { id = "nz",             weight = 0.25 },
  { id = "uk",             weight = 0.25 },
  { id = "ca",             weight = 0.25 },

  -- legacy adds (low impact for now, change weights as needed)
  { id = "legacy_common",       weight = 0.35 },
  { id = "legacy_handles",      weight = 0.10 },
  { id = "legacy_devs",         weight = 0.03 },
  { id = "legacy_contributors", weight = 0.03 },
  { id = "legacy_supporters",   weight = 0.02 },
  
  -- keep mil packs out of the general pool if you only want them for team-flavour
}

-- Behaviour toggles
local OPTIONS = {
  stripClanTags = false,       -- keep [AU] etc. visible in names
  stripFunBotsToken = true,    -- drop BOT_TOKEN if present
  enforceAscii = true,         -- keep overlay clean
  maxUnified = 120,            -- cap total exported names (for BotNames legacy)
  seedWithTeamFlavour = true,  -- US/RU team-specific defaults for legacy exports
}

-- -------- Regional tag policy (runtime; not stored in packs) --------
-- Add/remove regions as you add chatter packs. Weights = relative frequency.
local REGION_TAGS = {
  { tag = "[AU]", weight = 1.0, pack = "AU"      },
  { tag = "[NZ]", weight = 0.9, pack = "NZ"      },
  { tag = "[UK]", weight = 0.8, pack = "UK"      },
  { tag = "[CA]", weight = 0.8, pack = "CA"      },
  { tag = "[US]", weight = 1.0, pack = "Default" },
}

-- Probability a *new* name is tagged. Tune to taste.
local TAG_APPLY_PROB = 0.35

-- Prevent tagging names that *already* have a visible clan tag like [CLAN]
local function has_leading_tag(n)
  if not n then return false end
  -- fast path: first non-space must be bracket
  if not n:match("^%s*[%[%(%{]") then return false end
  -- then confirm a balanced token of one of the bracket types
  return n:match("^%s*%b[]") or n:match("^%s*%b()") or n:match("^%s*%b{}")
end

local function pick_weighted(list)
  local total = 0
  for _, r in ipairs(list) do total = total + (r.weight or 0) end
  if total <= 0 then return nil end
  local roll = math.random() * total
  local acc = 0
  for _, r in ipairs(list) do
    acc = acc + (r.weight or 0)
    if roll <= acc then return r end
  end
  return list[#list]
end

-- This is unused now for the moment, replaced by the newer apply_tag function below
local function maybe_tag(name)
  -- never tag if it already starts with any bracketed token
  if has_leading_tag(name) then return name end
  if math.random() >= TAG_APPLY_PROB then return name end
  local region = pick_weighted(REGION_TAGS)
  if not region or not region.tag then return name end
  return region.tag .. name
end

-- Per-pack tag policy
-- meta fields (all optional):
--   allowRegionTag = true|false     -- default true
--   forceTag       = "[DEV]"        -- if set, always apply unless name already has a tag
--   tagProb        = 0..1           -- overrides TAG_APPLY_PROB for this pack
local function apply_tag(name, pack)
  local meta = (pack and pack.meta) or {}
  -- never tag if prefix already looks like a tag
  if has_leading_tag(name) then return name end

  -- hard-coded tag for this pack (takes precedence)
  if meta.forceTag and meta.forceTag ~= "" then
    return tostring(meta.forceTag) .. name
  end

  -- allow/disallow normal regional tags per pack
  local allow = (meta.allowRegionTag ~= false)
  if not allow then return name end

  -- regional tag with (per-pack) probability
  local prob = (meta.tagProb ~= nil) and meta.tagProb or TAG_APPLY_PROB
  if math.random() >= prob then return name end

  local region = pick_weighted(REGION_TAGS)
  if not region or not region.tag then return name end
  return region.tag .. name
end

-- ---------------- Helpers ----------------
local function merge_arrays(a, b)
  local out = {}
  if a then for i = 1, #a do out[#out+1] = a[i] end end
  if b then for i = 1, #b do out[#out+1] = b[i] end end
  return out
end

local function sanitize_ascii(s)
  if not s then return "" end
  s = tostring(s)
  -- replace fancy quotes/dashes/ellipsis
  s = s:gsub("\226\128\153", "'"):gsub("\226\128\156", "\""):gsub("\226\128\157", "\"")
  s = s:gsub("\226\128\166", "..."):gsub("\226\128[\145\146\147\148]", "-")
  s = s:gsub("[^\32-\126]", "") -- drop other non-ASCII
  return s
end

local function strip_clan_tag(name)
  if not name then return "" end
  -- remove one leading [TAG]/(TAG)/{TAG}, then trailing whitespace
  -- NOTE: %s* is OUTSIDE the class so it's real whitespace, not literal 's'/'*'
  -- NEW: balanced-pair form is safer and clearer in Lua
  local s = name
  s = s:gsub("^%s*%b[]%s*", "")  -- leading [TAG]
  s = s:gsub("^%s*%b()%s*", "")  -- leading (TAG)
  s = s:gsub("^%s*%b{}%s*", "")  -- leading {TAG}
  return s:match("^%s*(.-)%s*$") or s
end

local function strip_bot_token(name)
  if BOT_TOKEN == nil or BOT_TOKEN == "" then return name end
  if name:sub(1, #BOT_TOKEN) == BOT_TOKEN then
    return name:sub(#BOT_TOKEN + 1)
  end
  return name
end

local function clean_name(raw)
  local n = raw or ""
  if OPTIONS.stripFunBotsToken then n = strip_bot_token(n) end
  if OPTIONS.stripClanTags then   n = strip_clan_tag(n)   end
  if OPTIONS.enforceAscii then    n = sanitize_ascii(n)   end
  -- collapse double spaces
  n = n:gsub("%s%s+", " ")
  return n
end

-- ---------------- Pack loading & mixing ----------------

local loadedPacks = {}
local unifiedPool = {}  -- array of names
local uniqueSet    = {} -- set for fast dup checks

local function load_pack(id)
  if loadedPacks[id] then return loadedPacks[id] end
  local fn = PACK_CATALOG[id]
  if not fn then return { id = id, names = {}, meta = {} } end
  local p = fn()
  -- pack structure: { id="au_nz", names={...}, meta={team="US"/"RU"/nil}}
  if not p or type(p) ~= "table" then
    p = { id = id, names = {}, meta = {} }
  end
  p.id   = p.id   or id
  p.meta = p.meta or {}
  p.names= p.names or {}
  loadedPacks[id] = p
  return p
end

local function push_unique(raw)
  local n = clean_name(raw)
  if n == "" then return end
  if uniqueSet[n] then return end
  uniqueSet[n] = true
  unifiedPool[#unifiedPool + 1] = n
end

local function build_unified_pool()
  loadedPacks, unifiedPool, uniqueSet = {}, {}, {}
  local LIMIT = OPTIONS.maxUnified or 120

  -- helper: should this pack contribute to the unified/generic pool?
  local function include_pack(pack)
    local meta = (pack and pack.meta) or {}
    if meta.includeInUnified == false then return false end
    return true
  end

  -- weighted copy pass (ACTIVE_PACKS)
  for _, ref in ipairs(ACTIVE_PACKS) do
    local pack = load_pack(ref.id)
    local w = math.max(0, ref.weight or 1)

    -- skip excluded / empty packs
    if include_pack(pack) and w > 0 and #pack.names > 0 then
      -- naive weighting: repeat sampling proportional to weight * size
      local budget = math.ceil(w * math.max(20, math.floor(#pack.names * 0.5)))
      for i = 1, budget do
        local name = pack.names[((i - 1) % #pack.names) + 1]
        -- name = maybe_tag(name)           -- inject a regional tag sometimes (deprecated for now)
        name = apply_tag(name, pack)
        push_unique(name)
        if #unifiedPool >= LIMIT then break end
      end
    end

    if #unifiedPool >= LIMIT then break end
  end

  -- if pool undersized, backfill with any remaining *eligible* pack content
  if #unifiedPool < LIMIT then
    for id, _ in pairs(PACK_CATALOG) do
      local p = load_pack(id)
      if include_pack(p) and #p.names > 0 then
        for _, n in ipairs(p.names) do
        -- push_unique(maybe_tag(n))     -- deprecated for now
          push_unique(apply_tag(n, p))
          if #unifiedPool >= LIMIT then break end
        end
      end
      if #unifiedPool >= LIMIT then break end
    end
  end
end

-- For session unique "next name"
local cursor = 1
local function shuffle_in_place(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

-- ---------------- Public API ----------------

function M.Init(seed)
  if seed then math.randomseed(seed) else math.randomseed(os.time() % 2147483647) end
  build_unified_pool()
  shuffle_in_place(unifiedPool)
  cursor = 1
end

function M.NextName()
  if #unifiedPool == 0 then M.Init() end
  local n = unifiedPool[cursor]
  cursor = cursor + 1
  if cursor > #unifiedPool then cursor = 1 end
  return n or ("Player"..tostring(math.random(10000,99999)))
end

-- Legacy exports for Fun-Bots, so we remain compatible
function M.ExportLegacyTables()
  if #unifiedPool == 0 then M.Init() end

  local generic = {}
  for i = 1, math.min(#unifiedPool, OPTIONS.maxUnified or 120) do
    generic[#generic + 1] = unifiedPool[i]
  end

  -- team-flavoured defaults for US/RU (override via packs)
  -- NEW: merge legacy military lists if present
  local us = merge_arrays(load_pack("mil_us").names, load_pack("mil_us_legacy").names)
  local ru = merge_arrays(load_pack("mil_ru").names, load_pack("mil_ru_legacy").names)

  -- fallbacks if empty
  if not us or #us == 0 then us = { "Pvt. Walker", "Cpl. Nguyen", "Sgt. Patel" } end
  if not ru or #ru == 0 then ru = { "Pvt. Ivanov", "Cpl. Petrov", "Sgt. Sokolov" } end

  -- sanitize/strip these too
  local USMar = {}
  for _, n in ipairs(us) do USMar[#USMar + 1] = clean_name(n) end
  local RUMil = {}
  for _, n in ipairs(ru) do RUMil[#RUMil + 1] = clean_name(n) end

  return generic, USMar, RUMil
end

return M
