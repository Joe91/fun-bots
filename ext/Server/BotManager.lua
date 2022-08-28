---@class BotManager
BotManager = class('BotManager')

require('Bot')

---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type Logger
local m_Logger = Logger("BotManager", Debug.Server.BOT)

function BotManager:__init()
	---@type Bot[]
	self._Bots = {}
	---@type table<string, Bot>
	---`[Player.name] -> Bot`
	self._BotsByName = {}
	---@type table<integer, Bot[]>
	self._BotsByTeam = { {}, {}, {}, {}, {} } -- neutral, team1, team2, team3, team4
	---@type table<integer, EntryInput>
	---`[Player.id] -> EntryInput`
	self._BotInputs = {}
	---@type table<string, string>
	---`[name of damaged player] -> name of shooting player`
	self._ShooterBots = {}
	---@type string[]
	---`playerName:string[]`
	self._ActivePlayers = {}
	self._BotAttackBotTimer = 0.0
	self._DestroyBotsTimer = 0.0
	---@type string[]
	---`BotName[]`
	self._BotsToDestroy = {}

	---@type string[]
	---`BotName[]`
	self._BotBotAttackList = {}
	self._RaycastsPerActivePlayer = 0
	---@type table<string, boolean>
	---`[BotName] -> boolean`
	self._BotCheckState = {}

	---@type table<string, boolean>
	---`[botPlayer.id .. "-" .. enemyBotPlayer.id] -> boolean`
	self._ConnectionCheckState = {}

	---@type string[]
	---`BotName[]`
	self._LastBotCheckIndex = 1
	self._LastPlayerCheckIndex = 1
	self._InitDone = false
end

-- =============================================
-- Events
-- =============================================

---VEXT Shared Level:Destroy Event
function BotManager:OnLevelDestroy()
	m_Logger:Write("destroyLevel")

	self:ResetAllBots()
	self._ActivePlayers = {}
	self._InitDone = false
end

---VEXT Shared UpdateManager:Update Event
---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function BotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	for _, l_Bot in pairs(self._Bots) do
		l_Bot:OnUpdatePassPostFrame(p_DeltaTime)
	end

	if Config.BotsAttackBots and self._InitDone then
		if self._BotAttackBotTimer >= Registry.GAME_RAYCASTING.BOT_BOT_CHECK_INTERVAL then
			self._BotAttackBotTimer = 0.0
			self:_CheckForBotBotAttack()
		end

		self._BotAttackBotTimer = self._BotAttackBotTimer + p_DeltaTime
	end

	if #self._BotsToDestroy > 0 then
		if self._DestroyBotsTimer >= 0.05 then
			self._DestroyBotsTimer = 0.0
			self:DestroyBot(table.remove(self._BotsToDestroy))
		end

		self._DestroyBotsTimer = self._DestroyBotsTimer + p_DeltaTime
	end
end

---VEXT Server Player:Left Event
---@param p_Player Player
function BotManager:OnPlayerLeft(p_Player)
	--remove all references of player
	if p_Player ~= nil then
		for _, l_Bot in pairs(self._Bots) do
			l_Bot:ClearPlayer(p_Player)
		end
	end

	for l_Index, l_PlayerName in pairs(self._ActivePlayers) do
		if l_PlayerName == p_Player.name then
			table.remove(self._ActivePlayers, l_Index)
			break
		end
	end

	-- check if player used a Bot-Name
	if Registry.COMMON.ALLOW_PLAYER_BOT_NAMES then
		for l_Index, l_BotNameToIgnore in pairs(Globals.IgnoreBotNames) do
			if l_BotNameToIgnore == p_Player.name then
				table.remove(Globals.IgnoreBotNames, l_Index)
				m_Logger:Write("Bot-Name " .. l_BotNameToIgnore .. " usable again")
			end
		end
	end
end

---@param p_BotName string
function BotManager:OnBotAbortWait(p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)

	if s_Bot ~= nil then
		s_Bot:ResetVehicleTimer()
	end
end

---@param p_BotName string
function BotManager:OnBotExitVehicle(p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)

	if s_Bot ~= nil then
		s_Bot:ExitVehicle()
	end
end

-- TODO: remove? this is unused / commented out
---@param p_GunSway GunSway
---@param p_Weapon Entity|nil
---@param p_WeaponFiring WeaponFiring|nil
---@param p_DeltaTime number
function BotManager:OnGunSway(p_GunSway, p_Weapon, p_WeaponFiring, p_DeltaTime)
	if p_Weapon == nil then
		return
	end

	---@type SoldierEntity|nil
	local s_Soldier = nil

	for _, l_Entity in pairs(p_Weapon.bus.parent.entities) do
		if l_Entity:Is('ServerSoldierEntity') then
			s_Soldier = SoldierEntity(l_Entity)
			break
		end
	end

	if s_Soldier == nil or s_Soldier.player == nil then
		return
	end

	local s_Bot = self:GetBotByName(s_Soldier.player.name)

	if s_Bot ~= nil then
		local s_GunSwayData = GunSwayData(p_GunSway.data)

		if s_Soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
			p_GunSway.dispersionAngle = s_GunSwayData.stand.zoom.baseValue.minAngle
		elseif s_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			p_GunSway.dispersionAngle = s_GunSwayData.crouch.zoom.baseValue.minAngle
		elseif s_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			p_GunSway.dispersionAngle = s_GunSwayData.prone.zoom.baseValue.minAngle
		else
			return
		end
	end
