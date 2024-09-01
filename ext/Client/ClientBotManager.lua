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
	self.m_RaycastTimer = 0
	self.m_AliveTimer = 0
	self.m_LastIndex = 0
	self.m_Player = nil
	self.m_ReadyToUpdate = false
	---@type RaycastRequests[]
	self.m_BotBotRaycastsToDo = {}

	-- Inputs for change of seats (1-8).
	self.m_LastInputLevelsPos = { 0, 0, 0, 0, 0, 0, 0, 0 }
end

-- =============================================
-- Events
-- =============================================

---VEXT Client Client:UpdateInput Event
---@param p_DeltaTime number
function ClientBotManager:OnClientUpdateInput(p_DeltaTime)
	-- To-do: find a better solution for that!!!
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_Q) then
		-- Execute Vehicle Enter Detection here.
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

			if s_Raycast ~= nil and s_Raycast.rigidBody:Is("CharacterPhysicsEntity") then
				-- Find a teammate at this position.
				for _, l_Player in pairs(PlayerManager:GetPlayersByTeam(self.m_Player.teamId)) do
					if l_Player.soldier ~= nil and m_Utilities:isBot(l_Player) and
						l_Player.soldier.worldTransform.trans:Distance(s_Raycast.position) < 2 then
						NetEvents:SendLocal('Client:RequestEnterVehicle', l_Player.name)
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
	if self.m_Player ~= nil and self.m_Player.inVehicle then
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
	if p_Message.type == MessageType.ClientLevelFinalizedMessage then
		NetEvents:SendLocal('Client:RequestSettings')
		self.m_ReadyToUpdate = true
		m_Logger:Write("level loaded on Client")
	end

	if p_Message.type == MessageType.ClientConnectionUnloadLevelMessage or
		p_Message.type == MessageType.ClientCharacterLocalPlayerDeletedMessage then
		self:RegisterVars()
	end
end

---@param p_Pos1 Vec3
---@param p_Pos2 Vec3
---@param p_InObjectPos1 boolean
---@param p_InObjectPos2 boolean
---@return boolean
function ClientBotManager:DoRaycast(p_Pos1, p_Pos2, p_InObjectPos1, p_InObjectPos2)
	if Registry.COMMON.USE_COLLISION_RAYCASTS then
		local s_DeltaPos = p_Pos2 - p_Pos1
		s_DeltaPos = s_DeltaPos:Normalize()

		if p_InObjectPos1 then -- Start Raycast outside of vehicle
			p_Pos1 = p_Pos1 + (s_DeltaPos * 3.2)
		end

		-- no need to go through bot, since soldier position should already cause the collision

		-- describes what doesn't end the raycast on a collision
		local s_MaterialFlags = MaterialFlags.MfSeeThrough -- windows
			-- MaterialFlags.MfNoCollisionResponse | -- no effect?
			-- MaterialFlags.MfNoCollisionResponseCombined | -- no effect?
			| MaterialFlags.MfPenetrable -- soldiers + solid fences (only with detailed-Mesh-Check)
			-- MaterialFlags.MfBashable | -- ???
			| MaterialFlags.MfClientDestructible -- some open fences, some crates

		---@cast s_MaterialFlags MaterialFlags
		local s_RaycastFlags = RayCastFlags.DontCheckWater
		if Registry.COMMON.USE_DETAILED_MESH_RAYCASTS then
			s_RaycastFlags = s_RaycastFlags | RayCastFlags.CheckDetailMesh -- needed to detect some fences as shoot-through
		end
		---@cast s_RaycastFlags RayCastFlags

		local s_RayHits = RaycastManager:CollisionRaycast(p_Pos1, p_Pos2, 5, s_MaterialFlags, s_RaycastFlags) -- only 5 hits supported at the moment

		if p_InObjectPos2 then
			if #s_RayHits > 0 and #s_RayHits < 5 and s_RayHits[#s_RayHits].rigidBody and s_RayHits[#s_RayHits].rigidBody:Is("DynamicPhysicsEntity") then -- right now only 5 hits possible. abort if 5 hits
				return true
			else
				return false
			end
		else
			if #s_RayHits > 0 and #s_RayHits < 5 and s_RayHits[#s_RayHits].rigidBody and s_RayHits[#s_RayHits].rigidBody:Is("CharacterPhysicsEntity") then -- right now only 5 hits possible. abort if 5 hits
				return true
			else
				return false
			end
		end
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
	NetEvents:SendLocal("Botmanager:RaycastResults", p_RaycastResultsToSend)
end

