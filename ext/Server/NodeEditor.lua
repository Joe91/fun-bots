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
	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)
	Events:Subscribe('Level:Destroy', self, self._onLevelDestroy)
	Events:Subscribe('Engine:Update', self, self._onEngineUpdate)
	Events:Subscribe('Player:Destroyed', self, self._onPlayerDestroyed)
	Events:Subscribe('Player:Left', self, self._onPlayerLeft)

	NetEvents:Subscribe('NodeEditor:SetBotVision', self, self._onSetBotVision)
	Events:Subscribe('Player:Respawn', self, self._onPlayerRespawn)
	Events:Subscribe('Player:Killed', self, self._onPlayerKilled)
end

function NodeEditor:_onPlayerKilled(player, inflictor, position, weapon, isRoadKill, isHeadShot, wasVictimInReviveState, info)
    if (player ~= nil and self.botVision[player.name] ~= nil) then
    	self.botVision[player.name] = {
			Player = player,
			Current = 0,
			Delay = 0,
			Speed = 0.25,
			State = false
		}
    end
end

function NodeEditor:_onPlayerRespawn(player)
	if (self.botVision[player.name] ~= nil) then
		self.botVision[player.name] = {
			Player = player,
			Current = 0,
			Delay = 1,
			Speed = 0.25,
			State = true
		}
	end
end

function NodeEditor:_onPlayerDestroyed(player)
	self:_stopSendingNodes(player)
end

function NodeEditor:_onPlayerLeft(player)
	self:_stopSendingNodes(player)
end

function NodeEditor:_onLevelDestroy(args)
	g_NodeCollection:Clear(args)
	g_NodeCollection:DeregisterEvents()
end

-- player has requested node collection to be sent
function NodeEditor:_onRequestNodes(player)
	print('NodeEditor:_onRequestNodes: '..tostring(player.name))
	-- tell client to clear their list and how many to expect
	NetEvents:SendToLocal('ClientNodeEditor:ReceivingNodes', player, #g_NodeCollection:Get())
end

-- player has indicated they are ready to receive nodes
function NodeEditor:_onSendNodes(player)
	local nodes = g_NodeCollection:Get()
	table.insert(self.playersReceivingNodes, {Player = player, Index = 1, Nodes = nodes, BatchSendDelay = 0})
	self.batchSendTimer = 0
	print('Sending '..tostring(#nodes)..' waypoints to '..player.name)
end

function NodeEditor:_stopSendingNodes(player)
	for i = 1, #self.playersReceivingNodes do
		if (self.playersReceivingNodes[i].Player.name == player.name) then
			table.remove(self.playersReceivingNodes, i)
			break
		end
	end
end

-- player has indicated they are ready to send nodes to the server
function NodeEditor:_onReceiveNodes(player, nodeCount)

	if (Config.settingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(player.accountGuid) ~= true) then
		print(player.name .. ' has no permissions for Waypoint-Editor.')
		return
	end

	g_NodeCollection:Clear()
	self.playerSendingNodes = player
	self.nodeReceiveTimer = 0
	print('Receiving '..tostring(nodeCount)..' waypoints from '..player.name)
end

-- player is sending a single node over
function NodeEditor:_onCreate(player, data)

	if (Config.settingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(player.accountGuid) ~= true) then
		print(player.name .. ' has no permissions for Waypoint-Editor.')
		return
	end

	g_NodeCollection:Create(data)
end

-- node payload has finished sending, setup events and calc indexes
function NodeEditor:_onInit(player, save)

	if (Config.settingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(player.accountGuid) ~= true) then
		print(player.name .. ' has no permissions for Waypoint-Editor.')
		return
	end

	g_NodeCollection:RecalculateIndexes()

	local staleNodes = 0
	local nodesToCheck = g_NodeCollection:Get()
	print('NodeEditor:_onInit -> Nodes received: '..tostring(#nodesToCheck))
	for i=1, #nodesToCheck do

		local waypoint = nodesToCheck[i]
		if (type(waypoint.Next) == 'string') then
			staleNodes = staleNodes+1
		end
		if (type(waypoint.Previous) == 'string') then
			staleNodes = staleNodes+1
		end
	end
	print('NodeEditor:_onInit -> Stale Nodes: '..tostring(staleNodes))

	if (save) then
		g_NodeCollection:Save()
	end
end

function NodeEditor:_onWarpTo(player, vec3Position)

	if (player == nil or not player.alive or player.soldier == nil or not player.soldier.isAlive) then
		print('Player invalid!')
		return
	end

	print('Teleporting '..player.name..': '..tostring(vec3Position))
	player.soldier:SetPosition(vec3Position)
end

function NodeEditor:_onSetBotVision(player, enabled)
	print('NodeEditor:_onSetBotVision ['..player.name..']: '..tostring(enabled))
	if (enabled) then
		self.botVision[player.name] = {
			Player = player,
			Current = 0,
			Delay = 1,
			Speed = 1,
			State = enabled
		}
	else
		player:Fade(1, false)
		self.botVision[player.name] = nil
	end
end

function NodeEditor:_onEngineUpdate(deltaTime, simulationDeltaTime)

	if (#self.botVision > 0) then
		for playerName, timeData in pairs(self.botVision) do
			if (type(timeData) == 'table') then
				timeData.Current = timeData.Current + deltaTime

				if (timeData.Current >= timeData.Delay) then
					timeData.Player:Fade(timeData.Speed, timeData.State)
					self.botVision[playerName] = true
				end
			end
		end
	end

	-- receiving nodes from player takes priority over sending
	if (self.nodeReceiveTimer >= 0 and self.playerSendingNodes ~= nil) then
		self.nodeReceiveTimer = self.nodeReceiveTimer + deltaTime

		if (self.nodeReceiveTimer >= self.nodeReceiveDelay) then
			NetEvents:SendToLocal('ClientNodeEditor:SendNodes', self.playerSendingNodes, #g_NodeCollection:Get())
			self.nodeReceiveTimer = -1
		end
	else

		-- only do sending if not receiving
		if (self.batchSendTimer >= 0 and #self.playersReceivingNodes > 0) then
			self.batchSendTimer = self.batchSendTimer + deltaTime

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
						print('Finished sending waypoints to '..sendStatus.Player.name)
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
function NodeEditor:_onLevelLoaded(levelName, gameMode)
	print('NodeEditor:_onLevelLoaded -> '.. levelName..', '..gameMode)
	g_NodeCollection:Load(levelName, gameMode)

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
	print('NodeEditor:_onLevelLoaded -> Stale Nodes: '..tostring(counter))
end

function NodeEditor:_onUIRequestSaveSettings(player, data)
	if Config.disableUserInterface == true then
		return
	end

	if (Config.settingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(player.accountGuid) ~= true) then
		return;
	end

	local request = json.decode(data);

	if (request.debugTracePaths) then
		-- enabled, send them a fresh list
		self:_onRequestNodes(player)
	else
		-- disabled, delete the client's list
		NetEvents:SendToLocal('NodeEditor:Clear', player)
		NetEvents:SendToLocal('NodeEditor:ClientInit', player)
	end
end

if (g_NodeEditor == nil) then
	g_NodeEditor = NodeEditor()
end

return g_NodeEditor