class('MenuSeparator');

function MenuSeparator:__init(title)
	self.title		= title or nil;
end

function MenuSeparator:__class()
	return 'MenuSeparator';
end

function MenuSeparator:Serialize()
	return {
		Title		= self.title
	};
end

return MenuSeparator;