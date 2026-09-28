---@class ServerRaycasts
---@overload fun():ServerRaycasts
ServerRaycasts = class('ServerRaycasts')

-- Sight-checks with server-side raycasts (Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS).
-- Replaces the raycasts the clients do otherwise (ClientBotManager), so bots work without any client:
--   bot-bot:       BotManager:_CheckForBotBotAttack builds the requests, CheckBotBot does the raycast.
--   bot-player:    UpdatePlayerChecks, the server version of the enemy-check of the clients.
--   player-revive: UpdatePlayerChecks as well, medic-bots in sight revive dead players.
-- The server has no RaycastManager:Raycast, only collision- and detailed-raycasts. Characters are ignored, so only
-- the environment and vehicles block the sight.

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type DebugBridge
local m_DebugBridge = require('Debug/DebugBridge')

-- The raycasts return max 5 hits at the moment.
local MAX_HITS = 5
-- Start the ray outside of the own vehicle.
local VEHICLE_EXIT_OFFSET = 3.2
local EYE_HEIGHT_VEHICLE = 1.4
local CORPSE_HEIGHT = 0.4

-- Materials the ray passes through (same as the collision-raycasts of the client).
local PASS_THROUGH_FLAGS = MaterialFlags.MfSeeThrough | MaterialFlags.MfPenetrable | MaterialFlags.MfClientDestructible
---@cast PASS_THROUGH_FLAGS MaterialFlags

-- A collision-raycast stops at the first solid hit. All hits before it are parts the ray passed through
-- (windows, fences, ...), so only the last hit can block the sight.
---@param p_RayHits RayCastHit[]
---@param p_TargetVehicle ControllableEntity|nil the ray may end on the hull of this vehicle
---@return boolean
local function _IsInSight(p_RayHits, p_TargetVehicle)
	local s_HitCount = #p_RayHits
	if s_HitCount == 0 then
		return true
	end

	local s_LastHit = p_RayHits[s_HitCount]
	if s_LastHit.rigidBody == nil then
		return false
	end

	-- The physics-entity of a vehicle has the vehicle itself as userData.
	local s_PhysicsEntity = PhysicsEntityBase(s_LastHit.rigidBody)
	if p_TargetVehicle ~= nil then
		local s_Owner = s_PhysicsEntity.userData
		if s_Owner ~= nil and s_Owner.instanceId == p_TargetVehicle.instanceId then
			return true
		end
	end

	-- The ray might have stopped before the target.
	if s_HitCount >= MAX_HITS then
		return false
	end

	return (s_PhysicsEntity:GetPartMaterialFlags(s_LastHit.part) & PASS_THROUGH_FLAGS) ~= 0
end

---Eye-position of a player. In a vehicle it is above the vehicle-center (as the clients do it).
---@param p_Player Player
---@param p_InVehicle boolean
---@return Vec3 position
---@return ControllableEntity|nil vehicle
local function _GetEyePosition(p_Player, p_InVehicle)
	local s_Controllable = p_Player.controlledControllable
	if p_InVehicle and s_Controllable ~= nil then
		local s_Position = s_Controllable.transform.trans:Clone()
		s_Position.y = s_Position.y + EYE_HEIGHT_VEHICLE
		return s_Position, s_Controllable
	end

	return p_Player.soldier.worldTransform.trans + m_Utilities:getCameraPos(p_Player, false, false), nil
end

---Players have no inVehicle on the server.
---@param p_Player Player
---@return boolean
local function _IsPlayerInVehicle(p_Player)
	local s_Controllable = p_Player.controlledControllable
	return s_Controllable ~= nil and not s_Controllable:Is('ServerSoldierEntity')
end

function ServerRaycasts:__init()
	self.m_Enabled = Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS == true
	self:_ResetPlayerChecks()
end

function ServerRaycasts:_ResetPlayerChecks()
	---`[Player.onlineId] -> { TargetIndex, AliveTimer }`
	self._PlayerStates = {}
end

---VEXT Shared Level:Destroy Event
function ServerRaycasts:OnLevelDestroy()
	self:_ResetPlayerChecks()
end

---@return boolean
function ServerRaycasts:IsEnabled()
	return self.m_Enabled
end

