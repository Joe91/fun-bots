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
	if Config.disableUserInterface == true then
		m_Logger:Write('UserInterface is disabled by Configuration.')
		return
	end

	--[[
		@variable: boot

		Components to be loaded. If new components are to be added, they are described here.
	]]
	self.boot = {
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
	self.load = {
		'BotEditor',
		'WaypointEditor'
	}

	--[[
		@variable: popups

		Popups to be loaded. If new popups are to be added, they are described here.
	]]
	self.popups = {
		'Settings',
		'Confirmation'
	}

	-- Do not modify here
	_G.Callbacks = {}
	self.views = {}
	self.dialogs = {}
	self.booted = 0
	self.loaded = 0
	self.inited = 0

	self.events = {
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
function UI:GetView(name)
	if (self.views[name] ~= nil) then
		return self.views[name]
	end

	return nil
end

--[[
	@method: GetDialog
	@parameter: name:string | Name of the dialog to get
	@return: Dialog | nil

	Fetches an initialized dialog from the cache
]]
function UI:GetDialog(name, view)
	local reference = self.dialogs[name]
	local instance = nil

	if (reference ~= nil) then
		instance = reference()

		if instance ~= nil then
			if (instance['InitializeComponent'] ~= nil) then
				instance:InitializeComponent(view)
			end

			return instance
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
	for _, component in pairs(self.boot) do
		local try = requireExists('UI/Components/' .. component)

		if (try ~= true) then
			m_Logger:Error('Can\'t load Component: ' .. component .. ' (' .. try .. ')')
		else
			m_Logger:Write('Component "' .. component .. '" was loaded.')
			self.booted = self.booted + 1
		end
	end

	-- Load Views
	for _, view in pairs(self.load) do
		local try = requireExists('UI/Views/' .. view)

		if (try ~= true) then
			m_Logger:Error('Can\'t load View: ' .. view .. ' (' .. try .. ')')
		else
			m_Logger:Write('View "' .. view .. '" was loaded.')
		end
	end

	for _, dialog in pairs(self.popups) do
		local try = requireExists('UI/Dialogs/' .. dialog)

		if (try ~= true) then
			m_Logger:Error('Can\'t load Dialog: ' .. dialog .. ' (' .. try .. ')')
		else
			m_Logger:Write('Dialog "' .. dialog .. '" was loaded.')
		end
	end
end

--[[
	@method: __update

	This method checks whether all components have been loaded at runtime.
]]
function UI:__update()
	for _, dialog in pairs(self.popups) do
		if (self.dialogs[dialog] == nil) then
			if (_G[dialog] ~= nil) then
				local instance = _G[dialog]

				if (instance ~= nil) then
					self.dialogs[dialog] = instance
					self.inited = self.inited + 1
				end
			end
		end
	end

	for _, view in pairs(self.load) do
		if (self.views[view] == nil) then
			if (_G[view] ~= nil) then
				local instance = _G[view](self)

				if (instance ~= nil) then
					if (instance['GetName'] ~= nil) then
						if (instance['InitializeComponent'] ~= nil) then
							instance:InitializeComponent()
						end

						self.views[view] = instance
						self.loaded = self.loaded + 1
					end
				end
			end
		end
	end

	if (self.booted == #self.boot and #self.load == self.loaded and #self.popups == self.inited) then
		self.events.EngineUpdate:Unsubscribe()
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
function UI:__action(player, type, destination, action, data)
	m_Logger:Write('Action { Type=' .. tostring(type) .. ', Destination=' .. tostring(destination) ..', Action=' .. tostring(action) .. ', Data=' .. json.encode(data) .. '}')

	if (type == 'VIEW') then
		local view = self.views[destination]

		if (view == nil) then
			m_Logger:Write('The View "' .. destination .. '" doesn\'t exists.')
			return
		end

		if PermissionManager:HasPermission(player, 'UserInterface.' .. view:GetName()) == false then
			if (action == 'HIDE' or action == 'HIDING') then
				view:Hide(player)
			else
				ChatManager:SendMessage('You have no permissions for this action (UserInterface.' .. view:GetName() .. ').', player)
			end
		elseif (action == 'SHOW' or action == 'SHOWING') then
			view:Show(player)
		elseif (action == 'HIDE' or action == 'HIDING') then
			view:Hide(player)
		elseif (action == 'TOGGLE') then
			view:Toggle(player)
		elseif (action == 'ACTIVATE') then
			view:Activate(player)
		elseif (action == 'DEACTIVATE') then
			view:Deactivate(player)
		elseif (action == 'ACTION' or action == 'CALL') then
			local element = nil
			local name = nil

			if string.find(data, '$') then
				local parts = data:split('$')
				element = parts[1]
				name = parts[2]
			else
				name = data
			end

			view:Call(player, element, name)
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
function UI:Send(component, receiver, action, object)
	local kind = nil
	local destination = nil
	local data = nil

	if component:__class() == 'View' then
		kind = 'VIEW'
		destination	= component:GetName()
	else
		m_Logger:Error('on Send: Unknown/Unimplemented Component "' .. component:__class() .. '".')
		m_Logger:Write(debug.traceback())
		return
	end

	if object ~= nil then
		data, error = json.encode(object)

		if (data == nil) then
			m_Logger:Error('Bad JSON: ' .. tostring(error) .. ', ' .. tostring(object))
			m_Logger:Write(debug.traceback())
			return
		end
	end

	if receiver == nil then
		NetEvents:BroadcastLocal('UI', kind, destination, action, data)
		m_Logger:Write('Broadcast (' .. tostring(kind) .. ' - ' .. tostring(destination) .. ') ~> ' .. tostring(action) .. ' ~> ' .. tostring(data))
	else
		NetEvents:SendToLocal('UI', receiver, kind, destination, action, data)
		m_Logger:Write('Send to ' .. tostring(receiver.name) .. ' (' .. tostring(kind) .. ' - ' .. tostring(destination) .. ') ~> ' .. tostring(action) .. ' ~> ' .. tostring(data))
	end
end

-- Singleton.
if g_UI == nil then
	g_UI = UI()
end

return g_UI