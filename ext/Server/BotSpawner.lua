---@class BotSpawner
---@overload fun():BotSpawner
BotSpawner = class('BotSpawner')

require('Model/SpawnSet')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type BotManager
local m_BotManager = require('BotManager')
---@type BotCreator
local m_BotCreator = require('BotCreator')
---@type WeaponList
local m_WeaponList = require('__shared/WeaponList')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Logger
local m_Logger = Logger("BotSpawner", Debug.Server.BOT)
local m_Vehicles = require('Vehicles')

function BotSpawner:__init()
	self:RegisterVars()
end

function BotSpawner:RegisterVars()
	self._BotSpawnTimer = 0.0
	self._LastRound = 0
	self._PlayerUpdateTimer = 0.0
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY
	self._DelayDirectSpawn = Registry.BOT_SPAWN.DELAY_DIRECT_SPAWN
	self._NrOfPlayers = 0
	self._UpdateActive = false
	---@type SpawnSet[]
	self._SpawnSets = {}
	---@type string[]
	self._KickPlayers = {}
	---@type Bot[]
	self._BotsWithoutPath = {}
end

-- =============================================
-- Events
-- =============================================

-- =============================================
-- Level Events
-- =============================================

---@param p_Round integer
function BotSpawner:OnLevelLoaded(p_Round)
	m_Logger:Write("on level loaded on spawner")
	self._FirstSpawnInLevel = true
	self._PlayerUpdateTimer = 0.0
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY

	if (Config.TeamSwitchMode == TeamSwitchModes.SwitchForRoundTwo and p_Round ~= self._LastRound) or
		(Config.TeamSwitchMode == TeamSwitchModes.AlwaysSwitchTeams) or
		(Config.TeamSwitchMode == TeamSwitchModes.SwitchTeamsRandomly and m_Utilities:CheckProbablity(50))
	then
		m_Logger:Write("switch teams")
		self:_SwitchTeams()
	end

	self._LastRound = p_Round
end

---VEXT Shared Level:Destroy Event
function BotSpawner:OnLevelDestroy()
	self._SpawnSets = {}
	self._UpdateActive = false
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY
	self._DelayDirectSpawn = Registry.BOT_SPAWN.DELAY_DIRECT_SPAWN
	self._PlayerUpdateTimer = 0.0
	self._NrOfPlayers = 0
end

-- =============================================
-- Update Events
-- =============================================

---VEXT Shared UpdateManager:Update Event
---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function BotSpawner:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	if self._FirstSpawnInLevel then
		if self._FirstSpawnDelay <= 0.0 then
			m_BotManager:ConfigGlobals()
			self:UpdateBotAmountAndTeam()
			self._PlayerUpdateTimer = 0.0
			self._FirstSpawnInLevel = false
		else
			self._FirstSpawnDelay = self._FirstSpawnDelay - p_DeltaTime
		end
	else
		-- count below 0 for post-delay-reactions
		if self._DelayDirectSpawn > -10 and Globals.IsInputAllowed and self._NrOfPlayers > 0 then
			self._DelayDirectSpawn = self._DelayDirectSpawn - p_DeltaTime
		end
		self._PlayerUpdateTimer = self._PlayerUpdateTimer + p_DeltaTime

		if self._PlayerUpdateTimer > 2.0 then
			self._PlayerUpdateTimer = 0.0
			self:UpdateBotAmountAndTeam()
		end
	end

	if #self._SpawnSets > 0 then
		if self._BotSpawnTimer > 0.2 then -- Time to wait between spawn. 0.2 works
			self._BotSpawnTimer = 0.0
			local s_SpawnSet = table.remove(self._SpawnSets)
			self:_SpawnSingleWayBot(s_SpawnSet.m_PlayerVarOfBot, s_SpawnSet.m_UseRandomWay, s_SpawnSet.m_ActiveWayIndex,
				s_SpawnSet.m_IndexOnPath, nil, s_SpawnSet.m_Team)
		end

		self._BotSpawnTimer = self._BotSpawnTimer + p_DeltaTime
	else
		if self._UpdateActive then
			self._UpdateActive = false

			if Globals.SpawnMode ~= SpawnModes.manual then
				-- Garbage-collection of unwanted bots
				m_BotManager:DestroyDisabledBots(self._DelayDirectSpawn > -5.0)
				m_BotManager:RefreshTables()
			end
		end
	end

	-- Kick players named after bots
	if #self._KickPlayers > 0 then
		for i, l_PlayerNameToKick in pairs(self._KickPlayers) do
			local s_PlayerToKick = PlayerManager:GetPlayerByName(l_PlayerNameToKick)

			if s_PlayerToKick ~= nil then
				s_PlayerToKick:Kick("You used a BOT-Name. Please use a real name on Fun-Bot-Servers...")

				for j, l_BotNameToIgnore in pairs(Globals.IgnoreBotNames) do
					if l_BotNameToIgnore == l_PlayerNameToKick then
						table.remove(Globals.IgnoreBotNames, j)
						break
					end
				end

				table.remove(self._KickPlayers, i)
				break
			end
		end
	end

	if #self._BotsWithoutPath > 0 then
		for i, l_Bot in pairs(self._BotsWithoutPath) do
			if l_Bot == nil or l_Bot.m_Player == nil then
				table.remove(self._BotsWithoutPath, i)
				break
			end

			if l_Bot.m_Player.soldier ~= nil then
				local s_Position = l_Bot.m_Player.soldier.worldTransform.trans:Clone()
				-- local s_Node = m_NodeCollection:Find(s_Position, 5)
				local s_Node = g_GameDirector:FindClosestPath(s_Position, false, false, nil)

				if s_Node ~= nil then
					l_Bot:SetVarsWay(nil, true, s_Node.PathIndex, s_Node.PointIndex, false)
					table.remove(self._BotsWithoutPath, i)

					if Globals.RemoveKitVisuals then
						Events:Dispatch('Bot:SoldierEntity', l_Bot.m_Player.soldier)
					end

					break
				end
			end
		end
	end
end

-- =============================================
-- Player Events
-- =============================================

---VEXT Server Player:Joining Event
---@param p_Name string
function BotSpawner:OnPlayerJoining(p_Name)
	-- Detect BOT-Names.
	if Registry.COMMON.ALLOW_PLAYER_BOT_NAMES then
		for _, l_Name in pairs(BotNames) do
			if Registry.COMMON.BOT_TOKEN .. l_Name == p_Name then
				-- Prevent bots from being named like this.
				m_Logger:Write("Don't use the name " .. p_Name .. " for Bots anymore")
				table.insert(Globals.IgnoreBotNames, p_Name)

				-- Destroy bots with this name.
				if m_BotManager:GetBotByName(p_Name) ~= nil then
					m_BotManager:DestroyBot(p_Name)
				end

				return
			end
		end
	else -- Not allowed to use Bot-Names.
		if Registry.COMMON.BOT_TOKEN == "" then
			for _, l_Name in pairs(BotNames) do
				if l_Name == p_Name then
					table.insert(self._KickPlayers, p_Name)

					if m_BotManager:GetBotByName(p_Name) ~= nil then
						table.insert(Globals.IgnoreBotNames, p_Name)
						m_BotManager:DestroyBot(p_Name)
					end

					return
				end
			end
		else
			if string.find(p_Name, Registry.COMMON.BOT_TOKEN) == 1 then -- Check if name starts with bot-token
				table.insert(self._KickPlayers, p_Name)

				if m_BotManager:GetBotByName(p_Name) ~= nil then
					table.insert(Globals.IgnoreBotNames, p_Name)
					m_BotManager:DestroyBot(p_Name)
				end
			end
		end
	end
end

---@param p_Player Player
function BotSpawner:OnPlayerAuthenticated(p_Player)
	if (Config.BalancePlayersIgnoringBots) then
		local s_CountPlayers = {}

		for i = 1, Globals.NrOfTeams do
			s_CountPlayers[i] = 0
			local s_TempPlayers = PlayerManager:GetPlayersByTeam(i)

			for _, l_Player in pairs(s_TempPlayers) do
				if not m_Utilities:isBot(l_Player) then
					s_CountPlayers[i] = s_CountPlayers[i] + 1
				end
			end
		end

		-- Move player to other team to balance.
		if s_CountPlayers[1] > s_CountPlayers[2] then
			p_Player.teamId = 2
		else
			p_Player.teamId = 1
		end
	end
end

