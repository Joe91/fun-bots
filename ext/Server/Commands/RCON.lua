class('RCONCommands')

require('__shared/Config')

local m_BotManager = require('BotManager')
local m_BotSpawner = require('BotSpawner')
local m_SettingsManager = require('SettingsManager')

function RCONCommands:__init()
	if Config.DisableRCONCommands then
		return
	end

	self.m_Commands = {
		-- save config
		CONFIG_SAVE = {
			Name = 'funbots.saveall',
			Callback = (function(p_Command, p_Args)
				m_SettingsManager:SaveAll()

				return { 'OK' }
			end)
		},

		-- save config
		CONFIG_RESET = {
			Name = 'funbots.restore',
			Callback = (function(p_Command, p_Args)
				m_SettingsManager:RestoreDefault()

				return { 'OK' }
			end)
		},

		-- Get Config
		GET_CONFIG = {
			Name = 'funbots.get.config',
			Callback = (function(p_Command, p_Args)
				if Debug.Server.RCON then
					print('[RCON] call funbots.config')
					print(json.encode(p_Args))
				end

				return {
					'OK',
					json.encode({
						USE_REAL_DAMAGE = USE_REAL_DAMAGE,
						Config = Config,
						StaticConfig = StaticConfig
					})
				}
			end)
		},

		-- Set Config
		SET_CONFIG = {
			Name = 'funbots.set.config',
			Parameters = { 'Name', 'Value' },
			Callback = (function(p_Command, p_Args)
				if Debug.Server.RCON then
					print('[RCON] call funbots.set.config')
					print(json.encode(p_Args))
				end

				local s_Old = {
					Name = nil,
					Value = nil
				}

				local s_New = {
					Name = nil,
					Value = nil
				}

				local s_Name = p_Args[1]
				local s_Value = p_Args[2]

				if s_Name == nil then
					return {'ERROR', 'Needing <Name>.'}
				end

				if s_Value == nil then
					return {'ERROR', 'Needing <Value>.'}
				end

				-- Constants
				if s_Name == 'USE_REAL_DAMAGE' then
					local s_New_Value = false

					if s_Value == true or s_Value == '1' or s_Value == 'true' or s_Value == 'True' or s_Value == 'TRUE' then
						s_New_Value = true
					end

					s_Old.Name = s_Name
					s_Old.Value = USE_REAL_DAMAGE
					USE_REAL_DAMAGE = s_New_Value
					s_New.Name = s_Name
					s_New.Value = USE_REAL_DAMAGE
				else
					-- Config
					if Config[s_Name] ~= nil then
						local s_Test = tostring(Config[s_Name])
						local s_Type = 'nil'

						-- Boolean
						if (s_Test == 'true' or s_Test == 'false') then
							s_Type = 'boolean'

						-- String
						elseif (s_Test == Config[s_Name]) then
							s_Type = 'string'

						-- Number
						elseif (tonumber(s_Test) == Config[s_Name]) then
							s_Type = 'number'
						end

						s_Old.Name = 'Config.' .. s_Name
						s_Old.Value = Config[s_Name]

						if s_Type == 'boolean' then
							local s_New_Value = false

							if s_Value == true or s_Value == '1' or s_Value == 'true' or s_Value == 'True' or s_Value == 'TRUE' then
								s_New_Value = true
							end

							Config[s_Name] = s_New_Value
							s_New.Name = 'Config.' .. s_Name
							s_New.Value = Config[s_Name]
						elseif s_Type == 'string' then
							Config[s_Name] = tostring(s_Value)
							s_New.Name = 'Config.' .. s_Name
							s_New.Value = Config[s_Name]
						elseif s_Type == 'number' then
							Config[s_Name] = tonumber(s_Value)
							s_New.Name = 'Config.' .. s_Name
							s_New.Value = Config[s_Name]
						else
							print('Unknown Config property-Type: ' .. s_Name .. ' -> ' .. s_Type)
						end
					elseif StaticConfig[s_Name] ~= nil then
						local s_Test = tostring(StaticConfig[s_Name])
						local s_Type = 'nil'

						s_Old.Name = 'StaticConfig.' .. s_Name
						s_Old.Value = StaticConfig[s_Name]

						-- Boolean
						if (s_Test == 'true' or s_Test == 'false') then
							s_Type = 'boolean'

						-- String
						elseif (s_Test == StaticConfig[s_Name]) then
							s_Type = 'string'

						-- Number
						elseif (tonumber(s_Test) == StaticConfig[s_Name]) then
							s_Type = 'number'
						end

						if s_Type == 'boolean' then
							local s_New_Value = false

							if s_Value == true or s_Value == '1' or s_Value == 'true' or s_Value == 'True' or s_Value == 'TRUE' then
								s_New_Value = true
							end

							StaticConfig[s_Name] = s_New_Value
							s_New.Name = 'StaticConfig.' .. s_Name
							s_New.Value = StaticConfig[s_Name]
						elseif s_Type == 'string' then
							StaticConfig[s_Name] = tostring(s_Value)
							s_New.Name = 'StaticConfig.' .. s_Name
							s_New.Value = StaticConfig[s_Name]
						elseif s_Type == 'number' then
							StaticConfig[s_Name] = tonumber(s_Value)
							s_New.Name = 'StaticConfig.' .. s_Name
							s_New.Value = StaticConfig[s_Name]
						else
							print('Unknown Config property-Type: ' .. s_Name .. ' -> ' .. s_Type)
						end
					else
						print('Unknown Config property: ' .. s_Name)
					end
				end

				-- Update some things
				local s_UpdateBotTeamAndNumber = false
				local s_UpdateWeaponSets = false
				local s_UpdateWeapons = false
				local s_CalcYawPerFrame = false

				if s_Name == 'botAimWorsening' then
					s_UpdateWeapons = true
				end

				if s_Name == 'botSniperAimWorsening' then
					s_UpdateWeapons = true
				end

				if s_Name == 'spawnMode' then
					s_UpdateBotTeamAndNumber = true
				end

				if s_Name == 'spawnInBothTeams' then
					s_UpdateBotTeamAndNumber = true
				end

				if s_Name == 'initNumberOfBots' then
					s_UpdateBotTeamAndNumber = true
				end

				if s_Name == 'newBotsPerNewPlayer' then
					s_UpdateBotTeamAndNumber = true
				end

				if s_Name == 'keepOneSlotForPlayers' then
					s_UpdateBotTeamAndNumber = true
				end

				if s_Name == 'assaultWeaponSet' then
					s_UpdateWeaponSets = true
				end

				if s_Name == 'engineerWeaponSet' then
					s_UpdateWeaponSets = true
				end

				if s_Name == 'supportWeaponSet' then
					s_UpdateWeaponSets = true
				end

				if s_Name == 'reconWeaponSet' then
					s_UpdateWeaponSets = true
				end

				if s_UpdateWeapons then
					if Debug.Server.RCON then
						print('[RCON] call WeaponModification:ModifyAllWeapons()')
					end

					WeaponModification:ModifyAllWeapons(Config.BotAimWorsening, Config.BotSniperAimWorsening)
				end

				NetEvents:BroadcastLocal('WriteClientSettings', Config, s_UpdateWeaponSets)

				if s_UpdateWeaponSets then
					if Debug.Server.RCON then
						print('[RCON] call WeaponList:updateWeaponList()')
					end

					WeaponList:updateWeaponList()
				end

				if s_CalcYawPerFrame then
					if Debug.Server.RCON then
						print('[RCON] call m_BotManager:CalcYawPerFrame()')
					end

					Globals.YawPerFrame = m_BotManager:CalcYawPerFrame()
				end

				if s_UpdateBotTeamAndNumber then
					if Debug.Server.RCON then
						print('[RCON] call m_BotSpawner:UpdateBotAmountAndTeam()')
					end

					Globals.SpawnMode = Config.SpawnMode
					m_BotSpawner:UpdateBotAmountAndTeam()
				end

				if Debug.Server.RCON then
					print('[RCON] Config Result')
					print('[RCON] ' .. s_Old.Name .. ' = ' .. tostring(s_Old.Value))
					print('[RCON] ' .. s_New.Name .. ' = ' .. tostring(s_New.Value))
				end

				return { 'OK', s_Old.Name .. ' = ' .. tostring(s_Old.Value), s_New.Name .. ' = ' .. tostring(s_New.Value) }
			end)
		},

		-- Clear/Reset Botnames
		CLEAR_BOTNAMES = {
			Name = 'funbots.clear.BotNames',
			Callback = (function(p_Command, p_Args)
				BotNames = {}

				return { 'OK' }
			end)
		},

		-- Add BotName
		ADD_BOTNAMES = {
			Name = 'funbots.add.BotNames',
			Parameters = { 'String' },
			Callback = (function(p_Command, p_Args)
				local s_Value = p_Args[1]

				if s_Value == nil then
					return {'ERROR', 'Needing <String>.'}
				end

				table.insert(BotNames, s_Value)

				return { 'OK' }
			end)
		},

		-- Replace BotName
		REPLACE_BOTNAMES = {
			Name = 'funbots.replace.BotNames',
			Parameters = { 'JSONArray' },
			Callback = (function(p_Command, p_Args)
				local s_Value = p_Args[1]

				if s_Value == nil then
					return {'ERROR', 'Needing <JSONArray>.'}
				end

				local s_Result = json.decode(s_Value)

				if s_Result == nil then
					return {'ERROR', 'Needing <JSONArray>.'}
				end

				BotNames = s_Result

				return { 'OK' }
			end)
		},

		-- Kick All
		KICKALLL = {
			Name = 'funbots.kickAll',
			Callback = (function(p_Command, p_Args)
				m_BotManager:DestroyAll()

				return { 'OK' }
			end)
		},

		-- Kick Bot
		KICKBOT = {
			Name = 'funbots.kickBot',
			Parameters = { 'Name' },
			Callback = (function(p_Command, p_Args)
				local s_Name = p_Args[1]

				if s_Name == nil then
					return {'ERROR', 'Name needed.'}
				end

				m_BotManager:DestroyBot(s_Name)

				return { 'OK' }
			end)
		},

		-- Kill All
		KILLALL = {
			Name = 'funbots.killAll',
			Callback = (function(p_Command, p_Args)
				m_BotManager:KillAll()

				return { 'OK' }
			end)
		},

		-- Spawn <Amount> <Team>
		SPAWN = {
			Name = 'funbots.spawn',
			Parameters = { 'Amount', 'Team' },
			Callback = (function(p_Command, p_Args)
				local s_Value = p_Args[1]
				local s_Team = p_Args[2]

				if s_Value == nil then
					return {'ERROR', 'Needing Spawn amount.'}
				end

				if s_Team == nil then
					return {'ERROR', 'Needing Team.'}
				end

				if tonumber(s_Value) == nil then
					return {'ERROR', 'Needing Spawn amount.'}
				end

				local s_Amount = tonumber(s_Value)

				if TeamId[s_Team] == nil then
					return {'ERROR', 'Unknown Team: TeamId.' .. s_Team }
				end

				m_BotSpawner:SpawnWayBots(nil, s_Amount, true, nil, nil, TeamId[s_Team])

				return {'OK'}
			end)
		},

		-- Permissions <Player> <PermissionName>
		PERMISSIONS = {
			Name = 'funbots.Permissions',
			Parameters = { 'PlayerName', 'PermissionName' },
			Callback = (function(command, args)
				local s_Name = args[1]
				local s_Permission = args[2]

				-- Revoke ALL Permissions
				if s_Permission ~= nil then
					if s_Permission == '!' then
						local s_Permissions = PermissionManager:GetPermissions(s_Name)
						local s_Result = {'OK', 'REVOKED'}

						if s_Permissions ~= nil and #s_Permissions >= 1 then
							for l_Key, l_Value in pairs(s_Permissions) do
								table.insert(s_Result, PermissionManager:GetCorrectName(l_Value))
							end
						end

						if PermissionManager:RevokeAll(s_Name) then
							return s_Result
						else
							return {'ERROR', 'Can\'r revoke all Permissions from "' .. s_Name .. '".'}
						end
					-- Revoke SPECIFIC Permission
					elseif s_Permission:sub(1, 1) == '!' then
						s_Permission = s_Permission:sub(2)

						if PermissionManager:Exists(s_Permission) == false then
							return {'ERROR', 'Unknown Permission:', s_Permission}
						end

						if PermissionManager:Revoke(s_Name, s_Permission) then
							return {'OK', 'REVOKED'}
						else
							return {'ERROR', 'Can\'r revoke the Permission "' .. PermissionManager:GetCorrectName(s_Permission) .. '" for "' .. s_Name .. '".'}
						end
					end
				end

				if s_Name == nil then
					local s_All = PermissionManager:GetAll()

					if s_All ~= nil and #s_All >= 1 then
						local s_Result = {'OK', 'LIST'}

						for l_Key, l_Value in pairs(s_All) do
							table.insert(s_Result, PermissionManager:GetCorrectName(l_Value))
						end

						return s_Result
					end

					return {'ERROR', 'Needing PlayerName.'}
				end

				local s_Player = PlayerManager:GetPlayerByName(s_Name)

				if s_Player == nil then
					s_Player = PlayerManager:GetPlayerByGuid(Guid(s_Name))

					if s_Player == nil then
						return {'ERROR', 'Unknown PlayerName "' .. s_Name .. '".'}
					end
				end

				if s_Permission == nil then
					local s_Result = { 'LIST', s_Player.name, tostring(s_Player.guid) }
					local s_Permissions = PermissionManager:GetPermissions(s_Name)

					if s_Permissions ~= nil then
						for l_Name, l_Value in pairs(s_Permissions) do
							table.insert(s_Result, PermissionManager:GetCorrectName(l_Value))
						end
					end

					return s_Result
				end

				if PermissionManager:Exists(s_Permission) == false then
					return {'ERROR', 'Unknown Permission:', s_Permission}
				end

				PermissionManager:AddPermission(s_Player.name, s_Permission)

				return {'OK'}
			end)
		}
	}

	self:_CreateCommand('funbots', (function(p_Command, p_Args)
		local s_Result = {}

		table.insert(s_Result, 'OK')

		for l_Index, l_Command in pairs(self.m_Commands) do
			local s_Command = l_Command.Name

			if l_Command.Parameters ~= nil then
				for _, parameter in pairs(l_Command.Parameters) do
					s_Command = s_Command .. ' <' .. parameter .. '>'
				end
			end

			table.insert(s_Result, s_Command)
		end

		return s_Result
	end))

	self:_Create()
