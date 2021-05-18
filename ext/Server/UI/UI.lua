--[[
	@class: UI
]]
class('UI')

local m_Logger = Logger("UI", Debug.Server.UI)

require('UI/Constants/Type')
require('UI/Constants/Position')
require('UI/Constants/Color')
require('UI/Constants/Numpad')
require('UI/Types/Category')
require('UI/Types/Range')
require('UI/Types/Option')
require('UI/Types/ValueType')
require('UI/SettingsDefinition')

--[[
	@method: __init

	Initialization of the UI component
]]
function UI:__init()
	-- Disable WebInterface
	if Config.DisableUserInterface == true then
		m_Logger:Write('UserInterface is disabled by Configuration.')
		return
	end

	--[[
		@variable: boot

		Components to be loaded. If new components are to be added, they are described here.
	]]
	self.m_Boot = {
		'QuickShortcut',
		'Input',
		'Text',
		'Button',
		'CheckBox',
		'Logo',
		'Menu',
		'View',
		'Alert',
		'Dialog',
		'Entry',
		'Box'
	}

	--[[
		@variable: load

		Views to be loaded. If new views are to be added, they are described here.
	]]
	self.m_Load = {
		'BotEditor',
		'WaypointEditor'
	}

	--[[
		@variable: popups

		Popups to be loaded. If new popups are to be added, they are described here.
	]]
	self.m_Popups = {
		'Settings',
		'Confirmation'
	}

	-- Do not modify here
	_G.Callbacks = {}
	self.m_Views = {}
	self.m_Dialogs = {}
	self.m_Booted = 0
	self.m_Loaded = 0
	self.m_Inited = 0

	self.m_Events = {
		ModuleLoaded = Events:Subscribe('Extension:Loaded', self, self.__boot),
		EngineUpdate = Events:Subscribe('Engine:Update', self, self.__update),
		UI = NetEvents:Subscribe('UI', self, self.__action)
	}
end

--[[
	@method: GetView
	@parameter: name:string | Name of the view to get
	@return: View | nil

	Fetches an initialized view from the cache
]]
function UI:GetView(p_Name)
	if (self.m_Views[p_Name] ~= nil) then
		return self.m_Views[p_Name]
	end

	return nil
end

--[[
	@method: GetDialog
	@parameter: name:string | Name of the dialog to get
	@return: Dialog | nil

	Fetches an initialized dialog from the cache
]]
function UI:GetDialog(p_Name, p_View)
	local s_Reference = self.m_Dialogs[p_Name]
	local s_Instance = nil

	if (s_Reference ~= nil) then
		s_Instance = s_Reference()

		if s_Instance ~= nil then
			if (s_Instance['InitializeComponent'] ~= nil) then
				s_Instance:InitializeComponent(p_View)
			end

			return s_Instance
		end
	end

	return nil
end

--[[
	@method: __boot

	All UI components were booted here.
]]
function UI:__boot()
	m_Logger:Write('Booting...')

	-- Load all required Components
	for _, l_Component in pairs(self.m_Boot) do
		local s_Try = requireExists('UI/Components/' .. l_Component)

		if (s_Try ~= true) then
			m_Logger:Error('Can\'t load Component: ' .. l_Component .. ' (' .. s_Try .. ')')
		else
			m_Logger:Write('Component "' .. l_Component .. '" was loaded.')
			self.m_Booted = self.m_Booted + 1
		end
	end

	-- Load Views
	for _, l_View in pairs(self.m_Load) do
		local s_Try = requireExists('UI/Views/' .. l_View)

		if (s_Try ~= true) then
			m_Logger:Error('Can\'t load View: ' .. l_View .. ' (' .. s_Try .. ')')
		else
			m_Logger:Write('View "' .. l_View .. '" was loaded.')
		end
	end

	for _, l_Dialog in pairs(self.m_Popups) do
		local s_Try = requireExists('UI/Dialogs/' .. l_Dialog)

		if (s_Try ~= true) then
			m_Logger:Error('Can\'t load Dialog: ' .. l_Dialog .. ' (' .. s_Try .. ')')
		else
			m_Logger:Write('Dialog "' .. l_Dialog .. '" was loaded.')
		end
	end
end

