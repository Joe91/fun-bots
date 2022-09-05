---@class ClientNodeEditor
---@overload fun():ClientNodeEditor
ClientNodeEditor = class "ClientNodeEditor"

require('__shared/Config')

---@type NodeCollection
local m_NodeCollection = require('__shared/NodeCollection')
---@type Logger
local m_Logger = Logger("ClientNodeEditor", Debug.Client.NODEEDITOR)

function ClientNodeEditor:__init()
	-- Data Points
	self.m_LastDataPoint = nil
	self.m_DataPoints = {}
	self.m_TempDataPoints = {}

	self.m_ScanForNode = false

	-- caching values for drawing performance
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


	self.m_NodeOperation = ''

	self.m_BotSelectedWaypoints = {}

	self.m_Colors = {
		["Text"] = Vec4(1, 1, 1, 1),
		["White"] = Vec4(1, 1, 1, 1),
		["Red"] = Vec4(1, 0, 0, 1),
		["Green"] = Vec4(0, 1, 0, 1),
		["Blue"] = Vec4(0, 0, 1, 1),
		["Purple"] = Vec4(0.5, 0, 1, 1),
		["Ray"] = { Node = Vec4(1, 1, 1, 0.2), Line = { Vec4(1, 1, 1, 1), Vec4(0, 0, 0, 1) } },
		["Orphan"] = { Node = Vec4(0, 0, 0, 0.5), Line = Vec4(0, 0, 0, 1) },
		{ Node = Vec4(1, 0, 0, 0.25), Line = Vec4(1, 0, 0, 1) },
		{ Node = Vec4(1, 0.55, 0, 0.25), Line = Vec4(1, 0.55, 0, 1) },
		{ Node = Vec4(1, 1, 0, 0.25), Line = Vec4(1, 1, 0, 1) },
		{ Node = Vec4(0, 0.5, 0, 0.25), Line = Vec4(0, 0.5, 0, 1) },
		{ Node = Vec4(0, 0, 1, 0.25), Line = Vec4(0, 0, 1, 1) },
		{ Node = Vec4(0.29, 0, 0.51, 0.25), Line = Vec4(0.29, 0, 0.51, 1) },
		{ Node = Vec4(1, 0, 1, 0.25), Line = Vec4(1, 0, 1, 1) },
		{ Node = Vec4(0.55, 0, 0, 0.25), Line = Vec4(0.55, 0, 0, 1) },
		{ Node = Vec4(1, 0.65, 0, 0.25), Line = Vec4(1, 0.65, 0, 1) },
		{ Node = Vec4(0.94, 0.9, 0.55, 0.25), Line = Vec4(0.94, 0.9, 0.55, 1) },
		{ Node = Vec4(0.5, 1, 0, 0.25), Line = Vec4(0.5, 1, 0, 1) },
		{ Node = Vec4(0.39, 0.58, 0.93, 0.25), Line = Vec4(0.39, 0.58, 0.93, 1) },
		{ Node = Vec4(0.86, 0.44, 0.58, 0.25), Line = Vec4(0.86, 0.44, 0.58, 1) },
		{ Node = Vec4(0.93, 0.51, 0.93, 0.25), Line = Vec4(0.93, 0.51, 0.93, 1) },
		{ Node = Vec4(1, 0.63, 0.48, 0.25), Line = Vec4(1, 0.63, 0.48, 1) },
		{ Node = Vec4(0.5, 0.5, 0, 0.25), Line = Vec4(0.5, 0.5, 0, 1) },
		{ Node = Vec4(0, 0.98, 0.6, 0.25), Line = Vec4(0, 0.98, 0.6, 1) },
		{ Node = Vec4(0.18, 0.31, 0.31, 0.25), Line = Vec4(0.18, 0.31, 0.31, 1) },
		{ Node = Vec4(0, 1, 1, 0.25), Line = Vec4(0, 1, 1, 1) },
		{ Node = Vec4(1, 0.08, 0.58, 0.25), Line = Vec4(1, 0.08, 0.58, 1) },
	}

	self.m_LastTraceSearchAreaPos = nil
	self.m_LastTraceSearchAreaSize = nil
	self.m_LastTraceStart = nil
	self.m_LastTraceEnd = nil

	self.m_DebugEntries = {}
	self.m_EventsReady = false
