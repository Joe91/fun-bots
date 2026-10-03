---@class ZoneProbe
---@overload fun():ZoneProbe
ZoneProbe = class('ZoneProbe')

-- Measures the capture zones: the engine doesn't tell their size (CapturePointEntityData.CaptureRadius is 0, the real
-- one comes from the level), but it tells who is inside (CapturePointEntity.playersInside). Bots get put around each
-- capture point, one per direction, and the distance is searched where they stop being inside. Runs as task of the
-- DebugBridge, a few seconds per capture point. The bots are left wherever they were put: meant for the census
-- (tools/debug-server, census run), which kicks them afterwards.
--   zone_probe  { flags = { { name, pos, active, directions = { { angle, inside, outside } } } } }
-- inside: the farthest distance found inside, outside: the closest one found outside (metres, horizontal, at the height
-- of the capture point). A capture point nobody is inside of even next to it is not active (the layout of another mode,
-- loaded as well, e.g. a second "C" on XP3_Alborz).

---@type BotManager
local m_BotManager = require('BotManager')
---@type Utilities
local m_Utilities = require('__shared/Utilities')

local _Vec = DebugBridge.Vec
local _Round = DebugBridge.Round

local DIRECTIONS = 16     -- Directions around each capture point.
local NEAR = 1.0          -- First test this close to the capture point: inside here, or the capture point isn't active.
local FAR = 100.0         -- No zone is larger.
local STEPS = 7           -- Halvings between NEAR and FAR: about 0.8 m exact.
local WAIT = 0.25         -- Seconds a bot stays at a position before the engine is asked whether it is inside.

---@class ZoneProbeTask
---@field CommandId integer
---@field Flags table[] { Entity, Name, Center, Active, Directions = { { Angle, Inside, Outside } } }
---@field Flag integer the capture point measured now
---@field Batch integer first direction of the current batch
---@field Step integer 0: NEAR, then the halvings
---@field BatchSize integer directions of the current batch
---@field Probes table[] { Bot, Direction, Distance, Position } of the current step
---@field Since number when the bots were put to the positions of the step
local ZoneProbeTask = {}
ZoneProbeTask.__index = ZoneProbeTask

function ZoneProbe:__init()
end

