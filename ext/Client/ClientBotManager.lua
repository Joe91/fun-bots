---@class ClientBotManager
---@overload fun():ClientBotManager
ClientBotManager = class('ClientBotManager')

---@type WeaponList
local m_WeaponList = require('__shared/WeaponList')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Logger
local m_Logger = Logger("ClientBotManager", Debug.Client.INFO)

function ClientBotManager:__init()
	self:RegisterVars()
end

function ClientBotManager:RegisterVars()
	self.m_ReadyToUpdate = false
	self.m_RaycastTimer = 0
	self.m_AliveTimer = 0
	self.m_LastIndex = 0
	-- Ids of the enemy bots of the local player for the enemy-check (rebuilt every CLIENT.ENEMY_LIST_INTERVAL).
	self.m_EnemyBotIds = {}
	self.m_EnemyListTeam = nil
	self.m_EnemyListNs = nil

	---@type RaycastRequests[]
	self.m_BotBotRaycastsToDo = {}
	self.m_Player = nil
	self.m_UpdateInterval = 1.0 / 60.0
	self.m_LastUpdateNs = nil
	self.m_LastRenderNs = nil
	-- Inputs for change of seats (1-8).
	self.m_LastInputLevelsPos = { 0, 0, 0, 0, 0, 0, 0, 0 }
	self:_ResetRayStats()
end

---Debug (Registry.DEBUG.ROUND_STATS_INTERVAL > 0): costs of the sight-raycasts of this client, sent to the server
---every interval and printed there with the round-stats.
function ClientBotManager:_ResetRayStats()
	self._RayStats = {
		StartNs = SharedUtils:GetTimeNS(), Frames = 0, Rays = 0, RayMs = 0.0, RayMaxMs = 0.0, FrameRayMaxMs = 0.0,
		BotBotReceived = 0, BotBotDone = 0, BotBotVisible = 0, Dropped = 0, QueueMax = 0, EnemyRays = 0,
		SlowRays = 0, UpdateMs = 0.0, UpdateMaxMs = 0.0, RenderFrames = 0, RenderMaxMs = 0.0, Hitches = 0,
		GcUpdates = 0, GcMaxMs = 0.0, NoGcMaxMs = 0.0, SlowRaysGc = 0, PlayersMaxMs = 0.0, SendMaxMs = 0.0,
		PairMaxMs = 0.0, OtherMaxMs = 0.0,
	}
end

-- =============================================
-- Events
-- =============================================

---VEXT Client Client:UpdateInput Event
---@param p_DeltaTime number
function ClientBotManager:OnClientUpdateInput(p_DeltaTime)
	if not self.m_ReadyToUpdate then
		return
	end
	-- To-do: find a better solution for that!!!
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_Q) then
		-- Execute Vehicle Enter Detection here.
		self.m_Player = PlayerManager:GetLocalPlayer()
		if self.m_Player ~= nil and self.m_Player.inVehicle then
			local s_Transform = ClientUtils:GetCameraTransform()

			if s_Transform == nil then return end

			-- The free cam transform is inverted. Invert it back.
			local s_CameraForward = Vec3(s_Transform.forward.x * -1, s_Transform.forward.y * -1, s_Transform.forward.z * -1)

			local s_MaxEnterDistance = 50
			local s_CastPosition = Vec3(s_Transform.trans.x + (s_CameraForward.x * s_MaxEnterDistance),
				s_Transform.trans.y + (s_CameraForward.y * s_MaxEnterDistance),
				s_Transform.trans.z + (s_CameraForward.z * s_MaxEnterDistance))

			local s_StartPosition = s_Transform.trans:Clone() + s_CameraForward * 4

			local s_RaycastFlags = RayCastFlags.DontCheckWater | RayCastFlags.IsAsyncRaycast
			---@cast s_RaycastFlags RayCastFlags
			local s_Raycast = RaycastManager:Raycast(s_StartPosition, s_CastPosition, s_RaycastFlags)

			if s_Raycast ~= nil and s_Raycast.rigidBody ~= nil and s_Raycast.rigidBody:Is("CharacterPhysicsEntity") then
				-- Find a teammate at this position.
				local s_PlayersByTeam = PlayerManager:GetPlayersByTeam(self.m_Player.teamId)
				for l_Index = 1, #s_PlayersByTeam do
					local l_Player = s_PlayersByTeam[l_Index]
					if l_Player.soldier ~= nil and m_Utilities:isBot(l_Player) and
						l_Player.soldier.worldTransform.trans:Distance(s_Raycast.position) < 2 then
						NetEvents:SendLocal('Client:RequestEnterVehicle', l_Player.id)
						break
					end
				end
			end
		end
	end
