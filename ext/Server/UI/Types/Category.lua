--[[
	@class: Category
]]
class('Category')

--[[
	@method: __init
]]
function Category:__init(name, title)
	self.name = name
	self.title = title
	self.options = {}
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
	return self.name
end

--[[
	@method: GetTitle
]]
function Category:GetTitle()
	return self.title
end

--[[
	@method: AddOption
]]
function Category:AddOption(option)
	table.insert(self.options, option)
end

--[[
	@method: Serialize
]]
function Category:Serialize()
	local options = {}

	for _, option in pairs(self.options) do
		table.insert(options, option:Serialize())
	end

	return {
		Name = self.name,
		Title = self.title,
		Options = options
	}
end

return Category
