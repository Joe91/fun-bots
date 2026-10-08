---@class ClientNodeEditor
---@overload fun():ClientNodeEditor
ClientNodeEditor = class('ClientNodeEditor')

require('__shared/Config')

---@type Logger
local m_Logger = Logger('ClientNodeEditor', Debug.Client.NODEEDITOR)
---@type ClientSpawnPointHelper
local m_ClientSpawnPointHelper = require('ClientSpawnPointHelper')
local m_Utilities = require('__shared/Utilities')

local m_SpeedModeNames = { [0] = 'Wait', 'Prone', 'Crouch', 'Walk', 'Sprint' }

-- The walking mesh is drawn from a grid of cells (meters, horizontally), and only rebuilt after the player moved that far.
local NAV_ZONE_CELL = 16.0
local NAV_ZONE_REBUILD_DISTANCE = 2.0

function ClientNodeEditor:__init()
	-- new Mode stuff
	self.m_WayPoints = {}
	self.m_WayPointsById = {}
	self.m_CurrentTrace = {}
	self.m_Selections = {}
	self.m_SelectionSet = {}
	self.m_RequestDataSent = false
	self.m_LastUpdateIndex = 0
	self.m_FirstNodeInPath = {}
	self.m_PathsToSkipForCycles = {}
	self.m_MinDistanceToPath = {}

	self.m_ScanForNode = false

	-- The walking mesh (server: NavZones): "@mesh" -> { Points, Edges, Junctions }, zone name -> { Name, Kind, Center, Size }.
	self.m_NavZones = {}
	-- What gets drawn of the mesh. Rebuilt by _UpdateNavZoneDraw when the player moved or something changed.
	self.m_NavZoneSpheres = {}
	self.m_NavZoneLines = {}
	self.m_NavZoneTexts = {}
	self.m_NavZoneDrawState = nil

	-- Caching values for drawing performance.
	self.m_PlayerPos = nil

	self.m_Enabled = Config.DebugTracePaths

	self.m_CommoRosePressed = false
	self.m_CommoRoseActive = false
	self.m_CommoRoseTimer = -1
	self.m_CommoRoseDelay = 0.25

	self.m_EditMode = 'none' -- 'Move', 'none', 'area'
	self.m_EditNodeStartPos = {}
	self.m_EditModeManualOffset = Vec3.zero
	self.m_EditModeManualSpeed = 0.05
	self.m_EditPositionMode = 'relative'

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

	self.m_Colors = {
		['Text'] = Vec4(1, 1, 1, 1),
		['White'] = Vec4(1, 1, 1, 1),
		['Red'] = Vec4(1, 0, 0, 1),
		['Green'] = Vec4(0, 1, 0, 1),
		['Blue'] = Vec4(0, 0, 1, 1),
		['Purple'] = Vec4(0.5, 0, 1, 1),
		['Ray'] = { Node = Vec4(1, 1, 1, 0.2), Line = { Vec4(1, 1, 1, 1), Vec4(0, 0, 0, 1) } },
		['Orphan'] = { Node = Vec4(0, 0, 0, 0.5), Line = Vec4(0, 0, 0, 1) },
		{ Node = Vec4(1, 0, 0, 0.25),          Line = Vec4(1, 0, 0, 1) },
		{ Node = Vec4(1, 0.55, 0, 0.25),       Line = Vec4(1, 0.55, 0, 1) },
		{ Node = Vec4(1, 1, 0, 0.25),          Line = Vec4(1, 1, 0, 1) },
		{ Node = Vec4(0, 0.5, 0, 0.25),        Line = Vec4(0, 0.5, 0, 1) },
		{ Node = Vec4(0, 0, 1, 0.25),          Line = Vec4(0, 0, 1, 1) },
		{ Node = Vec4(0.29, 0, 0.51, 0.25),    Line = Vec4(0.29, 0, 0.51, 1) },
		{ Node = Vec4(1, 0, 1, 0.25),          Line = Vec4(1, 0, 1, 1) },
		{ Node = Vec4(0.55, 0, 0, 0.25),       Line = Vec4(0.55, 0, 0, 1) },
		{ Node = Vec4(1, 0.65, 0, 0.25),       Line = Vec4(1, 0.65, 0, 1) },
		{ Node = Vec4(0.94, 0.9, 0.55, 0.25),  Line = Vec4(0.94, 0.9, 0.55, 1) },
		{ Node = Vec4(0.5, 1, 0, 0.25),        Line = Vec4(0.5, 1, 0, 1) },
		{ Node = Vec4(0.39, 0.58, 0.93, 0.25), Line = Vec4(0.39, 0.58, 0.93, 1) },
		{ Node = Vec4(0.86, 0.44, 0.58, 0.25), Line = Vec4(0.86, 0.44, 0.58, 1) },
		{ Node = Vec4(0.93, 0.51, 0.93, 0.25), Line = Vec4(0.93, 0.51, 0.93, 1) },
		{ Node = Vec4(1, 0.63, 0.48, 0.25),    Line = Vec4(1, 0.63, 0.48, 1) },
		{ Node = Vec4(0.5, 0.5, 0, 0.25),      Line = Vec4(0.5, 0.5, 0, 1) },
		{ Node = Vec4(0, 0.98, 0.6, 0.25),     Line = Vec4(0, 0.98, 0.6, 1) },
		{ Node = Vec4(0.18, 0.31, 0.31, 0.25), Line = Vec4(0.18, 0.31, 0.31, 1) },
		{ Node = Vec4(0, 1, 1, 0.25),          Line = Vec4(0, 1, 1, 1) },
		{ Node = Vec4(1, 0.08, 0.58, 0.25),    Line = Vec4(1, 0.08, 0.58, 1) },
	}
	-- Shared color tables, so GetColor doesn't create new ones for every node.
	self.m_TraceColor = { Node = self.m_Colors.White, Line = self.m_Colors.White }
	self.m_NoPathColor = { Node = self.m_Colors.Red, Line = self.m_Colors.Red }
	self.m_NavPathColor = { Node = Vec4(0.35, 0.8, 0.9, 0.35), Line = Vec4(0.35, 0.8, 0.9, 1) }
	-- Walking networks: points in the zone, points around it, connections, junctions with the waypoints.
	self.m_NavZoneColors = {
		Inside = Vec4(0.3, 0.85, 0.45, 0.6),
		Outside = Vec4(0.45, 0.6, 0.75, 0.5),
		Edge = Vec4(0.3, 0.85, 0.45, 1),
		EdgeOutside = Vec4(0.45, 0.6, 0.75, 1),
		Junction = Vec4(1, 0.72, 0.25, 1),
		Text = Vec4(0.3, 0.85, 0.45, 1),
	}

	self.m_EventsReady = false
end

