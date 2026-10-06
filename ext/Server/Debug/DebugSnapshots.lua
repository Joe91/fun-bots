---@class DebugSnapshots
---@overload fun():DebugSnapshots
DebugSnapshots = class('DebugSnapshots')

-- The built-in parts of the snapshots of the DebugBridge, and game-events for the debug-server.
-- Collectors return plain tables only: positions as { x, y, z } in m (rounded to cm), angles in rad.
-- Add a new part of the snapshot with m_DebugBridge:RegisterCollector (here or in any other file).

---@type DebugBridge
local m_DebugBridge = require('Debug/DebugBridge')
---@type BotManager
local m_BotManager = require('BotManager')
---@type ServerRaycasts
local m_ServerRaycasts = require('ServerRaycasts')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type Utilities
local m_Utilities = require('__shared/Utilities')

local _Vec = DebugBridge.Vec
local _Round = DebugBridge.Round

---@param p_Enum table
---@return table value -> name
local function _Names(p_Enum)
	local s_Names = {}
	for l_Name, l_Value in pairs(p_Enum) do
		s_Names[l_Value] = l_Name
	end
	return s_Names
end

local s_ActionNames = _Names(BotActionFlags)
local s_MoveModeNames = _Names(BotMoveModes)
local s_KitNames = _Names(BotKits)
-- The state-objects are created with g_BotStates, so this is built on first use.
local s_StateNames = nil
-- Utilities:GetTime() at the last level-load (every round), nil after a reload of the mod until the next level.
local s_RoundStart = nil
-- Utilities:GetTime() when the mod was loaded: the start of the game-server, or the last reload of the mod.
local s_ModStart = _Round(m_Utilities:GetTime(), 3)

---@param p_Entity ControllableEntity
---@return string
local function _VehicleName(p_Entity)
	return m_Vehicles:GetVehicleNameOfEntity(p_Entity)
end

function DebugSnapshots:__init()
	m_DebugBridge:RegisterCollector('meta', self.CollectMeta)
	m_DebugBridge:RegisterCollector('bots', self.CollectBots)
	m_DebugBridge:RegisterCollector('players', self.CollectPlayers)
	m_DebugBridge:RegisterCollector('vehicles', self.CollectVehicles)
	m_DebugBridge:RegisterCollector('objectives', self.CollectObjectives)
end

-- =============================================
-- Collectors
-- =============================================

---@return table
function DebugSnapshots.CollectMeta()
	return {
		level = SharedUtils:GetLevelName(),
		mode = SharedUtils:GetCurrentGameMode(),
		paths = m_NodeCollection:GetMapName(), -- the waypoints of this mode, mapfiles/<paths>.map
		round = Globals.Round,
		roundStart = s_RoundStart,
		modStart = s_ModStart,
		tickrate = SharedUtils:GetTickrate(),
		bots = m_BotManager:GetBotCount(),
		players = PlayerManager:GetPlayerCount(),
		serverRaycasts = m_ServerRaycasts.m_Enabled,
		luaMemoryKb = math.floor(collectgarbage('count')),
		version = Registry.GetVersion(),
		commands = m_DebugBridge:GetCommandNames(),
	}
end

