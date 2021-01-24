class('Database');

require('__shared/ArrayMap');
local batches	= ArrayMap();
	
DatabaseField = {
	NULL	= '{::DB:NULL::}',
	ID		= '{::DB:ID::}',
	Text	= '{::DB:TEXT::}',
	Time	= '{::DB:TIME::}',
	Integer	= '{::DB:INTEGER::}',
	Float	= '{::DB:FLOAT::}',
	Boolean	= '{::DB:BOOLEAN::}'
};

function Database:__init()
	self.lastError	= nil;
end

function Database:getLastError()
	return self.lastError;
end

function Database:now()
	return 'CURRENT_TIMESTAMP';
end

function Database:getError()
	return SQL:Error();
end

function Database:query(query, parameters)
	if not SQL:Open() then
		self.lastError = 'Can\'t open mod.db!';
		return nil;
	end

	-- @ToDo build query with given parameters
	local result = SQL:Query(query);

	if not result then
		self.lastError = 'Failed to execute query: ' .. self:getError();
		return nil;
	end

	SQL:Close();

	return result;
end

function Database:createTable(tableName, definitions, names)
	local entries = ArrayMap();

	for index, value in ipairs(definitions) do
		local name = names[index];

		if value == DatabaseField.ID then
			entries:add(name .. ' INTEGER PRIMARY KEY AUTOINCREMENT');

		elseif value == DatabaseField.Text then
			entries:add(name .. ' TEXT');

		elseif value == DatabaseField.Integer then
			entries:add(name .. ' INTEGER');

		elseif value == DatabaseField.Float then
			entries:add(name .. ' FLOAT');

		elseif value == DatabaseField.Time then
			entries:add(name .. ' DATETIME');

		end
	end

	return self:query('CREATE TABLE IF NOT EXISTS ' .. tableName .. ' (' .. entries:join(', ') .. ')');
end

function Database:single(query)
	local results = self:query(query);

	if results == nil then
		return nil;
	end
	
	return results[1];
end

function Database:count(query, parameters)
	local results = self:query(query, parameters);

	return #results;
end

function Database:fetch(query)
	return self:query(query);
end

function Database:update(tableName, parameters, where)
	local fields	= ArrayMap();
	local found		= nil;
	
	for name, value in pairs(parameters) do
		if value == nil then
			value = 'NULL';
		
		elseif value == self:now() then
			value = 'CURRENT_TIMESTAMP';

		elseif value == DatabaseField.NULL then
			value = 'NULL';
			
		elseif tostring(value) == 'true' or value == true then
			value = '\'true\'';
			
		elseif tostring(value) == 'false' or value == false then
			value = '\'false\'';
			
		else
			value = '\'' .. tostring(value) .. '\'';
		end
		
		if where == name then
			found = value;
		end
		
		fields:add(' `' .. name .. '`=' .. value .. '');
	end

	print('UPDATE `' .. tableName .. '` SET ' .. fields:join(',') .. ' WHERE `' .. where .. '`=' .. found);
	return self:query('UPDATE `' .. tableName .. '` SET ' .. fields:join(', ') .. ' WHERE `' .. where .. '`=' .. found);
end

function Database:executeBatch()
	print('Database:executeBatch');
	
	self:query(batches:join('\n'));
	
	print('END BATCH');
end

function Database:batchQuery(tableName, parameters, where)
	local fields	= ArrayMap();
	local names		= ArrayMap();
	local values	= ArrayMap();
	local found		= nil;
	
	for name, value in pairs(parameters) do
		names:add('`' .. name .. '`');
		
		if value == nil then
			value = 'NULL';
			values:add('NULL');
		
		elseif value == self:now() then
			value = 'CURRENT_TIMESTAMP';
			values:add('CURRENT_TIMESTAMP');

		elseif value == DatabaseField.NULL then
			value = 'NULL';
			values:add('NULL');
			
		elseif tostring(value) == 'true' or value == true then
			value = '\'true\'';
			values:add('\'true\'');
			
		elseif tostring(value) == 'false' or value == false then
			value = '\'false\'';
			values:add('\'false\'');
			
		else
			value = '\'' .. tostring(value) .. '\'';
			values:add('\'' .. tostring(value) .. '\'');
		end
		
		if where == name then
			found = value;
		end
		
		if name ~= 'ID' then
			fields:add(' `' .. name .. '`=' .. value .. '');
		end
	end
	
	batches:add('INSERT OR IGNORE INTO `' .. tableName .. '` (' .. names:join(', ') .. ') VALUES  (' .. values:join(', ') .. ');');
	batches:add('UPDATE `' .. tableName .. '` SET ' .. fields:join(', ') .. ' `' .. where .. '`=' .. found .. ' LIMIT 1;');
	
	return true;
end

function Database:delete(tableName, parameters)
	local where		= ArrayMap();

	for name, value in pairs(parameters) do
		where:add('`' .. name .. '`=\'' ..value .. '\'');
	end

	return self:query('DELETE FROM ' .. tableName .. ' WHERE ' .. where:join(' AND '));
end

function Database:insert(tableName, parameters)
	local names		= ArrayMap();
	local values	= ArrayMap();

	for name, value in pairs(parameters) do
		names:add('`' .. name .. '`');

		if value == nil then
			values:add('NULL');
		
		elseif value == self:now() then
			values:add('CURRENT_TIMESTAMP');

		elseif value == DatabaseField.NULL then
			values:add('NULL');
			
		elseif tostring(value) == 'true' or value == true then
			values:add('\'true\'');
			
		elseif tostring(value) == 'false' or value == false then
			values:add('\'false\'');
			
		else
			values:add('\'' .. tostring(value) .. '\'');
		end
	end

	self:query('INSERT INTO ' .. tableName .. ' (' .. names:join(', ') .. ') VALUES (' .. values:join(', ') .. ')');

	return SQL:LastInsertId();
end

-- Singleton.
if g_Database == nil then
	g_Database = Database();
end

return g_Database;