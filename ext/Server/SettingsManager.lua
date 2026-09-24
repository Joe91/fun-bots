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
---@type Language
local m_Language = require('__shared/Language')

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
		local s_Single = m_Database:Single('SELECT * FROM `FB_Config_Trace` WHERE `Key`=' .. m_Database:Quote(l_Name) .. ' LIMIT 1')

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
			local s_Single = m_Database:Single('SELECT * FROM `FB_Settings` WHERE `Key`=' .. m_Database:Quote(p_Name) .. ' LIMIT 1')

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

---Restores every setting to its default, persists the defaults and runs the resulting updates.
function SettingsManager:RestoreDefault()
	local s_Flags = {}

	for _, l_Item in pairs(SettingsDefinition.Elements) do
		if self:_HasChanged(Config[l_Item.Name], l_Item.Default) then
			s_Flags[l_Item.UpdateFlag] = true
		end

		self:Update(l_Item.Name, l_Item.Default, false, true)
	end

	m_Database:ExecuteBatch()
	self:_RunUpdateFlags(s_Flags)
end

---@param p_Name string
---@return table|nil
function SettingsManager:GetDefinition(p_Name)
	for _, l_Item in pairs(SettingsDefinition.Elements) do
		if l_Item.Name == p_Name then
			return l_Item
		end
	end

	return nil
end

---Converts a raw value from the WebUI, RCON or the console into the setting's type and validates it.
---@param p_Item table An element of SettingsDefinition.Elements.
---@param p_RawValue any
---@return boolean valid
---@return any value
function SettingsManager:ParseValue(p_Item, p_RawValue)
	local s_Type = p_Item.Type

	if s_Type == Type.Integer or s_Type == Type.Float then
		local s_Value = tonumber(p_RawValue)

		if s_Value == nil then
			return false, nil
		end

		if s_Type == Type.Integer then
			s_Value = math.floor(s_Value)
		end

		local s_Reference = p_Item.Reference
		---@cast s_Reference Range

		if not s_Reference:IsValid(s_Value) then
			return false, nil
		end

		return true, s_Value
	elseif s_Type == Type.Boolean then
		if p_RawValue == true or p_RawValue == 1 or p_RawValue == '1' or p_RawValue == 'true' then
			return true, true
		elseif p_RawValue == false or p_RawValue == 0 or p_RawValue == '0' or p_RawValue == 'false' then
			return true, false
		end

		return false, nil
	elseif s_Type == Type.Enum then
		-- Accept the name of the enum entry (case-insensitive) or its numeric value.
		local s_Number = tonumber(p_RawValue)
		local s_Name = type(p_RawValue) == 'string' and p_RawValue:lower() or nil

		for l_Key, l_Value in pairs(p_Item.Reference) do
			if l_Key ~= 'Count' and (l_Key:lower() == s_Name or l_Value == s_Number) then
				return true, l_Value
			end
		end

		return false, nil
	elseif s_Type == Type.List or s_Type == Type.DynamicList then
		local s_Reference = p_Item.Reference

		if s_Type == Type.DynamicList then
			s_Reference = _G[s_Reference]
		end

		for _, l_Value in pairs(s_Reference) do
			if l_Value == p_RawValue then
				return true, l_Value
			end
		end

		return false, nil
	end

	return false, nil
end

---Validates, converts and applies settings, then runs the side effects of their update flags once.
---This is the single entry point for the WebUI, RCON and the console.
---@param p_RawValues table<string, any> Raw values keyed by setting name. Unknown keys are ignored.
---@param p_Persist boolean Write the settings to the database.
---@return string[] # Names of the settings whose value was rejected.
function SettingsManager:Apply(p_RawValues, p_Persist)
	local s_Invalid = {}
	local s_Flags = {}

	for _, l_Item in pairs(SettingsDefinition.Elements) do
		local s_RawValue = p_RawValues[l_Item.Name]

		if s_RawValue ~= nil then
			local s_Valid, s_Value = self:ParseValue(l_Item, s_RawValue)

			if not s_Valid then
				s_Invalid[#s_Invalid + 1] = l_Item.Name
				-- Keep the current value. A persisted save rewrites the whole table, so it is still written.
				s_Value = Config[l_Item.Name]
			elseif self:_HasChanged(Config[l_Item.Name], s_Value) then
				s_Flags[l_Item.UpdateFlag] = true
			end

			self:Update(l_Item.Name, s_Value, not p_Persist, true)
		end
	end

	if p_Persist then
		m_Database:ExecuteBatch()
	end

	self:_RunUpdateFlags(s_Flags)

	return s_Invalid
end

---Sets a single setting at runtime (RCON and console). The change is not persisted.
---@param p_Name string
---@param p_Value any
---@return boolean
function SettingsManager:UpdateSetting(p_Name, p_Value)
	if self:GetDefinition(p_Name) == nil then
		return false
	end

	return #self:Apply({ [p_Name] = p_Value }, false) == 0
end

---@param p_Old any
---@param p_New any
---@return boolean
function SettingsManager:_HasChanged(p_Old, p_New)
	if type(p_Old) == 'number' and type(p_New) == 'number' then
		return math.abs(p_Old - p_New) > 0.001
	end

	return p_Old ~= p_New
end

---@param p_Flags table<UpdateFlag, boolean>
function SettingsManager:_RunUpdateFlags(p_Flags)
	if p_Flags[UpdateFlag.Language] then
		m_Language:loadLanguage(Config.Language)
		NetEvents:Broadcast('UI_Change_Language', Config.Language)
	end

	if p_Flags[UpdateFlag.WeaponSets] then
		m_WeaponList:UpdateWeaponList()
	end

	if p_Flags[UpdateFlag.YawPerSec] then
		Globals.YawPerFrame = m_BotManager:CalcYawPerFrame()
	end

	if p_Flags[UpdateFlag.MaxBots] then
		g_FunBotServer:SetMaxBotsPerTeam(Globals.GameMode)
	end

	if p_Flags[UpdateFlag.BotNames] then
		m_BotSpawner:UpdateBotNames()
	end

	NetEvents:BroadcastLocal('WriteClientSettings', Config, p_Flags[UpdateFlag.WeaponSets] == true)

	if p_Flags[UpdateFlag.AmountAndTeam] then
		Globals.SpawnMode = Config.SpawnMode
		m_BotSpawner:UpdateBotAmountAndTeam()
	end
end

if g_Settings == nil then
	---@type SettingsManager
	g_Settings = SettingsManager()
end

return g_Settings
