require('__shared/Config')
local raycastTimer = 0
local lastIndex = 0


--webui openclose funtions -Bictcrusher
local webui = 0

Events:Subscribe('Extension:Loaded', function()
  WebUI:Init();
  WebUI:Hide();
end)

Events:Subscribe('Client:UpdateInput', function(data)
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F1) then
	if webui == 0 then
	print("webui = 1")
    WebUI:Show();
	webui = 1
	elseif webui == 1 then
	print("webui = 0")
    WebUI:Hide();
	webui = 0
	end
	end
end)
--webui openclose funtions -Bictcrusher

Events:Subscribe('UpdateManager:Update', function(p_Delta, p_Pass)
	if(p_Pass ~= UpdatePass.UpdatePass_PreFrame) then
		return
	end

	raycastTimer = raycastTimer + p_Delta
	if raycastTimer >= Config.raycastInterval then
		raycastTimer = 0
		for i = lastIndex, Config.maxNumberOfBots + lastIndex do
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
								bot.soldier.transform.trans.x - player.soldier.transform.trans.x,
								bot.soldier.transform.trans.y + botCamereaHight - playerCameraTrans.trans.y,
								bot.soldier.transform.trans.z - player.soldier.transform.trans.z)
						
						local distance = playerCameraTrans.trans:Distance(playerCameraTrans.trans+direction)
						if distance > Config.maxRaycastDistance then
							return
						elseif distance < 3	then --shoot, because you are near
							NetEvents:SendLocal("BotShootAtPlayer", bot.name, true)
							lastIndex = newIndex
							return
						end
						direction = direction:Normalize() * Config.maxRaycastDistance
						local castPos = Vec3(playerCameraTrans.trans.x + direction.x, playerCameraTrans.trans.y + direction.y, playerCameraTrans.trans.z + direction.z)

						local raycast = RaycastManager:Raycast(playerCameraTrans.trans, castPos, RayCastFlags.DontCheckWater | RayCastFlags.IsAsyncRaycast)
						lastIndex = newIndex
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
end)

Hooks:Install('BulletEntity:Collision', 1, function(hook, entity, hit, shooter)
	if hit.rigidBody.typeInfo.name == "CharacterPhysicsEntity" then
		local player = PlayerManager:GetLocalPlayer()
		if shooter.teamId ~= player.teamId and player.soldier ~= nil then 	-- TODO: Check shooter for bot
			local dx = math.abs(player.soldier.transform.trans.x - hit.position.x)
			local dz = math.abs(player.soldier.transform.trans.z - hit.position.z)
			local dy = hit.position.y - player.soldier.transform.trans.y --player y is on ground. Hit must be higher to be valid
			if dx < 1 and dz < 1 and dy < 2 and dy > 0 then --included bodyhight
				NetEvents:SendLocal("DamagePlayer", Config.bulletDamageBot, shooter.name)
			end
		end
	end
end)


--key presses instead of commands -Bitcrusher
Events:Subscribe('Client:UpdateInput', function(data)
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
end)
--Key pressess instead of commands -Bitcrusher