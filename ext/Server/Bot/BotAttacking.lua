---@class BotAttacking
---@overload fun():BotAttacking
BotAttacking = class('BotAttacking')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")

function BotAttacking:__init()
	-- Nothing to do.
end

---@param p_Bot Bot
local function _DefaultAttackingAction(p_Bot)
	if not p_Bot._ShootPlayer.soldier or not p_Bot._Shoot or p_Bot._ShootModeTimer >= Config.BotAttackDuration then
		p_Bot._TargetPitch = 0.0
		p_Bot:AbortAttack()
		return
	end

	-- Check for melee attack.
	if p_Bot._ActiveAction ~= BotActionFlags.MeleeActive
		and p_Bot._MeleeCooldownTimer <= 0.0
		and p_Bot._ShootPlayer.soldier.worldTransform.trans:Distance(p_Bot.m_Player.soldier.worldTransform.trans) < 2 then
		p_Bot._ActiveAction = BotActionFlags.MeleeActive
		p_Bot.m_ActiveWeapon = p_Bot.m_Knife

		p_Bot:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
		p_Bot:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
		p_Bot:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
		p_Bot._MeleeCooldownTimer = Config.MeleeAttackCoolDown
	else
		if p_Bot._MeleeCooldownTimer < 0.0 then
			p_Bot._MeleeCooldownTimer = 0.0
		elseif p_Bot._MeleeCooldownTimer > 0.0 then
			p_Bot._MeleeCooldownTimer = p_Bot._MeleeCooldownTimer - Registry.BOT.BOT_UPDATE_CYCLE
			if p_Bot._MeleeCooldownTimer < (Config.MeleeAttackCoolDown - 0.8) then
				p_Bot:_ResetActionFlag(BotActionFlags.MeleeActive)
			else
				p_Bot:_SetInput(EntryInputActionEnum.EIAFire, 1)
			end
		end
	end

	p_Bot._WeaponToUse = BotWeapons.Knife

	-- Trace way back.
	if p_Bot._ShootTraceTimer > Registry.BOT.TRACE_DELTA_SHOOTING then
		-- Create a Trace to find way back.
		p_Bot._ShootTraceTimer = 0.0
		local s_Point = {
			Position = p_Bot.m_Player.soldier.worldTransform.trans:Clone(),
			SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
			ExtraMode = 0,
			OptValue = 0,
		}

		table.insert(p_Bot._ShootWayPoints, s_Point)

		local s_Trans = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone()
		if (#p_Bot._KnifeWayPositions == 0 or s_Trans:Distance(p_Bot._KnifeWayPositions[#p_Bot._KnifeWayPositions]) > Registry.BOT.TRACE_DELTA_SHOOTING) then
			table.insert(p_Bot._KnifeWayPositions, s_Trans)
		end
	end

	p_Bot._ShootTraceTimer = p_Bot._ShootTraceTimer + Registry.BOT.BOT_UPDATE_CYCLE
	p_Bot._ShotTimer = p_Bot._ShotTimer + Registry.BOT.BOT_UPDATE_CYCLE
end

---@param p_Bot Bot
function BotAttacking:UpdateAttacking(p_Bot)
	-- Reset if enemy is dead or attack is disabled.
	if not p_Bot._ShootPlayer then
		p_Bot:AbortAttack()
		return
	end

	_DefaultAttackingAction(p_Bot)

end

if g_BotAttacking == nil then
	---@type BotAttacking
	g_BotAttacking = BotAttacking()
end

return g_BotAttacking
