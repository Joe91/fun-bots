class "NodeEditor"

require('UIServer')
require('__shared/NodeCollection')

function NodeEditor:__init()
	self:RegisterEvents()
	self.nodeReceiveDelay = 1
	self.nodeReceiveTimer = -1
	self.batchSendTimer = 0
	self.nexBatchSend = 0
	self.playerSendingNodes = nil
	self.playersReceivingNodes = {}
	self.botVision = {}
	self.debugprints = 0
end

function NodeEditor:RegisterEvents()
	NetEvents:Subscribe('NodeEditor:RequestNodes', self, self._onRequestNodes)
	NetEvents:Subscribe('NodeEditor:SendNodes', self, self._onSendNodes)

	NetEvents:Subscribe('NodeEditor:ReceivingNodes', self, self._onReceiveNodes)
	NetEvents:Subscribe('NodeEditor:Create', self, self._onCreate)
	NetEvents:Subscribe('NodeEditor:Init', self, self._onInit)

	NetEvents:Subscribe('NodeEditor:WarpTo', self, self._onWarpTo)


	NetEvents:Subscribe('UI_Request_Save_Settings', self, self._onUIRequestSaveSettings)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	Events:Subscribe('Engine:Update', self, self._onEngineUpdate)
	Events:Subscribe('Player:Destroyed', self, self._onPlayerDestroyed)
	Events:Subscribe('Player:Left', self, self._onPlayerLeft)

	NetEvents:Subscribe('NodeEditor:SetBotVision', self, self._onSetBotVision)
	Events:Subscribe('Player:Respawn', self, self._onPlayerRespawn)
	Events:Subscribe('Player:Killed', self, self._onPlayerKilled)
end

function NodeEditor:Print(...)
	if Debug.Server.NODEEDITOR then
		print('NodeEditor: ' .. Language:I18N(...))
	end
end

function NodeEditor:_onPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot, p_wasVictimInReviveState, p_Info)
    if (p_Player ~= nil and self.botVision[p_Player.name] ~= nil) then
    	self.botVision[p_Player.name] = {
			Player = p_Player,
			Current = 0,
			Delay = 0,
			Speed = 0.5,
			State = false
		}
    end
end

function NodeEditor:_onPlayerRespawn(p_Player)
	if (self.botVision[p_Player.name] ~= nil) then
		self.botVision[p_Player.name] = {
			Player = p_Player,
			Current = 0,
			Delay = 1,
			Speed = 0.5,
			State = true
		}
	end
end

function NodeEditor:_onPlayerDestroyed(p_Player)
	self:_stopSendingNodes(p_Player)
end

function NodeEditor:_onPlayerLeft(p_Player)
	self:_stopSendingNodes(p_Player)
end

function NodeEditor:_onLevelDestroy(p_Args)
	g_NodeCollection:Clear(p_Args)
	g_NodeCollection:DeregisterEvents()
end

