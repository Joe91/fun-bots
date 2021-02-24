class "ClientNodeEditor"

require('__shared/Config');
require('__shared/NodeCollection')

function ClientNodeEditor:__init()
	-- caching values for drawing performance
	self.player = nil
	self.playerPos = nil

	self.enabled = Config.debugTracePaths
	self.disableUserInterface = Config.disableUserInterface
	self.commoRoseEnabled = false

	self.nodeReceiveTimer = -1
	self.nodeReceiveProgress = 0
	self.nodeReceiveDelay = 1
	self.nodeReceiveExpected = 0

	self.nodesToSend = {}
	self.nodeSendTimer = -1
	self.nodeSendProgress = 1
	self.nodeSendDelay = 0.02

	self.editMode = 'none' -- 'move', 'linkprevious', 'linknext', 'none'
	self.editStartPos = nil
	self.nodeStartPos = {}
	self.editModeManualOffset = Vec3.zero
	self.editModeManualSpeed = 0.05
	self.editPositionMode = 'relative'
	self.helpTextLocation = Vec2.zero

	self.botSelectedWaypoints = {}

	self.colors = {
		["Text"] = Vec4(1,1,1,1),
		["White"] = Vec4(1,1,1,1),
		["Red"] = Vec4(1,0,0,1),
		["Green"] = Vec4(0,1,0,1),
		["Blue"] = Vec4(0,0,1,1),
		["Purple"] = Vec4(0.5,0,1,1),
		["Ray"] = {Node = Vec4(1,1,1,0.2), Line = {Vec4(1,1,1,1),Vec4(0,0,0,1)}},
		["Orphan"] = {Node = Vec4(0,0,0,0.5), Line = Vec4(0,0,0,1)},
		{Node = Vec4(1,0,0,0.25), Line = Vec4(1,0,0,1)},
		{Node = Vec4(1,0.55,0,0.25), Line = Vec4(1,0.55,0,1)},
		{Node = Vec4(1,1,0,0.25), Line = Vec4(1,1,0,1)},
		{Node = Vec4(0,0.5,0,0.25), Line = Vec4(0,0.5,0,1)},
		{Node = Vec4(0,0,1,0.25), Line = Vec4(0,0,1,1)},
		{Node = Vec4(0.29,0,0.51,0.25), Line = Vec4(0.29,0,0.51,1)},
		{Node = Vec4(1,0,1,0.25), Line = Vec4(1,0,1,1)},
		{Node = Vec4(0.55,0,0,0.25), Line = Vec4(0.55,0,0,1)},
		{Node = Vec4(1,0.65,0,0.25), Line = Vec4(1,0.65,0,1)},
		{Node = Vec4(0.94,0.9,0.55,0.25), Line = Vec4(0.94,0.9,0.55,1)},
		{Node = Vec4(0.5,1,0,0.25), Line = Vec4(0.5,1,0,1)},
		{Node = Vec4(0.39,0.58,0.93,0.25), Line = Vec4(0.39,0.58,0.93,1)},
		{Node = Vec4(0.86,0.44,0.58,0.25), Line = Vec4(0.86,0.44,0.58,1)},
		{Node = Vec4(0.93,0.51,0.93,0.25), Line = Vec4(0.93,0.51,0.93,1)},
		{Node = Vec4(1,0.63,0.48,0.25), Line = Vec4(1,0.63,0.48,1)},
		{Node = Vec4(0.5,0.5,0,0.25), Line = Vec4(0.5,0.5,0,1)},
		{Node = Vec4(0,0.98,0.6,0.25), Line = Vec4(0,0.98,0.6,1)},
		{Node = Vec4(0.18,0.31,0.31,0.25), Line = Vec4(0.18,0.31,0.31,1)},
		{Node = Vec4(0,1,1,0.25), Line = Vec4(0,1,1,1)},
		{Node = Vec4(1,0.08,0.58,0.25), Line = Vec4(1,0.08,0.58,1)},
	}

	self.CommoRose = {
		Pressed = false,
		Active = false,
		LastAction = ''
	}

	self.lastTraceSearchAreaPos = nil
	self.lastTraceSearchAreaSize = nil
	self.lastTraceStart = nil
	self.lastTraceEnd = nil

	self.botVisionEnabled = false
	self.botVisionPlayers = {}
	self.botVistionCrosshair = nil

	self.debugEntries = {}
	self.pushScreenHook = nil

	-- ('UI_ClientNodeEditor_Enabled', <Bool|Enabled>)
	NetEvents:Subscribe('UI_ClientNodeEditor_Enabled', self, self._onSetEnabled)

	-- listens to UI settings for changes
	NetEvents:Subscribe('UI_Settings', self, self._onUISettings)


	self:RegisterEvents()
end

