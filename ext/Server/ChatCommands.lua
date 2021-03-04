class('ChatCommands');

require('__shared/Config');

local BotManager	= require('BotManager');
local BotSpawner	= require('BotSpawner');
local Globals 		= require('Globals');


function ChatCommands:__init()
	RCON:RegisterCommand('funbots', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
		return {
			'OK',
			'funbots.kickAll',
			'funbots.killAll',
			'funbots.spawn <Amount> <Team>'
		};
	end);
	
	RCON:RegisterCommand('funbots.kickAll', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
		BotManager:destroyAllBots();
	end);
	
	RCON:RegisterCommand('funbots.killAll', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
		BotManager:killAll();
	end);
	
	RCON:RegisterCommand('funbots.spawn', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
		local value	= args[1];
		local team	= args[2];
		
		if value == nil then
			return {'ERROR', 'Needing Spawn amount.'};
		end
		
		if team == nil then
			return {'ERROR', 'Needing Team.'};
		end
		
		if tonumber(value) == nil then
			return {'ERROR', 'Needing Spawn amount.'};
		end

		local amount	= tonumber(value);
		local t			= TeamId.Neutral;

		if team == "Team1" then
			t = TeamId.Team1;
		elseif team == "Team2" then
			t = TeamId.Team2;
		end
		
		BotSpawner:spawnWayBots(player, amount, true, nil, nil, t);
		
		return {'OK'};
	end);
end

