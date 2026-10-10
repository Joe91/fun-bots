---@class BotWalker
---@overload fun():BotWalker
BotWalker = class('BotWalker')

-- A bot walks given points (from the debug-server), the way it walks a path: speed, obstacle handling (jumping,
-- getting around), no path offsets. Used to find and record ways the waypoints are missing (funbots_debug/census:
-- spawns cut off from the network): the debug-server plans a way with rays, the bot walks it and tells where it got
-- stuck. Runs as task of the DebugBridge, answers the command at the end.
--   walk       { points = { {x, y, z}, ... }, bot?, team?, speed? = "normal"|"sprint"|"slow", place? = true,
--                stuck? = 6, timeout? = 180 }
--              -> { status = "done"|"stuck"|"border"|"dead"|"timeout"|"stopped", reached, bot, pos, time,
--                   trail = { {x, y, z}, ... } }
--   walk_stop  {}
-- bot: the id of the bot (default: a bot on foot, of the team if given). place: put it onto the first point first.
-- reached: how many points it got to. trail: where it walked, every TRAIL_STEP metres. stuck: seconds without moving
-- STUCK_DISTANCE metres. border: it left the combat-area (the game kills it after 10 s), stopped where it did.

---@type BotManager
local m_BotManager = require('BotManager')
---@type Utilities
local m_Utilities = require('__shared/Utilities')

local _Vec = DebugBridge.Vec

local TRAIL_STEP = 0.5
local EXIT_TIMEOUT = 10.0 -- Seconds a bot in a vehicle gets to get out before it walks.
local STUCK_DISTANCE = 1.0
local SPEEDS = { normal = BotMoveSpeeds.Normal, sprint = BotMoveSpeeds.Sprint, slow = BotMoveSpeeds.SlowCrouch }

---@class BotWalkerTask
---@field CommandId integer
---@field Bot Bot
---@field Total integer points given
---@field Started number
---@field Timeout number
---@field Stuck number seconds without moving STUCK_DISTANCE
---@field Anchor Vec3 where it was when it last moved STUCK_DISTANCE
---@field AnchorTime number
---@field Trail table[] where it walked
---@field Last Vec3 the last point of the trail
---@field Points table[] the points, until it starts
---@field Place boolean
---@field ExitSince number|nil since when it gets out of its vehicle
local BotWalkerTask = {}
BotWalkerTask.__index = BotWalkerTask

function BotWalker:__init()
end

---On foot controlledControllable is the soldier itself.
---@param p_Player Player
---@return boolean
local function _InVehicle(p_Player)
	local s_Controllable = p_Player.controlledControllable
	return s_Controllable ~= nil and not s_Controllable:Is('ServerSoldierEntity')
end

---@param p_Id integer|nil
---@param p_Team integer|nil
---@return Bot|nil
local function _PickBot(p_Id, p_Team)
	if p_Id ~= nil then
		return m_BotManager:GetBotById(p_Id)
	end
	-- On foot first, else one in a vehicle (it gets out first).
	local s_Bots = m_BotManager:GetBots()
	local s_InVehicle = nil
	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		if l_Bot.m_Player.soldier ~= nil and (p_Team == nil or l_Bot.m_Player.teamId == p_Team) then
			if not _InVehicle(l_Bot.m_Player) then
				return l_Bot
			end
			s_InVehicle = s_InVehicle or l_Bot
		end
	end
	return s_InVehicle
end

