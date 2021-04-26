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

local playerKilledDelay = 0

function FunBotServer:__init()
	m_Language:loadLanguage(Config.Language)
	Events:Subscribe('Engine:Init', self, self.OnEngineInit)
	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)
	Events:Subscribe('Player:Chat', self, self._onChat)
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnloading)
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded)
	Events:Subscribe('Partition:Loaded', self, self._onPartitionLoaded)
	

	Events:Subscribe('UpdateManager:Update', self, self.OnUpdate)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
	Events:Subscribe('Server:RoundOver', self, self.OnRoundOver)
	Events:Subscribe('Server:RoundReset', self, self.OnRoundReset)
	Events:Subscribe('CapturePoint:Lost', self, self.OnCapturePointLost)
	Events:Subscribe('CapturePoint:Captured', self, self.OnCapturePointCapture)
	Events:Subscribe('MCOM:Armed', self, self.OnMcomArmed)
	Events:Subscribe('MCOM:Disarmed', self, self.OnMcomDisarmed)
	Events:Subscribe('MCOM:Destroyed', self, self.OnMcomDestroyed)
	Events:Subscribe('Player:EnteredCapturePoint', self, self.OnPlayerEnterCapturePoint)
	Events:Subscribe('Engine:Update', self, self.OnUpdate)

	Hooks:Install('Soldier:Damage', 100, self, self.OnSoldierDamage)

	NetEvents:Subscribe('Client:RequestSettings', self, self._onRequestClientSettings)
	NetEvents:Subscribe('Bot:ShootAtPlayer', self, self.OnShootAt)
	NetEvents:Subscribe('Bot:RevivePlayer', self, self.OnRevivePlayer)
	NetEvents:Subscribe('Bot:ShootAtBot', self, self.OnBotShootAtBot)
	NetEvents:Subscribe('Client:DamagePlayer', self, self.OnDamagePlayer)   	--only triggered on false damage
	Events:Subscribe('Server:DamagePlayer', self, self.OnServerDamagePlayer) 	--only triggered on false damage
	Events:Subscribe('Player:Left', self, self.OnPlayerLeft)
	Events:Subscribe('Bot:RespawnBot', self, self.OnRespawnBot)
	Events:Subscribe('Player:KitPickup', self, self.OnKitPickup)
	Events:Subscribe('Player:Joining', self, self.OnPlayerJoining)
	Events:Subscribe('Player:TeamChange', self, self.OnTeamChange)

	--Events:Subscribe('Soldier:HealthAction', m_BotManager, m_BotManager._onHealthAction)	-- use this for more options on revive. Not needed yet
	--Events:Subscribe('GunSway:Update', m_BotManager, m_BotManager._onGunSway)
	--Events:Subscribe('GunSway:UpdateRecoil', m_BotManager, m_BotManager._onGunSway)
	--Events:Subscribe('Player:Destroyed', m_BotManager, m_BotManager._onPlayerDestroyed) -- Player left is called first, so use this one instead
	--Events:Subscribe('Engine:Message', m_BotManager, m_BotManager._onEngineMessage) -- maybe us this later
end

function FunBotServer:OnUpdate(p_DeltaTime, p_UpdatePass)
	m_BotManager:OnUpdate(p_DeltaTime, p_UpdatePass)
	m_BotSpawner.OnUpdate(p_DeltaTime, p_UpdatePass);
end

function FunBotServer:OnUpdate(p_DeltaTime)
	m_GameDirector:OnUpdate(p_DeltaTime)
end

function FunBotServer:OnLevelDestroy()
	m_BotManager:OnLevelDestroy()
	m_BotSpawner.OnLevelDestroy();
end

function FunBotServer:OnRoundOver(p_RoundTime, p_WinningTeam)
	m_GameDirector:OnRoundOver(p_RoundTime, p_WinningTeam)
end

function FunBotServer:OnRoundReset(p_RoundTime, p_WinningTeam)
	m_GameDirector:OnRoundReset(p_RoundTime, p_WinningTeam)
end

function FunBotServer:OnCapturePointLost(p_CapturePoint)
	m_GameDirector:OnCapturePointLost(p_CapturePoint)
end

function FunBotServer:OnCapturePointCapture(p_CapturePoint)
	m_GameDirector:OnCapturePointCapture(p_CapturePoint)
end

function FunBotServer:OnMcomArmed(p_Player)
	m_GameDirector:OnMcomArmed(p_Player)
end

function FunBotServer:OnMcomDisarmed(p_Player)
	m_GameDirector:OnMcomDisarmed(p_Player)
end

function FunBotServer:OnMcomDestroyed(p_Player)
	m_GameDirector:OnMcomDestroyed(p_Player)
end

function FunBotServer:OnPlayerEnterCapturePoint(p_Player, p_CapturePoint)
	m_GameDirector:OnPlayerEnterCapturePoint(p_Player, p_CapturePoint)
end

function FunBotServer:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
	m_BotManager:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
end

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

function FunBotServer:OnPlayerLeft(p_Player)
	m_BotManager:OnPlayerLeft(p_Player)
end

function FunBotServer:OnRespawnBot(p_BotName)
	m_BotSpawner:OnRespawnBot(p_BotName)
end

function FunBotServer:OnKitPickup(p_Player, p_NewCustomization)
	m_BotSpawner:OnKitPickup(p_Player, p_NewCustomization)
end

function FunBotServer:OnPlayerJoining(p_Name)
	m_BotSpawner:OnPlayerJoining(p_Name)
