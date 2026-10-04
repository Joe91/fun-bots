---@class NavZones
---@overload fun():NavZones
NavZones = class('NavZones')

-- The walking mesh of the level and the zones on it (capture points, MCOMs, bases, the spawns of the game). Bots walk
-- the mesh freely from point to point (Bot/BotZoneMovement.lua) instead of following waypoints; between areas of the
-- mesh they take the navigation paths (NavRoutes.lua). The mesh is made by the debug-server from a census of the level
-- (tools/debug-server/funbots_debug/census/navzones.py) and saved in the table <map>_navzones of mod.db, in one row
-- (name "@mesh", data: JSON):
--   points  { { x, y, z, clearance, cover, flags } }  flags: 1 = in a zone, 2 = indoors, 4 = crouch
--   edges   { { a, b, length, { corner, ... } } }     a, b count from 0, corners { x, y, z } between a and b
--   attach  { { path, point, mesh-point, distance, { x, y, z }, { corner, ... } } }  junctions with the waypoints
--   vehicle { points, edges, attach }                 the mesh of the land vehicles (wide and open ground)
--   zones   { { name, kind, center, radius, inside = { points }, vehicleInside = { vehicle-points } } }
-- Zones overlap (rush: the bases of one stage lie at the MCOMs of another), the mesh doesn't: a zone is a view on the
-- mesh (the same points, connections and junctions) with its own name and points.

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Logger
local m_Logger = Logger('NavZones', Debug.Server.PATH)

NavZoneFlags = {
	InZone = 1,
	Indoor = 2,
	Crouch = 4,
}

-- The row of the table with the mesh.
local MESH_ROW = '@mesh'
-- A junction is only used if its waypoint is still where the mesh was made for (the paths may have been edited).
local JUNCTION_TOLERANCE = 1.0
-- Points this far above or below a position are on another floor.
local FLOOR_HEIGHT = 1.5
-- Extra cost of a connection a bot got stuck on, per time (all bots avoid it then, until the level ends).
local BLOCKED_PENALTY = 50.0
-- Given up this many times, a connection is removed (until the level ends).
local REMOVE_AFTER = 3
-- Metres above or below an MCOM the bots walk around it (RandomPoint).
local MCOM_FLOOR = 3.0
-- Parts of the mesh with fewer points get no junctions (_LinkJunctions).
local MIN_PART = 10

---@class NavZonePoint
---@field Index integer
---@field Position Vec3
---@field Clearance number
---@field Cover integer
---@field Flags integer

---@class NavZoneJunction
---@field PathIndex integer
---@field PointIndex integer
---@field Position Vec3 where the waypoint was when the mesh was made
---@field Point integer the point of the mesh
---@field Corners Vec3[] the way from the point to the waypoint (around walls)
---@field Waypoint Waypoint|nil set by _LinkJunctions

---A zone, or the mesh itself (Name "@mesh"): zones share the tables of the mesh, only Name, Kind, Center, Radius and
---Inside are their own.
---@class NavZone
---@field Name string the objective
---@field Kind string capturepoint | mcom | base | mesh
---@field Center Vec3
---@field Radius number
---@field Points NavZonePoint[]
---@field Neighbours table<integer, { To: integer, Cost: number, Corners: Vec3[], Penalty: number, Removed: boolean|nil }[]>
---@field Inside integer[] the points in the zone (the mesh itself: none)
---@field InsideSet table<integer, boolean>
---@field Junctions NavZoneJunction[]
---@field Vehicle NavZone|nil the zone on the mesh of the land vehicles
---@field Part table<integer, integer> point -> number of its connected part (points of different parts have no way)
---@field ByWaypoint table<string, NavZoneJunction> waypoint-ID -> junction, set by _LinkJunctions
---@field Mesh NavZone the mesh the zone is on

function NavZones:__init()
	self:Clear()
end

function NavZones:Clear()
	---@type table<string, NavZone>
	self._Zones = {}
	---@type NavZone|nil
	self._Mesh = nil
	---@type NavZone|nil
	self._VehicleMesh = nil
	---point -> the zones it is in
	---@type table<integer, NavZone[]>
	self._PointZones = {}
	self._Count = 0
	-- Counts up whenever the mesh or its junctions change (NavRoutes builds its graph anew then).
	self._Version = (self._Version or 0) + 1
	-- Counts up whenever connections are removed as well (NavRoutes measures the ways anew then).
	self._Topology = (self._Topology or 0) + 1
