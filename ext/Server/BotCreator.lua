---@class BotManager
---@overload fun():BotManager
BotCreator = class('BotCreator')


---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Logger
local m_Logger = Logger("BotCreator", Debug.Server.BOT)

function BotCreator:__init()
	---@type BotAttributes[]
	self.AllBotAttributs = {}
	self.BotAttributesByClass = {}
	self._InitDone = false
end

function BotCreator:CreateBotCharacters()
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

		local s_BotAttributes = BotAttributs
		s_BotAttributes.Accuracy = s_RelAccuracy
		s_BotAttributes.Kit = s_Kit
		s_BotAttributes.Name = l_Name
		s_BotAttributes.ReactionTime = s_RelReactionTime
		s_BotAttributes.Behaviour = s_Behaviour

		table.insert(self.AllBotAttributs, s_BotAttributes)
		table.insert(self.BotAttributesByClass[s_Kit], s_BotAttributes)
	end
end

if g_BotCreator == nil then
	---@type BotCreator
	g_BotCreator = BotCreator()
end

return g_BotCreator