function ClientNodeEditor:RegisterEvents()

	-- simple check to make sure we don't reregister things if they are already done
	if (self.pushScreenHook ~= nil) then return end

	-- enable/disable events
	-- ('UI_CommoRose_Enabled', <Bool|Enabled>) -- true == block the BF3 commo rose
	NetEvents:Subscribe('UI_CommoRose_Enabled', self, self._onSetCommoRoseEnabled)

	-- selection-based events, no arguments required
	NetEvents:Subscribe('UI_CommoRose_Action_Save', self, self._onSaveNodes)
	NetEvents:Subscribe('UI_CommoRose_Action_Select', self, self._onSelectNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Load', self, self._onLoadNodes)

	-- Commo Rose left buttons
	NetEvents:Subscribe('UI_CommoRose_Action_Delete', self, self._onRemoveNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Disconnect', self, self._onDisconnectNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Merge', self, self._onMergeNode)
	NetEvents:Subscribe('UI_CommoRose_Action_SelectPrevious', self, self._onSelectPrevious)
	NetEvents:Subscribe('UI_CommoRose_Action_ClearSelections', self, self._onClearSelection)
	NetEvents:Subscribe('UI_CommoRose_Action_Move', self, self._onToggleMoveNode)

	-- Commor Rose right buttons
	NetEvents:Subscribe('UI_CommoRose_Action_Create', self, self._onCreateNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Connect', self, self._onConnectNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Split', self, self._onSplitNode)
	NetEvents:Subscribe('UI_CommoRose_Action_SelectNext', self, self._onSelectNext)
	NetEvents:Subscribe('UI_CommoRose_Action_SelectBetween', self, self._onSelectBetween)
	NetEvents:Subscribe('UI_CommoRose_Action_SetInput', self, self._onSetInputNode)

	-- must provide arguments
	-- ('UI_ClientNodeEditor_Trace_Show', <Int|PathIndex>)
	NetEvents:Subscribe('UI_ClientNodeEditor_Trace_Show', self, self._onShowPath)
	-- ('UI_ClientNodeEditor_Trace_Hide', <Int|PathIndex>)
	NetEvents:Subscribe('UI_ClientNodeEditor_Trace_Hide', self, self._onHidePath)

	-- debug stuff
	NetEvents:Subscribe('ClientNodeEditor:SetLastTraceSearchArea', self, self._onSetLastTraceSearchArea)
	NetEvents:Subscribe('ClientNodeEditor:BotSelect', self, self._onBotSelect)

	-- sever->client and client->server syncing events
	NetEvents:Subscribe('ClientNodeEditor:ReceiveNodes', self, self._onGetNodes)
	NetEvents:Subscribe('ClientNodeEditor:SendNodes', self, self._onSendNodes)
	NetEvents:Subscribe('ClientNodeEditor:Create', self, self._onServerCreateNode)
	NetEvents:Subscribe('ClientNodeEditor:Init', self, self._onInit)

	-- load/destroy events
	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)
	Events:Subscribe('Player:Deleted', self, self._onPlayerDeleted)
	Events:Subscribe('Level:Destroy', self, self._onUnload)

	-- keypresses
	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput)
	-- node send/receiver logic
	Events:Subscribe('UpdateManager:Update', self, self._onUpdateManagerUpdate)
	-- math for draw event
	Events:Subscribe('Engine:Update', self, self._onEngineUpdate)
	-- draw nodes and info
	Events:Subscribe('UI:DrawHud', self, self._onUIDrawHud)

	self.pushScreenHook = Hooks:Install('UI:PushScreen', 100, self, self._onUIPushScreen)

	-- UI Commands as Console commands

	Console:Register('Save', 'Send waypoints to server for saving to file', self, self._onSaveNodes)
	Console:Register('Select', 'Select or Deselect the waypoint you are looking at', self, self._onSelectNode)
	Console:Register('Load', 'Resend all waypoints and lose all changes', self, self._onGetNodes)

	Console:Register('Delete', 'Remove selected waypoints', self, self._onRemoveNode)
	Console:Register('Disconnect', 'Unlink two waypoints', self, self._onDisconnectNode)
	Console:Register('Merge', 'Merge selected waypoints', self, self._onMergeNode)
	Console:Register('SelectPrevious', 'Extend selection to previous waypoint', self, self._onSelectPrevious)
	Console:Register('ClearSelection', 'Clear selection', self, self._onClearSelection)
	Console:Register('Move', 'toggle move mode on selected waypoints', self, self._onToggleMoveNode)

	Console:Register('Create', 'Create a new waypoint after the selected one', self, self._onCreateNode)
	Console:Register('Connect', 'Link two waypoints', self, self._onConnectNode)
	Console:Register('Split', 'Split selected waypoints', self, self._onSplitNode)
	Console:Register('SelectNext', 'Extend selection to next waypoint', self, self._onSelectNext)
	Console:Register('SelectBetween', 'Select all waypoint between start and end of selection', self, self._onSelectBetween)
	Console:Register('SetInput', '<number|0-15> <number|0-15> <number|0-255> - Sets input variables for the selected waypoints', self, self._onSetInputNode)

	Console:Register('TraceShow', '\'all\' or <number|PathIndex> - Show trace\'s waypoints', self, self._onShowPath)
	Console:Register('TraceHide', '\'all\' or <number|PathIndex> - Hide trace\'s waypoints', self, self._onHidePath)
	Console:Register('WarpTo', '*<string|WaypointID>* Teleport yourself to the specified Waypoint ID', self, self._onWarpTo)
	Console:Register('SpawnAtWaypoint', '', self, self._onSpawnAtWaypoint)

	-- debugging commands, not meant for UI
	Console:Register('Enabled', 'Enable / Disable the waypoint editor', self, self._onSetEnabled)
	Console:Register('CommoRoseEnabled', 'Enable / Disable the waypoint editor Commo Rose', self, self._onSetCommoRoseEnabled)
	Console:Register('SetMetadata', '<string|Data> - Set Metadata for waypoint, Must be valid JSON string', self, self._onSetMetadata)
	Console:Register('AddObjective', '<string|Objective> - Add an objective to a path', self, self._onAddObjective)
	Console:Register('RemoveObjective', '<string|Objective> - Remove an objective from a path', self, self._onRemoveObjective)
	Console:Register('ProcessMetadata', 'Process waypoint metadata starting with selected nodes or all nodes', self, self._onProcessMetadata)
	Console:Register('RecalculateIndexes', 'Recalculate Indexes starting with selected nodes or all nodes', self, self._onRecalculateIndexes)
	Console:Register('ShowRose', 'Show custom Commo Rose', self, self._onShowRose)
	Console:Register('HideRose', 'Hide custom Commo Rose', self, self._onHideRose)
	Console:Register('DumpNodes', 'Print selected nodes or all nodes to console', self, self._onDumpNodes)
	Console:Register('UnloadNodes', 'Clears and unloads all clientside nodes', self, self._onUnload)

	Console:Register('BotVision', '*<boolean|Enabled>* Lets you see what the bots see [Experimental]', self, self._onSetBotVision)
end

-- used when the UI is disabled
function ClientNodeEditor:DeregisterEvents()
	NetEvents:Unsubscribe('ClientNodeEditor:SetLastTraceSearchArea')
	NetEvents:Unsubscribe('ClientNodeEditor:BotSelect')
	NetEvents:Unsubscribe('ClientNodeEditor:ReceiveNodes')
	NetEvents:Unsubscribe('ClientNodeEditor:SendNodes')
	NetEvents:Unsubscribe('ClientNodeEditor:Create')
	NetEvents:Unsubscribe('ClientNodeEditor:Init')

	NetEvents:Unsubscribe('UI_CommoRose_Action_Save')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Select')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Load')

	NetEvents:Unsubscribe('UI_CommoRose_Action_Delete')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Disconnect')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Merge')
	NetEvents:Unsubscribe('UI_CommoRose_Action_SelectPrevious')
	NetEvents:Unsubscribe('UI_CommoRose_Action_ClearSelections')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Move')

	NetEvents:Unsubscribe('UI_CommoRose_Action_Create')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Connect')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Split')
	NetEvents:Unsubscribe('UI_CommoRose_Action_SelectNext')
	NetEvents:Unsubscribe('UI_CommoRose_Action_SelectBetween')
	NetEvents:Unsubscribe('UI_CommoRose_Action_SetInput')

	Events:Unsubscribe('Player:Deleted')
	Events:Unsubscribe('Level:Destroy')

	Events:Unsubscribe('Client:UpdateInput')
	Events:Unsubscribe('UpdateManager:Update')
	Events:Unsubscribe('Engine:Update')
	Events:Unsubscribe('UI:DrawHud')

	--if (self.pushScreenHook ~= nil) then
		--self.pushScreenHook:Uninstall()
		--self.pushScreenHook = nil
	--end

	Console:Deregister('Save')
	Console:Deregister('Select')
	Console:Deregister('Load')

	Console:Deregister('Delete')
	Console:Deregister('Disconnect')
	Console:Deregister('Merge')
	Console:Deregister('SelectPrevious')
	Console:Deregister('ClearSelection')
	Console:Deregister('Move')

	Console:Deregister('Create')
	Console:Deregister('Connect')
	Console:Deregister('Split')
	Console:Deregister('SelectNext')
	Console:Deregister('SetInput')

	Console:Deregister('TraceShow')
	Console:Deregister('TraceHide')
	Console:Deregister('WarpTo')
	Console:Deregister('SpawnAtWaypoint')

	Console:Deregister('Enabled')
	Console:Deregister('CommoRoseEnabled')
	Console:Deregister('SetMetadata')
	Console:Deregister('AddObjective')
	Console:Deregister('RemoveObjective')
	Console:Deregister('ProcessMetadata')
	Console:Deregister('RecalculateIndexes')
	Console:Deregister('ShowRose')
	Console:Deregister('HideRose')
	Console:Deregister('DumpNodes')
	Console:Deregister('UnloadNodes')

	Console:Deregister('BotVision')
