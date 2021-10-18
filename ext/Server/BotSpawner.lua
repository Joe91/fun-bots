class('BotSpawner')

require('Model/SpawnSet')

local m_NodeCollection = require('__shared/NodeCollection')
local m_BotManager = require('BotManager')
local m_WeaponList = require('__shared/WeaponList')
local m_Utilities = require('__shared/Utilities')
local m_Logger = Logger("BotSpawner", Debug.Server.BOT)

function BotSpawner:__init()
	self:RegisterVars()
end

function BotSpawner:RegisterVars()
	self._BotSpawnTimer = 0
	self._LastRound = 0
	self._PlayerUpdateTimer = 0
	self._SpawnInObjectsTimer = 0
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY
	self._UpdateActive = false
	self._SpawnSets = {}
	self._KickPlayers = {}
	self._BotsWithoutPath = {}
end

-- =============================================
-- Events
-- =============================================

-- =============================================
	-- Level Events
-- =============================================

function BotSpawner:OnLevelLoaded(p_Round)
	m_Logger:Write("on level loaded on spawner")
	self._FirstSpawnInLevel = true
	self._PlayerUpdateTimer = 0
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY

	if (Config.TeamSwitchMode == TeamSwitcheModes.SwitchForRoundTwo and p_Round ~= self._LastRound) or
	(Config.TeamSwitchMode == TeamSwitcheModes.AlwaysSwitchTeams) then
		m_Logger:Write("switch teams")
		self:_SwitchTeams()
	end

	self._LastRound = p_Round
end

function BotSpawner:OnLevelDestroy()
	self._SpawnSets = {}
	self._UpdateActive = false
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = Registry.BOT_SPAWN.FIRST_SPAWN_DELAY
	self._PlayerUpdateTimer = 0
end

-- =============================================
	-- Update Events
-- =============================================

function BotSpawner:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	if self._FirstSpawnInLevel then
		if self._FirstSpawnDelay <= 0 then
			m_BotManager:ConfigGlobals()
			self:UpdateBotAmountAndTeam()
			self._PlayerUpdateTimer = 0
			self._FirstSpawnInLevel = false
		else
			self._FirstSpawnDelay = self._FirstSpawnDelay - p_DeltaTime
		end
	else
		self._PlayerUpdateTimer = self._PlayerUpdateTimer + p_DeltaTime

		if self._PlayerUpdateTimer > 2 then
			self._PlayerUpdateTimer = 0
			self:UpdateBotAmountAndTeam()
		end
	end

	if #self._SpawnSets > 0 then
		if self._BotSpawnTimer > 0.2 then --time to wait between spawn. 0.2 works
			self._BotSpawnTimer = 0
			local s_SpawnSet = table.remove(self._SpawnSets)
			self:_SpawnSingleWayBot(s_SpawnSet.m_PlayerVarOfBot, s_SpawnSet.m_UseRandomWay, s_SpawnSet.m_ActiveWayIndex, s_SpawnSet.m_IndexOnPath, nil, s_SpawnSet.m_Team)
		end

		self._BotSpawnTimer = self._BotSpawnTimer + p_DeltaTime
	else
		if self._UpdateActive then
			self._UpdateActive = false

			if Globals.SpawnMode ~= SpawnModes.manual then
				--garbage-collection of unwanted bots
				m_BotManager:DestroyDisabledBots()
				m_BotManager:RefreshTables()
			end
		end
	end

	--kick players named after bots
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
				--local s_Node = m_NodeCollection:Find(s_Position, 5)
				local s_Node = g_GameDirector:FindClosestPath(s_Position, false)

				if s_Node ~= nil then
					l_Bot:SetVarsWay(nil, true, s_Node.PathIndex, s_Node.PointIndex, false)
					table.remove(self._BotsWithoutPath, i)
					local s_SoldierCustomization = nil
					local s_SoldierKit = nil
					local s_Appearance = nil
					s_SoldierKit, s_Appearance, s_SoldierCustomization = self:_GetKitAppearanceCustomization(l_Bot.m_Player.teamId, l_Bot.m_Kit, l_Bot.m_Color, l_Bot.m_Primary, l_Bot.m_Pistol, l_Bot.m_Knife, l_Bot.m_PrimaryGadget, l_Bot.m_SecondaryGadget, l_Bot.m_Grenade)
					l_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, {s_Appearance})
					l_Bot.m_Player.soldier:ApplyCustomization(s_SoldierCustomization)
					self:_ModifyWeapon(l_Bot.m_Player.soldier)
					-- for Civilianizer-mod:
					Events:Dispatch('Bot:SoldierEntity', l_Bot.m_Player.soldier)
					break
				end
			end
		end
	end
end

-- =============================================
	-- Player Events
-- =============================================

