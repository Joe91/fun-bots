---@class BotStates
---@overload fun(p_Player: Player):BotStates
BotStates = class('BotStates')

function BotStates:__init()
	self.States = {
		Idle = require('BotStates/StateIdle'),
		Moving = require('BotStates/StateMoving'),
		Attacking = require('BotStates/StateAttacking'),
		Reviving = nil,
		Repairing = nil,

		-- InVehicleIdle = require('BotStates/StateInVehicleIdle'),
		InVehicleMoving = require('BotStates/StateInVehicleMoving'),
		InVehicleAttacking = require('BotStates/StateInVehicleAttacking'),

		OnVehicleIdle = require('BotStates/StateOnVehicleIdle'),
		OnVehicleAttacking = require('BotStates/StateOnVehicleAttacking'),
	}
end

if g_BotStates == nil then
	---@type BotStates
	g_BotStates = BotStates()
end

return g_BotStates
