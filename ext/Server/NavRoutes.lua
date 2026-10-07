---@class NavRoutes
---@overload fun():NavRoutes
NavRoutes = class('NavRoutes')

-- Routes over the mesh (NavZones.lua) and the paths. The mesh covers the objectives and the spawns of the game, the
-- paths lead between them (trimmed at the mesh by the debug-server, census/navpaths.py, with their links), and the
-- roads (land vehicle paths, they seem ROAD_FACTOR times as long: foot paths first). Where the mesh
-- leads to the target a bot walks the mesh, else it leaves the mesh at a junction (a waypoint with a point of the mesh),
-- walks the paths and goes onto the mesh again at another junction.
--
-- The graph of the paths has the waypoints where something can change as its nodes: the ends of the paths, the
-- waypoints with links and the junctions. Its edges are the stretches of the paths between two of them (both ways), the
-- links and the junctions (into the mesh). Per target one field gives the metres from every point of the mesh and every
-- node to it, over the mesh and the paths (_Field). On the mesh a bot picks the junction to leave at (Next), off the
-- mesh it picks at each node the cheapest way on (Step): along the path, over a link, or onto the mesh. Each bot weighs
-- the ways a little differently (_Spread), and the paths its team crowds seem longer (_Crowd): they spread over the ways.

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type NavZones
local m_NavZones = require('NavZones')
---@type Logger
local m_Logger = Logger('NavRoutes', Debug.Server.PATH)

-- Metres added for a link (rather stay on a path), longer links are no way to walk.
local LINK_COST = 2.0
local LINK_MAX = 15.0
-- A looping path whose ends are this close is walked over from its last waypoint to its first.
local LOOP_CLOSE = 30.0
-- Metres added for leaving the mesh and coming back to it (waiting bots, corners): the mesh wins a tie.
local MESH_CROSSING = 10.0
-- Metres added to an exit a bot didn't get to over the mesh, and to a stretch of a path a bot got stuck on (for all
-- bots, until the level ends).
local EXIT_PENALTY = 100.0
local STRETCH_PENALTY = 100.0
-- A stretch of a path shorter than this between two junctions whose points the mesh connects with a way at most
-- SHORTCUT_DETOUR times as long (plus SHORTCUT_SLACK metres) is no way for the routes (_DropShortcuts).
local SHORTCUT_LENGTH = 30.0
local SHORTCUT_DETOUR = 1.5
local SHORTCUT_SLACK = 20.0
-- A bot that just left the mesh doesn't go onto it again at a junction this close to where it left (metres).
local NO_ENTER_RANGE = 10.0
-- A field is measured anew when the mesh or the penalties changed, but at most this often (seconds).
local FIELD_REFRESH = 5.0

---@class NavTarget
---@field Zone NavZone|nil the zone of the objective (nil: an objective with paths of its own)
---@field Points integer[] the points of the mesh where the target is
---@field Junctions table<integer, NavZoneJunction>|nil point -> junction of a path of the objective (not a zone)
---@field Action table|nil something to do there, without a path (GameDirector:GetActionTarget): get into a vehicle,
---arm an MCOM. The points are the ones next to it.
---@field Topology integer|nil NavZones:GetTopology when the points next to the action were chosen

---@class NavEdge
---@field To integer the node
---@field Cost number metres
---@field Path integer|nil along this path (nil: a link)
---@field Direction string|nil 'Next' or 'Previous' along the path
---@field Penalty number|nil metres added: bots got stuck there (BlockStretch)

---@class NavNode
---@field Waypoint Waypoint
---@field Edges NavEdge[]
---@field Junction NavZoneJunction|nil
---@field JunctionCost number metres from the waypoint to the point of the junction

-- Points of the mesh next to a vehicle (horizontal metres, Registry.VEHICLES.MIN_DISTANCE_VEHICLE_ENTER) and on its
-- floor (the vehicle-spawn is the middle of the vehicle): the bot gets in from there. At most ACTION_POINTS of them.
local ACTION_RANGE = 8.0
-- An MCOM: only points in sight of it (_InSight), up to this far.
local ACTION_RANGE_MCOM = 12.0
local ACTION_RANGE_MCOM_FAR = 25.0
local ACTION_FLOOR = 3.0
local ACTION_POINTS = 4
-- A vehicle that moved this far: its points anew.
local ACTION_MOVED = 3.0
-- Same as NavZones.lua MIN_PART: points on smaller parts of the mesh are no target (islands, no way leads there).
local ACTION_MIN_PART = 10

-- Points whose ways to the junctions are kept (_JunctionCosts), at most this many (then anew).
local JUNCTION_COST_CACHE = 1500

-- Metres a path seems longer for each bot of the team on it or on the way to it (_Crowd): the bots spread over the ways
-- to their objective (the other staircase, the next street) instead of all taking the shortest one.
local CROWD_COST = 15.0
-- At most this many metres in all: enough to take the next staircase, not a long way round that ends where it began
-- (ten bots on the way north made a loop of 300 m south and back look shorter, MP_018).
local CROWD_MAX = 45.0
-- Seconds the counts of the bots per path are kept.
local CROWD_TIME = 1.0

