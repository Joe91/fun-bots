-- Free movement on the mesh (NavZones.lua). A bot that reaches a junction of the mesh leaves the waypoints and walks the
-- mesh: in the zone of its objective from point to point, waiting a moment at each (longer and in cover when it
-- defends); else over the mesh to that zone, or to the junction of the next navigation path of its route (NavRoutes).
-- When its objective changes it decides anew where to go.

---@type NavZones
local m_NavZones = require('NavZones')
---@type NavRoutes
local m_NavRoutes = require('NavRoutes')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type DebugBridge
local m_DebugBridge = require('Debug/DebugBridge')
---@type Logger
local m_Logger = Logger('BotZoneMovement', Debug.Server.BOT)

local ZONE_REACH_POINT = 1.5     -- Horizontal metres to a point of the network (in the open, 5 m apart) that count as
local ZONE_REACH_CORNER = 1.0    -- reached, and to a corner of the way between two points (around a wall).
local ZONE_REACH_SPRINT = 1.3    -- Running, a bot reaches positions this many times as far away.
local ZONE_NARROW = 1.5          -- To a point with less clearance (a ramp, a walkway) the bot walks: running it
                                 -- overshoots the turn there and falls down.
local ZONE_STEEP = 0.8           -- A target this much higher or lower (stairs, a ramp) within ZONE_STEEP_RANGE: the bot
local ZONE_STEEP_RANGE = 6.0     -- walks as well, running it falls off the side of narrow stairs and tries again.
local ZONE_TURN_DISTANCE = 3.0   -- Closer than this to the target and turned away more than ZONE_TURN_ANGLE, the bot
local ZONE_TURN_ANGLE = 1.0      -- slows down until it faces the target: else it runs circles around it.
local ZONE_REACH_HEIGHT = 1.5    -- Same as Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT.
local ZONE_MIN_PROGRESS = 0.3    -- Metres closer to the target that count as progress.
local ZONE_JUMP_TIME = 1.5       -- Seconds without progress before a jump.
local ZONE_SIDESTEP_TIME = 1.0   -- Seconds without progress, more than ZONE_SIDESTEP_OFFSET metres beside the way to
local ZONE_SIDESTEP_OFFSET = 0.3 -- the target: the bot steps back onto it sideways.
local ZONE_JUMP_RANGE = 1.5      -- Horizontal metres before a corner where the way was recorded with a jump: jump.
local ZONE_STUCK_TIME = 4.0      -- Seconds without progress before the bot gives up this way.
local ZONE_MAX_FAILS = 3         -- Ways given up before the bot leaves the zone.
local ZONE_MAX_GIVE_UPS = 3      -- Zones left like that in a row (no goal, no exit reached): the bot is stuck in a
                                 -- place it doesn't get out of, it respawns (as on the waypoints, Bot:_ObstacleHandling).
local ZONE_WAIT_ATTACK = { 1.0, 3.0 } -- Seconds at each point while capturing.
local ZONE_WAIT_DEFEND = { 5.0, 12.0 } -- Seconds at each point while defending.
local ZONE_SUBOBJECTIVE_CYCLE = 1.0 -- Seconds between two checks whether the bot shall arm / disarm the MCOM.
local ZONE_WAIT_VEHICLE = { 3.0, 8.0 } -- Seconds a vehicle stands at each point.
local ZONE_GOAL_TRIES = 4        -- Random goals tried in a zone...
local ZONE_DETOUR_FACTOR = 2.0   -- ...one whose way is at most this many times the straight distance...
local ZONE_DETOUR_MIN = 40.0     -- ...or this many metres. None of them: the bot waits where it is.
local ZONE_ARM_DISTANCE = 1.3    -- Horizontal metres to the MCOM the soldier walks up to before it interacts.
local ZONE_ARM_APPROACH = 4.0    -- Seconds at most for that, then it interacts from where it is.
local ZONE_ARM_TIME = 8.0        -- Seconds of interacting (arming takes about 6): then the bot gives up for now.
local ZONE_ARM_PITCH = -0.6      -- The MCOM stands on the ground.
local ZONE_VEHICLE_REACH = 10.0  -- Registry.VEHICLES.MIN_DISTANCE_VEHICLE_ENTER: the bot gets in from this close.
local ZONE_VEHICLE_NEAR = 5.5    -- Horizontal metres to the middle of the vehicle (a tank is about 8 m long): on the way
local ZONE_VEHICLE_FLOOR = 3.0   -- to the point next to it the bot gets in from here. The point can be under the hull.
local ZONE_OFF_POINT = 3.0       -- Horizontal metres from its point: a new route first leads back to it.
local ZONE_SMOOTH_ROOM = 2.5     -- Smoothing: metres before a point the bot turns towards the next one (at most).
local ZONE_REJOIN_RANGE = 30.0   -- No route from the point the bot is at (a piece of the mesh cut off by given-up
                                 -- connections): it goes on from a point of another part this close...
local ZONE_REJOIN_FAR = 120.0    -- Nothing that close: up to this far over open ground (a spawn on an island of the
local ZONE_REJOIN_SLOPE = 0.25   -- mesh, no path to the rest), not steeper than this (height per metre) plus
local ZONE_REJOIN_STEP = 3.0     -- this many metres.
local ZONE_REJOIN_SPEED = 3.0    -- Metres per second the bot is given for the way to the point it rejoins at.
local ZONE_REJOIN_MIN_PART = 10  -- ...with this many points at least (NavZones MIN_PART).
local ZONE_RECENT_EXIT_TIME = 60.0 -- Seconds a bot doesn't leave the mesh again at a junction it left it at.
local ZONE_AVOID_ENTRY_TIME = 30.0 -- Seconds a bot that came onto the mesh from a path takes no exit back to that path.
local ZONE_REENTER_TIME = 5.0    -- Seconds a bot that left the mesh at a junction doesn't go onto it there again.
local ZONE_FALL = 1.5            -- Metres below the way to the target (and ZONE_FALL_BELOW below both ends of it): the
local ZONE_FALL_BELOW = 1.0      -- bot fell off, the way is given up.
local ZONE_FALL_PAUSE = 3.0      -- Seconds after a fall before the next one counts (landing, getting up).
local ZONE_RESNAP = 8.0          -- Metres from its point a bot may be when it decides anew: else the closest point...
local ZONE_RESNAP_AFTER = 5.0    -- ...not in the first seconds on the mesh (on the way from the junction).
local BORDER_WAIT = 6.0          -- Rush: seconds a bot waits at the border of the combat area before it tries again.
local BORDER_GIVE_UP = 10.0      -- Not back inside this many seconds after it left: it was outside already (the area got
                                 -- smaller when a stage fell), it goes on to its objective.
local BORDER_BACK = 15.0         -- It walks back to a point it passed at least this far behind it (the point it reached
                                 -- last can be outside already)...
local TRAIL_POINTS = 6           -- ...of the last points it reached.
local ZONE_ENTER_RANGE = 6.0     -- Horizontal metres (and ZONE_ENTER_HEIGHT up or down) to the waypoint of a junction
local ZONE_ENTER_HEIGHT = 3.0    -- the bot goes onto the mesh from.

---@class BotZoneState
---@field Zone NavZone
---@field Objective string the objective the bot came for
---@field Point integer the point the bot was at last
---@field Goal integer|nil
---@field Targets { Position: Vec3, Flags: integer, Point: integer|nil }[]
---@field Step integer
---@field Wait number seconds left at the goal
---@field Waiting boolean
---@field Progress number
---@field Stuck number
---@field JumpTimer number
---@field Fails integer
---@field ExitFails integer exits given up (navigation paths): another one is taken
---@field Exit NavZoneJunction|nil
---@field SubObjective string|nil "mcom N interact" of an MCOM-zone
---@field SubTimer number
---@field Vehicle boolean on the vehicle-network, as driver of a land vehicle
---@field Reverse number seconds the vehicle still reverses
---@field Reverses integer reverses on the way to the current target
---@field Avoid integer|nil a dead end the bot got stuck at: not the start of the next route
---@field Action table|nil at the goal: get into the vehicle, arm or disarm the MCOM (GameDirector:GetActionTarget)
---@field ActionTime number seconds of the action so far
---@field Entered number time the bot came onto the mesh (or onto another part of it, _ZoneRejoin)
---@field FallTime number time of the last fall off a way
---@field Trail integer[]|nil the last points it reached (Bot:_ZoneTrail)

