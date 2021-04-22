class('FunBotServer')

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
require('__shared/Utilities')

require('NodeEditor')
require('GameDirector')
require('WeaponModification')

Language					= require('__shared/Language')
local SettingsManager		= require('SettingsManager')
local BotManager			= require('BotManager')
local BotSpawner			= require('BotSpawner')
local WeaponList			= require('__shared/WeaponList')
local ChatCommands			= require('ChatCommands')
local RCONCommands			= require('RCONCommands')
local FunBotUIServer		= require('UIServer')
local Globals 				= require('Globals')

local playerKilledDelay 	= 0

function FunBotServer:__init()
	Language:loadLanguage(Config.language)

	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)
	Events:Subscribe('Player:Chat', self, self._onChat)
	Events:Subscribe('Extension:Unloading', self, self._onExtensionUnload)
	Events:Subscribe('Extension:Loaded', self, self._onExtensionLoaded)
	Events:Subscribe('Partition:Loaded', self, self._onPartitionLoaded)
	NetEvents:Subscribe('RequestClientSettings', self, self._onRequestClientSettings)
end

function FunBotServer:_onExtensionUnload()
	BotManager:destroyAll(nil, nil, true)
end

function FunBotServer:_onExtensionLoaded()
	SettingsManager:onLoad()

	local fullLevelPath = SharedUtils:GetLevelName()

	if (fullLevelPath ~= nil) then
		fullLevelPath	= fullLevelPath:split('/')
		local level		= fullLevelPath[#fullLevelPath]
		local gameMode	= SharedUtils:GetCurrentGameMode()

		if Debug.Server.INFO then
			print(level .. '_' .. gameMode .. ' reloaded')
		end

		if (level ~= nil and gameMode~= nil) then
			self:_onLevelLoaded(level, gameMode)
		end
	end
end

function FunBotServer:_onPartitionLoaded(partition)
	g_WeaponModification:OnPartitionLoaded(partition)
	for _, instance in pairs(partition.instances) do
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

function FunBotServer:_onRequestClientSettings(player)
	NetEvents:SendToLocal('WriteClientSettings', player, Config, true)
	BotManager:registerActivePlayer(player)
end

function FunBotServer:_onLevelLoaded(levelName, gameMode)
	local customGameMode = ServerUtils:GetCustomGameModeName()
	if customGameMode ~= nil then
		gameMode = customGameMode
	end
	g_WeaponModification:ModifyAllWeapons(Config.botAimWorsening, Config.botSniperAimWorsening)
	WeaponList:onLevelLoaded()

	if Debug.Server.INFO then
		print('level ' .. levelName .. ' loaded...')
	end

	--get RespawnDelay
	local rconResponseTable = RCON:SendCommand('vars.playerRespawnTime')
    local respawnTimeModifier = tonumber(rconResponseTable[2]) / 100
	if playerKilledDelay > 0 and respawnTimeModifier ~= nil then
		Globals.respawnDelay = playerKilledDelay * respawnTimeModifier
	else
		Globals.respawnDelay = 10.0
	end

	-- prepare some more Globals
	Globals.ignoreBotNames = {}

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
		Globals.removeKitVisuals = true
	else
		Globals.removeKitVisuals = false
	end
	if noPreroundFound then
		Globals.isInputRestrictionDisabled = true
	else
		Globals.isInputRestrictionDisabled = false
	end

	-- disable inputs on start of round
	Globals.isInputAllowed = true

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
                if not Globals.isInputRestrictionDisabled then
                    if event.eventId == MathUtils:FNVHash("Activate") and Globals.isInputAllowed then
                        Globals.isInputAllowed = false
                    elseif event.eventId == MathUtils:FNVHash("Deactivate") and not Globals.isInputAllowed then
                        Globals.isInputAllowed = true
                    end
                end
            end)
        end
        s_Entity = s_EntityIterator:Next()
    end

	Globals.nrOfTeams = 2
	if gameMode == 'TeamDeathMatchC0' or gameMode == 'TeamDeathMatch0' then
		Globals.isTdm = true
	else
		Globals.isTdm = false
	end
	if gameMode == 'SquadDeathMatch0' then
		Globals.nrOfTeams = 4
		Globals.isSdm = true
	else
		Globals.isSdm = false
	end
	if gameMode == 'GunMaster0' then
		Globals.isGm = true
	else
		Globals.isGm = false
	end
	if gameMode == 'Scavenger0' then
		Globals.isScavenger = true
	else
		Globals.isScavenger = false
	end

	if gameMode == 'ConquestLarge0' or
	gameMode == 'ConquestSmall0' or
	gameMode == 'ConquestAssaultLarge0' or
	gameMode == 'ConquestAssaultSmall0' or
	gameMode == 'ConquestAssaultSmall1' or
	gameMode == 'BFLAG'then
		Globals.isConquest = true
	else
		Globals.isConquest = false
	end

	if gameMode == 'ConquestAssaultLarge0' or
	gameMode == 'ConquestAssaultSmall0' or
	gameMode == 'ConquestAssaultSmall1' then
		Globals.isAssault = true
	else
		Globals.isAssault = false
	end

	if gameMode == 'RushLarge0' then
		Globals.isRush = true
	else
		Globals.isRush = false
	end

	g_NodeEditor:onLevelLoaded(levelName, gameMode)
	g_GameDirector:onLevelLoaded()
	g_GameDirector:initObjectives()
	BotSpawner:onLevelLoaded()
	NetEvents:BroadcastUnreliableLocal('WriteClientSettings', Config, true)
end

function FunBotServer:_onChat(player, recipientMask, message)
	local messageParts = string.lower(message):split(' ')

	ChatCommands:execute(messageParts, player)
end

-- Singleton.
if g_FunBotServer == nil then
	g_FunBotServer = FunBotServer()
end

return g_FunBotServer
