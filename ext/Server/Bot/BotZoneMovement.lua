-- Free movement inside the zone of the objective (NavZones.lua). A bot that reaches a junction of the zone of its
-- objective leaves the waypoints and walks the network of the zone: from point to point inside the zone, waiting a
-- moment at each (longer and in cover when it defends). When its objective changes it walks to the junction that suits
-- the new objective best and goes on along that path.

---@type NavZones
local m_NavZones = require('NavZones')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type PathSwitcher
local m_PathSwitcher = require('PathSwitcher')
---@type DebugBridge
local m_DebugBridge = require('Debug/DebugBridge')
---@type Logger
local m_Logger = Logger('BotZoneMovement', Debug.Server.BOT)

local ZONE_REACH = 0.8           -- Horizontal metres to a position that count as reached.
local ZONE_REACH_HEIGHT = 1.5    -- Same as Registry.BOT.TARGET_HEIGHT_DISTANCE_WAYPOINT.
local ZONE_MIN_PROGRESS = 0.3    -- Metres closer to the target that count as progress.
local ZONE_JUMP_TIME = 1.5       -- Seconds without progress before a jump.
local ZONE_STUCK_TIME = 4.0      -- Seconds without progress before the bot gives up this way.
local ZONE_MAX_FAILS = 3         -- Ways given up before the bot leaves the zone.
local ZONE_WAIT_ATTACK = { 1.0, 3.0 } -- Seconds at each point while capturing.
local ZONE_WAIT_DEFEND = { 5.0, 12.0 } -- Seconds at each point while defending.
local ZONE_SUBOBJECTIVE_CYCLE = 1.0 -- Seconds between two checks whether the bot shall arm / disarm the MCOM.
local ZONE_WAIT_VEHICLE = { 3.0, 8.0 } -- Seconds a vehicle stands at each point.

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
---@field Exit NavZoneJunction|nil
---@field SubObjective string|nil "mcom N interact" of an MCOM-zone
---@field SubTimer number
---@field Vehicle boolean on the vehicle-network, as driver of a land vehicle
---@field Reverse number seconds the vehicle still reverses
---@field Reverses integer reverses on the way to the current target
---@field Avoid integer|nil a dead end the bot got stuck at: not the start of the next route

---Called when the bot reached a waypoint. At a junction of the zone of its objective, it walks the network from now on.
---@param p_Point Waypoint (or an offset-point with the fields of its waypoint)
---@return boolean true if the bot is in the zone now
function Bot:_CheckForZoneEntry(p_Point)
	if not Registry.BOT.USE_ZONE_NETWORKS or self._Objective == '' or self.m_Zone ~= nil then
		return false
	end

	local s_Entry = m_NavZones:GetJunction(p_Point.Original or p_Point)
	if s_Entry == nil or s_Entry.Zone.Name ~= self._Objective
		or (s_Entry.Zone.Kind ~= 'capturepoint' and s_Entry.Zone.Kind ~= 'mcom') then
		return false
	end

	self:_EnterZone(s_Entry.Zone, s_Entry.Junction.Point, false, s_Entry.Junction)
	return true
end

-- A spawn-point of the game this far from a point of a network: the bot walks straight to it and starts on the network.
local ZONE_SPAWN_RANGE = 30.0

---After a spawn at a spawn-point of the game (BotSpawner, SpawnMethod.Spawn): on the network of the zone there (a base
---or a capture point) the bot starts in it, and walks out over the junction that suits its objective.
---@param p_Position Vec3
---@return boolean true if the bot is in a zone now
function Bot:TryEnterZoneAt(p_Position)
	if not Registry.BOT.USE_ZONE_NETWORKS then
		return false
	end
	local s_Zone, s_Point = m_NavZones:ZoneAt(p_Position, ZONE_SPAWN_RANGE)
	if s_Zone == nil or s_Point == nil then
		return false
	end
	self:_EnterZone(s_Zone, s_Point)
	return true
end