function BotSpawner:OnPlayerJoining(p_Name)
	-- detect BOT-Names
	if string.find(p_Name, BOT_TOKEN) == 1 then --check if name starts with bot-token
		table.insert(self._KickPlayers, p_Name)

		if m_BotManager:GetBotByName(p_Name) ~= nil then
			table.insert(Globals.IgnoreBotNames, p_Name)
			m_BotManager:DestroyBot(p_Name)
		end
	end
end

function BotSpawner:OnTeamChange(p_Player, p_TeamId, p_SquadId)
	if Config.BotTeam ~= TeamId.TeamNeutral then
		if p_Player ~= nil then
			if p_Player.onlineId ~= 0 then -- no bot
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

function BotSpawner:OnKitPickup(p_Player, p_NewCustomization)
	if p_Player.soldier ~= nil then
		if p_Player.soldier.weaponsComponent.weapons[1] ~= nil then
			p_Player.soldier.weaponsComponent.weapons[1].secondaryAmmo = 182
		end

		if p_Player.soldier.weaponsComponent.weapons[2] ~= nil then
			p_Player.soldier.weaponsComponent.weapons[2].secondaryAmmo = 58
		end
	end
end

-- =============================================
	-- Custom Bot Respawn Event
-- =============================================

function BotSpawner:OnRespawnBot(p_BotName)
	local s_Bot = m_BotManager:GetBotByName(p_BotName)
	local s_SpawnMode = s_Bot:GetSpawnMode()

	if s_SpawnMode == BotSpawnModes.RespawnFixedPath then --fixed Way
		local s_WayIndex = s_Bot:GetWayIndex()
		local s_RandIndex = MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_WayIndex))
		self:_SpawnSingleWayBot(nil, false, s_WayIndex, s_RandIndex, s_Bot)
	elseif s_SpawnMode == BotSpawnModes.RespawnRandomPath then --random Way
		self:_SpawnSingleWayBot(nil, true, 0, 0, s_Bot)
	end

	-- fix bug with not counting down the tickets (thanks to HughesMDflyer4)
	if Globals.IsConquest or Globals.IsAssault or Globals.IsDomination then
		TicketManager:SetTicketCount(s_Bot.m_Player.teamId, TicketManager:GetTicketCount(s_Bot.m_Player.teamId) - 1)
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================

