---@class SettingsManager
---@overload fun():SettingsManager
SettingsManager = class('SettingsManager')

require('__shared/Config')

---@type Database
local m_Database = require('Database')
---@type BotManager
local m_BotManager = require('BotManager')
---@type BotSpawner
local m_BotSpawner = require('BotSpawner')
---@type WeaponList
local m_WeaponList = require('__shared/WeaponList')

function SettingsManager:__init()
	-- Create Config-Trace.
	m_Database:CreateTable('FB_Config_Trace', {
		DatabaseField.PrimaryText,
		DatabaseField.Text,
		DatabaseField.Time
	}, {
		'Key',
		'Value',
		'Time'
	}, {
		'PRIMARY KEY("Key")'
	})

	-- Create Settings.
	m_Database:CreateTable('FB_Settings', {
		DatabaseField.PrimaryText,
		DatabaseField.Text,
		DatabaseField.Time
	}, {
		'Key',
		'Value',
		'Time'
	}, {
		'PRIMARY KEY("Key")'
	})

	-- m_Database:Query('CREATE UNIQUE INDEX USKey ON FB_Settings(Key)')
end

---VEXT Shared Extension:Loaded Event
function SettingsManager:OnExtensionLoaded()
	-- Fix nil values on config.
	if Config.Language == nil then
		Config.Language = DatabaseField.NULL
	end

	-- Get Values from Config.lua
	for l_Name, l_Value in pairs(Config) do
		-- Check SQL if Config.lua has changed.
		local s_Single = m_Database:Single('SELECT * FROM `FB_Config_Trace` WHERE `Key`=\'' .. l_Name .. '\' LIMIT 1')

		-- If it doesn't exist, create it.
		if s_Single == nil then
			-- if Debug.Server.SETTINGS then
			-- print('SettingsManager: ADD (' .. l_Name .. ' = ' .. tostring(l_Value) .. ')')
			-- end

			m_Database:Insert('FB_Config_Trace', {
				Key = l_Name,
				Value = l_Value,
				Time = m_Database:Now()
			})

			-- m_Database:Insert('FB_Settings', {
			-- Key = l_Name,
			-- Value = DatabaseField.NULL,
			-- Time = DatabaseField.NULL
			-- })

			-- If it exists update Settings, if newer.
		else
			local s_Old = s_Single.Value

			if s_Old == nil then
				s_Old = DatabaseField.NULL
			end

			-- To-do: check Time / Timestamp, if newer.
			if tostring(l_Value) == tostring(s_Old) then
				-- if Debug.Server.SETTINGS then
				-- print('SettingsManager: SKIP (' .. l_Name .. ' = ' .. tostring(l_Value) .. ', NOT MODIFIED)')
				-- end
			else
				-- if Debug.Server.SETTINGS then
				-- print('SettingsManager: UPDATE (' .. l_Name .. ' = ' .. tostring(l_Value) .. ', Old = ' .. tostring(s_Old) .. ')')
				-- end

				-- If changed, update SETTINGS SQL
				m_Database:Update('FB_Config_Trace', {
					Key = l_Name,
					Value = l_Value,
					Time = m_Database:Now()
				}, 'Key')
			end
		end
	end

	if Debug.Server.SETTINGS then
		print('Start migrating of Settings/Config...')
	end

	-- Load Settings.
	local s_Settings = m_Database:Fetch([[SELECT
											`Settings`.`Key`,
											CASE WHEN
												`Config`.`Key` IS NULL
											THEN
												`Settings`.`Value`
											ELSE
												`Config`.`Value`
											END `Value`,
											COALESCE(`Config`.`Time`, `Settings`.`Time`) `Time`
										FROM
											`FB_Settings` `Settings`
										LEFT JOIN
											`FB_Config_Trace` `Config`
										ON
											`Config`.`Key` = `Settings`.`Key`
										AND
											`Config`.`Time` > `Settings`.`Time`]])

	if s_Settings ~= nil then
		for l_Name, l_Value in pairs(s_Settings) do
			-- if Debug.Server.SETTINGS then
			-- print('Updating Config Variable: ' .. tostring(l_Value.Key) .. ' = ' .. tostring(l_Value.Value) .. ' (' .. tostring(l_Value.Time) .. ')')
			-- end
			local s_TempValue = tonumber(l_Value.Value)

			if s_TempValue then -- Number?
				Config[l_Value.Key] = s_TempValue
			else       -- String.
				if l_Value.Value == 'true' then
					Config[l_Value.Key] = true
				elseif l_Value.Value == 'false' then
					Config[l_Value.Key] = false
				else
					Config[l_Value.Key] = l_Value.Value
				end
			end
		end
	end
	-- Revert Fix nil values on config.
	if Config.Language == DatabaseField.NULL then
		Config.Language = nil
	end
end

