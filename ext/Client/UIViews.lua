---@class UIViews
---@overload fun():UIViews
UIViews = class 'UIViews'

require('__shared/ArrayMap')

function UIViews:__init()
	self._views = ArrayMap()
	-- Events:Subscribe('UI_Close', self, self._onUIClose) 
end

-- Events. 
function UIViews:OnExtensionLoaded()
	WebUI:Init()
	WebUI:Show()
	self:setLanguage(Config.Language)
	self:disable()
end

function UIViews:OnExtensionUnloading()
	self:disable()
	WebUI:Hide()
end

function UIViews:_onUIClose(p_Name)
	-- To-do: p_Name of closing view. 
	-- if self:isVisible() and self._views:isEmpty() then 
	-- self:close() 
	-- end 
end

-- Open the complete WebUI. 
-- function UIViews:open() 
-- WebUI:Show() 
-- self._webui = 1 
-- end 

-- Close the complete WebUI. 
-- function UIViews:close() 
-- WebUI:Hide() 
-- self:disable() 
-- self._webui = 0 
-- end 

-- Enable Mouse/Keyboard actions. 
function UIViews:enable()
	WebUI:EnableMouse()
	WebUI:EnableKeyboard()
end

-- Enable Mouse/Keyboard actions. 
function UIViews:enableMouseOnly()
	WebUI:EnableMouse()
end

-- Disable Mouse/Keyboard actions. 
function UIViews:disable()
	WebUI:ResetMouse()
	WebUI:ResetKeyboard()
end

-- Check if WebUI is visible. 
-- function UIViews:isVisible() 
-- return self._webui ~= 0 
-- end 

function UIViews:focus()
	self:enable()
	-- To-do: send focus to form-object. 
end

function UIViews:focusMouse()
	self:enableMouseOnly()
	-- To-do: send focus to form-object. 
end

function UIViews:blur()
	self:disable()
	-- To-do: remove focus to form-object. 
end

-- Execute. 
function UIViews:execute(p_Script)
	WebUI:ExecuteJS(p_Script)
end

-- Change language. 
function UIViews:setLanguage(p_Name)
	if p_Name ~= nil then
		WebUI:ExecuteJS('BotEditor.loadLanguage(\'' .. p_Name .. '\')')
	end
end

-- Show a view. 
function UIViews:show(p_Name)
	if self._views:exists(p_Name) then
		self._views:delete(p_Name)
	end

	self._views:add(p_Name)
	WebUI:ExecuteJS('BotEditor.show(\'' .. p_Name .. '\')')
	-- self:_handleViewManagement() 
end

-- Hide a view. 
function UIViews:hide(p_Name)
	if self._views:exists(p_Name) then
		self._views:delete(p_Name)
	end

	WebUI:ExecuteJS('BotEditor.hide(\'' .. p_Name .. '\')')
	-- self:_handleViewManagement() 
end

-- Send an error to the specified view. 
function UIViews:error(p_Name, p_Text)
	WebUI:ExecuteJS('BotEditor.error(\'' .. p_Name .. '\', \'' .. p_Text .. '\')')
end

-- Handle WebUI when view-stack is empty. 
-- function UIViews:_handleViewManagement() 
-- if self._views:isEmpty() then 
-- self:close() 
-- else 
-- self:open() 
-- end 
-- end 

return UIViews
