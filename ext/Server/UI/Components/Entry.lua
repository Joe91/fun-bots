--[[
	@class: Entry
	@extends: Component
]]
class('Entry')

--[[
	@method: __init
]]
function Entry:__init(name, text, value)
	self.name = name or nil
	self.text = text or nil
	self.value = value or nil
end

--[[
	@method: __class
]]
function Entry:__class()
	return 'Entry'
end

--[[
	@method: GetText
]]
function Entry:GetText()
	return self.text
end

--[[
	@method: SetText
]]
function Entry:SetText(text)
	self.text = text
end

--[[
	@method: GetName
]]
function Entry:GetName()
	return self.name
end

--[[
	@method: GetValue
]]
function Entry:GetValue()
	return self.name
end

--[[
	@method: Serialize
]]
function Entry:Serialize()
	local value = nil

	if (type(self.value) == 'string') then
		value = self.value
	elseif (self.value['Serialize'] ~= nil) then
		value = self.value:Serialize()
	end

	return {
		Name = self.name,
		Text = self.text,
		Value = value
	}
end

return Entry