---@param p_Bridge DebugBridge
---@param p_CommandId integer
---@param p_Args table
function BotWalker:Start(p_Bridge, p_CommandId, p_Args)
	p_Bridge:AbortTasks(function(p_Task)
		return getmetatable(p_Task) == BotWalkerTask
	end, 'stopped')

	local s_Raw = type(p_Args.points) == 'table' and p_Args.points or {}
	if #s_Raw == 0 then
		error('no points')
	end
	local s_Bot = _PickBot(tonumber(p_Args.bot), tonumber(p_Args.team))
	if s_Bot == nil or s_Bot.m_Player.soldier == nil then
		error('no living bot')
	end
	local s_Speed = SPEEDS[p_Args.speed or 'normal'] or BotMoveSpeeds.Normal
	local s_Points = {}
	for l_Index = 1, #s_Raw do
		local l_Raw = s_Raw[l_Index]
		s_Points[l_Index] = { SpeedMode = s_Speed, Position = Vec3(l_Raw[1], l_Raw[2], l_Raw[3]) }
	end

	p_Bridge:AddTask(setmetatable({
		CommandId = p_CommandId,
		Bot = s_Bot,
		Total = #s_Points,
		Points = s_Points,
		Place = p_Args.place ~= false,
		Timeout = tonumber(p_Args.timeout) or 180.0,
		Stuck = tonumber(p_Args.stuck) or 6.0,
	}, BotWalkerTask))
	return { bot = s_Bot.m_Id, points = #s_Points }
end

---@param p_Bridge DebugBridge
function BotWalker:Stop(p_Bridge)
	return p_Bridge:AbortTasks(function(p_Task)
		return getmetatable(p_Task) == BotWalkerTask
	end, 'stopped')
end

---Out of its vehicle, onto the first point, and off.
---@return boolean started (false: still getting out)
function BotWalkerTask:_Begin()
	local s_Bot = self.Bot
	if _InVehicle(s_Bot.m_Player) then
		if self.ExitSince == nil then
			self.ExitSince = m_Utilities:GetTime()
			s_Bot:ExitVehicle()
		elseif m_Utilities:GetTime() - self.ExitSince > EXIT_TIMEOUT then
			error('the bot did not get out of its vehicle')
		end
		return false
	end
	local s_Soldier = s_Bot.m_Player.soldier
	if self.Place then
		local s_Transform = s_Soldier.worldTransform:Clone()
		s_Transform.trans = self.Points[1].Position:Clone()
		s_Soldier:SetTransform(s_Transform)
	end
	-- Not ResetVars: that makes the bot inactive (NoRespawn). It doesn't shoot while it walks.
	s_Bot._Shoot = false
	s_Bot._ShootPlayer = nil
	s_Bot._ShootPlayerId = -1
	s_Bot._ActiveAction = BotActionFlags.NoActionActive
	s_Bot._TargetPoint = nil
	s_Bot._NextTargetPoint = nil
	s_Bot._ShootWayPoints = {}
	s_Bot.m_Zone = nil
	s_Bot.m_Border = nil
	s_Bot._RemoteWalk = { CommandId = self.CommandId }
	s_Bot._FollowWayPoints = self.Points
	self.Points = nil
	local s_Now = m_Utilities:GetTime()
	local s_Here = s_Soldier.worldTransform.trans:Clone()
	self.Started = s_Now
	self.Anchor = s_Here
	self.AnchorTime = s_Now
	self.Trail = { _Vec(s_Here) }
	self.Last = s_Here
	return true
end

---@param p_Bridge DebugBridge
---@param p_Status string
---@param p_Position Vec3|nil
function BotWalkerTask:_Finish(p_Bridge, p_Status, p_Position)
	local s_Bot = self.Bot
	local s_Remaining = self.Points ~= nil and self.Total or (s_Bot._FollowWayPoints and #s_Bot._FollowWayPoints or self.Total)
	if s_Bot._RemoteWalk ~= nil and s_Bot._RemoteWalk.CommandId == self.CommandId then
		s_Bot._RemoteWalk = nil
		s_Bot._FollowWayPoints = {}
	end
	p_Bridge:Reply(self.CommandId, true, {
		status = p_Status,
		reached = self.Total - s_Remaining,
		bot = s_Bot.m_Id,
		pos = p_Position and _Vec(p_Position) or nil,
		time = DebugBridge.Round(m_Utilities:GetTime() - (self.Started or m_Utilities:GetTime()), 1),
		trail = self.Trail,
	})
end

---@param p_Bridge DebugBridge
---@return boolean done
function BotWalkerTask:Update(p_Bridge)
	local s_Bot = self.Bot
	local s_Soldier = s_Bot.m_Player and s_Bot.m_Player.soldier
	if self.Points ~= nil then
		if s_Soldier == nil then
			error('the bot died before it started')
		end
		self:_Begin()
		return false
	end
	if s_Soldier == nil or s_Bot._RemoteWalk == nil or s_Bot._RemoteWalk.CommandId ~= self.CommandId then
		self:_Finish(p_Bridge, s_Soldier == nil and 'dead' or 'stopped', nil)
		return true
	end
	local s_Now = m_Utilities:GetTime()
	local s_Here = s_Soldier.worldTransform.trans
	if s_Here:Distance(self.Last) >= TRAIL_STEP then
		self.Last = s_Here:Clone()
		self.Trail[#self.Trail + 1] = _Vec(s_Here)
	end
	if #s_Bot._FollowWayPoints == 0 then
		self:_Finish(p_Bridge, 'done', s_Here)
		return true
	end
	-- Out of the combat-area (GameDirector:OnCombatArea): no way there.
	if s_Bot.m_Border ~= nil then
		self:_Finish(p_Bridge, 'border', s_Here)
		return true
	end
	if s_Here:Distance(self.Anchor) >= STUCK_DISTANCE then
		self.Anchor = s_Here:Clone()
		self.AnchorTime = s_Now
	elseif s_Now - self.AnchorTime > self.Stuck then
		self:_Finish(p_Bridge, 'stuck', s_Here)
		return true
	end
	if s_Now - self.Started > self.Timeout then
		self:_Finish(p_Bridge, 'timeout', s_Here)
		return true
	end
	return false
end

---@param p_Bridge DebugBridge
---@param p_Reason string
function BotWalkerTask:Abort(p_Bridge, p_Reason)
	local s_Bot = self.Bot
	if s_Bot._RemoteWalk ~= nil and s_Bot._RemoteWalk.CommandId == self.CommandId then
		s_Bot._RemoteWalk = nil
		s_Bot._FollowWayPoints = {}
	end
	p_Bridge:Reply(self.CommandId, false, 'walk aborted: ' .. p_Reason)
end

if g_BotWalker == nil then
	---@type BotWalker
	g_BotWalker = BotWalker()
end

return g_BotWalker
