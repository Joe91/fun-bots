class('Box');

function Box:__init(color)
	self.attributes	= {};
	self.items		= {};
	self.color		= color or Color.White;
end

function Box:__class()
	return 'Box';
end

function Box:HasItems()
	return #self.items >= 1;
end

function Box:GetItems()
	return self.items;
end

function Box:GetAttributes()
	return self.attributes;
end

function Box:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= {
			Type		= flag,
			Position	= position
		}
	});
end

function Box:Serialize()
	local items = {};
	
	for _, item in pairs(self.items) do
		table.insert(items, {
			Type = item:__class(),
			Data = item:Serialize()
		});
	end
	
	return {
		Color	= self.color,
		Items	= items
	};
end

return Box;