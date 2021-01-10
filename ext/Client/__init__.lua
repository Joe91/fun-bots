class('FunBotClient')
require('__shared/Config')

function FunBotClient:__init()
	self._raycastTimer = 0
	self._lastIndex = 0
	self._webui = 0

	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput)
	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded)
	Hooks:Install('BulletEntity:Collision', 1, self, self._onBulletCollision)
	Events:Subscribe('exitui', self, self._onExitUi)
end

function FunBotClient:_onExitUi(player)
    if self._webui == 1 then
        self._webui = 0
		print("self._webui = 0")
    end
end

function FunBotClient:_onExtensionLoaded()
  WebUI:Init();
  WebUI:Hide();
end


function FunBotClient:_onUpdate(p_Delta, p_Pass)
	if(p_Pass ~= UpdatePass.UpdatePass_PreFrame) then
		return
	end

	self._raycastTimer = self._raycastTimer + p_Delta
	if self._raycastTimer >= Config.raycastInterval then
		self._raycastTimer = 0
		for i = self._lastIndex, Config.maxNumberOfBots + self._lastIndex do
			local newIndex = i % Config.maxNumberOfBots + 1
			local bot = PlayerManager:GetPlayerByName(BotNames[newIndex])
			local player = PlayerManager:GetLocalPlayer()
			if bot ~= nil then
				if player.teamId ~= bot.teamId then
					if bot.soldier ~= nil and player.soldier ~= nil then
						-- check for clear view
						local playerCameraTrans = ClientUtils:GetCameraTransform()

						local botCamereaHight = 1.6 --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand
						if bot.soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
							botCamereaHight = 0.3
						elseif bot.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
							botCamereaHight = 1.0
						end

						-- find direction of Bot
						local direction = Vec3(
								bot.soldier.worldTransform.trans.x - player.soldier.worldTransform.trans.x,
								bot.soldier.worldTransform.trans.y + botCamereaHight - playerCameraTrans.trans.y,
								bot.soldier.worldTransform.trans.z - player.soldier.worldTransform.trans.z)

						local distance = playerCameraTrans.trans:Distance(playerCameraTrans.trans+direction)
						if distance > Config.maxRaycastDistance then
							return
						elseif distance < 3	then --shoot, because you are near
							NetEvents:SendLocal("BotShootAtPlayer", bot.name, true)
							self._lastIndex = newIndex
							return
						end
						direction = direction:Normalize() * Config.maxRaycastDistance
						local castPos = Vec3(playerCameraTrans.trans.x + direction.x, playerCameraTrans.trans.y + direction.y, playerCameraTrans.trans.z + direction.z)

						local raycast = RaycastManager:Raycast(playerCameraTrans.trans, castPos, RayCastFlags.DontCheckWater | RayCastFlags.IsAsyncRaycast)
						self._lastIndex = newIndex
						if raycast == nil or raycast.rigidBody == nil or raycast.rigidBody:Is("CharacterPhysicsEntity") == false then
							return
						end
						-- we found a valid bot in Sight. Signal Server with players
						NetEvents:SendLocal("BotShootAtPlayer", bot.name, false)
						return --valid bot found. Return to save computing power
					end
				end
			end
		end
	end
end

function FunBotClient:_onBulletCollision(hook, entity, hit, shooter)
	if hit.rigidBody.typeInfo.name == "CharacterPhysicsEntity" then
		local player = PlayerManager:GetLocalPlayer()
		if shooter.teamId ~= player.teamId and player.soldier ~= nil then 	-- TODO: Check shooter for bot
			local dx = math.abs(player.soldier.worldTransform.trans.x - hit.position.x)
			local dz = math.abs(player.soldier.worldTransform.trans.z - hit.position.z)
			local dy = hit.position.y - player.soldier.worldTransform.trans.y --player y is on ground. Hit must be higher to be valid
			if dx < 1 and dz < 1 and dy < 2 and dy > 0 then --included bodyhight
				NetEvents:SendLocal("DamagePlayer", Config.bulletDamageBot, shooter.name)
			end
		end
	end
end


--key presses instead of commands -Bitcrusher
function FunBotClient:_onUpdateInput(data)
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F1) then
		if self._webui == 0 then
			WebUI:Show();
			WebUI:EnableMouse();
			WebUI:EnableKeyboard();	
			self._webui = 1
			print("self._webui = 1")
		elseif self._webui == 1 then
			WebUI:Hide();
			WebUI:ResetMouse();
			WebUI:ResetKeyboard();
			self._webui = 0
			print("self._webui = 0")
		end
	end


  	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F5) then
		NetEvents:Send('keypressF5')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F6) then
		NetEvents:Send('keypressF6')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F7) then
		NetEvents:Send('keypressF7')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F8) then
		NetEvents:Send('keypressF8')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F9) then
		NetEvents:Send('keypressF9')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F10) then
		NetEvents:Send('keypressF10')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F11) then
		NetEvents:Send('keypressF11')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		NetEvents:Send('keypressF12')
	end
end


--webui events dispatch -bitcrusher
--spawnbots
Events:Subscribe('spawnbotsvalue', function(data)
  spawnbots = data
  NetEvents:Send('spawnbots', spawnbots)
  print("spawning: ".. spawnbots .." bots..")
end)
Events:Subscribe('spawnrandombot', function(data)
  spawnbots = data
  NetEvents:Send('spawnrandombot', spawnbots)
  print("spawning: ".. spawnbots .." random bots..")
end)
Events:Subscribe('kickallbots', function(data)
  NetEvents:Send('kickallbots')
  print("Kicking all bots...")
end)
Events:Subscribe('respawnbots', function(data)
  NetEvents:Send('respawnbots')
  print("bot respawn enabled")
end)
--staticbots

-- Singleton.
if g_FunBotClient == nil then
	g_FunBotClient = FunBotClient()
end

return g_FunBotClient