function BotSpawner:UpdateBotAmountAndTeam()
	-- keep Slot for next player
	if Config.KeepOneSlotForPlayers then
		local s_PlayerLimit = Globals.MaxPlayers - 1
		local s_AmountToDestroy = PlayerManager:GetPlayerCount() - s_PlayerLimit

		if s_AmountToDestroy > 0 then
			m_BotManager:DestroyAll(s_AmountToDestroy)
		end
	end

	-- if update active do nothing
	if self._UpdateActive then
		return
	else
		self._UpdateActive = true
	end

	-- find all needed vars
	local s_BotCount = m_BotManager:GetActiveBotCount()
	local s_PlayerCount = 0

	local s_BotTeam = m_BotManager:GetBotTeam()
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

				if Globals.IsSdm then -- TODO: Only needed because of VEXT-Bug
					l_Player.squadId = 1
				end
			end
		end

		s_TeamCount[i] = s_CountBots[i] + s_CountPlayers[i]
		s_PlayerCount = s_PlayerCount + s_CountPlayers[i]
	end

	-- kill and destroy bots, if no player left
	if s_PlayerCount == 0 then
		if s_BotCount > 0 or self._FirstSpawnInLevel then
			m_BotManager:KillAll() --trigger once
			self._UpdateActive = true
		else
			self._UpdateActive = false
		end

		return
	end


	-- KEEP PLAYERCOUNT
	if Globals.SpawnMode == SpawnModes.keep_playercount then
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = math.floor(Config.InitNumberOfBots / Globals.NrOfTeams)
			end
		else
			for i = 1, Globals.NrOfTeams do
				if s_BotTeam ~= i then
					s_TargetTeamCount[i] = 0
				else
					s_TargetTeamCount[i] = Config.InitNumberOfBots
				end
			end
		end
		--limit team count
		for i = 1, Globals.NrOfTeams do
			if Globals.NrOfTeams == 2 then
				if i ~= s_BotTeam then
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

		-- move players if needed
		if s_PlayerCount >= Registry.BOT_TEAM_BALANCING.THRESHOLD then --use threshold
			local s_MinTargetPlayersPerTeam = math.floor(s_PlayerCount / Globals.NrOfTeams) - Registry.BOT_TEAM_BALANCING.ALLOWED_DIFFERENCE
			for i = 1, Globals.NrOfTeams do
				if s_CountPlayers[i] < s_MinTargetPlayersPerTeam then
					for _,l_Player in pairs(PlayerManager:GetPlayers()) do
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

	-- BALANCED teams
	elseif Globals.SpawnMode == SpawnModes.balanced_teams then
		local s_maxPlayersInOneTeam = 0

		for i = 1, Globals.NrOfTeams do
			if s_CountPlayers[i] > s_maxPlayersInOneTeam then
				s_maxPlayersInOneTeam = s_CountPlayers[i]
			end
		end

		local targetCount = Config.InitNumberOfBots + math.floor(((s_maxPlayersInOneTeam - 1) * Config.NewBotsPerNewPlayer) + 0.5)

		for i = 1, Globals.NrOfTeams do
			s_TargetTeamCount[i] = targetCount

			if s_TargetTeamCount[i] > Globals.MaxBotsPerTeam then
				s_TargetTeamCount[i] = Globals.MaxBotsPerTeam
			end

			if Globals.NrOfTeams == 2 and i ~= s_BotTeam then
				s_TargetTeamCount[i] = math.floor((s_TargetTeamCount[i] * Config.FactorPlayerTeamCount) + 0.5)
			end
		end

		for i = 1, Globals.NrOfTeams do
			if s_TeamCount[i] < s_TargetTeamCount[i] then
				self:SpawnWayBots(nil, s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
			elseif s_TeamCount[i] > s_TargetTeamCount[i] then
				m_BotManager:KillAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
			end
		end

	-- INCREMENT WITH PLAYER
	elseif Globals.SpawnMode == SpawnModes.increment_with_players then
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = 0

				if s_CountPlayers[i] > 0 then
					for j = 1, Globals.NrOfTeams do
						if i ~= j then
							local s_TempCount = Config.InitNumberOfBots + math.floor(((s_CountPlayers[i] - 1) * Config.NewBotsPerNewPlayer) + 0.5)

							if s_TempCount > s_TargetTeamCount[j] then
								s_TargetTeamCount[j] = s_TempCount
							end
						end
					end
				end
			end
			-- limit team count
			for i = 1, Globals.NrOfTeams do
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
		else
			-- check for bots in wrong team
			for i = 1, Globals.NrOfTeams do
				if i ~= s_BotTeam and s_CountBots[i] > 0 then
					m_BotManager:KillAll(nil, i)
				end
			end

			local s_TargetBotCount = Config.InitNumberOfBots + math.floor(((s_PlayerCount - 1) * Config.NewBotsPerNewPlayer) + 0.5)

			if s_TargetBotCount > Globals.MaxBotsPerTeam then
				s_TargetBotCount = Globals.MaxBotsPerTeam
			end

			local s_AmountToSpawn = s_TargetBotCount - s_BotCount

			if s_AmountToSpawn > 0 then
				self._BotSpawnTimer = -5.0
				self:SpawnWayBots(nil, s_AmountToSpawn, true, 0, 0, s_BotTeam)
			end

			if s_AmountToSpawn < 0 then
				m_BotManager:KillAll(-s_AmountToSpawn)
			end
		end
	-- FIXED NUMBER TO SPAWN
	elseif Globals.SpawnMode == SpawnModes.fixed_number then
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = math.floor(Config.InitNumberOfBots/Globals.NrOfTeams)

				if Globals.NrOfTeams == 2 then
					if i ~= s_BotTeam then
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
		else
			-- check for bots in wrong team
			for i = 1, Globals.NrOfTeams do
				if i ~= s_BotTeam and s_CountBots[i] > 0 then
					m_BotManager:KillAll(nil, i)
				end
			end

			local s_TargetBotCount = Config.InitNumberOfBots

			if s_TargetBotCount > Globals.MaxBotsPerTeam then
				s_TargetBotCount = Globals.MaxBotsPerTeam
			end

			local s_AmountToSpawn = s_TargetBotCount - s_BotCount

			if s_AmountToSpawn > 0 then
				self._BotSpawnTimer = -5.0
				self:SpawnWayBots(nil, s_AmountToSpawn, true, 0, 0, s_BotTeam)
			end

			if s_AmountToSpawn < 0 then
				m_BotManager:KillAll(-s_AmountToSpawn)
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

function BotSpawner:SpawnBotRow(p_Player, p_Length, p_Spacing)
	for i = 1, p_Length do
		local s_Name = m_BotManager:FindNextBotName()

		if s_Name ~= nil then
			local s_Transform = LinearTransform()
			s_Transform.trans = p_Player.soldier.worldTransform.trans + (p_Player.soldier.worldTransform.forward * i * p_Spacing)
			local s_Bot = m_BotManager:CreateBot(s_Name, m_BotManager:GetBotTeam(), SquadId.SquadNone)
			s_Bot:SetVarsStatic(p_Player)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

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
			s_Bot:SetVarsStatic(p_Player)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

function BotSpawner:SpawnBotGrid(p_Player, p_Rows, p_Columns, p_Spacing)
	for i = 1, p_Rows do
		for j = 1, p_Columns do
			local s_Name = m_BotManager:FindNextBotName()

			if s_Name ~= nil then
				local s_Yaw = p_Player.input.authoritativeAimingYaw
				local s_Transform = LinearTransform()
				s_Transform.trans.x = p_Player.soldier.worldTransform.trans.x + (i * math.cos(s_Yaw + (math.pi / 2)) * p_Spacing) + ((j - 1) * math.cos(s_Yaw) * p_Spacing)
				s_Transform.trans.y = p_Player.soldier.worldTransform.trans.y
				s_Transform.trans.z = p_Player.soldier.worldTransform.trans.z + (i * math.sin(s_Yaw + (math.pi / 2)) * p_Spacing) + ((j - 1) * math.sin(s_Yaw) * p_Spacing)
				local s_Bot = m_BotManager:CreateBot(s_Name, m_BotManager:GetBotTeam(), SquadId.SquadNone)
				s_Bot:SetVarsStatic(p_Player)
				self:_SpawnBot(s_Bot, s_Transform, true)
			end
		end
	end
end


function BotSpawner:SpawnWayBots(p_Player, p_Amount, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_TeamId)
	if #m_NodeCollection:GetPaths() <= 0 then
		return
	end

	if p_Amount <= 0 then
		m_Logger:Error("can't spawn zero or negative amount of bots")
	end

	-- check for amount available
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
		local s_SpawnSet = SpawnSet()
		s_SpawnSet.m_PlayerVarOfBot = nil
		s_SpawnSet.m_UseRandomWay = p_UseRandomWay
		s_SpawnSet.m_ActiveWayIndex = p_ActiveWayIndex
		s_SpawnSet.m_IndexOnPath = p_IndexOnPath
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

function BotSpawner:_SelectLoadout(p_Bot, p_SetKit)
	local s_WriteNewKit = (p_SetKit or Config.BotNewLoadoutOnSpawn)

	if not s_WriteNewKit and (p_Bot.m_Color == nil or p_Bot.m_Kit == nil or p_Bot.m_ActiveWeapon == nil) then
		s_WriteNewKit = true
	end

	local s_BotColor = Config.BotColor
	local s_BotKit = Config.BotKit

	if s_WriteNewKit then
		if s_BotColor == BotColors.RANDOM_COLOR then
			s_BotColor = MathUtils:GetRandomInt(1, BotColors.Count-1) -- color enum goes from 1 to 13
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
	self:_SetBotWeapons(p_Bot, s_BotKit, s_WriteNewKit)

	if p_Bot.m_Player.selectedKit == nil then
		-- SoldierBlueprint
		p_Bot.m_Player.selectedKit = ResourceManager:SearchForInstanceByGuid(Guid('261E43BF-259B-41D2-BF3B-9AE4DDA96AD2'))
	end

	-- TODO: do it properly
	local s_SoldierKit = ResourceManager:SearchForInstanceByGuid(Guid('47949491-F672-4CD6-998A-101B7740F919'))
	local s_SoldierPersistance = ResourceManager:SearchForInstanceByGuid(Guid('23CFF61F-F1E2-4306-AECE-2819E35484D2'))
	p_Bot.m_Player:SelectUnlockAssets(s_SoldierKit, {s_SoldierPersistance})
	p_Bot.m_Player:SelectWeapon(WeaponSlot.WeaponSlot_0, ResourceManager:SearchForInstanceByGuid(Guid('A7278B05-8D76-4A40-B65D-4414490F6886')), {})
end

function BotSpawner:_TriggerSpawn(p_Bot)
	local s_CurrentGameMode = SharedUtils:GetCurrentGameMode()

	if s_CurrentGameMode:match("DeathMatch") or
	s_CurrentGameMode:match("Domination") or
	s_CurrentGameMode:match("GunMaster") or
	s_CurrentGameMode:match("Scavenger") or
	s_CurrentGameMode:match("TankSuperiority") or
	s_CurrentGameMode:match("CaptureTheFlag") then
		self:_DeathMatchSpawn(p_Bot)
	elseif s_CurrentGameMode:match("Rush") then
		-- seems to be the same as DeathMatchSpawn
		-- but it has vehicles
		self:_RushSpawn(p_Bot)
	elseif s_CurrentGameMode:match("Conquest") then
		-- event + target spawn ("ID_H_US_B", "_ID_H_US_HQ", etc.)
		self:_ConquestSpawn(p_Bot)
	end
end

function BotSpawner:_DeathMatchSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.m_Player, true, false, false, false, false, false, p_Bot.m_Player.teamId)
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

