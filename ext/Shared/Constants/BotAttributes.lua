---@class BotAttributes
---@field Name string
---@field Kit BotKits|integer
---@field Color BotColors|integer
---@field Behaviour BotBehavior|integer
---@field ReactionTime number 0 = fastest, 1 = slowest
---@field Inaccuracy number 0 = best, 1 = worst aim
---@field PrefWeapon string
---@field PrefVehicle string

BotAttributs = {
	Name = "",
	Kit = BotKits.RANDOM_KIT,
	Color = BotColors.RANDOM_COLOR,
	Behaviour = BotBehavior.Default,
	ReactionTime = 0.0,
	Inaccuracy = 0.0,
	PrefWeapon = "",
	PrefVehicle = ""
}
