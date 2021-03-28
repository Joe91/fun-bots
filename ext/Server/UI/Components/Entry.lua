class('Entry');

function Entry:__init(text, value)
	self.text	= text or nil;
	self.value	= value or nil;
end

function Entry:__class()
	return 'Entry';
end

function Entry:GetName()
	return self.name;
end

function Entry:Serialize()
	local value = nil;
	
	if (type(self.value) == 'string') then
		value = self.value;
	elseif (self.value['Serialize'] ~= nil) then
		value = self.value:Serialize();
	end
	
	return {
		Text	= self.text,
		Value	= value
	};
end

return Entry;