function BotSpawner:_RushSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.m_Player, true, false, false, false, false, false, p_Bot.m_Player.teamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCharacterSpawnEntity")
	local s_Entity = s_EntityIterator:Next()

	while s_Entity do
		if s_Entity.data:Is('CharacterSpawnReferenceObjectData') then
			if CharacterSpawnReferenceObjectData(s_Entity.data).team == p_Bot.m_Player.teamId then
				-- skip if it is a vehiclespawn
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

function BotSpawner:_ConquestSpawn(p_Bot)
	local s_Event = ServerPlayerEvent("Spawn", p_Bot.m_Player, true, false, false, false, false, false, p_Bot.m_Player.teamId)
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

function BotSpawner:_FindAttackedSpawnPoint(p_TeamId)
	local s_BestSpawnPoint = nil
	local s_LowestFlagLocation = 100.0
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
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

function BotSpawner:_FindClosestSpawnPoint(p_TeamId)
	local s_BestSpawnPoint = nil
	local s_ClosestDistance = 0
	-- Enemy and Neutralized CapturePoints
	local s_TargetLocation = self:_FindTargetLocation(p_TeamId)
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
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

							-- for the case that the enemies have no place to spawn
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

function BotSpawner:_FindTargetLocation(p_TeamId)
	local s_TargetLocation = nil
	local s_EntityIterator = EntityManager:GetIterator("ServerCapturePointEntity")
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

	-- return enemy base location (or nil) if all capture points captured by bot team already
	return s_TargetLocation
