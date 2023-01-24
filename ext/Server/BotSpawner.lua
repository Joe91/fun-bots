---@class BotSpawner
---@overload fun():BotSpawner
BotSpawner = class('BotSpawner')

require('Model/SpawnSet')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type BotManager
local m_BotManager = require('BotManager')
---@type WeaponList
local m_WeaponList = require('__shared/WeaponList')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Logger
local m_Logger = Logger("BotSpawner", Debug.Server.BOT)

function BotSpawner:__init()
	self:RegisterVars()
end

function BotSpawner:RegisterVars()
	self._BotSpawnTimer = 0.0
	self._LastRound = 0
	self._PlayerUpdateTimer = 0.0
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY
	self._UpdateActive = false
	---@type SpawnSet[]
	self._SpawnSets = {}
	---@type string[]
	self._KickPlayers = {}
	---@type Bot[]
	self._BotsWithoutPath = {}

	self._CurrentSpawnWave = 0
	self._SpawnedBotsInCurrentWave = 0
	self._BotsToSpawnInWave = 0

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

	-- don't switch teams
	--	self:_SwitchTeams()
	self._CurrentSpawnWave = 0
	self._SpawnedBotsInCurrentWave = 0
	self._BotsToSpawnInWave = 0

	self._LastRound = p_Round
end

---VEXT Shared Level:Destroy Event
function BotSpawner:OnLevelDestroy()
	self._SpawnSets = {}
	self._UpdateActive = false
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY
	self._PlayerUpdateTimer = 0.0
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

	if self._FirstSpawnDelay > 0 then
		self._FirstSpawnDelay = self._FirstSpawnDelay - p_DeltaTime
		return
	end

	if self._FirstSpawnInLevel then
		m_BotManager:ConfigGlobals()
		self:UpdateBotAmountAndTeam()
		self._PlayerUpdateTimer = 0.0
		self._FirstSpawnInLevel = false
	else
		self._PlayerUpdateTimer = self._PlayerUpdateTimer + p_DeltaTime

		if self._PlayerUpdateTimer > 2.0 and #self._SpawnSets == 0 then -- don't update while we have to spawn some more bots
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
			if Globals.SpawnMode == SpawnModes.wave_spawn then
				self._SpawnedBotsInCurrentWave = self._SpawnedBotsInCurrentWave + 1
			end
		end

		self._BotSpawnTimer = self._BotSpawnTimer + p_DeltaTime
	else
		if self._UpdateActive then
			self._UpdateActive = false

			if Globals.SpawnMode ~= SpawnModes.manual then
				-- Garbage-collection of unwanted bots
				m_BotManager:DestroyDisabledBots()
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
---@param p_TeamId TeamId|integer
---@param p_SquadId SquadId|integer
function BotSpawner:OnTeamChange(p_Player, p_TeamId, p_SquadId)
	-- all bots in one team
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

-- =============================================
-- Custom Bot Respawn Event
-- =============================================

---@param p_BotName string
function BotSpawner:OnRespawnBot(p_BotName)
	local s_Bot = m_BotManager:GetBotByName(p_BotName)
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

