---@class ClientNodeEditor
---@overload fun():ClientNodeEditor
ClientNodeEditor = class('ClientNodeEditor')

require('__shared/Config')

---@type Logger
local m_Logger = Logger('ClientNodeEditor', Debug.Client.NODEEDITOR)
---@type ClientSpawnPointHelper
local m_ClientSpawnPointHelper = require('ClientSpawnPointHelper')
local m_Utilities = require('__shared/Utilities')

function ClientNodeEditor:__init()
	-- new Mode stuff
	self.m_WayPoints = {}
	self.m_WayPointsById = {}
	self.m_CurrentTrace = {}
	self.m_Selections = {}
	self.m_Links = {}
	self.m_RequestDataSent = false
	self.m_WayPointUpdateTimer = 0
	self.m_LastUpdateIndex = 0
	self.m_FirstNodeInPath = {}

	self.m_ScanForNode = false

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

	self.m_EventsReady = false
end

function ClientNodeEditor:OnRegisterEvents()
	-- Simple check to make sure we don't reregister things if they are already done.
	if self.m_EventsReady then return end

	NetEvents:Subscribe('UI_ClientNodeEditor_TraceData', self, self._OnUiTraceData)
	NetEvents:Subscribe('ClientNodeEditor:PrintLog', self, self._OnPrintServerLog)
	NetEvents:Subscribe('ClientNodeEditor:RevieveNodes', self, self._OnRecieveNodes)
	NetEvents:Subscribe('ClientNodeEditor:UpdateNodes', self, self._OnUpdateNodes)
	NetEvents:Subscribe('ClientNodeEditor:RemoveNodes', self, self._OnRemoveNodes)
	NetEvents:Subscribe('ClientNodeEditor:AddNodes', self, self._OnAddNodes)
	NetEvents:Subscribe('ClientNodeEditor:UpdateSelection', self, self._OnUpdateSelection)
	NetEvents:Subscribe('ClientNodeEditor:ClearCustomTrace', self, self._OnClearCustomTrace)

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
	-- self:Log('Register Events')
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

