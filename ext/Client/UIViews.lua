class 'UIViews';

require('__shared/ArrayMap');

function UIViews:__init()
	self._webui = false;
	self._views = ArrayMap();
	
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded);
	Events:Subscribe('UI_Close', self, self._onUIClose);
end

-- Events
function UIViews:_onExtensionLoaded()
	WebUI:Init();
	WebUI:Hide();
end

function UIViews:_onUIClose(name)
	-- @ToDo name of closing view
	if self:_isVisible() then
		if self._views:isEmpty() then
			self:_hide();
		else
			self:_show();
		end
	end
end

function UIViews:_show()
	WebUI:Show();
	self._webui = true;
end

function UIViews:_hide()
	WebUI:Hide();
	self:disable();
	self._webui = false;
end

function UIViews:enable()
	WebUI:EnableMouse();
	WebUI:EnableKeyboard();
end

function UIViews:disable()
	WebUI:ResetMouse();
	WebUI:ResetKeyboard();
end

function UIViews:_isVisible()
	return (self._webui ~= false);
end

function UIViews:focus()
	self:enable();
end

function UIViews:blur()
	self:disable();
end

function UIViews:show(name)
	if self._views:exists(name) then
		self._views:delete(name);	
	end
	
	self._views:add(name);
	WebUI:ExecuteJS('BotEditor.show(\'' .. name .. '\');');
	self:_handleViewManagement();
end

function UIViews:hide(name)
	if self._views:exists(name) then
		self._views:delete(name);	
	end
	
	WebUI:ExecuteJS('BotEditor.hide(\'' .. name .. '\');');
	self:_handleViewManagement();
end

function UIViews:error(name, text)
	WebUI:ExecuteJS('BotEditor.error(\'' .. name .. '\', \'' .. text .. '\');');
end

function UIViews:_handleViewManagement()
	if self._views:isEmpty() then
		self:_hide();
	else
		self:_show();
	end
end

return UIViews;