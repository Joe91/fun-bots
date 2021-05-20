--[[
	@class: Logo
	@extends: Component
]]
class('Logo')

--[[
	@method: __init
]]
function Logo:__init(p_Title, p_Subtitle)
	self.m_Title = p_Title or nil
	self.m_Subtitle = p_Subtitle or nil
	self.m_Attributes = {}
end

--[[
	@method: __class
]]
function Logo:__class()
	return 'Logo'
end

--[[
	@method: GetAttributes
]]
function Logo:GetAttributes()
	return self.m_Attributes
end

--[[
	@method: SetPosition
]]
function Logo:SetPosition(p_Flag, p_Position)
	table.insert(self.m_Attributes, {
		Name = 'Position',
		Value = {
			Type = p_Flag,
			Position = p_Position
		}
	})
end

--[[
	@method: Serialize
]]
function Logo:Serialize()
	return {
		Title = self.m_Title,
		Subtitle = self.m_Subtitle
	}
end

return Logo
