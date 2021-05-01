class('Box');

function Box:__init(color)
	self.attributes	= {};
	self.items		= {};
	self.color		= color or Color.White;
	self.hidden		= false;
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

function Box:AddItem(item)
	if (item == nil or item['__class'] == nil) then
		-- Bad Item
		return;
	end
	
	if (item:__class() ~= 'Entry') then
		-- Exception: Only Menu, MenuSeparator (-) or MenuItem
		return;
	end
	
	table.insert(self.items, item);
end

function Box:Hide()
	self.hidden = true;
end

function Box:Show()
	self.hidden = false;
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
		Items	= items,
		Hidden	= self.hidden
	};
end

return Box;