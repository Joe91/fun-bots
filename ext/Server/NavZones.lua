---@class NavZones
---@overload fun():NavZones
NavZones = class('NavZones')

-- The walking mesh of the level and the zones on it (capture points, MCOMs, bases, the spawns of the game). Bots walk
-- the mesh freely from point to point (Bot/BotZoneMovement.lua) instead of following waypoints; between areas of the
-- mesh they take the navigation paths (NavRoutes.lua). The mesh is made by the debug-server from a census of the level
-- (tools/debug-server/funbots_debug/census/navzones.py) and saved in the table <map>_navzones of mod.db, in one row
-- (name "@mesh", data: JSON):
--   points  { { x, y, z, clearance, cover, flags } }  flags: 1 = in a zone, 2 = indoors, 4 = crouch
--   edges   { { a, b, length, { corner, ... }, along, { jump, ... } } }  a, b count from 0, corners { x, y, z } between
--           a and b; along waypoints (1): jumps are the corners (from 0) where the soldier who recorded them jumped
--   attach  { { path, point, mesh-point, distance, { x, y, z }, { corner, ... } } }  junctions with the waypoints
--   vehicle { points, edges, attach }                 the mesh of the land vehicles (wide and open ground)
--   zones   { { name, kind, center, radius, inside = { points }, vehicleInside = { vehicle-points } } }
-- Zones overlap (rush: the bases of one stage lie at the MCOMs of another), the mesh doesn't: a zone is a view on the
-- mesh (the same points, connections and junctions) with its own name and points.

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Logger
local m_Logger = Logger('NavZones', Debug.Server.PATH)
---@type MinHeap
local m_Heap = require('__shared/Utils/MinHeap')

