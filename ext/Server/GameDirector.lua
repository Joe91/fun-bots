---@class GameDirector
---@overload fun():GameDirector
GameDirector = class('GameDirector')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Vehicles
local m_Vehicles = require("Vehicles")
---@type NavZones
local m_NavZones = require('NavZones')
---@type SpawnPoints
local m_SpawnPoints = require('SpawnPoints')
---@type DebugBridge
local m_DebugBridge = require('Debug/DebugBridge')
---@type Logger
local m_Logger = Logger("GameDirector", Debug.Server.GAMEDIRECTOR)

-- Coordinates of the nodes as plain numbers, per path: { Position, x, y, z, Position, x, y, z, ... }.
-- Reading x, y and z of a Vec3 costs ~0.4 µs each, too much for searches over all nodes of a map (50000 on big maps).
-- A node is re-read when its Position is another object than the cached one (positions are replaced, never changed).
local s_NodeCoords = {}

local function _AccessEntity(p_Entity)
	return p_Entity.data ~= nil
end

-- Accessing a destroyed entity raises an error, so probe it in protected mode.
local function _IsEntityValid(p_Entity)
	if p_Entity == nil then
		return false
	end
	local s_Ok, s_HasData = pcall(_AccessEntity, p_Entity)
	return s_Ok and s_HasData
end

-- Removes destroyed entities from a list in place and returns it.
local function _PruneInvalidEntities(p_List)
	if p_List == nil then
		return p_List
	end
	for l_Index = #p_List, 1, -1 do
		if not _IsEntityValid(p_List[l_Index]) then
			table.remove(p_List, l_Index)
		end
	end
	return p_List
end

-- Levels with a mesh: a vehicle is in a base (spawned into directly) if an HQ of its team is this close, without HQs
-- (rush) a spawn of the game of its team.
local VEHICLE_HQ_RANGE = 120.0
local VEHICLE_SPAWN_POINT_RANGE = 60.0

function GameDirector:__init()
	self:RegisterVars()
end

function GameDirector:RegisterVars()
	self.m_UpdateTimer = -1

	self.m_AllObjectives = {}
	self.m_Translations = {}
	self.m_ArmedMcoms = {}
	-- Who armed which MCOM ("mcom N" -> player id): the game names that player when it goes off (OnMcomDestroyedBy).
	self.m_ArmedBy = {}
	-- Since when all MCOMs of the stage count as destroyed (_UpdateTimersOfMcoms).
	self.m_StageDoneSince = nil
	self.m_ObjectivePositions = {}

	self.m_RushStageCounter = 0

	-- Vehicles a bot spawns for (ReserveVehicle): objective name -> { Bot = player id, Time = seconds }.
	self.m_VehicleReservations = {}
	-- Levels with a mesh: the objectives of the vehicles themselves, by name (_RefreshVehicleEntities).
	self.m_VehicleObjectives = {}
	-- MCOMs of the level: "mcom N" -> { Position, Stand, Yaw } or false (GetMcom), the positions of the engine.
	self.m_Mcoms = {}
	self.m_McomTries = {}
	self.m_EngineMcoms = nil

	self.m_SpawnableStationaryAas = {}
	-- Owning team of each stationary AA, by instanceId.
	self.m_StationaryAaTeams = {}
	-- Levels with a mesh: team of the vehicle-spawn of the engine each vehicle spawned at, by instanceId.
	self.m_VehicleSpawnTeams = {}
	self.m_SpawnableVehicles = {}
	self.m_MobileRespawnVehicles = {}
	self.m_AvailableVehicles = {}
	self.m_Beacons = {}
	self.m_Gunship = nil
	self.m_GunshipObjectiveName = nil
	self.m_GunshipObjectiveTeam = nil
	-- Gunship seat kept free for a player (comm-action), until the time runs out.
	self.m_GunshipReservedEntry = nil
	self.m_GunshipReservedUntil = 0.0

	self.m_MapCompletelyLoaded = false
	self.m_SpawnedEntitiesToProcess = {}

	self._AllCapturePoints = {}
	self._McomPositions = {}
	self._AllBases = {}
end

-- =============================================
-- Events.
-- =============================================

-- =============================================
-- Level Events.
-- =============================================

function GameDirector:OnLevelLoaded()
	self:_RegisterRushEventCallbacks()
	-- To-do: assign weights to each objective.
	self.m_UpdateTimer = 0
	if Globals.GameMode == "RushLarge0" then
		self.m_GunshipObjectiveTeam = TeamId.Team1 -- only attacking team has the gunship in rush
		self.m_GunshipObjectiveName = nil
	else
		self.m_GunshipObjectiveTeam = nil
		self.m_GunshipObjectiveName = self:GetGunshipObjectiveName(Globals.LevelName, Globals.GameMode)
	end



	for i = 0, Globals.NrOfTeams do
		self.m_SpawnableVehicles[i] = {}
		self.m_MobileRespawnVehicles[i] = {}
		self.m_SpawnableStationaryAas[i] = {}
		self.m_AvailableVehicles[i] = {}
	end
end

function GameDirector:OnLoadFinished()
	self.m_MapCompletelyLoaded = true
	-- parse all objectives
	self:_InitObjectives()
	-- update all already spawned vehicles (before the paths and objectives were ready)
	for l_Index = 1, #self.m_SpawnedEntitiesToProcess do
		local l_VehicleEntity = self.m_SpawnedEntitiesToProcess[l_Index]
		self:OnVehicleSpawnDone(l_VehicleEntity)
	end
	self.m_SpawnedEntitiesToProcess = {}
end

function GameDirector:OnLevelDestroy()
	self:RegisterVars()
	s_NodeCoords = {}
end

---VEXT Server Server:RoundOver Event
---@param p_RoundTime number
---@param p_WinningTeam TeamId|integer
function GameDirector:OnRoundOver(p_RoundTime, p_WinningTeam)
	self.m_UpdateTimer = -1
	self.m_Beacons = {}
	-- Vehicles of this round get destroyed, and their unspawn is ignored from now on.
	-- Not cleared on RoundReset, as vehicles of the next round might already be registered then.
	for l_Team = 0, Globals.NrOfTeams do
		self.m_SpawnableVehicles[l_Team] = {}
		self.m_MobileRespawnVehicles[l_Team] = {}
		self.m_SpawnableStationaryAas[l_Team] = {}
		self.m_AvailableVehicles[l_Team] = {}
	end
	self.m_StationaryAaTeams = {}
	self.m_Gunship = nil
	self.m_GunshipReservedEntry = nil
end

---VEXT Server Server:RoundReset Event
function GameDirector:OnRoundReset()
	self.m_AllObjectives = {}
	self.m_VehicleObjectives = {}
	self.m_Beacons = {}
	self.m_VehicleReservations = {}
	self.m_UpdateTimer = 0
end

-- =============================================
-- CapturePoint Events.
-- =============================================

---VEXT Server Player:EnteredCapturePoint Event
---@param p_Player Player
---@param p_CapturePoint CapturePointEntity|Entity
function GameDirector:OnPlayerEnterExitCapturePoint(p_Player, p_CapturePoint)
	p_CapturePoint = CapturePointEntity(p_CapturePoint)
	local s_ObjectiveName = self:_TranslateObjective(p_CapturePoint.transform.trans:Clone(), p_CapturePoint.name)
	self:_UpdateObjective(s_ObjectiveName, {
		isAttacked = p_CapturePoint.isAttacked
	})
end

---VEXT Server CapturePoint:Captured Event
---@param p_CapturePoint CapturePointEntity|Entity
function GameDirector:OnCapturePointCaptured(p_CapturePoint)
	p_CapturePoint = CapturePointEntity(p_CapturePoint)
	local s_ObjectiveName = self:_TranslateObjective(p_CapturePoint.transform.trans:Clone(), p_CapturePoint.name)
	self:_UpdateObjective(s_ObjectiveName, {
		team = p_CapturePoint.team,
		isAttacked = p_CapturePoint.isAttacked
	})

	if self.m_GunshipObjectiveName ~= nil
		and p_CapturePoint.name == self.m_GunshipObjectiveName
	then
		self.m_GunshipObjectiveTeam = p_CapturePoint.team;
		m_Logger:Write("Gunship capture point captured: " .. p_CapturePoint.name)
	end

	m_Logger:Write('GameDirector:_onCapture: ' .. s_ObjectiveName)
end

---VEXT Server CapturePoint:Lost Event
---@param p_CapturePoint CapturePointEntity|Entity
function GameDirector:OnCapturePointLost(p_CapturePoint)
	p_CapturePoint = CapturePointEntity(p_CapturePoint)
	local s_ObjectiveName = self:_TranslateObjective(p_CapturePoint.transform.trans:Clone(), p_CapturePoint.name)
	local s_IsAttacked = p_CapturePoint.flagLocation < 100.0 and p_CapturePoint.isControlled
	self:_UpdateObjective(s_ObjectiveName, {
		team = TeamId.TeamNeutral, -- p_CapturePoint.team
		isAttacked = s_IsAttacked
	})

	m_Logger:Write('GameDirector:_onLost: ' .. s_ObjectiveName)
end

---VEXT Shared Engine:Update Event
---@param p_DeltaTime number
function GameDirector:OnEngineUpdate(p_DeltaTime)
	if self.m_UpdateTimer >= 0 then
		self.m_UpdateTimer = self.m_UpdateTimer + p_DeltaTime
	end

	if self.m_UpdateTimer < Registry.GAME_DIRECTOR.UPDATE_OBJECTIVES_CYCLE then
		return
	end

	-- g_Profiler:Start("GameDirector:Update1")

	if Globals.IsRush then
		self:_UpdateTimersOfMcoms(self.m_UpdateTimer)
	end
	self:_RefreshVehicleObjectives()

	self.m_UpdateTimer = 0

	-- Update bot → team list.
	local s_BotList = g_BotManager:GetBots()
	local s_BotsByTeam = {}

	local s_BotStates = g_BotStates
	for i = 1, #s_BotList do
		local l_Bot = s_BotList[i]
		if not l_Bot:IsInactive() and l_Bot.m_Player ~= nil then
			if s_BotsByTeam[l_Bot.m_Player.teamId] == nil then
				s_BotsByTeam[l_Bot.m_Player.teamId] = {}
			end

			s_BotsByTeam[l_Bot.m_Player.teamId][#s_BotsByTeam[l_Bot.m_Player.teamId] + 1] = l_Bot
			l_Bot:UpdateBorder()
			self:_CheckProgressOffMesh(l_Bot)
			self:_CheckObjectiveProgress(l_Bot)
			self:_CheckVehicleProgress(l_Bot)
		end
	end

	-- g_Profiler:End("GameDirector:Update1")
	-- g_Profiler:Start("GameDirector:Update2")

	local s_MaxAssignsAttack = {}
	local s_MaxAssignsDefend = {}
	-- Evaluate how many bots are max- and min-assigned per objective.

	local s_AvailableObjectivesAttack = {}
	local s_AvailableObjectivesDefend = {}

	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if not l_Objective.subObjective and not l_Objective.isBase and l_Objective.active and not l_Objective.destroyed and
			not l_Objective.isEnterVehiclePath then
			for i = 1, Globals.NrOfTeams do
				if s_AvailableObjectivesAttack[i] == nil or s_AvailableObjectivesDefend[i] == nil then
					s_AvailableObjectivesAttack[i] = 0
					s_AvailableObjectivesDefend[i] = 0
				end

				if l_Objective.team ~= i then
					s_AvailableObjectivesAttack[i] = s_AvailableObjectivesAttack[i] + 1
				end
				if l_Objective.team == i then
					s_AvailableObjectivesDefend[i] = s_AvailableObjectivesDefend[i] + 1
				end
			end
		end
	end

	for i = 1, Globals.NrOfTeams do
		s_MaxAssignsAttack[i] = 0
		s_MaxAssignsDefend[i] = 0

		if s_AvailableObjectivesAttack[i] == nil then
			s_AvailableObjectivesAttack[i] = 0
		end

		if s_AvailableObjectivesDefend[i] == nil then
			s_AvailableObjectivesDefend[i] = 0
		end

		-- apply weight to attack-objectives
		local s_TotalObjectivesBalanced = s_AvailableObjectivesAttack[i] * Registry.GAME_DIRECTOR.WEIGHT_ATTACK_OBJECTIVE +
			s_AvailableObjectivesDefend[i] * Registry.GAME_DIRECTOR.WEIGHT_DEFEND_OBJECTIVE

		-- assign bots to the objectives
		-- number of bots / weighted objective-count = bots per weight-unit
		if s_BotsByTeam[i] ~= nil then
			if s_TotalObjectivesBalanced > 0 then
				local s_BotsPerWeightObjective = #s_BotsByTeam[i] / s_TotalObjectivesBalanced
				s_MaxAssignsAttack[i] = math.floor((s_BotsPerWeightObjective * Registry.GAME_DIRECTOR.WEIGHT_ATTACK_OBJECTIVE) + 0.999)
				s_MaxAssignsDefend[i] = math.floor((s_BotsPerWeightObjective * Registry.GAME_DIRECTOR.WEIGHT_DEFEND_OBJECTIVE) + 0.999)
				if s_MaxAssignsDefend[i] == 0 then
					s_MaxAssignsDefend[i] = 1
				end
				if s_MaxAssignsAttack[i] == 0 then
					s_MaxAssignsAttack[i] = 1
				end
			else
				-- No objectives available -> assign nothing
				s_MaxAssignsAttack[i] = 0
				s_MaxAssignsDefend[i] = 0
			end

			if s_AvailableObjectivesAttack[i] == 0 then
				s_MaxAssignsAttack[i] = 0
			end
			if s_AvailableObjectivesDefend[i] == 0 then
				s_MaxAssignsDefend[i] = 0
			end
			-- DEBUG
			m_Logger:Write("maxBots Team " .. i .. ": " .. tostring(s_MaxAssignsAttack[i]) .. " - " .. tostring(s_MaxAssignsDefend[i]))
		end
	end

	-- Check objective statuses.
	-- Clear assigned-count on every cycle first
	-- s_BotsByTeam is keyed by team ID and has holes for teams without bots,
	-- so iterate over all teams instead of using #s_BotsByTeam.
	for l_BotTeam = 1, Globals.NrOfTeams do
		for l_Index = 1, #self.m_AllObjectives do
			local l_Objective = self.m_AllObjectives[l_Index]
			l_Objective.assigned[l_BotTeam] = 0
		end
		-- Vehicles first: one bot per free seat, also if it comes later in the list than the bot that gets a new one.
		local l_Bots = s_BotsByTeam[l_BotTeam] or {}
		for l_Index = 1, #l_Bots do
			local s_Objective = self:_GetObjectiveObject(l_Bots[l_Index]:GetObjective())
			if s_Objective ~= nil and s_Objective.isEnterVehiclePath then
				s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] + 1
			end
		end
	end
	-- Reserved vehicles are taken as well, by the bot that spawns for them.
	for l_Name, _ in pairs(self:_GetVehicleReservations()) do
		local s_Objective = self:_GetObjectiveObject(l_Name)
		if s_Objective ~= nil and s_Objective.team >= 1 and s_Objective.team <= Globals.NrOfTeams then
			s_Objective.assigned[s_Objective.team] = s_Objective.assigned[s_Objective.team] + 1
		end
	end

	-- g_Profiler:End("GameDirector:Update2")
	-- g_Profiler:Start("GameDirector:Update3")

	for l_BotTeam = 1, Globals.NrOfTeams do
		local l_Bots = s_BotsByTeam[l_BotTeam] or {}
		for l_Index0 = 1, #l_Bots do
			local l_Bot = l_Bots[l_Index0]
			local s_BotObjective = l_Bot:GetObjective()
			if s_BotObjective == '' or s_BotObjective == nil then -- no active objective of bot
				if l_Bot.m_Player.soldier == nil then
					goto continue_with_next_bot
				end

				-- Spawned for a vehicle (ReserveVehicle): that one, once the bot is on the mesh.
				local s_Reserved = self:GetReservedVehicle(l_Bot)
				if s_Reserved ~= nil then
					if not s_Reserved.active or s_Reserved.destroyed
						or (l_Bot.m_Zone ~= nil and not l_Bot:CanReach(s_Reserved.name)) then
						-- Taken by someone else meanwhile, or no way leads there from the spawn (a boat at the shore, the
						-- bot spawned on the ship).
						self.m_VehicleReservations[s_Reserved.name] = nil
					else
						if l_Bot:SetObjectiveIfPossible(s_Reserved.name, BotObjectiveModes.Attack) then
							self.m_VehicleReservations[s_Reserved.name] = nil
							m_Logger:Write(l_Bot.m_Player.name .. " spawned for " .. s_Reserved.name .. " and goes there")
						end
						goto continue_with_next_bot
					end
				end

				-- Find the closest objective for bot.
				local s_ClosestDistance = nil
				local s_ClosestObjective = nil
				local s_ClosestObjectiveMode = BotObjectiveModes.Default

				-- loop through all objectives
				for l_Index1 = 1, #self.m_AllObjectives do
					local l_Objective = self.m_AllObjectives[l_Index1]
					if l_Objective.subObjective then
						goto continue_with_next_objective
					end

					if l_Objective.isBase or not l_Objective.active or l_Objective.destroyed then
						goto continue_with_next_objective
					end

					-- Assign vehicle-objectives if possible. Only close ones: with the navigation paths (NavRoutes) a bot gets
					-- to any vehicle, also to one at a spawn far behind the front.
					if Config.UseVehicles and
						l_Objective.isEnterVehiclePath and
						(l_Objective.team == l_BotTeam or (l_Objective.isVehicleEntity and l_Objective.team == TeamId.TeamNeutral)) and
						l_Objective.assigned[l_BotTeam] < (l_Objective.seats or 1) and
						-- Also idle: just spawned, it gets its first objective before it may move.
						(s_BotStates:IsSoldierState(l_Bot.m_ActiveState) or l_Bot.m_ActiveState == s_BotStates.States.Idle) and
						self:_GetDistanceFromObjective(l_Objective.name, l_Bot.m_Player.soldier.worldTransform.trans)
						<= Registry.GAME_DIRECTOR.MAX_VEHICLE_OBJECTIVE_DISTANCE and
						-- A way leads there (last: the route costs most).
						(m_NavZones:GetMesh() == nil or l_Bot:CanReach(l_Objective.name)) then
						if l_Bot:SetObjectiveIfPossible(l_Objective.name, BotObjectiveModes.Attack) then
							l_Objective.assigned[l_BotTeam] = l_Objective.assigned[l_BotTeam] + 1
							m_Logger:Write("assigned bot to " .. l_Objective.name)
							goto continue_with_next_bot
						end
					end
					if l_Objective.isEnterVehiclePath then
						goto continue_with_next_objective
					end

					-- defend can also be a valid objective
					if l_Objective.team == l_BotTeam and Config.DefendObjectives then
						if l_Objective.assigned[l_BotTeam] < s_MaxAssignsDefend[l_BotTeam] then
							local s_Distance = self:_GetDistanceFromObjective(l_Objective.name, l_Bot.m_Player.soldier.worldTransform.trans:Clone())

							if (s_ClosestDistance == nil or s_ClosestDistance > s_Distance) and self:_CanReach(l_Bot, l_Objective.name) then
								s_ClosestDistance = s_Distance
								s_ClosestObjective = l_Objective.name
								s_ClosestObjectiveMode = BotObjectiveModes.Defend
							end
						end
					elseif l_Objective.team ~= l_BotTeam then -- objective of enemy-team
						if l_Objective.assigned[l_BotTeam] < s_MaxAssignsAttack[l_BotTeam] then
							local s_Distance = self:_GetDistanceFromObjective(l_Objective.name, l_Bot.m_Player.soldier.worldTransform.trans:Clone())

							if (s_ClosestDistance == nil or s_ClosestDistance > s_Distance) and self:_CanReach(l_Bot, l_Objective.name) then
								s_ClosestDistance = s_Distance
								s_ClosestObjective = l_Objective.name
								s_ClosestObjectiveMode = BotObjectiveModes.Attack
							end
						end
					end

					::continue_with_next_objective::
				end

				if s_ClosestObjective ~= nil then
					local s_Objective = self:_GetObjectiveObject(s_ClosestObjective)
					l_Bot:SetObjective(s_ClosestObjective, s_ClosestObjectiveMode)
					m_Logger:Write("Team " ..
						tostring(l_BotTeam) .. " with " .. l_Bot.m_Player.name .. " gets this objective: " .. s_ClosestObjective)
					---@diagnostic disable-next-line: need-check-nil
					s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] + 1
				end
			else          -- bot already has an objective
				if not l_Bot.m_Player.soldier then
					l_Bot:SetObjective() -- Reset objective on death.
					goto continue_with_next_bot
				end

				local s_Objective = self:_GetObjectiveObject(l_Bot:GetObjective())
				local s_ObjectiveMode = l_Bot:GetObjectiveMode()

				if s_Objective == nil then
					goto continue_with_next_bot
				end

				if s_Objective.isEnterVehiclePath then
					if not s_Objective.active or s_Objective.destroyed or s_BotStates:IsInVehicleState(l_Bot.m_ActiveState) then
						l_Bot:SetObjective()
					end

					goto continue_with_next_bot
				end


				local s_ParentObjective = self:_GetObjectiveFromSubObj(s_Objective.name)
				s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] + 1

				if s_ParentObjective ~= nil then
					local s_TempObjective = self:_GetObjectiveObject(s_ParentObjective)
					if s_TempObjective then
						if s_TempObjective.active and not s_TempObjective.destroyed then
							s_TempObjective.assigned[l_BotTeam] = s_TempObjective.assigned[l_BotTeam] + 1

							-- Check for leave of subObjective.
							if not self:_UseSubobjective(l_BotTeam, s_Objective.name) then
								l_Bot:SetObjective(s_ParentObjective)
							end
						end
					end
				end

				-- remove bots, if too many defenders
				if s_ObjectiveMode == BotObjectiveModes.Defend then
					if s_Objective.team == l_BotTeam then
						if s_Objective.assigned[l_BotTeam] > s_MaxAssignsDefend[l_BotTeam] then
							s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] - 1
							l_Bot:SetObjective()
						end
					else
						s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] - 1
						l_Bot:SetObjective()
					end
				end

				if s_ObjectiveMode ~= BotObjectiveModes.Defend then
					if s_Objective.team ~= l_BotTeam then
						if s_Objective.assigned[l_BotTeam] > s_MaxAssignsAttack[l_BotTeam] then
							s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] - 1
							l_Bot:SetObjective()
						end
					else
						s_Objective.assigned[l_BotTeam] = s_Objective.assigned[l_BotTeam] - 1
						l_Bot:SetObjective()
					end
				end

				-- remove from invalid objectives
				if s_Objective.isBase or not s_Objective.active or s_Objective.destroyed then
					l_Bot:SetObjective()
				end
				-- remove from enter vehicle, when enter is done
				if s_Objective.team == l_BotTeam and s_Objective.isEnterVehiclePath and s_BotStates:IsInVehicleState(l_Bot.m_ActiveState) then
					l_Bot:SetObjective()
				end
			end

			::continue_with_next_bot::
		end
	end
	-- g_Profiler:End("GameDirector:Update3")
