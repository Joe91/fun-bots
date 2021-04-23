class "ClientNodeEditor"

require('__shared/Config')
require('__shared/NodeCollection')

function ClientNodeEditor:__init()
	-- caching values for drawing performance
	self.player = nil
	self.playerPos = nil

	self.enabled = Config.DebugTracePaths
	self.disableUserInterface = Config.DisableUserInterface

	self.commoRoseEnabled = false
	self.commoRosePressed = false
	self.commoRoseActive = false
	self.commoRoseTimer = -1
	self.commoRoseDelay = 0.25

	self.nodeReceiveTimer = -1
	self.nodeReceiveProgress = 0
	self.nodeReceiveDelay = 1
	self.nodeReceiveExpected = 0

	self.nodesToSend = {}
	self.nodeSendTimer = -1
	self.nodeSendProgress = 1
	self.nodeSendDelay = 0.02

	self.editMode = 'none' -- 'move', 'none'
	self.editStartPos = nil
	self.nodeStartPos = {}
	self.editModeManualOffset = Vec3.zero
	self.editModeManualSpeed = 0.05
	self.editPositionMode = 'relative'
	self.helpTextLocation = Vec2.zero

	self.customTrace = nil
	self.customTraceIndex = nil
	self.customTraceTimer = -1
	self.customTraceDelay = Config.TraceDelta
	self.customTraceDistance = 0
	self.customTraceSaving = false

	self.nodeOperation = ''

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

	self.lastTraceSearchAreaPos = nil
	self.lastTraceSearchAreaSize = nil
	self.lastTraceStart = nil
	self.lastTraceEnd = nil

	self.botVisionEnabled = false
	self.botVisionPlayers = {}
	self.botVistionCrosshair = nil

	self.debugEntries = {}
	self.pushScreenHook = nil
	self.eventsReady = false

	-- ('UI_ClientNodeEditor_Enabled', <Bool|Enabled>)
	NetEvents:Subscribe('UI_ClientNodeEditor_Enabled', self, self._onSetEnabled)

	-- listens to UI settings for changes
	NetEvents:Subscribe('UI_Settings', self, self._onUISettings)

	self:RegisterEvents()
end