end

function ClientNodeEditor:OnRegisterEvents()
	-- simple check to make sure we don't reregister things if they are already done
	if self.m_EventsReady then return end

	NetEvents:Subscribe('UI_ClientNodeEditor_TraceData', self, self._OnUiTraceData)
	NetEvents:Subscribe('ClientNodeEditor:DrawNodes', self, self._OnDrawNodes)

	-- enable/disable events
	-- ('UI_CommoRose_Enabled', <Bool|Enabled>) -- true == block the BF3 commo rose
	NetEvents:Subscribe('UI_CommoRose_Enabled', self, self._onSetCommoRoseEnabled)

	-- selection-based events, no arguments required
	-- NetEvents:Subscribe('UI_CommoRose_Action_Save', self, self._onSaveNodes)
	-- NetEvents:Subscribe('UI_CommoRose_Action_Load', self, self._onLoadNodes)

	NetEvents:Subscribe('UI_CommoRose_Action_Select', self, self._onSelectNode)
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
	-- NetEvents:Subscribe('ClientNodeEditor:SaveNodes', self, self._onSaveNodes)
	-- NetEvents:Subscribe('ClientNodeEditor:ReceiveNodes', self, self._onGetNodes)
	-- NetEvents:Subscribe('ClientNodeEditor:SendNodes', self, self._onSendNodes)
	-- NetEvents:Subscribe('ClientNodeEditor:Create', self, self._onServerCreateNode)
	-- NetEvents:Subscribe('ClientNodeEditor:Init', self, self._onInit)

	-- trace recording events
	-- NetEvents:Subscribe('ClientNodeEditor:StartTrace', self, self._onStartTrace)
	-- NetEvents:Subscribe('ClientNodeEditor:EndTrace', self, self._onEndTrace)
	-- NetEvents:Subscribe('ClientNodeEditor:ClearTrace', self, self._onClearTrace)
	-- NetEvents:Subscribe('ClientNodeEditor:SaveTrace', self, self._onSaveTrace)


	-- UI Commands as Console commands
	-- Console:Register('Save', 'Send waypoints to server for saving to file', self, self._onSaveNodes)
	-- Console:Register('Load', 'Resend all waypoints and lose all changes', self, self._onGetNodes)

	--add these Events to NodeEditor
	Console:Register('Select', 'Select or Deselect the waypoint you are looking at', self, self._onSelectNode) --done
	Console:Register('Remove', 'Remove selected waypoints', self, self._onRemoveNode)
	Console:Register('Unlink', 'Unlink two waypoints', self, self._onUnlinkNode)
	Console:Register('Merge', 'Merge selected waypoints', self, self._onMergeNode)
	Console:Register('SelectPrevious', 'Extend selection to previous waypoint', self, self._onSelectPrevious) --done
	Console:Register('ClearSelection', 'Clear selection', self, self._onClearSelection) --done
	Console:Register('Move', 'toggle move mode on selected waypoints', self, self._onToggleMoveNode)

	--add these Events to NodeEditor
	Console:Register('Add', 'Create a new waypoint after the selected one', self, self._onAddNode)
	Console:Register('Link', 'Link two waypoints', self, self._onLinkNode)
	Console:Register('Split', 'Split selected waypoints', self, self._onSplitNode)
	Console:Register('SelectNext', 'Extend selection to next waypoint', self, self._onSelectNext)
	Console:Register('SelectBetween', 'Select all waypoint between start and end of selection', self, self._onSelectBetween)
	Console:Register('SetInput',
		'<number|0-15> <number|0-15> <number|0-255> - Sets input variables for the selected waypoints', self,
		self._onSetInputNode)

	Console:Register('TraceShow', '\'all\' or <number|PathIndex> - Show trace\'s waypoints', self, self._onShowPath)
	Console:Register('TraceHide', '\'all\' or <number|PathIndex> - Hide trace\'s waypoints', self, self._onHidePath)
	Console:Register('WarpTo', '*<string|WaypointID>* Teleport yourself to the specified Waypoint ID', self, self._onWarpTo)
	Console:Register('SpawnAtWaypoint', '', self, self._onSpawnAtWaypoint)

	-- Console:Register('StartTrace', 'Begin recording a new trace', self, self._onStartTrace)
	-- Console:Register('EndTrace', 'Stop recording a new trace', self, self._onEndTrace)
	-- Console:Register('ClearTrace', 'Clear all nodes from recorded trace', self, self._onClearTrace)
	-- Console:Register('SaveTrace', '<number|PathIndex> Merge new trace with current waypoints', self, self._onSaveTrace)

	-- debugging commands, not meant for UI
	Console:Register('Enabled', 'Enable / Disable the waypoint editor', self, self.OnSetEnabled)
	Console:Register('CommoRoseEnabled', 'Enable / Disable the waypoint editor Commo Rose', self,
		self._onSetCommoRoseEnabled)
	Console:Register('CommoRoseShow', 'Show custom Commo Rose', self, self._onShowRose)
	Console:Register('CommoRoseHide', 'Hide custom Commo Rose', self, self._onHideRose)
	Console:Register('SetMetadata', '<string|Data> - Set Metadata for waypoint, Must be valid JSON string', self,
		self._onSetMetadata)

	-- add these Events for NodeEditor
	Console:Register('AddObjective', '<string|Objective> - Add an objective to a path', self, self._onAddObjective)
	Console:Register('AddMcom', 'Add an MCOM Arm/Disarm-Action to a point', self, self._onAddMcom)
	Console:Register('AddVehicle', 'Add a vehicle a bot can use', self, self._onAddVehicle)
	Console:Register('ExitVehicle',
		'<bool|OnlyPassengers> Add a point where all bots or only the passengers leaves the vehicle', self, self._onExitVehicle)
	Console:Register('AddVehiclePath', '<string|Type> Add vehicle-usage to a path. Types = land, water, air', self,
		self._onAddVehiclePath)
	Console:Register('RemoveObjective', '<string|Objective> - Remove an objective from a path', self,
		self._onRemoveObjective)
	Console:Register('RemoveData', 'Remove all data of one or several nodes', self, self._onRemoveData)


	Console:Register('ProcessMetadata', 'Process waypoint metadata starting with selected nodes or all nodes', self,
		self._onProcessMetadata)
	Console:Register('RecalculateIndexes', 'Recalculate Indexes starting with selected nodes or all nodes', self,
		self._onRecalculateIndexes)
	Console:Register('DumpNodes', 'Print selected nodes or all nodes to console', self, self._onDumpNodes)
	Console:Register('UnloadNodes', 'Clears and unloads all clientside nodes', self, self._onUnload)

	-- Console:Register('ObjectiveDirection', 'Show best direction to given objective', self, self._onObjectiveDirection)
	-- Console:Register('GetKnownObjectives', 'print all known objectives and associated paths', self,	self._onGetKnownObjectives)

	self.m_EventsReady = true
	self:Log('Register Events')
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

