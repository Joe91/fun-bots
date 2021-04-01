class('Entry');

function Entry:__init(name, text, value)
	self.name	= name or nil;
	self.text	= text or nil;
	self.value	= value or nil;
end

function Entry:__class()
	return 'Entry';
end

function Entry:GetText()
	return self.text;
end

function Entry:SetText(text)
	self.text = text;
end

function Entry:GetName()
	return self.name;
end

function Entry:GetValue()
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
		Name	= self.name,
		Text	= self.text,
		Value	= value
	};
end

return Entry;