---comment
---@param p_Name string
---@param p_Value any
---@param p_Temporary boolean
---@param p_Batch boolean
function SettingsManager:Update(p_Name, p_Value, p_Temporary, p_Batch)
	if p_Temporary ~= true then
		if p_Value == nil then
			p_Value = DatabaseField.NULL
		end

		-- Use old deprecated queries.
		if p_Batch == false then
			local s_Single = m_Database:Single('SELECT * FROM `FB_Settings` WHERE `Key`=\'' .. p_Name .. '\' LIMIT 1')

			-- If it doesn't exist, create it.
			if s_Single == nil then
				m_Database:Insert('FB_Settings', {
					Key = p_Name,
					Value = p_Value,
					Time = m_Database:Now()
				})
			else
				m_Database:Update('FB_Settings', {
					Key = p_Name,
					Value = p_Value,
					Time = m_Database:Now()
				}, 'Key')
			end

			-- Use new queries.
		else
			m_Database:BatchQuery('FB_Settings', {
				Key = p_Name,
				Value = p_Value,
				Time = m_Database:Now()
			}, 'Key')
		end

		if p_Value == DatabaseField.NULL then
			p_Value = nil
		end
	end

	Config[p_Name] = p_Value
end

function SettingsManager:SaveAll()
	for l_Key, l_Value in pairs(Config) do
		self:Update(l_Key, l_Value, false, true)
	end

	m_Database:ExecuteBatch()
end

function SettingsManager:RestoreDefault()
	for _, l_Item in pairs(SettingsDefinition.Elements) do
		Config[l_Item.Name] = l_Item.Default
	end
end

---comment
---@param p_Name string
---@param p_Value any
---@return boolean
function SettingsManager:UpdateSetting(p_Name, p_Value)
	local s_Valid = false
	local s_UpdateClientWeapons = false
	local s_UpdateFlag = UpdateFlag.None
	local s_ConvertedValue = nil

	for _, l_Item in pairs(SettingsDefinition.Elements) do
		if l_Item.Name == p_Name then
			if l_Item.Type == Type.Integer or l_Item.Type == Type.Float then
				s_ConvertedValue = tonumber(p_Value)
				---@type Range
				local s_Reference = l_Item.Reference

				-- Check for Range.
				if s_Reference:GetMax() >= s_ConvertedValue and s_Reference:GetMin() <= s_ConvertedValue then
					s_Valid = true
				end
			elseif l_Item.Type == Type.Boolean then
				s_ConvertedValue = (p_Value == '1' or p_Value == "true")
				s_Valid = true
			elseif l_Item.Type == Type.Enum then
				s_ConvertedValue = tonumber(p_Value)

				if s_ConvertedValue == nil and type(p_Value) == 'string' then -- Check for enum-string.
					if type(p_Value) == 'string' then
						for l_Key, l_Value in pairs(l_Item.Reference) do
							if string.find(p_Value, l_Key) ~= nil then
								s_ConvertedValue = l_Value
								s_Valid = true
								break
							end
						end
					end
				else
					for l_Key, l_Value in pairs(l_Item.Reference) do
						if s_ConvertedValue == l_Value then
							s_Valid = true
							break
						end
					end
				end
			elseif l_Item.Type == Type.List then
				if type(p_Value) == 'string' then
					for l_Key, l_Value in pairs(l_Item.Reference) do
						if string.find(p_Value, l_Key) ~= nil then
							s_ConvertedValue = l_Value
							s_Valid = true
							break
						end
					end
				end
			elseif l_Item.Type == Type.DynamicList then
				if type(p_Value) == 'string' then
					local s_Reference = _G[l_Item.Reference]

					for l_Key, l_Value in pairs(s_Reference) do
						if string.find(p_Value, l_Key) ~= nil then
							s_ConvertedValue = l_Value
							s_Valid = true
							break
						end
					end
				end
			end

			s_UpdateFlag = l_Item.UpdateFlag
			break
		end
	end

	if s_Valid then
		self:Update(p_Name, s_ConvertedValue, true, false)

		if s_UpdateFlag == UpdateFlag.WeaponSets then
			m_WeaponList:UpdateWeaponList()
			s_UpdateClientWeapons = true
		elseif s_UpdateFlag == UpdateFlag.YawPerSec then
			Globals.YawPerFrame = m_BotManager:CalcYawPerFrame()
		elseif s_UpdateFlag == UpdateFlag.AmountAndTeam then
			Globals.SpawnMode = Config.SpawnMode
			m_BotSpawner:UpdateBotAmountAndTeam()
		elseif s_UpdateFlag == UpdateFlag.BotNames then
			m_BotSpawner:UpdateBotNames()
		elseif s_UpdateFlag == UpdateFlag.Skill then
			m_BotManager:ResetSkills()
		end

		NetEvents:BroadcastLocal('WriteClientSettings', Config, s_UpdateClientWeapons)
		return true
	else
		return false
	end
end

if g_Settings == nil then
	---@type SettingsManager
	g_Settings = SettingsManager()
end

return g_Settings
