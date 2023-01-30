---@class BotAiming
---@overload fun():BotAiming
BotAiming = class('BotAiming')

---@type Utilities
local m_Utilities = require('__shared/Utilities')

function BotAiming:__init()
	-- Nothing to do.
end

---@param p_Bot Bot
local function _KnifeAimingAction(p_Bot)
	if p_Bot._ShootPlayer == nil or p_Bot._ShootPlayer.soldier == nil then
		return
	end

	local s_PositionTarget = p_Bot._ShootPlayer.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(p_Bot.m_Player, true, false)
	local s_PositionBot = p_Bot.m_Player.soldier.worldTransform.trans:Clone() +
		m_Utilities:getCameraPos(p_Bot.m_Player, false, false)

	-- Calculate how long the distance is
	p_Bot._DistanceToPlayer = s_PositionTarget:Distance(s_PositionBot)

	local s_DifferenceY = 0
	local s_DifferenceX = 0
	local s_DifferenceZ = 0

	-- Calculate yaw and pitch.
	if #p_Bot._KnifeWayPositions > 0 and p_Bot._DistanceToPlayer > 1.0 and
		(p_Bot._DistanceToPlayer > Config.DistanceForDirectAttack or not p_Bot._GoForDirectAttackIfClose) then
		if p_Bot._ObstacleSequenceTimer ~= 0 then
			p_Bot._KnifeWayPointTimer = p_Bot._KnifeWayPointTimer + Registry.BOT.BOT_FAST_UPDATE_CYCLE
		end

		s_DifferenceZ = p_Bot._KnifeWayPositions[1].z - p_Bot.m_Player.soldier.worldTransform.trans.z
		s_DifferenceX = p_Bot._KnifeWayPositions[1].x - p_Bot.m_Player.soldier.worldTransform.trans.x

		local s_CurrentAttackPointDistance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Bot._KnifeWayPositions[1])

		if s_CurrentAttackPointDistance < 0.75 or
			s_CurrentAttackPointDistance > p_Bot._LastAttackPointDistance then
			p_Bot._KnifeWayPointTimer = 0.0
			table.remove(p_Bot._KnifeWayPositions, 1)
		end
		p_Bot._LastAttackPointDistance = s_CurrentAttackPointDistance
	else
		p_Bot._KnifeWayPositions = {}
		s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
		s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
		s_DifferenceY = s_PositionTarget.y - s_PositionBot.y
	end

	local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
	local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

	-- Calculate pitch.
	local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
	local s_Pitch = math.atan(s_DifferenceY, s_Distance)

	p_Bot._TargetPitch = s_Pitch
	p_Bot._TargetYaw = s_Yaw
end

---@param p_Bot Bot
function BotAiming:UpdateAiming(p_Bot)
	if p_Bot._ShootPlayer == nil then
		return
	end

	_KnifeAimingAction(p_Bot)

end

if g_BotAiming == nil then
	---@type BotAiming
	g_BotAiming = BotAiming()
end

return g_BotAiming
