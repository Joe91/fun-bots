---@class NavZones
---@overload fun():NavZones
NavZones = class('NavZones')

-- Walking networks of the zones around the objectives. Inside such a zone the bots walk freely from point to point
-- (Bot/BotZoneMovement.lua) instead of following waypoints. The networks are made by the debug-server from a census of
-- the level (tools/debug-server/funbots_debug/census/navzones.py) and saved in the table <map>_navzones of mod.db,
-- one row per zone: name, data (JSON). Format of data:
--   points  { { x, y, z, clearance, cover, flags } }  flags: 1 = in the zone, 2 = indoors, 4 = crouch
--   edges   { { a, b, length, { corner, ... } } }     a, b count from 0, corners { x, y, z } between a and b
--   attach  { { path, point, network-point, distance, { x, y, z } } }  junctions with the waypoints

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Logger
local m_Logger = Logger('NavZones', Debug.Server.PATH)

NavZoneFlags = {
	InZone = 1,
	Indoor = 2,
	Crouch = 4,
}

-- A junction is only used if its waypoint is still where the network was made for (the paths may have been edited).
local JUNCTION_TOLERANCE = 1.0
-- Points this far above or below a position are on another floor.
local FLOOR_HEIGHT = 1.5
-- Extra cost of a connection a bot got stuck on, per time (all bots avoid it then, until the level ends).
local BLOCKED_PENALTY = 50.0

---@class NavZonePoint
---@field Index integer
---@field Position Vec3
---@field Clearance number
---@field Cover integer
---@field Flags integer

---@class NavZoneJunction
---@field PathIndex integer
---@field PointIndex integer
---@field Position Vec3 where the waypoint was when the network was made
---@field Point integer the point of the network
---@field Corners Vec3[] the way from the point to the waypoint (around walls)
---@field Waypoint Waypoint|nil set by _LinkJunctions

---@class NavZone
---@field Name string the objective
---@field Kind string capturepoint | mcom
---@field Center Vec3
---@field Points NavZonePoint[]
---@field Neighbours table<integer, { To: integer, Cost: number, Corners: Vec3[], Penalty: number }[]>
---@field Inside integer[] the points in the zone
---@field Junctions NavZoneJunction[]
---@field Vehicle NavZone|nil the network of the land vehicles in the zone
---@field Part table<integer, integer> point -> number of its connected part (points of different parts have no way)

function NavZones:__init()
	self:Clear()
end

function NavZones:Clear()
	---@type table<string, NavZone>
	self._Zones = {}
	---waypoint-ID -> { Zone, Junction }
	self._Junctions = {}
	---waypoint-ID -> { Zone (the vehicle-network), Junction }
	self._VehicleJunctions = {}
	self._Count = 0
end

-- =============================================
-- Loading and saving
-- =============================================

---After the waypoints of the level are loaded.
function NavZones:OnLoadFinished()
	self:Clear()
	if not Registry.BOT.USE_ZONE_NETWORKS then
		return
	end

	local s_Table = m_NodeCollection:GetMapName() .. '_navzones'
	if not SQL:Open() then
		m_Logger:Error('Failed to open SQL. ' .. SQL:Error())
		return
	end

	local s_Exists = SQL:Query("select name from sqlite_master where type='table' and name='" .. s_Table .. "'")
	if s_Exists and #s_Exists > 0 then
		local s_Rows = SQL:Query('SELECT data FROM ' .. s_Table) or {}
		for l_Index = 1, #s_Rows do
			local s_Ok, s_Data = pcall(json.decode, s_Rows[l_Index].data)
			if s_Ok and type(s_Data) == 'table' then
				self:_AddZone(s_Data)
			else
				m_Logger:Error('invalid zone in ' .. s_Table)
			end
		end
	end
	SQL:Close()

	self:_LinkJunctions()
	print('[NavZones] ' .. self._Count .. ' zone-networks for ' .. m_NodeCollection:GetMapName())
end

---Takes over the networks of the debug-server (DebugCommands "navzones_apply").
---@param p_Zones table[] zones as in the table
---@param p_Save boolean also save them in mod.db
---@return integer zones, integer junctions
function NavZones:Apply(p_Zones, p_Save)
	self:Clear()
	for l_Index = 1, #p_Zones do
		self:_AddZone(p_Zones[l_Index])
	end
	local s_Junctions = self:_LinkJunctions()

	if p_Save then
		self:_Save(p_Zones)
	end
	return self._Count, s_Junctions
end