---@param p_Player Player
---@param p_TeamId TeamId|integer
---@param p_SquadId SquadId|integer
function BotSpawner:OnTeamChange(p_Player, p_TeamId, p_SquadId)
	-- kill bot, if still alive
	local s_Bot = m_BotManager:GetBotById(p_Player.id)
	if s_Bot ~= nil then
		if s_Bot.m_Player.soldier ~= nil then
			s_Bot.m_Player.soldier:Kill()
		end
		s_Bot.m_Player.teamId = p_TeamId --not needed, but does not hurt as well.
	end

	if Config.BotTeam ~= TeamId.TeamNeutral then
		if p_Player ~= nil then
			if p_Player.onlineId ~= 0 then -- No bot.
				local s_PlayerTeams = {}

				for i = 1, Globals.NrOfTeams do
					if Config.BotTeam ~= i then
						table.insert(s_PlayerTeams, i)
					end
				end

				local s_PlayerTeam = s_PlayerTeams[MathUtils:GetRandomInt(1, #s_PlayerTeams)]

				if p_Player ~= nil and p_TeamId ~= nil and (p_TeamId ~= s_PlayerTeam) then
					p_Player.teamId = s_PlayerTeam
					ChatManager:SendMessage(Language:I18N('CANT_JOIN_BOT_TEAM', p_Player), p_Player)
				end
			end
		end
	end
end

-- =============================================
-- Custom Bot Respawn Event
-- =============================================

---@param p_BotId integer
function BotSpawner:OnRespawnBot(p_BotId)
	local s_Bot = m_BotManager:GetBotById(p_BotId)
	if s_Bot == nil then
		return
	end
	-- fix for end-of-round-crash
	if Registry.COMMON.DONT_SPAWN_BOTS_ON_LAST_CONQUEST_TICKET and Globals.IsConquest then
		local s_Player = s_Bot.m_Player
		if s_Player ~= nil then
			local s_PlayerTeam = s_Player.teamId
			local s_TicketsOfPlayerTeam = TicketManager:GetTicketCount(s_PlayerTeam)
			if s_TicketsOfPlayerTeam < 2 then
				-- only one ticket remaining. Don't spawn
				return
			end
		end
	end

	local s_SpawnMode = s_Bot:GetSpawnMode()
	if s_SpawnMode == BotSpawnModes.RespawnFixedPath then -- Fixed Way.
		local s_WayIndex = s_Bot:GetWayIndex()
		local s_RandIndex = MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_WayIndex))
		self:_SpawnSingleWayBot(nil, false, s_WayIndex, s_RandIndex, s_Bot)
	elseif s_SpawnMode == BotSpawnModes.RespawnRandomPath then -- Random Way.
		self:_SpawnSingleWayBot(nil, true, 0, 0, s_Bot)
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================
function BotSpawner:UpdateBotNames()
	self._SpawnSets = {}
	local s_TimeToWait = (#m_BotManager:GetBots() * Registry.BOT.BOT_DESTORY_DELAY) + 1.0
	m_BotManager:DestroyAll()
	m_BotManager:RefreshTables()
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = s_TimeToWait
end

function BotSpawner:UpdateBotAmountAndTeam()
	-- Keep Slot for next player.
	if Config.KeepOneSlotForPlayers then
		local s_PlayerLimit = Globals.MaxPlayers - 1
		local s_AmountToDestroy = PlayerManager:GetPlayerCount() - s_PlayerLimit

		if s_AmountToDestroy > 0 then
			m_BotManager:DestroyAll(s_AmountToDestroy)
		end
	end

	-- If update active, do nothing.
	if self._UpdateActive then
		return
	else
		self._UpdateActive = true
	end

	-- Find all needed vars.
	local s_BotCount = m_BotManager:GetActiveBotCount()
	local s_PlayerCount = 0

	local s_PlayerTeam = m_BotManager:GetPlayerTeam()
	local s_CountPlayers = {}
	local s_TeamCount = {}
	local s_CountBots = {}
	local s_TargetTeamCount = {}

	local s_BotsToDelay = {}

	for i = 1, Globals.NrOfTeams do
		s_CountPlayers[i] = 0
		s_BotsToDelay[i] = 0
		s_CountBots[i] = m_BotManager:GetActiveBotCount(i) -- + m_BotManager:GetInactiveBotCount()
		s_TargetTeamCount[i] = 0
		local s_TempPlayers = PlayerManager:GetPlayersByTeam(i)

		if self._DelayDirectSpawn > -5.0 then
			s_BotsToDelay[i] = #g_GameDirector:GetSpawnableVehicle(i)
		end

		for _, l_Player in pairs(s_TempPlayers) do
			if not m_Utilities:isBot(l_Player) then
				s_CountPlayers[i] = s_CountPlayers[i] + 1
			end
		end

		s_TeamCount[i] = s_CountBots[i] + s_CountPlayers[i] + s_BotsToDelay[i]
		s_PlayerCount = s_PlayerCount + s_CountPlayers[i]
	end

	self._NrOfPlayers = s_PlayerCount

	-- Kill and destroy bots, if no player left.
	if s_PlayerCount == 0 then
		if s_BotCount > 0 or self._FirstSpawnInLevel then
			m_BotManager:KillAll() -- Trigger once.
			self._UpdateActive = true
		else
			self._UpdateActive = false
		end

		return
	end


	-- KEEP PLAYERCOUNT.
	if Globals.SpawnMode == SpawnModes.keep_playercount then
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = math.floor(Config.InitNumberOfBots / Globals.NrOfTeams)
			end
		else
			for i = 1, Globals.NrOfTeams do
				if s_PlayerTeam == i then
					s_TargetTeamCount[i] = 0
				else
					s_TargetTeamCount[i] = Config.InitNumberOfBots / (Globals.NrOfTeams - 1)
				end
			end
		end
		-- Limit team count.
		for i = 1, Globals.NrOfTeams do
			if Globals.NrOfTeams == 2 then
				if i == s_PlayerTeam then
					s_TargetTeamCount[i] = math.floor((s_TargetTeamCount[i] * Config.FactorPlayerTeamCount) + 0.5)
				else
					s_TargetTeamCount[i] = math.floor((s_TargetTeamCount[i] * (2 - Config.FactorPlayerTeamCount)) + 0.5)
				end
			end

			if s_TargetTeamCount[i] > Globals.MaxBotsPerTeam then
				s_TargetTeamCount[i] = Globals.MaxBotsPerTeam
			end
		end

		for i = 1, Globals.NrOfTeams do
			if s_TeamCount[i] < s_TargetTeamCount[i] then
				self:SpawnWayBots(s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
			elseif s_TeamCount[i] > s_TargetTeamCount[i] and s_CountBots[i] > 0 then
				m_BotManager:KillAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
			end
		end

		-- Move players if needed.
		if s_PlayerCount >= Registry.BOT_TEAM_BALANCING.THRESHOLD then -- Use threshold.
			local s_MinTargetPlayersPerTeam = math.floor(s_PlayerCount / Globals.NrOfTeams) -
				Registry.BOT_TEAM_BALANCING.ALLOWED_DIFFERENCE

			for i = 1, Globals.NrOfTeams do
				if s_CountPlayers[i] < s_MinTargetPlayersPerTeam then
					for _, l_Player in pairs(PlayerManager:GetPlayers()) do
						if l_Player.soldier == nil and l_Player.teamId ~= i then
							local s_OldTeam = l_Player.teamId
							l_Player.teamId = i
							s_CountPlayers[i] = s_CountPlayers[i] + 1
							if s_OldTeam ~= 0 then
								s_CountPlayers[s_OldTeam] = s_CountPlayers[s_OldTeam] - 1
							end
						end

						if s_CountPlayers[i] >= s_MinTargetPlayersPerTeam then
							break
						end
					end
				end
			end
		end

		-- BALANCED teams.
	elseif Globals.SpawnMode == SpawnModes.balanced_teams then
		local s_maxPlayersInOneTeam = 0

		for i = 1, Globals.NrOfTeams do
			if s_CountPlayers[i] > s_maxPlayersInOneTeam then
				s_maxPlayersInOneTeam = s_CountPlayers[i]
			end
		end

		local targetCount = Config.InitNumberOfBots +
			math.floor(((s_maxPlayersInOneTeam - 1) * Config.NewBotsPerNewPlayer) + 0.5)

		for i = 1, Globals.NrOfTeams do
			s_TargetTeamCount[i] = targetCount / (Globals.NrOfTeams / 2)

			if s_TargetTeamCount[i] > Globals.MaxBotsPerTeam then
				s_TargetTeamCount[i] = Globals.MaxBotsPerTeam
			end

			if Globals.NrOfTeams == 2 and i == s_PlayerTeam then
				s_TargetTeamCount[i] = math.floor((s_TargetTeamCount[i] * Config.FactorPlayerTeamCount) + 0.5)
			end
		end

		for i = 1, Globals.NrOfTeams do
			if s_TeamCount[i] < s_TargetTeamCount[i] then
				self:SpawnWayBots(s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
			elseif s_TeamCount[i] > s_TargetTeamCount[i] then
				m_BotManager:KillAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
			end
		end

		-- INCREMENT WITH PLAYER.
	elseif Globals.SpawnMode == SpawnModes.increment_with_players then
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = 0

				if s_CountPlayers[i] > 0 then
					for j = 1, Globals.NrOfTeams do
						if i ~= j then
							local s_TempCount = Config.InitNumberOfBots +
								math.floor(((s_CountPlayers[i] - 1) * Config.NewBotsPerNewPlayer) + 0.5)

							if s_TempCount > s_TargetTeamCount[j] then
								s_TargetTeamCount[j] = s_TempCount
							end
						end
					end
				end
			end

			-- Limit team count.
			for i = 1, Globals.NrOfTeams do
				if s_TargetTeamCount[i] > Globals.MaxBotsPerTeam then
					s_TargetTeamCount[i] = Globals.MaxBotsPerTeam
				end
			end

			for i = 1, Globals.NrOfTeams do
				if s_TeamCount[i] < s_TargetTeamCount[i] then
					self:SpawnWayBots(s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
				elseif s_TeamCount[i] > s_TargetTeamCount[i] and s_CountBots[i] > 0 then
					m_BotManager:KillAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
				end
			end
		else
			-- Check for bots in wrong team.
			for i = 1, Globals.NrOfTeams do
				if i == s_PlayerTeam and s_CountBots[i] > 0 then
					m_BotManager:KillAll(nil, i)
				end
			end

			local s_TargetBotCount = Config.InitNumberOfBots +
				math.floor(((s_PlayerCount - 1) * Config.NewBotsPerNewPlayer) + 0.5)
			local s_TargetBotCountPerEnemyTeam = s_TargetBotCount / (Globals.NrOfTeams - 1)

			if s_TargetBotCountPerEnemyTeam > Globals.MaxBotsPerTeam then
				s_TargetBotCountPerEnemyTeam = Globals.MaxBotsPerTeam
			end

			for i = 1, Globals.NrOfTeams do
				if i ~= s_PlayerTeam then
					if s_TeamCount[i] < s_TargetBotCountPerEnemyTeam then
						self:SpawnWayBots(s_TargetBotCountPerEnemyTeam - s_TeamCount[i], true, 0, 0, i)
					elseif s_TeamCount[i] > s_TargetBotCountPerEnemyTeam then
						m_BotManager:KillAll(s_TeamCount[i] - s_TargetBotCountPerEnemyTeam, i)
					end
				end
			end
		end
		-- FIXED NUMBER TO SPAWN.
	elseif Globals.SpawnMode == SpawnModes.fixed_number then
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = math.floor(Config.InitNumberOfBots / Globals.NrOfTeams)

				if Globals.NrOfTeams == 2 then
					if i == s_PlayerTeam then
						s_TargetTeamCount[i] = math.floor((s_TargetTeamCount[i] * Config.FactorPlayerTeamCount) + 0.5)
					else
						s_TargetTeamCount[i] = math.floor((s_TargetTeamCount[i] * (2 - Config.FactorPlayerTeamCount)) + 0.5)
					end
				end

				if s_TargetTeamCount[i] > Globals.MaxBotsPerTeam then
					s_TargetTeamCount[i] = Globals.MaxBotsPerTeam
				end
			end

			for i = 1, Globals.NrOfTeams do
				if s_TeamCount[i] < s_TargetTeamCount[i] then
					self:SpawnWayBots(s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
				elseif s_TeamCount[i] > s_TargetTeamCount[i] and s_CountBots[i] > 0 then
					m_BotManager:KillAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
				end
			end
		else
			-- Check for bots in wrong team.
			for i = 1, Globals.NrOfTeams do
				if i == s_PlayerTeam and s_CountBots[i] > 0 then
					m_BotManager:KillAll(nil, i)
				end
			end

			local s_TargetBotCount = Config.InitNumberOfBots
			local s_TargetBotCountPerEnemyTeam = s_TargetBotCount / (Globals.NrOfTeams - 1)

			if s_TargetBotCountPerEnemyTeam > Globals.MaxBotsPerTeam then
				s_TargetBotCountPerEnemyTeam = Globals.MaxBotsPerTeam
			end

			for i = 1, Globals.NrOfTeams do
				if i ~= s_PlayerTeam then
					if s_TeamCount[i] < s_TargetBotCountPerEnemyTeam then
						self:SpawnWayBots(s_TargetBotCountPerEnemyTeam - s_TeamCount[i], true, 0, 0, i)
					elseif s_TeamCount[i] > s_TargetBotCountPerEnemyTeam then
						m_BotManager:KillAll(s_TeamCount[i] - s_TargetBotCountPerEnemyTeam, i)
					end
				end
			end
		end
	elseif Globals.SpawnMode == SpawnModes.manual then
		if self._FirstSpawnInLevel then
			for i = 1, Globals.NrOfTeams do
				self:SpawnWayBots(s_TeamCount[i] - s_CountPlayers[i], true, 0, 0, i)
			end
		end
	end
end

---@param p_ExistingBot Bot|nil
---@param p_Name string
---@param p_TeamId TeamId|integer
---@param p_SquadId SquadId|integer
---@return Bot|nil
function BotSpawner:GetBot(p_ExistingBot, p_Name, p_TeamId, p_SquadId)
	if p_ExistingBot ~= nil then
		return p_ExistingBot
	else
		local s_Bot = m_BotManager:CreateBot(p_Name, p_TeamId, p_SquadId)

		if s_Bot == nil then
			m_Logger:Error("Failed to create bot")
			return nil
		end

		if (TeamSquadManager:GetSquadPlayerCount(p_TeamId, p_SquadId) == 1) then
			s_Bot.m_Player:SetSquadLeader(true, false)
		end

		return s_Bot
	end
end

-- =============================================
-- Spawn Bots in Row / Tower / Grid / Line
-- =============================================

---@param p_Player Player
---@param p_Length integer
---@param p_Spacing number
function BotSpawner:SpawnBotRow(p_Player, p_Length, p_Spacing)
	for i = 1, p_Length do
		local s_Name = m_BotCreator:GetNextBotName(self:_GetSpawnBotKit(), m_BotManager:GetBotTeam())

		if s_Name ~= nil then
			local s_Transform = LinearTransform()
			s_Transform.trans = p_Player.soldier.worldTransform.trans + (p_Player.soldier.worldTransform.forward * i * p_Spacing)
			local s_Bot = m_BotManager:CreateBot(s_Name, m_BotManager:GetBotTeam(), SquadId.SquadNone)

			if not s_Bot then
				return
			end
			m_BotCreator:SetAttributesToBot(s_Bot)
			s_Bot:SetVarsStatic(p_Player)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

---@param p_Player Player
---@param p_Height integer
function BotSpawner:SpawnBotTower(p_Player, p_Height)
	for i = 1, p_Height do
		local s_Name = m_BotCreator:GetNextBotName(self:_GetSpawnBotKit(), m_BotManager:GetBotTeam())

		if s_Name ~= nil then
			local s_Yaw = p_Player.input.authoritativeAimingYaw
			local s_Transform = LinearTransform()
			s_Transform.trans.x = p_Player.soldier.worldTransform.trans.x + (math.cos(s_Yaw + (math.pi / 2)))
			s_Transform.trans.y = p_Player.soldier.worldTransform.trans.y + ((i - 1) * 1.8)
			s_Transform.trans.z = p_Player.soldier.worldTransform.trans.z + (math.sin(s_Yaw + (math.pi / 2)))
			local s_Bot = m_BotManager:CreateBot(s_Name, m_BotManager:GetBotTeam(), SquadId.SquadNone)

			if not s_Bot then
				return
			end
			m_BotCreator:SetAttributesToBot(s_Bot)
			s_Bot:SetVarsStatic(p_Player)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

---@param p_Player Player
---@param p_Rows integer
---@param p_Columns integer
---@param p_Spacing number
function BotSpawner:SpawnBotGrid(p_Player, p_Rows, p_Columns, p_Spacing)
	for i = 1, p_Rows do
		for j = 1, p_Columns do
			local s_Name = m_BotCreator:GetNextBotName(self:_GetSpawnBotKit(), m_BotManager:GetBotTeam())

			if s_Name ~= nil then
				local s_Yaw = p_Player.input.authoritativeAimingYaw
				local s_Transform = LinearTransform()
				s_Transform.trans.x = p_Player.soldier.worldTransform.trans.x + (i * math.cos(s_Yaw + (math.pi / 2)) * p_Spacing) +
					((j - 1) * math.cos(s_Yaw) * p_Spacing)
				s_Transform.trans.y = p_Player.soldier.worldTransform.trans.y
				s_Transform.trans.z = p_Player.soldier.worldTransform.trans.z + (i * math.sin(s_Yaw + (math.pi / 2)) * p_Spacing) +
					((j - 1) * math.sin(s_Yaw) * p_Spacing)
				local s_Bot = m_BotManager:CreateBot(s_Name, m_BotManager:GetBotTeam(), SquadId.SquadNone)

				if not s_Bot then
					return
				end

				m_BotCreator:SetAttributesToBot(s_Bot)
				s_Bot:SetVarsStatic(p_Player)
				self:_SpawnBot(s_Bot, s_Transform, true)
			end
		end
	end
end

---@param p_Amount integer|number
---@param p_UseRandomWay boolean
---@param p_ActiveWayIndex? integer
---@param p_IndexOnPath? integer
---@param p_TeamId? TeamId|integer
function BotSpawner:SpawnWayBots(p_Amount, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_TeamId)
	if #m_NodeCollection:GetPaths() <= 0 then
		return
	end

	if p_Amount <= 0 then
		m_Logger:Warning("can't spawn zero or negative amount of bots")
	end

	-- Check for amount available.
	local s_PlayerLimit = Globals.MaxPlayers

	if Config.KeepOneSlotForPlayers then
		s_PlayerLimit = s_PlayerLimit - 1
	end

	local s_InactiveBots = m_BotManager:GetBotCount() - m_BotManager:GetActiveBotCount()
	local s_SlotsLeft = s_PlayerLimit - (PlayerManager:GetPlayerCount() - s_InactiveBots)

	if p_Amount > s_SlotsLeft then
		p_Amount = s_SlotsLeft
	end

	for i = 1, p_Amount do
		---@type SpawnSet
		local s_SpawnSet = SpawnSet()
		s_SpawnSet.m_PlayerVarOfBot = nil
		s_SpawnSet.m_UseRandomWay = p_UseRandomWay
		s_SpawnSet.m_ActiveWayIndex = p_ActiveWayIndex or 0
		s_SpawnSet.m_IndexOnPath = p_IndexOnPath or 0
		s_SpawnSet.m_Team = p_TeamId
		table.insert(self._SpawnSets, s_SpawnSet)
	end
end

function BotSpawner:UpdateGmWeapon(p_Bot)
	local s_SoldierWeapon = SoldierWeapon(p_Bot.m_Player.soldier.weaponsComponent.weapons[1])
	if p_Bot.m_ActiveGmWeaponName == nil or s_SoldierWeapon.name ~= p_Bot.m_ActiveGmWeaponName then
		local s_Name = s_SoldierWeapon.name
		local s_UnlockPathParts = s_Name:split('/')
		local s_NameOfWeapon = s_UnlockPathParts[#s_UnlockPathParts]

		-- replace invalid weapon-names
		for l_key, l_value in pairs(GmSpecialWeapons) do
			if s_NameOfWeapon == l_key then
				s_NameOfWeapon = l_value
				break
			end
		end

		s_UnlockPathParts[#s_UnlockPathParts] = "U_" .. s_NameOfWeapon
		local s_unlock_path = ""
		for i = 1, #s_UnlockPathParts do
			s_unlock_path = s_unlock_path .. s_UnlockPathParts[i]
			if i < #s_UnlockPathParts then
				s_unlock_path = s_unlock_path .. "/"
			end
		end

		local s_newWeapon = Weapon(s_NameOfWeapon, '', {}, WeaponTypes.None, s_unlock_path)
		s_newWeapon:learnStatsValues()

		p_Bot.m_Primary = s_newWeapon
		p_Bot.m_ActiveWeapon = s_newWeapon

		p_Bot.m_ActiveGmWeaponName = s_SoldierWeapon.name
	end
end

-- =============================================
-- Private Functions
-- =============================================

-- =============================================
-- New Spawn Method
-- =============================================

---@param p_Bot Bot
---@param p_SetKit boolean
function BotSpawner:_SelectLoadout(p_Bot, p_SetKit)
	local s_WriteNewKit = false

	if p_Bot.m_ActiveWeapon == nil then
		s_WriteNewKit = true
	end

	local s_BotColor = p_Bot.m_Color
	local s_BotKit = p_Bot.m_Kit

	p_Bot:ResetSpawnVars()
	local s_Team = "US"

	if p_Bot.m_Player.teamId % 2 == 0 then
		s_Team = "RU"
	end

	self:_SetBotWeapons(p_Bot, s_BotKit, s_Team, s_WriteNewKit)

	if p_Bot.m_Player.selectedKit == nil then
		-- SoldierBlueprint
		p_Bot.m_Player.selectedKit = ResourceManager:SearchForInstanceByGuid(Guid('261E43BF-259B-41D2-BF3B-9AE4DDA96AD2'))
	end

	self:_SetKitAndAppearance(p_Bot, s_BotKit, s_BotColor)
end

---@param p_Bot Bot
function BotSpawner:_TriggerSpawn(p_Bot)
	local s_CurrentGameMode = SharedUtils:GetCurrentGameMode()

	if s_CurrentGameMode == nil then
		m_Logger:Error("CurrentGameMode returned nil. ")
		return
	end

	if s_CurrentGameMode:match("DeathMatch") or
		s_CurrentGameMode:match("Domination") or
		s_CurrentGameMode:match("GunMaster") or
		s_CurrentGameMode:match("Scavenger") or
		s_CurrentGameMode:match("TankSuperiority") or
		s_CurrentGameMode:match("CaptureTheFlag") then
		self:_DeathMatchSpawn(p_Bot)
	elseif s_CurrentGameMode:match("Rush") then
		-- Seems to be the same as DeathMatchSpawn.
		-- But it has vehicles.
		self:_RushSpawn(p_Bot)
	elseif s_CurrentGameMode:match("Conquest") then
		-- event + target spawn ("ID_H_US_B", "_ID_H_US_HQ", etc.)
		self:_ConquestSpawn(p_Bot)
	end
end

---@param p_Bot Bot
function BotSpawner:_DeathMatchSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.m_Player, true, false, false, false, false, false,
		p_Bot.m_Player.teamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCharacterSpawnEntity")
	local s_Entity = s_EntityIterator:Next()

	while s_Entity do
		if s_Entity.data:Is('CharacterSpawnReferenceObjectData') then
			if CharacterSpawnReferenceObjectData(s_Entity.data).team == p_Bot.m_Player.teamId then
				s_Entity:FireEvent(s_Event)
				return
			end
		end

		s_Entity = s_EntityIterator:Next()
	end
end

---@param p_Bot Bot
function BotSpawner:_RushSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.m_Player, true, false, false, false, false, false,
		p_Bot.m_Player.teamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCharacterSpawnEntity")
	local s_Entity = s_EntityIterator:Next()

	while s_Entity do
		if s_Entity.data:Is('CharacterSpawnReferenceObjectData') then
			if CharacterSpawnReferenceObjectData(s_Entity.data).team == p_Bot.m_Player.teamId then
				-- Skip if it is a vehicle spawn.
				for i, l_Entity in pairs(s_Entity.bus.entities) do
					if l_Entity:Is("ServerVehicleSpawnEntity") then
						goto skip
					end
				end

				s_Entity:FireEvent(s_Event)
				return
			end
		end

		::skip::
		s_Entity = s_EntityIterator:Next()
	end
end

---@param p_Bot Bot
function BotSpawner:_ConquestSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.m_Player, true, false, false, false, false, false,
		p_Bot.m_Player.teamId)
	local s_BestSpawnPoint = self:_FindAttackedSpawnPoint(p_Bot.m_Player.teamId)

	if s_BestSpawnPoint == nil then
		s_BestSpawnPoint = self:_FindClosestSpawnPoint(p_Bot.m_Player.teamId)
	end

	if s_BestSpawnPoint == nil then
		m_Logger:Error("No valid spawn point found")
		return
	end

	s_BestSpawnPoint:FireEvent(s_Event)
end

---@param p_TeamId TeamId|integer
---@return Entity|nil @ServerCharacterSpawnEntity
function BotSpawner:_FindAttackedSpawnPoint(p_TeamId)
	---@type Entity|nil
	local s_BestSpawnPoint = nil
	local s_LowestFlagLocation = 100.0
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
	---@type CapturePointEntity
	local s_Entity = s_EntityIterator:Next()

	while s_Entity do
		s_Entity = CapturePointEntity(s_Entity)

		if s_Entity.team ~= p_TeamId then
			goto endOfLoop
		end

		for i, l_Entity in pairs(s_Entity.bus.entities) do
			if l_Entity:Is('ServerCharacterSpawnEntity') then
				if CharacterSpawnReferenceObjectData(l_Entity.data).team == p_TeamId
					or CharacterSpawnReferenceObjectData(l_Entity.data).team == 0 then
					if s_Entity.flagLocation < 100.0 and s_Entity.isControlled then
						if s_BestSpawnPoint == nil then
							s_BestSpawnPoint = l_Entity
							s_LowestFlagLocation = s_Entity.flagLocation
						elseif s_Entity.flagLocation < s_LowestFlagLocation then
							s_BestSpawnPoint = l_Entity
							s_LowestFlagLocation = s_Entity.flagLocation
						end
					end

					goto endOfLoop
				end
			end
		end

		::endOfLoop::
		s_Entity = s_EntityIterator:Next()
	end

	return s_BestSpawnPoint
end

---@param p_TeamId TeamId|integer
---@return Entity|nil @ServerCharacterSpawnEntity
function BotSpawner:_FindClosestSpawnPoint(p_TeamId)
	---@type Entity|nil
	local s_BestSpawnPoint = nil
	local s_ClosestDistance = 0
	-- Enemy and Neutralized CapturePoints.
	local s_TargetLocation = self:_FindTargetLocation(p_TeamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
	---@type CapturePointEntity
	local s_Entity = s_EntityIterator:Next()

	while s_Entity do
		s_Entity = CapturePointEntity(s_Entity)

		if s_Entity.team ~= p_TeamId then
			goto endOfLoop
		end

		for _, l_Entity in pairs(s_Entity.bus.entities) do
			if l_Entity:Is('ServerCharacterSpawnEntity') then
				if CharacterSpawnReferenceObjectData(l_Entity.data).team == p_TeamId
					or CharacterSpawnReferenceObjectData(l_Entity.data).team == 0 then
					if s_Entity.isControlled then
						if s_BestSpawnPoint == nil then
							s_BestSpawnPoint = l_Entity

							-- For the case that the enemies have no place to spawn.
							if s_TargetLocation == nil then
								return s_BestSpawnPoint
							end

							s_ClosestDistance = s_TargetLocation:Distance(s_Entity.transform.trans)
						elseif s_TargetLocation and s_ClosestDistance > s_TargetLocation:Distance(s_Entity.transform.trans) then
							s_BestSpawnPoint = l_Entity
							s_ClosestDistance = s_TargetLocation:Distance(s_Entity.transform.trans)
						end
					end

					goto endOfLoop
				end
			end
		end

		::endOfLoop::
		s_Entity = s_EntityIterator:Next()
	end

	return s_BestSpawnPoint
end

---@param p_TeamId TeamId|integer
---@return Vec3|nil
function BotSpawner:_FindTargetLocation(p_TeamId)
	---@type Vec3|nil
	local s_TargetLocation = nil
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
	---@type CapturePointEntity
	local s_Entity = s_EntityIterator:Next()

	while s_Entity do
		s_Entity = CapturePointEntity(s_Entity)

		if s_Entity.team == p_TeamId then
			goto endOfLoop
		end

		for i, l_Entity in pairs(s_Entity.bus.entities) do
			if l_Entity:Is('ServerCharacterSpawnEntity') then
				if CharacterSpawnReferenceObjectData(l_Entity.data).team == 0 then
					s_TargetLocation = s_Entity.transform.trans
				else
					return s_Entity.transform.trans
				end

				goto endOfLoop
			end
		end

		::endOfLoop::
		s_Entity = s_EntityIterator:Next()
	end

	-- Return enemy base location (or nil) if all capture points were captured by bot team already.
	return s_TargetLocation
end

-- =============================================
-- Some more Functions
-- =============================================

---@param p_Player Player|nil
---@param p_UseRandomWay boolean
---@param p_ActiveWayIndex integer|nil
---@param p_IndexOnPath integer
---@param p_ExistingBot Bot|nil
---@param p_ForcedTeam TeamId|nil
function BotSpawner:_SpawnSingleWayBot(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_ExistingBot, p_ForcedTeam)
	local s_SpawnPoint = nil
	local s_SquadSpawnVehicle = nil
	local s_IsRespawn = false
	local s_Name = nil

	local s_TeamId = p_ForcedTeam
	if s_TeamId == nil then
		s_TeamId = m_BotManager:GetBotTeam()
	end

	if p_ExistingBot ~= nil then
		s_IsRespawn = true
		s_Name = p_ExistingBot.m_Name
		s_TeamId = p_ExistingBot.m_Player.teamId
	elseif Registry.BOT_SPAWN.KEEP_BOTS_ON_NEW_ROUND and m_BotManager:GetInactiveBotCount(s_TeamId) > 0 then
		local s_Bot = m_BotManager:GetInactiveBot(s_TeamId)
		if s_Bot then
			p_ExistingBot = s_Bot
			s_IsRespawn = true
			s_Name = p_ExistingBot.m_Name
			s_TeamId = p_ExistingBot.m_Player.teamId
		end
	end

	-- only new bot, if no respawn
	if not s_IsRespawn or not p_ExistingBot then
		s_Name = m_BotCreator:GetNextBotName(self:_GetSpawnBotKit(), s_TeamId)
	end

	local s_SquadId = self:_GetSquadToJoin(s_TeamId)

	if s_IsRespawn and p_ExistingBot then
		if p_ExistingBot.m_Player.squadId == SquadId.SquadNone or p_ExistingBot.m_Player.squadId > s_SquadId then -- place free in other squad
			p_ExistingBot.m_Player.squadId = s_SquadId
		else
			s_SquadId = p_ExistingBot.m_Player.squadId
		end
	end

	local s_InverseDirection = nil

	if s_Name ~= nil or s_IsRespawn then
		if Config.SpawnMethod == SpawnMethod.Spawn then
			local s_Bot = self:GetBot(p_ExistingBot, s_Name, s_TeamId, s_SquadId)

			if s_Bot == nil then
				return
			end

			m_BotCreator:SetAttributesToBot(s_Bot)
			self:_SelectLoadout(s_Bot, false)
			self:_TriggerSpawn(s_Bot)
			table.insert(self._BotsWithoutPath, s_Bot)
			return
		end

		local s_Beacon = g_GameDirector:GetPlayerBeacon(s_Name)

		-- Find a spawn point.
		if s_Beacon ~= nil then
			s_SpawnPoint = m_NodeCollection:Get(s_Beacon.Point, s_Beacon.Path)
			s_SquadSpawnVehicle = s_Beacon.Entity
			s_InverseDirection = true
		elseif p_UseRandomWay or p_ActiveWayIndex == nil or p_ActiveWayIndex == 0 then
			s_SpawnPoint, s_InverseDirection, s_SquadSpawnVehicle = self:_GetSpawnPoint(s_TeamId, s_SquadId)

			-- Special spawn in vehicles.
			if type(s_SpawnPoint) == 'string' then
				local s_SpawnEntity = nil
				local s_Transform = LinearTransform()

				if s_SpawnPoint == "SpawnAtVehicle" then
					local s_Vehicles = g_GameDirector:GetSpawnableVehicle(s_TeamId)

					for _, l_Vehicle in pairs(s_Vehicles) do
						if l_Vehicle ~= nil then
							s_SpawnEntity = l_Vehicle
							break
						end
					end
				elseif s_SpawnPoint == "SpawnInAa" then
					local s_StationaryAas = g_GameDirector:GetStationaryAas(s_TeamId)

					for _, l_Aa in pairs(s_StationaryAas) do
						if l_Aa ~= nil then
							s_SpawnEntity = l_Aa
							break
						end
					end
				elseif s_SpawnPoint == "SpawnInGunship" then
					s_SpawnEntity = g_GameDirector:GetGunship(s_TeamId)
				end


				if s_IsRespawn and p_ExistingBot then
					p_ExistingBot:SetVarsWay(nil, true, 0, 0, false)
					self:_SpawnBot(p_ExistingBot, s_Transform, false)

					if p_ExistingBot:_EnterVehicleEntity(s_SpawnEntity, false) ~= 0 then
						p_ExistingBot:Kill()
					elseif s_SpawnEntity ~= nil then
						p_ExistingBot:FindVehiclePath(s_SpawnEntity.transform.trans)
					end
				else
					local s_Bot = m_BotManager:CreateBot(s_Name, s_TeamId, s_SquadId)

					if s_Bot ~= nil then
						-- Check for first one in squad.
						if (TeamSquadManager:GetSquadPlayerCount(s_TeamId, s_SquadId) == 1) then
							s_Bot.m_Player:SetSquadLeader(true, false) -- Not private.
						end
						m_BotCreator:SetAttributesToBot(s_Bot)
						s_Bot:SetVarsWay(nil, true, 0, 0, false)
						self:_SpawnBot(s_Bot, s_Transform, true)

						if s_Bot:_EnterVehicleEntity(s_SpawnEntity, false) ~= 0 then
							s_Bot:Kill()
						elseif s_SpawnEntity then
							s_Bot:FindVehiclePath(s_SpawnEntity.transform.trans)
						end
					end
				end

				return
			end
		else
			s_SpawnPoint = m_NodeCollection:Get(p_IndexOnPath, p_ActiveWayIndex)
		end

		if s_SpawnPoint == nil then
			if s_SquadSpawnVehicle ~= nil then
				s_SpawnPoint = m_NodeCollection:Get()[1]

				if s_SpawnPoint == nil then
					return
				end
			else
				return
			end
		else
			p_IndexOnPath = s_SpawnPoint.PointIndex
			p_ActiveWayIndex = s_SpawnPoint.PathIndex
		end

		-- Find out direction, if path has a return point.
		if s_InverseDirection == nil then
			if m_NodeCollection:Get(1, p_ActiveWayIndex).OptValue == 0xFF then
				s_InverseDirection = (MathUtils:GetRandomInt(0, 1) == 1)
			else
				s_InverseDirection = false
			end
		end

		local s_Transform = LinearTransform()

		if p_IndexOnPath == nil or p_IndexOnPath == 0 then
			p_IndexOnPath = 1
		end

		s_Transform.trans = s_SpawnPoint.Position

		if p_ActiveWayIndex then
			if s_IsRespawn and p_ExistingBot then
				p_ExistingBot:SetVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, s_InverseDirection)
				self:_SpawnInEntity(p_ExistingBot, s_SquadSpawnVehicle, s_Transform, false)
			else
				local s_Bot = m_BotManager:CreateBot(s_Name, s_TeamId, s_SquadId)

				if s_Bot ~= nil then
					-- Check for first one in squad.
					if (TeamSquadManager:GetSquadPlayerCount(s_TeamId, s_SquadId) == 1) then
						s_Bot.m_Player:SetSquadLeader(true, false) -- Not private.
					end
					m_BotCreator:SetAttributesToBot(s_Bot)
					s_Bot:SetVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, s_InverseDirection)
					self:_SpawnInEntity(s_Bot, s_SquadSpawnVehicle, s_Transform, true)
				end
			end
		end
	end
end

function BotSpawner:_SpawnInEntity(p_Bot, p_Entity, p_Transform, p_SetKit)
	local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_Entity)

	if s_VehicleData and s_VehicleData.Name == "[RadioBeacon]" then
		self:_SpawnBot(p_Bot, p_Entity.transform, p_SetKit)
		return
	end

	self:_SpawnBot(p_Bot, p_Transform, p_SetKit)

	if p_Entity == nil then
		return
	end

	p_Bot:_EnterVehicleEntity(p_Entity, false)
end

---@param p_Bot Bot
---@param p_Transform LinearTransform
---@param p_SetKit boolean
function BotSpawner:_SpawnBot(p_Bot, p_Transform, p_SetKit)
	local s_WriteNewKit = false

	if p_Bot.m_ActiveWeapon == nil then
		s_WriteNewKit = true
	end

	local s_BotColor = p_Bot.m_Color
	local s_BotKit = p_Bot.m_Kit

	local s_Team = "US"

	if p_Bot.m_Player.teamId % 2 == 0 then
		s_Team = "RU"
	end

	self:_SetBotWeapons(p_Bot, s_BotKit, s_Team, s_WriteNewKit)
	p_Bot:ResetSpawnVars()

	-- Create kit and appearance.
	if p_Bot.m_Player.selectedKit == nil then
		-- SoldierBlueprint
		p_Bot.m_Player.selectedKit = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier') -- MpSoldier
	end

	self:_SetKitAndAppearance(p_Bot, s_BotKit, s_BotColor)

	m_BotManager:SpawnBot(p_Bot, p_Transform, CharacterPoseType.CharacterPoseType_Stand)

	if not p_Bot.m_Player.soldier then
		-- happens on the last ticket. round has ended.
		return
	end

	p_Bot.m_Player.soldier:ApplyCustomization(self:_GetCustomization(p_Bot, s_BotKit))

	if Globals.RemoveKitVisuals then
		-- for Civilianizer-mod:
		Events:Dispatch('Bot:SoldierEntity', p_Bot.m_Player.soldier)
	end
end

---@param p_TeamId TeamId|integer
---@param p_SquadId SquadId|integer
---@return string|table|nil
---@return boolean|nil
---@return ControllableEntity|nil
function BotSpawner:_GetSpawnPoint(p_TeamId, p_SquadId)
	local s_ActiveWayIndex = 0
	local s_IndexOnPath = 0

	local s_InvertDirection = nil
	local s_TargetNode = nil
	local s_VehicleToSpawnIn = nil
	local s_ValidPointFound = false
	local s_TargetDistance = Config.DistanceToSpawnBots
	local s_RetryCounter = Config.MaxTrysToSpawnAtDistance
	local s_MaximumTrys = 100
	local s_TrysDone = 0

	if Config.UseVehicles and self._DelayDirectSpawn <= 0.0 and #g_GameDirector:GetSpawnableVehicle(p_TeamId) > 0 then
		return "SpawnAtVehicle"
	end

	if Config.AABots and #g_GameDirector:GetStationaryAas(p_TeamId) > 0 then
		return "SpawnInAa"
	end

	-- Gunships disabled for now! TODO: enable gunship again, once server-cameras are supported for aiming
	local s_Gunship = g_GameDirector:GetGunship(p_TeamId)
	if false and s_Gunship then -- TODO: Remove "false", once the aiming works
		local s_SeatsLeft = false
		for i = 1, s_Gunship.entryCount - 1 do
			if s_Gunship:GetPlayerInEntry(i) == nil then
				s_SeatsLeft = true
				break
			end
		end
		if s_SeatsLeft then
			return "SpawnInGunship"
		end
	end

	-- CONQUEST
	-- Spawn at base, squad-mate, captured flag.
	if Globals.IsConquest then
		s_ActiveWayIndex, s_IndexOnPath, s_InvertDirection, s_VehicleToSpawnIn = g_GameDirector:GetSpawnPath(p_TeamId,
			p_SquadId, false)

		if s_ActiveWayIndex == 0 then
			-- Something went wrong. Use random path.
			m_Logger:Write("no base or capturepoint found to spawn")
			return
		end

		s_TargetNode = m_NodeCollection:Get(s_IndexOnPath, s_ActiveWayIndex)
		-- RUSH
		-- Spawn at base (of zone) or squad-mate.
	elseif Globals.IsRush then
		s_ActiveWayIndex, s_IndexOnPath, s_InvertDirection, s_VehicleToSpawnIn = g_GameDirector:GetSpawnPath(p_TeamId,
			p_SquadId, true)

		if s_ActiveWayIndex == 0 then
			-- Something went wrong. Use random path.
			m_Logger:Write("no base found to spawn")
			return
		end

		s_TargetNode = m_NodeCollection:Get(s_IndexOnPath, s_ActiveWayIndex)
		-- TDM / GM / SCAVENGER
		-- Spawn away from other team.
	else
		while not s_ValidPointFound and s_TrysDone < s_MaximumTrys do
			-- Get new point.
			s_ActiveWayIndex = MathUtils:GetRandomInt(1, #m_NodeCollection:GetPaths())

			if s_ActiveWayIndex == 0 then
				return
			end

			s_IndexOnPath = MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_ActiveWayIndex))

			if m_NodeCollection:Get(1, s_ActiveWayIndex) == nil then
				return
			end

			s_TargetNode = m_NodeCollection:Get(s_IndexOnPath, s_ActiveWayIndex)
			local s_SpawnPoint = s_TargetNode.Position

			-- Check for nearby player.
			local s_PlayerNearby = false
			local s_Players = PlayerManager:GetPlayers()

			for i = 1, PlayerManager:GetPlayerCount() do
				local s_TempPlayer = s_Players[i]

				if s_TempPlayer.soldier ~= nil then
					if p_TeamId == nil or p_TeamId ~= s_TempPlayer.teamId then
						local s_Distance = s_TempPlayer.soldier.worldTransform.trans:Distance(s_SpawnPoint)
						local s_HeightDiff = math.abs(s_TempPlayer.soldier.worldTransform.trans.y - s_SpawnPoint.y)

						if s_Distance < s_TargetDistance and s_HeightDiff < Config.HeightDistanceToSpawn then
							s_PlayerNearby = true
							break
						end
					end
				end
			end

			s_RetryCounter = s_RetryCounter - 1
			s_TrysDone = s_TrysDone + 1

			if s_RetryCounter == 0 then
				s_RetryCounter = Config.MaxTrysToSpawnAtDistance
				s_TargetDistance = s_TargetDistance - Config.DistanceToSpawnReduction

				if s_TargetDistance < 0 then
					s_TargetDistance = 0
				end
			end

			if not s_PlayerNearby then
				s_ValidPointFound = true
			end
		end
	end

	return s_TargetNode, s_InvertDirection, s_VehicleToSpawnIn
end

-- To-do: create a more advanced algorithm?
---@param p_TeamId TeamId|integer
---@return SquadId|integer
function BotSpawner:_GetSquadToJoin(p_TeamId)
	if Globals.IsSdm or Globals.IsSquadRush then
		return SquadId.Squad1
	else
		for l_SquadId = 1, SquadId.SquadIdCount - 1 do -- for i = 9, SquadId.SquadIdCount - 1 do -- first 8 squads for real players.
			if TeamSquadManager:GetSquadPlayerCount(p_TeamId, l_SquadId) < 4 then
				return l_SquadId
			end
		end
	end

	return SquadId.SquadNone
end

---comment
---@param p_Bot Bot
---@param p_TeamId TeamId
---@param p_SquadId SquadId
---@return table<integer, DataContainer>|nil
function BotSpawner:_GetUnlocks(p_Bot, p_TeamId, p_SquadId)
	if Globals.IsGm then
		-- No Perks in Gunmaster.
		return nil
	end

	local s_CurrentUnlockNames = {}
	local s_CurrentUnlocks = {}

	for _, l_PlayerUnlock in pairs(p_Bot.m_Player.selectedUnlocks) do
		table.insert(s_CurrentUnlocks, l_PlayerUnlock)
		table.insert(s_CurrentUnlockNames, l_PlayerUnlock["partition"]["name"])
	end

	local s_Unlocks = {}
	local s_SelectedPerk = ""
	local s_PossiblePerks = {                                         -- Sorted by quality.
		"persistence/unlocks/soldiers/specializations/sprintboostl2", -- Tier 1
		"persistence/unlocks/soldiers/specializations/ammoboostl2",   -- Tier 1
		"persistence/unlocks/soldiers/specializations/suppressionresistl2", -- Tier 1
		"persistence/unlocks/soldiers/specializations/explosiveboostl2", -- Tier 2
		"persistence/unlocks/soldiers/specializations/explosiveresistl2", -- Tier 2
		"persistence/unlocks/soldiers/specializations/grenadeboostl2", -- Tier 3
		"persistence/unlocks/soldiers/specializations/suppressionboostl2", -- Tier 3
		-- "persistence/unlocks/soldiers/specializations/healspeedboostl2", -- Not used.
	}
	local s_VehiclePerksToAdd = {}
	if not Globals.IsScavenger and not Globals.IsTdm and not Globals.IsGm then
		s_VehiclePerksToAdd = {
			"persistence/unlocks/vehicles/mbtproximityscan",
			"persistence/unlocks/vehicles/mbtcoaxlmg",
			"persistence/unlocks/vehicles/atkheliproximityscangunner",
			"persistence/unlocks/vehicles/atkhelizoomoptics",
			"persistence/unlocks/vehicles/atkhelihellfiremissile",
			"persistence/unlocks/vehicles/atkheliheatseekermissile",
			"persistence/unlocks/vehicles/atkheliflarelauncher",
			"persistence/unlocks/vehicles/atkhelilaserdesignator",
			"persistence/unlocks/vehicles/scoutatgmissile",
			"persistence/unlocks/vehicles/scoutflares",
			"persistence/unlocks/vehicles/scoutstealth",
			"persistence/unlocks/vehicles/jetstealth",
			"persistence/unlocks/vehicles/jetflarelauncher",
			"persistence/unlocks/vehicles/jetheatseekerstance",
			"persistence/unlocks/vehicles/ifvtow",
			"persistence/unlocks/vehicles/ifvsmokelaunchers",
			-- Xp3 perks.
			"persistence/unlocks/vehicles/lbtcoaxlmg",
			"persistence/unlocks/vehicles/artilleryreloadupgrade",
			"persistence/unlocks/vehicles/artillerysmokelaunchers",
			"persistence/unlocks/vehicles/artilleryairburst",
		}
		-- some variation in appearance
		if m_Utilities:CheckProbablity(50) then
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/mbtreactivearmor")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/lbtreactivearmor")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/ifvreloadupgrade")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/mbtsmokelaunchers")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/lbtsmokelaunchers")
		else
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/mbtproximityscan")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/lbtproximityscan")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/ifvreactivearmor")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/mbtenvgoptics")
			table.insert(s_VehiclePerksToAdd, "persistence/unlocks/vehicles/lbtenvgoptics")
		end
	end

	local s_SquadPlayers = PlayerManager:GetPlayersBySquad(p_TeamId, p_SquadId)
	for _, l_SquadPlayer in pairs(s_SquadPlayers) do
		if l_SquadPlayer.id ~= p_Bot.m_Player.id then
			for _, l_PlayerUnlock in pairs(l_SquadPlayer.selectedUnlocks) do
				local s_UsedSquadPerk = l_PlayerUnlock["partition"]["name"]
				for l_Index, l_PossiblePerk in pairs(s_PossiblePerks) do
					if l_PossiblePerk == s_UsedSquadPerk then
						table.remove(s_PossiblePerks, l_Index)
						break
					end
				end
			end
		end
	end

	-- Choose good available perk.
	for _, l_PerkName in pairs(s_PossiblePerks) do
		s_SelectedPerk = l_PerkName
		if m_Utilities:CheckProbablity(80) then -- Use the best available perk with this percentage.
			break
		end
	end

	-- Update Perks if needed.
	for l_Index, l_PerkName in pairs(s_CurrentUnlockNames) do
		if string.find(l_PerkName, "soldiers") then
			-- Squad perk.
			if l_PerkName == s_SelectedPerk then
				s_SelectedPerk = ""
				table.insert(s_Unlocks, s_CurrentUnlocks[l_Index])
			end
		else
			-- Vehicle perk.
			for l_IndexVehiclePerk = #s_VehiclePerksToAdd, 1, -1 do
				local l_VehiclePerkName = s_VehiclePerksToAdd[l_IndexVehiclePerk]
				if l_PerkName == l_VehiclePerkName then
					table.remove(s_VehiclePerksToAdd, l_IndexVehiclePerk)
					table.insert(s_Unlocks, s_CurrentUnlocks[l_Index])
				end
			end
		end
	end

	-- Add perk if not already copied.
	if s_SelectedPerk ~= "" then
		table.insert(s_Unlocks, ResourceManager:SearchForDataContainer(s_SelectedPerk))
	end
	for _, l_VehicelPerk in pairs(s_VehiclePerksToAdd) do
		table.insert(s_Unlocks, ResourceManager:SearchForDataContainer(l_VehicelPerk))
	end

	return s_Unlocks