function ClientNodeEditor:OnRegisterEvents()
	-- Simple check to make sure we don't reregister things if they are already done.
	if self.m_EventsReady then return end

	NetEvents:Subscribe('UI_ClientNodeEditor_TraceData', self, self._OnUiTraceData)
	NetEvents:Subscribe('ClientNodeEditor:PrintLog', self, self._OnPrintServerLog)
	NetEvents:Subscribe('ClientNodeEditor:ReceiveNodes', self, self._OnReceiveNodes)
	NetEvents:Subscribe('ClientNodeEditor:UpdateNodes', self, self._OnUpdateNodes)
	NetEvents:Subscribe('ClientNodeEditor:RemoveNodes', self, self._OnRemoveNodes)
	NetEvents:Subscribe('ClientNodeEditor:AddNodes', self, self._OnAddNodes)
	NetEvents:Subscribe('ClientNodeEditor:UpdateSelection', self, self._OnUpdateSelection)
	NetEvents:Subscribe('ClientNodeEditor:ClearCustomTrace', self, self._OnClearCustomTrace)
	NetEvents:Subscribe('ClientNodeEditor:ClearTrace', self, self._OnClearTrace)
	NetEvents:Subscribe('ClientNodeEditor:ClearAll', self, self._OnClearAll)
	NetEvents:Subscribe('ClientNodeEditor:ClearNavZones', self, self._OnClearNavZones)
	NetEvents:Subscribe('ClientNodeEditor:ReceiveNavZone', self, self._OnReceiveNavZone)

	NetEvents:Subscribe('UI_CommoRose_Action_Select', self, self._onSelectNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Remove', self, self._onRemoveNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Unlink', self, self._onUnlinkNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Merge', self, self._onMergeNode)
	NetEvents:Subscribe('UI_CommoRose_Action_SelectPrevious', self, self._onSelectPrevious)
	NetEvents:Subscribe('UI_CommoRose_Action_ClearSelections', self, self._onClearSelection)
	NetEvents:Subscribe('UI_CommoRose_Action_Move', self, self._onToggleMoveNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Add', self, self._onAddNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Link', self, self._onLinkNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Split', self, self._onSplitNode)
	NetEvents:Subscribe('UI_CommoRose_Action_SelectNext', self, self._onSelectNext)
	NetEvents:Subscribe('UI_CommoRose_Action_SelectBetween', self, self._onSelectBetween)
	NetEvents:Subscribe('UI_CommoRose_Action_SetInput', self, self._onSetInputNode)
	NetEvents:Subscribe('ClientNodeEditor:SelectNewNode', self, self._onSelectNewNode)

	-- Add these Events to NodeEditor.
	Console:Register('Select', 'Select or Deselect the waypoint you are looking at', self, self._onSelectNode) -- Done
	Console:Register('Remove', 'Remove selected waypoints', self, self._onRemoveNode)
	Console:Register('Unlink', 'Unlink two waypoints', self, self._onUnlinkNode)
	Console:Register('Merge', 'Merge selected waypoints', self, self._onMergeNode)
	Console:Register('SelectPrevious', 'Extend selection to previous waypoint', self, self._onSelectPrevious) -- Done
	Console:Register('ClearSelection', 'Clear selection', self, self._onClearSelection)                    -- Done
	Console:Register('Move', 'toggle move mode on selected waypoints', self, self._onToggleMoveNode)

	-- Add these Events to NodeEditor.
	Console:Register('Add', 'Create a new waypoint after the selected one', self, self._onAddNode)
	Console:Register('Link', 'Link two waypoints', self, self._onLinkNode)
	Console:Register('Split', 'Split selected waypoints', self, self._onSplitNode)
	Console:Register('SelectNext', 'Extend selection to next waypoint', self, self._onSelectNext)
	Console:Register('SelectBetween', 'Select all waypoint between start and end of selection', self, self._onSelectBetween)
	Console:Register('SetInput',
		'<number|0-15> <number|0-15> <number|0-255> - Sets input variables for the selected waypoints', self,
		self._onSetInputNode)


	-- Debugging commands, not meant for UI.
	Console:Register('Enabled', 'Enable / Disable the waypoint editor', self, self.OnSetEnabled)

	-- Add these Events for NodeEditor.
	Console:Register('AddObjective', '<string|Objective> - Add an objective to a path', self, self._onAddObjective)
	Console:Register('AddMcom', 'Add an MCOM Arm/Disarm-Action to a point', self, self._onAddMcom)
	Console:Register('AddVehicle', 'Add a vehicle a bot can use', self, self._onAddVehicle)
	Console:Register('ExitVehicle',
		'<bool|OnlyPassengers> Add a point where all bots or only the passengers leaves the vehicle', self, self._onExitVehicle)
	Console:Register('CustomAction', '<string|ActionType> Add custom action to a point', self, self._onCustomAction)
	Console:Register('AddVehiclePath', '<string|Type> Add vehicle-usage to a path. Types = land, water, air', self,
		self._onAddVehiclePath)
	Console:Register('AddVehicleSpawn', 'Makes an already existing vehicle-path spawnable', self, self._onSetVehicleSpawn)
	Console:Register('RemoveObjective', '<string|Objective> - Remove an objective from a path', self,
		self._onRemoveObjective)
	Console:Register('RemoveAllObjectives', 'Remove all objectives from a path', self, self._onRemoveAllObjectives)
	Console:Register('SetPathLoops', '<bool|Loop> - manually set loop-mode of selected path', self, self._onSetLoopMode)
	Console:Register('AddSpawnPath', 'Makes a spawn-path of this path.', self, self._onSetSpawnPath)


	self.m_EventsReady = true
	self.m_RequestDataSent = false
end

function ClientNodeEditor:Log(...)
	m_Logger:Write('ClientNodeEditor: ' .. Language:I18N(...))
end

function ClientNodeEditor:_OnPrintServerLog(p_Message)
	m_Logger:Write('NodeEditor: ' .. p_Message)
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
	end
end

function ClientNodeEditor:_OnUiTraceData(p_TotalTraceNodes, p_TotalTraceDistance, p_TraceIndex, p_Enable, p_TraceNodes)
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

	if p_TraceNodes ~= nil then
		self:_OnAddToCustomTrace(p_TraceNodes)
	end
end

function ClientNodeEditor:_OnReceiveNodes(p_WayPoints)
	print('[ClientNodeEditor] Receiving waypoints from server...')
	self.m_WayPoints = p_WayPoints or {}
	print('[ClientNodeEditor] Received ' .. tostring(#self.m_WayPoints) .. ' waypoints from server.')
	self.m_FirstNodeInPath = {}
	self.m_WayPointsById = {}
	for i = 1, #self.m_WayPoints do
		self.m_WayPointsById[self.m_WayPoints[i].ID] = self.m_WayPoints[i]
		local l_Node = self.m_WayPoints[i]
		if self.m_FirstNodeInPath[l_Node.PathIndex] == nil and l_Node.PointIndex == 1 then
			self.m_FirstNodeInPath[l_Node.PathIndex] = l_Node
			self.m_PathsToSkipForCycles[l_Node.PathIndex] = 0
		end
	end
end

function ClientNodeEditor:_OnClearNavZones()
	self.m_NavZones = {}
	self.m_NavZoneDrawState = nil
end

---@param p_X number
---@param p_Z number
---@return integer
local function _NavZoneCellKey(p_X, p_Z)
	return (math.floor(p_X / NAV_ZONE_CELL) + 32768) * 65536 + (math.floor(p_Z / NAV_ZONE_CELL) + 32768)
end

---@param p_Cells table<integer, integer[]>
---@param p_X number
---@param p_Z number
---@param p_Index integer
local function _AddToNavZoneCell(p_Cells, p_X, p_Z, p_Index)
	local s_Key = _NavZoneCellKey(p_X, p_Z)
	local s_Cell = p_Cells[s_Key]
	if s_Cell == nil then
		s_Cell = {}
		p_Cells[s_Key] = s_Cell
	end
	s_Cell[#s_Cell + 1] = p_Index
end

---Calls p_Callback with every index in the cells within p_Range (horizontally) of the position.
---@param p_Cells table<integer, integer[]>
---@param p_X number
---@param p_Z number
---@param p_Range number
---@param p_Callback fun(p_Index: integer)
local function _ForEachInNavZoneCells(p_Cells, p_X, p_Z, p_Range, p_Callback)
	local s_MinX = math.floor((p_X - p_Range) / NAV_ZONE_CELL)
	local s_MaxX = math.floor((p_X + p_Range) / NAV_ZONE_CELL)
	local s_MinZ = math.floor((p_Z - p_Range) / NAV_ZONE_CELL)
	local s_MaxZ = math.floor((p_Z + p_Range) / NAV_ZONE_CELL)
	for l_CellX = s_MinX, s_MaxX do
		for l_CellZ = s_MinZ, s_MaxZ do
			local s_Cell = p_Cells[(l_CellX + 32768) * 65536 + (l_CellZ + 32768)]
			if s_Cell ~= nil then
				for l_Index = 1, #s_Cell do
					p_Callback(s_Cell[l_Index])
				end
			end
		end
	end
end

---Takes plain coordinates of the points and junctions (a field of a Vec3 is a call into the engine) and puts them into
---cells, together with the connections of each point. So drawing only looks at the mesh around the player.
function ClientNodeEditor:_OnReceiveNavZone(p_Zone)
	if type(p_Zone) ~= 'table' or p_Zone.Name == nil then
		return
	end

	if p_Zone.Points ~= nil then
		local s_Points = p_Zone.Points
		local s_PointCells = {}
		for l_Index = 1, #s_Points do
			local l_Point = s_Points[l_Index]
			local s_Position = l_Point.Position
			l_Point.X, l_Point.Y, l_Point.Z = s_Position.x, s_Position.y, s_Position.z
			l_Point.IsInside = (l_Point.Flags or 0) & 1 ~= 0
			_AddToNavZoneCell(s_PointCells, l_Point.X, l_Point.Z, l_Index)
		end

		local s_PointEdges = {}
		local s_Edges = p_Zone.Edges or {}
		for l_Index = 1, #s_Edges do
			local l_Edge = s_Edges[l_Index]
			s_PointEdges[l_Edge.From] = s_PointEdges[l_Edge.From] or {}
			s_PointEdges[l_Edge.From][#s_PointEdges[l_Edge.From] + 1] = l_Index
			s_PointEdges[l_Edge.To] = s_PointEdges[l_Edge.To] or {}
			s_PointEdges[l_Edge.To][#s_PointEdges[l_Edge.To] + 1] = l_Index
		end

		local s_JunctionCells = {}
		local s_Junctions = p_Zone.Junctions or {}
		for l_Index = 1, #s_Junctions do
			local l_Junction = s_Junctions[l_Index]
			local s_Position = l_Junction.Position
			l_Junction.X, l_Junction.Y, l_Junction.Z = s_Position.x, s_Position.y, s_Position.z
			_AddToNavZoneCell(s_JunctionCells, l_Junction.X, l_Junction.Z, l_Index)
		end

		p_Zone.PointCells = s_PointCells
		p_Zone.PointEdges = s_PointEdges
		p_Zone.JunctionCells = s_JunctionCells
	end

	self.m_NavZones[p_Zone.Name] = p_Zone
	self.m_NavZoneDrawState = nil
end

function ClientNodeEditor:_OnUpdateSelection(p_Data)
	self.m_Selections = p_Data or {}
	self.m_SelectionSet = {}

	for l_Index = 1, #self.m_Selections do
		self.m_SelectionSet[self.m_Selections[l_Index]] = true
	end
end

function ClientNodeEditor:_OnAddToCustomTrace(p_Data)
	for l_Index = 1, #p_Data do
		local l_TraceNode = p_Data[l_Index]
		self.m_CurrentTrace[#self.m_CurrentTrace + 1] = l_TraceNode
	end
end

function ClientNodeEditor:_OnClearCustomTrace()
	self.m_CurrentTrace = {}
end

function ClientNodeEditor:_OnClearTrace(p_PathIndex)
	self:_RemoveWaypoints(function(p_Waypoint)
		return p_Waypoint.PathIndex == p_PathIndex
	end)
	self.m_FirstNodeInPath[p_PathIndex] = nil
end

---Removes all waypoints matching the filter in a single pass.
---@param p_ShouldRemove fun(p_Waypoint: table): boolean
function ClientNodeEditor:_RemoveWaypoints(p_ShouldRemove)
	local s_Count = #self.m_WayPoints
	local s_Kept = 0

	for l_Index = 1, s_Count do
		local l_Waypoint = self.m_WayPoints[l_Index]

		if p_ShouldRemove(l_Waypoint) then
			self.m_WayPointsById[l_Waypoint.ID] = nil

			if self.m_FirstNodeInPath[l_Waypoint.PathIndex] == l_Waypoint then
				self.m_FirstNodeInPath[l_Waypoint.PathIndex] = nil
			end
		else
			s_Kept = s_Kept + 1
			self.m_WayPoints[s_Kept] = l_Waypoint
		end
	end

	for l_Index = s_Count, s_Kept + 1, -1 do
		self.m_WayPoints[l_Index] = nil
	end
end

function ClientNodeEditor:_OnClearAll()
	self:_onUnload()
end

function ClientNodeEditor:_OnAddNodes(p_Data)
	for l_Index = 1, #p_Data do
		local l_NodeData = p_Data[l_Index]
		local l_NodeId = l_NodeData.ID
		-- already listed
		if self.m_WayPointsById[l_NodeId] then
			goto continue
		end
		self.m_WayPoints[#self.m_WayPoints + 1] = l_NodeData
		if l_NodeData.PointIndex == 1 then
			self.m_FirstNodeInPath[l_NodeData.PathIndex] = l_NodeData
			self.m_PathsToSkipForCycles[l_NodeData.PathIndex] = 0
		end
		self.m_WayPointsById[l_NodeData.ID] = l_NodeData
		::continue::
	end
end

function ClientNodeEditor:_OnRemoveNodes(p_Data)
	local s_IdsToRemove = {}

	for l_Index = 1, #p_Data do
		s_IdsToRemove[p_Data[l_Index].ID] = true
	end

	self:_RemoveWaypoints(function(p_Waypoint)
		return s_IdsToRemove[p_Waypoint.ID] == true
	end)
end

function ClientNodeEditor:_OnUpdateNodes(p_Data)
	for l_Index = 1, #p_Data do
		local l_Node = self.m_WayPointsById[p_Data[l_Index].ID]

		if l_Node ~= nil then
			m_Utilities:mergeKeys(l_Node, p_Data[l_Index])

			if l_Node.PointIndex == 1 then
				self.m_FirstNodeInPath[l_Node.PathIndex] = l_Node
			end
		end
	end
end

function ClientNodeEditor:GetColor(p_Node, p_IsTracePath)
	if p_IsTracePath then
		return self.m_TraceColor
	end

	-- The paths of the routes (trimmed at the mesh) all have the same color.
	local s_First = self.m_FirstNodeInPath[p_Node.PathIndex]
	if s_First ~= nil and s_First.Data ~= nil and s_First.Data.Nav ~= nil then
		return self.m_NavPathColor
	end

	if p_Node.PathIndex > 0 then
		if self.m_Colors[p_Node.PathIndex] == nil then
			local r, g, b = (math.random(20, 100) / 100), (math.random(20, 100) / 100), (math.random(20, 100) / 100)
			self.m_Colors[p_Node.PathIndex] = {
				Node = Vec4(r, g, b, 0.25),
				Line = Vec4(r, g, b, 1),
			}
		end

		return self.m_Colors[p_Node.PathIndex]
	end

	return self.m_NoPathColor
end

function ClientNodeEditor:GetIsSelected(p_NodeId, p_IsTracePath)
	return not p_IsTracePath and self.m_SelectionSet[p_NodeId] == true
end

function ClientNodeEditor:OnUISettings(p_Data)
	if p_Data == false then -- Client closed settings.
		-- Saving the settings overwrites Config with the server values, so an open editor has to stay enabled.
		self:OnSetEnabled(g_FunBotUIClient.m_InWaypointEditor or Config.DebugTracePaths)
	end
end

---Called after the server sent new settings. Drops the cached path visibility, so changed ranges apply right away.
function ClientNodeEditor:OnSettingsChanged()
	self.m_PathsToSkipForCycles = {}
	self.m_MinDistanceToPath = {}
	self.m_NavZoneDrawState = nil
end

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

---@param p_Position Vec3
---@return nil
function ClientNodeEditor:FindNode(p_Position)
	local s_ClosestNode = nil
	local s_ClosestDistance = 0.6 -- Maximum 0.6 meter.
	for l_Index = 1, #self.m_WayPoints do
		local l_DataNode = self.m_WayPoints[l_Index]
		local s_Distance = m_Utilities:DistanceFast(l_DataNode.Position, p_Position) -- was: self:GetDistance
		if s_ClosestDistance > s_Distance then
			s_ClosestDistance = s_Distance
			s_ClosestNode = l_DataNode
		end
	end

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
		if self:GetIsSelected(s_HitPoint.ID) then
			NetEvents:SendLocal('NodeEditor:Deselect', s_HitPoint.ID)
		else
			NetEvents:SendLocal('NodeEditor:Select', s_HitPoint.ID)
		end
		return
	end

	self.m_ScanForNode = true
end

function ClientNodeEditor:_onRemoveNode()
	NetEvents:SendLocal('NodeEditor:RemoveNode')
end

function ClientNodeEditor:_onUnlinkNode()
	NetEvents:SendLocal('NodeEditor:UnlinkNodes')
end

function ClientNodeEditor:_onMergeNode()
	NetEvents:SendLocal('NodeEditor:MergeNodes')
end

function ClientNodeEditor:_onSelectPrevious()
	NetEvents:SendLocal('NodeEditor:SelectPrevious')
end

function ClientNodeEditor:_onClearSelection()
	NetEvents:SendLocal('NodeEditor:ClearSelection')
end

function ClientNodeEditor:_onSpawnBot()
	NetEvents:SendLocal('NodeEditor:SpawnBot')
end

function ClientNodeEditor:GetSelectedNodes()
	local s_Selection = {}
	for s_Index = 1, #self.m_Selections do
		s_Selection[#s_Selection + 1] = self.m_WayPointsById[self.m_Selections[s_Index]]
	end

	return s_Selection
end

function ClientNodeEditor:_onToggleMoveNode(p_Args)
	local s_Player = PlayerManager:GetLocalPlayer()

	if self.m_EditMode == 'move' then
		self.m_EditMode = 'none'

		self.editRayHitStart = nil
		self.m_EditModeManualOffset = Vec3.zero

		-- Move was cancelled.
		if p_Args ~= nil and p_Args == true then
			self:Log('Move Cancelled')

			local s_UpdateData = {}
			local s_Selection = self:GetSelectedNodes()

			for i = 1, #s_Selection do
				local s_UpdateNode = {
					ID = s_Selection[i].ID,
					Pos = self.m_EditNodeStartPos[s_Selection[i].ID],
				}
				s_UpdateData[#s_UpdateData + 1] = s_UpdateNode
			end

			NetEvents:SendLocal('NodeEditor:UpdatePos', s_UpdateData)
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
				{ Key = 'Q',   Name = 'Quick Select' },
				{ Key = 'BS',  Name = 'Clear Select' },
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

		local s_Selection = self:GetSelectedNodes()

		if #s_Selection < 1 then
			self:Log('Must select at least one node')
			return false
		end

		self.m_EditNodeStartPos = {}

		for i = 1, #s_Selection do
			self.m_EditNodeStartPos[i] = s_Selection[i].Position:Clone()
			self.m_EditNodeStartPos[s_Selection[i].ID] = s_Selection[i].Position:Clone()
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
				{ Key = 'F12',      Name = 'Settings' },
				{ Key = 'Q',        Name = 'Finish Move' },
				{ Key = 'BS',       Name = 'Cancel Move' },
				{ Key = 'KP_PLUS',  Name = 'Speed +' },
				{ Key = 'KP_MINUS', Name = 'Speed -' },
			}
		})

		self:Log('Edit Mode: %s', self.m_EditMode)
		return true
	end
end

function ClientNodeEditor:_onAddNode(p_Args)
	NetEvents:SendLocal('NodeEditor:AddNode')
end

function ClientNodeEditor:_onSelectNewNode(p_NewDataNodeId)
	self:_OnUpdateSelection({ p_NewDataNodeId })
	self.m_EditPositionMode = 'absolute'
	self:_onToggleMoveNode()
end

function ClientNodeEditor:_onLinkNode()
	NetEvents:SendLocal('NodeEditor:LinkNodes')
end

function ClientNodeEditor:_onTeleportToEdge(p_Args)
	NetEvents:SendLocal('NodeEditor:TeleportToEdge')
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

function ClientNodeEditor:_onAddMcom()
	NetEvents:SendLocal('NodeEditor:AddMcom')
end

function ClientNodeEditor:_onAddVehicle(p_Args)
	NetEvents:SendLocal('NodeEditor:AddVehicle')
end

function ClientNodeEditor:_onExitVehicle(p_Args)
	NetEvents:SendLocal('NodeEditor:ExitVehicle', p_Args)
end

function ClientNodeEditor:_onCustomAction(p_Args)
	NetEvents:SendLocal('NodeEditor:CustomAction', p_Args)
end

function ClientNodeEditor:_onAddVehiclePath(p_Args)
	NetEvents:SendLocal('NodeEditor:AddVehiclePath', p_Args)
end

function ClientNodeEditor:_onSetVehicleSpawn(p_Args)
	NetEvents:SendLocal('NodeEditor:SetVehicleSpawn', p_Args)
end

function ClientNodeEditor:_onAddObjective(p_Args)
	NetEvents:SendLocal('NodeEditor:AddObjective', p_Args)
end

function ClientNodeEditor:_onRemoveObjective(p_Args)
	NetEvents:SendLocal('NodeEditor:RemoveObjective', p_Args)
end

function ClientNodeEditor:_onRemoveAllObjectives(p_Args)
	NetEvents:SendLocal('NodeEditor:RemoveAllObjectives', p_Args)
end

function ClientNodeEditor:_onSetLoopMode(p_Args)
	NetEvents:SendLocal('NodeEditor:SetPathLoops', p_Args)
end

function ClientNodeEditor:_onSetSpawnPath(p_Args)
	NetEvents:SendLocal('NodeEditor:AddSpawnPath', p_Args)
end

function ClientNodeEditor:_onRemoveData()
	NetEvents:SendLocal('NodeEditor:RemoveData')
end

-- ============================================
-- Events
-- ============================================

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

function ClientNodeEditor:_onUnload()
	-- new Mode stuff
	self.m_WayPoints = {}
	self.m_CurrentTrace = {}
	self.m_Selections = {}
	self.m_SelectionSet = {}
	self.m_RequestDataSent = false
	self.m_LastUpdateIndex = 0
	self.m_FirstNodeInPath = {}
	self.m_PathsToSkipForCycles = {}
	self.m_MinDistanceToPath = {}
	self.m_NavZones = {}
	self.m_NavZoneSpheres = {}
	self.m_NavZoneLines = {}
	self.m_NavZoneTexts = {}
	self.m_NavZoneDrawState = nil

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
end

---VEXT Client UI:PushScreen Hook
---@param p_HookCtx HookContext
---@param p_Screen DataContainer
---@param p_Priority UIGraphPriority
---@param p_ParentGraph DataContainer
---@param p_StateNodeGuid Guid|nil
function ClientNodeEditor:OnUIPushScreen(p_HookCtx, p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
	if self.m_Enabled and
		self.m_CommoRoseEnabled and
		p_Screen ~= nil and
		UIScreenAsset(p_Screen).name == 'UI/Flow/Screen/CommoRoseScreen' then
		p_HookCtx:Return()
		return
	end

	p_HookCtx:Pass(p_Screen, p_Priority, p_ParentGraph, p_StateNodeGuid)
end

-- ============================================
-- Update Events
-- ============================================

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

		-- Pressed and released without triggering Commo Rose.
		if self.m_CommoRosePressed and not s_CommButtonDown then
			if self.m_EditMode == 'move' then
				self:_onToggleMoveNode()
			else
				self:_onSelectNode()
			end
		end

		self.m_CommoRosePressed = (s_Comm1 or s_Comm2 or s_Comm3)
	end
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_Space) then --InputManager:WentDown(InputConceptIdentifiers.ConceptJump)
		NetEvents:SendLocal('NodeEditor:JumpDetected')
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
			-- Reserved for switching to area mode (not implemented).
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

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_T) then
			self:_onTeleportToEdge()
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
			self:_onSpawnBot()
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
	if not self.m_Enabled or p_UpdatePass ~= UpdatePass.UpdatePass_PreSim then
		return
	end

	-- request data if not done yet
	if not self.m_RequestDataSent then
		NetEvents:SendLocal('NodeEditor:RequestData')
		self.m_RequestDataSent = true
		return
	end

	-- Doing this here and not in UI:DrawHud prevents a memory leak that crashes you in under a minute.
	local s_Player = PlayerManager:GetLocalPlayer()
	if s_Player and s_Player.soldier and s_Player.soldier.worldTransform then
		self.m_PlayerPos = s_Player.soldier.worldTransform.trans:Clone()

		self.m_RaycastTimer = self.m_RaycastTimer + p_DeltaTime
		-- Do not update node positions if saving or loading.
		if true then
			if self.m_RaycastTimer >= Registry.GAME_RAYCASTING.UPDATE_INTERVAL_NODEEDITOR then
				self.m_RaycastTimer = 0

				-- Perform raycast to get where player is looking.
				if self.m_EditMode == 'move' then
					local s_Selection = self:GetSelectedNodes()

					if #s_Selection > 0 then
						-- Raycast to 4 meters.
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

						-- Loop selected nodes and update positions.
						local s_UpdateData = {}

						for i = 1, #s_Selection do
							local s_AdjustedPosition = self.m_EditNodeStartPos[s_Selection[i].ID] + self.m_EditModeManualOffset

							if self.m_EditPositionMode == 'relative' then
								s_AdjustedPosition = s_AdjustedPosition + (self.editRayHitRelative or Vec3.zero)
							elseif (self.m_EditPositionMode == 'standing') then
								s_AdjustedPosition = self.m_PlayerPos + self.m_EditModeManualOffset
							else
								s_AdjustedPosition = self.editRayHitCurrent + self.m_EditModeManualOffset
							end

							local s_UpdateNode = {
								ID = s_Selection[i].ID,
								Pos = s_AdjustedPosition,
							}
							s_UpdateData[#s_UpdateData + 1] = s_UpdateNode
						end

						NetEvents:SendLocal('NodeEditor:UpdatePos', s_UpdateData)
					end
				end
			end
		end
	end

	-- prepare data to draw
	if s_Player and s_Player.soldier and self.m_PlayerPos then
		local s_PlayerX, s_PlayerY, s_PlayerZ = self.m_PlayerPos.x, self.m_PlayerPos.y, self.m_PlayerPos.z

		-- Ranges are compared squared, so they are real meters without a square root per node.
		local s_WaypointRangeSq = Config.WaypointRange * Config.WaypointRange
		local s_LineRangeSq = Config.DrawWaypointLines and Config.LineRange * Config.LineRange or -1
		local s_TextRangeSq = Config.DrawWaypointIDs and Config.TextRange * Config.TextRange or -1
		local s_NodesPerCycle = Config.NodesPerCycle

		local s_WayPoints = self.m_WayPoints
		local s_WayPointCount = #s_WayPoints
		local s_CurrentTrace = self.m_CurrentTrace
		local s_MaxIndex = s_WayPointCount + #s_CurrentTrace
		local s_PathsToSkip = self.m_PathsToSkipForCycles
		local s_MinDistanceToPath = self.m_MinDistanceToPath
		local s_ScreenCenter = nil

		local s_LastUpdatedIndex = self.m_LastUpdateIndex
		local s_UpdateCount = 0

		for l_Index = self.m_LastUpdateIndex + 1, s_MaxIndex do
			s_LastUpdatedIndex = l_Index

			local s_IsTracePath = l_Index > s_WayPointCount
			local l_Node = nil
			local l_LastNode = nil

			if s_IsTracePath then
				local l_TraceIndex = l_Index - s_WayPointCount
				l_Node = s_CurrentTrace[l_TraceIndex]
				l_LastNode = s_CurrentTrace[l_TraceIndex - 1]
			else
				l_Node = s_WayPoints[l_Index]
				l_LastNode = s_WayPoints[l_Index - 1]
			end

			local s_PathIndex = l_Node.PathIndex

			if not s_IsTracePath and (s_PathsToSkip[s_PathIndex] or 0) > 0 then
				goto continue
			end

			local s_Position = l_Node.Position
			local s_DiffX = s_Position.x - s_PlayerX
			local s_DiffY = s_Position.y - s_PlayerY
			local s_DiffZ = s_Position.z - s_PlayerZ
			local s_DistanceSq = s_DiffX * s_DiffX + s_DiffY * s_DiffY + s_DiffZ * s_DiffZ

			if not s_IsTracePath then
				local s_MinDistanceSq = s_MinDistanceToPath[s_PathIndex]

				if s_MinDistanceSq == nil or s_DistanceSq < s_MinDistanceSq then
					s_MinDistanceToPath[s_PathIndex] = s_DistanceSq
				end
			end

			local s_DrawNode = s_DistanceSq <= s_WaypointRangeSq
			local s_DrawLine = s_DistanceSq <= s_LineRangeSq
			local s_DrawText = not s_IsTracePath and s_DistanceSq <= s_TextRangeSq

			if s_DrawNode or s_DrawLine then
				local s_Color = self:GetColor(l_Node, s_IsTracePath)
				local s_IsSelected = not s_IsTracePath and self.m_SelectionSet[l_Node.ID] == true

				if s_DrawNode then
					local s_Size = 0.05

					if s_IsSelected then
						s_Size = 0.08
						-- Transform marker.
						self:DrawLine(s_Position, s_Position + Vec3.up, self.m_Colors.Red, self.m_Colors.Red)
						self:DrawLine(s_Position, s_Position + (Vec3.right * 0.5), self.m_Colors.Green, self.m_Colors.Green)
						self:DrawLine(s_Position, s_Position + (Vec3.forward * 0.5), self.m_Colors.Blue, self.m_Colors.Blue)
					end

					-- Higher quality if text is drawn or the node is selected.
					self:DrawSphere(s_Position, s_Size, s_Color.Node, false, not (s_DrawText or s_IsSelected))
					s_UpdateCount = s_UpdateCount + 3

					-- Check if we are scanning for a node to select.
					if not s_IsTracePath and self.m_ScanForNode then
						local s_PointScreenPos = ClientUtils:WorldToScreen(s_Position)

						if s_PointScreenPos ~= nil then
							s_ScreenCenter = s_ScreenCenter or ClientUtils:GetWindowSize() / 2

							-- Select point if it's close to the center of the screen.
							if s_ScreenCenter:Distance(s_PointScreenPos) < 20 then
								self.m_ScanForNode = false

								if s_IsSelected then
									self:Log('Deselect -> %s', l_Node.ID)
									NetEvents:SendLocal('NodeEditor:Deselect', l_Node.ID)
								else
									self:Log('Select -> %s', l_Node.ID)
									NetEvents:SendLocal('NodeEditor:Select', l_Node.ID)
								end
							end
						end
					end
				end

				if s_DrawLine then
					if l_LastNode and (s_IsTracePath or l_LastNode.PathIndex == s_PathIndex) then
						self:DrawLine(s_Position, l_LastNode.Position, s_Color.Line, s_Color.Line)
						s_UpdateCount = s_UpdateCount + 2
					end

					if not s_IsTracePath and l_Node.Data and l_Node.Data.Links then
						for l_LinkIndex = 1, #l_Node.Data.Links do
							local l_LinkNode = self.m_WayPointsById[l_Node.Data.Links[l_LinkIndex]]

							if l_LinkNode then
								self:DrawLine(s_Position, l_LinkNode.Position, self.m_Colors.Purple, self.m_Colors.Purple)
								s_UpdateCount = s_UpdateCount + 1
							end
						end
					end
				end

				if s_DrawText and s_IsSelected then
					self:DrawPosText2D(s_Position + Vec3.up, self:_GetNodeInfoText(l_Node), self.m_Colors.Text, 1.2)
					s_UpdateCount = s_UpdateCount + 1
					s_DrawText = false
				end
			end

			if s_DrawText then
				-- Don't try to pre-calculate this value like with the distance, another memory leak crash awaits you.
				self:DrawPosText2D(s_Position + (Vec3.up * 0.05), tostring(l_Node.ID), self.m_Colors.Text, 1)
				s_UpdateCount = s_UpdateCount + 1
			end

			s_UpdateCount = s_UpdateCount + 1

			if s_UpdateCount >= s_NodesPerCycle then
				break
			end

			::continue::
		end

		self:_UpdateNavZoneDraw(s_WaypointRangeSq, s_LineRangeSq, s_TextRangeSq)

		if s_LastUpdatedIndex >= s_MaxIndex then
			m_ClientSpawnPointHelper:Update(self.m_PlayerPos, self.m_NodesToDraw_temp, self.m_LinesToDraw_temp)
			self.m_LastUpdateIndex = 0

			-- Paths that are completely out of range get skipped for a few cycles. The further away, the longer.
			local s_MaxDrawDistance = math.max(Config.WaypointRange,
				Config.DrawWaypointLines and Config.LineRange or 0,
				Config.DrawWaypointIDs and Config.TextRange or 0)
			local s_MaxDrawDistanceSq = s_MaxDrawDistance * s_MaxDrawDistance

			for l_PathIndex, l_Cycles in pairs(s_PathsToSkip) do
				if l_Cycles > 0 then
					s_PathsToSkip[l_PathIndex] = l_Cycles - 1
				end
			end

			-- Only contains the paths that were checked in this cycle.
			for l_PathIndex, l_MinDistanceSq in pairs(s_MinDistanceToPath) do
				if l_MinDistanceSq > s_MaxDrawDistanceSq then
					s_PathsToSkip[l_PathIndex] = math.floor((math.sqrt(l_MinDistanceSq) / s_MaxDrawDistance) * 10)
				end
			end

			self.m_MinDistanceToPath = {}

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
		else
			self.m_LastUpdateIndex = s_LastUpdatedIndex
		end
	end
end

---The walking mesh close to the player: points (green in a zone), connections, junctions with the waypoints (orange),
---and the names of the zones. Only rebuilt when the player moved NAV_ZONE_REBUILD_DISTANCE, the ranges or the mesh
---changed; OnUIDrawHud draws the lists every frame.
---@param p_PointRangeSq number
---@param p_LineRangeSq number
---@param p_TextRangeSq number
function ClientNodeEditor:_UpdateNavZoneDraw(p_PointRangeSq, p_LineRangeSq, p_TextRangeSq)
	local s_PlayerX, s_PlayerY, s_PlayerZ = self.m_PlayerPos.x, self.m_PlayerPos.y, self.m_PlayerPos.z
	local s_State = self.m_NavZoneDrawState

	if s_State ~= nil and s_State.PointRangeSq == p_PointRangeSq and s_State.LineRangeSq == p_LineRangeSq
		and s_State.TextRangeSq == p_TextRangeSq then
		local s_DiffX, s_DiffY, s_DiffZ = s_PlayerX - s_State.X, s_PlayerY - s_State.Y, s_PlayerZ - s_State.Z
		if s_DiffX * s_DiffX + s_DiffY * s_DiffY + s_DiffZ * s_DiffZ < NAV_ZONE_REBUILD_DISTANCE * NAV_ZONE_REBUILD_DISTANCE then
			return
		end
	end

	self.m_NavZoneDrawState = {
		X = s_PlayerX,
		Y = s_PlayerY,
		Z = s_PlayerZ,
		PointRangeSq = p_PointRangeSq,
		LineRangeSq = p_LineRangeSq,
		TextRangeSq = p_TextRangeSq,
	}

	local s_Spheres = {}
	local s_Lines = {}
	local s_Texts = {}
	local s_Colors = self.m_NavZoneColors
	local function _DistanceSq(p_X, p_Y, p_Z)
		local s_X, s_Y, s_Z = p_X - s_PlayerX, p_Y - s_PlayerY, p_Z - s_PlayerZ
		return s_X * s_X + s_Y * s_Y + s_Z * s_Z
	end
	local function _AddLine(p_From, p_To, p_Color)
		s_Lines[#s_Lines + 1] = { from = p_From, to = p_To, colorFrom = p_Color, colorTo = p_Color }
	end

	local s_Range = math.sqrt(math.max(p_PointRangeSq, p_LineRangeSq, 0))

	for _, l_Zone in pairs(self.m_NavZones) do
		local s_Points = l_Zone.Points

		if s_Points ~= nil and l_Zone.PointCells ~= nil then
			local s_Edges = l_Zone.Edges or {}
			local s_PointEdges = l_Zone.PointEdges
			local s_EdgesDone = {}

			_ForEachInNavZoneCells(l_Zone.PointCells, s_PlayerX, s_PlayerZ, s_Range, function(p_Index)
				local s_Point = s_Points[p_Index]
				local s_DistanceSq = _DistanceSq(s_Point.X, s_Point.Y, s_Point.Z)

				if s_DistanceSq <= p_PointRangeSq then
					s_Spheres[#s_Spheres + 1] = {
						pos = s_Point.Position,
						radius = 0.12,
						color = s_Point.IsInside and s_Colors.Inside or s_Colors.Outside,
						renderLines = false,
						smallSizeSegmentDecrease = true,
					}
				end

				-- A connection is drawn when one of its points is in range.
				if s_DistanceSq > p_LineRangeSq or s_PointEdges[p_Index] == nil then
					return
				end

				local s_EdgeIndices = s_PointEdges[p_Index]
				for l_Index = 1, #s_EdgeIndices do
					local l_EdgeIndex = s_EdgeIndices[l_Index]

					if not s_EdgesDone[l_EdgeIndex] then
						s_EdgesDone[l_EdgeIndex] = true
						local l_Edge = s_Edges[l_EdgeIndex]
						local s_From = s_Points[l_Edge.From]
						local s_To = s_Points[l_Edge.To]

						if s_From ~= nil and s_To ~= nil then
							local s_Color = (s_From.IsInside and s_To.IsInside) and s_Colors.Edge or s_Colors.EdgeOutside
							local s_Last = s_From.Position
							local s_Corners = l_Edge.Corners or {}
							for l_Corner = 1, #s_Corners do
								_AddLine(s_Last, s_Corners[l_Corner], s_Color)
								s_Last = s_Corners[l_Corner]
							end
							_AddLine(s_Last, s_To.Position, s_Color)
						end
					end
				end
			end)

			if p_LineRangeSq > 0 then
				local s_Junctions = l_Zone.Junctions or {}
				_ForEachInNavZoneCells(l_Zone.JunctionCells, s_PlayerX, s_PlayerZ, s_Range, function(p_Index)
					local s_Junction = s_Junctions[p_Index]
					local s_Point = s_Points[s_Junction.Point]

					if s_Point ~= nil and _DistanceSq(s_Junction.X, s_Junction.Y, s_Junction.Z) <= p_LineRangeSq then
						_AddLine(s_Junction.Position, s_Point.Position, s_Colors.Junction)
					end
				end)
			end
		end

		local s_Center = l_Zone.Center
		if s_Center ~= nil and _DistanceSq(s_Center.x, s_Center.y, s_Center.z) <= math.max(p_TextRangeSq, p_PointRangeSq) then
			s_Texts[#s_Texts + 1] = {
				pos = s_Center + Vec3.up * 2.0,
				text = 'Zone ' .. tostring(l_Zone.Name) .. ' (' .. tostring(l_Zone.Kind) .. ', ' .. tostring(l_Zone.Size or 0)
					.. ' points)',
				color = s_Colors.Text,
				scale = 1.2,
			}
		end
	end

	self.m_NavZoneSpheres = s_Spheres
	self.m_NavZoneLines = s_Lines
	self.m_NavZoneTexts = s_Texts
end

---Debug text shown for selected nodes.
---@param p_Node table
---@return string
function ClientNodeEditor:_GetNodeInfoText(p_Node)
	local s_FirstNode = self.m_FirstNodeInPath[p_Node.PathIndex]

	local s_SpeedModeValue = p_Node.InputVar & 0xF -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run.
	local s_ExtraModeValue = (p_Node.InputVar >> 4) & 0xF
	local s_OptValue = (p_Node.InputVar >> 8) & 0xFF

	local s_SpeedMode = m_SpeedModeNames[s_SpeedModeValue] or 'N/A'
	local s_ExtraMode = s_ExtraModeValue == 1 and 'Jump' or 'N/A'
	local s_OptionValue = s_SpeedModeValue == 0 and (tostring(s_OptValue) .. ' Seconds') or 'N/A'

	local s_PathMode = 'N/A'
	if s_FirstNode then
		s_PathMode = ((s_FirstNode.InputVar >> 8) & 0xFF == 0XFF) and 'Reverses' or 'Loops'
	end

	local s_Text = string.format('Index[%d]\n', p_Node.Index)
	s_Text = s_Text .. string.format('Path[%d][%d] (%s)\n', p_Node.PathIndex, p_Node.PointIndex, s_PathMode)
	if s_FirstNode and s_FirstNode.Data then
		s_Text = s_Text .. string.format('Path Objectives: %s\n', g_Utilities:dump(s_FirstNode.Data.Objectives, false))
		s_Text = s_Text .. string.format('Vehicles: %s\n', g_Utilities:dump(s_FirstNode.Data.Vehicles, false))
		local s_Nav = s_FirstNode.Data.Nav
		if type(s_Nav) == 'table' then
			s_Text = s_Text .. string.format('Navigation: %d m\n', math.floor(tonumber(s_Nav.Length) or 0))
		end
	end
	s_Text = s_Text .. string.format('InputVar: %d\n', p_Node.InputVar)
	s_Text = s_Text .. string.format('SpeedMode: %s (%d)\n', s_SpeedMode, s_SpeedModeValue)
	s_Text = s_Text .. string.format('ExtraMode: %s (%d)\n', s_ExtraMode, s_ExtraModeValue)
	s_Text = s_Text .. string.format('OptValue: %s (%d)\n', s_OptionValue, s_OptValue)
	s_Text = s_Text .. 'Data: ' .. g_Utilities:dump(p_Node.Data, true)

	return s_Text
end

---@param p_Spheres table[]
local function _DrawSpheres(p_Spheres)
	for l_Index = 1, #p_Spheres do
		local l_Node = p_Spheres[l_Index]
		DebugRenderer:DrawSphere(l_Node.pos, l_Node.radius, l_Node.color, l_Node.renderLines, l_Node.smallSizeSegmentDecrease)
	end
end

---@param p_Lines table[]
local function _DrawLines(p_Lines)
	for l_Index = 1, #p_Lines do
		local l_Line = p_Lines[l_Index]
		DebugRenderer:DrawLine(l_Line.from, l_Line.to, l_Line.colorFrom, l_Line.colorTo)
	end
end

---Texts at a position in the world.
---@param p_Texts table[]
local function _DrawPosTexts(p_Texts)
	for l_Index = 1, #p_Texts do
		local l_TextPos = p_Texts[l_Index]
		local s_ScreenPos = ClientUtils:WorldToScreen(l_TextPos.pos)

		if s_ScreenPos ~= nil then
			DebugRenderer:DrawText2D(s_ScreenPos.x, s_ScreenPos.y, l_TextPos.text, l_TextPos.color, l_TextPos.scale)
		end
	end
end

---VEXT Client UI:DrawHud Event
function ClientNodeEditor:OnUIDrawHud()
	-- Don't process waypoints if we're not supposed to see them.
	if not self.m_Enabled then
		return
	end

	_DrawSpheres(self.m_NodesToDraw)
	_DrawSpheres(self.m_NavZoneSpheres)
	_DrawLines(self.m_LinesToDraw)
	_DrawLines(self.m_NavZoneLines)

	for l_Index = 1, #self.m_TextToDraw do
		local l_Text = self.m_TextToDraw[l_Index]
		DebugRenderer:DrawText2D(l_Text.x, l_Text.y, l_Text.text, l_Text.color, l_Text.scale)
	end

	_DrawPosTexts(self.m_TextPosToDraw)
	_DrawPosTexts(self.m_NavZoneTexts)

	for l_Index = 1, #self.m_ObbToDraw do
		local l_Obb = self.m_ObbToDraw[l_Index]
		DebugRenderer:DrawOBB(l_Obb.aab, l_Obb.transform, l_Obb.color)
	end
end

function ClientNodeEditor:DrawSphere(p_Position, p_Size, p_Color, p_RenderLines, p_SmallSizeSegmentDecrease)
	self.m_NodesToDraw_temp[#self.m_NodesToDraw_temp + 1] = {
		pos = p_Position,
		radius = p_Size,
		color = p_Color,
		renderLines = p_RenderLines,
		smallSizeSegmentDecrease = p_SmallSizeSegmentDecrease,
	}
end

function ClientNodeEditor:DrawLine(p_From, p_To, p_ColorFrom, p_ColorTo)
	self.m_LinesToDraw_temp[#self.m_LinesToDraw_temp + 1] = {
		from = p_From,
		to = p_To,
		colorFrom = p_ColorFrom,
		colorTo = p_ColorTo,
	}
end

function ClientNodeEditor:DrawText2D(p_X, p_Y, p_Text, p_Color, p_Scale)
	self.m_TextToDraw_temp[#self.m_TextToDraw_temp + 1] = {
		x = p_X,
		y = p_Y,
		text = p_Text,
		color = p_Color,
		scale = p_Scale,
	}
end

function ClientNodeEditor:DrawPosText2D(p_Pos, p_Text, p_Color, p_Scale)
	self.m_TextPosToDraw_temp[#self.m_TextPosToDraw_temp + 1] = {
		pos = p_Pos,
		text = p_Text,
		color = p_Color,
		scale = p_Scale,
	}
end

function ClientNodeEditor:DrawOBB(p_Aab, p_Transform, p_Color)
	self.m_ObbToDraw_temp[#self.m_ObbToDraw_temp + 1] = {
		aab = p_Aab,
		transform = p_Transform,
		color = p_Color,
	}
end

-- Stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
---@param p_MaxDistance number|nil
---@param p_UseAsync boolean|nil
---@return RayCastHit|nil
function ClientNodeEditor:Raycast(p_MaxDistance, p_UseAsync)
	local s_Player = PlayerManager:GetLocalPlayer()
	if not s_Player then
		return
	end

	p_MaxDistance = p_MaxDistance or 100

	-- We get the camera transform, from which we will start the raycast. We get the direction from the forward vector. Camera transform
	-- is inverted, so we have to invert this vector.
	local s_Transform = ClientUtils:GetCameraTransform()
	if s_Transform == nil then
		return
	end
	local s_Direction = Vec3(-s_Transform.forward.x, -s_Transform.forward.y, -s_Transform.forward.z)

	if s_Transform.trans == Vec3.zero then
		return
	end

	local s_CastStart = s_Transform.trans:Clone()

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

	local s_RaycastHit = RaycastManager:Raycast(s_CastStart, s_CastEnd, s_Flags --[[@as RayCastFlags]])

	return s_RaycastHit
end

if g_ClientNodeEditor == nil then
	---@type ClientNodeEditor
	g_ClientNodeEditor = ClientNodeEditor()
end

return g_ClientNodeEditor
