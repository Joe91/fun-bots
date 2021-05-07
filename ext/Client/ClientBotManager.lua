class('ClientBotManager')

local m_WeaponList = require('__shared/WeaponList')
local m_Utilities = require('__shared/Utilities')
local m_Logger = Logger("ClientBotManager", Debug.Client.INFO)

function ClientBotManager:__init()
	self:RegisterVars()
end

function ClientBotManager:RegisterVars()
	self.m_RaycastTimer = 0
	self.m_AliveTimer = 0
	self.m_LastIndex = 1
	self.m_Player = nil
	self.m_ReadyToUpdate = false
end

-- =============================================
-- Events
-- =============================================

function ClientBotManager:OnEngineMessage(p_Message)
	if p_Message.type == MessageType.ClientLevelFinalizedMessage then
		NetEvents:SendLocal('Client:RequestSettings')
		self.m_ReadyToUpdate = true
		m_Logger:Write("level loaded on Client")
	end
	if p_Message.type == MessageType.ClientConnectionUnloadLevelMessage or p_Message.type == MessageType.ClientCharacterLocalPlayerDeletedMessage then
		self:RegisterVars()
	end
end

function ClientBotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PreFrame or not self.m_ReadyToUpdate then
		return
	end
	if self.m_Player == nil then
		self.m_Player = PlayerManager:GetLocalPlayer()
	end
	if self.m_Player == nil then
		return
	end

	self.m_RaycastTimer = self.m_RaycastTimer + p_DeltaTime

	if self.m_RaycastTimer < StaticConfig.RaycastInterval then
		return
	end

	self.m_RaycastTimer = 0

	if self.m_Player.soldier ~= nil then  -- alive. Check for enemy bots
		if self.m_AliveTimer < 1.0 then -- wait 2s (spawn-protection)
			self.m_AliveTimer = self.m_AliveTimer + p_DeltaTime
			return
		end

		local s_EnemyPlayers = {}
		local s_AllPlayers = PlayerManager:GetPlayers()
		for _, l_Player in pairs(s_AllPlayers) do
			if l_Player.teamId ~= self.m_Player.teamId then
				table.insert(s_EnemyPlayers, l_Player)
			end
		end
		if self.m_LastIndex >= #s_EnemyPlayers then
			self.m_LastIndex = 1
		end
		for i = self.m_LastIndex, #s_EnemyPlayers do
			local s_Bot = s_EnemyPlayers[i]
			if s_Bot == nil or s_Bot.onlineId ~= 0 or s_Bot.soldier == nil then
				goto continue_enemy_loop
			end

			-- check for clear view
			local s_PlayerPosition = ClientUtils:GetCameraTransform().trans:Clone() --player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(player, false)

			-- find direction of Bot
			local s_Target = s_Bot.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(s_Bot, false)
			local s_Distance = s_PlayerPosition:Distance(s_Bot.soldier.worldTransform.trans)

			if s_Distance < Config.MaxRaycastDistance then
				self.m_LastIndex = self.m_LastIndex + 1
				local s_Raycast = nil
				
				s_Raycast = RaycastManager:Raycast(s_PlayerPosition, s_Target, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)
				
				if s_Raycast == nil or s_Raycast.rigidBody == nil then
					-- we found a valid bot in Sight (either no hit, or player-hit). Signal Server with players
					local s_IgnoreYaw = false

					if s_Distance < Config.DistanceForDirectAttack then
						s_IgnoreYaw = true -- shoot, because you are near
					end
					NetEvents:SendLocal("Bot:ShootAtPlayer", s_Bot.name, s_IgnoreYaw)

				elseif (self.m_Player.inVehicle or s_Bot.inVehicle) and s_Raycast.rigidBody:Is("DynamicPhysicsEntity") then
					NetEvents:SendLocal("Bot:ShootAtPlayer", s_Bot.name, false) -- always check yaw in vehicle
				end

				return --only one raycast per cycle
			end
			::continue_enemy_loop::
		end
	elseif self.m_Player.corpse ~= nil then -- dead. check for revive botsAttackBots
		self.m_AliveTimer = 0.5
		local s_TeamMates = PlayerManager:GetPlayersByTeam(self.m_Player.teamId)
		if self.m_LastIndex >= #s_TeamMates then
			self.m_LastIndex = 1
		end

		for i = self.m_LastIndex, #s_TeamMates do
			local s_Bot = s_TeamMates[i]

			if s_Bot == nil or s_Bot.onlineId ~= 0 or s_Bot.soldier == nil then
				goto continue_teamMate_loop
			end

			-- check for clear view
			local s_PlayerPosition = self.m_Player.corpse.worldTransform.trans:Clone() + Vec3(0.0, 1.0, 0.0)

			-- find direction of Bot
			local s_Target = s_Bot.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(s_Bot, false)
			local s_Distance = s_PlayerPosition:Distance(s_Bot.soldier.worldTransform.trans)

			if s_Distance < 35.0 then  -- TODO: use config var for this
				self.m_LastIndex = self.m_LastIndex + 1
				local s_Raycast = RaycastManager:Raycast(s_PlayerPosition, s_Target, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)

				if s_Raycast == nil or s_Raycast.rigidBody == nil then
					-- we found a valid bot in Sight (either no hit, or player-hit). Signal Server with players
					NetEvents:SendLocal("Bot:RevivePlayer", s_Bot.name)
				end
				return -- only one raycast per cycle
			end
			::continue_teamMate_loop::
		end
	else
		self.m_AliveTimer = 0
	end
end

function ClientBotManager:OnExtensionUnloading()
	self:RegisterVars()
end

function ClientBotManager:OnLevelDestroy()
	self:RegisterVars()
end

-- =============================================
-- NetEvents
-- =============================================

function ClientBotManager:OnWriteClientSettings(p_NewConfig, p_UpdateWeaponSets)
	for l_Key, l_Value in pairs(p_NewConfig) do
		Config[l_Key] = l_Value
	end

	m_Logger:Write("write settings")

	if p_UpdateWeaponSets then
		m_WeaponList:updateWeaponList()
	end

	self.m_Player = PlayerManager:GetLocalPlayer()
end

function ClientBotManager:CheckForBotBotAttack(p_StartPos, p_EndPos, p_ShooterBotName, p_BotName, p_InVehicle)
	--check for clear view to startpoint
	local s_StartPos = Vec3(p_StartPos.x, p_StartPos.y + 1.0, p_StartPos.z)
	local s_EndPos = Vec3(p_EndPos.x, p_EndPos.y + 1.0, p_EndPos.z)

	local s_Raycast = RaycastManager:Raycast(s_StartPos, s_EndPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)

	if s_Raycast == nil or s_Raycast.rigidBody == nil then
		NetEvents:SendLocal("Bot:ShootAtBot", p_ShooterBotName, p_BotName)
	elseif p_InVehicle and s_Raycast.rigidBody:Is("DynamicPhysicsEntity") then
		NetEvents:SendLocal("Bot:ShootAtBot", p_ShooterBotName, p_BotName)
	end
end

-- =============================================
-- Hooks
-- =============================================

function ClientBotManager:OnBulletEntityCollision(p_HookCtx, p_Entity, p_Hit, p_Shooter)
	if p_Hit.rigidBody.typeInfo.name ~= 'CharacterPhysicsEntity' then
		return
	end
	if not m_Utilities:isBot(p_Shooter) then
		return
	end
	local s_LocalPlayer = PlayerManager:GetLocalPlayer()
	if s_LocalPlayer == nil or s_LocalPlayer.soldier == nil then
		return
	end

	local dx = math.abs(s_LocalPlayer.soldier.worldTransform.trans.x - p_Hit.position.x)
	local dz = math.abs(s_LocalPlayer.soldier.worldTransform.trans.z - p_Hit.position.z)
	local dy = p_Hit.position.y - s_LocalPlayer.soldier.worldTransform.trans.y -- s_LocalPlayer y is on ground. Hit must be higher to be valid

	if (dx < 1 and dz < 1 and dy < 2 and dy > 0) then -- included bodyheight
		local s_IsHeadshot = false
		local s_CameraHeight = m_Utilities:getTargetHeight(s_LocalPlayer.soldier, false)

		if dy < s_CameraHeight + 0.3 and dy > s_CameraHeight - 0.10 then
			s_IsHeadshot = true
		end

		NetEvents:SendLocal('Client:DamagePlayer', p_Shooter.name, false, s_IsHeadshot)
	end
end

if g_ClientBotManager == nil then
	g_ClientBotManager = ClientBotManager()
end

return g_ClientBotManager
