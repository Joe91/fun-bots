---@class FunBotServer
---@overload fun():FunBotServer
FunBotServer = class('FunBotServer')

-- The registry should be loaded first before loading anything else.
require('__shared/Registry/Registry')

require('__shared/Debug')
require('__shared/Config')
require('__shared/Constants/BotBehavior')
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/BotAttributes')
require('__shared/Constants/GmSpecialWeapons')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/WeaponTypes')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/BotMoveSpeeds')
require('__shared/Constants/SpawnModes')
require('__shared/Constants/SpawnMethods')
require('__shared/Constants/TeamSwitchModes')
require('__shared/Languages/Languages')
require('__shared/Settings/Type')
require('__shared/Settings/UpdateFlag')
require('__shared/Settings/BotEnums')
require('__shared/Settings/Range')
require('__shared/Settings/SettingsDefinition')
require('__shared/WeaponList')
require('__shared/EbxEditUtils')
require('__shared/Utils/Logger')
require('Vehicles')
require('UIServer')
require('UIPathMenu')
require('Model/Globals')
require('Constants/Permissions')

---@type Logger
local m_Logger = Logger("FunBotServer", Debug.Server.INFO)

require('__shared/Utilities')

---@type NodeEditor
local m_NodeEditor = require('NodeEditor')
---@type Language
local m_Language = require('__shared/Language')
---@type SettingsManager
local m_SettingsManager = require('SettingsManager')
---@type BotManager
local m_BotManager = require('BotManager')
---@type BotCreator
local m_BotCreator = require('BotCreator')
---@type BotSpawner
local m_BotSpawner = require('BotSpawner')
---@type WeaponList
local m_WeaponList = require('__shared/WeaponList')
---@type ChatCommands
local m_ChatCommands = require('Commands/Chat')
---@type Console
local m_Console = require('Commands/Console')
---@type RCONCommands
local m_RCONCommands = require('Commands/RCON')
---@type AirTargets
local m_AirTargets = require('AirTargets')
---@type GameDirector
local m_GameDirector = require('GameDirector')
---@type PermissionManager
PermissionManager = require('PermissionManager')


function FunBotServer:__init()
	self.m_PlayerKilledDelay = 0
	Events:Subscribe('Engine:Init', self, self.OnEngineInit)
	Events:Subscribe('Extension:Loaded', self, self.OnExtensionLoaded)
end

---VEXT Server Engine:Init Event
function FunBotServer:OnEngineInit()
	require('UpdateCheck')
end

---VEXT Shared Extension:Loaded Event
function FunBotServer:OnExtensionLoaded()
	-- destroy all still existing bot-players first
	m_BotManager:DestroyAllOldBotPlayers()
	m_SettingsManager:OnExtensionLoaded()
	m_Language:loadLanguage(Config.Language)
	m_WeaponList:UpdateWeaponList()
	self:RegisterEvents()
	self:RegisterHooks()
	self:RegisterCustomEvents()
	self:RegisterCallbacks()
	self:CreateBotAttributes()
	self:OnModReloaded()
end

function FunBotServer:RegisterEvents()
	Events:Subscribe('Extension:Unloading', self, self.OnExtensionUnloading)

	Events:Subscribe('Engine:Update', self, self.OnEngineUpdate)
	Events:Subscribe('UpdateManager:Update', self, self.OnUpdateManagerUpdate)

	Events:Subscribe('Level:Loaded', self, self.OnLevelLoaded)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
	Events:Subscribe('Server:RoundOver', self, self.OnRoundOver)
	Events:Subscribe('Server:RoundReset', self, self.OnRoundReset)

	Events:Subscribe('Player:Authenticated', self, self.OnPlayerAuthenticated)
	Events:Subscribe('Player:Joining', self, self.OnPlayerJoining)
	Events:Subscribe('Player:TeamChange', self, self.OnTeamChange)
	Events:Subscribe('Player:Respawn', self, self.OnPlayerRespawn)
	Events:Subscribe('Player:Killed', self, self.OnPlayerKilled)
	Events:Subscribe('Player:Chat', self, self.OnPlayerChat)
	Events:Subscribe('Player:Left', self, self.OnPlayerLeft)
	Events:Subscribe('Player:Destroyed', self, self.OnPlayerDestroyed)
	Events:Subscribe('Soldier:HealthAction', self, self.OnSoldierHealthAction)

	Events:Subscribe('CapturePoint:Lost', self, self.OnCapturePointLost)
	Events:Subscribe('CapturePoint:Captured', self, self.OnCapturePointCaptured)
	Events:Subscribe('Player:EnteredCapturePoint', self, self.OnPlayerEnteredCapturePoint)
	Events:Subscribe('Player:ExitedCapturePoint', self, self.OnPlayerExitedCapturePoint)
	Events:Subscribe('Vehicle:SpawnDone', self, self.OnVehicleSpawnDone)
	Events:Subscribe('Vehicle:Unspawn', self, self.OnVehicleUnspawn)
	Events:Subscribe('Vehicle:Damage', self, self.OnVehicleDamage)
	Events:Subscribe('Vehicle:Enter', self, self.OnVehicleEnter)
	Events:Subscribe('Vehicle:Exit', self, self.OnVehicleExit)
	Events:Subscribe('ScoringSystem:StatEvent', self, self.OnScoringStatEvent)

	Events:Subscribe('CombatArea:PlayerDeserting', self, self.OnCombatAreaDeserting)
	Events:Subscribe('CombatArea:PlayerReturning', self, self.OnCombatAreaReturning)
	Events:Subscribe('LifeCounter:BaseDestroyed', self, self.OnLifeCounterBaseDestoyed)

	Events:Subscribe('NodeCollection:FinishedLoading', self, self.OnFinishedLoading)