end

---VEXT Server Vehicle:Damage Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Damage number
---@param p_DamageGiverInfo DamageGiverInfo|nil
function BotManager:OnVehicleDamage(p_VehicleEntity, p_Damage, p_DamageGiverInfo)
	if p_Damage > 0.0 and p_VehicleEntity ~= nil then
		local s_ControllableEntity = ControllableEntity(p_VehicleEntity)
		local s_MaxEntries = s_ControllableEntity.entryCount

		for i = 0, s_MaxEntries - 1 do
			local s_Player = s_ControllableEntity:GetPlayerInEntry(i)

			if s_Player ~= nil then
				if m_Utilities:isBot(s_Player) then
					local s_Bot = self:GetBotByName(s_Player.name)

					if s_Bot ~= nil then
						-- shoot back
						if p_DamageGiverInfo and p_DamageGiverInfo.giver ~= nil then
							--detect if we need to shoot back
							if Config.ShootBackIfHit then
								s_Bot:ShootAt(p_DamageGiverInfo.giver, true)
							end
						end
					end
				end
			end
		end
	end
end

-- =============================================
-- Hooks
-- =============================================

---VEXT Server Soldier:Damage Hook
---@param p_HookCtx HookContext
---@param p_Soldier SoldierEntity
---@param p_Info DamageInfo
---@param p_GiverInfo DamageGiverInfo
function BotManager:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
	-- soldier -> soldier damage only
	if p_Soldier.player == nil then
		return
	end

	local s_SoldierIsBot = m_Utilities:isBot(p_Soldier.player)

	if s_SoldierIsBot and p_GiverInfo.giver ~= nil then
		--detect if we need to shoot back
		if Config.ShootBackIfHit and p_Info.damage > 0 then
			self:OnShootAt(p_GiverInfo.giver, p_Soldier.player.name, true)
		end

		-- prevent bots from killing themselves. Bad bot, no suicide.
		if not Config.BotCanKillHimself and p_Soldier.player == p_GiverInfo.giver then
			p_Info.damage = 0
		end
	end

	--find out, if a player was hit by the server:
	if not s_SoldierIsBot then
		if p_GiverInfo.giver == nil then
			local s_Bot = self:GetBotByName(self._ShooterBots[p_Soldier.player.name])

			if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil and p_Info.damage > 0 then
				p_Info.damage = self:_GetDamageValue(p_Info.damage, s_Bot, p_Soldier, true)
				p_Info.boneIndex = 0
				p_Info.isBulletDamage = true
				p_Info.position = Vec3(p_Soldier.worldTransform.trans.x, p_Soldier.worldTransform.trans.y + 1,
					p_Soldier.worldTransform.trans.z)
				p_Info.direction = p_Soldier.worldTransform.trans - s_Bot.m_Player.soldier.worldTransform.trans
				p_Info.origin = s_Bot.m_Player.soldier.worldTransform.trans

				if (p_Soldier.health - p_Info.damage) <= 0 then
					if Globals.IsTdm then
						local s_EnemyTeam = TeamId.Team1

						if p_Soldier.player.teamId == TeamId.Team1 then
							s_EnemyTeam = TeamId.Team2
						end

						TicketManager:SetTicketCount(s_EnemyTeam, (TicketManager:GetTicketCount(s_EnemyTeam) + 1))
					end
				end
			end
		else
			--valid bot-damage?
			local s_Bot = self:GetBotByName(p_GiverInfo.giver.name)

			if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil then
				-- giver was a bot
				p_Info.damage = self:_GetDamageValue(p_Info.damage, s_Bot, p_Soldier, false)
			end
		end
	end

	p_HookCtx:Pass(p_Soldier, p_Info, p_GiverInfo)
end

-- =============================================
-- Custom (Net-)Events
-- =============================================

---@param p_PlayerName string
---@param p_ShooterName string
---@param p_MeleeAttack boolean
function BotManager:OnServerDamagePlayer(p_PlayerName, p_ShooterName, p_MeleeAttack)
	local s_Player = PlayerManager:GetPlayerByName(p_PlayerName)

	if s_Player ~= nil then
		self:OnDamagePlayer(s_Player, p_ShooterName, p_MeleeAttack, false)
	end
end

---@param p_Player Player
---@param p_ShooterName string
---@param p_MeleeAttack boolean
---@param p_IsHeadShot boolean
function BotManager:OnDamagePlayer(p_Player, p_ShooterName, p_MeleeAttack, p_IsHeadShot)
	local s_Bot = self:GetBotByName(p_ShooterName)

	if p_Player.soldier == nil or s_Bot == nil then
		return
	end

	if p_Player.teamId == s_Bot.m_Player.teamId then
		return
	end

	local s_Damage = 1 --only trigger soldier-damage with this

	if p_IsHeadShot then
		s_Damage = 2 -- singal Headshot
	elseif p_MeleeAttack then
		s_Damage = 3 --signal melee damage with this value
	end

	--save potential killer bot
	self._ShooterBots[p_Player.name] = p_ShooterName

	if p_Player.soldier ~= nil then
		p_Player.soldier.health = p_Player.soldier.health - s_Damage
	end
end

---@param p_Player Player
---@param p_BotName string
---@param p_IgnoreYaw boolean
function BotManager:OnShootAt(p_Player, p_BotName, p_IgnoreYaw)
	local s_Bot = self:GetBotByName(p_BotName)

	if s_Bot == nil or s_Bot.m_Player == nil or s_Bot.m_Player.soldier == nil or p_Player == nil then
		return
	end

	s_Bot:ShootAt(p_Player, p_IgnoreYaw)
