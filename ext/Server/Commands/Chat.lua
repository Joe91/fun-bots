---@class ChatCommands
---@overload fun():ChatCommands
ChatCommands = class('ChatCommands')

require('__shared/Config')
require('__shared/Utilities')
local m_NodeCollection = require('NodeCollection')

local m_BotManager = require('BotManager')
local m_BotSpawner = require('BotSpawner')

local m_CarParts

-- The debug-server runs chat-commands as this pseudo-player when no real player is chosen: it has all
-- permissions, no soldier, and its answers only go back to the debug-server.
ChatCommands.CONSOLE = { name = '<debug-server>', id = -1 }

-- Lines collected by ExecuteCaptured (chat-answers and prints), nil otherwise.
local s_Output = nil

---@param p_Message string
---@param p_Player Player|table
local function _SendMessage(p_Message, p_Player)
	if s_Output ~= nil then
		s_Output[#s_Output + 1] = p_Message
	end

	if p_Player ~= ChatCommands.CONSOLE then
		ChatManager:SendMessage(p_Message, p_Player)
	end
end

---@param p_Player Player|table
---@param p_Permission string
---@return boolean
local function _HasPermission(p_Player, p_Permission)
	return p_Player == ChatCommands.CONSOLE or PermissionManager:HasPermission(p_Player, p_Permission)
end

-- Some commands use the caller's soldier; tell the caller instead of raising an error when they are dead.
---@param p_Player Player
---@return boolean
local function _IsAlive(p_Player)
	if p_Player.soldier == nil then
		_SendMessage('You need to be alive for this command.', p_Player)
		return false
	end

	return true
end

function ChatCommands:Execute(p_Parts, p_Player)
	if p_Player == nil or Config.DisableChatCommands == true then
		return
	end

	if p_Parts[1] == '!permissions' then
		local s_Permissions = PermissionManager:GetPermissions(p_Player)

		if s_Permissions == nil then
			_SendMessage('You have no active permissions (GUID: ' .. tostring(p_Player.guid) .. ').', p_Player)
		else
			_SendMessage('You have following permissions (GUID: ' .. tostring(p_Player.guid) .. '):', p_Player)
			_SendMessage(table.concat(s_Permissions, ', '), p_Player)
		end
	elseif p_Parts[1] == '!weap' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.KickAll).', p_Player)
			return
		end

		if not _IsAlive(p_Player) then
			return
		end

		-- testing with extracting of weapon-information for gunmaster
		local s_weapon = SoldierWeapon(p_Player.soldier.weaponsComponent.currentWeapon)
		print(s_weapon.name)
		print(p_Player.soldier.weaponsComponent.currentWeaponSlot)
		for i = 1, 15, 1 do
			if p_Player.soldier.weaponsComponent.weapons[i] then
				print(i)
				print(p_Player.soldier.weaponsComponent.weapons[i].name)
			end
		end
		local s_name = s_weapon.name
		local s_unlock_path_parts = s_name:split('/')
		local s_name_of_weapon = s_unlock_path_parts[#s_unlock_path_parts]
		s_unlock_path_parts[#s_unlock_path_parts] = "U_" .. s_unlock_path_parts[#s_unlock_path_parts]
		local s_unlock_path = ""
		for i = 1, #s_unlock_path_parts do
			s_unlock_path = s_unlock_path .. s_unlock_path_parts[i]
			if i < #s_unlock_path_parts then
				s_unlock_path = s_unlock_path .. "/"
			end
		end
		print(s_unlock_path)
		local s_WeaponInfo = Weapon(s_name_of_weapon, '', {}, WeaponTypes.None, s_unlock_path)
		s_WeaponInfo:learnStatsValues()
		print(s_WeaponInfo.bulletDrop)
		print(s_WeaponInfo.bulletSpeed)
		print(s_WeaponInfo.damage)
	elseif p_Parts[1] == '!car' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		m_CarParts = {}

		if p_Player.attachedControllable ~= nil then
			local s_VehicleName = VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/", "")
			local s_Pos = p_Player.controlledControllable.transform.forward:Clone()
			local s_PlayerPos = p_Player.soldier.worldTransform.trans:Clone()
			print("-----------------------------")
			print(s_VehicleName)
			local s_VehicleEntity
			print(s_PlayerPos)

			-- Vehicle found.
			print(p_Player.controlledControllable.physicsEntityBase.partCount)
			s_VehicleEntity = p_Player.controlledControllable.physicsEntityBase

			if Registry.DEBUG.VEHICLE_PROJECTILE_TRACE and Globals.LastProjectile ~= nil then
				print("Offset of vehicle to bullet:")
				local s_Diff = Globals.LastProjectile.trans:Clone() - p_Player.controlledControllable.transform.trans:Clone()

				local s_Left = Globals.LastProjectile.left:Clone()
				local s_FactLeft = s_Diff:Dot(s_Left) / s_Left:Dot(s_Left)
				print("x: " .. string.format("%.3f", s_FactLeft))

				local s_Up = Globals.LastProjectile.up:Clone()
				local s_FactUp = s_Diff:Dot(s_Up) / s_Up:Dot(s_Up)
				print("y: " .. string.format("%.3f", s_FactUp))

				local s_Forward = Globals.LastProjectile.forward:Clone()
				local s_FactForward = s_Diff:Dot(s_Forward) / s_Forward:Dot(s_Forward)
				print("z: " .. string.format("%.3f", s_FactForward))

				local s_DistToHit = (((s_Diff):Cross(Globals.LastProjectile.forward)).magnitude) / Globals.LastProjectile.forward.magnitude
				print("Distance: " .. string.format("%.3f", s_DistToHit))
				print("-----")
			end

			for j = 0, s_VehicleEntity.partCount - 1 do
				if p_Player.controlledControllable.physicsEntityBase:GetPart(j) ~= nil then -- And p_Player.controlledControllable.physicsEntityBase:GetPart(j):Is("ServerChildComponent") then
					local s_QuatTransform = p_Player.controlledControllable.physicsEntityBase:GetPartTransform(j)

					if s_QuatTransform == nil then
						return -1
					end

					-- print(p_Player.controlledControllable.physicsEntityBase:GetPart(j).typeInfo.name)

					local s_Direction = s_QuatTransform:ToLinearTransform().forward - s_Pos
					local s_Position = s_QuatTransform:ToLinearTransform().trans:Clone()
					if Registry.DEBUG.VEHICLE_PROJECTILE_TRACE and Globals.LastProjectile ~= nil then
						local s_DiffDir = s_QuatTransform:ToLinearTransform().forward:Clone() - Globals.LastProjectile.forward

						if s_DiffDir.magnitude < 0.05 then
							print("index: " .. j)
							print(s_Direction)
							print(s_DiffDir)
							print("Offset to bullet:")
							local s_Diff = Globals.LastProjectile.trans - s_Position

							local s_Left = Globals.LastProjectile.left
							local s_FactLeft = s_Diff:Dot(s_Left) / s_Left:Dot(s_Left)
							print("x: " .. string.format("%.3f", s_FactLeft))

							local s_Up = Globals.LastProjectile.up
							local s_FactUp = s_Diff:Dot(s_Up) / s_Up:Dot(s_Up)
							print("y: " .. string.format("%.3f", s_FactUp))

							local s_Forward = Globals.LastProjectile.forward
							local s_FactForward = s_Diff:Dot(s_Forward) / s_Forward:Dot(s_Forward)
							print("z: " .. string.format("%.3f", s_FactForward))

							-- only for validatiaon
							-- local s_NewEnd = s_Position + (s_Forward * s_FactForward) + (s_Left * s_FactLeft) + (s_Up * s_FactUp)
							-- print(s_NewEnd - Globals.LastProjectile.trans)

							local s_DistToHit = (((s_Diff):Cross(Globals.LastProjectile.forward)).magnitude) / Globals.LastProjectile.forward.magnitude
							print("Distance: " .. string.format("%.3f", s_DistToHit))
						end
					else
						print("index: " .. j)
						print(s_Direction)
					end

					m_CarParts[j] = s_QuatTransform.rotation:ToEuler()
				end
			end
		end
	elseif p_Parts[1] == '!caryaw' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		m_CarParts = {}

		if p_Player.attachedControllable ~= nil then
			local s_VehicleName = VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/", "")
			local s_PlayerPos = p_Player.soldier.worldTransform.trans:Clone()
			print("-----------------------------")
			print(s_VehicleName)
			local s_VehicleEntity
			print(s_PlayerPos)

			-- Vehicle found.
			print(p_Player.controlledControllable.physicsEntityBase.partCount)
			s_VehicleEntity = p_Player.controlledControllable.physicsEntityBase

			print("Offset of vehicle to bullet:")
			for j = 0, s_VehicleEntity.partCount - 1 do
				if j == 1 then                                                   --j == 1 or j == 3
					if p_Player.controlledControllable.physicsEntityBase:GetPart(j) ~= nil then -- And p_Player.controlledControllable.physicsEntityBase:GetPart(j):Is("ServerChildComponent") then
						local s_QuatTransform = p_Player.controlledControllable.physicsEntityBase:GetPartTransform(j)
						if s_QuatTransform == nil then
							return -1
						end

						print("index: " .. j)

						local s_Euler = s_QuatTransform.rotation:ToEuler()
						s_Euler.x = s_Euler.x
						s_Euler.y = s_Euler.y - 0.5 -- roll equals pitch
						s_Euler.z = s_Euler.z

						local s_Quat = Quat(s_Euler)
						s_QuatTransform.rotation = s_Quat



						local s_DirOld = s_QuatTransform:ToLinearTransform().forward:Clone() + p_Player.controlledControllable.transform.left:Clone()
						local s_DirrBullet = (Globals.LastProjectile.trans - s_QuatTransform:ToLinearTransform().trans):Normalize()

						local s_AtanDzDx = math.atan(s_DirOld.z, s_DirOld.x)
						local s_Yaw1 = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
						local s_Pitch1 = math.asin(s_DirOld.y / 1.0)

						s_AtanDzDx = math.atan(s_DirrBullet.z, s_DirrBullet.x)
						local s_Yaw2 = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
						local s_Pitch2 = math.asin(s_DirrBullet.y / 1.0)


						local s_Yaw4 = s_QuatTransform.rotation:ToEuler().x
						local s_Roll4 = s_QuatTransform.rotation:ToEuler().y
						local s_Pitch4 = s_QuatTransform.rotation:ToEuler().z
						print("euler:")
						print(-s_Yaw4 + math.pi + math.pi / 2) --- 0.344
						print(s_Roll4)
						print(s_Pitch4)      --+ 0.6499
						print("old:")
						print(s_Yaw1)
						print(s_Pitch1)
						print("bullet:")
						print(s_Yaw2)
						print(s_Pitch2)
						print("---")

						print(s_Yaw1 + s_Yaw4)
						print(s_Pitch1 + s_Pitch4)
					end
				end
			end
		end
	elseif p_Parts[1] == '!dbg' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		local s_Index = tonumber(p_Parts[2]) or 1
		if s_Index > 10 then
			s_Index = 1
		end
		local s_Value = tonumber(p_Parts[3]) or 0.0

		Debug.Vars[s_Index] = s_Value
	elseif p_Parts[1] == '!aimeval' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		local s_AimEvaluation = require('AimEvaluation')
		local s_Mode = p_Parts[2] or (s_AimEvaluation:IsEnabled() and 'off' or 'on')
		if s_Mode == 'on' then
			s_AimEvaluation:SetEnabled(true)
			_SendMessage('AimEval on. Report in the server-console every ' ..
				Registry.DEBUG.AIM_EVALUATION_REPORT_INTERVAL .. ' s or with "!aimeval report".', p_Player)
		elseif s_Mode == 'off' then
			s_AimEvaluation:SetEnabled(false)
			_SendMessage('AimEval off.', p_Player)
		elseif s_Mode == 'report' then
			s_AimEvaluation:PrintReport(p_Player ~= ChatCommands.CONSOLE and p_Player or nil)
		elseif s_Mode == 'reset' then
			s_AimEvaluation:Reset()
			_SendMessage('AimEval statistics cleared.', p_Player)
		elseif s_Mode == 'verbose' then
			s_AimEvaluation:SetVerbose(p_Parts[3] ~= 'off')
			_SendMessage('AimEval per-shot output ' .. (p_Parts[3] ~= 'off' and 'on' or 'off') .. '.', p_Player)
		else
			_SendMessage('Usage: !aimeval [on|off|report|reset|verbose [off]]', p_Player)
		end
	elseif p_Parts[1] == '!serverraycasts' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		local s_ServerRaycasts = require('ServerRaycasts')
		local s_Mode = p_Parts[2] or (s_ServerRaycasts:IsEnabled() and 'off' or 'on')
		if s_Mode == 'on' or s_Mode == 'off' then
			s_ServerRaycasts:SetEnabled(s_Mode == 'on')
			_SendMessage('Server-raycasts ' .. s_Mode .. '.', p_Player)
		else
			_SendMessage('Usage: !serverraycasts [on|off]', p_Player)
		end
	elseif p_Parts[1] == '!debugbridge' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		local s_DebugBridge = require('Debug/DebugBridge')
		local s_Mode = p_Parts[2] or (s_DebugBridge:IsEnabled() and 'off' or 'on')
		if s_Mode == 'on' or s_Mode == 'off' then
			s_DebugBridge:SetEnabled(s_Mode == 'on')
		elseif s_Mode ~= 'status' then
			_SendMessage('Usage: !debugbridge [on|off|status]', p_Player)
			return
		end
		_SendMessage('DebugBridge ' .. (s_DebugBridge:IsEnabled() and 'on' or 'off') .. ', ' ..
			(s_DebugBridge:IsConnected() and 'connected to ' or 'not connected to ') .. s_DebugBridge:GetUrl(), p_Player)
	elseif p_Parts[1] == '!perks' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end
		print(g_Utilities:dump(p_Player.selectedUnlocks, true, 4))
	elseif p_Parts[1] == '!objectives' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end
		for l_Index = 1, #m_BotManager:GetBots() do
			local l_Bot = m_BotManager:GetBots()[l_Index]
			print("Objecitve: " .. l_Bot._Objective .. " - " .. l_Bot._ObjectiveMode .. " of Bot" .. l_Bot.m_Player.name)
		end
		print(g_Utilities:dump(p_Player.selectedUnlocks, true, 4))
	elseif p_Parts[1] == '!cardiff' then
		if _HasPermission(p_Player, 'ChatCommands') == false then
			_SendMessage('You have no permissions for this action (ChatCommands).', p_Player)
			return
		end

		if p_Player.attachedControllable ~= nil then
			local s_VehicleName = VehicleEntityData(p_Player.controlledControllable.data).controllableType:gsub(".+/.+/", "")
			print(s_VehicleName)
			local s_VehicleEntity

			-- Vehicle found.
			print(p_Player.controlledControllable.physicsEntityBase.partCount)
			s_VehicleEntity = p_Player.controlledControllable.physicsEntityBase

			for j = 0, s_VehicleEntity.partCount - 1 do
				if p_Player.controlledControllable.physicsEntityBase:GetPart(j) ~= nil then -- And p_Player.controlledControllable.physicsEntityBase:GetPart(j):Is("ServerChildComponent") then
					local s_QuatTransform = p_Player.controlledControllable.physicsEntityBase:GetPartTransform(j)

					if s_QuatTransform == nil then
						return -1
					end

					print(p_Player.controlledControllable.physicsEntityBase:GetPart(j).typeInfo.name)
					print("index: " .. j)
					local s_Direction = s_QuatTransform.rotation:ToEuler()

					if m_CarParts[j] ~= nil then
						print(s_Direction - m_CarParts[j])
					end
				end
			end
		end
	elseif p_Parts[1] == '!row' then
		if _HasPermission(p_Player, 'ChatCommands.Row') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Row).', p_Player)
			return
		end

		if not _IsAlive(p_Player) then
			return
		end

		local s_Length = tonumber(p_Parts[2])

		if s_Length == nil then
			return
		end

		local s_Spacing = tonumber(p_Parts[3]) or 2

		m_BotSpawner:SpawnBotRow(p_Player, s_Length, s_Spacing)
	elseif p_Parts[1] == '!tower' then
		if _HasPermission(p_Player, 'ChatCommands.Tower') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Tower).', p_Player)
			return
		end

		if not _IsAlive(p_Player) then
			return
		end

		local s_Height = tonumber(p_Parts[2])

		if s_Height == nil then
			return
		end

		m_BotSpawner:SpawnBotTower(p_Player, s_Height)
	elseif p_Parts[1] == '!grid' then
		if _HasPermission(p_Player, 'ChatCommands.Grid') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Grid).', p_Player)
			return
		end

		if not _IsAlive(p_Player) then
			return
		end

		local s_Rows = tonumber(p_Parts[2])

		if s_Rows == nil then
			return
		end

		local s_Columns = tonumber(p_Parts[3]) or s_Rows
		local s_Spacing = tonumber(p_Parts[4]) or 2

		m_BotSpawner:SpawnBotGrid(p_Player, s_Rows, s_Columns, s_Spacing)
		-- Static mode commands.
	elseif p_Parts[1] == '!mimic' then
		if _HasPermission(p_Player, 'ChatCommands.Mimic') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Mimic).', p_Player)
			return
		end

		m_BotManager:SetStaticOption(p_Player, 'mode', BotMoveModes.Mimic)
	elseif p_Parts[1] == '!mirror' then
		if _HasPermission(p_Player, 'ChatCommands.Mirror') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Mirror).', p_Player)
			return
		end

		m_BotManager:SetStaticOption(p_Player, 'mode', BotMoveModes.Mirror)
	elseif p_Parts[1] == '!static' then
		if _HasPermission(p_Player, 'ChatCommands.Static') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Static).', p_Player)
			return
		end

		m_BotManager:SetStaticOption(p_Player, 'mode', BotMoveModes.Standstill)
	elseif p_Parts[1] == '!spawnway' then
		if _HasPermission(p_Player, 'ChatCommands.SpawnWay') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.SpawnWay).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == nil then
			return
		end

		local s_Amount = tonumber(p_Parts[2]) or 1
		local s_ActiveWayIndex = tonumber(p_Parts[3]) or 1
		s_ActiveWayIndex = math.min(math.max(s_ActiveWayIndex, 1), m_NodeCollection:GetNrOfPaths())

		m_BotSpawner:SpawnWayBots(s_Amount, false, s_ActiveWayIndex)
	elseif p_Parts[1] == '!spawnbots' then
		if _HasPermission(p_Player, 'ChatCommands.SpawnBots') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.SpawnBots).', p_Player)
			return
		end

		local s_Amount = tonumber(p_Parts[2])

		if s_Amount == nil then
			return
		end

		m_BotSpawner:SpawnWayBots(s_Amount, true)
		-- Respawn moving bots.
	elseif p_Parts[1] == '!respawn' then
		if _HasPermission(p_Player, 'ChatCommands.Respawn') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Respawn).', p_Player)
			return
		end

		local s_Respawning = true

		if tonumber(p_Parts[2]) == 0 then
			s_Respawning = false
		end

		Globals.RespawnWayBots = s_Respawning

		m_BotManager:SetOptionForAll('respawn', s_Respawning)
	elseif p_Parts[1] == '!shoot' then
		if _HasPermission(p_Player, 'ChatCommands.Shoot') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Shoot).', p_Player)
			return
		end

		local s_Shooting = true

		if tonumber(p_Parts[2]) == 0 then
			s_Shooting = false
		end

		Globals.AttackWayBots = s_Shooting

		m_BotManager:SetOptionForAll('shoot', s_Shooting)
		-- Spawn team settings.
	elseif p_Parts[1] == '!setbotkit' then
		if _HasPermission(p_Player, 'ChatCommands.SetBotKit') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.SetBotKit).', p_Player)
			return
		end

		local s_KitNumber = tonumber(p_Parts[2]) or 1

		if s_KitNumber < BotKits.Count and s_KitNumber >= 0 then
			Config.BotKit = s_KitNumber
		end
	elseif p_Parts[1] == '!setbotcolor' then
		if _HasPermission(p_Player, 'ChatCommands.SetBotColor') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.SetBotColor).', p_Player)
			return
		end

		local s_BotColor = tonumber(p_Parts[2]) or 1

		if s_BotColor < BotColors.Count and s_BotColor >= 0 then
			Config.BotColor = s_BotColor
		end
	elseif p_Parts[1] == '!setaim' then
		if _HasPermission(p_Player, 'ChatCommands.SetAim') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.SetAim).', p_Player)
			return
		end

		Config.BotAimWorsening = tonumber(p_Parts[2]) or 0.5
		-- Takes effect after a round restart (reloading the weapons right away causes lag).
	elseif p_Parts[1] == '!shootback' then
		if _HasPermission(p_Player, 'ChatCommands.ShootBack') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.ShootBack).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == 0 then
			Config.ShootBackIfHit = false
		else
			Config.ShootBackIfHit = true
		end
	elseif p_Parts[1] == '!attackmelee' then
		if _HasPermission(p_Player, 'ChatCommands.AttackMelee') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.AttackMelee).', p_Player)
			return
		end

		if tonumber(p_Parts[2]) == 0 then
			Config.MeleeAttackIfClose = false
		else
			Config.MeleeAttackIfClose = true
		end
		-- Reset everything.
	elseif p_Parts[1] == '!stopall' then
		if _HasPermission(p_Player, 'ChatCommands.StopAll') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.StopAll).', p_Player)
			return
		end

		m_BotManager:SetOptionForAll('shoot', false)
		m_BotManager:SetOptionForAll('respawn', false)
		m_BotManager:SetOptionForAll('moveMode', 0)
	elseif p_Parts[1] == '!stop' then
		if _HasPermission(p_Player, 'ChatCommands.Stop') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Stop).', p_Player)
			return
		end

		m_BotManager:SetOptionForPlayer(p_Player, 'shoot', false)
		m_BotManager:SetOptionForPlayer(p_Player, 'respawn', false)
		m_BotManager:SetOptionForPlayer(p_Player, 'moveMode', 0)
	elseif p_Parts[1] == '!kickplayer' then
		if _HasPermission(p_Player, 'ChatCommands.KickPlayer') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.KickPlayer).', p_Player)
			return
		end

		m_BotManager:DestroyPlayerBots(p_Player)
	elseif p_Parts[1] == '!kick' then
		if _HasPermission(p_Player, 'ChatCommands.Kick') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Kick).', p_Player)
			return
		end

		local s_Amount = tonumber(p_Parts[2]) or 1

		m_BotManager:DestroyAll(s_Amount)
	elseif p_Parts[1] == '!kickteam' then
		if _HasPermission(p_Player, 'ChatCommands.KickTeam') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.KickTeam).', p_Player)
			return
		end

		local s_TeamToKick = tonumber(p_Parts[2]) or 1

		if s_TeamToKick < 1 or s_TeamToKick > 2 then
			return
		end

		local s_TeamId = s_TeamToKick == 1 and TeamId.Team1 or TeamId.Team2

		m_BotManager:DestroyAll(nil, s_TeamId)
	elseif p_Parts[1] == '!kickall' then
		if _HasPermission(p_Player, 'ChatCommands.KickAll') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.KickAll).', p_Player)
			return
		end

		m_BotManager:DestroyAll()
	elseif p_Parts[1] == '!kill' then
		if _HasPermission(p_Player, 'ChatCommands.Kill') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Kill).', p_Player)
			return
		end

		m_BotManager:KillPlayerBots(p_Player)
	elseif p_Parts[1] == '!killall' then
		if _HasPermission(p_Player, 'ChatCommands.KillAll') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.KillAll).', p_Player)
			return
		end

		m_BotManager:KillAll()
		-- Waypoint stuff.
	elseif p_Parts[1] == '!trace' then
		if _HasPermission(p_Player, 'ChatCommands.Trace') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.Trace).', p_Player)
			return
		end

		NetEvents:SendToLocal('ClientNodeEditor:StartTrace', p_Player)
	elseif p_Parts[1] == '!tracedone' then
		if _HasPermission(p_Player, 'ChatCommands.TraceDone') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.TraceDone).', p_Player)
			return
		end

		NetEvents:SendToLocal('ClientNodeEditor:EndTrace', p_Player)
	elseif p_Parts[1] == '!cleartrace' then
		if _HasPermission(p_Player, 'ChatCommands.ClearTrace') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.ClearTrace).', p_Player)
			return
		end

		NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', p_Player)
	elseif p_Parts[1] == '!clearalltraces' then
		if _HasPermission(p_Player, 'ChatCommands.ClearAllTraces') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.ClearAllTraces).', p_Player)
			return
		end

		m_NodeCollection:Clear()
		NetEvents:SendToLocal('NodeCollection:Clear', p_Player)
	elseif p_Parts[1] == '!printtrans' then
		if _HasPermission(p_Player, 'ChatCommands.PrintTransform') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.PrintTransform).', p_Player)
			return
		end

		if not _IsAlive(p_Player) then
			return
		end

		print('!printtrans')
		ChatManager:Yell('!printtrans check server console', 2.5)
		print(p_Player.soldier.worldTransform)
		print(p_Player.soldier.worldTransform.trans.x)
		print(p_Player.soldier.worldTransform.trans.y)
		print(p_Player.soldier.worldTransform.trans.z)
	elseif p_Parts[1] == '!tracesave' then
		if _HasPermission(p_Player, 'ChatCommands.TraceSave') == false then
			_SendMessage('You have no permissions for this action (ChatCommands.TraceSave).', p_Player)
			return
		end

		local s_TraceIndex = tonumber(p_Parts[2]) or 0
		NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', p_Player, s_TraceIndex)
	else
		-- Nothing to do.
	end