--[[
	@method: __update

	This method checks whether all components have been loaded at runtime.
]]
function UI:__update()
	for _, l_Dialog in pairs(self.m_Popups) do
		if (self.m_Dialogs[l_Dialog] == nil) then
			if (_G[l_Dialog] ~= nil) then
				local s_Instance = _G[l_Dialog]

				if (s_Instance ~= nil) then
					self.m_Dialogs[l_Dialog] = s_Instance
					self.m_Inited = self.m_Inited + 1
				end
			end
		end
	end

	for _, l_View in pairs(self.m_Load) do
		if (self.m_Views[l_View] == nil) then
			if (_G[l_View] ~= nil) then
				local s_Instance = _G[l_View](self)

				if (s_Instance ~= nil) then
					if (s_Instance['GetName'] ~= nil) then
						if (s_Instance['InitializeComponent'] ~= nil) then
							s_Instance:InitializeComponent()
						end

						self.m_Views[l_View] = s_Instance
						self.m_Loaded = self.m_Loaded + 1
					end
				end
			end
		end
	end

	if (self.m_Booted == #self.m_Boot and #self.m_Load == self.m_Loaded and #self.m_Popups == self.m_Inited) then
		self.m_Events.EngineUpdate:Unsubscribe()
	end
end

--[[
	@method: __action
	@parameter: player:Player | The player object that performs the action
	@parameter: type:string | The component type for the target
	@parameter: destination:string | The target for which the action is intended
	@parameter: action:string | The action performed by the player
	@parameter: data:table | The data to be used in the action

	All UI Actions will be handled here.
]]
function UI:__action(p_Player, p_Type, p_Destination, p_Action, p_Data)
	m_Logger:Write('Action { Type=' .. tostring(p_Type) .. ', Destination=' .. tostring(p_Destination) ..', Action=' .. tostring(p_Action) .. ', Data=' .. json.encode(p_Data) .. '}')

	if (p_Type == 'VIEW') then
		local s_View = self.m_Views[p_Destination]

		if (s_View == nil) then
			m_Logger:Write('The View "' .. p_Destination .. '" doesn\'t exists.')
			return
		end

		if PermissionManager:HasPermission(p_Player, 'UserInterface.' .. s_View:GetName()) == false then
			if (p_Action == 'HIDE' or p_Action == 'HIDING') then
				s_View:Hide(p_Player)
			else
				ChatManager:SendMessage('You have no permissions for this action (UserInterface.' .. s_View:GetName() .. ').', p_Player)
			end
		elseif (p_Action == 'SHOW' or p_Action == 'SHOWING') then
			s_View:Show(p_Player)
		elseif (p_Action == 'HIDE' or p_Action == 'HIDING') then
			s_View:Hide(p_Player)
		elseif (p_Action == 'TOGGLE') then
			s_View:Toggle(p_Player)
		elseif (p_Action == 'ACTIVATE') then
			s_View:Activate(p_Player)
		elseif (p_Action == 'DEACTIVATE') then
			s_View:Deactivate(p_Player)
		elseif (p_Action == 'ACTION' or p_Action == 'CALL') then
			local s_Element = nil
			local s_Name = nil

			if string.find(p_Data, '$') then
				local s_Parts = p_Data:split('$')
				s_Element = s_Parts[1]
				s_Name = s_Parts[2]
			else
				s_Name = p_Data
			end

			s_View:Call(p_Player, s_Element, s_Name)
		end
	end
end

--[[
	@method: Send
	@parameter: component:string | The component to be addressed in the action
	@parameter: receiver:Player | The recipient who is to receive the action
	@parameter: action:string | The action to be performed at the recipient
	@parameter: object:table | The data to be used in the action
]]
function UI:Send(p_Component, p_Receiver, p_Action, p_Object)
	local s_Kind = nil
	local s_Destination = nil
	local s_Data = nil

	if p_Component:__class() == 'View' then
		s_Kind = 'VIEW'
		s_Destination = p_Component:GetName()
	else
		m_Logger:Error('on Send: Unknown/Unimplemented Component "' .. p_Component:__class() .. '".')
		m_Logger:Write(debug.traceback())
		return
	end

	if p_Object ~= nil then
		local s_Error = nil
		s_Data, s_Error = json.encode(p_Object)

		if (s_Data == nil) then
			m_Logger:Error('Bad JSON: ' .. tostring(s_Error) .. ', ' .. tostring(p_Object))
			m_Logger:Write(debug.traceback())
			return
		end
	end

	if p_Receiver == nil then
		NetEvents:BroadcastLocal('UI', s_Kind, s_Destination, p_Action, s_Data)
		m_Logger:Write('Broadcast (' .. tostring(s_Kind) .. ' - ' .. tostring(s_Destination) .. ') ~> ' .. tostring(p_Action) .. ' ~> ' .. tostring(s_Data))
	else
		NetEvents:SendToLocal('UI', p_Receiver, s_Kind, s_Destination, p_Action, s_Data)
		m_Logger:Write('Send to ' .. tostring(p_Receiver.name) .. ' (' .. tostring(s_Kind) .. ' - ' .. tostring(s_Destination) .. ') ~> ' .. tostring(p_Action) .. ' ~> ' .. tostring(s_Data))
	end
end

if g_UI == nil then
	g_UI = UI()
end

return g_UI
