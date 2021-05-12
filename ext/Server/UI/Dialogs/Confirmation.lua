class('Confirmation')

function Confirmation:__init()
	self.button_yes = nil;
	self.button_no 	= nil;
	self.dialog		= Dialog('confirmation', 'Confirmation');
end

function Confirmation:__class()
	return 'Confirmation';
end

function Confirmation:SetTitle(title)
	self.dialog:SetTitle(title);
end

function Confirmation:SetContent(content)
	self.dialog:SetContent(content);
end

function Confirmation:SetYes(callback)
	self.button_yes:SetCallback(callback);
end

function Confirmation:SetNo(callback)
	self.button_no:SetCallback(callback);
end

function Confirmation:InitializeComponent()
	self.button_yes = Button('button_confirmation_yes', 'Yes');
	self.dialog:AddButton(self.button_yes, Position.Left);
	
	self.button_no = Button('button_confirmation_no', 'No');
	self.dialog:AddButton(self.button_no, Position.Right);
end

function Confirmation:Serialize(player)
	return self.dialog:Serialize(player);
end

function Confirmation:Open(view, player)
	view:Push(player, self.dialog);
end

function Confirmation:Hide(view, player)
	view:Remove(player, self.dialog);
end

return Confirmation;