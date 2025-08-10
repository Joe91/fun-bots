-- ext/Shared/BotChatterConfig.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
return {
  -- Which pack to use if no per-bot tag is matched.
  defaultPack = "Default",

  -- Let bot name tags select a regional pack, e.g. "[AU]Gaz".
  allowPerBotPackByTag = true,

  -- Keys are case-insensitive prefixes to match at start of name.
  -- Values are pack IDs (folder/file names in BotChatter/Packs).
  tagToPack = {
    ["[AU]"] = "AU",
    ["(AU)"] = "AU",
    ["{AU}"] = "AU",
    ["[NZ]"] = "NZ",
    ["(NZ)"] = "NZ",
    ["{NZ}"] = "NZ",
    ["[UK]"] = "UK",
    ["(UK)"] = "UK",
    ["{UK}"] = "UK",
    ["[CA]"] = "CA",
    ["(CA)"] = "CA",
    ["{CA}"] = "CA",
    ["[US]"] = "Default",  -- US bots fall back to Default chatter
  },

  -- Personality assignment:
  --  "seeded" (stable per-bot), "single" (force one for all), "randomEachEvent"
  personalityMode = "seeded",
  forcedPersonality = "Tactical",

  -- Deterministic seed for personalities, etc.
  seed = 1337,

  -- Global distortion knobs (packs can override bits of this)
  distort = {
    enabled = true,
    emoticonChance = 0.12,     -- append a text emoticon sometimes
    elongateChance = 0.06,     -- "niice"
    uppercaseBurstChance = 0.05,
    maxElongate = 3,
  },

  -- Safety: limit how many lines per bot per time window (anti-spam)
  rateLimit = {
    windowSec = 8.0,
    maxPerWindow = 2
  }
}