end

function FunBotServer:RegisterHooks()
	Hooks:Install('Soldier:Damage', 100, self, self.OnSoldierDamage)
	Hooks:Install('EntityFactory:Create', 100, self, self.OnEntityFactoryCreate)
	Hooks:Install('BulletEntity:Collision', 1, self, self.OnBulletEntityCollision)
end

function FunBotServer:RegisterCustomEvents()
	NetEvents:Subscribe("Botmanager:RaycastResults", self, self.OnClientRaycastResults)
	Events:Subscribe('Bot:RespawnBot', self, self.OnRespawnBot)
	Events:Subscribe('Bot:AbortWait', self, self.OnBotAbortWait)
	Events:Subscribe('Bot:ExitVehicle', self, self.OnBotExitVehicle)
	NetEvents:Subscribe('Client:RequestSettings', self, self.OnRequestClientSettings)
	NetEvents:Subscribe('Client:RequestEnterVehicle', self, self.OnRequestEnterVehicle)
	NetEvents:Subscribe('Client:RequestChangeVehicleSeat', self, self.OnRequestChangeSeatVehicle)
	NetEvents:Subscribe('ConsoleCommands:SetConfig', self, self.OnConsoleCommandSetConfig)
	NetEvents:Subscribe('ConsoleCommands:SaveAll', self, self.OnConsoleCommandSaveAll)
	NetEvents:Subscribe('ConsoleCommands:Restore', self, self.OnConsoleCommandRestore)
	NetEvents:Subscribe('ConsoleCommands:SpawnGrenade', self, self.OnSpawnGrenade)
	NetEvents:Subscribe('ConsoleCommands:DestroyObstaclesTest', self, self.OnDestroyObstaclesTest)
	NetEvents:Subscribe("SpawnPointHelper:TeleportTo", self, self.OnTeleportTo)
	m_NodeEditor:RegisterCustomEvents()
end