---@param p_Zones table[]
function NavZones:_Save(p_Zones)
	local s_Table = m_NodeCollection:GetMapName() .. '_navzones'
	if not SQL:Open() then
		m_Logger:Error('Failed to open SQL. ' .. SQL:Error())
		return
	end

	SQL:Query('DROP TABLE IF EXISTS ' .. s_Table)
	SQL:Query('CREATE TABLE ' .. s_Table .. ' (name TEXT, data TEXT)')
	SQL:Query('BEGIN TRANSACTION')
	for l_Index = 1, #p_Zones do
		local l_Zone = p_Zones[l_Index]
		local s_Name = tostring(l_Zone.name):gsub("'", "''")
		local s_Data = json.encode(l_Zone):gsub("'", "''")
		SQL:Query('INSERT INTO ' .. s_Table .. " (name, data) VALUES ('" .. s_Name .. "', '" .. s_Data .. "')")
	end
	SQL:Query('COMMIT')
	SQL:Close()
end

---One network (points, edges, attach) of a zone.
---@param p_Data table
---@param p_Name string
---@param p_Kind string
---@param p_Center Vec3
---@return NavZone
local function _ParseNetwork(p_Data, p_Name, p_Kind, p_Center)
	---@type NavZone
	local s_Zone = {
		Name = p_Name,
		Kind = p_Kind,
		Center = p_Center,
		Points = {},
		Neighbours = {},
		Inside = {},
		Junctions = {},
	}

	local s_Points = p_Data.points or {}
	for l_Index = 1, #s_Points do
		local l_Point = s_Points[l_Index]
		local s_Flags = math.floor(tonumber(l_Point[6]) or 0)
		s_Zone.Points[l_Index] = {
			Index = l_Index,
			Position = Vec3(l_Point[1], l_Point[2], l_Point[3]),
			Clearance = tonumber(l_Point[4]) or 0,
			Cover = math.floor(tonumber(l_Point[5]) or 0),
			Flags = s_Flags,
		}
		s_Zone.Neighbours[l_Index] = {}
		if s_Flags & NavZoneFlags.InZone ~= 0 then
			s_Zone.Inside[#s_Zone.Inside + 1] = l_Index
		end
	end

	local s_Edges = p_Data.edges or {}
	for l_Index = 1, #s_Edges do
		local l_Edge = s_Edges[l_Index]
		local s_A = math.floor(l_Edge[1]) + 1
		local s_B = math.floor(l_Edge[2]) + 1
		if s_Zone.Points[s_A] ~= nil and s_Zone.Points[s_B] ~= nil then
			local s_Corners = {}
			local s_Reversed = {}
			local s_Raw = l_Edge[4] or {}
			for l_Corner = 1, #s_Raw do
				s_Corners[l_Corner] = Vec3(s_Raw[l_Corner][1], s_Raw[l_Corner][2], s_Raw[l_Corner][3])
			end
			for l_Corner = #s_Corners, 1, -1 do
				s_Reversed[#s_Reversed + 1] = s_Corners[l_Corner]
			end
			local s_Cost = tonumber(l_Edge[3]) or s_Zone.Points[s_A].Position:Distance(s_Zone.Points[s_B].Position)
			table.insert(s_Zone.Neighbours[s_A], { To = s_B, Cost = s_Cost, Corners = s_Corners, Penalty = 0.0 })
			table.insert(s_Zone.Neighbours[s_B], { To = s_A, Cost = s_Cost, Corners = s_Reversed, Penalty = 0.0 })
		end
	end

	local s_Attach = p_Data.attach or {}
	for l_Index = 1, #s_Attach do
		local l_Entry = s_Attach[l_Index]
		local s_Pos = l_Entry[5] or {}
		local s_Corners = {}
		local s_RawCorners = type(l_Entry[6]) == 'table' and l_Entry[6] or {}
		for l_Corner = 1, #s_RawCorners do
			s_Corners[l_Corner] = Vec3(s_RawCorners[l_Corner][1], s_RawCorners[l_Corner][2], s_RawCorners[l_Corner][3])
		end
		s_Zone.Junctions[#s_Zone.Junctions + 1] = {
			PathIndex = math.floor(l_Entry[1]),
			PointIndex = math.floor(l_Entry[2]),
			Point = math.floor(l_Entry[3]) + 1,
			Position = Vec3(tonumber(s_Pos[1]) or 0, tonumber(s_Pos[2]) or 0, tonumber(s_Pos[3]) or 0),
			Corners = s_Corners,
		}
	end

	-- Connected parts: a bot only goes where a way leads.
	s_Zone.Part = {}
	local s_PartCount = 0
	for l_Start = 1, #s_Zone.Points do
		if s_Zone.Part[l_Start] == nil then
			s_PartCount = s_PartCount + 1
			s_Zone.Part[l_Start] = s_PartCount
			local s_Stack = { l_Start }
			while #s_Stack > 0 do
				local s_Current = table.remove(s_Stack)
				local s_Neighbours = s_Zone.Neighbours[s_Current]
				for l_Index = 1, #s_Neighbours do
					local s_Next = s_Neighbours[l_Index].To
					if s_Zone.Part[s_Next] == nil then
						s_Zone.Part[s_Next] = s_PartCount
						s_Stack[#s_Stack + 1] = s_Next
					end
				end
			end
		end
	end

	return s_Zone
end

---@param p_Data table one zone as in the table
function NavZones:_AddZone(p_Data)
	local s_Center = p_Data.center or {}
	local s_Name = tostring(p_Data.name)
	local s_Kind = tostring(p_Data.kind)
	local s_CenterVec = Vec3(tonumber(s_Center[1]) or 0, tonumber(s_Center[2]) or 0, tonumber(s_Center[3]) or 0)
	local s_Zone = _ParseNetwork(p_Data, s_Name, s_Kind, s_CenterVec)
	-- Land vehicles have a network of their own: wide and open ground, junctions with the vehicle-paths.
	if type(p_Data.vehicle) == 'table' then
		local s_Vehicle = _ParseNetwork(p_Data.vehicle, s_Name, s_Kind, s_CenterVec)
		if #s_Vehicle.Points > 0 then
			s_Zone.Vehicle = s_Vehicle
		end
	end

	if #s_Zone.Points > 0 then
		self._Zones[s_Zone.Name] = s_Zone
		self._Count = self._Count + 1
	end
end

---Finds the waypoints of the junctions. Junctions whose waypoint moved or is gone are dropped.
---@return integer junctions
function NavZones:_LinkJunctions()
	local s_Paths = m_NodeCollection:GetPaths()
	local s_Count = 0

	local function _Link(p_Zone, p_Lookup)
		local s_Valid = {}
		for l_Index = 1, #p_Zone.Junctions do
			local l_Junction = p_Zone.Junctions[l_Index]
			local s_Waypoints = s_Paths[l_Junction.PathIndex]
			local s_Waypoint = s_Waypoints and s_Waypoints[l_Junction.PointIndex]
			if s_Waypoint ~= nil and p_Zone.Points[l_Junction.Point] ~= nil
				and s_Waypoint.Position:Distance(l_Junction.Position) <= JUNCTION_TOLERANCE then
				l_Junction.Waypoint = s_Waypoint
				s_Valid[#s_Valid + 1] = l_Junction
				p_Lookup[s_Waypoint.ID] = { Zone = p_Zone, Junction = l_Junction }
				s_Count = s_Count + 1
			end
		end
		p_Zone.Junctions = s_Valid
	end

	for _, l_Zone in pairs(self._Zones) do
		_Link(l_Zone, self._Junctions)
		if l_Zone.Vehicle ~= nil then
			_Link(l_Zone.Vehicle, self._VehicleJunctions)
		end
	end
	return s_Count
end

-- =============================================
-- Queries
-- =============================================

---@param p_Name string the objective
---@return NavZone|nil
function NavZones:GetZone(p_Name)
	return self._Zones[p_Name]
end

---@return integer
function NavZones:GetCount()
	return self._Count
end

---The zone whose junction the waypoint is.
---@param p_Waypoint Waypoint
---@return { Zone: NavZone, Junction: NavZoneJunction }|nil
function NavZones:GetJunction(p_Waypoint)
	if self._Count == 0 or p_Waypoint == nil or p_Waypoint.ID == nil then
		return nil
	end
	return self._Junctions[p_Waypoint.ID]
end

---The vehicle-network whose junction the waypoint (of a vehicle-path) is.
---@param p_Waypoint Waypoint
---@return { Zone: NavZone, Junction: NavZoneJunction }|nil
function NavZones:GetVehicleJunction(p_Waypoint)
	if self._Count == 0 or p_Waypoint == nil or p_Waypoint.ID == nil then
		return nil
	end
	return self._VehicleJunctions[p_Waypoint.ID]
end

---The point of the network closest to the position. Points on the same floor (FLOOR_HEIGHT) come first: a soldier
---can't reach the point above it.
---@param p_Zone NavZone
---@param p_Position Vec3
---@param p_Avoid? integer a point not to take (a dead end the bot got stuck at)
---@return integer|nil point, number distance
function NavZones:Closest(p_Zone, p_Position, p_Avoid)
	local s_Best = nil
	local s_BestOtherFloor = true
	local s_BestDistance = math.huge
	for l_Index = 1, #p_Zone.Points do
		if l_Index == p_Avoid then
			goto continue
		end
		local s_Pos = p_Zone.Points[l_Index].Position
		local s_DeltaX = s_Pos.x - p_Position.x
		local s_DeltaY = s_Pos.y - p_Position.y
		local s_DeltaZ = s_Pos.z - p_Position.z
		local s_Distance = s_DeltaX * s_DeltaX + 4 * s_DeltaY * s_DeltaY + s_DeltaZ * s_DeltaZ
		local s_OtherFloor = math.abs(s_DeltaY) > FLOOR_HEIGHT
		if (s_BestOtherFloor and not s_OtherFloor) or (s_OtherFloor == s_BestOtherFloor and s_Distance < s_BestDistance) then
			s_BestDistance = s_Distance
			s_BestOtherFloor = s_OtherFloor
			s_Best = l_Index
		end
		::continue::
	end
	return s_Best, math.sqrt(s_BestDistance)
end

---The zone whose network is at the position: a point within p_Range on the same floor. Used for bots that spawn at the
---spawn-points of the game.
---@param p_Position Vec3
---@param p_Range number
---@return NavZone|nil, integer|nil point
function NavZones:ZoneAt(p_Position, p_Range)
	local s_BestZone = nil
	local s_BestPoint = nil
	local s_BestDistance = p_Range
	for _, l_Zone in pairs(self._Zones) do
		local s_Point, s_Distance = self:Closest(l_Zone, p_Position)
		if s_Point ~= nil and s_Distance <= s_BestDistance
			and math.abs(l_Zone.Points[s_Point].Position.y - p_Position.y) <= FLOOR_HEIGHT then
			s_BestZone = l_Zone
			s_BestPoint = s_Point
			s_BestDistance = s_Distance
		end
	end
	return s_BestZone, s_BestPoint
end

---Whether every connection of the point was given up already (a dead end for the bot standing there).
---@param p_Zone NavZone
---@param p_Point integer
---@return boolean
function NavZones:IsBlockedIn(p_Zone, p_Point)
	local s_Neighbours = p_Zone.Neighbours[p_Point] or {}
	for l_Index = 1, #s_Neighbours do
		if s_Neighbours[l_Index].Penalty <= 0.0 then
			return false
		end
	end
	return true
end

---A bot got stuck between the two points: all bots avoid the connection from now on (until the level ends).
---@param p_Zone NavZone
---@param p_A integer
---@param p_B integer
function NavZones:BlockEdge(p_Zone, p_A, p_B)
	for _, l_Pair in ipairs({ { p_A, p_B }, { p_B, p_A } }) do
		local s_Neighbours = p_Zone.Neighbours[l_Pair[1]] or {}
		for l_Index = 1, #s_Neighbours do
			if s_Neighbours[l_Index].To == l_Pair[2] then
				s_Neighbours[l_Index].Penalty = s_Neighbours[l_Index].Penalty + BLOCKED_PENALTY
			end
		end
	end
end

---Shortest way through the network (A*).
---@param p_Zone NavZone
---@param p_From integer
---@param p_To integer
---@return integer[]|nil points from p_From to p_To
function NavZones:Route(p_Zone, p_From, p_To)
	if p_From == p_To then
		return { p_From }
	end

	local s_Points = p_Zone.Points
	local s_Goal = s_Points[p_To].Position
	local s_Costs = { [p_From] = 0.0 }
	local s_Came = {}
	local s_Closed = {}
	-- Binary heap of { estimate, point }.
	local s_Heap = { { s_Points[p_From].Position:Distance(s_Goal), p_From } }

	local function _Push(p_Entry)
		s_Heap[#s_Heap + 1] = p_Entry
		local s_Index = #s_Heap
		while s_Index > 1 do
			local s_Parent = s_Index // 2
			if s_Heap[s_Parent][1] <= s_Heap[s_Index][1] then
				break
			end
			s_Heap[s_Parent], s_Heap[s_Index] = s_Heap[s_Index], s_Heap[s_Parent]
			s_Index = s_Parent
		end
	end

	local function _Pop()
		local s_Top = s_Heap[1]
		local s_Last = table.remove(s_Heap)
		if #s_Heap > 0 then
			s_Heap[1] = s_Last
			local s_Index = 1
			while true do
				local s_Smallest = s_Index
				local s_Left = 2 * s_Index
				local s_Right = s_Left + 1
				if s_Left <= #s_Heap and s_Heap[s_Left][1] < s_Heap[s_Smallest][1] then
					s_Smallest = s_Left
				end
				if s_Right <= #s_Heap and s_Heap[s_Right][1] < s_Heap[s_Smallest][1] then
					s_Smallest = s_Right
				end
				if s_Smallest == s_Index then
					break
				end
				s_Heap[s_Smallest], s_Heap[s_Index] = s_Heap[s_Index], s_Heap[s_Smallest]
				s_Index = s_Smallest
			end
		end
		return s_Top
	end

	while #s_Heap > 0 do
		local s_Current = _Pop()[2]
		if s_Current == p_To then
			local s_Route = { p_To }
			while s_Came[s_Route[1]] ~= nil do
				table.insert(s_Route, 1, s_Came[s_Route[1]])
			end
			return s_Route
		end

		if not s_Closed[s_Current] then
			s_Closed[s_Current] = true
			local s_Neighbours = p_Zone.Neighbours[s_Current]
			for l_Index = 1, #s_Neighbours do
				local l_Edge = s_Neighbours[l_Index]
				local s_Cost = s_Costs[s_Current] + l_Edge.Cost + l_Edge.Penalty
				if not s_Closed[l_Edge.To] and s_Cost < (s_Costs[l_Edge.To] or math.huge) then
					s_Costs[l_Edge.To] = s_Cost
					s_Came[l_Edge.To] = s_Current
					_Push({ s_Cost + s_Points[l_Edge.To].Position:Distance(s_Goal), l_Edge.To })
				end
			end
		end
	end

	return nil
end

---The positions to walk along a route: the corners of each connection and the points, without the first point.
---@param p_Zone NavZone
---@param p_Route integer[]
---@return { Position: Vec3, Flags: integer }[]
function NavZones:Positions(p_Zone, p_Route)
	local s_Result = {}
	for l_Index = 2, #p_Route do
		local s_From = p_Route[l_Index - 1]
		local s_To = p_Route[l_Index]
		local s_Neighbours = p_Zone.Neighbours[s_From]
		for l_Edge = 1, #s_Neighbours do
			if s_Neighbours[l_Edge].To == s_To then
				local s_Corners = s_Neighbours[l_Edge].Corners
				for l_Corner = 1, #s_Corners do
					s_Result[#s_Result + 1] = { Position = s_Corners[l_Corner], Flags = 0 }
				end
				break
			end
		end
		local s_Point = p_Zone.Points[s_To]
		s_Result[#s_Result + 1] = { Position = s_Point.Position, Flags = s_Point.Flags, Point = s_To }
	end
	return s_Result
end

---A random point in the zone that can be reached from p_From, other than p_From. With p_Cover the ones with more cover
---are taken more often.
---@param p_Zone NavZone
---@param p_From integer|nil
---@param p_Cover boolean
---@return integer|nil
function NavZones:RandomPoint(p_Zone, p_From, p_Cover)
	local s_Part = p_From and p_Zone.Part[p_From]
	local s_Candidates = {}
	for l_Index = 1, #p_Zone.Inside do
		local l_Point = p_Zone.Inside[l_Index]
		if s_Part == nil or p_Zone.Part[l_Point] == s_Part then
			s_Candidates[#s_Candidates + 1] = l_Point
		end
	end
	if #s_Candidates == 0 then
		for l_Index = 1, #p_Zone.Points do
			if s_Part == nil or p_Zone.Part[l_Index] == s_Part then
				s_Candidates[#s_Candidates + 1] = l_Index
			end
		end
	end
	if #s_Candidates == 0 then
		return nil
	end
	local s_Not = p_From

	local s_Best = nil
	local s_BestScore = -1
	-- Best of a few random tries: cover wins when defending.
	for _ = 1, p_Cover and 6 or 1 do
		local s_Index = s_Candidates[MathUtils:GetRandomInt(1, #s_Candidates)]
		if s_Index ~= s_Not then
			local s_Score = p_Cover and p_Zone.Points[s_Index].Cover or 0
			if s_Score > s_BestScore then
				s_BestScore = s_Score
				s_Best = s_Index
			end
		end
	end
	return s_Best
end

if g_NavZones == nil then
	---@type NavZones
	g_NavZones = NavZones()
end

return g_NavZones