end

---@param p_Bot Bot
---@param p_Kit BotKits|integer
---@param p_Color BotColors|integer
function BotSpawner:_SetKitAndAppearance(p_Bot, p_Kit, p_Color)
	-- Create the loadouts.
	local s_SoldierKit = nil
	local s_Appearance = nil
	local s_Unlocks = nil
	local s_TeamId = p_Bot.m_Player.teamId
	local s_SquadId = p_Bot.m_Player.squadId

	-- Cast Colour.
	local s_ColorString = ""

	for l_Key, l_Value in pairs(BotColors) do
		if l_Value == p_Color then
			s_ColorString = l_Key
			break
		end
	end

	-- Get Kit and Appearance.
	if s_TeamId % 2 == 1 then      -- US
		if p_Kit == BotKits.Assault then -- Assault
			s_Appearance = self:_FindAppearance('Us', 'Assault', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Assault')
		elseif p_Kit == BotKits.Engineer then -- Engineer
			s_Appearance = self:_FindAppearance('Us', 'Engi', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Engineer')
		elseif p_Kit == BotKits.Support then -- Support
			s_Appearance = self:_FindAppearance('Us', 'Support', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Support')
		else -- Recon
			s_Appearance = self:_FindAppearance('Us', 'Recon', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Recon')
		end
	else                           -- RU
		if p_Kit == BotKits.Assault then -- Assault
			s_Appearance = self:_FindAppearance('RU', 'Assault', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Assault')
		elseif p_Kit == BotKits.Engineer then -- Engineer
			s_Appearance = self:_FindAppearance('RU', 'Engi', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Engineer')
		elseif p_Kit == BotKits.Support then -- Support
			s_Appearance = self:_FindAppearance('RU', 'Support', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Support')
		else -- Recon
			s_Appearance = self:_FindAppearance('RU', 'Recon', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Recon')
		end
	end

	if not Globals.IsGm then
		s_Unlocks = self:_GetUnlocks(p_Bot, s_TeamId, s_SquadId)
	end
	if not s_SoldierKit then
		return
	end

	if Globals.RemoveKitVisuals then
		-- for Civilianizer-mod:
		if not Globals.IsGm and s_Unlocks then
			p_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, { s_Appearance }, s_Unlocks)
		else
			p_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, {})
		end
	else
		if not Globals.IsGm and s_Unlocks then
			p_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, { s_Appearance }, s_Unlocks)
		else
			p_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, { s_Appearance })
		end
	end
end

function BotSpawner:_SetPrimaryAttachments(p_UnlockWeapon, p_Attachments)
	for _, l_Attachment in pairs(p_Attachments) do
		local s_Asset = ResourceManager:SearchForDataContainer(l_Attachment)

		if s_Asset == nil then
			m_Logger:Warning('Attachment invalid [' .. tostring(p_UnlockWeapon.weapon.name) .. ']: ' .. tostring(l_Attachment))
		else
			p_UnlockWeapon.unlockAssets:add(UnlockAsset(s_Asset))
		end
	end
end

function BotSpawner:_GetCustomization(p_Bot, p_Kit)
	local p_SoldierCustomization = CustomizeSoldierData()

	local s_PrimaryInput = p_Bot.m_Primary
	local s_PistolInput = p_Bot.m_Pistol
	local s_KnifeInput = p_Bot.m_Knife
	local s_Gadget1Input = p_Bot.m_PrimaryGadget
	local s_Gadget2Input = p_Bot.m_SecondaryGadget
	local s_GrenadeInput = p_Bot.m_Grenade

	p_SoldierCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	p_SoldierCustomization.removeAllExistingWeapons = false

	if Globals.IsGm then
		p_Bot.m_LastWeapon = nil
		return p_SoldierCustomization
	end

	-- Primary Weapon.
	local s_PrimaryWeapon = UnlockWeaponAndSlot()
	s_PrimaryWeapon.slot = WeaponSlot.WeaponSlot_0

	if s_PrimaryInput ~= nil then
		local s_PrimaryWeaponResource = ResourceManager:SearchForDataContainer(s_PrimaryInput:getResourcePath())

		if s_PrimaryWeaponResource == nil then
			m_Logger:Warning("Path not found: " .. s_PrimaryInput:getResourcePath())
		else
			s_PrimaryWeapon.weapon = SoldierWeaponUnlockAsset(s_PrimaryWeaponResource)
			self:_SetPrimaryAttachments(s_PrimaryWeapon, s_PrimaryInput:getAllAttachments())
		end
	end

	-- Primary Gadget.
	local s_PrimaryGadget = UnlockWeaponAndSlot()

	if p_Kit == BotKits.Assault or p_Kit == BotKits.Support then
		s_PrimaryGadget.slot = WeaponSlot.WeaponSlot_4
	else
		s_PrimaryGadget.slot = WeaponSlot.WeaponSlot_2
	end

	if s_Gadget1Input ~= nil then
		local s_Gadget1Weapon = ResourceManager:SearchForDataContainer(s_Gadget1Input:getResourcePath())

		if s_Gadget1Weapon == nil then
			m_Logger:Warning("Path not found: " .. s_Gadget1Input:getResourcePath())
		else
			s_PrimaryGadget.weapon = SoldierWeaponUnlockAsset(s_Gadget1Weapon)
		end
	end

	-- Secondary Gadget.
	local s_SecondaryGadget = UnlockWeaponAndSlot()
	if s_Gadget2Input ~= nil then
		local s_Gadget2Weapon = ResourceManager:SearchForDataContainer(s_Gadget2Input:getResourcePath())
		s_SecondaryGadget.slot = WeaponSlot.WeaponSlot_5

		if s_Gadget2Weapon == nil then
			m_Logger:Warning("Path not found: " .. s_Gadget2Input:getResourcePath())
		else
			s_SecondaryGadget.weapon = SoldierWeaponUnlockAsset(s_Gadget2Weapon)
		end
	end

	-- Grenade.

	local s_Grenade = UnlockWeaponAndSlot()
	s_Grenade.slot = WeaponSlot.WeaponSlot_6

	if s_GrenadeInput ~= nil then
		local s_GrenadeWeapon = ResourceManager:SearchForDataContainer(s_GrenadeInput:getResourcePath())

		if s_GrenadeWeapon == nil then
			m_Logger:Warning("Path not found: " .. s_GrenadeInput:getResourcePath())
		else
			s_Grenade.weapon = SoldierWeaponUnlockAsset(s_GrenadeWeapon)
		end
	end

	-- Pistol / Secondary.
	local s_SecondaryWeapon = UnlockWeaponAndSlot()
	s_SecondaryWeapon.slot = WeaponSlot.WeaponSlot_1

	if s_PistolInput ~= nil then
		local s_PistolWeapon = ResourceManager:SearchForDataContainer(s_PistolInput:getResourcePath())

		if s_PistolWeapon == nil then
			m_Logger:Warning("Path not found: " .. s_PistolInput:getResourcePath())
		else
			s_SecondaryWeapon.weapon = SoldierWeaponUnlockAsset(s_PistolWeapon)
		end
	end

	-- Knife.
	local s_Knife = UnlockWeaponAndSlot()
	s_Knife.slot = WeaponSlot.WeaponSlot_7

	if s_KnifeInput ~= nil then
		local s_KnifeWeapon = ResourceManager:SearchForDataContainer(s_KnifeInput:getResourcePath())

		if s_KnifeWeapon == nil then
			m_Logger:Warning("Path not found: " .. s_KnifeInput:getResourcePath())
		else
			s_Knife.weapon = SoldierWeaponUnlockAsset(s_KnifeWeapon)
		end
	end

	-- Fill Customization.
	if Globals.IsScavenger then
		p_SoldierCustomization.weapons:add(s_PrimaryWeapon)
		p_SoldierCustomization.weapons:add(s_SecondaryWeapon)
		p_SoldierCustomization.weapons:add(s_Knife)
	else
		p_SoldierCustomization.weapons:add(s_PrimaryWeapon)
		p_SoldierCustomization.weapons:add(s_SecondaryWeapon)
		p_SoldierCustomization.weapons:add(s_PrimaryGadget)
		p_SoldierCustomization.weapons:add(s_SecondaryGadget)
		p_SoldierCustomization.weapons:add(s_Grenade)
		p_SoldierCustomization.weapons:add(s_Knife)
	end

	return p_SoldierCustomization
end

---@return BotKits|integer
function BotSpawner:_GetSpawnBotKit()
	-- check for overwritten bot-kit
	if Config.BotKit ~= BotKits.RANDOM_KIT then
		return Config.BotKit
	end
	---@type BotKits|integer
	local s_BotKit = MathUtils:GetRandomInt(1, BotKits.Count - 1) -- Kit enum goes from 1 to 4.
	local s_ChangeKit = false
	-- Find out, if possible.
	local s_KitCount = m_BotManager:GetKitCount(s_BotKit)

	if s_BotKit == BotKits.Assault then
		if Config.MaxAssaultBots >= 0 and s_KitCount >= Config.MaxAssaultBots then
			s_ChangeKit = true
		end
	elseif s_BotKit == BotKits.Engineer then
		if Config.MaxEngineerBots >= 0 and s_KitCount >= Config.MaxEngineerBots then
			s_ChangeKit = true
		end
	elseif s_BotKit == BotKits.Support then
		if Config.MaxSupportBots >= 0 and s_KitCount >= Config.MaxSupportBots then
			s_ChangeKit = true
		end
	else -- s_BotKit == BotKits.Recon
		if Config.MaxReconBots >= 0 and s_KitCount >= Config.MaxReconBots then
			s_ChangeKit = true
		end
	end

	if s_ChangeKit then
		local s_AvailableKitList = {}

		if (Config.MaxAssaultBots == -1) or (m_BotManager:GetKitCount(BotKits.Assault) < Config.MaxAssaultBots) then
			table.insert(s_AvailableKitList, BotKits.Assault)
		end

		if (Config.MaxEngineerBots == -1) or (m_BotManager:GetKitCount(BotKits.Engineer) < Config.MaxEngineerBots) then
			table.insert(s_AvailableKitList, BotKits.Engineer)
		end

		if (Config.MaxSupportBots == -1) or (m_BotManager:GetKitCount(BotKits.Support) < Config.MaxSupportBots) then
			table.insert(s_AvailableKitList, BotKits.Support)
		end

		if (Config.MaxReconBots == -1) or (m_BotManager:GetKitCount(BotKits.Recon) < Config.MaxReconBots) then
			table.insert(s_AvailableKitList, BotKits.Recon)
		end

		if #s_AvailableKitList > 0 then
			s_BotKit = s_AvailableKitList[MathUtils:GetRandomInt(1, #s_AvailableKitList)]
		end
	end

	return s_BotKit
end

-- Tries to find first available kit.
---@param p_TeamName string|'"US"'|'"RU"'
---@param p_KitName string|'"Assault"'|'"Engineer"'|'"Support"'|'"Recon"'
---@return DataContainer|nil
function BotSpawner:_FindKit(p_TeamName, p_KitName)
	local s_GameModeKits = {
		'',  -- Standard.
		'_GM', -- Gun Master on XP2 Maps.
		'_GM_XP4', -- Gun Master on XP4 Maps.
		'_XP4', -- Copy of Standard for XP4 Maps.
		'_XP4_SCV' -- Scavenger on XP4 Maps.
	}

	for l_KitType = 1, #s_GameModeKits do
		local s_ProperKitName = string.lower(p_KitName)
		s_ProperKitName = s_ProperKitName:gsub("%a", string.upper, 1)

		local s_FullKitName = string.upper(p_TeamName) .. s_ProperKitName .. s_GameModeKits[l_KitType]
		local s_Kit = ResourceManager:SearchForDataContainer('Gameplay/Kits/' .. s_FullKitName)

		if s_Kit ~= nil then
			return s_Kit
		end
	end

	return nil
end

---@param p_TeamName string|'"US"'|'"RU"'
---@param p_KitName string|'"Assault"'|'"Engineer"'|'"Support"'|'"Recon"'
---@param p_ColorName string
---@return DataContainer|nil
function BotSpawner:_FindAppearance(p_TeamName, p_KitName, p_ColorName)
	local s_GameModeAppearances = {
		'MP/', -- Standard.
		'MP_XP4/', -- Gun Master on XP2 Maps.
	}

	-- 'Persistence/Unlocks/Soldiers/Visual/MP[or:MP_XP4]/Us/MP_US_Assault_Appearance_'..p_ColorName
	for _, l_GameMode in pairs(s_GameModeAppearances) do
		local s_AppearanceString = l_GameMode ..
			p_TeamName .. '/MP_' .. string.upper(p_TeamName) .. '_' .. p_KitName .. '_Appearance_' .. p_ColorName
		local s_Appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/' ..
			s_AppearanceString)

		if s_Appearance ~= nil then
			return s_Appearance
		end
	end

	return nil
end

---@param p_Bot Bot
---@param p_BotKit BotKits|integer
---@param p_Team string
---@param p_NewWeapons boolean
function BotSpawner:_SetBotWeapons(p_Bot, p_BotKit, p_Team, p_NewWeapons)
	if Globals.IsScavenger then
		p_Bot.m_SecondaryGadget = nil
		p_Bot.m_PrimaryGadget = nil
		p_Bot.m_Grenade = nil
		p_Bot.m_Pistol = m_WeaponList:getWeapon(ScavengerWeapons[BotWeapons.Pistol][
		MathUtils:GetRandomInt(1, #ScavengerWeapons[BotWeapons.Pistol])])
		p_Bot.m_Knife = m_WeaponList:getWeapon(ScavengerWeapons[BotWeapons.Knife][
		MathUtils:GetRandomInt(1, #ScavengerWeapons[BotWeapons.Knife])])
		p_Bot.m_Primary = m_WeaponList:getWeapon(ScavengerWeapons[BotWeapons.Primary][
		MathUtils:GetRandomInt(1, #ScavengerWeapons[BotWeapons.Primary])])
	elseif Globals.IsGm then
		return
	elseif p_NewWeapons then
		local s_Pistol = Config.Pistol
		local s_Knife = Config.Knife

		local s_Weapon = nil

		if p_BotKit == BotKits.Assault then
			s_Weapon = Config.AssaultWeapon
		elseif p_BotKit == BotKits.Engineer then
			s_Weapon = Config.EngineerWeapon
		elseif p_BotKit == BotKits.Support then
			s_Weapon = Config.SupportWeapon
		else
			s_Weapon = Config.ReconWeapon
		end

		if Config.UseRandomWeapon then
			s_Weapon = Weapons[p_BotKit][BotWeapons.Primary][p_Team][
			MathUtils:GetRandomInt(1, #Weapons[p_BotKit][BotWeapons.Primary][p_Team])]
			s_Pistol = Weapons[p_BotKit][BotWeapons.Pistol][p_Team][
			MathUtils:GetRandomInt(1, #Weapons[p_BotKit][BotWeapons.Pistol][p_Team])]
			s_Knife = Weapons[p_BotKit][BotWeapons.Knife][p_Team][
			MathUtils:GetRandomInt(1, #Weapons[p_BotKit][BotWeapons.Knife][p_Team])]
		end

		p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
		if p_BotKit == BotKits.Engineer and
			(Globals.IsTdm or Globals.IsDomination or Globals.IsSquadRush or Globals.IsRushWithoutVehicles) then
			-- Don't use missiles without vehicles.
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(Weapons[p_BotKit][BotWeapons.Gadget2][p_Team][1])
		else
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(Weapons[p_BotKit][BotWeapons.Gadget2][p_Team][
			MathUtils:GetRandomInt(1, #Weapons[p_BotKit][BotWeapons.Gadget2][p_Team])])
		end
		p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(Weapons[p_BotKit][BotWeapons.Gadget1][p_Team][
		MathUtils:GetRandomInt(1, #Weapons[p_BotKit][BotWeapons.Gadget1][p_Team])])
		p_Bot.m_Pistol = m_WeaponList:getWeapon(s_Pistol)
		p_Bot.m_Grenade = m_WeaponList:getWeapon(Weapons[p_BotKit][BotWeapons.Grenade][p_Team][
		MathUtils:GetRandomInt(1, #Weapons[p_BotKit][BotWeapons.Grenade][p_Team])])
		p_Bot.m_Knife = m_WeaponList:getWeapon(s_Knife)
	end

	if Config.BotWeapon == BotWeapons.Primary or Config.BotWeapon == BotWeapons.Auto then
		p_Bot.m_ActiveWeapon = p_Bot.m_Primary
	elseif Config.BotWeapon == BotWeapons.Pistol then
		p_Bot.m_ActiveWeapon = p_Bot.m_Pistol
	elseif Config.BotWeapon == BotWeapons.Gadget2 then
		p_Bot.m_ActiveWeapon = p_Bot.m_SecondaryGadget
	elseif Config.BotWeapon == BotWeapons.Gadget1 then
		p_Bot.m_ActiveWeapon = p_Bot.m_PrimaryGadget
	elseif Config.BotWeapon == BotWeapons.Grenade then
		p_Bot.m_ActiveWeapon = p_Bot.m_Grenade
	else
		p_Bot.m_ActiveWeapon = p_Bot.m_Knife
	end
end

function BotSpawner:_SwitchTeams()
	local s_Players = PlayerManager:GetPlayers()

	for _, l_Player in pairs(s_Players) do
		local s_OldTeam = l_Player.teamId

		if s_OldTeam ~= TeamId.TeamNeutral then
			local s_NewTeam = ((s_OldTeam + 1) % Globals.NrOfTeams)

			if s_NewTeam == 0 then
				s_NewTeam = Globals.NrOfTeams
			end

			if not Config.BotTeamNames or not m_Utilities:isBot(l_Player) then
				l_Player.teamId = s_NewTeam
			end
		end
	end
end

if g_BotSpawner == nil then
	---@type BotSpawner
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner
