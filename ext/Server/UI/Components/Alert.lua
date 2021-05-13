--[[
	@class: Alert
	@extends: Component
	
	The Alert component can be used to send messages to a player's UI.
]]
class('Alert');

--[[
	@method: __init
	@parameter: position:Position | The position of the alert
	@parameter: color:Color | The color of the alert
	@parameter: text:string | The text of the alert
	@parameter: delay:int | Specifies how many milliseconds the alert is displayed (Default: `1000`)
]]
function Alert:__init(position, color, text, delay)
	self.attributes	= {};
	self.text		= text or nil;
	self.color		= color or nil;
	self.delay		= delay or 1000;
	self.position	= position or nil;
	
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= self.position
	});
end

--[[
	@method: __class
	@return: string
]]
function Alert:__class()
	return 'Alert';
end

--[[
	@method: GetAttributes
	@return: table
]]
function Alert:GetAttributes()
	return self.attributes;
end

--[[
	@method: Serialize
	@return: table
]]
function Alert:Serialize()
	return {
		Text	= self.text,
		Color	= self.color,
		Delay	= self.delay
	};
end

return Alert;