end

---@param p_Player Player
---@param p_BotName string
function BotManager:OnRevivePlayer(p_Player, p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)

	if s_Bot == nil or s_Bot.m_Player == nil or s_Bot.m_Player.soldier == nil or p_Player == nil then
		return
	end

	s_Bot:Revive(p_Player)
end

---@param p_Player Player
---@param p_BotName1 string
---@param p_BotName2 string
function BotManager:OnBotShootAtBot(p_Player, p_BotName1, p_BotName2)
	local s_Bot1 = self:GetBotByName(p_BotName1)
	local s_Bot2 = self:GetBotByName(p_BotName2)

	if s_Bot1 == nil or s_Bot1.m_Player == nil or s_Bot2 == nil or s_Bot2.m_Player == nil then
		return
	end

	if s_Bot1:ShootAt(s_Bot2.m_Player, false) then
		self._BotCheckState[s_Bot1.m_Player.name] = true
	end

	if s_Bot2:ShootAt(s_Bot1.m_Player, false) then
		self._BotCheckState[s_Bot2.m_Player.name] = true
	end
end

function BotManager:OnClientRaycastResults(p_Player, p_RaycastResults)
	if p_RaycastResults == nil then
		return
	end

	for _, l_RaycastResult in pairs(p_RaycastResults) do
		if l_RaycastResult.Mode == "ShootAtBot" then
			self:OnBotShootAtBot(p_Player, l_RaycastResult.Bot1, l_RaycastResult.Bot2)
		elseif l_RaycastResult.Mode == "ShootAtPlayer" then
			self:OnShootAt(p_Player, l_RaycastResult.Bot1, l_RaycastResult.IgnoreYaw)
		elseif l_RaycastResult.Mode == "RevivePlayer" then
			self:OnRevivePlayer(p_Player, l_RaycastResult.Bot1)
		end
	end
end

---@param p_Player Player
---@param p_BotName string
function BotManager:OnRequestEnterVehicle(p_Player, p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)

	if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil then
		s_Bot:EnterVehicleOfPlayer(p_Player)
	end
end

---@param p_Player Player
---@param p_SeatNumber integer
function BotManager:OnRequestChangeSeatVehicle(p_Player, p_SeatNumber)
	local s_TargetEntryId = p_SeatNumber - 1
	local s_VehicleEntity = p_Player.controlledControllable

	if s_VehicleEntity ~= nil and s_VehicleEntity:Is("ServerSoldierEntity") and p_Player.attachedControllable ~= nil then
		s_VehicleEntity = p_Player.attachedControllable
	end

	if s_VehicleEntity == nil then
		return
	end

	local s_PlayerInTargetSet = s_VehicleEntity:GetPlayerInEntry(s_TargetEntryId)

	if s_PlayerInTargetSet ~= nil then
		local s_Bot = self:GetBotByName(s_PlayerInTargetSet.name)

		if s_Bot ~= nil then
			s_Bot:_AbortAttack()
			s_Bot.m_Player:ExitVehicle(false, false)
			p_Player:EnterVehicle(s_VehicleEntity, s_TargetEntryId)

			-- find next free seat
			for i = 0, s_VehicleEntity.entryCount - 1 do
				if s_VehicleEntity:GetPlayerInEntry(i) == nil then
					s_Bot.m_Player:EnterVehicle(s_VehicleEntity, i)
					s_Bot:_UpdateVehicleMovableId()
					break
				end
			end
		end
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================

---@param p_Player Player
function BotManager:RegisterActivePlayer(p_Player)
	local s_AlreadyListed = false

	for _, l_PlayerName in pairs(self._ActivePlayers) do
		if l_PlayerName == p_Player.name then
			s_AlreadyListed = true
		end
	end

	if not s_AlreadyListed then
		table.insert(self._ActivePlayers, p_Player.name)
	end
end

---@return integer|TeamId
function BotManager:GetPlayerTeam()
	---@type integer|TeamId
	local s_PlayerTeam
	---@type table<integer|TeamId, integer>
	local s_CountPlayers = {}

	for i = 1, Globals.NrOfTeams do
		s_CountPlayers[i] = 0
		local s_Players = PlayerManager:GetPlayersByTeam(i)

		for j = 1, #s_Players do
			if not m_Utilities:isBot(s_Players[j]) then
				s_CountPlayers[i] = s_CountPlayers[i] + 1
			end
		end
	end

	local s_HighestPlayerCount = 0

	---@type integer|TeamId
	for i = 1, Globals.NrOfTeams do
		if s_CountPlayers[i] > s_HighestPlayerCount then
			s_PlayerTeam = i
			s_HighestPlayerCount = s_CountPlayers[i]
		end
	end

	return s_PlayerTeam
end

---@return integer|TeamId
function BotManager:GetBotTeam()
	if Config.BotTeam ~= TeamId.TeamNeutral then
		return Config.BotTeam
	end

	---@type integer|TeamId
	local s_BotTeam
	---@type table<integer|TeamId, integer>
	local s_CountPlayers = {}

	for i = 1, Globals.NrOfTeams do
		s_CountPlayers[i] = 0
		local s_Players = PlayerManager:GetPlayersByTeam(i)

		for j = 1, #s_Players do
			if not m_Utilities:isBot(s_Players[j]) then
				s_CountPlayers[i] = s_CountPlayers[i] + 1
			end
		end
	end

	local s_LowestPlayerCount = 128

	---@type integer|TeamId
	for i = 1, Globals.NrOfTeams do
		if s_CountPlayers[i] < s_LowestPlayerCount then
			s_BotTeam = i
			s_LowestPlayerCount = s_CountPlayers[i]
		end
	end

	return s_BotTeam
