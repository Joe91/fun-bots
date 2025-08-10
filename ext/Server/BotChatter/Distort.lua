-- ext/Server/BotChatter/Distort.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
local M = {}

local emoticons = { ":)", ";)", ":D", ":P", ">:)", "xD", ":^)", ":3" }
local vowels = { a=true, e=true, i=true, o=true, u=true }

local function rand(tbl) return tbl[math.random(#tbl)] end

local function sanitize_ascii(s)
  -- Replace known curly quotes/dashes with ASCII
  s = s:gsub("[\226\128\153\226\128\156\226\128\157]", "'") -- ’ “ ”
  s = s:gsub("[\226\128\147\226\128\148]", "--")            -- en/em-dash -> --
  -- Remove other non-ASCII
  s = s:gsub("[^\x20-\x7E]", "")
  return s
end

local function elongate(s, maxTimes)
  if maxTimes <= 0 then return s end
  -- elongate last vowel in a random word
  local words = {}
  for w in s:gmatch("%S+") do table.insert(words, w) end
  if #words == 0 then return s end
  local idx = math.random(#words)
  local w = words[idx]
  local pos
  for i = #w,1,-1 do
    local ch = w:sub(i,i):lower()
    if vowels[ch] then pos = i; break end
  end
  if not pos then return s end
  local times = math.random(1, maxTimes)
  words[idx] = w:sub(1,pos) .. string.rep(w:sub(pos,pos), times) .. w:sub(pos+1)
  return table.concat(words, " ")
end

local function uppercase_burst(s)
  -- randomly uppercase a short segment
  if #s < 6 then return s:upper() end
  local a = math.random(1, math.max(1, #s-3))
  local b = math.min(#s, a + math.random(2,5))
  return s:sub(1,a-1) .. s:sub(a,b):upper() .. s:sub(b+1)
end

function M.apply(text, globalCfg, packTweaks)
  text = sanitize_ascii(text or "")
  local cfg = globalCfg or {}
  local tw  = (packTweaks and packTweaks.distort) or {}

  local emot = (tw.emoticonChance or cfg.emoticonChance or 0)
  local elong= (tw.elongateChance or cfg.elongateChance or 0)
  local up   = (tw.uppercaseBurstChance or cfg.uppercaseBurstChance or 0)
  local maxE = (tw.maxElongate or cfg.maxElongate or 2)

  if cfg.enabled then
    if math.random() < elong then text = elongate(text, maxE) end
    if math.random() < up    then text = uppercase_burst(text) end
    if math.random() < emot  then text = text .. " " .. rand(emoticons) end
  end
  return text
end

return M