NavZoneFlags = {
	InZone = 1,
	Indoor = 2,
	Crouch = 4,
	-- A corner of a connection along waypoints where the soldier who recorded them jumped (Bot:UpdateZoneMovement).
	Jump = 8,
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
-- A point of the zone of an MCOM whose way over the mesh to the floor of the MCOM is longer than this many times its
-- distance to the MCOM (at least MCOM_DETOUR_MIN metres) is not part of the zone (_TrimMcomZone).
local MCOM_DETOUR_FACTOR = 2.0
local MCOM_DETOUR_MIN = 20.0
-- Parts of the mesh with fewer points get no junctions (_LinkJunctions).
local MIN_PART = 10
-- Metres of a cell of the grid of the points (Closest).
local GRID_CELL = 8.0
-- Closest searches the grid ring by ring up to this many rings for a point on the same floor, then all points.
local GRID_MAX_RINGS = 16

---@class NavZonePoint
---@field Index integer
---@field Position Vec3
---@field X number the position as plain numbers: the searches read them often, an access of a Vec3 is a call into the
---engine
---@field Y number
---@field Z number
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
---@field Neighbours table<integer, { To: integer, Cost: number, Corners: Vec3[], Jumps: table<integer, boolean>|nil, Penalty: number, Removed: boolean|nil }[]>
---@field Inside integer[] the points in the zone (the mesh itself: none)
---@field InsideSet table<integer, boolean>
---@field Junctions NavZoneJunction[]
---@field Vehicle NavZone|nil the zone on the mesh of the land vehicles
---@field Part table<integer, integer> point -> number of its connected part (points of different parts have no way)
---@field PartSize table<integer, integer> part -> its points
---@field ByWaypoint table<string, NavZoneJunction> waypoint-ID -> junction, set by _LinkJunctions
---@field Mesh NavZone the mesh the zone is on
---@field Grid NavZoneGrid the points by cells (Closest)

---@class NavZoneGrid
---@field Cells table<integer, integer[]> cell-key -> points
---@field MinX integer
---@field MaxX integer
---@field MinZ integer
---@field MaxZ integer

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
	-- Where players died in a damage area (electrified rails, fire): { Vec3 } (OnDamageAreaDeath).
	self._HazardDeaths = {}
	-- Counts up whenever the mesh or its junctions change (NavRoutes builds its graph anew then).
	self._Version = (self._Version or 0) + 1
	-- Counts up whenever connections are removed as well (NavRoutes measures the ways anew then).
	self._Topology = (self._Topology or 0) + 1
	-- Counts up whenever a connection costs more (BlockEdge): the fields of NavRoutes include those costs.
	self._Penalties = (self._Penalties or 0) + 1
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
	local s_Sizes = p_Mesh.PartSize
	for l_Part in pairs(s_Sizes) do
		s_Sizes[l_Part] = nil
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
	for l_Point = 1, #p_Mesh.Points do
		s_Sizes[s_Part[l_Point]] = (s_Sizes[s_Part[l_Point]] or 0) + 1
	end
end

---@param p_Raw table|nil { x, y, z }
---@return Vec3
local function _Vec(p_Raw)
	p_Raw = p_Raw or {}
	return Vec3(tonumber(p_Raw[1]) or 0, tonumber(p_Raw[2]) or 0, tonumber(p_Raw[3]) or 0)
end

---@param p_X integer
---@param p_Z integer
---@return integer
local function _CellKey(p_X, p_Z)
	return (p_X + 32768) * 65536 + (p_Z + 32768)
end

---The points by cells of GRID_CELL metres (horizontally), for Closest.
---@param p_Points NavZonePoint[]
---@return NavZoneGrid
local function _BuildGrid(p_Points)
	local s_Grid = { Cells = {}, MinX = math.huge, MaxX = -math.huge, MinZ = math.huge, MaxZ = -math.huge }
	for l_Index = 1, #p_Points do
		local s_X = math.floor(p_Points[l_Index].X / GRID_CELL)
		local s_Z = math.floor(p_Points[l_Index].Z / GRID_CELL)
		local s_Key = _CellKey(s_X, s_Z)
		local s_Cell = s_Grid.Cells[s_Key]
		if s_Cell == nil then
			s_Cell = {}
			s_Grid.Cells[s_Key] = s_Cell
		end
		s_Cell[#s_Cell + 1] = l_Index
		s_Grid.MinX = math.min(s_Grid.MinX, s_X)
		s_Grid.MaxX = math.max(s_Grid.MaxX, s_X)
		s_Grid.MinZ = math.min(s_Grid.MinZ, s_Z)
		s_Grid.MaxZ = math.max(s_Grid.MaxZ, s_Z)
	end
	return s_Grid
end

---The points in the cells up to p_Range metres around the position (horizontally; some are farther away).
---@param p_Grid NavZoneGrid
---@param p_Position Vec3
---@param p_Range number
---@return integer[]
local function _PointsAround(p_Grid, p_Position, p_Range)
	local s_Result = {}
	local s_MinX = math.floor((p_Position.x - p_Range) / GRID_CELL)
	local s_MaxX = math.floor((p_Position.x + p_Range) / GRID_CELL)
	local s_MinZ = math.floor((p_Position.z - p_Range) / GRID_CELL)
	local s_MaxZ = math.floor((p_Position.z + p_Range) / GRID_CELL)
	for l_X = s_MinX, s_MaxX do
		for l_Z = s_MinZ, s_MaxZ do
			local s_Cell = p_Grid.Cells[_CellKey(l_X, l_Z)]
			if s_Cell ~= nil then
				for l_Index = 1, #s_Cell do
					s_Result[#s_Result + 1] = s_Cell[l_Index]
				end
			end
		end
	end
	return s_Result
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
		PartSize = {},
		ByWaypoint = {},
	}
	s_Mesh.Mesh = s_Mesh

	local s_Points = p_Data.points or {}
	for l_Index = 1, #s_Points do
		local l_Point = s_Points[l_Index]
		local s_X, s_Y, s_Z = tonumber(l_Point[1]) or 0.0, tonumber(l_Point[2]) or 0.0, tonumber(l_Point[3]) or 0.0
		s_Mesh.Points[l_Index] = {
			Index = l_Index,
			Position = Vec3(s_X, s_Y, s_Z),
			X = s_X,
			Y = s_Y,
			Z = s_Z,
			Clearance = tonumber(l_Point[4]) or 0,
			Cover = math.floor(tonumber(l_Point[5]) or 0),
			Flags = math.floor(tonumber(l_Point[6]) or 0),
		}
		s_Mesh.Neighbours[l_Index] = {}
	end
	s_Mesh.Grid = _BuildGrid(s_Mesh.Points)

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
			-- Corners to jump at, as indices of the corners in each direction.
			local s_Jumps = nil
			local s_JumpsReversed = nil
			if type(l_Edge[6]) == 'table' and #l_Edge[6] > 0 then
				s_Jumps = {}
				s_JumpsReversed = {}
				for l_Jump = 1, #l_Edge[6] do
					local s_Corner = math.floor(l_Edge[6][l_Jump]) + 1
					s_Jumps[s_Corner] = true
					s_JumpsReversed[#s_Corners - s_Corner + 1] = true
				end
			end
			local s_Cost = tonumber(l_Edge[3]) or s_Mesh.Points[s_A].Position:Distance(s_Mesh.Points[s_B].Position)
			table.insert(s_Mesh.Neighbours[s_A], { To = s_B, Cost = s_Cost, Corners = s_Corners, Jumps = s_Jumps, Penalty = 0.0 })
			table.insert(s_Mesh.Neighbours[s_B],
				{ To = s_A, Cost = s_Cost, Corners = s_Reversed, Jumps = s_JumpsReversed, Penalty = 0.0 })
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
		PartSize = p_Mesh.PartSize,
		ByWaypoint = p_Mesh.ByWaypoint,
		Grid = p_Mesh.Grid,
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

---The zone of an MCOM is a circle: it also takes points of a floor far above or below that lead to the MCOM only over a
---long way round (XP4_Quake MCOM 2: an upper floor 10 m above it, 78 m over the mesh). Bots there were in the zone and
---walked around only where the mesh leads straight (_ZoneNewGoal): they stood up there and were sent to arm the MCOM from
---there. Those points are left out: the bots go on to the zone over the mesh. Unchanged if no point is on the floor of
---the MCOM.
---@param p_Zone NavZone
---@return integer points left out
local function _TrimMcomZone(p_Zone)
	local s_Points = p_Zone.Points
	local s_Center = p_Zone.Center
	local s_Costs = {}
	local s_Heap = m_Heap.New()
	for l_Index = 1, #p_Zone.Inside do
		local l_Point = p_Zone.Inside[l_Index]
		if math.abs(s_Points[l_Point].Y - s_Center.y) <= MCOM_FLOOR then
			s_Costs[l_Point] = 0.0
			m_Heap.Push(s_Heap, 0.0, l_Point)
		end
	end
	if s_Heap.Size == 0 then
		return 0
	end
	-- The longest way a point of the zone may have.
	local s_Limit = math.max(MCOM_DETOUR_MIN, MCOM_DETOUR_FACTOR * p_Zone.Radius)
	local s_Closed = {}
	while s_Heap.Size > 0 do
		local s_Cost, s_Current = m_Heap.Pop(s_Heap)
		if not s_Closed[s_Current] then
			s_Closed[s_Current] = true
			local s_Neighbours = p_Zone.Neighbours[s_Current]
			for l_Index = 1, #s_Neighbours do
				local l_Edge = s_Neighbours[l_Index]
				local s_New = s_Cost + l_Edge.Cost
				if s_New <= s_Limit and s_New < (s_Costs[l_Edge.To] or math.huge) then
					s_Costs[l_Edge.To] = s_New
					m_Heap.Push(s_Heap, s_New, l_Edge.To)
				end
			end
		end
	end
	local s_Inside = {}
	local s_InsideSet = {}
	for l_Index = 1, #p_Zone.Inside do
		local l_Point = p_Zone.Inside[l_Index]
		local s_DeltaX = s_Points[l_Point].X - s_Center.x
		local s_DeltaZ = s_Points[l_Point].Z - s_Center.z
		local s_Allowed = math.max(MCOM_DETOUR_MIN, MCOM_DETOUR_FACTOR * math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ))
		if (s_Costs[l_Point] or math.huge) <= s_Allowed then
			s_Inside[#s_Inside + 1] = l_Point
			s_InsideSet[l_Point] = true
		end
	end
	local s_Dropped = #p_Zone.Inside - #s_Inside
	p_Zone.Inside = s_Inside
	p_Zone.InsideSet = s_InsideSet
	return s_Dropped
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
		if s_Zone.Kind == 'mcom' then
			local s_Dropped = _TrimMcomZone(s_Zone)
			if s_Dropped > 0 then
				m_Logger:Write(s_Zone.Name .. ': ' .. s_Dropped .. ' points of another floor left out')
			end
		end
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
		local s_PartSize = p_Mesh.PartSize
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

---@return integer counts up when a connection was given up (BlockEdge)
function NavZones:GetPenalties()
	return self._Penalties
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
---point (not a hub: only where paths meet, nothing to walk around in), else the mesh.
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
	for l_Index = 1, #s_Zones do
		if s_Zones[l_Index].Kind ~= 'hub' then
			return s_Zones[l_Index]
		end
	end
	return self._Mesh
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

---Scores the points p_Indices (nil: all points of the zone) for Closest, returns the best so far.
---@return integer|nil, boolean, number
local function _ScanClosest(p_Zone, p_Indices, p_Position, p_Avoid, p_RangeSq, p_Best, p_BestOtherFloor, p_BestDistance)
	local s_Points = p_Zone.Points
	local s_Part = p_Zone.Part
	local s_PartSize = p_Zone.PartSize
	local s_X, s_Y, s_Z = p_Position.x, p_Position.y, p_Position.z
	for l_Entry = 1, p_Indices ~= nil and #p_Indices or #s_Points do
		local l_Index = p_Indices ~= nil and p_Indices[l_Entry] or l_Entry
		if l_Index ~= p_Avoid and (s_PartSize[s_Part[l_Index]] or 0) >= MIN_PART then
			local s_Point = s_Points[l_Index]
			local s_DeltaX = s_Point.X - s_X
			local s_DeltaY = s_Point.Y - s_Y
			local s_DeltaZ = s_Point.Z - s_Z
			local s_Horizontal = s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ
			if p_RangeSq == nil or s_Horizontal <= p_RangeSq then
				local s_Distance = s_Horizontal + 4 * s_DeltaY * s_DeltaY
				local s_OtherFloor = math.abs(s_DeltaY) > FLOOR_HEIGHT
				if (p_BestOtherFloor and not s_OtherFloor) or (s_OtherFloor == p_BestOtherFloor and s_Distance < p_BestDistance) then
					p_BestDistance = s_Distance
					p_BestOtherFloor = s_OtherFloor
					p_Best = l_Index
				end
			end
		end
	end
	return p_Best, p_BestOtherFloor, p_BestDistance
end

---The point of the network closest to the position. Points on the same floor (FLOOR_HEIGHT) come first: a soldier
---can't reach the point above it. Not on an island of the mesh (fewer than MIN_PART points, e.g. a point behind a wall
---the checks of the game cut off): the bot can't get there, no route leads on from there.
---Searches the grid ring by ring outwards (the same result as all points, the zones share the whole mesh).
---@param p_Zone NavZone
---@param p_Position Vec3
---@param p_Avoid? integer a point not to take (a dead end the bot got stuck at)
---@param p_Range? number only points up to this many metres away horizontally (nil: any)
---@return integer|nil point, number distance
function NavZones:Closest(p_Zone, p_Position, p_Avoid, p_Range)
	local s_Best = nil
	local s_BestOtherFloor = true
	local s_BestDistance = math.huge
	local s_Grid = p_Zone.Grid
	local s_RangeSq = p_Range ~= nil and p_Range * p_Range or nil
	local s_CellX = math.floor(p_Position.x / GRID_CELL)
	local s_CellZ = math.floor(p_Position.z / GRID_CELL)
	-- Beyond this ring there are no cells with points.
	local s_Extent = math.max(s_CellX - s_Grid.MinX, s_Grid.MaxX - s_CellX, s_CellZ - s_Grid.MinZ, s_Grid.MaxZ - s_CellZ)
	local s_MaxRings = p_Range ~= nil and math.ceil(p_Range / GRID_CELL) or GRID_MAX_RINGS
	local s_Cells = s_Grid.Cells
	for l_Ring = 0, math.min(s_MaxRings, s_Extent) do
		for l_X = -l_Ring, l_Ring do
			-- The rows at the top and bottom of the ring whole, of the others only both ends.
			local s_Step = (l_X == -l_Ring or l_X == l_Ring) and 1 or math.max(2 * l_Ring, 1)
			for l_Z = -l_Ring, l_Ring, s_Step do
				local s_Cell = s_Cells[_CellKey(s_CellX + l_X, s_CellZ + l_Z)]
				if s_Cell ~= nil then
					s_Best, s_BestOtherFloor, s_BestDistance = _ScanClosest(p_Zone, s_Cell, p_Position, p_Avoid, s_RangeSq,
						s_Best, s_BestOtherFloor, s_BestDistance)
				end
			end
		end
		-- The points of the next rings are at least this far away horizontally (and the height only adds).
		if s_Best ~= nil and not s_BestOtherFloor and s_BestDistance <= (l_Ring * GRID_CELL) ^ 2 then
			return s_Best, math.sqrt(s_BestDistance)
		end
	end
	if p_Range == nil and s_Extent > s_MaxRings then
		-- Nothing on the same floor close by: all points.
		s_Best, s_BestOtherFloor, s_BestDistance = _ScanClosest(p_Zone, nil, p_Position, p_Avoid, nil, nil, true, math.huge)
	end
	return s_Best, math.sqrt(s_BestDistance)
end

-- A spawn of the game can lie outside of the mesh (the alternate spawns of a capture point, 70 m from the flag): the
-- closest points may be behind a wall. ZoneAtVisible casts rays to the closest ones, at most this many, at these heights.
local VISIBLE_CANDIDATES = 8
local VISIBLE_HEIGHTS = { 0.5, 1.2 }

---The mesh at the position: a point within p_Range on the same floor the soldier can walk to straight (no wall between,
---rays at knee and chest height), and the zone there (ZoneAtPoint). Used for bots that spawn at the spawn-points of the
---game. nil, nil if there is no such point; the closest point on the floor then as third value.
---@param p_Position Vec3
---@param p_Range number
---@param p_Objective string|nil
---@return NavZone|nil, integer|nil, integer|nil
function NavZones:ZoneAtVisible(p_Position, p_Range, p_Objective)
	if self._Mesh == nil then
		return nil, nil, nil
	end
	local s_Points = self._Mesh.Points
	local s_Part = self._Mesh.Part
	local s_PartSize = self._Mesh.PartSize
	local s_Candidates = {}
	local s_X, s_Y, s_Z = p_Position.x, p_Position.y, p_Position.z
	local s_Around = _PointsAround(self._Mesh.Grid, p_Position, p_Range)
	for l_Entry = 1, #s_Around do
		local l_Index = s_Around[l_Entry]
		local s_Point = s_Points[l_Index]
		local s_DeltaX = s_Point.X - s_X
		local s_DeltaZ = s_Point.Z - s_Z
		local s_Distance = s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ
		-- Not on an island of the mesh (a nook next to a spawn the checks cut off): no way leads on from there.
		if s_Distance <= p_Range * p_Range and math.abs(s_Point.Y - s_Y) <= FLOOR_HEIGHT
			and (s_PartSize[s_Part[l_Index]] or 0) >= MIN_PART then
			s_Candidates[#s_Candidates + 1] = { l_Index, s_Distance }
		end
	end
	if #s_Candidates == 0 then
		return nil, nil, nil
	end
	table.sort(s_Candidates, function(p_A, p_B) return p_A[2] < p_B[2] end)
	local s_Flags = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.DontCheckWater
	---@cast s_Flags RayCastFlags
	---@type MaterialFlags|integer
	local s_NoMaterialFlags = 0
	for l_Index = 1, math.min(VISIBLE_CANDIDATES, #s_Candidates) do
		local l_Point = s_Candidates[l_Index][1]
		local s_Target = s_Points[l_Point].Position
		local s_Clear = true
		for _, l_Height in ipairs(VISIBLE_HEIGHTS) do
			local s_Up = Vec3(0, l_Height, 0)
			if RaycastManager:CollisionRaycast(p_Position + s_Up, s_Target + s_Up, 1, s_NoMaterialFlags, s_Flags)[1] ~= nil then
				s_Clear = false
				break
			end
		end
		if s_Clear then
			return self:ZoneAtPoint(l_Point, p_Objective), l_Point, s_Candidates[1][1]
		end
	end
	return nil, nil, s_Candidates[1][1]
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
	self._Penalties = self._Penalties + 1
	local s_Removed = s_Remove == true
	if s_Removed then
		self._Topology = self._Topology + 1
		_ComputeParts(p_Zone.Mesh)
		m_Logger:Write('zone ' .. p_Zone.Name .. ': connection ' .. p_A .. '-' .. p_B .. ' removed')
	end
end

---Whether the connection was given up REMOVE_AFTER times but kept: it is the only way between two parts of the mesh
---(BlockEdge). A bot stuck there again is put across it (Bot:_ZoneGiveUpConnection).
---@param p_Zone NavZone
---@param p_A integer
---@param p_B integer
---@return boolean
function NavZones:IsKeptBlocked(p_Zone, p_A, p_B)
	local s_Neighbours = p_Zone.Neighbours[p_A] or {}
	for l_Index = 1, #s_Neighbours do
		local l_Edge = s_Neighbours[l_Index]
		if l_Edge.To == p_B then
			return not l_Edge.Removed and l_Edge.Penalty >= BLOCKED_PENALTY * REMOVE_AFTER
		end
	end
	return false
end

-- A second death in a damage area this close to an earlier one: a hazard on the mesh (the rails in a metro), not the
-- border of the combat area (those deaths are spread out). The points this close to it are left out until the level ends.
local HAZARD_DEATHS_RANGE = 3.0
local HAZARD_POINT_RANGE = 2.5

---A player died in a damage area (weapon "DamageArea"): at the second death at the same place the mesh there is left
---out (its connections are removed): the census sees the ground, not that it kills.
---@param p_Position Vec3
function NavZones:OnDamageAreaDeath(p_Position)
	local s_Mesh = self._Mesh
	if s_Mesh == nil or p_Position == nil then
		return
	end
	local s_Repeated = false
	for l_Index = 1, #self._HazardDeaths do
		if self._HazardDeaths[l_Index]:Distance(p_Position) <= HAZARD_DEATHS_RANGE then
			s_Repeated = true
			break
		end
	end
	self._HazardDeaths[#self._HazardDeaths + 1] = p_Position:Clone()
	if not s_Repeated then
		return
	end
	local s_Removed = 0
	for l_Point = 1, #s_Mesh.Points do
		local s_Position = s_Mesh.Points[l_Point].Position
		local s_DeltaX = s_Position.x - p_Position.x
		local s_DeltaZ = s_Position.z - p_Position.z
		if s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ <= HAZARD_POINT_RANGE * HAZARD_POINT_RANGE
			and math.abs(s_Position.y - p_Position.y) <= FLOOR_HEIGHT then
			for _, l_Edge in ipairs(s_Mesh.Neighbours[l_Point]) do
				if not l_Edge.Removed then
					l_Edge.Removed = true
					s_Removed = s_Removed + 1
					for _, l_Back in ipairs(s_Mesh.Neighbours[l_Edge.To]) do
						if l_Back.To == l_Point then
							l_Back.Removed = true
						end
					end
				end
			end
		end
	end
	if s_Removed > 0 then
		self._Topology = self._Topology + 1
		_ComputeParts(s_Mesh)
		m_Logger:Write('hazard at ' .. tostring(p_Position) .. ': ' .. s_Removed .. ' connections removed')
	end
end

-- Metres of the regions a bot avoids more or less (NavZones:Route with a seed).
local SPREAD_REGION = 30.0

---How much longer the ways in the region of the position seem to the bot (Registry.BOT.NAV_ROUTE_SPREAD): the bots
---take different streets and corridors, not all the shortest one. The same for a life of the bot (p_Seed).
---@param p_Seed number
---@param p_X number
---@param p_Z number
---@return number factor 1 .. 1 + NAV_ROUTE_SPREAD
local function _RegionSpread(p_Seed, p_X, p_Z)
	local s_Hash = math.sin(p_Seed * 12.9898 + math.floor(p_X / SPREAD_REGION) * 78.233
		+ math.floor(p_Z / SPREAD_REGION) * 37.719) * 43758.5453
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
	local s_GoalX, s_GoalY, s_GoalZ = s_Points[p_To].X, s_Points[p_To].Y, s_Points[p_To].Z
	local s_Costs = { [p_From] = 0.0 }
	local s_Came = {}
	local s_Closed = {}
	-- Points by their estimate (the straight way to the goal).
	local s_Heap = m_Heap.New()
	m_Heap.Push(s_Heap, 0.0, p_From)

	while s_Heap.Size > 0 do
		local _, s_Current = m_Heap.Pop(s_Heap)
		if s_Current == p_To then
			-- Back from the goal, then reversed.
			local s_Route = { p_To }
			while s_Came[s_Route[#s_Route]] ~= nil do
				s_Route[#s_Route + 1] = s_Came[s_Route[#s_Route]]
			end
			for l_Index = 1, #s_Route // 2 do
				local s_Other = #s_Route - l_Index + 1
				s_Route[l_Index], s_Route[s_Other] = s_Route[s_Other], s_Route[l_Index]
			end
			return s_Route, s_Costs[p_To]
		end

		if not s_Closed[s_Current] then
			s_Closed[s_Current] = true
			local s_Neighbours = p_Zone.Neighbours[s_Current]
			local s_CurrentCost = s_Costs[s_Current]
			for l_Index = 1, #s_Neighbours do
				local l_Edge = s_Neighbours[l_Index]
				local s_To = l_Edge.To
				if not l_Edge.Removed and not s_Closed[s_To] then
					local s_Point = s_Points[s_To]
					local s_Step = l_Edge.Cost
					if p_Seed ~= nil then
						s_Step = s_Step * _RegionSpread(p_Seed, s_Point.X, s_Point.Z)
					end
					local s_Cost = s_CurrentCost + s_Step + l_Edge.Penalty
					if s_Cost < (s_Costs[s_To] or math.huge) then
						s_Costs[s_To] = s_Cost
						s_Came[s_To] = s_Current
						local s_DeltaX, s_DeltaY, s_DeltaZ = s_Point.X - s_GoalX, s_Point.Y - s_GoalY, s_Point.Z - s_GoalZ
						m_Heap.Push(s_Heap, s_Cost + math.sqrt(s_DeltaX * s_DeltaX + s_DeltaY * s_DeltaY + s_DeltaZ * s_DeltaZ),
							s_To)
					end
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
				local s_Jumps = s_Neighbours[l_Edge].Jumps
				for l_Corner = 1, #s_Corners do
					s_Result[#s_Result + 1] = {
						Position = s_Corners[l_Corner],
						Flags = (s_Jumps ~= nil and s_Jumps[l_Corner]) and NavZoneFlags.Jump or 0,
					}
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
