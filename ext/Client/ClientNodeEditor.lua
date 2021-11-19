class "ClientNodeEditor"

require('__shared/Config')

local m_NodeCollection = require('__shared/NodeCollection')
local m_Logger = Logger("ClientNodeEditor", Debug.Client.NODEEDITOR)

function ClientNodeEditor:__init()
	-- caching values for drawing performance
	self.m_Player = nil
	self.m_PlayerPos = nil

	self.m_Enabled = Config.DebugTracePaths
	self.m_DisableUserInterface = Config.DisableUserInterface

	self.m_CommoRoseEnabled = false
	self.m_CommoRosePressed = false
	self.m_CommoRoseActive = false
	self.m_CommoRoseTimer = -1
	self.m_CommoRoseDelay = 0.25

	self.m_NodeReceiveTimer = -1
	self.m_NodeReceiveProgress = 0
	self.m_NodeReceiveDelay = 1
	self.m_NodeReceiveExpected = 0

	self.m_NodesToSend = {}
	self.m_NodeSendTimer = -1
	self.m_NodeSendProgress = 1
	self.m_NodeSendDelay = 0.02

	self.m_EditMode = 'none' -- 'move', 'none', 'area'
	self.m_EditStartPos = nil
	self.m_NodeStartPos = {}
	self.m_EditModeManualOffset = Vec3.zero
	self.m_EditModeManualSpeed = 0.05
	self.m_EditPositionMode = 'relative'
	self.m_HelpTextLocation = Vec2.zero

	self.m_CustomTrace = nil
	self.m_CustomTraceIndex = nil
	self.m_CustomTraceTimer = -1
	self.m_CustomTraceDelay = Config.TraceDelta
	self.m_CustomTraceDistance = 0
	self.m_CustomTraceSaving = false

	self.m_RaycastTimer = 0
    self.m_NodesToDraw = {}
	self.m_NodesToDraw_temp = {}
    self.m_LinesToDraw = {}
	self.m_LinesToDraw_temp = {}
    self.m_TextToDraw = {}
	self.m_TextToDraw_temp = {}
	self.m_TextPosToDraw = {}
	self.m_TextPosToDraw_temp = {}
    self.m_ObbToDraw = {}
	self.m_ObbToDraw_temp = {}
	self.m_lastDrawIndexPath = 0
	self.m_lastDrawIndexNode = 0

	self.m_ScanForNode = false

	self.m_NodeOperation = ''

	self.m_BotSelectedWaypoints = {}

	self.m_Colors = {
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

	self.m_LastTraceSearchAreaPos = nil
	self.m_LastTraceSearchAreaSize = nil
	self.m_LastTraceStart = nil
	self.m_LastTraceEnd = nil

	self.m_BotVisionEnabled = false
	self.m_BotVisionPlayers = {}
	self.m_BotVisionCrosshair = nil

	self.m_DebugEntries = {}
	self.m_EventsReady = false
end

function ClientNodeEditor:OnRegisterEvents()
	-- simple check to make sure we don't reregister things if they are already done
	if self.m_EventsReady then return end

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
	Console:Register('Enabled', 'Enable / Disable the waypoint editor', self, self.OnSetEnabled)
	Console:Register('CommoRoseEnabled', 'Enable / Disable the waypoint editor Commo Rose', self, self._onSetCommoRoseEnabled)
	Console:Register('CommoRoseShow', 'Show custom Commo Rose', self, self._onShowRose)
	Console:Register('CommoRoseHide', 'Hide custom Commo Rose', self, self._onHideRose)
	Console:Register('SetMetadata', '<string|Data> - Set Metadata for waypoint, Must be valid JSON string', self, self._onSetMetadata)
	Console:Register('AddObjective', '<string|Objective> - Add an objective to a path', self, self._onAddObjective)
	Console:Register('AddMcom', 'Add an MCOM Arm/Disarm-Action to a point', self, self._onAddMcom)
	Console:Register('AddVehicle', 'Add a vehicle a bot can use', self, self._onAddVehicle)
	Console:Register('ExitVehicle', '<bool|OnlyPassengers> Add a point where all bots or only the passengers leaves the vehicle', self, self._onExitVehicle)
	Console:Register('AddVehiclePath', '<string|Type> Add vehicle-usage to a path. Types = land, water, air', self, self._onAddVehiclePath)
	Console:Register('RemoveObjective', '<string|Objective> - Remove an objective from a path', self, self._onRemoveObjective)
	Console:Register('RemoveData', 'Remove all data of one or several nodes', self, self._onRemoveData)
	Console:Register('ProcessMetadata', 'Process waypoint metadata starting with selected nodes or all nodes', self, self._onProcessMetadata)
	Console:Register('RecalculateIndexes', 'Recalculate Indexes starting with selected nodes or all nodes', self, self._onRecalculateIndexes)
	Console:Register('DumpNodes', 'Print selected nodes or all nodes to console', self, self._onDumpNodes)
	Console:Register('UnloadNodes', 'Clears and unloads all clientside nodes', self, self._onUnload)

	Console:Register('ObjectiveDirection', 'Show best direction to given objective', self, self._onObjectiveDirection)
	Console:Register('GetKnownObjectives', 'print all known objectives and associated paths', self, self._onGetKnownObjectives)


	Console:Register('BotVision', '*<boolean|Enabled>* Lets you see what the bots see [Experimental]', self, self._onSetBotVision)

	self.m_EventsReady = true
	self:Log('Register Events')
end

function ClientNodeEditor:IsSavingOrLoading()
	return (self.m_NodeSendTimer > -1 or self.m_NodeReceiveTimer > -1 or self.m_NodeOperation ~= '' or not self.m_Enabled)
end

function ClientNodeEditor:Log(...)
	m_Logger:Write('ClientNodeEditor: ' .. Language:I18N(...))
end

function ClientNodeEditor:OnSetEnabled(p_Args)
	local s_Enabled = p_Args

	if type(p_Args) == 'table' then
		s_Enabled = p_Args[1]
	end

	s_Enabled = (s_Enabled == true or s_Enabled == 'true' or s_Enabled == '1')

	if self.m_Enabled ~= s_Enabled then
		self.m_Enabled = s_Enabled
		self.m_CommoRoseEnabled = s_Enabled

		if #m_NodeCollection:Get() == 0 then
			if self.m_Enabled then
				self:_onUnload() -- clear local copy
				self.m_NodeReceiveTimer = 0 -- enable the timer for receiving nodes
			end
		end
	end
end

function ClientNodeEditor:_onSetCommoRoseEnabled(p_Args)
	local s_Enabled = p_Args

	if type(p_Args) == 'table' then
		s_Enabled = p_Args[1]
	end

	s_Enabled = (s_Enabled == true or s_Enabled == 'true' or s_Enabled == '1')

	self.m_CommoRoseEnabled = s_Enabled
end

function ClientNodeEditor:OnUISettings(p_Data)
	if p_Data == false then -- client closed settings
		self:OnSetEnabled(Config.DebugTracePaths)

		self.m_HelpTextLocation = Vec2.zero
		self.m_CustomTraceDelay = Config.TraceDelta
	end
end

-- ########### commo rose top / middle / bottom
-- ############################################

function ClientNodeEditor:_onSaveNodes(p_Args)
	self.m_CommoRoseActive = false

	if not self:IsSavingOrLoading() then
		self:Log('Initiating Save...')
		self.m_NodeOperation = 'Client Save'
		NetEvents:Send('NodeEditor:ReceivingNodes', #m_NodeCollection:Get())
		return true
	end

	self:Log('Operation in progress, please wait...')
	return false
end

function ClientNodeEditor:_onSelectNode(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	self:_onCommoRoseAction('Select')
	return true
end

function ClientNodeEditor:_onLoadNodes(p_Args)
	self.m_CommoRoseActive = false

	if not self:IsSavingOrLoading() then
		self:Log('Initiating Load...')
		self.m_NodeOperation = 'Client Load'
		self:_onGetNodes()
		return true
	end

	self:Log('Operation in progress, please wait...')
	return false
end

-- ####################### commo rose left side
-- ############################################

function ClientNodeEditor:_onRemoveNode(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Result, s_Message = m_NodeCollection:Remove()

	if not s_Result then
		self:Log(s_Message)
	end

	return s_Result
end

function ClientNodeEditor:_onUnlinkNode()
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Result, s_Message = m_NodeCollection:Unlink()

	if not s_Result then
		self:Log(s_Message)
	end

	return s_Result
end

function ClientNodeEditor:_onMergeNode(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Result, s_Message = m_NodeCollection:MergeSelection()

	if not s_Result then
		self:Log(s_Message)
	end

	return s_Result
end

function ClientNodeEditor:_onSelectPrevious()
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection > 0 then
		if s_Selection[1].Previous ~= false then
			m_NodeCollection:Select(s_Selection[1].Previous)
			return true
		end
	else
		self:Log('Must select at least one node')
	end

	return false
end

function ClientNodeEditor:_onClearSelection(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	m_NodeCollection:ClearSelection()
	return true
end

function ClientNodeEditor:_onToggleMoveNode(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if self.m_EditMode == 'move' then
		self.m_EditMode = 'none'
        
		self.editRayHitStart = nil
		self.m_EditModeManualOffset = Vec3.zero

		-- move was cancelled
		if p_Args ~= nil and p_Args == true then
			self:Log('Move Cancelled')
			local s_Selection = m_NodeCollection:GetSelected()

			for i = 1, #s_Selection do
				m_NodeCollection:Update(s_Selection[i], {
					Position = self.editNodeStartPos[s_Selection[i].ID]
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
				{Grid = 'K9', Key = '9', Name = 'Split'}
			},
			Other = {
				{Key = 'F12', Name = 'Settings'},
				{Key = 'Q', Name = 'Quick Select'},
				{Key = 'BS', Name = 'Clear Select'},
				{Key = 'INS', Name = 'Spawn Bot'}
			}
		})

		self:Log('Edit Mode: %s', self.m_EditMode)
		return true
	else
		if self.m_Player == nil or self.m_Player.soldier == nil then
			self:Log('Player must be alive')
			return false
		end

		local s_Selection = m_NodeCollection:GetSelected()

		if #s_Selection < 1 then
			self:Log('Must select at least one node')
			return false
		end

		self.editNodeStartPos = {}

		for i = 1, #s_Selection do
			self.editNodeStartPos[i] = s_Selection[i].Position:Clone()
			self.editNodeStartPos[s_Selection[i].ID] = s_Selection[i].Position:Clone()
		end

		self.m_EditMode = 'move'
		self.m_EditModeManualOffset = Vec3.zero

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

		self:Log('Edit Mode: %s', self.m_EditMode)
		return true
	end

	return false
end

-- ###################### commo rose right side
-- ############################################

function ClientNodeEditor:_onAddNode(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Result, s_Message = m_NodeCollection:Add()

	if not s_Result then
		self:Log(s_Message)
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()

	-- if selected is 0 or 1, we created a new node
	-- clear selection, select new node, change to move mode
	-- otherwise we just connected two nodes, don't change selection
	if s_Result ~= nil and #s_Selection <= 1 then
		m_NodeCollection:ClearSelection()
		m_NodeCollection:Select(s_Result)
		self.m_EditPositionMode = 'absolute'
		self:_onToggleMoveNode()
	end

	return true
end

function ClientNodeEditor:_onLinkNode()
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Result, s_Message = m_NodeCollection:Link()

	if not s_Result then
		self:Log(s_Message)
	end

	return s_Result
end

function ClientNodeEditor:_onSplitNode(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Result, s_Message = m_NodeCollection:SplitSelection()

	if not s_Result then
		self:Log(s_Message)
	end

	return s_Result
end

function ClientNodeEditor:_onSelectNext()
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection > 0 then
		if s_Selection[1].Next ~= false then
			m_NodeCollection:Select(s_Selection[1].Next)
			return true
		end
	else
		self:Log('Must select at least one node')
	end

	return false
end

function ClientNodeEditor:_onSelectBetween()
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()
	if #s_Selection < 1 then
		self:Log('Must select more than one node')
		return false
	end

	local s_BreakAt = (#m_NodeCollection:Get())
	local s_Current = 0
	local s_CurrentWaypoint = s_Selection[1]

	while s_CurrentWaypoint.Next and s_CurrentWaypoint.ID ~= s_Selection[#s_Selection].ID do
		m_NodeCollection:Select(s_CurrentWaypoint)
		s_Current = s_Current + 1

		if s_Current > s_BreakAt then
			break
		end

		s_CurrentWaypoint = s_CurrentWaypoint.Next
	end

	return true
end

function ClientNodeEditor:_onSetInputNode(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Result, s_Message = m_NodeCollection:SetInput(p_Args[1], p_Args[2], p_Args[3])

	if not s_Result then
		self:Log(s_Message)
	end

	return s_Result
end

-- ############################## Other Methods
-- ############################################


function ClientNodeEditor:_onShowPath(p_Args)
	self.m_CommoRoseActive = false

	local s_PathIndex = p_Args

	if type(p_Args) == 'table' then
		s_PathIndex = p_Args[1]
	end

	if s_PathIndex ~= nil and s_PathIndex:lower() == 'all' then
		for l_PathID, l_Waypoints in pairs(m_NodeCollection:GetPaths()) do
			m_NodeCollection:ShowPath(l_PathID)
		end

		return true
	end

	if (s_PathIndex ~= nil and tonumber(s_PathIndex) ~= nil) then
		m_NodeCollection:ShowPath(tonumber(s_PathIndex))
		return true
	end

	self:Log('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onHidePath(p_Args)
	self.m_CommoRoseActive = false

	local s_PathIndex = p_Args

	if type(p_Args) == 'table' then
		s_PathIndex = p_Args[1]
	end

	if s_PathIndex ~= nil and s_PathIndex:lower() == 'all' then
		for l_PathID, l_Waypoints in pairs(m_NodeCollection:GetPaths()) do
			m_NodeCollection:HidePath(l_PathID)
		end

		return true
	end

	if (s_PathIndex ~= nil and tonumber(s_PathIndex) ~= nil) then
		m_NodeCollection:HidePath(tonumber(s_PathIndex))
		return true
	end

	self:Log('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onWarpTo(p_Args)
	self.m_CommoRoseActive = false

	if self.m_Player == nil or self.m_Player.soldier == nil or self.m_Player.soldier == nil then
		self:Log('Player must be alive')
		return false
	end

	if p_Args == nil or #p_Args == 0 then
		self:Log('Must provide Waypoint ID')
		return false
	end

	local s_Waypoint = m_NodeCollection:Get(p_Args[1])

	if s_Waypoint == nil then
		self:Log('Waypoint not found: %s', p_Args[1])
		return false
	end

	self:Log('Teleporting to Waypoint: %s (%s)', s_Waypoint.ID, tostring(s_Waypoint.Position))
	NetEvents:Send('NodeEditor:WarpTo', s_Waypoint.Position)
end

function ClientNodeEditor:_onSpawnAtWaypoint(p_Args)
	if p_Args == nil or #p_Args == 0 then
		self:Log('Must provide Waypoint ID')
		return false
	end

	local s_Waypoint = m_NodeCollection:Get(p_Args[1])

	if s_Waypoint == nil then
		self:Log('Waypoint not found: %s', p_Args[1])
		return false
	end

	NetEvents:Send('BotEditor', json.encode({
		action = 'bot_spawn_path',
		value = s_Waypoint.PathIndex,
		pointindex = s_Waypoint.PointIndex,
	}))
end

-- ############################## Debug Methods
-- ############################################

function ClientNodeEditor:_onSetLastTraceSearchArea(p_Data)
	self.m_LastTraceSearchAreaPos = p_Data[1]
	self.m_LastTraceSearchAreaSize = p_Data[2]
end

-- NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', pathIndex, pointIndex, botPosition, color)
function ClientNodeEditor:_onBotSelect(p_PathIndex, p_PointIndex, p_BotPosition, p_IsObstacleMode, p_Color)
	local s_Waypoint = m_NodeCollection:Get(p_PointIndex, p_PathIndex)

	if s_Waypoint ~= nil then
		self.m_BotSelectedWaypoints[s_Waypoint.ID] = {
			Timer = 0.5,
			Position = p_BotPosition,
			Obstacle = p_IsObstacleMode,
			Color = (p_Color or 'White')
		}
	end
end

function ClientNodeEditor:_onShowRose(p_Args)
	self.m_CommoRoseEnabled = true
	self.m_CommoRoseActive = true
	self:_onCommoRoseAction('Show')
	return true
end

function ClientNodeEditor:_onHideRose(p_Args)
	self.m_CommoRoseActive = false
	self:_onCommoRoseAction('Hide')
	return true
end

function ClientNodeEditor:_onDumpNodes(p_Args)
	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection < 1 then
		s_Selection = m_NodeCollection:Get()
	end

	for i = 1, #s_Selection do
		self:Log(g_Utilities:dump(s_Selection[i], true, 1))
	end

	self:Log('Dumped [%d] Nodes!', #s_Selection)
	return true
end

function ClientNodeEditor:_onSetMetadata(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Data = table.concat(p_Args or {}, ' ')
	self:Log('Set Metadata (data): %s', g_Utilities:dump(s_Data, true))

	local s_Result, s_Message = m_NodeCollection:UpdateMetadata(s_Data)

	if s_Result ~= false then
		m_NodeCollection:ProcessMetadata(s_Result)
	else
		self:Log(s_Message)
	end

	return s_Result
end

function ClientNodeEditor:_onAddMcom(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if self.m_Player == nil or self.m_Player.soldier == nil then
		self:Log('Player must be alive')
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection ~= 1 then
		self:Log('Must select one node')
		return false
	end

	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local action = {
			type = "mcom",
			inputs = {EntryInputActionEnum.EIAInteract},
			time = 6.0,
			yaw = self.m_Player.input.authoritativeAimingYaw,
			pitch = self.m_Player.input.authoritativeAimingPitch
		}
		s_Selection[i].Data.Action = action
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end

	return true
end

function ClientNodeEditor:_onAddVehicle(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if self.m_Player == nil or self.m_Player.soldier == nil then
		self:Log('Player must be alive')
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection ~= 1 then
		self:Log('Must select one node')
		return false
	end

	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local action = {
			type = "vehicle",
			inputs = {EntryInputActionEnum.EIAInteract},
			time = 0.5,
			yaw = self.m_Player.input.authoritativeAimingYaw,
			pitch = self.m_Player.input.authoritativeAimingPitch
		}
		s_Selection[i].Data.Action = action
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end

	return true
end

function ClientNodeEditor:_onExitVehicle(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if self.m_Player == nil or self.m_Player.soldier == nil then
		self:Log('Player must be alive')
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection ~= 1 then
		self:Log('Must select one node')
		return false
	end

	local s_Data = p_Args[1] or "false"
	self:Log('Exit Vehicle (type): %s', g_Utilities:dump(s_Data, true))

	local s_OnlyPassengers = not (s_Data:lower() == "false" or s_Data == "0")
	print(s_OnlyPassengers)

	for i = 1, #s_Selection do
		local action = {
			type = "exit",
			onlyPassengers = s_OnlyPassengers,
			inputs = {EntryInputActionEnum.EIAInteract},
			time = 0.5
		}
		s_Selection[i].Data.Action = action
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end

	return true
end

function ClientNodeEditor:_onAddVehiclePath(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Data = table.concat(p_Args or {"land"}, ' ')
	self:Log('Add Vehicle (type): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection < 1 then
		self:Log('Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true

			local s_Vehicles = s_Waypoint.Data.Vehicles or {}
			local s_InTable = false

			for j = 1, #s_Vehicles do
				if (s_Vehicles[j] == s_Data) then
					s_InTable = true
					break
				end
			end

			if not s_InTable then
				table.insert(s_Vehicles, s_Data)
				s_Waypoint.Data.Vehicles = s_Vehicles
				self:Log('Updated Waypoint: %s', s_Waypoint.ID)
			end
		end
	end

	return true
end

function ClientNodeEditor:_onAddObjective(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Data = table.concat(p_Args or {}, ' ')
	self:Log('Add Objective (data): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection < 1 then
		self:Log('Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true

			local s_Objectives = s_Waypoint.Data.Objectives or {}
			local s_InTable = false

			for j = 1, #s_Objectives do
				if (s_Objectives[j] == s_Data) then
					s_InTable = true
					break
				end
			end

			if not s_InTable then
				table.insert(s_Objectives, s_Data)
				s_Waypoint.Data.Objectives = s_Objectives
				self:Log('Updated Waypoint: %s', s_Waypoint.ID)
			end
		end
	end

	return true
end

function ClientNodeEditor:_onRemoveObjective(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Data = table.concat(p_Args or {}, ' ')
	self:Log('Remove Objective (data): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection < 1 then
		self:Log('Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true

			local s_Objectives = s_Waypoint.Data.Objectives or {}
			local s_NewObjectives = {}

			for j = 1, #s_Objectives do
				if (s_Objectives[j] ~= s_Data) then
					table.insert(s_NewObjectives, s_Objectives[j])
				end
			end

			s_Waypoint.Data.Objectives = s_NewObjectives
			self:Log('Updated Waypoint: %s', s_Waypoint.ID)
		end
	end

	return true
end

function ClientNodeEditor:_onRemoveData(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	if self.m_Player == nil or self.m_Player.soldier == nil then
		self:Log('Player must be alive')
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection < 1 then
		self:Log('Must select at least one node')
		return false
	end

	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		s_Selection[i].Data = {}
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end

	return true
end

function ClientNodeEditor:_onRecalculateIndexes(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()
	local s_Firstnode = nil

	if #s_Selection > 0 then
		s_Firstnode = s_Selection[1]
	end

	m_NodeCollection:RecalculateIndexes(s_Firstnode)
	return true
end

function ClientNodeEditor:_onProcessMetadata(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected()
	local s_Firstnode = nil

	if #s_Selection > 0 then
		s_Firstnode = s_Selection[1]
	end

	m_NodeCollection:ProcessMetadata(s_Firstnode)
	return true
end

function ClientNodeEditor:_onSetBotVision(p_Args)
	self.m_BotVisionEnabled = (p_Args ~= nil and (p_Args[1] == '1' or p_Args[1] == 'true'))

	self:Log('BotVision: %s', self.m_BotVisionEnabled)

	NetEvents:Send('NodeEditor:SetBotVision', self.m_BotVisionEnabled)

	if self.m_BotVisionEnabled then
		-- unload our current cache
		self:_onUnload(p_Args)
		-- enable the timer before we are ready to receive
		self.m_NodeReceiveTimer = 0
	end
end


function ClientNodeEditor:_onObjectiveDirection(p_Args)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		return false
	end

	local s_Data = table.concat(p_Args or {}, ' ')
	self:Log('Objective Direction (data): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected()

	if #s_Selection < 1 then
		self:Log('Must select at least one node')
		return false
	end

	local s_Direction, s_BestPreviousWaypoint = m_NodeCollection:ObjectiveDirection(s_Selection[1], s_Data)

	self:Log('Direction: %s', s_Direction)

	if s_BestPreviousWaypoint ~= nil then
		self:Log('Best Previous Waypoint: %s', s_BestPreviousWaypoint.ID)
	end

	return true
end

function ClientNodeEditor:_onGetKnownObjectives(p_Args)
	self.m_CommoRoseActive = false
	self:Log('Known Objectives -> '..g_Utilities:dump(m_NodeCollection:GetKnownObjectives(), true))
	return true
end

-- ############################ Trace Recording
-- ############################################

function ClientNodeEditor:_getNewIndex()
	local s_NextIndex = 0
	local s_AllPaths = m_NodeCollection:GetPaths()

	local s_HighestIndex = 0
	for l_PathIndex, l_Points in pairs(s_AllPaths) do
		if l_PathIndex > s_HighestIndex then
			s_HighestIndex = l_PathIndex
		end
	end

	for i = 1, s_HighestIndex do
		if s_AllPaths[i] == nil or s_AllPaths[i] == {} then	
			return i
		end
	end
	return s_HighestIndex + 1
end

function ClientNodeEditor:_onStartTrace()
	if self.m_CustomTrace ~= nil then
		self.m_CustomTrace:Clear()
	end

	self.m_CustomTrace = NodeCollection(true)
	self.m_CustomTraceTimer = 0
	self.m_CustomTraceIndex = self:_getNewIndex()
	self.m_CustomTraceDistance = 0

	local s_FirstWaypoint = self.m_CustomTrace:Create({
		Position = self.m_PlayerPos:Clone()
	})
	self.m_CustomTrace:ClearSelection()
	self.m_CustomTrace:Select(s_FirstWaypoint)

	self:Log('Custom Trace Started')

	g_FunBotUIClient:_onUITrace(true)
	g_FunBotUIClient:_onUITraceIndex(self.m_CustomTraceIndex)
	g_FunBotUIClient:_onUITraceWaypoints(#self.m_CustomTrace:Get())
	g_FunBotUIClient:_onUITraceWaypointsDistance(self.m_CustomTraceDistance)
end

function ClientNodeEditor:_onEndTrace()
	self.m_CustomTraceTimer = -1
	g_FunBotUIClient:_onUITrace(false)

	local s_FirstWaypoint = self.m_CustomTrace:GetFirst()

	if s_FirstWaypoint then
		local s_StartPos = s_FirstWaypoint.Position + Vec3.up
		local s_EndPos = self.m_CustomTrace:GetLast().Position + Vec3.up
		local s_Raycast = nil

		if self.m_Player.attachedControllable ~= nil then
			s_Raycast = RaycastManager:Raycast(s_StartPos, s_EndPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh | RayCastFlags.DontCheckPhantoms | RayCastFlags.DontCheckGroup | RayCastFlags.IsAsyncRaycast)
		else
			s_Raycast = RaycastManager:Raycast(s_StartPos, s_EndPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh | RayCastFlags.IsAsyncRaycast)
		end

		self.m_CustomTrace:ClearSelection()
		self.m_CustomTrace:Select(s_FirstWaypoint)

		if s_Raycast == nil or s_Raycast.rigidBody == nil then
			-- clear view from start node to end node, path loops
			self.m_CustomTrace:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0)
		else
			-- no clear view, path should just invert at the end
			self.m_CustomTrace:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0XFF)
		end

		self.m_CustomTrace:ClearSelection()
	end

	self:Log('Custom Trace Ended')
end

function ClientNodeEditor:_onClearTrace()
	self.m_CustomTraceTimer = -1
	self.m_CustomTraceIndex = self:_getNewIndex()
	self.m_CustomTraceDistance = 0
	self.m_CustomTrace:Clear()
	g_FunBotUIClient:_onUITrace(false)
	g_FunBotUIClient:_onUITraceIndex(self.m_CustomTraceIndex)
	g_FunBotUIClient:_onUITraceWaypoints(#self.m_CustomTrace:Get())
	g_FunBotUIClient:_onUITraceWaypointsDistance(self.m_CustomTraceDistance)

	self:Log('Custom Trace Cleared')
end

function ClientNodeEditor:_onSaveTrace(p_PathIndex)
	self.m_CommoRoseActive = false

	if self:IsSavingOrLoading() then
		self:Log('Operation in progress, please wait...')
		return false
	end

	if type(p_PathIndex) == 'table' then
		p_PathIndex = p_PathIndex[1]
	end

	if self.m_CustomTrace == nil then
		self:Log('Custom Trace is empty')
		return false
	end

	self.m_NodeOperation = 'Custom Trace'

	local s_PathCount = #m_NodeCollection:GetPaths()
	p_PathIndex = tonumber(p_PathIndex) or self:_getNewIndex()
	local s_CurrentWaypoint = self.m_CustomTrace:GetFirst()
	local s_ReferrenceWaypoint = nil
	local s_Direction = 'Next'

	if s_PathCount == 0 then
		s_CurrentWaypoint.PathIndex = 1
		s_ReferrenceWaypoint = m_NodeCollection:Create(s_CurrentWaypoint)
		s_CurrentWaypoint = s_CurrentWaypoint.Next

		s_PathCount = #m_NodeCollection:GetPaths()
	end

	-- remove existing path and replace with current
	if p_PathIndex == 1 then
		if s_PathCount == 1 then
			s_ReferrenceWaypoint = m_NodeCollection:GetFirst()
		else
			-- get first node of 2nd path, we'll InsertBefore the new nodes
			s_ReferrenceWaypoint = m_NodeCollection:GetFirst(2)
			s_CurrentWaypoint = self.m_CustomTrace:GetLast()
			s_Direction = 'Previous'
		end
	-- p_PathIndex is between 2 and #m_NodeCollection:GetPaths()
	-- get the node before the start of the specified path, if the path is existing
	elseif p_PathIndex <= s_PathCount then
		if #m_NodeCollection:Get(nil, p_PathIndex) > 0 then
			s_ReferrenceWaypoint = m_NodeCollection:GetFirst(p_PathIndex).Previous
		else
			s_ReferrenceWaypoint = m_NodeCollection:GetLast()
		end
	-- p_PathIndex == last path index, append all nodes to end of collection
	elseif p_PathIndex > s_PathCount then
		s_ReferrenceWaypoint = m_NodeCollection:GetLast()
	end

	-- we might have a path to delete
	if p_PathIndex > 0 and p_PathIndex <= s_PathCount then
		local s_PathWaypoints = m_NodeCollection:Get(nil, p_PathIndex)

		if #s_PathWaypoints > 0 then
			for i = 1, #s_PathWaypoints do
				m_NodeCollection:Remove(s_PathWaypoints[i])
			end
		end
	end

	collectgarbage('collect')

	-- merge custom trace into main node collection
	while s_CurrentWaypoint do
		s_CurrentWaypoint.PathIndex = p_PathIndex
		local s_NewWaypoint = m_NodeCollection:Create(s_CurrentWaypoint)

		if s_Direction == 'Next' then
			m_NodeCollection:InsertAfter(s_ReferrenceWaypoint, s_NewWaypoint)
		else
			m_NodeCollection:InsertBefore(s_ReferrenceWaypoint, s_NewWaypoint)
		end

		s_ReferrenceWaypoint = s_NewWaypoint
		s_CurrentWaypoint = s_CurrentWaypoint[s_Direction]
	end

	self.m_CustomTrace:Clear()
	collectgarbage('collect')
	self:Log('Custom Trace Saved to Path: %d', p_PathIndex)
	self.m_NodeOperation = ''
end

-- ##################################### Events
-- ############################################

function ClientNodeEditor:OnLevelLoaded(p_LevelName, p_GameMode)
	self.m_Enabled = Config.DebugTracePaths

	if self.m_Enabled then
		self.m_NodeReceiveTimer = 0 -- enable the timer for receiving nodes
	end
end

function ClientNodeEditor:OnPlayerDeleted(p_Player)
	if self.m_Player ~= nil and p_Player ~= nil and self.m_Player.name == p_Player.name then
		self:_onUnload()
	end
end

function ClientNodeEditor:OnLevelDestroy()
	self:_onUnload()
end

function ClientNodeEditor:_onUnload(p_Args)
	self.m_Player = nil
	self.m_NodeReceiveProgress = 0
	self.m_NodeReceiveExpected = 0
	self.m_lastDrawIndexPath = 0
	self.m_lastDrawIndexNode = 0

    self.m_NodesToDraw = {}
	self.m_NodesToDraw_temp = {}
    self.m_LinesToDraw = {}
	self.m_LinesToDraw_temp = {}
    self.m_TextToDraw = {}
	self.m_TextToDraw_temp = {}
	self.m_TextPosToDraw = {}
	self.m_TextPosToDraw_temp = {}
    self.m_ObbToDraw = {}
	self.m_ObbToDraw_temp = {}

	if p_Args ~= nil then
		if type(p_Args) == 'table' then
			self.m_NodeReceiveExpected = tonumber(p_Args[1]) or 0
		else
			self.m_NodeReceiveExpected = tonumber(p_Args) or 0
		end
	end

	self:Log('Unload, Expecting Waypoints: %s', g_Utilities:dump(p_Args))

	m_NodeCollection:Clear()
end

function ClientNodeEditor:_onCommoRoseAction(p_Action, p_Hit)
	self:Log('Commo Rose -> %s', p_Action)

	if p_Action == 'Hide' then
		self.m_CommoRoseActive = false
		g_FunBotUIClient:_onUICommonRose('false')
		return
	end

	if p_Action == 'Show' then
		self.m_CommoRoseActive = false -- disabled for now

		local s_Center = { Action = 'UI_CommoRose_Action_Select', Label = Language:I18N('Select') }

		if self.m_EditMode == 'move' then
			s_Center = { Action = 'UI_CommoRose_Action_Move', Label = Language:I18N('Finish') }
		elseif (self.m_EditMode == 'link') then
			s_Center = { Action = 'UI_CommoRose_Action_Connect', Label = Language:I18N('Connect') }
		end

		--[[
		g_FunBotUIClient:_onUICommonRose({
			Top = { Action = 'UI_CommoRose_Action_ClearSelection', Label = Language:I18N('Clear Selection') },
			Bottom = { Action = 'UI_CommoRose_Action_SelectBetween', Label = Language:I18N('Select Between') },
			Center = s_Center,
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

	if p_Action == 'Select' then
		local s_Hit = self:Raycast()

		if s_Hit == nil then
			self.m_ScanForNode = true
			return
		end

		local s_HitPoint = m_NodeCollection:Find(s_Hit.position)

		-- nothing found at hit location, try a raytracing check
		if s_HitPoint == nil and self.m_Player ~= nil and self.m_Player.soldier ~= nil then
			local s_PlayerCamPos = self.m_Player.soldier.worldTransform.trans + self.m_Player.input.authoritativeCameraPosition
			s_HitPoint = m_NodeCollection:FindAlongTrace(s_PlayerCamPos, s_Hit.position)
			self.m_LastTraceStart = s_PlayerCamPos
			self.m_LastTraceEnd = s_Hit.position
		end

		-- we found one, let's toggle its selected state
		if s_HitPoint ~= nil then
			local s_IsSelected = m_NodeCollection:IsSelected(s_HitPoint)

			if s_IsSelected then
				self:Log('Deselect -> %s', s_HitPoint.ID)
				m_NodeCollection:Deselect(s_HitPoint)
				return
			else
				self:Log('Select -> %s', s_HitPoint.ID)
				m_NodeCollection:Select(s_HitPoint)
				return
			end
		end
	end
end

function ClientNodeEditor:OnUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
	if self.m_Enabled and self.m_CommoRoseEnabled and p_Screen ~= nil and UIScreenAsset(p_Screen).name == 'UI/Flow/Screen/CommRoseScreen' then
		self:Log('Blocked vanilla commo rose')
		p_HookCtx:Return()
		return
	end

	p_HookCtx:Pass(p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
end

-- ############################## Update Events
-- ############################################

function ClientNodeEditor:OnClientUpdateInput(p_DeltaTime)
	if not self.m_Enabled then
		return
	end

	if self:IsSavingOrLoading() then
		return
	end

	if self.m_CommoRoseEnabled and not self.m_CommoRoseActive then
		local s_Comm1 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu1) > 0
		local s_Comm2 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu2) > 0
		local s_Comm3 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu3) > 0
		local s_CommButtonDown = (s_Comm1 or s_Comm2 or s_Comm3)

		-- pressed and released without triggering commo rose
		if self.m_CommoRosePressed and not s_CommButtonDown then
			if self.m_EditMode == 'move' then
				self:_onToggleMoveNode()
			else
				self:_onCommoRoseAction('Select')
			end
		end

		self.m_CommoRosePressed = (s_Comm1 or s_Comm2 or s_Comm3)
	end

	if self.m_EditMode == 'move' then
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowLeft) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad4) then
			self.m_EditModeManualOffset = self.m_EditModeManualOffset + (Vec3.left * self.m_EditModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowRight) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad6) then
			self.m_EditModeManualOffset = self.m_EditModeManualOffset - (Vec3.left * self.m_EditModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowUp) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad8) then
			self.m_EditModeManualOffset = self.m_EditModeManualOffset + (Vec3.forward * self.m_EditModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowDown) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad2) then
			self.m_EditModeManualOffset = self.m_EditModeManualOffset - (Vec3.forward * self.m_EditModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageUp) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad9) then
			self.m_EditModeManualOffset = self.m_EditModeManualOffset + (Vec3.up * self.m_EditModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageDown) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad3) then
			self.m_EditModeManualOffset = self.m_EditModeManualOffset - (Vec3.up * self.m_EditModeManualSpeed)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Equals) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Add) then
			self.m_EditModeManualSpeed = math.min(self.m_EditModeManualSpeed + 0.05, 1)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Minus) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Subtract) then
			self.m_EditModeManualSpeed = math.max(self.m_EditModeManualSpeed - 0.05, 0.05)
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad7) then
			self.m_EditModeManualOffset = Vec3.zero
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad1) then
			if self.m_EditPositionMode == 'absolute' then
				self.m_EditPositionMode = 'relative'
			elseif self.m_EditPositionMode == 'relative' then
				self.m_EditPositionMode = 'standing'
			else
				self.m_EditPositionMode = 'absolute'
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
        
        if InputManager:WentKeyDown(InputDeviceKeys.IDK_T) then
            -- TODO: Not functional yet!
            -- self:_onSwitchToArea()
			-- NetEvents:SendLocal('WaypointEditor:ChangeMode', self.m_EditMode, {tostring(self.m_EditModeManualSpeed), self.m_EditPositionMode})
			return
		end
	elseif self.m_EditMode == 'none' then
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
			m_NodeCollection:ClearSelection()
			return
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Insert) then
			local s_Selection = m_NodeCollection:GetSelected()

			if #s_Selection > 0 then
				NetEvents:Send('BotEditor', json.encode({
					action = 'bot_spawn_path',
					value = s_Selection[1].PathIndex,
					pointindex = s_Selection[1].PointIndex,
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

function ClientNodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	if self.m_NodeSendTimer >= 0 and #self.m_NodesToSend > 0 then
		self.m_DebugEntries['nodeSendProgress'] = self.m_NodeSendProgress..'/'..(#self.m_NodesToSend)
		self.m_NodeSendTimer = self.m_NodeSendTimer + p_DeltaTime

		if self.m_NodeSendTimer > self.m_NodeSendDelay then
			local s_DoneThisBatch = 0

			for i = self.m_NodeSendProgress, #self.m_NodesToSend do
				local s_SendableNode = {}

				for k, v in pairs(self.m_NodesToSend[i]) do
					if (k == 'Next' or k == 'Previous') and type(v) == 'table' then
						s_SendableNode[k] = v.ID
					else
						s_SendableNode[k] = v
					end
				end

				NetEvents:Send('NodeEditor:Create', s_SendableNode)
				s_DoneThisBatch = s_DoneThisBatch + 1
				self.m_NodeSendProgress = i + 1

				if s_DoneThisBatch >= 30 then
					break
				end
			end

			if self.m_NodeSendProgress >= #self.m_NodesToSend then
				self.m_NodesToSend = {}
				self.m_NodeSendTimer = -1
				self.m_NodeSendProgress = 1
				self.m_NodeOperation = ''
				NetEvents:Send('NodeEditor:Init', false)
				self:Log('Finished sending waypoints to server')
			end
		end
	end

	if self.m_NodeReceiveTimer >= 0 then
		self.m_NodeReceiveTimer = self.m_NodeReceiveTimer + p_DeltaTime

		-- timer for receiving node payload
		if self.m_NodeReceiveTimer > self.m_NodeReceiveDelay then
			self:Log('Ready to receive waypoints')
			NetEvents:Send('NodeEditor:SendNodes')
			self.m_NodeReceiveTimer = -1
		end
	end

	if self.m_CommoRoseEnabled and not self.m_CommoRoseActive then
		if self.m_CommoRoseTimer == -1 and self.m_CommoRosePressed then
			self.m_CommoRoseTimer = 0
		end

		if self.m_CommoRosePressed and self.m_CommoRoseTimer >= 0 then
			self.m_CommoRoseTimer = self.m_CommoRoseTimer + p_DeltaTime

			if self.m_CommoRoseTimer > self.m_CommoRoseDelay then
				self.m_CommoRoseTimer = -1
				self.m_CommoRoseActive = true
				self:_onCommoRoseAction('Show')
			end
		end
	end

	if (self.m_CustomTraceTimer >= 0 and self.m_Player ~= nil and self.m_Player.soldier ~= nil) then
		self.m_CustomTraceTimer = self.m_CustomTraceTimer + p_DeltaTime

		if self.m_CustomTraceTimer > self.m_CustomTraceDelay then
			local s_LastWaypoint = self.m_CustomTrace:GetLast()

			if s_LastWaypoint then
				local s_LastDistance = s_LastWaypoint.Position:Distance(self.m_PlayerPos)

				if s_LastDistance >= self.m_CustomTraceDelay then
					-- primary weapon, record movement
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_0 then
						local s_NewWaypoint, s_Msg = self.m_CustomTrace:Add()
						self.m_CustomTrace:Update(s_NewWaypoint, {
							Position = self.m_PlayerPos:Clone()
						})
						self.m_CustomTrace:ClearSelection()
						self.m_CustomTrace:Select(s_NewWaypoint)

						local s_Speed = BotMoveSpeeds.NoMovement -- 0 = wait, 1 = prone ... (4 Bits)
						local s_Extra = 0 -- 0 = nothing, 1 = jump ... (4 Bits)

						if self.m_Player.attachedControllable ~= nil then
							local s_SpeedInput = math.abs(self.m_Player.input:GetLevel(EntryInputActionEnum.EIAThrottle))

							if s_SpeedInput > 0 then
								s_Speed = BotMoveSpeeds.Normal

								if self.m_Player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
									s_Speed = BotMoveSpeeds.Sprint
								end
							elseif s_SpeedInput == 0 then
								s_Speed = BotMoveSpeeds.SlowCrouch
							end

							if self.m_Player.input:GetLevel(EntryInputActionEnum.EIABrake) > 0 then
								s_Speed = BotMoveSpeeds.VerySlowProne
							end

							self.m_CustomTrace:SetInput(s_Speed, s_Extra, 0)
						else
							if self.m_Player.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then --record only if moving
								if self.m_Player.soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
									s_Speed = BotMoveSpeeds.VerySlowProne
								elseif self.m_Player.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
									s_Speed = BotMoveSpeeds.SlowCrouch
								else
									s_Speed = BotMoveSpeeds.Normal

									if self.m_Player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
										s_Speed = BotMoveSpeeds.Sprint
									end
								end

								if self.m_Player.input:GetLevel(EntryInputActionEnum.EIAJump) == 1 then
									s_Extra = 1
								end

								self.m_CustomTrace:SetInput(s_Speed, s_Extra, 0)
							end
						end
					-- secondary weapon, increase wait timer
					elseif self.m_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_1 then
						local s_LastWaypointAgain = self.m_CustomTrace:GetLast()
						self.m_CustomTrace:ClearSelection()
						self.m_CustomTrace:Select(s_LastWaypointAgain)
						self.m_CustomTrace:SetInput(s_LastWaypointAgain.SpeedMode, s_LastWaypointAgain.ExtraMode, s_LastWaypointAgain.OptValue + p_DeltaTime)
					end

					self.m_CustomTraceDistance = self.m_CustomTraceDistance + s_LastDistance
					g_FunBotUIClient:_onUITraceWaypointsDistance(self.m_CustomTraceDistance)
					g_FunBotUIClient:_onUITraceWaypoints(#self.m_CustomTrace:Get())
				end
			else
				-- collection is empty, stop the timer
				self.m_CustomTraceTimer = -1
			end

			self.m_CustomTraceTimer = 0
		end
	end
end

function ClientNodeEditor:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	-- Only do math on presimulation UpdatePass, don't bother if debugging is off
	if not self.m_Enabled or p_UpdatePass ~= UpdatePass.UpdatePass_PreSim then
		return
	end
	if self.m_HelpTextLocation == Vec2.zero then
		local s_WindowSize = ClientUtils:GetWindowSize()
		-- fun fact, debugtext is 8x15 pixels
		self.m_HelpTextLocation = Vec2(s_WindowSize.x - 256, math.floor(s_WindowSize.y / 2.0 + 0.5) - 195)
	end

	-- doing this here and not in UI:DrawHud prevents a memory leak that crashes you in under a minute
	if self.m_Player ~= nil and self.m_Player.soldier ~= nil and self.m_Player.soldier.worldTransform ~= nil then
		self.m_PlayerPos = self.m_Player.soldier.worldTransform.trans

		self.m_RaycastTimer = self.m_RaycastTimer + p_DeltaTime
		-- do not update node positions if saving or loading
		if not self:IsSavingOrLoading() then

			if self.m_RaycastTimer >= Registry.GAME_RAYCASTING.UPDATE_INTERVAL_NODEEDITOR then
				self.m_RaycastTimer = 0
			
				-- perform raycast to get where player is looking
				if self.m_EditMode == 'move' then
					local s_Selection = m_NodeCollection:GetSelected()

					if #s_Selection > 0 then
						--raycast to 4 meters
						local s_Hit = self:Raycast(4)

						if s_Hit ~= nil then
							if self.editRayHitStart == nil then
								self.editRayHitStart = s_Hit.position
								self.editRayHitCurrent = s_Hit.position
								self.editRayHitRelative = Vec3.zero
							else
								self.editRayHitCurrent = s_Hit.position
								self.editRayHitRelative = self.editRayHitCurrent - self.editRayHitStart
							end
						end

						-- loop selected nodes and update positions
						local s_NodePaths = m_NodeCollection:GetPaths()

						for l_Path, _ in pairs(s_NodePaths) do
							if m_NodeCollection:IsPathVisible(l_Path) then
								local s_PathWaypoints = s_NodePaths[l_Path]

								for i = 1, #s_PathWaypoints do
									if m_NodeCollection:IsSelected(s_PathWaypoints[i]) then
										local s_AdjustedPosition = self.editNodeStartPos[s_PathWaypoints[i].ID] + self.m_EditModeManualOffset

										if self.m_EditPositionMode == 'relative' then
											s_AdjustedPosition = s_AdjustedPosition + (self.editRayHitRelative or Vec3.zero)
										elseif (self.m_EditPositionMode == 'standing') then
											s_AdjustedPosition = self.m_PlayerPos + self.m_EditModeManualOffset
										else
											s_AdjustedPosition = self.editRayHitCurrent + self.m_EditModeManualOffset
										end

										m_NodeCollection:Update(s_PathWaypoints[i], {
											Position = s_AdjustedPosition
										})
									end
								end
							end
						end
					end
				end
			end
			
			-- prepare draw of nodes
			--self:DrawDebugThings(p_DeltaTime)
			self:DrawSomeNodes(Config.NodesPerCycle)
		end

		if self.m_BotVisionEnabled then
			-- bot vision crosshair lines, generate once only
			if self.m_BotVisionCrosshair == nil then
				local s_WindowSize = ClientUtils:GetWindowSize()
				local cx = math.floor(s_WindowSize.x / 2.0 + 0.5)
				local cy = math.floor(s_WindowSize.y / 2.0 + 0.5)

				self.m_BotVisionCrosshair = {
					Vec2(cx - 9, cy - 1), Vec2(cx + 8, cy - 1),
					Vec2(cx - 10, cy), Vec2(cx + 9, cy),
					Vec2(cx - 9, cy + 1), Vec2(cx + 8, cy + 1),

					Vec2(cx - 1, cy - 9), Vec2(cx - 1, cy + 8),
					Vec2(cx, cy - 10), Vec2(cx, cy + 9),
					Vec2(cx + 1, cy - 9), Vec2(cx + 1, cy + 8)
				}
			end

			-- check vision from player to "enemies", only update position if visible
			local s_Players = PlayerManager:GetPlayers()

			for p = 1, #s_Players do
				if s_Players[p].soldier ~= nil and self.m_Player.teamId ~= s_Players[p].teamId then
					local s_Ray = RaycastManager:Raycast(self.m_PlayerPos+Vec3.up, (s_Players[p].soldier.worldTransform.trans+Vec3.up), RayCastFlags.CheckDetailMesh | RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)

					local s_PosData = {
						Visible = (s_Ray == nil or s_Ray.rigidBody == nil),
						Alive = s_Players[p].soldier ~= nil
					}

					if s_PosData.Visible then
						s_PosData.Position = s_Players[p].soldier.worldTransform.trans
					end

					self.m_BotVisionPlayers[s_Players[p].name] = s_PosData
				end
			end
		end    
	end
end

function ClientNodeEditor:OnUIDrawHud()
	if self.m_BotVisionEnabled then
		if self.m_BotVisionCrosshair ~= nil then
			-- all this for a simple + in the middle of the screen
			DebugRenderer:DrawLine2D(self.m_BotVisionCrosshair[1], self.m_BotVisionCrosshair[2], self.m_Colors.Text)
			DebugRenderer:DrawLine2D(self.m_BotVisionCrosshair[3], self.m_BotVisionCrosshair[4], self.m_Colors.Text)
			DebugRenderer:DrawLine2D(self.m_BotVisionCrosshair[5], self.m_BotVisionCrosshair[6], self.m_Colors.Text)
			DebugRenderer:DrawLine2D(self.m_BotVisionCrosshair[7], self.m_BotVisionCrosshair[8], self.m_Colors.Text)
			DebugRenderer:DrawLine2D(self.m_BotVisionCrosshair[9], self.m_BotVisionCrosshair[10], self.m_Colors.Text)
			DebugRenderer:DrawLine2D(self.m_BotVisionCrosshair[11], self.m_BotVisionCrosshair[12], self.m_Colors.Text)
		end

		for k, v in pairs(self.m_BotVisionPlayers) do
			if v ~= nil and v ~= false and v.Position ~= nil then
				local s_ScreenPos = ClientUtils:WorldToScreen(v.Position + (Vec3.up * 0.3))

				if s_ScreenPos ~= nil then
					DebugRenderer:DrawText2D(s_ScreenPos.x, s_ScreenPos.y, k, self.m_Colors.Text, 1)
					s_ScreenPos = nil
				end

				local s_Color = self.m_Colors.Text

				if not v.Alive then
					s_Color = self.m_Colors[1].Line
				else
					if v.Visible then
						s_Color = self.m_Colors[4].Line
					end
				end

				DebugRenderer:DrawSphere(v.Position+(Vec3.up*1.5), 0.15, s_Color, false, false)
				DebugRenderer:DrawSphere(v.Position+(Vec3.up*1.0), 0.3, s_Color, false, false)
				DebugRenderer:DrawSphere(v.Position+(Vec3.up*0.3), 0.2, s_Color, false, false)
			end
		end
	end

	-- dont process waypoints if we're not supposed to see them
	if not self.m_Enabled then
		return
	end

	for _,l_Node in pairs(self.m_NodesToDraw) do
        -- draw speres
        DebugRenderer:DrawSphere(l_Node.pos, l_Node.radius, l_Node.color, l_Node.renderLines, l_Node.smallSizeSegmentDecrease)
    end
    for _,l_Line in pairs(self.m_LinesToDraw) do
        -- draw lines
        DebugRenderer:DrawLine(l_Line.from, l_Line.to, l_Line.colorFrom, l_Line.colorTo)
    end
    for _,l_Text in pairs(self.m_TextToDraw) do
        -- draw text
        DebugRenderer:DrawText2D(l_Text.x, l_Text.y, l_Text.text, l_Text.color, l_Text.scale)
	end
	for _,l_TextPos in pairs(self.m_TextPosToDraw) do
		local s_ScreenPos = ClientUtils:WorldToScreen(l_TextPos.pos)
		if s_ScreenPos ~= nil then
			DebugRenderer:DrawText2D(s_ScreenPos.x, s_ScreenPos.y, l_TextPos.text, l_TextPos.color, l_TextPos.scale)
		end
	end
    for _,l_Obb in pairs(self.m_ObbToDraw) do
        -- draw OBB
        DebugRenderer:DrawOBB(l_Obb.p_Aab, l_Obb.transform, l_Obb.color)
    end
end

function ClientNodeEditor:DrawSphere(p_Position, p_Size, p_Color, p_RenderLines, p_SmallSizeSegmentDecrease)
    table.insert(self.m_NodesToDraw_temp, {
        pos = p_Position,
        radius = p_Size,
        color = p_Color,
        renderLines = p_RenderLines,
        smallSizeSegmentDecrease = p_SmallSizeSegmentDecrease
    })
end

function ClientNodeEditor:DrawLine(p_From, p_To, p_ColorFrom, p_ColorTo)
    table.insert(self.m_LinesToDraw_temp, {
        from = p_From,
        to = p_To,
        colorFrom = p_ColorFrom,
        colorTo = p_ColorTo
    })
end

function ClientNodeEditor:DrawText2D(p_X, p_Y, p_Text, p_Color, p_Scale)
    table.insert(self.m_TextToDraw_temp, {
        x = p_X,
		y = p_Y,
		text = p_Text,
        color = p_Color,
        scale = p_Scale
    })
end

function ClientNodeEditor:DrawPosText2D(p_Pos, p_Text, p_Color, p_Scale)
    table.insert(self.m_TextPosToDraw_temp, {
        pos = p_Pos,
		text = p_Text,
        color = p_Color,
        scale = p_Scale
    })
end

function ClientNodeEditor:DrawOBB(p_Aab, p_Transform, p_Color)
    table.insert(self.m_ObbToDraw_temp, {
        aab = p_Aab,
        transform = p_Transform,
        color = p_Color
    })
end


function ClientNodeEditor:DrawDebugThings(p_DeltaTime)
	-- Bot _onSelectNode
	local s_Botwpcount = 0

	for l_WaypointID, l_Data in pairs(self.m_BotSelectedWaypoints) do
		if l_Data.Timer < 0 then
			self.m_BotSelectedWaypoints[l_WaypointID] = nil
		else
			l_Data.Timer = l_Data.Timer - p_DeltaTime
			s_Botwpcount = s_Botwpcount + 1
		end
	end
	self.m_DebugEntries['botSelectedWaypoints'] = s_Botwpcount

    -- generic debug values
	local s_DebugText = ''

	self.m_DebugEntries['commoRoseEnabled'] = self.m_CommoRoseEnabled
	self.m_DebugEntries['commoRosePressed'] = self.m_CommoRosePressed
	self.m_DebugEntries['commoRoseTimer'] = string.format('%4.2f', self.m_CommoRoseTimer)
	self.m_DebugEntries['commoRoseActive'] = self.m_CommoRoseActive

	for k, v in pairs(self.m_DebugEntries) do
		s_DebugText = s_DebugText .. k..': '..tostring(v).."\n"
	end

	--self:DrawText2D(20, 400, debugText, self.colors.Text, 1)
	-- draw help info
	local s_HelpText = ''

	if self.m_EditMode == 'none' then
		s_HelpText = s_HelpText..' Node Operation Controls '.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..'|   7   |   8   |   9   |'.."\n"
		s_HelpText = s_HelpText..'| Merge | Link  | Split |'.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..'|   4   |   5   |   6   |'.."\n"
		s_HelpText = s_HelpText..'| Move  |Select | Input |'.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..'|   1   |   2   |   3   |'.."\n"
		s_HelpText = s_HelpText..'|Remove |Unlink |  Add  |'.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..'						 '.."\n"
		s_HelpText = s_HelpText..'	  [F12] - Settings   '.."\n"
		s_HelpText = s_HelpText..'	 [Spot] - Quick Select'.."\n"
		s_HelpText = s_HelpText..'[Backspace] - Clear Select'.."\n"
		s_HelpText = s_HelpText..'   [Insert] - Spawn Bot  '.."\n"
		s_HelpText = s_HelpText..'	   [F9] - Save Nodes '.."\n"
		s_HelpText = s_HelpText..'	  [F11] - Load Nodes '.."\n"
	elseif self.m_EditMode == 'move' then
		s_HelpText = s_HelpText..'  Nudge Position Controls '.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..'|   7   |   8   |   9   |'.."\n"
		s_HelpText = s_HelpText..'| Reset |Forward|  Up   |'.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..'|   4   |   5   |   6   |'.."\n"
		s_HelpText = s_HelpText..'| Left  |Finish | Right |'.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..'|   1   |   2   |   3   |'.."\n"
		s_HelpText = s_HelpText..'| Mode  | Back  | Down  |'.."\n"
		s_HelpText = s_HelpText..'+-------+-------+-------+'.."\n"
		s_HelpText = s_HelpText..string.format('|X %+04.2f | Y %+04.2f|', self.m_EditModeManualOffset.x, self.m_EditModeManualOffset.y).."\n"
		s_HelpText = s_HelpText..string.format('|	  Z %+04.2f	   |', self.m_EditModeManualOffset.z).."\n"
		s_HelpText = s_HelpText..'+-----------------------+'.."\n"
		s_HelpText = s_HelpText..' Nudge Speed: '..tostring(self.m_EditModeManualSpeed).."\n"

		if self.m_EditPositionMode == 'relative' then
			s_HelpText = s_HelpText..'   Move Mode: Relative   '.."\n"
		elseif (self.m_EditPositionMode == 'standing') then
			s_HelpText = s_HelpText..'   Move Mode: Standing   '.."\n"
		else
			s_HelpText = s_HelpText..'   Move Mode: Absolute   '.."\n"
		end

		s_HelpText = s_HelpText..'						 '.."\n"
		s_HelpText = s_HelpText..'	  [F12] - Settings	'.."\n"
		s_HelpText = s_HelpText..'	 [Spot] - Finish Move '.."\n"
		s_HelpText = s_HelpText..'[Backspace] - Cancel Move '.."\n"
		s_HelpText = s_HelpText..' [Numpad +] - Nudge Speed +'.."\n"
		s_HelpText = s_HelpText..' [Numpad -] - Nudge Speed -'.."\n"
	end

	--self:DrawText2D(self.helpTextLocation.x, self.helpTextLocation.y, helpText, self.colors.Text, 1)
	-- draw debug selection traces
	if self.debugSelectionRaytraces then
		if self.m_LastTraceStart ~= nil and self.m_LastTraceEnd ~= nil then
			self:DrawLine(self.m_LastTraceStart, self.m_LastTraceEnd, self.m_Colors.Ray.Line[1], self.m_Colors.Ray.Line[2])
		end
		if self.m_LastTraceSearchAreaPos ~= nil and self.m_LastTraceSearchAreaSize ~= nil then
			self:DrawSphere(self.m_LastTraceSearchAreaPos, self.m_LastTraceSearchAreaSize, self.m_Colors.Ray.Node, false, false)
		end
	end
end

function ClientNodeEditor:DrawSomeNodes(p_NrOfNodes)
	if self.m_PlayerPos == nil then
		return false
	end
	local s_FirstPath = true
	local s_Count = 0
	
	-- draw waypoints stored in main collection
	local s_WaypointPaths = m_NodeCollection:GetPaths()

	for l_Path, _ in pairs(s_WaypointPaths) do
		if l_Path >= self.m_lastDrawIndexPath then
			if m_NodeCollection:IsPathVisible(l_Path) then
				local s_startIndex = 1
				if s_FirstPath then
					s_startIndex = self.m_lastDrawIndexNode
					if s_startIndex <= 0 then
						s_startIndex = 1
					end
					s_FirstPath = false
				end

				for l_Waypoint = s_startIndex, #s_WaypointPaths[l_Path] do
					self:_drawNode(s_WaypointPaths[l_Path][l_Waypoint], false)
					s_Count = s_Count + 1
					if s_Count >= p_NrOfNodes then
						self.m_lastDrawIndexNode = l_Waypoint
						self.m_lastDrawIndexPath = l_Path
						return false
					end
				end
			end
		end
	end
	self.m_lastDrawIndexPath = 99999

	-- draw waypoints for custom trace
	if self.m_CustomTrace ~= nil then
		local s_CustomWaypoints = self.m_CustomTrace:Get()

		for i = 1, #s_CustomWaypoints do
			self:_drawNode(s_CustomWaypoints[i], true)
			s_Count = s_Count + 1
			if s_Count >= p_NrOfNodes then
				self.m_lastDrawIndexNode = i
				return false
			end
		end
	end
	
	-- copy tables
	self.m_NodesToDraw = self.m_NodesToDraw_temp
	self.m_NodesToDraw_temp = {}
	self.m_LinesToDraw = self.m_LinesToDraw_temp
	self.m_LinesToDraw_temp = {}
	self.m_TextToDraw = self.m_TextToDraw_temp
	self.m_TextToDraw_temp = {}
	self.m_TextPosToDraw = self.m_TextPosToDraw_temp
	self.m_TextPosToDraw_temp = {}
	self.m_ObbToDraw = self.m_ObbToDraw_temp
	self.m_ObbToDraw_temp = {}

	-- reset vars
	self.m_lastDrawIndexPath = 0
	self.m_lastDrawIndexNode = 0
	collectgarbage('collect')
	return true
end

function ClientNodeEditor:_drawNode(p_Waypoint, p_IsTracePath)
	local s_IsSelected = not p_IsTracePath and m_NodeCollection:IsSelected(p_Waypoint)
	local s_QualityAtRange = m_NodeCollection:InRange(p_Waypoint, self.m_PlayerPos, Config.LineRange)

	-- setup node color information
	local s_Color = self.m_Colors.Orphan

	if p_Waypoint.Previous ~= false and p_Waypoint.Next ~= false then
		-- happens after the 20th path
		if self.m_Colors[p_Waypoint.PathIndex] == nil then
			local r, g, b = (math.random(20, 100) / 100), (math.random(20, 100) / 100), (math.random(20, 100) / 100)
			self.m_Colors[p_Waypoint.PathIndex] = {
				Node = Vec4(r, g, b, 0.25),
				Line = Vec4(r, g, b, 1),
			}
		end

		s_Color = self.m_Colors[p_Waypoint.PathIndex]
	end

	if p_IsTracePath then
		s_Color = {
			Node = self.m_Colors.White,
			Line = self.m_Colors.White,
		}
	end

	-- draw the node for the waypoint itself
	if m_NodeCollection:InRange(p_Waypoint, self.m_PlayerPos, Config.WaypointRange) then
		self:DrawSphere(p_Waypoint.Position, 0.05, s_Color.Node, false, (not s_QualityAtRange))

		if self.m_ScanForNode then
			local s_PointScreenPos = ClientUtils:WorldToScreen(p_Waypoint.Position)

			-- Skip to the next point if this one isn't in view
			if s_PointScreenPos ~= nil then
				local s_Center = ClientUtils:GetWindowSize()/2
				-- Select point if its close to the hitPosition
				if s_Center:Distance(s_PointScreenPos) < 20 then
					self.m_ScanForNode = false
					if s_IsSelected then
						self:Log('Deselect -> %s', p_Waypoint.ID)
						m_NodeCollection:Deselect(p_Waypoint)
						return
					else
						self:Log('Select -> %s', p_Waypoint.ID)
						m_NodeCollection:Select(p_Waypoint)
						return
					end
				end
			end
		end
	end

	-- if bot has selected draw it
	--[[if not p_IsTracePath and self.m_BotSelectedWaypoints[p_Waypoint.ID] ~= nil then
		local s_SelectData = self.m_BotSelectedWaypoints[p_Waypoint.ID]
		if s_SelectData.Obstacle then
			self:DrawLine(s_SelectData.Position + (Vec3.up * 1.2), p_Waypoint.Position, self.m_Colors.Red, self.m_Colors.Red)
		else
			self:DrawLine(s_SelectData.Position + (Vec3.up * 1.2), p_Waypoint.Position, self.m_Colors[s_SelectData.Color], self.m_Colors[s_SelectData.Color])
		end
	end--]]

	-- if selected draw bigger node and transform helper
	if not p_IsTracePath and s_IsSelected and m_NodeCollection:InRange(p_Waypoint, self.m_PlayerPos, Config.WaypointRange) then
		-- node selection indicator
		self:DrawSphere(p_Waypoint.Position, 0.08, s_Color.Node, false, (not s_QualityAtRange))

		-- transform marker
		self:DrawLine(p_Waypoint.Position, p_Waypoint.Position + (Vec3.up), self.m_Colors.Red, self.m_Colors.Red)
		self:DrawLine(p_Waypoint.Position, p_Waypoint.Position + (Vec3.right * 0.5), self.m_Colors.Green, self.m_Colors.Green)
		self:DrawLine(p_Waypoint.Position, p_Waypoint.Position + (Vec3.forward * 0.5), self.m_Colors.Blue, self.m_Colors.Blue)
	end

	-- draw connection lines
	if Config.DrawWaypointLines and m_NodeCollection:InRange(p_Waypoint, self.m_PlayerPos, Config.LineRange) then
		-- try to find a previous node and draw a line to it
		if p_Waypoint.Previous and type(p_Waypoint.Previous) == 'string' then
			p_Waypoint.Previous = m_NodeCollection:Get(p_Waypoint.Previous)
		end

		if p_Waypoint.Previous then
			if (p_Waypoint.PathIndex ~= p_Waypoint.Previous.PathIndex) then
				-- draw a white line between nodes on separate paths
				-- self:DrawLine(p_Waypoint.Previous.Position, p_Waypoint.Position, self.colors.White, self.colors.White)
			else
				-- draw fading line between nodes on same path
				self:DrawLine(p_Waypoint.Previous.Position, p_Waypoint.Position, s_Color.Line, s_Color.Line)
			end
		end

		if p_Waypoint.Data and p_Waypoint.Data.LinkMode ~= nil and p_Waypoint.Data.Links ~= nil then
			for i = 1, #p_Waypoint.Data.Links do
				local s_LinkedWaypoint = m_NodeCollection:Get(p_Waypoint.Data.Links[i])

				if s_LinkedWaypoint ~= nil then
					-- draw lines between linked nodes
					self:DrawLine(s_LinkedWaypoint.Position, p_Waypoint.Position, self.m_Colors.Purple, self.m_Colors.Purple)
				end
			end
		end
	end

	-- draw debugging text
	if Config.DrawWaypointIDs and m_NodeCollection:InRange(p_Waypoint, self.m_PlayerPos, Config.TextRange) then
		if s_IsSelected then
			-- don't try to precalc this value like with the distance, another memory leak crash awaits you
			local s_PreviousNode = tostring(p_Waypoint.Previous)
			local s_NextNode = tostring(p_Waypoint.Next)
			local s_PathNode = m_NodeCollection:GetFirst(p_Waypoint.PathIndex)

			if type(p_Waypoint.Previous) == 'table' then
				s_PreviousNode = p_Waypoint.Previous.ID
			end

			if type(p_Waypoint.Next) == 'table' then
				s_NextNode = p_Waypoint.Next.ID
			end

			local s_SpeedMode = 'N/A'

			if p_Waypoint.SpeedMode == 0 then s_SpeedMode = 'Wait' end

			if p_Waypoint.SpeedMode == 1 then s_SpeedMode = 'Prone' end

			if p_Waypoint.SpeedMode == 2 then s_SpeedMode = 'Crouch' end

			if p_Waypoint.SpeedMode == 3 then s_SpeedMode = 'Walk' end

			if p_Waypoint.SpeedMode == 4 then s_SpeedMode = 'Sprint' end


			local s_ExtraMode = 'N/A'

			if p_Waypoint.ExtraMode == 1 then s_ExtraMode = 'Jump' end

			local s_OptionValue = 'N/A'

			if p_Waypoint.SpeedMode == 0 then
				s_OptionValue = tostring(p_Waypoint.OptValue)..' Seconds'
			end

			local s_PathMode = 'Loops'

			if s_PathNode then
				if (s_PathNode.OptValue == 0XFF) then
					s_PathMode = 'Reverses'
				end
			end

			local s_Text = ''
			s_Text = s_Text..string.format("(%s)Pevious [ %s ] Next(%s)\n", s_PreviousNode, p_Waypoint.ID, s_NextNode)
			s_Text = s_Text..string.format("Index[%d]\n", p_Waypoint.Index)
			s_Text = s_Text..string.format("Path[%d][%d] (%s)\n", p_Waypoint.PathIndex, p_Waypoint.PointIndex, s_PathMode)
			s_Text = s_Text..string.format("Path Objectives: %s\n", g_Utilities:dump(s_PathNode.Data.Objectives, false))
			s_Text = s_Text..string.format("Vehicles: %s\n", g_Utilities:dump(s_PathNode.Data.Vehicles, false))
			s_Text = s_Text..string.format("InputVar: %d\n", p_Waypoint.InputVar)
			s_Text = s_Text..string.format("SpeedMode: %s (%d)\n", s_SpeedMode, p_Waypoint.SpeedMode)
			s_Text = s_Text..string.format("ExtraMode: %s (%d)\n", s_ExtraMode, p_Waypoint.ExtraMode)
			s_Text = s_Text..string.format("OptValue: %s (%d)\n", s_OptionValue, p_Waypoint.OptValue)
			s_Text = s_Text..'Data: '..g_Utilities:dump(p_Waypoint.Data, true)

			self:DrawPosText2D(p_Waypoint.Position + Vec3.up, s_Text, self.m_Colors.Text, 1.2)
		else
			-- don't try to precalc this value like with the distance, another memory leak crash awaits you
			self:DrawPosText2D(p_Waypoint.Position + (Vec3.up * 0.05), tostring(p_Waypoint.ID), self.m_Colors.Text, 1)
		end
	end
end

-- ################# Node sending and retrieval
-- ############################################

-- request a fresh node list from the server
-- or server has told us be ready to receive
function ClientNodeEditor:_onGetNodes(p_Args)
	self:Log('Getting Nodes: %s', tostring(p_Args))

	-- unload our current cache
	self:_onUnload(p_Args)
	-- enable the timer before we are ready to receive
	self.m_NodeReceiveTimer = 0
	return true
end

-- server is ready to receive our nodes
function ClientNodeEditor:_onSendNodes(p_Args)
	self.m_NodesToSend = m_NodeCollection:Get()
	self:Log('Sending Nodes: %d', #self.m_NodesToSend)

	if self.m_NodesToSend == nil or #self.m_NodesToSend < 1 then
		self:Log('Client has 0 Nodes, Cancelling Send!')
		return false
	else
		self.m_NodeSendTimer = 0
		return true
	end
end

function ClientNodeEditor:_onServerCreateNode(p_Data)
	m_NodeCollection:Create(p_Data, true)
	self.m_NodeReceiveProgress = self.m_NodeReceiveProgress + 1
	self.m_DebugEntries['nodeReceiveProgress'] = self.m_NodeReceiveProgress..'/'..(self.m_NodeReceiveExpected)
end

-- node payload has finished sending, setup events and calc indexes
function ClientNodeEditor:_onInit()
	m_NodeCollection:RecalculateIndexes()
	m_NodeCollection:ProcessMetadata()

	local s_Waypoints = m_NodeCollection:Get()
	self.m_Player = PlayerManager:GetLocalPlayer()

	local s_StaleNodes = 0

	self:Log('Receved Nodes: %d', #s_Waypoints)

	for i = 1, #s_Waypoints do
		local s_Waypoint = s_Waypoints[i]

		if type(s_Waypoint.Next) == 'string' then
			s_StaleNodes = s_StaleNodes+1
		end

		if type(s_Waypoint.Previous) == 'string' then
			s_StaleNodes = s_StaleNodes+1
		end
	end

	if s_StaleNodes > 0 then
		self:Log('Warning! Stale Nodes: %d', s_StaleNodes)
	end

	self.m_NodeOperation = ''
end

-- stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
function ClientNodeEditor:Raycast(p_MaxDistance, p_UseAsync)
	if self.m_Player == nil then
		return
	end

	p_MaxDistance = p_MaxDistance or 100

	-- We get the camera transform, from which we will start the raycast. We get the direction from the forward vector. Camera transform
	-- is inverted, so we have to invert this vector.
	local s_Transform = ClientUtils:GetCameraTransform()
	local s_Direction = Vec3(-s_Transform.forward.x, -s_Transform.forward.y, -s_Transform.forward.z)

	if s_Transform.trans == Vec3.zero then
		return
	end

	local s_CastStart = s_Transform.trans

	-- We get the raycast end transform with the calculated direction and the max distance.
	local s_CastEnd = Vec3(
		s_Transform.trans.x + (s_Direction.x * p_MaxDistance),
		s_Transform.trans.y + (s_Direction.y * p_MaxDistance),
		s_Transform.trans.z + (s_Direction.z * p_MaxDistance))

	-- Perform raycast, returns a RayCastHit object.

	local s_Flags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh

	if p_UseAsync then
		s_Flags = s_Flags | RayCastFlags.IsAsyncRaycast
	end

	local s_RaycastHit = RaycastManager:Raycast(s_CastStart, s_CastEnd, s_Flags)

	return s_RaycastHit
end

if g_ClientNodeEditor == nil then
	g_ClientNodeEditor = ClientNodeEditor()
end

return g_ClientNodeEditor
