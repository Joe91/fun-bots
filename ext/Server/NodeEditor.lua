class "NodeEditor"

local m_NodeCollection = require('__shared/NodeCollection')
local m_Logger = Logger("NodeEditor", Debug.Server.NODEEDITOR)

function NodeEditor:__init()
	self.m_NodeReceiveDelay = 1
	self.m_NodeReceiveTimer = -1
	self.m_BatchSendTimer = 0
	self.m_NexBatchSend = 0
	self.m_PlayerSendingNodes = nil
	self.m_PlayersReceivingNodes = {}
	self.m_BotVision = {}
	self.m_Debugprints = 0
end

function NodeEditor:RegisterCustomEvents()
	NetEvents:Subscribe('NodeEditor:RequestNodes', self, self.OnRequestNodes)
	NetEvents:Subscribe('NodeEditor:SendNodes', self, self.OnSendNodes)
	NetEvents:Subscribe('NodeEditor:ReceivingNodes', self, self.OnReceiveNodes)
	NetEvents:Subscribe('NodeEditor:Create', self, self.OnCreate)
	NetEvents:Subscribe('NodeEditor:Init', self, self.OnInit)
	NetEvents:Subscribe('NodeEditor:WarpTo', self, self.OnWarpTo)
	-- NetEvents:Subscribe('UI_Request_Save_Settings', self, self.OnUIRequestSaveSettings)
	NetEvents:Subscribe('NodeEditor:SetBotVision', self, self.OnSetBotVision)
end

-- =============================================
-- Events
-- =============================================

-- =============================================
	-- Level Events
-- =============================================

function NodeEditor:OnLevelLoaded(p_LevelName, p_GameMode)
	self:Log('Level Load: %s %s', p_LevelName, p_GameMode)

	-- convert mapnames if needed
	if Globals.IsTdm or Globals.IsGm or Globals.IsScavenger then
		p_GameMode = 'TeamDeathMatch0' -- paths are compatible
	end

	if p_LevelName == "MP_Subway" and p_GameMode == "ConquestSmall0" then
		p_GameMode = "ConquestLarge0" --paths are the same
	end

	if p_LevelName == "XP4_Rubble" and p_GameMode == "ConquestAssaultLarge0" then
		p_GameMode = "ConquestAssaultSmall0"
	end

	m_NodeCollection:Load(p_LevelName, p_GameMode)

	local s_Counter = 0
	local s_Waypoints = m_NodeCollection:Get()

	for i = 1, #s_Waypoints do
		local s_Waypoint = s_Waypoints[i]

		if type(s_Waypoint.Next) == 'string' then
			s_Counter = s_Counter + 1
		end

		if type(s_Waypoint.Previous) == 'string' then
			s_Counter = s_Counter + 1
		end
	end

	self:Log('Load -> Stale Nodes: %d', s_Counter)
end

function NodeEditor:OnLevelDestroy()
	m_NodeCollection:Clear()
end

-- =============================================
	-- Player Events
-- =============================================

function NodeEditor:OnPlayerRespawn(p_Player)
	if self.m_BotVision[p_Player.name] == nil then
		return
	end

	self.m_BotVision[p_Player.name] = {
		Player = p_Player,
		Current = 0,
		Delay = 1,
		Speed = 0.5,
		State = true
	}
end

function NodeEditor:OnPlayerKilled(p_Player)
	if p_Player == nil or self.m_BotVision[p_Player.name] == nil then
		return
	end

	self.m_BotVision[p_Player.name] = {
		Player = p_Player,
		Current = 0,
		Delay = 0,
		Speed = 0.5,
		State = false
	}
end

function NodeEditor:OnPlayerLeft(p_Player)
	self:StopSendingNodes(p_Player)
end

function NodeEditor:OnPlayerDestroyed(p_Player)
	self:StopSendingNodes(p_Player)
end

-- =============================================
	-- Update Events
-- =============================================

function NodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	for l_PlayerName, l_TimeData in pairs(self.m_BotVision) do
		if type(l_TimeData) == 'table' then
			l_TimeData.Current = l_TimeData.Current + p_DeltaTime

			if l_TimeData.Current >= l_TimeData.Delay then
				self:Log('Player -> Fade [%s]: %s', l_TimeData.Player.name, l_TimeData.State)
				l_TimeData.Player:Fade(l_TimeData.Speed, l_TimeData.State)
				self.m_BotVision[l_PlayerName] = true
			else
				self.m_BotVision[l_PlayerName] = l_TimeData
			end
		end
	end
	-- receiving nodes from player takes priority over sending
	if self.m_NodeReceiveTimer >= 0 and self.m_PlayerSendingNodes ~= nil then
		self.m_NodeReceiveTimer = self.m_NodeReceiveTimer + p_DeltaTime

		if self.m_NodeReceiveTimer >= self.m_NodeReceiveDelay then
			NetEvents:SendToLocal('ClientNodeEditor:SendNodes', self.m_PlayerSendingNodes, #m_NodeCollection:Get())
			self.m_NodeReceiveTimer = -1
		end

		return
	end

	-- saving nodes before sending or recieving
	if m_NodeCollection:IsSaveActive() then
		m_NodeCollection:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	end

	-- only do sending if not receiving
	if self.m_BatchSendTimer < 0 or #self.m_PlayersReceivingNodes == 0 then
		return
	end

	self.m_BatchSendTimer = self.m_BatchSendTimer + p_DeltaTime

	for i = 1, #self.m_PlayersReceivingNodes do
		local s_SendStatus = self.m_PlayersReceivingNodes[i]

		if self.m_BatchSendTimer > s_SendStatus.BatchSendDelay then
			s_SendStatus.BatchSendDelay = s_SendStatus.BatchSendDelay + 0.02 -- milliseconds
			local s_DoneThisBatch = 0

			for j = s_SendStatus.Index, #s_SendStatus.Nodes do
				local s_SendableNode = {}

				for l_Key, l_Value in pairs(s_SendStatus.Nodes[j]) do
					if (l_Key == 'Next' or l_Key == 'Previous') and type(l_Value) == 'table' then
						s_SendableNode[l_Key] = l_Value.ID
					else
						s_SendableNode[l_Key] = l_Value
					end
				end

				NetEvents:SendToLocal('ClientNodeEditor:Create', s_SendStatus.Player, s_SendableNode)
				s_DoneThisBatch = s_DoneThisBatch + 1
				s_SendStatus.Index = j + 1

				if s_DoneThisBatch >= 30 then
					break
				end
			end
			if s_SendStatus.Index >= #s_SendStatus.Nodes then
				self:Log('Finished sending waypoints to %s', s_SendStatus.Player.name)
				table.remove(self.m_PlayersReceivingNodes, i)
				NetEvents:SendToLocal('ClientNodeEditor:Init', s_SendStatus.Player)
				break
			end
		end
	end

	if #self.m_PlayersReceivingNodes < 1 then
		self.m_BatchSendTimer = -1
	end
end

-- =============================================
-- Custom Events
-- =============================================

-- player has requested node collection to be sent
function NodeEditor:OnRequestNodes(p_Player)
	-- tell client to clear their list and how many to expect
	NetEvents:SendToLocal('ClientNodeEditor:ReceivingNodes', p_Player, #m_NodeCollection:Get())
end

-- player has indicated they are ready to receive nodes
function NodeEditor:OnSendNodes(p_Player)
	local s_Nodes = m_NodeCollection:Get()
	table.insert(self.m_PlayersReceivingNodes, {Player = p_Player, Index = 1, Nodes = s_Nodes, BatchSendDelay = 0})
	self.m_BatchSendTimer = 0
	self:Log('Sending %d waypoints to %s', #s_Nodes, p_Player.name)
end

-- player has indicated they are ready to send nodes to the server
function NodeEditor:OnReceiveNodes(p_Player, p_NodeCount)
	if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end	

	m_NodeCollection:Clear()
	self.m_PlayerSendingNodes = p_Player
	self.m_NodeReceiveTimer = 0
	self:Log('Receiving %d waypoints from %s', p_NodeCount, p_Player.name)
end

-- player is sending a single node over
function NodeEditor:OnCreate(p_Player, p_Data)
	if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	m_NodeCollection:Create(p_Data, true)
end

-- node payload has finished sending, setup events and calc indexes
function NodeEditor:OnInit(p_Player, p_Save)
	if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	m_NodeCollection:RecalculateIndexes()
	m_NodeCollection:ProcessMetadata()

	local s_StaleNodes = 0
	local s_NodesToCheck = m_NodeCollection:Get()
	self:Log('Nodes Received: %d', #s_NodesToCheck)

	for i = 1, #s_NodesToCheck do
		local s_Waypoint = s_NodesToCheck[i]

		if type(s_Waypoint.Next) == 'string' then
			s_StaleNodes = s_StaleNodes + 1
		end

		if type(s_Waypoint.Previous) == 'string' then
			s_StaleNodes = s_StaleNodes + 1
		end
	end

	self:Log('Stale Nodes: %d', s_StaleNodes)

	-- don't save when sent from client
	if p_Save then
		m_NodeCollection:Save()
	end
end

function NodeEditor:OnWarpTo(p_Player, p_Vec3Position)
	if p_Player == nil or not p_Player.alive or p_Player.soldier == nil or not p_Player.soldier.isAlive then
		return
	end

	self:Log('Teleporting %s to %s', p_Player.name, tostring(p_Vec3Position))
	p_Player.soldier:SetPosition(p_Vec3Position)
end

function NodeEditor:OnSetBotVision(p_Player, p_Enabled)
	self:Log('Player -> BotVision [%s]: %s', p_Player.name, p_Enabled)

	if p_Enabled then
		self.m_BotVision[p_Player.name] = {
			Player = p_Player,
			Current = 0,
			Delay = 1,
			Speed = 0.5,
			State = p_Enabled
		}
	else
		p_Player:Fade(0.5, false)
		self.m_BotVision[p_Player.name] = nil
	end
end

function NodeEditor:OnUIRequestSaveSettings(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	local s_Request = json.decode(p_Data)

	if s_Request.debugTracePaths then
		-- enabled, send them a fresh list
		self:OnRequestNodes(p_Player)
	else
		-- disabled, delete the client's list
		NetEvents:SendToLocal('NodeEditor:Clear', p_Player)
		NetEvents:SendToLocal('NodeEditor:ClientInit', p_Player)
	end
end

-- =============================================
-- Functions
-- =============================================

function NodeEditor:StopSendingNodes(p_Player)
	for i = 1, #self.m_PlayersReceivingNodes do
		if self.m_PlayersReceivingNodes[i].Player.name == p_Player.name then
			table.remove(self.m_PlayersReceivingNodes, i)
			break
		end
	end
end

function NodeEditor:Log(...)
	m_Logger:Write(Language:I18N(...))
end

if g_NodeEditor == nil then
	g_NodeEditor = NodeEditor()
end

return g_NodeEditor