---The capture points without the HQs (bases, no zones to walk around in).
---@return table[]
local function _Flags()
	local s_Flags = {}
	local s_Iterator = EntityManager:GetIterator('ServerCapturePointEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		local s_CapturePoint = CapturePointEntity(s_Entity)
		if string.sub(s_CapturePoint.name, -2) ~= 'HQ' then
			local s_Directions = {}
			for l_Index = 1, DIRECTIONS do
				s_Directions[l_Index] = { Angle = (l_Index - 1) * 2 * math.pi / DIRECTIONS, Inside = 0.0, Outside = FAR }
			end
			s_Flags[#s_Flags + 1] = {
				Entity = s_CapturePoint,
				Name = s_CapturePoint.name,
				Center = s_CapturePoint.transform.trans:Clone(),
				Active = false,
				Directions = s_Directions,
			}
		end
		s_Entity = s_Iterator:Next()
	end
	return s_Flags
end

---Bots on foot, alive.
---@return Bot[]
local function _ProbeBots()
	local s_Result = {}
	local s_Bots = m_BotManager:GetBots()
	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		local s_Player = l_Bot.m_Player
		if s_Player ~= nil and s_Player.soldier ~= nil and s_Player.attachedControllable == nil then
			s_Result[#s_Result + 1] = l_Bot
		end
	end
	return s_Result
end

---@param p_Bridge DebugBridge
---@param p_CommandId integer
---@return table info
function ZoneProbe:Start(p_Bridge, p_CommandId)
	p_Bridge:AbortTasks(function(p_Task)
		return getmetatable(p_Task) == ZoneProbeTask
	end, 'stopped')

	local s_Flags = _Flags()
	if #_ProbeBots() == 0 and #s_Flags > 0 then
		error('no bots alive to measure the capture zones with')
	end
	local s_Task = setmetatable({
		CommandId = p_CommandId,
		Flags = s_Flags,
		Flag = 1,
		Batch = 1,
		Step = 0,
		BatchSize = 0,
		Probes = {},
		Since = nil,
	}, ZoneProbeTask)
	p_Bridge:AddTask(s_Task)
	return { flags = #s_Flags }
end

---The distance to test next in the direction.
---@param p_Direction table
---@param p_Step integer
---@return number
local function _Distance(p_Direction, p_Step)
	if p_Step == 0 then
		return NEAR
	end
	return (p_Direction.Inside + p_Direction.Outside) / 2
end

---Puts the bots of the current step to their positions (again: they would walk away).
function ZoneProbeTask:_Place()
	for l_Index = 1, #self.Probes do
		local l_Probe = self.Probes[l_Index]
		local s_Soldier = l_Probe.Bot.m_Player and l_Probe.Bot.m_Player.soldier
		if s_Soldier ~= nil then
			local s_Transform = s_Soldier.worldTransform:Clone()
			s_Transform.trans = l_Probe.Position
			s_Soldier:SetTransform(s_Transform)
		end
	end
end

---Starts the next step of the current batch of directions: one bot per direction.
---@return boolean false if there are no bots
function ZoneProbeTask:_StartStep()
	local s_Flag = self.Flags[self.Flag]
	local s_Bots = _ProbeBots()
	if #s_Bots == 0 then
		return false
	end
	self.Probes = {}
	local s_Last = math.min(#s_Flag.Directions, self.Batch + #s_Bots - 1)
	self.BatchSize = s_Last - self.Batch + 1
	for l_Index = self.Batch, s_Last do
		local l_Direction = s_Flag.Directions[l_Index]
		local s_Distance = _Distance(l_Direction, self.Step)
		self.Probes[#self.Probes + 1] = {
			Bot = s_Bots[l_Index - self.Batch + 1],
			Direction = l_Direction,
			Distance = s_Distance,
			Position = s_Flag.Center + Vec3(math.cos(l_Direction.Angle) * s_Distance, 0.0,
				math.sin(l_Direction.Angle) * s_Distance),
		}
	end
	self.Since = m_Utilities:GetTime()
	self:_Place()
	return true
end

---Reads who is inside and narrows the directions down.
function ZoneProbeTask:_Read()
	local s_Flag = self.Flags[self.Flag]
	local s_Inside = {}
	for _, l_Player in pairs(s_Flag.Entity.playersInside) do
		s_Inside[l_Player.id] = true
	end
	for l_Index = 1, #self.Probes do
		local l_Probe = self.Probes[l_Index]
		local s_Player = l_Probe.Bot.m_Player
		-- A bot that died meanwhile tells nothing.
		if s_Player ~= nil and s_Player.soldier ~= nil then
			if s_Inside[s_Player.id] then
				l_Probe.Direction.Inside = math.max(l_Probe.Direction.Inside, l_Probe.Distance)
				s_Flag.Active = true
			else
				l_Probe.Direction.Outside = math.min(l_Probe.Direction.Outside, l_Probe.Distance)
			end
		end
	end
	self.Probes = {}
end

---Next step, batch or capture point. false when all are measured.
---@return boolean
function ZoneProbeTask:_Advance()
	local s_Flag = self.Flags[self.Flag]
	-- Nobody inside next to the capture point (first batch): not active, no need to search further.
	local s_Inactive = self.Step == 0 and self.Batch == 1 and not s_Flag.Active
	if self.Step < STEPS and not s_Inactive then
		self.Step = self.Step + 1
		return true
	end
	self.Step = 0
	self.Batch = self.Batch + self.BatchSize
	if self.Batch <= #s_Flag.Directions and not s_Inactive then
		return true
	end
	self.Batch = 1
	self.Flag = self.Flag + 1
	return self.Flag <= #self.Flags
end

---@param p_Bridge DebugBridge
---@return boolean done
function ZoneProbeTask:Update(p_Bridge)
	if self.Flag <= #self.Flags then
		if #self.Probes == 0 then
			if not self:_StartStep() then
				error('no bots alive to measure the capture zones with')
			end
			return false
		end
		if m_Utilities:GetTime() - self.Since < WAIT then
			self:_Place()
			return false
		end
		self:_Read()
		if self:_Advance() then
			return false
		end
	end

	local s_Result = {}
	for l_Index = 1, #self.Flags do
		local l_Flag = self.Flags[l_Index]
		local s_Directions = {}
		for l_Direction = 1, #l_Flag.Directions do
			local s_Direction = l_Flag.Directions[l_Direction]
			s_Directions[l_Direction] = {
				angle = _Round(s_Direction.Angle, 3),
				inside = _Round(s_Direction.Inside, 1),
				outside = _Round(s_Direction.Outside, 1),
			}
		end
		s_Result[l_Index] = { name = l_Flag.Name, pos = _Vec(l_Flag.Center), active = l_Flag.Active, directions = s_Directions }
	end
	p_Bridge:Event('zone_probe', { flags = s_Result })
	p_Bridge:Reply(self.CommandId, true, { flags = #s_Result })
	return true
end

---@param p_Bridge DebugBridge
---@param p_Reason string
function ZoneProbeTask:Abort(p_Bridge, p_Reason)
	p_Bridge:Reply(self.CommandId, false, 'zone probe aborted: ' .. p_Reason)
end

if g_ZoneProbe == nil then
	---@type ZoneProbe
	g_ZoneProbe = ZoneProbe()
end

return g_ZoneProbe
