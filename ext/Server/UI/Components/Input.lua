--[[
	@class: Input
	@extends: Component
]]
class('Input');

--[[
	@method: __init
]]
function Input:__init(type, name, value)
	self.type		= type or nil;
	self.name		= name or nil;
	self.value		= value or nil;
	self.disabled	= false;
	self.arrows		= {};
end

--[[
	@method: __class
]]
function Input:__class()
	return 'Input';
end

--[[
	@method: GetName
]]
function Input:GetName()
	return self.name;
end

--[[
	@method: GetItems
]]
function Input:GetItems()
	return self.arrows;
end

--[[
	@method: HasItems
]]
function Input:HasItems()
	return #self.arrows >= 1;
end

--[[
	@method: AddArrow
]]
function Input:AddArrow(position, character, callback)
	if (_G['ArrowID'] == nil) then
		_G['ArrowID'] = 1;
	end
	
	_G['ArrowID']							= _G['ArrowID'] + 1;
	_G.Callbacks['Arrow#' .. _G['ArrowID']]	= callback;
	
	table.insert(self.arrows, {
		Type		= 'Arrow',
		Name		= 'Arrow#' .. _G['ArrowID'],
		Position 	= position,
		Character	= character,
		Callback	= callback
	});
end

--[[
	@method: Enable
]]
function Input:Enable()
	self.disabled = false;
end

--[[
	@method: Disable
]]
function Input:Disable()
	self.disabled = true;
end

--[[
	@method: GetValue
]]
function Input:GetValue()
	return self.value;
end

--[[
	@method: SetValue
]]
function Input:SetValue(value)
	self.value = value;
end

--[[
	@method: Serialize
]]
function Input:Serialize()
	return {
		Type		= self.type,
		Name		= self.name,
		Value		= self.value,
		Disabled	= self.disabled,
		Arrows		= self.arrows
	};
end

return Input;