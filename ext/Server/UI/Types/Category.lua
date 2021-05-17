--[[
	@class: Category
]]
class('Category')

--[[
	@method: __init
]]
function Category:__init(p_Name, p_Title)
	self.m_Name = p_Name
	self.m_Title = p_Title
	self.m_Options = {}
end

--[[
	@method: __class
]]
function Category:__class()
	return 'Category'
end

--[[
	@method: GetName
]]
function Category:GetName()
	return self.m_Name
end

--[[
	@method: GetTitle
]]
function Category:GetTitle()
	return self.m_Title
end

--[[
	@method: AddOption
]]
function Category:AddOption(p_Option)
	table.insert(self.m_Options, p_Option)
end

--[[
	@method: Serialize
]]
function Category:Serialize()
	local s_Options = {}

	for _, l_Option in pairs(self.m_Options) do
		table.insert(s_Options, l_Option:Serialize())
	end

	return {
		Name = self.m_Name,
		Title = self.m_Title,
		Options = s_Options
	}
end

return Category
