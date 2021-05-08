class('PermissionManager')

local m_Logger = Logger("PermissionManager", Debug.Server.PERMISSIONS)

function PermissionManager:__init()
	self.permissions	= {}
	self.guid_players	= {}
	self.events			= {
		ModuleLoaded	= Events:Subscribe('Extension:Loaded', self, self.__boot)
	}
end

function PermissionManager:__boot()
	m_Logger:Write('Booting...')
	
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
	})
	
	-- Load all permissions
	local permissions = Database:fetch('SELECT * FROM `FB_Permissions`')
	
	if permissions == nil then
		m_Logger:Write('Currently no Permissions exists, skipping...')
		return
	end
	
	m_Logger:Write('Loading ' .. #permissions .. ' permissions.')
	
	for name, value in pairs(permissions) do
		if self.guid_players[value.PlayerName] == nil then
			self.guid_players[value.PlayerName] = value.GUID
		end
		
		if self.permissions[value.GUID] == nil then
			m_Logger:Write(value.GUID .. ' (' .. value.PlayerName .. ') ~> ' .. PermissionManager:GetCorrectName(value.Value))
			self.permissions[value.GUID] = { PermissionManager:GetCorrectName(value.Value) }
		elseif Utilities:has(self.permissions[value.GUID], value.Value) == false then
			m_Logger:Write(value.GUID .. ' (' .. value.PlayerName .. ') ~> ' .. PermissionManager:GetCorrectName(value.Value))
			table.insert(self.permissions[value.GUID], PermissionManager:GetCorrectName(value.Value))
		end
	end
end

function PermissionManager:GetPermissions(name)
	local player = name
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name)
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name))
		end
		
		if player == nil then
			player = self:GetDataByName(name)
		end
	end
	
	if player == nil then
		return nil
	end
	
	if (self.permissions[tostring(player.guid)] ~= nil) then
		return self.permissions[tostring(player.guid)]
	end
	
	return nil
end

function PermissionManager:AddPermission(name, permission)
	local player	= name
	permission		= PermissionManager:GetCorrectName(permission)
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name)
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name))
		end
		
		if player == nil then
			player = self:GetDataByName(name)
		end
	end
	
	if self.permissions[tostring(player.guid)] == nil then
		self.permissions[tostring(player.guid)]	= { permission }
		self.guid_players[player.name]			= tostring(player.guid)
	elseif Utilities:has(self.permissions[tostring(player.guid)], permission) == false then
		table.insert(self.permissions[tostring(player.guid)], permission)
	end
	
	local single = Database:single('SELECT * FROM `FB_Permissions` WHERE `GUID`=\'' .. tostring(player.guid) .. '\' AND `Value`=\'' .. permission .. '\' LIMIT 1')

	-- If not exists, create
	if single == nil then
		Database:insert('FB_Permissions', {
			GUID		= tostring(player.guid),
			PlayerName	= player.name,
			Value		= permission,
			Time		= Database:now()
		})
	end
end

function PermissionManager:GetAll()
	local result		= {}
	
	for guid, permissions in pairs(self.permissions) do
		local name = nil
		
		for temp_name, temp_guid in pairs(self.guid_players) do
			if guid:lower() == temp_guid:lower() then
				name = temp_name
			end
		end
		
		table.insert(result, guid)
		table.insert(result, name)
		table.insert(result, tostring(#permissions))
	end
	
	return result
end

function PermissionManager:ExtendPermissions(permissions)
	local result = {}
	
	for index, permission in pairs(permissions) do
		local parts	= permission:split('.')
		local temp 	= ''
		
		for _, part in pairs(parts) do
			temp = temp .. part
			table.insert(result, temp)
			
			temp = temp .. '.'
		end
	end
	
	return result
end

function PermissionManager:Exists(name)
	if name == '*' then
		return true
	end
	
	for _, permission in pairs(Permissions) do	
		if permission:lower() == name:lower() then
			return true
		end
	end
	
	return false
end

function PermissionManager:GetCorrectName(name)
	for _, permission in pairs(Permissions) do	
		if permission:lower() .. '.*' == name:lower() then
			return permission .. '.*'
		elseif permission:lower() == name:lower() then
			return permission
		end
	end
	
	return name
end

function PermissionManager:HasPermission(name, permission)
	if Config.IgnorePermissions then
		return true
	end
	
	local permissions = self:GetPermissions(name)
	if permissions == nil then
		return false
	end
	
	if #permissions == 0 then
		return false
	end
	
	permissions		= self:ExtendPermissions(permissions)
	local search	= permission:split('.')
	local result	= false
	
	for i = 1, #permissions do
		if result then
			return true
		end
		
		local exists = permissions[i]:split('.')
	
		-- Simple Check
		if permissions[i]:lower() == permission:lower() or permissions[i] == '*' or permissions[i]:lower() == permission:lower() .. '.*' then 
			result = true
		end
		
		-- Extended Check
		local temp = ''
		
		for j = 1, #search do
			if result then
				return true
			end
			
			temp = temp .. search[j]

			if (temp:lower() .. '.*' == permissions[i]:lower()) then
				result = true
			end
			
			temp = temp .. '.'
		end
	end
	
	return result
end

function PermissionManager:Revoke(name, permission)
	local player = name
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name)
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name))
		end
		
		if player == nil then
			player = self:GetDataByName(name)
		end
	end
	
	if player == nil then
		return false
	end
	
	if (self.permissions[tostring(player.guid)] == nil) then
		return false
	end
	
	local permissions = self:GetPermissions(name)
	
	if permissions == nil or #permissions == 0 then
		return false
	end
	
	for i = 1, #permissions do
		if permissions[i]:lower() == permission:lower() then 
			Database:delete('FB_Permissions', {
				GUID	= tostring(player.guid),
				Value	= PermissionManager:GetCorrectName(permissions[i])
			})
			
			table.remove(self.permissions[tostring(player.guid)], i)
			return true
		end
	end
	
	return false
end

function PermissionManager:RevokeAll(name)
	local player = name
	
	if type(name) == 'string' then
		player = PlayerManager:GetPlayerByName(name)
		
		if player == nil then
			player = PlayerManager:GetPlayerByGuid(Guid(name))
			
			if player == nil then
				player = self:GetDataByName(name)
			end
		end
	end
	
	if player == nil then
		return false
	end
	
	if (self.permissions[tostring(player.guid)] == nil) then
		return false
	end
	
	self.permissions[tostring(player.guid)] = {}
	
	Database:delete('FB_Permissions', {
		GUID	= tostring(player.guid)
	})
	
	return true
end

function PermissionManager:GetDataByName(name)
	local guid = nil
	
	for temp_name, temp_guid in pairs(self.guid_players) do	
		if name:lower() == temp_guid:lower() or name:lower() == temp_name:lower() then
			guid = temp_guid
			name = temp_name
		end
	end
	
	if guid == nil then
		return nil
	end
	
	return {
		guid = Guid(guid),
		name = name
	}
end

-- Singleton.
if g_PermissionManager == nil then
	g_PermissionManager = PermissionManager()
end

return g_PermissionManager