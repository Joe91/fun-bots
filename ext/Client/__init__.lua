class('FunBotClient')

require('__shared/Config')
require('__shared/Debug')
require('__shared/Constants/BotColors')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotKits')
require('__shared/Constants/BotNames')
require('__shared/Constants/BotWeapons')
require('__shared/Constants/WeaponSets')
require('__shared/Constants/BotAttackModes')
require('__shared/Constants/SpawnModes')
require ('__shared/Utils/Logger')

local m_Logger = Logger("FunBotClient", true)

--local m_Language = require('__shared/Language')
local m_ClientBotManager = require('ClientBotManager')
local m_ClientNodeEditor = require('ClientNodeEditor')
local m_ClientUi = require('UI/UI');


function FunBotClient:__init()
	Events:Subscribe('Extension:Loaded', self, self.OnExtensionLoaded)
end

function FunBotClient:OnExtensionLoaded()
	--m_Language:loadLanguage(Config.Language)
	self:RegisterEvents()
	self:RegisterHooks()
end

function FunBotClient:RegisterEvents()
	Events:Subscribe('Extension:Unloading', self, self.OnExtensionUnloading)
	Events:Subscribe('Engine:Message', self, self.OnEngineMessage)
	Events:Subscribe('UpdateManager:Update', self, self.OnUpdateManagerUpdate)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
	Events:Subscribe('Level:Loaded', self, self.OnLevelLoaded)
	Events:Subscribe('Player:Deleted', self, self.OnPlayerDeleted)
	Events:Subscribe('Client:UpdateInput', self, self.OnClientUpdateInput)
	Events:Subscribe('Engine:Update', self, self.OnEngineUpdate)
	Events:Subscribe('UI:DrawHud', self, self.OnUIDrawHud)

	NetEvents:Subscribe('WriteClientSettings', self, self.OnWriteClientSettings)
	NetEvents:Subscribe('CheckBotBotAttack', self, self.CheckForBotBotAttack)
	NetEvents:Subscribe('UI_ClientNodeEditor_Enabled', self, self.OnUIClientNodeEditorEnabled)
	NetEvents:Subscribe('UI_Settings', self, self.OnUISettings)
end

function FunBotClient:RegisterHooks()
	if not USE_REAL_DAMAGE then
		Hooks:Install('BulletEntity:Collision', 200, self, self.OnBulletEntityCollision)
	end
	Hooks:Install('UI:PushScreen', 1, self, self.OnUIPushScreen)
end

-- =============================================
-- Events
-- =============================================

function FunBotClient:OnEngineMessage(p_Message)
	m_ClientBotManager:OnEngineMessage(p_Message)
end

function FunBotClient:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_ClientBotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	m_ClientNodeEditor:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
end

function FunBotClient:OnExtensionUnloading()
	m_ClientBotManager:OnExtensionUnloading()
	m_FunBotUIClient:OnExtensionUnloading()
end

function FunBotClient:OnLevelDestroy()
	m_ClientBotManager:OnLevelDestroy()
	m_ClientNodeEditor:OnLevelDestroy()
end

function FunBotClient:OnLevelLoaded(p_LevelName, p_GameMode)
	m_ClientNodeEditor:OnLevelLoaded(p_LevelName, p_GameMode)
end

function FunBotClient:OnPlayerDeleted(p_Player)
	m_ClientNodeEditor:OnPlayerDeleted(p_Player)
end

function FunBotClient:OnClientUpdateInput(p_DeltaTime)
	m_ClientNodeEditor:OnClientUpdateInput(p_DeltaTime)
	m_FunBotUIClient:OnClientUpdateInput(p_DeltaTime)
end

function FunBotClient:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	m_ClientNodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
end

function FunBotClient:OnUIDrawHud()
	m_ClientNodeEditor:OnUIDrawHud()
end

-- =============================================
-- NetEvents
-- =============================================

function FunBotClient:OnWriteClientSettings(p_NewConfig, p_UpdateWeaponSets)
	m_ClientBotManager:OnWriteClientSettings(p_NewConfig, p_UpdateWeaponSets)
end

function FunBotClient:CheckForBotBotAttack(p_StartPos, p_EndPos, p_ShooterBotName, p_BotName, p_InVehicle)
	m_ClientBotManager:CheckForBotBotAttack(p_StartPos, p_EndPos, p_ShooterBotName, p_BotName, p_InVehicle)
end

function FunBotClient:OnUIClientNodeEditorEnabled(p_Args)
	m_ClientNodeEditor:OnSetEnabled(p_Args)
end

function FunBotClient:OnUISettings(p_Data)
	m_ClientNodeEditor:OnUISettings(p_Data)
end

-- =============================================
-- Hooks
-- =============================================

function FunBotClient:OnBulletEntityCollision(p_HookCtx, p_Entity, p_Hit, p_Shooter)
	m_ClientBotManager:OnBulletEntityCollision(p_HookCtx, p_Entity, p_Hit, p_Shooter)
end

function FunBotClient:OnUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
	m_ClientNodeEditor:OnUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
end

if g_FunBotClient == nil then
	g_FunBotClient = FunBotClient()
end

return g_FunBotClient
