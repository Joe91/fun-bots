--[[
	@class: Settings
	@extends: Dialog
]]
class('Settings')

--[[
	@method: __init
]]
function Settings:__init()
	self.m_Dialog = Dialog('settings', 'Settings')
	self.m_Categories = {}

	-- Initialize Settings definitions
	for l_Name, l_Title in pairs(SettingsDefinition.Categorys) do
		table.insert(self.m_Categories, Category(l_Name, l_Title))
	end

	for _, l_Entry in pairs(SettingsDefinition.Elements) do
		local s_Option = Option(l_Entry.Name, l_Entry.Text, l_Entry.Description)
		local s_Category = self:GetCategory(l_Entry.Category)

		s_Option:SetType(l_Entry.Type)
		s_Option:SetValue(l_Entry.Value)
		s_Option:SetDefault(l_Entry.Default)

		if l_Entry.Type == Type.List or l_Entry.Type == Type.Enum or l_Entry.Type == Type.Integer or l_Entry.Type == Type.Float then
			s_Option:SetReference(l_Entry.Reference)
		end

		if s_Category == nil then
			print('Unknown Category: ' .. l_Entry.Category)
		else
			s_Category:AddOption(s_Option)
		end
	end
end

--[[
	@method: GetCategory
]]
function Settings:GetCategory(p_Name)
	local s_Result = nil

	for l_Reference, l_Category in pairs(self.m_Categories) do
		if l_Category:GetName() == p_Name or s_Result ~= nil then
			s_Result = l_Category
			break
		end
	end

	return s_Result
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
function Settings:InitializeComponent(p_View)
	-- Debug
	for _, l_Category in pairs(self.m_Categories) do
		print(g_Utilities:dump(l_Category:Serialize(), true, 5))
	end

	-- Add Menu

	-- Add Buttons
	self.m_Dialog:AddButton(Button('button_settings_cancel', 'Cancel', function(player)
		self:Hide(p_View, player)
	end), Position.Left)

	self.m_Dialog:AddButton(Button('button_settings_restore', 'Restore all to Default', function(player)
		print('[Settings] Button Restore')
	end), Position.Left, 'Settings.Restore')

	self.m_Dialog:AddButton(Button('button_settings_save_temporarily', 'Save Temporarily', function(player)
		print('[Settings] Button Temporarily')
		self:Hide(p_View, player)
	end), Position.Right, 'Settings.Save')

	self.m_Dialog:AddButton(Button('button_settings_save', 'Save', function(player)
		print('[Settings] Button Save')
		self:Hide(p_View, player)
	end), Position.Right, 'Settings.Save')

	-- Add Content
		-- Add Tabs

	print(g_Utilities:dump(self.m_Dialog, true, 1))
end

--[[
	@method: Serialize
]]
function Settings:Serialize(p_Player)
	return self.m_Dialog:Serialize(p_Player)
end

--[[
	@method: Open
]]
function Settings:Open(p_View, p_Player)
	p_View:Push(p_Player, self.m_Dialog)
end

--[[
	@method: Hide
]]
function Settings:Hide(p_View, p_Player)
	p_View:Remove(p_Player, self.m_Dialog)
end

return Settings
