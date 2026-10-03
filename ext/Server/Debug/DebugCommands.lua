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
--   paths_apply     { paths, save }             objectives, loop and links from the labeler of the debug-server
--                                               (funbots_debug/paths), see DebugCommands.PathsApply
--   scan            see MapScanner:Start        streams the scan as "scan_row" events
--   scan_stop       { scan }                    stops one (or all) scans
--   census          see MapCensus:Start         everything about the level for the waypoint-tools, streamed as
--                                               "census_*" events (funbots_debug/census)
--   census_stop     {}                          stops a running census
--   navzones_apply  { map, mesh, save }         the walking mesh and its zones (NavZones.lua), save: into mod.db
--   rcon            { command, args }           any RCON-command (also the vanilla ones) -> { lines }
--   chat            { message, player }         a chat-command, as the player with that id or (no player) as
--                                               ChatCommands.CONSOLE with all permissions -> { lines }

---@type DebugBridge
local m_DebugBridge = require('Debug/DebugBridge')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type MapScanner
local m_MapScanner = require('Debug/MapScanner')
---@type MapCensus
local m_MapCensus = require('Debug/MapCensus')
---@type NavZones
local m_NavZones = require('NavZones')
---@type ServerRaycasts
local m_ServerRaycasts = require('ServerRaycasts')
---@type BotManager
local m_BotManager = require('BotManager')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type ChatCommands
local m_ChatCommands = require('Commands/Chat')
---@type NodeEditor
local m_NodeEditor = require('NodeEditor')
---@type GameDirector
local m_GameDirector = require('GameDirector')

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

