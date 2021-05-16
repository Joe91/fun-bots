class('QuickShortcut')

function QuickShortcut:__init(name)
	self.name		= name or nil
	self.enabled	= true
	self.numpad		= {}
	self.help		= {}
	self.attributes	= {}
end

function QuickShortcut:__class()
	return 'QuickShortcut'
end

function QuickShortcut:GetAttributes()
	return self.attributes
end

function QuickShortcut:SetPosition(flag, position)
	table.insert(self.attributes, {
		Name		= 'Position',
		Value		= {
			Type		= flag,
			Position	= position
		}
	})

	return self
end

function QuickShortcut:IsEnabled()
	return self.enabled
end

function QuickShortcut:Enable()
	self.enabled = true
end

function QuickShortcut:Disable()
	self.enabled = false
end

function QuickShortcut:AddNumpad(key, text)
	table.insert(self.numpad, {
		Key		= key,
		Text	= text
	})
end

function QuickShortcut:AddHelp(key, text)
	table.insert(self.help, {
		Key		= key,
		Text	= text
	})
end

function QuickShortcut:Serialize()
	return {
		Name = self.name,
		Disabled = not self.enabled,
		Numpad = self.numpad,
		Help = self.help
	}
end

return QuickShortcut
