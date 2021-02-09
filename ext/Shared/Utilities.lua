class('Utilities');

require('__shared/Config');

function Utilities:__init()
	-- nothing to do
end

function Utilities:getCameraPos(player, isTarget)
	local returnVec = Vec3(0,0,0)
	local cameraVec = player.input.authoritativeCameraPosition:Clone();
	if cameraVec.z ~= 0 then
		returnVec = player.soldier.worldTransform.forward* cameraVec.z + player.soldier.worldTransform.left * cameraVec.x + player.soldier.worldTransform.up * cameraVec.y;
		--print(returnVec)

		if isTarget then
			if Config.aimForHead then
				if player.soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
					returnVec.y = returnVec.y - 0.1
				elseif player.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
					returnVec.y = returnVec.y - 0.05
				else
					returnVec.y = returnVec.y - 0.05
				end
			else
				if player.soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
					returnVec.y = returnVec.y - 0.4
				elseif player.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
					returnVec.y = returnVec.y - 0.2
				else
					returnVec.y = returnVec.y - 0.05
				end
			end
		end
	else
		returnVec = Vec3(0.03 ,self:getTargetHeight(player.soldier, isTarget), 0.03)
	end
	return returnVec;
end

function Utilities:getTargetHeight(soldier, isTarget)
	local camereaHight = 0;

	if not isTarget then
		camereaHight = 1.6; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand
		if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			camereaHight = 0.3;
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			camereaHight = 1.0;
		end
	elseif isTarget and Config.aimForHead then
		camereaHight = 1.50; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand
		if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			camereaHight = 0.25;
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			camereaHight = 1;
		end
	else --aim a little lower
		camereaHight = 1.2; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand - reduce by 0.4
		if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			camereaHight = 0.25; -- don't reduce
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			camereaHight = 0.8; -- reduce by 0.2
		end
	end

	return camereaHight;
end

function Utilities:isBot(name)
	local isBot = false
	for  index, botname in pairs(BotNames) do
		if name == botname then
			isBot = true;
			break;
		end
		if index > MAX_NUMBER_OF_BOTS then
			break;
		end
	end
	return isBot;
end

-- Singleton.
if g_Utilities == nil then
	g_Utilities = Utilities();
end

return g_Utilities;