---@class NavRoutes
---@overload fun():NavRoutes
NavRoutes = class('NavRoutes')

-- Routes over the mesh (NavZones.lua) and the navigation paths. The mesh covers the areas around the objectives, the
-- navigation paths (made by the debug-server, census/navpaths.py) lead from one area to another: their first waypoint
-- has "Nav" = { From = zone at the first waypoint, To = zone at the last one, Length }. Where the mesh connects two
-- places a bot walks the mesh, else it leaves the mesh over the junction of a navigation path, walks the path and goes
-- onto the mesh again at its other end.
--
-- The graph has the ends of the navigation paths as its nodes: an end is the junction of a path with the mesh. From an
-- end a bot walks the path to its other end, and from there over the mesh to any end in the same connected part of the
-- mesh. A route ends in the part of the mesh where the target is: the points of the zone of the objective, or the
-- junctions of the paths of an objective that isn't a zone (a vehicle, a beacon, the action-node of an MCOM).

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type NavZones
local m_NavZones = require('NavZones')
---@type Logger
local m_Logger = Logger('NavRoutes', Debug.Server.PATH)

-- Metres added for each walk over the mesh between two navigation paths (waiting bots, fights, corners).
local MESH_CROSSING = 10.0
-- An end of a navigation path is its junction with the mesh among this many waypoints from the end.
local END_SEARCH = 15
-- Metres added to an exit a bot didn't get to over the mesh (for all bots, until the level ends).
local EXIT_PENALTY = 100.0

---@class NavRouteEnd
---@field Path NavPath
---@field Junction NavZoneJunction
---@field AtStart boolean the end at the first waypoint
---@field Other NavRouteEnd the end at the other side of the path

---@class NavPath
---@field PathIndex integer
---@field Length number
---@field Start NavRouteEnd
---@field Finish NavRouteEnd

---@class NavTarget
---@field Zone NavZone|nil the zone of the objective (nil: an objective with paths of its own)
---@field Points integer[] the points of the mesh where the target is
---@field Junctions table<integer, NavZoneJunction>|nil point -> junction of a path of the objective (not a zone)

---What NavRoutes:Next returns: walk the mesh to Point (in Zone), or leave it over Exit.
---@class NavStep
---@field Zone NavZone|nil
---@field Point integer|nil
---@field Exit NavZoneJunction|nil

function NavRoutes:__init()
	self:Clear()
end