---Called when the bot reached a waypoint. Where the routes guide it (NavRoutes:Step, a level with a mesh): at a node of
---the paths it goes onto the mesh, switches over a link or turns to the way on. Else at a junction it walks the mesh
---from now on, unless it walks the way to its objective (a vehicle-path with its name).
---@param p_Point Waypoint (or an offset-point with the fields of its waypoint)
---@return boolean true if the bot is on the mesh now or on another path (the caller doesn't go on)
function Bot:_CheckForZoneEntry(p_Point)
	if self.m_Zone ~= nil then
		return false
	end
	local s_Waypoint = p_Point.Original or p_Point
	-- Only if the bot is there: the obstacle-handling counts a waypoint as reached when it skips it, from far away.
	local s_Soldier = self.m_Player.soldier
	if s_Soldier == nil then
		return false
	end
	local s_Here = s_Soldier.worldTransform.trans
	local s_DeltaX = s_Waypoint.Position.x - s_Here.x
	local s_DeltaZ = s_Waypoint.Position.z - s_Here.z
	local s_There = s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ <= ZONE_ENTER_RANGE * ZONE_ENTER_RANGE
		and math.abs(s_Waypoint.Position.y - s_Here.y) <= ZONE_ENTER_HEIGHT
	-- Just left the mesh here: on along the path (else it goes on and off the mesh at the same junction).
	local s_Left = self.m_LeftZoneAt
	local s_NoEnter = s_Left ~= nil and SharedUtils:GetTime() - s_Left.Time < ZONE_REENTER_TIME and s_Left.Point or nil

	if m_NavRoutes:Guides(s_Waypoint.PathIndex, self._Objective) then
		-- Not onto the mesh from far away (a skipped waypoint): on along the paths then.
		if not s_There then
			local s_Junction = m_NavZones:GetJunction(s_Waypoint)
			s_NoEnter = s_Junction ~= nil and s_Junction.Junction.Point or s_NoEnter
		end
		local s_Step = m_NavRoutes:Step(s_Waypoint, self._Objective, self.m_RouteSeed, self._NavCame, s_NoEnter)
		if s_Step == nil then
			return false
		end
		self._NavCame = s_Step.Node
		if s_Step.Enter ~= nil then
			self:_EnterZone(m_NavZones:ZoneAtPoint(s_Step.Enter.Point, self._Objective) or m_NavZones:GetMesh(),
				s_Step.Enter.Point, false, s_Step.Enter)
			return self.m_Zone ~= nil
		end
		if s_Step.Switch ~= nil then
			self._PathIndex = s_Step.Switch.PathIndex
			self._CurrentWayPoint = s_Step.Switch.PointIndex
			self._TargetPoint = s_Step.Switch
			if s_Step.Direction ~= nil then
				self._InvertPathDirection = s_Step.Direction == 'Previous'
			end
			self._NextTargetPoint = m_NodeCollection:Get(self:_GetWayIndex(self._InvertPathDirection and -1 or 1),
				self._PathIndex)
			return true
		end
		if s_Step.Direction ~= nil then
			self._InvertPathDirection = s_Step.Direction == 'Previous'
		end
		return false
	end

	local s_Entry = m_NavZones:GetJunction(s_Waypoint)
	if s_Entry == nil or not s_There or s_NoEnter == s_Entry.Junction.Point then
		return false
	end
	if self._Objective ~= '' and m_NavZones:GetZone(self._Objective) == nil then
		-- The way to a vehicle, a beacon: the bot walks it to its end.
		local s_First = m_NodeCollection:GetFirst(s_Waypoint.PathIndex)
		local s_Objectives = type(s_First) == 'table' and s_First.Data and s_First.Data.Objectives or {}
		if table.has(s_Objectives, self._Objective) or not m_NavRoutes:Knows(self._Objective) then
			return false
		end
	end

	self:_EnterZone(m_NavZones:ZoneAtPoint(s_Entry.Junction.Point, self._Objective) or s_Entry.Zone,
		s_Entry.Junction.Point, false, s_Entry.Junction)
	return self.m_Zone ~= nil
end

-- A spawn-point of the game this far from a point of the mesh: the bot walks straight to it and starts on the mesh.
local ZONE_SPAWN_RANGE = 30.0

---After a spawn at a spawn-point of the game (BotSpawner, SpawnMethod.Spawn): on the mesh there (a base, a capture
---point) the bot starts on it, and goes where its objective is.
---Only a point the bot can walk to straight (NavZones:ZoneAtVisible). Just spawned and none in sight (the spawn is in
---a corner the mesh doesn't reach): onto the closest point at once, nobody sees it there yet.
---@param p_Position Vec3
---@param p_Spawned boolean|nil
---@return boolean true if the bot is in a zone now
function Bot:TryEnterZoneAt(p_Position, p_Spawned)
	local s_Zone, s_Point, s_Closest = m_NavZones:ZoneAtVisible(p_Position, ZONE_SPAWN_RANGE, self._Objective)
	if s_Zone == nil or s_Point == nil then
		if p_Spawned and s_Closest ~= nil and self.m_Player.soldier ~= nil then
			m_Logger:Write(self.m_Player.name .. ' spawned out of sight of the mesh, put onto point ' .. s_Closest)
			return self:TeleportToMesh(ZONE_SPAWN_RANGE)
		end
		return false
	end
	self:_EnterZone(s_Zone, s_Point)
	return true
end

---A bot that doesn't get along off the mesh (GameDirector): onto the closest point of the mesh up to p_Range away, it
---goes on from there.
---@param p_Range number
---@return boolean true if the bot is on the mesh now
function Bot:TeleportToMesh(p_Range)
	local s_Soldier = self.m_Player.soldier
	local s_Mesh = m_NavZones:GetMesh()
	if s_Soldier == nil or s_Mesh == nil or self.m_Zone ~= nil then
		return false
	end
	local s_Point, s_Distance = m_NavZones:Closest(s_Mesh, s_Soldier.worldTransform.trans)
	if s_Point == nil or s_Distance > p_Range then
		return false
	end
	local s_Transform = s_Soldier.worldTransform:Clone()
	s_Transform.trans = s_Mesh.Points[s_Point].Position:Clone()
	s_Soldier:SetTransform(s_Transform)
	self:_EnterZone(m_NavZones:ZoneAtPoint(s_Point, self._Objective) or s_Mesh, s_Point)
	return self.m_Zone ~= nil
end

---Called when the driver of a land vehicle reached a waypoint of its vehicle-path. At a junction of the vehicle-network
---of the capture point of its objective, it drives the network from now on (VehicleMovement).
---@param p_Point Waypoint
---@return boolean true if the vehicle is in the zone now
function Bot:_CheckForVehicleZoneEntry(p_Point)
	if not Registry.BOT.USE_VEHICLE_ZONE_NETWORKS or self._Objective == ''
		or self.m_Zone ~= nil or self.m_ActiveVehicle == nil or self.m_ActiveVehicle.Terrain ~= VehicleTerrains.Land then
		return false
	end

	local s_Zone = m_NavZones:GetZone(self._Objective)
	if s_Zone == nil or s_Zone.Kind ~= 'capturepoint' or s_Zone.Vehicle == nil then
		return false
	end
	local s_Junction = m_NavZones:GetJunctionIn(s_Zone.Vehicle, p_Point)
	if s_Junction == nil or s_Zone.Vehicle.Points[s_Junction.Point] == nil
		or s_Zone.Vehicle.Points[s_Junction.Point].Position:Distance(s_Zone.Center) > s_Zone.Radius then
		return false
	end

	-- The zone on the vehicle-mesh (NavZones:_Build).
	self:_EnterZone(s_Zone.Vehicle, s_Junction.Point, true, s_Junction)
	return true
end

---@param p_Zone NavZone
---@param p_Point integer
---@param p_Vehicle? boolean the vehicle-network, as driver
---@param p_Junction? NavZoneJunction entered here: first the way from its waypoint to the network
function Bot:_EnterZone(p_Zone, p_Point, p_Vehicle, p_Junction)
	---@type BotZoneState
	self.m_Zone = {
		Zone = p_Zone,
		-- The objective the bot decided for (_ZoneDecide); vehicles: the zone, they leave it for another objective.
		Objective = p_Vehicle and p_Zone.Name or nil,
		Point = p_Point,
		Goal = nil,
		Targets = {},
		Step = 1,
		Wait = 0.0,
		Waiting = false,
		Progress = math.huge,
		Stuck = 0.0,
		JumpTimer = 0.0,
		Fails = 0,
		ExitFails = 0,
		Exit = nil,
		-- The MCOM is armed and disarmed at the action-node of the path "mcom N interact" (a junction of the mesh).
		SubObjective = nil,
		SubTimer = 0.0,
		Vehicle = p_Vehicle == true,
		Reverse = 0.0,
		Reverses = 0,
		Action = nil,
		ActionTime = 0.0,
		-- Just entered: on the way from the junction to its point, which may be farther than ZONE_RESNAP.
		Entered = SharedUtils:GetTime(),
		-- The junction it came onto the mesh at (from a path).
		EntryJunction = p_Junction,
		FallTime = 0.0,
	}
	self:_StopObstacleSequence()
	if p_Vehicle then
		self:_ZoneNewGoal()
	else
		self:_ZoneDecide()
		if self.m_Zone == nil then
			return
		end
	end

	-- From the waypoint of the junction to its point: the corners backwards, then the point itself.
	if p_Junction ~= nil then
		local s_Lead = {}
		for l_Index = #p_Junction.Corners, 1, -1 do
			s_Lead[#s_Lead + 1] = { Position = p_Junction.Corners[l_Index], Flags = 0 }
		end
		local s_Point = p_Zone.Points[p_Point]
		s_Lead[#s_Lead + 1] = { Position = s_Point.Position, Flags = s_Point.Flags, Point = p_Point }
		local s_State = self.m_Zone
		---@cast s_State -nil
		for l_Index = #s_Lead, 1, -1 do
			table.insert(s_State.Targets, 1, s_Lead[l_Index])
		end
	end
	m_Logger:Write(self.m_Player.name .. ' on the mesh at ' .. p_Zone.Name)
end

---Whether the bot gets to the objective: on the mesh a route leads there from its point (NavRoutes:Next: not from a
---ship to a boat at the shore), off the mesh the objective has a target on the mesh at all.
---@param p_Objective string
---@return boolean
function Bot:CanReach(p_Objective)
	local s_State = self.m_Zone
	if s_State == nil or s_State.Vehicle then
		return m_NavRoutes:Knows(p_Objective)
	end
	-- As _ZoneDecide: from its point, else from a point of another part close by (_ZoneRejoin).
	return m_NavRoutes:Next(s_State.Point, p_Objective, self.m_RouteSeed, self.m_Player.teamId) ~= nil
		or self:_ZoneRejoinPoint(p_Objective) ~= nil
end

---Where to go for the objective: in its zone from point to point, over the mesh to its zone, out over the junction of
---the next navigation path of the route (NavRoutes), else the path that suits the objective best (_ZoneBestExit).
---Without objective the bot walks around in the zone it is in (on the mesh outside of zones it waits).
---@param p_Rejoined boolean|nil the point was just moved to another part of the mesh (_ZoneRejoin): no second time
function Bot:_ZoneDecide(p_Rejoined)
	local s_State = self.m_Zone
	---@cast s_State -nil
	self:_ZoneResnap()
	s_State.Objective = self._Objective
	s_State.Exit = nil
	s_State.SubObjective = nil
	s_State.Action = nil
	s_State.ActionTime = 0.0
	if self._Objective == '' then
		s_State.Zone = m_NavZones:ZoneAtPoint(s_State.Point, nil) or s_State.Zone
		self:_ZoneNewGoal()
		return
	end

	-- The routes are over the mesh of the soldiers, a vehicle leaves its network at the junction closest to the objective.
	-- Just came onto the mesh from a path: not back there at once (NavRoutes:Next).
	local s_Avoid = s_State.EntryJunction ~= nil and SharedUtils:GetTime() - s_State.Entered < ZONE_AVOID_ENTRY_TIME
		and self._NavCame or nil
	local s_Used = nil
	if self.m_RecentExits ~= nil then
		local s_Now = SharedUtils:GetTime()
		for l_Junction, l_Time in pairs(self.m_RecentExits) do
			if s_Now - l_Time > ZONE_RECENT_EXIT_TIME then
				self.m_RecentExits[l_Junction] = nil
			else
				s_Used = s_Used or {}
				s_Used[l_Junction] = true
			end
		end
	end
	local s_Next = not s_State.Vehicle
		and m_NavRoutes:Next(s_State.Point, self._Objective, self.m_RouteSeed, self.m_Player.teamId, s_Avoid, s_Used) or nil
	if s_Next ~= nil and s_Next.Action ~= nil and s_Next.Point ~= nil then
		-- Into the vehicle, arm the MCOM: to the point next to it, then do it there (_ZoneAction).
		s_State.Zone = s_Next.Zone or s_State.Zone
		s_State.Action = s_Next.Action
		self:_ZoneRouteTo(s_Next.Point)
		s_State.Wait = 0.0
		return
	end
	if s_Next ~= nil and s_Next.Zone ~= nil then
		s_State.Zone = s_Next.Zone
		-- The MCOM is armed and disarmed at the action-node of the path "mcom N interact" (a junction of the mesh).
		if s_Next.Zone.Kind == 'mcom' then
			s_State.SubObjective = g_GameDirector:_GetSubObjectiveFromObj(s_Next.Zone.Name)
		end
		if s_Next.Zone.InsideSet[s_State.Point] then
			self:_ZoneNewGoal()
		else
			self:_ZoneRouteTo(s_Next.Point)
			s_State.Wait = 0.0
		end
		return
	end
	if s_Next == nil and not s_State.Vehicle and not p_Rejoined and self:_ZoneRejoin() then
		self:_ZoneDecide(true)
		return
	end
	local s_Exit = s_Next ~= nil and s_Next.Exit or self:_ZoneBestExit(self._Objective)
	if s_Exit == nil then
		if self:_ZoneNoWay() then
			return
		end
		self:_LeaveZone(nil)
		return
	end
	self:_ZoneRouteToExit(s_Exit)
end

-- No way on from the mesh: a path this close is taken (as before the mesh), else the bot waits on the mesh.
local ZONE_LEAVE_RANGE = 30.0

---Neither the mesh nor a navigation path leads to the objective from here (the ship of the attackers, the boats are
---their way). Off the mesh onto a path close by, else the bot stays and drops the objective: the GameDirector gives it
---one it gets to (a boat next to it) as soon as there is one. Not onto a path far away: the bot would walk (swim) there
---straight.
---@return boolean true if the bot waits on the mesh
function Bot:_ZoneNoWay()
	local s_State = self.m_Zone
	local s_Soldier = self.m_Player.soldier
	if s_State == nil or s_State.Vehicle or s_Soldier == nil then
		return false
	end
	local s_Position = s_Soldier.worldTransform.trans
	local s_Path = g_GameDirector:FindClosestPath(s_Position, false, true, nil)
	if s_Path ~= nil and s_Path.Position:Distance(s_Position) <= ZONE_LEAVE_RANGE then
		return false
	end
	m_Logger:Write(self.m_Player.name .. ' no way to ' .. tostring(self._Objective) .. ', waits')
	self:SetObjective('')
	s_State.Objective = ''
	s_State.Zone = m_NavZones:ZoneAtPoint(s_State.Point, nil) or s_State.Zone
	self:_ZoneNewGoal()
	return true
end

---No route from the point of the bot: the closest point of another part of the mesh (ZONE_REJOIN_RANGE) from which one
---leads to the objective becomes its point. The bot walks straight there.
---@return boolean true if the bot has another point now
function Bot:_ZoneRejoin()
	local s_State = self.m_Zone
	---@cast s_State -nil
	local s_Mesh = m_NavZones:GetMesh()
	local l_Point = self:_ZoneRejoinPoint(self._Objective)
	if s_Mesh == nil or l_Point == nil then
		return false
	end
	m_Logger:Write(self.m_Player.name .. ' no route from point ' .. s_State.Point .. ', goes on from ' .. l_Point)
	-- On the way there (up to ZONE_REJOIN_FAR, a few metres per second): not snapped back meanwhile (_ZoneResnap).
	local s_From = s_State.Zone.Points[s_State.Point]
	local s_Way = s_From ~= nil and s_From.Position:Distance(s_Mesh.Points[l_Point].Position) or 0.0
	s_State.RejoinUntil = SharedUtils:GetTime() + s_Way / ZONE_REJOIN_SPEED
	s_State.Point = l_Point
	-- On the way there: not snapped back to the closest point (_ZoneResnap), that one has no route.
	s_State.Entered = SharedUtils:GetTime()
	s_State.Targets = { { Position = s_Mesh.Points[l_Point].Position, Flags = 0, Point = l_Point } }
	return true
end

---The closest point of another part of the mesh (ZONE_REJOIN_RANGE, at least ZONE_REJOIN_MIN_PART points) from which
---a route leads to the objective (_ZoneRejoin). nil if there is none.
---@param p_Objective string
---@return integer|nil
function Bot:_ZoneRejoinPoint(p_Objective)
	local s_State = self.m_Zone
	local s_Mesh = m_NavZones:GetMesh()
	local s_Current = s_State ~= nil and s_State.Zone.Points[s_State.Point] or nil
	if s_State == nil or s_Mesh == nil or s_Current == nil then
		return nil
	end
	local s_Part = s_Mesh.Part[s_State.Point]
	local s_From = s_Current.Position
	local s_Candidates = {}
	for l_Index = 1, #s_Mesh.Points do
		-- Not onto an island of the mesh (a point behind a wall the checks cut off).
		if s_Mesh.Part[l_Index] ~= s_Part and (s_Mesh.PartSize[s_Mesh.Part[l_Index]] or 0) >= ZONE_REJOIN_MIN_PART then
			local s_Distance = s_Mesh.Points[l_Index].Position:Distance(s_From)
			if s_Distance <= ZONE_REJOIN_RANGE then
				s_Candidates[#s_Candidates + 1] = { l_Index, s_Distance }
			end
		end
	end
	-- None close by (a spawn on a piece of the mesh the census didn't join to the rest, no path across): farther, over
	-- open ground (not down a cliff or a roof: at most ZONE_REJOIN_SLOPE metres up or down per metre, plus a step).
	-- Not to the shore from a ship or a carrier: those are farther, the boats are the way there.
	if #s_Candidates == 0 then
		for l_Index = 1, #s_Mesh.Points do
			if s_Mesh.Part[l_Index] ~= s_Part and (s_Mesh.PartSize[s_Mesh.Part[l_Index]] or 0) >= ZONE_REJOIN_MIN_PART then
				local s_Position = s_Mesh.Points[l_Index].Position
				local s_DeltaX = s_Position.x - s_From.x
				local s_DeltaZ = s_Position.z - s_From.z
				local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
				if s_Distance <= ZONE_REJOIN_FAR
					and math.abs(s_Position.y - s_From.y) <= ZONE_REJOIN_SLOPE * s_Distance + ZONE_REJOIN_STEP then
					s_Candidates[#s_Candidates + 1] = { l_Index, s_Distance }
				end
			end
		end
	end
	table.sort(s_Candidates, function(p_A, p_B) return p_A[2] < p_B[2] end)
	local s_Tried = {}
	for l_Index = 1, #s_Candidates do
		local l_Point = s_Candidates[l_Index][1]
		local l_Part = s_Mesh.Part[l_Point]
		if not s_Tried[l_Part] then
			s_Tried[l_Part] = true
			if m_NavRoutes:Next(l_Point, p_Objective, self.m_RouteSeed, self.m_Player.teamId) ~= nil then
				return l_Point
			end
		end
	end
	return nil
end

---The point of the bot is where it last reached one. It may be far away by now (it fought, pushed forward while
---shooting, walked up to an MCOM): a route from there leads somewhere else, back to where it came from. Then the point
---closest to where it stands.
function Bot:_ZoneResnap()
	local s_State = self.m_Zone
	local s_Soldier = self.m_Player.soldier
	if s_State == nil or s_Soldier == nil or s_State.Vehicle or SharedUtils:GetTime() - s_State.Entered < ZONE_RESNAP_AFTER
		or (s_State.RejoinUntil ~= nil and SharedUtils:GetTime() < s_State.RejoinUntil) then
		return
	end
	local s_Current = s_State.Zone.Points[s_State.Point]
	local s_Position = s_Soldier.worldTransform.trans
	if s_Current ~= nil and s_Current.Position:Distance(s_Position) <= ZONE_RESNAP then
		return
	end
	local s_Point = m_NavZones:Closest(s_State.Zone, s_Position, s_State.Avoid)
	if s_Point ~= nil then
		s_State.Point = s_Point
	end
end

---Whether the bot holds the zone: waits longer at each point, at the ones with cover crouched. Defending its capture
---point, or in rush a defender at its MCOM (the GameDirector sends the defenders to the MCOMs to attack: they aren't of
---their team).
---@param p_State BotZoneState
---@return boolean
function Bot:_ZoneDefends(p_State)
	return self._ObjectiveMode == BotObjectiveModes.Defend
		or (Globals.IsRush and self.m_Player.teamId == TeamId.Team2 and p_State.Zone.Kind == 'mcom' and not p_State.Vehicle)
end

---Walks to the next point of the zone (not the one the bot is at).
function Bot:_ZoneNewGoal()
	local s_State = self.m_Zone
	---@cast s_State -nil
	self:_ZoneResnap()
	-- On the mesh outside of the zones there is nothing to walk around in.
	if s_State.Zone.Kind == 'mesh' then
		self:_ZoneRouteTo(nil)
		return
	end
	local s_Defend = self:_ZoneDefends(s_State)
	-- Only goals the mesh leads to directly: two points of a zone can be connected only over a long way round
	-- (another floor, through the area behind), the bot would walk far away from its objective.
	local s_Goal = nil
	local s_Route = nil
	local s_From = s_State.Zone.Points[s_State.Point]
	for _ = 1, ZONE_GOAL_TRIES do
		local l_Goal = m_NavZones:RandomPoint(s_State.Zone, s_State.Point, s_Defend and not s_State.Vehicle)
		if l_Goal == nil or s_From == nil then
			break
		end
		local l_Route, l_Cost = m_NavZones:Route(s_State.Zone, s_State.Point, l_Goal, self.m_RouteSeed)
		local s_Straight = s_From.Position:Distance(s_State.Zone.Points[l_Goal].Position)
		if l_Route ~= nil and l_Cost <= math.max(ZONE_DETOUR_MIN, ZONE_DETOUR_FACTOR * s_Straight) then
			s_Goal = l_Goal
			s_Route = l_Route
			break
		end
	end
	self:_ZoneRouteTo(s_Goal, s_Route)
	local s_Wait = s_State.Vehicle and ZONE_WAIT_VEHICLE or (s_Defend and ZONE_WAIT_DEFEND or ZONE_WAIT_ATTACK)
	s_State.Wait = MathUtils:GetRandom(s_Wait[1], s_Wait[2])
end

---@param p_Goal integer|nil
---@param p_Route integer[]|nil the route there, if known
function Bot:_ZoneRouteTo(p_Goal, p_Route)
	local s_State = self.m_Zone
	---@cast s_State -nil
	s_State.Goal = p_Goal
	s_State.Targets = {}
	s_State.Step = 1
	s_State.Waiting = false
	s_State.Progress = math.huge
	s_State.Stuck = 0.0
	if p_Goal ~= nil then
		local s_Route = p_Route or m_NavZones:Route(s_State.Zone, s_State.Point, p_Goal, self.m_RouteSeed)
		if s_Route ~= nil then
			s_State.Targets = m_NavZones:Positions(s_State.Zone, s_Route)
		end
	end
	-- The route starts at the point of the bot: if it isn't there (spawned up to ZONE_SPAWN_RANGE away, halfway to the
	-- next point), first to it. Straight to the second point the way can lead through a wall.
	local s_Soldier = self.m_Player.soldier
	local s_Start = s_State.Zone.Points[s_State.Point]
	if not s_State.Vehicle and s_Soldier ~= nil and s_Start ~= nil then
		local s_DeltaX = s_Start.Position.x - s_Soldier.worldTransform.trans.x
		local s_DeltaZ = s_Start.Position.z - s_Soldier.worldTransform.trans.z
		if s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ > ZONE_OFF_POINT * ZONE_OFF_POINT then
			table.insert(s_State.Targets, 1, { Position = s_Start.Position, Flags = s_Start.Flags, Point = s_State.Point })
		end
	end
end

---Back on the network from where the bot is now, e.g. after a fight. Keeps the goal unless p_NewGoal.
---@param p_NewGoal boolean
function Bot:_ZoneReplan(p_NewGoal)
	local s_State = self.m_Zone
	local s_Soldier = self.m_Player.soldier
	if s_State == nil or s_Soldier == nil then
		return
	end

	local s_Position = s_State.Vehicle and self.m_Player.controlledControllable ~= nil
		and self.m_Player.controlledControllable.transform.trans or s_Soldier.worldTransform.trans
	local s_Point = m_NavZones:Closest(s_State.Zone, s_Position, s_State.Avoid)
	if s_Point ~= nil then
		s_State.Point = s_Point
	end
	s_State.Avoid = nil

	if s_State.Exit ~= nil then
		self:_ZoneRouteToExit(s_State.Exit)
	elseif p_NewGoal or s_State.Goal == nil then
		self:_ZoneNewGoal()
	else
		self:_ZoneRouteTo(s_State.Goal)
	end
end

---Without a route over the mesh (NavRoutes): the junction of a path of the routes closest to the objective, else of
---any other path the bot can take (not the dead end of another objective).
---@param p_Objective string
---@return NavZoneJunction|nil
function Bot:_ZoneBestExit(p_Objective)
	local s_State = self.m_Zone
	---@cast s_State -nil

	local s_Best = nil
	local s_BestNavigation = false
	local s_BestDistance = math.huge

	for l_Index = 1, #s_State.Zone.Junctions do
		local l_Junction = s_State.Zone.Junctions[l_Index]
		local s_Waypoint = l_Junction.Waypoint
		local s_First = s_Waypoint and m_NodeCollection:GetFirst(s_Waypoint.PathIndex)
		-- Soldiers leave on paths they may walk, vehicles on vehicle-paths for land. Only junctions the bot can reach.
		local s_Usable = false
		if s_Waypoint ~= nil and type(s_First) == 'table'
			and s_State.Zone.Part[l_Junction.Point] == s_State.Zone.Part[s_State.Point] then
			if s_State.Vehicle then
				s_Usable = s_First.Data ~= nil and type(s_First.Data.Vehicles) == 'table' and table.has(s_First.Data.Vehicles, 'land')
			else
				s_Usable = m_PathSwitcher:IsWalkable(s_Waypoint.PathIndex)
			end
		end
		-- Dead ends of other objectives (the way to a vehicle, a beacon) lead nowhere: the bot would walk it to its end,
		-- get onto the mesh there and take it again.
		local s_Route = s_Usable and not s_State.Vehicle and m_NavRoutes:IsRoutePath(s_Waypoint.PathIndex)
		if s_Usable and not s_Route and not s_State.Vehicle then
			local s_Objectives = s_First.Data and s_First.Data.Objectives or {}
			s_Usable = #s_Objectives == 0 or table.has(s_Objectives, p_Objective)
		end
		if s_Usable then
			---@cast s_Waypoint Waypoint
			local s_Distance = g_GameDirector:_GetDistanceFromObjective(p_Objective, s_Waypoint.Position)
			if (s_Route and not s_BestNavigation) or (s_Route == s_BestNavigation and s_Distance < s_BestDistance) then
				s_Best = l_Junction
				s_BestNavigation = s_Route
				s_BestDistance = s_Distance
			end
		end
	end
	return s_Best
end

---@param p_Junction NavZoneJunction
function Bot:_ZoneRouteToExit(p_Junction)
	local s_State = self.m_Zone
	---@cast s_State -nil
	s_State.Exit = p_Junction
	self:_ZoneRouteTo(p_Junction.Point)
	-- At last the way to the waypoint of the junction, and the waypoint itself.
	for l_Index = 1, #p_Junction.Corners do
		s_State.Targets[#s_State.Targets + 1] = { Position = p_Junction.Corners[l_Index], Flags = 0 }
	end
	s_State.Targets[#s_State.Targets + 1] = { Position = p_Junction.Waypoint.Position, Flags = 0 }
end

---Back to the waypoints: on the path of the junction (or the closest path), heading for the objective.
---@param p_Junction NavZoneJunction|nil
function Bot:_LeaveZone(p_Junction)
	local s_State = self.m_Zone
	self.m_Zone = nil
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._ShootWayPoints = {}

	local s_Waypoint = p_Junction and p_Junction.Waypoint
	self.m_LeftZoneAt = p_Junction ~= nil and { Point = p_Junction.Point, Time = SharedUtils:GetTime() } or nil
	-- The exits it took lately: not again for a while (a loop over junctions next to each other, NavRoutes:Next).
	if p_Junction ~= nil then
		self.m_RecentExits = self.m_RecentExits or {}
		self.m_RecentExits[p_Junction] = SharedUtils:GetTime()
	end
	self.m_LeftMeshTime = SharedUtils:GetTime()
	if s_Waypoint == nil and s_State ~= nil and s_State.Vehicle and self.m_Player.controlledControllable ~= nil then
		s_Waypoint = g_GameDirector:FindClosestPath(self.m_Player.controlledControllable.transform.trans, true, false,
			VehicleTerrains.Land)
	elseif s_Waypoint == nil and self.m_Player.soldier ~= nil then
		s_Waypoint = g_GameDirector:FindClosestPath(self.m_Player.soldier.worldTransform.trans, false, true, nil)
	end

	self._NavCame = nil
	if s_Waypoint ~= nil then
		-- Onto the waypoint: there the routes decide the way on (_CheckForZoneEntry), until then towards the objective.
		self._PathIndex = s_Waypoint.PathIndex
		self._CurrentWayPoint = s_Waypoint.PointIndex
		if self._Objective ~= '' then
			local s_Direction = nil
			if s_State == nil or not s_State.Vehicle then
				s_Direction = m_NavRoutes:Direction(s_Waypoint, self._Objective, self.m_RouteSeed)
			end
			s_Direction = s_Direction
				or m_NodeCollection:ObjectiveDirection(s_Waypoint, self._Objective, s_State ~= nil and s_State.Vehicle)
			if s_Direction then
				self._InvertPathDirection = (s_Direction == 'Previous')
			end
		end
	end

	self:CenterPathOffset(2.0)
	self._StuckTimer = 0.0
	self._ObstacleRetryCounter = 0
	self:_ResetObstacleSequence()
	self._LastWayDistance = 1000.0
	m_Logger:Write(self.m_Player.name .. ' leaves the zone of ' .. (s_State and s_State.Zone.Name or '?'))
end

---MCOM: the GameDirector sends up to two bots per team to arm (attackers) or disarm (defenders) it. Their objective
---becomes "mcom N interact", they leave the zone at the action-node of that path, and the action is done there. Also
---called while the bot fights (StateAttacking): the MCOM gets armed while the defenders shoot at the attacker.
---@param p_DeltaTime number
function Bot:UpdateZoneSubObjective(p_DeltaTime)
	local s_State = self.m_Zone
	if s_State == nil or s_State.SubObjective == nil or s_State.Exit ~= nil or self._Objective ~= s_State.Zone.Name then
		return
	end
	-- Only in the zone of the MCOM: on the way there the bot would hold one of the two places for a long time.
	if not s_State.Zone.InsideSet[s_State.Point] then
		return
	end
	s_State.SubTimer = s_State.SubTimer + p_DeltaTime
	if s_State.SubTimer >= ZONE_SUBOBJECTIVE_CYCLE then
		s_State.SubTimer = 0.0
		g_GameDirector:UseSubobjective(self.m_Id, self.m_Player.teamId, s_State.SubObjective)
	end
end

---Rush: the bot left the combat area (GameDirector:OnCombatArea). The area of the next stage opens a while after the
---stage before fell, but the objectives are the new MCOMs at once. On the mesh the bot walks back to the point it
---reached last (inside) and waits there, off the mesh it turns around on its path. Then it tries again.
function Bot:OnCombatAreaLeft()
	if self.m_Player.soldier == nil then
		return
	end
	local s_Border = { Left = SharedUtils:GetTime(), Returned = nil, Inverted = false }
	self.m_Border = s_Border
	local s_State = self.m_Zone
	if s_State ~= nil and not s_State.Vehicle then
		s_State.Exit = nil
		s_State.Action = nil
		s_State.SubObjective = nil
		-- Back to a point it passed a bit behind it (inside), the oldest one it knows if none is that far. It stops as soon
		-- as it is inside again (OnCombatAreaReturned).
		local s_Here = self.m_Player.soldier.worldTransform.trans
		local s_Back = s_State.Point
		local s_Trail = s_State.Trail or {}
		for l_Index = #s_Trail, 1, -1 do
			s_Back = s_Trail[l_Index]
			local s_Point = s_State.Zone.Points[s_Back]
			if s_Point ~= nil and s_Point.Position:Distance(s_Here) >= BORDER_BACK then
				break
			end
		end
		self:_ZoneRouteTo(s_Back)
		local s_Point = s_State.Zone.Points[s_Back]
		if s_Point ~= nil and #s_State.Targets == 0 then
			s_State.Targets = { { Position = s_Point.Position, Flags = s_Point.Flags, Point = s_Back } }
		end
	else
		self._InvertPathDirection = not self._InvertPathDirection
		s_Border.Inverted = true
	end
end

---Rush: back in the combat area: waits there (UpdateBorder), off the mesh it turns around again.
function Bot:OnCombatAreaReturned()
	local s_Border = self.m_Border
	if s_Border == nil then
		return
	end
	s_Border.Returned = SharedUtils:GetTime()
	local s_State = self.m_Zone
	if s_State ~= nil and not s_State.Vehicle then
		-- Inside again: it waits right here.
		s_State.Targets = {}
		s_State.Step = 1
	elseif s_Border.Inverted and s_State == nil then
		self._InvertPathDirection = not self._InvertPathDirection
		s_Border.Inverted = false
	end
end

---Remembers the point the bot reached (the last TRAIL_POINTS), the way back from the border of the combat area.
---@param p_State BotZoneState
function Bot:_ZoneTrail(p_State)
	local s_Trail = p_State.Trail
	if s_Trail == nil then
		s_Trail = {}
		p_State.Trail = s_Trail
	end
	if s_Trail[#s_Trail] ~= p_State.Point then
		s_Trail[#s_Trail + 1] = p_State.Point
		if #s_Trail > TRAIL_POINTS then
			table.remove(s_Trail, 1)
		end
	end
end

---Rush: the end of the wait at the border (GameDirector, about every second).
function Bot:UpdateBorder()
	local s_Border = self.m_Border
	if s_Border == nil then
		return
	end
	local s_Now = SharedUtils:GetTime()
	if self.m_Player.soldier == nil then
		self.m_Border = nil
	elseif s_Border.Returned == nil and s_Now - s_Border.Left > BORDER_GIVE_UP then
		-- Never came back: it was outside already. On to the objective.
		self.m_Border = nil
		if s_Border.Inverted and self.m_Zone == nil then
			self._InvertPathDirection = not self._InvertPathDirection
		end
	elseif s_Border.Returned ~= nil and s_Now - s_Border.Returned > BORDER_WAIT then
		self.m_Border = nil
	else
		return
	end
	if self.m_Zone ~= nil and not self.m_Zone.Vehicle then
		self:_ZoneDecide()
	end
end

---Movement in the zone, instead of Bot:UpdateNormalMovement.
---@param p_DeltaTime number
---@return boolean true while the bot is in the zone
function Bot:UpdateZoneMovement(p_DeltaTime)
	local s_State = self.m_Zone
	local s_Soldier = self.m_Player.soldier
	if s_State == nil or s_Soldier == nil then
		return false
	end

	-- After a fight: back on the network from where the bot is now.
	if #self._ShootWayPoints > 0 then
		self._ShootWayPoints = {}
		self:_ZoneReplan(false)
	end

	self:UpdateZoneSubObjective(p_DeltaTime)

	-- New objective: decide anew where to go (not while it waits at the border of the combat area, UpdateBorder).
	if self._Objective ~= s_State.Objective and (s_State.Exit == nil or self._Objective ~= '') and self.m_Border == nil then
		self:_ZoneDecide()
		if self.m_Zone == nil then
			return false
		end
	end

	-- The fast update skipped a target that was passed already.
	local s_Following = s_State.Targets[s_State.Step + 1]
	if s_Following ~= nil and self._TargetPoint == s_Following then
		local s_Passed = s_State.Targets[s_State.Step]
		if s_Passed ~= nil and s_Passed.Point ~= nil then
			s_State.Point = s_Passed.Point
			self:_ZoneTrail(s_State)
		end
		s_State.Step = s_State.Step + 1
	end

	local s_Target = s_State.Targets[s_State.Step]
	if s_Target == nil then
		-- At the goal: the ways given up on the way there don't count anymore (not at each point: after giving a way
		-- up the bot walks back over points it reaches and would try the same way again forever).
		s_State.Fails = 0
		self.m_ZoneGiveUps = 0
		if s_State.Exit ~= nil then
			self:_LeaveZone(s_State.Exit)
			return false
		end
		if s_State.Action ~= nil then
			return self:_ZoneAction(p_DeltaTime)
		end

		-- In a base the bot only waits for its objective, on the mesh outside of the zones as well. At the border of the
		-- combat area until it tries again (UpdateBorder).
		if s_State.Zone.Kind == 'base' or s_State.Zone.Kind == 'mesh' or self.m_Border ~= nil then
			s_State.Waiting = true
			self:LookAround(p_DeltaTime)
			return true
		end

		-- At the goal: look around for a while, then the next one.
		if s_State.Wait > 0.0 then
			s_State.Waiting = true
			s_State.Wait = s_State.Wait - p_DeltaTime
			local s_Point = s_State.Goal and s_State.Zone.Points[s_State.Goal]
			if self:_ZoneDefends(s_State) and s_Point ~= nil and s_Point.Cover >= 3
				and s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
			self:LookAround(p_DeltaTime)
			return true
		end

		self:_ZoneNewGoal()
		return true
	end

	-- On the way to a vehicle: in as soon as the bot is next to it, or doesn't get closer from where it gets in.
	if s_State.Action ~= nil and s_State.Action.Kind == 'vehicle' then
		local s_Ok, s_VehiclePosition = pcall(function() return s_State.Action.Entity.transform.trans end)
		if s_Ok and s_VehiclePosition ~= nil then
			local s_Here = s_Soldier.worldTransform.trans
			local s_DeltaX = s_VehiclePosition.x - s_Here.x
			local s_DeltaZ = s_VehiclePosition.z - s_Here.z
			local s_Near = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
			if math.abs(s_VehiclePosition.y - s_Here.y) <= ZONE_VEHICLE_FLOOR
				and (s_Near <= ZONE_VEHICLE_NEAR or (s_Near <= ZONE_VEHICLE_REACH and s_State.Stuck > ZONE_JUMP_TIME)) then
				return self:_ZoneAction(p_DeltaTime)
			end
		end
	end

	-- Walking.
	s_State.Waiting = false
	self._DefendTimer = 0.0
	self._WayWaitTimer = 0.0
	local s_TargetPoint = s_Target.Point and s_State.Zone.Points[s_Target.Point]
	local s_Position = s_Soldier.worldTransform.trans
	local s_DeltaX = s_Target.Position.x - s_Position.x
	local s_DeltaZ = s_Target.Position.z - s_Position.z
	local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
	local s_Narrow = (s_TargetPoint ~= nil and s_TargetPoint.Clearance < ZONE_NARROW)
		or (s_Distance < ZONE_STEEP_RANGE and math.abs(s_Target.Position.y - s_Position.y) > ZONE_STEEP)
	if s_Target.Flags & NavZoneFlags.Crouch ~= 0 then
		self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
	elseif s_Narrow or (s_State.Exit == nil and s_Target.Flags & NavZoneFlags.InZone ~= 0) then
		-- Walking around in the zone. On the way out (to the next objective, to arm or disarm) the bot runs.
		self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
	else
		self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint
	end
	self:_ApplyReactionAction(p_DeltaTime)
	if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement then
		self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
	end

	self._TargetPoint = s_Target
	self._NextTargetPoint = s_State.Targets[s_State.Step + 1]


	-- Close to the target but facing away: slow down while turning (a bot can only turn so fast while it runs).
	if s_Distance < ZONE_TURN_DISTANCE and self.m_Input ~= nil
		and self.m_ActiveSpeedValue ~= BotMoveSpeeds.SlowCrouch and self.m_ActiveSpeedValue ~= BotMoveSpeeds.NoMovement then
		local s_Atan = math.atan(s_DeltaZ, s_DeltaX)
		local s_Yaw = (s_Atan > math.pi / 2) and (s_Atan - math.pi / 2) or (s_Atan + 3 * math.pi / 2)
		local s_Turn = math.abs(self.m_Input.authoritativeAimingYaw - s_Yaw) % (2 * math.pi)
		if s_Turn > math.pi then
			s_Turn = 2 * math.pi - s_Turn
		end
		if s_Turn > ZONE_TURN_ANGLE then
			self.m_ActiveSpeedValue = BotMoveSpeeds.Slow
		end
	end

	-- Where the soldier who recorded the way jumped (a step into a train, over a railing): jump as well.
	if s_Target.Flags & NavZoneFlags.Jump ~= 0 and s_Distance < ZONE_JUMP_RANGE then
		self:_SetInput(EntryInputActionEnum.EIAJump, 1)
		self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
	end

	local s_Reach = (s_Target.Point ~= nil and not s_Narrow) and ZONE_REACH_POINT or ZONE_REACH_CORNER
	if self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
		s_Reach = s_Reach * ZONE_REACH_SPRINT
	end
	s_Reach = self:_ZoneSmooth(s_State, s_Target, s_TargetPoint, s_Distance, s_Reach, s_Narrow)
	if s_Distance < s_Reach and math.abs(s_Target.Position.y - s_Position.y) < ZONE_REACH_HEIGHT then
		if s_Target.Point ~= nil then
			s_State.Point = s_Target.Point
			self:_ZoneTrail(s_State)
		end
		s_State.Step = s_State.Step + 1
		s_State.Progress = math.huge
		s_State.Stuck = 0.0
		self._LastWayDistance = 1000.0
		return true
	end

	-- Fallen off (a narrow ramp, stairs without a railing): far below the way from the last target to this one. The bot
	-- walks round and tries again, always with some progress: count it as a way given up at once.
	local s_From = s_State.Targets[s_State.Step - 1]
	local s_FromPosition = s_From ~= nil and s_From.Position
		or (s_State.Zone.Points[s_State.Point] and s_State.Zone.Points[s_State.Point].Position)
	if s_FromPosition ~= nil and s_State.FallTime + ZONE_FALL_PAUSE < SharedUtils:GetTime() then
		local s_LengthX = s_Target.Position.x - s_FromPosition.x
		local s_LengthZ = s_Target.Position.z - s_FromPosition.z
		local s_Length = math.sqrt(s_LengthX * s_LengthX + s_LengthZ * s_LengthZ)
		local s_Share = 0.0
		if s_Length > 0.1 then
			s_Share = math.max(0.0, math.min(1.0, 1.0 - s_Distance / s_Length))
		end
		local s_Expected = s_FromPosition.y + (s_Target.Position.y - s_FromPosition.y) * s_Share
		if s_Position.y < s_Expected - ZONE_FALL
			and s_Position.y < math.min(s_FromPosition.y, s_Target.Position.y) - ZONE_FALL_BELOW then
			s_State.FallTime = SharedUtils:GetTime()
			m_Logger:Write(self.m_Player.name .. ' fell off the way in the zone of ' .. s_State.Zone.Name)
			if self:_ZoneGiveUpConnection(s_Position, s_Target.Position) then
				return false
			end
			return true
		end
	end

	-- Stuck: jump now and then, give the way up after a while, the zone after a few ways.
	if s_Distance < s_State.Progress - ZONE_MIN_PROGRESS then
		s_State.Progress = s_Distance
		s_State.Stuck = 0.0
	else
		s_State.Stuck = s_State.Stuck + p_DeltaTime
	end

	-- A wall in the way that can be shot away (Bot:_TryBreach): that first, then on.
	if s_State.Stuck > ZONE_JUMP_TIME and self:_TryBreach(s_Target.Position, s_Target) then
		s_State.Stuck = 0.0
		s_State.Progress = math.huge
		return true
	end

	-- Off the line of the way (pushed aside, cut a corner): back onto it sideways, the way itself is free. Else a pillar
	-- beside the line holds the bot.
	if s_State.Stuck > ZONE_SIDESTEP_TIME and s_FromPosition ~= nil then
		local s_LineX = s_Target.Position.x - s_FromPosition.x
		local s_LineZ = s_Target.Position.z - s_FromPosition.z
		local s_LineLength = math.sqrt(s_LineX * s_LineX + s_LineZ * s_LineZ)
		if s_LineLength > 0.5 then
			-- Right of the way (looking along it) is (-z, x): positive offset = right of it, strafe left.
			local s_Offset = ((s_Position.x - s_FromPosition.x) * -s_LineZ + (s_Position.z - s_FromPosition.z) * s_LineX)
				/ s_LineLength
			if math.abs(s_Offset) > ZONE_SIDESTEP_OFFSET then
				self:_SetInput(EntryInputActionEnum.EIAStrafe, s_Offset > 0 and -1.0 or 1.0)
			end
		end
	end

	s_State.JumpTimer = s_State.JumpTimer + p_DeltaTime
	if s_State.Stuck > ZONE_JUMP_TIME and s_State.JumpTimer > ZONE_JUMP_TIME then
		s_State.JumpTimer = 0.0
		self:_SetInput(EntryInputActionEnum.EIAJump, 1)
		self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
	end

	if s_State.Stuck > ZONE_STUCK_TIME then
		if self:_ZoneGiveUpConnection(s_Position, s_Target.Position) then
			return false
		end
	end

	return true
end

---Smoothing (Registry.BOT.ZONE_SMOOTHING): from a point of the mesh on to the next one, the bot turns before it gets
---there instead of walking to it and turning on the spot. Within ZONE_SMOOTH_ROOM of the point it already steers to a
---spot on the way to the next one (further along the closer it gets), and it counts the point as reached as soon as it
---is within ZONE_SMOOTH_ROOM of it. Both only as far as there is room around this and the next point (their clearance),
---not at corners around walls, narrow ways, steps and where the bot has to crouch.
---@param p_State BotZoneState
---@param p_Target { Position: Vec3, Flags: integer, Point: integer|nil }
---@param p_TargetPoint NavZonePoint|nil
---@param p_Distance number horizontal metres to the target
---@param p_Reach number
---@param p_Narrow boolean
---@return number the distance at which the target counts as reached
function Bot:_ZoneSmooth(p_State, p_Target, p_TargetPoint, p_Distance, p_Reach, p_Narrow)
	local s_Next = p_State.Targets[p_State.Step + 1]
	if not Registry.BOT.ZONE_SMOOTHING or p_Narrow or p_TargetPoint == nil or s_Next == nil or s_Next.Point == nil
		or p_Target.Flags & NavZoneFlags.Crouch ~= 0 or s_Next.Flags & NavZoneFlags.Crouch ~= 0
		or math.abs(s_Next.Position.y - p_Target.Position.y) > ZONE_STEEP then
		return p_Reach
	end
	local s_NextPoint = p_State.Zone.Points[s_Next.Point]
	local s_Room = math.min(ZONE_SMOOTH_ROOM, p_TargetPoint.Clearance, s_NextPoint and s_NextPoint.Clearance or 0.0)
	if s_Room <= p_Reach then
		return p_Reach
	end
	if p_Distance < 2.0 * s_Room then
		local s_DeltaX = s_Next.Position.x - p_Target.Position.x
		local s_DeltaZ = s_Next.Position.z - p_Target.Position.z
		local s_Length = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
		if s_Length > 0.1 then
			-- From 0 (2 * room away) to the room (at the point) along the way to the next point.
			local s_Along = math.min(s_Length, s_Room * (2.0 - p_Distance / s_Room)) / s_Length
			self._TargetPoint = {
				Position = Vec3(p_Target.Position.x + s_DeltaX * s_Along, p_Target.Position.y,
					p_Target.Position.z + s_DeltaZ * s_Along),
			}
		end
	end
	return s_Room
end

---At the goal of its action: get into the vehicle, or walk up to the MCOM, look at it and interact (the GameDirector
---gives the bot its MCOM back as objective once it is armed or disarmed, _ZoneDecide then ends this).
---@param p_DeltaTime number
---@return boolean true while the bot is in the zone
function Bot:_ZoneAction(p_DeltaTime)
	local s_State = self.m_Zone
	---@cast s_State -nil
	local s_Action = s_State.Action
	local s_Soldier = self.m_Player.soldier
	s_State.Waiting = false

	if s_Action.Kind == 'vehicle' then
		local s_Entity = s_Action.Entity
		local s_Ok, s_Position = pcall(function() return s_Entity.transform.trans:Clone() end)
		if not s_Ok or s_Position == nil then
			self:SetObjective('')
			return true
		end
		if s_Position:Distance(s_Soldier.worldTransform.trans) > ZONE_VEHICLE_REACH then
			-- It drove off meanwhile: the way to where it is now.
			s_State.Action = nil
			self:_ZoneDecide()
			return self.m_Zone ~= nil
		end
		local s_Code = self:_EnterVehicleEntity(s_Entity, false)
		if s_Code == 0 then
			m_Logger:Write(self.m_Player.name .. ' got into ' .. tostring(self._Objective))
			self.m_Zone = nil
			self._ShootWayPoints = {}
			self:FindVehiclePath(s_Position)
			return false
		end
		if m_DebugBridge.m_Enabled then
			m_DebugBridge:Event('vehicle_enter_failed', {
				bot = self.m_Id,
				code = s_Code,
				pos = DebugBridge.Vec(s_Soldier.worldTransform.trans),
			})
		end
		self:SetObjective('')
		return true
	end

	-- MCOM: up to it (where the soldier stood on the recorded path, else close to the MCOM), then interact.
	s_State.ActionTime = s_State.ActionTime + p_DeltaTime
	local s_Position = s_Soldier.worldTransform.trans
	local s_Goal = s_Action.Stand or s_Action.Position
	local s_DeltaX = s_Goal.x - s_Position.x
	local s_DeltaZ = s_Goal.z - s_Position.z
	local s_Reach = s_Action.Stand ~= nil and 0.5 or ZONE_ARM_DISTANCE
	if math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ) > s_Reach and s_State.ActionTime < ZONE_ARM_APPROACH then
		self.m_ActiveSpeedValue = BotMoveSpeeds.Slow
		self._TargetPoint = { Position = s_Goal }
		self._NextTargetPoint = nil
		return true
	end

	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self._TargetPoint = nil
	if s_Action.Yaw ~= nil then
		self._TargetYaw = s_Action.Yaw
	else
		local s_Atan = math.atan(s_Action.Position.z - s_Position.z, s_Action.Position.x - s_Position.x)
		self._TargetYaw = (s_Atan > math.pi / 2) and (s_Atan - math.pi / 2) or (s_Atan + 3 * math.pi / 2)
	end
	self._TargetPitch = ZONE_ARM_PITCH
	if s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
		s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
	end
	self:_SetInput(EntryInputActionEnum.EIAInteract, 1)
	if s_State.ActionTime > ZONE_ARM_APPROACH + ZONE_ARM_TIME then
		-- Doesn't work from here: the MCOM itself again, the GameDirector may send the bot anew.
		m_Logger:Write(self.m_Player.name .. ' could not interact with ' .. tostring(self._Objective))
		local s_Parent = g_GameDirector:_GetObjectiveFromSubObj(self._Objective)
		if s_Parent ~= nil then
			g_GameDirector:McomTryFailed(s_Parent)
		end
		self:SetObjective(s_Parent or '', self._ObjectiveMode)
	end
	return true
end

---The bot doesn't get along to the next point: all bots avoid this connection from now on, the bot takes another
---way. After ZONE_MAX_FAILS of them in a row it goes back to the waypoints.
---@param p_Position Vec3
---@param p_Target Vec3
---@return boolean true if the bot left the zone
function Bot:_ZoneGiveUpConnection(p_Position, p_Target)
	local s_State = self.m_Zone
	---@cast s_State -nil
	s_State.Fails = s_State.Fails + 1
	m_Logger:Write(self.m_Player.name .. ' stuck in the zone of ' .. s_State.Zone.Name .. ' (' .. s_State.Fails .. ')')

	local s_Next = nil
	for l_Step = s_State.Step, #s_State.Targets do
		if s_State.Targets[l_Step].Point ~= nil then
			s_Next = s_State.Targets[l_Step].Point
			break
		end
	end
	-- The connection is the one of the route: from its last point before the target (the bot may have passed it
	-- without the point being counted).
	for l_Step = s_State.Step - 1, 1, -1 do
		if s_State.Targets[l_Step].Point ~= nil then
			s_State.Point = s_State.Targets[l_Step].Point
			break
		end
	end
	if s_Next ~= nil and s_Next ~= s_State.Point then
		m_NavZones:BlockEdge(s_State.Zone, s_State.Point, s_Next)
	elseif s_Next ~= nil then
		-- It didn't get back to its own point (pushed off, came onto the mesh beside it): the way there from the point it
		-- stands at is blocked (a railing, a bench the census and the checks don't see), for all bots.
		local s_Near = m_NavZones:Closest(s_State.Zone, p_Position, s_Next)
		if s_Near ~= nil and s_Near ~= s_Next then
			m_NavZones:BlockEdge(s_State.Zone, s_Near, s_Next)
		end
	end
	-- All ways from the last point failed, or the bot didn't get back to it (_ZoneRouteTo, from ZONE_OFF_POINT away):
	-- start the next route at another point.
	if s_Next == s_State.Point or m_NavZones:IsBlockedIn(s_State.Zone, s_State.Point) then
		s_State.Avoid = s_State.Point
	end
	-- Off a path onto the mesh, and the point of that junction can't be reached from its waypoint (a pillar, a corner
	-- the census measured too open): all bots come onto the mesh elsewhere from now on.
	local s_Entry = s_State.EntryJunction
	if s_Entry ~= nil and s_Next == s_State.Point and s_State.Point == s_Entry.Point and not s_State.Vehicle then
		m_NavRoutes:BlockEntry(s_Entry)
		s_State.EntryJunction = nil
	end
	if m_DebugBridge.m_Enabled then
		-- Points counted from 0, as in the file of the networks.
		m_DebugBridge:Event('zone_stuck', {
			zone = s_State.Vehicle and (s_State.Zone.Name .. ' (vehicles)') or s_State.Zone.Name,
			from = s_State.Point - 1,
			to = s_Next and s_Next - 1,
			pos = DebugBridge.Vec(p_Position),
			target = DebugBridge.Vec(p_Target),
			bot = self.m_Id,
		})
	end

	if s_State.Fails >= ZONE_MAX_FAILS then
		-- On the way out: another exit, if there is one (all bots take this one less from now on).
		if s_State.Exit ~= nil and s_State.ExitFails < ZONE_MAX_FAILS and m_NavRoutes:Knows(self._Objective) then
			m_NavRoutes:BlockExit(s_State.Exit)
			s_State.ExitFails = s_State.ExitFails + 1
			s_State.Fails = 0
			self:_ZoneReplan(false)
			self:_ZoneDecide()
			return self.m_Zone == nil
		end
		self.m_ZoneGiveUps = self.m_ZoneGiveUps + 1
		if self.m_ZoneGiveUps >= ZONE_MAX_GIVE_UPS then
			m_Logger:Write(self.m_Player.name .. ' stuck in the zone of ' .. s_State.Zone.Name .. '. Kill')
			self:_LeaveZone(nil)
			self.m_Player.soldier:Kill()
			return true
		end
		self:_LeaveZone(nil)
		return true
	end
	self:_ZoneReplan(true)
	return false
end