-- player has requested node collection to be sent
function NodeEditor:_onRequestNodes(p_Player)
	-- tell client to clear their list and how many to expect
	NetEvents:SendToLocal('ClientNodeEditor:ReceivingNodes', p_Player, #g_NodeCollection:Get())
end

-- player has indicated they are ready to receive nodes
function NodeEditor:_onSendNodes(p_Player)
	local nodes = g_NodeCollection:Get()
	table.insert(self.playersReceivingNodes, {Player = p_Player, Index = 1, Nodes = nodes, BatchSendDelay = 0})
	self.batchSendTimer = 0
	self:Print('Sending %d waypoints to %s', #nodes, p_Player.name)
end

function NodeEditor:_stopSendingNodes(p_Player)
	for i = 1, #self.playersReceivingNodes do
		if (self.playersReceivingNodes[i].Player.name == p_Player.name) then
			table.remove(self.playersReceivingNodes, i)
			break
		end
	end
end

-- player has indicated they are ready to send nodes to the server
function NodeEditor:_onReceiveNodes(p_Player, p_NodeCount)

	if (Config.SettingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(p_Player.accountGuid) ~= true) then
		self:Print('%s has no permissions for Waypoint-Editor.', p_Player.name)
		return
	end

	g_NodeCollection:Clear()
	self.playerSendingNodes = p_Player
	self.nodeReceiveTimer = 0
	self:Print('Receiving %d waypoints from %s', p_NodeCount, p_Player.name)
end

-- player is sending a single node over
function NodeEditor:_onCreate(p_Player, p_Data)

	if (Config.SettingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(p_Player.accountGuid) ~= true) then
		self:Print('%s has no permissions for Waypoint-Editor.', p_Player.name)
		return
	end

	g_NodeCollection:Create(p_Data, true)
end

-- node payload has finished sending, setup events and calc indexes
function NodeEditor:_onInit(p_Player, p_Save)

	if (Config.SettingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(p_Player.accountGuid) ~= true) then
		self:Print('%s has no permissions for Waypoint-Editor.', p_Player.name)
		return
	end

	g_NodeCollection:RecalculateIndexes()
	g_NodeCollection:ProcessMetadata()

	local staleNodes = 0
	local nodesToCheck = g_NodeCollection:Get()
	self:Print('Nodes Received: %d', #nodesToCheck)

	for i=1, #nodesToCheck do

		local waypoint = nodesToCheck[i]
		if (type(waypoint.Next) == 'string') then
			staleNodes = staleNodes+1
		end
		if (type(waypoint.Previous) == 'string') then
			staleNodes = staleNodes+1
		end
	end

	self:Print('Stale Nodes: %d', staleNodes)

	if (p_Save) then
		g_NodeCollection:Save()
	end
end

function NodeEditor:_onWarpTo(p_Player, p_Vec3Position)

	if (p_Player == nil or not p_Player.alive or p_Player.soldier == nil or not p_Player.soldier.isAlive) then
		return
	end

	self:Print('Teleporting %s to %s', p_Player.name, tostring(p_Vec3Position))

	p_Player.soldier:SetPosition(p_Vec3Position)
end

function NodeEditor:_onSetBotVision(p_Player, p_Enabled)
	self:Print('Player -> BotVision [%s]: %s', p_Player.name, p_Enabled)

	if (p_Enabled) then
		self.botVision[p_Player.name] = {
			Player = p_Player,
			Current = 0,
			Delay = 1,
			Speed = 0.5,
			State = p_Enabled
		}
	else
		p_Player:Fade(0.5, false)
		self.botVision[p_Player.name] = nil
	end
end

function NodeEditor:_onEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)

	for playerName, timeData in pairs(self.botVision) do
		if (type(timeData) == 'table') then
			timeData.Current = timeData.Current + p_DeltaTime

			if (timeData.Current >= timeData.Delay) then
				self:Print('Player -> Fade [%s]: %s', timeData.Player.name, timeData.State)

				timeData.Player:Fade(timeData.Speed, timeData.State)
				self.botVision[playerName] = true
			else
				self.botVision[playerName] = timeData
			end
		end
	end

	-- receiving nodes from player takes priority over sending
	if (self.nodeReceiveTimer >= 0 and self.playerSendingNodes ~= nil) then
		self.nodeReceiveTimer = self.nodeReceiveTimer + p_DeltaTime

		if (self.nodeReceiveTimer >= self.nodeReceiveDelay) then
			NetEvents:SendToLocal('ClientNodeEditor:SendNodes', self.playerSendingNodes, #g_NodeCollection:Get())
			self.nodeReceiveTimer = -1
		end
	else

		-- only do sending if not receiving
		if (self.batchSendTimer >= 0 and #self.playersReceivingNodes > 0) then
			self.batchSendTimer = self.batchSendTimer + p_DeltaTime

			for i = 1, #self.playersReceivingNodes do
				local sendStatus = self.playersReceivingNodes[i]

				if (self.batchSendTimer > sendStatus.BatchSendDelay) then
					sendStatus.BatchSendDelay = sendStatus.BatchSendDelay + 0.02 -- milliseconds

					local doneThisBatch = 0
					for j = sendStatus.Index, #sendStatus.Nodes do

						local sendableNode = {}
						for k,v in pairs(sendStatus.Nodes[j]) do
							if ((k == 'Next' or k == 'Previous') and type(v) == 'table') then
								sendableNode[k] = v.ID
							else
								sendableNode[k] = v
							end
						end

						NetEvents:SendToLocal('ClientNodeEditor:Create', sendStatus.Player, sendableNode)
						doneThisBatch = doneThisBatch + 1
						sendStatus.Index = j+1
						if (doneThisBatch >= 30) then
							break
						end
					end
					if (sendStatus.Index >= #sendStatus.Nodes) then
						self:Print('Finished sending waypoints to %s', sendStatus.Player.name)

						table.remove(self.playersReceivingNodes, i)
						NetEvents:SendToLocal('ClientNodeEditor:Init', sendStatus.Player)
						break
					end
				end
			end
			if (#self.playersReceivingNodes < 1) then
				self.batchSendTimer = -1
			end
		end
	end
end

-- load waypoints from sql
function NodeEditor:onLevelLoaded(p_LevelName, p_GameMode)
	self:Print('Level Load: %s %s', p_LevelName, p_GameMode)

	g_NodeCollection:Load(p_LevelName, p_GameMode)

	local counter = 0
	local waypoints = g_NodeCollection:Get()
	for i=1, #waypoints do

		local waypoint = waypoints[i]
		if (type(waypoint.Next) == 'string') then
			counter = counter+1
		end
		if (type(waypoint.Previous) == 'string') then
			counter = counter+1
		end
	end
	self:Print('Load -> Stale Nodes: %d', counter)
end

function NodeEditor:_onUIRequestSaveSettings(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if (Config.SettingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(p_Player.accountGuid) ~= true) then
		return
	end

	local request = json.decode(p_Data)

	if (request.debugTracePaths) then
		-- enabled, send them a fresh list
		self:_onRequestNodes(p_Player)
	else
		-- disabled, delete the client's list
		NetEvents:SendToLocal('NodeEditor:Clear', p_Player)
		NetEvents:SendToLocal('NodeEditor:ClientInit', p_Player)
	end
end

if (g_NodeEditor == nil) then
	g_NodeEditor = NodeEditor()
end

return g_NodeEditor
