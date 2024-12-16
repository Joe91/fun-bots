---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type AirTargets
local m_AirTargets = require('AirTargets')
---@type Logger
local m_Logger = Logger('Bot', Debug.Server.BOT)

local m_BotAiming = require('Bot/BotAiming')
local m_BotAttacking = require('Bot/BotAttacking')
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')
local m_VehicleAiming = require('Bot/VehicleAiming')
local m_VehicleAttacking = require('Bot/VehicleAttacking')
local m_VehicleMovement = require('Bot/VehicleMovement')
local m_VehicleWeaponHandling = require('Bot/VehicleWeaponHandling')

-- Update frame (every Cycle).
-- Update very fast (0.03) ? Needed? Aiming?
-- Update fast (0.1) ? Movement, Reactions.
-- (Update medium? Maybe some things in between).
-- Update slow (0.5) ? Reload, Deploy, (Obstacle-Handling).

-- -- Old movement-modes -- remove one day?
-- if self:IsStaticMovement() then
-- 	m_BotMovement:UpdateStaticMovement(self)
-- 	self:_UpdateInputs(p_DeltaTime)
-- 	m_BotMovement:UpdateYaw(self)
-- 	self._UpdateFastTimer = 0.0
-- 	return
-- end

-- update L0, called every tick
function Bot:UpdateL0()
	self.m_ActiveState.UpdateVeryFast(self.m_ActiveState, self)
end

-- very fast Bot-Code
function Bot:UpdateL1(p_DeltaTime)
	self.m_ActiveState.UpdateFast(self.m_ActiveState, self, p_DeltaTime)
end

-- normal fast Bot-Code
function Bot:UpdateL2(p_DeltaTime)
	self.m_ActiveState.Update(self.m_ActiveState, self, p_DeltaTime)
end

-- slow Bot-Code TODO: fill some slow stuff here
function Bot:UpdateL3(p_DeltaTime)
	self.m_ActiveState.UpdateSlow(self.m_ActiveState, self, p_DeltaTime)
end
