class('FunBotServer')

require('__shared/Version')
require('__shared/Debug')
require('__shared/Config')
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/SpawnModes')
require ('__shared/Utils/Logger')
require('Globals')

local m_Logger = Logger("FunBotServer", Debug.Server.INFO)

require('__shared/Utilities')

local m_NodeEditor = require('NodeEditor')
local m_WeaponModification = require('WeaponModification')
local m_Language = require('__shared/Language')
local m_SettingsManager = require('SettingsManager')
local m_BotManager = require('BotManager')
local m_BotSpawner = require('BotSpawner')
local m_WeaponList = require('__shared/WeaponList')
local m_ChatCommands = require('ChatCommands')
local m_RCONCommands = require('RCONCommands')
local m_FunBotUIServer = require('UIServer')
local m_GameDirector = require('GameDirector')


function FunBotServer:__init()
	self.m_PlayerKilledDelay = 0
	Events:Subscribe('Engine:Init', self, self.OnEngineInit)
	Events:Subscribe('Extension:Loaded', self, self.OnExtensionLoaded)
end

function FunBotServer:OnEngineInit()
	require('UpdateCheck')
end

function FunBotServer:OnExtensionLoaded()
	m_Language:loadLanguage(Config.Language)
	m_SettingsManager:onLoad()
	self:RegisterEvents()
	self:RegisterHooks()
	self:RegisterCustomEvents()
	self:OnModReloaded()
end

function FunBotServer:RegisterEvents()
	Events:Subscribe('Extension:Unloading', self, self.OnExtensionUnloading)

	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
	Events:Subscribe('Engine:Update', self, self.OnEngineUpdate)
	Events:Subscribe('UpdateManager:Update', self, self.OnUpdateManagerUpdate)

	Events:Subscribe('Level:Loaded', self, self.OnLevelLoaded)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
	Events:Subscribe('Server:RoundOver', self, self.OnRoundOver)
	Events:Subscribe('Server:RoundReset', self, self.OnRoundReset)

	Events:Subscribe('Player:Joining', self, self.OnPlayerJoining)
	Events:Subscribe('Player:TeamChange', self, self.OnTeamChange)
	Events:Subscribe('Player:KitPickup', self, self.OnKitPickup)
	Events:Subscribe('Player:Chat', self, self.OnPlayerChat)
	Events:Subscribe('Player:Left', self, self.OnPlayerLeft)

	Events:Subscribe('CapturePoint:Lost', self, self.OnCapturePointLost)
	Events:Subscribe('CapturePoint:Captured', self, self.OnCapturePointCaptured)
	Events:Subscribe('Player:EnteredCapturePoint', self, self.OnPlayerEnteredCapturePoint)
	Events:Subscribe('MCOM:Armed', self, self.OnMcomArmed)
	Events:Subscribe('MCOM:Disarmed', self, self.OnMcomDisarmed)
	Events:Subscribe('MCOM:Destroyed', self, self.OnMcomDestroyed)
	Events:Subscribe('Vehicle:SpawnDone', self, self.OnVehicleSpawnDone)
	Events:Subscribe('Vehicle:Enter', self, self.OnVehicleEnter)

	--Events:Subscribe('Soldier:HealthAction', m_BotManager, m_BotManager._onHealthAction)	-- use this for more options on revive. Not needed yet
	--Events:Subscribe('GunSway:Update', m_BotManager, m_BotManager._onGunSway)
	--Events:Subscribe('GunSway:UpdateRecoil', m_BotManager, m_BotManager._onGunSway)
	--Events:Subscribe('Player:Destroyed', m_BotManager, m_BotManager._onPlayerDestroyed) -- Player left is called first, so use this one instead
	--Events:Subscribe('Engine:Message', m_BotManager, m_BotManager._onEngineMessage) -- maybe us this later
end

function FunBotServer:RegisterHooks()
	Hooks:Install('Soldier:Damage', 100, self, self.OnSoldierDamage)
end

function FunBotServer:RegisterCustomEvents()
	NetEvents:Subscribe('Bot:ShootAtPlayer', self, self.OnShootAt)
	NetEvents:Subscribe('Bot:RevivePlayer', self, self.OnRevivePlayer)
	NetEvents:Subscribe('Bot:ShootAtBot', self, self.OnBotShootAtBot)
	NetEvents:Subscribe('Client:DamagePlayer', self, self.OnDamagePlayer) --only triggered on false damage
	Events:Subscribe('Server:DamagePlayer', self, self.OnServerDamagePlayer) --only triggered on false damage
	Events:Subscribe('Bot:RespawnBot', self, self.OnRespawnBot)
	NetEvents:Subscribe('Client:RequestSettings', self, self.OnRequestClientSettings)
