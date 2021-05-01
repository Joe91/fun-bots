class('Logo');

function Logo:__init(title, subtitle)
	self.title		= title or nil;
	self.subtitle	= subtitle or nil;
	self.attributes	= {};
end

function Logo:__class()
	return 'Logo';
end

function Logo:GetAttributes()
	return self.attributes;
end

function Logo:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= {
			Type		= flag,
			Position	= position
		}
	});
end

function Logo:Serialize()
	return {
		Title		= self.title,
		Subtitle	= self.subtitle
	};
end

return Logo;