end

-- Seconds a vehicle stays reserved for the bot that spawns for it, until the bot is on the mesh and takes it.
local VEHICLE_RESERVATION_TIME = 15.0

---The reservations that are not timed out (ReserveVehicle).
---@return table<string, { Bot: integer, Time: number }>
function GameDirector:_GetVehicleReservations()
	local s_Now = m_Utilities:GetTime()
	for l_Name, l_Reservation in pairs(self.m_VehicleReservations) do
		if s_Now - l_Reservation.Time > VEHICLE_RESERVATION_TIME then
			self.m_VehicleReservations[l_Name] = nil
		end
	end
	return self.m_VehicleReservations
end

---Whether the bot gets to the objective. On the mesh only if a route leads there from where it is (a soldier on the ship
---of the attackers only gets to the boats), else it waits there for one it gets to.
---@param p_Bot Bot
---@param p_Objective string
---@return boolean
function GameDirector:_CanReach(p_Bot, p_Objective)
	return p_Bot.m_Zone == nil or m_NavZones:GetMesh() == nil or p_Bot:CanReach(p_Objective)
end

---@param p_Bot Bot
---@return table|nil the vehicle-objective reserved for the bot
function GameDirector:GetReservedVehicle(p_Bot)
	for l_Name, l_Reservation in pairs(self:_GetVehicleReservations()) do
		if l_Reservation.Bot == p_Bot.m_Player.id then
			return self:_GetObjectiveObject(l_Name)
		end
	end
	return nil
end

---A free vehicle of the team (its objective is active, no bot has it or spawns for it), reserved for the bot: it spawns
---at the spawn of the game next to it (BotSpawner) and gets it as objective once it is on the mesh (OnEngineUpdate).
---@param p_Bot Bot
---@return Vec3|nil the start of the way to the vehicle
function GameDirector:ReserveVehicle(p_Bot)
	if not Config.UseVehicles or p_Bot.m_Player == nil or g_NavRoutes == nil then
		return nil
	end
	local s_TeamId = p_Bot.m_Player.teamId
	local s_Taken = {}
	for l_Name, _ in pairs(self:_GetVehicleReservations()) do
		s_Taken[l_Name] = true
	end
	local s_Bots = g_BotManager:GetBots()
	for l_Index = 1, #s_Bots do
		s_Taken[s_Bots[l_Index]:GetObjective()] = true
	end
	local s_Spawns = self:_TeamSpawnPositions(s_TeamId)

	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		-- Not the vehicles bots spawn in directly ("spawn vehicle ...").
		-- Not the vehicles in a base either: every bot that spawns gets into those directly (BotSpawner), the one that
		-- spawned for it in the base would find it taken.
		if l_Objective.isEnterVehiclePath and not l_Objective.isSpawnPath
			and (l_Objective.team == s_TeamId or (l_Objective.isVehicleEntity and l_Objective.team == TeamId.TeamNeutral))
			and l_Objective.active and not l_Objective.destroyed and not s_Taken[l_Objective.name]
			and (l_Objective.entity == nil or _IsEntityValid(l_Objective.entity))
			and not (l_Objective.entity ~= nil and self.m_SpawnableVehicles[s_TeamId] ~= nil
				and self:IsEntityInVehicleCollection(self.m_SpawnableVehicles, s_TeamId, l_Objective.entity))
			and g_NavRoutes:Knows(l_Objective.name) then
			local s_Position = self:_GetObjectivePosition(l_Objective.name)
			-- Only next to a spawn of the team: the bot spawns at the one closest to it (a boat the attackers left at the
			-- shore is far from their ship).
			local s_Near = false
			if s_Position ~= nil then
				for l_Spawn = 1, #s_Spawns do
					if s_Spawns[l_Spawn]:Distance(s_Position) <= Registry.GAME_DIRECTOR.MAX_VEHICLE_OBJECTIVE_DISTANCE then
						s_Near = true
						break
					end
				end
			end
			if s_Near and s_Position ~= nil then
				self.m_VehicleReservations[l_Objective.name] = { Bot = p_Bot.m_Player.id, Time = m_Utilities:GetTime() }
				return s_Position
			end
		end
	end
	return nil
end

-- Passengers this far from the vehicle (on the mesh to it) are waited for.
local PASSENGER_WAIT_RANGE = 80.0

---Whether bots of the team are on foot on their way to get into the vehicle (its objective "vehicle <id>").
---@param p_Entity ControllableEntity|nil
---@param p_TeamId TeamId|integer
---@return boolean
function GameDirector:PassengersComing(p_Entity, p_TeamId)
	if p_Entity == nil then
		return false
	end
	local s_Name = 'vehicle ' .. tostring(p_Entity.instanceId)
	local s_Position = p_Entity.transform.trans
	local s_Bots = g_BotManager:GetBots()
	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		local s_Soldier = l_Bot.m_Player.soldier
		if l_Bot.m_Player.teamId == p_TeamId and l_Bot:GetObjective() == s_Name and s_Soldier ~= nil
			and l_Bot.m_ActiveVehicle == nil and s_Soldier.worldTransform.trans:Distance(s_Position) <= PASSENGER_WAIT_RANGE then
			return true
		end
	end
	return false
end