---Yaw in the convention of the bots: the view-direction is (x = -sin(yaw), z = cos(yaw)).
---@return table
function DebugSnapshots.CollectBots()
	if s_StateNames == nil then
		s_StateNames = _Names(g_BotStates.States)
	end

	local s_Result = {}
	local s_Bots = m_BotManager:GetBots()

	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		local s_Player = l_Bot.m_Player
		local s_Soldier = s_Player.soldier
		local s_Entry = {
			id = l_Bot.m_Id,
			name = s_Player.name,
			team = s_Player.teamId,
			squad = s_Player.squadId,
			kit = s_KitNames[l_Bot.m_Kit],
			alive = s_Soldier ~= nil,
			state = s_StateNames[l_Bot.m_ActiveState],
			action = s_ActionNames[l_Bot._ActiveAction],
			move = s_MoveModeNames[l_Bot.m_ActiveMoveMode],
			target = l_Bot._ShootPlayerId,
			path = l_Bot._PathIndex,
			point = type(l_Bot._CurrentWayPoint) == 'number' and l_Bot._CurrentWayPoint or nil,
			objective = l_Bot._Objective,
		}

		if s_Soldier ~= nil then
			local s_InVehicle = g_BotStates:IsInVehicleState(l_Bot.m_ActiveState)
			local s_Controllable = s_Player.controlledControllable
			-- The cast to the vehicle-data crashes on a soldier: check the entity, not only the state.
			if s_InVehicle and s_Controllable ~= nil and not s_Controllable:Is('ServerSoldierEntity') then
				s_Entry.pos = _Vec(s_Controllable.transform.trans)
				s_Entry.vehicle = l_Bot.m_ActiveVehicle and l_Bot.m_ActiveVehicle.Name or _VehicleName(s_Controllable)
				s_Entry.seat = s_Player.controlledEntryId
			else
				s_Entry.pos = _Vec(s_Soldier.worldTransform.trans)
			end
			s_Entry.yaw = _Round(l_Bot.m_Input.authoritativeAimingYaw, 3)
			s_Entry.pitch = _Round(l_Bot.m_Input.authoritativeAimingPitch, 3)
			s_Entry.health = _Round(s_Soldier.health, 1)
			s_Entry.pose = s_Soldier.pose
			s_Entry.stuck = l_Bot._ObstacleSequenceTimer ~= 0
			-- Rush: on to the MCOM while shooting (Bot:UpdatePushMovement).
			s_Entry.push = l_Bot._Pushing or nil
			-- Standing on purpose: defending, waiting on a node, executing an action, waiting for passengers.
			s_Entry.holding = l_Bot._DefendTimer > 0.0 or l_Bot._WayWaitTimer > 0.0 or l_Bot._VehicleWaitTimer > 0.0 or
				l_Bot._ActiveAction == BotActionFlags.OtherActionActive or (l_Bot.m_Zone ~= nil and l_Bot.m_Zone.Waiting)
			-- Free in the zone of the objective (BotZoneMovement): its name, and whether the bot is on its way out.
			if l_Bot.m_Zone ~= nil then
				s_Entry.zone = l_Bot.m_Zone.Zone.Name
				s_Entry.zoneExit = l_Bot.m_Zone.Exit ~= nil
			end
			-- Rush: left the combat area, waits at the border (Bot:OnCombatAreaLeft).
			s_Entry.border = l_Bot.m_Border ~= nil or nil

			local s_TargetPoint = l_Bot._TargetPoint
			if type(s_TargetPoint) == 'table' and s_TargetPoint.Position ~= nil then
				s_Entry.waypoint = _Vec(s_TargetPoint.Position)
			end
		end

		s_Result[#s_Result + 1] = s_Entry
	end

	return s_Result
end

---The real players.
---@return table
function DebugSnapshots.CollectPlayers()
	local s_Result = {}
	local s_Players = PlayerManager:GetPlayers()

	for l_Index = 1, #s_Players do
		local l_Player = s_Players[l_Index]
		if m_BotManager:GetBotById(l_Player.id) == nil then
			local s_Entry = {
				id = l_Player.id,
				name = l_Player.name,
				team = l_Player.teamId,
				squad = l_Player.squadId,
				alive = l_Player.soldier ~= nil,
			}

			local s_Soldier = l_Player.soldier
			if s_Soldier ~= nil then
				local s_Controllable = l_Player.controlledControllable
				if s_Controllable ~= nil and not s_Controllable:Is('ServerSoldierEntity') then
					s_Entry.pos = _Vec(s_Controllable.transform.trans)
					s_Entry.vehicle = _VehicleName(s_Controllable)
				else
					s_Entry.pos = _Vec(s_Soldier.worldTransform.trans)
				end
				s_Entry.health = _Round(s_Soldier.health, 1)

				local s_Input = l_Player.input
				if s_Input ~= nil then
					s_Entry.yaw = _Round(s_Input.authoritativeAimingYaw, 3)
					s_Entry.pitch = _Round(s_Input.authoritativeAimingPitch, 3)
				end
			end

			s_Result[#s_Result + 1] = s_Entry
		end
	end

	return s_Result
end

---All vehicles, also the empty ones. forward and velocity are world-vectors.
---@return table
function DebugSnapshots.CollectVehicles()
	local s_Result = {}
	local s_Iterator = EntityManager:GetIterator('ServerVehicleEntity')
	local s_Entity = s_Iterator:Next()

	while s_Entity ~= nil do
		local s_Vehicle = ControllableEntity(s_Entity)
		local s_Transform = s_Vehicle.transform
		local s_Name = _VehicleName(s_Vehicle)
		local s_Data = VehicleData[s_Name]

		local s_Occupants = {}
		for l_Entry = 0, s_Vehicle.entryCount - 1 do
			local s_Player = s_Vehicle:GetPlayerInEntry(l_Entry)
			if s_Player ~= nil then
				s_Occupants[#s_Occupants + 1] = { seat = l_Entry, id = s_Player.id }
			end
		end

		s_Result[#s_Result + 1] = {
			id = s_Vehicle.instanceId,
			name = s_Name,
			type = s_Data and s_Data.Type or nil,
			team = s_Vehicle.teamId,
			pos = _Vec(s_Transform.trans),
			forward = _Vec(s_Transform.forward),
			velocity = _Vec(PhysicsEntity(s_Vehicle).velocity),
			health = _Round(s_Vehicle.internalHealth, 1),
			occupants = s_Occupants,
		}

		s_Entity = s_Iterator:Next()
	end

	return s_Result
end

---Capture points (all modes, straight from the entities) and the MCOMs of rush (positions of the
---"mcom N interact" paths, state from the GameDirector).
---@return table { flags = { ... }, mcoms = { ... }, stage }
function DebugSnapshots.CollectObjectives()
	local s_Flags = {}
	local s_Translations = g_GameDirector.m_Translations
	local s_Iterator = EntityManager:GetIterator('ServerCapturePointEntity')
	local s_Entity = s_Iterator:Next()

	while s_Entity ~= nil do
		local s_CapturePoint = CapturePointEntity(s_Entity)
		-- Who is inside: the debug-server estimates the size of the zone from it (census/zones.py).
		local s_Inside = {}
		for _, l_Player in pairs(s_CapturePoint.playersInside) do
			s_Inside[#s_Inside + 1] = l_Player.id
		end
		s_Flags[#s_Flags + 1] = {
			name = s_CapturePoint.name,
			objective = s_Translations[s_CapturePoint.name],
			hq = m_Utilities:IsHq(s_CapturePoint),
			pos = _Vec(s_CapturePoint.transform.trans),
			team = s_CapturePoint.team,
			attacked = s_CapturePoint.isAttacked,
			controlled = s_CapturePoint.isControlled,
			flag = _Round(s_CapturePoint.flagLocation, 1),
			inside = s_Inside,
		}
		s_Entity = s_Iterator:Next()
	end

	local s_Mcoms = {}
	if Globals.IsRush then
		-- State of the objectives "mcom N" (the name-case is up to the waypoint-files).
		local s_States = {}
		local s_Objectives = g_GameDirector.m_AllObjectives
		for l_Index = 1, #s_Objectives do
			local l_Objective = s_Objectives[l_Index]
			local s_McomIndex = tonumber(l_Objective.name:lower():match('^mcom (%d+)$'))
			if s_McomIndex ~= nil then
				s_States[s_McomIndex] = l_Objective
			end
		end

		for l_McomIndex, l_Position in pairs(g_GameDirector._McomPositions) do
			local s_State = s_States[l_McomIndex]
			local s_Armed = s_State and g_GameDirector.m_ArmedMcoms[s_State.name]
			s_Mcoms[#s_Mcoms + 1] = {
				index = l_McomIndex,
				name = s_State and s_State.name or ('mcom ' .. l_McomIndex),
				pos = _Vec(l_Position),
				active = s_State ~= nil and s_State.active,
				destroyed = s_State ~= nil and s_State.destroyed,
				-- Seconds since it was armed.
				armed = s_Armed and _Round(s_Armed + g_GameDirector.m_UpdateTimer, 1) or nil,
			}
		end
		table.sort(s_Mcoms, function(p_A, p_B) return p_A.index < p_B.index end)
	end

	-- The ways to the vehicles: active while their vehicle is there (GameDirector:_SetVehicleObjectiveState).
	local s_Vehicles = {}
	local s_AllObjectives = g_GameDirector.m_AllObjectives
	for l_Index = 1, #s_AllObjectives do
		local l_Objective = s_AllObjectives[l_Index]
		if l_Objective.isEnterVehiclePath then
			s_Vehicles[#s_Vehicles + 1] = { name = l_Objective.name, active = l_Objective.active, team = l_Objective.team }
		end
	end

	return { flags = s_Flags, mcoms = s_Mcoms, vehicles = s_Vehicles, stage = g_GameDirector.m_RushStageCounter }
end

-- =============================================
-- Game-Events
-- =============================================

---@param p_LevelName string
---@param p_GameMode string
function DebugSnapshots:OnLevelLoaded(p_LevelName, p_GameMode)
	s_RoundStart = _Round(m_Utilities:GetTime(), 3)
	m_DebugBridge:Event('level_loaded', { level = p_LevelName, mode = p_GameMode })
end

---@param p_Player Player
---@param p_Inflictor Player|nil
---@param p_Position Vec3
---@param p_Weapon string
---@param p_IsRoadKill boolean
---@param p_IsHeadShot boolean
function DebugSnapshots:OnPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot)
	if not m_DebugBridge.m_Enabled then
		return
	end

	-- Kills with the weapons of vehicles come as weapon "Death": the vehicle of the killer tells which.
	local s_KillerVehicle = nil
	local s_KillerControllable = p_Inflictor and p_Inflictor.soldier ~= nil and p_Inflictor.controlledControllable
	if s_KillerControllable and not s_KillerControllable:Is('ServerSoldierEntity') then
		s_KillerVehicle = _VehicleName(s_KillerControllable)
	end

	m_DebugBridge:Event('kill', {
		victim = p_Player.id,
		victimTeam = p_Player.teamId,
		killer = p_Inflictor and p_Inflictor.id or -1,
		killerTeam = p_Inflictor and p_Inflictor.teamId or 0,
		killerVehicle = s_KillerVehicle,
		weapon = p_Weapon,
		pos = _Vec(p_Position),
		headshot = p_IsHeadShot,
		roadkill = p_IsRoadKill,
	})
end

if g_DebugSnapshots == nil then
	---@type DebugSnapshots
	g_DebugSnapshots = DebugSnapshots()
end

return g_DebugSnapshots
