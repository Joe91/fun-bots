---@class BotCreator
---@overload fun():BotCreator
BotCreator = class('BotCreator')

---@type Logger
local m_Logger = Logger("BotCreator", Debug.Server.BOT_CREATION)

function BotCreator:__init()
	---@type BotAttributes[]
	self.AllBotAttributes = {}

	self.BotAttributesByClass = {}
	self.BotAttributesByTeamByClass = {}

	self.ActiveBotNames = {}
	self.ActiveTeamBotNames = {}

	self._InitDone = false
end

function BotCreator:CreateBotAttributes()
	-- create bot-attributes out of each class
	self:GenerateBotAtributes(USMarinesNames, 1)
	self:GenerateBotAtributes(RUMilitaryNames, 2)
	self:GenerateBotAtributes(BotNames, 0)

	print("The Team Table")
	m_Logger:Write(self.BotAttributesByTeamByClass)
	print("Each Kit inside the teams")
	for team, kitTable in pairs(self.BotAttributesByTeamByClass) do
		print(" The team: " .. team)
		m_Logger:Write(kitTable)
		for kit, attributes in pairs(kitTable) do
			print(" The kit: " .. kit)
			m_Logger:Write(attributes)
		end
	end



	m_Logger:Write("BotAttributes of " .. #self.AllBotAttributes .. " Bots created")
end

---@param p_botNames {}
function BotCreator:GenerateBotAtributes(p_botNames, p_teamId)
	local s_NumberOfBotsPerKit = math.floor(#BotNames / 4)
	self.BotAttributesByTeamByClass[p_teamId] = {}
	for _, l_Kit in pairs(BotKits) do
		self.BotAttributesByTeamByClass[p_teamId][l_Kit] = {}
	end
	for _, l_Kit in pairs(BotKits) do
		self.BotAttributesByClass[l_Kit] = {}
	end
	for l_Index, l_Name in pairs(p_botNames) do
		local s_Name = Registry.COMMON.BOT_TOKEN .. l_Name
		local s_IndexInKit = math.floor(l_Index / 4)
		local s_Kit = nil
		if l_Index % 4 == 1 then -- assault
			s_Kit = BotKits.Assault
		elseif l_Index % 4 == 2 then --engineer
			s_Kit = BotKits.Engineer
		elseif l_Index % 4 == 3 then --support
			s_Kit = BotKits.Support
		else                   -- recon
			s_Kit = BotKits.Recon
		end

		local s_RelSkill = s_IndexInKit / s_NumberOfBotsPerKit
		-- additional reaction time from 0 to 1
		local s_RelReactionTime = 0.5 - s_RelSkill
		if s_RelReactionTime < 0.0 then
			s_RelReactionTime = s_RelReactionTime + 1.0
		end
		-- set accuracy to skill level
		local s_RelAccuracy = s_RelSkill

		-- rotate behavior over each class
		local s_Behaviour = s_IndexInKit % BotBehavior.COUNT
		-- rotate colors of the bots
		local s_Color = s_IndexInKit % (BotColors.Count - 1) + 1
		if Config.BotColor ~= BotColors.RANDOM_COLOR then
			s_Color = Config.BotColor
		end

		local s_BotAttributes = {
			Name = s_Name,
			Kit = s_Kit,
			Color = s_Color,
			Skill = s_RelSkill,
			Behaviour = s_Behaviour,
			ReactionTime = s_RelReactionTime,
			Accuracy = s_RelAccuracy,
			PrefWeapon = "",
			PrefVehicle = ""
		}
		if p_teamId > 0 then
			table.insert(self.BotAttributesByTeamByClass[p_teamId][s_Kit], s_BotAttributes)
		else
			table.insert(self.BotAttributesByClass[s_Kit], s_BotAttributes)
		end
		table.insert(self.AllBotAttributes, s_BotAttributes)
	end
end

---@param p_BotKit BotKits|integer
function BotCreator:GetNextBotName(p_BotKit, p_teamId)
	print("The team id: " .. p_teamId)
	print("The bot kit: " .. p_BotKit)

	local s_PossibleNames = {}
	local botTattributesByClass = {}
	local activeNames

	if Config.BotTeamNames then
		botTattributesByClass = self.BotAttributesByTeamByClass[p_teamId]
		activeNames = self.ActiveBotNames
	else
		botTattributesByClass = self.BotAttributesByClass
		activeNames = self.ActiveTeamBotNames
	end
	for l_Index, l_Attributes in pairs(botTattributesByClass[p_BotKit]) do
		local s_NameAvailable = true
		for _, l_UsedNames in pairs(activeNames) do
			if l_Attributes.Name == l_UsedNames then
				s_NameAvailable = false
				break
			end
		end
		for _, l_PlayerName in pairs(Globals.IgnoreBotNames) do
			if l_Attributes.Name == l_PlayerName then
				s_NameAvailable = false
				break
			end
		end
		--TODO: check for existing player or Bot?

		if s_NameAvailable then
			table.insert(s_PossibleNames, l_Attributes.Name)
		end
	end
	local s_SelectedName = s_PossibleNames[MathUtils:GetRandomInt(1, #s_PossibleNames)]
	-- local s_SelectedAttribute = s_PossibleNames[1] -- don't randomize them for now
	table.insert(activeNames, s_SelectedName)
	return s_SelectedName
end

---@param p_Bot Bot
function BotCreator:SetAttributesToBot(p_Bot)
	local s_Attributes = self:GetAttributesOfBot(p_Bot.m_Name)
	p_Bot.m_Kit = s_Attributes.Kit
	p_Bot.m_Color = s_Attributes.Color
	p_Bot.m_Behavior = s_Attributes.Behaviour
	p_Bot.m_Reaction = s_Attributes.ReactionTime
	p_Bot.m_Accuracy = s_Attributes.Accuracy
	p_Bot.m_Skill = s_Attributes.Skill
	p_Bot.m_PrefWeapon = s_Attributes.PrefWeapon
	p_Bot.m_PrefVehicle = s_Attributes.PrefVehicle
end

---@param p_BotName string
function BotCreator:RemoveActiveBot(p_BotName)
	for l_Index, l_Name in pairs(self.ActiveBotNames) do
		if (l_Name == p_BotName) then
			table.remove(self.ActiveBotNames, l_Index)
		end
	end
end

---@param p_BotName string
function BotCreator:GetAttributesOfBot(p_BotName)
	for _, l_Attributes in pairs(self.AllBotAttributes) do
		if l_Attributes.Name == p_BotName then
			return l_Attributes
		end
	end
end

if g_BotCreator == nil then
	---@type BotCreator
	g_BotCreator = BotCreator()
end

return g_BotCreator
