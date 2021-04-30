class('Text');

function Text:__init(name, text)
	self.name		= name or nil;
	self.text		= text or nil;
	self.icon		= nil;
	self.disabled	= false;
	self.attributes	= {};
end

function Text:__class()
	return 'Text';
end

function Text:GetAttributes()
	return self.attributes;
end

function Text:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= {
			Type		= flag,
			Position	= position
		}
	});
	
	return self;
end

function Text:GetName()
	return self.name;
end

function Text:GetText()
	return self.text;
end

function Text:SetText(text)
	self.text = text;
	
	return self;
end

function Text:Enable()
	self.disabled = false;
	
	return self;
end

function Text:Disable()
	self.disabled = true;
	
	return self;
end

function Text:SetIcon(icon)
	self.icon = icon;
	
	return self;
end

function Text:Serialize()
	return {
		Name		= self.name,
		Text		= self.text,
		Icon		= self.icon,
		Disabled	= self.disabled
	};
end

return Text;