end

-- =============================================
	-- Some more Functions
-- =============================================

function BotSpawner:_SpawnSingleWayBot(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_ExistingBot, p_ForcedTeam)
	local s_SpawnPoint = nil
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

		-- find a spawnpoint
		if p_UseRandomWay or p_ActiveWayIndex == nil or p_ActiveWayIndex == 0 then
			s_SpawnPoint, s_InverseDirection = self:_GetSpawnPoint(s_TeamId, s_SquadId)
			-- special spawn in vehicles
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
					p_ExistingBot:_EnterVehicleEntity(s_SpawnEntity)
					p_ExistingBot:FindVehiclePath(s_SpawnEntity.transform.trans)
				else
					local s_Bot = m_BotManager:CreateBot(s_Name, s_TeamId, s_SquadId)
		
					if s_Bot ~= nil then
						-- check for first one in squad
						if (TeamSquadManager:GetSquadPlayerCount(s_TeamId, s_SquadId) == 1) then
							s_Bot.m_Player:SetSquadLeader(true, false) -- not private
						end
		
						s_Bot:SetVarsWay(nil, true, 0, 0, false)
						self:_SpawnBot(s_Bot, s_Transform, true)
						s_Bot:_EnterVehicleEntity(s_SpawnEntity)
						s_Bot:FindVehiclePath(s_SpawnEntity.transform.trans)
					end
				end
				return
			end
		else
			s_SpawnPoint = m_NodeCollection:Get(p_IndexOnPath, p_ActiveWayIndex)
		end

		if s_SpawnPoint == nil then
			return
		else
			p_IndexOnPath = s_SpawnPoint.PointIndex
			p_ActiveWayIndex = s_SpawnPoint.PathIndex
		end

		--find out direction, if path has a return point
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
		else
			local s_Bot = m_BotManager:CreateBot(s_Name, s_TeamId, s_SquadId)

			if s_Bot ~= nil then
				-- check for first one in squad
				if (TeamSquadManager:GetSquadPlayerCount(s_TeamId, s_SquadId) == 1) then
					s_Bot.m_Player:SetSquadLeader(true, false) -- not private
				end

				s_Bot:SetVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, s_InverseDirection)
				self:_SpawnBot(s_Bot, s_Transform, true)
			end
		end
	end
end

function BotSpawner:_SpawnBot(p_Bot, p_Trans, p_SetKit)
	local s_WriteNewKit = (p_SetKit or Config.BotNewLoadoutOnSpawn)

	if not s_WriteNewKit and (p_Bot.m_Color == nil or p_Bot.m_Kit == nil or p_Bot.m_ActiveWeapon == nil) then
		s_WriteNewKit = true
	end

	local s_BotColor = Config.BotColor
	local s_BotKit = Config.BotKit

	if s_WriteNewKit then
		if s_BotColor == BotColors.RANDOM_COLOR then
			s_BotColor = MathUtils:GetRandomInt(1, BotColors.Count-1) -- color enum goes from 1 to 13
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

	self:_SetBotWeapons(p_Bot, s_BotKit, s_WriteNewKit)

	p_Bot:ResetSpawnVars()

	-- create kit and appearance
	local s_SoldierBlueprint = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier')
	local s_SoldierCustomization = nil
	local s_SoldierKit = nil
	local s_Appearance = nil
	s_SoldierKit, s_Appearance, s_SoldierCustomization = self:_GetKitAppearanceCustomization(p_Bot.m_Player.teamId, s_BotKit, s_BotColor, p_Bot.m_Primary, p_Bot.m_Pistol, p_Bot.m_Knife, p_Bot.m_PrimaryGadget, p_Bot.m_SecondaryGadget, p_Bot.m_Grenade)

	-- Create the transform of where to spawn the bot at.
	local s_Transform = LinearTransform()
	s_Transform = p_Trans

	-- And then spawn the bot. This will create and return a new SoldierEntity object.
	-- for Civilianizer-Mod
	if Globals.RemoveKitVisuals then
		m_BotManager:SpawnBot(p_Bot, s_Transform, CharacterPoseType.CharacterPoseType_Stand, s_SoldierBlueprint, s_SoldierKit, {})
	else
		m_BotManager:SpawnBot(p_Bot, s_Transform, CharacterPoseType.CharacterPoseType_Stand, s_SoldierBlueprint, s_SoldierKit, { s_Appearance })
	end

	p_Bot.m_Player.soldier:ApplyCustomization(s_SoldierCustomization)
	self:_ModifyWeapon(p_Bot.m_Player.soldier)

	-- for Civilianizer-mod:
	Events:Dispatch('Bot:SoldierEntity', p_Bot.m_Player.soldier)