function BotSpawner:UpdateWaveConfig()
	local s_WaveValue = self._CurrentSpawnWave - 1
	if s_WaveValue < 0 then
		s_WaveValue = 0
	end
	Globals.MaxHealthValue = Config.BotMaxHealth + (s_WaveValue * Config.IncrementMaxHealthPerWave)
	Globals.MinHealthValue = Config.BotMinHealth + (s_WaveValue * Config.IncrementMaxHealthPerWave)
	Globals.DamageFactorZombies = Config.DamageFactorKnife + (s_WaveValue * Config.IncrementDamageFactorPerWave)
	Globals.SpeedAttackValue = Config.SpeedFactorAttack + (s_WaveValue * Config.IncrementMaxSpeedPerWave)
	self._BotsToSpawnInWave = Config.FirstWaveCount + (s_WaveValue * Config.IncrementZombiesPerWave)
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

	for i = 1, Globals.NrOfTeams do
		s_CountPlayers[i] = 0
		s_CountBots[i] = m_BotManager:GetActiveBotCount(i)
		s_TargetTeamCount[i] = 0
		local s_TempPlayers = PlayerManager:GetPlayersByTeam(i)

		for _, l_Player in pairs(s_TempPlayers) do
			if not m_Utilities:isBot(l_Player) then
				s_CountPlayers[i] = s_CountPlayers[i] + 1

				if Globals.IsSdm then -- To-do: Only needed because of VEXT-Bug.
					l_Player.squadId = 1
				end
			end
		end

		s_TeamCount[i] = s_CountBots[i] + s_CountPlayers[i]
		s_PlayerCount = s_PlayerCount + s_CountPlayers[i]
	end

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


	if Globals.SpawnMode == SpawnModes.wave_spawn then
		if self._CurrentSpawnWave == 0 then
			Globals.RespawnWayBots = false
			m_BotManager:DestroyAll()
			ChatManager:Yell("First Wave starts in 10 seconds", 7.0)
			self._FirstSpawnDelay = 10
			self._CurrentSpawnWave = 1
			Globals.MaxHealthValue = Config.BotMaxHealth
			Globals.MinHealthValue = Config.BotMinHealth
			Globals.DamageFactorZombies = Config.DamageFactorKnife
			Globals.SpeedAttackValue = Config.SpeedFactorAttack
			self._BotsToSpawnInWave = Config.FirstWaveCount
		end
		if Config.KillRemainingZombiesAfterWave and self._SpawnedBotsInCurrentWave == 0 then
			m_BotManager:KillAll()
		end
		if self._SpawnedBotsInCurrentWave < self._BotsToSpawnInWave then
			local s_PlayerLimit = Globals.MaxPlayers - 1
			local s_SlotsLeft = s_PlayerLimit - (PlayerManager:GetPlayerCount())
			local numberOfBotsToSpawn = self._BotsToSpawnInWave - self._SpawnedBotsInCurrentWave
			if numberOfBotsToSpawn > s_SlotsLeft then
				numberOfBotsToSpawn = s_SlotsLeft
			end
			self:SpawnWayBots(nil, numberOfBotsToSpawn, true, 0, 0, Config.BotTeam)
		else
			-- all bots spawned. Check for alive bots
			if m_BotManager:GetAliveBotCount() <= Config.ZombiesAliveForNextWave then
				ChatManager:Yell("Wave finished, new wave starts in a few seconds", 7.0)
				self._FirstSpawnDelay = Config.TimeBetweenWaves
				self._CurrentSpawnWave = self._CurrentSpawnWave + 1
				self._SpawnedBotsInCurrentWave = 0
				self:UpdateWaveConfig()
			end
		end

	elseif Globals.SpawnMode == SpawnModes.keep_playercount then
		for i = 1, Globals.NrOfTeams do
			if s_PlayerTeam == i then
				s_TargetTeamCount[i] = 0
			else
				s_TargetTeamCount[i] = Config.InitNumberOfBots / (Globals.NrOfTeams - 1)
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
				self:SpawnWayBots(nil, s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
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

	-- INCREMENT WITH PLAYER.
	elseif Globals.SpawnMode == SpawnModes.increment_with_players then
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
					self:SpawnWayBots(nil, s_TargetBotCountPerEnemyTeam - s_TeamCount[i], true, 0, 0, i)
				elseif s_TeamCount[i] > s_TargetBotCountPerEnemyTeam then
					m_BotManager:KillAll(s_TeamCount[i] - s_TargetBotCountPerEnemyTeam, i)
				end
			end
		end

	-- FIXED NUMBER TO SPAWN.
	elseif Globals.SpawnMode == SpawnModes.fixed_number then

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
					self:SpawnWayBots(nil, s_TargetBotCountPerEnemyTeam - s_TeamCount[i], true, 0, 0, i)
				elseif s_TeamCount[i] > s_TargetBotCountPerEnemyTeam then
					m_BotManager:KillAll(s_TeamCount[i] - s_TargetBotCountPerEnemyTeam, i)
				end
			end
		end

	elseif Globals.SpawnMode == SpawnModes.manual then
		if self._FirstSpawnInLevel then
			for i = 1, Globals.NrOfTeams do
				self:SpawnWayBots(nil, s_TeamCount[i] - s_CountPlayers[i], true, 0, 0, i)
			end
		end
	end
end

---@param p_ExistingBot Bot
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
		local s_Name = m_BotManager:FindNextBotName()

		if s_Name ~= nil then
			local s_Transform = LinearTransform()
			s_Transform.trans = p_Player.soldier.worldTransform.trans + (p_Player.soldier.worldTransform.forward * i * p_Spacing)
			local s_Bot = m_BotManager:CreateBot(s_Name, m_BotManager:GetBotTeam(), SquadId.SquadNone)

			if not s_Bot then
				return
			end

			s_Bot:SetVarsStatic(p_Player)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

---@param p_Player Player
---@param p_Height integer
function BotSpawner:SpawnBotTower(p_Player, p_Height)
	for i = 1, p_Height do
		local s_Name = m_BotManager:FindNextBotName()

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
			local s_Name = m_BotManager:FindNextBotName()

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

				s_Bot:SetVarsStatic(p_Player)
				self:_SpawnBot(s_Bot, s_Transform, true)
			end
		end
	end
end

---@param p_Player Player
---@param p_Amount integer
---@param p_UseRandomWay boolean
---@param p_ActiveWayIndex? integer
---@param p_IndexOnPath? integer
---@param p_TeamId? TeamId|integer
function BotSpawner:SpawnWayBots(p_Player, p_Amount, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_TeamId)
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

-- =============================================
-- Private Functions
-- =============================================

-- =============================================
-- New Spawn Method
-- =============================================

---@param p_Bot Bot
---@param p_SetKit boolean
function BotSpawner:_SelectLoadout(p_Bot, p_SetKit)
	local s_WriteNewKit = (p_SetKit or Config.BotNewLoadoutOnSpawn)

	if not s_WriteNewKit and (p_Bot.m_Color == nil or p_Bot.m_Kit == nil or p_Bot.m_ActiveWeapon == nil) then
		s_WriteNewKit = true
	end

	local s_BotColor = Config.BotColor
	local s_BotKit = Config.BotKit

	if s_WriteNewKit then
		if s_BotColor == BotColors.RANDOM_COLOR then
			s_BotColor = MathUtils:GetRandomInt(1, BotColors.Count - 1) -- Color enum goes from 1 to 13.
		end

		if s_BotKit == BotKits.RANDOM_KIT then
			s_BotKit = self:_GetSpawnBotKit()
		end

		p_Bot.m_Color = s_BotColor
		p_Bot.m_Kit = s_BotKit
	else
		s_BotColor = p_Bot.m_Color
		s_BotKit = p_Bot.m_Kit
	end

	p_Bot:ResetSpawnVars()

	self:_SetBotWeapons(p_Bot, s_WriteNewKit)

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
						elseif s_ClosestDistance > s_TargetLocation:Distance(s_Entity.transform.trans) then
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

---@param p_Player Player
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

	if p_ExistingBot ~= nil then
		s_IsRespawn = true
	else
		s_Name = m_BotManager:FindNextBotName()
	end

	local s_TeamId = p_ForcedTeam
	local s_SquadId = SquadId.SquadNone

	if s_TeamId == nil then
		s_TeamId = m_BotManager:GetBotTeam()
	end

	if s_IsRespawn then
		s_TeamId = p_ExistingBot.m_Player.teamId
		s_SquadId = p_ExistingBot.m_Player.squadId
	else
		s_SquadId = self:_GetSquadToJoin(s_TeamId)
	end

	local s_InverseDirection = nil

	if s_Name ~= nil or s_IsRespawn then
		if Config.SpawnMethod == SpawnMethod.Spawn then
			local s_Bot = self:GetBot(p_ExistingBot, s_Name, s_TeamId, s_SquadId)

			if s_Bot == nil then
				return
			end

			self:_SelectLoadout(s_Bot, true)
			self:_TriggerSpawn(s_Bot)
			table.insert(self._BotsWithoutPath, s_Bot)
			return
		end

		-- Find a spawn point.
		if p_UseRandomWay or p_ActiveWayIndex == nil or p_ActiveWayIndex == 0 then
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
				end

				if s_IsRespawn then
					p_ExistingBot:SetVarsWay(nil, true, 0, 0, false)
					self:_SpawnBot(p_ExistingBot, s_Transform, false)

					if p_ExistingBot:_EnterVehicleEntity(s_SpawnEntity, false) ~= 0 then
						p_ExistingBot:Kill()
					else
						p_ExistingBot:FindVehiclePath(s_SpawnEntity.transform.trans)
					end
				else
					local s_Bot = m_BotManager:CreateBot(s_Name, s_TeamId, s_SquadId)

					if s_Bot ~= nil then
						-- Check for first one in squad.
						if (TeamSquadManager:GetSquadPlayerCount(s_TeamId, s_SquadId) == 1) then
							s_Bot.m_Player:SetSquadLeader(true, false) -- Not private.
						end

						s_Bot:SetVarsWay(nil, true, 0, 0, false)
						self:_SpawnBot(s_Bot, s_Transform, true)

						if s_Bot:_EnterVehicleEntity(s_SpawnEntity, false) ~= 0 then
							s_Bot:Kill()
						else
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

		if s_IsRespawn then
			p_ExistingBot:SetVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, s_InverseDirection)
			self:_SpawnBot(p_ExistingBot, s_Transform, false)

			-- Check for vehicle of squad.
			if s_SquadSpawnVehicle ~= nil then
				p_ExistingBot:_EnterVehicleEntity(s_SquadSpawnVehicle, false)
			end
		else
			local s_Bot = m_BotManager:CreateBot(s_Name, s_TeamId, s_SquadId)

			if s_Bot ~= nil then
				-- Check for first one in squad.
				if (TeamSquadManager:GetSquadPlayerCount(s_TeamId, s_SquadId) == 1) then
					s_Bot.m_Player:SetSquadLeader(true, false) -- Not private.
				end

				s_Bot:SetVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, s_InverseDirection)
				self:_SpawnBot(s_Bot, s_Transform, true)

				-- Check for vehicle of squad.
				if s_SquadSpawnVehicle ~= nil then
					s_Bot:_EnterVehicleEntity(s_SquadSpawnVehicle, false)
				end
			end
		end
	end
