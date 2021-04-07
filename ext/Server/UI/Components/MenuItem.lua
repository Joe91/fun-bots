class('MenuItem');

function MenuItem:__init(title, name, callback, shortcut)
	self.title		= title or nil;
	self.name		= name or nil;
	self.callback	= callback or nil;
	self.shortcut	= shortcut or nil;
	self.icon		= nil;
	self.items		= {};
	self.inputs		= {};
	self.checkboxes	= {};
	self.permission	= nil;
end

function MenuItem:__class()
	return 'MenuItem';
end

function MenuItem:BindPermission(permission)
	self.permission = permission;
end

function MenuItem:GetPermission()
	return self.permission;
end

function MenuItem:AddItem(item, permission)
	if (item == nil or item['__class'] == nil) then
		-- Bad Item
		return self;
	end
	
	if (item:__class() ~= 'MenuItem' and item:__class() ~= 'MenuSeparator') then
		-- Exception: Only Menu, MenuSeparator or MenuItem
		return self;
	end
	
	if permission ~= nil then
		item:BindPermission(permission);
	end
	
	table.insert(self.items, item);
	
	return self;
end

function MenuItem:SetIcon(file)
	self.icon = file;
	
	return self;
end

function MenuItem:GetItems()
	return self.items;
end

function MenuItem:HasItems()
	return #self.items >= 1;
end

function MenuItem:GetInputs()
	return self.inputs;
end

function MenuItem:HasInputs()
	return #self.inputs >= 1;
end

function MenuItem:GetCheckBoxes()
	return self.checkboxes;
end

function MenuItem:HasCheckBoxes()
	return #self.checkboxes >= 1;
end

-- Title
function MenuItem:GetTitle()
	return self.title;
end

function MenuItem:SetTitle(title)
	self.title = title;
	
	return self;
end

-- Name
function MenuItem:GetName()
	return self.name;
end

function MenuItem:SetName(name)
	self.name = name;
	
	return self;
end

-- Callback
function MenuItem:GetCallback()
	return self.callback;
end

function MenuItem:SetCallback(callback)
	self.callback = callback;
	
	return self;
end

function MenuItem:FireCallback(player)
	if (self.callback == nil) then
		print('MenuItem ' .. self.name .. ' has no Callback.');
		return;
	end
	
	if (type(self.callback) == 'string') then
		print('MenuItem ' .. self.name .. ' has an reference Callback.');
		return;
	end;
	
	if self.permission ~= nil then
		if PermissionManager:HasPermission(player, self.permission) == false then
			ChatManager:SendMessage('You have no permissions for this action (' .. self.permission .. ').', player);
			return self;
		end
	end
	
	self.callback(player);
	
	return self;
end

-- Shortcut
function MenuItem:GetShortcut()
	return self.shortcut;
end

function MenuItem:SetShortcut(shortcut)
	self.shortcut = shortcut;
	
	return self;
end

function MenuItem:HasShortcut()
	return (self.shortcut ~= nil);
end

-- CheckBox
function MenuItem:AddCheckBox(position, checkbox)
	if (checkbox == nil or checkbox['__class'] == nil) then
		-- Bad Item
		return self;
	end
	
	if (checkbox:__class() ~= 'CheckBox') then
		-- Exception: Only Menu, Separator (-) or MenuItem
		return self;
	end
	
	table.insert(self.checkboxes, {
		Position	= position,
		CheckBox	= checkbox
	});
	
	return self;
end

-- Input
function MenuItem:AddInput(position, input)
	if (input == nil or input['__class'] == nil) then
		-- Bad Item
		return self;
	end
	
	if (input:__class() ~= 'Input') then
		-- Exception: Only Menu, Separator (-) or MenuItem
		return self;
	end
	
	table.insert(self.inputs, {
		Position	= position,
		Input		= input
	});
	
	return self;
end

function MenuItem:Serialize(player)
	local items			= {};
	local inputs		= {};
	local checkboxes	= {};
	local callback		= nil;
	
	if (type(self.callback) == 'function') then
		callback	= 'MenuItem$' .. self.name;
	else
		callback	= self.callback;
	end
	
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
	
	for _, data in pairs(self.inputs) do
		table.insert(inputs, {
			Type		= data.Input:__class(),
			Data		= data.Input:Serialize(),
			Position	= data.Position
		});
	end
	
	for _, data in pairs(self.checkboxes) do
		table.insert(checkboxes, {
			Type		= data.CheckBox:__class(),
			Data		= data.CheckBox:Serialize(),
			Position	= data.Position
		});
	end
	
	if (#items >= 1) then
		return {
			Title		= self.title,
			Name		= self.name,
			Icon		= self.icon,
			Items		= items,
			Permission	= self.permission
		};
	end
	
	return {
		Title		= self.title,
		Name		= self.name,
		Icon		= self.icon,
		Callback	= callback,
		Shortcut	= self.shortcut,
		Inputs		= inputs,
		CheckBoxes	= checkboxes,
		Permission	= self.permission
	};
end

return MenuItem;