end

---VEXT Client Input:PreUpdate Hook
---@param p_HookCtx HookContext
---@param p_Cache ConceptCache
---@param p_DeltaTime number
function ClientBotManager:OnInputPreUpdate(p_HookCtx, p_Cache, p_DeltaTime)
	if not self.m_ReadyToUpdate then
		return
	end

	-- Don't use a cached player, the local player object can be destroyed at round end.
	self.m_Player = PlayerManager:GetLocalPlayer()
	if self.m_Player ~= nil and self.m_Player.alive and self.m_Player.inVehicle then
		for i = 1, 8 do
			local s_Varname = "ConceptSelectPosition" .. tostring(i)
			local s_LevelId = InputConceptIdentifiers[s_Varname]
			local s_CurrentLevel = p_Cache:GetLevel(s_LevelId)

			if self.m_LastInputLevelsPos[i] == 0 and s_CurrentLevel > 0 then
				NetEvents:SendLocal('Client:RequestChangeVehicleSeat', i)
			end

			self.m_LastInputLevelsPos[i] = s_CurrentLevel
		end
	end
end

---VEXT Shared Engine:Message Event
---@param p_Message Message
function ClientBotManager:OnEngineMessage(p_Message)
	if p_Message.type == MessageType.ClientStateEnteredIngameMessage then --MessageType.ClientLevelFinalizedMessage then
		NetEvents:SendLocal('Client:RequestSettings')
		self:RegisterVars()
		m_Logger:Write("level loaded on Client")
	end

	if p_Message.type == MessageType.ClientConnectionUnloadLevelMessage or
		p_Message.type == MessageType.UIRequestEndOfRoundMessage then
		print("End: " .. tostring(p_Message.type))
		self.m_ReadyToUpdate = false
	end
end

---The position a bot looks from / is seen at for the bot-bot sight-check: 1.4 m above its vehicle or soldier.
---@param p_Player Player|nil
---@param p_WantsVehicle boolean the server saw the bot in a vehicle
---@return Vec3|nil @nil without a soldier
---@return boolean @in a vehicle (the ray starts / ends outside of it)
local function _GetSightPosition(p_Player, p_WantsVehicle)
	if p_Player == nil then
		return nil, false
	end
	local s_Soldier = p_Player.soldier
	if s_Soldier == nil then
		return nil, false
	end
	local s_Position = nil
	local s_InVehicle = false
	if p_WantsVehicle then
		local s_Controllable = p_Player.controlledControllable
		if s_Controllable ~= nil then
			s_Position = s_Controllable.transform.trans:Clone()
			s_InVehicle = true
		end
	end
	if s_Position == nil then
		s_Position = s_Soldier.worldTransform.trans:Clone()
	end
	s_Position.y = s_Position.y + 1.4
	return s_Position, s_InVehicle
end

---The flags of the sight-raycasts, built once (the enums are looked up through the engine).
local m_SightMaterialFlags = nil
local m_SightCollisionFlags = nil
local m_SightCollisionFlagsDetail = nil

local function _InitSightFlags()
	-- Describes what doesn't end the raycast on a collision:
	m_SightMaterialFlags = MaterialFlags.MfSeeThrough -- windows
		-- MaterialFlags.MfNoCollisionResponse | -- no effect?
		-- MaterialFlags.MfNoCollisionResponseCombined | -- no effect?
		| MaterialFlags.MfPenetrable -- soldiers + solid fences (only with detailed-Mesh-Check)
		-- MaterialFlags.MfBashable | -- ???
		| MaterialFlags.MfClientDestructible -- some open fences, some crates
	m_SightCollisionFlags = RayCastFlags.DontCheckWater
	-- The detail mesh is needed to detect some fences as shoot-through.
	m_SightCollisionFlagsDetail = m_SightCollisionFlags | RayCastFlags.CheckDetailMesh