function ClientNodeEditor:_OnUiTraceData(p_TotalTraceNodes, p_TotalTraceDistance, p_TraceIndex, p_Enable)
	if p_Enable ~= nil then
		g_FunBotUIClient:_onUITrace(p_Enable)
	end
	if p_TraceIndex ~= nil then
		g_FunBotUIClient:_onUITraceIndex(p_TraceIndex)
	end
	if p_TotalTraceNodes ~= nil then
		g_FunBotUIClient:_onUITraceWaypoints(p_TotalTraceNodes)
	end
	if p_TotalTraceDistance ~= nil then
		g_FunBotUIClient:_onUITraceWaypointsDistance(p_TotalTraceDistance)
	end
end

function ClientNodeEditor:_OnDrawNodes(p_NodesToDraw, p_UpdateView)
	for _, l_NodeData in pairs(p_NodesToDraw) do
		self:_DrawData(l_NodeData)
		table.insert(self.m_TempDataPoints, l_NodeData)
	end

	if p_UpdateView then
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

		self.m_DataPoints = self.m_TempDataPoints
		self.m_TempDataPoints = {}
	end

end

function ClientNodeEditor:_DrawData(p_DataPoint)
	--[[local s_DataNode = {
		Node = l_Node,
		DrawNode = s_DrawNode,
		DrawLine = s_DrawLine,
		DrawText = s_DrawText,
		IsSelected = s_IsSelected,
		Objectives = s_FirstNode.Data.Objectives,
		Vehicles = s_FirstNode.Data.Vehicles,
		Reverse = (s_FirstNode.OptValue == 0XFF),
		Links = s_LinkPositions,
		IsTrace = false,
		IsOthersTrace = false
	}--]]

	local s_IsSelected = p_DataPoint.IsSelected
	local s_QualityAtRange = p_DataPoint.DrawLine
	local s_IsTracePath = p_DataPoint.IsTrace
	local s_IsOtherTracePath = false
	local s_Waypoint = p_DataPoint.Node

	-- setup node color information
	local s_Color = self.m_Colors.Orphan

	-- happens after the 20th path --TODO: add more colors?
	if self.m_Colors[s_Waypoint.PathIndex] == nil then
		local r, g, b = (math.random(20, 100) / 100), (math.random(20, 100) / 100), (math.random(20, 100) / 100)
		self.m_Colors[s_Waypoint.PathIndex] = {
			Node = Vec4(r, g, b, 0.25),
			Line = Vec4(r, g, b, 1),
		}
	end

	s_Color = self.m_Colors[s_Waypoint.PathIndex]


	if s_IsTracePath then
		s_Color = {
			Node = self.m_Colors.White,
			Line = self.m_Colors.White,
		}
	end

	-- draw the node for the waypoint itself
	if p_DataPoint.DrawNode then
		self:DrawSphere(s_Waypoint.Position, 0.05, s_Color.Node, false, (not s_QualityAtRange))

		if self.m_ScanForNode then
			local s_PointScreenPos = ClientUtils:WorldToScreen(s_Waypoint.Position)

			-- Skip to the next point if this one isn't in view
			if s_PointScreenPos ~= nil then
				local s_Center = ClientUtils:GetWindowSize() / 2

				-- Select point if its close to the hitPosition
				if s_Center:Distance(s_PointScreenPos) < 20 then
					self.m_ScanForNode = false

					if s_IsSelected then
						self:Log('Deselect -> %s', s_Waypoint.ID)
						NetEvents:SendLocal('NodeEditor:Deselect', s_Waypoint.ID)
						return
					else
						self:Log('Select -> %s', s_Waypoint.ID)
						NetEvents:SendLocal('NodeEditor:Select', s_Waypoint.ID)
						return
					end
				end
			end
		end
	end

	-- if selected draw bigger node and transform helper
	if not s_IsTracePath and s_IsSelected and p_DataPoint.DrawNode then
		-- node selection indicator
		self:DrawSphere(s_Waypoint.Position, 0.08, s_Color.Node, false, (not s_QualityAtRange))

		-- transform marker
		self:DrawLine(s_Waypoint.Position, s_Waypoint.Position + (Vec3.up), self.m_Colors.Red, self.m_Colors.Red)
		self:DrawLine(s_Waypoint.Position, s_Waypoint.Position + (Vec3.right * 0.5), self.m_Colors.Green, self.m_Colors.Green)
		self:DrawLine(s_Waypoint.Position, s_Waypoint.Position + (Vec3.forward * 0.5), self.m_Colors.Blue, self.m_Colors.Blue)
	end

	-- draw connection lines
	if Config.DrawWaypointLines and p_DataPoint.DrawLine then
		-- try to find a previous node and draw a line to it
		if self.m_LastDataPoint and self.m_LastDataPoint.Node.PathIndex == s_Waypoint.PathIndex then
			self:DrawLine(self.m_LastDataPoint.Node.Position, s_Waypoint.Position, s_Color.Line, s_Color.Line)
		end

		-- draw Links
		if s_Waypoint.Data and s_Waypoint.Data.LinkMode ~= nil and s_Waypoint.Data.Links ~= nil then
			for _, l_LinkPos in pairs(p_DataPoint.Links) do
				self:DrawLine(l_LinkPos, s_Waypoint.Position, self.m_Colors.Purple, self.m_Colors.Purple)
			end
		end
	end

	-- draw debugging text
	if Config.DrawWaypointIDs and p_DataPoint.DrawText then
		if s_IsSelected then
			-- don't try to precalc this value like with the distance, another memory leak crash awaits you
			-- local s_PreviousNode = tostring(p_Waypoint.Previous)
			-- local s_NextNode = tostring(p_Waypoint.Next)

			-- if type(p_Waypoint.Previous) == 'table' then
			-- 	s_PreviousNode = p_Waypoint.Previous.ID
			-- end

			-- if type(p_Waypoint.Next) == 'table' then
			-- 	s_NextNode = p_Waypoint.Next.ID
			-- end

			local s_SpeedMode = 'N/A'

			if s_Waypoint.SpeedMode == 0 then s_SpeedMode = 'Wait' end

			if s_Waypoint.SpeedMode == 1 then s_SpeedMode = 'Prone' end

			if s_Waypoint.SpeedMode == 2 then s_SpeedMode = 'Crouch' end

			if s_Waypoint.SpeedMode == 3 then s_SpeedMode = 'Walk' end

			if s_Waypoint.SpeedMode == 4 then s_SpeedMode = 'Sprint' end

			local s_ExtraMode = 'N/A'

			if s_Waypoint.ExtraMode == 1 then s_ExtraMode = 'Jump' end

			local s_OptionValue = 'N/A'

			if s_Waypoint.SpeedMode == 0 then
				s_OptionValue = tostring(s_Waypoint.OptValue) .. ' Seconds'
			end

			local s_PathMode = 'Loops'
			if p_DataPoint.Reverse then
				s_PathMode = 'Reverses'
			end

			local s_Text = ''
			-- s_Text = s_Text .. string.format("(%s)Pevious [ %s ] Next(%s)\n", s_PreviousNode, p_Waypoint.ID, s_NextNode)
			s_Text = s_Text .. string.format("Index[%d]\n", s_Waypoint.Index)
			s_Text = s_Text .. string.format("Path[%d][%d] (%s)\n", s_Waypoint.PathIndex, s_Waypoint.PointIndex, s_PathMode)
			s_Text = s_Text .. string.format("Path Objectives: %s\n", g_Utilities:dump(p_DataPoint.Objectives, false))
			s_Text = s_Text .. string.format("Vehicles: %s\n", g_Utilities:dump(p_DataPoint.Vehicles, false))
			s_Text = s_Text .. string.format("InputVar: %d\n", s_Waypoint.InputVar)
			s_Text = s_Text .. string.format("SpeedMode: %s (%d)\n", s_SpeedMode, s_Waypoint.SpeedMode)
			s_Text = s_Text .. string.format("ExtraMode: %s (%d)\n", s_ExtraMode, s_Waypoint.ExtraMode)
			s_Text = s_Text .. string.format("OptValue: %s (%d)\n", s_OptionValue, s_Waypoint.OptValue)
			s_Text = s_Text .. 'Data: ' .. g_Utilities:dump(s_Waypoint.Data, true)

			self:DrawPosText2D(s_Waypoint.Position + Vec3.up, s_Text, self.m_Colors.Text, 1.2)
		else
			-- don't try to precalc this value like with the distance, another memory leak crash awaits you
			self:DrawPosText2D(s_Waypoint.Position + (Vec3.up * 0.05), tostring(s_Waypoint.ID), self.m_Colors.Text, 1)
		end
	end

	self.m_LastDataPoint = {}
	for l_Key, l_Value in pairs(p_DataPoint) do
		self.m_LastDataPoint[l_Key] = l_Value
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

