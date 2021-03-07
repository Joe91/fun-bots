class('Database');

require('__shared/ArrayMap');
local batches	= ArrayMap();
local batched	= '';
	
DatabaseField = {
	NULL		= '{::DB:NULL::}',
	ID			= '{::DB:ID::}',
	Text		= '{::DB:TEXT::}',
	Time		= '{::DB:TIME::}',
	Integer		= '{::DB:INTEGER::}',
	Float		= '{::DB:FLOAT::}',
	Boolean		= '{::DB:BOOLEAN::}',
	PrimaryText	= '{::DB:TEXT:PRIMARY::}',
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
	SQL:Open();
	-- @ToDo build query with given parameters
	local result = SQL:Query(query);

	if not result then
		self.lastError = 'Failed to execute query: ' .. self:getError();
		SQL:Close();
		return nil;
	end

	SQL:Close();

	return result;
end

function Database:createTable(tableName, definitions, names, additional)
	local entries		= ArrayMap();
	local additionals	= ArrayMap();
	
	for index, value in ipairs(definitions) do
		local name = names[index];

		if value == DatabaseField.Text then
			entries:add(name .. ' TEXT');
			
		elseif value == DatabaseField.PrimaryText then
			entries:add(name .. ' TEXT UNIQUE');

		elseif value == DatabaseField.Integer then
			entries:add(name .. ' INTEGER');

		elseif value == DatabaseField.Float then
			entries:add(name .. ' FLOAT');

		elseif value == DatabaseField.Time then
			entries:add(name .. ' DATETIME');

		end
	end
	
	if additional ~= nil then
		for index, value in pairs(additional) do
			entries:add(value);
			additionals:add(value);
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

	if Debug.Server.DATABASE then
		print('UPDATE `' .. tableName .. '` SET ' .. fields:join(',') .. ' WHERE `' .. where .. '`=' .. found);
	end
	
	return self:query('UPDATE `' .. tableName .. '` SET ' .. fields:join(', ') .. ' WHERE `' .. where .. '`=\'' .. found .. '\'');
end

function Database:executeBatch()
	self:query('DELETE FROM `FB_Settings`');
	self:query(batched .. batches:join(', '));
	print(self:getError());
end

function Database:batchQuery(tableName, parameters, where)
	local names		= ArrayMap();
	local values	= ArrayMap();
	local fields	= ArrayMap();
	local found		= nil;

	for name, value in pairs(parameters) do
		names:add('`' .. name .. '`');

		if value == nil then
			values:add('NULL');
			value = 'NULL';
		
		elseif value == self:now() then
			values:add('CURRENT_TIMESTAMP');
			value = 'CURRENT_TIMESTAMP';

		elseif value == DatabaseField.NULL then
			values:add('NULL');
			value = 'NULL';
			
		elseif tostring(value) == 'true' or value == true then
			values:add('\'true\'');
			value = '\'true\'';
			
		elseif tostring(value) == 'false' or value == false then
			values:add('\'false\'');
			value = '\'false\'';
			
		else
			values:add('\'' .. tostring(value) .. '\'');
			value = tostring(value);
		end
		
		if where == name then
			found = value;
		end
		
		if where ~= name then
			fields:add('`' .. name .. '`=' .. value .. '');
		end
	end

	--batches:add('UPDATE `' .. tableName .. '` SET ' .. fields:join(', ') .. ' WHERE `' .. where .. '`=\'' .. found .. '\'');
	--batches:add('INSERT OR REPLACE INTO ' .. tableName .. ' (' .. names:join(', ') .. ') VALUES (' .. values:join(', ') .. ')');
	batched = 'INSERT INTO ' .. tableName .. ' (' .. names:join(', ') .. ') VALUES ';
	batches:add('(' .. values:join(', ') .. ')');

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