end

---@param p_Pos1 Vec3
---@param p_Pos2 Vec3
---@param p_InObjectPos1 boolean
---@param p_InObjectPos2 boolean
---@return boolean
function ClientBotManager:DoRaycast(p_Pos1, p_Pos2, p_InObjectPos1, p_InObjectPos2)
	if Registry.DEBUG.ROUND_STATS_INTERVAL <= 0 then
		return self:_DoRaycast(p_Pos1, p_Pos2, p_InObjectPos1, p_InObjectPos2)
	end

	local s_MemKb = collectgarbage('count')
	local s_StartNs = SharedUtils:GetTimeNS()
	local s_Visible = self:_DoRaycast(p_Pos1, p_Pos2, p_InObjectPos1, p_InObjectPos2)
	local s_Ms = (SharedUtils:GetTimeNS() - s_StartNs) / 1000000
	local s_Stats = self._RayStats
	s_Stats.Rays = s_Stats.Rays + 1
	s_Stats.RayMs = s_Stats.RayMs + s_Ms
	s_Stats.RayMaxMs = math.max(s_Stats.RayMaxMs, s_Ms)
	s_Stats.FrameRayMs = (s_Stats.FrameRayMs or 0) + s_Ms
	if s_Ms > 2.0 then
		s_Stats.SlowRays = s_Stats.SlowRays + 1
		-- Less memory afterwards: the garbage-collector ran inside.
		if collectgarbage('count') < s_MemKb then
			s_Stats.SlowRaysGc = s_Stats.SlowRaysGc + 1
		end
	end
	return s_Visible
end

---@param p_Pos1 Vec3
---@param p_Pos2 Vec3
---@param p_InObjectPos1 boolean
---@param p_InObjectPos2 boolean
---@return boolean
function ClientBotManager:_DoRaycast(p_Pos1, p_Pos2, p_InObjectPos1, p_InObjectPos2)
	if Registry.COMMON.USE_COLLISION_RAYCASTS then
		if m_SightMaterialFlags == nil then
			_InitSightFlags()
		end

		if p_InObjectPos1 then -- Start Raycast outside of vehicle
			p_Pos1 = p_Pos1 + ((p_Pos2 - p_Pos1):Normalize() * 3.2)
		end

		-- no need to go through bot, since soldier position should already cause the collision

		local s_MaterialFlags = m_SightMaterialFlags
		---@cast s_MaterialFlags MaterialFlags
		local s_RaycastFlags = Registry.COMMON.USE_DETAILED_MESH_RAYCASTS and m_SightCollisionFlagsDetail or
			m_SightCollisionFlags
		---@cast s_RaycastFlags RayCastFlags

		local s_RayHits = RaycastManager:CollisionRaycast(p_Pos1, p_Pos2, 5, s_MaterialFlags, s_RaycastFlags) -- only 5 hits supported at the moment

		if p_InObjectPos2 then
			return m_Utilities:IsInSight(s_RayHits, s_MaterialFlags, p_Pos2, true)
		end

		-- right now only 5 hits possible. abort if 5 hits
		local s_HitCount = #s_RayHits
		if s_HitCount == 0 or s_HitCount >= 5 then
			return false
		end
		local s_RigidBody = s_RayHits[s_HitCount].rigidBody
		return s_RigidBody ~= nil and s_RigidBody:Is("CharacterPhysicsEntity")
	else
		if p_InObjectPos1 or p_InObjectPos2 then
			local s_DeltaPos = p_Pos2 - p_Pos1
			s_DeltaPos = s_DeltaPos:Normalize()

			if p_InObjectPos1 then -- Start Raycast outside of vehicle?
				p_Pos1 = p_Pos1 + (s_DeltaPos * 3.2)
			end

			if p_InObjectPos2 then
				p_Pos2 = p_Pos2 - (s_DeltaPos * 3.2)
			end
		end

		local s_RaycastFlags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast
		if Registry.COMMON.USE_DETAILED_MESH_RAYCASTS then
			s_RaycastFlags = s_RaycastFlags | RayCastFlags.CheckDetailMesh -- not sure if this makes a difference for the normal raycast
		end
		---@cast s_RaycastFlags RayCastFlags
		local s_Raycast = RaycastManager:Raycast(p_Pos1, p_Pos2, s_RaycastFlags)

		if s_Raycast == nil or s_Raycast.rigidBody == nil then
			return true
		else
			return false
		end
	end
