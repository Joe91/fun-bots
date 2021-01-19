class('Database');

require('__shared/ArrayMap');

DatabaseField = {
	NULL	= 0,
	ID		= 1,
	Text	= 2,
	Time	= 3,
	Integer	= 4,
	Float	= 5
};

function Database:__init()
	self.lastError = nil;
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

	return results[1];
end

function Database:count(query, parameters)
	local results = self:query(query, parameters);

	return #results;
end

function Database:fetch(query)
	return self:query(query);
end

function Database:update(tableName, where, parameters)
	--local fields = '';

	--foreach(parameters AS name => value) {
	--	fields .= ' `' . $name . '`=:' . $name . ',';
	--}

	--return self:query(sprintf('UPDATE `%1$s` SET %2$s WHERE `%3$s`=:%3$s', $table, rtrim($fields, ','), $where), $parameters)->fetchAll(\PDO::FETCH_OBJ);
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

		if value == 'CURRENT_TIMESTAMP' then
			values:add('CURRENT_TIMESTAMP');

		elseif value == DatabaseField.NULL then
			values:add('NULL');

		else
			values:add('\'' .. value .. '\'');
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