end

function BotManager:ConfigGlobals()
	Globals.RespawnWayBots = Config.RespawnWayBots
	Globals.AttackWayBots = Config.AttackWayBots
	Globals.SpawnMode = Config.SpawnMode
	Globals.YawPerFrame = self:CalcYawPerFrame()
	local s_MaxPlayers = RCON:SendCommand('vars.maxPlayers')
	s_MaxPlayers = tonumber(s_MaxPlayers[2])

	if s_MaxPlayers ~= nil and s_MaxPlayers > 0 then
		Globals.MaxPlayers = s_MaxPlayers

		m_Logger:Write("there are " .. s_MaxPlayers .. " slots on this server")
	else
		Globals.MaxPlayers = 127 -- only fallback. Should not happens
		m_Logger:Error("No Playercount found")
	end

	-- calculate Raycast per Player
	local s_CycleTime = 1.0 / SharedUtils:GetTickrate()
	local s_FactorTicksUpdate = Registry.GAME_RAYCASTING.BOT_BOT_CHECK_INTERVAL / s_CycleTime
	local s_RaycastsMax = s_FactorTicksUpdate * (Registry.GAME_RAYCASTING.MAX_RAYCASTS_PER_PLAYER_BOT_BOT)
	self._RaycastsPerActivePlayer = math.floor(s_RaycastsMax - 0.1) -- always round down one

	self._InitDone = true
end

---@return number
function BotManager:CalcYawPerFrame()
	local s_DeltaTime = 1.0 / SharedUtils:GetTickrate()
	local s_DegreePerDeltaTime = Config.MaximunYawPerSec * s_DeltaTime
	return (s_DegreePerDeltaTime / 360.0) * 2 * math.pi
end

---@return string|nil
function BotManager:FindNextBotName()
	for _, l_Name in pairs(BotNames) do
		local s_Name = Registry.COMMON.BOT_TOKEN .. l_Name
		local s_SkipName = false

		for _, l_IgnoreName in pairs(Globals.IgnoreBotNames) do
			if s_Name == l_IgnoreName then
				s_SkipName = true
				break
			end
		end

		if not s_SkipName then
			local s_Bot = self:GetBotByName(s_Name)

			if s_Bot == nil and PlayerManager:GetPlayerByName(s_Name) == nil then
				return s_Name
			elseif s_Bot ~= nil and s_Bot.m_Player.soldier == nil and s_Bot:GetSpawnMode() ~= BotSpawnModes.RespawnRandomPath then
				return s_Name
			end
		end
	end

	return nil
end

---@param p_TeamId? TeamId|integer
---@return Bot[]
function BotManager:GetBots(p_TeamId)
	if p_TeamId ~= nil then
		return self._BotsByTeam[p_TeamId + 1]
	else
		return self._Bots
	end
end

---@return integer
function BotManager:GetBotCount()
	return #self._Bots
end

---@param p_TeamId? TeamId|integer
---@return integer
function BotManager:GetActiveBotCount(p_TeamId)
	local s_Count = 0

	for _, l_Bot in pairs(self._Bots) do
		if not l_Bot:IsInactive() then
			if p_TeamId == nil or l_Bot.m_Player.teamId == p_TeamId then
				s_Count = s_Count + 1
			end
		end
	end

	return s_Count
end

---@return Player[]
function BotManager:GetPlayers()
	local s_AllPlayers = PlayerManager:GetPlayers()
	local s_Players = {}

	for i = 1, #s_AllPlayers do
		if not m_Utilities:isBot(s_AllPlayers[i]) then
			table.insert(s_Players, s_AllPlayers[i])
		end
	end

	return s_Players
end

---@return integer
function BotManager:GetPlayerCount()
	return PlayerManager:GetPlayerCount() - #self._Bots
end

---@param p_Kit integer|BotKits
---@return integer
function BotManager:GetKitCount(p_Kit)
	local s_Count = 0

	for _, l_Bot in pairs(self._Bots) do
		if l_Bot.m_Kit == p_Kit then
			s_Count = s_Count + 1
		end
	end

	return s_Count
end

function BotManager:ResetAllBots()
	for _, l_Bot in pairs(self._Bots) do
		l_Bot:ResetVars()
	end
end

