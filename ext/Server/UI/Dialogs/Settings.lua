class('Settings')

function Settings:__init()
	self:InitializeComponent();
end

function Settings:InitializeComponent()
	-- Create Dialog
	-- Add Menu
	-- Add Buttons
	-- Add Content
		-- Add Tabs
end

function Settings:Open(view, player)
	view:Push(player, Alert(Position.Bottom_Center, Color.Red, 'Blah, Blah, Blah!', 2500));
end

return Settings;