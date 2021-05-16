--[[
	@class: Button
	@extends: Component
	
	Creates an button
]]
class('Button');

function Button:__init(name, title, callback)
	if (_G['ButtonID'] == nil) then
		_G['ButtonID'] = 1;
	end
	
	_G['ButtonID']	= _G['ButtonID'] + 1;
	self.id			= _G['ButtonID'];
	self.name		= name or nil;
	self.title		= title or nil;
	self.callback	= callback or nil;
	self.permission	= nil;
	self.disabled	= false;
	
	if self.callback ~= nil then
		_G.Callbacks['Button#' .. self.name .. self.id]	= self.callback;
	end
end

function Button:__class()
	return 'Button';
end

function Button:GetName()
	return self.name;
end

function Button:GetPermission()
	return self.permission;
end

function Button:SetCallback(callback)
	self.callback = callback;
	_G.Callbacks['Button#' .. self.name .. self.id]	= self.callback;
end

function Button:BindPermission(permission)
	self.permission = permission;
end

function Button:Enable()
	self.disabled = false;
end

function Button:Disable()
	self.disabled = true;
end

function Button:Serialize()
	return {
		Name		= 'Button#' .. self.name .. self.id,
		Title		= self.title,
		Disabled	= self.disabled,
		Permission	= self.permission
	};
end

return Button;