---@param p_Player Player
---@param p_Option string|'"mode"'|'"speed"'
---@param p_Value integer|BotMoveModes|BotMoveSpeeds
function BotManager:SetStaticOption(p_Player, p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			if l_Bot:IsStaticMovement() then
				if p_Option == "mode" then
					l_Bot:SetMoveMode(p_Value)
				elseif p_Option == "speed" then
					l_Bot:SetSpeed(p_Value)
				end
			end
		end
	end
end

---@param p_Option string|'"shoot"'|'"respawn"'|'"moveMode"'
---@param p_Value boolean|integer|BotMoveModes
function BotManager:SetOptionForAll(p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if p_Option == "shoot" then
			l_Bot:SetShoot(p_Value)
		elseif p_Option == "respawn" then
			l_Bot:SetRespawn(p_Value)
		elseif p_Option == "moveMode" then
			l_Bot:SetMoveMode(p_Value)
		end
	end
end

---@param p_Player Player
---@param p_Option string|'"shoot"'|'"respawn"'|'"moveMode"'
---@param p_Value boolean|integer|BotMoveModes
function BotManager:SetOptionForPlayer(p_Player, p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			if p_Option == "shoot" then
				l_Bot:SetShoot(p_Value)
			elseif p_Option == "respawn" then
				l_Bot:SetRespawn(p_Value)
			elseif p_Option == "moveMode" then
				l_Bot:SetMoveMode(p_Value)
			end
		end
	end
end

---@param p_Name string
---@return Bot
function BotManager:GetBotByName(p_Name)
	return self._BotsByName[p_Name]
end

---@param p_Name string
---@param p_TeamId integer|TeamId
---@param p_SquadId integer|SquadId
---@return Bot|nil
function BotManager:CreateBot(p_Name, p_TeamId, p_SquadId)
	--m_Logger:Write('botsByTeam['..#self._BotsByTeam[2]..'|'..#self._BotsByTeam[3]..']')

	local s_Bot = self:GetBotByName(p_Name)

	if s_Bot ~= nil then
		s_Bot.m_Player.teamId = p_TeamId
		s_Bot.m_Player.squadId = p_SquadId
		s_Bot:ResetVars()
		return s_Bot
	end

	-- check for max-players
	local s_PlayerLimit = Globals.MaxPlayers

	if Config.KeepOneSlotForPlayers then
		s_PlayerLimit = s_PlayerLimit - 1
	end

	if s_PlayerLimit <= PlayerManager:GetPlayerCount() then
		m_Logger:Write("playerlimit reached")
		return nil
	end

	-- Create a player for this bot.
	local s_BotPlayer = PlayerManager:CreatePlayer(p_Name, p_TeamId, p_SquadId)

	if s_BotPlayer == nil then
		m_Logger:Write("can't create more players on this team")
		return nil
	end

	-- Create input for this bot.
	local s_BotInput = EntryInput()
	s_BotInput.deltaTime = 1.0 / SharedUtils:GetTickrate()
	s_BotInput.flags = EntryInputFlags.AuthoritativeAiming
	s_BotPlayer.input = s_BotInput

	---@type Bot
	s_Bot = Bot(s_BotPlayer)

	local teamLookup = s_Bot.m_Player.teamId + 1
	table.insert(self._Bots, s_Bot)
	self._BotsByTeam[teamLookup] = self._BotsByTeam[teamLookup] or {}
	table.insert(self._BotsByTeam[teamLookup], s_Bot)
	self._BotsByName[p_Name] = s_Bot
	self._BotInputs[s_BotPlayer.id] = s_BotInput -- bot inputs are stored to prevent garbage collection
	return s_Bot
end

---@param p_Bot Bot
---@param p_Transform LinearTransform
---@param p_Pose CharacterPoseType|integer
---@param p_SoldierBp SoldierBlueprint|DataContainer
---@param p_Kit CharacterCustomizationAsset|DataContainer
---@param p_Unlocks UnlockAsset[]|DataContainer[]
---@return SoldierEntity|nil
function BotManager:SpawnBot(p_Bot, p_Transform, p_Pose, p_SoldierBp, p_Kit, p_Unlocks)
	if p_Bot.m_Player.soldier ~= nil then
		p_Bot.m_Player.soldier:Destroy()
	end

	if p_Bot.m_Player.corpse ~= nil then
		p_Bot.m_Player.corpse:Destroy()
	end

	p_Bot.m_Player:SelectUnlockAssets(p_Kit, p_Unlocks)
	local s_BotSoldier = p_Bot.m_Player:CreateSoldier(p_SoldierBp, p_Transform) -- Returns SoldierEntity

	if s_BotSoldier == nil then
		m_Logger:Error("CreateSoldier failed")
		return nil
	end

	-- Customisation of health of bot
	s_BotSoldier.maxHealth = Config.BotMaxHealth

	p_Bot.m_Player:SpawnSoldierAt(s_BotSoldier, p_Transform, p_Pose)
	p_Bot.m_Player:AttachSoldier(s_BotSoldier)

	if p_Bot.m_Player.soldier == nil then
		m_Logger:Error("AttachSoldier failed. Maybe the spawn failed as well")
		return nil
	elseif p_Bot.m_Player.soldier ~= s_BotSoldier then
		m_Logger:Error("AttachSoldier failed. We still have the old SoldierEntity attached to the Player.")
		return nil
	else
		return s_BotSoldier
	end
end

---@param p_Player Player
function BotManager:KillPlayerBots(p_Player)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			l_Bot:ResetVars()

			if l_Bot.m_Player.soldier ~= nil then
				l_Bot.m_Player.soldier:Kill()
			end
		end
	end
end

function BotManager:ResetAllBots()
	for _, l_Bot in pairs(self._Bots) do
		l_Bot:ResetVars()
	end
end

function BotManager:ResetSkills()
	for _, l_Bot in pairs(self._Bots) do
		l_Bot:ResetSkill()
	end
end

---@param p_Amount? integer
---@param p_TeamId? TeamId|integer
function BotManager:KillAll(p_Amount, p_TeamId)
	local s_BotTable = self._Bots

	if p_TeamId ~= nil then
		s_BotTable = self._BotsByTeam[p_TeamId + 1]
	end

	p_Amount = p_Amount or #s_BotTable

	for _, l_Bot in pairs(s_BotTable) do
		l_Bot:Kill()

		p_Amount = p_Amount - 1

		if p_Amount <= 0 then
			return
		end
	end
end

---@param p_Amount? integer
---@param p_TeamId? TeamId|integer
---@param p_Force? boolean
function BotManager:DestroyAll(p_Amount, p_TeamId, p_Force)
	local s_BotTable = self._Bots

	if p_TeamId ~= nil then
		s_BotTable = self._BotsByTeam[p_TeamId + 1]
	end

	p_Amount = p_Amount or #s_BotTable

	for _, l_Bot in pairs(s_BotTable) do
		if p_Force then
			self:DestroyBot(l_Bot)
		else
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end

		p_Amount = p_Amount - 1

		if p_Amount <= 0 then
			return
		end
	end
end

function BotManager:DestroyDisabledBots()
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:IsInactive() then
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end
	end
end

---@param p_Player Player
function BotManager:DestroyPlayerBots(p_Player)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end
	end
end

function BotManager:RefreshTables()
	local s_NewTeamsTable = { {}, {}, {}, {}, {} }
	local s_NewBotTable = {}
	local s_NewBotbyNameTable = {}

	for _, l_Bot in pairs(self._Bots) do
		if l_Bot.m_Player ~= nil then
			table.insert(s_NewBotTable, l_Bot)
			table.insert(s_NewTeamsTable[l_Bot.m_Player.teamId + 1], l_Bot)
			s_NewBotbyNameTable[l_Bot.m_Player.name] = l_Bot
		end
	end

	self._Bots = s_NewBotTable
	self._BotsByTeam = s_NewTeamsTable
	self._BotsByName = s_NewBotbyNameTable
end

---@param p_Bot Bot @might be a string as well
function BotManager:DestroyBot(p_Bot)
	if type(p_Bot) == 'string' then
		p_Bot = self._BotsByName[p_Bot]
	end

	-- Bot was not found.
	if p_Bot == nil then
		return
	end

	-- Find index of this bot.
	local s_NewTable = {}

	for _, l_Bot in pairs(self._Bots) do
		if p_Bot.m_Name ~= l_Bot.m_Name then
			table.insert(s_NewTable, l_Bot)
		end

		l_Bot:ClearPlayer(p_Bot.m_Player)
	end

	self._Bots = s_NewTable

	local s_NewTeamsTable = {}

	for _, l_Bot in pairs(self._BotsByTeam[p_Bot.m_Player.teamId + 1]) do
		if p_Bot.m_Name ~= l_Bot.m_Name then
			table.insert(s_NewTeamsTable, l_Bot)
		end
	end

	self._BotsByTeam[p_Bot.m_Player.teamId + 1] = s_NewTeamsTable
	self._BotsByName[p_Bot.m_Name] = nil
	self._BotInputs[p_Bot.m_Id] = nil

	p_Bot:Destroy()
	p_Bot = nil
end

-- Comm-Actions
---@param p_Player Player
function BotManager:ExitVehicle(p_Player)
	if p_Player ~= nil and p_Player.soldier ~= nil then
		-- find closest bots in vehicle
		local s_ClosestDistance = nil
		local s_ClosestBot = nil

		for _, l_Bot in pairs(self._BotsByTeam[p_Player.teamId + 1]) do
			if l_Bot.m_InVehicle and l_Bot.m_Player.soldier ~= nil then
				if s_ClosestBot == nil then
					s_ClosestBot = l_Bot
					s_ClosestDistance = l_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Player.soldier.worldTransform.trans)
				else
					local s_Distance = l_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Player.soldier.worldTransform.trans)

					if s_Distance < s_ClosestDistance then
						s_ClosestDistance = s_Distance
						s_ClosestBot = l_Bot
					end
				end
			end
		end

		if s_ClosestBot ~= nil and s_ClosestDistance < Registry.COMMON.COMMAND_DISTANCE then
			local s_VehicleEntity = s_ClosestBot.m_Player.controlledControllable

			if s_VehicleEntity ~= nil then
				for i = 0, (s_VehicleEntity.entryCount - 1) do
					local s_Player = s_VehicleEntity:GetPlayerInEntry(i)

					if s_Player ~= nil then
						self:OnBotExitVehicle(s_Player.name)
					end
				end
			end
		end
	end
end

---@param p_Player Player
---@param p_Type string|'"ammo"'|'"medkit"'
function BotManager:Deploy(p_Player, p_Type)
	if p_Player ~= nil and p_Player.soldier ~= nil then
		-- find bots in range
		local s_BotsInRange = {}

		for _, l_Bot in pairs(self._BotsByTeam[p_Player.teamId + 1]) do
			if not l_Bot.m_InVehicle and l_Bot.m_Player.soldier ~= nil then
				if p_Type == "ammo" and l_Bot.m_Kit == BotKits.Support then
					local s_Distance = l_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Player.soldier.worldTransform.trans)

					if s_Distance < Registry.COMMON.COMMAND_DISTANCE then
						l_Bot:DeployIfPossible()
					end
				elseif p_Type == "medkit" and l_Bot.m_Kit == BotKits.Assault then
					local s_Distance = l_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Player.soldier.worldTransform.trans)

					if s_Distance < Registry.COMMON.COMMAND_DISTANCE then
						l_Bot:DeployIfPossible()
					end
				end
			end
		end
	end