end

---@param p_Bot Bot
---@param p_Transform LinearTransform
---@param p_SetKit boolean
function BotSpawner:_SpawnBot(p_Bot, p_Transform, p_SetKit)
	local s_WriteNewKit = (p_SetKit or Config.BotNewLoadoutOnSpawn)

	if not s_WriteNewKit and (p_Bot.m_Color == nil or p_Bot.m_Kit == nil or p_Bot.m_ActiveWeapon == nil) then
		s_WriteNewKit = true
	end

	local s_BotColor = Config.BotColor
	local s_BotKit = Config.BotKit

	if s_WriteNewKit then
		if s_BotColor == BotColors.RANDOM_COLOR then
			s_BotColor = MathUtils:GetRandomInt(1, BotColors.Count - 1) -- Color enum goes from 1 to 13.
		end

		if s_BotKit == BotKits.RANDOM_KIT then
			s_BotKit = self:_GetSpawnBotKit()
		end

		p_Bot.m_Color = s_BotColor
		p_Bot.m_Kit = s_BotKit
	else
		s_BotColor = p_Bot.m_Color
		s_BotKit = p_Bot.m_Kit
	end


	self:_SetBotWeapons(p_Bot, s_WriteNewKit)
	p_Bot:ResetSpawnVars()

	-- Create kit and appearance.
	if p_Bot.m_Player.selectedKit == nil then
		-- SoldierBlueprint
		p_Bot.m_Player.selectedKit = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier') -- MpSoldier
	end

	self:_SetKitAndAppearance(p_Bot, s_BotKit, s_BotColor)

	m_BotManager:SpawnBot(p_Bot, p_Transform, CharacterPoseType.CharacterPoseType_Stand)

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

	if Config.UseVehicles and #g_GameDirector:GetSpawnableVehicle(p_TeamId) > 0 then
		return "SpawnAtVehicle"
	end

	if Config.AABots and #g_GameDirector:GetStationaryAas(p_TeamId) > 0 then
		return "SpawnInAa"
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

