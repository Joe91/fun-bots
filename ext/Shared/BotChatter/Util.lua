-- ext/Shared/BotChatter/Util.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
local M = {}

-- ----- BOT_TOKEN bootstrap (read from global Registry) -----
local BOT_TOKEN = ""
do
  -- load the module so it defines global `Registry`
  pcall(function() require('__shared/Registry/Registry') end)
  local reg = rawget(_G, 'Registry')  -- <-- THIS is where Registry actually lives
  if reg and reg.COMMON and reg.COMMON.BOT_TOKEN ~= nil then
    BOT_TOKEN = reg.COMMON.BOT_TOKEN or ""
  end
end

local function ltrim(s) return (s or ""):gsub("^%s+", "") end
local function escpat(s) return (s:gsub("([^%w])","%%%1")) end

-- strip leading [TAG]/(TAG)/{TAG}
local function strip_leading_bracket_tag(s)
  local t = s
  t = t:gsub("^%s*%b[]%s*", "")
  t = t:gsub("^%s*%b()%s*", "")
  t = t:gsub("^%s*%b{}%s*", "")
  return t
end

-- case-insensitive token remove at BOS
local TOK   = (BOT_TOKEN ~= "" and escpat(BOT_TOKEN)) or nil
local TOK_L = TOK and TOK:lower() or nil

local function strip_leading_bot_token(s)
  if not TOK then return s end
  s = s:gsub("^%s*" .. TOK,   "")
  s = s:gsub("^%s*" .. TOK_L, "")
  return s
end

-- legacy
function M.strip_tags(s)
  return ltrim(strip_leading_bracket_tag(s or ""))
end

-- Names -> used for {enemy} and mention matching
function M.normalize_name_for_mentions(s)
  local out = tostring(s or "")
  local changed = true
  while changed do
    local before = out
    out = strip_leading_bot_token(out)
    out = strip_leading_bracket_tag(out)
    out = ltrim(out)
    changed = (out ~= before)
  end
  return out:gsub("%s%s+", " ")
end

-- Text lines -> remove inline prefixes like ", BOT_[UK]Foo" or " bot_Foo"
function M.scrub_inline_prefixes(text)
  local out = tostring(text or "")
  if out == "" then return out end

  -- remove bracket tags at BOS and after non-word
  out = out:gsub("^%s*%b[]%s*", ""):gsub("^%s*%b()%s*", ""):gsub("^%s*%b{}%s*", "")
  out = out:gsub("([^%w])%s*%b[]%s*", "%1")
           :gsub("([^%w])%s*%b()%s*", "%1")
           :gsub("([^%w])%s*%b{}%s*", "%1")

  if TOK then
    out = out:gsub("^%s*" .. TOK,   "")
             :gsub("^%s*" .. TOK_L, "")
             :gsub("([^%w])%s*" .. TOK,   "%1")
             :gsub("([^%w])%s*" .. TOK_L, "%1")
  end

  return out:gsub("%s%s+", " ")
end

-- misc
function M.simple_hash(s, seed)
  local h = seed or 1337
  s = tostring(s or "")
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

function M.merge_arrays(a, b, c)
  local t = {}
  if a then for i=1,#a do t[#t+1] = a[i] end end
  if b then for i=1,#b do t[#b+1] = b[i] end end
  if c then for i=1,#c do t[#c+1] = c[i] end end
  return t
end

return M
