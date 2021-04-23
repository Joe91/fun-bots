class('SettingsManager')

require('__shared/ArrayMap')
require('__shared/Config')
require('Database')

function SettingsManager:__init()
	-- Create Config-Trace
	Database:createTable('FB_Config_Trace', {
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

	-- Create Settings
	Database:createTable('FB_Settings', {
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

	--Database:query('CREATE UNIQUE INDEX USKey ON FB_Settings(Key)')
end

function SettingsManager:onLoad()
	-- Fix nil values on config
	if Config.Language == nil then
		Config.Language = DatabaseField.NULL
	end

	if Config.SettingsPassword == nil then
		Config.SettingsPassword = DatabaseField.NULL
	end

	-- get Values from Config.lua
	for name, value in pairs(Config) do
		-- Check SQL if Config.lua has changed
		local single = Database:single('SELECT * FROM `FB_Config_Trace` WHERE `Key`=\'' .. name .. '\' LIMIT 1')

		-- If not exists, create
		if single == nil then
			--if Debug.Server.SETTINGS then
			--print('SettingsManager: ADD (' .. name .. ' = ' .. tostring(value) .. ')')
			--end

			Database:insert('FB_Config_Trace', {
				Key		= name,
				Value	= value,
				Time	= Database:now()
			})

			--Database:insert('FB_Settings', {
			--	Key		= name,
			--	Value	= DatabaseField.NULL,
			--	Time	= DatabaseField.NULL
			--})

		-- If exists update Settings, if newer
		else
			local old = single.Value

			if old == nil then
				old = DatabaseField.NULL
			end

			-- @ToDo check Time / Timestamp, if newer
			if tostring(value) == tostring(old) then
				--if Debug.Server.SETTINGS then
				--print('SettingsManager: SKIP (' .. name .. ' = ' .. tostring(value) .. ', NOT MODIFIED)')
				--end
			else
				--if Debug.Server.SETTINGS then
				--print('SettingsManager: UPDATE (' .. name .. ' = ' .. tostring(value) .. ', Old = ' .. tostring(old) .. ')')
				--end

				-- if changed, update SETTINGS SQL
				Database:update('FB_Config_Trace', {
					Key		= name,
					Value	= value,
					Time	= Database:now()
				}, 'Key')
			end
		end
	end

	if Debug.Server.SETTINGS then
		print('Start migrating of Settings/Config...')
	end

	-- Load Settings
	local settings = Database:fetch([[SELECT
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

	if settings ~= nil then
		for name, value in pairs(settings) do
			--if Debug.Server.SETTINGS then
			--print('Updating Config Variable: ' .. tostring(value.Key) .. ' = ' .. tostring(value.Value) .. ' (' .. tostring(value.Time) .. ')')
			--end
			local tempValue = tonumber(value.Value)
			if tempValue then --number?
				Config[value.Key] = tempValue
			else --string
				if value.Value == 'true' then
					Config[value.Key] = true
				elseif value.Value == 'false' then
					Config[value.Key] = false
				else
					Config[value.Key] = value.Value
				end
			end
		end
	end

	-- revert Fix nil values on config
	if Config.Language == DatabaseField.NULL then
		Config.Language = nil
	end

	if Config.SettingsPassword == DatabaseField.NULL then
		Config.SettingsPassword = nil
	end
end

function SettingsManager:update(p_Name, p_Value, p_Temporary, p_Batch)
	if p_Temporary ~= true then
		if p_Value == nil then
			p_Value = DatabaseField.NULL
		end

		-- Use old deprecated querys
		if p_Batch == false then
			local single = Database:single('SELECT * FROM `FB_Settings` WHERE `Key`=\'' .. p_Name .. '\' LIMIT 1')

			-- If not exists, create
			if single == nil then
				Database:insert('FB_Settings', {
					Key		= p_Name,
					Value	= p_Value,
					Time	= Database:now()
				})
			else
				Database:update('FB_Settings', {
					Key		= p_Name,
					Value	= p_Value,
					Time	= Database:now()
				}, 'Key')
			end

		-- Use new querys
		else
			Database:batchQuery('FB_Settings', {
				Key		= p_Name,
				Value	= p_Value,
				Time	= Database:now()
			}, 'Key')
		end

		if p_Value == DatabaseField.NULL then
			p_Value = nil
		end
	end

	Config[p_Name] = p_Value
end

-- Singleton.
if g_Settings == nil then
	g_Settings = SettingsManager()
end

return g_Settings
