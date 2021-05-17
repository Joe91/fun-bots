--[[
	@class: Alert
	@extends: Component

	The Alert component can be used to send messages to a player's UI.
]]
class('Alert')

--[[
	@method: __init
	@parameter: position:Position | The position of the alert
	@parameter: color:Color | The color of the alert
	@parameter: text:string | The text of the alert
	@parameter: delay:int | Specifies how many milliseconds the alert is displayed (Default: `1000`)
]]
function Alert:__init(p_Position, p_Color, p_Text, p_Delay)
	self.m_Attributes = {}
	self.m_Text = p_Text or nil
	self.m_Color = p_Color or nil
	self.m_Delay = p_Delay or 1000
	self.m_Position = p_Position or nil

	table.insert(self.m_Attributes, {
		Name = 'Position',
		Value = self.m_Position
	})
end

--[[
	@method: __class
	@return: string
]]
function Alert:__class()
	return 'Alert'
end

--[[
	@method: GetAttributes
	@return: table
]]
function Alert:GetAttributes()
	return self.m_Attributes
end

--[[
	@method: Serialize
	@return: table
]]
function Alert:Serialize()
	return {
		Text = self.m_Text,
		Color = self.m_Color,
		Delay = self.m_Delay
	}
end

return Alert
