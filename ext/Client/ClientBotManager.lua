class('ClientBotManager');

require('__shared/Config');

local WeaponModification = require('__shared/WeaponModification');

function ClientBotManager:__init()
	self._raycastTimer	= 0;
	self._lastIndex		= 0;
	
	Events:Subscribe('UpdateManager:Update', self, self._onUpdate);
	Hooks:Install('BulletEntity:Collision', 1, self, self._onBulletCollision);
	NetEvents:Subscribe('WriteClientSettings', self, self._onWriteClientSettings);
end

function ClientBotManager:onExtensionUnload()
	self._raycastTimer	= 0;
	self._lastIndex		= 0;
end

function ClientBotManager:onEngineMessage(p_Message)
	if (p_Message.type == MessageType.ClientLevelFinalizedMessage) then
		NetEvents:SendLocal('RequestClientSettings');
	end
end

function ClientBotManager:_onWriteClientSettings(newConfig, isInitialConfig)
	for key, value in pairs(newConfig) do
		Config[key] = value;
	end
	
	if isInitialConfig then
		WeaponModification:ModifyAllWeapons(Config.botAimWorsening);
	end
end

function ClientBotManager:_onUpdate(p_Delta, p_Pass)
	if (p_Pass ~= UpdatePass.UpdatePass_PreFrame) then
		return
	end

	self._raycastTimer = self._raycastTimer + p_Delta;
	
	if (self._raycastTimer >= Config.raycastInterval) then
		self._raycastTimer = 0;
		
		for i = self._lastIndex, Config.maxNumberOfBots + self._lastIndex do
			local newIndex	= i % Config.maxNumberOfBots + 1;
			local bot		= PlayerManager:GetPlayerByName(BotNames[newIndex]);
			local player	= PlayerManager:GetLocalPlayer();
			
			if (bot ~= nil) then
				if (player.teamId ~= bot.teamId) then
					if (bot.soldier ~= nil and player.soldier ~= nil) then
						-- check for clear view
						local playerCameraTrans	= ClientUtils:GetCameraTransform();
						local botCamereaHight	= 1.6; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand
						
						if (bot.soldier.pose == CharacterPoseType.CharacterPoseType_Prone) then
							botCamereaHight = 0.3;
						elseif (bot.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch) then
							botCamereaHight = 1.0;
						end

						-- find direction of Bot
						local target	= Vec3(bot.soldier.worldTransform.trans.x, bot.soldier.worldTransform.trans.y + botCamereaHight, bot.soldier.worldTransform.trans.z);
						local distance	= playerCameraTrans.trans:Distance(bot.soldier.worldTransform.trans);
						
						if (distance < Config.distanceForDirectAttack) then --shoot, because you are near
							NetEvents:SendLocal('BotShootAtPlayer', bot.name, true);
						elseif (distance < Config.maxRaycastDistance) then
							self._lastIndex	= newIndex;
							local raycast	= RaycastManager:Raycast(playerCameraTrans.trans, target, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter| RayCastFlags.IsAsyncRaycast);
							
							if (raycast == nil or raycast.rigidBody == nil) then
								-- we found a valid bot in Sight (either no hit, or player-hit). Signal Server with players
								NetEvents:SendLocal("BotShootAtPlayer", bot.name, false);
							end
							return  --only one raycast per cycle
						end
					end
				end
			end
		end
	end
end

function ClientBotManager:_onBulletCollision(hook, entity, hit, shooter)
	if (hit.rigidBody.typeInfo.name == 'CharacterPhysicsEntity') then
		local player = PlayerManager:GetLocalPlayer();
		
		if (shooter.teamId ~= player.teamId and player.soldier ~= nil) then -- TODO: Check shooter for bot
			local dx	= math.abs(player.soldier.worldTransform.trans.x - hit.position.x);
			local dz	= math.abs(player.soldier.worldTransform.trans.z - hit.position.z);
			local dy	= hit.position.y - player.soldier.worldTransform.trans.y; --player y is on ground. Hit must be higher to be valid
			
			if (dx < 1 and dz < 1 and dy < 2 and dy > 0) then --included bodyhight
				NetEvents:SendLocal('ClientDamagePlayer', shooter.name, false);
			end
		end
	end
end

-- Singleton.
if g_ClientBotManager == nil then
	g_ClientBotManager = ClientBotManager();
end

return g_ClientBotManager;