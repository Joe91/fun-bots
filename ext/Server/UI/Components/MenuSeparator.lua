--[[
	@class: MenuSeparator
	@extends: Component
]]
class('MenuSeparator')

--[[
	@method: __init
]]
function MenuSeparator:__init(title)
	self.title = title or nil
end

--[[
	@method: __class
]]
function MenuSeparator:__class()
	return 'MenuSeparator'
end

--[[
	@method: Serialize
]]
function MenuSeparator:Serialize()
	return {
		Title = self.title
	}
end

return MenuSeparator
