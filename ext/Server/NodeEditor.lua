---@class NodeEditor
---@overload fun():NodeEditor
NodeEditor = class "NodeEditor"

---@type NodeCollection
local m_NodeCollection = require('__shared/NodeCollection')
---@type Logger
local m_Logger = Logger("NodeEditor", Debug.Server.NODEEDITOR)

function NodeEditor:__init()
	self.m_NodeReceiveDelay = 1
	self.m_NodeReceiveTimer = -1
	self.m_BatchSendTimer = 0
	self.m_NexBatchSend = 0
	self.m_PlayerSendingNodes = nil
	self.m_PlayersReceivingNodes = {}
	self.m_Debugprints = 0



	self.m_ActiveTracePlayers = {}

	self.m_CustomTrace = {}
	self.m_CustomTraceIndex = {}
	self.m_CustomTraceTimer = {}
	self.m_CustomTraceDelay = Config.TraceDelta
	self.m_CustomTraceDistance = {}
	self.m_CustomTraceSaving = false


	self.m_lastDrawIndexNode = {}
	self.m_lastDrawIndexPath = {}

	self.m_NodeOperation = ''

	self.m_NodeSendUpdateTimer = 0
end

function NodeEditor:RegisterCustomEvents()

	-- Remove them?
	NetEvents:Subscribe('NodeEditor:RequestNodes', self, self.OnRequestNodes)
	NetEvents:Subscribe('NodeEditor:SendNodes', self, self.OnSendNodes)
	NetEvents:Subscribe('NodeEditor:ReceivingNodes', self, self.OnReceiveNodes)
	NetEvents:Subscribe('NodeEditor:Create', self, self.OnCreate)
	NetEvents:Subscribe('NodeEditor:Init', self, self.OnInit)
	NetEvents:Subscribe('NodeEditor:WarpTo', self, self.OnWarpTo)
	-- NetEvents:Subscribe('UI_Request_Save_Settings', self, self.OnUIRequestSaveSettings)


	-- EDIT-Events from Client
	NetEvents:Subscribe('NodeEditor:Select', self, self.OnSelect)
	NetEvents:Subscribe('NodeEditor:Deselect', self, self.OnDeselect)
	NetEvents:Subscribe('NodeEditor:SelectBetween', self, self.OnSelectBetween)
	NetEvents:Subscribe('NodeEditor:SelectNext', self, self.OnSelectNext)
	NetEvents:Subscribe('NodeEditor:SelectPrevious', self, self.OnSelectPrevious)
	NetEvents:Subscribe('NodeEditor:ClearSelection', self, self.OnClearSelection)
	NetEvents:Subscribe('NodeEditor:SetInputNode', self, self.OnSetInputNode)
	NetEvents:Subscribe('NodeEditor:LinkNodes', self, self.OnLinkNodes)
	NetEvents:Subscribe('NodeEditor:UnlinkNodes', self, self.OnUnlinkNodes)
	NetEvents:Subscribe('NodeEditor:MergeNodes', self, self.OnMergeNodes)
	NetEvents:Subscribe('NodeEditor:SplitNode', self, self.OnSplitNode)
	NetEvents:Subscribe('NodeEditor:RemoveNode', self, self.OnRemoveNode)

	NetEvents:Subscribe('NodeEditor:AddMcom', self, self.OnAddMcom)
	NetEvents:Subscribe('NodeEditor:AddVehicle', self, self.OnAddVehicle)
	NetEvents:Subscribe('NodeEditor:ExitVehicle', self, self.OnExitVehicle)
	NetEvents:Subscribe('NodeEditor:AddVehiclePath', self, self.OnAddVehiclePath)
	NetEvents:Subscribe('NodeEditor:AddObjective', self, self.OnAddObjective)
	NetEvents:Subscribe('NodeEditor:RemoveObjective', self, self.OnRemoveObjective)
	NetEvents:Subscribe('NodeEditor:RemoveData', self, self.OnRemoveData)

	NetEvents:Subscribe('NodeEditor:SpawnBot', self, self.OnSpawnBot)
	NetEvents:Subscribe('NodeEditor:UpdatePos', self, self.OnUpdatePos)


	-- TODO: fill
end

-- =============================================
-- Events
-- =============================================