end

---Runs a chat-command for the debug-server and returns what it answered: the chat-messages and everything it
---printed. Commands that need a soldier or a client don't work as ChatCommands.CONSOLE.
---@param p_Message string e.g. "!spawnbots 5"
---@param p_Player? Player nil = ChatCommands.CONSOLE
---@return string[]
function ChatCommands:ExecuteCaptured(p_Message, p_Player)
	if Config.DisableChatCommands == true then
		error('chat-commands are disabled (Config.DisableChatCommands)')
	end

	local s_Print = print
	s_Output = {}
	print = function(...)
		local s_Parts = {}
		for l_Index = 1, select('#', ...) do
			s_Parts[l_Index] = tostring((select(l_Index, ...)))
		end
		s_Output[#s_Output + 1] = table.concat(s_Parts, ' ')
		s_Print(...)
	end

	local s_Ok, s_Error = pcall(self.Execute, self, string.lower(p_Message):split(' '), p_Player or ChatCommands.CONSOLE)
	print = s_Print
	local s_Lines = s_Output
	s_Output = nil

	if not s_Ok then
		s_Lines[#s_Lines + 1] = tostring(s_Error)
		error(table.concat(s_Lines, '\n'), 0)
	end

	return s_Lines
end

if g_ChatCommands == nil then
	---@type ChatCommands
	g_ChatCommands = ChatCommands()
end

return g_ChatCommands
