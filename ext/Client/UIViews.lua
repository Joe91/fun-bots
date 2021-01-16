class 'UIViews';

require('__shared/ArrayMap');

function UIViews:__init()
	self._webui = 0;
	self._views = ArrayMap();
	
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded);
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload);
	Events:Subscribe('UI_Close', self, self._onUIClose);
end

-- Events
function UIViews:_onExtensionUnload()
	self:close();
end

function UIViews:_onExtensionLoaded()
	WebUI:Init();
	self:close();
end

function UIViews:_onUIClose(name)
	-- @ToDo name of closing view
	if self:isVisible() and self._views:isEmpty() then
		self:close();
	end
end

-- Open the complete WebUI
function UIViews:open()
	WebUI:Show();
	self._webui = 1;
end

-- Close the complete WebUI
function UIViews:close()
	WebUI:Hide();
	self:disable();
	self._webui = 0;
end

-- Enable Mouse/Keyboard actions
function UIViews:enable()
	WebUI:EnableMouse();
	WebUI:EnableKeyboard();
end

-- Disable Mouse/Keyboard actions
function UIViews:disable()
	WebUI:ResetMouse();
	WebUI:ResetKeyboard();
end

-- Check if WebUI is visible
function UIViews:isVisible()
	return self._webui ~= 0;
end

function UIViews:focus()
	self:enable();
	-- @ToDo send focus to form-object
end

function UIViews:blur()
	self:disable();
	-- @ToDo remove focus to form-object
end

-- Show an view
function UIViews:show(name)
	if self._views:exists(name) then
		self._views:delete(name);	
	end
	
	self._views:add(name);
	WebUI:ExecuteJS('BotEditor.show(\'' .. name .. '\');');
	self:_handleViewManagement();
end

-- Hide an view
function UIViews:hide(name)
	if self._views:exists(name) then
		self._views:delete(name);	
	end
	
	WebUI:ExecuteJS('BotEditor.hide(\'' .. name .. '\');');
	self:_handleViewManagement();
end

-- Send an error to the specified view
function UIViews:error(name, text)
	WebUI:ExecuteJS('BotEditor.error(\'' .. name .. '\', \'' .. text .. '\');');
end

-- Handle WebUI when view-stack is empty
function UIViews:_handleViewManagement()
	if self._views:isEmpty() then
		self:close();
	else
		self:open();
	end
end

return UIViews;