end

function BotSpawner:_GetSpawnPoint(p_TeamId, p_SquadId)
	local s_ActiveWayIndex = 0
	local s_IndexOnPath = 0

	local s_InvertDirection = nil
	local s_TargetNode = nil
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
	-- spawn at base, squad-mate, captured flag
	if Globals.IsConquest then
		s_ActiveWayIndex, s_IndexOnPath, s_InvertDirection = g_GameDirector:GetSpawnPath(p_TeamId, p_SquadId, false)

		if s_ActiveWayIndex == 0 then
			-- something went wrong. use random path
			m_Logger:Write("no base or capturepoint found to spawn")
			return
		end

		s_TargetNode = m_NodeCollection:Get(s_IndexOnPath, s_ActiveWayIndex)
	-- RUSH
	-- spawn at base (of zone) or squad-mate
	elseif Globals.IsRush then
		s_ActiveWayIndex, s_IndexOnPath, s_InvertDirection = g_GameDirector:GetSpawnPath(p_TeamId, p_SquadId, true)

		if s_ActiveWayIndex == 0 then
			-- something went wrong. use random path
			m_Logger:Write("no base found to spawn")
			return
		end

		s_TargetNode = m_NodeCollection:Get(s_IndexOnPath, s_ActiveWayIndex)
	-- TDM / GM / SCAVANGER
	-- spawn away from other team
	else
		while not s_ValidPointFound and s_TrysDone < s_MaximumTrys do
			-- get new point
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

			--check for nearby player
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

	return s_TargetNode, s_InvertDirection
end

function BotSpawner:_GetSquadToJoin(p_TeamId) -- TODO: create a more advanced algorithm?
	if Globals.IsSdm then
		return 1
	else
		for i = 1, SquadId.SquadIdCount - 1 do -- for i = 9, SquadId.SquadIdCount - 1 do -- first 8 squads for real players
			if TeamSquadManager:GetSquadPlayerCount(p_TeamId, i) < 4 then
				return i
			end
		end
	end

	return 0
end