end

-- =============================================
-- Events
-- =============================================

function FunBotServer:OnExtensionUnloading()
	m_BotManager:destroyAll(nil, nil, true)
end

function FunBotServer:OnPartitionLoaded(p_Partition)
	m_WeaponModification:OnPartitionLoaded(p_Partition)
	for _, l_Instance in pairs(p_Partition.instances) do
		if USE_REAL_DAMAGE then
			if l_Instance:Is("SyncedGameSettings") then
				l_Instance = SyncedGameSettings(l_Instance)
				l_Instance:MakeWritable()
				l_Instance.allowClientSideDamageArbitration = false
			end
			if l_Instance:Is("ServerSettings") then
				l_Instance = ServerSettings(l_Instance)
				l_Instance:MakeWritable()
				--l_Instance.drawActivePhysicsObjects = true --doesn't matter
				--l_Instance.isSoldierAnimationEnabled = true --doesn't matter
				--l_Instance.isSoldierDetailedCollisionEnabled = true --doesn't matter
				l_Instance.isRenderDamageEvents = true
			end
		end
		if l_Instance:Is("HumanPlayerEntityData") then
			l_Instance = HumanPlayerEntityData(l_Instance)
			self.m_PlayerKilledDelay =  l_Instance.playerKilledDelay
		end
		if l_Instance:Is("AutoTeamEntityData") then
			l_Instance = AutoTeamEntityData(l_Instance)
			l_Instance:MakeWritable()
			l_Instance.rotateTeamOnNewRound = false
			l_Instance.teamAssignMode = TeamAssignMode.TamOneTeam
			l_Instance.playerCountNeededToAutoBalance = 127
			l_Instance.teamDifferenceToAutoBalance = 127
			l_Instance.autoBalance = false
			l_Instance.forceIntoSquad = true
		end
	end
end

function FunBotServer:OnEngineUpdate(p_DeltaTime)
	m_GameDirector:OnEngineUpdate(p_DeltaTime)
end

function FunBotServer:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_BotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_BotSpawner:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
end

-- =============================================
	-- Level Events
-- =============================================

function FunBotServer:OnLevelLoaded(p_LevelName, p_GameMode)
	local s_GameMode = ServerUtils:GetCustomGameModeName()
	if s_GameMode == nil then
		s_GameMode = p_GameMode
	end
	m_WeaponModification:ModifyAllWeapons(Config.BotAimWorsening, Config.BotSniperAimWorsening)
	m_WeaponList:onLevelLoaded()

	m_Logger:Write('OnLevelLoaded: ' .. p_LevelName .. ' ' .. s_GameMode)

	self:SetRespawnDelay()
	Globals.IgnoreBotNames = {}
	self:DetectSpecialMods()
	self:RegisterInputRestrictionEventCallbacks()
	self:SetGameMode(s_GameMode)

	m_NodeEditor:onLevelLoaded(p_LevelName, s_GameMode)
	m_GameDirector:onLevelLoaded()
	m_GameDirector:initObjectives()
	m_BotSpawner:OnLevelLoaded()
	NetEvents:BroadcastUnreliableLocal('WriteClientSettings', Config, true)
end

function FunBotServer:OnLevelDestroy()
	m_BotManager:OnLevelDestroy()
	m_BotSpawner:OnLevelDestroy()
end

function FunBotServer:OnRoundOver(p_RoundTime, p_WinningTeam)
	m_GameDirector:OnRoundOver(p_RoundTime, p_WinningTeam)
end

function FunBotServer:OnRoundReset(p_RoundTime, p_WinningTeam)
	m_GameDirector:OnRoundReset(p_RoundTime, p_WinningTeam)
end

-- =============================================
	-- Player Events
-- =============================================

function FunBotServer:OnPlayerJoining(p_Name)
	m_BotSpawner:OnPlayerJoining(p_Name)
end

function FunBotServer:OnTeamChange(p_Player, p_TeamId, p_SquadId)
	m_BotSpawner:OnTeamChange(p_Player, p_TeamId, p_SquadId)