---@param p_Enabled boolean
function ServerRaycasts:SetEnabled(p_Enabled)
	self.m_Enabled = p_Enabled
	-- The clients read it from the registry as well, so keep it in sync.
	Registry.GAME_RAYCASTING.USE_SERVER_RAYCASTS = p_Enabled
	self:_ResetPlayerChecks()
	NetEvents:BroadcastLocal('ServerRaycasts:SetEnabled', p_Enabled)
end

---Tells a (new) client whether it has to do the raycasts itself.
---@param p_Player Player
function ServerRaycasts:SendStateToPlayer(p_Player)
	NetEvents:SendToLocal('ServerRaycasts:SetEnabled', p_Player, self.m_Enabled)
end

---@param p_From Vec3 eye-position of the viewer
---@param p_To Vec3 eye-position of the target
---@param p_FromInVehicle boolean start the ray outside of the own vehicle
---@param p_TargetVehicle ControllableEntity|nil vehicle of the target, the ray may end on its hull
---@param p_Kind string only used for the debug-traces
---@return boolean
function ServerRaycasts:CheckSight(p_From, p_To, p_FromInVehicle, p_TargetVehicle, p_Kind)
	if p_FromInVehicle then
		p_From = p_From + (p_To - p_From):Normalize() * VEHICLE_EXIT_OFFSET
	end

	local s_RaycastFlags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll
	if Registry.COMMON.USE_DETAILED_MESH_RAYCASTS then
		s_RaycastFlags = s_RaycastFlags | RayCastFlags.CheckDetailMesh
	end
	---@cast s_RaycastFlags RayCastFlags

	local s_RayHits = RaycastManager:CollisionRaycast(p_From, p_To, MAX_HITS, PASS_THROUGH_FLAGS, s_RaycastFlags)
	local s_Visible = _IsInSight(s_RayHits, p_TargetVehicle)

	if m_DebugBridge.m_TraceRaycasts then
		local s_LastHit = s_RayHits[#s_RayHits]
		m_DebugBridge:Trace(p_Kind, p_From, p_To, s_Visible, s_LastHit and s_LastHit.position)
	end

	return s_Visible
end

---Server version of the bot-bot-raycast of the clients.
---@param p_Bot1 Bot
---@param p_Bot2 Bot
---@param p_Bot1InVehicle boolean
---@param p_Bot2InVehicle boolean
---@return boolean
function ServerRaycasts:CheckBotBot(p_Bot1, p_Bot2, p_Bot1InVehicle, p_Bot2InVehicle)
	local s_Player1 = p_Bot1.m_Player
	local s_Player2 = p_Bot2.m_Player
	if s_Player1.soldier == nil or s_Player2.soldier == nil then
		return false
	end

	local s_From = _GetEyePosition(s_Player1, p_Bot1InVehicle)
	local s_To, s_TargetVehicle = _GetEyePosition(s_Player2, p_Bot2InVehicle)
	return self:CheckSight(s_From, s_To, p_Bot1InVehicle, s_TargetVehicle, 'botbot')
end

---Server version of the checks the clients do for their own player (ClientBotManager:OnUpdateManagerUpdate).
---Alive: enemy bots in sight attack the player. Dead: medic-bots in sight revive the player.
---@param p_BotManager BotManager
---@param p_ActivePlayers integer[] onlineIds of the real players
---@param p_DeltaTime number
function ServerRaycasts:UpdatePlayerChecks(p_BotManager, p_ActivePlayers, p_DeltaTime)
	for l_Index = 1, #p_ActivePlayers do
		local l_OnlineId = p_ActivePlayers[l_Index]
		local s_Player = PlayerManager:GetPlayerByOnlineId(l_OnlineId)

		if s_Player ~= nil and s_Player.teamId ~= TeamId.TeamNeutral then -- Don't let bots attack spectators.
			local s_State = self._PlayerStates[l_OnlineId]
			if s_State == nil then
				s_State = { TargetIndex = 0, AliveTimer = 0.0 }
				self._PlayerStates[l_OnlineId] = s_State
			end

			if s_Player.alive and s_Player.soldier ~= nil then
				if s_State.AliveTimer < Registry.CLIENT.SPAWN_PROTECTION then
					s_State.AliveTimer = s_State.AliveTimer + p_DeltaTime
				elseif Config.BotsAttackPlayers then
					self:_CheckEnemyBots(p_BotManager, s_Player, s_State)
				end
			elseif s_Player.corpse ~= nil and not s_Player.corpse.isDead then
				s_State.AliveTimer = 0.5 -- Add a little delay.
				self:_CheckReviveBots(p_BotManager, s_Player, s_State)
			else
				s_State.AliveTimer = 0.0
			end
		end
	end
end

---@param p_BotManager BotManager
---@param p_Player Player
---@param p_State table
function ServerRaycasts:_CheckEnemyBots(p_BotManager, p_Player, p_State)
	local s_Bots = p_BotManager:GetBots()
	local s_BotCount = #s_Bots
	if s_BotCount == 0 then
		return
	end

	local s_InVehicle = _IsPlayerInVehicle(p_Player)
	local s_Eye = _GetEyePosition(p_Player, s_InVehicle)
	local s_MaxVehicleDistance = math.max(Config.MaxShootDistanceVehicles, Config.MaxShootDistanceGunship)
	local s_MaxPlayerDistance = math.max(Config.MaxShootDistanceMissileAir, Config.MaxShootDistanceSniper)
	local s_Raycasts = 0
	local s_Checks = 0

	for _ = 1, s_BotCount do
		p_State.TargetIndex = p_State.TargetIndex % s_BotCount + 1
		local s_Bot = s_Bots[p_State.TargetIndex]
		local s_BotPlayer = s_Bot.m_Player

		if s_BotPlayer.teamId ~= p_Player.teamId and s_BotPlayer.soldier ~= nil then
			local s_BotInVehicle = g_BotStates:IsInVehicleState(s_Bot.m_ActiveState)
			local s_Target, s_TargetVehicle = _GetEyePosition(s_BotPlayer, s_BotInVehicle)
			local s_Distance = s_Eye:Distance(s_Target)

			if s_Distance < (s_BotInVehicle and s_MaxVehicleDistance or s_MaxPlayerDistance) then
				if self:CheckSight(s_Eye, s_Target, s_InVehicle, s_TargetVehicle, 'player') then
					-- Shoot, because you are near.
					p_BotManager:OnShootAt(p_Player, s_Bot.m_Id, s_Distance < Config.DistanceForDirectAttack)
				end

				s_Raycasts = s_Raycasts + 1
				if s_Raycasts >= Registry.GAME_RAYCASTING.SERVER_RAYCASTS_PER_PLAYER then
					return
				end
			end

			s_Checks = s_Checks + 1
			if s_Checks >= Registry.CLIENT.MAX_CHECKS_PER_CYCLE then
				return
			end
		end
	end
end

---@param p_BotManager BotManager
---@param p_Player Player
---@param p_State table
function ServerRaycasts:_CheckReviveBots(p_BotManager, p_Player, p_State)
	local s_Bots = p_BotManager:GetBots(p_Player.teamId)
	local s_BotCount = #s_Bots
	if s_BotCount == 0 then
		return
	end

	local s_CorpsePosition = p_Player.corpse.worldTransform.trans:Clone()
	s_CorpsePosition.y = s_CorpsePosition.y + CORPSE_HEIGHT
	local s_Raycasts = 0
	local s_Checks = 0

	for _ = 1, s_BotCount do
		p_State.TargetIndex = p_State.TargetIndex % s_BotCount + 1
		local s_Bot = s_Bots[p_State.TargetIndex]
		local s_BotPlayer = s_Bot.m_Player

		-- Only assaults can revive (see Bot:Revive), no need to raycast for the others.
		if s_BotPlayer.soldier ~= nil and s_Bot.m_Kit == BotKits.Assault and
			not g_BotStates:IsInVehicleState(s_Bot.m_ActiveState) then
			local s_Target = _GetEyePosition(s_BotPlayer, false)

			if s_CorpsePosition:Distance(s_BotPlayer.soldier.worldTransform.trans) < Registry.CLIENT.REVIVE_DISTANCE then
				if self:CheckSight(s_CorpsePosition, s_Target, false, nil, 'revive') then
					p_BotManager:OnRevivePlayer(p_Player, s_Bot.m_Id)
				end

				s_Raycasts = s_Raycasts + 1
				if s_Raycasts >= Registry.GAME_RAYCASTING.SERVER_RAYCASTS_PER_PLAYER then
					return
				end
			end

			s_Checks = s_Checks + 1
			if s_Checks >= Registry.CLIENT.MAX_CHECKS_PER_CYCLE then
				return
			end
		end
	end
end

if g_ServerRaycasts == nil then
	---@type ServerRaycasts
	g_ServerRaycasts = ServerRaycasts()
end

return g_ServerRaycasts