end

-- =============================================
-- Loading and saving
-- =============================================

---After the waypoints of the level are loaded.
function NavZones:OnLoadFinished()
	self:Clear()

	local s_Table = m_NodeCollection:GetMapName() .. '_navzones'
	if not SQL:Open() then
		m_Logger:Error('Failed to open SQL. ' .. SQL:Error())
		return
	end

	local s_Exists = SQL:Query("select name from sqlite_master where type='table' and name='" .. s_Table .. "'")
	if s_Exists and #s_Exists > 0 then
		local s_Rows = SQL:Query('SELECT name, data FROM ' .. s_Table) or {}
		for l_Index = 1, #s_Rows do
			if s_Rows[l_Index].name == MESH_ROW then
				local s_Ok, s_Data = pcall(json.decode, s_Rows[l_Index].data)
				if s_Ok and type(s_Data) == 'table' then
					self:_Build(s_Data)
				else
					m_Logger:Error('invalid mesh in ' .. s_Table)
				end
			end
		end
	end
	SQL:Close()

	local s_Junctions = self:_LinkJunctions()
	print('[NavZones] ' .. self._Count .. ' zones, ' .. (self._Mesh and #self._Mesh.Points or 0) .. ' points, '
		.. s_Junctions .. ' junctions for ' .. m_NodeCollection:GetMapName())
end

---Takes over the mesh of the debug-server (DebugCommands "navzones_apply").
---@param p_Data table the mesh as in the table
---@param p_Save boolean also save it in mod.db
---@return integer zones, integer junctions
function NavZones:Apply(p_Data, p_Save)
	self:Clear()
	self:_Build(p_Data)
	local s_Junctions = self:_LinkJunctions()

	if p_Save then
		self:_Save(p_Data)
	end
	return self._Count, s_Junctions
end

---@param p_Data table
function NavZones:_Save(p_Data)
	local s_Table = m_NodeCollection:GetMapName() .. '_navzones'
	if not SQL:Open() then
		m_Logger:Error('Failed to open SQL. ' .. SQL:Error())
		return
	end

	SQL:Query('DROP TABLE IF EXISTS ' .. s_Table)
	SQL:Query('CREATE TABLE ' .. s_Table .. ' (name TEXT, data TEXT)')
	local s_Data = json.encode(p_Data):gsub("'", "''")
	SQL:Query('INSERT INTO ' .. s_Table .. " (name, data) VALUES ('" .. MESH_ROW .. "', '" .. s_Data .. "')")
	SQL:Close()
end

---Connected parts: a bot only goes where a way leads. Connections given up for good (Removed) don't connect. In place:
---the zones share the table.
---@param p_Mesh NavZone
local function _ComputeParts(p_Mesh)
	local s_Part = p_Mesh.Part
	for l_Point in pairs(s_Part) do
		s_Part[l_Point] = nil
	end
	local s_PartCount = 0
	for l_Start = 1, #p_Mesh.Points do
		if s_Part[l_Start] == nil then
			s_PartCount = s_PartCount + 1
			s_Part[l_Start] = s_PartCount
			local s_Stack = { l_Start }
			while #s_Stack > 0 do
				local s_Current = table.remove(s_Stack)
				local s_Neighbours = p_Mesh.Neighbours[s_Current]
				for l_Index = 1, #s_Neighbours do
					local s_Next = s_Neighbours[l_Index].To
					if s_Part[s_Next] == nil and not s_Neighbours[l_Index].Removed then
						s_Part[s_Next] = s_PartCount
						s_Stack[#s_Stack + 1] = s_Next
					end
				end
			end
		end
	end
end

---@param p_Raw table|nil { x, y, z }
---@return Vec3
local function _Vec(p_Raw)
	p_Raw = p_Raw or {}
	return Vec3(tonumber(p_Raw[1]) or 0, tonumber(p_Raw[2]) or 0, tonumber(p_Raw[3]) or 0)
end

---One mesh (points, edges, attach).
---@param p_Data table
---@return NavZone
local function _ParseMesh(p_Data)
	---@type NavZone
	local s_Mesh = {
		Name = MESH_ROW,
		Kind = 'mesh',
		Center = Vec3(0, 0, 0),
		Radius = math.huge,
		Points = {},
		Neighbours = {},
		Inside = {},
		InsideSet = {},
		Junctions = {},
		Part = {},
		ByWaypoint = {},
	}
	s_Mesh.Mesh = s_Mesh

	local s_Points = p_Data.points or {}
	for l_Index = 1, #s_Points do
		local l_Point = s_Points[l_Index]
		s_Mesh.Points[l_Index] = {
			Index = l_Index,
			Position = Vec3(l_Point[1], l_Point[2], l_Point[3]),
			Clearance = tonumber(l_Point[4]) or 0,
			Cover = math.floor(tonumber(l_Point[5]) or 0),
			Flags = math.floor(tonumber(l_Point[6]) or 0),
		}
		s_Mesh.Neighbours[l_Index] = {}
	end

	local s_Edges = p_Data.edges or {}
	for l_Index = 1, #s_Edges do
		local l_Edge = s_Edges[l_Index]
		local s_A = math.floor(l_Edge[1]) + 1
		local s_B = math.floor(l_Edge[2]) + 1
		if s_Mesh.Points[s_A] ~= nil and s_Mesh.Points[s_B] ~= nil then
			local s_Corners = {}
			local s_Reversed = {}
			local s_Raw = l_Edge[4] or {}
			for l_Corner = 1, #s_Raw do
				s_Corners[l_Corner] = _Vec(s_Raw[l_Corner])
			end
			for l_Corner = #s_Corners, 1, -1 do
				s_Reversed[#s_Reversed + 1] = s_Corners[l_Corner]
			end
			local s_Cost = tonumber(l_Edge[3]) or s_Mesh.Points[s_A].Position:Distance(s_Mesh.Points[s_B].Position)
			table.insert(s_Mesh.Neighbours[s_A], { To = s_B, Cost = s_Cost, Corners = s_Corners, Penalty = 0.0 })
			table.insert(s_Mesh.Neighbours[s_B], { To = s_A, Cost = s_Cost, Corners = s_Reversed, Penalty = 0.0 })
		end
	end

	local s_Attach = p_Data.attach or {}
	for l_Index = 1, #s_Attach do
		local l_Entry = s_Attach[l_Index]
		local s_Corners = {}
		local s_RawCorners = type(l_Entry[6]) == 'table' and l_Entry[6] or {}
		for l_Corner = 1, #s_RawCorners do
			s_Corners[l_Corner] = _Vec(s_RawCorners[l_Corner])
		end
		s_Mesh.Junctions[#s_Mesh.Junctions + 1] = {
			PathIndex = math.floor(l_Entry[1]),
			PointIndex = math.floor(l_Entry[2]),
			Point = math.floor(l_Entry[3]) + 1,
			Position = _Vec(l_Entry[5]),
			Corners = s_Corners,
		}
	end

	_ComputeParts(s_Mesh)
	return s_Mesh
end

---A zone: a view on the mesh with its own name and points.
---@param p_Mesh NavZone
---@param p_Data table one zone as in the mesh
---@param p_Inside table|nil its points, counted from 0
---@return NavZone
local function _ZoneOn(p_Mesh, p_Data, p_Inside)
	---@type NavZone
	local s_Zone = {
		Name = tostring(p_Data.name),
		Kind = tostring(p_Data.kind),
		Center = _Vec(p_Data.center),
		Radius = tonumber(p_Data.radius) or 30.0,
		Points = p_Mesh.Points,
		Neighbours = p_Mesh.Neighbours,
		Inside = {},
		InsideSet = {},
		Junctions = p_Mesh.Junctions,
		Part = p_Mesh.Part,
		ByWaypoint = p_Mesh.ByWaypoint,
		Mesh = p_Mesh,
	}
	for l_Index = 1, #(p_Inside or {}) do
		local s_Point = math.floor(p_Inside[l_Index]) + 1
		if p_Mesh.Points[s_Point] ~= nil then
			s_Zone.Inside[#s_Zone.Inside + 1] = s_Point
			s_Zone.InsideSet[s_Point] = true
		end
	end
	return s_Zone
end

---@param p_Data table the mesh as in the table (version 2)
function NavZones:_Build(p_Data)
	self._Mesh = _ParseMesh(p_Data)
	if type(p_Data.vehicle) == 'table' then
		local s_Vehicle = _ParseMesh(p_Data.vehicle)
		if #s_Vehicle.Points > 0 then
			self._VehicleMesh = s_Vehicle
		end
	end

	local s_Zones = p_Data.zones or {}
	for l_Index = 1, #s_Zones do
		local l_Data = s_Zones[l_Index]
		local s_Zone = _ZoneOn(self._Mesh, l_Data, l_Data.inside)
		if self._VehicleMesh ~= nil then
			s_Zone.Vehicle = _ZoneOn(self._VehicleMesh, l_Data, l_Data.vehicleInside)
		end
		if self._Zones[s_Zone.Name] == nil then
			self._Zones[s_Zone.Name] = s_Zone
			self._Count = self._Count + 1
			for l_Point = 1, #s_Zone.Inside do
				local s_List = self._PointZones[s_Zone.Inside[l_Point]] or {}
				s_List[#s_List + 1] = s_Zone
				self._PointZones[s_Zone.Inside[l_Point]] = s_List
			end
		else
			m_Logger:Warning('two zones named ' .. s_Zone.Name)
		end
	end
end

---Finds the waypoints of the junctions. Junctions whose waypoint moved or is gone are dropped.
---@return integer junctions
function NavZones:_LinkJunctions()
	local s_Paths = m_NodeCollection:GetPaths()
	local s_Count = 0

	local function _Link(p_Mesh)
		-- Not onto an island of the mesh (a few points the census measured apart): no route leads on from there, the
		-- bots went back and forth between it and their path.
		local s_PartSize = {}
		for l_Point = 1, #p_Mesh.Points do
			local s_Part = p_Mesh.Part[l_Point]
			s_PartSize[s_Part] = (s_PartSize[s_Part] or 0) + 1
		end
		local s_Valid = {}
		for l_Index = 1, #p_Mesh.Junctions do
			local l_Junction = p_Mesh.Junctions[l_Index]
			local s_Waypoints = s_Paths[l_Junction.PathIndex]
			local s_Waypoint = s_Waypoints and s_Waypoints[l_Junction.PointIndex]
			if s_Waypoint ~= nil and p_Mesh.Points[l_Junction.Point] ~= nil
				and (s_PartSize[p_Mesh.Part[l_Junction.Point]] or 0) >= MIN_PART
				and s_Waypoint.Position:Distance(l_Junction.Position) <= JUNCTION_TOLERANCE then
				l_Junction.Waypoint = s_Waypoint
				s_Valid[#s_Valid + 1] = l_Junction
				p_Mesh.ByWaypoint[s_Waypoint.ID] = l_Junction
				s_Count = s_Count + 1
			end
		end
		-- In place: the zones share the list.
		for l_Index = #p_Mesh.Junctions, 1, -1 do
			p_Mesh.Junctions[l_Index] = nil
		end
		for l_Index = 1, #s_Valid do
			p_Mesh.Junctions[l_Index] = s_Valid[l_Index]
		end
	end

	if self._Mesh ~= nil then
		_Link(self._Mesh)
	end
	if self._VehicleMesh ~= nil then
		_Link(self._VehicleMesh)
	end
	self._Version = self._Version + 1
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

---@return integer changes whenever the networks or their junctions change
function NavZones:GetVersion()
	return self._Version
end

---@return integer counts up when the mesh changes or a connection is removed (BlockEdge)
function NavZones:GetTopology()
	return self._Topology
end

---@return integer
function NavZones:GetCount()
	return self._Count
end

---Whether there are networks of bases (also the ones around the spawns of the game): bots spawned by the game start on
---them (BotSpawner).
---@return boolean
function NavZones:HasBases()
	for _, l_Zone in pairs(self._Zones) do
		if l_Zone.Kind == 'base' then
			return true
		end
	end
	return false
end

---The mesh (a zone without name and points of its own). nil without mesh.
---@return NavZone|nil
function NavZones:GetMesh()
	return self._Mesh
end

---The zones the point of the mesh is in (zones overlap).
---@param p_Point integer|nil
---@return NavZone[]
function NavZones:ZonesOf(p_Point)
	return p_Point and self._PointZones[p_Point] or {}
end

---The zone to walk around in at the point: the one of the objective if the point is in it, else the first zone of the
---point, else the mesh.
---@param p_Point integer
---@param p_Objective string|nil
---@return NavZone|nil
function NavZones:ZoneAtPoint(p_Point, p_Objective)
	local s_Zones = self:ZonesOf(p_Point)
	for l_Index = 1, #s_Zones do
		if s_Zones[l_Index].Name == p_Objective then
			return s_Zones[l_Index]
		end
	end
	return s_Zones[1] or self._Mesh
end

---The junction of the mesh at the waypoint, with the zone it leads into.
---@param p_Waypoint Waypoint
---@return { Zone: NavZone, Junction: NavZoneJunction }|nil
function NavZones:GetJunction(p_Waypoint)
	if self._Mesh == nil or p_Waypoint == nil or p_Waypoint.ID == nil then
		return nil
	end
	local s_Junction = self._Mesh.ByWaypoint[p_Waypoint.ID]
	if s_Junction == nil then
		return nil
	end
	return { Zone = self:ZoneAtPoint(s_Junction.Point, nil), Junction = s_Junction }
end

---The junction of the mesh (of this zone) at the waypoint.
---@param p_Zone NavZone
---@param p_Waypoint Waypoint
---@return NavZoneJunction|nil
function NavZones:GetJunctionIn(p_Zone, p_Waypoint)
	if p_Zone.ByWaypoint == nil or p_Waypoint == nil or p_Waypoint.ID == nil then
		return nil
	end
	return p_Zone.ByWaypoint[p_Waypoint.ID]
end

---@return table<string, NavZone>
function NavZones:GetZones()
	return self._Zones
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

---The mesh at the position: a point within p_Range on the same floor, and the zone there (ZoneAtPoint). Used for bots
---that spawn at the spawn-points of the game.
---@param p_Position Vec3
---@param p_Range number
---@param p_Objective string|nil
---@return NavZone|nil, integer|nil point
function NavZones:ZoneAt(p_Position, p_Range, p_Objective)
	if self._Mesh == nil then
		return nil, nil
	end
	local s_Point, s_Distance = self:Closest(self._Mesh, p_Position)
	if s_Point == nil or s_Distance > p_Range
		or math.abs(self._Mesh.Points[s_Point].Position.y - p_Position.y) > FLOOR_HEIGHT then
		return nil, nil
	end
	return self:ZoneAtPoint(s_Point, p_Objective), s_Point
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

---Whether the two points stay connected without the connection between them (it isn't the only way between two parts
---of the mesh).
---@param p_Mesh NavZone
---@param p_A integer
---@param p_B integer
---@return boolean
local function _ConnectedWithout(p_Mesh, p_A, p_B)
	local s_Seen = { [p_A] = true }
	local s_Stack = { p_A }
	while #s_Stack > 0 do
		local s_Current = table.remove(s_Stack)
		local s_Neighbours = p_Mesh.Neighbours[s_Current]
		for l_Index = 1, #s_Neighbours do
			local l_Edge = s_Neighbours[l_Index]
			local s_Next = l_Edge.To
			if not l_Edge.Removed and not s_Seen[s_Next] and not (s_Current == p_A and s_Next == p_B) then
				if s_Next == p_B then
					return true
				end
				s_Seen[s_Next] = true
				s_Stack[#s_Stack + 1] = s_Next
			end
		end
	end
	return false
end

---A bot got stuck between the two points: all bots avoid the connection from now on (until the level ends).
---@param p_Zone NavZone
---@param p_A integer
---@param p_B integer
---How many points can be reached from p_Start without the connection p_A - p_B, counted up to p_Limit.
---@param p_Mesh NavZone
---@param p_Start integer
---@param p_A integer
---@param p_B integer
---@param p_Limit integer
---@return integer
local function _SizeWithout(p_Mesh, p_Start, p_A, p_B, p_Limit)
	local s_Seen = { [p_Start] = true }
	local s_Count = 1
	local s_Stack = { p_Start }
	while #s_Stack > 0 and s_Count < p_Limit do
		local s_Current = table.remove(s_Stack)
		local s_Neighbours = p_Mesh.Neighbours[s_Current]
		for l_Index = 1, #s_Neighbours do
			local l_Edge = s_Neighbours[l_Index]
			local s_Next = l_Edge.To
			if not l_Edge.Removed and not s_Seen[s_Next] and not (s_Current == p_A and s_Next == p_B)
				and not (s_Current == p_B and s_Next == p_A) then
				s_Seen[s_Next] = true
				s_Count = s_Count + 1
				s_Stack[#s_Stack + 1] = s_Next
			end
		end
	end
	return s_Count
end

function NavZones:BlockEdge(p_Zone, p_A, p_B)
	local s_Remove = nil
	for _, l_Pair in ipairs({ { p_A, p_B }, { p_B, p_A } }) do
		local s_Neighbours = p_Zone.Neighbours[l_Pair[1]] or {}
		for l_Index = 1, #s_Neighbours do
			local l_Edge = s_Neighbours[l_Index]
			if l_Edge.To == l_Pair[2] then
				l_Edge.Penalty = l_Edge.Penalty + BLOCKED_PENALTY
				-- Given up too often: no way at all, also not for goals and exits behind it (the parts change). Not
				-- the only way between two parts of the mesh: bots crowding on stairs get stuck as well, and without
				-- it no route would lead on (it stays expensive). Unless it only cuts off a few points (MIN_PART, no
				-- junctions there either): a junction on a ramp the mesh reaches over its side, the bots fell off
				-- and tried again for minutes.
				if not l_Edge.Removed and l_Edge.Penalty >= BLOCKED_PENALTY * REMOVE_AFTER then
					if s_Remove == nil then
						local s_Mesh = p_Zone.Mesh
						s_Remove = _ConnectedWithout(s_Mesh, p_A, p_B)
							or _SizeWithout(s_Mesh, p_A, p_A, p_B, MIN_PART) < MIN_PART
							or _SizeWithout(s_Mesh, p_B, p_A, p_B, MIN_PART) < MIN_PART
					end
					l_Edge.Removed = s_Remove
				end
			end
		end
	end
	local s_Removed = s_Remove == true
	if s_Removed then
		self._Topology = self._Topology + 1
		_ComputeParts(p_Zone.Mesh)
		m_Logger:Write('zone ' .. p_Zone.Name .. ': connection ' .. p_A .. '-' .. p_B .. ' removed')
	end
end

-- Metres of the regions a bot avoids more or less (NavZones:Route with a seed).
local SPREAD_REGION = 30.0

---How much longer the ways in the region of the position seem to the bot (Registry.BOT.NAV_ROUTE_SPREAD): the bots
---take different streets and corridors, not all the shortest one. The same for a life of the bot (p_Seed).
---@param p_Seed number
---@param p_Position Vec3
---@return number factor 1 .. 1 + NAV_ROUTE_SPREAD
local function _RegionSpread(p_Seed, p_Position)
	local s_Hash = math.sin(p_Seed * 12.9898 + math.floor(p_Position.x / SPREAD_REGION) * 78.233
		+ math.floor(p_Position.z / SPREAD_REGION) * 37.719) * 43758.5453
	return 1.0 + Registry.BOT.NAV_ROUTE_SPREAD * (s_Hash - math.floor(s_Hash))
end

---Shortest way through the network (A*).
---@param p_Zone NavZone
---@param p_From integer
---@param p_To integer
---@param p_Seed? number the bot's: its own way among similar ones (_RegionSpread), nil: the shortest
---@return integer[]|nil points from p_From to p_To
---@return number cost of the way (with the spread)
function NavZones:Route(p_Zone, p_From, p_To, p_Seed)
	if p_From == p_To then
		return { p_From }, 0.0
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
			return s_Route, s_Costs[p_To]
		end

		if not s_Closed[s_Current] then
			s_Closed[s_Current] = true
			local s_Neighbours = p_Zone.Neighbours[s_Current]
			for l_Index = 1, #s_Neighbours do
				local l_Edge = s_Neighbours[l_Index]
				local s_Step = l_Edge.Cost
				if p_Seed ~= nil then
					s_Step = s_Step * _RegionSpread(p_Seed, s_Points[l_Edge.To].Position)
				end
				local s_Cost = s_Costs[s_Current] + s_Step + l_Edge.Penalty
				if not l_Edge.Removed and not s_Closed[l_Edge.To] and s_Cost < (s_Costs[l_Edge.To] or math.huge) then
					s_Costs[l_Edge.To] = s_Cost
					s_Came[l_Edge.To] = s_Current
					_Push({ s_Cost + s_Points[l_Edge.To].Position:Distance(s_Goal), l_Edge.To })
				end
			end
		end
	end

	return nil, math.huge
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
	-- An MCOM: on its floor (the zone reaches to floors far below or above, a long way round).
	local s_Floor = p_Zone.Kind == 'mcom' and p_Zone.Center.y or nil
	for _, l_SameFloor in ipairs(s_Floor and { true, false } or { false }) do
		for l_Index = 1, #p_Zone.Inside do
			local l_Point = p_Zone.Inside[l_Index]
			if (s_Part == nil or p_Zone.Part[l_Point] == s_Part)
				and (not l_SameFloor or math.abs(p_Zone.Points[l_Point].Position.y - s_Floor) <= MCOM_FLOOR) then
				s_Candidates[#s_Candidates + 1] = l_Point
			end
		end
		if #s_Candidates > 0 then
			break
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
