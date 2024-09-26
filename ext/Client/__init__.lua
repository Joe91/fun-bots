---@class FunBotClient
---@overload fun():FunBotClient
FunBotClient = class('FunBotClient')

require('__shared/Registry/Registry')

require('__shared/Config')
require('__shared/Debug')
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotWeapons')
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

---@type Logger
local m_Logger = Logger("FunBotClient", Debug.Client.INFO)

---@type ClientBotManager
local m_ClientBotManager = require('ClientBotManager')
---@type ClientNodeEditor
local m_ClientNodeEditor = require('ClientNodeEditor')
---@type ClientSpawnPointHelper
local m_ClientSpawnPointHelper = require('ClientSpawnPointHelper')
---@type ConsoleCommands
local m_ConsoleCommands = require('ConsoleCommands')
---@type Language
local m_Language = require('__shared/Language')
---@type FunBotUIClient
local m_FunBotUIClient = require('UIClient')

function FunBotClient:__init()
	Events:Subscribe('Extension:Loaded', self, self.OnExtensionLoaded)
	self._SettingsValid = false
end

function FunBotClient:OnExtensionLoaded()
	self._SettingsValid = false
	self:RegisterEvents()
	self:RegisterHooks()

	-- Announce the version in the client's console if enabled in the registry.
	if Registry.VERSION.CLIENT_SHOW_VERSION_ON_JOIN then
		print("Server is running fun-bots version " .. Registry.GetVersion())
	end
end

function FunBotClient:RegisterEvents()
	Events:Subscribe('Extension:Unloading', self, self.OnExtensionUnloading)
	Events:Subscribe('Engine:Message', self, self.OnEngineMessage)
	Events:Subscribe('UpdateManager:Update', self, self.OnUpdateManagerUpdate)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
	Events:Subscribe('Player:Deleted', self, self.OnPlayerDeleted)
	Events:Subscribe('Client:UpdateInput', self, self.OnClientUpdateInput)
	Events:Subscribe('Engine:Update', self, self.OnEngineUpdate)
	Events:Subscribe('Player:Respawn', self, self.OnPlayerRespawn)
	Events:Subscribe('UI:DrawHud', self, self.OnUIDrawHud)
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)

	NetEvents:Subscribe('WriteClientSettings', self, self.OnWriteClientSettings)
	NetEvents:Subscribe('CheckBotBotAttack', self, self.CheckForBotBotAttack)
	NetEvents:Subscribe('UI_Settings', self, self.OnUISettings)

	NetEvents:Subscribe('ConsoleCommands:RegisterCommands', self, self.OnRegisterConsoleCommands)
	NetEvents:Subscribe('ConsoleCommands:PrintResponse', self, self.OnPrintResponse)
	NetEvents:Subscribe('ClientNodeEditor:RegisterEvents', self, self.OnRegisterNodeEditorEvents)
end

function FunBotClient:RegisterHooks()
	Hooks:Install('UI:PushScreen', 1, self, self.OnUIPushScreen)
	Hooks:Install('Input:PreUpdate', 100, self, self.OnInputPreUpdate)
end

-- =============================================
-- Events
-- =============================================

---VEXT Shared Engine:Message Event
---@param p_Message Message
function FunBotClient:OnEngineMessage(p_Message)
	m_ClientBotManager:OnEngineMessage(p_Message)
end

---VEXT Client Player:Respawn Event
---@param p_Player Player
function FunBotClient:OnPlayerRespawn(p_Player)
	local s_LocalPlayer = PlayerManager:GetLocalPlayer()

	if s_LocalPlayer ~= nil and p_Player == s_LocalPlayer then
		local s_OldMemory = math.floor(collectgarbage("count") / 1024)
		collectgarbage('collect')
		m_Logger:Write("*Collecting Garbage on Level Destroy: " ..
			math.floor(collectgarbage("count") / 1024) .. " MB | Old Memory: " .. s_OldMemory .. " MB")
	end
end

---VEXT Shared UpdateManager:Update Event
---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function FunBotClient:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_ClientBotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_ClientNodeEditor:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
end

