class('Utilities');

function Utilities:__init()
	-- nothing to do
end

function Utilities:getTargetHeight(soldier, isTarget)
	local camereaHight = 0;

	if not isTarget or Config.aimForHead then
		camereaHight = 1.6; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand

		if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			camereaHight = 0.3;
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			camereaHight = 1.0;
		end
	else --aim a little lower
		camereaHight = 1.3; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand - reduce by 0.3

		if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			camereaHight = 0.3; -- don't reduce
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			camereaHight = 0.8; -- reduce by 0.2
		end
	end

	return camereaHight;
end

-- Singleton.
if g_Utilities == nil then
	g_Utilities = Utilities();
end

return g_Utilities;