function FunBotServer:RegisterCallbacks()
	-- Use server-sided bullet damage.
	ResourceManager:RegisterInstanceLoadHandler(Guid('C4DCACFF-ED8F-BC87-F647-0BC8ACE0D9B4'),
		Guid('818334B3-CEA6-FC3F-B524-4A0FED28CA35'), self, self.OnServerSettingsCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('C4DCACFF-ED8F-BC87-F647-0BC8ACE0D9B4'),
		Guid('B983148D-4B2B-1CDA-D8A0-407789610202'), self, self.OnSyncedGameSettingsCallback)
	-- Modify stationary AA.
	ResourceManager:RegisterInstanceLoadHandler(Guid('15A6F4C7-1700-432B-95A7-D5DE8A058ED2'),
		Guid('465DA0A5-F57D-44CF-8383-7F7DC105973A'), self, self.OnStationaryAACallback)
	-- Conquest.
	ResourceManager:RegisterInstanceLoadHandler(Guid('0C342A8C-BCDE-11E0-8467-9159D6ACA94C'),
		Guid('0093213A-2BA5-4B27-979C-8C0B6DBE38CE'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('0C342A8C-BCDE-11E0-8467-9159D6ACA94C'),
		Guid('4CD461D1-A9D5-4A1B-A88D-D72AF01FB82D'), self, self.OnHumanPlayerEntityDataCallback)
	-- Domination.
	ResourceManager:RegisterInstanceLoadHandler(Guid('9E2ED50A-C01C-49BA-B3BE-9940BD4C5A08'),
		Guid('D9F43E4E-CDB1-4BE5-8C28-80CC6F860090'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('9E2ED50A-C01C-49BA-B3BE-9940BD4C5A08'),
		Guid('D90027CC-5A84-4BEB-8622-497E3DAEFA37'), self, self.OnHumanPlayerEntityDataCallback)
	-- Rush.
	ResourceManager:RegisterInstanceLoadHandler(Guid('56364B35-5D80-4874-9D74-CCF829D579D9'),
		Guid('015C301E-D440-4A25-9F2A-5AA59F6CDDCD'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('56364B35-5D80-4874-9D74-CCF829D579D9'),
		Guid('896A2B3B-DC2B-46C6-A288-1A4149C2790C'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full CTF Prototype.
	ResourceManager:RegisterInstanceLoadHandler(Guid('DF2A507F-0CB2-4430-B854-26589870B52C'),
		Guid('C2A37490-3663-4633-B9AD-7FB04B898A34'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('DF2A507F-0CB2-4430-B854-26589870B52C'),
		Guid('0DB61706-1F91-43F4-8898-13DA716E3E9E'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full GunMaster.
	ResourceManager:RegisterInstanceLoadHandler(Guid('F71EE45B-1BB0-4442-A46D-5B079A722230'),
		Guid('9C396851-78ED-49B9-8F24-FC6A8E2AF7A9'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('F71EE45B-1BB0-4442-A46D-5B079A722230'),
		Guid('4F65C8D9-EE5F-4CAB-BC97-A4DB3D7B528A'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full GunMaster XP4.
	ResourceManager:RegisterInstanceLoadHandler(Guid('F58C83A7-C753-4360-A9C0-4E44C79836F8'),
		Guid('58019F0F-3CDA-48EA-BAAE-A776D4395BCF'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('F58C83A7-C753-4360-A9C0-4E44C79836F8'),
		Guid('BF4E6675-DC22-4156-A978-C504C6A0B342'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full SquadDeathmatch.
	ResourceManager:RegisterInstanceLoadHandler(Guid('A2074F27-7D1F-11E0-B283-C22E2A7B7393'),
		Guid('5C01FD39-C10C-4D4B-ABDB-724B1EA54815'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('A2074F27-7D1F-11E0-B283-C22E2A7B7393'),
		Guid('99CFF247-8F58-489E-BB66-1FAEC6FDA8A9'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full SquadDeathmatch NoVehicles.
	ResourceManager:RegisterInstanceLoadHandler(Guid('1341E76F-293C-4091-AF99-05DFA3B73CF3'),
		Guid('C94EC3CF-FCCB-462C-83E1-8CA70A3A525A'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('1341E76F-293C-4091-AF99-05DFA3B73CF3'),
		Guid('43C71D6D-9972-4A8C-BD74-677972E49F4E'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full SquadDeathmatch XP4.
	ResourceManager:RegisterInstanceLoadHandler(Guid('7B941CFA-9955-461B-8390-0789AD9AA1A5'),
		Guid('FA2B2A7D-25C0-4B9B-BF2E-AF363F853F68'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('7B941CFA-9955-461B-8390-0789AD9AA1A5'),
		Guid('FF4D8BD7-7D79-499D-AA2B-18865FB01200'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full TeamDeathmatch.
	ResourceManager:RegisterInstanceLoadHandler(Guid('FAD987C1-7D2A-11E0-B283-C22E2A7B7393'),
		Guid('6E2D7A9F-67A8-4827-B261-0025C6559F7B'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('FAD987C1-7D2A-11E0-B283-C22E2A7B7393'),
		Guid('742EAB4B-FFCB-4201-ADAC-1D4BC20E6831'), self, self.OnHumanPlayerEntityDataCallback)
	-- Full TeamDeathmatch XP4.
	ResourceManager:RegisterInstanceLoadHandler(Guid('676C0FD7-EA75-4F5D-8764-BB076F6F3E11'),
		Guid('CC76229D-95EE-4B52-822B-BE222EED803B'), self, self.OnAutoTeamEntityDataCallback)
	ResourceManager:RegisterInstanceLoadHandler(Guid('676C0FD7-EA75-4F5D-8764-BB076F6F3E11'),
		Guid('4B797B64-6CDC-41F3-963D-DE22517EC4B5'), self, self.OnHumanPlayerEntityDataCallback)
	-- Coop.
	-- ResourceManager:RegisterInstanceLoadHandler(Guid('945CAF0E-B0F2-11DF-91B7-DD34EE95ED77'), Guid('77B694D1-046A-4A33-A5F2-4C667DB51D27'), self, self.OnHumanPlayerEntityDataCallback)
	-- SP.
	-- ResourceManager:RegisterInstanceLoadHandler(Guid('9C2FFA19-B419-11DF-A7E7-B3A3B68B4D14'), Guid('7B7F0014-13B6-4387-AE94-1E61548AB6D3'), self, self.OnHumanPlayerEntityDataCallback)
	-- FrontEnd.
	-- ResourceManager:RegisterInstanceLoadHandler(Guid('6EA4B5DA-DE3A-4808-A85C-FCA07B2AFB04'), Guid('8BD2E753-9B37-426A-8AA8-1685C8E2744D'), self, self.OnHumanPlayerEntityDataCallback)
	-- TutorialMP Sandbox.
	-- ResourceManager:RegisterInstanceLoadHandler(Guid('CC083805-FAC2-4940-9D8E-45C232C005E3'), Guid('592D94FC-68F7-413E-8B61-0ACEC4FD7D0D'), self, self.OnHumanPlayerEntityDataCallback)
	-- TutorialMP.
	-- ResourceManager:RegisterInstanceLoadHandler(Guid('8517D561-0AED-4C58-A634-5D069A8E1BA2'), Guid('502DA681-116F-494C-AFBD-DC02522A14B4'), self, self.OnHumanPlayerEntityDataCallback)
	-- TutorialMP ShootHouse.
	-- ResourceManager:RegisterInstanceLoadHandler(Guid('53C55F5E-C5CF-4B60-A455-445739D99501'), Guid('F4B49F70-BE94-4792-95E6-09A5F3F932F4'), self, self.OnHumanPlayerEntityDataCallback)
end

-- =============================================
-- Events.
-- =============================================

---VEXT Shared Extension:Unloading Event
function FunBotServer:OnExtensionUnloading()
	m_BotManager:DestroyAll(nil, nil, true)
end

---VEXT Shared Engine:Update Event
---@param p_DeltaTime number
---@param p_SimulationDeltaTime number
function FunBotServer:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	m_GameDirector:OnEngineUpdate(p_DeltaTime)
	m_NodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
end

---VEXT Shared UpdateManager:Update Event
---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function FunBotServer:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_BotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_BotSpawner:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_NodeEditor:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
end

function FunBotServer:OnScoringStatEvent(p_Player, p_ObjectPlayer, p_StatEvent, p_ParamX, p_ParamY, p_Value)
	if p_StatEvent == StatEvent.StatEvent_CrateArmed then
		m_GameDirector:OnMcomArmed(p_Player)
	end
	if p_StatEvent == StatEvent.StatEvent_CrateDisarmed then
		m_GameDirector:OnMcomDisarmed(p_Player)
	end
	--[[ If p_StatEvent == StatEvent.StatEvent_CrateDestroyed then.
		-- Not reliably usable, since place can be anywhere at this moment.
	end ]]
end

function FunBotServer:OnCombatAreaDeserting(p_Entity, p_Player)
	m_GameDirector:ToggleDirectionCombatZone(p_Entity, p_Player)
end

function FunBotServer:OnCombatAreaReturning(p_Entity, p_Player)
	m_GameDirector:ToggleDirectionCombatZone(p_Entity, p_Player)
end

function FunBotServer:OnLifeCounterBaseDestoyed(p_LifeCounterEntity, p_FinalBase)
	m_GameDirector:OnLifeCounterBaseDestoyed(p_LifeCounterEntity, p_FinalBase)
end

-- =============================================
-- Level Events.
-- =============================================

---VEXT Server Level:Loaded Event
---@param p_LevelName string
---@param p_GameMode string
---@param p_Round integer
---@param p_RoundsPerMap integer
function FunBotServer:OnLevelLoaded(p_LevelName, p_GameMode, p_Round, p_RoundsPerMap)
	Globals.GameMode = p_GameMode
	local s_CustomGameMode = ServerUtils:GetCustomGameModeName()

	m_WeaponList:OnLevelLoaded()

	-- Only use name of Level.
	p_LevelName = p_LevelName:gsub(".+/.+/", "")
	Globals.LevelName = p_LevelName
	Globals.Round = p_Round
	m_Logger:Write('OnLevelLoaded: ' .. p_LevelName .. ' ' .. p_GameMode)

	self:SetRespawnDelay()

	-- Don't reset list of Ignore-Bot-Names, if those are allowed to use.
	if not Registry.COMMON.ALLOW_PLAYER_BOT_NAMES then
		Globals.IgnoreBotNames = {}
	end

	self:DetectSpecialMods()
	self:RegisterInputRestrictionEventCallbacks()
	self:SetGameMode(p_GameMode, p_LevelName)
	self:SetMaxBotsPerTeam(p_GameMode)
	if Registry.COMMON.DESTROY_OBSTACLES_ON_START then
		self:DestroyObstacles(p_LevelName, p_GameMode)
	end

	m_GameDirector:OnLevelLoaded()
	m_AirTargets:OnLevelLoaded()
	m_BotSpawner:OnLevelLoaded(Globals.Round)
	m_NodeEditor:OnLevelLoaded(p_LevelName, p_GameMode, s_CustomGameMode)
end

function FunBotServer:OnFinishedLoading()
	m_NodeEditor:EndOfLoad()
	m_GameDirector:OnLoadFinished()
end

function FunBotServer:DestroyObstacles(p_LevelName, p_GameMode)
	local s_Positions = {}

	if p_LevelName == "XP4_Quake" and p_GameMode == "ConquestLarge0" then
		s_Positions[#s_Positions + 1] = Vec3(-172.89, 182.11, 96.32)
		s_Positions[#s_Positions + 1] = Vec3(-159.28, 173.89, 99.74)
		s_Positions[#s_Positions + 1] = Vec3(-74.64, 178.01, 42.61)
		s_Positions[#s_Positions + 1] = Vec3(-85.23, 178.01, 44.08)
		s_Positions[#s_Positions + 1] = Vec3(-89.42, 178.40, 50.82)
		s_Positions[#s_Positions + 1] = Vec3(-64.84, 179.04, -36.78)
		s_Positions[#s_Positions + 1] = Vec3(-77.92, 174.98, 4.35)
		s_Positions[#s_Positions + 1] = Vec3(-93.82, 174.97, -11.36)
	end

	for _, l_Position in ipairs(s_Positions) do
		self:SpawnGrenade(l_Position)
	end
end

---VEXT Shared Level:Destroy Event
function FunBotServer:OnLevelDestroy()
	m_BotManager:OnLevelDestroy()
	m_BotSpawner:OnLevelDestroy()
	m_NodeEditor:OnLevelDestroy()
	m_AirTargets:OnLevelDestroy()
	m_GameDirector:OnLevelDestroy()
	local s_OldMemory = math.floor(collectgarbage("count") / 1024)
	collectgarbage('collect')
	m_Logger:Write("*Collecting Garbage on Level Destroy: " ..
		math.floor(collectgarbage("count") / 1024) .. " MB | Old Memory: " .. s_OldMemory .. " MB")
end

---VEXT Server Server:RoundOver Event
---@param p_RoundTime number
---@param p_WinningTeam TeamId|integer
function FunBotServer:OnRoundOver(p_RoundTime, p_WinningTeam)
	m_GameDirector:OnRoundOver(p_RoundTime, p_WinningTeam)
	Globals.IsInputAllowed = false
end

---VEXT Server Server:RoundReset Event
function FunBotServer:OnRoundReset()
	m_GameDirector:OnRoundReset()
end

-- =============================================
-- Player Events.
-- =============================================

---VEXT Server Player:Authenticated Event
---@param p_Player Player
function FunBotServer:OnPlayerAuthenticated(p_Player)
	m_BotSpawner:OnPlayerAuthenticated(p_Player)
end

---VEXT Server Player:Joining Event
---@param p_Name string
---@param p_PlayerGuid Guid
---@param p_IpAddress string
---@param p_AccountGuid Guid
function FunBotServer:OnPlayerJoining(p_Name, p_PlayerGuid, p_IpAddress, p_AccountGuid)
	m_BotSpawner:OnPlayerJoining(p_Name)
end

---VEXT Server Player:TeamChange Event
---@param p_Player Player
---@param p_TeamId TeamId|integer
---@param p_SquadId SquadId|integer
function FunBotServer:OnTeamChange(p_Player, p_TeamId, p_SquadId)
	m_BotSpawner:OnTeamChange(p_Player, p_TeamId, p_SquadId)
end

---VEXT Server Player:Respawn Event
---@param p_Player Player
function FunBotServer:OnPlayerRespawn(p_Player)
	m_NodeEditor:OnPlayerRespawn(p_Player)
end

---VEXT Server Player:Killed Event
---@param p_Player Player
---@param p_Inflictor Player|nil
---@param p_Position Vec3
---@param p_Weapon string
---@param p_IsRoadKill boolean
---@param p_IsHeadShot boolean
---@param p_WasVictimInReviveState boolean
---@param p_Info DamageGiverInfo
function FunBotServer:OnPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot, p_WasVictimInReviveState, p_Info)
	m_NodeEditor:OnPlayerKilled(p_Player)
	m_AirTargets:OnPlayerKilled(p_Player)
end

---VEXT Server Player:Chat Event
---@param p_Player Player
---@param p_RecipientMask integer
---@param p_Message string
function FunBotServer:OnPlayerChat(p_Player, p_RecipientMask, p_Message)
	local s_MessageParts = string.lower(p_Message):split(' ')
	m_ChatCommands:Execute(s_MessageParts, p_Player)
end

---VEXT Server Player:Left Event
---@param p_Player Player
function FunBotServer:OnPlayerLeft(p_Player)
	m_BotManager:OnPlayerLeft(p_Player)
	m_NodeEditor:OnPlayerLeft(p_Player)
end

---VEXT Server Player:Destroyed Event
---@param p_Player Player
function FunBotServer:OnPlayerDestroyed(p_Player)
	m_NodeEditor:OnPlayerDestroyed(p_Player)
	m_AirTargets:OnPlayerDestroyed(p_Player)
end

---VEXT Server Soldier:HealthAction Event
---@param p_Soldier SoldierEntity
---@param p_Action HealthStateAction|integer
function FunBotServer:OnSoldierHealthAction(p_Soldier, p_Action)
	m_BotManager:OnSoldierHealthAction(p_Soldier, p_Action)
end

-- =============================================
-- CapturePoint Events.
-- =============================================

---VEXT Server CapturePoint:Lost Event
---@param p_CapturePoint Entity @`CapturePointEntity`
function FunBotServer:OnCapturePointLost(p_CapturePoint)
	m_GameDirector:OnCapturePointLost(p_CapturePoint)
end

---VEXT Server CapturePoint:Captured Event
---@param p_CapturePoint Entity @`CapturePointEntity`
function FunBotServer:OnCapturePointCaptured(p_CapturePoint)
	m_GameDirector:OnCapturePointCaptured(p_CapturePoint)
end

---VEXT Server Player:EnteredCapturePoint Event
---@param p_Player Player
---@param p_CapturePoint Entity @`CapturePointEntity`
function FunBotServer:OnPlayerEnteredCapturePoint(p_Player, p_CapturePoint)
	m_GameDirector:OnPlayerEnterExitCapturePoint(p_Player, p_CapturePoint)
end

---VEXT Server Player:EnteredCapturePoint Event
---@param p_Player Player
---@param p_CapturePoint Entity @`CapturePointEntity`
function FunBotServer:OnPlayerExitedCapturePoint(p_Player, p_CapturePoint)
	m_GameDirector:OnPlayerEnterExitCapturePoint(p_Player, p_CapturePoint)
end

-- =============================================
-- Vehicle Events.
-- =============================================

---VEXT Server Vehicle:SpawnDone Event
---@param p_VehicleEntity Entity @`ControllableEntity`
function FunBotServer:OnVehicleSpawnDone(p_VehicleEntity)
	m_GameDirector:OnVehicleSpawnDone(p_VehicleEntity)
end

function FunBotServer:OnVehicleUnspawn(p_VehicleEntity, p_VehiclePoints, p_HotTeam)
	m_GameDirector:OnVehicleUnspawn(p_VehicleEntity, p_VehiclePoints, p_HotTeam)
end

---VEXT Server Vehicle:Damage Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Damage number
---@param p_DamageGiverInfo DamageGiverInfo|nil
function FunBotServer:OnVehicleDamage(p_VehicleEntity, p_Damage, p_DamageGiverInfo)
	m_BotManager:OnVehicleDamage(p_VehicleEntity, p_Damage, p_DamageGiverInfo)
end

---VEXT Server Vehicle:Enter Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Player Player
function FunBotServer:OnVehicleEnter(p_VehicleEntity, p_Player)
	m_GameDirector:OnVehicleEnter(p_VehicleEntity, p_Player)
	m_AirTargets:OnVehicleEnter(p_VehicleEntity, p_Player)
end

---VEXT Server Vehicle:Exit Event
---@param p_VehicleEntity Entity @`ControllableEntity`
---@param p_Player Player
function FunBotServer:OnVehicleExit(p_VehicleEntity, p_Player)
	m_GameDirector:OnVehicleExit(p_VehicleEntity, p_Player)
	m_AirTargets:OnVehicleExit(p_VehicleEntity, p_Player)
end

-- =============================================
-- Hooks.
-- =============================================

---VEXT Server Soldier:Damage Hook
---@param p_HookCtx HookContext
---@param p_Soldier SoldierEntity
---@param p_Info DamageInfo
---@param p_GiverInfo DamageGiverInfo
function FunBotServer:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
	m_BotManager:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
end

function FunBotServer:OnEntityFactoryCreate(p_HookCtx, p_EntityData, p_Transform)
	if p_EntityData.typeInfo.name == "MissileEntityData" then
		local s_MissileEntityData = MissileEntityData(p_EntityData)
		if s_MissileEntityData.lockingController then
			local s_CreatedEntity = p_HookCtx:Call()
			if not s_CreatedEntity then
				return
			end
			local s_TimeDelay = s_MissileEntityData.engineTimeToIgnition + s_MissileEntityData.timeToActivateGuidingSystem
			local s_MaxSpeed = s_MissileEntityData.maxSpeed

			m_BotManager:CheckForFlareOrSmoke(s_CreatedEntity, s_MaxSpeed, s_TimeDelay)
		end
	end
	if Registry.DEBUG.VEHICLE_PROJECTILE_TRACE then
		if p_EntityData.typeInfo.name == "ProjectileEntityData" or p_EntityData.typeInfo.name == "BulletEntityData" or p_EntityData.typeInfo.name == "MissileEntityData" then
			local s_CreatedEntity = p_HookCtx:Call()
			if s_CreatedEntity then
				local s_SpartialEntity = SpatialEntity(s_CreatedEntity)
				-- Globals.LastPorjectile = s_SpartialEntity.transform
			end
		end
	end
end

---@param p_HookCtx HookContext
---@param p_Entity Entity
---@param p_Hit RayCastHit
---@param p_GiverInfo DamageGiverInfo
function FunBotServer:OnBulletEntityCollision(p_HookCtx, p_Entity, p_Hit, p_GiverInfo)
	if Registry.COMMON.USE_BUGGED_HITBOXES then
		return
	end

	if Registry.DEBUG.VEHICLE_PROJECTILE_TRACE then
		Globals.LastPorjectile = SpatialEntity(p_Entity).transform
	end

	if p_GiverInfo.giver and p_GiverInfo.giver.onlineId == 0 then
		local s_SyncedGameSettings = ResourceManager:GetSettings("SyncedGameSettings")

		if not s_SyncedGameSettings then return end

		s_SyncedGameSettings = SyncedGameSettings(s_SyncedGameSettings)
		s_SyncedGameSettings:MakeWritable()
		s_SyncedGameSettings.allowClientSideDamageArbitration = false
		p_HookCtx:Call()
		s_SyncedGameSettings.allowClientSideDamageArbitration = true
	end
end

-- =============================================
-- Custom Events.
-- =============================================

function FunBotServer:OnClientRaycastResults(p_Player, p_RaycastResults)
	m_BotManager:OnClientRaycastResults(p_Player, p_RaycastResults)
end

function FunBotServer:OnBotAbortWait(p_BotId)
	m_BotManager:OnBotAbortWait(p_BotId)
end

function FunBotServer:OnBotExitVehicle(p_BotId)
	m_BotManager:OnBotExitVehicle(p_BotId)
end

function FunBotServer:OnRespawnBot(p_BotId)
	m_BotSpawner:OnRespawnBot(p_BotId)
end

function FunBotServer:OnRequestClientSettings(p_Player)
	NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, true)
	m_Console:RegisterConsoleCommands(p_Player)
	m_BotManager:RegisterActivePlayer(p_Player)
end

function FunBotServer:OnRequestEnterVehicle(p_Player, p_BotName)
	m_BotManager:OnRequestEnterVehicle(p_Player, p_BotName)
end

function FunBotServer:OnRequestChangeSeatVehicle(p_Player, p_SeatNumber)
	m_BotManager:OnRequestChangeSeatVehicle(p_Player, p_SeatNumber)
end

function FunBotServer:OnConsoleCommandSetConfig(p_Player, p_Name, p_Value)
	m_Console:OnConsoleCommandSetConfig(p_Player, p_Name, p_Value)
end

function FunBotServer:OnConsoleCommandSaveAll(p_Player, p_Args)
	m_Console:OnConsoleCommandSaveAll(p_Player, p_Args)
end

function FunBotServer:OnConsoleCommandRestore(p_Player, p_Args)
	m_Console:OnConsoleCommandRestore(p_Player, p_Args)
end

function FunBotServer:OnSpawnGrenade(p_Player, p_Args)
	local position = p_Player.soldier.worldTransform.trans:Clone()
	position.y = position.y + 0.1

	m_Logger:Write("Grenade spawn at " .. tostring(position))
	self:SpawnGrenade(position)
end

function FunBotServer:OnDestroyObstaclesTest(p_Player, p_Args)
	self:DestroyObstacles(p_Args[1], p_Args[2])
end

function FunBotServer:SpawnGrenade(p_Position)
	local resource = ResourceManager:SearchForDataContainer('Weapons/M67/M67_Projectile')
	if not resource then
		return
	end

	local creationParams = EntityCreationParams()
	creationParams.transform = LinearTransform()
	creationParams.networked = true
	creationParams.transform.trans = p_Position

	local createdBus = EntityManager:CreateEntitiesFromBlueprint(resource, creationParams)

	if createdBus == nil then
		return
	end

	for _, entity in pairs(createdBus.entities) do
		entity:Init(Realm.Realm_ClientAndServer, true)
	end
end

function FunBotServer:OnTeleportTo(p_Player, p_Transform)
	if p_Player == nil or p_Player.soldier == nil then
		return
	end

	p_Player.soldier:SetTransform(p_Transform)
end

-- =============================================
-- Register Callbacks.
-- =============================================

---@param p_ServerSettings ServerSettings|DataContainer
function FunBotServer:OnServerSettingsCallback(p_ServerSettings)
	p_ServerSettings = ServerSettings(p_ServerSettings)
	p_ServerSettings:MakeWritable()
	p_ServerSettings.isRenderDamageEvents = true
	m_Logger:Write("Changed ServerSettings")
end

---@param p_SyncedGameSettings SyncedGameSettings|DataContainer
function FunBotServer:OnSyncedGameSettingsCallback(p_SyncedGameSettings)
	p_SyncedGameSettings = SyncedGameSettings(p_SyncedGameSettings)
	p_SyncedGameSettings:MakeWritable()
	if Registry.COMMON.USE_BUGGED_HITBOXES then
		p_SyncedGameSettings.allowClientSideDamageArbitration = false
	else
		p_SyncedGameSettings.allowClientSideDamageArbitration = true
	end
end

---@param p_FiringFunctionData FiringFunctionData|DataContainer
function FunBotServer:OnStationaryAACallback(p_FiringFunctionData)
	p_FiringFunctionData = FiringFunctionData(p_FiringFunctionData)
	p_FiringFunctionData:MakeWritable()
	p_FiringFunctionData.overHeat.heatPerBullet = 0.0001
	p_FiringFunctionData.dispersion[1].minAngle = 0.2 -- Config.spreadMinAngle
	p_FiringFunctionData.dispersion[1].maxAngle = 0.6 -- Config.spreadMaxAngle
	-- p_FiringFunctionData.shot.initialSpeed = Vec3(0, 0, Config.bulletSpeed)
	-- p_FiringFunctionData.shot.initialPosition = Vec3(0, 0, 35)
	-- p_FiringFunctionData.fireLogic.rateOfFire = Config.rateOfFire
	-- p_FiringFunctionData.fireLogic.clientFireRateMultiplier = Config.clientFireRateMultiplier
end

---@param p_AutoTeamEntityData AutoTeamEntityData|DataContainer
function FunBotServer:OnAutoTeamEntityDataCallback(p_AutoTeamEntityData)
	p_AutoTeamEntityData = AutoTeamEntityData(p_AutoTeamEntityData)
	p_AutoTeamEntityData:MakeWritable()
	p_AutoTeamEntityData.rotateTeamOnNewRound = false
	p_AutoTeamEntityData.teamAssignMode = TeamAssignMode.TamOneTeam
	p_AutoTeamEntityData.playerCountNeededToAutoBalance = 127
	p_AutoTeamEntityData.teamDifferenceToAutoBalance = 127
	p_AutoTeamEntityData.autoBalance = false
	p_AutoTeamEntityData.forceIntoSquad = true
end

---@param p_HumanPlayerEntityData HumanPlayerEntityData|DataContainer
function FunBotServer:OnHumanPlayerEntityDataCallback(p_HumanPlayerEntityData)
	p_HumanPlayerEntityData = HumanPlayerEntityData(p_HumanPlayerEntityData)
	self.m_PlayerKilledDelay = p_HumanPlayerEntityData.playerKilledDelay
end

-- =============================================
-- Functions.
-- =============================================

function FunBotServer:OnModReloaded()
	local s_FullLevelPath = SharedUtils:GetLevelName()

	if s_FullLevelPath == nil then
		return
	end

	local s_FullLevelPathTable = s_FullLevelPath:split('/')
	local s_Level = s_FullLevelPathTable[#s_FullLevelPathTable]
	local s_GameMode = SharedUtils:GetCurrentGameMode()
	m_Logger:Write(s_Level .. '_' .. s_GameMode .. ' reloaded')

	if s_Level ~= nil and s_GameMode ~= nil then
		self:OnLevelLoaded(s_Level, s_GameMode, TicketManager:GetCurrentRound(), TicketManager:GetRoundCount())
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

function FunBotServer:CreateBotAttributes()
	m_BotCreator:CreateBotAttributes()
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
	-- Disable inputs on start of round.
	Globals.IsInputAllowed = true

	if Globals.IsInputRestrictionDisabled then
		return
	end

	local s_EntityIterator = EntityManager:GetIterator("ServerInputRestrictionEntity")
	local s_Entity = s_EntityIterator:Next()

	while s_Entity do
		s_Entity = Entity(s_Entity)

		if s_Entity.data.instanceGuid == Guid('E8C37E6A-0C8B-4F97-ABDD-28715376BD2D') or
			-- Cq / CD assault / tank- / air superiority.
			s_Entity.data.instanceGuid == Guid('593710B7-EDC4-4EDB-BE20-323E7B0CE023') or -- Tdm XP4.
			s_Entity.data.instanceGuid == Guid('6F42FBE3-428A-463A-9014-AA0C6E09DA64') or -- Tdm.
			s_Entity.data.instanceGuid == Guid('9EDC59FB-5821-4A37-A739-FE867F251000') or -- Rush / sq rush.
			s_Entity.data.instanceGuid == Guid('BF4003AC-4B85-46DC-8975-E6682815204D') or -- Domination / scavenger.
			s_Entity.data.instanceGuid == Guid('A0158B87-FA34-4ED2-B752-EBFC1A34B081') or -- Gunmaster XP4.
			s_Entity.data.instanceGuid == Guid('AAF90FE3-D1CA-4CFE-84F3-66C6146AD96F') or -- Gunmaster.
			s_Entity.data.instanceGuid == Guid('753BD81F-07AC-4140-B05C-24210E1DF3FA') or -- Sqdm XP4.
			s_Entity.data.instanceGuid == Guid('CBFB0D7E-8561-4216-9AB2-99E14E9D18D0') or -- Sqdm noVehicles.
			s_Entity.data.instanceGuid == Guid('A40B08B7-D781-487A-8D0C-2E1B911C1949') then -- Sqdm.
			-- Rip CTF.
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

function FunBotServer:SetMaxBotsPerTeam(p_GameMode)
	if p_GameMode == 'TeamDeathMatchC0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamTdmc
	elseif p_GameMode == 'TeamDeathMatch0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamTdm
	elseif p_GameMode == 'SquadDeathMatch0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamSdm
	elseif p_GameMode == 'GunMaster0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamGm
	elseif p_GameMode == 'Scavenger0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamS
	elseif p_GameMode == 'ConquestLarge0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamCl
	elseif p_GameMode == 'ConquestSmall0' or p_GameMode == 'TankSuperiority0' or p_GameMode == 'BFLAG' or p_GameMode == 'BFLAG0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamCs
	elseif p_GameMode == 'ConquestAssaultLarge0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamCal
	elseif p_GameMode == 'ConquestAssaultSmall0' or p_GameMode == 'ConquestAssaultSmall1' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamCas
	elseif p_GameMode == 'RushLarge0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamRl
	elseif p_GameMode == 'Domination0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamD
	elseif p_GameMode == 'CaptureTheFlag0' then
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamCtf
	else
		Globals.MaxBotsPerTeam = Config.MaxBotsPerTeamDefault
	end
end

function FunBotServer:SetGameMode(p_GameMode, p_LevelName)
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
		p_GameMode == 'TankSuperiority0' or
		p_GameMode == "BFLAG0" or
		p_GameMode == 'BFLAG' then
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

	if p_GameMode == 'Domination0' then
		Globals.IsDomination = true
	else
		Globals.IsDomination = false
	end

	if p_GameMode == 'RushLarge0' or
		p_GameMode == 'SquadRush0' then
		Globals.IsRush = true
		if p_LevelName == "MP_Subway" or p_LevelName == "XP4_Rubble" then
			Globals.IsRushWithoutVehicles = true
		else
			Globals.IsRushWithoutVehicles = false
		end
	else
		Globals.IsRush = false
		Globals.IsRushWithoutVehicles = false
	end

	if p_GameMode == 'SquadRush0' then
		Globals.IsSquadRush = true
	else
		Globals.IsSquadRush = false
	end
end

if g_FunBotServer == nil then
	---@type FunBotServer
	g_FunBotServer = FunBotServer()
end

return g_FunBotServer
