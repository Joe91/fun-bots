class('Dialog')

function Dialog:__init(name, title)
	self.name = name or nil
	self.title = title or nil
	self.buttons = {}
	self.content = nil
end

function Dialog:GetName()
	return self.name
end

function Dialog:__class()
	return 'Dialog'
end

function Dialog:AddButton(button, position, permission)
	if (button == nil or button['__class'] == nil) then
		-- Bad Item
		return
	end

	if (button:__class() ~= 'Button') then
		-- Exception: Only Button
		return
	end

	if position ~= nil then

	end

	if permission ~= nil then
		button:BindPermission(permission)
	end

	table.insert(self.buttons, button)
end

function Dialog:SetTitle(title)
	self.title = title
end

function Dialog:SetContent(content)
	self.content = content
end

function Dialog:Serialize(player)
	local buttons = {}

	for _, button in pairs(self.buttons) do
		table.insert(buttons, {
			Type = button:__class(),
			Data = button:Serialize()
		})
	end

	return {
		Name = self.name,
		Title = self.title,
		Content = self.content,
		Buttons = buttons
	}
end

return Dialog
