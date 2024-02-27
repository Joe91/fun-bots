---@class BotAttributes
---@field Name string
---@field Kit BotKits|integer
---@field Skill number
---@field Behaviour BotBehavior[]|integer
---@field ReactionTime integer
---@field Accuracy integer
---@field PrefWeapon string
---@field PrefVehicle string

BotAttributs = {
	Name = "",
	Kit = BotKits.RANDOM_KIT,
	Skill = 0.0,
	Behaviour = { BotBehavior.Default },
	ReactionTime = 0.0,
	Accuracy = 0.0,
	PrefWeapon = "",
	PrefVehicle = ""
}