end

---@param p_RaycastResultsToSend RaycastResults
function ClientBotManager:SendRaycastResults(p_RaycastResultsToSend)
	-- Skip empty results, otherwise every client sends a reliable NetEvent each frame.
	if #p_RaycastResultsToSend == 0 then
		return
	end

	local s_StartNs = SharedUtils:GetTimeNS()
	NetEvents:SendLocal("Botmanager:RaycastResults", p_RaycastResultsToSend)
	local s_Ms = (SharedUtils:GetTimeNS() - s_StartNs) / 1000000
	local s_Stats = self._RayStats
	s_Stats.SendMaxMs = math.max(s_Stats.SendMaxMs, s_Ms)
	s_Stats.SendMs = (s_Stats.SendMs or 0) + s_Ms
	s_Stats.Sends = (s_Stats.Sends or 0) + 1
	s_Stats.FrameSendMs = (s_Stats.FrameSendMs or 0) + s_Ms
end

---VEXT Shared UpdateManager:Update Event
---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function ClientBotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass == UpdatePass.UpdatePass_PreFrame and Registry.DEBUG.ROUND_STATS_INTERVAL > 0 then
		self:_CountRenderFrame()
		return
	end

	if p_UpdatePass ~= UpdatePass.UpdatePass_PreSim or not self.m_ReadyToUpdate then -- UpdatePass_PreSim UpdatePass_PreFrame
		return
	end

	-- Real interval of this update (the tickrate of the server, p_DeltaTime is not it), smoothed: the timer has 1 ms.
	local s_NowNs = SharedUtils:GetTimeNS()
	if self.m_LastUpdateNs ~= nil then
		local s_Interval = math.min(math.max((s_NowNs - self.m_LastUpdateNs) / 1000000000, 0.004), 0.1)
		self.m_UpdateInterval = self.m_UpdateInterval * 0.95 + s_Interval * 0.05
	end
	self.m_LastUpdateNs = s_NowNs

	if Registry.DEBUG.ROUND_STATS_INTERVAL <= 0 then
		self:_UpdateRaycasts(p_DeltaTime)
		return
	end

	self:_UpdateRayStats()
	local s_MemKb = collectgarbage('count')
	local s_StartNs = SharedUtils:GetTimeNS()
	self._RayStats.FrameSendMs = 0
	self:_UpdateRaycasts(p_DeltaTime)
	local s_Ms = (SharedUtils:GetTimeNS() - s_StartNs) / 1000000
	local s_Stats = self._RayStats
	s_Stats.OtherMaxMs = math.max(s_Stats.OtherMaxMs, s_Ms - (s_Stats.FrameRayMs or 0) - s_Stats.FrameSendMs)
	s_Stats.UpdateMs = s_Stats.UpdateMs + s_Ms
	s_Stats.UpdateMaxMs = math.max(s_Stats.UpdateMaxMs, s_Ms)
	if collectgarbage('count') < s_MemKb then
		s_Stats.GcUpdates = s_Stats.GcUpdates + 1
		s_Stats.GcMaxMs = math.max(s_Stats.GcMaxMs, s_Ms)
	else
		s_Stats.NoGcMaxMs = math.max(s_Stats.NoGcMaxMs, s_Ms)
	end
end

