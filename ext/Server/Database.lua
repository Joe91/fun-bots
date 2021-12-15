---@class Database
Database = class('Database')

require('__shared/ArrayMap')
local m_Batches = ArrayMap()
local m_Batched = ''
local m_Logger = Logger("Database", Debug.Server.DATABASE)

DatabaseField = {
	NULL = '{::DB:NULL::}',
	ID = '{::DB:ID::}',
	Text = '{::DB:TEXT::}',
	Time = '{::DB:TIME::}',
	Integer = '{::DB:INTEGER::}',
	Float = '{::DB:FLOAT::}',
	Boolean = '{::DB:BOOLEAN::}',
	PrimaryText = '{::DB:TEXT:PRIMARY::}',
}

function Database:__init()
	self.m_LastError = nil
end

-- this is unused
function Database:GetLastError()
	return self.m_LastError
end

function Database:Now()
	return 'CURRENT_TIMESTAMP'
end

function Database:GetError()
	return SQL:Error()
end

function Database:Query(p_Query, p_Parameters)
	SQL:Open()
	-- @ToDo build p_Query with given p_Parameters
	local s_Result = SQL:Query(p_Query)

	if not s_Result then
		self.m_LastError = 'Failed to execute query: ' .. self:GetError()
		SQL:Close()
		return nil
	end

	SQL:Close()

	return s_Result
end

function Database:CreateTable(p_TableName, p_Definitions, p_Names, p_Additional)
	local s_Entries = ArrayMap()
	local s_Additionals = ArrayMap()

	for i, l_Value in ipairs(p_Definitions) do
		local s_Name = p_Names[i]

		if l_Value == DatabaseField.Text then
			s_Entries:add(s_Name .. ' TEXT')
		elseif l_Value == DatabaseField.PrimaryText then
			s_Entries:add(s_Name .. ' TEXT UNIQUE')
		elseif l_Value == DatabaseField.Integer then
			s_Entries:add(s_Name .. ' INTEGER')
		elseif l_Value == DatabaseField.Float then
			s_Entries:add(s_Name .. ' FLOAT')
		elseif l_Value == DatabaseField.Time then
			s_Entries:add(s_Name .. ' DATETIME')
		end
	end

	if p_Additional ~= nil then
		for _, l_Value in pairs(p_Additional) do
			s_Entries:add(l_Value)
			s_Additionals:add(l_Value)
		end
	end

	return self:Query('CREATE TABLE IF NOT EXISTS ' .. p_TableName .. ' (' .. s_Entries:join(', ') .. ')')
end

function Database:Single(p_Query)
	local s_Results = self:Query(p_Query)

	if s_Results == nil then
		return nil
	end

	return s_Results[1]
end

-- this is unused
function Database:Count(p_Query, p_Parameters)
	local s_Results = self:Query(p_Query, p_Parameters)

	return #s_Results
end

function Database:Fetch(p_Query)
	return self:Query(p_Query)
end

function Database:Update(p_TableName, p_Parameters, p_Where)
	local s_Fields = ArrayMap()
	local s_Found = nil

	for l_Name, l_Value in pairs(p_Parameters) do
		if l_Value == nil then
			l_Value = 'NULL'
		elseif l_Value == self:Now() then
			l_Value = 'CURRENT_TIMESTAMP'
		elseif l_Value == DatabaseField.NULL then
			l_Value = 'NULL'
		elseif tostring(l_Value) == 'true' or l_Value == true then
			l_Value = '\'true\''
		elseif tostring(l_Value) == 'false' or l_Value == false then
			l_Value = '\'false\''
		else
			l_Value = '\'' .. tostring(l_Value) .. '\''
		end

		if p_Where == l_Name then
			s_Found = l_Value
		end

		s_Fields:add(' `' .. l_Name .. '`=' .. l_Value .. '')
	end

	m_Logger:Write('UPDATE `' .. p_TableName .. '` SET ' .. s_Fields:join(',') .. ' WHERE `' .. p_Where .. '`=' .. s_Found)

	return self:Query('UPDATE `' .. p_TableName .. '` SET ' .. s_Fields:join(', ') .. ' WHERE `' .. p_Where .. '`=\'' .. s_Found .. '\'')
