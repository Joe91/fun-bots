require('__shared/Debug')

-- Load utils
require('__shared/Utils/Logger')
require('__shared/Utils/Timestamp')

-- Load constants
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/WeaponTypes')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/BotMoveSpeeds')
require('__shared/Constants/SpawnModes')
require('__shared/Constants/SpawnMethods')
require('__shared/Constants/TeamSwitchModes')
require('__shared/WeaponList')
require('__shared/EbxEditUtils')
require('__shared/Registry/Registry')

---@type Language
local m_Language = require('__shared/Language')
---@type RegistryManager
local m_Registry = require('__shared/Registry/RegistryManager')
