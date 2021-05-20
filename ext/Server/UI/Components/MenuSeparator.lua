--[[
	@class: MenuSeparator
	@extends: Component
]]
class('MenuSeparator')

--[[
	@method: __init
]]
function MenuSeparator:__init(p_Title)
	self.m_Title = p_Title or nil
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
		Title = self.m_Title
	}
end

return MenuSeparator
