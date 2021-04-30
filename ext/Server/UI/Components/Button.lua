class('Button');

function Button:__init(name, title, callback)
	self.name		= name or nil;
	self.title		= title or nil;
	self.callback	= callback or nil;
	self.permission	= nil;
	self.disabled	= false;
end

function Button:__class()
	return 'Button';
end

function Button:GetPermission()
	return self.permission;
end

function Button:SetCallback(callback)
	self.callback = callback;
end

function Button:BindPermission(permission)
	self.permission = permission;
end

function Button:Enable()
	self.disabled = false;
end

function Button:Disable()
	self.disabled = true;
end

function Button:Serialize()
	return {
		Name		= self.name,
		Title		= self.title,
		Disabled	= self.disabled,
		Permission	= self.permission
	};
end

return Button;