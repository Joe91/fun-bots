---@class RCONCommands
---@overload fun():RCONCommands
RCONCommands = class('RCONCommands')

require('__shared/Config')

---@type BotManager
local m_BotManager = require('BotManager')
---@type BotSpawner
local m_BotSpawner = require('BotSpawner')
---@type SettingsManager
local m_SettingsManager = require('SettingsManager')

function RCONCommands:__init()
	if Config.DisableRCONCommands then
		return
	end

	self.m_Commands = {
		-- Save config.
		CONFIG_SAVE = {
			Name = 'funbots.saveall',
			Callback = (function(p_Command, p_Args)
				m_SettingsManager:SaveAll()

				return { 'OK' }
			end)
		},

		-- Save config.
		CONFIG_RESET = {
			Name = 'funbots.restore',
			Callback = (function(p_Command, p_Args)
				m_SettingsManager:RestoreDefault()

				return { 'OK' }
			end)
		},

		-- Clear/Reset Botnames.
		CLEAR_BOTNAMES = {
			Name = 'funbots.clear.BotNames',
			Callback = (function(p_Command, p_Args)
				BotNames = {}

				return { 'OK' }
			end)
		},

		-- Add BotName.
		ADD_BOTNAMES = {
			Name = 'funbots.add.BotNames',
			Parameters = { 'String' },
			Callback = (function(p_Command, p_Args)
				local s_Value = p_Args[1]

				if s_Value == nil then
					return { 'ERROR', 'Needing <String>.' }
				end

				table.insert(BotNames, s_Value)

				return { 'OK' }
			end)
		},

		-- Replace BotName.
		REPLACE_BOTNAMES = {
			Name = 'funbots.replace.BotNames',
			Parameters = { 'JSONArray' },
			Callback = (function(p_Command, p_Args)
				local s_Value = p_Args[1]

				if s_Value == nil then
					return { 'ERROR', 'Needing <JSONArray>.' }
				end

				local s_Result = json.decode(s_Value)

				if s_Result == nil then
					return { 'ERROR', 'Needing <JSONArray>.' }
				end

				BotNames = s_Result

				return { 'OK' }
			end)
		},

		-- Kick All.
		KICKALLL = {
			Name = 'funbots.kickAll',
			Callback = (function(p_Command, p_Args)
				Globals.SpawnMode = "manual"
				m_BotManager:DestroyAll()

				return { 'OK' }
			end)
		},

		-- Kick Bot.
		KICKBOT = {
			Name = 'funbots.kickBot',
			Parameters = { 'Name' },
			Callback = (function(p_Command, p_Args)
				local s_Name = p_Args[1]

				if s_Name == nil then
					return { 'ERROR', 'Name needed.' }
				end

				m_BotManager:DestroyBot(s_Name)

				return { 'OK' }
			end)
		},

		-- Kill All.
		KILLALL = {
			Name = 'funbots.killAll',
			Callback = (function(p_Command, p_Args)
				Globals.SpawnMode = "manual"
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
					return { 'ERROR', 'Needing Spawn amount.' }
				end

				if s_Team == nil then
					return { 'ERROR', 'Needing Team.' }
				end

				if tonumber(s_Value) == nil then
					return { 'ERROR', 'Needing Spawn amount.' }
				end

				local s_Amount = tonumber(s_Value)

				if TeamId[s_Team] == nil then
					return { 'ERROR', 'Unknown Team: TeamId.' .. s_Team }
				end

				m_BotSpawner:SpawnWayBots(s_Amount, true, nil, nil, TeamId[s_Team])

				return { 'OK' }
			end)
		},

		-- Permissions <Player> <PermissionName>
		PERMISSIONS = {
			Name = 'funbots.Permissions',
			Parameters = { 'PlayerName', 'PermissionName' },
			Callback = (function(command, args)
				local s_Name = args[1]
				local s_Permission = args[2]

				-- Revoke ALL Permissions.
				if s_Permission ~= nil then
					if s_Permission == '!' then
						local s_Permissions = PermissionManager:GetPermissions(s_Name)
						local s_Result = { 'OK', 'REVOKED' }

						if s_Permissions ~= nil and #s_Permissions >= 1 then
							for l_Key, l_Value in pairs(s_Permissions) do
								table.insert(s_Result, PermissionManager:GetCorrectName(l_Value))
							end
						end

						if PermissionManager:RevokeAll(s_Name) then
							return s_Result
						else
							return { 'ERROR', 'Can\'r revoke all Permissions from "' .. s_Name .. '".' }
						end
						-- Revoke SPECIFIC Permission.
					elseif s_Permission:sub(1, 1) == '!' then
						s_Permission = s_Permission:sub(2)

						if PermissionManager:Exists(s_Permission) == false then
							return { 'ERROR', 'Unknown Permission:', s_Permission }
						end

						if PermissionManager:Revoke(s_Name, s_Permission) then
							return { 'OK', 'REVOKED' }
						else
							return { 'ERROR',
								'Can\'r revoke the Permission "' .. PermissionManager:GetCorrectName(s_Permission) .. '" for "' .. s_Name .. '".' }
						end
					end
				end

				if s_Name == nil then
					local s_All = PermissionManager:GetAll()

					if s_All ~= nil and #s_All >= 1 then
						local s_Result = { 'OK', 'LIST' }

						for l_Key, l_Value in pairs(s_All) do
							table.insert(s_Result, PermissionManager:GetCorrectName(l_Value))
						end

						return s_Result
					end

					return { 'ERROR', 'PlayerName needed.' }
				end

				-- local s_Player = PlayerManager:GetPlayerByName(s_Name)

				-- if s_Player == nil then
				-- 	s_Player = PlayerManager:GetPlayerByGuid(Guid(s_Name))

				-- 	if s_Player == nil then
				-- 		return {'ERROR', 'Unknown PlayerName "' .. s_Name .. '".'}
				-- 	end
				-- end

				if s_Permission == nil then
					local s_Result = { 'LIST', s_Name }
					local s_Permissions = PermissionManager:GetPermissions(s_Name)

					if s_Permissions ~= nil then
						for l_Name, l_Value in pairs(s_Permissions) do
							table.insert(s_Result, PermissionManager:GetCorrectName(l_Value))
						end
					end

					return s_Result
				end

				if PermissionManager:Exists(s_Permission) == false then
					return { 'ERROR', 'Unknown Permission:', s_Permission }
				end

				PermissionManager:AddPermission(s_Name, s_Permission)

				return { 'OK' }
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
		RCON:RegisterCommand('funbots.config.' .. key, RemoteCommandFlag.RequiresLogin,
			function(p_Command, p_Args, p_LoggedIn)
				local s_values = p_Command:split(".")
				local s_VarName = s_values[#s_values]

				if p_Args == nil or #p_Args == 0 then
					-- Get var.
					return { 'OK', 'value of var ' .. s_VarName .. ' is ' .. tostring(Config[s_VarName]) }
				elseif #p_Args == 1 and p_Args[1] ~= nil then
					-- Set var.
					local s_Result = m_SettingsManager:UpdateSetting(s_VarName, p_Args[1])

					if s_Result then
						return { 'OK' }
					else
						return { 'ERROR', 'Not valid' }
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
	---@type RCONCommands
	g_RCONCommands = RCONCommands()
end

return g_RCONCommands