---VEXT Shared UpdateManager:Update Event
---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function ClientBotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PreSim or not self.m_ReadyToUpdate then -- UpdatePass_PreSim UpdatePass_PreFrame
		return
	end

	local s_RaycastResultsToSend = {}

	self.m_RaycastTimer = self.m_RaycastTimer + p_DeltaTime
	local s_SkipEnemyCheck = not Config.BotsAttackPlayers or
		(self.m_RaycastTimer < Registry.GAME_RAYCASTING.RAYCAST_INTERVAL_ENEMY_CHECK)

	-- Check bot-bot attack.
	if #self.m_BotBotRaycastsToDo > 0 then
		local s_MaxRaycastsBotBot = Registry.GAME_RAYCASTING.MAX_RAYCASTS_PER_PLAYER_PER_CYCLE

		if not s_SkipEnemyCheck then
			s_MaxRaycastsBotBot = s_MaxRaycastsBotBot - 1
		end

		local s_RaycastEntriesDone = 0

		for i = 1, s_MaxRaycastsBotBot do
			if (#self.m_BotBotRaycastsToDo > 0) then
				---@type RaycastRequests
				local s_RaycastCheckEntry = table.remove(self.m_BotBotRaycastsToDo, 1)
				s_RaycastEntriesDone = s_RaycastEntriesDone + 1
				local s_Bot1 = PlayerManager:GetPlayerById(s_RaycastCheckEntry.Bot1)
				local s_Bot2 = PlayerManager:GetPlayerById(s_RaycastCheckEntry.Bot2)

				if s_Bot1 and s_Bot2 and s_Bot1.soldier and s_Bot2.soldier then
					local s_StartPos = nil
					local s_EndPos = nil
					if s_RaycastCheckEntry.Bot1InVehicle then
						s_StartPos = s_Bot1.controlledControllable.transform.trans:Clone()
					else
						s_StartPos = s_Bot1.soldier.worldTransform.trans:Clone()
					end
					s_StartPos.y = s_StartPos.y + 1.4

					if s_RaycastCheckEntry.Bot2InVehicle then
						s_EndPos = s_Bot2.controlledControllable.transform.trans:Clone()
					else
						s_EndPos = s_Bot2.soldier.worldTransform.trans:Clone()
					end
					s_EndPos.y = s_EndPos.y + 1.4
					if self:DoRaycast(s_StartPos, s_EndPos, s_RaycastCheckEntry.Bot1InVehicle, s_RaycastCheckEntry.Bot2InVehicle) then
						table.insert(s_RaycastResultsToSend, {
							Mode = RaycastResultModes.ShootAtBot,
							Bot1 = s_RaycastCheckEntry.Bot1,
							Bot2 = s_RaycastCheckEntry.Bot2,
							IgnoreYaw = false,
						})
					end
				end
			end
		end

		-- Check for too many entries.
		if #self.m_BotBotRaycastsToDo > 20 then
			m_Logger:Write("More Raycasts than doable")
			self.m_BotBotRaycastsToDo = {}
		end
	end

	if self.m_Player == nil then
		self.m_Player = PlayerManager:GetLocalPlayer()

		if self.m_Player == nil then
			self:SendRaycastResults(s_RaycastResultsToSend)
			return
		end
	end

	if s_SkipEnemyCheck then
		self:SendRaycastResults(s_RaycastResultsToSend)
		return
	end

	self.m_RaycastTimer = 0
	local s_CheckCount = 0

	if self.m_Player.soldier ~= nil then                       -- Alive. Check for enemy bots.
		if self.m_AliveTimer < Registry.CLIENT.SPAWN_PROTECTION then -- Wait 2s (spawn-protection).
			self.m_AliveTimer = self.m_AliveTimer + p_DeltaTime
			self:SendRaycastResults(s_RaycastResultsToSend)
			return
		end

		---@type Player[]
		local s_EnemyPlayers = {}

		for _, l_Player in pairs(PlayerManager:GetPlayers()) do
			if l_Player.teamId ~= self.m_Player.teamId and self.m_Player.teamId ~= 0 then -- Don't let bots attack spectators.
				table.insert(s_EnemyPlayers, l_Player)
			end
		end

		if self.m_LastIndex >= #s_EnemyPlayers then
			self.m_LastIndex = 0
		end

		-- Check for clear view.
		local s_PlayerPosition = Vec3()
		if self.m_Player.inVehicle then
			s_PlayerPosition = self.m_Player.controlledControllable.transform.trans:Clone()
			s_PlayerPosition.y = s_PlayerPosition.y + 1.4
		else
			s_PlayerPosition = ClientUtils:GetCameraTransform().trans:Clone() -- player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(player, false)
		end
		for i = 0, #s_EnemyPlayers - 1 do
			local s_Index = (self.m_LastIndex + i) % #s_EnemyPlayers + 1
			local s_Bot = s_EnemyPlayers[s_Index]

			if s_Bot == nil or s_Bot.onlineId ~= 0 or s_Bot.soldier == nil then
				goto continue_enemy_loop
			end

			-- Find direction of Bot.
			local s_TargetPos = Vec3()

			if s_Bot.inVehicle then
				s_TargetPos = s_Bot.controlledControllable.transform.trans:Clone()
				s_TargetPos.y = s_TargetPos.y + 1.4
			else
				s_TargetPos = s_Bot.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(s_Bot, false, false)
			end

			local s_Distance = s_PlayerPosition:Distance(s_TargetPos)

			s_CheckCount = s_CheckCount + 1

			if (s_Distance < Config.MaxShootDistanceSniper) or (s_Bot.inVehicle and (s_Distance < Config.MaxShootDistanceVehicles)) then
				if self:DoRaycast(s_PlayerPosition, s_TargetPos, self.m_Player.inVehicle, s_Bot.inVehicle) then
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
				self:SendRaycastResults(s_RaycastResultsToSend)
				return -- Only one raycast per cycle.
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

---VEXT Shared Extension:Unloading Event
function ClientBotManager:OnExtensionUnloading()
	self:RegisterVars()
end

---VEXT Shared Level:Destroy Event
function ClientBotManager:OnLevelDestroy()
	self:RegisterVars()
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
end

function ClientBotManager:CheckForBotBotAttack(p_RaycastData)
	for _, l_RaycastEntry in pairs(p_RaycastData) do
		table.insert(self.m_BotBotRaycastsToDo, l_RaycastEntry)
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