end

function ClientNodeEditor:_onSetEnabled(args)

	local enabled = args
	if (type(args) == 'table') then
		enabled = args[1]
	end

	enabled = (enabled == true or enabled == 'true' or enabled == '1')

	if (self.enabled ~= enabled) then
		self.enabled = enabled
		Config.debugTracePaths = enabled
		if (self.enabled) then
			self:_onUnload() -- clear local copy
			self.nodeReceiveTimer = 0 -- enable the timer for receiving nodes
		else
			self:_onUnload()
		end
	end
end

function ClientNodeEditor:_onSetCommoRoseEnabled(data)

	local enabled = args
	if (type(args) == 'table') then
		enabled = args[1]
	end

	enabled = (enabled == true or enabled == 'true' or enabled == '1')

	self.commoRoseEnabled = enabled
end

function ClientNodeEditor:_onUISettings(data)
	if (data == false) then -- client closed settings

		self:_onSetEnabled(Config.debugTracePaths)

		if (self.disableUserInterface ~= Config.disableUserInterface) then
			self.disableUserInterface = Config.disableUserInterface
			if (self.disableUserInterface) then
				self:DeregisterEvents()
			else
				self:RegisterEvents()
			end
		end

		self.helpTextLocation = Vec2.zero
	end
end

-- ########### commo rose top / middle / bottom
-- ############################################

