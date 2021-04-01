class('PermissionManager');

function PermissionManager:__init()
	self.permissions	= {};
	self.guid_players	= {};
	self.events			= {
		ModuleLoaded	= Events:Subscribe('Extension:Loaded', self, self.__boot)
	};
end

function PermissionManager:__boot()
	print('[PermissionManager] Booting...');
	
	-- Create Permissions
	Database:createTable('FB_Permissions', {
		DatabaseField.Text,
		DatabaseField.Text,
		DatabaseField.Text,
		DatabaseField.Time
	}, {
		'GUID',
		'PlayerName',
		'Value',
		'Time'
	});
	
	-- Load all permissions
	local permissions = Database:fetch('SELECT * FROM `FB_Permissions`');
	
	if permissions == nil then
		print('[PermissionManager] Currently no Permissions exists, skipping...');
		return;
	end
	
	print('[PermissionManager] Loading ' .. #permissions .. ' permissions.');
	
	for name, value in pairs(permissions) do
		if self.guid_players[value.PlayerName] == nil then
			self.guid_players[value.PlayerName] = value.GUID;
		end
		
		print('[PermissionManager] ' .. value.GUID .. ' (' .. value.PlayerName .. ') ~> ' .. value.Value);
		
		if self.permissions[value.GUID] == nil then
			self.permissions[value.GUID] = { value.Value };
		else
			table.insert(self.permissions[value.GUID], value.Value);
		end
	end
end

function PermissionManager:GetPermissions(name)
	local player = name;
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name);
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name));
		end
		
		if player == nil then
			player = self:GetDataByName(name);
		end
	end
	
	if player == nil then
		return nil;
	end
	
	if (self.permissions[tostring(player.guid)] ~= nil) then
		return self.permissions[tostring(player.guid)];
	end
	
	return nil;
end

function PermissionManager:AddPermission(name, permission)
	local player = name;
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name);
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name));
		end
		
		if player == nil then
			player = self:GetDataByName(name);
		end
	end
	
	if self.permissions[tostring(player.guid)] == nil then
		self.permissions[tostring(player.guid)]	= { permission };
		self.guid_players[player.name]			= tostring(player.guid);
	else
		table.insert(self.permissions[tostring(player.guid)], permission);
	end
	
	local single = Database:single('SELECT * FROM `FB_Permissions` WHERE `GUID`=\'' .. tostring(player.guid) .. '\' AND `Value`=\'' .. permission .. '\' LIMIT 1');

	-- If not exists, create
	if single == nil then
		Database:insert('FB_Permissions', {
			GUID		= tostring(player.guid),
			PlayerName	= player.name,
			Value		= permission,
			Time		= Database:now()
		});
	end
end

function PermissionManager:GetAll()
	local result		= {};
	
	for guid, permissions in pairs(self.permissions) do
		local name = nil;
		
		for temp_name, temp_guid in pairs(self.guid_players) do
			if guid:lower() == temp_guid:lower() then
				name = temp_name;
			end
		end
		
		table.insert(result, guid);
		table.insert(result, name);
		table.insert(result, tostring(#permissions));
	end
	
	return result;
end

function PermissionManager:ExtendPermissions(permissions)
	local result = {};
	
	for index, permission in pairs(permissions) do
		local parts	= permission:split('.');
		local temp 	= '';
		
		for _, part in pairs(parts) do
			temp = temp .. part;
			table.insert(result, temp);
			
			temp = temp .. '.';
		end
	end
	
	return result;
end

function PermissionManager:HasPermission(name, permission)
	local permissions = self:GetPermissions(name);
	
	if permissions == nil then
		return false;
	end
	
	if #permissions == 0 then
		return false;
	end
	
	permissions		= self:ExtendPermissions(permissions);
	local search	= permission:split('.');
	local result	= false;
	
	for i = 1, #permissions do
		if result then
			return true;
		end
		
		local exists = permissions[i]:split('.');
	
		-- Simple Check
		if permissions[i]:lower() == permission:lower() or permissions[i] == '*' or permissions[i]:lower() == permission:lower() .. '.*' then 
			result = true;
		end
		
		-- Extended Check
		local temp = '';
		
		for j = 1, #search do
			if result then
				return true;
			end
			
			temp = temp .. search[j];

			if (temp:lower() .. '.*' == permissions[i]:lower()) then
				result = true;
			end
			
			temp = temp .. '.';
		end
	end
	
	return result;
end

function PermissionManager:Revoke(name, permission)
	local player = name;
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name);
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name));
		end
		
		if player == nil then
			player = self:GetDataByName(name);
		end
	end
	
	if player == nil then
		return false;
	end
	
	if (self.permissions[tostring(player.guid)] == nil) then
		return false;
	end
	
	local permissions = self:GetPermissions(name);
	
	if permissions == nil or #permissions == 0 then
		return false;
	end
	
	for i = 1, #permissions do
		print(permissions[i]);
		if permissions[i]:lower() == permission:lower() then 
			Database:delete('FB_Permissions', {
				GUID	= tostring(player.guid),
				Value	= permissions[i]
			});
			
			table.remove(self.permissions[tostring(player.guid)], i);
			return true;
		end
	end
	
	return false;
end

function PermissionManager:RevokeAll(name)
	local player = name;
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name);
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name));
			
			if player == nil then
				player = self:GetDataByName(name);
			end
		end
	end
	
	if player == nil then
		return false;
	end
	
	if (self.permissions[tostring(player.guid)] == nil) then
		return false;
	end
	
	self.permissions[tostring(player.guid)] = {};
	
	Database:delete('FB_Permissions', {
		GUID	= tostring(player.guid)
	});
	
	return true;
end

function PermissionManager:GetDataByName(name)
	local guid = nil;
	
	for temp_name, temp_guid in pairs(self.guid_players) do	
		print(json.encode({
			Name = name,
			TGuid = temp_guid,
			TName =  temp_name
		}));
		
		if name:lower() == temp_guid:lower() or name:lower() == temp_name:lower() then
			guid = temp_guid;
			name = temp_name;
		end
	end
	
	if guid == nil then
		return nil;
	end
	
	return {
		guid = Guid(guid),
		name = name
	};
end

-- Singleton.
if g_PermissionManager == nil then
	g_PermissionManager = PermissionManager();
end

return g_PermissionManager;