function NodeEditor:OnUpdatePos(p_Player, p_UpdateData)
	for _, l_UpdateItem in pairs(p_UpdateData) do
		local s_NodeToUpdate = m_NodeCollection:Get(l_UpdateItem.ID)
		m_NodeCollection:Update(s_NodeToUpdate, {
			Position = l_UpdateItem.Pos
		})
	end
end

function NodeEditor:OnAddMcom(p_Player)

	if not p_Player.soldier then
		self:Log('Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection ~= 1 then
		self:Log('Must select one node')
		return false
	end

	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local action = {
			type = "mcom",
			inputs = { EntryInputActionEnum.EIAInteract },
			time = 6.0,
			yaw = p_Player.input.authoritativeAimingYaw,
			pitch = p_Player.input.authoritativeAimingPitch
		}
		s_Selection[i].Data.Action = action
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end

	return true
end

function NodeEditor:OnAddVehicle(p_Player)

	if not p_Player.soldier then
		self:Log('Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection ~= 1 then
		self:Log('Must select one node')
		return
	end

	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local action = {
			type = "vehicle",
			inputs = { EntryInputActionEnum.EIAInteract },
			time = 0.5,
			yaw = p_Player.input.authoritativeAimingYaw,
			pitch = p_Player.input.authoritativeAimingPitch
		}
		s_Selection[i].Data.Action = action
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end

	return
end

function NodeEditor:OnExitVehicle(p_Player, p_Args)
	self.m_CommoRoseActive = false

	if not p_Player.soldier then
		self:Log('Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection ~= 1 then
		self:Log('Must select one node')
		return
	end

	local s_Data = p_Args[1] or "false"
	self:Log('Exit Vehicle (type): %s', g_Utilities:dump(s_Data, true))

	local s_OnlyPassengers = not (s_Data:lower() == "false" or s_Data == "0")
	print(s_OnlyPassengers)

	for i = 1, #s_Selection do
		local action = {
			type = "exit",
			onlyPassengers = s_OnlyPassengers,
			inputs = { EntryInputActionEnum.EIAInteract },
			time = 0.5
		}
		s_Selection[i].Data.Action = action
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end

	return
end

function NodeEditor:OnAddVehiclePath(p_Player, p_Args)
	local s_Data = table.concat(p_Args or { "land" }, ' ')
	self:Log('Add Vehicle (type): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

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

-- EVENTS for editing
function NodeEditor:OnAddObjective(p_Player, p_Args)
	local s_Data = table.concat(p_Args or {}, ' ')
	s_Data = s_Data:lower()
	self:Log('Add Objective (data): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

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

function NodeEditor:OnRemoveObjective(p_Player, p_Args)
	local s_Data = table.concat(p_Args or {}, ' ')
	s_Data = s_Data:lower()
	self:Log('Remove Objective (data): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

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

function NodeEditor:OnRemoveData(p_Player)
	if not p_Player.soldier then
		self:Log('Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log('Must select at least one node')
		return
	end

	self:Log('Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		s_Selection[i].Data = {}
		self:Log('Updated Waypoint: %s', s_Selection[i].ID)
	end
end

function NodeEditor:OnRemoveNode(p_Player)
	local s_Result, s_Message = m_NodeCollection:Remove(p_Player.onlineId)
	if not s_Result then
		self:Log(s_Message)
	end
end

function NodeEditor:OnSplitNode(p_Player)
	local s_Result, s_Message = m_NodeCollection:SplitSelection(p_Player.onlineId)
	if not s_Result then
		self:Log(s_Message)
	end
end

function NodeEditor:OnMergeNodes(p_Player)
	local s_Result, s_Message = m_NodeCollection:MergeSelection(p_Player.onlineId)
	if not s_Result then
		self:Log(s_Message)
	end
end

function NodeEditor:OnUnlinkNodes(p_Player)
	local s_Result, s_Message = m_NodeCollection:Unlink(p_Player.onlineId)
	if not s_Result then
		self:Log(s_Message)
	end
end

function NodeEditor:OnLinkNodes(p_Player)
	local s_Result, s_Message = m_NodeCollection:Link(p_Player.onlineId)
	if not s_Result then
		self:Log(s_Message)
	end
end

function NodeEditor:OnSpitNode(p_Player)
	local s_Result, s_Message = m_NodeCollection:SplitSelection(p_Player.onlineId)
	if not s_Result then
		self:Log(s_Message)
	end
end

function NodeEditor:OnSetInputNode(p_Player, p_Arg1, p_Arg2, p_Arg3)
	local s_Result, s_Message = m_NodeCollection:SetInput(p_Arg1, p_Arg2, p_Arg3)
	if not s_Result then
		self:Log(s_Message)
	end
end

function NodeEditor:OnSpawnBot(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection > 0 then
		Events:Dispatch('BotEditor', json.encode({
			action = 'bot_spawn_path',
			value = s_Selection[1].PathIndex,
			pointindex = s_Selection[1].PointIndex,
		}))
	end
end

function NodeEditor:OnSelect(p_Player, p_WaypointId)
	m_NodeCollection:Select(p_Player.onlineId, p_WaypointId)
end

function NodeEditor:OnDeselect(p_Player, p_WaypointId)
	m_NodeCollection:Deselect(p_Player.onlineId, p_WaypointId)
end

function NodeEditor:OnSelectBetween(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log('Must select more than one node')
		return false
	end

	local s_BreakAt = (#m_NodeCollection:Get())
	local s_Current = 0
	local s_CurrentWaypoint = s_Selection[1]

	while s_CurrentWaypoint.Next and s_CurrentWaypoint.ID ~= s_Selection[#s_Selection].ID do
		m_NodeCollection:Select(p_Player.onlineId, s_CurrentWaypoint)
		s_Current = s_Current + 1

		if s_Current > s_BreakAt then
			break
		end

		s_CurrentWaypoint = s_CurrentWaypoint.Next
	end
end

function NodeEditor:OnSelectNext(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection > 0 then
		if s_Selection[1].Next ~= false then
			m_NodeCollection:Select(p_Player.onlineId, s_Selection[1].Next)
		end
	else
		self:Log('Must select at least one node')
	end
end

function NodeEditor:OnSelectPrevious(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection > 0 then
		if s_Selection[1].Next ~= false then
			m_NodeCollection:Select(p_Player.onlineId, s_Selection[1].Previous)
		end
	else
		self:Log('Must select at least one node')
	end
end

function NodeEditor:OnClearSelection(p_Player)
	m_NodeCollection:ClearSelection(p_Player.onlineId)
end

-- =============================================
-- Level Events
-- =============================================

-- Management Events
function NodeEditor:OnOpenEditor(p_Player)
	self.m_CustomTraceTimer[p_Player.onlineId] = -1
	self.m_lastDrawIndexNode[p_Player.onlineId] = 0
	self.m_lastDrawIndexPath[p_Player.onlineId] = 0
	self.m_ActiveTracePlayers[p_Player.onlineId] = true
end

function NodeEditor:OnCloseEditor(p_Player)
	self.m_ActiveTracePlayers[p_Player.onlineId] = false
end

--- TRACE Events

-- ############################ Trace Recording
-- ############################################

function NodeEditor:_getNewIndex()
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

function NodeEditor:StartTrace(p_Player)
	if not p_Player.soldier then
		return
	end

	if self.m_CustomTrace[p_Player.onlineId] ~= nil then
		self.m_CustomTrace[p_Player.onlineId]:Clear()
	end

	self.m_CustomTrace[p_Player.onlineId] = NodeCollection(true)
	self.m_CustomTraceTimer[p_Player.onlineId] = 0
	self.m_CustomTraceIndex[p_Player.onlineId] = self:_getNewIndex()
	self.m_CustomTraceDistance[p_Player.onlineId] = 0

	local s_FirstWaypoint = self.m_CustomTrace[p_Player.onlineId]:Create({
		Position = p_Player.soldier.worldTransform.trans:Clone()
	})
	self.m_CustomTrace[p_Player.onlineId]:ClearSelection()
	self.m_CustomTrace[p_Player.onlineId]:Select(p_Player.onlineId, s_FirstWaypoint)

	self:Log('Custom Trace Started')

	local s_TotalTraceDistance = self.m_CustomTraceDistance[p_Player.onlineId]
	local s_TotalTraceNodes = #self.m_CustomTrace[p_Player.onlineId]:Get()
	local s_TraceIndex = self.m_CustomTraceIndex[p_Player.onlineId] -- TODO: not really needed ?
	NetEvents:SendToLocal("UI_ClientNodeEditor_TraceData", p_Player, s_TotalTraceNodes, s_TotalTraceDistance, s_TraceIndex,
		true)
end

function NodeEditor:EndTrace(p_Player)
	self.m_CustomTraceTimer[p_Player.onlineId] = -1
	NetEvents:SendToLocal("UI_ClientNodeEditor_TraceData", p_Player, nil, nil, nil, false)

	local s_FirstWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetFirst()

	if s_FirstWaypoint then
		local s_FirstWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetFirst()

		local s_StartPos = s_FirstWaypoint.Position + Vec3.up
		local s_EndPos = self.m_CustomTrace[p_Player.onlineId]:GetLast().Position + Vec3.up
		local s_RayHits = nil

		if p_Player.attachedControllable then
			s_RayHits = RaycastManager:CollisionRaycast(s_StartPos, s_EndPos, 1, 0,
				RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll |
				RayCastFlags.CheckDetailMesh | RayCastFlags.DontCheckPhantoms | RayCastFlags.DontCheckGroup |
				RayCastFlags.IsAsyncRaycast)
		else
			s_RayHits = RaycastManager:CollisionRaycast(s_StartPos, s_EndPos, 1, 0,
				RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll |
				RayCastFlags.CheckDetailMesh | RayCastFlags.IsAsyncRaycast)
		end


		self.m_CustomTrace[p_Player.onlineId]:ClearSelection()
		self.m_CustomTrace[p_Player.onlineId]:Select(p_Player.onlineId, s_FirstWaypoint)

		if s_RayHits == nil or s_RayHits == 0 then
			-- clear view from start node to end node, path loops
			self.m_CustomTrace[p_Player.onlineId]:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0)
		else
			-- no clear view, path should just invert at the end
			self.m_CustomTrace[p_Player.onlineId]:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0XFF)
		end

		self.m_CustomTrace[p_Player.onlineId]:ClearSelection()
	end

	self:Log('Custom Trace Ended')
end

function NodeEditor:ClearTrace(p_Player)
	self.m_CustomTraceTimer[p_Player.onlineId] = -1
	self.m_CustomTraceIndex[p_Player.onlineId] = self:_getNewIndex()
	self.m_CustomTraceDistance[p_Player.onlineId] = 0
	self.m_CustomTrace[p_Player.onlineId]:Clear()

	-- TODO: Client: set UI
	local s_TotalTraceDistance = self.m_CustomTraceDistance[p_Player.onlineId]
	local s_TotalTraceNodes = #self.m_CustomTrace[p_Player.onlineId]:Get()
	local s_TraceIndex = self.m_CustomTraceIndex[p_Player.onlineId] -- TODO: not really needed ?
	NetEvents:SendToLocal("UI_ClientNodeEditor_TraceData", p_Player, s_TotalTraceNodes, s_TotalTraceDistance, s_TraceIndex,
		false)

	self:Log('Custom Trace Cleared')
end

function NodeEditor:IsSavingOrLoading()
	return self.m_NodeOperation ~= ''
end

function NodeEditor:SaveTrace(p_Player, p_PathIndex)
	if self:IsSavingOrLoading() then
		self:Log('Operation in progress, please wait...')
		return false
	end

	if type(p_PathIndex) == 'table' then
		p_PathIndex = p_PathIndex[1]
	end

	if self.m_CustomTrace[p_Player.onlineId] == nil then
		self:Log('Custom Trace is empty')
		return false
	end

	self.m_NodeOperation = 'Custom Trace'

	local s_PathCount = #m_NodeCollection:GetPaths()
	p_PathIndex = tonumber(p_PathIndex) or self:_getNewIndex()
	local s_CurrentWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetFirst()
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
			s_CurrentWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetLast()
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
				m_NodeCollection:Remove(p_Player.onlineId, s_PathWaypoints[i])
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

	self.m_CustomTrace[p_Player.onlineId]:Clear()
	collectgarbage('collect')
	self:Log('Custom Trace Saved to Path: %d', p_PathIndex)
	self.m_NodeOperation = ''
end

--- COMMON EVENTS

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

---VEXT Shared Level:Destroy Event
function NodeEditor:OnLevelDestroy()
	m_NodeCollection:Clear()
	self.m_ActiveTracePlayers = {}
end

-- =============================================
-- Player Events
-- =============================================

---VEXT Server Player:Respawn Event
---@param p_Player Player
function NodeEditor:OnPlayerRespawn(p_Player)
end

---VEXT Server Player:Killed Event
---@param p_Player Player
function NodeEditor:OnPlayerKilled(p_Player)
end

---VEXT Server Player:Left Event
---@param p_Player Player
function NodeEditor:OnPlayerLeft(p_Player)
	self:StopSendingNodes(p_Player)
end

---VEXT Server Player:Destroyed Event
---@param p_Player Player
function NodeEditor:OnPlayerDestroyed(p_Player)
	self:StopSendingNodes(p_Player)
end

-- =============================================
-- Update Events
-- =============================================
function NodeEditor:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	-- Only do math on presimulation UpdatePass, don't bother if debugging is off
	if p_UpdatePass ~= UpdatePass.UpdatePass_PreSim then
		return
	end
end

---VEXT Shared Engine:Update Event
---@param p_DeltaTime number
---@param p_SimulationDeltaTime number
function NodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	-- TRACE-Handling
	for l_PlayerGuid, l_Active in pairs(self.m_ActiveTracePlayers) do
		local s_Player = PlayerManager:GetPlayerByOnlineId(l_PlayerGuid)
		if (s_Player and s_Player.soldier and l_Active and self.m_CustomTraceTimer[l_PlayerGuid] >= 0) then
			self.m_CustomTraceTimer[l_PlayerGuid] = self.m_CustomTraceTimer[l_PlayerGuid] + p_DeltaTime

			local s_PlayerPos = s_Player.soldier.worldTransform.trans:Clone()

			if self.m_CustomTraceTimer[l_PlayerGuid] > self.m_CustomTraceDelay then
				local s_LastWaypoint = self.m_CustomTrace[l_PlayerGuid]:GetLast()

				if s_LastWaypoint then
					local s_LastDistance = s_LastWaypoint.Position:Distance(s_PlayerPos)

					if s_LastDistance >= self.m_CustomTraceDelay then
						-- primary weapon, record movement
						if s_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_0 then
							local s_NewWaypoint, s_Msg = self.m_CustomTrace[l_PlayerGuid]:Add()
							self.m_CustomTrace[l_PlayerGuid]:Update(s_NewWaypoint, {
								Position = s_PlayerPos
							})
							self.m_CustomTrace[l_PlayerGuid]:ClearSelection()
							self.m_CustomTrace[l_PlayerGuid]:Select(l_PlayerGuid, s_NewWaypoint)

							local s_Speed = BotMoveSpeeds.NoMovement -- 0 = wait, 1 = prone ... (4 Bits)
							local s_Extra = 0 -- 0 = nothing, 1 = jump ... (4 Bits)

							if s_Player.attachedControllable ~= nil then
								local s_SpeedInput = math.abs(s_Player.input:GetLevel(EntryInputActionEnum.EIAThrottle))

								if s_SpeedInput > 0 then
									s_Speed = BotMoveSpeeds.Normal

									if s_Player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
										s_Speed = BotMoveSpeeds.Sprint
									end
								elseif s_SpeedInput == 0 then
									s_Speed = BotMoveSpeeds.SlowCrouch
								end

								if s_Player.input:GetLevel(EntryInputActionEnum.EIABrake) > 0 then
									s_Speed = BotMoveSpeeds.VerySlowProne
								end

								self.m_CustomTrace[l_PlayerGuid]:SetInput(s_Speed, s_Extra, 0)
							else
								if s_Player.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then --record only if moving
									if s_Player.soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
										s_Speed = BotMoveSpeeds.VerySlowProne
									elseif s_Player.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
										s_Speed = BotMoveSpeeds.SlowCrouch
									else
										s_Speed = BotMoveSpeeds.Normal

										if s_Player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
											s_Speed = BotMoveSpeeds.Sprint
										end
									end

									if s_Player.input:GetLevel(EntryInputActionEnum.EIAJump) == 1 then
										s_Extra = 1
									end

									self.m_CustomTrace[l_PlayerGuid]:SetInput(s_Speed, s_Extra, 0)
								end
							end
						-- secondary weapon, increase wait timer
						elseif s_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_1 then
							local s_LastWaypointAgain = self.m_CustomTrace[l_PlayerGuid]:GetLast()
							self.m_CustomTrace[l_PlayerGuid]:ClearSelection()
							self.m_CustomTrace[l_PlayerGuid]:Select(l_PlayerGuid, s_LastWaypointAgain)
							self.m_CustomTrace[l_PlayerGuid]:SetInput(s_LastWaypointAgain.SpeedMode, s_LastWaypointAgain.ExtraMode,
								s_LastWaypointAgain.OptValue + p_DeltaTime)
						end

						self.m_CustomTraceDistance[l_PlayerGuid] = self.m_CustomTraceDistance[l_PlayerGuid] + s_LastDistance

						-- TODO: Send to Client UI:
						local s_TotalTraceDistance = self.m_CustomTraceDistance[l_PlayerGuid]
						local s_TotalTraceNodes = #self.m_CustomTrace[l_PlayerGuid]:Get()
						NetEvents:SendUnreliableToLocal("UI_ClientNodeEditor_TraceData", s_Player, s_TotalTraceNodes, s_TotalTraceDistance)
					end
				else
					-- collection is empty, stop the timer
					self.m_CustomTraceTimer[l_PlayerGuid] = -1
				end

				self.m_CustomTraceTimer[l_PlayerGuid] = 0
			end
		end
	end


	-- visible NODE distribution-handling
	if self.m_NodeSendUpdateTimer < 0.1 then
		self.m_NodeSendUpdateTimer = self.m_NodeSendUpdateTimer + p_DeltaTime
	else
		self.m_NodeSendUpdateTimer = 0.0

		-- ToDo: distribute load equally (multible Players)
		for l_PlayerGuid, l_Active in pairs(self.m_ActiveTracePlayers) do
			local s_Player = PlayerManager:GetPlayerByOnlineId(l_PlayerGuid)
			local s_FirstPath = true
			local s_Count = 0
			if not s_Player or not s_Player.soldier or not l_Active then
				goto continue
			end

			local s_NodesToDraw = {}

			-- selected + isTracepath + showOption (text, node, id)

			local s_PlayerPos = s_Player.soldier.worldTransform.trans
			local s_WaypointPaths = m_NodeCollection:GetPaths()
			for l_Path, _ in pairs(s_WaypointPaths) do
				if m_NodeCollection:IsPathVisible(l_Path) and l_Path >= self.m_lastDrawIndexPath[l_PlayerGuid] then
					local s_startIndex = 1

					if s_FirstPath then
						s_startIndex = self.m_lastDrawIndexNode[l_PlayerGuid] + 1

						if s_startIndex <= 0 then
							s_startIndex = 1
						end

						s_FirstPath = false
					end

					local s_FirstNode = s_WaypointPaths[l_Path][1]
					for l_Waypoint = s_startIndex, #s_WaypointPaths[l_Path] do
						local l_Node = s_WaypointPaths[l_Path][l_Waypoint]
						if (l_Node.Next ~= false and l_Node.Previous ~= false) then -- removed node?

							local s_DrawNode = false
							local s_DrawLine = false
							local s_DrawText = false
							local s_IsSelected = false

							local s_Distance = m_NodeCollection:GetDistance(l_Node, s_PlayerPos)
							if s_Distance <= Config.WaypointRange then
								s_DrawNode = true
							end
							if s_Distance <= Config.LineRange then
								s_DrawLine = true
							end
							if s_Distance <= Config.TextRange then
								s_DrawText = true
							end

							-- display all selected nodes
							if m_NodeCollection:IsSelected(l_PlayerGuid, l_Node) then
								s_IsSelected = true
							end

							s_Count = s_Count + 1

							if s_DrawNode or s_DrawLine or s_DrawText or s_IsSelected then
								local s_DataNode = {
									Node = {},
									DrawNode = s_DrawNode,
									DrawLine = s_DrawLine,
									DrawText = s_DrawText,
									IsSelected = s_IsSelected,
									Objectives = {},
									Vehicles = {},
									Reverse = (s_FirstNode.OptValue == 0XFF),
									Links = {},
									IsTrace = false,
									IsOthersTrace = false
								}

								-- fill tables
								if l_Node.Data.Links then
									for i = 1, #l_Node.Data.Links do
										local s_LinkNode = m_NodeCollection:Get(l_Node.Data.Links[i])
										if s_LinkNode then
											table.insert(s_DataNode.Links, s_LinkNode.Position)
										end
									end
								end

								for l_Key, l_Value in pairs(l_Node) do
									if (l_Key ~= 'Next' and l_Key ~= 'Previous') then
										s_DataNode.Node[l_Key] = l_Value
									end
								end

								if s_FirstNode.Data.Objectives then
									for _, l_Objective in pairs(s_FirstNode.Data.Objectives) do
										table.insert(s_DataNode.Objectives, l_Objective)
									end
								end

								if s_FirstNode.Data.Vehicles then
									for _, l_Vehicle in pairs(s_FirstNode.Data.Vehicles) do
										table.insert(s_DataNode.Vehicles, l_Vehicle)
									end
								end

								table.insert(s_NodesToDraw, s_DataNode)
								if s_Count >= Config.NodesPerCycle and l_Waypoint < #s_WaypointPaths[l_Path] then
									self.m_lastDrawIndexNode[l_PlayerGuid] = l_Waypoint
									self.m_lastDrawIndexPath[l_PlayerGuid] = l_Path
									NetEvents:SendUnreliableToLocal('ClientNodeEditor:DrawNodes', s_Player, s_NodesToDraw, false) -- send all nodes that are visible for the player
									return
								end
							end
						end
					end
				end
			end

			if self.m_lastDrawIndexPath[l_PlayerGuid] ~= 99999 then
				self.m_lastDrawIndexNode[l_PlayerGuid] = 0
			end

			self.m_lastDrawIndexPath[l_PlayerGuid] = 99999

			-- custom trace of player
			-- TODO: also show active Traces of other players with other color?
			if self.m_CustomTrace[l_PlayerGuid] then
				local s_CustomWaypoints = self.m_CustomTrace[l_PlayerGuid]:Get()
				for i = self.m_lastDrawIndexNode[l_PlayerGuid] + 1, #s_CustomWaypoints do
					local l_Node = s_CustomWaypoints[i]
					local s_DrawNode = false
					local s_DrawLine = false
					local s_DrawText = false
					local s_IsSelected = false

					local s_Distance = m_NodeCollection:GetDistance(l_Node, s_PlayerPos)
					if s_Distance <= Config.WaypointRange then
						s_DrawNode = true
					end
					if s_Distance <= Config.LineRange then
						s_DrawLine = true
					end

					s_Count = s_Count + 1

					if s_DrawNode or s_DrawLine or s_DrawText then

						local s_DataNode = {
							Node = {},
							DrawNode = s_DrawNode,
							DrawLine = s_DrawLine,
							DrawText = s_DrawText,
							IsSelected = s_IsSelected,
							IsTrace = true,
							IsOthersTrace = false
						}

						-- fill tables
						for l_Key, l_Value in pairs(l_Node) do
							if (l_Key ~= 'Next' and l_Key ~= 'Previous') then
								s_DataNode.Node[l_Key] = l_Value
							end
						end

						table.insert(s_NodesToDraw, s_DataNode)
						if s_Count >= Config.NodesPerCycle and i < #s_CustomWaypoints then
							self.m_lastDrawIndexNode[l_PlayerGuid] = i
							NetEvents:SendUnreliableToLocal('ClientNodeEditor:DrawNodes', s_Player, s_NodesToDraw, false)
							return
						end
					end

				end
			end

			NetEvents:SendUnreliableToLocal('ClientNodeEditor:DrawNodes', s_Player, s_NodesToDraw, true) -- send all nodes that are visible for the player
			-- reset vars
			self.m_lastDrawIndexPath[l_PlayerGuid] = 0
			self.m_lastDrawIndexNode[l_PlayerGuid] = 0

			::continue::
		end
	end
end

function NodeEditor:OnEngineUpdateOld(p_DeltaTime, p_SimulatioonDeltaTime)
	-- receiving nodes from player takes priority over sending
	if self.m_NodeReceiveTimer >= 0 and self.m_PlayerSendingNodes ~= nil then
		self.m_NodeReceiveTimer = self.m_NodeReceiveTimer + p_DeltaTime

		if self.m_NodeReceiveTimer >= self.m_NodeReceiveDelay then
			NetEvents:SendToLocal('ClientNodeEditor:SendNodes', self.m_PlayerSendingNodes, #m_NodeCollection:Get())
			self.m_NodeReceiveTimer = -1
		end

		return
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
	table.insert(self.m_PlayersReceivingNodes, { Player = p_Player, Index = 1, Nodes = s_Nodes, BatchSendDelay = 0 })
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
	ChatManager:Yell(Language:I18N('Server recieved %d nodes.', #s_NodesToCheck), 5.5)
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
	---@type NodeEditor
	g_NodeEditor = NodeEditor()
end

return g_NodeEditor