function ClientNodeEditor:_onSaveNodes(args)
	self.CommoRose.Active = false
	if (self.nodeSendTimer == -1) then
		NetEvents:Send('NodeEditor:ReceivingNodes', #g_NodeCollection:Get())
		return true
	end
	print('Saving in progress, please wait...')
	return false
end

function ClientNodeEditor:_onSelectNode(args)
	self.CommoRose.Active = false
	self:_onCommoRoseAction('Select')
end

function ClientNodeEditor:_onLoadNodes(args)
	self.CommoRose.Active = false
	if (self.nodeReceiveTimer == -1) then
		self:_onGetNodes()
		return true
	end
	print('Loading in progress, please wait...')
	return false
end

-- ####################### commo rose left side
-- ############################################

function ClientNodeEditor:_onRemoveNode(args)
	self.CommoRose.Active = false
	g_NodeCollection:Remove()
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onDisconnectNode()
	self.CommoRose.Active = false
	local result, message = g_NodeCollection:Disconnect()
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onMergeNode(args)
	self.CommoRose.Active = false
	local result, message = g_NodeCollection:MergeSelection()
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onSelectPrevious()
	print('ClientNodeEditor:_onSelectPrevious')
	local selection = g_NodeCollection:GetSelected()
	if (#selection < 1) then
		print('Must select at least one node')
	end

	if (selection[1].Previous ~= false) then
		g_NodeCollection:Select(selection[1].Previous)
	end
end

function ClientNodeEditor:_onClearSelection(args)
	g_NodeCollection:ClearSelection()
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onToggleMoveNode(args)
	print('ClientNodeEditor:_onToggleMoveNode: '..tostring(args))
	self.CommoRose.Active = false

	if (self.editMode == 'move') then
		self.editMode = 'none'
		self.editRayHitStart = nil
		self.editModeManualOffset = Vec3.zero

		-- move was cancelled
		if (args ~= nil and args == true) then
			local selection = g_NodeCollection:GetSelected()
			for i=1, #selection do
				g_NodeCollection:Update(selection[i], {
					Position = self.editNodeStartPos[selection[i].ID]
				})
			end
		end

		print(Language:I18N('Exiting Node Move Mode'))
		return true
	else
		if (self.player ~= nil and self.player.soldier ~= nil) then
			
			local selection = g_NodeCollection:GetSelected()
			if (#selection < 1) then
				print(Language:I18N('Must select at least one waypoint'))
				return false
			end

			self.editNodeStartPos = {}
			for i=1, #selection do
				self.editNodeStartPos[i] = selection[i].Position:Clone()
				self.editNodeStartPos[selection[i].ID] = selection[i].Position:Clone()
			end

			self.editMode = 'move'
			self.editModeManualOffset = Vec3.zero
			print(Language:I18N('Entering Node Move Mode'))
			return true

		else
			print(Language:I18N('Player not alive'))
			return false
		end
	end

	print(Language:I18N('Not Implemented Yet'))
	return false
end

-- ###################### commo rose right side
-- ############################################

function ClientNodeEditor:_onCreateNode(args)
	self.CommoRose.Active = false

	print('ClientNodeEditor:_onCreateNode')
	
	local result, message = g_NodeCollection:CreateAfter()

	if (result ~= nil) then
		g_NodeCollection:ClearSelection()
		g_NodeCollection:Select(result)
		self.editPositionMode = 'absolute'
		self:_onToggleMoveNode()
	end

	print(Language:I18N(message))
	return result ~= nil
end

function ClientNodeEditor:_onConnectNode()
	self.CommoRose.Active = false
	local result, message = g_NodeCollection:Connect()
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onSplitNode(args)
	self.CommoRose.Active = false
	local result, message = g_NodeCollection:SplitSelection()
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onSelectNext()
	print('ClientNodeEditor:_onSelectNext')
	local selection = g_NodeCollection:GetSelected()
	if (#selection < 1) then
		print('Must select at least one waypoint')
	end

	if (selection[#selection].Next ~= false) then
		g_NodeCollection:Select(selection[#selection].Next)
	end
end

function ClientNodeEditor:_onSelectBetween()
	print('ClientNodeEditor:_onSelectBetween')
	local selection = g_NodeCollection:GetSelected()
	if (#selection < 1) then
		print('Must select more than one')
	end

	local breakAt = (#g_NodeCollection:Get())
	local current = 0
	local currentWaypoint = selection[1]
	while currentWaypoint.Next and currentWaypoint.ID ~= selection[#selection].ID do
		g_NodeCollection:Select(currentWaypoint)
		current = current + 1
		if (current > breakAt) then
			break
		end
		currentWaypoint = currentWaypoint.Next
	end
end

function ClientNodeEditor:_onSetInputNode(args)
	self.CommoRose.Active = false
	print('ClientNodeEditor:_onSetInputNode: '..g_NodeCollection:SetInput(args[1], args[2], args[3]))
	print(Language:I18N('Success'))
	return true
end

-- ############################## Other Methods
-- ############################################


function ClientNodeEditor:_onShowPath(args)

	local pathIndex = args
	if (type(args) == 'table') then
		pathIndex = args[1]
	end

	if (pathIndex == nil) then
		print('Use `all` or *<number|PathIndex>*')
		return false
	end

	if (pathIndex:lower() == 'all') then
		for pathID, waypoints in pairs(g_NodeCollection:GetPaths()) do
			g_NodeCollection:ShowPath(pathID)
		end
		print(Language:I18N('Success'))
		return true
	end

	if (tonumber(pathIndex) ~= nil) then
		g_NodeCollection:ShowPath(tonumber(pathIndex))
		print(Language:I18N('Success'))
		return true
	end
	print('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onHidePath(args)

	local pathIndex = args
	if (type(args) == 'table') then
		pathIndex = args[1]
	end

	if (pathIndex == nil) then
		print('Use `all` or *<number|PathIndex>*')
		return false
	end

	if (pathIndex:lower() == 'all') then
		for pathID, waypoints in pairs(g_NodeCollection:GetPaths()) do
			g_NodeCollection:HidePath(pathID)
		end
		print(Language:I18N('Success'))
		return true
	end

	if (tonumber(pathIndex) ~= nil) then
		g_NodeCollection:HidePath(tonumber(pathIndex))
		print(Language:I18N('Success'))
		return true
	end
	print('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onWarpTo(args)
	if (args == nil or #args == 0) then
		print('Must provide Waypoint ID')
		return false
	end
	local waypoint = g_NodeCollection:Get(args[1])

	if (waypoint == nil) then
		print('Waypoint not found!')
		return false
	end

	local player = PlayerManager:GetLocalPlayer()
	if (player == nil or not player.alive or player.soldier == nil or not player.soldier.isAlive) then
		print('Player invalid!')
		return false
	end

	print('Teleporting to ['..waypoint.ID..']: '..tostring(waypoint.Position))
	NetEvents:Send('NodeEditor:WarpTo', waypoint.Position)
end

function ClientNodeEditor:_onSpawnAtWaypoint(args)
	if (args == nil or #args == 0) then
		print('Must provide Waypoint ID')
		return false
	end
	local waypoint = g_NodeCollection:Get(args[1])

	if (waypoint == nil) then
		print('Waypoint not found!')
		return false
	end

	NetEvents:Send('BotEditor', json.encode({
		action = 'bot_spawn_path',
		value = waypoint.PathIndex,
		pointindex = waypoint.PointIndex,
	}))
end

-- ############################## Debug Methods
-- ############################################

function ClientNodeEditor:_onSetLastTraceSearchArea(data)
	self.lastTraceSearchAreaPos = data[1]
	self.lastTraceSearchAreaSize = data[2]
end

-- NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', pathIndex, pointIndex, botPosition, color)
function ClientNodeEditor:_onBotSelect(pathIndex, pointIndex, botPosition, isObstacleMode, color)
	local waypoint = g_NodeCollection:Get(pointIndex, pathIndex)
	if (waypoint ~= nil) then
		self.botSelectedWaypoints[waypoint.ID] = {
			Timer = 1,
			Position = botPosition,
			Obstacle = isObstacleMode,
			Color = (color or 'White')
		}
	end
end

function ClientNodeEditor:_onShowRose(args)
	self:_onCommoRoseAction('Show')
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onHideRose(args)
	self:_onCommoRoseAction('Hide')
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onDumpNodes(args)

	local selection = g_NodeCollection:GetSelected()

	if (#selection < 1) then
		selection = g_NodeCollection:Get()
	end

	for i=1, #selection do
		print(g_Utilities:dump(selection[i], true, 1))
	end
	print('Dumped ['..tostring(#selection)..'] Nodes!')
	return true
end

function ClientNodeEditor:_onSetMetadata(args)
	self.CommoRose.Active = false

	local data = table.concat(args or {}, ' ')
	print('ClientNodeEditor:_onSetMetadata -> data: '..g_Utilities:dump(data, true))

	local result, message = g_NodeCollection:UpdateMetadata(data)
	if (result ~= false) then
		g_NodeCollection:ProcessMetadata(result)
	end
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onAddObjective(args)
	self.CommoRose.Active = false

	local data = table.concat(args or {}, ' ')
	print('ClientNodeEditor:AddObjective -> data: '..g_Utilities:dump(data, true))

	local selection = g_NodeCollection:GetSelected()
	local donePaths = {}

	if (#selection > 0) then
		for i=1, #selection do

			local waypoint = g_NodeCollection:GetFirst(selection[i].PathIndex)

			if (not donePaths[waypoint.PathIndex]) then
				donePaths[waypoint.PathIndex] = true

				local objectives = waypoint.Data.Objectives or {}
				local inTable = false

				for i=1, #objectives do
					if (objectives[i] == data) then
						inTable = true
						break
					end
				end

				if (not inTable) then
					table.insert(objectives, data)
					waypoint.Data.Objectives = objectives
					print(Language:I18N('Success')..' ['..waypoint.PathIndex..']')
				else
					print(Language:I18N('Path already has objective: ')..'['..waypoint.PathIndex..'] -> '..data)
				end
			end
		end
	else
		print(Language:I18N('Must select at least one node'))
		return false
	end
	return true
end

function ClientNodeEditor:_onRemoveObjective(args)
	self.CommoRose.Active = false

	local data = table.concat(args or {}, ' ')
	print('ClientNodeEditor:RemoveObjective -> data: '..g_Utilities:dump(data, true))

	local selection = g_NodeCollection:GetSelected()
	local donePaths = {}
	if (#selection > 0) then
		for i=1, #selection do
			local waypoint = g_NodeCollection:GetFirst(selection[i].PathIndex)

			if (not donePaths[waypoint.PathIndex]) then
				donePaths[waypoint.PathIndex] = true

				local objectives = waypoint.Data.Objectives or {}
				local newObjectives = {}

				for i=1, #objectives do
					if (objectives[i] ~= data) then
						table.insert(newObjectives, objectives[i])
					end
				end

				waypoint.Data.Objectives = newObjectives
				print(Language:I18N('Success')..' ['..waypoint.PathIndex..']')
			end
		end
		return true
	else
		print(Language:I18N('Must select at least one node'))
		return false
	end
end

function ClientNodeEditor:_onRecalculateIndexes(args)

	local selection = g_NodeCollection:GetSelected()
	local firstnode = nil

	if (#selection > 0) then
		firstnode = selection[1]
	end
	g_NodeCollection:RecalculateIndexes(firstnode)
	return true
end

function ClientNodeEditor:_onProcessMetadata(args)

	local selection = g_NodeCollection:GetSelected()
	local firstnode = nil

	if (#selection > 0) then
		firstnode = selection[1]
	end
	g_NodeCollection:ProcessMetadata(firstnode)
	return true
end

function ClientNodeEditor:_onSetBotVision(args)
	self.botVisionEnabled = (args ~= nil and (args[1] == '1' or args[1] == 'true'))
	print('ClientNodeEditor:_onSetBotVision: '..tostring(self.botVisionEnabled))
	NetEvents:Send('NodeEditor:SetBotVision', self.botVisionEnabled)
	if (self.botVisionEnabled) then
		-- unload our current cache
		self:_onUnload(args)
		-- enable the timer before we are ready to receive
		self.nodeReceiveTimer = 0
	end
end

-- ##################################### Events
-- ############################################

function ClientNodeEditor:_onLevelLoaded(levelName, gameMode)
	self.enabled = Config.debugTracePaths
	if (self.enabled) then
		self.nodeReceiveTimer = 0 -- enable the timer for receiving nodes
	end
end

function ClientNodeEditor:_onPlayerDeleted(player)
	if (self.player ~= nil and player ~= nil and self.player.name == player.name) then
		self:_onUnload()
	end
end

function ClientNodeEditor:_onUnload(args)
	self.player = nil
	self.nodeReceiveProgress = 0
	self.nodeReceiveExpected = 0
	if (args ~= nil) then
		if (type(args) == 'table') then
			self.nodeReceiveExpected = tonumber(args[1]) or 0
		else
			self.nodeReceiveExpected = tonumber(args) or 0
		end
	end
	print('NodeCollection:Clear -> Expecting: '..g_Utilities:dump(args))
	g_NodeCollection:Clear()
	g_NodeCollection:DeregisterEvents()
end

function ClientNodeEditor:_onCommoRoseAction(action, hit)
	print('CommoRoseAction: '..tostring(action))

	if (action == 'Show') then
		--self.CommoRose.Active = true

		local center = { Action = 'UI_CommoRose_Action_Select', Label = Language:I18N('Select') }

		if (self.editMode == 'move') then
			center = { Action = 'UI_CommoRose_Action_Move', Label = Language:I18N('Finish') }
		elseif (self.editMode == 'link') then
			center = { Action = 'UI_CommoRose_Action_Connect', Label = Language:I18N('Connect') }
		end

		g_FunBotUIClient:_onUICommonRose({
			Top = { Action = 'UI_CommoRose_Action_Save', Label = Language:I18N('Save') },
			Bottom = { Action = 'UI_CommoRose_Action_Load', Label = Language:I18N('Load') },
			Center = center,
			Left = {
				{ Action = 'UI_CommoRose_Action_Delete', Label = Language:I18N('Delete') },
				{ Action = 'UI_CommoRose_Action_Merge', Label = Language:I18N('Merge') },
				{ Action = 'UI_CommoRose_Action_SelectPrevious', Label = Language:I18N('Select Previous') },
				{ Action = 'UI_CommoRose_Action_ClearSelection', Label = Language:I18N('Clear Selection') },
				{ Action = 'UI_CommoRose_Action_Move', Label = Language:I18N('Move') },
			},
			Right = {
				{ Action = 'UI_CommoRose_Action_Create', Label = Language:I18N('Create') },
				{ Action = 'UI_CommoRose_Action_Split', Label = Language:I18N('Split') },
				{ Action = 'UI_CommoRose_Action_SelectNext', Label = Language:I18N('Select Next') },
				{ Action = 'UI_CommoRose_Action_SelectBetween', Label = Language:I18N('Select Between') },
				{ Action = 'UI_CommoRose_Action_SetInput', Label = Language:I18N('Set Input') },
			}
		})
		return
	end

	if (action == 'Select') then

		local hit = self:Raycast()
		if (hit == nil) then
			return
		end
	    local hitPoint = g_NodeCollection:Find(hit.position)

		-- nothing found at hit location, try a raytracing check
		if (hitPoint == nil and self.player ~= nil and self.player ~= nil) then
			local playerCamPos = self.player.soldier.worldTransform.trans + self.player.input.authoritativeCameraPosition
			hitPoint = g_NodeCollection:FindAlongTrace(playerCamPos, hit.position)
			self.lastTraceStart = playerCamPos
			self.lastTraceEnd = hit.position
		end

		-- we found one, let's toggle its selected state
		if (hitPoint ~= nil) then 
			local isSelected = g_NodeCollection:IsSelected(hitPoint)

			if (isSelected) then 
				g_NodeCollection:Deselect(hitPoint)
				return
			else
				g_NodeCollection:Select(hitPoint)
				return
			end
		end
	end
end

function ClientNodeEditor:_onUIPushScreen(hook, screen, priority, parentGraph, stateNodeGuid)
	if (self.enabled) then
		if (self.commoRoseEnabled and screen ~= nil and UIScreenAsset(screen).name == 'UI/Flow/Screen/CommRoseScreen') then
			-- triggered vanilla commo rose and ours should be active
			-- block it
			hook:Return() 
		end
	end
	hook:Pass(screen, priority, parentGraph, stateNodeGuid)
end

-- ############################## Update Events
-- ############################################

function ClientNodeEditor:_onUpdateInput(player, delta)
	if (not self.enabled) then
		return
	end

	local Comm1 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu1) > 0
	local Comm2 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu2) > 0
	local Comm3 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu3) > 0

	-- pressed and released without triggering commo rose
	if (self.CommoRose.Pressed and not self.CommoRose.Active and not (Comm1 or Comm2 or Comm3)) then
		if (self.editMode == 'move') then
			self:_onToggleMoveNode()
		else
			self:_onCommoRoseAction('Select')
		end
	end

	self.CommoRose.Pressed = (Comm1 or Comm2 or Comm3)

	if (self.editMode == 'move') then

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowLeft) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad4) then
			self.editModeManualOffset = self.editModeManualOffset + (Vec3.left * self.editModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowRight) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad6) then
			self.editModeManualOffset = self.editModeManualOffset - (Vec3.left * self.editModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowUp) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad8) then
			self.editModeManualOffset = self.editModeManualOffset + (Vec3.forward * self.editModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowDown) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad2) then
			self.editModeManualOffset = self.editModeManualOffset - (Vec3.forward * self.editModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageUp) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad9) then
			self.editModeManualOffset = self.editModeManualOffset + (Vec3.up * self.editModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageDown) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad3) then
			self.editModeManualOffset = self.editModeManualOffset - (Vec3.up * self.editModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Equals) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Add) then
			self.editModeManualSpeed = math.min(self.editModeManualSpeed + 0.05, 1)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Minus) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Subtract) then
			self.editModeManualSpeed = math.max(self.editModeManualSpeed - 0.05, 0.05)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad7) then
			self.editModeManualOffset = Vec3.zero
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad1) then
			if (self.editPositionMode == 'absolute') then
				self.editPositionMode = 'relative'
			elseif (self.editPositionMode == 'relative') then
				self.editPositionMode = 'standing'
			else
				self.editPositionMode = 'absolute'
			end
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Backspace) then
			self:_onToggleMoveNode(true)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad5) then
			self:_onToggleMoveNode()
			return
		end

	elseif (self.editMode == 'none') then

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad8) then
			self:_onSaveNodes()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad5) then
			self:_onSelectNode()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad2) then
			self:_onLoadNodes()
			return
		end


		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad7) then
			self:_onMergeNode()
			return
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad4) then
			self:_onToggleMoveNode()
			return
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad1) then
			self:_onRemoveNode()
			return
		end


		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad9) then
			self:_onSplitNode()
			return
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad6) then
			self:_onSetInputNode()
			return
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad3) then
			self:_onCreateNode()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Backspace) then
			g_NodeCollection:ClearSelection()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Insert) then
			local selection = g_NodeCollection:GetSelected()
			if (#selection > 0) then
				NetEvents:Send('BotEditor', json.encode({
					action = 'bot_spawn_path',
					value = selection[1].PathIndex,
					pointindex = selection[1].PointIndex,
				}))
			end
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Equals) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Add) then
			self:_onConnectNode()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Minus) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Subtract) then
			self:_onDisconnectNode()
			return
		end
	end
