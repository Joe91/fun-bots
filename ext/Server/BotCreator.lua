---@class BotCreator
---@overload fun():BotCreator
BotCreator = class('BotCreator')


---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Logger
local m_Logger = Logger("BotCreator", Debug.Server.BOT_CREATION)

function BotCreator:__init()
	---@type BotAttributes[]
	self.AllBotAttributs = {}
	self.BotAttributesByClass = {}

	self.ActiveBotNames = {}
	self.IgnoreBotNames = {}
	self._InitDone = false
end

function BotCreator:CreateBotAttributes()
	local s_NumberOfBotsPerKit = math.floor(#BotNames / 4)

	for _, l_Kit in pairs(BotKits) do
		self.BotAttributesByClass[l_Kit] = {}
	end

	-- create bot-attributes out of each class
	for l_Index, l_Name in pairs(BotNames) do
		local s_IndexInKit = math.floor(l_Index / 4)
		local s_Kit = nil
		if l_Index % 4 == 0 then -- assault
			s_Kit = BotKits.Assault
		elseif l_Index % 4 == 1 then --engineer
			s_Kit = BotKits.Engineer
		elseif l_Index % 4 == 2 then --support
			s_Kit = BotKits.Support
		else                   -- recon
			s_Kit = BotKits.Recon
		end

		local s_RelSkill = s_IndexInKit / s_NumberOfBotsPerKit
		local s_RelReactionTime = 1.0 - s_RelSkill
		local s_RelAccuracy = s_RelSkill

		local s_Behaviour = s_IndexInKit % BotBehavior.COUNT
		local s_Color = s_IndexInKit % (BotColors.Count - 1) + 1

		local s_BotAttributes = BotAttributs
		s_BotAttributes.Accuracy = s_RelAccuracy
		s_BotAttributes.Kit = s_Kit
		s_BotAttributes.Name = l_Name
		s_BotAttributes.ReactionTime = s_RelReactionTime
		s_BotAttributes.Behaviour = s_Behaviour
		s_BotAttributes.Color = s_Color

		table.insert(self.AllBotAttributs, s_BotAttributes)
		table.insert(self.BotAttributesByClass[s_Kit], s_BotAttributes)
	end
	m_Logger:Write("BotAttributes of " .. #self.AllBotAttributs .. " Bots created")
end

function BotCreator:GetNextBotName(p_BotKit)
	local s_PossibleAttributes = {}

	for l_Index, l_Attributes in pairs(self.BotAttributesByClass[p_BotKit]) do
		local s_NameAvailable = true
		for _, l_UsedNames in self.ActiveBotNames do
			if l_Attributes.Name == l_UsedNames then
				s_NameAvailable = false
				break
			end
		end
		for _, l_PlayerName in self.IgnoreBotNames do
			if l_Attributes.Name == l_PlayerName then
				s_NameAvailable = false
				break
			end
		end

		if s_NameAvailable then
			table.insert(s_PossibleAttributes, l_Attributes)
		end
	end
	-- local s_SelectedAttribute = s_PossibleAttributes[MathUtils:GetRandomInt(1, #s_PossibleAttributes)]
	local s_SelectedAttribute = s_PossibleAttributes[1] -- don't randomize them for now
	table.insert(self.ActiveBotNames, s_SelectedAttribute.Name)
	--return
	return s_SelectedAttribute.Name
end

function BotCreator:SetAttributesToBot(p_Bot)
	local s_Attributes = self:GetAttributesOfBot(p_Bot.m_Name)
	p_Bot.m_Kit = s_Attributes.Kit
	p_Bot.m_Color = s_Attributes.Color
	p_Bot.m_Attributes = s_Attributes
end

function BotCreator:RemoveActiveBot(p_BotName)
	for l_Index, l_Name in pairs(self.ActiveBotNames) do
		if (l_Name == p_BotName) then
			table.remove(self.ActiveBotNames, l_Index)
		end
	end
end

function BotCreator:GetAttributesOfBot(p_BotName)
	for _, l_Attributes in pairs(self.AllBotAttributs) do
		if l_Attributes.Name == p_BotName then
			return l_Attributes
		end
	end
end

function BotCreator:SetIgnoreName(p_Name)
	table.insert(self.IgnoreBotNames, p_Name)
end

function BotCreator:RemoveIgnoreName(p_Name)
	for l_Index, l_Name in pairs(self.IgnoreBotNames) do
		if (l_Name == p_Name) then
			table.remove(self.IgnoreBotNames, l_Index)
		end
	end
end

if g_BotCreator == nil then
	---@type BotCreator
	g_BotCreator = BotCreator()
end

return g_BotCreator