function ClientNodeEditor:GetDistance(p_Position1, p_Position2)
	local s_PosA = p_Position1 or Vec3.zero
	local s_PosB = p_Position2 or Vec3.zero
	local s_DiffX = math.abs(s_PosA.x - s_PosB.x)
	local s_DiffY = math.abs(s_PosA.y - s_PosB.y)
	local s_DiffZ = math.abs(s_PosA.z - s_PosB.z)
	if s_DiffX > s_DiffZ then
		return s_DiffX + 0.5 * s_DiffZ + 0.25 * s_DiffY
	else
		return s_DiffZ + 0.5 * s_DiffX + 0.25 * s_DiffY
	end
end

function ClientNodeEditor:FindNode(p_Position)
	local s_ClosestNode = nil
	local s_ClosestDistance = nil
	for _, l_DataNode in pairs(self.m_DataPoints) do
		local s_Distance = self:GetDistance(l_DataNode.Node.Position, p_Position)
		if not s_ClosestDistance or s_ClosestDistance > s_Distance then
			s_ClosestDistance = s_Distance
			s_ClosestNode = l_DataNode
		end
	end
	--[[if s_ClosestDistance < 1 then
		return s_ClosestNode
	else
		return nil
	end ]]
	return s_ClosestNode
end

function ClientNodeEditor:_onSelectNode(p_Args)
	local s_Hit = self:Raycast()

	if s_Hit == nil then
		self.m_ScanForNode = true
		return
	end

	local s_HitPoint = self:FindNode(s_Hit.position)

	if s_HitPoint then
		if s_HitPoint.IsSelected then
			NetEvents:SendLocal('NodeEditor:Deselect', s_HitPoint.Node.ID)
		else
			NetEvents:SendLocal('NodeEditor:Select', s_HitPoint.Node.ID)
		end
	end
