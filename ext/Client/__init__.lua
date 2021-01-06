require('__shared/Config')
local explosionEntityData = nil
local RAYCAST_INTERVAL = 0.1 -- seconds
local MAX_RAYCAST_DISTANCE = 150.0 -- meters
local raycastTimer = 0
local lastIndex = 0

Events:Subscribe('UpdateManager:Update', function(p_Delta, p_Pass)
	if(p_Pass ~= UpdatePass.UpdatePass_PreFrame) then
		return
	end

	raycastTimer = raycastTimer + p_Delta
	if raycastTimer >= RAYCAST_INTERVAL then
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
						local dx = bot.soldier.transform.trans.x - player.soldier.transform.trans.x
						local dy = bot.soldier.transform.trans.y + botCamereaHight - playerCameraTrans.trans.y
						local dz = bot.soldier.transform.trans.z - player.soldier.transform.trans.z
						local direction = Vec3(dx, dy,  dz)
						
						local distance = playerCameraTrans.trans:Distance(playerCameraTrans.trans+direction)
						if distance > MAX_RAYCAST_DISTANCE then
							print("bot too far away"..bot.name.."  "..distance)
							return
						end
						direction = direction:Normalize() * MAX_RAYCAST_DISTANCE
						local castPos = Vec3(playerCameraTrans.trans.x + direction.x, playerCameraTrans.trans.y + direction.y, playerCameraTrans.trans.z + direction.z)

						local raycast = RaycastManager:Raycast(playerCameraTrans.trans, castPos, RayCastFlags.DontCheckWater | RayCastFlags.IsAsyncRaycast)
						lastIndex = newIndex
						if raycast == nil or raycast.rigidBody == nil or raycast.rigidBody:Is("CharacterPhysicsEntity") == false then
							print("no valid cast to "..bot.name)
							return
						end
						-- we found a valid bot in Sight. Signal Server with players
						NetEvents:SendLocal("BotShootAtPlayer", bot.name)
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
		if shooter.teamId ~= player.teamId then 	-- TODO: Check shooter for bot
			local dx = player.soldier.transform.trans.x - hit.position.x
			local dy = player.soldier.transform.trans.y - hit.position.y
			local dz = player.soldier.transform.trans.z - hit.position.z
			if dx < 1 and dy < 1 and dz < 1 then
				NetEvents:SendLocal("DamagePlayer", Config.bulletDamageBot)
			end
		end
	end
end)

local function getExplosionEntityData()
	if explosionEntityData ~= nil then
		return explosionEntityData
	end

	local original = ResourceManager:SearchForInstanceByGuid(Guid('D41B0855-6874-4650-8064-DC9F7ED76B0E'))	--5FE6E2AD-072E-4722-984A-5C52BC66D4C1

	if original == nil then
		print('Could not find explosion template')
		return nil
	end

	explosionEntityData = VeniceExplosionEntityData(original:Clone())

	return explosionEntityData
end

NetEvents:Subscribe('Bot:Killed', function(position)

	local data = getExplosionEntityData()

	if data == nil then
		print('Could not get explosion data')
		return
	end

	-- Create the entity at the provided position.
	local transform = LinearTransform()
	transform.trans = position

	local entity = EntityManager:CreateEntity(data, transform)

	if entity == nil then
		print('Could not create entity.')
		return
	end

	entity = ExplosionEntity(entity)
	--entity:Init(Realm.Realm_ClientAndServer, true)
	entity:Detonate(transform, Vec3(0, 1, 0), 1.0, nil)
end)

Events:Subscribe('Level:LoadResources', function()
	explosionEntityData = nil
end)
