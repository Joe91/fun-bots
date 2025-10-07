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
		Following = require('BotStates/StateFollowing'),

		-- InVehicleIdle = require('BotStates/StateInVehicleIdle'),
		InVehicleMoving = require('BotStates/StateInVehicleMoving'),
		InVehicleAttacking = require('BotStates/StateInVehicleAttacking'),

		InVehicleJetControl = require('BotStates/StateInVehicleJetControl'),
		InVehicleChopperControl = require('BotStates/StateInVehicleChopperControl'),
		InVehicleStationaryAaControl = require('BotStates/StateInVehicleStationaryAAControl'),

		OnVehicleIdle = require('BotStates/StateOnVehicleIdle'),
		OnVehicleAttacking = require('BotStates/StateOnVehicleAttacking'),
	}
end

function BotStates:IsSoldierState(p_State)
	if p_State == self.States.Moving or
		p_State == self.States.Attacking then
		return true
	else
		return false
	end
end

function BotStates:IsInVehicleState(p_State)
	if p_State == self.States.InVehicleAttacking or
		p_State == self.States.InVehicleMoving or
		p_State == self.States.InVehicleJetControl or
		p_State == self.States.InVehicleChopperControl or
		p_State == self.States.InVehicleStationaryAaControl then
		return true
	else
		return false
	end
end

function BotStates:IsOnVehicleState(p_State)
	if p_State == self.States.OnVehicleAttacking or
		p_State == self.States.OnVehicleIdle then
		return true
	else
		return false
	end
end

function BotStates:IsVehicleState(p_State)
	if p_State == self.States.InVehicleAttacking or
		p_State == self.States.InVehicleMoving or
		p_State == self.States.InVehicleJetControl or
		p_State == self.States.InVehicleChopperControl or
		p_State == self.States.InVehicleStationaryAaControl or
		p_State == self.States.OnVehicleAttacking or
		p_State == self.States.OnVehicleIdle then
		return true
	else
		return false
	end
end

if g_BotStates == nil then
	---@type BotStates
	g_BotStates = BotStates()
end

return g_BotStates
