class('CheckBox');

function CheckBox:__init(name, checked)
	self.name		= name or nil;
	self.checked	= checked or false;
	self.disabled	= false;
end

function CheckBox:__class()
	return 'CheckBox';
end

function CheckBox:GetName()
	return self.name;
end

function CheckBox:Enable()
	self.disabled = false;
end

function CheckBox:Disable()
	self.disabled = true;
end

function CheckBox:IsChecked()
	return self.checked;
end

function CheckBox:SetChecked(checked)
	self.checked = checked;
end

function CheckBox:Serialize()
	return {
		Name		= self.name,
		IsChecked	= self.checked,
		Disabled	= self.disabled
	};
end

return CheckBox;