---Called when the driver of a land vehicle reached a waypoint of its vehicle-path. At a junction of the vehicle-network
---of the capture point of its objective, it drives the network from now on (VehicleMovement).
---@param p_Point Waypoint
---@return boolean true if the vehicle is in the zone now
function Bot:_CheckForVehicleZoneEntry(p_Point)
	if not Registry.BOT.USE_ZONE_NETWORKS or not Registry.BOT.USE_VEHICLE_ZONE_NETWORKS or self._Objective == ''
		or self.m_Zone ~= nil or self.m_ActiveVehicle == nil or self.m_ActiveVehicle.Terrain ~= VehicleTerrains.Land then
		return false
	end

	local s_Entry = m_NavZones:GetVehicleJunction(p_Point)
	if s_Entry == nil or s_Entry.Zone.Name ~= self._Objective or s_Entry.Zone.Kind ~= 'capturepoint' then
		return false
	end

	self:_EnterZone(s_Entry.Zone, s_Entry.Junction.Point, true, s_Entry.Junction)
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
		-- The objective of the zone: a bot with another one leaves it (from a base: as soon as it has one).
		Objective = p_Zone.Name,
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
		Exit = nil,
		-- The MCOM is armed and disarmed at the action-node of the path "mcom N interact" (a junction of the zone).
		SubObjective = not p_Vehicle and p_Zone.Kind == 'mcom' and g_GameDirector:_GetSubObjectiveFromObj(p_Zone.Name) or nil,
		SubTimer = 0.0,
		Vehicle = p_Vehicle == true,
		Reverse = 0.0,
		Reverses = 0,
	}
	self:_StopObstacleSequence()
	self:_ZoneNewGoal()

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
	m_Logger:Write(self.m_Player.name .. ' enters the zone of ' .. p_Zone.Name)
end

---Walks to the next point of the zone (not the one the bot is at).
function Bot:_ZoneNewGoal()
	local s_State = self.m_Zone
	---@cast s_State -nil
	local s_Defend = self._ObjectiveMode == BotObjectiveModes.Defend
	local s_Goal = m_NavZones:RandomPoint(s_State.Zone, s_State.Point, s_Defend and not s_State.Vehicle)
	self:_ZoneRouteTo(s_Goal)
	local s_Wait = s_State.Vehicle and ZONE_WAIT_VEHICLE or (s_Defend and ZONE_WAIT_DEFEND or ZONE_WAIT_ATTACK)
	s_State.Wait = MathUtils:GetRandom(s_Wait[1], s_Wait[2])
end

---@param p_Goal integer|nil
function Bot:_ZoneRouteTo(p_Goal)
	local s_State = self.m_Zone
	---@cast s_State -nil
	s_State.Goal = p_Goal
	s_State.Targets = {}
	s_State.Step = 1
	s_State.Waiting = false
	s_State.Progress = math.huge
	s_State.Stuck = 0.0
	if p_Goal == nil then
		return
	end
	local s_Route = m_NavZones:Route(s_State.Zone, s_State.Point, p_Goal)
	if s_Route ~= nil then
		s_State.Targets = m_NavZones:Positions(s_State.Zone, s_Route)
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