---Where the team can spawn now (ReserveVehicle): in rush the soldier-spawns of the team that are on (the stage), else
---the capture points and HQs the team holds.
---@param p_TeamId TeamId|integer
---@return Vec3[]
function GameDirector:_TeamSpawnPositions(p_TeamId)
	local s_Result = {}
	if Globals.IsRush then
		local s_Iterator = EntityManager:GetIterator('ServerCharacterSpawnEntity')
		local s_Entity = s_Iterator:Next()
		while s_Entity ~= nil do
			if s_Entity.data:Is('CharacterSpawnReferenceObjectData')
				and CharacterSpawnReferenceObjectData(s_Entity.data).team == p_TeamId and SpawnEntity(s_Entity).enabled then
				s_Result[#s_Result + 1] = SpawnEntity(s_Entity).transform.trans:Clone()
			end
			s_Entity = s_Iterator:Next()
		end
		return s_Result
	end
	for _, l_List in ipairs({ self._AllBases or {}, self._AllCapturePoints or {} }) do
		for l_Index = 1, #l_List do
			local l_CapturePoint = l_List[l_Index]
			local s_Ok, s_Position = pcall(function()
				return l_CapturePoint.team == p_TeamId and l_CapturePoint.isControlled
					and l_CapturePoint.transform.trans:Clone() or nil
			end)
			if s_Ok and s_Position ~= nil then
				s_Result[#s_Result + 1] = s_Position
			end
		end
	end
	return s_Result
end

-- Rush: a spawn this many metres farther from the MCOMs than the most forward spawn of the team is behind (the base of a
-- stage that fell: the game still offers it). The bot is moved to a forward spawn (ForwardSpawn).
local FORWARD_SPAWN_MARGIN = 100.0
-- Among the forward spawns: the ones up to this much farther than the best one.
local FORWARD_SPAWN_CHOICE = 30.0

---Rush: where a bot that spawned at p_Position starts instead, if the game spawned it far behind the front (players
---can choose the base of the first stage as long as it is on, the engine picks it for bots now and then): one of the
---most forward spawns of the team, on the ground. nil if p_Position is fine.
---@param p_TeamId TeamId|integer
---@param p_Position Vec3
---@return Vec3|nil
function GameDirector:ForwardSpawn(p_TeamId, p_Position)
	if not Globals.IsRush then
		return nil
	end
	local s_Targets = self:GetActiveMcomPositions()
	if #s_Targets == 0 then
		return nil
	end
	local function _Distance(p_Pos)
		local s_Best = math.huge
		for l_Index = 1, #s_Targets do
			local s_DeltaX = s_Targets[l_Index].x - p_Pos.x
			local s_DeltaZ = s_Targets[l_Index].z - p_Pos.z
			s_Best = math.min(s_Best, math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ))
		end
		return s_Best
	end
	local s_Spawns = self:_TeamSpawnPositions(p_TeamId)
	local s_Best = math.huge
	for l_Index = 1, #s_Spawns do
		s_Best = math.min(s_Best, _Distance(s_Spawns[l_Index]))
	end
	if s_Best == math.huge or _Distance(p_Position) <= s_Best + FORWARD_SPAWN_MARGIN then
		return nil
	end
	local s_Choice = {}
	for l_Index = 1, #s_Spawns do
		if _Distance(s_Spawns[l_Index]) <= s_Best + FORWARD_SPAWN_CHOICE then
			s_Choice[#s_Choice + 1] = s_Spawns[l_Index]
		end
	end
	local s_Spawn = s_Choice[MathUtils:GetRandomInt(1, #s_Choice)]
	-- Spawn-entities may float above the ground (40 m on XP5_004): the soldier stands on the ground below.
	local s_Flags = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.DontCheckWater
	---@cast s_Flags RayCastFlags
	local s_Hit = RaycastManager:CollisionRaycast(s_Spawn + Vec3(0, 1.0, 0), s_Spawn - Vec3(0, 60.0, 0), 1, 0, s_Flags)[1]
	return s_Hit ~= nil and s_Hit.position + Vec3(0, 0.1, 0) or s_Spawn
end

---Off the mesh a soldier walks a navigation path to its end, or the way to its objective (a vehicle, an MCOM to arm). If
---it doesn't get closer to where it walks to for a while, it is stuck there (walks a dead end back and forth, can't get
---past something): onto the mesh close by, later it respawns. Not while it fights, waits or does an action.
---@param p_Bot Bot
function GameDirector:_CheckProgressOffMesh(p_Bot)
	local s_Soldier = p_Bot.m_Player.soldier
	if s_Soldier == nil or p_Bot.m_Zone ~= nil or m_NavZones:GetMesh() == nil or g_NavRoutes == nil
		or p_Bot.m_Border ~= nil -- Waits at the border of the combat area.
		or g_BotStates:IsInVehicleState(p_Bot.m_ActiveState) or g_BotStates:IsStaticState(p_Bot.m_ActiveState)
		or p_Bot._FollowTargetPlayer ~= nil or p_Bot._ActiveAction == BotActionFlags.OtherActionActive then
		p_Bot._KillYourselfTimer = 0.0
		p_Bot._OffMeshTarget = nil
		return
	end

	-- Where it walks to: the next node of the routes on its path (an end, a link, a junction), else its objective. The
	-- time counts per path (or objective): a bot that turns around on it again and again (skipping waypoints it can't
	-- reach) doesn't start anew.
	local s_End = g_NavRoutes:Heading(p_Bot._PathIndex, p_Bot._CurrentWayPoint, p_Bot._InvertPathDirection)
	local s_Key = nil
	local s_Target = nil
	if s_End ~= nil then
		s_Key = 'path ' .. p_Bot._PathIndex
		s_Target = s_End.Position
	else
		s_Key = p_Bot:GetObjective()
		s_Target = self:_GetObjectivePosition(s_Key)
	end
	if s_Target == nil then
		p_Bot._KillYourselfTimer = 0.0
		p_Bot._OffMeshTarget = nil
		return
	end
	if s_Key ~= p_Bot._OffMeshTarget then
		p_Bot._OffMeshTarget = s_Key
		p_Bot._OffMeshEnd = s_End
		p_Bot._OffMeshBestDistance = math.huge
		p_Bot._KillYourselfTimer = 0.0
	elseif s_End ~= p_Bot._OffMeshEnd then
		-- Turned around on the path: closer to the other end from now on, the time goes on.
		p_Bot._OffMeshEnd = s_End
		p_Bot._OffMeshBestDistance = s_Target:Distance(s_Soldier.worldTransform.trans)
	end

	local s_Distance = s_Target:Distance(s_Soldier.worldTransform.trans)
	if s_Distance < p_Bot._OffMeshBestDistance - Registry.GAME_DIRECTOR.OFF_MESH_MIN_PROGRESS then
		p_Bot._OffMeshBestDistance = s_Distance
		p_Bot._KillYourselfTimer = 0.0
		return
	end
	if p_Bot._ShootPlayer ~= nil or p_Bot._WayWaitTimer > 0.0 then
		return
	end
	p_Bot._KillYourselfTimer = p_Bot._KillYourselfTimer + Registry.GAME_DIRECTOR.UPDATE_OBJECTIVES_CYCLE

	-- The stretch of the path it got stuck on costs more for all bots from now on (once per bot and path).
	if p_Bot._KillYourselfTimer > Registry.GAME_DIRECTOR.OFF_MESH_TELEPORT_TIME and s_End ~= nil
		and p_Bot._OffMeshBlocked ~= s_Key and g_NavRoutes:BlockStretch(p_Bot._PathIndex, p_Bot._CurrentWayPoint) then
		p_Bot._OffMeshBlocked = s_Key
		if m_DebugBridge.m_Enabled then
			local s_Here = s_Soldier.worldTransform.trans
			m_DebugBridge:Event('path_stuck', { bot = p_Bot.m_Player.name, path = p_Bot._PathIndex,
				point = p_Bot._CurrentWayPoint, pos = { s_Here.x, s_Here.y, s_Here.z } })
		end
	end
	if Config.TeleportIfStuck and p_Bot._KillYourselfTimer > Registry.GAME_DIRECTOR.OFF_MESH_TELEPORT_TIME
		and p_Bot:TeleportToMesh(Registry.GAME_DIRECTOR.OFF_MESH_TELEPORT_RANGE) then
		p_Bot._KillYourselfTimer = 0.0
		m_Logger:Write("teleport " .. p_Bot.m_Player.name .. " onto the mesh, it got stuck off the mesh")
	elseif p_Bot._KillYourselfTimer > Registry.GAME_DIRECTOR.OFF_MESH_KILL_TIME then
		p_Bot.m_DontRevive = true
		s_Soldier:Kill()
		p_Bot._KillYourselfTimer = 0.0
		m_Logger:Write("kill " .. p_Bot.m_Player.name .. ", it got stuck off the mesh")
	end
end

---The last resort for anything the mesh, the paths and the other checks don't catch (a way that leads out of the
---combat area again and again, a loop, an area the bot can't leave): a bot on foot that doesn't get
---OBJECTIVE_PROGRESS_MIN metres closer to its objective for OBJECTIVE_PROGRESS_TIME seconds respawns. Not close to the
---objective (it holds it, walks around in its zone), not while it fights, waits, sits in a vehicle or does an action.
---@param p_Bot Bot
function GameDirector:_CheckObjectiveProgress(p_Bot)
	local s_Soldier = p_Bot.m_Player.soldier
	local s_Objective = p_Bot:GetObjective()
	local s_Registry = Registry.GAME_DIRECTOR
	if s_Soldier == nil or s_Objective == nil or s_Objective == ''
		or g_BotStates:IsInVehicleState(p_Bot.m_ActiveState) or g_BotStates:IsStaticState(p_Bot.m_ActiveState)
		or p_Bot._ActiveAction == BotActionFlags.OtherActionActive or p_Bot._FollowTargetPlayer ~= nil then
		p_Bot._ProgressObjective = nil
		return
	end
	local s_Distance = self:_GetDistanceFromObjective(s_Objective, s_Soldier.worldTransform.trans)
	if s_Distance == math.huge or s_Distance < s_Registry.OBJECTIVE_PROGRESS_NEAR then
		p_Bot._ProgressObjective = nil
		return
	end
	-- In the zone of its objective (a big capture point: it holds it at the edge).
	local s_Parent = s_Objective:find('interact', 1, true) and self:_GetObjectiveFromSubObj(s_Objective) or nil
	local s_Zone = m_NavZones:GetZone(s_Parent or s_Objective)
	if s_Zone ~= nil and p_Bot.m_Zone ~= nil and s_Zone.InsideSet[p_Bot.m_Zone.Point] then
		p_Bot._ProgressObjective = nil
		return
	end
	if p_Bot._ProgressObjective ~= s_Objective or s_Distance < p_Bot._ProgressBest - s_Registry.OBJECTIVE_PROGRESS_MIN then
		p_Bot._ProgressObjective = s_Objective
		p_Bot._ProgressBest = s_Distance
		p_Bot._ProgressTime = 0.0
		return
	end
	if p_Bot._ShootPlayer ~= nil or p_Bot._WayWaitTimer > 0.0 then
		return
	end
	p_Bot._ProgressTime = p_Bot._ProgressTime + s_Registry.UPDATE_OBJECTIVES_CYCLE
	if p_Bot._ProgressTime < s_Registry.OBJECTIVE_PROGRESS_TIME then
		return
	end
	p_Bot._ProgressObjective = nil
	-- The way it was on costs more for all bots (off the mesh: the stretch of its path).
	if p_Bot.m_Zone == nil and g_NavRoutes ~= nil then
		g_NavRoutes:BlockStretch(p_Bot._PathIndex, p_Bot._CurrentWayPoint)
	end
	m_Logger:Write("respawn " .. p_Bot.m_Player.name .. ", no progress towards " .. s_Objective)
	if m_DebugBridge.m_Enabled then
		local s_Here = s_Soldier.worldTransform.trans
		m_DebugBridge:Event('no_progress', { bot = p_Bot.m_Player.name, objective = s_Objective,
			pos = { s_Here.x, s_Here.y, s_Here.z }, zone = p_Bot.m_Zone ~= nil and p_Bot.m_Zone.Zone.Name or nil })
	end
	p_Bot._RespawnAway = s_Soldier.worldTransform.trans:Clone()
	p_Bot.m_DontRevive = true
	s_Soldier:Kill()
end

---A ground vehicle whose driver doesn't get VEHICLE_PROGRESS_MIN metres away from where it was for
---VEHICLE_PROGRESS_TIME seconds is stuck (in terrain, on a rock, flipped, against a wall the obstacle handling doesn't
---get past): all bots in it get out and go on foot. Not while the driver waits for passengers, nor close to its
---objective (it holds the capture point).
---@param p_Bot Bot
function GameDirector:_CheckVehicleProgress(p_Bot)
	local s_Vehicle = p_Bot.m_Player.controlledControllable
	local s_Registry = Registry.GAME_DIRECTOR
	if s_Vehicle == nil or p_Bot.m_Player.soldier == nil or p_Bot.m_Player.controlledEntryId ~= 0
		or not g_BotStates:IsInVehicleState(p_Bot.m_ActiveState) or p_Bot.m_ActiveVehicle == nil
		or m_Vehicles:IsAirVehicle(p_Bot.m_ActiveVehicle)
		or m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.StationaryAA)
		or m_Vehicles:IsVehicleType(p_Bot.m_ActiveVehicle, VehicleTypes.Gadgets)
		or p_Bot._VehicleWaitTimer > 0.0 then
		p_Bot._VehicleAnchor = nil
		return
	end
	local s_Position = s_Vehicle.transform.trans
	local s_Objective = p_Bot:GetObjective()
	if s_Objective ~= nil and s_Objective ~= ''
		and self:_GetDistanceFromObjective(s_Objective, s_Position) < s_Registry.OBJECTIVE_PROGRESS_NEAR then
		p_Bot._VehicleAnchor = nil
		return
	end
	if p_Bot._VehicleAnchor == nil or p_Bot._VehicleAnchor:Distance(s_Position) > s_Registry.VEHICLE_PROGRESS_MIN then
		p_Bot._VehicleAnchor = s_Position:Clone()
		p_Bot._VehicleStuckTime = 0.0
		return
	end
	p_Bot._VehicleStuckTime = p_Bot._VehicleStuckTime + s_Registry.UPDATE_OBJECTIVES_CYCLE
	if p_Bot._VehicleStuckTime < s_Registry.VEHICLE_PROGRESS_TIME then
		return
	end
	p_Bot._VehicleAnchor = nil
	m_Logger:Write("vehicle of " .. p_Bot.m_Player.name .. " stuck, everybody out")
	if m_DebugBridge.m_Enabled then
		m_DebugBridge:Event('vehicle_stuck', { bot = p_Bot.m_Player.name, pos = { s_Position.x, s_Position.y, s_Position.z } })
	end
	local s_Id = s_Vehicle.instanceId
	local s_Bots = g_BotManager:GetBots()
	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		local s_Other = l_Bot.m_Player ~= nil and l_Bot.m_Player.controlledControllable or nil
		if s_Other ~= nil and s_Other.instanceId == s_Id and l_Bot.m_Player.soldier ~= nil then
			l_Bot:ExitVehicle()
		end
	end
end

-- =============================================
-- RUSH Events.
-- =============================================

---Rush: a bot left the combat area (p_Left) or came back into it. The area of the next stage opens only a while after
---the last one fell, the bots already go there: they turn back and wait at the border (Bot:OnCombatAreaLeft).
---@param p_Player Player
---@param p_Left boolean
function GameDirector:OnCombatArea(p_Player, p_Left)
	if not Globals.IsRush or not m_Utilities:isBot(p_Player) then
		return
	end
	local s_Bot = g_BotManager:GetBotById(p_Player.id)
	if s_Bot == nil then
		return
	end
	if p_Left then
		s_Bot:OnCombatAreaLeft()
	else
		s_Bot:OnCombatAreaReturned()
	end
end

function GameDirector:OnMcomArmed(p_Player)
	local s_PlayerPos = nil
	if p_Player and p_Player.soldier then
		s_PlayerPos = p_Player.soldier.worldTransform.trans:Clone()
	elseif p_Player and p_Player.corpse then
		s_PlayerPos = p_Player.corpse.worldTransform.trans:Clone()
	end

	if s_PlayerPos then
		local s_Objective = self:_TranslateMcom(s_PlayerPos)
		if not s_Objective then
			return
		end
		m_Logger:Write(s_Objective .. " armed")

		self:_UpdateObjective(s_Objective, {
			team = TeamId.Team1,
			isAttacked = true
		})
		self.m_ArmedMcoms[s_Objective] = -self.m_UpdateTimer
		self.m_ArmedBy[s_Objective] = p_Player.id
	end
end

---An MCOM went off (scoring event "crate destroyed" of the player who armed it). The position of the player tells
---nothing (anywhere by now): the MCOM it armed, else the one armed the longest.
---@param p_Player Player|nil
function GameDirector:OnMcomDestroyedBy(p_Player)
	local s_Objective = nil
	local s_Longest = -math.huge
	for l_Objective, l_Timer in pairs(self.m_ArmedMcoms) do
		if p_Player ~= nil and self.m_ArmedBy[l_Objective] == p_Player.id then
			s_Objective = l_Objective
			break
		end
		if l_Timer > s_Longest then
			s_Objective = l_Objective
			s_Longest = l_Timer
		end
	end
	if s_Objective ~= nil then
		self:OnMcomDestroyed(s_Objective, 'event')
	end
end

---@param p_Objective string|nil "mcom N"
---@return boolean
function GameDirector:IsMcomArmed(p_Objective)
	return p_Objective ~= nil and self.m_ArmedMcoms[p_Objective] ~= nil
end

function GameDirector:OnMcomDisarmed(p_Player)
	local s_PlayerPos = nil
	if p_Player and p_Player.soldier then
		s_PlayerPos = p_Player.soldier.worldTransform.trans:Clone()
	elseif p_Player and p_Player.corpse then
		s_PlayerPos = p_Player.corpse.worldTransform.trans:Clone()
	end

	if s_PlayerPos then
		local s_Objective = self:_TranslateMcom(s_PlayerPos)
		if not s_Objective then
			return
		end
		m_Logger:Write(s_Objective .. " disarmed")

		self:_UpdateObjective(s_Objective, {
			team = TeamId.TeamNeutral,
			isAttacked = false
		})
		self.m_ArmedMcoms[s_Objective] = nil
		self.m_ArmedBy[s_Objective] = nil
	end
end

function GameDirector:OnLifeCounterBaseDestoyed(p_LifeCounterEntity, p_FinalBase)
	self.m_StageDoneSince = nil
	self:_UpdateValidObjectives()
end

---@param p_Objective string
---@param p_Source string|nil 'event' (the game said so) or 'timer' (armed long enough)
function GameDirector:OnMcomDestroyed(p_Objective, p_Source)
	m_Logger:Write(p_Objective .. " destroyed after " .. tostring(self.m_ArmedMcoms[p_Objective]) .. " s")
	if m_DebugBridge.m_Enabled then
		m_DebugBridge:Event('mcom_destroyed', { objective = p_Objective, source = p_Source,
			armed = self.m_ArmedMcoms[p_Objective] })
	end
	self.m_ArmedMcoms[p_Objective] = nil
	self.m_ArmedBy[p_Objective] = nil

	local s_SubObjective = nil
	local s_TopObjective = nil

	if p_Objective ~= '' then
		self:_UpdateObjective(p_Objective, {
			team = TeamId.TeamNeutral, -- p_Player.teamId,
			isAttacked = false,
			destroyed = true
		})
		s_SubObjective = self:_GetSubObjectiveFromObj(p_Objective)
		s_TopObjective = self:_GetObjectiveFromSubObj(p_Objective)
	end

	if s_TopObjective ~= nil then
		self:_UpdateObjective(s_TopObjective, {
			destroyed = true
		})
	end

	if s_SubObjective ~= nil then
		self:_UpdateObjective(s_SubObjective, {
			destroyed = true
		})
	end
end

---@param p_EntityId integer
function GameDirector:OnRushZoneDisabled(p_EntityId)
	m_Logger:Write("Zone " .. tostring(p_EntityId) .. " disabled")
end

-- =============================================
-- Vehicle Events.
-- =============================================

-- Rush: a vehicle is spawned into directly only this close to a spawn of the team that is on (the stage).
local VEHICLE_STAGE_RANGE = 120.0

function GameDirector:GetSpawnableVehicle(p_TeamId)
	local spawnableVehiclesForTeamID = {}
	if self.m_SpawnableVehicles[p_TeamId] then
		spawnableVehiclesForTeamID = _PruneInvalidEntities(self.m_SpawnableVehicles[p_TeamId])
	end
	-- Rush: the vehicles at the bases of the other stages can't be entered (the bot was killed to spawn again, over and
	-- over): only the ones of the stage.
	if Globals.IsRush and #spawnableVehiclesForTeamID > 0 then
		local s_Spawns = self:_TeamSpawnPositions(p_TeamId)
		local s_Stage = {}
		for l_Index = 1, #spawnableVehiclesForTeamID do
			local l_Vehicle = spawnableVehiclesForTeamID[l_Index]
			local s_Ok, s_Position = pcall(function() return l_Vehicle.transform.trans end)
			if s_Ok and s_Position ~= nil then
				for l_Spawn = 1, #s_Spawns do
					if s_Spawns[l_Spawn]:Distance(s_Position) <= VEHICLE_STAGE_RANGE then
						s_Stage[#s_Stage + 1] = l_Vehicle
						break
					end
				end
			end
		end
		spawnableVehiclesForTeamID = s_Stage
	end
	return spawnableVehiclesForTeamID
end

function GameDirector:GetMobileRespawnVehicles(p_TeamId)
	local s_Vehicles = {}

	_PruneInvalidEntities(self.m_MobileRespawnVehicles[p_TeamId])
	for l_Index = 1, #self.m_MobileRespawnVehicles[p_TeamId] do
		local l_Vehicle = self.m_MobileRespawnVehicles[p_TeamId][l_Index]
		if l_Vehicle ~= nil and m_Vehicles:GetNrOfFreeSeats(l_Vehicle, false) > 0 then
			s_Vehicles[#s_Vehicles + 1] = l_Vehicle
		end
	end

	return s_Vehicles
end

function GameDirector:GetStationaryAas(p_TeamId)
	return _PruneInvalidEntities(self.m_SpawnableStationaryAas[p_TeamId])
end

---Team that owns a stationary AA. Uses the team of the vehicle-spawn, as the faction
---does not tell the team (e.g. in Rush the attackers are always Team1, whatever faction they are).
---@param p_Entity ControllableEntity
---@param p_VehicleData table
---@return TeamId|integer
function GameDirector:_GetStationaryAaTeam(p_Entity, p_VehicleData)
	-- Rush: the team of the entity is not reliable there (e.g. final base on Operation Firestorm).
	-- Use the team of the closest base instead (defenders as fallback).
	if Globals.IsRush then
		return self:_VehicleSpawnTeam(p_Entity.transform.trans)
			or self:_GetTeamOfClosestBasePath(p_Entity.transform.trans) or TeamId.Team2
	end

	local s_Team = p_Entity.defaultTeamId

	if s_Team == nil or s_Team == TeamId.TeamNeutral then
		s_Team = p_Entity.teamId
	end

	if s_Team == nil or s_Team == TeamId.TeamNeutral or s_Team > Globals.NrOfTeams then
		s_Team = p_VehicleData.Team -- Fallback: faction of the AA.
	end

	return s_Team
end

---Team of the base (e.g. "base us 2", "base ru 1": its zone, or its path) closest to the position. Used where no capture
---points exist (Rush). Attackers and defenders spawn far apart there.
---@param p_Position Vec3
---@return TeamId|integer|nil
function GameDirector:_GetTeamOfClosestBasePath(p_Position)
	local s_ClosestDistance = nil
	local s_ClosestTeam = nil

	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if l_Objective.isBase and l_Objective.team ~= TeamId.TeamNeutral then
			local s_Position = self:_GetObjectivePosition(l_Objective.name)
			local s_Distance = s_Position ~= nil and s_Position:Distance(p_Position) or nil
			if s_Distance ~= nil and (s_ClosestDistance == nil or s_Distance < s_ClosestDistance) then
				s_ClosestDistance = s_Distance
				s_ClosestTeam = l_Objective.team
			end
		end
	end

	return s_ClosestTeam
end

---@param p_ControllableEntity ControllableEntity
---@param p_TeamId TeamId
function GameDirector:ReturnStationaryAaEntity(p_ControllableEntity, p_TeamId)
	p_ControllableEntity = ControllableEntity(p_ControllableEntity)
	-- Always return it to the owning team, not to the team of the last user.
	p_TeamId = self.m_StationaryAaTeams[p_ControllableEntity.instanceId] or p_TeamId
	_PruneInvalidEntities(self.m_SpawnableStationaryAas[p_TeamId])
	for l_Index = 1, #self.m_SpawnableStationaryAas[p_TeamId] do
		local l_Entity = self.m_SpawnableStationaryAas[p_TeamId][l_Index]
		if (l_Entity.uniqueId == p_ControllableEntity.uniqueId) and (l_Entity.instanceId == p_ControllableEntity.instanceId) then
			-- already in list, return
			return
		end
	end
	self:AddEntityToVehicleCollection(self.m_SpawnableStationaryAas, p_TeamId, p_ControllableEntity)
end

function GameDirector:GetGadgetOwner(p_Entity)
	local s_GadgetPosition = p_Entity.transform.trans:Clone()

	local s_MinDistance = nil
	local s_ClosestPlayer = nil
	local s_Players = PlayerManager:GetPlayers()

	for l_Index = 1, #s_Players do
		local l_Player = s_Players[l_Index]
		if l_Player.soldier ~= nil then
			local s_CurrentDistance = s_GadgetPosition:Distance(l_Player.soldier.worldTransform.trans)

			if s_MinDistance == nil or s_MinDistance > s_CurrentDistance then
				s_MinDistance = s_CurrentDistance
				s_ClosestPlayer = l_Player
			end
		end
	end

	return s_ClosestPlayer
end

---VEXT Server Vehicle:SpawnDone Event
---@param p_Entity ControllableEntity|Entity
function GameDirector:OnVehicleSpawnDone(p_Entity)
	p_Entity = ControllableEntity(p_Entity)
	local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_Entity)
	if s_VehicleData == nil then
		return -- No vehicle found.
	end

	if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.Gadgets) then
		local s_Owner = self:GetGadgetOwner(p_Entity)

		if s_Owner ~= nil then
			m_Logger:Write("Gadget spawn: " .. s_VehicleData.Name .. "; Owner: " .. s_Owner.name)

			if s_VehicleData.Name == "[RadioBeacon]" then
				if m_Utilities:isBot(s_Owner) then
					local s_Bot = g_BotManager:GetBotById(s_Owner.id)

					if s_Bot ~= nil then
						s_Bot.m_HasBeacon = true
					end
				end

				local s_Beacon = {}
				local s_Pos = p_Entity.transform.trans:Clone()
				local s_Node = self:FindClosestPath(s_Pos, false, true, nil, 1)

				if s_Node and s_Node.Position:Distance(s_Pos) < 6.0 then
					s_Beacon.Path = s_Node.PathIndex
					s_Beacon.Point = s_Node.PointIndex
					s_Beacon.Entity = p_Entity

					self.m_Beacons[s_Owner.name] = s_Beacon
				end
			end
		end
	end

	if not Config.UseAirVehicles and m_Vehicles:IsAirVehicle(s_VehicleData) then
		return -- Not allowed to use.
	end

	if not Config.UseJets and m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.Plane) then
		return
	end

	-- if map not completely loaded yet, insert them for later and return
	if not self.m_MapCompletelyLoaded then
		self.m_SpawnedEntitiesToProcess[#self.m_SpawnedEntitiesToProcess + 1] = p_Entity
		return
	end

	-- spawn directly into jets
	if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.Plane) then
		-- The team of the vehicle-spawn of the engine, else of the closest base or capture point.
		local s_SpawnTeam = self:_VehicleSpawnTeam(p_Entity.transform.trans)
		if s_SpawnTeam ~= nil then
			m_Logger:Write("Jet spawned: " .. s_VehicleData.Name .. ", team of its spawn: " .. tostring(s_SpawnTeam))
			self:AddEntityToVehicleCollection(self.m_SpawnableVehicles, s_SpawnTeam, p_Entity)
			return
		end
		-- find closest base or caputre-point --> team of jet
		if self._AllBases then
			local s_ClosestDistance = nil
			local s_ClosestTeam = nil

			-- try bases first
			for l_Index = 1, #self._AllBases do
				local l_BaseCapturePoint = self._AllBases[l_Index]
				if l_BaseCapturePoint.team ~= TeamId.TeamNeutral then
					local s_Distance = l_BaseCapturePoint.transform.trans:Distance(p_Entity.transform.trans)
					if s_ClosestDistance == nil or s_ClosestDistance > s_Distance then
						s_ClosestDistance = s_Distance
						s_ClosestTeam = l_BaseCapturePoint.team
					end
				end
			end

			-- then also consider other capture points
			if self._AllCapturePoints then
				for l_Index = 1, #self._AllCapturePoints do
					local l_CapturePoint = self._AllCapturePoints[l_Index]
					if l_CapturePoint.team ~= TeamId.TeamNeutral then
						local s_Distance = l_CapturePoint.transform.trans:Distance(p_Entity.transform.trans)
						if s_ClosestDistance == nil or s_ClosestDistance > s_Distance then
							s_ClosestDistance = s_Distance
							s_ClosestTeam = l_CapturePoint.team
						end
					end
				end
			end
			-- no capture points (e.g. Rush): use the team of the closest base
			if s_ClosestTeam == nil then
				s_ClosestTeam = self:_GetTeamOfClosestBasePath(p_Entity.transform.trans)
			end

			if s_ClosestTeam then
				m_Logger:Write("Jet spawned: " .. s_VehicleData.Name .. ", team: " .. tostring(s_ClosestTeam))
				self:AddEntityToVehicleCollection(self.m_SpawnableVehicles, s_ClosestTeam, p_Entity)
			end
		end
		return
	end

	-- now check the other vehicles
	local s_Objective = nil
	if m_NavZones:GetMesh() ~= nil then
		-- Levels with a mesh: no paths or labels. The engine tells the team (the vehicle-spawn it stands at); in a base
		-- (an HQ, a spawn area of the game) the bots spawn right into it, elsewhere they walk to it over the mesh (vehicle
		-- objectives, _RefreshVehicleEntities).
		local s_Position = p_Entity.transform.trans
		local s_Team = self:_VehicleSpawnTeam(s_Position)
		self.m_VehicleSpawnTeams[p_Entity.instanceId] = s_Team
		if s_Team ~= nil and not m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.StationaryAA)
			and not m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.MavBot)
			and not m_Vehicles:IsGunship(s_VehicleData) then
			local s_InBase = self:_IsInBase(s_Position, s_Team)
			m_Logger:Write("Vehicle spawned: " .. s_VehicleData.Name .. ", team " .. tostring(s_Team) .. ", in base: "
				.. tostring(s_InBase))
			self:AddEntityToVehicleCollection(s_InBase and self.m_SpawnableVehicles or self.m_AvailableVehicles,
				s_Team, p_Entity)
		end
	else
		s_Objective = self:_SetVehicleObjectiveState(p_Entity.transform.trans:Clone(), true)
	end
	if s_Objective ~= nil then
		-- don't make this dependant of the nodes
		if s_Objective.isSpawnPath then
			self:AddEntityToVehicleCollection(self.m_SpawnableVehicles, s_Objective.team, p_Entity)
		else
			self:AddEntityToVehicleCollection(self.m_AvailableVehicles, s_Objective.team, p_Entity)
		end
	elseif m_NavZones:GetMesh() == nil then
		if Config.EnableParadrop and self.m_Gunship ~= nil and m_Vehicles:IsVehicleType(self.m_Gunship.Data, VehicleTypes.UnarmedGunship) then
			if p_Entity.transform.trans.y > self.m_Gunship.Entity.transform.trans.y then
				m_Logger:Write("Add spawnable vehicle at gunship: " .. s_VehicleData.Name)
				self:AddEntityToVehicleCollection(self.m_SpawnableVehicles, self.m_Gunship.Team, p_Entity)
			end
		end
	end

	if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.StationaryAA) then
		local s_AaTeam = self:_GetStationaryAaTeam(p_Entity, s_VehicleData)
		m_Logger:Write("Stationary AA spawned: " .. s_VehicleData.Name .. ", team: " .. tostring(s_AaTeam))
		self.m_StationaryAaTeams[p_Entity.instanceId] = s_AaTeam
		self:AddEntityToVehicleCollection(self.m_SpawnableStationaryAas, s_AaTeam, p_Entity)
	end

	if m_Vehicles:IsGunship(s_VehicleData)
		and self.m_GunshipObjectiveTeam ~= nil
	then
		m_Logger:Write("Spawned gunship, team: " .. self.m_GunshipObjectiveTeam)

		local s_Gunship = {}
		s_Gunship.Entity = p_Entity
		s_Gunship.Team = self.m_GunshipObjectiveTeam
		s_Gunship.Data = s_VehicleData

		self.m_Gunship = s_Gunship
	end
