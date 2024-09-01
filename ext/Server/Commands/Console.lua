---@class Console
---@overload fun():Console
Console = class('Console')

require('__shared/Config')

local m_SettingsManager = require('SettingsManager')

---comment
---@param p_Player Player
---@param p_Name string
---@param p_Value any
function Console:OnConsoleCommandSetConfig(p_Player, p_Name, p_Value)
	local s_Respone = ""

	if PermissionManager:HasPermission(p_Player, 'UserInterface.Settings') == false then
		s_Respone = "Missing Permissions"
	else
		local s_Result = m_SettingsManager:UpdateSetting(p_Name, p_Value)

		if s_Result then
			s_Respone = "OK"
		else
			s_Respone = "Failed"
		end
	end

	NetEvents:SendToLocal('ConsoleCommands:PrintResponse', p_Player, s_Respone)
end

---@param p_Player Player
---@param p_Args table<string, any>
function Console:OnConsoleCommandRestore(p_Player, p_Args)
	local s_Respone = ""

	if PermissionManager:HasPermission(p_Player, 'UserInterface.Settings') == false then
		s_Respone = "Missing Permissions"
	else
		m_SettingsManager:SaveAll()
		s_Respone = "OK"
	end

	NetEvents:SendToLocal('ConsoleCommands:PrintResponse', p_Player, s_Respone)
end

---@param p_Player Player
---@param p_Args table<string, any>
function Console:OnConsoleCommandSaveAll(p_Player, p_Args)
	local s_Respone = ""

	if PermissionManager:HasPermission(p_Player, 'UserInterface.Settings') == false then
		s_Respone = "Missing Permissions"
	else
		m_SettingsManager:RestoreDefault()
		s_Respone = "OK"
	end

	NetEvents:SendToLocal('ConsoleCommands:PrintResponse', p_Player, s_Respone)
end

---@param p_Player Player
function Console:RegisterConsoleCommands(p_Player)
	-- Generate list out of Name, Default, Description.
	if PermissionManager:HasPermission(p_Player, 'UserInterface.Settings') == false then
		NetEvents:SendToLocal('ConsoleCommands:PrintResponse', p_Player,
			"No Commands registered because of missing permissions")
	else
		local s_CommandList = {}

		for _, l_Item in pairs(SettingsDefinition.Elements) do
			table.insert(s_CommandList, { Name = l_Item.Name, Default = l_Item.Default, Description = l_Item.Description })
		end

		NetEvents:SendToLocal('ConsoleCommands:RegisterCommands', p_Player, s_CommandList)
	end

	-- Register events for NodeEditor.
	if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
		NetEvents:SendToLocal('ConsoleCommands:PrintResponse', p_Player,
			"No Nodeeditor-Commands registered because of missing permissions")
	else
		NetEvents:SendToLocal('ClientNodeEditor:RegisterEvents', p_Player)
	end
end

if g_Console == nil then
	---@type Console
	g_Console = Console()
end

return g_Console