---@param p_Bot Bot|integer
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
	if s_TeamId % 2 == 1 then -- US
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
	else -- RU
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

	if Globals.RemoveKitVisuals then
		-- for Civilianizer-mod:
		p_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, {})
	else
		p_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, { s_Appearance })
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

	local s_KnifeInput = p_Bot.m_Knife

	p_SoldierCustomization.activeSlot = WeaponSlot.WeaponSlot_7
	p_SoldierCustomization.removeAllExistingWeapons = false

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
	p_SoldierCustomization.activeSlot = WeaponSlot.WeaponSlot_7
	p_SoldierCustomization.weapons:add(s_Knife)

	return p_SoldierCustomization
end

---@return BotKits|integer
function BotSpawner:_GetSpawnBotKit()
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
		'', -- Standard.
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
---@param p_NewWeapons boolean
function BotSpawner:_SetBotWeapons(p_Bot, p_NewWeapons)
	if p_NewWeapons then
		local s_Knife = Config.Knife

		if Config.UseRandomWeapon then
			s_Knife = Weapons[MathUtils:GetRandomInt(1, #Weapons)]
		end

		p_Bot.m_Knife = m_WeaponList:getWeapon(s_Knife)
	end

	p_Bot.m_ActiveWeapon = p_Bot.m_Knife
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

			l_Player.teamId = s_NewTeam
		end
	end
end

if g_BotSpawner == nil then
	---@type BotSpawner
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner
