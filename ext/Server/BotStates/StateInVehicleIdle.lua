---@class StateInVehicleIdle
---@overload fun():StateInVehicleIdle
StateInVehicleIdle = class('StateInVehicleIdle')

-- this class handles the following things:
-- - waiting for action
-- - waiting for revive
-- - waiting for respawn

-- transitions to:
-- - moving
-- (- vehicle-idle?)

---@type Utilities
local m_Utilities = require('__shared/Utilities')
-- bot-methods
local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

function StateInVehicleIdle:__init()
	-- Nothing to do.
end

function StateInVehicleIdle:UpdatePrecheck(p_Bot)
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleIdle:Update(p_Bot, p_DeltaTime)
	p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleIdle:UpdateFast(p_Bot, p_DeltaTime)
end

---update in every frame
---@param p_Bot Bot
function StateInVehicleIdle:UpdateVeryFast(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateInVehicleIdle:UpdateSlow(p_Bot, p_DeltaTime)
end

if g_StateInVehicleIdle == nil then
	---@type StateInVehicleIdle
	g_StateInVehicleIdle = StateInVehicleIdle()
end

return g_StateInVehicleIdle