---The sight-raycasts of one update: bot-bot requests of the server, enemy bots / revives of the local player.
---@param p_DeltaTime number
function ClientBotManager:_UpdateRaycasts(p_DeltaTime)
	local s_RaycastResultsToSend = {}

	self.m_RaycastTimer = self.m_RaycastTimer + p_DeltaTime
	-- With server-raycasts the server checks the enemy-bots and revives of this player as well.
	local s_SkipEnemyCheck = not Config.BotsAttackPlayers or Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS or
		(self.m_RaycastTimer < Registry.GAME_RAYCASTING.RAYCAST_INTERVAL_ENEMY_CHECK)

	-- Check bot-bot attack.
	if #self.m_BotBotRaycastsToDo > 0 then
		-- This update runs with the tickrate of the server. Below 60 Hz the budget per update grows, so the clients do as
		-- many raycasts per second as with 60 Hz (the server sends them, see BotManager:ConfigGlobals).
		local s_TickScale = math.max(1.0, self.m_UpdateInterval * 60.0)
		local s_MaxRaycastsBotBot = math.floor(Registry.GAME_RAYCASTING.MAX_RAYCASTS_PER_PLAYER_PER_CYCLE * s_TickScale + 0.5)
		self._RayStats.TickScale = s_TickScale

		if not s_SkipEnemyCheck then
			s_MaxRaycastsBotBot = s_MaxRaycastsBotBot - Registry.CLIENT.ENEMY_RAYCASTS_PER_CYCLE
		end

		local s_Queue = self.m_BotBotRaycastsToDo
		for _ = 1, math.min(s_MaxRaycastsBotBot, #s_Queue) do
			---@type RaycastRequests
			local s_RaycastCheckEntry = table.remove(s_Queue, 1)
			local s_PairNs = SharedUtils:GetTimeNS()
			-- The request is some frames old, the bots might have left their vehicles in the meantime.
			local s_StartPos, s_Bot1InVehicle = _GetSightPosition(PlayerManager:GetPlayerById(s_RaycastCheckEntry.Bot1),
				s_RaycastCheckEntry.Bot1InVehicle)
			local s_EndPos, s_Bot2InVehicle = nil, false
			if s_StartPos ~= nil then
				s_EndPos, s_Bot2InVehicle = _GetSightPosition(PlayerManager:GetPlayerById(s_RaycastCheckEntry.Bot2),
					s_RaycastCheckEntry.Bot2InVehicle)
			end

			self._RayStats.PairMaxMs = math.max(self._RayStats.PairMaxMs, (SharedUtils:GetTimeNS() - s_PairNs) / 1000000)
			if s_EndPos ~= nil then
				self._RayStats.BotBotDone = self._RayStats.BotBotDone + 1
				if self:DoRaycast(s_StartPos, s_EndPos, s_Bot1InVehicle, s_Bot2InVehicle) then
					self._RayStats.BotBotVisible = self._RayStats.BotBotVisible + 1
					s_RaycastResultsToSend[#s_RaycastResultsToSend + 1] = {
						Mode = RaycastResultModes.ShootAtBot,
						Bot1 = s_RaycastCheckEntry.Bot1,
						Bot2 = s_RaycastCheckEntry.Bot2,
						IgnoreYaw = false,
					}
				end
			end
		end

		-- Check for too many entries.
		if #self.m_BotBotRaycastsToDo > Registry.GAME_RAYCASTING.MAX_QUEUED_RAYCASTS_BOT_BOT then
			m_Logger:Write("More Raycasts than doable")
			self._RayStats.Dropped = self._RayStats.Dropped + #self.m_BotBotRaycastsToDo
			self.m_BotBotRaycastsToDo = {}
		end
	end

	self.m_Player = PlayerManager:GetLocalPlayer()
	if self.m_Player == nil then
		self:SendRaycastResults(s_RaycastResultsToSend)
		return
	end

	if s_SkipEnemyCheck then
		self:SendRaycastResults(s_RaycastResultsToSend)
		return
	end

	self.m_RaycastTimer = 0
	local s_CheckCount = 0

	if self.m_Player.alive and self.m_Player.soldier ~= nil then -- Alive. Check for enemy bots.
		if self.m_AliveTimer < Registry.CLIENT.SPAWN_PROTECTION then -- Wait 2s (spawn-protection).
			self.m_AliveTimer = self.m_AliveTimer + p_DeltaTime
			self:SendRaycastResults(s_RaycastResultsToSend)
			return
		end

		local s_OwnTeam = self.m_Player.teamId
		if s_OwnTeam == TeamId.TeamNeutral then -- Don't let bots attack spectators.
			self:SendRaycastResults(s_RaycastResultsToSend)
			return
		end

		local s_EnemyBotIds = self:_GetEnemyBotIds(s_OwnTeam)
		if self.m_LastIndex >= #s_EnemyBotIds then
			self.m_LastIndex = 0
		end

		-- Check for clear view.
		local s_PlayerInVehicle = self.m_Player.inVehicle and self.m_Player.controlledControllable ~= nil
		local s_PlayerPosition = Vec3()
		if s_PlayerInVehicle then
			s_PlayerPosition = self.m_Player.controlledControllable.transform.trans:Clone()
			s_PlayerPosition.y = s_PlayerPosition.y + 1.4
		else
			local s_CameraTransform = ClientUtils:GetCameraTransform()
			if s_CameraTransform == nil then
				self:SendRaycastResults(s_RaycastResultsToSend)
				return
			end
			s_PlayerPosition = s_CameraTransform.trans:Clone() -- player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(player, false)
		end

		local s_MaxVehicleDistance = math.max(Config.MaxShootDistanceVehicles, Config.MaxShootDistanceGunship)
		local s_MaxPlayerDistance = math.max(Config.MaxShootDistanceMissileAir, Config.MaxShootDistanceSniper)
		local s_EnemyRaycasts = 0

		for i = 0, #s_EnemyBotIds - 1 do
			local s_Index = (self.m_LastIndex + i) % #s_EnemyBotIds + 1
			local s_Bot = PlayerManager:GetPlayerById(s_EnemyBotIds[s_Index])

			-- The list is up to a second old: the id might be free again or the bot in another team now.
			if s_Bot == nil or s_Bot.onlineId ~= 0 or s_Bot.teamId == s_OwnTeam or s_Bot.soldier == nil then
				goto continue_enemy_loop
			end

			-- Find direction of Bot.
			local s_TargetPos = Vec3()
			local s_BotInVehicle = s_Bot.inVehicle and s_Bot.controlledControllable ~= nil

			if s_BotInVehicle then
				s_TargetPos = s_Bot.controlledControllable.transform.trans:Clone()
				s_TargetPos.y = s_TargetPos.y + 1.4
			else
				s_TargetPos = s_Bot.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(s_Bot, false, false)
			end

			local s_Distance = s_PlayerPosition:Distance(s_TargetPos)

			s_CheckCount = s_CheckCount + 1

			if (not s_BotInVehicle and (s_Distance < s_MaxPlayerDistance)) or (s_BotInVehicle and (s_Distance < s_MaxVehicleDistance)) then
				self._RayStats.EnemyRays = self._RayStats.EnemyRays + 1
				if self:DoRaycast(s_PlayerPosition, s_TargetPos, s_PlayerInVehicle, s_BotInVehicle) then
					-- We found a valid bot in Sight (either no hit, or player-hit). Signal Server with players.
					local s_IgnoreYaw = false

					if s_Distance < Config.DistanceForDirectAttack then
						s_IgnoreYaw = true -- Shoot, because you are near.
					end

					table.insert(s_RaycastResultsToSend, {
						Mode = RaycastResultModes.ShootAtPlayer,
						Bot1 = s_Bot.id,
						Bot2 = 0,
						IgnoreYaw = s_IgnoreYaw,
					})
				end

				self.m_LastIndex = s_Index
				s_EnemyRaycasts = s_EnemyRaycasts + 1
				if s_EnemyRaycasts >= Registry.CLIENT.ENEMY_RAYCASTS_PER_CYCLE then
					self:SendRaycastResults(s_RaycastResultsToSend)
					return
				end
				goto continue_enemy_loop
			end

			if s_CheckCount >= Registry.CLIENT.MAX_CHECKS_PER_CYCLE then
				self.m_LastIndex = s_Index
				self:SendRaycastResults(s_RaycastResultsToSend)
				return
			end

			::continue_enemy_loop::
		end
	elseif self.m_Player.corpse ~= nil and not self.m_Player.corpse.isDead then -- Dead. Check for revive botsAttackBots.
		self.m_AliveTimer = 0.5                                              -- Add a little delay.
		local s_TeamMates = PlayerManager:GetPlayersByTeam(self.m_Player.teamId)

		if self.m_LastIndex >= #s_TeamMates then
			self.m_LastIndex = 0
		end

		for i = 0, #s_TeamMates - 1 do
			local s_Index = (self.m_LastIndex + i) % #s_TeamMates + 1
			local s_Bot = s_TeamMates[s_Index]

			if s_Bot == nil or s_Bot.onlineId ~= 0 or s_Bot.soldier == nil or s_Bot.inVehicle then
				goto continue_teamMate_loop
			end

			-- Check for clear view.
			local s_PlayerPosition = self.m_Player.corpse.worldTransform.trans:Clone()
			s_PlayerPosition.y = s_PlayerPosition.y + 0.4

			-- Find direction of Bot.
			local s_Target = s_Bot.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(s_Bot, false, false)
			local s_Distance = s_PlayerPosition:Distance(s_Bot.soldier.worldTransform.trans)

			s_CheckCount = s_CheckCount + 1

			if s_Distance < Registry.CLIENT.REVIVE_DISTANCE then -- To-do: use config var for this.
				self.m_LastIndex = s_Index

				if self:DoRaycast(s_PlayerPosition, s_Target, false, false) then
					-- We found a valid bot in Sight (either no hit, or player-hit). Signal Server with players.
					table.insert(s_RaycastResultsToSend, {
						Mode = RaycastResultModes.RevivePlayer,
						Bot1 = s_Bot.id,
						Bot2 = 0,
						IgnoreYaw = false,
					})
				end

				self:SendRaycastResults(s_RaycastResultsToSend)
				return -- Only one raycast per cycle.
			end

			if s_CheckCount >= Registry.CLIENT.MAX_CHECKS_PER_CYCLE then
				self.m_LastIndex = s_Index
				self:SendRaycastResults(s_RaycastResultsToSend)
				return
			end

			::continue_teamMate_loop::
		end
	else
		self.m_AliveTimer = 0 -- Add a little delay after spawn.
	end

	self:SendRaycastResults(s_RaycastResultsToSend)
end

---The ids of the bots in the other teams. Building the list touches every player, so it is only rebuilt every
---CLIENT.ENEMY_LIST_INTERVAL (or when the own team changes) and not on every enemy-check.
---@param p_OwnTeam TeamId|integer
---@return integer[]
function ClientBotManager:_GetEnemyBotIds(p_OwnTeam)
	local s_NowNs = SharedUtils:GetTimeNS()
	if self.m_EnemyListTeam == p_OwnTeam and self.m_EnemyListNs ~= nil and
		(s_NowNs - self.m_EnemyListNs) < Registry.CLIENT.ENEMY_LIST_INTERVAL * 1000000000 then
		return self.m_EnemyBotIds
	end

	local s_EnemyBotIds = {}
	local s_Players = PlayerManager:GetPlayers()
	for l_Index = 1, #s_Players do
		local l_Player = s_Players[l_Index]
		if l_Player.onlineId == 0 and l_Player.teamId ~= p_OwnTeam then
			s_EnemyBotIds[#s_EnemyBotIds + 1] = l_Player.id
		end
	end
	self.m_EnemyBotIds = s_EnemyBotIds
	self.m_EnemyListTeam = p_OwnTeam
	self.m_EnemyListNs = s_NowNs
	self._RayStats.PlayersMaxMs = math.max(self._RayStats.PlayersMaxMs, (SharedUtils:GetTimeNS() - s_NowNs) / 1000000)
	return s_EnemyBotIds
end

---VEXT Shared Extension:Unloading Event
function ClientBotManager:OnExtensionUnloading()
	self.m_ReadyToUpdate = false
end

---VEXT Shared Level:Destroy Event
function ClientBotManager:OnLevelDestroy()
	self.m_ReadyToUpdate = false
end

-- =============================================
-- NetEvents
-- =============================================
---@param p_NewConfig table<string,integer|number>
---@param p_UpdateWeaponSets boolean
function ClientBotManager:OnWriteClientSettings(p_NewConfig, p_UpdateWeaponSets)
	for l_Key, l_Value in pairs(p_NewConfig) do
		Config[l_Key] = l_Value
	end

	m_Logger:Write("write settings")

	if p_UpdateWeaponSets then
		m_WeaponList:UpdateWeaponList()
	end

	self.m_Player = PlayerManager:GetLocalPlayer()
	self.m_ReadyToUpdate = true
end

---The server does all raycasts itself (Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS).
---@param p_Enabled boolean
function ClientBotManager:OnServerRaycastsSetEnabled(p_Enabled)
	Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS = p_Enabled
	if p_Enabled then
		self.m_BotBotRaycastsToDo = {}
	end
end

function ClientBotManager:CheckForBotBotAttack(p_RaycastData)
	for l_Index = 1, #p_RaycastData do
		local l_RaycastEntry = p_RaycastData[l_Index]
		self.m_BotBotRaycastsToDo[#self.m_BotBotRaycastsToDo + 1] = l_RaycastEntry
	end
	local s_Stats = self._RayStats
	s_Stats.BotBotReceived = s_Stats.BotBotReceived + #p_RaycastData
	s_Stats.QueueMax = math.max(s_Stats.QueueMax, #self.m_BotBotRaycastsToDo)
end

---Debug: one update-frame of the client, sends the stats to the server every Registry.DEBUG.ROUND_STATS_INTERVAL.
function ClientBotManager:_UpdateRayStats()
	local s_Stats = self._RayStats
	s_Stats.Frames = s_Stats.Frames + 1
	s_Stats.FrameRayMaxMs = math.max(s_Stats.FrameRayMaxMs, s_Stats.FrameRayMs or 0)
	s_Stats.FrameRayMs = 0
	local s_Seconds = (SharedUtils:GetTimeNS() - s_Stats.StartNs) / 1000000000
	if s_Seconds < Registry.DEBUG.ROUND_STATS_INTERVAL then
		return
	end
	s_Stats.Seconds = s_Seconds
	s_Stats.StartNs = nil
	s_Stats.FrameRayMs = nil
	NetEvents:SendLocal('Debug:ClientRayStats', s_Stats)
	self:_ResetRayStats()
end

---Debug: one rendered frame (UpdatePass_PreFrame), for the frame rate and hitches of the client.
function ClientBotManager:_CountRenderFrame()
	local s_NowNs = SharedUtils:GetTimeNS()
	local s_Stats = self._RayStats
	if self.m_LastRenderNs ~= nil then
		local s_Ms = (s_NowNs - self.m_LastRenderNs) / 1000000
		s_Stats.RenderFrames = s_Stats.RenderFrames + 1
		s_Stats.RenderMaxMs = math.max(s_Stats.RenderMaxMs, s_Ms)
		if s_Ms > 25.0 then
			s_Stats.Hitches = s_Stats.Hitches + 1
		end
	end
	self.m_LastRenderNs = s_NowNs
end

---Debug: a Registry value set by the debug-bridge on the server (A/B tests of client-side values).
---@param p_Section string
---@param p_Key string
---@param p_Value number|boolean
function ClientBotManager:OnDebugRegistry(p_Section, p_Key, p_Value)
	local s_Section = Registry[p_Section]
	if type(s_Section) == 'table' and type(s_Section[p_Key]) == type(p_Value) then
		s_Section[p_Key] = p_Value
		print('[Registry] ' .. p_Section .. '.' .. p_Key .. ' = ' .. tostring(p_Value))
	end
end

-- =============================================
-- Hooks
-- =============================================

if g_ClientBotManager == nil then
	---@type ClientBotManager
	g_ClientBotManager = ClientBotManager()
end

return g_ClientBotManager