end

function RCONCommands:CreateConfigCommands()
	for key, value in pairs(Config) do
		RCON:RegisterCommand('funbots.config.'..key, RemoteCommandFlag.RequiresLogin, function(p_Command, p_Args, p_LoggedIn)
			local s_values = p_Command:split(".")
			local s_VarName = s_values[#s_values]

			if p_Args == nil or #p_Args == 0 then
				-- get var
				return {'OK', 'value of var '.. s_VarName .. ' is '..tostring(Config[s_VarName])}
			elseif #p_Args == 1 and  p_Args[1] ~= nil then
				-- set var
				local s_Result = m_SettingsManager:UpdateSetting(s_VarName, p_Args[1])
				if s_Result then
					return {'OK'}
				else
					return {'ERROR', 'Not valid'}
				end
			end
		end)
	end
end

function RCONCommands:_Create()
	self:CreateConfigCommands()
	for l_Index, l_Command in pairs(self.m_Commands) do
		self:_CreateCommand(l_Command.Name, l_Command.Callback)
	end
end

function RCONCommands:_CreateCommand(p_Name, p_Callback)
	RCON:RegisterCommand(p_Name, RemoteCommandFlag.RequiresLogin, function(p_Command, p_Args, p_LoggedIn)
		return p_Callback(p_Command, p_Args)
	end)
end

if g_RCONCommands == nil then
	g_RCONCommands = RCONCommands()
end

return g_RCONCommands
