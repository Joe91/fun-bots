---@class DebugCommands
---@overload fun():DebugCommands
DebugCommands = class('DebugCommands')

-- The built-in commands of the debug-server. Each gets the args-table of the command and returns the data of the
-- answer (or DebugBridge.ASYNC and answers later). Errors are sent back as failed answer.
--   ping                                        -> { time }
--   channels        { <channel> = bool, ... }   switch parts of the snapshot / the traces on and off
--   interval        { seconds }                 time between two snapshots
--   server_raycasts { enabled }                 Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS at runtime
--   raycast         { from, to, detailed, maxHits }   -> all hits of one raycast
--   bot             { id }                      -> all plain fields of a bot (Bot.lua)
--   nodes           {}                          streams all waypoints as "nodes" events
--   scan            see MapScanner:Start        streams the scan as "scan_row" events
--   scan_stop       { scan }                    stops one (or all) scans

---@type DebugBridge
local m_DebugBridge = require('Debug/DebugBridge')
---@type MapScanner
local m_MapScanner = require('Debug/MapScanner')
---@type ServerRaycasts
local m_ServerRaycasts = require('ServerRaycasts')
---@type BotManager
local m_BotManager = require('BotManager')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')

local _Vec = DebugBridge.Vec
local _Round = DebugBridge.Round

-- Waypoints per "nodes" event.
local NODES_PER_EVENT = 2000

---@param p_Value any
---@param p_Name string
---@return Vec3
local function _ToVec3(p_Value, p_Name)
	local s_X = type(p_Value) == 'table' and tonumber(p_Value[1])
	local s_Y = type(p_Value) == 'table' and tonumber(p_Value[2])
	local s_Z = type(p_Value) == 'table' and tonumber(p_Value[3])
	if not s_X or not s_Y or not s_Z then
		error(p_Name .. ' needs to be [x, y, z]')
	end
	return Vec3(s_X, s_Y, s_Z)
end

---JSON-safe copy of a value of a bot: plain values stay, everything else becomes a readable string.
---@param p_Value any
---@return any
local function _PlainValue(p_Value)
	local s_Type = type(p_Value)
	if s_Type == 'number' then
		if p_Value ~= p_Value or p_Value == math.huge or p_Value == -math.huge then
			return tostring(p_Value)
		end
		return p_Value
	elseif s_Type == 'string' or s_Type == 'boolean' then
		return p_Value
	elseif s_Type == 'table' then
		-- Weapons, vehicle-data and waypoints have a name or a position.
		if type(p_Value.name) == 'string' then
			return '<' .. p_Value.name .. '>'
		elseif type(p_Value.Name) == 'string' then
			return '<' .. p_Value.Name .. '>'
		elseif p_Value.Position ~= nil and p_Value.PathIndex ~= nil then
			return '<waypoint ' .. tostring(p_Value.PathIndex) .. ':' .. tostring(p_Value.PointIndex) .. '>'
		end
		return '<table>'
	elseif s_Type == 'userdata' then
		local s_Ok, s_String = pcall(tostring, p_Value)
		return s_Ok and s_String or '<userdata>'
	end
	return nil
end

function DebugCommands:__init()
	m_DebugBridge:RegisterCommand('ping', self.Ping)
	m_DebugBridge:RegisterCommand('channels', self.Channels)
	m_DebugBridge:RegisterCommand('interval', self.Interval)
	m_DebugBridge:RegisterCommand('server_raycasts', self.ServerRaycasts)
	m_DebugBridge:RegisterCommand('raycast', self.Raycast)
	m_DebugBridge:RegisterCommand('bot', self.Bot)
	m_DebugBridge:RegisterCommand('nodes', self.Nodes)
	m_DebugBridge:RegisterCommand('scan', self.Scan)
	m_DebugBridge:RegisterCommand('scan_stop', self.ScanStop)
end

function DebugCommands.Ping()
	return { time = SharedUtils:GetTime() }
end

function DebugCommands.Channels(p_Args, p_Bridge)
	for l_Name, l_Enabled in pairs(p_Args) do
		p_Bridge:SetChannel(l_Name, l_Enabled == true)
	end
	return p_Bridge:GetChannels()
end

function DebugCommands.Interval(p_Args, p_Bridge)
	local s_Seconds = tonumber(p_Args.seconds)
	if s_Seconds == nil then
		error('interval needs seconds')
	end
	p_Bridge:SetInterval(s_Seconds)
	return { seconds = s_Seconds }
end

function DebugCommands.ServerRaycasts(p_Args)
	if p_Args.enabled ~= nil then
		m_ServerRaycasts:SetEnabled(p_Args.enabled == true)
	end
	return { enabled = m_ServerRaycasts:IsEnabled() }
end