end

function ClientNodeEditor:_onEngineUpdate(delta, simDelta)
	if (self.nodeSendTimer >= 0 and #self.nodesToSend > 0) then

		self.debugEntries['nodeSendProgress'] = self.nodeSendProgress..'/'..(#self.nodesToSend)
		self.nodeSendTimer = self.nodeSendTimer + delta

		if (self.nodeSendTimer > self.nodeSendDelay) then

			local doneThisBatch = 0
			for i=self.nodeSendProgress, #self.nodesToSend do

				local sendableNode = {}
				for k,v in pairs(self.nodesToSend[i]) do
					if ((k == 'Next' or k == 'Previous') and type(v) == 'table') then
						sendableNode[k] = v.ID
					else
						sendableNode[k] = v
					end
				end

				NetEvents:Send('NodeEditor:Create', sendableNode)
				doneThisBatch = doneThisBatch + 1
				self.nodeSendProgress = i+1
				if (doneThisBatch >= 30) then
					break
				end
			end

			if (self.nodeSendProgress >= #self.nodesToSend) then
				print('Finished sending waypoints to server')
				self.nodesToSend = {}
				self.nodeSendTimer = -1
				self.nodeSendProgress = 1
				NetEvents:Send('NodeEditor:Init', true)
			end
		end
	end

	if (self.nodeReceiveTimer >= 0) then
		self.nodeReceiveTimer = self.nodeReceiveTimer + delta

		-- timer for receiving node payload
		if (self.nodeReceiveTimer > self.nodeReceiveDelay) then
			print('NodeEditor:SendNodes')
			NetEvents:Send('NodeEditor:SendNodes')
			self.nodeReceiveTimer = -1
		end
	end

	local botwpcount = 0
	for waypointID, data in pairs(self.botSelectedWaypoints) do
		if (data.Timer < 0) then
			self.botSelectedWaypoints[waypointID] = nil
		else
			data.Timer = data.Timer - delta
			botwpcount = botwpcount + 1
		end
	end

	self.debugEntries['botSelectedWaypoints'] = botwpcount
end

function ClientNodeEditor:_onUpdateManagerUpdate(delta, pass)

	-- Only do math on presimulation UpdatePass, don't bother if debugging is off
	if not self.enabled or pass ~= UpdatePass.UpdatePass_PreSim then
		return
	end

	if (self.helpTextLocation == Vec2.zero) then
		local windowSize = ClientUtils:GetWindowSize()
		-- fun fact, debugtext is 8x15 pixels
		self.helpTextLocation = Vec2(windowSize.x - 256, math.floor(windowSize.y / 2.0 + 0.5) - 195)
	end

	-- doing this here and not in UI:DrawHud prevents a memory leak that crashes you in under a minute
	if (self.player ~= nil and self.player.alive and self.player.soldier ~= nil and self.player.soldier.alive and self.player.soldier.worldTransform ~= nil) then
		self.playerPos = self.player.soldier.worldTransform.trans

		if (self.editMode == 'move') then
			local selection = g_NodeCollection:GetSelected()
			if (#selection > 0) then
				--raycast to 4 meters
				local hit = self:Raycast(4)
				if (hit ~= nil) then
					if (self.editRayHitStart == nil) then
						self.editRayHitStart = hit.position
						self.editRayHitCurrent = hit.position
						self.editRayHitRelative = Vec3.zero
					else 
						self.editRayHitCurrent = hit.position
						self.editRayHitRelative = self.editRayHitCurrent - self.editRayHitStart
					end
				end
			end
		end

		-- draw the actual waypoints
		local nodePaths = g_NodeCollection:GetPaths()
		for path=1, #nodePaths do

			if (g_NodeCollection:IsPathVisible(path)) then

				local pathWaypoints = nodePaths[path]

				for i=1, #pathWaypoints do

	    			if (self.editMode == 'move') then
						if (g_NodeCollection:IsSelected(pathWaypoints[i])) then

							local adjustedPosition = self.editNodeStartPos[pathWaypoints[i].ID] + self.editModeManualOffset
							if (self.editPositionMode == 'relative') then
								adjustedPosition = adjustedPosition + (self.editRayHitRelative or Vec3.zero)
							elseif (self.editPositionMode == 'standing') then
								adjustedPosition = self.playerPos + self.editModeManualOffset
							else
								adjustedPosition = self.editRayHitCurrent + self.editModeManualOffset
							end 

							g_NodeCollection:Update(pathWaypoints[i], {
								Position = adjustedPosition
							})
						end
					end

	    			-- precalc the distances for less overhead on the hud draw
	    			--pathWaypoints[i].Distance = self.playerPos:Distance(pathWaypoints[i].Position)
	    		end
    		end
    	end

    	if (self.botVisionEnabled) then

    		-- bot vision crosshair lines, generate once only
    		if (self.botVistionCrosshair == nil) then
    			local windowSize = ClientUtils:GetWindowSize()
				local cx = math.floor(windowSize.x / 2.0 + 0.5)
				local cy = math.floor(windowSize.y / 2.0 + 0.5)

				self.botVistionCrosshair = {
					Vec2(cx - 9, cy - 1),	Vec2(cx + 8, cy - 1),
					Vec2(cx - 10, cy),		Vec2(cx + 9, cy),
					Vec2(cx - 9, cy + 1),	Vec2(cx + 8, cy + 1),

					Vec2(cx - 1, cy - 9),	Vec2(cx - 1, cy + 8),
					Vec2(cx,	 cy - 10),	Vec2(cx,	 cy + 9),
					Vec2(cx + 1, cy - 9),	Vec2(cx + 1, cy + 8)
				}
    		end

    		-- check vision from player to "enemies", only update position if visible
    		local players = PlayerManager:GetPlayers()
    		for p=1, #players do
    			if (players[p].soldier ~= nil and self.player.teamId ~= players[p].teamId) then

    				local ray = RaycastManager:Raycast(self.playerPos+Vec3.up, (players[p].soldier.worldTransform.trans+Vec3.up), RayCastFlags.CheckDetailMesh | RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)
    				
					local posData = {
						Visible = (ray == nil or ray.rigidBody == nil),
						Alive = players[p].soldier.alive
					}

					if (posData.Visible) then
						posData.Position = players[p].soldier.worldTransform.trans
					end

					self.botVisionPlayers[players[p].name] = posData
    			end
    		end
    	end
    end
end

function ClientNodeEditor:_onUIDrawHud()

	if (self.botVisionEnabled) then

		if(self.botVistionCrosshair ~= nil) then
			-- all this for a simple + in the middle of the screen
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[1],	self.botVistionCrosshair[2],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[3],	self.botVistionCrosshair[4],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[5],	self.botVistionCrosshair[6],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[7],	self.botVistionCrosshair[8],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[9],	self.botVistionCrosshair[10],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[11],	self.botVistionCrosshair[12],	self.colors.Text)
		end

		for k,v in pairs(self.botVisionPlayers) do
			if (v ~= nil and v ~= false and v.Position ~= nil) then
				local screenPos = ClientUtils:WorldToScreen(v.Position + (Vec3.up * 0.3))

				if (screenPos ~= nil) then
					DebugRenderer:DrawText2D(screenPos.x, screenPos.y, k, self.colors.Text, 1)
					screenPos = nil
				end

				local color = self.colors.Text
				
				if (not v.Alive) then
					color = self.colors[1].Line
				else
					if (v.Visible) then
						color = self.colors[4].Line
					end
				end

				DebugRenderer:DrawSphere(v.Position+(Vec3.up*1.5), 0.15, color, false, false)
				DebugRenderer:DrawSphere(v.Position+(Vec3.up*1.0), 0.3, color, false, false)
				DebugRenderer:DrawSphere(v.Position+(Vec3.up*0.3), 0.2, color, false, false)
			end
		end
	end

	-- dont process waypoints if we're not supposed to see them
	if (not self.enabled) then
		return
	end

	-- generic debug values
	local debugText = ''

	for k,v in pairs(self.debugEntries) do
		debugText = debugText .. k..': '..tostring(v).."\n"
	end

	--DebugRenderer:DrawText2D(20, 20, debugText, self.colors.Text, 1)
	

	-- draw help info
	local helpText = ''
	if (self.editMode == 'none') then

		helpText = helpText..' Node Operation Controls '.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   7   |   8   |   9   |'.."\n"
		helpText = helpText..'| Merge | Send  | Split |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   4   |   5   |   6   |'.."\n"
		helpText = helpText..'| Move  |Select | Input |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   1   |   2   |   3   |'.."\n"
		helpText = helpText..'|Remove | Load  |Create |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'                         '.."\n"
		helpText = helpText..'        F12 - Settings    '.."\n"
		helpText = helpText..'     [Spot] - Quick Select'.."\n"
		helpText = helpText..'[Backspace] - Clear Select'.."\n"
		helpText = helpText..'   [Insert] - Spawn Bot   '.."\n"
		helpText = helpText..' [Numpad +] - Link Node  '.."\n"
		helpText = helpText..' [Numpad -] - Unlink Node'.."\n"

	elseif (self.editMode == 'move') then

		helpText = helpText..'  Nudge Position Controls '.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   7   |   8   |   9   |'.."\n"
		helpText = helpText..'| Reset |Forward|  Up   |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   4   |   5   |   6   |'.."\n"
		helpText = helpText..'| Left  |Finish | Right |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   1   |   2   |   3   |'.."\n"
		helpText = helpText..'| Mode  | Back  | Down  |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..string.format('|X %+04.2f | Y %+04.2f|', self.editModeManualOffset.x, self.editModeManualOffset.y).."\n"
		helpText = helpText..string.format('|      Z %+04.2f       |', self.editModeManualOffset.z).."\n"
		helpText = helpText..'+-----------------------+'.."\n"
		helpText = helpText..' Nudge Speed: '..tostring(self.editModeManualSpeed).."\n"
		if (self.editPositionMode == 'relative') then
		helpText = helpText..'   Move Mode: Relative   '.."\n"
		elseif (self.editPositionMode == 'standing') then
		helpText = helpText..'   Move Mode: Standing   '.."\n"
		else
		helpText = helpText..'   Move Mode: Absolute   '.."\n"
		end
		helpText = helpText..'                         '.."\n"
		helpText = helpText..'        F12 - Settings    '.."\n"
		helpText = helpText..'     [Spot] - Finish Move '.."\n"
		helpText = helpText..'[Backspace] - Cancel Move '.."\n"
		helpText = helpText..' [Numpad +] - Nudge Speed +'.."\n"
		helpText = helpText..' [Numpad -] - Nudge Speed -'.."\n"
	end

	--DebugRenderer:DrawText2D(self.helpTextLocation.x, self.helpTextLocation.y, helpText, self.colors.Text, 1)

	-- draw debug selection traces
	if (self.debugSelectionRaytraces) then
		if (self.lastTraceStart ~= nil and self.lastTraceEnd ~= nil) then
			DebugRenderer:DrawLine(self.lastTraceStart, self.lastTraceEnd, self.colors.Ray.Line[1], self.colors.Ray.Line[2])
		end
		if (self.lastTraceSearchAreaPos ~= nil and self.lastTraceSearchAreaSize ~= nil) then
			DebugRenderer:DrawSphere(self.lastTraceSearchAreaPos, self.lastTraceSearchAreaSize, self.colors.Ray.Node, false, false)
		end
	end

	if (self.playerPos == nil) then
		return
	end

	-- draw the actual waypoints
	local nodePaths = g_NodeCollection:GetPaths()
	for path=1, #nodePaths do

		if (g_NodeCollection:IsPathVisible(path)) then

			local pathWaypoints = nodePaths[path]

			for node=1, #pathWaypoints do
				local waypoint = pathWaypoints[node]
				local isSelected = g_NodeCollection:IsSelected(waypoint)
				local qualityAtRange = g_NodeCollection:InRange(waypoint, self.playerPos, Config.lineRange)


				-- setup node color information
				local color = self.colors[waypoint.PathIndex]
				if (waypoint.Previous == false and waypoint.Next == false) then
					color = self.colors.Orphan
				end

				-- draw the node for the waypoint itself
				if (g_NodeCollection:InRange(waypoint, self.playerPos, Config.waypointRange)) then
					DebugRenderer:DrawSphere(waypoint.Position, 0.05, color.Node, false, (not qualityAtRange))
				end

				-- if bot has selected draw it
				if (self.botSelectedWaypoints[waypoint.ID] ~= nil) then
					local selectData = self.botSelectedWaypoints[waypoint.ID]
					if (selectData.Obstacle) then
						DebugRenderer:DrawLine(selectData.Position + (Vec3.up * 1.2), waypoint.Position, self.colors.Red, self.colors.Red)
					else
						DebugRenderer:DrawLine(selectData.Position + (Vec3.up * 1.2), waypoint.Position, self.colors[selectData.Color], self.colors[selectData.Color])
					end
				end

				-- if selected draw bigger node and transform helper
				if (isSelected and g_NodeCollection:InRange(waypoint, self.playerPos, Config.waypointRange)) then
					-- node selection indicator
					DebugRenderer:DrawSphere(waypoint.Position, 0.08,  color.Node, false, (not qualityAtRange))

					-- transform marker
					DebugRenderer:DrawLine(waypoint.Position, waypoint.Position + (Vec3.up * 0.7), self.colors.Red, self.colors.Red)
					DebugRenderer:DrawLine(waypoint.Position, waypoint.Position + (Vec3.right * 0.5), self.colors.Green, self.colors.Green)
					DebugRenderer:DrawLine(waypoint.Position, waypoint.Position + (Vec3.forward * 0.5), self.colors.Blue, self.colors.Blue)
				end

				-- draw connection lines
				if (Config.drawWaypointLines and g_NodeCollection:InRange(waypoint, self.playerPos, Config.lineRange)) then
					-- try to find a previous node and draw a line to it
					if (waypoint.Previous and type(waypoint.Previous) == 'string') then
						waypoint.Previous = g_NodeCollection:Get(waypoint.Previous)
					end

					if (waypoint.Previous) then
						if (waypoint.PathIndex ~= waypoint.Previous.PathIndex) then
							-- draw a white line between nodes on separate paths
							DebugRenderer:DrawLine(waypoint.Previous.Position, waypoint.Position, self.colors.White, self.colors.White)
						else
							-- draw fading line between nodes on same path
							DebugRenderer:DrawLine(waypoint.Previous.Position, waypoint.Position, color.Line, color.Line)
						end
					end
					if (waypoint.Data and waypoint.Data.LinkMode ~= nil and waypoint.Data.Links ~= nil) then
						for i=1, #waypoint.Data.Links do
							local linkedWaypoint = g_NodeCollection:Get(waypoint.Data.Links[i])
							if (linkedWaypoint ~= nil) then
								-- draw lines between linked nodes
								DebugRenderer:DrawLine(linkedWaypoint.Position, waypoint.Position, self.colors.Purple, self.colors.Purple)
							end
						end
					end
				end

				-- draw debugging text
				if (Config.drawWaypointIDs and g_NodeCollection:InRange(waypoint, self.playerPos, Config.textRange)) then
					if (isSelected) then
						-- don't try to precalc this value like with the distance, another memory leak crash awaits you
						local screenPos = ClientUtils:WorldToScreen(waypoint.Position + (Vec3.up * 0.7))
						if (screenPos ~= nil) then

							local previousNode = tostring(waypoint.Previous)
							local nextNode = tostring(waypoint.Next)
							if (type(waypoint.Previous) == 'table') then
								previousNode = waypoint.Previous.ID
							end
							if (type(waypoint.Next) == 'table') then
								nextNode = waypoint.Next.ID
							end

							local speedMode = 'N/A'
							if (waypoint.SpeedMode == 0) then speedMode = 'Wait' end
							if (waypoint.SpeedMode == 1) then speedMode = 'Prone' end
							if (waypoint.SpeedMode == 2) then speedMode = 'Crouch' end
							if (waypoint.SpeedMode == 3) then speedMode = 'Walk' end
							if (waypoint.SpeedMode == 4) then speedMode = 'Sprint' end

							local extraMode = 'N/A'
							if (waypoint.ExtraMode == 1) then extraMode = 'Jump' end

							local optionValue = 'N/A'
							if (waypoint.SpeedMode == 0) then 
								optionValue = tostring(waypoint.OptValue)..' Seconds'
							end
							if (not waypoint.Previous or (waypoint.Previous and waypoint.Previous.PathIndex ~= waypoint.PathIndex)) then
								if (waypoint.OptValue == 255) then
									optionValue = 'Path Reverses'
								else
									optionValue = 'Path Loops'
								end
							end

							local text = ''
							text = text..string.format("%s <--[ %s ]--> %s\n", previousNode, waypoint.ID, nextNode)
							text = text..string.format("Index[%d]\n", waypoint.Index)
							text = text..string.format("Path[%d][%d]\n", waypoint.PathIndex, waypoint.PointIndex)
							text = text..string.format("InputVar: %d\n", waypoint.InputVar)
							text = text..string.format("SpeedMode: %s (%d)\n", speedMode, waypoint.SpeedMode)
							text = text..string.format("ExtraMode: %s (%d)\n", extraMode, waypoint.ExtraMode)
							text = text..string.format("OptValue: %s (%d)\n", optionValue, waypoint.OptValue)
							text = text..'Data: '..g_Utilities:dump(waypoint.Data, true)

							DebugRenderer:DrawText2D(screenPos.x, screenPos.y, text, self.colors.Text, 1.2)
						end
						screenPos = nil
					else
						-- don't try to precalc this value like with the distance, another memory leak crash awaits you
						local screenPos = ClientUtils:WorldToScreen(waypoint.Position + (Vec3.up * 0.05))
						if (screenPos ~= nil) then
							DebugRenderer:DrawText2D(screenPos.x, screenPos.y, tostring(waypoint.ID), self.colors.Text, 1)
							screenPos = nil
						end
					end
				end
			end
		end
	end
end

-- ################# Node sending and retrieval
-- ############################################

-- request a fresh node list from the server
-- or server has told us be ready to receive
function ClientNodeEditor:_onGetNodes(args)
	print('ClientNodeEditor:_onGetNodes: '..tostring(args))
	-- unload our current cache
	self:_onUnload(args)
	-- enable the timer before we are ready to receive
	self.nodeReceiveTimer = 0
	return true
end

-- server is ready to receive our nodes
function ClientNodeEditor:_onSendNodes(args)

	self.nodesToSend = g_NodeCollection:Get()

	print('ClientNodeEditor:_onSendNodes: '..tostring(#self.nodesToSend))
	if (self.nodesToSend ~= nil and #self.nodesToSend > 0) then
		self.nodeSendTimer = 0
	else
		print('ClientNodeEditor:_onSendNodes: Client has 0 Nodes, Cancelling Send!')
	end
end

function ClientNodeEditor:_onServerCreateNode(data)
	g_NodeCollection:Create(data)
	self.nodeReceiveProgress = self.nodeReceiveProgress + 1
	self.debugEntries['nodeReceiveProgress'] = self.nodeReceiveProgress..'/'..(self.nodeReceiveExpected)
end

-- node payload has finished sending, setup events and calc indexes
function ClientNodeEditor:_onInit()
	g_NodeCollection:RegisterEvents()
	g_NodeCollection:RecalculateIndexes()
	g_NodeCollection:ProcessMetadata()

	local waypoints = g_NodeCollection:Get()
	self.player = PlayerManager:GetLocalPlayer()

	local staleNodes = 0
	print('ClientNodeEditor:_onInit -> Nodes received: '..tostring(#waypoints))
	for i=1, #waypoints do

		local waypoint = waypoints[i]
		if (type(waypoint.Next) == 'string') then
			staleNodes = staleNodes+1
		end
		if (type(waypoint.Previous) == 'string') then
			staleNodes = staleNodes+1
		end
	end
	print('ClientNodeEditor:_onInit -> Stale Nodes: '..tostring(staleNodes))
end

-- stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
function ClientNodeEditor:Raycast(maxDistance, useAsync)
	if self.player == nil then
		return
	end
	maxDistance = maxDistance or 100

	-- We get the camera transform, from which we will start the raycast. We get the direction from the forward vector. Camera transform
	-- is inverted, so we have to invert this vector.
	local transform = ClientUtils:GetCameraTransform()
	local direction = Vec3(-transform.forward.x, -transform.forward.y, -transform.forward.z)

	if transform.trans == Vec3.zero then
		return
	end

	local castStart = transform.trans

	-- We get the raycast end transform with the calculated direction and the max distance.
	local castEnd = Vec3(
		transform.trans.x + (direction.x * maxDistance),
		transform.trans.y + (direction.y * maxDistance),
		transform.trans.z + (direction.z * maxDistance))

	-- Perform raycast, returns a RayCastHit object.

	local flags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh
	if (useAsync) then
		flags = flags | RayCastFlags.IsAsyncRaycast
	end

	local raycastHit = RaycastManager:Raycast(castStart, castEnd, flags)

	return raycastHit	
end

if (g_ClientNodeEditor == nil) then
	g_ClientNodeEditor = ClientNodeEditor()
end

return g_ClientNodeEditor