end

---@param p_TeamId TeamId|nil
---@return ControllableEntity|nil
function GameDirector:GetGunship(p_TeamId)
	if self.m_Gunship ~= nil and not _IsEntityValid(self.m_Gunship.Entity) then
		self.m_Gunship = nil
	end
	if self.m_Gunship ~= nil and m_Vehicles:IsVehicleType(self.m_Gunship.Data, VehicleTypes.Gunship) then
		if p_TeamId == nil or p_TeamId == self.m_Gunship.Team then
			return self.m_Gunship.Entity
		end
	end
	return nil
end

---Keep a gunship seat free for a player for some time.
---@param p_EntryId integer
function GameDirector:ReserveGunshipEntry(p_EntryId)
	self.m_GunshipReservedEntry = p_EntryId
	self.m_GunshipReservedUntil = SharedUtils:GetTime() + Registry.COMMON.GUNSHIP_SEAT_RESERVE_TIME
end

---@param p_EntryId integer
---@return boolean
function GameDirector:IsGunshipEntryReserved(p_EntryId)
	if self.m_GunshipReservedEntry == nil then
		return false
	end

	if SharedUtils:GetTime() > self.m_GunshipReservedUntil then
		self.m_GunshipReservedEntry = nil
		return false
	end

	return self.m_GunshipReservedEntry == p_EntryId
end

---Checks if the gunship has a seat left bots are allowed to take.
---@param p_Gunship ControllableEntity
---@return boolean
function GameDirector:GunshipHasFreeBotSeat(p_Gunship)
	for l_EntryId = 1, p_Gunship.entryCount - 1 do
		if p_Gunship:GetPlayerInEntry(l_EntryId) == nil and not self:IsGunshipEntryReserved(l_EntryId) then
			return true
		end
	end

	return false
end

---@param p_Entity ControllableEntity|Entity
---@param p_VehiclePoints any
---@param p_HotTeam any
function GameDirector:OnVehicleUnspawn(p_Entity, p_VehiclePoints, p_HotTeam)
	p_Entity = ControllableEntity(p_Entity)
	local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_Entity)

	if s_VehicleData == nil then
		return
	end

	-- Always drop beacons, also during a round switch. Otherwise a destroyed entity stays referenced.
	if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.Gadgets) then
		m_Logger:Write("Gadget unspawn: " .. s_VehicleData.Name)
		for l_Owner, l_Beacon in pairs(self.m_Beacons) do
			local l_Entity = l_Beacon.Entity
			if not _IsEntityValid(l_Entity)
				or ((l_Entity.uniqueId == p_Entity.uniqueId) and (l_Entity.instanceId == p_Entity.instanceId)) then
				self.m_Beacons[l_Owner] = nil
			end
		end
	end

	-- Added the timer check since this could have been called right while we are switching rounds, causing issues while this tries to access variables
	-- or tables that might be already wipedout
	if self.m_UpdateTimer == -1 then -- updateTimer being -1 means all vars where wipedout due to next round triggered.
		return
	end

	if m_Vehicles:IsGunship(s_VehicleData) then
		m_Logger:Write("Gunship unspawn")
		self.m_Gunship = nil
		self.m_GunshipReservedEntry = nil
	end

	if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.StationaryAA) then
		self.m_StationaryAaTeams[p_Entity.instanceId] = nil
	end

	for l_Team = TeamId.Team1, Globals.NrOfTeams do
		if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.StationaryAA) then
			self:RemoveEntityFromVehicleCollection(self.m_SpawnableStationaryAas, l_Team, p_Entity)
		else
			self:RemoveEntityFromVehicleCollection(self.m_SpawnableVehicles, l_Team, p_Entity)
			self:RemoveEntityFromVehicleCollection(self.m_AvailableVehicles, l_Team, p_Entity)
			self:RemoveEntityFromVehicleCollection(self.m_MobileRespawnVehicles, l_Team, p_Entity)
		end
	end
end

---VEXT Server Vehicle:Exit Event
---@param p_VehicleEntity ControllableEntity|Entity
---@param p_Player Player
function GameDirector:OnVehicleExit(p_VehicleEntity, p_Player)
	if (p_VehicleEntity == nil) or (p_VehicleEntity:Is("ServerSoldierEntity")) then -- or (p_VehicleEntity:Is("SoldierEntityData"))
		return
	end
	p_VehicleEntity = ControllableEntity(p_VehicleEntity)
	local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_VehicleEntity)
	if s_VehicleData ~= nil then
		if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.StationaryAA) then
			self:ReturnStationaryAaEntity(p_VehicleEntity, p_Player.teamId)
		end

		if m_Vehicles:IsMobileRespawnVehicle(s_VehicleData)
			and m_Vehicles:IsEmpty(p_VehicleEntity)
		then
			self:RemoveEntityFromVehicleCollection(self.m_MobileRespawnVehicles, p_Player.teamId, p_VehicleEntity)
		end
	end
end

---VEXT Server Vehicle:Enter Event
---@param p_Entity ControllableEntity|Entity
---@param p_Player Player
function GameDirector:OnVehicleEnter(p_Entity, p_Player)
	p_Entity = ControllableEntity(p_Entity)
	local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_Entity)

	if s_VehicleData ~= nil then
		local l_Team = p_Player.teamId

		if m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.StationaryAA) then
			-- Also an enemy can enter it: remove it from the list of every team.
			for l_AaTeam = TeamId.Team1, Globals.NrOfTeams do
				self:RemoveEntityFromVehicleCollection(self.m_SpawnableStationaryAas, l_AaTeam, p_Entity)
			end
		elseif m_Vehicles:IsMobileRespawnVehicle(s_VehicleData) then
			self:RemoveEntityFromVehicleCollection(self.m_SpawnableVehicles, l_Team, p_Entity)
			self:RemoveEntityFromVehicleCollection(self.m_AvailableVehicles, l_Team, p_Entity)

			if not self:IsEntityInVehicleCollection(self.m_MobileRespawnVehicles, l_Team, p_Entity) then
				self:AddEntityToVehicleCollection(self.m_MobileRespawnVehicles, l_Team, p_Entity)
			end
		else
			self:RemoveEntityFromVehicleCollection(self.m_SpawnableVehicles, l_Team, p_Entity)
			self:RemoveEntityFromVehicleCollection(self.m_AvailableVehicles, l_Team, p_Entity)
		end
	end

	if not m_Utilities:isBot(p_Player) then
		p_Entity = ControllableEntity(p_Entity)

		-- The player took the gunship seat: no need to keep it free anymore.
		if self.m_GunshipReservedEntry ~= nil and s_VehicleData ~= nil and m_Vehicles:IsGunship(s_VehicleData) then
			self.m_GunshipReservedEntry = nil
		end

		self:_SetVehicleObjectiveState(p_Entity.transform.trans:Clone(), false)

		if p_Player.controlledEntryId ~= 0 and p_Player.controlledControllable then
			local s_Driver = p_Player.controlledControllable:GetPlayerInEntry(0)
			if s_Driver ~= nil then
				Events:Dispatch("Bot:AbortWait", s_Driver.id)
			end
		end

		self:_SetVehicleObjectiveState(p_Entity.transform.trans:Clone(), false)
	end
end

-- =============================================
-- Functions.
-- =============================================

-- =============================================
-- Public Functions.
-- =============================================

---@param p_LevelName string
---@param p_GameMode string
---@return string|nil
function GameDirector:GetGunshipObjectiveName(p_LevelName, p_GameMode)
	if p_GameMode == "ConquestLarge0" then
		if p_LevelName == "XP3_Desert" then
			return "ID_H_US_G"
		elseif p_LevelName == "XP3_Alborz" then
			return "ID_H_US_E"
		elseif p_LevelName == "XP3_Shield" then
			return "ID_H_US_B"
		elseif p_LevelName == "XP3_Valley" then
			return "ID_H_US_D"
		elseif p_LevelName == "XP5_001" then
			return "ID_H_US_C"
		elseif p_LevelName == "XP5_002" then
			return "ID_H_US_D"
		elseif p_LevelName == "XP5_003" then
			return "ID_H_US_D"
		elseif p_LevelName == "XP5_004" then
			return "ID_H_US_D"
		end
	elseif p_GameMode == "ConquestSmall0" then
		if p_LevelName == "XP3_Desert" then
			return "ID_H_US_E"
		elseif p_LevelName == "XP3_Alborz" then
			return "ID_H_US_C"
		elseif p_LevelName == "XP3_Shield" then
			return "ID_H_US_B"
		elseif p_LevelName == "XP3_Valley" then
			return "ID_H_US_C"
		elseif p_LevelName == "XP5_001" then
			return "ID_H_US_C"
		elseif p_LevelName == "XP5_002" then
			return "ID_H_US_C"
		elseif p_LevelName == "XP5_003" then
			return "ID_H_US_C"
		elseif p_LevelName == "XP5_004" then
			return "ID_H_US_C"
		end
	end

	return nil
end

function GameDirector:GetAllCapturePoints()
	return self._AllCapturePoints
end