function ClientNodeEditor:RegisterEvents()

	-- simple check to make sure we don't reregister things if they are already done
	if self.eventsReady then return end

	-- enable/disable events
	-- ('UI_CommoRose_Enabled', <Bool|Enabled>) -- true == block the BF3 commo rose
	NetEvents:Subscribe('UI_CommoRose_Enabled', self, self._onSetCommoRoseEnabled)

	-- selection-based events, no arguments required
	NetEvents:Subscribe('UI_CommoRose_Action_Save', self, self._onSaveNodes)
	NetEvents:Subscribe('UI_CommoRose_Action_Select', self, self._onSelectNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Load', self, self._onLoadNodes)

	-- Commo Rose left buttons
	NetEvents:Subscribe('UI_CommoRose_Action_Remove', self, self._onRemoveNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Unlink', self, self._onUnlinkNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Merge', self, self._onMergeNode)
	NetEvents:Subscribe('UI_CommoRose_Action_SelectPrevious', self, self._onSelectPrevious)
	NetEvents:Subscribe('UI_CommoRose_Action_ClearSelections', self, self._onClearSelection)
	NetEvents:Subscribe('UI_CommoRose_Action_Move', self, self._onToggleMoveNode)

	-- Commor Rose right buttons
	NetEvents:Subscribe('UI_CommoRose_Action_Add', self, self._onAddNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Link', self, self._onLinkNode)
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
	NetEvents:Subscribe('ClientNodeEditor:SaveNodes', self, self._onSaveNodes)
	NetEvents:Subscribe('ClientNodeEditor:ReceiveNodes', self, self._onGetNodes)
	NetEvents:Subscribe('ClientNodeEditor:SendNodes', self, self._onSendNodes)
	NetEvents:Subscribe('ClientNodeEditor:Create', self, self._onServerCreateNode)
	NetEvents:Subscribe('ClientNodeEditor:Init', self, self._onInit)

	-- trace recording events
	NetEvents:Subscribe('ClientNodeEditor:StartTrace', self, self._onStartTrace)
	NetEvents:Subscribe('ClientNodeEditor:EndTrace', self, self._onEndTrace)
	NetEvents:Subscribe('ClientNodeEditor:ClearTrace', self, self._onClearTrace)
	NetEvents:Subscribe('ClientNodeEditor:SaveTrace', self, self._onSaveTrace)

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

	self.pushScreenHook = Hooks:Install('UI:PushScreen', 1, self, self._onUIPushScreen)

	-- UI Commands as Console commands

	Console:Register('Save', 'Send waypoints to server for saving to file', self, self._onSaveNodes)
	Console:Register('Select', 'Select or Deselect the waypoint you are looking at', self, self._onSelectNode)
	Console:Register('Load', 'Resend all waypoints and lose all changes', self, self._onGetNodes)

	Console:Register('Remove', 'Remove selected waypoints', self, self._onRemoveNode)
	Console:Register('Unlink', 'Unlink two waypoints', self, self._onUnlinkNode)
	Console:Register('Merge', 'Merge selected waypoints', self, self._onMergeNode)
	Console:Register('SelectPrevious', 'Extend selection to previous waypoint', self, self._onSelectPrevious)
	Console:Register('ClearSelection', 'Clear selection', self, self._onClearSelection)
	Console:Register('Move', 'toggle move mode on selected waypoints', self, self._onToggleMoveNode)

	Console:Register('Add', 'Create a new waypoint after the selected one', self, self._onAddNode)
	Console:Register('Link', 'Link two waypoints', self, self._onLinkNode)
	Console:Register('Split', 'Split selected waypoints', self, self._onSplitNode)
	Console:Register('SelectNext', 'Extend selection to next waypoint', self, self._onSelectNext)
	Console:Register('SelectBetween', 'Select all waypoint between start and end of selection', self, self._onSelectBetween)
	Console:Register('SetInput', '<number|0-15> <number|0-15> <number|0-255> - Sets input variables for the selected waypoints', self, self._onSetInputNode)

	Console:Register('TraceShow', '\'all\' or <number|PathIndex> - Show trace\'s waypoints', self, self._onShowPath)
	Console:Register('TraceHide', '\'all\' or <number|PathIndex> - Hide trace\'s waypoints', self, self._onHidePath)
	Console:Register('WarpTo', '*<string|WaypointID>* Teleport yourself to the specified Waypoint ID', self, self._onWarpTo)
	Console:Register('SpawnAtWaypoint', '', self, self._onSpawnAtWaypoint)

	Console:Register('StartTrace', 'Begin recording a new trace', self, self._onStartTrace)
	Console:Register('EndTrace', 'Stop recording a new trace', self, self._onEndTrace)
	Console:Register('ClearTrace', 'Clear all nodes from recorded trace', self, self._onClearTrace)
	Console:Register('SaveTrace', '<number|PathIndex> Merge new trace with current waypoints', self, self._onSaveTrace)

	-- debugging commands, not meant for UI
	Console:Register('Enabled', 'Enable / Disable the waypoint editor', self, self._onSetEnabled)
	Console:Register('CommoRoseEnabled', 'Enable / Disable the waypoint editor Commo Rose', self, self._onSetCommoRoseEnabled)
	Console:Register('CommoRoseShow', 'Show custom Commo Rose', self, self._onShowRose)
	Console:Register('CommoRoseHide', 'Hide custom Commo Rose', self, self._onHideRose)
	Console:Register('SetMetadata', '<string|Data> - Set Metadata for waypoint, Must be valid JSON string', self, self._onSetMetadata)
	Console:Register('AddObjective', '<string|Objective> - Add an objective to a path', self, self._onAddObjective)
	Console:Register('AddMcom', 'Add an MCOM Arm/Disarm-Action to a point', self, self._onAddMcom)
	Console:Register('AddVehicle', 'Add a vehicle a bot can use', self, self._onAddVehicle)
	Console:Register('RemoveObjective', '<string|Objective> - Remove an objective from a path', self, self._onRemoveObjective)
	Console:Register('ProcessMetadata', 'Process waypoint metadata starting with selected nodes or all nodes', self, self._onProcessMetadata)
	Console:Register('RecalculateIndexes', 'Recalculate Indexes starting with selected nodes or all nodes', self, self._onRecalculateIndexes)
	Console:Register('DumpNodes', 'Print selected nodes or all nodes to console', self, self._onDumpNodes)
	Console:Register('UnloadNodes', 'Clears and unloads all clientside nodes', self, self._onUnload)

	Console:Register('ObjectiveDirection', 'Show best direction to given objective', self, self._onObjectiveDirection)
	Console:Register('GetKnownOjectives', 'print all known objectives and associated paths', self, self._onGetKnownOjectives)


	Console:Register('BotVision', '*<boolean|Enabled>* Lets you see what the bots see [Experimental]', self, self._onSetBotVision)

	self.eventsReady = true
	self:Print('Register Events')
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

	NetEvents:Unsubscribe('UI_CommoRose_Action_Remove')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Unlink')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Merge')
	NetEvents:Unsubscribe('UI_CommoRose_Action_SelectPrevious')
	NetEvents:Unsubscribe('UI_CommoRose_Action_ClearSelections')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Move')

	NetEvents:Unsubscribe('UI_CommoRose_Action_Add')
	NetEvents:Unsubscribe('UI_CommoRose_Action_Link')
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

	Console:Deregister('Save')
	Console:Deregister('Select')
	Console:Deregister('Load')

	Console:Deregister('Remove')
	Console:Deregister('Unlink')
	Console:Deregister('Merge')
	Console:Deregister('SelectPrevious')
	Console:Deregister('ClearSelection')
	Console:Deregister('Move')

	Console:Deregister('Add')
	Console:Deregister('Link')
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
	Console:Deregister('AddMcom')
	Console:Deregister('RemoveObjective')
	Console:Deregister('ProcessMetadata')
	Console:Deregister('RecalculateIndexes')
	Console:Deregister('ShowRose')
	Console:Deregister('HideRose')
	Console:Deregister('DumpNodes')
	Console:Deregister('UnloadNodes')

	Console:Deregister('BotVision')
	self.eventsReady = false
	self:Print('Deregister Events')
end

function ClientNodeEditor:IsSavingOrLoading()
	return (self.nodeSendTimer > -1 or self.nodeReceiveTimer > -1 or self.nodeOperation ~= '')
end

function ClientNodeEditor:Print(...)
	if Debug.Client.NODEEDITOR then
		print('ClientNodeEditor: ' .. Language:I18N(...))
	end
end

function ClientNodeEditor:_onSetEnabled(p_Args)

	local enabled = p_Args
	if (type(p_Args) == 'table') then
		enabled = p_Args[1]
	end

	enabled = (enabled == true or enabled == 'true' or enabled == '1')

	if (self.enabled ~= enabled) then
		self.enabled = enabled
		self.commoRoseEnabled = enabled

		if (self.enabled) then
			self:_onUnload() -- clear local copy
			self.nodeReceiveTimer = 0 -- enable the timer for receiving nodes
		else
			self:_onUnload()
		end
	end
end

function ClientNodeEditor:_onSetCommoRoseEnabled(p_Args)

	local enabled = p_Args
	if (type(p_Args) == 'table') then
		enabled = p_Args[1]
	end

	enabled = (enabled == true or enabled == 'true' or enabled == '1')

	self.commoRoseEnabled = enabled
end

function ClientNodeEditor:_onUISettings(p_Data)
	if (p_Data == false) then -- client closed settings

		self:_onSetEnabled(Config.DebugTracePaths)

		if (self.disableUserInterface ~= Config.DisableUserInterface) then
			self.disableUserInterface = Config.DisableUserInterface
			if (self.disableUserInterface) then
				self:DeregisterEvents()
			else
				self:RegisterEvents()
			end
		end

		self.helpTextLocation = Vec2.zero
		self.customTraceDelay = Config.TraceDelta
	end
end

-- ########### commo rose top / middle / bottom
-- ############################################

function ClientNodeEditor:_onSaveNodes(p_Args)
	self.commoRoseActive = false

	if not self:IsSavingOrLoading() then
		self:Print('Initiating Save...')
		self.nodeOperation = 'Client Save'
		NetEvents:Send('NodeEditor:ReceivingNodes', #g_NodeCollection:Get())
		return true
	end

	self:Print('Operation in progress, please wait...')
	return false
end

function ClientNodeEditor:_onSelectNode(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	self:_onCommoRoseAction('Select')
	return true
end

function ClientNodeEditor:_onLoadNodes(p_Args)
	self.commoRoseActive = false

	if not self:IsSavingOrLoading() then
		self:Print('Initiating Load...')
		self.nodeOperation = 'Client Load'
		self:_onGetNodes()
		return true
	end

	self:Print('Operation in progress, please wait...')
	return false
end

-- ####################### commo rose left side
-- ############################################

function ClientNodeEditor:_onRemoveNode(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local result, message = g_NodeCollection:Remove()
	if not result then
		self:Print(message)
	end
	return result
end

function ClientNodeEditor:_onUnlinkNode()
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local result, message = g_NodeCollection:Unlink()
	if not result then
		self:Print(message)
	end
	return result
end

function ClientNodeEditor:_onMergeNode(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local result, message = g_NodeCollection:MergeSelection()
	if not result then
		self:Print(message)
	end
	return result
end

function ClientNodeEditor:_onSelectPrevious()
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local selection = g_NodeCollection:GetSelected()
	if (#selection > 0) then
		if (selection[1].Previous ~= false) then
			g_NodeCollection:Select(selection[1].Previous)
			return true
		end
	else
		self:Print('Must select at least one node')
	end
	return false
end

function ClientNodeEditor:_onClearSelection(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	g_NodeCollection:ClearSelection()
	return true
end

function ClientNodeEditor:_onToggleMoveNode(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if (self.editMode == 'move') then
		self.editMode = 'none'
		self.editRayHitStart = nil
		self.editModeManualOffset = Vec3.zero

		-- move was cancelled
		if (p_Args ~= nil and p_Args == true) then
			self:Print('Move Cancelled')
			local selection = g_NodeCollection:GetSelected()
			for i=1, #selection do
				g_NodeCollection:Update(selection[i], {
					Position = self.editNodeStartPos[selection[i].ID]
				})
			end
		end

		g_FunBotUIClient:_onSetOperationControls({
			Numpad = {
				{Grid = 'K1', Key = '1', Name = 'Remove'},
				{Grid = 'K2', Key = '2', Name = 'Unlink'},
				{Grid = 'K3', Key = '3', Name = 'Add'},
				{Grid = 'K4', Key = '4', Name = 'Move'},
				{Grid = 'K5', Key = '5', Name = 'Select'},
				{Grid = 'K6', Key = '6', Name = 'Input'},
				{Grid = 'K7', Key = '7', Name = 'Merge'},
				{Grid = 'K8', Key = '8', Name = 'Link'},
				{Grid = 'K9', Key = '9', Name = 'Split'},
			},
			Other = {
				{Key = 'F12', Name = 'Settings'},
				{Key = 'Q', Name = 'Quick Select'},
				{Key = 'BS', Name = 'Clear Select'},
				{Key = 'INS', Name = 'Spawn Bot'},
			}
		})

		self:Print('Edit Mode: %s', self.editMode)
		return true
	else
		if (self.player == nil or self.player.soldier == nil) then
			self:Print('Player must be alive')
			return false
		end

		local selection = g_NodeCollection:GetSelected()
		if (#selection < 1) then
			self:Print('Must select at least one node')
			return false
		end

		self.editNodeStartPos = {}
		for i=1, #selection do
			self.editNodeStartPos[i] = selection[i].Position:Clone()
			self.editNodeStartPos[selection[i].ID] = selection[i].Position:Clone()
		end

		self.editMode = 'move'
		self.editModeManualOffset = Vec3.zero

		g_FunBotUIClient:_onSetOperationControls({
			Numpad = {
				{Grid = 'K1', Key = '1', Name = 'Mode'},
				{Grid = 'K2', Key = '2', Name = 'Back'},
				{Grid = 'K3', Key = '3', Name = 'Down'},
				{Grid = 'K4', Key = '4', Name = 'Left'},
				{Grid = 'K5', Key = '5', Name = 'Finish'},
				{Grid = 'K6', Key = '6', Name = 'Right'},
				{Grid = 'K7', Key = '7', Name = 'Reset'},
				{Grid = 'K8', Key = '8', Name = 'Forward'},
				{Grid = 'K9', Key = '9', Name = 'Up'},
			},
			Other = {
				{Key = 'F12', Name = 'Settings'},
				{Key = 'Q', Name = 'Finish Move'},
				{Key = 'BS', Name = 'Cancel Move'},
				{Key = 'KP_PLUS', Name = 'Speed +'},
				{Key = 'KP_MINUS', Name = 'Speed -'},
			}
		})

		self:Print('Edit Mode: %s', self.editMode)
		return true
	end
	return false
end

-- ###################### commo rose right side
-- ############################################

function ClientNodeEditor:_onAddNode(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local result, message = g_NodeCollection:Add()
	if not result then
		self:Print(message)
		return false
	end

	local selection = g_NodeCollection:GetSelected()

	-- if selected is 0 or 1, we created a new node
	-- clear selection, select new node, change to move mode
	-- otherwise we just connected two nodes, don't change selection
	if (result ~= nil and #selection <= 1) then
		g_NodeCollection:ClearSelection()
		g_NodeCollection:Select(result)
		self.editPositionMode = 'absolute'
		self:_onToggleMoveNode()
	end
	return true
end

function ClientNodeEditor:_onLinkNode()
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local result, message = g_NodeCollection:Link()
	if not result then
		self:Print(message)
	end
	return result
end

function ClientNodeEditor:_onSplitNode(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local result, message = g_NodeCollection:SplitSelection()
	if not result then
		self:Print(message)
	end
	return result
end

function ClientNodeEditor:_onSelectNext()
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local selection = g_NodeCollection:GetSelected()
	if (#selection > 0) then
		if (selection[1].Next ~= false) then
			g_NodeCollection:Select(selection[1].Next)
			return true
		end
	else
		self:Print('Must select at least one node')
	end
	return false
end

function ClientNodeEditor:_onSelectBetween()
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local selection = g_NodeCollection:GetSelected()
	if (#selection < 1) then
		self:Print('Must select more than one node')
		return false
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
	return true
end

function ClientNodeEditor:_onSetInputNode(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local result, message = g_NodeCollection:SetInput(p_Args[1], p_Args[2], p_Args[3])
	if not result then
		self:Print(message)
	end
	return result
end

-- ############################## Other Methods
-- ############################################


function ClientNodeEditor:_onShowPath(p_Args)
	self.commoRoseActive = false

	local pathIndex = p_Args
	if (type(p_Args) == 'table') then
		pathIndex = p_Args[1]
	end

	if (pathIndex ~= nil and pathIndex:lower() == 'all') then
		for pathID, waypoints in pairs(g_NodeCollection:GetPaths()) do
			g_NodeCollection:ShowPath(pathID)
		end
		return true
	end

	if (pathIndex ~= nil and tonumber(pathIndex) ~= nil) then
		g_NodeCollection:ShowPath(tonumber(pathIndex))
		return true
	end

	self:Print('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onHidePath(p_Args)
	self.commoRoseActive = false

	local pathIndex = p_Args
	if (type(p_Args) == 'table') then
		pathIndex = p_Args[1]
	end

	if (pathIndex ~= nil and pathIndex:lower() == 'all') then
		for pathID, waypoints in pairs(g_NodeCollection:GetPaths()) do
			g_NodeCollection:HidePath(pathID)
		end
		return true
	end

	if (pathIndex ~= nil and tonumber(pathIndex) ~= nil) then
		g_NodeCollection:HidePath(tonumber(pathIndex))
		return true
	end

	self:Print('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onWarpTo(p_Args)
	self.commoRoseActive = false

	if (self.player == nil or self.player.soldier == nil or not self.player.alive or not self.player.soldier.isAlive) then
		self:Print('Player must be alive')
		return false
	end

	if (p_Args == nil or #p_Args == 0) then
		self:Print('Must provide Waypoint ID')
		return false
	end

	local waypoint = g_NodeCollection:Get(p_Args[1])

	if (waypoint == nil) then
		self:Print('Waypoint not found: %s', p_Args[1])
		return false
	end

	self:Print('Teleporting to Waypoint: %s (%s)', waypoint.ID, tostring(waypoint.Position))
	NetEvents:Send('NodeEditor:WarpTo', waypoint.Position)
end

function ClientNodeEditor:_onSpawnAtWaypoint(p_Args)
	if (p_Args == nil or #p_Args == 0) then
		self:Print('Must provide Waypoint ID')
		return false
	end

	local waypoint = g_NodeCollection:Get(p_Args[1])

	if (waypoint == nil) then
		self:Print('Waypoint not found: %s', p_Args[1])
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

function ClientNodeEditor:_onSetLastTraceSearchArea(p_Data)
	self.lastTraceSearchAreaPos = p_Data[1]
	self.lastTraceSearchAreaSize = p_Data[2]
end

-- NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', pathIndex, pointIndex, botPosition, color)
function ClientNodeEditor:_onBotSelect(p_PathIndex, p_PointIndex, p_BotPosition, p_IsObstacleMode, p_Color)
	local waypoint = g_NodeCollection:Get(p_PointIndex, p_PathIndex)
	if (waypoint ~= nil) then
		self.botSelectedWaypoints[waypoint.ID] = {
			Timer = 0.5,
			Position = p_BotPosition,
			Obstacle = p_IsObstacleMode,
			Color = (p_Color or 'White')
		}
	end
end

function ClientNodeEditor:_onShowRose(p_Args)
	self.commoRoseEnabled = true
	self.commoRoseActive = true
	self:_onCommoRoseAction('Show')
	return true
end

function ClientNodeEditor:_onHideRose(p_Args)
	self.commoRoseActive = false
	self:_onCommoRoseAction('Hide')
	return true
end

function ClientNodeEditor:_onDumpNodes(p_Args)

	local selection = g_NodeCollection:GetSelected()

	if (#selection < 1) then
		selection = g_NodeCollection:Get()
	end

	for i=1, #selection do
		self:Print(g_Utilities:dump(selection[i], true, 1))
	end

	self:Print('Dumped [%d] Nodes!', #selection)
	return true
end

function ClientNodeEditor:_onSetMetadata(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local data = table.concat(p_Args or {}, ' ')
	self:Print('Set Metadata (data): %s', g_Utilities:dump(data, true))

	local result, message = g_NodeCollection:UpdateMetadata(data)
	if (result ~= false) then
		g_NodeCollection:ProcessMetadata(result)
	else
		self:Print(message)
	end
	return result
end

function ClientNodeEditor:_onAddMcom(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if (self.player == nil or self.player.soldier == nil) then
		self:Print('Player must be alive')
		return false
	end

	local selection = g_NodeCollection:GetSelected()
	if (#selection ~= 1) then
		self:Print('Must select one node')
		return false
	end

	self:Print('Updating %d Possible Waypoints', (#selection))

	for i=1, #selection do
		local action = {
			type = "mcom",
			inputs = {EntryInputActionEnum.EIAInteract},
			time = 6.0,
			yaw = self.player.input.authoritativeAimingYaw,
			pitch = self.player.input.authoritativeAimingPitch
		}
		selection[i].Data.Action = action
		self:Print('Updated Waypoint: %s', selection[i].ID)
	end
	return true
end

function ClientNodeEditor:_onAddVehicle(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if (self.player == nil or self.player.soldier == nil) then
		self:Print('Player must be alive')
		return false
	end

	local selection = g_NodeCollection:GetSelected()
	if (#selection ~= 1) then
		self:Print('Must select one node')
		return false
	end

	self:Print('Updating %d Possible Waypoints', (#selection))

	for i=1, #selection do
		local action = {
			type = "vehicle",
			inputs = {EntryInputActionEnum.EIAInteract},
			time = 0.5,
			yaw = self.player.input.authoritativeAimingYaw,
			pitch = self.player.input.authoritativeAimingPitch
		}
		selection[i].Data.Action = action
		self:Print('Updated Waypoint: %s', selection[i].ID)
	end
	return true
end

function ClientNodeEditor:_onAddObjective(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local data = table.concat(p_Args or {}, ' ')
	self:Print('Add Objective (data): %s', g_Utilities:dump(data, true))

	local selection = g_NodeCollection:GetSelected()
	if (#selection < 1) then
		self:Print('Must select at least one node')
		return false
	end

	local donePaths = {}
	self:Print('Updating %d Possible Waypoints', (#selection))

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
				self:Print('Updated Waypoint: %s', waypoint.ID)
			end
		end
	end
	return true
end

function ClientNodeEditor:_onRemoveObjective(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local data = table.concat(p_Args or {}, ' ')
	self:Print('Remove Objective (data): %s', g_Utilities:dump(data, true))

	local selection = g_NodeCollection:GetSelected()
	if (#selection < 1) then
		self:Print('Must select at least one node')
		return false
	end

	local donePaths = {}
	self:Print('Updating %d Possible Waypoints', (#selection))

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
			self:Print('Updated Waypoint: %s', waypoint.ID)
		end
	end
	return true
end

function ClientNodeEditor:_onRecalculateIndexes(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local selection = g_NodeCollection:GetSelected()
	local firstnode = nil

	if (#selection > 0) then
		firstnode = selection[1]
	end
	g_NodeCollection:RecalculateIndexes(firstnode)
	return true
end

function ClientNodeEditor:_onProcessMetadata(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local selection = g_NodeCollection:GetSelected()
	local firstnode = nil

	if (#selection > 0) then
		firstnode = selection[1]
	end
	g_NodeCollection:ProcessMetadata(firstnode)
	return true
end

function ClientNodeEditor:_onSetBotVision(p_Args)
	self.botVisionEnabled = (p_Args ~= nil and (p_Args[1] == '1' or p_Args[1] == 'true'))

	self:Print('BotVision: %s', self.botVisionEnabled)

	NetEvents:Send('NodeEditor:SetBotVision', self.botVisionEnabled)
	if (self.botVisionEnabled) then
		-- unload our current cache
		self:_onUnload(p_Args)
		-- enable the timer before we are ready to receive
		self.nodeReceiveTimer = 0
	end
end


function ClientNodeEditor:_onObjectiveDirection(p_Args)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local data = table.concat(p_Args or {}, ' ')
	self:Print('Objective Direction (data): %s', g_Utilities:dump(data, true))

	local selection = g_NodeCollection:GetSelected()
	if (#selection < 1) then
		self:Print('Must select at least one node')
		return false
	end

	local direction, bestPreviousWaypoint = g_NodeCollection:ObjectiveDirection(selection[1], data)

	self:Print('Direction: %s', direction)

	if (bestPreviousWaypoint ~= nil) then
		self:Print('Best Previous Waypoint: %s', bestPreviousWaypoint.ID)
	end
	return true
end

function ClientNodeEditor:_onGetKnownOjectives(p_Args)
	self.commoRoseActive = false
	self:Print('Known Objectives -> '..g_Utilities:dump(g_NodeCollection:GetKnownOjectives(), true))
	return true
end

-- ############################ Trace Recording
-- ############################################

function ClientNodeEditor:_getNewIndex()
	local nextIndex = 0
	local allPaths = g_NodeCollection:GetPaths()
	for pathIndex, points in pairs(allPaths) do
		if pathIndex - nextIndex > 1 then
			return nextIndex + 1 -- gap in traces
		end
		nextIndex = pathIndex
	end
	return nextIndex + 1 -- increment index
end

function ClientNodeEditor:_onStartTrace()
	if (self.customTrace ~= nil) then
		self.customTrace:Clear()
	end
	self.customTrace = NodeCollection(true)
	self.customTraceTimer = 0
	self.customTraceIndex = self:_getNewIndex()
	self.customTraceDistance = 0

	local firstWaypoint = self.customTrace:Create({
		Position = self.playerPos:Clone()
	})
	self.customTrace:ClearSelection()
	self.customTrace:Select(firstWaypoint)

	self:Print('Custom Trace Started')

	g_FunBotUIClient:_onUITrace(true)
	g_FunBotUIClient:_onUITraceIndex(self.customTraceIndex)
	g_FunBotUIClient:_onUITraceWaypoints(#self.customTrace:Get())
	g_FunBotUIClient:_onUITraceWaypointsDistance(self.customTraceDistance)
end

function ClientNodeEditor:_onEndTrace()
	self.customTraceTimer = -1
	g_FunBotUIClient:_onUITrace(false)

	local firstWaypoint = self.customTrace:GetFirst()

	if (firstWaypoint) then
		local startPos 	= firstWaypoint.Position + Vec3.up
		local endPos 	= self.customTrace:GetLast().Position + Vec3.up
		local raycast	= RaycastManager:Raycast(startPos, endPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh | RayCastFlags.IsAsyncRaycast)

		self.customTrace:ClearSelection()
		self.customTrace:Select(firstWaypoint)
		if (raycast == nil or raycast.rigidBody == nil) then
			-- clear view from start node to end node, path loops
			self.customTrace:SetInput(firstWaypoint.SpeedMode, firstWaypoint.ExtraMode, 0)
		else
			-- no clear view, path should just invert at the end
			self.customTrace:SetInput(firstWaypoint.SpeedMode, firstWaypoint.ExtraMode, 0XFF)
		end
		self.customTrace:ClearSelection()
	end

	self:Print('Custom Trace Ended')
end

function ClientNodeEditor:_onClearTrace()
	self.customTraceTimer = -1
	self.customTraceIndex = self:_getNewIndex()
	self.customTraceDistance = 0
	self.customTrace:Clear()
	g_FunBotUIClient:_onUITrace(false)
	g_FunBotUIClient:_onUITraceIndex(self.customTraceIndex)
	g_FunBotUIClient:_onUITraceWaypoints(#self.customTrace:Get())
	g_FunBotUIClient:_onUITraceWaypointsDistance(self.customTraceDistance)

	self:Print('Custom Trace Cleared')
end

function ClientNodeEditor:_onSaveTrace(p_PathIndex)
	self.commoRoseActive = false

	if self:IsSavingOrLoading() then
		self:Print('Operation in progress, please wait...')
		return false
	end

	if (type(p_PathIndex) == 'table') then
		p_PathIndex = p_PathIndex[1]
	end

	if (self.customTrace == nil) then
		self:Print('Custom Trace is empty')
		return false
	end

	self.nodeOperation = 'Custom Trace'

	local pathCount = #g_NodeCollection:GetPaths()
	p_PathIndex = tonumber(p_PathIndex) or self:_getNewIndex()
	local currentWaypoint = self.customTrace:GetFirst()
	local referrenceWaypoint = nil
	local direction = 'Next'

	if (pathCount == 0) then
		currentWaypoint.PathIndex = 1
		referrenceWaypoint = g_NodeCollection:Create(currentWaypoint)
		currentWaypoint = currentWaypoint.Next

		pathCount = #g_NodeCollection:GetPaths()
	end

	-- remove existing path and replace with current
	if (p_PathIndex == 1) then

		if (pathCount == 1) then
			referrenceWaypoint = g_NodeCollection:GetFirst()
		else
			-- get first node of 2nd path, we'll InsertBefore the new nodes
			referrenceWaypoint = g_NodeCollection:GetFirst(2)
			currentWaypoint = self.customTrace:GetLast()
			direction = 'Previous'
		end

	-- p_PathIndex is between 2 and #g_NodeCollection:GetPaths()
	-- get the node before the start of the specified path, if the path is existing
	elseif (p_PathIndex <= pathCount) then
		if #g_NodeCollection:Get(nil, p_PathIndex) > 0 then
			print("path exists")
			referrenceWaypoint = g_NodeCollection:GetFirst(p_PathIndex).Previous
		else
			referrenceWaypoint = g_NodeCollection:GetLast()
		end

	-- p_PathIndex == last path index, append all nodes to end of collection
	elseif (p_PathIndex > pathCount) then
		referrenceWaypoint = g_NodeCollection:GetLast()
	end

	-- we might have a path to delete
	if (p_PathIndex > 0 and p_PathIndex <= pathCount) then
		local pathWaypoints = g_NodeCollection:Get(nil, p_PathIndex)
		if #pathWaypoints > 0 then
			for i=1, #pathWaypoints do
				g_NodeCollection:Remove(pathWaypoints[i])
			end
		end
	end

	-- merge custom trace into main node collection
	while currentWaypoint do

		currentWaypoint.PathIndex = p_PathIndex

		local newWaypoint = g_NodeCollection:Create(currentWaypoint)

		if (direction == 'Next') then
			g_NodeCollection:InsertAfter(referrenceWaypoint, newWaypoint)
		else
			g_NodeCollection:InsertBefore(referrenceWaypoint, newWaypoint)
		end

		referrenceWaypoint = newWaypoint
		currentWaypoint = currentWaypoint[direction]
	end

	self.customTrace:Clear()
	self:Print('Custom Trace Saved to Path: %d', p_PathIndex)
	self.nodeOperation = ''
end

-- ##################################### Events
-- ############################################

function ClientNodeEditor:_onLevelLoaded(p_LevelName, p_GameMode)
	self.enabled = Config.DebugTracePaths
	if (self.enabled) then
		self.nodeReceiveTimer = 0 -- enable the timer for receiving nodes
	end
end

function ClientNodeEditor:_onPlayerDeleted(p_Player)
	if (self.player ~= nil and p_Player ~= nil and self.player.name == p_Player.name) then
		self:_onUnload()
	end
end

function ClientNodeEditor:_onUnload(p_Args)
	self.player = nil
	self.nodeReceiveProgress = 0
	self.nodeReceiveExpected = 0
	if (p_Args ~= nil) then
		if (type(p_Args) == 'table') then
			self.nodeReceiveExpected = tonumber(p_Args[1]) or 0
		else
			self.nodeReceiveExpected = tonumber(p_Args) or 0
		end
	end

	self:Print('Unload, Expecting Waypoints: %s', g_Utilities:dump(p_Args))

	g_NodeCollection:Clear()
	g_NodeCollection:DeregisterEvents()
end

function ClientNodeEditor:_onCommoRoseAction(p_Action, p_Hit)
	self:Print('Commo Rose -> %s', p_Action)

	if (p_Action == 'Hide') then
		self.commoRoseActive = false
		g_FunBotUIClient:_onUICommonRose('false')
		return
	end

	if (p_Action == 'Show') then
		self.commoRoseActive = false -- disabled for now

		local center = { Action = 'UI_CommoRose_Action_Select', Label = Language:I18N('Select') }

		if (self.editMode == 'move') then
			center = { Action = 'UI_CommoRose_Action_Move', Label = Language:I18N('Finish') }
		elseif (self.editMode == 'link') then
			center = { Action = 'UI_CommoRose_Action_Connect', Label = Language:I18N('Connect') }
		end
		--[[
		g_FunBotUIClient:_onUICommonRose({
			Top = { Action = 'UI_CommoRose_Action_ClearSelection', Label = Language:I18N('Clear Selection') },
			Bottom = { Action = 'UI_CommoRose_Action_SelectBetween', Label = Language:I18N('Select Between') },
			Center = center,
			Left = {
				{ Action = 'UI_CommoRose_Action_Remove', Label = Language:I18N('Remove') },
				{ Action = 'UI_CommoRose_Action_Unlink', Label = Language:I18N('Unlink') },
				{ Action = 'UI_CommoRose_Action_SelectPrevious', Label = Language:I18N('Select Previous') },
				{ Action = 'UI_CommoRose_Action_Move', Label = Language:I18N('Move') },
				{ Action = 'UI_CommoRose_Action_Merge', Label = Language:I18N('Merge') },
			},
			Right = {
				{ Action = 'UI_CommoRose_Action_Add', Label = Language:I18N('Add') },
				{ Action = 'UI_CommoRose_Action_Link', Label = Language:I18N('Link') },
				{ Action = 'UI_CommoRose_Action_SelectNext', Label = Language:I18N('Select Next') },
				{ Action = 'UI_CommoRose_Action_SetInput', Label = Language:I18N('Set Input') },
				{ Action = 'UI_CommoRose_Action_Split', Label = Language:I18N('Split') },
			}
		})
		]] -- disabled for now
		return
	end

	if (p_Action == 'Select') then

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
				self:Print('Deselect -> %s', hitPoint.ID)
				g_NodeCollection:Deselect(hitPoint)
				return
			else
				self:Print('Select -> %s', hitPoint.ID)
				g_NodeCollection:Select(hitPoint)
				return
			end
		end
	end
end

function ClientNodeEditor:_onUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
	if (self.enabled and self.commoRoseEnabled and p_Screen ~= nil and UIScreenAsset(p_Screen).name == 'UI/Flow/Screen/CommRoseScreen') then
		self:Print('Blocked vanilla commo rose')
		p_HookCtx:Return()
		return
	end
	p_HookCtx:Pass(p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
end

-- ############################## Update Events
-- ############################################

function ClientNodeEditor:_onUpdateInput(p_Player, p_Delta)
	if (not self.enabled) then
		return
	end

	if (self:IsSavingOrLoading()) then
		return
	end

	if (self.commoRoseEnabled and not self.commoRoseActive) then

		local Comm1 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu1) > 0
		local Comm2 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu2) > 0
		local Comm3 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu3) > 0
		local commButtonDown = (Comm1 or Comm2 or Comm3)

		-- pressed and released without triggering commo rose
		if (self.commoRosePressed and not commButtonDown) then
			if (self.editMode == 'move') then
				self:_onToggleMoveNode()
			else
				self:_onCommoRoseAction('Select')
			end
		end

		self.commoRosePressed = (Comm1 or Comm2 or Comm3)
	end

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
			self:_onLinkNode()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad5) then
			self:_onSelectNode()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad2) then
			self:_onUnlinkNode()
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
			self:_onAddNode()
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
			self:_onLinkNode()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Minus) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Subtract) then
			self:_onUnlinkNode()
			return
		end
	end
end

function ClientNodeEditor:_onEngineUpdate(p_Delta, p_SimDelta)
	if (self.nodeSendTimer >= 0 and #self.nodesToSend > 0) then

		self.debugEntries['nodeSendProgress'] = self.nodeSendProgress..'/'..(#self.nodesToSend)
		self.nodeSendTimer = self.nodeSendTimer + p_Delta

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
				self.nodesToSend = {}
				self.nodeSendTimer = -1
				self.nodeSendProgress = 1
				self.nodeOperation = ''
				NetEvents:Send('NodeEditor:Init', true)
				self:Print('Finished sending waypoints to server')
			end
		end
	end

	if (self.nodeReceiveTimer >= 0) then
		self.nodeReceiveTimer = self.nodeReceiveTimer + p_Delta

		-- timer for receiving node payload
		if (self.nodeReceiveTimer > self.nodeReceiveDelay) then
			self:Print('Ready to receive waypoints')
			NetEvents:Send('NodeEditor:SendNodes')
			self.nodeReceiveTimer = -1
		end
	end

	if (self.commoRoseEnabled and not self.commoRoseActive) then

		if (self.commoRoseTimer == -1 and self.commoRosePressed) then
			self.commoRoseTimer = 0
		end

		if (self.commoRosePressed and self.commoRoseTimer >= 0) then

			self.commoRoseTimer = self.commoRoseTimer + p_Delta

			if (self.commoRoseTimer > self.commoRoseDelay) then
				self.commoRoseTimer = -1
				self.commoRoseActive = true
				self:_onCommoRoseAction('Show')
			end
		end
	end

	if (self.customTraceTimer >= 0 and self.player ~= nil and self.player.soldier ~= nil) then
		self.customTraceTimer = self.customTraceTimer + p_Delta

		if (self.customTraceTimer > self.customTraceDelay) then

			local lastWaypoint = self.customTrace:GetLast()

			if (lastWaypoint) then

				local lastDistance = lastWaypoint.Position:Distance(self.playerPos)

				if (lastDistance >= self.customTraceDelay) then
					-- primary weapon, record movement
					if (self.player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_0) then

						local newWaypoint, msg = self.customTrace:Add()
						self.customTrace:Update(newWaypoint, {
							Position = self.playerPos:Clone()
						})
						self.customTrace:ClearSelection()
						self.customTrace:Select(newWaypoint)

						local speed = 0 -- 0 = wait, 1 = prone ... (4 Bits)
						local extra = 0 -- 0 = nothing, 1 = jump ... (4 Bits)

						if self.player.attachedControllable ~= nil then
							local speedInput = math.abs(self.player.input:GetLevel(EntryInputActionEnum.EIAThrottle))
							if speedInput > 0 then
								speed = 3
								if self.player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
									speed = 4
								end
							elseif speedInput == 0 then
								if self.player.attachedControllable.velocity.magnitude > 0 then
									print(self.player.attachedControllable.velocity.magnitude)
									speed = 2
								end
							end

							if self.player.input:GetLevel(EntryInputActionEnum.EIABrake) > 0 then
								speed = 1
							end

							self.customTrace:SetInput(speed, extra, 0)

						else
							if self.player.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then --record only if moving
								if self.player.soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
									speed = 1
								elseif self.player.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
									speed = 2
								else
									speed = 3

									if self.player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
										speed = 4
									end
								end

								if self.player.input:GetLevel(EntryInputActionEnum.EIAJump) == 1 then
									extra = 1
								end

								self.customTrace:SetInput(speed, extra, 0)
							end
						end

					-- secondary weapon, increase wait timer
					elseif (self.player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_1) then

						local lastWaypoint = self.customTrace:GetLast()
						self.customTrace:ClearSelection()
						self.customTrace:Select(lastWaypoint)
						self.customTrace:SetInput(lastWaypoint.SpeedMode, lastWaypoint.ExtraMode, lastWaypoint.OptValue + p_Delta)
					end

					self.customTraceDistance = self.customTraceDistance + lastDistance
					g_FunBotUIClient:_onUITraceWaypointsDistance(self.customTraceDistance)
					g_FunBotUIClient:_onUITraceWaypoints(#self.customTrace:Get())
				end
			else
				-- collection is empty, stop the timer
				self.customTraceTimer = -1
			end

			self.customTraceTimer = 0
		end
	end

	local botwpcount = 0
	for waypointID, data in pairs(self.botSelectedWaypoints) do
		if (data.Timer < 0) then
			self.botSelectedWaypoints[waypointID] = nil
		else
			data.Timer = data.Timer - p_Delta
			botwpcount = botwpcount + 1
		end
	end

	self.debugEntries['botSelectedWaypoints'] = botwpcount
end

function ClientNodeEditor:_onUpdateManagerUpdate(p_Delta, p_Pass)

	-- Only do math on presimulation UpdatePass, don't bother if debugging is off
	if not self.enabled or p_Pass ~= UpdatePass.UpdatePass_PreSim then
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

		-- do not update node positions if saving or loading
		if (not self:IsSavingOrLoading()) then

			-- perform raycast to get where player is looking
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

			-- loop selected nodes and update positions
			local nodePaths = g_NodeCollection:GetPaths()
			for path,_ in pairs(nodePaths) do

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
					end
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

	self.debugEntries['commoRoseEnabled'] = self.commoRoseEnabled
	self.debugEntries['commoRosePressed'] = self.commoRosePressed
	self.debugEntries['commoRoseTimer'] = string.format('%4.2f', self.commoRoseTimer)
	self.debugEntries['commoRoseActive'] = self.commoRoseActive

	for k,v in pairs(self.debugEntries) do
		debugText = debugText .. k..': '..tostring(v).."\n"
	end

	--DebugRenderer:DrawText2D(20, 400, debugText, self.colors.Text, 1)


	-- draw help info
	local helpText = ''
	if (self.editMode == 'none') then

		helpText = helpText..' Node Operation Controls '.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   7   |   8   |   9   |'.."\n"
		helpText = helpText..'| Merge | Link  | Split |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   4   |   5   |   6   |'.."\n"
		helpText = helpText..'| Move  |Select | Input |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'|   1   |   2   |   3   |'.."\n"
		helpText = helpText..'|Remove |Unlink |  Add  |'.."\n"
		helpText = helpText..'+-------+-------+-------+'.."\n"
		helpText = helpText..'                         '.."\n"
		helpText = helpText..'      [F12] - Settings   '.."\n"
		helpText = helpText..'     [Spot] - Quick Select'.."\n"
		helpText = helpText..'[Backspace] - Clear Select'.."\n"
		helpText = helpText..'   [Insert] - Spawn Bot  '.."\n"
		helpText = helpText..'       [F9] - Save Nodes '.."\n"
		helpText = helpText..'      [F11] - Load Nodes '.."\n"

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
		helpText = helpText..'      [F12] - Settings    '.."\n"
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

	-- draw waypoints stored in main collection
	local waypointPaths = g_NodeCollection:GetPaths()
	for path,_ in pairs(waypointPaths) do
		if (g_NodeCollection:IsPathVisible(path)) then
			for waypoint=1, #waypointPaths[path] do
				self:_drawNode(waypointPaths[path][waypoint], false)
			end
		end
	end

	-- draw waypoints for custom trace
	if (self.customTrace ~= nil) then
		local customWaypoints = self.customTrace:Get()
		for i=1, #customWaypoints do
			self:_drawNode(customWaypoints[i], true)
		end
	end
end

function ClientNodeEditor:_drawNode(p_Waypoint, p_IsTracePath)
	local isSelected = not p_IsTracePath and g_NodeCollection:IsSelected(p_Waypoint)
	local qualityAtRange = g_NodeCollection:InRange(p_Waypoint, self.playerPos, Config.LineRange)

	-- setup node color information
	local color = self.colors.Orphan
	if (p_Waypoint.Previous ~= false and p_Waypoint.Next ~= false) then

		-- happens after the 20th path
		if (self.colors[p_Waypoint.PathIndex] == nil) then
			local r, g, b = (math.random(20, 100) / 100), (math.random(20, 100) / 100), (math.random(20, 100) / 100)
			self.colors[p_Waypoint.PathIndex] = {
				Node = Vec4(r, g, b, 0.25),
				Line = Vec4(r, g, b, 1),
			}
		end
		color = self.colors[p_Waypoint.PathIndex]
	end
	if (p_IsTracePath) then
		color = {
			Node = self.colors.White,
			Line = self.colors.White,
		}
	end

	-- draw the node for the waypoint itself
	if (g_NodeCollection:InRange(p_Waypoint, self.playerPos, Config.WaypointRange)) then
		DebugRenderer:DrawSphere(p_Waypoint.Position, 0.05, color.Node, false, (not qualityAtRange))
	end

	-- if bot has selected draw it
	if (not p_IsTracePath and self.botSelectedWaypoints[p_Waypoint.ID] ~= nil) then
		local selectData = self.botSelectedWaypoints[p_Waypoint.ID]
		if (selectData.Obstacle) then
			DebugRenderer:DrawLine(selectData.Position + (Vec3.up * 1.2), p_Waypoint.Position, self.colors.Red, self.colors.Red)
		else
			DebugRenderer:DrawLine(selectData.Position + (Vec3.up * 1.2), p_Waypoint.Position, self.colors[selectData.Color], self.colors[selectData.Color])
		end
	end

	-- if selected draw bigger node and transform helper
	if (not p_IsTracePath and isSelected and g_NodeCollection:InRange(p_Waypoint, self.playerPos, Config.WaypointRange)) then
		-- node selection indicator
		DebugRenderer:DrawSphere(p_Waypoint.Position, 0.08,  color.Node, false, (not qualityAtRange))

		-- transform marker
		DebugRenderer:DrawLine(p_Waypoint.Position, p_Waypoint.Position + (Vec3.up), self.colors.Red, self.colors.Red)
		DebugRenderer:DrawLine(p_Waypoint.Position, p_Waypoint.Position + (Vec3.right * 0.5), self.colors.Green, self.colors.Green)
		DebugRenderer:DrawLine(p_Waypoint.Position, p_Waypoint.Position + (Vec3.forward * 0.5), self.colors.Blue, self.colors.Blue)
	end

	-- draw connection lines
	if (Config.DrawWaypointLines and g_NodeCollection:InRange(p_Waypoint, self.playerPos, Config.LineRange)) then
		-- try to find a previous node and draw a line to it
		if (p_Waypoint.Previous and type(p_Waypoint.Previous) == 'string') then
			p_Waypoint.Previous = g_NodeCollection:Get(p_Waypoint.Previous)
		end

		if (p_Waypoint.Previous) then
			if (p_Waypoint.PathIndex ~= p_Waypoint.Previous.PathIndex) then
				-- draw a white line between nodes on separate paths
				-- DebugRenderer:DrawLine(p_Waypoint.Previous.Position, p_Waypoint.Position, self.colors.White, self.colors.White)
			else
				-- draw fading line between nodes on same path
				DebugRenderer:DrawLine(p_Waypoint.Previous.Position, p_Waypoint.Position, color.Line, color.Line)
			end
		end
		if (p_Waypoint.Data and p_Waypoint.Data.LinkMode ~= nil and p_Waypoint.Data.Links ~= nil) then
			for i=1, #p_Waypoint.Data.Links do
				local linkedWaypoint = g_NodeCollection:Get(p_Waypoint.Data.Links[i])
				if (linkedWaypoint ~= nil) then
					-- draw lines between linked nodes
					DebugRenderer:DrawLine(linkedWaypoint.Position, p_Waypoint.Position, self.colors.Purple, self.colors.Purple)
				end
			end
		end
	end

	-- draw debugging text
	if (Config.DrawWaypointIDs and g_NodeCollection:InRange(p_Waypoint, self.playerPos, Config.TextRange)) then
		if (isSelected) then
			-- don't try to precalc this value like with the distance, another memory leak crash awaits you
			local screenPos = ClientUtils:WorldToScreen(p_Waypoint.Position + Vec3.up)
			if (screenPos ~= nil) then

				local previousNode = tostring(p_Waypoint.Previous)
				local nextNode = tostring(p_Waypoint.Next)
				local pathNode = g_NodeCollection:GetFirst(p_Waypoint.PathIndex)

				if (type(p_Waypoint.Previous) == 'table') then
					previousNode = p_Waypoint.Previous.ID
				end
				if (type(p_Waypoint.Next) == 'table') then
					nextNode = p_Waypoint.Next.ID
				end

				local speedMode = 'N/A'
				if (p_Waypoint.SpeedMode == 0) then speedMode = 'Wait' end
				if (p_Waypoint.SpeedMode == 1) then speedMode = 'Prone' end
				if (p_Waypoint.SpeedMode == 2) then speedMode = 'Crouch' end
				if (p_Waypoint.SpeedMode == 3) then speedMode = 'Walk' end
				if (p_Waypoint.SpeedMode == 4) then speedMode = 'Sprint' end

				local extraMode = 'N/A'
				if (p_Waypoint.ExtraMode == 1) then extraMode = 'Jump' end

				local optionValue = 'N/A'
				if (p_Waypoint.SpeedMode == 0) then
					optionValue = tostring(p_Waypoint.OptValue)..' Seconds'
				end

				local pathMode = 'Loops'
				if (pathNode) then
					if (pathNode.OptValue == 0XFF) then
						pathMode = 'Reverses'
					end
				end

				local text = ''
				text = text..string.format("(%s)Pevious [ %s ] Next(%s)\n", previousNode, p_Waypoint.ID, nextNode)
				text = text..string.format("Index[%d]\n", p_Waypoint.Index)
				text = text..string.format("Path[%d][%d] (%s)\n", p_Waypoint.PathIndex, p_Waypoint.PointIndex, pathMode)
				text = text..string.format("Path Objectives: %s\n", g_Utilities:dump(pathNode.Data.Objectives, false))
				text = text..string.format("InputVar: %d\n", p_Waypoint.InputVar)
				text = text..string.format("SpeedMode: %s (%d)\n", speedMode, p_Waypoint.SpeedMode)
				text = text..string.format("ExtraMode: %s (%d)\n", extraMode, p_Waypoint.ExtraMode)
				text = text..string.format("OptValue: %s (%d)\n", optionValue, p_Waypoint.OptValue)
				text = text..'Data: '..g_Utilities:dump(p_Waypoint.Data, true)

				DebugRenderer:DrawText2D(screenPos.x, screenPos.y, text, self.colors.Text, 1.2)
			end
			screenPos = nil
		else
			-- don't try to precalc this value like with the distance, another memory leak crash awaits you
			local screenPos = ClientUtils:WorldToScreen(p_Waypoint.Position + (Vec3.up * 0.05))
			if (screenPos ~= nil) then
				DebugRenderer:DrawText2D(screenPos.x, screenPos.y, tostring(p_Waypoint.ID), self.colors.Text, 1)
				screenPos = nil
			end
		end
	end
end

-- ################# Node sending and retrieval
-- ############################################

-- request a fresh node list from the server
-- or server has told us be ready to receive
function ClientNodeEditor:_onGetNodes(p_Args)
	self:Print('Getting Nodes: %s', tostring(p_Args))

	-- unload our current cache
	self:_onUnload(p_Args)
	-- enable the timer before we are ready to receive
	self.nodeReceiveTimer = 0
	return true
end

-- server is ready to receive our nodes
function ClientNodeEditor:_onSendNodes(p_Args)

	self.nodesToSend = g_NodeCollection:Get()
	self:Print('Sending Nodes: %d', #self.nodesToSend)

	if (self.nodesToSend == nil or #self.nodesToSend < 1) then
		self:Print('Client has 0 Nodes, Cancelling Send!')
		return false
	else
		self.nodeSendTimer = 0
		return true
	end
end

function ClientNodeEditor:_onServerCreateNode(p_Data)
	g_NodeCollection:Create(p_Data, true)
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

	self:Print('Receved Nodes: %d', #waypoints)

	for i=1, #waypoints do

		local waypoint = waypoints[i]
		if (type(waypoint.Next) == 'string') then
			staleNodes = staleNodes+1
		end
		if (type(waypoint.Previous) == 'string') then
			staleNodes = staleNodes+1
		end
	end

	if (staleNodes > 0) then
		self:Print('Warning! Stale Nodes: %d', staleNodes)
	end

	self.nodeOperation = ''
end

-- stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
function ClientNodeEditor:Raycast(p_MaxDistance, p_UseAsync)
	if self.player == nil then
		return
	end
	p_MaxDistance = p_MaxDistance or 100

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
		transform.trans.x + (direction.x * p_MaxDistance),
		transform.trans.y + (direction.y * p_MaxDistance),
		transform.trans.z + (direction.z * p_MaxDistance))

	-- Perform raycast, returns a RayCastHit object.

	local flags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh
	if (p_UseAsync) then
		flags = flags | RayCastFlags.IsAsyncRaycast
	end

	local raycastHit = RaycastManager:Raycast(castStart, castEnd, flags)

	return raycastHit
end

if (g_ClientNodeEditor == nil) then
	g_ClientNodeEditor = ClientNodeEditor()
end

return g_ClientNodeEditor
