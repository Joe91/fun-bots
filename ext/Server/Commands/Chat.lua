---@class ChatCommands
---@overload fun():ChatCommands
ChatCommands = class('ChatCommands')

require('__shared/Config')
local m_NodeCollection = require('NodeCollection')

local m_BotManager = require('BotManager')
local m_BotSpawner = require('BotSpawner')
local m_Debug = require('Debug/BugReport')

local m_CarParts

function ChatCommands:Execute(p_Parts, p_Player)
	if p_Player == nil or Config.DisableChatCommands == true then
		return
	end

	if p_Parts[1] == '!permissions' then
		local s_Permissions = PermissionManager:GetPermissions(p_Player)

		if s_Permissions == nil then
			ChatManager:SendMessage('You have no active permissions (GUID: ' .. tostring(p_Player.guid) .. ').', p_Player)
		else
			ChatManager:SendMessage('You have following permissions (GUID: ' .. tostring(p_Player.guid) .. '):', p_Player)
			ChatManager:SendMessage(table.concat(s_Permissions, ', '), p_Player)
		end
	elseif p_Parts[1] == '!car' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		m_CarParts = {}

		if p_Player.attachedControllable ~= nil then
			local s_VehicleName = VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/", "")
			local s_Pos = p_Player.controlledControllable.transform.forward
			print(s_VehicleName)
			local s_VehicleEntity

			-- vehicle found
			print(p_Player.controlledControllable.physicsEntityBase.partCount)
			s_VehicleEntity = p_Player.controlledControllable.physicsEntityBase

			for j = 0, s_VehicleEntity.partCount - 1 do
				if p_Player.controlledControllable.physicsEntityBase:GetPart(j) ~= nil then --and p_Player.controlledControllable.physicsEntityBase:GetPart(j):Is("ServerChildComponent") then
					local s_QuatTransform = p_Player.controlledControllable.physicsEntityBase:GetPartTransform(j)

					if s_QuatTransform == nil then
						return -1
					end

					print(p_Player.controlledControllable.physicsEntityBase:GetPart(j).typeInfo.name)
					print("index: " .. j)
					local s_Direction = s_QuatTransform:ToLinearTransform().forward - s_Pos
					print(s_Direction)
					m_CarParts[j] = s_Direction
				end
			end
		end
	elseif p_Parts[1] == '!perks' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end
		print(g_Utilities:dump(p_Player.selectedUnlocks, true, 4))
	elseif p_Parts[1] == '!cardiff' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		if p_Player.attachedControllable ~= nil then
			local s_VehicleName = VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/", "")
			local s_Pos = p_Player.controlledControllable.transform.forward
			print(s_VehicleName)
			local s_VehicleEntity

			-- vehicle found
			print(p_Player.controlledControllable.physicsEntityBase.partCount)
			s_VehicleEntity = p_Player.controlledControllable.physicsEntityBase

			for j = 0, s_VehicleEntity.partCount - 1 do
				if p_Player.controlledControllable.physicsEntityBase:GetPart(j) ~= nil then --and p_Player.controlledControllable.physicsEntityBase:GetPart(j):Is("ServerChildComponent") then
					local s_QuatTransform = p_Player.controlledControllable.physicsEntityBase:GetPartTransform(j)

					if s_QuatTransform == nil then
						return -1
					end

					print(p_Player.controlledControllable.physicsEntityBase:GetPart(j).typeInfo.name)
					print("index: " .. j)
					local s_Direction = s_QuatTransform:ToLinearTransform().forward - s_Pos

					if m_CarParts[j] ~= nil then
						print(s_Direction - m_CarParts[j])
					end
				end
			end
		end
	elseif p_Parts[1] == '!row' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Row') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Row).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == nil then
			return
		end

		local s_Length = tonumber(p_Parts[2])
		local s_Spacing = tonumber(p_Parts[3]) or 2

		m_BotSpawner:SpawnBotRow(p_Player, s_Length, s_Spacing)
	elseif p_Parts[1] == '!tower' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Tower') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Tower).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == nil then
			return
		end

		local s_Height = tonumber(p_Parts[2])
		m_BotSpawner:SpawnBotTower(p_Player, s_Height)
	elseif p_Parts[1] == '!grid' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Grid') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Grid).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == nil then
			return
		end

		local s_Rows = tonumber(p_Parts[2])
		local s_Columns = tonumber(p_Parts[3]) or tonumber(p_Parts[2])
		local s_Spacing = tonumber(p_Parts[4]) or 2

		m_BotSpawner:SpawnBotGrid(p_Player, s_Rows, s_Columns, s_Spacing)
	-- static mode commands
	elseif p_Parts[1] == '!mimic' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Mimic') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Mimic).', p_Player)
			return
		end

		m_BotManager:SetStaticOption(p_Player, 'mode', BotMoveModes.Mimic)
	elseif p_Parts[1] == '!mirror' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Mirror') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Mirror).', p_Player)
			return
		end

		m_BotManager:SetStaticOption(p_Player, 'mode', BotMoveModes.Mirror)
	elseif p_Parts[1] == '!static' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Static') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Static).', p_Player)
			return
		end

		m_BotManager:SetStaticOption(p_Player, 'mode', BotMoveModes.Standstill)
	elseif p_Parts[1] == '!spawnway' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.SpawnWay') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SpawnWay).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == nil then
			return
		end

		local s_Amount = tonumber(p_Parts[2]) or 1
		local s_ActiveWayIndex = tonumber(p_Parts[3]) or 1
		s_ActiveWayIndex = math.min(math.max(s_ActiveWayIndex, 1), #m_NodeCollection:GetPaths())

		m_BotSpawner:SpawnWayBots(p_Player, s_Amount, false, s_ActiveWayIndex)
	elseif p_Parts[1] == '!spawnbots' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.SpawnBots') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SpawnBots).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == nil then
			return
		end

		local s_Amount = tonumber(p_Parts[2])

		m_BotSpawner:SpawnWayBots(p_Player, s_Amount, true)
	-- respawn moving bots
	elseif p_Parts[1] == '!respawn' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Respawn') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Respawn).', p_Player)
			return
		end

		local s_Respawning = true

		if tonumber(p_Parts[2]) == 0 then
			s_Respawning = false
		end

		Globals.RespawnWayBots = s_Respawning

		m_BotManager:SetOptionForAll('respawn', s_Respawning)
	elseif p_Parts[1] == '!shoot' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Shoot') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Shoot).', p_Player)
			return
		end

		local s_Shooting = true

		if tonumber(p_Parts[2]) == 0 then
			s_Shooting = false
		end

		Globals.AttackWayBots = s_Shooting

		m_BotManager:SetOptionForAll('shoot', s_Shooting)
	-- spawn team settings
	elseif p_Parts[1] == '!setbotkit' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.SetBotKit') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SetBotKit).', p_Player)
			return
		end

		local s_KitNumber = tonumber(p_Parts[2]) or 1

		if s_KitNumber <= 4 and s_KitNumber >= 0 then
			Config.BotKit = BotKits[s_KitNumber]
		end
	elseif p_Parts[1] == '!setbotcolor' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.SetBotColor') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SetBotColor).', p_Player)
			return
		end

		local s_BotColor = tonumber(p_Parts[2]) or 1

		if s_BotColor <= #BotColors and s_BotColor >= 0 then
			Config.BotColor = BotColors[s_BotColor]
		end
	elseif p_Parts[1] == '!setaim' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.SetAim') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.SetAim).', p_Player)
			return
		end

		Config.BotAimWorsening = tonumber(p_Parts[2]) or 0.5
	--self:_modifyWeapons(Config.BotAimWorsening) --causes lag. Instead restart round
	elseif p_Parts[1] == '!shootback' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.ShootBack') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.ShootBack).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == 0 then
			Config.ShootBackIfHit = false
		else
			Config.ShootBackIfHit = true
		end
	elseif p_Parts[1] == '!attackmelee' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.AttackMelee') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.AttackMelee).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == 0 then
			Config.MeleeAttackIfClose = false
		else
			Config.MeleeAttackIfClose = true
		end
	-- reset everything
	elseif p_Parts[1] == '!stopall' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.StopAll') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.StopAll).', p_Player)
			return
		end

		m_BotManager:SetOptionForAll('shoot', false)
		m_BotManager:SetOptionForAll('respawning', false)
		m_BotManager:SetOptionForAll('moveMode', 0)
	elseif p_Parts[1] == '!stop' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Stop') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Stop).', p_Player)
			return
		end

		m_BotManager:SetOptionForPlayer(p_Player, 'shoot', false)
		m_BotManager:SetOptionForPlayer(p_Player, 'respawning', false)
		m_BotManager:SetOptionForPlayer(p_Player, 'moveMode', 0)
	elseif p_Parts[1] == '!kickp_Player' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.KickPlayer') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KickPlayer).', p_Player)
			return
		end

		m_BotManager:DestroyPlayerBots(p_Player)
	elseif p_Parts[1] == '!kick' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Kick') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Kick).', p_Player)
			return
		end

		local s_Amount = tonumber(p_Parts[2]) or 1

		m_BotManager:DestroyAll(s_Amount)
	elseif p_Parts[1] == '!kickteam' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.KickTeam') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KickTeam).', p_Player)
			return
		end

		local s_TeamToKick = tonumber(p_Parts[2]) or 1

		if s_TeamToKick < 1 or s_TeamToKick > 2 then
			return
		end

		local s_TeamId = s_TeamToKick == 1 and TeamId.Team1 or TeamId.Team2

		m_BotManager:DestroyAll(nil, s_TeamId)
	elseif p_Parts[1] == '!kickall' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.KickAll') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KickAll).', p_Player)
			return
		end

		m_BotManager:DestroyAll()
	elseif p_Parts[1] == '!kill' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Kill') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Kill).', p_Player)
			return
		end

		m_BotManager:KillPlayerBots(p_Player)
	elseif p_Parts[1] == '!killall' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.KillAll') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.KillAll).', p_Player)
			return
		end

		m_BotManager:KillAll()
	-- waypoint stuff
	elseif p_Parts[1] == '!trace' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.Trace') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.Trace).', p_Player)
			return
		end

		NetEvents:SendToLocal('ClientNodeEditor:StartTrace', p_Player)
	elseif p_Parts[1] == '!tracedone' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.TraceDone') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.TraceDone).', p_Player)
			return
		end

		NetEvents:SendToLocal('ClientNodeEditor:EndTrace', p_Player)
	elseif p_Parts[1] == '!cleartrace' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.ClearTrace') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.ClearTrace).', p_Player)
			return
		end

		NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', p_Player)
	elseif p_Parts[1] == '!clearalltraces' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.ClearAllTraces') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.ClearAllTraces).', p_Player)
			return
		end

		m_NodeCollection:Clear()
		NetEvents:SendToLocal('NodeCollection:Clear', p_Player)
	elseif p_Parts[1] == '!printtrans' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.PrintTransform') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.PrintTransform).', p_Player)
			return
		end

		print('!printtrans')
		ChatManager:Yell('!printtrans check server console', 2.5)
		print(p_Player.soldier.worldTransform)
		print(p_Player.soldier.worldTransform.trans.x)
		print(p_Player.soldier.worldTransform.trans.y)
		print(p_Player.soldier.worldTransform.trans.z)
	elseif p_Parts[1] == '!tracesave' then
		if PermissionManager:HasPermission(p_Player, 'ChatCommands.TraceSave') == false then
			ChatManager:SendMessage('You have no permissions for this action (ChatCommands.TraceSave).', p_Player)
			return
		end

		local s_TraceIndex = tonumber(p_Parts[2]) or 0
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', p_Player, s_TraceIndex)

	-- Section: Debugging, Bug Reporting and error logging
	-- Command: !bugreport
	-- Permission: Debug.BugReport
	elseif p_Parts[1] == '!bugreport' then
		if PermissionManager:HasPermission(p_Player, 'Debug.BugReport') == false then
			ChatManager:SendMessage('You have no permissions for this action (Debug.BugReport).', p_Player)
			return
		end

		BugReport:GenerateReport(p_Player)
	else
		-- nothing to do
	end
end

if g_ChatCommands == nil then
	---@type ChatCommands
	g_ChatCommands = ChatCommands()
end

return g_ChatCommands
