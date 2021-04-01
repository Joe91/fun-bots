class('Menu');

require('UI/Components/MenuItem');
require('UI/Components/MenuSeparator');

function Menu:__init()
	self.items		= {};
	self.attributes	= {};
end

function Menu:__class()
	return 'Menu';
end

function Menu:GetAttributes()
	return self.attributes;
end

function Menu:AddItem(item, permission)
	if (item == nil or item['__class'] == nil) then
		-- Bad Item
		return;
	end
	
	if (item:__class() ~= 'Menu' and item:__class() ~= 'MenuItem' and item:__class() ~= 'MenuSeparator') then
		-- Exception: Only Menu, MenuSeparator (-) or MenuItem
		return;
	end
	
	if permission ~= nil then
		item:BindPermission(permission);
	end
	
	table.insert(self.items, item);
end

function Menu:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= {
			Type		= flag,
			Position	= position
		}
	});
end

function Menu:HasItems()
	return #self.items >= 1;
end

function Menu:GetItems()
	return self.items;
end

function Menu:Serialize(player)
	local items = {};
	
	for _, item in pairs(self.items) do
		if item['GetPermission'] ~= nil then
			if item:GetPermission() == nil then
				table.insert(items, {
					Type = item:__class(),
					Data = item:Serialize(player)
				});
			elseif PermissionManager:HasPermission(player, item:GetPermission()) then
				table.insert(items, {
					Type = item:__class(),
					Data = item:Serialize(player)
				});
			end
		else
			table.insert(items, {
				Type = item:__class(),
				Data = item:Serialize(player)
			});
		end
	end
	
	return {
		Items		= items
	};
end

return Menu;