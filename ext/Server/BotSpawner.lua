class('BotSpawner')

require('Model/SpawnSet')

local m_NodeCollection = require('__shared/NodeCollection')
local m_BotManager = require('BotManager')
local m_WeaponList = require('__shared/WeaponList')
local m_Utilities = require('__shared/Utilities')
local m_Logger = Logger("BotSpawner", Debug.Server.BOT)

local FIRST_SPAWN_DELAY = 3.0 -- needs to be big enough to register the inputActiveEvents. 1 is too small

function BotSpawner:__init()
	self:RegisterVars()
end

function BotSpawner:RegisterVars()
	self._BotSpawnTimer = 0
	self._PlayerUpdateTimer = 0
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = FIRST_SPAWN_DELAY
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

function BotSpawner:OnLevelLoaded()
	m_Logger:Write("on level loaded on spawner")
	self._FirstSpawnInLevel = true
	self._PlayerUpdateTimer = 0
	self._FirstSpawnDelay = FIRST_SPAWN_DELAY
end

function BotSpawner:OnLevelDestroy()
	self._SpawnSets = {}
	self._UpdateActive = false
	self._FirstSpawnInLevel = true
	self._FirstSpawnDelay = FIRST_SPAWN_DELAY
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
			if m_BotManager:getPlayerCount() > 0 then
				m_BotManager:configGlobals()
				self:UpdateBotAmountAndTeam()
				self._PlayerUpdateTimer = 0
				self._FirstSpawnInLevel = false
			end
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
			if Globals.SpawnMode ~= 'manual' then
				--garbage-collection of unwanted bots
				m_BotManager:destroyDisabledBots()
				m_BotManager:freshnTables()
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
				--local s_Node = m_NodeCollection:Find(s_Position, 5);
				local s_Node = g_GameDirector:FindClosestPath(s_Position, false)
				if s_Node ~= nil then
					l_Bot:setVarsWay(nil, true, s_Node.PathIndex, s_Node.PointIndex, false)
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
	if m_BotManager:getPlayerCount() == 0 then
		m_Logger:Write("first player - spawn bots")
		self:OnLevelLoaded()
	end
	-- detect BOT-Names
	if string.find(p_Name, BOT_TOKEN) == 1 then --check if name starts with bot-token
		table.insert(self._KickPlayers, p_Name)
		if m_BotManager:getBotByName(p_Name) ~= nil then
			table.insert(Globals.IgnoreBotNames, p_Name)
			m_BotManager:destroyBot(p_Name)
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
	local s_Bot = m_BotManager:getBotByName(p_BotName)
	local s_SpawnMode = s_Bot:getSpawnMode()

	if s_SpawnMode == 2 then --spawnInLine
		local s_Transform = LinearTransform()
		s_Transform = s_Bot:getSpawnTransform()
		self:_SpawnBot(s_Bot, s_Transform, false)

	elseif s_SpawnMode == 4 then --fixed Way
		local s_WayIndex = s_Bot:getWayIndex()
		local s_RandIndex = MathUtils:GetRandomInt(1, #m_NodeCollection:Get(nil, s_WayIndex))
		self:_SpawnSingleWayBot(nil, false, s_WayIndex, s_RandIndex, s_Bot)

	elseif s_SpawnMode == 5 then --random Way
		self:_SpawnSingleWayBot(nil, true, 0, 0, s_Bot)
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
			m_BotManager:destroyAll(s_AmountToDestroy)
		end
	end

	-- if update active do nothing
	if self._UpdateActive then
		return
	else
		self._UpdateActive = true
	end

	-- find all needed vars
	local s_PlayerCount = m_BotManager:getPlayerCount()
	local s_BotCount = m_BotManager:getActiveBotCount()
	local s_MaxBotsPerTeam = 0
	if Globals.IsSdm then
		s_MaxBotsPerTeam = Config.MaxBotsPerTeamSdm
	else
		s_MaxBotsPerTeam = Config.MaxBotsPerTeamDefault
	end

	-- kill and destroy bots, if no player left
	if s_PlayerCount == 0 then
		if s_BotCount > 0 then
			m_BotManager:killAll()
			self._UpdateActive = true
		else
			self._UpdateActive = false
		end
		return
	end

	local s_BotTeam = m_BotManager:getBotTeam()
	local s_CountPlayers = {}
	local s_TeamCount = {}
	local s_CountBots = {}
	local s_TargetTeamCount = {}
	for i = 1, Globals.NrOfTeams do
		s_CountPlayers[i] = 0
		s_CountBots[i] = 0
		s_TargetTeamCount[i] = 0
		local s_TempPlayers = PlayerManager:GetPlayersByTeam(i)
		s_TeamCount[i] = #s_TempPlayers
		for _, l_Player in pairs(s_TempPlayers) do
			if m_Utilities:isBot(l_Player) then
				s_CountBots[i] = s_CountBots[i] + 1
			else
				s_CountPlayers[i] = s_CountPlayers[i] + 1
				if Globals.IsSdm then	-- TODO: Only needed because of VEXT-Bug
					l_Player.squadId = 1
				end
			end
		end
	end

	-- KEEP PLAYERCOUNT
	if Globals.SpawnMode == 'keep_playercount' then
		for i = 1, Globals.NrOfTeams do
			s_TargetTeamCount[i] = Config.InitNumberOfBots
		end
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = math.floor(Config.InitNumberOfBots / Globals.NrOfTeams)
			end
		else
			for i = 1, Globals.NrOfTeams do
				if s_BotTeam ~= i then
					s_TargetTeamCount[i] = 0
				end
			end
		end
		--limit team count
		for i = 1, Globals.NrOfTeams do
			if s_TargetTeamCount[i] > s_MaxBotsPerTeam then
				s_TargetTeamCount[i] = s_MaxBotsPerTeam
			end
		end

		for i = 1, Globals.NrOfTeams do
			if s_TeamCount[i] < s_TargetTeamCount[i] then
				self:SpawnWayBots(nil, s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
			elseif s_TeamCount[i] > s_TargetTeamCount[i] and s_CountBots[i] > 0 then
				m_BotManager:killAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
			end
		end

	-- BALANCED teams
	elseif Globals.SpawnMode == 'balanced_teams' then
		local s_maxPlayersInOneTeam = 0
		for i = 1, Globals.NrOfTeams do
			if s_CountPlayers[i] > s_maxPlayersInOneTeam then
				s_maxPlayersInOneTeam = s_CountPlayers[i]
			end
		end
		local targetCount = Config.InitNumberOfBots + ((s_maxPlayersInOneTeam - 1) * Config.NewBotsPerNewPlayer)
		for i = 1, Globals.NrOfTeams do
			s_TargetTeamCount[i] = targetCount
			if s_TargetTeamCount[i] > s_MaxBotsPerTeam then
				s_TargetTeamCount[i] = s_MaxBotsPerTeam
			end
		end

		for i = 1, Globals.NrOfTeams do
			if s_TeamCount[i] < s_TargetTeamCount[i] then
				self:SpawnWayBots(nil, s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
			elseif s_TeamCount[i] > s_TargetTeamCount[i] then
				m_BotManager:killAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
			end
		end
	-- INCREMENT WITH PLAYER
	elseif Globals.SpawnMode == 'increment_with_players' then
		if Config.SpawnInBothTeams then
			for i = 1, Globals.NrOfTeams do
				s_TargetTeamCount[i] = 0
				if s_CountPlayers[i] > 0 then
					for j = 1, Globals.NrOfTeams do
						if i ~= j then
							local s_TempCount = Config.InitNumberOfBots + ((s_CountPlayers[i] - 1) * Config.NewBotsPerNewPlayer)
							if s_TempCount > s_TargetTeamCount[j] then
								s_TargetTeamCount[j] = s_TempCount
							end
						end
					end
				end
			end
			-- limit team count
			for i = 1, Globals.NrOfTeams do
				if s_TargetTeamCount[i] > s_MaxBotsPerTeam then
					s_TargetTeamCount[i] = s_MaxBotsPerTeam
				end
			end
			for i = 1, Globals.NrOfTeams do
				if s_TeamCount[i] < s_TargetTeamCount[i] then
					self:SpawnWayBots(nil, s_TargetTeamCount[i] - s_TeamCount[i], true, 0, 0, i)
				elseif s_TeamCount[i] > s_TargetTeamCount[i] and s_CountBots[i] > 0 then
					m_BotManager:killAll(s_TeamCount[i] - s_TargetTeamCount[i], i)
				end
			end

		else
			-- check for bots in wrong team
			for i = 1, Globals.NrOfTeams do
				if i ~= s_BotTeam and s_CountBots[i] > 0 then
					m_BotManager:killAll(nil, i)
				end
			end

			local s_TargetBotCount = Config.InitNumberOfBots + ((s_PlayerCount - 1) * Config.NewBotsPerNewPlayer)
			if s_TargetBotCount > s_MaxBotsPerTeam then
				s_TargetBotCount = s_MaxBotsPerTeam
			end
			local s_AmountToSpawn = s_TargetBotCount - s_BotCount
			if s_AmountToSpawn > 0 then
				self._BotSpawnTimer = -5.0
				self:SpawnWayBots(nil, s_AmountToSpawn, true, 0, 0, s_BotTeam)
			end
			if s_AmountToSpawn < 0 then
				m_BotManager:killAll(-s_AmountToSpawn)
			end
		end

	-- FIXED NUMBER TO SPAWN
	elseif Globals.SpawnMode == 'fixed_number' then
		if Config.SpawnInBothTeams then
			local s_AmountPerTeam = math.floor(Config.InitNumberOfBots/Globals.NrOfTeams)
			if s_AmountPerTeam > s_MaxBotsPerTeam then
				s_AmountPerTeam = s_MaxBotsPerTeam
			end

			for i = 1, Globals.NrOfTeams do
				if s_TeamCount[i] < s_AmountPerTeam then
					self:SpawnWayBots(nil, s_AmountPerTeam - s_TeamCount[i], true, 0, 0, i)
				elseif s_TeamCount[i] > s_AmountPerTeam and s_CountBots[i] > 0 then
					m_BotManager:killAll(s_TeamCount[i] - s_AmountPerTeam, i)
				end
			end
		else
			-- check for bots in wrong team
			for i = 1, Globals.NrOfTeams do
				if i ~= s_BotTeam and s_CountBots[i] > 0 then
					m_BotManager:killAll(nil, i)
				end
			end

			local s_TargetBotCount = Config.InitNumberOfBots
			if s_TargetBotCount > s_MaxBotsPerTeam then
				s_TargetBotCount = s_MaxBotsPerTeam
			end
			local s_AmountToSpawn = s_TargetBotCount - s_BotCount
			if s_AmountToSpawn > 0 then
				self._BotSpawnTimer = -5.0
				self:SpawnWayBots(nil, s_AmountToSpawn, true, 0, 0, s_BotTeam)
			end
			if s_AmountToSpawn < 0 then
				m_BotManager:killAll(-s_AmountToSpawn)
			end
		end
	elseif Globals.SpawnMode == 'manual' then
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
		local s_Bot = m_BotManager:createBot(p_Name, p_TeamId, p_SquadId)
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
		local s_Name = m_BotManager:findNextBotName()
		if s_Name ~= nil then
			local s_Transform = LinearTransform()
			s_Transform.trans = p_Player.soldier.worldTransform.trans + (p_Player.soldier.worldTransform.forward * i * p_Spacing)
			local s_Bot = m_BotManager:createBot(s_Name, m_BotManager:getBotTeam(), SquadId.SquadNone)
			s_Bot:setVarsStatic(p_Player)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

function BotSpawner:SpawnBotTower(p_Player, p_Height)
	for i = 1, p_Height do
		local s_Name = m_BotManager:findNextBotName()
		if s_Name ~= nil then
			local s_Yaw = p_Player.input.authoritativeAimingYaw
			local s_Transform = LinearTransform()
			s_Transform.trans.x = p_Player.soldier.worldTransform.trans.x + (math.cos(s_Yaw + (math.pi / 2)))
			s_Transform.trans.y = p_Player.soldier.worldTransform.trans.y + ((i - 1) * 1.8)
			s_Transform.trans.z = p_Player.soldier.worldTransform.trans.z + (math.sin(s_Yaw + (math.pi / 2)))
			local s_Bot = m_BotManager:createBot(s_Name, m_BotManager:getBotTeam(), SquadId.SquadNone)
			s_Bot:setVarsStatic(p_Player)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

function BotSpawner:SpawnBotGrid(p_Player, p_Rows, p_Columns, p_Spacing)
	for i = 1, p_Rows do
		for j = 1, p_Columns do
			local s_Name = m_BotManager:findNextBotName()
			if s_Name ~= nil then
				local s_Yaw = p_Player.input.authoritativeAimingYaw
				local s_Transform = LinearTransform()
				s_Transform.trans.x = p_Player.soldier.worldTransform.trans.x + (i * math.cos(s_Yaw + (math.pi / 2)) * p_Spacing) + ((j - 1) * math.cos(s_Yaw) * p_Spacing)
				s_Transform.trans.y = p_Player.soldier.worldTransform.trans.y
				s_Transform.trans.z = p_Player.soldier.worldTransform.trans.z + (i * math.sin(s_Yaw + (math.pi / 2)) * p_Spacing) + ((j - 1) * math.sin(s_Yaw) * p_Spacing)
				local s_Bot = m_BotManager:createBot(s_Name, m_BotManager:getBotTeam(), SquadId.SquadNone)
				s_Bot:setVarsStatic(p_Player)
				self:_SpawnBot(s_Bot, s_Transform, true)
			end
		end
	end
end

function BotSpawner:SpawnLineBots(p_Player, p_Amount, p_Spacing)
	 for i = 1, p_Amount do
		local s_Name = m_BotManager:findNextBotName()
		if s_Name ~= nil then
			local s_Transform = LinearTransform()
			s_Transform.trans = p_Player.soldier.worldTransform.trans + (p_Player.soldier.worldTransform.forward * i * p_Spacing)
			local s_Bot = m_BotManager:createBot(s_Name, m_BotManager:getBotTeam(), SquadId.SquadNone)
			s_Bot:setVarsSimpleMovement(p_Player, 2, s_Transform)
			self:_SpawnBot(s_Bot, s_Transform, true)
		end
	end
end

function BotSpawner:SpawnWayBots(p_Player, p_Amount, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, p_TeamId)
	if #m_NodeCollection:GetPaths() <= 0 then
		return
	end

	-- check for amount available
	local s_PlayerLimit = Globals.MaxPlayers
	if Config.KeepOneSlotForPlayers then
		s_PlayerLimit = s_PlayerLimit - 1
	end

	local s_InactiveBots = m_BotManager:getBotCount() - m_BotManager:getActiveBotCount()
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
	if not s_WriteNewKit and (p_Bot.m_Color == "" or p_Bot.m_Kit == "" or p_Bot.m_ActiveWeapon == nil) then
		s_WriteNewKit = true
	end
	local s_BotColor = Config.BotColor
	local s_BotKit = Config.BotKit

	if s_WriteNewKit then
		if s_BotColor == "RANDOM_COLOR" then
			s_BotColor = BotColors[MathUtils:GetRandomInt(2, #BotColors)]
		end
		if s_BotKit == "RANDOM_KIT" then
			s_BotKit = self:_GetSpawnBotKit()
		end
		p_Bot.m_Color = s_BotColor
		p_Bot.m_Kit = s_BotKit
	else
		s_BotColor = p_Bot.m_Color
		s_BotKit = p_Bot.m_Kit
	end

	p_Bot:resetSpawnVars()
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
		s_Name = m_BotManager:findNextBotName()
	end
	local s_TeamId = p_ForcedTeam
	local s_SquadId = SquadId.SquadNone
	if s_TeamId == nil then
		s_TeamId = m_BotManager:getBotTeam()
	end
	if s_IsRespawn then
		s_TeamId = p_ExistingBot.m_Player.teamId
		s_SquadId = p_ExistingBot.m_Player.squadId
	else
		s_SquadId = self:_GetSquadToJoin(s_TeamId)
	end
	local s_InverseDirection = false
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
			s_SpawnPoint = self:_GetSpawnPoint(s_TeamId, s_SquadId)
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
		if m_NodeCollection:Get(1, p_ActiveWayIndex).OptValue == 0xFF then
			s_InverseDirection = (MathUtils:GetRandomInt(0, 1) == 1)
		end

		local s_Transform = LinearTransform()
		if p_IndexOnPath == nil or p_IndexOnPath == 0 then
			p_IndexOnPath = 1
		end
		s_Transform.trans = s_SpawnPoint.Position

		if s_IsRespawn then
			p_ExistingBot:setVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, s_InverseDirection)
			self:_SpawnBot(p_ExistingBot, s_Transform, false)
		else
			local s_Bot = m_BotManager:createBot(s_Name, s_TeamId, s_SquadId)

			if s_Bot ~= nil then
				-- check for first one in squad
				if (TeamSquadManager:GetSquadPlayerCount(s_TeamId, s_SquadId) == 1) then
					s_Bot.m_Player:SetSquadLeader(true, false)  -- not private
				end

				s_Bot:setVarsWay(p_Player, p_UseRandomWay, p_ActiveWayIndex, p_IndexOnPath, s_InverseDirection)
				self:_SpawnBot(s_Bot, s_Transform, true)
			end
		end
	end
end

function BotSpawner:_SpawnBot(p_Bot, p_Trans, p_SetKit)
	local s_WriteNewKit = (p_SetKit or Config.BotNewLoadoutOnSpawn)
	if not s_WriteNewKit and (p_Bot.m_Color == "" or p_Bot.m_Kit == "" or p_Bot.m_ActiveWeapon == nil) then
		s_WriteNewKit = true
	end
	local s_BotColor = Config.BotColor
	local s_BotKit = Config.BotKit

	if s_WriteNewKit then
		if s_BotColor == "RANDOM_COLOR" then
			s_BotColor = BotColors[MathUtils:GetRandomInt(2, #BotColors)]
		end
		if s_BotKit == "RANDOM_KIT" then
			s_BotKit = self:_GetSpawnBotKit()
		end
		p_Bot.m_Color = s_BotColor
		p_Bot.m_Kit = s_BotKit
	else
		s_BotColor = p_Bot.m_Color
		s_BotKit = p_Bot.m_Kit
	end

	self:_SetBotWeapons(p_Bot, s_BotKit, s_WriteNewKit)

	p_Bot:resetSpawnVars()

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
		m_BotManager:spawnBot(p_Bot, s_Transform, CharacterPoseType.CharacterPoseType_Stand, s_SoldierBlueprint, s_SoldierKit, {})
	else
		m_BotManager:spawnBot(p_Bot, s_Transform, CharacterPoseType.CharacterPoseType_Stand, s_SoldierBlueprint, s_SoldierKit, { s_Appearance })
	end
	p_Bot.m_Player.soldier:ApplyCustomization(s_SoldierCustomization)
	self:_ModifyWeapon(p_Bot.m_Player.soldier)

	-- for Civilianizer-mod:
	Events:Dispatch('Bot:SoldierEntity', p_Bot.m_Player.soldier)
end

function BotSpawner:_GetSpawnPoint(p_TeamId, p_SquadId)
	local s_ActiveWayIndex = 0
	local s_IndexOnPath = 0

	local s_TargetNode = nil
	local s_ValidPointFound = false
	local s_TargetDistance = Config.DistanceToSpawnBots
	local s_RetryCounter = Config.MaxTrysToSpawnAtDistance
	local s_MaximumTrys = 100
	local s_TrysDone = 0

	-- CONQUEST
	-- spawn at base, squad-mate, captured flag
	if Globals.IsConquest then
		s_ActiveWayIndex, s_IndexOnPath = g_GameDirector:GetSpawnPath(p_TeamId, p_SquadId, false)

		if s_ActiveWayIndex == 0 then
			-- something went wrong. use random path
			m_Logger:Write("no base or capturepoint found to spawn")
			return
		end

		s_TargetNode = m_NodeCollection:Get(s_IndexOnPath, s_ActiveWayIndex)


	-- RUSH
	-- spawn at base (of zone) or squad-mate
	elseif Globals.IsRush then
		s_ActiveWayIndex, s_IndexOnPath = g_GameDirector:GetSpawnPath(p_TeamId, p_SquadId, true)

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
				if s_TempPlayer.alive then
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
	return s_TargetNode
end

function BotSpawner:_GetSquadToJoin(p_TeamId)  -- TODO: create a more advanced algorithm?
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
	if p_Kit == "Assault" or p_Kit == "Support" then
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

	if p_TeamId % 2 == 1 then -- US
		if p_Kit == "Assault" then --assault
			s_Appearance = self:_FindAppearance('Us', 'Assault', p_Color)
			s_SoldierKit = self:_FindKit('US', 'Assault')
		elseif p_Kit == "Engineer" then --engineer
			s_Appearance = self:_FindAppearance('Us', 'Engi', p_Color)
			s_SoldierKit = self:_FindKit('US', 'Engineer')
		elseif p_Kit == "Support" then --support
			s_Appearance = self:_FindAppearance('Us', 'Support', p_Color)
			s_SoldierKit = self:_FindKit('US', 'Support')
		else --recon
			s_Appearance = self:_FindAppearance('Us', 'Recon', p_Color)
			s_SoldierKit = self:_FindKit('US', 'Recon')
		end
	else -- RU
		if p_Kit == "Assault" then --assault
			s_Appearance = self:_FindAppearance('RU', 'Assault', p_Color)
			s_SoldierKit = self:_FindKit('RU', 'Assault')
		elseif p_Kit == "Engineer" then --engineer
			s_Appearance = self:_FindAppearance('RU', 'Engi', p_Color)
			s_SoldierKit = self:_FindKit('RU', 'Engineer')
		elseif p_Kit == "Support" then --support
			s_Appearance = self:_FindAppearance('RU', 'Support', p_Color)
			s_SoldierKit = self:_FindKit('RU', 'Support')
		else --recon
			s_Appearance = self:_FindAppearance('RU', 'Recon', p_Color)
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
	local s_BotKit = BotKits[MathUtils:GetRandomInt(2, #BotKits)]
	local s_ChangeKit = false
	--find out, if possible
	local s_KitCount = m_BotManager:getKitCount(s_BotKit)
	if s_BotKit == "Assault" then
		if Config.MaxAssaultBots >= 0 and s_KitCount >= Config.MaxAssaultBots then
			s_ChangeKit = true
		end
	elseif s_BotKit == "Engineer" then
		if Config.MaxEngineerBots >= 0 and s_KitCount >= Config.MaxEngineerBots then
			s_ChangeKit = true
		end
	elseif s_BotKit == "Support" then
		if Config.MaxSupportBots >= 0 and s_KitCount >= Config.MaxSupportBots then
			s_ChangeKit = true
		end
	else -- s_BotKit == "Recon"
		if Config.MaxReconBots >= 0 and s_KitCount >= Config.MaxReconBots then
			s_ChangeKit = true
		end
	end

	if s_ChangeKit then
		local s_AvailableKitList = {}
		if (Config.MaxAssaultBots == -1) or (m_BotManager:getKitCount("Assault") < Config.MaxAssaultBots) then
			table.insert(s_AvailableKitList, "Assault")
		end
		if (Config.MaxEngineerBots == -1) or (m_BotManager:getKitCount("Engineer") < Config.MaxEngineerBots) then
			table.insert(s_AvailableKitList, "Engineer")
		end
		if (Config.MaxSupportBots == -1) or (m_BotManager:getKitCount("Support") < Config.MaxSupportBots) then
			table.insert(s_AvailableKitList, "Support")
		end
		if(Config.MaxReconBots == -1) or (m_BotManager:getKitCount("Recon") < Config.MaxReconBots) then
			table.insert(s_AvailableKitList, "Recon")
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

function BotSpawner:_FindAppearance(p_TeamName, p_KitName, p_Color)
	local s_GameModeAppearances = {
		'MP/', -- Standard
		'MP_XP4/', --Gun Master on XP2 Maps
	}
	--'Persistence/Unlocks/Soldiers/Visual/MP[or:MP_XP4]/Us/MP_US_Assault_Appearance_'..p_Color
	for _, l_GameMode in pairs(s_GameModeAppearances) do
		local s_AppearanceString = l_GameMode .. p_TeamName .. '/MP_' .. string.upper(p_TeamName) .. '_' .. p_KitName .. '_Appearance_' .. p_Color
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
		if p_BotKit == "Assault" then
			local s_Weapon = Config.AssaultWeapon
			if Config.UseRandomWeapon then
				s_Weapon = AssaultPrimary[MathUtils:GetRandomInt(1, #AssaultPrimary)]
			end
			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(AssaultGadget2[MathUtils:GetRandomInt(1, #AssaultGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(AssaultGadget1[MathUtils:GetRandomInt(1, #AssaultGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(AssaultPistol[MathUtils:GetRandomInt(1, #AssaultPistol)])
			p_Bot.m_Grenade = m_WeaponList:getWeapon(AssaultGrenade[MathUtils:GetRandomInt(1, #AssaultGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(AssaultKnife[MathUtils:GetRandomInt(1, #AssaultKnife)])
		elseif p_BotKit == "Engineer" then
			local s_Weapon = Config.EngineerWeapon
			if Config.UseRandomWeapon then
				s_Weapon = EngineerPrimary[MathUtils:GetRandomInt(1, #EngineerPrimary)]
			end
			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(EngineerGadget2[MathUtils:GetRandomInt(1, #EngineerGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(EngineerGadget1[MathUtils:GetRandomInt(1, #EngineerGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(EngineerPistol[MathUtils:GetRandomInt(1, #EngineerPistol)])
			p_Bot.m_Grenade = m_WeaponList:getWeapon(EngineerGrenade[MathUtils:GetRandomInt(1, #EngineerGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(EngineerKnife[MathUtils:GetRandomInt(1, #EngineerKnife)])
		elseif p_BotKit == "Support" then
			local s_Weapon = Config.SupportWeapon
			if Config.UseRandomWeapon then
				s_Weapon = SupportPrimary[MathUtils:GetRandomInt(1, #SupportPrimary)]
			end
			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(SupportGadget2[MathUtils:GetRandomInt(1, #SupportGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(SupportGadget1[MathUtils:GetRandomInt(1, #SupportGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(SupportPistol[MathUtils:GetRandomInt(1, #SupportPistol)])
			p_Bot.m_Grenade = m_WeaponList:getWeapon(SupportGrenade[MathUtils:GetRandomInt(1, #SupportGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(SupportKnife[MathUtils:GetRandomInt(1, #SupportKnife)])
		else
			local s_Weapon = Config.ReconWeapon
			if Config.UseRandomWeapon then
				s_Weapon = ReconPrimary[MathUtils:GetRandomInt(1, #ReconPrimary)]
			end
			p_Bot.m_Primary = m_WeaponList:getWeapon(s_Weapon)
			p_Bot.m_SecondaryGadget = m_WeaponList:getWeapon(ReconGadget2[MathUtils:GetRandomInt(1, #ReconGadget2)])
			p_Bot.m_PrimaryGadget = m_WeaponList:getWeapon(ReconGadget1[MathUtils:GetRandomInt(1, #ReconGadget1)])
			p_Bot.m_Pistol = m_WeaponList:getWeapon(ReconPistol[MathUtils:GetRandomInt(1, #ReconPistol)])
			p_Bot.m_Grenade = m_WeaponList:getWeapon(ReconGrenade[MathUtils:GetRandomInt(1, #ReconGrenade)])
			p_Bot.m_Knife = m_WeaponList:getWeapon(ReconKnife[MathUtils:GetRandomInt(1, #ReconKnife)])
		end
	end

	if Config.BotWeapon == "Primary" or Config.BotWeapon == "Auto" then
		p_Bot.m_ActiveWeapon = p_Bot.m_Primary
	elseif Config.BotWeapon == "Pistol" then
		p_Bot.m_ActiveWeapon = p_Bot.m_Pistol
	elseif Config.BotWeapon == "Gadget2" then
		p_Bot.m_ActiveWeapon = p_Bot.m_SecondaryGadget
	elseif Config.BotWeapon == "Gadget1" then
		p_Bot.m_ActiveWeapon = p_Bot.m_PrimaryGadget
	elseif Config.BotWeapon == "Grenade" then
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

if g_BotSpawner == nil then
	g_BotSpawner = BotSpawner()
end

return g_BotSpawner