end

function FunBotServer:OnKitPickup(p_Player, p_NewCustomization)
	m_BotSpawner:OnKitPickup(p_Player, p_NewCustomization)
end

function FunBotServer:OnPlayerChat(p_Player, p_RecipientMask, p_Message)
	local s_MessageParts = string.lower(p_Message):split(' ')
	m_ChatCommands:execute(s_MessageParts, p_Player)
end

function FunBotServer:OnPlayerLeft(p_Player)
	m_BotManager:OnPlayerLeft(p_Player)
end

-- =============================================
	-- CapturePoint Events
-- =============================================

function FunBotServer:OnCapturePointLost(p_CapturePoint)
	m_GameDirector:OnCapturePointLost(p_CapturePoint)
end

function FunBotServer:OnCapturePointCaptured(p_CapturePoint)
	m_GameDirector:OnCapturePointCaptured(p_CapturePoint)
end

function FunBotServer:OnPlayerEnteredCapturePoint(p_Player, p_CapturePoint)
	m_GameDirector:OnPlayerEnteredCapturePoint(p_Player, p_CapturePoint)
end

-- =============================================
	-- Vehicle Events
-- =============================================

function FunBotServer:OnVehicleSpawnDone(p_VehicleEntiy)
	m_GameDirector:OnVehicleSpawnDone(p_VehicleEntiy)
end

function FunBotServer:OnVehicleEnter(p_VehicleEntiy, p_Player)
	m_GameDirector:OnVehicleEnter(p_VehicleEntiy, p_Player)
end

-- =============================================
	-- MCOM Events
-- =============================================

function FunBotServer:OnMcomArmed(p_Player)
	m_GameDirector:OnMcomArmed(p_Player)
end

function FunBotServer:OnMcomDisarmed(p_Player)
	m_GameDirector:OnMcomDisarmed(p_Player)
end

function FunBotServer:OnMcomDestroyed(p_Player)
	m_GameDirector:OnMcomDestroyed(p_Player)
end

-- =============================================
-- Hooks
-- =============================================

function FunBotServer:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
	m_BotManager:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
end

-- =============================================
-- Custom Events
-- =============================================

function FunBotServer:OnShootAt(p_Player, p_BotName, p_IgnoreYaw)
	m_BotManager:OnShootAt(p_Player, p_BotName, p_IgnoreYaw)
end

function FunBotServer:OnRevivePlayer(p_Player, p_BotName)
	m_BotManager:OnRevivePlayer(p_Player, p_BotName)
end

function FunBotServer:OnBotShootAtBot(p_Player, p_BotName1, p_BotName2)
	m_BotManager:OnBotShootAtBot(p_Player, p_BotName1, p_BotName2)
end

function FunBotServer:OnDamagePlayer(p_Player, p_ShooterName, p_MeleeAttack, p_IsHeadShot)
	m_BotManager:OnDamagePlayer(p_Player, p_ShooterName, p_MeleeAttack, p_IsHeadShot)
end

function FunBotServer:OnServerDamagePlayer(p_PlayerName, p_ShooterName, p_MeleeAttack)
	m_BotManager:OnServerDamagePlayer(p_PlayerName, p_ShooterName, p_MeleeAttack)
end

function FunBotServer:OnRespawnBot(p_BotName)
	m_BotSpawner:OnRespawnBot(p_BotName)
end

function FunBotServer:OnRequestClientSettings(p_Player)
	NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, true)
	m_BotManager:registerActivePlayer(p_Player)
end

-- =============================================
-- Functions
-- =============================================

