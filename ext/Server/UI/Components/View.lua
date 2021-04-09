class('View');

function View:__init(core, name)
	self.core		= core;
	self.name		= name;
	self.components = {};
	self.visible	= false;
end

function View:__class()
	return 'View';
end

function View:GetCore()
	return self.core;
end

function View:GetName()
	return self.name;
end

function View:AddComponent(component)
	table.insert(self.components, component);
end

function View:GetComponents()
	return self.components;
end

function View:CallbackModify(destination)
	if (type(destination) ~= 'table') then
		return destination;
	end
	
	for name, value in pairs(destination) do
		if (name == 'Callback') then
			if(type(value) == 'function') then
				local reference = '';
				
				if (destination.Type ~= nil) then
					reference = reference .. destination.Type;
				end
				
				if (destination.Type ~= nil and destination.Name ~= nil) then
					reference = reference .. '$';
				end
				
				if (destination.Name ~= nil) then
					reference = reference .. destination.Name;
				end
				
				destination[name] = 'UI:VIEW:' .. self.name .. ':CALL:' .. reference;
			elseif (string.starts(value, 'UI:') == false) then
				destination[name] = 'UI:VIEW:' .. self.name .. ':ACTION:' .. value;
			end
		else
			value = self:CallbackModify(value);
		end
	end
	
	return destination; 
end

function View:Show(player)
	self:GetCore():Send(self, player, 'SHOW', self:CallbackModify(self:Serialize(player)));
	self.visible	= true;
end

function View:Push(player, component)
	local attributes = {};
	
	if (component['GetAttributes'] ~= nil) then
		attributes = component:GetAttributes();
	end
	
	local serialized = component:Serialize(player);

	if (#attributes >= 1) then
		self:GetCore():Send(self, player, 'PUSH', {
			Type 		= component:__class(),
			Data 		= serialized,
			Attributes	= attributes
		});
	else
		self:GetCore():Send(self, player, 'PUSH', {
			Type 		= component:__class(),
			Data 		= serialized
		});
	end
end

function View:Hide(player)
	self:GetCore():Send(self, player, 'HIDE');
	self.visible	= false;
end

function View:IsVisible()
	return self.visible;
end

function View:Toggle(player)
	if (self:IsVisible()) then
		self:Hide(player)
	else
		self:Show(player)
	end
end

function View:SubCall(player, element, name, component)	
	if (component:__class() == element and component['HasItems'] == nil and component['FireCallback'] ~= nil and component['GetName'] ~= nil and component:GetName() == name) then
		print('FireCallback ' .. name);
		component:FireCallback(player);
		
	elseif (component['HasItems'] ~= nil and component:HasItems()) then
		for _, item in pairs(component:GetItems()) do
			if (item:__class() == element) then
				if (item['GetName'] ~= nil and item:GetName() == name and item['FireCallback'] ~= nil) then
					print('Sub-FireCallback ' .. name);
					item:FireCallback(player);
					
				elseif (item['Name'] ~= nil and item.Name == element) then
					print('Callback-Trigger ' .. name);
					item:Callback(player);
					
				else
					self:SubCall(player, element, name, item);
				end
			else
				self:SubCall(player, element, name, item);
			end
		end
	end
end

function View:Call(player, element, name)
	if (_G.Callbacks[name] ~= nil) then
		_G.Callbacks[name](player);
		return;
	end
	
	for _, component in pairs(self.components) do
		self:SubCall(player, element, name, component);
	end
end

function View:Activate(player)
	self:GetCore():Send(self, player, 'ACTIVATE');
end

function View:Deactivate(player)
	self:GetCore():Send(self, player, 'DEACTIVATE');
end

function View:Serialize(player)
	local components = {};
	
	for _, component in pairs(self.components) do
		local attributes = {};
		
		if (component['GetAttributes'] ~= nil) then
			attributes = component:GetAttributes();
		end
		
		if (#attributes >= 1) then
			table.insert(components, {
				Type 		= component:__class(),
				Data 		= component:Serialize(player),
				Attributes	= attributes
			});
		else
			table.insert(components, {
				Type 		= component:__class(),
				Data 		= component:Serialize(player)
			});
		end
	end
	
	return {
		Name		= self.name,
		Components	= components
	};
end

return View;