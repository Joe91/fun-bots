--[[
	@class: View
	@extends: Component
]]
class('View')

--[[
	@method: __init
]]
function View:__init(p_Core, p_Name)
	self.m_Core = p_Core
	self.m_Name = p_Name
	self.m_Components = {}
	self.m_Visible = false
end

--[[
	@method: __class
]]
function View:__class()
	return 'View'
end

--[[
	@method: GetCore
]]
function View:GetCore()
	return self.m_Core
end

--[[
	@method: GetName
]]
function View:GetName()
	return self.m_Name
end

--[[
	@method: AddComponent
]]
function View:AddComponent(p_Component)
	table.insert(self.m_Components, p_Component)
end

--[[
	@method: GetComponents
]]
function View:GetComponents()
	return self.m_Components
end

--[[
	@method: CallbackModify
]]
function View:CallbackModify(p_Destination)
	if (type(p_Destination) ~= 'table') then
		return p_Destination
	end

	for l_Name, l_Value in pairs(p_Destination) do
		if (l_Name == 'Callback') then
			if(type(l_Value) == 'function') then
				local s_Reference = ''

				if (p_Destination.Type ~= nil) then
					s_Reference = s_Reference .. p_Destination.Type
				end

				if (p_Destination.Type ~= nil and p_Destination.Name ~= nil) then
					s_Reference = s_Reference .. '$'
				end

				if (p_Destination.Name ~= nil) then
					s_Reference = s_Reference .. p_Destination.Name
				end

				p_Destination[l_Name] = 'UI:VIEW:' .. self.m_Name .. ':CALL:' .. s_Reference
			elseif (string.starts(l_Value, 'UI:') == false) then
				p_Destination[l_Name] = 'UI:VIEW:' .. self.m_Name .. ':ACTION:' .. l_Value
			end
		else
			l_Value = self:CallbackModify(l_Value)
		end
	end

	return p_Destination
end

--[[
	@method: Show
]]
function View:Show(p_Player)
	self:GetCore():Send(self, p_Player, 'SHOW', self:CallbackModify(self:Serialize(p_Player)))
	self.m_Visible = true
end

--[[
	@method: Remove
]]
function View:Remove(p_Player, p_Component)
	self:GetCore():Send(self, p_Player, 'REMOVE', {
		Type = p_Component:__class(),
		Name = p_Component:GetName()
	})
end

--[[
	@method: Push
]]
function View:Push(p_Player, p_Component)
	local s_Attributes = {}

	if (p_Component['GetAttributes'] ~= nil) then
		s_Attributes = p_Component:GetAttributes()
	end

	local s_Serialized = p_Component:Serialize(p_Player)

	if (#s_Attributes >= 1) then
		self:GetCore():Send(self, p_Player, 'PUSH', {
			Type = p_Component:__class(),
			Data = s_Serialized,
			Attributes = s_Attributes
		})
	else
		self:GetCore():Send(self, p_Player, 'PUSH', {
			Type = p_Component:__class(),
			Data = s_Serialized
		})
	end
end

--[[
	@method: Hide
]]
function View:Hide(p_Player)
	self:GetCore():Send(self, p_Player, 'HIDE')
	self.m_Visible = false
end

--[[
	@method: IsVisible
]]
function View:IsVisible()
	return self.m_Visible
end

--[[
	@method: Toggle
]]
function View:Toggle(p_Player)
	if (self:IsVisible()) then
		self:Hide(p_Player)
	else
		self:Show(p_Player)
	end
end

--[[
	@method: SubCall
]]
function View:SubCall(p_Player, p_Element, p_Name, p_Component)
	if (p_Component:__class() == p_Element and p_Component['HasItems'] == nil and p_Component['FireCallback'] ~= nil and p_Component['GetName'] ~= nil and p_Component:GetName() == p_Name) then
		--print('FireCallback ' .. name)
		p_Component:FireCallback(p_Player)

	elseif (p_Component['HasItems'] ~= nil and p_Component:HasItems()) then
		for _, l_Item in pairs(p_Component:GetItems()) do
			if (l_Item:__class() == p_Element) then
				if (l_Item['GetName'] ~= nil and l_Item:GetName() == p_Name and l_Item['FireCallback'] ~= nil) then
					--print('Sub-FireCallback ' .. name)
					l_Item:FireCallback(p_Player)

				elseif (l_Item['Name'] ~= nil and l_Item.Name == p_Element) then
					--print('Callback-Trigger ' .. name)
					l_Item:Callback(p_Player)

				else
					self:SubCall(p_Player, p_Element, p_Name, l_Item)
				end
			else
				self:SubCall(p_Player, p_Element, p_Name, l_Item)
			end
		end
	end
end

--[[
	@method: Call
]]
function View:Call(p_Player, p_Element, p_Name)
	if (_G.Callbacks[p_Name] ~= nil) then
		_G.Callbacks[p_Name](p_Player)
		return
	end

	for _, l_Component in pairs(self.m_Components) do
		self:SubCall(p_Player, p_Element, p_Name, l_Component)
	end
end

--[[
	@method: Activate
]]
function View:Activate(p_Player)
	self:GetCore():Send(self, p_Player, 'ACTIVATE')
end

--[[
	@method: Deactivate
]]
function View:Deactivate(p_Player)
	self:GetCore():Send(self, p_Player, 'DEACTIVATE')
end

--[[
	@method: Serialize
]]
function View:Serialize(p_Player)
	local s_Components = {}

	for _, l_Component in pairs(self.m_Components) do
		local s_Attributes = {}

		if (l_Component['GetAttributes'] ~= nil) then
			s_Attributes = l_Component:GetAttributes()
		end

		if (#s_Attributes >= 1) then
			table.insert(s_Components, {
				Type = l_Component:__class(),
				Data = l_Component:Serialize(p_Player),
				Attributes = s_Attributes
			})
		else
			table.insert(s_Components, {
				Type = l_Component:__class(),
				Data = l_Component:Serialize(p_Player)
			})
		end
	end

	return {
		Name = self.m_Name,
		Components = s_Components
	}
end

return View