function BotSpawner:_GetKitAppearanceCustomization(p_TeamId, p_Kit, p_Color, p_Primary, p_Pistol, p_Knife, p_Gadget1, p_Gadget2, p_Grenade)
	-- Create the loadouts
	local s_SoldierKit = nil
	local s_Appearance = nil
	local s_SoldierCustomization = CustomizeSoldierData()

	local s_PistolWeapon = ResourceManager:SearchForDataContainer(p_Pistol:getResourcePath())
	local s_KnifeWeapon = ResourceManager:SearchForDataContainer(p_Knife:getResourcePath())
	local s_Gadget1Weapon = ResourceManager:SearchForDataContainer(p_Gadget1:getResourcePath())
	local s_Gadget2Weapon = ResourceManager:SearchForDataContainer(p_Gadget2:getResourcePath())
	local s_GrenadeWeapon = ResourceManager:SearchForDataContainer(p_Grenade:getResourcePath())

	s_SoldierCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	s_SoldierCustomization.removeAllExistingWeapons = true

	local s_PrimaryWeapon = UnlockWeaponAndSlot()
	s_PrimaryWeapon.slot = WeaponSlot.WeaponSlot_0

	local s_PrimaryWeaponResource = ResourceManager:SearchForDataContainer(p_Primary:getResourcePath())
	s_PrimaryWeapon.weapon = SoldierWeaponUnlockAsset(s_PrimaryWeaponResource)
	self:_SetAttachments(s_PrimaryWeapon, p_Primary:getAllAttachements())

	local s_PrimaryGadget = UnlockWeaponAndSlot()
	s_PrimaryGadget.weapon = SoldierWeaponUnlockAsset(s_Gadget1Weapon)

	if p_Kit == BotKits.Assault or p_Kit == BotKits.Support then
		s_PrimaryGadget.slot = WeaponSlot.WeaponSlot_4
	else
		s_PrimaryGadget.slot = WeaponSlot.WeaponSlot_2
	end

	local s_SecondaryGadget = UnlockWeaponAndSlot()
	s_SecondaryGadget.weapon = SoldierWeaponUnlockAsset(s_Gadget2Weapon)
	s_SecondaryGadget.slot = WeaponSlot.WeaponSlot_5

	local s_Grenade = UnlockWeaponAndSlot()
	s_Grenade.weapon = SoldierWeaponUnlockAsset(s_GrenadeWeapon)
	s_Grenade.slot = WeaponSlot.WeaponSlot_6

	local s_SecondaryWeapon = UnlockWeaponAndSlot()
	s_SecondaryWeapon.weapon = SoldierWeaponUnlockAsset(s_PistolWeapon)
	s_SecondaryWeapon.slot = WeaponSlot.WeaponSlot_1

	local s_Knife = UnlockWeaponAndSlot()
	s_Knife.weapon = SoldierWeaponUnlockAsset(s_KnifeWeapon)
	s_Knife.slot = WeaponSlot.WeaponSlot_7

	local s_ColorString = ""

	for l_Key, l_Value in pairs(BotColors) do
		if l_Value == p_Color then
			s_ColorString = l_Key
			break
		end
	end

	if p_TeamId % 2 == 1 then -- US
		if p_Kit == BotKits.Assault then --assault
			s_Appearance = self:_FindAppearance('Us', 'Assault', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Assault')
		elseif p_Kit == BotKits.Engineer then --engineer
			s_Appearance = self:_FindAppearance('Us', 'Engi', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Engineer')
		elseif p_Kit == BotKits.Support then --support
			s_Appearance = self:_FindAppearance('Us', 'Support', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Support')
		else --recon
			s_Appearance = self:_FindAppearance('Us', 'Recon', s_ColorString)
			s_SoldierKit = self:_FindKit('US', 'Recon')
		end
	else -- RU
		if p_Kit == BotKits.Assault then --assault
			s_Appearance = self:_FindAppearance('RU', 'Assault', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Assault')
		elseif p_Kit == BotKits.Engineer then --engineer
			s_Appearance = self:_FindAppearance('RU', 'Engi', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Engineer')
		elseif p_Kit == BotKits.Support then --support
			s_Appearance = self:_FindAppearance('RU', 'Support', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Support')
		else --recon
			s_Appearance = self:_FindAppearance('RU', 'Recon', s_ColorString)
			s_SoldierKit = self:_FindKit('RU', 'Recon')
		end
	end

	if Config.ZombieMode then
		s_SoldierCustomization.activeSlot = WeaponSlot.WeaponSlot_7
		s_SoldierCustomization.weapons:add(s_Knife)
	else
		s_SoldierCustomization.weapons:add(s_PrimaryWeapon)
		s_SoldierCustomization.weapons:add(s_SecondaryWeapon)
		s_SoldierCustomization.weapons:add(s_PrimaryGadget)
		s_SoldierCustomization.weapons:add(s_SecondaryGadget)
		s_SoldierCustomization.weapons:add(s_Grenade)
		s_SoldierCustomization.weapons:add(s_Knife)
	end

	return s_SoldierKit, s_Appearance, s_SoldierCustomization
end

function BotSpawner:_GetSpawnBotKit()
	local s_BotKit = MathUtils:GetRandomInt(1, BotKits.Count-1) -- Kit enum goes from 1 to 4
	local s_ChangeKit = false
	--find out, if possible
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

		if(Config.MaxReconBots == -1) or (m_BotManager:GetKitCount(BotKits.Recon) < Config.MaxReconBots) then
			table.insert(s_AvailableKitList, BotKits.Recon)
		end

		if #s_AvailableKitList > 0 then
			s_BotKit = s_AvailableKitList[MathUtils:GetRandomInt(1, #s_AvailableKitList)]
		end
	end

	return s_BotKit
end

-- Tries to find first available kit
-- @param teamName string Values: 'US', 'RU'
-- @param kitName string Values: 'Assault', 'Engineer', 'Support', 'Recon'
function BotSpawner:_FindKit(p_TeamName, p_KitName)

	local s_GameModeKits = {
		'', -- Standard
		'_GM', --Gun Master on XP2 Maps
		'_GM_XP4', -- Gun Master on XP4 Maps
		'_XP4', -- Copy of Standard for XP4 Maps
		'_XP4_SCV' -- Scavenger on XP4 Maps
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

	return
end

function BotSpawner:_FindAppearance(p_TeamName, p_KitName, p_ColorName)
	local s_GameModeAppearances = {
		'MP/', -- Standard
		'MP_XP4/', --Gun Master on XP2 Maps
	}

	--'Persistence/Unlocks/Soldiers/Visual/MP[or:MP_XP4]/Us/MP_US_Assault_Appearance_'..p_ColorName
	for _, l_GameMode in pairs(s_GameModeAppearances) do
		local s_AppearanceString = l_GameMode .. p_TeamName .. '/MP_' .. string.upper(p_TeamName) .. '_' .. p_KitName .. '_Appearance_' .. p_ColorName
		local s_Appearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/'..s_AppearanceString)

		if s_Appearance ~= nil then
			return s_Appearance
		end
	end

	return
end

function BotSpawner:_SetAttachments(p_UnlockWeapon, p_Attachments)
	for _, l_Attachment in pairs(p_Attachments) do
		local s_Asset = ResourceManager:SearchForDataContainer(l_Attachment)

		if s_Asset == nil then
			if Debug.Server.BOT then
				m_Logger:Warning('Attachment invalid [' .. tostring(p_UnlockWeapon.weapon.name) .. ']: ' .. tostring(l_Attachment))
			end
		else
			p_UnlockWeapon.unlockAssets:add(UnlockAsset(s_Asset))
		end
	end
end

function BotSpawner:_SetBotWeapons(p_Bot, p_BotKit, p_NewWeapons)
	if p_NewWeapons then
		if p_BotKit == BotKits.Assault then
			local s_Weapon = Config.AssaultWeapon
			local s_Pistol = Config.Pistol

			if Config.UseRandomWeapon then
				s_Weapon = AssaultPrimary[MathUtils:GetRandomInt(1, #AssaultPrimary)]
				s_Pistol = AssaultPistol[MathUtils:GetRandomInt(1, #AssaultPistol)]
			end

			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(AssaultGadget2[MathUtils:GetRandomInt(1, #AssaultGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(AssaultGadget1[MathUtils:GetRandomInt(1, #AssaultGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(s_Pistol)
			p_Bot.m_Grenade = m_WeaponList:getWeapon(AssaultGrenade[MathUtils:GetRandomInt(1, #AssaultGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(AssaultKnife[MathUtils:GetRandomInt(1, #AssaultKnife)])
		elseif p_BotKit == BotKits.Engineer then
			local s_Weapon = Config.EngineerWeapon
			local s_Pistol = Config.Pistol

			if Config.UseRandomWeapon then
				s_Weapon = EngineerPrimary[MathUtils:GetRandomInt(1, #EngineerPrimary)]
				s_Pistol = EngineerPistol[MathUtils:GetRandomInt(1, #EngineerPistol)]
			end

			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(EngineerGadget2[MathUtils:GetRandomInt(1, #EngineerGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(EngineerGadget1[MathUtils:GetRandomInt(1, #EngineerGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(s_Pistol)
			p_Bot.m_Grenade = m_WeaponList:getWeapon(EngineerGrenade[MathUtils:GetRandomInt(1, #EngineerGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(EngineerKnife[MathUtils:GetRandomInt(1, #EngineerKnife)])
		elseif p_BotKit == BotKits.Support then
			local s_Weapon = Config.SupportWeapon
			local s_Pistol = Config.Pistol

			if Config.UseRandomWeapon then
				s_Weapon = SupportPrimary[MathUtils:GetRandomInt(1, #SupportPrimary)]
				s_Pistol = SupportPistol[MathUtils:GetRandomInt(1, #SupportPistol)]
			end

			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(SupportGadget2[MathUtils:GetRandomInt(1, #SupportGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(SupportGadget1[MathUtils:GetRandomInt(1, #SupportGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(s_Pistol)
			p_Bot.m_Grenade = m_WeaponList:getWeapon(SupportGrenade[MathUtils:GetRandomInt(1, #SupportGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(SupportKnife[MathUtils:GetRandomInt(1, #SupportKnife)])
		else
			local s_Weapon = Config.ReconWeapon
			local s_Pistol = Config.Pistol

			if Config.UseRandomWeapon then
				s_Weapon = ReconPrimary[MathUtils:GetRandomInt(1, #ReconPrimary)]
				s_Pistol = ReconPistol[MathUtils:GetRandomInt(1, #ReconPistol)]
			end

			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(ReconGadget2[MathUtils:GetRandomInt(1, #ReconGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(ReconGadget1[MathUtils:GetRandomInt(1, #ReconGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(s_Pistol)
			p_Bot.m_Grenade = m_WeaponList:getWeapon(ReconGrenade[MathUtils:GetRandomInt(1, #ReconGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(ReconKnife[MathUtils:GetRandomInt(1, #ReconKnife)])
		end
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

function BotSpawner:_ModifyWeapon(p_Soldier)
	--p_Soldier.weaponsComponent.currentWeapon.secondaryAmmo = 9999
	if p_Soldier.weaponsComponent.weapons[1] ~= nil then
		p_Soldier.weaponsComponent.weapons[1].secondaryAmmo = 9999
	end

	if p_Soldier.weaponsComponent.weapons[2] ~= nil then
		p_Soldier.weaponsComponent.weapons[2].secondaryAmmo = 9999
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

			l_Player.teamId = s_NewTeam
		end
	end
end

if g_BotSpawner == nil then
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner
