class('ClientBotManager')

local m_WeaponList = require('__shared/WeaponList')
local m_Utilities = require('__shared/Utilities')

function ClientBotManager:__init()
	self:RegisterVars()
end

function ClientBotManager:RegisterVars()
	self._raycastTimer	= 0
	self._lastIndex		= 1
	self.player			= nil
	self.readyToUpdate	= false
end

function ClientBotManager:OnEngineMessage(p_Message)
	if (p_Message.type == MessageType.ClientLevelFinalizedMessage) then
		NetEvents:SendLocal('RequestClientSettings')
		self.readyToUpdate	= true
		if Debug.Client.INFO then
			print("level loaded on Client")
		end
	end
	if (p_Message.type == MessageType.ClientConnectionUnloadLevelMessage) or (p_Message.type == MessageType.ClientCharacterLocalPlayerDeletedMessage) then
		self:RegisterVars()
	end
end

function ClientBotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if (p_UpdatePass ~= UpdatePass.UpdatePass_PreFrame or not self.readyToUpdate) then
		return
	end

	if (self.player == nil) then
		self.player = PlayerManager:GetLocalPlayer()
	end

	if (self.player == nil) then
		return
	end

	self._raycastTimer = self._raycastTimer + p_DeltaTime

	if (self._raycastTimer >= StaticConfig.RaycastInterval) then
		self._raycastTimer	= 0

		if self.player.soldier ~= nil then  -- alive. Check for enemy bots

			local enemyPlayers = {}
			for i = 1, 4 do
				if i ~= self.player.teamId then
					local tempPlayers = PlayerManager:GetPlayersByTeam(i)
					if #tempPlayers > 0 then
						if #enemyPlayers == 0 then
							enemyPlayers = tempPlayers
						else
							for _,player in pairs(tempPlayers) do
								table.insert(enemyPlayers, player)
							end
						end
					end
				end
			end
			if (self._lastIndex >= #enemyPlayers) then
				self._lastIndex = 1
			end

			for i = self._lastIndex, #enemyPlayers do
				local bot = enemyPlayers[i]

				-- valid player and is bot
				if (bot ~= nil and bot.onlineId == 0 and bot.soldier ~= nil) then

					-- check for clear view
					local playerPosition = ClientUtils:GetCameraTransform().trans:Clone() --player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(player, false)

					-- find direction of Bot
					local target	= bot.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(bot, false)
					local distance	= playerPosition:Distance(bot.soldier.worldTransform.trans)

					if (distance < Config.MaxRaycastDistance) then
						self._lastIndex	= self._lastIndex+1
						local raycast = nil
						if self.player.inVehicle then
							-- TODO: Some Vehicles are detected as objects of type Group. Find a better solution
							raycast	= RaycastManager:Raycast(playerPosition, target, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckPhantoms | RayCastFlags.DontCheckGroup | RayCastFlags.IsAsyncRaycast)
						else
							raycast	= RaycastManager:Raycast(playerPosition, target, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)
						end
						if (raycast == nil or raycast.rigidBody == nil) then
							-- we found a valid bot in Sight (either no hit, or player-hit). Signal Server with players
							local ignoreYaw = false

							if (distance < Config.DistanceForDirectAttack) then
								ignoreYaw = true --shoot, because you are near
							end

							NetEvents:SendLocal("BotShootAtPlayer", bot.name, ignoreYaw)
						end

						return --only one raycast per cycle
					end
				end
			end
		elseif self.player.corpse ~= nil then -- dead. check for revive botsAttackBots
			local teamMates = PlayerManager:GetPlayersByTeam(self.player.teamId)
			if (self._lastIndex >= #teamMates) then
				self._lastIndex = 1
			end

			for i = self._lastIndex, #teamMates do
				local bot = teamMates[i]

				-- valid player and is bot
				if (bot ~= nil and bot.onlineId == 0 and bot.soldier ~= nil) then

					-- check for clear view
					local playerPosition = self.player.corpse.worldTransform.trans:Clone() + Vec3(0, 1, 0)

					-- find direction of Bot
					local target	= bot.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(bot, false)
					local distance	= playerPosition:Distance(bot.soldier.worldTransform.trans)

					if (distance < 35) then  -- TODO: use config var for this
						self._lastIndex	= self._lastIndex+1
						local raycast	= RaycastManager:Raycast(playerPosition, target, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)

						if (raycast == nil or raycast.rigidBody == nil) then
							-- we found a valid bot in Sight (either no hit, or player-hit). Signal Server with players
							NetEvents:SendLocal("BotRevivePlayer", bot.name)
						end
						return --only one raycast per cycle
					end
				end
			end
		end
	end
end

function ClientBotManager:OnExtensionUnloading()
	self:RegisterVars()
end

function ClientBotManager:OnLevelDestroy()
	self:RegisterVars()
end

function ClientBotManager:OnWriteClientSettings(p_NewConfig, p_UpdateWeaponSets)
	for key, value in pairs(p_NewConfig) do
		Config[key] = value
	end

	if Debug.Client.INFO then
		print("write settings")
	end

	if p_UpdateWeaponSets then
		m_WeaponList:updateWeaponList()
	end

	self.player = PlayerManager:GetLocalPlayer()
end

function ClientBotManager:CheckForBotBotAttack(p_StartPos, p_EndPos, p_ShooterBotName, p_BotName, p_InVehicle)
	--check for clear view to startpoint
	local startPos 	= Vec3(p_StartPos.x, p_StartPos.y + 1.0, p_StartPos.z)
	local endPos 	= Vec3(p_EndPos.x, p_EndPos.y + 1.0, p_EndPos.z)
	local raycast = nil
	if p_InVehicle then
		raycast	= RaycastManager:Raycast(startPos, endPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckPhantoms | RayCastFlags.DontCheckGroup | RayCastFlags.IsAsyncRaycast)
	else
		raycast	= RaycastManager:Raycast(startPos, endPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)
	end

	if (raycast == nil or raycast.rigidBody == nil) then
		NetEvents:SendLocal("BotShootAtBot", p_ShooterBotName, p_BotName)
	end
end

function ClientBotManager:OnBulletEntityCollision(p_HookCtx, p_Entity, p_Hit, p_Shooter)
	if (p_Hit.rigidBody.typeInfo.name == 'CharacterPhysicsEntity') then
		if m_Utilities:isBot(p_Shooter) then
			local player = PlayerManager:GetLocalPlayer()

			if (player.soldier ~= nil) then
				local dx	= math.abs(player.soldier.worldTransform.trans.x - p_Hit.position.x)
				local dz	= math.abs(player.soldier.worldTransform.trans.z - p_Hit.position.z)
				local dy	= p_Hit.position.y - player.soldier.worldTransform.trans.y --player y is on ground. Hit must be higher to be valid

				if (dx < 1 and dz < 1 and dy < 2 and dy > 0) then --included bodyhight
					local isHeadshot	= false
					local camaraHeight	= m_Utilities:getTargetHeight(player.soldier, false)

					if dy < camaraHeight + 0.3 and dy > camaraHeight - 0.10 then
						isHeadshot = true
					end

					NetEvents:SendLocal('ClientDamagePlayer', p_Shooter.name, false, isHeadshot)
				end
			end
		end
	end
end

if g_ClientBotManager == nil then
	g_ClientBotManager = ClientBotManager()
end

return g_ClientBotManager