function NavRoutes:Clear()
	---@type table<integer, NavPath>
	self._Paths = {}
	---@type NavRouteEnd[]
	self._Ends = {}
	self._Count = 0
	self._Version = -1
	---junction -> metres added (BlockExit)
	---@type table<NavZoneJunction, number>
	self._Penalty = {}
	---objective -> its target (false: none), see Target
	self._Targets = {}
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

	local s_Missing = 0
	for l_PathIndex, l_Waypoints in pairs(m_NodeCollection:GetPaths() or {}) do
		local s_First = l_Waypoints[1]
		local s_Nav = s_First and s_First.Data and s_First.Data.Nav
		if type(s_Nav) == 'table' and #l_Waypoints >= 2 then
			local s_StartJunction = self:_EndJunction(s_Mesh, l_Waypoints, 1, 1)
			local s_FinishJunction = self:_EndJunction(s_Mesh, l_Waypoints, #l_Waypoints, -1)
			if s_StartJunction ~= nil and s_FinishJunction ~= nil and s_StartJunction ~= s_FinishJunction then
				local s_Start = { Junction = s_StartJunction, AtStart = true }
				local s_Finish = { Junction = s_FinishJunction, AtStart = false, Other = s_Start }
				s_Start.Other = s_Finish
				---@type NavPath
				local s_Path = {
					PathIndex = l_PathIndex,
					Length = tonumber(s_Nav.Length) or 0.0,
					Start = s_Start,
					Finish = s_Finish,
				}
				s_Start.Path = s_Path
				s_Finish.Path = s_Path
				self._Paths[l_PathIndex] = s_Path
				self._Count = self._Count + 1
				self._Ends[#self._Ends + 1] = s_Start
				self._Ends[#self._Ends + 1] = s_Finish
			else
				s_Missing = s_Missing + 1
			end
		end
	end
	if self._Count > 0 or s_Missing > 0 then
		m_Logger:Write(self._Count .. ' navigation paths, ' .. s_Missing .. ' without junctions at both ends')
	end
end

---The junction of the mesh closest to an end of the path.
---@param p_Mesh NavZone
---@param p_Waypoints Waypoint[]
---@param p_From integer
---@param p_Step integer
---@return NavZoneJunction|nil
function NavRoutes:_EndJunction(p_Mesh, p_Waypoints, p_From, p_Step)
	for l_Offset = 0, END_SEARCH - 1 do
		local s_Waypoint = p_Waypoints[p_From + l_Offset * p_Step]
		if s_Waypoint == nil then
			return nil
		end
		local s_Junction = m_NavZones:GetJunctionIn(p_Mesh, s_Waypoint)
		if s_Junction ~= nil then
			return s_Junction
		end
	end
	return nil
end

-- =============================================
-- Queries
-- =============================================

---Whether the level has navigation paths.
---@return boolean
function NavRoutes:IsActive()
	self:_Ensure()
	return self._Count > 0
end

---@param p_PathIndex integer|nil
---@return NavPath|nil
function NavRoutes:GetPath(p_PathIndex)
	self:_Ensure()
	return p_PathIndex and self._Paths[p_PathIndex] or nil
end

---Where the bots with this objective go on the mesh: the points of its zone, else the junctions of its paths (a
---vehicle, a beacon, "mcom N interact"). nil if the mesh has neither.
---@param p_Objective string|nil
---@return NavTarget|nil
function NavRoutes:Target(p_Objective)
	self:_Ensure()
	local s_Mesh = m_NavZones:GetMesh()
	if p_Objective == nil or p_Objective == '' or s_Mesh == nil then
		return nil
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
				if s_Data ~= nil and s_Data.Nav == nil and table.has(s_Data.Objectives or {}, p_Objective)
					and s_Junctions[l_Junction.Point] == nil then
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

---Whether bots get to the objective over the mesh and the navigation paths (Target).
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

---The ends of navigation paths the bot can walk to from the point over the mesh (same part), with the cost.
---@param p_Point integer
---@param p_Start number cost so far
---@param p_Except NavRouteEnd|nil
---@return { End: NavRouteEnd, Cost: number }[]
function NavRoutes:_Departures(p_Point, p_Start, p_Except)
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_Result = {}
	local s_Part = s_Mesh.Part[p_Point]
	local s_From = s_Mesh.Points[p_Point].Position
	for l_Index = 1, #self._Ends do
		local l_End = self._Ends[l_Index]
		if l_End ~= p_Except and s_Mesh.Part[l_End.Junction.Point] == s_Part then
			s_Result[#s_Result + 1] = {
				End = l_End,
				Cost = p_Start + (self._Penalty[l_End.Junction] or 0.0)
					+ s_From:Distance(s_Mesh.Points[l_End.Junction.Point].Position),
			}
		end
	end
	return s_Result
end

---How much longer the navigation path seems to the bot (Registry.BOT.NAV_ROUTE_SPREAD): each bot takes its own
---route, not all of them the shortest one. The same for the path during a life of the bot (p_Seed).
---@param p_Seed number|nil
---@param p_PathIndex integer
---@return number factor 1 .. 1 + NAV_ROUTE_SPREAD
local function _Spread(p_Seed, p_PathIndex)
	if p_Seed == nil then
		return 1.0
	end
	local s_Hash = math.sin(p_Seed * 12.9898 + p_PathIndex * 78.233) * 43758.5453
	return 1.0 + Registry.BOT.NAV_ROUTE_SPREAD * (s_Hash - math.floor(s_Hash))
end

---Dijkstra over the ends. p_Departures: ends the bot can leave over, with what it costs to get there. Returns the
---cost to the target and the first end of that route.
---@param p_Departures { End: NavRouteEnd, Cost: number }[]
---@param p_Target NavTarget
---@param p_Seed? number the bot's (_Spread), nil: the shortest route
---@return number, NavRouteEnd|nil
function NavRoutes:_Search(p_Departures, p_Target, p_Seed)
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_Cost = {}
	local s_First = {}
	local s_Done = {}
	local s_Open = {}
	for l_Index = 1, #p_Departures do
		local l_Departure = p_Departures[l_Index]
		if s_Cost[l_Departure.End] == nil or l_Departure.Cost < s_Cost[l_Departure.End] then
			if s_Cost[l_Departure.End] == nil then
				s_Open[#s_Open + 1] = l_Departure.End
			end
			s_Cost[l_Departure.End] = l_Departure.Cost
			s_First[l_Departure.End] = l_Departure.End
		end
	end

	local s_Best = math.huge
	local s_BestFirst = nil
	while true do
		-- The open end with the lowest cost (few ends: a list is fast enough).
		local s_Index = nil
		for l_Index = 1, #s_Open do
			if s_Index == nil or s_Cost[s_Open[l_Index]] < s_Cost[s_Open[s_Index]] then
				s_Index = l_Index
			end
		end
		if s_Index == nil then
			break
		end
		local s_End = s_Open[s_Index]
		table.remove(s_Open, s_Index)
		if s_Cost[s_End] >= s_Best then
			break
		end
		if not s_Done[s_End] then
			s_Done[s_End] = true
			local s_Arrival = s_End.Other
			local s_ArrivalPoint = s_Arrival.Junction.Point
			local s_Total = s_Cost[s_End] + s_End.Path.Length * _Spread(p_Seed, s_End.Path.PathIndex)
			local s_Found, s_Distance = _TargetIn(p_Target, s_Mesh.Part[s_ArrivalPoint],
				s_Mesh.Points[s_ArrivalPoint].Position)
			if s_Found ~= nil then
				if s_Total + s_Distance < s_Best then
					s_Best = s_Total + s_Distance
					s_BestFirst = s_First[s_End]
				end
			else
				local s_Next = self:_Departures(s_ArrivalPoint, s_Total + MESH_CROSSING, s_Arrival)
				for l_Index = 1, #s_Next do
					local l_Next = s_Next[l_Index]
					if not s_Done[l_Next.End] and (s_Cost[l_Next.End] == nil or l_Next.Cost < s_Cost[l_Next.End]) then
						if s_Cost[l_Next.End] == nil then
							s_Open[#s_Open + 1] = l_Next.End
						end
						s_Cost[l_Next.End] = l_Next.Cost
						s_First[l_Next.End] = s_First[s_End]
					end
				end
			end
		end
	end
	return s_Best, s_BestFirst
end

---Where to go next from the point of the mesh, for the objective: over the mesh to a point of its zone (Zone, Point),
---or to the junction of a path (Exit: of a navigation path, or of a path of the objective). nil if the objective has no
---target on the mesh or no route leads there.
---@param p_Point integer
---@param p_Objective string
---@param p_Seed? number the bot's: its own route among similar ones (_Spread)
---@return NavStep|nil
function NavRoutes:Next(p_Point, p_Objective, p_Seed)
	local s_Target = self:Target(p_Objective)
	local s_Mesh = m_NavZones:GetMesh()
	if s_Target == nil or s_Mesh == nil or s_Mesh.Points[p_Point] == nil then
		return nil
	end
	local s_Found = _TargetIn(s_Target, s_Mesh.Part[p_Point], s_Mesh.Points[p_Point].Position)
	local s_Cost, s_First = self:_Search(self:_Departures(p_Point, 0.0, nil), s_Target, p_Seed)
	if s_Found ~= nil then
		-- The mesh leads there, maybe only a long way round: a navigation path may be shorter (its cost has straight
		-- lines over the mesh at both ends: only clearly shorter).
		local s_Route, s_MeshCost = m_NavZones:Route(s_Mesh, p_Point, s_Found, p_Seed)
		if s_First == nil or s_Route == nil or s_MeshCost <= s_Cost + MESH_CROSSING then
			if s_Target.Zone ~= nil then
				return { Zone = s_Target.Zone, Point = s_Found }
			end
			local s_Junctions = s_Target.Junctions
			---@cast s_Junctions -nil
			return { Exit = s_Junctions[s_Found] }
		end
	end
	if s_First == nil then
		return nil
	end
	return { Exit = s_First.Junction }
end

---What it costs from the end of a path (the bot arrives there) to the target.
---@param p_Arrival NavRouteEnd
---@param p_Target NavTarget
---@return number
function NavRoutes:_FromArrival(p_Arrival, p_Target)
	local s_Mesh = m_NavZones:GetMesh()
	---@cast s_Mesh -nil
	local s_Point = p_Arrival.Junction.Point
	local s_Found, s_Distance = _TargetIn(p_Target, s_Mesh.Part[s_Point], s_Mesh.Points[s_Point].Position)
	if s_Found ~= nil then
		return s_Distance
	end
	local s_Cost = self:_Search(self:_Departures(s_Point, MESH_CROSSING, p_Arrival), p_Target)
	return s_Cost
end

---On a navigation path: which way leads to the objective. 'Next' (towards the last waypoint), 'Previous' or nil if
---the path isn't a navigation path or the objective has no target on the mesh.
---@param p_Waypoint Waypoint
---@param p_Objective string
---@return string|nil
function NavRoutes:Direction(p_Waypoint, p_Objective)
	local s_Path = self:GetPath(p_Waypoint and p_Waypoint.PathIndex)
	local s_Target = self:Target(p_Objective)
	if s_Path == nil or s_Target == nil then
		return nil
	end
	local s_Count = #(m_NodeCollection:Get(nil, s_Path.PathIndex) or {})
	local s_Share = s_Count > 1 and (p_Waypoint.PointIndex - 1) / (s_Count - 1) or 0.0
	local s_Forward = (1.0 - s_Share) * s_Path.Length + self:_FromArrival(s_Path.Finish, s_Target)
	local s_Back = s_Share * s_Path.Length + self:_FromArrival(s_Path.Start, s_Target)
	if s_Forward == math.huge and s_Back == math.huge then
		return nil
	end
	return s_Forward <= s_Back and 'Next' or 'Previous'
end

---The end the bot walks towards on a navigation path.
---@param p_PathIndex integer
---@param p_Inverted boolean walking towards the first waypoint
---@return NavRouteEnd|nil
function NavRoutes:Heading(p_PathIndex, p_Inverted)
	local s_Path = self:GetPath(p_PathIndex)
	if s_Path == nil then
		return nil
	end
	return p_Inverted and s_Path.Start or s_Path.Finish
end

---A bot didn't get to the exit over the mesh: all bots take it less from now on.
---@param p_Junction NavZoneJunction
function NavRoutes:BlockExit(p_Junction)
	self._Penalty[p_Junction] = (self._Penalty[p_Junction] or 0.0) + EXIT_PENALTY
end

if g_NavRoutes == nil then
	---@type NavRoutes
	g_NavRoutes = NavRoutes()
end

return g_NavRoutes
