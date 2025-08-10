-- ext/Server/BotChatter/PackLoader.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
local M = {}

local function safe_require(path)
  local ok, mod = pcall(require, path)
  if ok then return mod end
  print("[BotChatter] require failed: " .. path .. " -> " .. tostring(mod))
  return nil
end

function M.Load(name)
  local mod = safe_require('BotChatter/Packs/' .. name)
  if not mod then
    print("[BotChatter] Falling back to Default pack.")
    mod = safe_require('BotChatter/Packs/Default') or { Lines = {}, Aliases = {} }
  end
  -- normalize empty tables
  mod.Lines = mod.Lines or {}
  mod.PersonalityBias = mod.PersonalityBias or {} -- optional per-pack bias weights
  mod.Tweaks = mod.Tweaks or {}                   -- optional distortion tweaks, casing, etc.
  return mod
end

function M.Reload(name)
  package.loaded['BotChatter/Packs/' .. name] = nil
  return M.Load(name)
end

return M
