class('Database')

require('__shared/ArrayMap')
local batches	= ArrayMap()
local batched	= ''

DatabaseField = {
	NULL		= '{::DB:NULL::}',
	ID			= '{::DB:ID::}',
	Text		= '{::DB:TEXT::}',
	Time		= '{::DB:TIME::}',
	Integer		= '{::DB:INTEGER::}',
	Float		= '{::DB:FLOAT::}',
	Boolean		= '{::DB:BOOLEAN::}',
	PrimaryText	= '{::DB:TEXT:PRIMARY::}',
}

function Database:__init()
	self.lastError	= nil
end

function Database:getLastError()
	return self.lastError
end

function Database:now()
	return 'CURRENT_TIMESTAMP'
end

function Database:getError()
	return SQL:Error()
end

function Database:query(p_Query, p_Parameters)
	SQL:Open()
	-- @ToDo build p_Query with given p_Parameters
	local result = SQL:Query(p_Query)

	if not result then
		self.lastError = 'Failed to execute query: ' .. self:getError()
		SQL:Close()
		return nil
	end

	SQL:Close()

	return result
end

function Database:createTable(p_TableName, p_Definitions, p_Names, p_Additional)
	local entries		= ArrayMap()
	local additionals	= ArrayMap()

	for index, value in ipairs(p_Definitions) do
		local name = p_Names[index]

		if value == DatabaseField.Text then
			entries:add(name .. ' TEXT')

		elseif value == DatabaseField.PrimaryText then
			entries:add(name .. ' TEXT UNIQUE')

		elseif value == DatabaseField.Integer then
			entries:add(name .. ' INTEGER')

		elseif value == DatabaseField.Float then
			entries:add(name .. ' FLOAT')

		elseif value == DatabaseField.Time then
			entries:add(name .. ' DATETIME')

		end
	end

	if p_Additional ~= nil then
		for index, value in pairs(p_Additional) do
			entries:add(value)
			additionals:add(value)
		end
	end

	return self:query('CREATE TABLE IF NOT EXISTS ' .. p_TableName .. ' (' .. entries:join(', ') .. ')')
end

function Database:single(p_Query)
	local results = self:query(p_Query)

	if results == nil then
		return nil
	end

	return results[1]
end

function Database:count(p_Query, p_Parameters)
	local results = self:query(p_Query, p_Parameters)

	return #results
end

function Database:fetch(p_Query)
	return self:query(p_Query)
end

function Database:update(p_TableName, p_Parameters, p_Where)
	local fields	= ArrayMap()
	local found		= nil

	for name, value in pairs(p_Parameters) do
		if value == nil then
			value = 'NULL'

		elseif value == self:now() then
			value = 'CURRENT_TIMESTAMP'

		elseif value == DatabaseField.NULL then
			value = 'NULL'

		elseif tostring(value) == 'true' or value == true then
			value = '\'true\''

		elseif tostring(value) == 'false' or value == false then
			value = '\'false\''

		else
			value = '\'' .. tostring(value) .. '\''
		end

		if p_Where == name then
			found = value
		end

		fields:add(' `' .. name .. '`=' .. value .. '')
	end

	if Debug.Server.DATABASE then
		print('UPDATE `' .. p_TableName .. '` SET ' .. fields:join(',') .. ' WHERE `' .. p_Where .. '`=' .. found)
	end

	return self:query('UPDATE `' .. p_TableName .. '` SET ' .. fields:join(', ') .. ' WHERE `' .. p_Where .. '`=\'' .. found .. '\'')
end

function Database:executeBatch()
	self:query('DELETE FROM `FB_Settings`')
	self:query(batched .. batches:join(', '))
	print(self:getError())
end

function Database:batchQuery(p_TableName, p_Parameters, p_Where)
	local names		= ArrayMap()
	local values	= ArrayMap()
	local fields	= ArrayMap()
	local found		= nil

	for name, value in pairs(p_Parameters) do
		names:add('`' .. name .. '`')

		if value == nil then
			values:add('NULL')
			value = 'NULL'

		elseif value == self:now() then
			values:add('CURRENT_TIMESTAMP')
			value = 'CURRENT_TIMESTAMP'

		elseif value == DatabaseField.NULL then
			values:add('NULL')
			value = 'NULL'

		elseif tostring(value) == 'true' or value == true then
			values:add('\'true\'')
			value = '\'true\''

		elseif tostring(value) == 'false' or value == false then
			values:add('\'false\'')
			value = '\'false\''

		else
			values:add('\'' .. tostring(value) .. '\'')
			value = tostring(value)
		end

		if p_Where == name then
			found = value
		end

		if p_Where ~= name then
			fields:add('`' .. name .. '`=' .. value .. '')
		end
	end

	--batches:add('UPDATE `' .. p_TableName .. '` SET ' .. fields:join(', ') .. ' WHERE `' .. p_Where .. '`=\'' .. found .. '\'')
	--batches:add('INSERT OR REPLACE INTO ' .. p_TableName .. ' (' .. names:join(', ') .. ') VALUES (' .. values:join(', ') .. ')')
	batched = 'INSERT INTO ' .. p_TableName .. ' (' .. names:join(', ') .. ') VALUES '
	batches:add('(' .. values:join(', ') .. ')')

	return true
end

function Database:delete(p_TableName, p_Parameters)
	local where		= ArrayMap()

	for name, value in pairs(p_Parameters) do
		where:add('`' .. name .. '`=\'' ..value .. '\'')
	end

	return self:query('DELETE FROM ' .. p_TableName .. ' WHERE ' .. where:join(' AND '))
end

function Database:insert(p_TableName, p_Parameters)
	local names		= ArrayMap()
	local values	= ArrayMap()

	for name, value in pairs(p_Parameters) do
		names:add('`' .. name .. '`')

		if value == nil then
			values:add('NULL')

		elseif value == self:now() then
			values:add('CURRENT_TIMESTAMP')

		elseif value == DatabaseField.NULL then
			values:add('NULL')

		elseif tostring(value) == 'true' or value == true then
			values:add('\'true\'')

		elseif tostring(value) == 'false' or value == false then
			values:add('\'false\'')

		else
			values:add('\'' .. tostring(value) .. '\'')
		end
	end

	self:query('INSERT INTO ' .. p_TableName .. ' (' .. names:join(', ') .. ') VALUES (' .. values:join(', ') .. ')')

	return SQL:LastInsertId()
end

-- Singleton.
if g_Database == nil then
	g_Database = Database()
end

return g_Database
