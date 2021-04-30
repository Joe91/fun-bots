class('ChatCommands');

require('__shared/Config');
require('__shared/NodeCollection');

local BotManager	= require('BotManager');
local BotSpawner	= require('BotSpawner');
local Globals 		= require('Model/Globals');

function ChatCommands:execute(parts, player)
	if player == nil or Config.disableChatCommands == true then
		return;
	end

	if parts[1] == '!permissions' then
		local permissions	= PermissionManager:GetPermissions(player);
		
		if permissions == nil then
			ChatManager:SendMessage('You have no active permissions (GUID: ' .. tostring(player.guid) .. ').', player);
		else
			ChatManager:SendMessage('You have following permissions (GUID: ' .. tostring(player.guid) .. '):', player);
			ChatManager:SendMessage(table.concat(permissions, ', '), player);
		end
		
	elseif parts[1] == '!row' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Row') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Row).', player);
			return;
		end
		
		if tonumber(parts[2]) == nil then
			return;
		end

		local length	= tonumber(parts[2]);
		local spacing	= tonumber(parts[3]) or 2;

		BotSpawner:spawnBotRow(player, length, spacing);

	elseif parts[1] == '!tower' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Tower') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Tower).', player);
			return;
		end
		
		if tonumber(parts[2]) == nil then
			return;
		end

		local height = tonumber(parts[2]);
		BotSpawner:spawnBotTower(player, height);

	elseif parts[1] == '!grid' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Grid') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Grid).', player);
			return;
		end
		
		if tonumber(parts[2]) == nil then
			return;
		end

		local rows		= tonumber(parts[2]);
		local columns	= tonumber(parts[3]) or tonumber(parts[2]);
		local spacing	= tonumber(parts[4]) or 2;

		BotSpawner:spawnBotGrid(player, rows, columns, spacing);

	-- static mode commands
	elseif parts[1] == '!mimic' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Mimic') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Mimic).', player);
			return;
		end
		
		BotManager:setStaticOption(player, 'mode', 3);

	elseif parts[1] == '!mirror' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Mirror') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Mirror).', player);
			return;
		end
		
		BotManager:setStaticOption(player, 'mode', 4);

	elseif parts[1] == '!static' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Static') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Static).', player);
			return;
		end
		
		BotManager:setStaticOption(player, 'mode', 0);

	-- moving bots spawning
	elseif parts[1] == '!spawnline' then
		if PermissionManager:HasPermission(player, 'ChatCommands.SpawnLine') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SpawnLine).', player);
			return;
		end
		
		if tonumber(parts[2]) == nil then
			return;
		end

		local amount	= tonumber(parts[2]);
		local spacing	= tonumber(parts[3]) or 2;

		BotSpawner:spawnLineBots(player, amount, spacing);

	elseif parts[1] == '!spawnway' then
		if PermissionManager:HasPermission(player, 'ChatCommands.SpawnWay') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SpawnWay).', player);
			return;
		end
		
		if tonumber(parts[2]) == nil then
			return;
		end

		local amount = tonumber(parts[2]) or 1;
		local activeWayIndex = tonumber(parts[3]) or 1;
		activeWayIndex = math.min(math.max(activeWayIndex, 1), #g_NodeCollection:GetPaths())

		BotSpawner:spawnWayBots(player, amount, false, activeWayIndex);

	elseif parts[1] == '!spawnbots' then
		if PermissionManager:HasPermission(player, 'ChatCommands.SpawnBots') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SpawnBots).', player);
			return;
		end
		
		if tonumber(parts[2]) == nil then
			return;
		end

		local amount = tonumber(parts[2]);

		BotSpawner:spawnWayBots(player, amount, true);

	-- respawn moving bots
	elseif parts[1] == '!respawn' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Respawn') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Respawn).', player);
			return;
		end
		
		local respawning = true;

		if tonumber(parts[2]) == 0 then
			respawning = false;
		end

		Globals.respawnWayBots = respawning;

		BotManager:setOptionForAll('respawn', respawning);

	elseif parts[1] == '!shoot' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Shoot') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Shoot).', player);
			return;
		end
		
		local shooting = true;

		if tonumber(parts[2]) == 0 then
			shooting = false;
		end

		Globals.attackWayBots = shooting;

		BotManager:setOptionForAll('shoot', shooting);

	-- spawn team settings
	elseif parts[1] == '!setbotkit' then
		if PermissionManager:HasPermission(player, 'ChatCommands.SetBotKit') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SetBotKit).', player);
			return;
		end
		
		local kitNumber = tonumber(parts[2]) or 1;

		if kitNumber <= 4 and kitNumber >= 0 then
			Config.botKit = BotKits[kitNumber];
		end

	elseif parts[1] == '!setbotcolor' then
		if PermissionManager:HasPermission(player, 'ChatCommands.SetBotColor') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SetBotColor).', player);
			return;
		end
		
		local botColor = tonumber(parts[2]) or 1;

		if botColor <= #BotColors and botColor >= 0 then
			Config.botColor = BotColors[botColor];
		end

	elseif parts[1] == '!setaim' then
		if PermissionManager:HasPermission(player, 'ChatCommands.SetAim') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SetAim).', player);
			return;
		end
		
		Config.botAimWorsening = tonumber(parts[2]) or 0.5;
		--self:_modifyWeapons(Config.botAimWorsening) --causes lag. Instead restart round
		if Debug.Server.COMMAND then
			print('difficulty set to ' .. Config.botAimWorsening .. '. Please restart round or level to take effect');
		end
		
	elseif parts[1] == '!shootback' then
		if PermissionManager:HasPermission(player, 'ChatCommands.ShootBack') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.ShootBack).', player);
			return;
		end
		
		if tonumber(parts[2]) == 0 then
			Config.shootBackIfHit = false;
		else
			Config.shootBackIfHit = true;
		end

	elseif parts[1] == '!attackmelee' then
		if PermissionManager:HasPermission(player, 'ChatCommands.AttackMelee') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.AttackMelee).', player);
			return;
		end
		
		if tonumber(parts[2]) == 0 then
			Config.meleeAttackIfClose = false;
		else
			Config.meleeAttackIfClose = true;
		end

	-- reset everything
	elseif parts[1] == '!stopall' then
		if PermissionManager:HasPermission(player, 'ChatCommands.StopAll') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.StopAll).', player);
			return;
		end
		
		BotManager:setOptionForAll('shoot', false);
		BotManager:setOptionForAll('respawning', false);
		BotManager:setOptionForAll('moveMode', 0);

	elseif parts[1] == '!stop' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Stop') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Stop).', player);
			return;
		end
		
		BotManager:setOptionForPlayer(player, 'shoot', false);
		BotManager:setOptionForPlayer(player, 'respawning', false);
		BotManager:setOptionForPlayer(player, 'moveMode', 0);

	elseif parts[1] == '!kickplayer' then
		if PermissionManager:HasPermission(player, 'ChatCommands.KickPlayer') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KickPlayer).', player);
			return;
		end
		
		BotManager:destroyPlayerBots(player);

	elseif parts[1] == '!kick' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Kick') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Kick).', player);
			return;
		end
		
		local amount = tonumber(parts[2]) or 1;

		BotManager:destroyAll(amount);

	elseif parts[1] == '!kickteam' then
		if PermissionManager:HasPermission(player, 'ChatCommands.KickTeam') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KickTeam).', player);
			return;
		end
		
		local teamToKick = tonumber(parts[2]) or 1;

		if teamToKick < 1 or teamToKick > 2 then
			return;
		end

		local teamId = teamToKick == 1 and TeamId.Team1 or TeamId.Team2;

		BotManager:destroyAll(nil, teamId);

	elseif parts[1] == '!kickall' then
		if PermissionManager:HasPermission(player, 'ChatCommands.KickAll') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KickAll).', player);
			return;
		end
		
		BotManager:destroyAll();

	elseif parts[1] == '!kill' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Kill') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Kill).', player);
			return;
		end
		
		BotManager:killPlayerBots(player);

	elseif parts[1] == '!killall' then
		if PermissionManager:HasPermission(player, 'ChatCommands.KillAll') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KillAll).', player);
			return;
		end
		
		BotManager:killAll();

	-- waypoint stuff
	elseif parts[1] == '!getnodes' then
		if PermissionManager:HasPermission(player, 'ChatCommands.GetNodes') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.GetNodes).', player);
			return;
		end
		
		NetEvents:SendToLocal('ClientNodeEditor:ReceiveNodes', player, #g_NodeCollection:Get())

	elseif parts[1] == '!sendnodes' then
		if PermissionManager:HasPermission(player, 'ChatCommands.SendNodes') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SendNodes).', player);
			return;
		end
		
		NetEvents:SendToLocal('ClientNodeEditor:SaveNodes', player)

	elseif parts[1] == '!trace' then
		if PermissionManager:HasPermission(player, 'ChatCommands.Trace') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Trace).', player);
			return;
		end
		
		NetEvents:SendToLocal('ClientNodeEditor:StartTrace', player)

	elseif parts[1] == '!tracedone' then
		if PermissionManager:HasPermission(player, 'ChatCommands.TraceDone') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.TraceDone).', player);
			return;
		end
		
		NetEvents:SendToLocal('ClientNodeEditor:EndTrace', player)


	elseif parts[1] == '!cleartrace' then
		if PermissionManager:HasPermission(player, 'ChatCommands.ClearTrace') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.ClearTrace).', player);
			return;
		end
		
		NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', player)

	elseif parts[1] == '!clearalltraces' then
		if PermissionManager:HasPermission(player, 'ChatCommands.ClearAllTraces') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.ClearAllTraces).', player);
			return;
		end
		
		g_NodeCollection:Clear()
		NetEvents:SendLocal('NodeCollection:Clear')

	elseif parts[1] == '!printtrans' then
		if PermissionManager:HasPermission(player, 'ChatCommands.PrintTransform') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.PrintTransform).', player);
			return;
		end
		
		print('!printtrans');
		ChatManager:Yell('!printtrans check server console', 2.5);
		print(player.soldier.worldTransform);
		print(player.soldier.worldTransform.trans.x);
		print(player.soldier.worldTransform.trans.y);
		print(player.soldier.worldTransform.trans.z);

	elseif parts[1] == '!tracesave' then
		if PermissionManager:HasPermission(player, 'ChatCommands.TraceSave') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.TraceSave).', player);
			return;
		end
		
		local traceIndex = tonumber(parts[2]) or 0;
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', player, traceIndex)
	end
end

-- Singleton.
if g_ChatCommands == nil then
	g_ChatCommands = ChatCommands();
end

return g_ChatCommands;