class('UI')

local m_Logger = Logger("ClientUI", Debug.Client.UI)

function UI:__init()
	self.m_WaypointEditor = false
end

function UI:OnExtensionLoaded()
	WebUI:Init()
	WebUI:Show()

	Events:Subscribe('UI', self, self.__local)
	NetEvents:Subscribe('UI', self, self.__action)
end

function UI:OnExtensionUnloading()
	WebUI:ResetMouse()
	WebUI:ResetKeyboard()
	WebUI:Hide()
end

function UI:OnClientUpdateInput(p_DeltaTime)
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		if self.m_WaypointEditor then
			NetEvents:Send('UI', 'VIEW', 'WaypointEditor', 'HIDE')
		end

		NetEvents:Send('UI', 'VIEW', 'BotEditor', 'TOGGLE')
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_Q) and self.m_WaypointEditor then
		self:__local(json.encode({ 'VIEW', 'WaypointEditor', 'ACTIVATE' }))
	elseif InputManager:WentKeyUp(InputDeviceKeys.IDK_Q) and self.m_WaypointEditor then
		self:__local(json.encode({ 'VIEW', 'WaypointEditor', 'DEACTIVATE' }))
	end
end

function UI:__local(p_String)
	local s_DataTable, s_Error = json.decode(p_String)

	if s_DataTable == nil then
		m_Logger:Error('[UI] Bad JSON: ' .. tostring(s_Error) .. ', ' .. tostring(p_String))
		return
	end

	local s_Type = s_DataTable[1]
	local s_Destination = s_DataTable[2]
	local s_Action = s_DataTable[3]
	local s_Data = s_DataTable[4]

	m_Logger:Write('[UI][Client] LocalAction { Type=' .. tostring(s_Type) .. ', Destination=' .. tostring(s_Destination) ..', Action=' .. tostring(s_Action) .. ', Data=' .. json.encode(s_Data) .. '}')
	NetEvents:Send('UI', s_Type, s_Destination, s_Action, s_Data)
end

function UI:__action(p_Type, p_Destination, p_Action, p_String)
	local s_Data = nil

	if p_String ~= nil then
		local s_Error = nil
		s_Data, s_Error = json.decode(p_String)

		if s_Data == nil then
			m_Logger:Error('[UI] Bad JSON: ' .. tostring(s_Error) .. ', ' .. tostring(p_String))
			return
		end
	end

	m_Logger:Write('[UI][Client] Action { Type=' .. tostring(p_Type) .. ', Destination=' .. tostring(p_Destination) ..', Action=' .. tostring(p_Action) .. ', Data=' .. json.encode(s_Data) .. '}')

	if p_Action == 'ACTIVATE' then
		WebUI:EnableMouse()
		WebUI:EnableKeyboard()
	elseif p_Action == 'DEACTIVATE' then
		if (self.m_WaypointEditor and p_Destination == 'WaypointEditor') or p_Destination == 'BotEditor' then
			WebUI:ResetMouse()
			WebUI:ResetKeyboard()
		end
	elseif p_Action == 'SHOW' and p_Destination == 'WaypointEditor' then
		self.m_WaypointEditor = true
	elseif p_Action == 'HIDE' and p_Destination == 'WaypointEditor' then
		self.m_WaypointEditor = false
	end

	WebUI:ExecuteJS('UI.Handle(' .. json.encode({
		Type = p_Type,
		Destination = p_Destination,
		Action = p_Action,
		Data = s_Data
	}) .. ')')
end

if g_UI == nil then
	g_UI = UI()
end

return g_UI
