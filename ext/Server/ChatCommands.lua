class('ChatCommands')

require('__shared/Config')
require('__shared/NodeCollection')

local BotManager	= require('BotManager')
local BotSpawner	= require('BotSpawner')

function ChatCommands:execute(p_Parts, p_Player)
	if p_Player == nil or Config.DisableChatCommands == true then
		return
	end

	if p_Parts[1] == '!row' then
		if tonumber(p_Parts[2]) == nil then
			return
		end

		local length	= tonumber(p_Parts[2])
		local spacing	= tonumber(p_Parts[3]) or 2

		BotSpawner:spawnBotRow(p_Player, length, spacing)

	elseif p_Parts[1] == '!tower' then
		if tonumber(p_Parts[2]) == nil then
			return
		end

		local height = tonumber(p_Parts[2])
		BotSpawner:spawnBotTower(p_Player, height)

	elseif p_Parts[1] == '!grid' then
		if tonumber(p_Parts[2]) == nil then
			return
		end

		local rows		= tonumber(p_Parts[2])
		local columns	= tonumber(p_Parts[3]) or tonumber(p_Parts[2])
		local spacing	= tonumber(p_Parts[4]) or 2

		BotSpawner:spawnBotGrid(p_Player, rows, columns, spacing)

	-- static mode commands
	elseif p_Parts[1] == '!mimic' then
		BotManager:setStaticOption(p_Player, 'mode', 3)

	elseif p_Parts[1] == '!mirror' then
		BotManager:setStaticOption(p_Player, 'mode', 4)

	elseif p_Parts[1] == '!static' then
		BotManager:setStaticOption(p_Player, 'mode', 0)

	-- moving bots spawning
	elseif p_Parts[1] == '!spawnline' then
		if tonumber(p_Parts[2]) == nil then
			return
		end

		local amount	= tonumber(p_Parts[2])
		local spacing	= tonumber(p_Parts[3]) or 2

		BotSpawner:spawnLineBots(p_Player, amount, spacing)

	elseif p_Parts[1] == '!spawnway' then
		if tonumber(p_Parts[2]) == nil then
			return
		end

		local amount = tonumber(p_Parts[2]) or 1
		local activeWayIndex = tonumber(p_Parts[3]) or 1
		activeWayIndex = math.min(math.max(activeWayIndex, 1), #g_NodeCollection:GetPaths())

		BotSpawner:spawnWayBots(p_Player, amount, false, activeWayIndex)

	elseif p_Parts[1] == '!spawnbots' then
		if tonumber(p_Parts[2]) == nil then
			return
		end

		local amount = tonumber(p_Parts[2])

		BotSpawner:spawnWayBots(p_Player, amount, true)

	-- respawn moving bots
	elseif p_Parts[1] == '!respawn' then
		local respawning = true

		if tonumber(p_Parts[2]) == 0 then
			respawning = false
		end

		Globals.RespawnWayBots = respawning

		BotManager:setOptionForAll('respawn', respawning)

	elseif p_Parts[1] == '!shoot' then
		local shooting = true

		if tonumber(p_Parts[2]) == 0 then
			shooting = false
		end

		Globals.AttackWayBots = shooting

		BotManager:setOptionForAll('shoot', shooting)

	-- spawn team settings
	elseif p_Parts[1] == '!setbotkit' then
		local kitNumber = tonumber(p_Parts[2]) or 1

		if kitNumber <= 4 and kitNumber >= 0 then
			Config.BotKit = BotKits[kitNumber]
		end

	elseif p_Parts[1] == '!setbotcolor' then
		local botColor = tonumber(p_Parts[2]) or 1

		if botColor <= #BotColors and botColor >= 0 then
			Config.BotColor = BotColors[botColor]
		end

	elseif p_Parts[1] == '!setaim' then
		Config.BotAimWorsening = tonumber(p_Parts[2]) or 0.5
		--self:_modifyWeapons(Config.BotAimWorsening) --causes lag. Instead restart round
		if Debug.Server.COMMAND then
			print('difficulty set to ' .. Config.BotAimWorsening .. '. Please restart round or level to take effect')
		end

	elseif p_Parts[1] == '!shootback' then
		if tonumber(p_Parts[2]) == 0 then
			Config.ShootBackIfHit = false
		else
			Config.ShootBackIfHit = true
		end

	elseif p_Parts[1] == '!attackmelee' then
		if tonumber(p_Parts[2]) == 0 then
			Config.MeleeAttackIfClose = false
		else
			Config.MeleeAttackIfClose = true
		end

	-- reset everything
	elseif p_Parts[1] == '!stopall' then
		BotManager:setOptionForAll('shoot', false)
		BotManager:setOptionForAll('respawning', false)
		BotManager:setOptionForAll('moveMode', 0)

	elseif p_Parts[1] == '!stop' then
		BotManager:setOptionForPlayer(p_Player, 'shoot', false)
		BotManager:setOptionForPlayer(p_Player, 'respawning', false)
		BotManager:setOptionForPlayer(p_Player, 'moveMode', 0)

	elseif p_Parts[1] == '!kickp_Player' then
		BotManager:destroyPlayerBots(p_Player)

	elseif p_Parts[1] == '!kick' then
		local amount = tonumber(p_Parts[2]) or 1

		BotManager:destroyAll(amount)

	elseif p_Parts[1] == '!kickteam' then
		local teamToKick = tonumber(p_Parts[2]) or 1

		if teamToKick < 1 or teamToKick > 2 then
			return
		end

		local teamId = teamToKick == 1 and TeamId.Team1 or TeamId.Team2

		BotManager:destroyAll(nil, teamId)

	elseif p_Parts[1] == '!kickall' then
		BotManager:destroyAll()

	elseif p_Parts[1] == '!kill' then
		BotManager:killPlayerBots(p_Player)

	elseif p_Parts[1] == '!killall' then
		BotManager:killAll()

	-- waypoint stuff
	elseif p_Parts[1] == '!getnodes' then
		NetEvents:SendToLocal('ClientNodeEditor:ReceiveNodes', p_Player, #g_NodeCollection:Get())

	elseif p_Parts[1] == '!sendnodes' then
		NetEvents:SendToLocal('ClientNodeEditor:SaveNodes', p_Player)

	elseif p_Parts[1] == '!trace' then
		NetEvents:SendToLocal('ClientNodeEditor:StartTrace', p_Player)

	elseif p_Parts[1] == '!tracedone' then
		NetEvents:SendToLocal('ClientNodeEditor:EndTrace', p_Player)


	elseif p_Parts[1] == '!cleartrace' then
		NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', p_Player)

	elseif p_Parts[1] == '!clearalltraces' then
		g_NodeCollection:Clear()
		NetEvents:SendLocal('NodeCollection:Clear')

	elseif p_Parts[1] == '!printtrans' then
		print('!printtrans')
		ChatManager:Yell('!printtrans check server console', 2.5)
		print(p_Player.soldier.worldTransform)
		print(p_Player.soldier.worldTransform.trans.x)
		print(p_Player.soldier.worldTransform.trans.y)
		print(p_Player.soldier.worldTransform.trans.z)

	elseif p_Parts[1] == '!tracesave' then
		local traceIndex = tonumber(p_Parts[2]) or 0
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', p_Player, traceIndex)
	end
end

-- Singleton.
if g_ChatCommands == nil then
	g_ChatCommands = ChatCommands()
end

return g_ChatCommands