---Binary heap of { cost, ... }.
---@param p_Heap table
---@param p_Entry table
local function _Push(p_Heap, p_Entry)
	p_Heap[#p_Heap + 1] = p_Entry
	local s_Index = #p_Heap
	while s_Index > 1 do
		local s_Parent = s_Index // 2
		if p_Heap[s_Parent][1] <= p_Heap[s_Index][1] then
			break
		end
		p_Heap[s_Parent], p_Heap[s_Index] = p_Heap[s_Index], p_Heap[s_Parent]
		s_Index = s_Parent
	end
end

---@param p_Heap table
---@return table
local function _Pop(p_Heap)
	local s_Top = p_Heap[1]
	local s_Last = table.remove(p_Heap)
	if #p_Heap > 0 then
		p_Heap[1] = s_Last
		local s_Index = 1
		while true do
			local s_Smallest = s_Index
			local s_Left = 2 * s_Index
			if s_Left <= #p_Heap and p_Heap[s_Left][1] < p_Heap[s_Smallest][1] then
				s_Smallest = s_Left
			end
			if s_Left + 1 <= #p_Heap and p_Heap[s_Left + 1][1] < p_Heap[s_Smallest][1] then
				s_Smallest = s_Left + 1
			end
			if s_Smallest == s_Index then
				break
			end
			p_Heap[s_Smallest], p_Heap[s_Index] = p_Heap[s_Index], p_Heap[s_Smallest]
			s_Index = s_Smallest
		end
	end
	return s_Top
end

---How much longer a way seems to the bot (Registry.BOT.NAV_ROUTE_SPREAD): each bot takes its own route, not all of
---them the shortest one. The same for the way during a life of the bot (p_Seed).
---@param p_Seed number|nil
---@param p_Key integer the path (0: the mesh, negative: a link)
---@return number factor 1 .. 1 + NAV_ROUTE_SPREAD
local function _Spread(p_Seed, p_Key)
	if p_Seed == nil then
		return 1.0
	end
	local s_Hash = math.sin(p_Seed * 12.9898 + p_Key * 78.233) * 43758.5453
	return 1.0 + Registry.BOT.NAV_ROUTE_SPREAD * (s_Hash - math.floor(s_Hash))
end

---What NavRoutes:Next returns: walk the mesh to Point (in Zone), or leave it over Exit. With Action: do it at Point.
---@class NavStep
---@field Zone NavZone|nil
---@field Point integer|nil
---@field Exit NavZoneJunction|nil
---@field Action table|nil

function NavRoutes:__init()
	self:Clear()
end

function NavRoutes:Clear()
	self._Version = -1
	---@type NavNode[]
	self._Nodes = {}
	---waypoint-ID -> node
	---@type table<string, integer>
	self._NodeOf = {}
	---path -> { Before = point -> node, BeforeCost = point -> metres, After, AfterCost }: the nodes around each waypoint
	self._Around = {}
	---point of the mesh -> the nodes with a junction there
	---@type table<integer, integer[]>
	self._JunctionNodes = {}
	---junction -> metres added (BlockExit)
	---@type table<NavZoneJunction, number>
	self._Penalty = {}
	---junction -> metres added for coming onto the mesh there (BlockEntry)
	---@type table<NavZoneJunction, number>
	self._EntryPenalty = {}
	self._PenaltyVersion = 0
	---objective -> its target (false: none), see Target
	self._Targets = {}
	---objective -> its target next to a vehicle or an MCOM (false: none on the mesh), see _ActionTarget
	self._ActionTargets = {}
	---target -> { Topology, Penalties, Time, Mesh = point -> metres, Node = node -> metres }
	self._Fields = {}
	---target -> { Topology, Cost = point -> metres over the mesh alone }
	self._MeshFields = {}
	---point -> the metres over the mesh to the junction-nodes in its part (_JunctionCosts)
	self._JunctionCostCache = {}
	self._JunctionCostCount = 0
	self._JunctionCostTopology = -1
	---team -> { Time, Count = path -> bots of the team on it or on the way to it } (_Crowd)
	self._Crowds = {}
end

-- A road (a land vehicle path) seems this many times as long to a soldier: it walks one where no foot path leads.
local ROAD_FACTOR = 1.5

---Whether soldiers walk the path, and how much longer it seems to them: a foot path (1), a road (ROAD_FACTOR, a land
---vehicle path), not the paths of the boats, amphibious vehicles and of the air (nil).
---@param p_First Waypoint|boolean|nil
---@return number|nil
local function _WalkFactor(p_First)
	if p_First == nil or type(p_First) ~= 'table' then
		return nil
	end
	local s_Vehicles = p_First.Data and p_First.Data.Vehicles
	if s_Vehicles == nil or #s_Vehicles == 0 then
		return 1.0
	end
	local s_Land = false
	for l_Index = 1, #s_Vehicles do
		local l_Kind = tostring(s_Vehicles[l_Index]):lower()
		if l_Kind == 'air' or l_Kind == 'water' then
			return nil -- Also amphibious paths: they cross the water.
		end
		s_Land = s_Land or l_Kind == 'land'
	end
	return s_Land and ROAD_FACTOR or nil
end

---Builds the graph anew when the mesh or the waypoints changed (NavZones:GetVersion).
function NavRoutes:_Ensure()
	local s_Version = m_NavZones:GetVersion()
	if s_Version == self._Version then
		return
	end
	self:Clear()
	self._Version = s_Version
	local s_Mesh = m_NavZones:GetMesh()
	if s_Mesh == nil then
		return
	end

	local s_Paths = m_NodeCollection:GetPaths() or {}
	-- The waypoints that are nodes: the ends, the ones with links (and where links end), the junctions.
	local s_Key = {}
	local s_LinkCount = 0
	for _, l_Waypoints in pairs(s_Paths) do
		if _WalkFactor(l_Waypoints[1]) then
			for l_Index = 1, #l_Waypoints do
				local l_Waypoint = l_Waypoints[l_Index]
				if l_Index == 1 or l_Index == #l_Waypoints or m_NavZones:GetJunctionIn(s_Mesh, l_Waypoint) ~= nil then
					s_Key[l_Waypoint.ID] = true
				end
				local s_Links = l_Waypoint.Data and l_Waypoint.Data.Links
				for l_Link = 1, #(s_Links or {}) do
					local s_Target = m_NodeCollection:Get(s_Links[l_Link])
					if s_Target ~= nil and s_Target.PathIndex ~= l_Waypoint.PathIndex
						and _WalkFactor(m_NodeCollection:GetFirst(s_Target.PathIndex)) ~= nil then
						s_Key[l_Waypoint.ID] = true
						s_Key[s_Target.ID] = true
					end
				end
			end
		end
	end

	local function _NodeFor(p_Waypoint)
		local s_Node = self._NodeOf[p_Waypoint.ID]
		if s_Node == nil then
			self._Nodes[#self._Nodes + 1] = { Waypoint = p_Waypoint, Edges = {}, JunctionCost = 0.0 }
			s_Node = #self._Nodes
			self._NodeOf[p_Waypoint.ID] = s_Node
		end
		return s_Node
	end

	local function _Connect(p_A, p_B, p_Cost, p_Path, p_Direction, p_Back)
		local s_Edges = self._Nodes[p_A].Edges
		for l_Index = 1, #s_Edges do
			if s_Edges[l_Index].To == p_B and s_Edges[l_Index].Cost <= p_Cost then
				return
			end
		end
		s_Edges[#s_Edges + 1] = { To = p_B, Cost = p_Cost, Path = p_Path, Direction = p_Direction }
		local s_BackEdges = self._Nodes[p_B].Edges
		s_BackEdges[#s_BackEdges + 1] = { To = p_A, Cost = p_Cost, Path = p_Path, Direction = p_Back }
	end

	-- The stretches between the nodes of each path, and around each waypoint the nodes before and after it.
	for l_PathIndex, l_Waypoints in pairs(s_Paths) do
		local s_Count = #l_Waypoints
		local s_Factor = _WalkFactor(l_Waypoints[1])
		if s_Factor ~= nil and s_Count >= 1 then
			local s_Around = { Before = {}, BeforeCost = {}, After = {}, AfterCost = {} }
			self._Around[l_PathIndex] = s_Around
			local s_Last = nil
			local s_Since = 0.0
			for l_Index = 1, s_Count do
				local l_Waypoint = l_Waypoints[l_Index]
				if l_Index > 1 then
					s_Since = s_Since + l_Waypoints[l_Index - 1].Position:Distance(l_Waypoint.Position) * s_Factor
				end
				if s_Key[l_Waypoint.ID] then
					local s_Node = _NodeFor(l_Waypoint)
					if s_Last ~= nil then
						_Connect(s_Last, s_Node, s_Since, l_PathIndex, 'Next', 'Previous')
					end
					s_Last = s_Node
					s_Since = 0.0
				end
				s_Around.Before[l_Index] = s_Last
				s_Around.BeforeCost[l_Index] = s_Since
			end
			s_Last = nil
			s_Since = 0.0
			for l_Index = s_Count, 1, -1 do
				local l_Waypoint = l_Waypoints[l_Index]
				if l_Index < s_Count then
					s_Since = s_Since + l_Waypoints[l_Index + 1].Position:Distance(l_Waypoint.Position) * s_Factor
				end
				if s_Key[l_Waypoint.ID] then
					s_Last = self._NodeOf[l_Waypoint.ID]
					s_Since = 0.0
				end
				s_Around.After[l_Index] = s_Last
				s_Around.AfterCost[l_Index] = s_Since
			end
			-- A closed loop: from the last waypoint on to the first.
			local s_First = l_Waypoints[1]
			if s_Count > 2 and s_First.OptValue ~= 0xFF then
				local s_Gap = l_Waypoints[s_Count].Position:Distance(s_First.Position)
				if s_Gap <= LOOP_CLOSE then
					_Connect(self._NodeOf[l_Waypoints[s_Count].ID], self._NodeOf[s_First.ID], s_Gap * s_Factor, l_PathIndex,
						'Next', 'Previous')
				end
			end
		end
	end

	-- Links.
	for l_Node = 1, #self._Nodes do
		local l_Waypoint = self._Nodes[l_Node].Waypoint
		local s_Links = l_Waypoint.Data and l_Waypoint.Data.Links
		for l_Link = 1, #(s_Links or {}) do
			local s_Target = m_NodeCollection:Get(s_Links[l_Link])
			local s_Other = s_Target ~= nil and self._NodeOf[s_Target.ID] or nil
			if s_Other ~= nil and s_Other ~= l_Node then
				local s_Distance = l_Waypoint.Position:Distance(s_Target.Position)
				if s_Distance <= LINK_MAX then
					s_LinkCount = s_LinkCount + 1
					_Connect(l_Node, s_Other, s_Distance + LINK_COST, nil, nil, nil)
				end
			end
		end
	end

	-- Junctions.
	local s_Junctions = 0
	for l_Index = 1, #s_Mesh.Junctions do
		local l_Junction = s_Mesh.Junctions[l_Index]
		local s_Node = l_Junction.Waypoint ~= nil and self._NodeOf[l_Junction.Waypoint.ID] or nil
		if s_Node ~= nil and s_Mesh.Points[l_Junction.Point] ~= nil then
			local s_Entry = self._Nodes[s_Node]
			s_Entry.Junction = l_Junction
			s_Entry.JunctionCost = l_Junction.Waypoint.Position:Distance(s_Mesh.Points[l_Junction.Point].Position)
			local s_List = self._JunctionNodes[l_Junction.Point] or {}
			s_List[#s_List + 1] = s_Node
			self._JunctionNodes[l_Junction.Point] = s_List
			s_Junctions = s_Junctions + 1
		end
	end
	local s_Shortcuts = self:_DropShortcuts(s_Mesh)
	m_Logger:Write(#self._Nodes .. ' nodes on the paths, ' .. s_LinkCount .. ' links, ' .. s_Junctions .. ' junctions, '
		.. s_Shortcuts .. ' shortcuts dropped')
end

---Without the short stretches of paths between two junctions that the mesh connects about as well (SHORTCUT_*): the
---bots went off the mesh, a few metres along the path and onto it again, at the next such stretch off again (each bot
---weighs them a bit differently, they are all about as long).
---@param p_Mesh NavZone
---@return integer how many
function NavRoutes:_DropShortcuts(p_Mesh)
	local s_Count = 0
	for l_Node = 1, #self._Nodes do
		local s_Entry = self._Nodes[l_Node]
		local s_Junction = s_Entry.Junction
		if s_Junction ~= nil then
			for l_Index = #s_Entry.Edges, 1, -1 do
				local l_Edge = s_Entry.Edges[l_Index]
				local s_Other = self._Nodes[l_Edge.To].Junction
				if l_Edge.Path ~= nil and l_Edge.To > l_Node and s_Other ~= nil and l_Edge.Cost < SHORTCUT_LENGTH
					and p_Mesh.Part[s_Junction.Point] == p_Mesh.Part[s_Other.Point] then
					local s_Limit = SHORTCUT_DETOUR * l_Edge.Cost + SHORTCUT_SLACK
					if self:_MeshDistance(s_Junction.Point, s_Other.Point, s_Limit) <= s_Limit then
						table.remove(s_Entry.Edges, l_Index)
						local s_Back = self._Nodes[l_Edge.To].Edges
						for l_Back = #s_Back, 1, -1 do
							if s_Back[l_Back].To == l_Node and s_Back[l_Back].Path == l_Edge.Path then
								table.remove(s_Back, l_Back)
							end
						end
						s_Count = s_Count + 1
					end
				end
			end
		end
	end
	return s_Count
end

---Metres over the mesh from point to point, math.huge if more than p_Limit.
---@param p_From integer
---@param p_To integer
---@param p_Limit number
---@return number
function NavRoutes:_MeshDistance(p_From, p_To, p_Limit)
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_Cost = { [p_From] = 0.0 }
	local s_Heap = { { 0.0, p_From } }
	while #s_Heap > 0 do
		local s_Entry = _Pop(s_Heap)
		local s_Current = s_Entry[2]
		if s_Current == p_To then
			return s_Entry[1]
		end
		if s_Entry[1] <= s_Cost[s_Current] and s_Entry[1] <= p_Limit then
			local s_Neighbours = s_Mesh.Neighbours[s_Current]
			for l_Index = 1, #s_Neighbours do
				local l_Edge = s_Neighbours[l_Index]
				local s_Next = s_Entry[1] + l_Edge.Cost
				if not l_Edge.Removed and s_Next < (s_Cost[l_Edge.To] or math.huge) then
					s_Cost[l_Edge.To] = s_Next
					_Push(s_Heap, { s_Next, l_Edge.To })
				end
			end
		end
	end
	return math.huge
end

-- =============================================
-- Queries
-- =============================================

---Whether the bots find their way over the mesh and the paths.
---@return boolean
function NavRoutes:IsActive()
	return m_NavZones:GetMesh() ~= nil
end

---Whether the path is part of the routes (a path soldiers walk or a road, on a level with a mesh).
---@param p_PathIndex integer|nil
---@return boolean
function NavRoutes:IsRoutePath(p_PathIndex)
	self:_Ensure()
	return p_PathIndex ~= nil and self._Around[p_PathIndex] ~= nil
end

---Whether the routes guide a bot on the path to the objective (Step, Direction).
---@param p_PathIndex integer|nil
---@param p_Objective string|nil
---@return boolean
function NavRoutes:Guides(p_PathIndex, p_Objective)
	return self:IsRoutePath(p_PathIndex) and self:Knows(p_Objective)
end

---Where the bots with this objective go on the mesh: the points of its zone, else the junctions of its paths (a
---vehicle-path with its name). nil if the mesh has neither.
---@param p_Objective string|nil
---@return NavTarget|nil
function NavRoutes:Target(p_Objective)
	self:_Ensure()
	local s_Mesh = m_NavZones:GetMesh()
	if p_Objective == nil or p_Objective == '' or s_Mesh == nil then
		return nil
	end
	local s_Action = g_GameDirector ~= nil and g_GameDirector:GetActionTarget(p_Objective) or nil
	if s_Action ~= nil then
		local s_ActionTarget = self:_ActionTarget(p_Objective, s_Action)
		if s_ActionTarget ~= nil then
			return s_ActionTarget
		end
	end
	local s_Known = self._Targets[p_Objective]
	if s_Known == nil then
		s_Known = false
		local s_Zone = m_NavZones:GetZone(p_Objective)
		if s_Zone ~= nil and #s_Zone.Inside > 0 then
			s_Known = { Zone = s_Zone, Points = s_Zone.Inside }
		else
			local s_Points = {}
			local s_Junctions = {}
			for l_Index = 1, #s_Mesh.Junctions do
				local l_Junction = s_Mesh.Junctions[l_Index]
				local s_First = l_Junction.Waypoint and m_NodeCollection:GetFirst(l_Junction.Waypoint.PathIndex)
				local s_Data = type(s_First) == 'table' and s_First.Data or nil
				if s_Data ~= nil and table.has(s_Data.Objectives or {}, p_Objective) and s_Junctions[l_Junction.Point] == nil then
					s_Points[#s_Points + 1] = l_Junction.Point
					s_Junctions[l_Junction.Point] = l_Junction
				end
			end
			if #s_Points > 0 then
				s_Known = { Points = s_Points, Junctions = s_Junctions }
			end
		end
		self._Targets[p_Objective] = s_Known
	end
	return s_Known or nil
end

-- Rays from a point next to an MCOM to where the soldier stands to arm it: at these heights above both. A hit this close
-- to the spot is the MCOM itself.
local SIGHT_HEIGHTS = { 0.6, 1.2 }
local SIGHT_TOLERANCE = 0.8

---Whether the way from the point straight to the spot is free (rays at knee and chest height).
---@param p_From Vec3
---@param p_To Vec3
---@return boolean
local function _InSight(p_From, p_To)
	local s_Flags = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.DontCheckWater
	---@cast s_Flags RayCastFlags
	---@type MaterialFlags|integer
	local s_NoMaterialFlags = 0
	for _, l_Height in ipairs(SIGHT_HEIGHTS) do
		local s_To = Vec3(p_To.x, p_To.y + l_Height, p_To.z)
		local s_Hit = RaycastManager:CollisionRaycast(Vec3(p_From.x, p_From.y + l_Height, p_From.z), s_To, 1,
			s_NoMaterialFlags, s_Flags)[1]
		if s_Hit ~= nil and s_Hit.position:Distance(s_To) > SIGHT_TOLERANCE then
			return false
		end
	end
	return true
end

---The target of an objective that is done on the mesh: the points next to the vehicle or the MCOM (in the zone of the
---MCOM, closest to where the soldier stands). Again when the vehicle moved.
---@param p_Objective string
---@param p_Action table
---@return NavTarget|nil
function NavRoutes:_ActionTarget(p_Objective, p_Action)
	local s_Known = self._ActionTargets[p_Objective]
	-- Anew when connections were removed as well: a point next to it can be cut off now.
	if s_Known and s_Known.Action ~= nil and s_Known.Topology == m_NavZones:GetTopology()
		and s_Known.Action.Position:Distance(p_Action.Position) < ACTION_MOVED then
		s_Known.Action = p_Action
		return s_Known
	end
	if s_Known then
		self._Fields[s_Known] = nil
		self._MeshFields[s_Known] = nil
	end

	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_From = p_Action.Stand or p_Action.Position
	local s_Candidates = {}
	local s_Pool = p_Action.Zone ~= nil and p_Action.Zone.Inside or nil
	local s_Count = s_Pool ~= nil and #s_Pool or #s_Mesh.Points
	-- An MCOM in a room the mesh doesn't reach into (behind walls): the points up to ACTION_RANGE_MCOM_FAR then.
	local s_Ranges = p_Action.Kind == 'mcom' and { ACTION_RANGE_MCOM, ACTION_RANGE_MCOM_FAR } or { ACTION_RANGE }
	for _, l_Range in ipairs(s_Ranges) do
		for l_Index = 1, s_Count do
			local l_Point = s_Pool ~= nil and s_Pool[l_Index] or l_Index
			local s_Position = s_Mesh.Points[l_Point].Position
			local s_DeltaX = s_Position.x - s_From.x
			local s_DeltaZ = s_Position.z - s_From.z
			local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
			-- Not on an island of the mesh (a point in a room the bots can't get into over the mesh).
			if s_Distance <= l_Range and math.abs(s_Position.y - s_From.y) <= ACTION_FLOOR
				and (s_Mesh.PartSize[s_Mesh.Part[l_Point]] or 0) >= ACTION_MIN_PART then
				s_Candidates[#s_Candidates + 1] = { l_Point, s_Distance }
			end
		end
		if #s_Candidates > 0 then
			break
		end
	end
	table.sort(s_Candidates, function(p_A, p_B) return p_A[2] < p_B[2] end)
	local s_Points = {}
	for l_Index = 1, #s_Candidates do
		if #s_Points >= ACTION_POINTS then
			break
		end
		local l_Point = s_Candidates[l_Index][1]
		-- An MCOM: only points the soldier walks up to it from straight (the closest one can be behind the wall of the
		-- room it stands in, the bot ran against the wall).
		if p_Action.Kind ~= 'mcom' or _InSight(s_Mesh.Points[l_Point].Position, s_From) then
			s_Points[#s_Points + 1] = l_Point
		end
	end
	-- None in sight (an MCOM behind wooden walls, Subway MCOM 7): the closest ones anyway. A wrong way is better than none,
	-- the bots shoot what can be shot away on the way (Bot:_TryBreach).
	if #s_Points == 0 then
		for l_Index = 1, math.min(ACTION_POINTS, #s_Candidates) do
			s_Points[#s_Points + 1] = s_Candidates[l_Index][1]
		end
	end
	local s_Target = false
	if #s_Points > 0 then
		s_Target = { Zone = p_Action.Zone, Points = s_Points, Action = p_Action, Topology = m_NavZones:GetTopology() }
	end
	self._ActionTargets[p_Objective] = s_Target
	return s_Target or nil
end

---Whether bots get to the objective over the mesh and the paths (Target).
---@param p_Objective string|nil
---@return boolean
function NavRoutes:Knows(p_Objective)
	return self:Target(p_Objective) ~= nil
end

---The point of the target in the part of the mesh, closest to the position. nil if none is in it.
---@param p_Target NavTarget
---@param p_Part integer|nil
---@param p_Position Vec3
---@return integer|nil, number
local function _TargetIn(p_Target, p_Part, p_Position)
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_Best = nil
	local s_BestDistance = math.huge
	for l_Index = 1, #p_Target.Points do
		local l_Point = p_Target.Points[l_Index]
		if s_Mesh.Part[l_Point] == p_Part then
			local s_Distance = p_Position:Distance(s_Mesh.Points[l_Point].Position)
			if s_Distance < s_BestDistance then
				s_Best = l_Point
				s_BestDistance = s_Distance
			end
		end
	end
	return s_Best, s_BestDistance
end

---The metres over the mesh alone from every point to the target (the closest of its points), nil where the mesh
---doesn't lead there. Anew when connections were removed.
---@param p_Target NavTarget
---@return table<integer, number>
function NavRoutes:_MeshField(p_Target)
	local s_Topology = m_NavZones:GetTopology()
	local s_Known = self._MeshFields[p_Target]
	if s_Known ~= nil and s_Known.Topology == s_Topology then
		return s_Known.Cost
	end
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_Cost = {}
	local s_Heap = {}
	for l_Index = 1, #p_Target.Points do
		local l_Point = p_Target.Points[l_Index]
		s_Cost[l_Point] = 0.0
		_Push(s_Heap, { 0.0, l_Point })
	end
	while #s_Heap > 0 do
		local s_Entry = _Pop(s_Heap)
		local s_Current = s_Entry[2]
		if s_Entry[1] <= s_Cost[s_Current] then
			local s_Neighbours = s_Mesh.Neighbours[s_Current]
			for l_Index = 1, #s_Neighbours do
				local l_Edge = s_Neighbours[l_Index]
				local s_Next = s_Entry[1] + l_Edge.Cost
				if not l_Edge.Removed and s_Next < (s_Cost[l_Edge.To] or math.huge) then
					s_Cost[l_Edge.To] = s_Next
					_Push(s_Heap, { s_Next, l_Edge.To })
				end
			end
		end
	end
	self._MeshFields[p_Target] = { Topology = s_Topology, Cost = s_Cost }
	return s_Cost
end

---The metres from every point of the mesh and every node of the paths to the target, over both (given-up connections
---and exits cost more, removed connections don't lead on). Anew when that changed, at most every FIELD_REFRESH seconds.
---Mesh: point -> metres, Node: node -> metres.
---@param p_Target NavTarget
---@return { Mesh: table<integer, number>, Node: table<integer, number> }
function NavRoutes:_Field(p_Target)
	local s_Topology = m_NavZones:GetTopology()
	local s_Now = SharedUtils:GetTime()
	local s_Known = self._Fields[p_Target]
	if s_Known ~= nil and ((s_Known.Topology == s_Topology and s_Known.Penalties == self._PenaltyVersion)
			or s_Now - s_Known.Time < FIELD_REFRESH) then
		return s_Known
	end
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_MeshCost = {}
	local s_NodeCost = {}
	-- Entries { cost, point } for the mesh, { cost, -node } for the nodes.
	local s_Heap = {}
	for l_Index = 1, #p_Target.Points do
		local l_Point = p_Target.Points[l_Index]
		s_MeshCost[l_Point] = 0.0
		_Push(s_Heap, { 0.0, l_Point })
	end

	local function _ToNode(p_Node, p_Cost)
		if p_Cost < (s_NodeCost[p_Node] or math.huge) then
			s_NodeCost[p_Node] = p_Cost
			_Push(s_Heap, { p_Cost, -p_Node })
		end
	end

	while #s_Heap > 0 do
		local s_Entry = _Pop(s_Heap)
		local s_Cost, s_Id = s_Entry[1], s_Entry[2]
		if s_Id > 0 then
			if s_Cost <= s_MeshCost[s_Id] then
				local s_Neighbours = s_Mesh.Neighbours[s_Id]
				for l_Index = 1, #s_Neighbours do
					local l_Edge = s_Neighbours[l_Index]
					local s_Next = s_Cost + l_Edge.Cost + l_Edge.Penalty
					if not l_Edge.Removed and s_Next < (s_MeshCost[l_Edge.To] or math.huge) then
						s_MeshCost[l_Edge.To] = s_Next
						_Push(s_Heap, { s_Next, l_Edge.To })
					end
				end
				-- From the waypoint of a junction onto the mesh here (entries bots didn't get onto the mesh at cost more).
				local s_Junctions = self._JunctionNodes[s_Id]
				for l_Index = 1, #(s_Junctions or {}) do
					local l_Node = s_Junctions[l_Index]
					local s_Entry = self._Nodes[l_Node]
					_ToNode(l_Node, s_Cost + s_Entry.JunctionCost + (self._EntryPenalty[s_Entry.Junction] or 0.0))
				end
			end
		else
			local s_Node = -s_Id
			if s_Cost <= s_NodeCost[s_Node] then
				local s_Entry = self._Nodes[s_Node]
				for l_Index = 1, #s_Entry.Edges do
					local l_Edge = s_Entry.Edges[l_Index]
					_ToNode(l_Edge.To, s_Cost + l_Edge.Cost + (l_Edge.Penalty or 0.0))
				end
				-- From the mesh off at this junction: leaving costs (MESH_CROSSING, the exits bots didn't get to more).
				local s_Junction = s_Entry.Junction
				if s_Junction ~= nil then
					local s_Next = s_Cost + s_Entry.JunctionCost + MESH_CROSSING + (self._Penalty[s_Junction] or 0.0)
					if s_Next < (s_MeshCost[s_Junction.Point] or math.huge) then
						s_MeshCost[s_Junction.Point] = s_Next
						_Push(s_Heap, { s_Next, s_Junction.Point })
					end
				end
			end
		end
	end

	local s_Field = { Topology = s_Topology, Penalties = self._PenaltyVersion, Time = s_Now, Mesh = s_MeshCost,
		Node = s_NodeCost }
	self._Fields[p_Target] = s_Field
	return s_Field
end

---The metres over the mesh from the point to the junction-nodes in its part, the way the bots walk there (given-up
---connections cost more, removed ones don't lead on). Kept per point until connections are removed.
---@param p_Point integer
---@return table<integer, number> node -> metres
function NavRoutes:_JunctionCosts(p_Point)
	local s_Topology = m_NavZones:GetTopology()
	if self._JunctionCostTopology ~= s_Topology or self._JunctionCostCount >= JUNCTION_COST_CACHE then
		self._JunctionCostCache = {}
		self._JunctionCostCount = 0
		self._JunctionCostTopology = s_Topology
	end
	local s_Known = self._JunctionCostCache[p_Point]
	if s_Known ~= nil then
		return s_Known
	end
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_Result = {}
	local s_Cost = { [p_Point] = 0.0 }
	local s_Heap = { { 0.0, p_Point } }
	while #s_Heap > 0 do
		local s_Entry = _Pop(s_Heap)
		local s_Current = s_Entry[2]
		if s_Entry[1] <= s_Cost[s_Current] then
			local s_Nodes = self._JunctionNodes[s_Current]
			for l_Index = 1, #(s_Nodes or {}) do
				s_Result[s_Nodes[l_Index]] = s_Entry[1]
			end
			local s_Neighbours = s_Mesh.Neighbours[s_Current]
			for l_Index = 1, #s_Neighbours do
				local l_Edge = s_Neighbours[l_Index]
				local s_Next = s_Entry[1] + l_Edge.Cost + l_Edge.Penalty
				if not l_Edge.Removed and s_Next < (s_Cost[l_Edge.To] or math.huge) then
					s_Cost[l_Edge.To] = s_Next
					_Push(s_Heap, { s_Next, l_Edge.To })
				end
			end
		end
	end
	self._JunctionCostCache[p_Point] = s_Result
	self._JunctionCostCount = self._JunctionCostCount + 1
	return s_Result
end

---How many bots of the team walk each path or are on the way to it (on the mesh to its junction).
---@param p_Team TeamId|integer
---@return table<integer, integer> path -> bots
function NavRoutes:_Crowd(p_Team)
	local s_Now = SharedUtils:GetTime()
	local s_Known = self._Crowds[p_Team]
	if s_Known ~= nil and s_Now - s_Known.Time < CROWD_TIME then
		return s_Known.Count
	end
	local s_Count = {}
	local s_Bots = g_BotManager ~= nil and g_BotManager:GetBots() or {}
	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		if l_Bot.m_Player ~= nil and l_Bot.m_Player.teamId == p_Team and l_Bot.m_Player.soldier ~= nil then
			local s_State = l_Bot.m_Zone
			local s_Path = nil
			if s_State == nil then
				s_Path = l_Bot._PathIndex
			elseif s_State.Exit ~= nil and s_State.Exit.Waypoint ~= nil then
				s_Path = s_State.Exit.Waypoint.PathIndex
			end
			if s_Path ~= nil and self._Around[s_Path] ~= nil then
				s_Count[s_Path] = (s_Count[s_Path] or 0) + 1
			end
		end
	end
	self._Crowds[p_Team] = { Time = s_Now, Count = s_Count }
	return s_Count
end

---Where to go next from the point of the mesh, for the objective: over the mesh to a point of its zone (Zone, Point),
---or to the junction of a path (Exit). nil if the objective has no target on the mesh or no route leads there.
---@param p_Point integer
---@param p_Objective string
---@param p_Seed? number the bot's: its own route among similar ones (_Spread)
---@param p_Team? TeamId|integer the bot's: away from the paths its team crowds (_Crowd)
---@param p_Avoid? integer the node of the paths the bot just came onto the mesh from: no exit back there (it went on and
---off the mesh at two junctions next to each other)
---@param p_Used? table<NavZoneJunction, boolean> exits the bot took a short while ago: not again (a loop)
---@return NavStep|nil
function NavRoutes:Next(p_Point, p_Objective, p_Seed, p_Team, p_Avoid, p_Used)
	local s_Target = self:Target(p_Objective)
	local s_Mesh = m_NavZones:GetMesh()
	if s_Target == nil or s_Mesh == nil or s_Mesh.Points[p_Point] == nil then
		return nil
	end
	local s_Field = self:_Field(s_Target)
	if s_Field.Mesh[p_Point] == nil then
		return nil
	end

	-- The best junction to leave the mesh at: the way there over the mesh, then on along the paths. Each bot weighs the
	-- way to the junction and the first stretch of the path its own way (_Spread), the rest is what the field says: a
	-- stub that only leads back onto the mesh never seems shorter than the way on.
	local s_Crowd = p_Team ~= nil and self:_Crowd(p_Team) or {}
	local s_Exit = nil
	local s_ExitCost = math.huge
	for l_Node, l_Cost in pairs(self:_JunctionCosts(p_Point)) do
		local s_Entry = self._Nodes[l_Node]
		local s_Path = s_Entry.Waypoint.PathIndex
		local s_Out = math.huge
		-- Not an exit the bot took a short while ago (a loop), nor back to where it came onto the mesh.
		local s_Usable = l_Node ~= p_Avoid and not (p_Used ~= nil and p_Used[s_Entry.Junction])
		for l_Index = 1, s_Usable and #s_Entry.Edges or 0 do
			local l_Edge = s_Entry.Edges[l_Index]
			local s_Rest = s_Field.Node[l_Edge.To]
			if s_Rest ~= nil and l_Edge.To ~= p_Avoid then
				s_Out = math.min(s_Out, l_Edge.Cost * _Spread(p_Seed, l_Edge.Path or -l_Edge.To) + (l_Edge.Penalty or 0.0) + s_Rest)
			end
		end
		if s_Out < math.huge then
			local s_Cost = l_Cost * _Spread(p_Seed, s_Path) + s_Out + s_Entry.JunctionCost + MESH_CROSSING
				+ (self._Penalty[s_Entry.Junction] or 0.0) + math.min((s_Crowd[s_Path] or 0) * CROWD_COST, CROWD_MAX)
			if s_Cost < s_ExitCost then
				s_Exit = s_Entry.Junction
				s_ExitCost = s_Cost
			end
		end
	end

	-- To a vehicle, an MCOM: the point closest to it (not to the bot, that one may be behind a wall).
	local s_Action = s_Target.Action
	local s_Towards = s_Action ~= nil and (s_Action.Stand or s_Action.Position) or s_Mesh.Points[p_Point].Position
	local s_Found = _TargetIn(s_Target, s_Mesh.Part[p_Point], s_Towards)
	local s_MeshCost = self:_MeshField(s_Target)[p_Point]
	if s_Found ~= nil and s_MeshCost ~= nil and (s_Exit == nil or s_MeshCost * _Spread(p_Seed, 0) <= s_ExitCost) then
		if s_Target.Action ~= nil then
			return { Zone = s_Target.Zone or m_NavZones:ZoneAtPoint(s_Found, nil), Point = s_Found, Action = s_Target.Action }
		end
		if s_Target.Zone ~= nil then
			return { Zone = s_Target.Zone, Point = s_Found }
		end
		local s_Junctions = s_Target.Junctions
		---@cast s_Junctions -nil
		return { Exit = s_Junctions[s_Found] }
	end
	if s_Exit == nil then
		return nil
	end
	return { Exit = s_Exit }
end

---What the bot does at a node of the paths on the way to the objective: Enter the mesh at the junction there, Switch
---over a link to another waypoint, or go on along the path in Direction. Not back the way it came (p_Came, the node
---before), unless there is no other way; not onto the mesh at p_NoEnter (it just left the mesh there). Node: the node of
---the waypoint (the bot keeps it as p_Came for the next one). nil if the waypoint is no node or no route leads on.
---@param p_Waypoint Waypoint
---@param p_Objective string
---@param p_Seed? number
---@param p_Came? integer
---@param p_NoEnter? integer a point of the mesh
---@return { Node: integer, Enter: NavZoneJunction|nil, Switch: Waypoint|nil, Direction: string|nil }|nil
function NavRoutes:Step(p_Waypoint, p_Objective, p_Seed, p_Came, p_NoEnter)
	self:_Ensure()
	local s_Node = p_Waypoint ~= nil and self._NodeOf[p_Waypoint.ID] or nil
	local s_Target = s_Node ~= nil and self:Target(p_Objective) or nil
	if s_Target == nil then
		return nil
	end
	---@cast s_Node -nil
	local s_Field = self:_Field(s_Target)
	local s_Entry = self._Nodes[s_Node]

	local s_Best = nil
	local s_BestCost = math.huge
	local s_Back = nil
	local s_BackCost = math.huge
	for l_Index = 1, #s_Entry.Edges do
		local l_Edge = s_Entry.Edges[l_Index]
		local s_Rest = s_Field.Node[l_Edge.To]
		if s_Rest ~= nil then
			local s_Cost = l_Edge.Cost * _Spread(p_Seed, l_Edge.Path or -l_Edge.To) + (l_Edge.Penalty or 0.0) + s_Rest
			if l_Edge.To == p_Came then
				if s_Cost < s_BackCost then
					s_Back = l_Edge
					s_BackCost = s_Cost
				end
			elseif s_Cost < s_BestCost then
				s_Best = l_Edge
				s_BestCost = s_Cost
			end
		end
	end
	local s_Junction = s_Entry.Junction
	local s_Mesh = m_NavZones:GetMesh()
	-- Not onto the mesh where the bot just left it, nor at a junction next to that (two junctions of one path end).
	local s_Left = p_NoEnter ~= nil and s_Mesh ~= nil and s_Mesh.Points[p_NoEnter] or nil
	if s_Junction ~= nil and s_Left ~= nil and s_Mesh.Points[s_Junction.Point] ~= nil
		and s_Mesh.Points[s_Junction.Point].Position:Distance(s_Left.Position) < NO_ENTER_RANGE then
		s_Junction = nil
	end
	if s_Junction ~= nil and s_Junction.Point ~= p_NoEnter then
		local s_Rest = s_Field.Mesh[s_Junction.Point]
		if s_Rest ~= nil and s_Entry.JunctionCost + (self._EntryPenalty[s_Junction] or 0.0) + s_Rest <= s_BestCost then
			return { Node = s_Node, Enter = s_Junction }
		end
	end
	s_Best = s_Best or s_Back
	if s_Best == nil then
		return nil
	end
	if s_Best.Path == nil then
		local s_To = self._Nodes[s_Best.To]
		return { Node = s_Node, Switch = s_To.Waypoint, Direction = self:_NodeDirection(s_Best.To, s_Field, p_Seed, s_Node) }
	end
	return { Node = s_Node, Direction = s_Best.Direction }
end

---The direction along its path to take from a node: the cheaper of the two stretches (not back to p_Came).
---@param p_Node integer
---@param p_Field table
---@param p_Seed number|nil
---@param p_Came integer|nil
---@return string|nil
function NavRoutes:_NodeDirection(p_Node, p_Field, p_Seed, p_Came)
	local s_Entry = self._Nodes[p_Node]
	local s_Best = nil
	local s_BestCost = math.huge
	for l_Index = 1, #s_Entry.Edges do
		local l_Edge = s_Entry.Edges[l_Index]
		local s_Rest = p_Field.Node[l_Edge.To]
		if l_Edge.Path ~= nil and l_Edge.To ~= p_Came and s_Rest ~= nil then
			local s_Cost = l_Edge.Cost * _Spread(p_Seed, l_Edge.Path) + (l_Edge.Penalty or 0.0) + s_Rest
			if s_Cost < s_BestCost then
				s_Best = l_Edge.Direction
				s_BestCost = s_Cost
			end
		end
	end
	return s_Best
end

---On a path: which way leads to the objective. 'Next' (towards the last waypoint), 'Previous' or nil if the path
---isn't part of the routes or no route leads there.
---@param p_Waypoint Waypoint
---@param p_Objective string
---@param p_Seed? number
---@return string|nil
function NavRoutes:Direction(p_Waypoint, p_Objective, p_Seed)
	self:_Ensure()
	local s_Around = p_Waypoint ~= nil and self._Around[p_Waypoint.PathIndex] or nil
	local s_Target = s_Around ~= nil and self:Target(p_Objective) or nil
	if s_Target == nil then
		return nil
	end
	---@cast s_Around -nil
	local s_Field = self:_Field(s_Target)
	local s_Index = p_Waypoint.PointIndex
	local s_Node = self._NodeOf[p_Waypoint.ID]
	if s_Node ~= nil then
		return self:_NodeDirection(s_Node, s_Field, p_Seed, nil)
	end
	local s_Spread = _Spread(p_Seed, p_Waypoint.PathIndex)
	local s_Before, s_After = s_Around.Before[s_Index], s_Around.After[s_Index]
	local s_Back = s_Before ~= nil and s_Field.Node[s_Before] ~= nil
		and s_Around.BeforeCost[s_Index] * s_Spread + s_Field.Node[s_Before] or math.huge
	local s_Forward = s_After ~= nil and s_Field.Node[s_After] ~= nil
		and s_Around.AfterCost[s_Index] * s_Spread + s_Field.Node[s_After] or math.huge
	if s_Back == math.huge and s_Forward == math.huge then
		return nil
	end
	return s_Forward <= s_Back and 'Next' or 'Previous'
end

---The node the bot walks towards on its path (the next end, link or junction), for the progress-check off the mesh.
---@param p_PathIndex integer|nil
---@param p_PointIndex integer|nil
---@param p_Inverted boolean walking towards the first waypoint
---@return Waypoint|nil
function NavRoutes:Heading(p_PathIndex, p_PointIndex, p_Inverted)
	self:_Ensure()
	local s_Around = p_PathIndex ~= nil and self._Around[p_PathIndex] or nil
	if s_Around == nil or p_PointIndex == nil then
		return nil
	end
	local s_Node = p_Inverted and s_Around.Before[p_PointIndex] or s_Around.After[p_PointIndex]
	return s_Node ~= nil and self._Nodes[s_Node].Waypoint or nil
end

---A bot got stuck on the path there (no progress off the mesh, GameDirector:_CheckProgressOffMesh): the stretch between
---the two nodes around the waypoint costs more for all bots from now on, both ways. The paths have issues no tool finds
---(a door that is closed now, a fence, a gap the recording jumped): the bots learn them during the round.
---@param p_PathIndex integer|nil
---@param p_PointIndex integer|nil
---@return boolean true if there was such a stretch
function NavRoutes:BlockStretch(p_PathIndex, p_PointIndex)
	self:_Ensure()
	local s_Around = p_PathIndex ~= nil and self._Around[p_PathIndex] or nil
	if s_Around == nil or p_PointIndex == nil then
		return false
	end
	local s_Before, s_After = s_Around.Before[p_PointIndex], s_Around.After[p_PointIndex]
	if s_Before == nil or s_After == nil or s_Before == s_After then
		return false
	end
	local s_Found = false
	for _, l_Pair in ipairs({ { s_Before, s_After }, { s_After, s_Before } }) do
		local s_Edges = self._Nodes[l_Pair[1]].Edges
		for l_Index = 1, #s_Edges do
			local l_Edge = s_Edges[l_Index]
			if l_Edge.To == l_Pair[2] and l_Edge.Path == p_PathIndex then
				l_Edge.Penalty = (l_Edge.Penalty or 0.0) + STRETCH_PENALTY
				s_Found = true
			end
		end
	end
	if s_Found then
		self._PenaltyVersion = self._PenaltyVersion + 1
		m_Logger:Write('stretch of path ' .. p_PathIndex .. ' at ' .. p_PointIndex .. ' blocked')
	end
	return s_Found
end

---A bot that came onto the mesh at the junction didn't get from its waypoint to its point: all bots come onto the mesh
---elsewhere from now on, where there is another way.
---@param p_Junction NavZoneJunction
function NavRoutes:BlockEntry(p_Junction)
	self._EntryPenalty[p_Junction] = (self._EntryPenalty[p_Junction] or 0.0) + EXIT_PENALTY
	self._PenaltyVersion = self._PenaltyVersion + 1
	m_Logger:Write('entry at point ' .. p_Junction.Point .. ' blocked')
end

---A bot didn't get to the exit over the mesh: all bots take it less from now on.
---@param p_Junction NavZoneJunction
function NavRoutes:BlockExit(p_Junction)
	self._Penalty[p_Junction] = (self._Penalty[p_Junction] or 0.0) + EXIT_PENALTY
	self._PenaltyVersion = self._PenaltyVersion + 1
end

if g_NavRoutes == nil then
	---@type NavRoutes
	g_NavRoutes = NavRoutes()
end

return g_NavRoutes
