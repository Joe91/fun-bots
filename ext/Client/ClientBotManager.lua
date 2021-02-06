class('ClientBotManager');

require('__shared/Config');

local WeaponModification 	= require('__shared/WeaponModification');
local Utilities 			= require('__shared/Utilities')

function ClientBotManager:__init()
	self._raycastTimer	= 0;
	self._lastIndex		= 0;

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate);
	Hooks:Install('BulletEntity:Collision', 200, self, self._onBulletCollision);
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
		WeaponModification:ModifyAllWeapons(Config.botAimWorsening, Config.botSniperAimWorsening);
	end
end

function ClientBotManager:_onUpdate(p_Delta, p_Pass)
	if (p_Pass ~= UpdatePass.UpdatePass_PreFrame) then
		return
	end

	self._raycastTimer = self._raycastTimer + p_Delta;

	if (self._raycastTimer >= StaticConfig.raycastInterval) then
		self._raycastTimer = 0;

		for i = self._lastIndex, MAX_NUMBER_OF_BOTS + self._lastIndex do
			local newIndex	= i % MAX_NUMBER_OF_BOTS + 1;
			local bot		= PlayerManager:GetPlayerByName(BotNames[newIndex]);
			local player	= PlayerManager:GetLocalPlayer();

			if (bot ~= nil) then
				if (bot.soldier ~= nil and player.soldier ~= nil) then
					-- check for clear view
					-- local playerCameraTrans	= ClientUtils:GetCameraTransform(); -- don't use camera, as this is used by mav or eod
					local playerPosition = player.soldier.worldTransform.trans:Clone() + Utilities:getCameraPos(player, false); --Vec3(player.soldier.worldTransform.trans.x, player.soldier.worldTransform.trans.y + Utilities:getTargetHeight(player.soldier, false), player.soldier.worldTransform.trans.z)

					-- find direction of Bot
					local target	= bot.soldier.worldTransform.trans:Clone() + Utilities:getCameraPos(bot, false);
					local distance	= playerPosition:Distance(bot.soldier.worldTransform.trans);

					if (distance < Config.maxRaycastDistance) then
						self._lastIndex	= newIndex;
						local raycast	= RaycastManager:Raycast(playerPosition, target, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)

						if (raycast == nil or raycast.rigidBody == nil) then
							-- we found a valid bot in Sight (either no hit, or player-hit). Signal Server with players
							local ignoreYaw = false;
							if (distance < Config.distanceForDirectAttack) then
								ignoreYaw = true; --shoot, because you are near
							end
							NetEvents:SendLocal("BotShootAtPlayer", bot.name, ignoreYaw);
						end
						return --only one raycast per cycle
					end
				end
			end
		end
	end
end

function ClientBotManager:_onBulletCollision(hook, entity, hit, shooter)
	if (hit.rigidBody.typeInfo.name == 'CharacterPhysicsEntity') then
		if Utilities:isBot(shooter.name) then
			local player = PlayerManager:GetLocalPlayer();

			if (player.soldier ~= nil) then
				local dx	= math.abs(player.soldier.worldTransform.trans.x - hit.position.x);
				local dz	= math.abs(player.soldier.worldTransform.trans.z - hit.position.z);
				local dy	= hit.position.y - player.soldier.worldTransform.trans.y; --player y is on ground. Hit must be higher to be valid

				if (dx < 1 and dz < 1 and dy < 2 and dy > 0) then --included bodyhight
					local isHeadshot = false;
					local camaraHeight = Utilities:getTargetHeight(player.soldier, false)
					if dy < camaraHeight + 0.3 and dy > camaraHeight - 0.20 then
						isHeadshot = true;
					end
					NetEvents:SendLocal('ClientDamagePlayer', shooter.name, false, isHeadshot);
				end
			end
		end
	end
end

-- Singleton.
if g_ClientBotManager == nil then
	g_ClientBotManager = ClientBotManager();
end

return g_ClientBotManager;