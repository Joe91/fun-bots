---@class NavRoutes
---@overload fun():NavRoutes
NavRoutes = class('NavRoutes')

-- Routes from zone to zone. The navigation paths (made by the debug-server, census/navpaths.py) each lead from one zone
-- to another: their first waypoint has "Nav" = { From = zone at the first waypoint, To = zone at the last one, Length }.
-- Inside the zones the bots walk the networks (NavZones.lua, Bot/BotZoneMovement.lua). So a route is: out of the zone
-- over the junction of a navigation path, along it, into the next zone at its other end, across that zone to the next
-- navigation path, and so on until the zone of the objective.
--
-- The graph has the ends of the navigation paths as its nodes: an end is where a path leaves a zone (its junction with
-- the network of that zone). From an end a bot walks the path to its other end, and from there across the zone to any
-- end in the same part of that network.

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type NavZones
local m_NavZones = require('NavZones')
---@type Logger
local m_Logger = Logger('NavRoutes', Debug.Server.PATH)

-- Metres added for each zone a route crosses (the walk on its network, waiting bots, fights).
local ZONE_CROSSING = 20.0
-- An end of a navigation path is its junction with the network among this many waypoints from the end.
local END_SEARCH = 15
-- Metres added to an exit a bot didn't get to over the network (for all bots, until the level ends).
local EXIT_PENALTY = 100.0

---@class NavRouteEnd
---@field Path NavPath
---@field Zone NavZone
---@field Junction NavZoneJunction
---@field AtStart boolean the end at the first waypoint
---@field Other NavRouteEnd|nil the end at the other side of the path

---@class NavPath
---@field PathIndex integer
---@field Length number
---@field Start NavRouteEnd
---@field Finish NavRouteEnd

function NavRoutes:__init()
	self:Clear()
end

function NavRoutes:Clear()
	---@type table<integer, NavPath>
	self._Paths = {}
	---zone name -> the ends of navigation paths in it
	---@type table<string, NavRouteEnd[]>
	self._Ends = {}
	self._Count = 0
	self._Version = -1
	---junction -> metres added (BlockExit)
	---@type table<NavZoneJunction, number>
	self._Penalty = {}
	---objective -> zone of the graph it is reached from (false: none), see ZoneFor
	self._TargetZones = {}
end