end

-- ####################### commo rose left side
-- ############################################

function ClientNodeEditor:_onRemoveNode(p_Args)
	NetEvents:SendLocal('NodeEditor:RemoveNode')
end

function ClientNodeEditor:_onUnlinkNode()
	NetEvents:SendLocal('NodeEditor:UnlinkNodes')
end

function ClientNodeEditor:_onMergeNode(p_Args)
	NetEvents:SendLocal('NodeEditor:MergeNode')
end

function ClientNodeEditor:_onSelectPrevious()
	NetEvents:SendLocal('NodeEditor:SelectPrevious')
end

function ClientNodeEditor:_onClearSelection(p_Args)
	NetEvents:SendLocal('NodeEditor:ClearSelection')
end

function ClientNodeEditor:_onToggleMoveNode(p_Args)
	self.m_CommoRoseActive = false
	local s_Player = PlayerManager:GetLocalPlayer()

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
				{ Grid = 'K1', Key = '1', Name = 'Remove' },
				{ Grid = 'K2', Key = '2', Name = 'Unlink' },
				{ Grid = 'K3', Key = '3', Name = 'Add' },
				{ Grid = 'K4', Key = '4', Name = 'Move' },
				{ Grid = 'K5', Key = '5', Name = 'Select' },
				{ Grid = 'K6', Key = '6', Name = 'Input' },
				{ Grid = 'K7', Key = '7', Name = 'Merge' },
				{ Grid = 'K8', Key = '8', Name = 'Link' },
				{ Grid = 'K9', Key = '9', Name = 'Split' }
			},
			Other = {
				{ Key = 'F12', Name = 'Settings' },
				{ Key = 'Q', Name = 'Quick Select' },
				{ Key = 'BS', Name = 'Clear Select' },
				{ Key = 'INS', Name = 'Spawn Bot' }
			}
		})

		self:Log('Edit Mode: %s', self.m_EditMode)
		return true
	else
		if s_Player == nil or s_Player.soldier == nil then
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
				{ Grid = 'K1', Key = '1', Name = 'Mode' },
				{ Grid = 'K2', Key = '2', Name = 'Back' },
				{ Grid = 'K3', Key = '3', Name = 'Down' },
				{ Grid = 'K4', Key = '4', Name = 'Left' },
				{ Grid = 'K5', Key = '5', Name = 'Finish' },
				{ Grid = 'K6', Key = '6', Name = 'Right' },
				{ Grid = 'K7', Key = '7', Name = 'Reset' },
				{ Grid = 'K8', Key = '8', Name = 'Forward' },
				{ Grid = 'K9', Key = '9', Name = 'Up' },
			},
			Other = {
				{ Key = 'F12', Name = 'Settings' },
				{ Key = 'Q', Name = 'Finish Move' },
				{ Key = 'BS', Name = 'Cancel Move' },
				{ Key = 'KP_PLUS', Name = 'Speed +' },
				{ Key = 'KP_MINUS', Name = 'Speed -' },
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
	NetEvents:SendLocal('NodeEditor:LinkNodes')
end

function ClientNodeEditor:_onSplitNode(p_Args)
	NetEvents:SendLocal('NodeEditor:SplitNode')
end

function ClientNodeEditor:_onSelectNext()
	NetEvents:SendLocal('NodeEditor:SelectNext')
end

function ClientNodeEditor:_onSelectBetween()
	NetEvents:SendLocal('NodeEditor:SelectBetween')
end

function ClientNodeEditor:_onSetInputNode(p_Args)
	NetEvents:SendLocal('NodeEditor:SetInputNode', p_Args[1], p_Args[2], p_Args[3])
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
	local s_Player = PlayerManager:GetLocalPlayer()

	if s_Player == nil or s_Player.soldier == nil then
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

function ClientNodeEditor:_onAddMcom()
	NetEvents:SendLocal('NodeEditor:AddMcom')
end

function ClientNodeEditor:_onAddVehicle(p_Args)
	NetEvents:SendLocal('NodeEditor:AddVehicle')
end

function ClientNodeEditor:_onExitVehicle(p_Args)
	NetEvents:SendLocal('NodeEditor:ExitVehicle', p_Args)
end

function ClientNodeEditor:_onAddVehiclePath(p_Args)
	NetEvents:SendLocal('NodeEditor:AddVehiclePath', p_Args)
end

-- EVENTS for editing
function ClientNodeEditor:_onAddObjective(p_Args)
	NetEvents:SendLocal('NodeEditor:AddObjective', p_Args)
end

function ClientNodeEditor:_onRemoveObjective(p_Args)
	NetEvents:SendLocal('NodeEditor:RemoveObjective', p_Args)
end

function ClientNodeEditor:_onRemoveData(p_Args)
	NetEvents:Subscribe('NodeEditor:RemoveData')
end

function ClientNodeEditor:_onRecalculateIndexes(p_Args)
	self.m_CommoRoseActive = false

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

	local s_Selection = m_NodeCollection:GetSelected()
	local s_Firstnode = nil

	if #s_Selection > 0 then
		s_Firstnode = s_Selection[1]
	end

	m_NodeCollection:ProcessMetadata(s_Firstnode)
	return true
end

--[[ function ClientNodeEditor:_onObjectiveDirection(p_Args)
	self.m_CommoRoseActive = false

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
	self:Log('Known Objectives -> ' .. g_Utilities:dump(m_NodeCollection:GetKnownObjectives(), true))
	return true
end ]]

-- ##################################### Events
-- ############################################

---VEXT Client Level:Loaded Event
---@param p_LevelName string
---@param p_GameMode string
function ClientNodeEditor:OnLevelLoaded(p_LevelName, p_GameMode)
	self.m_Enabled = Config.DebugTracePaths

	if self.m_Enabled then
		self.m_NodeReceiveTimer = 0 -- enable the timer for receiving nodes
	end
end

---VEXT Client Player:Deleted Event
---@param p_Player Player
function ClientNodeEditor:OnPlayerDeleted(p_Player)
	local s_Player = PlayerManager:GetLocalPlayer()
	if s_Player ~= nil and p_Player ~= nil and s_Player.name == p_Player.name then
		self:_onUnload()
	end
end

---VEXT Shared Level:Destroy Event
function ClientNodeEditor:OnLevelDestroy()
	self:_onUnload()
end

function ClientNodeEditor:_onUnload(p_Args)
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
		return
	end
end

---VEXT Client UI:PushScreen Hook
---@param p_HookCtx HookContext
---@param p_Screen DataContainer
---@param p_Priority UIGraphPriority
---@param p_ParentGraph DataContainer
---@param p_StateNodeGuid Guid|nil
function ClientNodeEditor:OnUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
	if self.m_Enabled and self.m_CommoRoseEnabled and p_Screen ~= nil and
		UIScreenAsset(p_Screen).name == 'UI/Flow/Screen/CommRoseScreen' then
		self:Log('Blocked vanilla commo rose')
		p_HookCtx:Return()
		return
	end

	p_HookCtx:Pass(p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
end

-- ############################## Update Events
-- ############################################

---VEXT Client Client:UpdateInput Event
---@param p_DeltaTime number
function ClientNodeEditor:OnClientUpdateInput(p_DeltaTime)
	if not self.m_Enabled then
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
				self:_onSelectNode()
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
			self:_onClearSelection()
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

---VEXT Shared UpdateManager:Update Event
---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function ClientNodeEditor:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if true then
		return
	end


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
	local s_Player = PlayerManager:GetLocalPlayer()
	if s_Player ~= nil and s_Player.soldier ~= nil and s_Player.soldier.worldTransform ~= nil then
		self.m_PlayerPos = s_Player.soldier.worldTransform.trans:Clone()

		self.m_RaycastTimer = self.m_RaycastTimer + p_DeltaTime
		-- do not update node positions if saving or loading
		if true then
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
			-- self:DrawSomeNodes(Config.NodesPerCycle)
			-- collectgarbage("step", 1000)
		end
	end
end

---VEXT Client UI:DrawHud Event
function ClientNodeEditor:OnUIDrawHud()
	-- dont process waypoints if we're not supposed to see them
	if not self.m_Enabled then
		return
	end

	for _, l_Node in pairs(self.m_NodesToDraw) do
		-- draw speres
		DebugRenderer:DrawSphere(l_Node.pos, l_Node.radius, l_Node.color, l_Node.renderLines, l_Node.smallSizeSegmentDecrease)
	end

	for _, l_Line in pairs(self.m_LinesToDraw) do
		-- draw lines
		DebugRenderer:DrawLine(l_Line.from, l_Line.to, l_Line.colorFrom, l_Line.colorTo)
	end

	for _, l_Text in pairs(self.m_TextToDraw) do
		-- draw text
		DebugRenderer:DrawText2D(l_Text.x, l_Text.y, l_Text.text, l_Text.color, l_Text.scale)
	end

	for _, l_TextPos in pairs(self.m_TextPosToDraw) do
		local s_ScreenPos = ClientUtils:WorldToScreen(l_TextPos.pos)

		if s_ScreenPos ~= nil then
			DebugRenderer:DrawText2D(s_ScreenPos.x, s_ScreenPos.y, l_TextPos.text, l_TextPos.color, l_TextPos.scale)
		end
	end

	for _, l_Obb in pairs(self.m_ObbToDraw) do
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

-- stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
function ClientNodeEditor:Raycast(p_MaxDistance, p_UseAsync)
	local s_Player = PlayerManager:GetLocalPlayer()
	if not s_Player then
		print("no Player")
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

	local s_Flags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll |
		RayCastFlags.CheckDetailMesh

	if p_UseAsync then
		s_Flags = s_Flags | RayCastFlags.IsAsyncRaycast
	end

	local s_RaycastHit = RaycastManager:Raycast(s_CastStart, s_CastEnd, s_Flags)

	return s_RaycastHit
end

if g_ClientNodeEditor == nil then
	---@type ClientNodeEditor
	g_ClientNodeEditor = ClientNodeEditor()
end

return g_ClientNodeEditor
