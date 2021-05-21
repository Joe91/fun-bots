class('PermissionManager')

local m_Logger = Logger("PermissionManager", Debug.Server.PERMISSIONS)

function PermissionManager:__init()
	self.m_Permissions = {}
	self.m_Guid_Players = {}
	self.m_Events = {
		ModuleLoaded = Events:Subscribe('Extension:Loaded', self, self.__boot)
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
	local s_Permissions = Database:fetch('SELECT * FROM `FB_Permissions`')

	if s_Permissions == nil then
		m_Logger:Write('Currently no Permissions exists, skipping...')
		return
	end

	m_Logger:Write('Loading ' .. #s_Permissions .. ' permissions.')

	for l_Name, l_Value in pairs(s_Permissions) do
		if self.m_Guid_Players[l_Value.PlayerName] == nil then
			self.m_Guid_Players[l_Value.PlayerName] = l_Value.GUID
		end

		if self.m_Permissions[l_Value.GUID] == nil then
			m_Logger:Write(l_Value.GUID .. ' (' .. l_Value.PlayerName .. ') ~> ' .. PermissionManager:GetCorrectName(l_Value.Value))
			self.m_Permissions[l_Value.GUID] = { PermissionManager:GetCorrectName(l_Value.Value) }
		elseif Utilities:has(self.m_Permissions[l_Value.GUID], l_Value.Value) == false then
			m_Logger:Write(l_Value.GUID .. ' (' .. l_Value.PlayerName .. ') ~> ' .. PermissionManager:GetCorrectName(l_Value.Value))
			table.insert(self.m_Permissions[l_Value.GUID], PermissionManager:GetCorrectName(l_Value.Value))
		end
	end
end

function PermissionManager:GetPermissions(p_Name)
	local s_Player = p_Name

	if type(p_Name) == 'string' then
		s_Player = PlayerManager:GetPlayerByName(p_Name)

		if s_Player == nil then
			s_Player = PlayerManager:GetPlayerByGuid(Guid(p_Name))
		end

		if s_Player == nil then
			s_Player = self:GetDataByName(p_Name)
		end
	end

	if s_Player == nil then
		return nil
	end

	if self.m_Permissions[tostring(s_Player.guid)] ~= nil then
		return self.m_Permissions[tostring(s_Player.guid)]
	end

	return nil
end

function PermissionManager:AddPermission(p_Name, p_Permission)
	local s_Player = p_Name
	p_Permission = self:GetCorrectName(p_Permission)

	if type(p_Name) == 'string' then
		s_Player = PlayerManager:GetPlayerByName(p_Name)

		if s_Player == nil then
			s_Player = PlayerManager:GetPlayerByGuid(Guid(p_Name))
		end

		if s_Player == nil then
			s_Player = self:GetDataByName(p_Name)
		end
	end

	if self.m_Permissions[tostring(s_Player.guid)] == nil then
		self.m_Permissions[tostring(s_Player.guid)] = { p_Permission }
		self.m_Guid_Players[s_Player.name] = tostring(s_Player.guid)
	elseif Utilities:has(self.m_Permissions[tostring(s_Player.guid)], p_Permission) == false then
		table.insert(self.m_Permissions[tostring(s_Player.guid)], p_Permission)
	end

	local s_Single = Database:single('SELECT * FROM `FB_Permissions` WHERE `GUID`=\'' .. tostring(s_Player.guid) .. '\' AND `Value`=\'' .. p_Permission .. '\' LIMIT 1')

	-- If not exists, create
	if s_Single == nil then
		Database:insert('FB_Permissions', {
			GUID = tostring(s_Player.guid),
			PlayerName = s_Player.name,
			Value = p_Permission,
			Time = Database:now()
		})
	end
end

function PermissionManager:GetAll()
	local s_Result = {}

	for l_Guid, l_Permissions in pairs(self.m_Permissions) do
		local s_Name = nil

		for l_Temp_Name, l_Temp_Guid in pairs(self.m_Guid_Players) do
			if l_Guid:lower() == l_Temp_Guid:lower() then
				s_Name = l_Temp_Name
			end
		end

		table.insert(s_Result, l_Guid)
		table.insert(s_Result, s_Name)
		table.insert(s_Result, tostring(#l_Permissions))
	end

	return s_Result
end

function PermissionManager:ExtendPermissions(p_Permissions)
	local s_Result = {}

	for l_Index, l_Permission in pairs(p_Permissions) do
		local s_Parts = l_Permission:split('.')
		local s_Temp = ''

		for _, l_Part in pairs(s_Parts) do
			s_Temp = s_Temp .. l_Part
			table.insert(s_Result, s_Temp)

			s_Temp = s_Temp .. '.'
		end
	end

	return s_Result
end

function PermissionManager:Exists(p_Name)
	if p_Name == '*' then
		return true
	end

	local s_CorrectedName = string.gsub(p_Name, "%.%*", ""):lower() -- remove ".*" at the end

	for _, l_Permission in pairs(Permissions) do
		if l_Permission:lower() == s_CorrectedName then
			return true
		end
	end

	return false
end

function PermissionManager:GetCorrectName(p_Name)
	for _, l_Permission in pairs(Permissions) do
		if l_Permission:lower() .. '.*' == p_Name:lower() then
			return l_Permission .. '.*'
		elseif l_Permission:lower() == p_Name:lower() then
			return l_Permission
		end
	end

	return p_Name
end

function PermissionManager:HasPermission(p_Name, p_Permission)
	if Config.IgnorePermissions then
		return true
	end

	local s_Permissions = self:GetPermissions(p_Name)

	if s_Permissions == nil then
		return false
	end

	if #s_Permissions == 0 then
		return false
	end

	s_Permissions = self:ExtendPermissions(s_Permissions)
	local s_Search = p_Permission:split('.')
	local s_Result = false

	for i = 1, #s_Permissions do
		if s_Result then
			return true
		end

		-- Simple Check
		if s_Permissions[i]:lower() == p_Permission:lower() or s_Permissions[i] == '*' or s_Permissions[i]:lower() == p_Permission:lower() .. '.*' then
			s_Result = true
		end

		-- Extended Check
		local s_Temp = ''

		for j = 1, #s_Search do
			if s_Result then
				return true
			end

			s_Temp = s_Temp .. s_Search[j]

			if (s_Temp:lower() .. '.*' == s_Permissions[i]:lower()) then
				s_Result = true
			end

			s_Temp = s_Temp .. '.'
		end
	end

	return s_Result
end

function PermissionManager:Revoke(p_Name, p_Permission)
	local p_Player = p_Name

	if type(p_Name) == 'string' then
		p_Player = PlayerManager:GetPlayerByName(p_Name)

		if p_Player == nil then
			p_Player = PlayerManager:GetPlayerByGuid(Guid(p_Name))
		end

		if p_Player == nil then
			p_Player = self:GetDataByName(p_Name)
		end
	end

	if p_Player == nil then
		return false
	end

	if self.m_Permissions[tostring(p_Player.guid)] == nil then
		return false
	end

	local s_Permissions = self:GetPermissions(p_Name)

	if s_Permissions == nil or #s_Permissions == 0 then
		return false
	end

	for i = 1, #s_Permissions do
		if s_Permissions[i]:lower() == p_Permission:lower() then
			Database:delete('FB_Permissions', {
				GUID = tostring(p_Player.guid),
				Value = PermissionManager:GetCorrectName(s_Permissions[i])
			})

			table.remove(self.m_Permissions[tostring(p_Player.guid)], i)
			return true
		end
	end

	return false
end

function PermissionManager:RevokeAll(p_Name)
	local s_Player = p_Name

	if type(p_Name) == 'string' then
		s_Player = PlayerManager:GetPlayerByName(p_Name)

		if s_Player == nil then
			s_Player = PlayerManager:GetPlayerByGuid(Guid(p_Name))

			if s_Player == nil then
				s_Player = self:GetDataByName(p_Name)
			end
		end
	end

	if s_Player == nil then
		return false
	end

	if self.m_Permissions[tostring(s_Player.guid)] == nil then
		return false
	end

	self.m_Permissions[tostring(s_Player.guid)] = {}

	Database:delete('FB_Permissions', {
		GUID = tostring(s_Player.guid)
	})

	return true
end

function PermissionManager:GetDataByName(p_Name)
	local s_Guid = nil

	for l_Temp_Name, l_Temp_Guid in pairs(self.m_Guid_Players) do
		if p_Name:lower() == l_Temp_Guid:lower() or p_Name:lower() == l_Temp_Name:lower() then
			s_Guid = l_Temp_Guid
			p_Name = l_Temp_Name
		end
	end

	if s_Guid == nil then
		return nil
	end

	return {
		guid = Guid(s_Guid),
		name = p_Name
	}
end

if g_PermissionManager == nil then
	g_PermissionManager = PermissionManager()
end

return g_PermissionManager