---Builds the graph anew when the networks or the waypoints changed (NavZones:GetVersion).
function NavRoutes:_Ensure()
	local s_Version = m_NavZones:GetVersion()
	if s_Version == self._Version then
		return
	end
	self:Clear()
	self._Version = s_Version

	local s_Missing = 0
	for l_PathIndex, l_Waypoints in pairs(m_NodeCollection:GetPaths() or {}) do
		local s_First = l_Waypoints[1]
		local s_Nav = s_First and s_First.Data and s_First.Data.Nav
		if type(s_Nav) == 'table' and #l_Waypoints >= 2 then
			local s_From = m_NavZones:GetZone(tostring(s_Nav.From))
			local s_To = m_NavZones:GetZone(tostring(s_Nav.To))
			local s_StartJunction = s_From and self:_EndJunction(s_From, l_Waypoints, 1, 1)
			local s_FinishJunction = s_To and self:_EndJunction(s_To, l_Waypoints, #l_Waypoints, -1)
			if s_From ~= nil and s_To ~= nil and s_StartJunction ~= nil and s_FinishJunction ~= nil then
				local s_Start = { Zone = s_From, Junction = s_StartJunction, AtStart = true }
				local s_Finish = { Zone = s_To, Junction = s_FinishJunction, AtStart = false, Other = s_Start }
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
				for _, l_End in ipairs({ s_Path.Start, s_Path.Finish }) do
					local s_Ends = self._Ends[l_End.Zone.Name] or {}
					s_Ends[#s_Ends + 1] = l_End
					self._Ends[l_End.Zone.Name] = s_Ends
				end
			else
				s_Missing = s_Missing + 1
			end
		end
	end
	if self._Count > 0 or s_Missing > 0 then
		m_Logger:Write(self._Count .. ' navigation paths, ' .. s_Missing .. ' without junctions at both ends')
	end
end

---The junction of the zone closest to an end of the path.
---@param p_Zone NavZone
---@param p_Waypoints Waypoint[]
---@param p_From integer
---@param p_Step integer
---@return NavZoneJunction|nil
function NavRoutes:_EndJunction(p_Zone, p_Waypoints, p_From, p_Step)
	for l_Offset = 0, END_SEARCH - 1 do
		local s_Waypoint = p_Waypoints[p_From + l_Offset * p_Step]
		if s_Waypoint == nil then
			return nil
		end
		local s_Junction = m_NavZones:GetJunctionIn(p_Zone, s_Waypoint)
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

---The zone of the graph a bot heads for with this objective: the zone of that name, else (a vehicle, a beacon, an
---MCOM to arm) the zone whose network has a junction with a path of the objective. There the bot leaves the network
---for that path (BotZoneMovement). nil if there is none.
---@param p_Objective string|nil
---@return string|nil
function NavRoutes:ZoneFor(p_Objective)
	self:_Ensure()
	if p_Objective == nil or p_Objective == '' then
		return nil
	end
	if self._Ends[p_Objective] ~= nil then
		return p_Objective
	end
	local s_Known = self._TargetZones[p_Objective]
	if s_Known == nil then
		s_Known = false
		local s_BestCount = 0
		for l_Name, l_Zone in pairs(m_NavZones:GetZones()) do
			if self._Ends[l_Name] ~= nil then
				local s_Count = 0
				for l_Index = 1, #l_Zone.Junctions do
					local s_Waypoint = l_Zone.Junctions[l_Index].Waypoint
					local s_First = s_Waypoint and m_NodeCollection:GetFirst(s_Waypoint.PathIndex)
					local s_Data = type(s_First) == 'table' and s_First.Data or nil
					if s_Data ~= nil and s_Data.Nav == nil and table.has(s_Data.Objectives or {}, p_Objective) then
						s_Count = s_Count + 1
					end
				end
				-- Zones overlap: "mcom 1 interact" belongs to "mcom 1".
				if s_Count > 0 and p_Objective:sub(1, #l_Name + 1) == l_Name .. ' ' then
					s_Count = s_Count + 1000
				end
				if s_Count > s_BestCount then
					s_BestCount = s_Count
					s_Known = l_Name
				end
			end
		end
		self._TargetZones[p_Objective] = s_Known
	end
	return s_Known or nil
end

---Whether bots get to the objective over the navigation paths (ZoneFor).
---@param p_Objective string|nil
---@return boolean
function NavRoutes:Knows(p_Objective)
	return self:ZoneFor(p_Objective) ~= nil
end

---@param p_Zone NavZone
---@param p_Point integer
---@return Vec3
local function _PointPosition(p_Zone, p_Point)
	return p_Zone.Points[p_Point].Position
end

---Dijkstra over the ends. p_Departures: ends the bot can leave over, with what it costs to get there. Returns the
---cost to the zone of the objective and the first end of that route.
---@param p_Departures { End: NavRouteEnd, Cost: number }[]
---@param p_Target string
---@return number, NavRouteEnd|nil
function NavRoutes:_Search(p_Departures, p_Target)
	local s_Cost = {}
	local s_First = {}
	local s_Done = {}
	local s_Open = {}
	for l_Index = 1, #p_Departures do
		local l_Departure = p_Departures[l_Index]
		if s_Cost[l_Departure.End] == nil or l_Departure.Cost < s_Cost[l_Departure.End] then
			s_Cost[l_Departure.End] = l_Departure.Cost
			s_First[l_Departure.End] = l_Departure.End
			s_Open[#s_Open + 1] = l_Departure.End
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
			---@cast s_Arrival -nil
			local s_Total = s_Cost[s_End] + s_End.Path.Length
			if s_Arrival.Zone.Name == p_Target then
				if s_Total < s_Best then
					s_Best = s_Total
					s_BestFirst = s_First[s_End]
				end
			else
				local s_Part = s_Arrival.Zone.Part[s_Arrival.Junction.Point]
				local s_From = _PointPosition(s_Arrival.Zone, s_Arrival.Junction.Point)
				local s_Ends = self._Ends[s_Arrival.Zone.Name] or {}
				for l_Index = 1, #s_Ends do
					local l_Next = s_Ends[l_Index]
					if l_Next ~= s_Arrival and not s_Done[l_Next]
						and s_Arrival.Zone.Part[l_Next.Junction.Point] == s_Part then
						local s_Next = s_Total + ZONE_CROSSING + (self._Penalty[l_Next.Junction] or 0.0)
							+ s_From:Distance(_PointPosition(l_Next.Zone, l_Next.Junction.Point))
						if s_Cost[l_Next] == nil or s_Next < s_Cost[l_Next] then
							if s_Cost[l_Next] == nil then
								s_Open[#s_Open + 1] = l_Next
							end
							s_Cost[l_Next] = s_Next
							s_First[l_Next] = s_First[s_End]
						end
					end
				end
			end
		end
	end
	return s_Best, s_BestFirst
end

---The ends of navigation paths in the zone the bot can walk to from the point (same part of the network).
---@param p_Zone NavZone
---@param p_Point integer
---@param p_Start number cost so far
---@param p_Except NavRouteEnd|nil
---@return { End: NavRouteEnd, Cost: number }[]
function NavRoutes:_Departures(p_Zone, p_Point, p_Start, p_Except)
	local s_Result = {}
	local s_Part = p_Zone.Part[p_Point]
	local s_From = _PointPosition(p_Zone, p_Point)
	local s_Ends = self._Ends[p_Zone.Name] or {}
	for l_Index = 1, #s_Ends do
		local l_End = s_Ends[l_Index]
		if l_End ~= p_Except and l_End.Zone == p_Zone and p_Zone.Part[l_End.Junction.Point] == s_Part then
			s_Result[#s_Result + 1] = {
				End = l_End,
				Cost = p_Start + (self._Penalty[l_End.Junction] or 0.0)
					+ s_From:Distance(_PointPosition(p_Zone, l_End.Junction.Point)),
			}
		end
	end
	return s_Result
end

---The junction to leave the zone over, towards the objective. nil if the objective isn't a zone of the graph or no
---route leads there.
---@param p_Zone NavZone
---@param p_Point integer where the bot is in the zone
---@param p_Objective string
---@return NavZoneJunction|nil
function NavRoutes:NextExit(p_Zone, p_Point, p_Objective)
	local s_Target = self:ZoneFor(p_Objective)
	if s_Target == nil or p_Zone.Name == s_Target or p_Zone.Points[p_Point] == nil then
		return nil
	end
	local _, s_First = self:_Search(self:_Departures(p_Zone, p_Point, 0.0, nil), s_Target)
	return s_First and s_First.Junction or nil
end

---What it costs from the end of a path (the bot arrives there) to the zone of the objective.
---@param p_Arrival NavRouteEnd
---@param p_Objective string
---@return number
function NavRoutes:_FromArrival(p_Arrival, p_Objective)
	if p_Arrival.Zone.Name == p_Objective then
		return 0.0
	end
	local s_Cost = self:_Search(self:_Departures(p_Arrival.Zone, p_Arrival.Junction.Point, ZONE_CROSSING, p_Arrival),
		p_Objective)
	return s_Cost
end

---On a navigation path: which way leads to the objective. 'Next' (towards the last waypoint), 'Previous' or nil if
---the path isn't a navigation path or the objective not in the graph.
---@param p_Waypoint Waypoint
---@param p_Objective string
---@return string|nil
function NavRoutes:Direction(p_Waypoint, p_Objective)
	local s_Path = self:GetPath(p_Waypoint and p_Waypoint.PathIndex)
	local s_Target = self:ZoneFor(p_Objective)
	if s_Path == nil or s_Target == nil then
		return nil
	end
	p_Objective = s_Target
	local s_Count = #(m_NodeCollection:Get(nil, s_Path.PathIndex) or {})
	local s_Share = s_Count > 1 and (p_Waypoint.PointIndex - 1) / (s_Count - 1) or 0.0
	local s_Forward = (1.0 - s_Share) * s_Path.Length + self:_FromArrival(s_Path.Finish, p_Objective)
	local s_Back = s_Share * s_Path.Length + self:_FromArrival(s_Path.Start, p_Objective)
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

---A bot didn't get to the exit over the network: all bots take it less from now on.
---@param p_Junction NavZoneJunction
function NavRoutes:BlockExit(p_Junction)
	self._Penalty[p_Junction] = (self._Penalty[p_Junction] or 0.0) + EXIT_PENALTY
end

---For the debug-bridge: the graph.
---@return table[]
function NavRoutes:ToJson()
	self:_Ensure()
	local s_Result = {}
	for l_PathIndex, l_Path in pairs(self._Paths) do
		s_Result[#s_Result + 1] = {
			path = l_PathIndex,
			from = l_Path.Start.Zone.Name,
			to = l_Path.Finish.Zone.Name,
			length = l_Path.Length,
		}
	end
	return s_Result
end

if g_NavRoutes == nil then
	---@type NavRoutes
	g_NavRoutes = NavRoutes()
end

return g_NavRoutes