---VEXT Shared Extension:Unloading Event
function FunBotClient:OnExtensionUnloading()
	m_ClientBotManager:OnExtensionUnloading()
	m_FunBotUIClient:OnExtensionUnloading()
end

---VEXT Shared Level:Destroy Event
function FunBotClient:OnLevelDestroy()
	m_ClientBotManager:OnLevelDestroy()
	m_ClientNodeEditor:OnLevelDestroy()
	m_ClientSpawnPointHelper:OnLevelDestroy()
end

---VEXT Client Player:Deleted Event
---@param p_Player Player
function FunBotClient:OnPlayerDeleted(p_Player)
	m_ClientNodeEditor:OnPlayerDeleted(p_Player)
end

---VEXT Client Client:UpdateInput Event
---@param p_DeltaTime number
function FunBotClient:OnClientUpdateInput(p_DeltaTime)
	m_ClientNodeEditor:OnClientUpdateInput(p_DeltaTime)
	m_ClientBotManager:OnClientUpdateInput(p_DeltaTime)
	m_ClientSpawnPointHelper:OnClientUpdateInput(p_DeltaTime)
	m_FunBotUIClient:OnClientUpdateInput(p_DeltaTime)
end

---VEXT Shared Engine:Update Event
---@param p_DeltaTime number
---@param p_SimulationDeltaTime number
function FunBotClient:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	-- m_ClientNodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
end

---VEXT Client UI:DrawHud Event
function FunBotClient:OnUIDrawHud()
	m_ClientNodeEditor:OnUIDrawHud()
	m_ClientSpawnPointHelper:OnUIDrawHud()
end

---VEXT Shared Partition:Loaded Event
---@param p_Partition DatabasePartition
function FunBotClient:OnPartitionLoaded(p_Partition)
	m_ClientSpawnPointHelper:OnPartitionLoaded(p_Partition)
end

-- =============================================
-- NetEvents
-- =============================================
---@param p_NewConfig table
---@param p_UpdateWeaponSets boolean
function FunBotClient:OnWriteClientSettings(p_NewConfig, p_UpdateWeaponSets)
	m_ClientBotManager:OnWriteClientSettings(p_NewConfig, p_UpdateWeaponSets)

	if not self._SettingsValid then
		self._SettingsValid = true
		m_Language:loadLanguage(Config.Language)
		m_FunBotUIClient:OnExtensionLoaded()
	end
end

---@param p_RaycastData RaycastRequests
function FunBotClient:CheckForBotBotAttack(p_RaycastData)
	m_ClientBotManager:CheckForBotBotAttack(p_RaycastData)
end

---@param p_Data any
function FunBotClient:OnUISettings(p_Data)
	m_ClientNodeEditor:OnUISettings(p_Data)
end

---@param p_ConfigList table
function FunBotClient:OnRegisterConsoleCommands(p_ConfigList)
	m_ConsoleCommands:OnRegisterConsoleCommands(p_ConfigList)
end

function FunBotClient:OnRegisterNodeEditorEvents()
	m_ClientNodeEditor:OnRegisterEvents()
end

function FunBotClient:OnPrintResponse(p_Response)
	m_ConsoleCommands:OnPrintResponse(p_Response)
end

-- =============================================
-- Hooks
-- =============================================

---VEXT Client Input:PreUpdate Hook
---@param p_HookCtx HookContext
---@param p_Cache ConceptCache
---@param p_DeltaTime number
function FunBotClient:OnInputPreUpdate(p_HookCtx, p_Cache, p_DeltaTime)
	m_ClientBotManager:OnInputPreUpdate(p_HookCtx, p_Cache, p_DeltaTime)
end

---VEXT Client UI:PushScreen Hook
---@param p_HookCtx HookContext
---@param p_Screen DataContainer
---@param p_Priority UIGraphPriority
---@param p_ParentGraph DataContainer
---@param p_StateNodeGuid Guid|nil
function FunBotClient:OnUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
	m_ClientNodeEditor:OnUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
end

return FunBotClient()