---The junction that leads to the objective best: the path with the highest priority for it (PathSwitcher), the one
---closest to the objective of these.
---@param p_Objective string
---@return NavZoneJunction|nil
function Bot:_ZoneBestExit(p_Objective)
	local s_State = self.m_Zone
	---@cast s_State -nil
	local s_Best = nil
	local s_BestPriority = -math.huge
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
		if s_Usable then
			---@cast s_First Waypoint
			---@cast s_Waypoint Waypoint
			local s_Priority = m_PathSwitcher:GetPriorityOfPath(s_First, p_Objective)
			-- A path that stays in the zone (only this objective) doesn't lead anywhere else.
			local s_Objectives = s_First.Data and s_First.Data.Objectives or {}
			if #s_Objectives == 1 and s_Objectives[1] == s_State.Zone.Name then
				s_Priority = s_Priority - 2
			end
			local s_Distance = g_GameDirector:_GetDistanceFromObjective(p_Objective, s_Waypoint.Position)
			if s_Priority > s_BestPriority or (s_Priority == s_BestPriority and s_Distance < s_BestDistance) then
				s_Best = l_Junction
				s_BestPriority = s_Priority
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
	if s_Waypoint == nil and s_State ~= nil and s_State.Vehicle and self.m_Player.controlledControllable ~= nil then
		s_Waypoint = g_GameDirector:FindClosestPath(self.m_Player.controlledControllable.transform.trans, true, false,
			VehicleTerrains.Land)
	elseif s_Waypoint == nil and self.m_Player.soldier ~= nil then
		s_Waypoint = g_GameDirector:FindClosestPath(self.m_Player.soldier.worldTransform.trans, false, true, nil)
	end

	if s_Waypoint ~= nil then
		self._PathIndex = s_Waypoint.PathIndex
		self._CurrentWayPoint = s_Waypoint.PointIndex
		if self._Objective ~= '' then
			local s_Direction = m_NodeCollection:ObjectiveDirection(s_Waypoint, self._Objective, s_State ~= nil and s_State.Vehicle)
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
	s_State.SubTimer = s_State.SubTimer + p_DeltaTime
	if s_State.SubTimer >= ZONE_SUBOBJECTIVE_CYCLE then
		s_State.SubTimer = 0.0
		g_GameDirector:UseSubobjective(self.m_Id, self.m_Player.teamId, s_State.SubObjective)
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

	-- New objective: out over the junction that suits it best. Without objective the bot stays.
	if self._Objective ~= s_State.Objective and s_State.Exit == nil then
		if self._Objective == '' then
			s_State.Objective = ''
		else
			local s_Exit = self:_ZoneBestExit(self._Objective)
			if s_Exit == nil then
				self:_LeaveZone(nil)
				return false
			end
			self:_ZoneRouteToExit(s_Exit)
		end
	end

	-- The fast update skipped a target that was passed already.
	local s_Following = s_State.Targets[s_State.Step + 1]
	if s_Following ~= nil and self._TargetPoint == s_Following then
		s_State.Step = s_State.Step + 1
	end

	local s_Target = s_State.Targets[s_State.Step]
	if s_Target == nil then
		if s_State.Exit ~= nil then
			self:_LeaveZone(s_State.Exit)
			return false
		end

		-- In a base the bot only waits for its objective.
		if s_State.Zone.Kind == 'base' then
			s_State.Waiting = true
			self:LookAround(p_DeltaTime)
			return true
		end

		-- At the goal: look around for a while, then the next one.
		if s_State.Wait > 0.0 then
			s_State.Waiting = true
			s_State.Wait = s_State.Wait - p_DeltaTime
			local s_Point = s_State.Goal and s_State.Zone.Points[s_State.Goal]
			if self._ObjectiveMode == BotObjectiveModes.Defend and s_Point ~= nil and s_Point.Cover >= 3
				and s_Soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
				s_Soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
			end
			self:LookAround(p_DeltaTime)
			return true
		end

		self:_ZoneNewGoal()
		return true
	end

	-- Walking.
	s_State.Waiting = false
	self._DefendTimer = 0.0
	self._WayWaitTimer = 0.0
	if s_Target.Flags & NavZoneFlags.Crouch ~= 0 then
		self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
	elseif s_State.Exit == nil and s_Target.Flags & NavZoneFlags.InZone ~= 0 then
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

	local s_Position = s_Soldier.worldTransform.trans
	local s_DeltaX = s_Target.Position.x - s_Position.x
	local s_DeltaZ = s_Target.Position.z - s_Position.z
	local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)

	if s_Distance < ZONE_REACH and math.abs(s_Target.Position.y - s_Position.y) < ZONE_REACH_HEIGHT then
		if s_Target.Point ~= nil then
			s_State.Point = s_Target.Point
		end
		s_State.Step = s_State.Step + 1
		s_State.Progress = math.huge
		s_State.Stuck = 0.0
		s_State.Fails = 0
		self._LastWayDistance = 1000.0
		return true
	end

	-- Stuck: jump now and then, give the way up after a while, the zone after a few ways.
	if s_Distance < s_State.Progress - ZONE_MIN_PROGRESS then
		s_State.Progress = s_Distance
		s_State.Stuck = 0.0
	else
		s_State.Stuck = s_State.Stuck + p_DeltaTime
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
	if s_Next ~= nil and s_Next ~= s_State.Point then
		m_NavZones:BlockEdge(s_State.Zone, s_State.Point, s_Next)
	end
	-- All ways from the last point failed: start the next route at another point.
	if m_NavZones:IsBlockedIn(s_State.Zone, s_State.Point) then
		s_State.Avoid = s_State.Point
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
		self:_LeaveZone(nil)
		return true
	end
	self:_ZoneReplan(true)
	return false
end
