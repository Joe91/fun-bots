---@class BotNames
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- This file now loads the NameProvider module instead of hard-coding names here.

local NameProvider = require("__shared/Names/NameProvider")

-- Build pool once per extension load; shuffle internally
NameProvider.Init()

local generic, us, ru = NameProvider.ExportLegacyTables()

-- Fun-Bots expects these globals to exist:
BotNames       = generic
USMarinesNames = us
RUMilitaryNames= ru

return BotNames