function ClientNodeEditor:_OnRecieveNodes(p_WayPoints)
	print('[ClientNodeEditor] Receiving waypoints from server...')
	self.m_WayPoints = p_WayPoints or {}
	print('[ClientNodeEditor] Recieved ' .. tostring(#self.m_WayPoints) .. ' waypoints from server.')
	self.m_FirstNodeInPath = {}
	self.m_WayPointsById = {}
	for i = 1, #self.m_WayPoints do
		self.m_WayPointsById[self.m_WayPoints[i].ID] = self.m_WayPoints[i]
		local l_Node = self.m_WayPoints[i]
		if self.m_FirstNodeInPath[l_Node.PathIndex] == nil and l_Node.PointIndex == 1 then
			self.m_FirstNodeInPath[l_Node.PathIndex] = l_Node
		end
	end
end

function ClientNodeEditor:_OnUpdateSelection(p_Data)
	self.m_Selections = p_Data or {}
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

function ClientNodeEditor:_OnAddNodes(p_Data)
	for l_Index = 1, #p_Data do
		local l_NodeData = p_Data[l_Index]
		self.m_WayPoints[#self.m_WayPoints + 1] = l_NodeData
		if l_NodeData.PointIndex == 1 then
			self.m_FirstNodeInPath[l_NodeData.PathIndex] = l_NodeData
		end
		self.m_WayPointsById[l_NodeData.ID] = l_NodeData
	end
end

function ClientNodeEditor:_OnRemoveNodes(p_Data)
	for l_Index = 1, #p_Data do
		local l_NodeId = p_Data[l_Index]
		for l_WaypointIndex, l_Waypoint in pairs(self.m_WayPoints) do
			if l_Waypoint.ID == l_NodeId then
				table.remove(self.m_WayPoints, l_WaypointIndex)
				break
			end
		end
	end
end

function ClientNodeEditor:_OnUpdateNodes(p_Data)
	for l_Index = 1, #p_Data do
		local l_NodeId = p_Data[l_Index].ID
		m_Utilities:mergeKeys(self.m_WayPointsById[l_NodeId], p_Data[l_Index])
	end
end

function ClientNodeEditor:GetColor(p_Node, p_IsTracePath)
	local s_Color = {}
	if p_IsTracePath then
		s_Color = {
			Node = self.m_Colors.White,
			Line = self.m_Colors.White,
		}
		return s_Color
	end
	if p_Node.PathIndex > 0 then
		if self.m_Colors[p_Node.PathIndex] == nil then
			local r, g, b = (math.random(20, 100) / 100), (math.random(20, 100) / 100), (math.random(20, 100) / 100)
			self.m_Colors[p_Node.PathIndex] = {
				Node = Vec4(r, g, b, 0.25),
				Line = Vec4(r, g, b, 1),
			}
		end

		s_Color = self.m_Colors[p_Node.PathIndex]
	else
		-- print("node with index 0")
		-- print(s_Waypoint)
		s_Color = {
			Node = self.m_Colors.Red,
			Line = self.m_Colors.Red,
		}
	end

	return s_Color
end

function ClientNodeEditor:GetIsSelected(p_NodeId, p_IsTracePath)
	if p_IsTracePath then
		return false
	end
	for l_Index = 1, #self.m_Selections do
		local l_SelectionId = self.m_Selections[l_Index]
		if l_SelectionId == p_NodeId then
			return true
		end
	end
	return false
end

function ClientNodeEditor:GetLinkNode(p_LinkID)
	return self.m_WayPointsById[p_LinkID]
end

function ClientNodeEditor:OnUISettings(p_Data)
	if p_Data == false then -- Client closed settings.
		self:OnSetEnabled(Config.DebugTracePaths)
	end
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
	end

	local s_HitSpawn = m_ClientSpawnPointHelper:FindSpawn(s_Hit.position)
	if s_HitSpawn then
		print(s_HitSpawn)
		NetEvents:SendLocal('NodeEditor:SelectSpawn', s_HitSpawn)
	end

	local s_SelectedSpawn = m_ClientSpawnPointHelper:GetSelectedSpawn()
	if s_SelectedSpawn then
		print(s_SelectedSpawn)
		NetEvents:SendLocal('NodeEditor:SelectSpawn', s_SelectedSpawn)
	end
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

	return false
end

function ClientNodeEditor:_onAddNode(p_Args)
	NetEvents:SendLocal('NodeEditor:AddNode')
end

function ClientNodeEditor:_onSelectNewNode(p_NewDataNodeId)
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
	NetEvents:SendLocal('NodeEditor:SetLoopMode', p_Args)
end

function ClientNodeEditor:_onSetSpawnPath(p_Args)
	NetEvents:SendLocal('NodeEditor:SetSpawnPath', p_Args)
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
	self.m_CurrentTrace = {} -- TODO: Fill it
	self.m_Selections = {} -- TODO: Fill it
	self.m_Links = {}     -- TODO: Fill it
	self.m_RequestDataSent = false
	self.m_WayPointUpdateTimer = 0
	self.m_LastUpdateIndex = 0
	self.m_FirstNodeInPath = {}

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
		-- self:Log('Blocked vanilla Commo Rose')
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
			-- To-do: Not functional yet!
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
	self.m_WayPointUpdateTimer = self.m_WayPointUpdateTimer + p_DeltaTime
	if self.m_WayPointUpdateTimer >= 0.03 and s_Player and s_Player.soldier then -- TODO: Adjust update interval for performance vs update speed
		self.m_WayPointUpdateTimer = 0

		local s_LastIndexToUpdate = self.m_LastUpdateIndex + 1024 -- TODO: Adjust this value for performance vs update speed
		-- TOOD: maybe only count if point is drawn? Or only count every 5 not drawn points as one drawn point?
		local s_MaxIndex = #self.m_WayPoints + #self.m_CurrentTrace
		if s_LastIndexToUpdate > s_MaxIndex then
			s_LastIndexToUpdate = s_MaxIndex
		end
		for l_Index = self.m_LastUpdateIndex + 1, s_LastIndexToUpdate do
			local s_IsTracePath = false
			local l_Node = nil
			local l_LastNode = nil
			if l_Index <= #self.m_WayPoints then
				l_Node = self.m_WayPoints[l_Index]
				if l_Index > 1 then
					l_LastNode = self.m_WayPoints[l_Index - 1]
				end
			else
				s_IsTracePath = true
				local l_TraceIndex = l_Index - #self.m_WayPoints
				l_Node = self.m_CurrentTrace[l_TraceIndex]
				if l_TraceIndex > 1 then
					l_LastNode = self.m_CurrentTrace[l_TraceIndex - 1]
				end
			end

			local s_IsSelected = self:GetIsSelected(l_Node.ID, s_IsTracePath)

			local s_Distance = m_Utilities:DistanceFast(l_Node.Position, self.m_PlayerPos)
			local s_DrawNode = false
			local s_DrawLine = false
			local s_DrawText = false
			if s_Distance <= Config.WaypointRange then
				s_DrawNode = true
			end
			if s_Distance <= Config.LineRange then
				s_DrawLine = true
			end
			if s_Distance <= Config.TextRange then
				s_DrawText = true
			end

			if s_DrawNode or s_DrawLine then
				-- only draw if in front of player
				-- local s_DiffPos = l_Node.Position - self.m_PlayerPos
				-- local s_DotProduct = s_DiffPos:Dot(s_Player.soldier.worldTransform.forward)
				-- local s_DotProduct = 1 -- just do it always for now, to avoid issues with nodes behind the player
				-- if s_DotProduct > 0 then
				local s_Color = self:GetColor(l_Node, s_IsTracePath)
				local s_QualityAtRange = s_DrawText or s_IsSelected -- higher quality if text is drawn or is selected
				local s_Size = 0.05
				if s_IsSelected then
					s_Size = 0.08
					-- Transform marker.
					self:DrawLine(l_Node.Position, l_Node.Position + (Vec3.up), self.m_Colors.Red, self.m_Colors.Red)
					self:DrawLine(l_Node.Position, l_Node.Position + (Vec3.right * 0.5), self.m_Colors.Green, self.m_Colors.Green)
					self:DrawLine(l_Node.Position, l_Node.Position + (Vec3.forward * 0.5), self.m_Colors.Blue, self.m_Colors.Blue)
				end
				self:DrawSphere(l_Node.Position, s_Size, s_Color.Node, false, (not s_QualityAtRange))

				-- Check if we are scanning for a node to select.
				if not s_IsTracePath and self.m_ScanForNode then
					local s_PointScreenPos = ClientUtils:WorldToScreen(l_Node.Position)

					-- Skip to the next point if this one isn't in view.
					if s_PointScreenPos ~= nil then
						local s_Center = ClientUtils:GetWindowSize() / 2

						-- Select point if it's close to the hitPosition.
						if s_Center:Distance(s_PointScreenPos) < 20 then
							self.m_ScanForNode = false

							if s_IsSelected then
								self:Log('Deselect -> %s', l_Node.ID)
								NetEvents:SendLocal('NodeEditor:Deselect', l_Node.ID)
								return
							else
								self:Log('Select -> %s', l_Node.ID)
								NetEvents:SendLocal('NodeEditor:Select', l_Node.ID)
								return
							end
						end
					end
				end

				if Config.DrawWaypointLines and s_DrawLine and l_LastNode and (s_IsTracePath or l_LastNode.PathIndex == l_Node.PathIndex) then
					self:DrawLine(l_Node.Position, l_LastNode.Position, s_Color.Line, s_Color.Line)
				end
				if l_Node.Data and l_Node.Data.Links then
					for l_LinkIndex = 1, #l_Node.Data.Links do
						local l_LinkID = l_Node.Data.Links[l_LinkIndex]
						local l_LinkNode = self:GetLinkNode(l_LinkID)
						if l_LinkNode then
							self:DrawLine(l_Node.Position, l_LinkNode.Position, self.m_Colors.Purple, self.m_Colors.Purple)
						end
					end
				end
				if Config.DrawWaypointIDs and s_DrawText and not s_IsTracePath then
					-- Draw debugging text.
					if s_IsSelected then
						local s_FirstNode = self.m_FirstNodeInPath[l_Node.PathIndex]
						local s_SpeedMode = 'N/A'

						local SpeedMode = l_Node.InputVar & 0xF -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run.
						local ExtraMode = (l_Node.InputVar >> 4) & 0xF
						local OptValue = (l_Node.InputVar >> 8) & 0xFF

						if SpeedMode == 0 then s_SpeedMode = 'Wait' end

						if SpeedMode == 1 then s_SpeedMode = 'Prone' end

						if SpeedMode == 2 then s_SpeedMode = 'Crouch' end

						if SpeedMode == 3 then s_SpeedMode = 'Walk' end

						if SpeedMode == 4 then s_SpeedMode = 'Sprint' end

						local s_ExtraMode = 'N/A'

						if ExtraMode == 1 then s_ExtraMode = 'Jump' end

						local s_OptionValue = 'N/A'

						if SpeedMode == 0 then
							s_OptionValue = tostring(OptValue) .. ' Seconds'
						end

						local s_PathMode = 'Loops'
						local s_Reverses = (s_FirstNode.InputVar >> 8) & 0xFF == 0XFF
						if s_Reverses then
							s_PathMode = 'Reverses'
						end

						local s_Text = ''
						-- s_Text = s_Text .. string.format("(%s)Pevious [ %s ] Next(%s)\n", s_PreviousNode, p_Waypoint.ID, s_NextNode)
						s_Text = s_Text .. string.format('Index[%d]\n', l_Node.Index)
						s_Text = s_Text .. string.format('Path[%d][%d] (%s)\n', l_Node.PathIndex, l_Node.PointIndex, s_PathMode)
						s_Text = s_Text .. string.format('Path Objectives: %s\n', g_Utilities:dump(s_FirstNode.Data.Objectives, false))
						s_Text = s_Text .. string.format('Vehicles: %s\n', g_Utilities:dump(s_FirstNode.Data.Vehicles, false))
						s_Text = s_Text .. string.format('InputVar: %d\n', l_Node.InputVar)
						s_Text = s_Text .. string.format('SpeedMode: %s (%d)\n', s_SpeedMode, SpeedMode)
						s_Text = s_Text .. string.format('ExtraMode: %s (%d)\n', s_ExtraMode, ExtraMode)
						s_Text = s_Text .. string.format('OptValue: %s (%d)\n', s_OptionValue, OptValue)
						s_Text = s_Text .. 'Data: ' .. g_Utilities:dump(l_Node.Data, true)

						self:DrawPosText2D(l_Node.Position + Vec3.up, s_Text, self.m_Colors.Text, 1.2)
					else
						-- Don't try to pre-calculate this value like with the distance, another memory leak crash awaits you.
						self:DrawPosText2D(l_Node.Position + (Vec3.up * 0.05), tostring(l_Node.ID), self.m_Colors.Text, 1)
					end
				end
				-- end
			end
		end

		self.m_LastUpdateIndex = s_LastIndexToUpdate
		if self.m_LastUpdateIndex >= s_MaxIndex then
			self.m_LastUpdateIndex = 0

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
		end
	end
end

---VEXT Client UI:DrawHud Event
function ClientNodeEditor:OnUIDrawHud()
	-- Don't process waypoints if we're not supposed to see them.
	if not self.m_Enabled then
		return
	end

	for l_Index = 1, #self.m_NodesToDraw do
		local l_Node = self.m_NodesToDraw[l_Index]
		-- Draw spheres.
		DebugRenderer:DrawSphere(l_Node.pos, l_Node.radius, l_Node.color, l_Node.renderLines, l_Node.smallSizeSegmentDecrease)
	end

	for l_Index = 1, #self.m_LinesToDraw do
		local l_Line = self.m_LinesToDraw[l_Index]
		-- Draw lines.
		DebugRenderer:DrawLine(l_Line.from, l_Line.to, l_Line.colorFrom, l_Line.colorTo)
	end

	for l_Index = 1, #self.m_TextToDraw do
		local l_Text = self.m_TextToDraw[l_Index]
		-- Draw text.
		DebugRenderer:DrawText2D(l_Text.x, l_Text.y, l_Text.text, l_Text.color, l_Text.scale)
	end

	for l_Index = 1, #self.m_TextPosToDraw do
		local l_TextPos = self.m_TextPosToDraw[l_Index]
		local s_ScreenPos = ClientUtils:WorldToScreen(l_TextPos.pos)

		if s_ScreenPos ~= nil then
			DebugRenderer:DrawText2D(s_ScreenPos.x, s_ScreenPos.y, l_TextPos.text, l_TextPos.color, l_TextPos.scale)
		end
	end

	for l_Index = 1, #self.m_ObbToDraw do
		local l_Obb = self.m_ObbToDraw[l_Index]
		-- Draw OBB.
		DebugRenderer:DrawOBB(l_Obb.p_Aab, l_Obb.transform, l_Obb.color)
	end
end

function ClientNodeEditor:DrawSphere(p_Position, p_Size, p_Color, p_RenderLines, p_SmallSizeSegmentDecrease)
	table.insert(self.m_NodesToDraw_temp, {
		pos = p_Position,
		radius = p_Size,
		color = p_Color,
		renderLines = p_RenderLines,
		smallSizeSegmentDecrease = p_SmallSizeSegmentDecrease,
	})
end

function ClientNodeEditor:DrawLine(p_From, p_To, p_ColorFrom, p_ColorTo)
	table.insert(self.m_LinesToDraw_temp, {
		from = p_From,
		to = p_To,
		colorFrom = p_ColorFrom,
		colorTo = p_ColorTo,
	})
end

function ClientNodeEditor:DrawText2D(p_X, p_Y, p_Text, p_Color, p_Scale)
	table.insert(self.m_TextToDraw_temp, {
		x = p_X,
		y = p_Y,
		text = p_Text,
		color = p_Color,
		scale = p_Scale,
	})
end

function ClientNodeEditor:DrawPosText2D(p_Pos, p_Text, p_Color, p_Scale)
	table.insert(self.m_TextPosToDraw_temp, {
		pos = p_Pos,
		text = p_Text,
		color = p_Color,
		scale = p_Scale,
	})
end

function ClientNodeEditor:DrawOBB(p_Aab, p_Transform, p_Color)
	table.insert(self.m_ObbToDraw_temp, {
		aab = p_Aab,
		transform = p_Transform,
		color = p_Color,
	})
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

	local s_CastStart = s_Transform.trans

	-- We get the raycast end transform with the calculated direction and the max distance.
	local s_CastEnd = Vec3(
		s_Transform.trans.x + (s_Direction.x * p_MaxDistance),
		s_Transform.trans.y + (s_Direction.y * p_MaxDistance),
		s_Transform.trans.z + (s_Direction.z * p_MaxDistance))

	-- Perform raycast, returns a RayCastHit object.

	---@type RayCastFlags
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