end

-- this is unused
function Database:ExecuteBatch()
	self:Query('DELETE FROM `FB_Settings`')
	self:Query(m_Batched .. m_Batches:join(', '))
	m_Batched = ""
	m_Batches:clear()

	if self:GetError() ~= "" then
		m_Logger:Error(self:GetError())
	end
end

function Database:BatchQuery(p_TableName, p_Parameters, p_Where)
	local s_Names = ArrayMap()
	local s_Values = ArrayMap()
	local s_Fields = ArrayMap()
	local s_Found = nil

	for l_Name, l_Value in pairs(p_Parameters) do
		s_Names:add('`' .. l_Name .. '`')

		if l_Value == nil then
			s_Values:add('NULL')
			l_Value = 'NULL'
		elseif l_Value == self:Now() then
			s_Values:add('CURRENT_TIMESTAMP')
			l_Value = 'CURRENT_TIMESTAMP'
		elseif l_Value == DatabaseField.NULL then
			s_Values:add('NULL')
			l_Value = 'NULL'
		elseif tostring(l_Value) == 'true' or l_Value == true then
			s_Values:add('\'true\'')
			l_Value = '\'true\''
		elseif tostring(l_Value) == 'false' or l_Value == false then
			s_Values:add('\'false\'')
			l_Value = '\'false\''
		else
			s_Values:add('\'' .. tostring(l_Value) .. '\'')
			l_Value = tostring(l_Value)
		end

		if p_Where == l_Name then
			s_Found = l_Value
		end

		if p_Where ~= l_Name then
			s_Fields:add('`' .. l_Name .. '`=' .. l_Value .. '')
		end
	end

	--m_Batches:add('UPDATE `' .. p_TableName .. '` SET ' .. s_Fields:join(', ') .. ' WHERE `' .. p_Where .. '`=\'' .. s_Found .. '\'')
	--m_Batches:add('INSERT OR REPLACE INTO ' .. p_TableName .. ' (' .. s_Names:join(', ') .. ') VALUES (' .. s_Values:join(', ') .. ')')
	m_Batched = 'INSERT INTO ' .. p_TableName .. ' (' .. s_Names:join(', ') .. ') VALUES '
	m_Batches:add('(' .. s_Values:join(', ') .. ')')

	return true
end

function Database:Delete(p_TableName, p_Parameters)
	local s_Where = ArrayMap()

	for l_Name, l_Value in pairs(p_Parameters) do
		s_Where:add('`' .. l_Name .. '`=\'' ..l_Value .. '\'')
	end

	return self:Query('DELETE FROM ' .. p_TableName .. ' WHERE ' .. s_Where:join(' AND '))
end

function Database:Insert(p_TableName, p_Parameters)
	local s_Names = ArrayMap()
	local s_Values = ArrayMap()

	for l_Name, l_Value in pairs(p_Parameters) do
		s_Names:add('`' .. l_Name .. '`')

		if l_Value == nil then
			s_Values:add('NULL')
		elseif l_Value == self:Now() then
			s_Values:add('CURRENT_TIMESTAMP')
		elseif l_Value == DatabaseField.NULL then
			s_Values:add('NULL')
		elseif tostring(l_Value) == 'true' or l_Value == true then
			s_Values:add('\'true\'')
		elseif tostring(l_Value) == 'false' or l_Value == false then
			s_Values:add('\'false\'')
		else
			s_Values:add('\'' .. tostring(l_Value) .. '\'')
		end
	end

	self:Query('INSERT INTO ' .. p_TableName .. ' (' .. s_Names:join(', ') .. ') VALUES (' .. s_Values:join(', ') .. ')')

	return SQL:LastInsertId()
end

if g_Database == nil then
	g_Database = Database()
end

return g_Database
