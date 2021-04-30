class('Input');

function Input:__init(type, name, value)
	self.type		= type or nil;
	self.name		= name or nil;
	self.value		= value or nil;
	self.disabled	= false;
	self.arrows		= {};
end

function Input:__class()
	return 'Input';
end

function Input:GetName()
	return self.name;
end

function Input:GetItems()
	return self.arrows;
end

function Input:HasItems()
	return #self.arrows >= 1;
end

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

function Input:Enable()
	self.disabled = false;
end

function Input:Disable()
	self.disabled = true;
end

function Input:GetValue()
	return self.value;
end

function Input:SetValue(value)
	self.value = value;
end

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