function GameDirector:CapturePointStats()
	local s_Stats = {}
	s_Stats["captured"] = {}
	s_Stats["neutral"] = {}
	s_Stats["all"] = self._AllCapturePoints

	s_Stats.captured[TeamId.Team1] = {}
	s_Stats.captured[TeamId.Team2] = {}

	for l_Index = 1, #self._AllCapturePoints do
		local l_CapturePoint = self._AllCapturePoints[l_Index]

		if l_CapturePoint.team == TeamId.TeamNeutral then
			s_Stats.neutral[#s_Stats.neutral + 1] = l_CapturePoint
		else
			local s_TeamCaptured = s_Stats.captured[l_CapturePoint.team]
			s_TeamCaptured[#s_TeamCaptured + 1] = l_CapturePoint
		end
	end

	return s_Stats
end

function GameDirector:GetActiveMcomPositions()
	local s_Positions = {}

	-- Build a proper array (starting at 1, no holes), so callers can use #.
	-- MCOMs without a trace path have no known position and are skipped.
	if Globals.IsRush then
		if Globals.IsSquadRush then
			s_Positions[#s_Positions + 1] = self._McomPositions[self.m_RushStageCounter]
		else
			s_Positions[#s_Positions + 1] = self._McomPositions[self.m_RushStageCounter * 2]
			s_Positions[#s_Positions + 1] = self._McomPositions[self.m_RushStageCounter * 2 - 1]
		end
	end

	return s_Positions
end

---@param p_Collection table
---@param p_Team integer
---@param p_Entity ControllableEntity|Entity
function GameDirector:AddEntityToVehicleCollection(p_Collection, p_Team, p_Entity)
	p_Collection[p_Team][#p_Collection[p_Team] + 1] = p_Entity
end

---@param p_Collection table
---@param p_Team integer
---@param p_Entity ControllableEntity|Entity
function GameDirector:RemoveEntityFromVehicleCollection(p_Collection, p_Team, p_Entity)
	-- Destroyed entries would error on the id comparison below.
	_PruneInvalidEntities(p_Collection[p_Team])

	for l_Index = 1, #p_Collection[p_Team] do
		local l_Entity = p_Collection[p_Team][l_Index]

		if (l_Entity.uniqueId == p_Entity.uniqueId) and (l_Entity.instanceId == p_Entity.instanceId) then
			table.remove(p_Collection[p_Team], l_Index)
			break -- should only happen once
		end
	end
end

---@param p_Collection table
---@param p_Team integer
---@param p_Entity ControllableEntity|Entity
function GameDirector:IsEntityInVehicleCollection(p_Collection, p_Team, p_Entity)
	_PruneInvalidEntities(p_Collection[p_Team])

	for l_Index = 1, #p_Collection[p_Team] do
		local l_Entity = p_Collection[p_Team][l_Index]

		if (l_Entity.uniqueId == p_Entity.uniqueId) and (l_Entity.instanceId == p_Entity.instanceId) then
			return true
		end
	end

	return false
end

---@param p_Point table
---@param p_TeamId TeamId|integer
---@param p_InVehicle boolean
---@return boolean
function GameDirector:CheckForExecution(p_Point, p_TeamId, p_InVehicle)
	if p_Point.Data.Action == nil then
		return false
	end

	local s_Action = p_Point.Data.Action

	if s_Action.type == "mcom" then
		local s_Mcom = self:_TranslateObjective(p_Point.Position)

		if s_Mcom == nil then
			return false
		end

		local s_Objective = self:_GetObjectiveObject(s_Mcom)

		if s_Objective == nil then
			return false
		end

		-- The action-node is the start of "mcom N interact": armed or not is stored at "mcom N" (OnMcomArmed).
		if s_Objective.subObjective then
			local s_ParentName = self:_GetObjectiveFromSubObj(s_Objective.name)
			local s_Parent = s_ParentName and self:_GetObjectiveObject(s_ParentName)
			if s_Parent ~= nil then
				s_Objective = s_Parent
			end
		end

		if s_Objective.active and not s_Objective.destroyed then
			if p_TeamId == TeamId.Team1 and s_Objective.team == TeamId.TeamNeutral then
				return true -- Attacking Team.
			elseif p_TeamId == TeamId.Team2 and s_Objective.isAttacked then
				return true -- Defending Team.
			end
		end

		return false
	elseif s_Action.type == "vehicle" then
		if p_InVehicle then
			return false
		end

		local s_CurrentPathFirst = m_NodeCollection:GetFirst(p_Point.PathIndex)

		if s_CurrentPathFirst.Data.Objectives ~= nil and #s_CurrentPathFirst.Data.Objectives == 1 then
			local s_TempObjective = self:_GetObjectiveObject(s_CurrentPathFirst.Data.Objectives[1])

			if s_TempObjective ~= nil and s_TempObjective.active and s_TempObjective.isEnterVehiclePath then
				return true
			end
		end
		return false
	elseif s_Action.type == "exit" then
		if p_InVehicle then
			return true
		else
			return false
		end
	else -- Execute ACTION.
		return true
	end
end

---@param p_PathIndex integer
---@param p_Nodes Waypoint[]
---@param p_Index integer
---@param p_X number
---@param p_Y number
---@param p_Z number
---@return number squared distance
local function _NodeDistanceSquared(p_PathIndex, p_Nodes, p_Index, p_X, p_Y, p_Z)
	local s_Coords = s_NodeCoords[p_PathIndex]
	if s_Coords == nil then
		s_Coords = {}
		s_NodeCoords[p_PathIndex] = s_Coords
	end

	local s_Offset = p_Index * 4 - 3
	local s_Position = p_Nodes[p_Index].Position
	if not rawequal(s_Coords[s_Offset], s_Position) then
		s_Coords[s_Offset] = s_Position
		s_Coords[s_Offset + 1] = s_Position.x
		s_Coords[s_Offset + 2] = s_Position.y
		s_Coords[s_Offset + 3] = s_Position.z
	end

	local s_DiffX = s_Coords[s_Offset + 1] - p_X
	local s_DiffY = s_Coords[s_Offset + 2] - p_Y
	local s_DiffZ = s_Coords[s_Offset + 3] - p_Z
	return s_DiffX * s_DiffX + s_DiffY * s_DiffY + s_DiffZ * s_DiffZ
end

---@param p_Trans Vec3
---@param p_VehiclePath boolean
---@param p_DetailedSearch boolean
---@param p_VehicleTerrain VehicleTerrains|nil
---@param p_Increment integer|nil
---@return Waypoint|nil
function GameDirector:FindClosestPath(p_Trans, p_VehiclePath, p_DetailedSearch, p_VehicleTerrain, p_Increment)
	local s_Paths = m_NodeCollection:GetPaths()

	if s_Paths == nil then
		return nil
	end

	p_Increment = p_Increment or Registry.GAME_DIRECTOR.NODE_SEARCH_INCREMENTS

	local s_X, s_Y, s_Z = p_Trans.x, p_Trans.y, p_Trans.z
	local s_ClosestPathNode = nil
	local s_ClosestDistance = math.huge
	-- With a mesh the actions (arming an MCOM) are done from the mesh: their paths lead nowhere for a soldier off it
	-- (the loop around a destroyed MCOM behind a wall).
	local s_SkipActions = not p_VehiclePath and m_NavZones:GetMesh() ~= nil

	for l_PathIndex, l_Waypoints in pairs(s_Paths) do
		local s_FirstNode = l_Waypoints[1]
		if s_FirstNode ~= nil then
			local s_isVehiclePath = false
			local s_isAirPath = false
			local s_isWaterPath = false
			local s_isSpawnVehiclePath = false

			if s_FirstNode.Data ~= nil then
				if s_FirstNode.Data.Vehicles ~= nil then
					s_isVehiclePath = true

					for l_Index = 1, #s_FirstNode.Data.Vehicles do
						local l_PathType = s_FirstNode.Data.Vehicles[l_Index]:lower()
						if l_PathType == "air" then
							s_isAirPath = true
						end

						if l_PathType == "water" then
							s_isWaterPath = true
						end
					end
				end
				if s_FirstNode.Data.Objectives and s_FirstNode.Data.Objectives[1] then
					local s_Objective = self:_GetObjectiveObject(s_FirstNode.Data.Objectives[1])
					if s_Objective and s_Objective.isSpawnPath and s_Objective.isEnterVehiclePath then
						s_isSpawnVehiclePath = true
					end
				end
			end
			local s_Action = s_SkipActions and s_FirstNode.Data ~= nil and s_FirstNode.Data.Action ~= nil
				and s_FirstNode.Data.Action.type ~= 'exit'

			local s_Search = false
			if p_VehiclePath then
				s_Search = s_isVehiclePath and ((p_VehicleTerrain == VehicleTerrains.Air and s_isAirPath) or
					(p_VehicleTerrain == VehicleTerrains.Water and s_isWaterPath) or
					(p_VehicleTerrain == VehicleTerrains.Land and not s_isWaterPath and not s_isAirPath) or
					(p_VehicleTerrain == VehicleTerrains.Amphibious and not s_isAirPath))
			else -- Not in vehicle. Only use infantery-paths
				s_Search = not s_isVehiclePath and not s_isSpawnVehiclePath and not s_Action
			end

			if s_Search then
				local s_LastIndex = p_DetailedSearch and #l_Waypoints or 1
				for i = 1, s_LastIndex, p_Increment do
					local s_NewDistance = _NodeDistanceSquared(l_PathIndex, l_Waypoints, i, s_X, s_Y, s_Z)

					if s_NewDistance < s_ClosestDistance then
						s_ClosestDistance = s_NewDistance
						s_ClosestPathNode = l_Waypoints[i]
					end
				end
			end
		end
	end

	return s_ClosestPathNode
end

function GameDirector:GetPlayerBeacon(p_PlayerName)
	local s_Beacon = self.m_Beacons[p_PlayerName]

	if s_Beacon ~= nil and not _IsEntityValid(s_Beacon.Entity) then
		m_Logger:Write("removing destroyed beacon of " .. p_PlayerName)
		self.m_Beacons[p_PlayerName] = nil
		return nil
	end

	return s_Beacon
end

-- A spawn without a way to any objective (the ship of the attackers): a squad-mate at least this far away is spawned on.
local STRANDED_MATE_DISTANCE = 60.0

---Spawn at a beacon or on a squad-mate (now and then). p_Stranded: the spawn of the game the bot is at leads nowhere
---(IsStranded), it spawns on a mate (or its beacon) away from there whenever there is one.
---@param p_TeamId TeamId|integer
---@param p_SquadId SquadId|integer
---@param p_Stranded Vec3|nil
function GameDirector:GetSpawnableBeaconOrMate(p_TeamId, p_SquadId, p_Stranded)
	local s_SquadMates = PlayerManager:GetPlayersBySquad(p_TeamId, p_SquadId)
	local s_Probability = p_Stranded ~= nil and 100 or Registry.BOT_SPAWN.PROBABILITY_SQUADMATE_SPAWN

	---@param p_Position Vec3
	---@return boolean
	local function _Away(p_Position)
		return p_Stranded == nil or p_Position:Distance(p_Stranded) > STRANDED_MATE_DISTANCE
	end

	for l_Index = 1, #s_SquadMates do
		local l_Player = s_SquadMates[l_Index]
		local s_Beacon = self:GetPlayerBeacon(l_Player.name)

		if s_Beacon ~= nil and _Away(s_Beacon.Entity.transform.trans) then
			if m_Utilities:CheckProbability(s_Probability) then
				m_Logger:Write("spawn at beacon, owned by " .. l_Player.name)
				return s_Beacon.Path, s_Beacon.Point, true, nil, s_Beacon.Entity.transform.trans:Clone()
			end
		end

		if l_Player.soldier and l_Player.isAllowedToSpawnOn and _Away(l_Player.soldier.worldTransform.trans) then
			-- check for vehicle and spawn either on player or vehicle
			if m_Utilities:CheckProbability(s_Probability) then
				m_Logger:Write("spawn at squad-mate " .. l_Player.name)
				if l_Player.controlledControllable ~= nil and not l_Player.controlledControllable:Is("ServerSoldierEntity") then
					---@type ControllableEntity
					local s_Vehicle = l_Player.controlledControllable

					-- Check for free seats.
					if m_Vehicles:GetNrOfFreeSeats(s_Vehicle, true) > 0 then
						return 1, 1, false, s_Vehicle, nil
					end
				else
					local s_Node = self:FindClosestPath(l_Player.soldier.worldTransform.trans:Clone(), false, false)
					if s_Node then
						return s_Node.PathIndex, s_Node.PointIndex, false, nil, l_Player.soldier.worldTransform.trans:Clone()
					end
				end
			end
		end
	end
end

---Whether no way leads from the position (a spawn of the game) to any objective of the team over the mesh and the
---navigation paths: the ship of the attackers, the boats are their way (GetSpawnableBeaconOrMate).
---@param p_Position Vec3
---@param p_TeamId TeamId|integer
---@return boolean
function GameDirector:IsStranded(p_Position, p_TeamId)
	if m_NavZones:GetMesh() == nil or g_NavRoutes == nil then
		return false
	end
	local _, s_Point, s_Closest = m_NavZones:ZoneAtVisible(p_Position, 30.0, nil)
	s_Point = s_Point or s_Closest
	if s_Point == nil then
		return false
	end
	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if not l_Objective.subObjective and not l_Objective.isBase and not l_Objective.isEnterVehiclePath
			and l_Objective.active and not l_Objective.destroyed
			and (l_Objective.team ~= p_TeamId or Config.DefendObjectives)
			and g_NavRoutes:Next(s_Point, l_Objective.name) ~= nil then
			return false
		end
	end
	return true
end

---@param p_Path integer
---@param p_Objective string
---@return boolean
function GameDirector:IsOnSubobjectivePath(p_Path, p_Objective)
	local s_CurrentPathFirst = m_NodeCollection:GetFirst(p_Path)

	if s_CurrentPathFirst.Data ~= nil and s_CurrentPathFirst.Data.Objectives ~= nil then
		if #s_CurrentPathFirst.Data.Objectives == 1 and s_CurrentPathFirst.Data.Objectives[1] == p_Objective then
			local s_TempObjective = self:_GetObjectiveObject(p_Objective)
			if s_TempObjective ~= nil and s_TempObjective.subObjective then
				return true
			end
		end
	end

	return false
end

---@param p_ObjectiveNames string[]
---@return boolean
function GameDirector:IsBasePath(p_ObjectiveNames)
	if #p_ObjectiveNames < 1 then
		return false
	end
	for l_Index = 1, #p_ObjectiveNames do
		local l_ObjectiveName = p_ObjectiveNames[l_Index]
		local s_Objective = self:_GetObjectiveObject(l_ObjectiveName)
		if s_Objective ~= nil and s_Objective.isBase then
			return true
		end
	end

	return false
end

---Whether the objective of a path of one objective is destroyed (an MCOM or the way to it): nothing to do there.
---@param p_ObjectiveNames string[]
---@return boolean
function GameDirector:IsDestroyedPath(p_ObjectiveNames)
	if #p_ObjectiveNames ~= 1 then
		return false
	end

	local s_Objective = self:_GetObjectiveObject(p_ObjectiveNames[1])
	return s_Objective ~= nil and s_Objective.destroyed == true
end

-- -1 = destroyed objective.
-- 0 = all inactive.
-- 1 = partly inactive.
-- 2 = all active.
---@param p_ObjectiveNamesOfPath string[]
---@return integer
function GameDirector:GetEnableStateOfPath(p_ObjectiveNamesOfPath)
	local s_ActiveCount = 0

	for _, l_ObjectiveName in pairs(p_ObjectiveNamesOfPath) do
		local s_Objective = self:_GetObjectiveObject(l_ObjectiveName)

		if s_Objective ~= nil then
			if s_Objective.destroyed and #p_ObjectiveNamesOfPath == 1 and s_Objective.subObjective then
				return -1 -- Path of a destroyed MCOM
			elseif s_Objective.active then
				s_ActiveCount = s_ActiveCount + 1
			end
		end
	end

	if s_ActiveCount == 0 then
		return 0
	elseif s_ActiveCount < #p_ObjectiveNamesOfPath then
		return 1
	else
		return 2
	end
end

---@param p_BotTeam TeamId|integer
---@param p_Objective string
---@return boolean
function GameDirector:UseVehicle(p_BotTeam, p_Objective)
	local s_TempObjective = self:_GetObjectiveObject(p_Objective)

	if s_TempObjective ~= nil and s_TempObjective.active and s_TempObjective.isEnterVehiclePath then
		-- Not the vehicle of the other team.
		if s_TempObjective.team ~= TeamId.TeamNeutral and s_TempObjective.team ~= p_BotTeam then
			return false
		end

		if s_TempObjective.isEnterAirVehiclePath then
			return Config.UseVehicles and Config.UseAirVehicles
		elseif s_TempObjective.isEnterJetPath then
			return Config.UseJets
		else
			return Config.UseVehicles
		end
	end

	return false
end

---@param p_Objective string
---@return boolean
function GameDirector:IsVehicleEnterPath(p_Objective)
	local s_TempObjective = self:_GetObjectiveObject(p_Objective)

	if s_TempObjective ~= nil and s_TempObjective.isEnterVehiclePath then
		return true
	end

	return false
end

---@param p_Objective string
---@return boolean
function GameDirector:IsBeaconPath(p_Objective)
	local s_TempObjective = self:_GetObjectiveObject(p_Objective)

	if s_TempObjective ~= nil and s_TempObjective.isBeaconPath then
		return true
	end

	return false
end

---@param p_BotId integer
---@param p_BotTeam TeamId
---@param p_Objective string
function GameDirector:UseSubobjective(p_BotId, p_BotTeam, p_Objective)
	local s_TempObjective = self:_GetObjectiveObject(p_Objective)

	if s_TempObjective ~= nil and s_TempObjective.subObjective then -- Is valid getSubObjective.
		if s_TempObjective.active and not s_TempObjective.destroyed then
			if self:_UseSubobjective(p_BotTeam, p_Objective) then
				if s_TempObjective.assigned[p_BotTeam] < 2 then
					s_TempObjective.assigned[p_BotTeam] = s_TempObjective.assigned[p_BotTeam] + 1
					local s_Bot = g_BotManager:GetBotById(p_BotId)

					if s_Bot ~= nil then
						s_Bot:SetObjective(p_Objective)
						return true
					end
				end
			end
		end
	end

	return false
end

---@param p_TeamId TeamId
---@param p_Position? Vec3 position of the asking vehicle; picks the closest point of each kind
---@return Vec3
function GameDirector:GetActiveTargetPointPosition(p_TeamId, p_Position)
	local s_TargetPos = Vec3.zero

	if self.m_UpdateTimer < 0 then -- round over or not started yet
		return s_TargetPos
	end

	if Globals.IsConquest then
		local s_Closest = {}  -- kind → position
		local s_Distance = {} -- kind → distance to p_Position
		for l_Index = 1, #self._AllCapturePoints do
			local l_CapturePoint = self._AllCapturePoints[l_Index]

			local s_Kind = 'enemy'
			if l_CapturePoint.team == p_TeamId then
				s_Kind = 'friendly'
			elseif l_CapturePoint.team == TeamId.TeamNeutral then
				s_Kind = 'neutral'
			end

			local s_Pos = l_CapturePoint.transform.trans
			local l_Distance = p_Position and p_Position:Distance(s_Pos) or 0.0
			if s_Closest[s_Kind] == nil or l_Distance < s_Distance[s_Kind] then
				s_Closest[s_Kind] = s_Pos
				s_Distance[s_Kind] = l_Distance
			end
		end
		-- first use enemy-nodes, then neutral, then friendly
		local s_Pos = s_Closest['enemy'] or s_Closest['neutral'] or s_Closest['friendly']
		if s_Pos then
			s_TargetPos = s_Pos:Clone()
		end
	elseif Globals.IsRush then
		-- An MCOM without a trace path has no known position.
		if Globals.IsSquadRush then
			s_TargetPos = self._McomPositions[self.m_RushStageCounter] or s_TargetPos
		else -- Rush-Large, use middle between positions
			local s_McomA = self._McomPositions[self.m_RushStageCounter * 2]
			local s_McomB = self._McomPositions[self.m_RushStageCounter * 2 - 1]
			if s_McomA and s_McomB then
				s_TargetPos = (s_McomA + s_McomB) / 2
			else
				s_TargetPos = s_McomA or s_McomB or s_TargetPos
			end
		end
	end

	return s_TargetPos
end

-- =============================================
-- Private Functions.
-- =============================================

function GameDirector:_RegisterRushEventCallbacks()
	if not Globals.IsRush then
		return
	end

	self.m_RushStageCounter = 0

	-- Register Event for Zone.
	local s_Iterator = EntityManager:GetIterator("ServerSyncedBoolEntity")
	local s_Entity = s_Iterator:Next()

	while s_Entity do
		s_Entity = Entity(s_Entity)

		if s_Entity.data.instanceGuid == Guid("F8D564AC-9235-4141-B320-297BEA370FD8") then
			s_Entity:RegisterEventCallback(function(p_Entity, p_EntityEvent)
				if p_EntityEvent.eventId == MathUtils:FNVHash("SetTrue") then
					self:OnRushZoneDisabled(p_Entity.instanceId)
				end
			end)
		end

		s_Entity = s_Iterator:Next()
	end
end

-- Seconds the game gets to open the next stage once all MCOMs of the stage count as destroyed. Not by then: one of them
-- still stands (a disarm that didn't count, the timer took it for destroyed), all of them are objectives again.
local STAGE_ADVANCE_TIMEOUT = 20.0

---@param p_DeltaTime number
function GameDirector:_UpdateTimersOfMcoms(p_DeltaTime)
	for l_Objective, l_Timer in pairs(self.m_ArmedMcoms) do
		self.m_ArmedMcoms[l_Objective] = l_Timer + p_DeltaTime

		if self.m_ArmedMcoms[l_Objective] >= Registry.GAME_DIRECTOR.MCOMS_CHECK_CYCLE then
			self:OnMcomDestroyed(l_Objective, 'timer')
		end
	end

	-- All MCOMs of the stage destroyed, but no next stage.
	local s_Stage = {}
	local s_AllDestroyed = true
	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if l_Objective.active and not l_Objective.subObjective and l_Objective.name:lower():match('^mcom %d+$') then
			s_Stage[#s_Stage + 1] = l_Objective
			s_AllDestroyed = s_AllDestroyed and l_Objective.destroyed
		end
	end
	if #s_Stage == 0 or not s_AllDestroyed then
		self.m_StageDoneSince = nil
		return
	end
	local s_Now = m_Utilities:GetTime()
	self.m_StageDoneSince = self.m_StageDoneSince or s_Now
	if s_Now - self.m_StageDoneSince < STAGE_ADVANCE_TIMEOUT then
		return
	end
	self.m_StageDoneSince = nil
	m_Logger:Write("stage " .. tostring(self.m_RushStageCounter) .. " not over: its MCOMs are objectives again")
	for l_Index = 1, #s_Stage do
		local l_Objective = s_Stage[l_Index]
		self:_UpdateObjective(l_Objective.name, { team = TeamId.TeamNeutral, isAttacked = false, destroyed = false })
		local s_SubObjective = self:_GetSubObjectiveFromObj(l_Objective.name)
		if s_SubObjective ~= nil then
			self:_UpdateObjective(s_SubObjective, { destroyed = false })
		end
		if m_DebugBridge.m_Enabled then
			m_DebugBridge:Event('mcom_restored', { objective = l_Objective.name })
		end
	end
end

function GameDirector:_InitObjectives()
	self.m_AllObjectives = {}
	self._McomPositions = {}

	-- Every capture point of the engine is an objective, also without paths of its own ("ID_H_US_A" -> "a").
	for _, l_Objective in pairs(self:_EngineCapturePoints()) do
		m_NodeCollection:AddKnownObjective(l_Objective)
	end
	-- Every zone of the mesh (capture points, MCOMs, bases): the paths are trimmed at them and have no names. Not the
	-- spawns of the game (the bots only start there) and not the hubs (where paths meet). An MCOM also gets its
	-- "mcom N interact" (arm or disarm it): the bots do that on the mesh, no path needed (BotZoneMovement).
	for l_Name, l_Zone in pairs(m_NavZones:GetZones()) do
		if l_Name:lower():sub(1, 6) ~= 'spawn ' and l_Zone.Kind ~= 'hub' then
			m_NodeCollection:AddKnownObjective(l_Name)
			if l_Zone.Kind == 'mcom' then
				m_NodeCollection:AddKnownObjective(l_Name .. ' interact')
			end
		end
	end
	local s_Engine = {}
	for _, l_CapturePoint in pairs(self:_EngineCapturePoints()) do
		s_Engine[l_CapturePoint] = true
	end

	for l_ObjectiveName, _ in pairs(m_NodeCollection:GetKnownObjectives()) do
		local s_Objective = {
			name = l_ObjectiveName,
			team = TeamId.TeamNeutral,
			position = nil,
			isAttacked = false,
			isBase = false,
			isSpawnPath = false,
			isEnterVehiclePath = false,
			isEnterAirVehiclePath = false,
			isEnterJetPath = false,
			isBeaconPath = false,
			canBeCaptured = true,
			destroyed = false,
			active = true,
			subObjective = false,
			assigned = {}
		}

		if string.find(l_ObjectiveName:lower(), "base") ~= nil then
			s_Objective.isBase = true

			if string.find(l_ObjectiveName:lower(), "us") ~= nil then
				s_Objective.team = TeamId.Team1
			else
				s_Objective.team = TeamId.Team2
			end
		end

		if string.find(l_ObjectiveName:lower(), "spawn") ~= nil then
			s_Objective.isSpawnPath = true
			s_Objective.active = false
			s_Objective.canBeCaptured = false
		end

		if string.find(l_ObjectiveName:lower(), "beacon") ~= nil then
			s_Objective.isBeaconPath = true
			s_Objective.active = false
			s_Objective.canBeCaptured = false
		end

		if string.find(l_ObjectiveName:lower(), "explore") ~= nil then
			s_Objective.active = false
			s_Objective.canBeCaptured = false
		end

		-- With a mesh the bots go to the vehicles themselves (_RefreshVehicleObjectives): the ways to them are only
		-- objectives where bots spawn into the vehicle ("spawn vehicle ...").
		if string.find(l_ObjectiveName:lower(), "vehicle") ~= nil and m_NavZones:GetMesh() ~= nil
			and not s_Objective.isSpawnPath then
			goto continue_with_next_name
		end

		if string.find(l_ObjectiveName:lower(), "vehicle") ~= nil then
			s_Objective.isEnterVehiclePath = true
			s_Objective.active = false
			s_Objective.canBeCaptured = false

			if string.find(l_ObjectiveName:lower(), "chopper") ~= nil
				or string.find(l_ObjectiveName:lower(), "plane") ~= nil
			then
				s_Objective.isEnterAirVehiclePath = true
			end

			if string.find(l_ObjectiveName:lower(), "plane") ~= nil then
				s_Objective.isEnterJetPath = true
			end

			if string.find(l_ObjectiveName:lower(), "us") ~= nil then
				s_Objective.team = TeamId.Team1
			elseif string.find(l_ObjectiveName:lower(), "ru") ~= nil then
				s_Objective.team = TeamId.Team2
			end
		end

		-- Other names on paths ("explore", "sniper") are nothing to capture. In conquest only the capture points of the
		-- engine and the zones are (rush: the MCOMs, by their numbers, see _UpdateValidObjectives).
		if Globals.IsConquest and not s_Objective.isBase and s_Objective.canBeCaptured and not s_Engine[l_ObjectiveName]
			and m_NavZones:GetZone(l_ObjectiveName) == nil then
			s_Objective.active = false
			s_Objective.canBeCaptured = false
		end

		self.m_AllObjectives[#self.m_AllObjectives + 1] = s_Objective
		::continue_with_next_name::
	end
	self.m_VehicleObjectives = {}

	if Globals.IsRush then
		for l_PathIndex, _ in pairs(m_NodeCollection:GetPaths()) do
			local s_PathWaypoint = m_NodeCollection:GetFirst(l_PathIndex)

			-- Only insert objectives that are objectives (on at least one path alone). Only the path with the action to arm
			-- it (the cut keeps paths named like it that only lead there, NavRoutes:Target).
			if type(s_PathWaypoint) == "table" and s_PathWaypoint.Data.Objectives ~= nil and #s_PathWaypoint.Data.Objectives == 1
				and self:_HasMcomAction(l_PathIndex) then
				local s_ObjectiveName = s_PathWaypoint.Data.Objectives[1]

				if string.find(s_ObjectiveName:lower(), "interact") ~= nil and string.find(s_ObjectiveName:lower(), "mcom") ~= nil then
					local s_Fields = s_ObjectiveName:split(" ")
					local s_Index = nil
					if #s_Fields > 1 then
						s_Index = tonumber(s_Fields[2])
					end
					-- add to list of mcoms
					if s_Index then
						self._McomPositions[s_Index] = s_PathWaypoint.Position
					end
				end
			end
		end
		-- No paths to the MCOMs at all (a new level): the MCOMs of the engine, numbered by their order.
		if next(self._McomPositions) == nil and next(m_NavZones:GetZones()) == nil then
			self:_NumberEngineMcoms()
		end
		-- Without the path to arm it: the middle of its zone.
		for l_Name, l_Zone in pairs(m_NavZones:GetZones()) do
			local s_Index = l_Zone.Kind == 'mcom' and tonumber(l_Name:match('^mcom (%d+)$')) or nil
			if s_Index ~= nil and self._McomPositions[s_Index] == nil then
				self._McomPositions[s_Index] = l_Zone.Center
			end
		end
	end

	self:_InitFlagTeams()
	self:_UpdateValidObjectives()
end

---Whether a waypoint of the path is the action to arm an MCOM.
---@param p_PathIndex integer
---@return boolean
function GameDirector:_HasMcomAction(p_PathIndex)
	local s_Waypoints = m_NodeCollection:Get(nil, p_PathIndex) or {}
	for l_Index = 1, #s_Waypoints do
		local l_Action = s_Waypoints[l_Index].Data and s_Waypoints[l_Index].Data.Action
		if type(l_Action) == 'table' and l_Action.type == 'mcom' then
			return true
		end
	end
	return false
end

---Builds the objectives anew after their paths changed during the round (e.g. by the debug-server). Keeps the rush
---stage and what is known about the objectives that still exist.
function GameDirector:ReloadObjectives()
	local s_Known = {}
	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		s_Known[l_Objective.name] = {
			team = l_Objective.team,
			isAttacked = l_Objective.isAttacked,
			destroyed = l_Objective.destroyed,
			position = l_Objective.position,
			-- Vehicle-objectives are switched on while their vehicle is there (_SetVehicleObjectiveState).
			active = l_Objective.isEnterVehiclePath and l_Objective.active or nil,
		}
	end

	self.m_Translations = {}
	self.m_ObjectivePositions = {}
	self.m_Mcoms = {}
	self.m_McomTries = {}
	-- _InitObjectives counts the stage up outside of conquest (_UpdateValidObjectives), as at the start of the round.
	if not Globals.IsConquest then
		self.m_RushStageCounter = self.m_RushStageCounter - 1
	end
	self:_InitObjectives()

	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		local s_Old = s_Known[l_Objective.name]
		if s_Old ~= nil then
			for l_Key, l_Value in pairs(s_Old) do
				l_Objective[l_Key] = l_Value
			end
		end
	end
end

function GameDirector:_InitFlagTeams()
	self._AllCapturePoints = {}
	self._AllBases = {}
	if not Globals.IsConquest then -- Valid for all Conquest-types. Rush has no capture points.
		return
	end

	local s_Iterator = EntityManager:GetIterator('ServerCapturePointEntity')
	local s_Entity = s_Iterator:Next()

	while s_Entity ~= nil do
		s_Entity = CapturePointEntity(s_Entity)

		if not m_Utilities:IsHq(s_Entity) then
			self._AllCapturePoints[#self._AllCapturePoints + 1] = s_Entity
		else
			self._AllBases[#self._AllBases + 1] = s_Entity
		end

		s_Entity = s_Iterator:Next()
	end

	-- Some levels have the capture points of several modes in one layer, with the same names (XP3_Alborz: two "C").
	-- An owned one is of the running mode: those first, they give the objective its position and team. Else the
	-- first one of the engine.
	local s_Owned = {}
	local s_Neutral = {}
	for l_Index = 1, #self._AllCapturePoints do
		local l_CapturePoint = self._AllCapturePoints[l_Index]
		local s_List = l_CapturePoint.team ~= TeamId.TeamNeutral and s_Owned or s_Neutral
		s_List[#s_List + 1] = l_CapturePoint
	end
	for l_Index = 1, #s_Neutral do
		s_Owned[#s_Owned + 1] = s_Neutral[l_Index]
	end
	self._AllCapturePoints = s_Owned
	local s_Done = {}

	for l_Index = 1, #self._AllCapturePoints do
		local s_CapturePoint = self._AllCapturePoints[l_Index]

		local s_ObjectiveName = self:_TranslateObjective(s_CapturePoint.transform.trans:Clone(), s_CapturePoint.name)
		if s_ObjectiveName ~= "" and not s_Done[s_ObjectiveName] then
			s_Done[s_ObjectiveName] = true
			local s_Objective = self:_GetObjectiveObject(s_ObjectiveName)

			---@diagnostic disable-next-line: need-check-nil
			if not s_Objective.isBase then
				self:_UpdateObjective(s_ObjectiveName, {
					team = s_CapturePoint.team,
					isAttacked = s_CapturePoint.isAttacked
				})
			end
		end
	end
end

function GameDirector:_UpdateValidObjectives()
	if Globals.IsConquest then -- Nothing to do in conquest.
		return
	end

	self.m_RushStageCounter = self.m_RushStageCounter + 1

	if Globals.IsRush then
		local s_McomIndexA = -1
		local s_McomIndexB = -1
		if Globals.IsSquadRush then
			s_McomIndexA = self.m_RushStageCounter
		else -- Rush-Large.
			s_McomIndexA = (self.m_RushStageCounter * 2) - 1
			s_McomIndexB = self.m_RushStageCounter * 2
		end

		for l_Index = 1, #self.m_AllObjectives do
			local l_Objective = self.m_AllObjectives[l_Index]
			local s_Fields = l_Objective.name:split(" ")
			local s_Active = false
			local s_SubObjective = false

			if l_Objective.isSpawnPath or l_Objective.isEnterVehiclePath then
				goto continue_objective_loop
			end

			if not l_Objective.isBase then
				if #s_Fields > 1 then
					local s_Index = tonumber(s_Fields[2])
					if s_Index == s_McomIndexA or s_Index == s_McomIndexB then
						s_Active = true
					end

					if #s_Fields > 2 then -- "MCOM N interact".
						s_SubObjective = true
					end
				end
			else
				if #s_Fields > 2 then
					local s_Index = tonumber(s_Fields[3])

					if s_Index == self.m_RushStageCounter then
						s_Active = true
					end
				end
			end

			l_Objective.active = s_Active
			l_Objective.subObjective = s_SubObjective
			::continue_objective_loop::
		end
	end
end

---@param p_Position Vec3
---@param p_Value boolean
---@return table|nil
function GameDirector:_SetVehicleObjectiveState(p_Position, p_Value)
	local s_Paths = m_NodeCollection:GetPaths()

	if s_Paths == nil then
		return
	end

	local s_ClosestDistance = 10
	local s_ClosestVehicleEnterObjective = nil

	for _, l_Waypoints in pairs(s_Paths) do
		if l_Waypoints[1] ~= nil and l_Waypoints[1].Data ~= nil and l_Waypoints[1].Data.Objectives ~= nil and
			#l_Waypoints[1].Data.Objectives == 1 then
			local s_ObjectiveObject = self:_GetObjectiveObject(l_Waypoints[1].Data.Objectives[1])

			if s_ObjectiveObject ~= nil and s_ObjectiveObject.active ~= p_Value and s_ObjectiveObject.isEnterVehiclePath then -- Only check disabled objectives.
				-- Check position of first and last node.
				local s_FirstNode = l_Waypoints[1]
				local s_LastNode = l_Waypoints[#l_Waypoints]
				local s_TempDistanceFirst = s_FirstNode.Position:Distance(p_Position)
				local s_TempDistanceLast = s_LastNode.Position:Distance(p_Position)
				local s_CloserDistance = s_TempDistanceFirst

				if s_TempDistanceLast < s_TempDistanceFirst then
					s_CloserDistance = s_TempDistanceLast
				end

				if s_CloserDistance < s_ClosestDistance then
					s_ClosestDistance = s_CloserDistance
					s_ClosestVehicleEnterObjective = s_ObjectiveObject
				end
			end
		end
	end

	if s_ClosestVehicleEnterObjective ~= nil then
		s_ClosestVehicleEnterObjective.active = p_Value
	end

	return s_ClosestVehicleEnterObjective
end

---The ways to vehicles lead somewhere only while a vehicle with a free seat stands at their action-node, where the bot
---gets in (Bot:_EnterVehicle, also while its driver waits for passengers). Switched on and off by the events as well
---(_SetVehicleObjectiveState), but a vehicle also leaves without one (driven off after the wait for passengers was
---aborted, taken by the enemy, abandoned): bots got sent to empty places, failed to enter and walked back and forth.
function GameDirector:_RefreshVehicleObjectives()
	if m_NavZones:GetMesh() ~= nil then
		self:_RefreshVehicleEntities()
		return
	end
	local s_Free = {}
	local s_Iterator = EntityManager:GetIterator('ServerVehicleEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		local s_Vehicle = ControllableEntity(s_Entity)
		for l_Seat = 0, s_Vehicle.entryCount - 1 do
			if s_Vehicle:GetPlayerInEntry(l_Seat) == nil then
				s_Free[#s_Free + 1] = s_Vehicle.transform.trans
				break
			end
		end
		s_Entity = s_Iterator:Next()
	end

	local s_Known = m_NodeCollection:GetKnownObjectives()
	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if l_Objective.isEnterVehiclePath and not l_Objective.isSpawnPath and not l_Objective.destroyed then
			local s_There = false
			local s_Paths = s_Known[l_Objective.name] or {}
			for l_PathIndex = 1, #s_Paths do
				local s_Node = self:_VehicleActionNode(s_Paths[l_PathIndex])
				for l_Free = 1, #s_Free do
					if s_Node ~= nil and s_Node.Position:Distance(s_Free[l_Free]) < Registry.VEHICLES.MIN_DISTANCE_VEHICLE_ENTER then
						s_There = true
						break
					end
				end
				if s_There then
					break
				end
			end
			l_Objective.active = s_There
		end
	end

	-- Bots on foot sent to a vehicle that is gone: something else to do (else they walk its way back and forth).
	local s_Bots = g_BotManager:GetBots()
	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		if l_Bot.m_Player.soldier ~= nil and l_Bot.m_ActiveVehicle == nil then
			local s_Objective = self:_GetObjectiveObject(l_Bot:GetObjective())
			if s_Objective ~= nil and s_Objective.isEnterVehiclePath and not s_Objective.isSpawnPath
				and not s_Objective.active and self:GetReservedVehicle(l_Bot) == nil then
				l_Bot:SetObjective('')
			end
		end
	end
end

-- A vehicle faster than this (m/s) is driven: no objective for bots on foot.
local VEHICLE_PARKED_SPEED = 2.0

---The team that may take the vehicle: the one of its passengers, else its own (the team of its spawn), else both.
---@param p_Entity ControllableEntity
---@return TeamId|integer
local function _VehicleTeam(p_Entity)
	for l_Seat = 0, p_Entity.entryCount - 1 do
		local s_Player = p_Entity:GetPlayerInEntry(l_Seat)
		if s_Player ~= nil then
			return s_Player.teamId
		end
	end
	if p_Entity.teamId == TeamId.Team1 or p_Entity.teamId == TeamId.Team2 then
		return p_Entity.teamId
	end
	if p_Entity.defaultTeamId == TeamId.Team1 or p_Entity.defaultTeamId == TeamId.Team2 then
		return p_Entity.defaultTeamId
	end
	return nil
end

-- A vehicle stands this close to the vehicle-spawn of the engine it spawned at.
local VEHICLE_SPAWN_RANGE = 10.0

---The team of the vehicle-spawn of the engine at the position (where a vehicle spawned): the team of its data, else
---of the entity. Also right for rush, where the vehicles of a stage spawn without a team. nil if there is none.
---@param p_Position Vec3
---@return TeamId|integer|nil
function GameDirector:_VehicleSpawnTeam(p_Position)
	local s_Best = nil
	local s_BestDistance = VEHICLE_SPAWN_RANGE
	local s_Iterator = EntityManager:GetIterator('ServerVehicleSpawnEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		local s_Spawn = SpawnEntity(s_Entity)
		local s_Distance = s_Spawn.transform.trans:Distance(p_Position)
		if s_Distance < s_BestDistance then
			local s_Team = nil
			if s_Entity.data ~= nil and s_Entity.data:Is('VehicleSpawnReferenceObjectData') then
				s_Team = VehicleSpawnReferenceObjectData(s_Entity.data).team
			end
			if s_Team ~= TeamId.Team1 and s_Team ~= TeamId.Team2 then
				s_Team = s_Spawn.teamId
			end
			if s_Team == TeamId.Team1 or s_Team == TeamId.Team2 then
				s_Best = s_Team
				s_BestDistance = s_Distance
			end
		end
		s_Entity = s_Iterator:Next()
	end
	return s_Best
end

---Whether the position is in a base of the team: an HQ of the team within VEHICLE_HQ_RANGE, without HQs (rush) a spawn
---of the team within VEHICLE_SPAWN_POINT_RANGE (SpawnPoints).
---@param p_Position Vec3
---@param p_Team TeamId|integer
---@return boolean
function GameDirector:_IsInBase(p_Position, p_Team)
	local s_Bases = self._AllBases or {}
	for l_Index = 1, #s_Bases do
		local l_Hq = s_Bases[l_Index]
		local s_Ok, s_Distance = pcall(function() return l_Hq.transform.trans:Distance(p_Position) end)
		if s_Ok and s_Distance <= VEHICLE_HQ_RANGE and l_Hq.team == p_Team then
			return true
		end
	end
	if #s_Bases > 0 then
		return false
	end
	-- Rush: a spawn of the team in the layers of the mode close by (the bases of the stages).
	local _, s_Distance = m_SpawnPoints:Closest(p_Position, p_Team)
	return s_Distance <= VEHICLE_SPAWN_POINT_RANGE
end

-- An empty vehicle belongs to the owner of the HQ or capture point this close (conquest), of the base this close (rush).
local VEHICLE_OWNER_RANGE = 80.0
local VEHICLE_BASE_RANGE = 150.0

---The team an empty vehicle without a team of its own belongs to: the one of the closest HQ or capture point (it
---spawned there), in rush of the closest base. Else any team may take it (TeamNeutral), as in the game.
---@param p_Position Vec3
---@return TeamId|integer
function GameDirector:_VehicleOwner(p_Position)
	local s_Best = nil
	local s_BestDistance = VEHICLE_OWNER_RANGE
	for _, l_List in ipairs({ self._AllBases or {}, self._AllCapturePoints or {} }) do
		for l_Index = 1, #l_List do
			local l_CapturePoint = l_List[l_Index]
			local s_Ok, s_Distance = pcall(function() return l_CapturePoint.transform.trans:Distance(p_Position) end)
			if s_Ok and s_Distance < s_BestDistance and l_CapturePoint.team ~= TeamId.TeamNeutral then
				s_Best = l_CapturePoint.team
				s_BestDistance = s_Distance
			end
		end
	end
	if s_Best == nil and Globals.IsRush then
		s_BestDistance = VEHICLE_BASE_RANGE
		for l_Index = 1, #self.m_AllObjectives do
			local l_Objective = self.m_AllObjectives[l_Index]
			local s_Position = l_Objective.isBase and self:_GetObjectivePosition(l_Objective.name) or nil
			if s_Position ~= nil and s_Position:Distance(p_Position) < s_BestDistance then
				s_Best = l_Objective.team
				s_BestDistance = s_Position:Distance(p_Position)
			end
		end
	end
	return s_Best or TeamId.TeamNeutral
end

---Levels with a mesh: every vehicle is an objective of its own ("vehicle <id>", isVehicleEntity), active while it
---stands still with a free seat. The bots walk over the mesh to it and get in there (BotZoneMovement), no paths with
---actions needed. Not the stationary weapons and gadgets (AABots, beacons).
function GameDirector:_RefreshVehicleEntities()
	local s_Seen = {}
	local s_Iterator = EntityManager:GetIterator('ServerVehicleEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		local s_Vehicle = ControllableEntity(s_Entity)
		local s_Data = m_Vehicles:GetVehicleByEntity(s_Vehicle)
		if s_Data ~= nil and not m_Vehicles:IsVehicleType(s_Data, VehicleTypes.StationaryAA)
			and not m_Vehicles:IsVehicleType(s_Data, VehicleTypes.Gadgets)
			and not m_Vehicles:IsVehicleType(s_Data, VehicleTypes.MavBot)
			and not m_Vehicles:IsGunship(s_Data) then
			local s_Name = 'vehicle ' .. tostring(s_Vehicle.instanceId)
			s_Seen[s_Name] = true
			local s_Objective = self.m_VehicleObjectives[s_Name]
			if s_Objective == nil then
				s_Objective = {
					name = s_Name,
					team = TeamId.TeamNeutral,
					position = nil,
					isAttacked = false,
					isBase = false,
					isSpawnPath = false,
					isEnterVehiclePath = true,
					isEnterAirVehiclePath = m_Vehicles:IsAirVehicle(s_Data),
					isEnterJetPath = m_Vehicles:IsVehicleType(s_Data, VehicleTypes.Plane),
					isBeaconPath = false,
					isVehicleEntity = true,
					canBeCaptured = false,
					destroyed = false,
					active = false,
					subObjective = false,
					assigned = {},
				}
				self.m_VehicleObjectives[s_Name] = s_Objective
				self.m_AllObjectives[#self.m_AllObjectives + 1] = s_Objective
			end
			s_Objective.entity = s_Vehicle
			s_Objective.position = s_Vehicle.transform.trans:Clone()
			s_Objective.team = _VehicleTeam(s_Vehicle) or self.m_VehicleSpawnTeams[s_Vehicle.instanceId]
				or self:_VehicleOwner(s_Objective.position)
			-- Only seats a bot may take (Bot:_EnterVehicleEntity): else the bots walk to it and don't get in. As many bots
			-- as seats: driver and passengers (the driver waits for them, Config.VehicleWaitForPassengersTime).
			s_Objective.seats = m_Vehicles:FreeBotSeats(s_Vehicle, s_Data)
			s_Objective.active = s_Objective.seats > 0
				and PhysicsEntity(s_Vehicle).velocity.magnitude < VEHICLE_PARKED_SPEED
		end
		s_Entity = s_Iterator:Next()
	end

	-- Gone (destroyed, unspawned): no objective anymore.
	for l_Index = #self.m_AllObjectives, 1, -1 do
		local l_Objective = self.m_AllObjectives[l_Index]
		if l_Objective.isVehicleEntity and not s_Seen[l_Objective.name] then
			l_Objective.active = false
			l_Objective.destroyed = true
			l_Objective.entity = nil
			self.m_VehicleObjectives[l_Objective.name] = nil
			table.remove(self.m_AllObjectives, l_Index)
		end
	end

	-- Bots on foot sent to a vehicle that is gone or taken: something else to do.
	local s_Bots = g_BotManager:GetBots()
	for l_Index = 1, #s_Bots do
		local l_Bot = s_Bots[l_Index]
		if l_Bot.m_Player.soldier ~= nil and l_Bot.m_ActiveVehicle == nil then
			local s_Name = l_Bot:GetObjective()
			local s_Objective = s_Name ~= nil and s_Name:sub(1, 8) == 'vehicle ' and self:_GetObjectiveObject(s_Name) or nil
			if s_Name ~= nil and s_Name:sub(1, 8) == 'vehicle ' and (s_Objective == nil or (s_Objective.isVehicleEntity
				and not s_Objective.active and self:GetReservedVehicle(l_Bot) == nil)) then
				l_Bot:SetObjective('')
			end
		end
	end
end

---Where a bot on the mesh does what its objective asks for, without a path: get into the vehicle (Kind "vehicle",
---Entity), arm or disarm the MCOM (Kind "mcom", objective "mcom N interact": Zone of the MCOM, Position of the MCOM to
---look at, Stand where to stand if known, Yaw). nil for other objectives.
---@param p_Objective string|nil
---@return table|nil
function GameDirector:GetActionTarget(p_Objective)
	local s_Objective = p_Objective ~= nil and p_Objective ~= '' and self:_GetObjectiveObject(p_Objective) or nil
	if s_Objective == nil then
		return nil
	end
	if s_Objective.isVehicleEntity then
		if s_Objective.entity == nil or s_Objective.position == nil then
			return nil
		end
		return { Kind = 'vehicle', Position = s_Objective.position, Entity = s_Objective.entity }
	end
	if s_Objective.subObjective then
		local s_Parent = self:_GetObjectiveFromSubObj(s_Objective.name)
		local s_Zone = s_Parent ~= nil and m_NavZones:GetZone(s_Parent) or nil
		if s_Zone == nil then
			return nil
		end
		local s_Mcom = self:GetMcom(s_Parent)
		if s_Mcom == nil then
			return nil
		end
		local s_Stand = s_Mcom.Stand
		if s_Stand == nil and s_Mcom.Stands ~= nil and #s_Mcom.Stands > 0 then
			-- Without a recorded spot: the free spots around it in turn, the next one after each try that failed.
			s_Stand = s_Mcom.Stands[(self.m_McomTries[s_Parent] or 0) % #s_Mcom.Stands + 1]
		end
		return { Kind = 'mcom', Zone = s_Zone, Position = s_Mcom.Position, Stand = s_Stand, Yaw = s_Mcom.Yaw }
	end
	return nil
end

-- Metres in front of a recorded action-node where the MCOM is (the node is where the soldier stands to arm it).
local MCOM_IN_FRONT = 1.0
-- An MCOM of the engine this close to the middle of the zone of "mcom N" is that MCOM.
local MCOM_ENGINE_MATCH = 15.0

---Where the MCOM ("mcom N") is: Position (to walk up to and look at), and from a recorded path "mcom N interact" Stand
---(the action-node, where the soldier stood) and Yaw. From the MCOMs of the engine (_FindEngineMcoms), else the path,
---else the middle of its zone.
---@param p_Name string
---@return { Position: Vec3, Stand: Vec3|nil, Yaw: number|nil }|nil
function GameDirector:GetMcom(p_Name)
	local s_Known = self.m_Mcoms[p_Name]
	if s_Known ~= nil then
		return s_Known or nil
	end
	s_Known = false
	local s_Zone = m_NavZones:GetZone(p_Name)
	local s_Engine = nil
	if s_Zone ~= nil then
		local s_Best = MCOM_ENGINE_MATCH
		for _, l_Position in ipairs(self:_FindEngineMcoms()) do
			local s_Distance = l_Position:Distance(s_Zone.Center)
			if s_Distance < s_Best then
				s_Best = s_Distance
				s_Engine = l_Position
			end
		end
	end
	local s_Paths = m_NodeCollection:GetKnownObjectives()[p_Name .. ' interact'] or {}
	for l_Index = 1, #s_Paths do
		local s_Waypoints = m_NodeCollection:Get(nil, s_Paths[l_Index]) or {}
		for l_Node = 1, #s_Waypoints do
			local l_Action = s_Waypoints[l_Node].Data and s_Waypoints[l_Node].Data.Action
			if l_Action ~= nil and l_Action.type == 'mcom' and l_Action.yaw ~= nil then
				local s_Stand = s_Waypoints[l_Node].Position
				local s_Front = s_Stand + Vec3(-math.sin(l_Action.yaw), 0.0, math.cos(l_Action.yaw)) * MCOM_IN_FRONT
				s_Known = { Position = s_Engine or s_Front, Stand = s_Stand, Yaw = l_Action.yaw }
				break
			end
		end
		if s_Known then
			break
		end
	end
	if not s_Known and (s_Engine ~= nil or s_Zone ~= nil) then
		s_Known = { Position = s_Engine or s_Zone.Center }
		if s_Engine ~= nil then
			s_Known.Stands = self:_McomStands(s_Engine)
		end
	end
	self.m_Mcoms[p_Name] = s_Known
	return s_Known or nil
end

-- Spots to arm an MCOM from without a recorded one: this far from its interaction point, in MCOM_STAND_DIRECTIONS
-- directions, free at chest height towards it and with ground below.
local MCOM_STAND_DISTANCE = 1.0
local MCOM_STAND_DIRECTIONS = 8

---The free spots around an MCOM (rays), by their angle: the bots try them in turn (McomTryFailed).
---@param p_Position Vec3 the interaction point of the engine
---@return Vec3[]
function GameDirector:_McomStands(p_Position)
	local s_Flags = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.DontCheckWater
	---@cast s_Flags RayCastFlags
	local s_Result = {}
	local s_From = p_Position + Vec3(0.0, 1.0, 0.0)
	for l_Index = 0, MCOM_STAND_DIRECTIONS - 1 do
		local s_Angle = l_Index * 2 * math.pi / MCOM_STAND_DIRECTIONS
		local s_Spot = p_Position + Vec3(math.cos(s_Angle), 0.0, math.sin(s_Angle)) * MCOM_STAND_DISTANCE
		local s_Blocked = RaycastManager:CollisionRaycast(s_From, s_Spot + Vec3(0.0, 1.0, 0.0), 1, 0, s_Flags)[1]
		local s_Ground = RaycastManager:CollisionRaycast(s_Spot + Vec3(0.0, 1.0, 0.0), s_Spot - Vec3(0.0, 1.5, 0.0), 1, 0,
			s_Flags)[1]
		if s_Blocked == nil and s_Ground ~= nil then
			s_Result[#s_Result + 1] = s_Ground.position
		end
	end
	return s_Result
end

---A bot didn't get the MCOM armed or disarmed from where it was: the next bot tries the next free spot around it.
---@param p_Name string "mcom N"
function GameDirector:McomTryFailed(p_Name)
	self.m_McomTries[p_Name] = (self.m_McomTries[p_Name] or 0) + 1
end

-- Two interactions this close are the same MCOM (one per team).
local MCOM_SAME = 1.0
-- An MCOM is close to the waypoints players recorded; the level also has interactions far off (other layouts, dummies).
local MCOM_NEAR_WAYPOINTS = 40.0

---Whether an interaction of the engine is an MCOM of the level: close to the waypoints, or to an MCOM-zone of the mesh
---(the paths are trimmed there).
---@param p_Position Vec3
---@return boolean
function GameDirector:_NearWaypointsOrMcomZone(p_Position)
	for _, l_Zone in pairs(m_NavZones:GetZones()) do
		if l_Zone.Kind == 'mcom' and l_Zone.Center:Distance(p_Position) < MCOM_NEAR_WAYPOINTS then
			return true
		end
	end
	local s_Node = self:FindClosestPath(p_Position, false, true, nil, 1)
	return s_Node ~= nil and s_Node.Position:Distance(p_Position) < MCOM_NEAR_WAYPOINTS
end

---The positions of the MCOMs of the engine (its interactions, GameInteractionEntityData, ~1 m from where a soldier
---arms it), once per level. Only the ones close to the waypoints or to an MCOM-zone.
---@return Vec3[]
function GameDirector:_FindEngineMcoms()
	if self.m_EngineMcoms ~= nil then
		return self.m_EngineMcoms
	end
	self.m_EngineMcoms = {}
	if not Globals.IsRush then
		return self.m_EngineMcoms
	end
	local s_Iterator = EntityManager:GetIterator('ServerInteractionEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		if s_Entity.data ~= nil and s_Entity.data:Is('GameInteractionEntityData') then
			-- Where the census found them (MapCensus _DumpEntity), else as a spatial entity.
			local s_Ok, s_Position = pcall(function() return s_Entity.computedWorldTransform.trans:Clone() end)
			if not s_Ok or s_Position == nil then
				s_Ok, s_Position = pcall(function() return SpatialEntity(s_Entity).transform.trans:Clone() end)
				s_Position = s_Ok and s_Position or nil
			end
			local s_Known = false
			for _, l_Position in ipairs(self.m_EngineMcoms) do
				if s_Position ~= nil and l_Position:Distance(s_Position) < MCOM_SAME then
					s_Known = true
					break
				end
			end
			if s_Position ~= nil and not s_Known and self:_NearWaypointsOrMcomZone(s_Position) then
				self.m_EngineMcoms[#self.m_EngineMcoms + 1] = s_Position
			end
		end
		s_Entity = s_Iterator:Next()
	end
	m_Logger:Write(#self.m_EngineMcoms .. " MCOMs of the engine")
	return self.m_EngineMcoms
end

---Rush without recorded paths to the MCOMs ("mcom N interact"): the MCOMs of the engine get their numbers. Stage 1 is
---the pair (squad rush: the one) closest to the spawn of the attackers, each next stage the closest to the one before.
---Right on 24 of 26 levels with known numbers; check the numbers of a new level (Maps tab, map view).
function GameDirector:_NumberEngineMcoms()
	local s_Mcoms = self:_FindEngineMcoms()
	if #s_Mcoms == 0 then
		return
	end
	-- Where the attackers start: their spawns that are on (all of them if none is on yet).
	local s_Enabled, s_All = {}, {}
	local s_Iterator = EntityManager:GetIterator('ServerCharacterSpawnEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		if s_Entity.data:Is('CharacterSpawnReferenceObjectData')
			and CharacterSpawnReferenceObjectData(s_Entity.data).team == TeamId.Team1 then
			local s_Position = SpawnEntity(s_Entity).transform.trans:Clone()
			s_All[#s_All + 1] = s_Position
			if SpawnEntity(s_Entity).enabled then
				s_Enabled[#s_Enabled + 1] = s_Position
			end
		end
		s_Entity = s_Iterator:Next()
	end
	local s_Spawns = #s_Enabled > 0 and s_Enabled or s_All
	if #s_Spawns == 0 then
		return
	end
	local s_Current = Vec3(0, 0, 0)
	for _, l_Position in ipairs(s_Spawns) do
		s_Current = s_Current + l_Position
	end
	s_Current = s_Current * (1.0 / #s_Spawns)

	local function _Flat(p_A, p_B)
		return math.sqrt((p_A.x - p_B.x) ^ 2 + (p_A.z - p_B.z) ^ 2)
	end
	local s_Left = {}
	for _, l_Position in ipairs(s_Mcoms) do
		s_Left[#s_Left + 1] = l_Position
	end
	local s_PerStage = Globals.IsSquadRush and 1 or 2
	local s_Index = 0
	while #s_Left > 0 do
		table.sort(s_Left, function(p_A, p_B) return _Flat(p_A, s_Current) < _Flat(p_B, s_Current) end)
		local s_Stage = {}
		for _ = 1, math.min(s_PerStage, #s_Left) do
			s_Stage[#s_Stage + 1] = table.remove(s_Left, 1)
		end
		s_Current = Vec3(0, 0, 0)
		for _, l_Position in ipairs(s_Stage) do
			s_Index = s_Index + 1
			self._McomPositions[s_Index] = l_Position
			s_Current = s_Current + l_Position
		end
		s_Current = s_Current * (1.0 / #s_Stage)
	end
	m_Logger:Write("MCOMs numbered from the attackers' spawn: " .. s_Index)
end

---The waypoint of the path where bots get into the vehicle: its action "vehicle", else its last one.
---@param p_PathIndex integer
---@return Waypoint|nil
function GameDirector:_VehicleActionNode(p_PathIndex)
	local s_Waypoints = m_NodeCollection:Get(nil, p_PathIndex) or {}
	for l_Index = #s_Waypoints, 1, -1 do
		local l_Waypoint = s_Waypoints[l_Index]
		if l_Waypoint.Data ~= nil and l_Waypoint.Data.Action ~= nil and l_Waypoint.Data.Action.type == 'vehicle' then
			return l_Waypoint
		end
	end
	return s_Waypoints[#s_Waypoints]
end

---@param p_Name string|nil
---@param p_Data table
function GameDirector:_UpdateObjective(p_Name, p_Data)
	if p_Name == "" then
		return
	end
	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if l_Objective.name == p_Name then
			for l_Key, l_Value in pairs(p_Data) do
				l_Objective[l_Key] = l_Value
			end

			break
		end
	end
end

---@param p_Objective any
---@param p_Position Vec3
---@return number
function GameDirector:_GetDistanceFromObjective(p_Objective, p_Position)
	local s_Position = self:_GetObjectivePosition(p_Objective)
	if s_Position == nil then
		return math.huge
	end
	return s_Position:Distance(p_Position)
end

---The middle of the zone of the objective, else the action-node of its paths (a vehicle, the MCOM to arm), else the
---first node of its path.
---@param p_Objective string|nil
---@return Vec3|nil
function GameDirector:_GetObjectivePosition(p_Objective)
	if p_Objective == nil or p_Objective == '' then
		return nil
	end

	local s_Vehicle = self.m_VehicleObjectives ~= nil and self.m_VehicleObjectives[p_Objective] or nil
	if s_Vehicle ~= nil then
		return s_Vehicle.position
	end

	if self.m_ObjectivePositions[p_Objective] == nil then
		local s_Zone = m_NavZones:GetZone(p_Objective)
		if s_Zone ~= nil then
			self.m_ObjectivePositions[p_Objective] = s_Zone.Center
			return s_Zone.Center
		end
		local s_Paths = m_NodeCollection:GetKnownObjectives()[p_Objective] or {}
		for l_Index = 1, #s_Paths do
			local s_Waypoints = m_NodeCollection:Get(nil, s_Paths[l_Index]) or {}
			for l_Node = 1, #s_Waypoints do
				local l_Waypoint = s_Waypoints[l_Node]
				if l_Waypoint.Data ~= nil and l_Waypoint.Data.Action ~= nil and l_Waypoint.Data.Action.type ~= 'exit' then
					self.m_ObjectivePositions[p_Objective] = l_Waypoint.Position
					return l_Waypoint.Position
				end
			end
		end
		local s_First = s_Paths[1] and m_NodeCollection:Get(1, s_Paths[1])
		if s_First ~= nil then
			self.m_ObjectivePositions[p_Objective] = s_First.Position
		end
	end

	return self.m_ObjectivePositions[p_Objective]
end

-- A soldier arms or disarms an MCOM from up to this far from it (horizontal metres, and MCOM_INTERACT_FLOOR up or down).
local MCOM_INTERACT_RANGE = 4.0
local MCOM_INTERACT_FLOOR = 2.5

---The active MCOM ("mcom N") closest to the position: to any node of its paths, also of the path to it ("mcom N
---interact"), where the soldier arms it. Not a base or another objective close by, the MCOM would never be destroyed.
---@param p_Position Vec3
---@return string|nil
function GameDirector:_TranslateMcom(p_Position)
	-- The MCOMs of the engine first (GetMcom): the player stands right at the one it armed or disarmed. The paths
	-- "mcom N interact" of a level with a mesh lead from the mesh to the MCOM, they can pass the other one.
	local s_Engine = nil
	local s_EngineDistance = MCOM_INTERACT_RANGE
	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if l_Objective.active and not l_Objective.destroyed and l_Objective.name:lower():match('^mcom %d+$') then
			local s_Mcom = self:GetMcom(l_Objective.name)
			if s_Mcom ~= nil then
				local s_DeltaX = s_Mcom.Position.x - p_Position.x
				local s_DeltaZ = s_Mcom.Position.z - p_Position.z
				local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
				if s_Distance < s_EngineDistance and math.abs(s_Mcom.Position.y - p_Position.y) < MCOM_INTERACT_FLOOR then
					s_Engine = l_Objective.name
					s_EngineDistance = s_Distance
				end
			end
		end
	end
	if s_Engine ~= nil then
		return s_Engine
	end

	local s_ClosestObjective = nil
	local s_ClosestDistance = nil

	for l_Name, l_Paths in pairs(m_NodeCollection:GetKnownObjectives()) do
		local s_Fields = l_Name:lower():split(" ")
		local s_McomName = (#s_Fields == 2 or (#s_Fields == 3 and s_Fields[3] == "interact")) and s_Fields[1] == "mcom"
			and "mcom " .. s_Fields[2] or nil
		local s_Mcom = s_McomName and self:_GetObjectiveObject(s_McomName)

		if s_Mcom and s_Mcom.active and not s_Mcom.destroyed then
			for l_Index = 1, #l_Paths do
				local s_First = m_NodeCollection:GetFirst(l_Paths[l_Index])

				if type(s_First) == 'table' and s_First.Data.Objectives ~= nil and #s_First.Data.Objectives == 1 then
					local s_Nodes = m_NodeCollection:Get(nil, l_Paths[l_Index]) or {}

					for l_NodeIndex = 1, #s_Nodes do
						local s_Distance = p_Position:Distance(s_Nodes[l_NodeIndex].Position)

						if s_ClosestDistance == nil or s_Distance < s_ClosestDistance then
							s_ClosestDistance = s_Distance
							s_ClosestObjective = s_Mcom.name
						end
					end
				end
			end
		end
	end

	-- MCOMs without paths of their own (cut at the zones): the zone around the MCOM.
	for l_Name, _ in pairs(m_NodeCollection:GetKnownObjectives()) do
		local s_Mcom = self:_GetObjectiveObject(l_Name)
		local s_Zone = m_NavZones:GetZone(l_Name)
		if s_Zone ~= nil and s_Zone.Kind == 'mcom' and s_Mcom ~= nil and s_Mcom.active and not s_Mcom.destroyed then
			local s_Distance = p_Position:Distance(s_Zone.Center)
			if s_ClosestDistance == nil or s_Distance < s_ClosestDistance then
				s_ClosestDistance = s_Distance
				s_ClosestObjective = s_Mcom.name
			end
		end
	end

	-- Paths without the usual names: as before.
	return s_ClosestObjective or self:_TranslateObjective(p_Position)
end

---The objectives of the capture points of the engine in conquest ("ID_H_US_A" -> "a"), without the HQs.
---@return string[]
function GameDirector:_EngineCapturePoints()
	local s_Result = {}
	if not Globals.IsConquest then
		return s_Result
	end
	local s_Iterator = EntityManager:GetIterator('ServerCapturePointEntity')
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		local s_Objective = self:_EngineObjective(CapturePointEntity(s_Entity).name)
		if s_Objective ~= nil then
			s_Result[#s_Result + 1] = s_Objective
		end
		s_Entity = s_Iterator:Next()
	end
	return s_Result
end

---The objective of a capture point from its name in the engine: "ID_H_US_A" -> "a". nil for the HQs and other names.
---@param p_Name string|nil
---@return string|nil
function GameDirector:_EngineObjective(p_Name)
	if p_Name == nil or string.sub(p_Name, -2) == 'HQ' then
		return nil
	end
	local s_Letter = p_Name:match('_(%a)$')
	return s_Letter ~= nil and s_Letter:lower() or nil
end

---@param p_Position Vec3
---@param p_Name string|nil
---@return string|nil
function GameDirector:_TranslateObjective(p_Position, p_Name)
	if p_Name ~= nil and self.m_Translations[p_Name] ~= nil then
		return self.m_Translations[p_Name]
	end

	-- The name in the engine, where it has one: the paths might be labelled wrongly.
	local s_EngineObjective = self:_EngineObjective(p_Name)
	local s_Object = s_EngineObjective ~= nil and self:_GetObjectiveObject(s_EngineObjective) or nil
	if s_Object ~= nil then
		self.m_Translations[p_Name] = s_EngineObjective
		self.m_ObjectivePositions[s_EngineObjective] = p_Position:Clone()
		s_Object.position = p_Position
		return s_EngineObjective
	end

	local s_AllObjectives = m_NodeCollection:GetKnownObjectives()
	local s_PathsDone = {}
	local s_ClosestObjective = nil
	local s_ClosestDistance = nil

	for l_Objective, l_Paths in pairs(s_AllObjectives) do
		for l_Index = 1, #l_Paths do
			local l_Path = l_Paths[l_Index]
			if s_PathsDone[l_Path] then
				goto continue_paths_loop
			end

			local s_Node = m_NodeCollection:Get(1, l_Path)

			if s_Node == nil or s_Node.Data.Objectives == nil or #s_Node.Data.Objectives ~= 1 then
				goto continue_paths_loop
			end

			-- Possible objective.
			local s_TempObject = self:_GetObjectiveObject(l_Objective)

			if s_TempObject == nil or s_TempObject.canBeCaptured then
				local s_Distance = p_Position:Distance(s_Node.Position)

				if s_ClosestDistance == nil or s_ClosestDistance > s_Distance then
					s_ClosestObjective = s_TempObject
					s_ClosestDistance = s_Distance
				end
			end

			s_PathsDone[l_Path] = true
			::continue_paths_loop::
		end

		-- Without a path of its own (cut at the zones): the middle of its zone.
		local s_Zone = m_NavZones:GetZone(l_Objective)
		if s_Zone ~= nil and s_Zone.Kind ~= 'mcom' then
			local s_TempObject = self:_GetObjectiveObject(l_Objective)
			if s_TempObject == nil or s_TempObject.canBeCaptured then
				local s_Distance = p_Position:Distance(s_Zone.Center)
				if s_ClosestDistance == nil or s_ClosestDistance > s_Distance then
					s_ClosestObjective = s_TempObject
					s_ClosestDistance = s_Distance
				end
			end
		end
	end

	if p_Name ~= nil and s_ClosestObjective ~= nil then
		self.m_Translations[p_Name] = s_ClosestObjective.name
		self.m_ObjectivePositions[p_Name] = p_Position:Clone()
		s_ClosestObjective.position = p_Position
	end

	if s_ClosestObjective ~= nil then
		return s_ClosestObjective.name
	else
		return ""
	end
end

---@param p_Name string
---@return table|nil
function GameDirector:_GetObjectiveObject(p_Name)
	for l_Index = 1, #self.m_AllObjectives do
		local l_Objective = self.m_AllObjectives[l_Index]
		if l_Objective.name == p_Name then
			return l_Objective
		end
	end
end

---@param p_Objective string
---@return string|nil
function GameDirector:_GetSubObjectiveFromObj(p_Objective)
	for l_Index = 1, #self.m_AllObjectives do
		local l_TempObjective = self.m_AllObjectives[l_Index]
		if l_TempObjective.subObjective and l_TempObjective.name ~= p_Objective then
			local s_Name = l_TempObjective.name:lower()

			if string.find(s_Name, p_Objective:lower()) ~= nil then
				return l_TempObjective.name
			end
		end
	end
end

---@param p_SubObjective string
---@return string|nil
function GameDirector:_GetObjectiveFromSubObj(p_SubObjective)
	for l_Index = 1, #self.m_AllObjectives do
		local l_TempObjective = self.m_AllObjectives[l_Index]
		if not l_TempObjective.subObjective and l_TempObjective.name ~= p_SubObjective then
			local s_Name = l_TempObjective.name:lower()

			if string.find(p_SubObjective:lower(), s_Name) ~= nil then
				return l_TempObjective.name
			end
		end
	end
end

---@param p_BotTeam TeamId|integer
---@param p_ObjectiveName string
---@return boolean
function GameDirector:_UseSubobjective(p_BotTeam, p_ObjectiveName)
	local s_Use = false
	local s_Objective = self:_GetObjectiveObject(p_ObjectiveName)

	if s_Objective ~= nil and s_Objective.subObjective then
		if s_Objective.active and not s_Objective.destroyed then
			-- Arming and disarming change the MCOM itself ("mcom N", see OnMcomArmed), not "mcom N interact".
			local s_State = s_Objective
			local s_ParentName = self:_GetObjectiveFromSubObj(p_ObjectiveName)
			local s_Parent = s_ParentName and self:_GetObjectiveObject(s_ParentName)
			if s_Parent ~= nil then
				s_State = s_Parent
			end

			if p_BotTeam == TeamId.Team1 and s_State.team == TeamId.TeamNeutral then
				s_Use = true -- Attacking Team.
			elseif p_BotTeam == TeamId.Team2 and s_State.isAttacked then
				s_Use = true -- Defending Team.
			end
		end
	end

	return s_Use
end

if g_GameDirector == nil then
	---@type GameDirector
	g_GameDirector = GameDirector()
end

return g_GameDirector