---Data of a waypoint as it is saved: the links as {path, point} instead of waypoint-IDs (NodeCollection:Save).
---@param p_Data table
---@return table
local function _SavedData(p_Data)
	local s_Data = {}
	for l_Key, l_Value in pairs(p_Data) do
		s_Data[l_Key] = l_Value
	end
	if type(p_Data.Links) == 'table' then
		local s_Links = {}
		for l_Index = 1, #p_Data.Links do
			local l_Link = p_Data.Links[l_Index]
			local s_Linked = type(l_Link) == 'string' and m_NodeCollection:Get(l_Link) or nil
			if s_Linked ~= nil then
				s_Links[#s_Links + 1] = { s_Linked.PathIndex, s_Linked.PointIndex }
			elseif type(l_Link) == 'table' then
				s_Links[#s_Links + 1] = l_Link -- Pointed nowhere at load.
			end
		end
		s_Data.Links = s_Links
	end
	return s_Data
end

function DebugCommands:__init()
	m_DebugBridge:RegisterCommand('ping', self.Ping)
	m_DebugBridge:RegisterCommand('channels', self.Channels)
	m_DebugBridge:RegisterCommand('interval', self.Interval)
	m_DebugBridge:RegisterCommand('server_raycasts', self.ServerRaycasts)
	m_DebugBridge:RegisterCommand('raycast', self.Raycast)
	m_DebugBridge:RegisterCommand('bot', self.Bot)
	m_DebugBridge:RegisterCommand('nodes', self.Nodes)
	m_DebugBridge:RegisterCommand('paths_apply', self.PathsApply)
	m_DebugBridge:RegisterCommand('scan', self.Scan)
	m_DebugBridge:RegisterCommand('scan_stop', self.ScanStop)
	m_DebugBridge:RegisterCommand('census', self.Census)
	m_DebugBridge:RegisterCommand('census_stop', self.CensusStop)
	m_DebugBridge:RegisterCommand('navzones_apply', self.NavZonesApply)
	m_DebugBridge:RegisterCommand('rcon', self.Rcon)
	m_DebugBridge:RegisterCommand('chat', self.Chat)
end

function DebugCommands.Ping()
	return { time = m_Utilities:GetTime() }
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
		end
		-- Same source as Utilities:IsInSight. No cast of the rigidBody or its userData (crashes on some entities).
		if l_Hit.material ~= nil and l_Hit.material:Is('MaterialContainerPair') then
			s_Entry.materialFlags = MaterialContainerPair(l_Hit.material).flagsAndIndex
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
		local s_Inputs = {}
		local s_Data = {}
		for l_Index = s_First, s_Last do
			local l_Waypoint = s_Waypoints[l_Index]
			s_Points[#s_Points + 1] = _Vec(l_Waypoint.Position)
			s_Inputs[#s_Inputs + 1] = l_Waypoint.InputVar
			if type(l_Waypoint.Data) == 'table' and next(l_Waypoint.Data) ~= nil then
				s_Data[#s_Data + 1] = { l_Index, _SavedData(l_Waypoint.Data) }
			end
		end

		-- inputs: inputVar of every point, data: {point, data} of the points with data, links as {path, point}.
		local s_Event = {
			path = s_PathIndex,
			first = s_First,
			points = s_Points,
			inputs = s_Inputs,
			data = s_Data,
			last = s_Last >= #s_Waypoints,
		}
		-- Objectives and vehicles of the path are stored at its first waypoint.
		local s_FirstData = s_First == 1 and s_Waypoints[1] and s_Waypoints[1].Data
		if type(s_FirstData) == 'table' then
			s_Event.objectives = s_FirstData.Objectives
			s_Event.vehicles = s_FirstData.Vehicles
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

---Takes over the objectives, loop and links the labeler of the debug-server computed (funbots_debug/paths).
---  paths: { { path, count, objectives?, loop?, links? = { { point, { { path, point }, ... } }, ... } }, ... }
---         count is the number of waypoints the labeler saw, objectives an empty list removes them, links replace
---         the links of each listed point.
---  save:  save the paths into the database afterwards.
---Everything is checked before anything changes, so paths edited in the meantime are refused as a whole.
function DebugCommands.PathsApply(p_Args)
	local s_Entries = type(p_Args.paths) == 'table' and p_Args.paths or {}
	-- Not NodeCollection:Get(point, path), it adds an empty path for an unknown index.
	local s_Paths = m_NodeCollection:GetPaths()

	local function _Waypoint(p_Link)
		local s_Waypoints = type(p_Link) == 'table' and s_Paths[tonumber(p_Link[1])]
		local s_Waypoint = s_Waypoints and s_Waypoints[tonumber(p_Link[2])]
		if not s_Waypoint then
			error('no waypoint ' .. tostring(p_Link and p_Link[1]) .. ':' .. tostring(p_Link and p_Link[2]))
		end
		return s_Waypoint
	end

	for l_Index = 1, #s_Entries do
		local l_Entry = s_Entries[l_Index]
		local s_Waypoints = s_Paths[tonumber(l_Entry.path)] or {}
		if #s_Waypoints == 0 or #s_Waypoints ~= tonumber(l_Entry.count) then
			error('path ' .. tostring(l_Entry.path) .. ' changed in the meantime, load the waypoints again')
		end
		for l_LinkIndex = 1, #(l_Entry.links or {}) do
			local l_Links = l_Entry.links[l_LinkIndex]
			_Waypoint({ l_Entry.path, l_Links[1] })
			for l_TargetIndex = 1, #(l_Links[2] or {}) do
				_Waypoint(l_Links[2][l_TargetIndex])
			end
		end
	end

	local s_Updated = {}
	local s_Count = 0
	for l_Index = 1, #s_Entries do
		local l_Entry = s_Entries[l_Index]
		local s_First = s_Paths[tonumber(l_Entry.path)][1]

		if l_Entry.objectives ~= nil then
			s_First.Data.Objectives = #l_Entry.objectives > 0 and l_Entry.objectives or nil
			s_Updated[s_First.ID] = s_First
		end

		if l_Entry.loop ~= nil then
			s_First.OptValue = l_Entry.loop and 0 or 0xFF
			m_NodeCollection:UpdateInputVar(s_First)
			s_Updated[s_First.ID] = s_First
		end

		for l_LinkIndex = 1, #(l_Entry.links or {}) do
			local l_Links = l_Entry.links[l_LinkIndex]
			local s_Waypoint = _Waypoint({ l_Entry.path, l_Links[1] })
			local s_Ids = {}
			for l_TargetIndex = 1, #(l_Links[2] or {}) do
				s_Ids[#s_Ids + 1] = _Waypoint(l_Links[2][l_TargetIndex]).ID
			end
			if #s_Ids > 0 then
				s_Waypoint.Data.LinkMode = s_Waypoint.Data.LinkMode or 0
				s_Waypoint.Data.Links = s_Ids
			else
				s_Waypoint.Data.LinkMode = nil
				s_Waypoint.Data.Links = nil
			end
			s_Updated[s_Waypoint.ID] = s_Waypoint
		end
		s_Count = s_Count + 1
	end

	m_NodeCollection:ParseObjectives()
	m_GameDirector:ReloadObjectives()

	local s_UpdatedList = {}
	for _, l_Waypoint in pairs(s_Updated) do
		s_UpdatedList[#s_UpdatedList + 1] = l_Waypoint
	end
	-- Players with the node-editor open see the changes too.
	m_NodeEditor:SendToAllPlayers('ClientNodeEditor:UpdateNodes', m_NodeEditor:GetNodesForPlayer(s_UpdatedList))

	if p_Args.save then
		m_NodeCollection:Save('debug-server')
	end
	return { paths = s_Count, waypoints = #s_UpdatedList, saved = p_Args.save == true }
end

function DebugCommands.Scan(p_Args, p_Bridge, p_Command)
	m_MapScanner:Start(p_Bridge, p_Command.id, p_Args)
	return DebugBridge.ASYNC
end

function DebugCommands.ScanStop(p_Args, p_Bridge)
	return { stopped = m_MapScanner:Stop(p_Bridge, tonumber(p_Args.scan)) }
end

function DebugCommands.Census(p_Args, p_Bridge, p_Command)
	m_MapCensus:Start(p_Bridge, p_Command.id, p_Args)
	return DebugBridge.ASYNC
end

function DebugCommands.CensusStop(p_Args, p_Bridge)
	return { stopped = m_MapCensus:Stop(p_Bridge) }
end

function DebugCommands.NavZonesApply(p_Args)
	if p_Args.map ~= m_NodeCollection:GetMapName() then
		error('the networks are for ' .. tostring(p_Args.map) .. ', the level is ' .. m_NodeCollection:GetMapName())
	end
	-- Bots on the mesh walk on the old one: back to the waypoints, they go onto the new one at the next junction.
	local s_Bots = m_BotManager:GetBots()
	for l_Index = 1, #s_Bots do
		if s_Bots[l_Index].m_Zone ~= nil then
			s_Bots[l_Index]:_LeaveZone(nil)
		end
	end
	if type(p_Args.mesh) ~= 'table' then
		error('navzones_apply needs the mesh')
	end
	local s_Zones, s_Junctions = m_NavZones:Apply(p_Args.mesh, p_Args.save == true)
	return { zones = s_Zones, junctions = s_Junctions, saved = p_Args.save == true }
end

function DebugCommands.Rcon(p_Args)
	if type(p_Args.command) ~= 'string' or p_Args.command == '' then
		error('rcon needs a command')
	end

	local s_Args = {}
	if type(p_Args.args) == 'table' then
		for l_Index = 1, #p_Args.args do
			s_Args[l_Index] = tostring(p_Args.args[l_Index])
		end
	end

	return { lines = RCON:SendCommand(p_Args.command, s_Args) }
end

function DebugCommands.Chat(p_Args)
	if type(p_Args.message) ~= 'string' or p_Args.message == '' then
		error('chat needs a message')
	end

	local s_Player = nil
	if p_Args.player ~= nil then
		s_Player = PlayerManager:GetPlayerById(tonumber(p_Args.player) or -1)
		if s_Player == nil then
			error('no player with id ' .. tostring(p_Args.player))
		end
	end

	return { lines = m_ChatCommands:ExecuteCaptured(p_Args.message, s_Player) }
end

if g_DebugCommands == nil then
	---@type DebugCommands
	g_DebugCommands = DebugCommands()
end

return g_DebugCommands
