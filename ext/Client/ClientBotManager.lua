class('ClientBotManager')

require('__shared/Config')

local WeaponList			= require('__shared/WeaponList')
local Utilities 			= require('__shared/Utilities')

function ClientBotManager:__init()
	self._raycastTimer	= 0
	self._lastIndex		= 1
	self.player			= nil
	self.readyToUpdate	= false

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Level:Destroy', self, self.onExtensionUnload)
	NetEvents:Subscribe('WriteClientSettings', self, self._onWriteClientSettings)
	NetEvents:Subscribe('CheckBotBotAttack', self, self._checkForBotBotAttack)
	
	if not USE_REAL_DAMAGE then
		Hooks:Install('BulletEntity:Collision', 200, self, self._onBulletCollision)
	end
end

function ClientBotManager:onExtensionUnload()
	self._raycastTimer	= 0
	self._lastIndex		= 1
	self.player			= nil
	self.readyToUpdate	= false
end

function ClientBotManager:onEngineMessage(p_Message)
	if (p_Message.type == MessageType.ClientLevelFinalizedMessage) then
		NetEvents:SendLocal('RequestClientSettings')
		self.readyToUpdate	= true
		if Debug.Client.INFO then
			print("level loaded on Client")
		end
	end
	if (p_Message.type == MessageType.ClientConnectionUnloadLevelMessage) or (p_Message.type == MessageType.ClientCharacterLocalPlayerDeletedMessage) then
		self:onExtensionUnload()
	end
end

function ClientBotManager:_onWriteClientSettings(newConfig, updateWeaponSets)
	for key, value in pairs(newConfig) do
		Config[key] = value
	end
	
	if Debug.Client.INFO then
		print("write settings")
	end
	
	if updateWeaponSets then
		WeaponList:updateWeaponList()
	end

	self.player = PlayerManager:GetLocalPlayer()
end

function ClientBotManager:_onUpdate(p_Delta, p_Pass)
	if (p_Pass ~= UpdatePass.UpdatePass_PreFrame or not self.readyToUpdate) then
		return
	end

	if (self.player == nil) then
		self.player = PlayerManager:GetLocalPlayer()
	end

	if (self.player == nil) then
		return
	end

	self._raycastTimer = self._raycastTimer + p_Delta

	if (self._raycastTimer >= StaticConfig.raycastInterval) then
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
					local playerPosition = ClientUtils:GetCameraTransform().trans:Clone() --player.soldier.worldTransform.trans:Clone() + Utilities:getCameraPos(player, false)

					-- find direction of Bot
					local target	= bot.soldier.worldTransform.trans:Clone() + Utilities:getCameraPos(bot, false)
					local distance	= playerPosition:Distance(bot.soldier.worldTransform.trans)

					if (distance < Config.maxRaycastDistance) then
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

							if (distance < Config.distanceForDirectAttack) then
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
					local target	= bot.soldier.worldTransform.trans:Clone() + Utilities:getCameraPos(bot, false)
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

function ClientBotManager:_checkForBotBotAttack(pos1, pos2, name1, name2, inVehicle)
	--check for clear view to startpoint
	local startPos 	= Vec3(pos1.x, pos1.y + 1.0, pos1.z)
	local endPos 	= Vec3(pos2.x, pos2.y + 1.0, pos2.z)
	local raycast = nil
	if inVehicle then
		raycast	= RaycastManager:Raycast(startPos, endPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckPhantoms | RayCastFlags.DontCheckGroup | RayCastFlags.IsAsyncRaycast)
	else
		raycast	= RaycastManager:Raycast(startPos, endPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)
	end

	if (raycast == nil or raycast.rigidBody == nil) then
		NetEvents:SendLocal("BotShootAtBot", name1, name2)
	end
end

function ClientBotManager:_onBulletCollision(hook, entity, hit, shooter)
	if (hit.rigidBody.typeInfo.name == 'CharacterPhysicsEntity') then
		if Utilities:isBot(shooter) then
			local player = PlayerManager:GetLocalPlayer()

			if (player.soldier ~= nil) then
				local dx	= math.abs(player.soldier.worldTransform.trans.x - hit.position.x)
				local dz	= math.abs(player.soldier.worldTransform.trans.z - hit.position.z)
				local dy	= hit.position.y - player.soldier.worldTransform.trans.y --player y is on ground. Hit must be higher to be valid

				if (dx < 1 and dz < 1 and dy < 2 and dy > 0) then --included bodyhight
					local isHeadshot	= false
					local camaraHeight	= Utilities:getTargetHeight(player.soldier, false)
					
					if dy < camaraHeight + 0.3 and dy > camaraHeight - 0.10 then
						isHeadshot = true
					end
					
					NetEvents:SendLocal('ClientDamagePlayer', shooter.name, false, isHeadshot)
				end
			end
		end
	end
end

-- Singleton.
if g_ClientBotManager == nil then
	g_ClientBotManager = ClientBotManager()
end

return g_ClientBotManager
