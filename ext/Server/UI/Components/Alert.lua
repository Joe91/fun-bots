class('Alert')

function Alert:__init(position, color, text, delay)
	self.attributes = {}
	self.text = text or nil
	self.color = color or nil
	self.delay = delay or 1000
	self.position = position or nil

	table.insert(self.attributes, {
		Name = 'Position',
		Value = self.position
	})
end

function Alert:__class()
	return 'Alert'
end

function Alert:GetAttributes()
	return self.attributes
end

function Alert:Serialize()
	return {
		Text = self.text,
		Color = self.color,
		Delay = self.delay
	}
end

return Alert