---A test-raycast, e.g. to find out which materials block the sight.
function DebugCommands.Raycast(p_Args)
	local s_From = _ToVec3(p_Args.from, 'from')
	local s_To = _ToVec3(p_Args.to, 'to')
	local s_MaxHits = math.max(1, math.min(tonumber(p_Args.maxHits) or 5, 20))
	local s_Flags = RayCastFlags.DontCheckWater
	---@cast s_Flags RayCastFlags

	local s_Hits
	if p_Args.detailed then
		---@type MaterialFlags|integer
		local s_NoMaterialFlags = 0
		s_Hits = RaycastManager:DetailedRaycast(s_From, s_To, s_MaxHits, s_NoMaterialFlags, s_Flags)
	else
		-- Same pass-through materials as the sight-checks.
		local s_PassThrough = MaterialFlags.MfSeeThrough | MaterialFlags.MfPenetrable | MaterialFlags.MfClientDestructible
		---@cast s_PassThrough MaterialFlags
		s_Hits = RaycastManager:CollisionRaycast(s_From, s_To, s_MaxHits, s_PassThrough, s_Flags)
	end

	local s_Result = {}
	for l_Index = 1, #s_Hits do
		local l_Hit = s_Hits[l_Index]
		local s_Entry = { pos = _Vec(l_Hit.position), normal = _Vec(l_Hit.normal), part = l_Hit.part }
		if l_Hit.rigidBody ~= nil then
			s_Entry.entity = l_Hit.rigidBody.typeInfo.name
			local s_Physics = PhysicsEntityBase(l_Hit.rigidBody)
			s_Entry.materialFlags = s_Physics:GetPartMaterialFlags(l_Hit.part)
			if s_Physics.userData ~= nil then
				s_Entry.owner = s_Physics.userData.typeInfo.name
			end
		end
		s_Result[#s_Result + 1] = s_Entry
	end

	m_DebugBridge:Trace('test', s_From, s_To, #s_Hits == 0, s_Hits[1] and s_Hits[1].position)
	return { from = _Vec(s_From), to = _Vec(s_To), hits = s_Result }
end

function DebugCommands.Bot(p_Args)
	local s_Bot = m_BotManager:GetBotById(tonumber(p_Args.id) or -1)
	if s_Bot == nil then
		error('no bot with id ' .. tostring(p_Args.id))
	end

	local s_Fields = {}
	for l_Key, l_Value in pairs(s_Bot) do
		if type(l_Key) == 'string' then
			s_Fields[l_Key] = _PlainValue(l_Value)
		end
	end

	local s_Soldier = s_Bot.m_Player.soldier
	if s_Soldier ~= nil then
		s_Fields.pos = _Vec(s_Soldier.worldTransform.trans)
		s_Fields.maxHealth = _Round(s_Soldier.maxHealth, 1)
	end
	return s_Fields
end

---Streams the waypoints of all paths, NODES_PER_EVENT per update.
function DebugCommands.Nodes(p_Args, p_Bridge, p_Command)
	local s_Paths = m_NodeCollection:GetPaths()
	local s_PathIndices = {}
	for l_PathIndex, l_Waypoints in pairs(s_Paths) do
		if #l_Waypoints > 0 then
			s_PathIndices[#s_PathIndices + 1] = l_PathIndex
		end
	end
	table.sort(s_PathIndices)

	p_Bridge:Event('nodes_started', { paths = #s_PathIndices })

	local s_Task = { CommandId = p_Command.id, Path = 1, Point = 1, Total = 0 }

	function s_Task.Update(p_Task, p_TaskBridge)
		local s_PathIndex = s_PathIndices[p_Task.Path]
		if s_PathIndex == nil then
			p_TaskBridge:Reply(p_Task.CommandId, true, { paths = #s_PathIndices, points = p_Task.Total })
			return true
		end

		local s_Waypoints = s_Paths[s_PathIndex] or {}
		local s_First = p_Task.Point
		local s_Last = math.min(#s_Waypoints, s_First + NODES_PER_EVENT - 1)
		local s_Points = {}
		for l_Index = s_First, s_Last do
			s_Points[#s_Points + 1] = _Vec(s_Waypoints[l_Index].Position)
		end

		local s_Event = { path = s_PathIndex, first = s_First, points = s_Points, last = s_Last >= #s_Waypoints }
		-- Objectives and vehicles of the path are stored at its first waypoint.
		local s_Data = s_First == 1 and s_Waypoints[1] and s_Waypoints[1].Data
		if type(s_Data) == 'table' then
			s_Event.objectives = s_Data.Objectives
			s_Event.vehicles = s_Data.Vehicles
		end
		p_TaskBridge:Event('nodes', s_Event)

		p_Task.Total = p_Task.Total + #s_Points
		if s_Last >= #s_Waypoints then
			p_Task.Path = p_Task.Path + 1
			p_Task.Point = 1
		else
			p_Task.Point = s_Last + 1
		end
		return false
	end

	function s_Task.Abort(p_Task, p_TaskBridge, p_Reason)
		p_TaskBridge:Reply(p_Task.CommandId, false, 'nodes aborted: ' .. p_Reason)
	end

	p_Bridge:AddTask(s_Task)
	return DebugBridge.ASYNC
end

function DebugCommands.Scan(p_Args, p_Bridge, p_Command)
	m_MapScanner:Start(p_Bridge, p_Command.id, p_Args)
	return DebugBridge.ASYNC
end

function DebugCommands.ScanStop(p_Args, p_Bridge)
	return { stopped = m_MapScanner:Stop(p_Bridge, tonumber(p_Args.scan)) }
end

if g_DebugCommands == nil then
	---@type DebugCommands
	g_DebugCommands = DebugCommands()
end

return g_DebugCommands