function ChatCommands:execute(parts, player)
	if player == nil or Config.disableChatCommands == true then
		return;
	end

	if parts[1] == '!row' then
		if tonumber(parts[2]) == nil then
			return;
		end

		local length	= tonumber(parts[2]);
		local spacing	= tonumber(parts[3]) or 2;

		BotSpawner:spawnBotRow(player, length, spacing);

	elseif parts[1] == '!tower' then
		if tonumber(parts[2]) == nil then
			return;
		end

		local height = tonumber(parts[2]);
		BotSpawner:spawnBotTower(player, height);

	elseif parts[1] == '!grid' then
		if tonumber(parts[2]) == nil then
			return;
		end

		local rows		= tonumber(parts[2]);
		local columns	= tonumber(parts[3]) or tonumber(parts[2]);
		local spacing	= tonumber(parts[4]) or 2;

		BotSpawner:spawnBotGrid(player, rows, columns, spacing);

	-- static mode commands
	elseif parts[1] == '!mimic' then
		BotManager:setStaticOption(player, 'mode', 3);

	elseif parts[1] == '!mirror' then
		BotManager:setStaticOption(player, 'mode', 4);

	elseif parts[1] == '!static' then
		BotManager:setStaticOption(player, 'mode', 0);

	-- moving bots spawning
	elseif parts[1] == '!spawnline' then
		if tonumber(parts[2]) == nil then
			return;
		end

		local amount	= tonumber(parts[2]);
		local spacing	= tonumber(parts[3]) or 2;

		BotSpawner:spawnLineBots(player, amount, spacing);

	elseif parts[1] == '!spawnway' then
		if tonumber(parts[2]) == nil then
			return;
		end

		local activeWayIndex = tonumber(parts[3]) or 1;

		if activeWayIndex > MAX_TRACE_NUMBERS or activeWayIndex < 1 then
			activeWayIndex = 1;
		end

		local amount = tonumber(parts[2]);

		BotSpawner:spawnWayBots(player, amount, false, activeWayIndex);

	elseif parts[1] == '!spawnbots' then
		if tonumber(parts[2]) == nil then
			return;
		end

		local amount = tonumber(parts[2]);

		BotSpawner:spawnWayBots(player, amount, true);

	-- respawn moving bots
	elseif parts[1] == '!respawn' then
		local respawning = true;

		if tonumber(parts[2]) == 0 then
			respawning = false;
		end

		Globals.respawnWayBots = respawning;

		BotManager:setOptionForAll('respawn', respawning);

	elseif parts[1] == '!shoot' then
		local shooting = true;

		if tonumber(parts[2]) == 0 then
			shooting = false;
		end

		Globals.attackWayBots = shooting;

		BotManager:setOptionForAll('shoot', shooting);

	-- spawn team settings
	elseif parts[1] == '!setbotkit' then
		local kitNumber = tonumber(parts[2]) or 1;

		if kitNumber <= 4 and kitNumber >= 0 then
			Config.botKit = BotKits[kitNumber];
		end

	elseif parts[1] == '!setbotcolor' then
		local botColor = tonumber(parts[2]) or 1;

		if botColor <= #BotColors and botColor >= 0 then
			Config.botColor = BotColors[botColor];
		end

	elseif parts[1] == '!setaim' then
		Config.botAimWorsening = tonumber(parts[2]) or 0.5;
		--self:_modifyWeapons(Config.botAimWorsening) --causes lag. Instead restart round
		print('difficulty set to ' .. Config.botAimWorsening .. '. Please restart round or level to take effect');

	elseif parts[1] == '!shootback' then
		if tonumber(parts[2]) == 0 then
			Config.shootBackIfHit = false;
		else
			Config.shootBackIfHit = true;
		end

	elseif parts[1] == '!attackmelee' then
		if tonumber(parts[2]) == 0 then
			Config.meleeAttackIfClose = false;
		else
			Config.meleeAttackIfClose = true;
		end

	-- reset everything
	elseif parts[1] == '!stopall' then
		BotManager:setOptionForAll('shoot', false);
		BotManager:setOptionForAll('respawning', false);
		BotManager:setOptionForAll('moveMode', 0);

	elseif parts[1] == '!stop' then
		BotManager:setOptionForPlayer(player, 'shoot', false);
		BotManager:setOptionForPlayer(player, 'respawning', false);
		BotManager:setOptionForPlayer(player, 'moveMode', 0);

	elseif parts[1] == '!kickplayer' then
		BotManager:destroyPlayerBots(player);

	elseif parts[1] == '!kick' then
		local amount = tonumber(parts[2]) or 1;

		BotManager:destroyAmount(amount);

	elseif parts[1] == '!kickteam' then
		local teamToKick = tonumber(parts[2]) or 1;

		if teamToKick < 1 or teamToKick > 2 then
			return;
		end

		local teamId = teamToKick == 1 and TeamId.Team1 or TeamId.Team2;

		BotManager:destroyTeam(teamId);

	elseif parts[1] == '!kickall' then
		BotManager:destroyAllBots();

	elseif parts[1] == '!kill' then
		BotManager:killPlayerBots(player);

	elseif parts[1] == '!killall' then
		BotManager:killAll();

	-- waypoint stuff
	elseif parts[1] == '!getnodes' then
		NetEvents:SendToLocal('ClientNodeEditor:ReceiveNodes', player, #g_NodeCollection:Get())

	elseif parts[1] == '!sendnodes' then
		NetEvents:SendToLocal('ClientNodeEditor:SaveNodes', player)

	elseif parts[1] == '!trace' then
		NetEvents:SendToLocal('ClientNodeEditor:StartTrace', player)

	elseif parts[1] == '!tracedone' then
		NetEvents:SendToLocal('ClientNodeEditor:EndTrace', player)


	elseif parts[1] == '!cleartrace' then
		NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', player)

	elseif parts[1] == '!clearalltraces' then
		g_NodeCollection:Clear()
		NetEvents:SendLocal('NodeCollection:Clear')

	elseif parts[1] == '!printtrans' then
		print('!printtrans');
		ChatManager:Yell('!printtrans check server console', 2.5);
		print(player.soldier.worldTransform);
		print(player.soldier.worldTransform.trans.x);
		print(player.soldier.worldTransform.trans.y);
		print(player.soldier.worldTransform.trans.z);

	elseif parts[1] == '!tracesave' then
		local traceIndex = tonumber(parts[2]) or 0;
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', player, traceIndex)
	end
end

-- Singleton.
if g_ChatCommands == nil then
	g_ChatCommands = ChatCommands();
end

return g_ChatCommands;