end

function FunBotServer:OnTeamChange(p_Player, p_TeamId, p_SquadId)
	m_BotSpawner:OnTeamChange(p_Player, p_TeamId, p_SquadId)
end



function FunBotServer:OnEngineInit()
	require('UpdateCheck')
end

function FunBotServer:_onExtensionUnloading()
	m_BotManager:destroyAll(nil, nil, true)
end

function FunBotServer:_onExtensionLoaded()
	m_SettingsManager:onLoad()

	local fullLevelPath = SharedUtils:GetLevelName()

	if (fullLevelPath ~= nil) then
		fullLevelPath = fullLevelPath:split('/')
		local level = fullLevelPath[#fullLevelPath]
		local gameMode = SharedUtils:GetCurrentGameMode()

		m_Logger:Write(level .. '_' .. gameMode .. ' reloaded')

		if (level ~= nil and gameMode~= nil) then
			self:_onLevelLoaded(level, gameMode)
		end
	end
end

function FunBotServer:_onPartitionLoaded(p_Partition)
	m_WeaponModification:OnPartitionLoaded(p_Partition)
	for _, instance in pairs(p_Partition.instances) do
		if USE_REAL_DAMAGE then
			if instance:Is("SyncedGameSettings") then
				instance = SyncedGameSettings(instance)
				instance:MakeWritable()
				instance.allowClientSideDamageArbitration = false
			end
			if instance:Is("ServerSettings") then
				instance = ServerSettings(instance)
				instance:MakeWritable()
				--instance.drawActivePhysicsObjects = true --doesn't matter
				--instance.isSoldierAnimationEnabled = true --doesn't matter
				--instance.isSoldierDetailedCollisionEnabled = true --doesn't matter
				instance.isRenderDamageEvents = true
			end
			if instance:Is("HumanPlayerEntityData") then
				instance = HumanPlayerEntityData(instance)
				playerKilledDelay =  instance.playerKilledDelay
			end
			if instance:Is("AutoTeamEntityData") then
				instance = AutoTeamEntityData(instance)
				instance:MakeWritable()
				--autoTeamData.enabled = false
				instance.rotateTeamOnNewRound = false
				instance.teamAssignMode = TeamAssignMode.TamOneTeam
				instance.playerCountNeededToAutoBalance = 127
				instance.teamDifferenceToAutoBalance = 127
				instance.autoBalance = false
				instance.forceIntoSquad = true
			end
		end
	end
end

function FunBotServer:_onRequestClientSettings(p_Player)
	NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, true)
	m_BotManager:registerActivePlayer(p_Player)
end

function FunBotServer:_onLevelLoaded(p_LevelName, p_GameMode)
	local customGameMode = ServerUtils:GetCustomGameModeName()
	if customGameMode ~= nil then
		p_GameMode = customGameMode
	end
	m_WeaponModification:ModifyAllWeapons(Config.BotAimWorsening, Config.BotSniperAimWorsening)
	m_WeaponList:onLevelLoaded()

	m_Logger:Write('level ' .. p_LevelName .. ' loaded...')

	--get RespawnDelay
	local rconResponseTable = RCON:SendCommand('vars.playerRespawnTime')
    local respawnTimeModifier = tonumber(rconResponseTable[2]) / 100
	if playerKilledDelay > 0 and respawnTimeModifier ~= nil then
		Globals.RespawnDelay = playerKilledDelay * respawnTimeModifier
	else
		Globals.RespawnDelay = 10.0
	end

	-- prepare some more Globals
	Globals.IgnoreBotNames = {}

	-- detect special mods:
	rconResponseTable = RCON:SendCommand('Modlist.ListRunning')
	local noPreroundFound = false
	local civilianizerFound = false
	for i = 2, #rconResponseTable do
		local mod = rconResponseTable[i]
		if string.find(mod:lower(), "preround") ~= nil then
			noPreroundFound = true
		end
		if string.find(mod:lower(), "civilianizer") ~= nil then
			civilianizerFound = true
		end
	end
	if civilianizerFound then
		Globals.RemoveKitVisuals = true
	else
		Globals.RemoveKitVisuals = false
	end
	if noPreroundFound then
		Globals.IsInputRestrictionDisabled = true
	else
		Globals.IsInputRestrictionDisabled = false
	end

	-- disable inputs on start of round
	Globals.IsInputAllowed = true

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
            s_Entity:RegisterEventCallback(function(entity, event)
                if not Globals.IsInputRestrictionDisabled then
                    if event.eventId == MathUtils:FNVHash("Activate") and Globals.IsInputAllowed then
                        Globals.IsInputAllowed = false
                    elseif event.eventId == MathUtils:FNVHash("Deactivate") and not Globals.IsInputAllowed then
                        Globals.IsInputAllowed = true
                    end
                end
            end)
        end
        s_Entity = s_EntityIterator:Next()
    end

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

	m_NodeEditor:onLevelLoaded(p_LevelName, p_GameMode)
	m_GameDirector:onLevelLoaded()
	m_GameDirector:initObjectives()
	m_BotSpawner:OnLevelLoaded()
	NetEvents:BroadcastUnreliableLocal('WriteClientSettings', Config, true)
end

function FunBotServer:_onChat(p_Player, p_RecipientMask, p_Message)
	local messageParts = string.lower(p_Message):split(' ')

	m_ChatCommands:execute(messageParts, p_Player)
end

if g_FunBotServer == nil then
	g_FunBotServer = FunBotServer()
end

return g_FunBotServer