end

---@param p_Player Player
function BotManager:RepairVehicle(p_Player)
	if p_Player ~= nil and p_Player.soldier ~= nil and p_Player.controlledControllable ~= nil and
		not p_Player.controlledControllable:Is("ServerSoldierEntity") then
		-- find bots in range
		local s_BotsInRange = {}

		for _, l_Bot in pairs(self._BotsByTeam[p_Player.teamId + 1]) do
			if not l_Bot.m_InVehicle and l_Bot.m_Player.soldier ~= nil then
				if l_Bot.m_Kit == BotKits.Engineer then
					local s_Distance = l_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Player.soldier.worldTransform.trans)

					if s_Distance < Registry.COMMON.COMMAND_DISTANCE then
						l_Bot:Repair(p_Player)
						break
					end
				end
			end
		end
	end
end

---@param p_Player Player
function BotManager:EnterVehicle(p_Player)
	if p_Player ~= nil and p_Player.soldier ~= nil then
		-- check for vehicle of player and seats
		if p_Player.controlledControllable ~= nil and not p_Player.controlledControllable:Is("ServerSoldierEntity") then
			local s_VehicleEntity = p_Player.controlledControllable
			local s_MaxFreeSeats = s_VehicleEntity.entryCount - 1

			for _, l_Bot in pairs(self._BotsByTeam[p_Player.teamId + 1]) do
				if not l_Bot.m_InVehicle and l_Bot.m_Player.soldier ~= nil then
					local s_Distance = l_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Player.soldier.worldTransform.trans)

					if s_Distance < Registry.COMMON.COMMAND_DISTANCE then
						l_Bot:EnterVehicleOfPlayer(p_Player)
						s_MaxFreeSeats = s_MaxFreeSeats - 1
					end
				end

				if s_MaxFreeSeats <= 0 then
					break
				end
			end
		end
	end
