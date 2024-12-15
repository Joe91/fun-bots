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

		InVehicleIdle = nil,
		InVehicleMoving = nil,
		InVehicleAttacking = nil,

		OnVehicleIdle = nil,
		OnVehicleAttacking = nil
	}
end

if g_BotStates == nil then
	---@type BotStates
	g_BotStates = BotStates()
end

return g_BotStates
