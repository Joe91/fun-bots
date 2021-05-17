--[[
	@class: Settings
	@extends: Dialog
]]
class('Settings')

--[[
	@method: __init
]]
function Settings:__init()
	self.dialog = Dialog('settings', 'Settings')
	self.categories = {}

	-- Initialize Settings definitions
	for name, title in pairs(SettingsDefinition.Categorys) do
		table.insert(self.categories, Category(name, title))
	end

	for _, entry in pairs(SettingsDefinition.Elements) do
		local option = Option(entry.Name, entry.Text, entry.Description)
		local category = self:GetCategory(entry.Category)

		option:SetType(entry.Type)
		option:SetValue(entry.Value)
		option:SetDefault(entry.Default)

		if entry.Type == Type.List or entry.Type == Type.Enum or entry.Type == Type.Integer or entry.Type == Type.Float then
			option:SetReference(entry.Reference)
		end

		if category == nil then
			print('Unknown Category: ' .. entry.Category)
		else
			category:AddOption(option)
		end
	end
end

--[[
	@method: GetCategory
]]
function Settings:GetCategory(name)
	local result = nil

	for reference, category in pairs(self.categories) do
		if category:GetName() == name or result ~= nil then
			result = category
			break
		end
	end

	return result
end

--[[
	@method: __class
]]
function Settings:__class()
	return 'Settings'
end

--[[
	@method: InitializeComponent
]]
function Settings:InitializeComponent(view)
	-- Debug
	for _, category in pairs(self.categories) do
		print(g_Utilities:dump(category:Serialize(), true, 5))
	end

	-- Add Menu

	-- Add Buttons
	self.dialog:AddButton(Button('button_settings_cancel', 'Cancel', function(player)
		self:Hide(view, player)
	end), Position.Left)

	self.dialog:AddButton(Button('button_settings_restore', 'Restore all to Default', function(player)
		print('[Settings] Button Restore')
	end), Position.Left, 'Settings.Restore')

	self.dialog:AddButton(Button('button_settings_save_temporarily', 'Save Temporarily', function(player)
		print('[Settings] Button Temporarily')
		self:Hide(view, player)
	end), Position.Right, 'Settings.Save')

	self.dialog:AddButton(Button('button_settings_save', 'Save', function(player)
		print('[Settings] Button Save')
		self:Hide(view, player)
	end), Position.Right, 'Settings.Save')

	-- Add Content
		-- Add Tabs

	print(g_Utilities:dump(self.dialog, true, 1))
end

--[[
	@method: Serialize
]]
function Settings:Serialize(player)
	return self.dialog:Serialize(player)
end

--[[
	@method: Open
]]
function Settings:Open(view, player)
	view:Push(player, self.dialog)
end

--[[
	@method: Hide
]]
function Settings:Hide(view, player)
	view:Remove(player, self.dialog)
end

return Settings