end

---@param p_Player Player
---@param p_Objective any @TODO add emmylua type
function BotManager:Attack(p_Player, p_Objective)
	if Globals.IsConquest and p_Player ~= nil and p_Player.soldier ~= nil then
		local s_MaxObjectiveBots = 4

		for _, l_Bot in pairs(self._BotsByTeam[p_Player.teamId + 1]) do
			if l_Bot.m_Player.soldier ~= nil then
				local s_Distance = l_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Player.soldier.worldTransform.trans)

				if s_Distance < Registry.COMMON.COMMAND_DISTANCE then
					l_Bot:UpdateObjective(p_Objective)
					s_MaxObjectiveBots = s_MaxObjectiveBots - 1
				end
			end

			if s_MaxObjectiveBots <= 0 then
				break
			end
		end
	end
end

-- =============================================
-- Private Functions
-- =============================================

---@param p_RaycastData any @TODO add emmylua type
function BotManager:_DistributeRaycastsBotBotAttack(p_RaycastData)
	local s_RaycastIndex = 0

	for i = 0, (#self._ActivePlayers - 1) do
		local s_Index = ((self._LastPlayerCheckIndex + i) % #self._ActivePlayers) + 1
		local s_ActivePlayer = PlayerManager:GetPlayerByName(self._ActivePlayers[s_Index])

		if s_ActivePlayer ~= nil then
			local s_RaycastsToSend = {}

			for l_Count = 1, self._RaycastsPerActivePlayer do
				if s_RaycastIndex < #p_RaycastData then
					s_RaycastIndex = s_RaycastIndex + 1
					table.insert(s_RaycastsToSend, p_RaycastData[s_RaycastIndex])
				else
					NetEvents:SendUnreliableToLocal('CheckBotBotAttack', s_ActivePlayer, s_RaycastsToSend)
					self._LastPlayerCheckIndex = s_Index
					return
				end
			end

			NetEvents:SendUnreliableToLocal('CheckBotBotAttack', s_ActivePlayer, s_RaycastsToSend)
		end
	end
end

function BotManager:_CheckForBotBotAttack()
	-- not enough on either team and no players to use
	if #self._ActivePlayers == 0 then
		return
	end

	-- create tables and scramble them
	if #self._BotBotAttackList == 0 then
		for _, s_TempBot in pairs(self._Bots) do
			if s_TempBot.m_InVehicle then
				if s_TempBot.m_ActiveVehicle ~= nil and s_TempBot.m_ActiveVehicle.Type ~= VehicleTypes.StationaryAA then
					table.insert(self._BotBotAttackList, s_TempBot.m_Name)
				end
			else
				table.insert(self._BotBotAttackList, s_TempBot.m_Name)
			end
		end

		for i = #self._BotBotAttackList, 2, -1 do
			local j = math.random(i)
			self._BotBotAttackList[i], self._BotBotAttackList[j] = self._BotBotAttackList[j], self._BotBotAttackList[i]
		end
	end

	local s_Raycasts = 0
	local s_ChecksDone = 0

	local s_RaycastEntries = {}

	for i = self._LastBotCheckIndex, #self._BotBotAttackList do
		-- body
		local s_BotNameToCheck = self._BotBotAttackList[i]
		local s_Bot = self:GetBotByName(s_BotNameToCheck)

		if s_Bot ~= nil and
			s_Bot.m_Player and
			s_Bot.m_Player.soldier ~= nil and
			s_Bot:IsReadyToAttack() then
			for _, l_BotName in pairs(self._BotBotAttackList) do
				if l_BotName ~= s_BotNameToCheck then
					local s_EnemyBot = self:GetBotByName(l_BotName)

					if s_EnemyBot ~= nil and
						s_EnemyBot.m_Player and
						s_EnemyBot.m_Player.soldier ~= nil and
						s_EnemyBot.m_Player.teamId ~= s_Bot.m_Player.teamId and
						s_EnemyBot:IsReadyToAttack() then
						-- check connection-state
						local s_ConnectionValue = ""
						local s_Id1 = s_Bot.m_Player.id
						local s_Id2 = s_EnemyBot.m_Player.id

						if s_Id1 > s_Id2 then
							s_ConnectionValue = tostring(s_Id2) .. "-" .. tostring(s_Id1)
						else
							s_ConnectionValue = tostring(s_Id1) .. "-" .. tostring(s_Id2)
						end

						if not self._ConnectionCheckState[s_ConnectionValue] then
							self._ConnectionCheckState[s_ConnectionValue] = true
							-- check distance
							local s_Distance = s_Bot.m_Player.soldier.worldTransform.trans:Distance(s_EnemyBot.m_Player.soldier.worldTransform
								.trans)
							s_ChecksDone = s_ChecksDone + 1
							local s_MaxDistance = s_Bot:GetAttackDistance()
							local s_MaxDistanceEnemyBot = s_EnemyBot:GetAttackDistance()

							if s_MaxDistanceEnemyBot > s_MaxDistance then
								s_MaxDistance = s_MaxDistanceEnemyBot
							end

							if s_Distance <= s_MaxDistance then
								table.insert(s_RaycastEntries, {
									Bot1 = s_BotNameToCheck,
									Bot2 = l_BotName,
									Bot1InVehicle = s_Bot.m_InVehicle,
									Bot2InVehicle = s_EnemyBot.m_InVehicle,
									Distance = s_Distance
								})
								s_Raycasts = s_Raycasts + 1

								if s_Raycasts >= (#self._ActivePlayers * self._RaycastsPerActivePlayer) then
									self._LastBotCheckIndex = i
									self:_DistributeRaycastsBotBotAttack(s_RaycastEntries)
									return
								end
							end

							if s_ChecksDone >= Registry.GAME_RAYCASTING.BOT_BOT_MAX_CHECKS then
								self._LastBotCheckIndex = i
								self:_DistributeRaycastsBotBotAttack(s_RaycastEntries)
								return
							end
						end
					end
				end
			end
		end

		self._LastBotCheckIndex = i
	end

	self:_DistributeRaycastsBotBotAttack(s_RaycastEntries)

	-- should only reach here if every connection has been checked
	-- clear the cache and start over
	self._LastBotCheckIndex = 1
	self._BotCheckState = {}
	self._ConnectionCheckState = {}
	self._BotBotAttackList = {}
end

---@param p_Damage integer
---@param p_Bot Bot
---@param p_Soldier SoldierEntity
---@param p_Fake boolean
---@return number
function BotManager:_GetDamageValue(p_Damage, p_Bot, p_Soldier, p_Fake)
	local s_ResultDamage = 0.0
	local s_DamageFactor = 1.0

	if p_Bot.m_ActiveWeapon.type == WeaponTypes.Shotgun then
		s_DamageFactor = Config.DamageFactorShotgun
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Assault then
		s_DamageFactor = Config.DamageFactorAssault
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Carabine then
		s_DamageFactor = Config.DamageFactorCarabine
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.PDW then
		s_DamageFactor = Config.DamageFactorPDW
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.LMG then
		s_DamageFactor = Config.DamageFactorLMG
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Sniper then
		s_DamageFactor = Config.DamageFactorSniper
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Pistol then
		s_DamageFactor = Config.DamageFactorPistol
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Knife then
		s_DamageFactor = Config.DamageFactorKnife
	end

	if not p_Fake then -- frag mode
		s_ResultDamage = p_Damage * s_DamageFactor
	else
		if p_Damage <= 2 then
			local s_Distance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Soldier.worldTransform.trans)

			if s_Distance >= p_Bot.m_ActiveWeapon.damageFalloffEndDistance then
				s_ResultDamage = p_Bot.m_ActiveWeapon.endDamage
			elseif s_Distance <= p_Bot.m_ActiveWeapon.damageFalloffStartDistance then
				s_ResultDamage = p_Bot.m_ActiveWeapon.damage
			else -- extrapolate damage
				local s_RelativePosition = (s_Distance - p_Bot.m_ActiveWeapon.damageFalloffStartDistance) /
					(p_Bot.m_ActiveWeapon.damageFalloffEndDistance - p_Bot.m_ActiveWeapon.damageFalloffStartDistance)
				s_ResultDamage = p_Bot.m_ActiveWeapon.damage -
					(s_RelativePosition * (p_Bot.m_ActiveWeapon.damage - p_Bot.m_ActiveWeapon.endDamage))
			end

			if p_Damage == 2 then
				s_ResultDamage = s_ResultDamage * Config.HeadShotFactorBots
			end

			s_ResultDamage = s_ResultDamage * s_DamageFactor
		elseif p_Damage == 3 then -- melee
			s_ResultDamage = p_Bot.m_Knife.damage * Config.DamageFactorKnife
		end
	end

	return s_ResultDamage
end

if g_BotManager == nil then
	---@type BotManager
	g_BotManager = BotManager()
end

return g_BotManager
