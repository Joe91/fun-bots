class('Bots')

function Bots:__init()
	self._bots = {}
	self._botInputs = {}

	Events:Subscribe('UpdateManager:Update', self, self._onUpdate)
	Events:Subscribe('Extension:Unloading', self, self._onUnloading)
end

function Bots:_onUpdate(dt, pass)
	if pass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	for _, bot in pairs(self._bots) do
		Events:Dispatch('Bot:Update', bot, dt)

		if bot.soldier ~= nil then
			bot.soldier:SingleStepEntry(bot.controlledEntryId)
		end
	end
end

function Bots:_onUnloading()
	-- Extension is unloading. Get rid of all the bots.
	self:destroyAllBots()
end

-- Creates a bot with the specified name and puts it in the specified team and squad.
function Bots:createBot(name, team, squad)
	-- Create a player for this bot.
	local botPlayer = PlayerManager:CreatePlayer(name, team, squad)

	-- Create input for this bot.
	local botInput = EntryInput()
	botInput.deltaTime = 1.0 / SharedUtils:GetTickrate()

	botPlayer.input = botInput

	-- Add to our local storage.
	-- We need to keep the EntryInput instances around separately because if we don't
	-- they'll get garbage-collected and destroyed and that will cause our game to crash.
	table.insert(self._bots, botPlayer)
	self._botInputs[botPlayer.id] = botInput

	return botPlayer
end

-- Returns `true` if the specified player is a bot, `false` otherwise.
function Bots:isBot(player)
	for _, bot in pairs(self._bots) do
		if bot == player then
			return true
		end
	end

	return false
end

-- Spawns a bot at the provided `transform`, with the provided `pose`,
-- using the provided blueprint, kit, and unlocks.
function Bots:spawnBot(bot, transform, pose, soldierBp, kit, unlocks)
	if not self:isBot(bot) then
		return
	end

	-- If this bot already has a soldier, kill it.
	if bot.soldier ~= nil then
		bot.soldier:Kill()
	end

	bot:SelectUnlockAssets(kit, unlocks)

	-- Create and spawn the soldier for this bot.
	local botSoldier = bot:CreateSoldier(soldierBp, transform)

	bot:SpawnSoldierAt(botSoldier, transform, pose)
	bot:AttachSoldier(botSoldier)

	return botSoldier
end

-- Destroys / kicks the specified `bot` player.
function Bots:destroyBot(bot)
	-- Find index of this bot.
	local idx = nil

	for i, botPlayer in pairs(self._bots) do
		if bot == botPlayer then
			idx = i
			break
		end
	end

	-- Bot was not found.
	if idx == nil then
		return
	end

	local botId = bot.id

	-- Delete the bot.
	bot.input = nil
	PlayerManager:DeletePlayer(bot)

	-- Delete the input.
	self._botInputs[botId] = nil

	-- Delete the bot from the list.
	table.remove(self._bots, idx)
end

-- Destroys / kicks all bot players.
function Bots:destroyAllBots()
	for _, bot in pairs(self._bots) do
		bot.input = nil
		PlayerManager:DeletePlayer(bot)
	end

	self._bots = {}
	self._botInputs = {}
end

-- Singleton.
if g_Bots == nil then
	g_Bots = Bots()
end

return g_Bots