function FunBotServer:OnModReloaded()
	local s_FullLevelPath = SharedUtils:GetLevelName()
	if s_FullLevelPath == nil then
		return
	end
	s_FullLevelPath = s_FullLevelPath:split('/')
	local s_Level = s_FullLevelPath[#s_FullLevelPath]
	local s_GameMode = SharedUtils:GetCurrentGameMode()
	m_Logger:Write(s_Level .. '_' .. s_GameMode .. ' reloaded')
	if s_Level ~= nil and s_GameMode ~= nil then
		self:OnLevelLoaded(s_Level, s_GameMode)
	end
end

function FunBotServer:SetRespawnDelay()
	local s_RconResponseTable = RCON:SendCommand('vars.playerRespawnTime')
    local s_RespawnTimeModifier = tonumber(s_RconResponseTable[2]) / 100
	if self.m_PlayerKilledDelay > 0 and s_RespawnTimeModifier ~= nil then
		Globals.RespawnDelay = self.m_PlayerKilledDelay * s_RespawnTimeModifier
	else
		Globals.RespawnDelay = 10.0
	end
end

function FunBotServer:DetectSpecialMods()
	local s_RconResponseTable = RCON:SendCommand('modlist.ListRunning')
	Globals.IsInputRestrictionDisabled = false
	Globals.RemoveKitVisuals = false
	for i = 2, #s_RconResponseTable do
		local s_ModName = s_RconResponseTable[i]
		if string.find(s_ModName:lower(), "preround") ~= nil then
			Globals.IsInputRestrictionDisabled = true
		end
		if string.find(s_ModName:lower(), "civilianizer") ~= nil then
			Globals.RemoveKitVisuals = true
		end
	end
end

function FunBotServer:RegisterInputRestrictionEventCallbacks()
	-- disable inputs on start of round
	Globals.IsInputAllowed = true

	if Globals.IsInputRestrictionDisabled then
		return
	end

    local s_EntityIterator = EntityManager:GetIterator("ServerInputRestrictionEntity")
    local s_Entity = s_EntityIterator:Next()

    while s_Entity do
        s_Entity = Entity(s_Entity)
        if s_Entity.data.instanceGuid == Guid('E8C37E6A-0C8B-4F97-ABDD-28715376BD2D') or -- cq / cq assault / tank- / air superiority
        s_Entity.data.instanceGuid == Guid('6F42FBE3-428A-463A-9014-AA0C6E09DA64') or -- tdm
        s_Entity.data.instanceGuid == Guid('9EDC59FB-5821-4A37-A739-FE867F251000') or -- rush / sq rush
        s_Entity.data.instanceGuid == Guid('BF4003AC-4B85-46DC-8975-E6682815204D') or -- domination / scavenger
        s_Entity.data.instanceGuid == Guid('AAF90FE3-D1CA-4CFE-84F3-66C6146AD96F') or -- gunmaster
        s_Entity.data.instanceGuid == Guid('A40B08B7-D781-487A-8D0C-2E1B911C1949') then -- sqdm
        -- rip CTF
            s_Entity:RegisterEventCallback(function(p_Entity, p_Event)
				if p_Event.eventId == MathUtils:FNVHash("Activate") and Globals.IsInputAllowed then
					Globals.IsInputAllowed = false
				elseif p_Event.eventId == MathUtils:FNVHash("Deactivate") and not Globals.IsInputAllowed then
					Globals.IsInputAllowed = true
				end
            end)
        end
        s_Entity = s_EntityIterator:Next()
    end
end

function FunBotServer:SetGameMode(p_GameMode)
	Globals.NrOfTeams = 2
	if p_GameMode == 'TeamDeathMatchC0' or p_GameMode == 'TeamDeathMatch0' then
		Globals.IsTdm = true
	else
		Globals.IsTdm = false
	end
	if p_GameMode == 'SquadDeathMatch0' then
		Globals.NrOfTeams = 4
		Globals.IsSdm = true
	else
		Globals.IsSdm = false
	end
	if p_GameMode == 'GunMaster0' then
		Globals.IsGm = true
	else
		Globals.IsGm = false
	end
	if p_GameMode == 'Scavenger0' then
		Globals.IsScavenger = true
	else
		Globals.IsScavenger = false
	end

	if p_GameMode == 'ConquestLarge0' or
	p_GameMode == 'ConquestSmall0' or
	p_GameMode == 'ConquestAssaultLarge0' or
	p_GameMode == 'ConquestAssaultSmall0' or
	p_GameMode == 'ConquestAssaultSmall1' or
	p_GameMode == 'BFLAG'then
		Globals.IsConquest = true
	else
		Globals.IsConquest = false
	end

	if p_GameMode == 'ConquestAssaultLarge0' or
	p_GameMode == 'ConquestAssaultSmall0' or
	p_GameMode == 'ConquestAssaultSmall1' then
		Globals.IsAssault = true
	else
		Globals.IsAssault = false
	end

	if p_GameMode == 'RushLarge0' then
		Globals.IsRush = true
	else
		Globals.IsRush = false
	end
end

if g_FunBotServer == nil then
	g_FunBotServer = FunBotServer()
end

return g_FunBotServer
