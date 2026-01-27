---@class NodeEditor
---@overload fun():NodeEditor
NodeEditor = class('NodeEditor')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Logger
local m_Logger = Logger('NodeEditor', Debug.Server.NODEEDITOR)

function NodeEditor:__init()
	self:RegisterVars()
end

function NodeEditor:RegisterVars()
	self.m_ActiveTracePlayers = {}
	self.m_ActivePlayers = {}
	self.m_DataWasRequested = false

	self.m_CustomTrace = {}
	self.m_NodeWaitTimer = {}
	self.m_CustomTraceIndex = {}
	self.m_CustomTraceTimer = {}
	self.m_CustomTraceDistance = {}
	self.m_CustomTraceLastNodeIndex = {}
	self.m_JumpDetected = {}

	self.m_lastDrawIndexNode = {}
	self.m_lastDrawIndexPath = {}

	self.m_NodeOperation = ''

	self.m_NodeSendUpdateTimer = 0
end

function NodeEditor:RegisterCustomEvents()
	-- Remove them?
	-- NetEvents:Subscribe('UI_Request_Save_Settings', self, self.OnUIRequestSaveSettings)

	-- EDIT-Events from Client.
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
	NetEvents:Subscribe('NodeEditor:TeleportToEdge', self, self.OnTeleportToEdge)
	NetEvents:Subscribe('NodeEditor:SplitNode', self, self.OnSplitNode)
	NetEvents:Subscribe('NodeEditor:RemoveNode', self, self.OnRemoveNode)

	NetEvents:Subscribe('NodeEditor:AddMcom', self, self.OnAddMcom)
	NetEvents:Subscribe('NodeEditor:AddVehicle', self, self.OnAddVehicle)
	NetEvents:Subscribe('NodeEditor:ExitVehicle', self, self.OnExitVehicle)
	NetEvents:Subscribe('NodeEditor:CustomAction', self, self.OnCustomAction)
	NetEvents:Subscribe('NodeEditor:AddVehiclePath', self, self.OnAddVehiclePath)
	NetEvents:Subscribe('NodeEditor:AddObjective', self, self.OnAddObjective)
	NetEvents:Subscribe('NodeEditor:RemoveObjective', self, self.OnRemoveObjective)
	NetEvents:Subscribe('NodeEditor:SetVehicleSpawn', self, self.OnSetVehicleSpawn)
	NetEvents:Subscribe('NodeEditor:RemoveData', self, self.OnRemoveData)

	NetEvents:Subscribe('NodeEditor:RemoveAllObjectives', self, self.OnRemoveAllObjectives)
	NetEvents:Subscribe('NodeEditor:SetPathLoops', self, self.OnSetLoopMode)
	NetEvents:Subscribe('NodeEditor:AddSpawnPath', self, self.OnSetSpawnPath)

	NetEvents:Subscribe('NodeEditor:SpawnBot', self, self.OnSpawnBot)
	NetEvents:Subscribe('NodeEditor:UpdatePos', self, self.OnUpdatePos)
	NetEvents:Subscribe('NodeEditor:AddNode', self, self.OnAddNode)

	NetEvents:Subscribe('NodeEditor:JumpDetected', self, self.OnJumpDetected)

	NetEvents:Subscribe('NodeEditor:RequestData', self, self.OnRequestData)


	-- To-do: fill.
end

-- =============================================
-- Events
-- =============================================

function NodeEditor:OnAddNode(p_Player)
	local s_Result, s_Message = m_NodeCollection:Add(p_Player.onlineId)

	if not s_Result then
		self:Log(p_Player, s_Message)
		return false
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	-- If selected is 0 or 1, we created a new node.
	-- Clear selection, select new node, change to move mode.
	-- Otherwise we just connected two nodes, don't change selection.
	if s_Result ~= nil and #s_Selection <= 1 then
		m_NodeCollection:ClearSelection(p_Player.onlineId)
		m_NodeCollection:Select(p_Player.onlineId, s_Result)

		local s_NewNodes = self:GetNodesForPlayer({ s_Result })
		self:SendToAllPlayers('ClientNodeEditor:AddNodes', s_NewNodes)
		NetEvents:SendToLocal('ClientNodeEditor:SelectNewNode', p_Player, s_Result.ID)
	end

	return true
end

---@param p_Player Player
---@param p_UpdateData table
function NodeEditor:OnUpdatePos(p_Player, p_UpdateData)
	for _, l_UpdateItem in pairs(p_UpdateData) do
		local s_NodeToUpdate = m_NodeCollection:Get(l_UpdateItem.ID)
		if s_NodeToUpdate then
			m_NodeCollection:Update(s_NodeToUpdate, {
				Position = l_UpdateItem.Pos,
			})
		end
	end

	local s_NodesToSend = {}
	for _, l_UpdateItem in pairs(p_UpdateData) do
		s_NodesToSend[#s_NodesToSend + 1] = m_NodeCollection:Get(l_UpdateItem.ID)
	end
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_NodesToSend))
end

---@param p_Player Player
function NodeEditor:OnAddMcom(p_Player)
	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection ~= 1 then
		self:Log(p_Player, 'Must select one node')
		return false
	end

	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local action = {
			type = 'mcom',
			inputs = { EntryInputActionEnum.EIAInteract },
			time = 6.0,
			yaw = p_Player.input.authoritativeAimingYaw,
			pitch = p_Player.input.authoritativeAimingPitch,
		}
		s_Selection[i].Data.Action = action
		self:Log(p_Player, 'Updated Waypoint: %s', s_Selection[i].ID)
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))

	return true
end

---@param p_Player Player
function NodeEditor:OnAddVehicle(p_Player)
	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection ~= 1 then
		self:Log(p_Player, 'Must select one node')
		return
	end

	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local action = {
			type = 'vehicle',
			inputs = { EntryInputActionEnum.EIAInteract },
			time = 0.5,
			yaw = p_Player.input.authoritativeAimingYaw,
			pitch = p_Player.input.authoritativeAimingPitch,
		}
		s_Selection[i].Data.Action = action
		self:Log(p_Player, 'Updated Waypoint: %s', s_Selection[i].ID)
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))
end

---@param p_Player Player
function NodeEditor:OnExitVehicle(p_Player, p_Args)
	self.m_CommoRoseActive = false

	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection ~= 1 then
		self:Log(p_Player, 'Must select one node')
		return
	end

	local s_Data = p_Args[1] or 'false'
	self:Log(p_Player, 'Exit Vehicle (type): %s', g_Utilities:dump(s_Data, true))

	local s_OnlyPassengers = not (s_Data:lower() == 'false' or s_Data == '0')

	for i = 1, #s_Selection do
		local action = {
			type = 'exit',
			onlyPassengers = s_OnlyPassengers,
			inputs = { EntryInputActionEnum.EIAInteract },
			time = 0.5,
		}
		s_Selection[i].Data.Action = action
		self:Log(p_Player, 'Updated Waypoint: %s', s_Selection[i].ID)
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))

	return
end

---@param p_Player Player
---@param p_Args table
function NodeEditor:OnCustomAction(p_Player, p_Args)
	self.m_CommoRoseActive = false

	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection ~= 1 then
		self:Log(p_Player, 'Must select one node')
		return
	end

	if #p_Args == 0 then
		self:Log(p_Player, 'Must contain action type')
		return
	end

	for i = 1, #s_Selection do
		local action = {
			type = p_Args[1],
			time = 5.0,
			inputs = {},
			yaw = p_Player.input.authoritativeAimingYaw,
			pitch = p_Player.input.authoritativeAimingPitch,
		}

		s_Selection[i].Data.Action = action
		self:Log(p_Player, 'Updated Waypoint: %s', s_Selection[i].ID)
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))
end

---@param p_Player Player
---@param p_Args table
function NodeEditor:OnAddVehiclePath(p_Player, p_Args)
	local s_Data = table.concat(p_Args or { 'land' }, ' ')
	self:Log(p_Player, 'Add Vehicle (type): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	local s_UpdatedNodes = {}
	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true

			if s_Data == "clear" then
				s_Waypoint.Data.Vehicles = {}
				self:Log(p_Player, 'Updated Waypoint: %s', s_Waypoint.ID)
				s_UpdatedNodes[#s_UpdatedNodes + 1] = s_Waypoint
			else
				local s_Vehicles = s_Waypoint.Data.Vehicles or {}
				local s_InTable = false

				for j = 1, #s_Vehicles do
					if (s_Vehicles[j] == s_Data) then
						s_InTable = true
						break
					end
				end

				if not s_InTable then
					s_Vehicles[#s_Vehicles + 1] = s_Data
					s_Waypoint.Data.Vehicles = s_Vehicles
					self:Log(p_Player, 'Updated Waypoint: %s', s_Waypoint.ID)
					s_UpdatedNodes[#s_UpdatedNodes + 1] = s_Waypoint
				end
			end
		end
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_UpdatedNodes))

	return true
end

---@param p_Player Player
function NodeEditor:OnSetVehicleSpawn(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	local s_UpdatedNodes = {}
	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true

			local s_Objectives = s_Waypoint.Data.Objectives or {}
			if #s_Objectives == 1 and string.find(s_Objectives[1], "vehicle") ~= nil then
				if string.find(s_Objectives[1], "spawn") == nil then
					s_Waypoint.Data.Objectives = { "spawn " .. s_Objectives[1] }
					self:Log(p_Player, 'Updated Waypoint: %s', s_Waypoint.ID)
					s_UpdatedNodes[#s_UpdatedNodes + 1] = s_Waypoint
				else
					self:Log(p_Player, 'Path is already spawnable')
				end
			else
				self:Log(p_Player, 'Path must have one vehicle objective')
			end
		end
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_UpdatedNodes))
	return true
end

-- EVENTS for editing.
---@param p_Player Player
---@param p_Args table
function NodeEditor:OnAddObjective(p_Player, p_Args)
	local s_Data = table.concat(p_Args or {}, ' ')
	s_Data = s_Data:lower()
	self:Log(p_Player, 'Add Objective (data): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	local s_UpdatedNodes = {}
	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

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
				s_Objectives[#s_Objectives + 1] = s_Data
				s_Waypoint.Data.Objectives = s_Objectives
				s_UpdatedNodes[#s_UpdatedNodes + 1] = s_Waypoint
				self:Log(p_Player, 'Updated Waypoint: %s', s_Waypoint.ID)
			end
		end
	end
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_UpdatedNodes))

	return true
end

---@param p_Player Player
---@param p_Args table
function NodeEditor:OnRemoveObjective(p_Player, p_Args)
	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Data = table.concat(p_Args or {}, ' ')
	s_Data = s_Data:lower()
	self:Log(p_Player, 'Remove Objective (data): %s', g_Utilities:dump(s_Data, true))

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	local s_UpdatedNodes = {}
	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true

			local s_Objectives = s_Waypoint.Data.Objectives or {}
			local s_NewObjectives = {}

			for j = 1, #s_Objectives do
				if (s_Objectives[j] ~= s_Data) then
					s_NewObjectives[#s_NewObjectives + 1] = s_Objectives[j]
				end
			end

			s_Waypoint.Data.Objectives = s_NewObjectives
			s_UpdatedNodes[#s_UpdatedNodes + 1] = s_Waypoint
			self:Log(p_Player, 'Updated Waypoint: %s', s_Waypoint.ID)
		end
	end
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_UpdatedNodes))
	return true
end

---@param p_Player Player
---@param p_Args table|nil
function NodeEditor:OnRemoveAllObjectives(p_Player, p_Args)
	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	local s_UpdatedNodes = {}
	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true
			s_Waypoint.Data.Objectives = {}
			s_UpdatedNodes[#s_UpdatedNodes + 1] = s_Waypoint
			self:Log(p_Player, 'Updated Waypoint: %s', s_Waypoint.ID)
		end
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_UpdatedNodes))

	return true
end

function NodeEditor:OnSetLoopMode(p_Player, p_Args)
	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Data = p_Args[1] or "false"
	self:Log(p_Player, 'Set loop-mode: %s', g_Utilities:dump(s_Data, true))

	local s_PathLoops = not (s_Data:lower() == "false" or s_Data == "0")

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	local s_UpdatedNodes = {}
	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_Waypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Waypoint.PathIndex] then
			s_DonePaths[s_Waypoint.PathIndex] = true

			if s_PathLoops then
				s_Waypoint.OptValue = 0
			else
				s_Waypoint.OptValue = 0XFF
			end
			m_NodeCollection:UpdateInputVar(s_Waypoint)
			s_UpdatedNodes[#s_UpdatedNodes + 1] = s_Waypoint
			self:Log(p_Player, 'Updated Waypoint: %s', s_Waypoint.ID)
		end
	end

	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_UpdatedNodes))

	return true
end

---@param p_Player Player
---@param p_Args table|nil
function NodeEditor:OnSetSpawnPath(p_Player, p_Args)
	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return false
	end

	local s_DonePaths = {}
	local s_UpdatedNodes = {}
	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		local s_LastWaypoint = m_NodeCollection:GetLast(s_Selection[i].PathIndex)

		if not s_DonePaths[s_Selection[i].PathIndex] then
			s_DonePaths[s_Selection[i].PathIndex] = true

			-- Find links (should be only one link on the last node)
			local s_Links = s_LastWaypoint.Data.Links

			local s_TargetObjective = ""

			if s_Links and #s_Links == 1 then
				-- Get objective of linked path.
				local s_LinkedWaypoint = m_NodeCollection:Get(s_Links[1])
				-- Check if only one objective.
				if s_LinkedWaypoint then
					local s_FirstOfLinkedPath = m_NodeCollection:GetFirst(s_LinkedWaypoint.PathIndex)
					if s_FirstOfLinkedPath and s_FirstOfLinkedPath.Data and s_FirstOfLinkedPath.Data.Objectives and #s_FirstOfLinkedPath.Data.Objectives == 1 then
						s_TargetObjective = s_FirstOfLinkedPath.Data.Objectives[1]
						local s_FirstWaypoint = m_NodeCollection:GetFirst(s_Selection[i].PathIndex)
						local s_SpawnObjective = "spawn " .. s_TargetObjective
						-- Add new objective to current path.
						s_FirstWaypoint.Data.Objectives = { s_SpawnObjective }
						s_UpdatedNodes[#s_UpdatedNodes + 1] = s_FirstWaypoint
						self:Log(p_Player, 'Updated Waypoint: %s', s_FirstWaypoint.ID)
					else
						self:Log(p_Player, 'Path must have one connection to target-objective on last node')
						return false
					end
				else
					self:Log(p_Player, 'Path must have one connection to target-objective on last node')
					return false
				end
			else
				self:Log(p_Player, 'Path must have one connection to target-objective on last node')
				return false
			end
		end
	end
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_UpdatedNodes))
	return true
end

---@param p_Player Player
function NodeEditor:OnRemoveData(p_Player)
	if not p_Player.soldier then
		self:Log(p_Player, 'Player must be alive')
		return
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select at least one node')
		return
	end

	self:Log(p_Player, 'Updating %d Possible Waypoints', (#s_Selection))

	for i = 1, #s_Selection do
		s_Selection[i].Data = {}
		self:Log(p_Player, 'Updated Waypoint: %s', s_Selection[i].ID)
	end
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))
end

function NodeEditor:GetNodesForPlayer(p_Nodes)
	local s_SerializedNodes = {}
	for _, l_Node in pairs(p_Nodes) do
		if l_Node.Next or l_Node.Prev then -- Only send nodes that aren't stale
			s_SerializedNodes[#s_SerializedNodes + 1] = {
				ID = l_Node.ID,
				Index = l_Node.Index,
				PathIndex = l_Node.PathIndex,
				PointIndex = l_Node.PointIndex,
				InputVar = l_Node.InputVar,
				Position = l_Node.Position,
				Data = l_Node.Data
			}
		end
	end
	return s_SerializedNodes
end

function NodeEditor:SendToAllPlayers(p_EventName, p_Data)
	for l_Index = 1, #self.m_ActivePlayers do
		local s_Player = PlayerManager:GetPlayerByOnlineId(self.m_ActivePlayers[l_Index])
		if s_Player then
			NetEvents:SendToLocal(p_EventName, s_Player, p_Data)
		end
	end
end

function NodeEditor:OnRequestData(p_Player)
	self.m_DataWasRequested = true
	local s_AllNodes = m_NodeCollection:Get()

	if not s_AllNodes then
		return
	end

	local s_SerializedNodes = self:GetNodesForPlayer(s_AllNodes)

	print('[NodeEditor] Sending ' .. tostring(#s_SerializedNodes) .. ' waypoints to client.')

	-- TODO: better handling here for all Players
	self:SendToAllPlayers('ClientNodeEditor:RevieveNodes', s_SerializedNodes)
	print('[NodeEditor] Sent waypoints to client.')
end

function NodeEditor:OnRemoveNode(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
	self:SendToAllPlayers('ClientNodeEditor:RemoveNodes', self:GetNodesForPlayer(s_Selection))

	local s_Result, s_Message = m_NodeCollection:Remove(p_Player.onlineId)
	if not s_Result then
		self:Log(p_Player, s_Message)
	end
end

---@param p_Player Player
function NodeEditor:OnTeleportToEdge(p_Player)
	local s_Result, s_Message = m_NodeCollection:TeleportToEdge(p_Player)
	if not s_Result then
		self:Log(p_Player, s_Message)
	end
end

---@param p_Player Player
function NodeEditor:OnSplitNode(p_Player)
	local s_Result, s_Message = m_NodeCollection:SplitSelection(p_Player.onlineId)
	if not s_Result then
		self:Log(p_Player, s_Message)
	else
		local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
		self:SendToAllPlayers("ClientNodeEditor:AddNodes", self:GetNodesForPlayer(s_Selection))
	end
end

---@param p_Player Player
function NodeEditor:OnMergeNodes(p_Player)
	local s_OriginalSelectionToRemove = self:GetNodesForPlayer(m_NodeCollection:GetSelected(p_Player.onlineId))
	local s_Result, s_Message = m_NodeCollection:MergeSelection(p_Player.onlineId)
	if not s_Result then
		self:Log(p_Player, s_Message)
	else
		table.remove(s_OriginalSelectionToRemove, 1) -- first node is only updated, rest is removed
		self:SendToAllPlayers("ClientNodeEditor:RemoveNodes", s_OriginalSelectionToRemove)
		local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
		self:SendToAllPlayers("ClientNodeEditor:UpdateNodes", self:GetNodesForPlayer(s_Selection))
	end
end

---@param p_Player Player
function NodeEditor:OnUnlinkNodes(p_Player)
	local s_Result, s_Message = m_NodeCollection:Unlink(p_Player.onlineId)
	if not s_Result then
		self:Log(p_Player, s_Message)
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))
end

---@param p_Player Player
function NodeEditor:OnLinkNodes(p_Player)
	local s_Result, s_Message = m_NodeCollection:Link(p_Player.onlineId)
	if not s_Result then
		self:Log(p_Player, s_Message)
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))
end

---@param p_Player Player
---@param p_Arg1 integer
---@param p_Arg2 integer
---@param p_Arg3 integer
function NodeEditor:OnSetInputNode(p_Player, p_Arg1, p_Arg2, p_Arg3)
	local s_Result, s_Message = m_NodeCollection:SetInput(p_Arg1, p_Arg2, p_Arg3)
	if not s_Result then
		self:Log(p_Player, s_Message)
	end

	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
	self:SendToAllPlayers('ClientNodeEditor:UpdateNodes', self:GetNodesForPlayer(s_Selection))
end

---@param p_Player Player
function NodeEditor:OnSpawnBot(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection > 0 then
		Events:Dispatch('BotEditor', p_Player, json.encode({
			action = 'bot_spawn_path',
			value = s_Selection[1].PathIndex,
			pointindex = s_Selection[1].PointIndex,
		}))
	end
end

---@param p_Player Player
---@param p_WaypointId integer|string
function NodeEditor:OnSelect(p_Player, p_WaypointId)
	m_NodeCollection:Select(p_Player.onlineId, p_WaypointId)
	self:UpdateSelection(p_Player)
end

---@param p_Player Player
---@param p_WaypointId integer|string
function NodeEditor:OnDeselect(p_Player, p_WaypointId)
	m_NodeCollection:Deselect(p_Player.onlineId, p_WaypointId)
	self:UpdateSelection(p_Player)
end

function NodeEditor:UpdateSelection(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
	local s_SelectionIDs = {}
	for _, l_Node in pairs(s_Selection) do
		s_SelectionIDs[#s_SelectionIDs + 1] = l_Node.ID
	end
	NetEvents:SendToLocal('ClientNodeEditor:UpdateSelection', p_Player, s_SelectionIDs)
end

---@param p_Player Player
function NodeEditor:OnSelectBetween(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection < 1 then
		self:Log(p_Player, 'Must select more than one node')
		return false
	end

	local s_BreakAt = (#m_NodeCollection:Get())
	local s_Current = 0
	local s_CurrentWaypoint = s_Selection[1]

	while s_CurrentWaypoint and s_CurrentWaypoint.Next and s_CurrentWaypoint.ID ~= s_Selection[#s_Selection].ID do
		m_NodeCollection:Select(p_Player.onlineId, s_CurrentWaypoint)
		s_Current = s_Current + 1

		if s_Current > s_BreakAt then
			break
		end

		s_CurrentWaypoint = s_CurrentWaypoint.Next
	end

	self:UpdateSelection(p_Player)
end

---@param p_Player Player
function NodeEditor:OnSelectNext(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection > 0 then
		if s_Selection[1].Next ~= false then
			m_NodeCollection:Select(p_Player.onlineId, s_Selection[1].Next)
		end
	else
		self:Log(p_Player, 'Must select at least one node')
	end

	self:UpdateSelection(p_Player)
end

---@param p_Player Player
function NodeEditor:OnSelectPrevious(p_Player)
	local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)

	if #s_Selection > 0 then
		if s_Selection[1].Next ~= false then
			m_NodeCollection:Select(p_Player.onlineId, s_Selection[1].Previous)
		end
	else
		self:Log(p_Player, 'Must select at least one node')
	end

	self:UpdateSelection(p_Player)
end

---@param p_Player Player
function NodeEditor:OnClearSelection(p_Player)
	m_NodeCollection:ClearSelection(p_Player.onlineId)
	self:UpdateSelection(p_Player)
end

-- =============================================
-- Level Events
-- =============================================

-- Management Events.
---@param p_Player Player
function NodeEditor:OnOpenEditor(p_Player)
	self.m_CustomTraceTimer[p_Player.onlineId] = -1
	self.m_lastDrawIndexNode[p_Player.onlineId] = 0
	self.m_lastDrawIndexPath[p_Player.onlineId] = 0
	self.m_ActiveTracePlayers[p_Player.onlineId] = true
end

---@param p_Player Player
function NodeEditor:OnCloseEditor(p_Player)
	self.m_ActiveTracePlayers[p_Player.onlineId] = false
end

-- =============================================
-- Trace Events
-- Trace Recording
-- =============================================
function NodeEditor:_getNewIndex()
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
		else
			-- Maybe the path was deleted.
			local s_PathIsDeleted = true
			for _, l_NodeInPath in pairs(s_AllPaths[i]) do
				if l_NodeInPath.Next ~= false or l_NodeInPath.Previous ~= false then
					s_PathIsDeleted = false
					break
				end
			end
			if s_PathIsDeleted then
				return i
			end
		end
	end

	return s_HighestIndex + 1
end

---@param p_Player Player
function NodeEditor:StartTrace(p_Player)
	if not p_Player.soldier then
		return
	end

	if self.m_CustomTrace[p_Player.onlineId] ~= nil then
		self.m_CustomTrace[p_Player.onlineId]:Clear()
	end

	self.m_CustomTrace[p_Player.onlineId] = NodeCollection(true)
	self.m_CustomTraceTimer[p_Player.onlineId] = 0
	self.m_JumpDetected[p_Player.onlineId] = 0
	self.m_NodeWaitTimer[p_Player.onlineId] = 0
	self.m_CustomTraceIndex[p_Player.onlineId] = self:_getNewIndex()
	self.m_CustomTraceLastNodeIndex[p_Player.onlineId] = 0
	self.m_CustomTraceDistance[p_Player.onlineId] = 0

	local s_PlayerPos = nil
	if not p_Player.attachedControllable then
		s_PlayerPos = p_Player.soldier.worldTransform.trans:Clone()
	else
		s_PlayerPos = p_Player.controlledControllable.transform.trans:Clone()
	end

	local s_FirstWaypoint = self.m_CustomTrace[p_Player.onlineId]:Create({
		Position = s_PlayerPos,
	})
	self.m_CustomTrace[p_Player.onlineId]:ClearSelection()
	self.m_CustomTrace[p_Player.onlineId]:Select(nil, s_FirstWaypoint)

	self:Log(p_Player, 'Custom Trace Started')

	local s_TotalTraceDistance = self.m_CustomTraceDistance[p_Player.onlineId]
	local s_TraceNodes = self.m_CustomTrace[p_Player.onlineId]:Get()
	local s_TotalTraceNodes = #s_TraceNodes
	local s_NodesToSend = {}
	for i = self.m_CustomTraceLastNodeIndex[p_Player.onlineId] + 1, s_TotalTraceNodes do
		s_NodesToSend[#s_NodesToSend + 1] = {
			Position = s_TraceNodes[i].Position,
		}
	end
	local s_TraceIndex = self.m_CustomTraceIndex[p_Player.onlineId] -- To-do: not really needed?
	NetEvents:SendToLocal('UI_ClientNodeEditor_TraceData', p_Player, s_TotalTraceNodes, s_TotalTraceDistance, s_TraceIndex, true, s_NodesToSend)
	self.m_CustomTraceLastNodeIndex[p_Player.onlineId] = s_TotalTraceNodes
end

---@param p_Player Player
function NodeEditor:EndTrace(p_Player)
	self.m_CustomTraceTimer[p_Player.onlineId] = -1
	NetEvents:SendToLocal('UI_ClientNodeEditor_TraceData', p_Player, nil, nil, nil, false, nil)

	local s_FirstWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetFirst()

	if s_FirstWaypoint then
		local s_FirstWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetFirst()

		local s_StartPos = s_FirstWaypoint.Position + Vec3.up
		local s_EndPos = self.m_CustomTrace[p_Player.onlineId]:GetLast().Position + Vec3.up
		local s_RayHits = nil

		local s_FlagsMaterial = MaterialFlags.MfNoCollisionResponse
		---@type RayCastFlags
		local s_RaycastFlags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll |
			RayCastFlags.CheckDetailMesh


		s_RayHits = RaycastManager:DetailedRaycast(s_StartPos, s_EndPos, 2, s_FlagsMaterial, s_RaycastFlags)

		self.m_CustomTrace[p_Player.onlineId]:ClearSelection()
		self.m_CustomTrace[p_Player.onlineId]:Select(nil, s_FirstWaypoint)

		if #s_RayHits == 0 or (p_Player.attachedControllable and #s_RayHits == 1 and s_RayHits[1].rigidBody:Is("DynamicPhysicsEntity")) then
			-- Clear view from start node to end node, path loops.
			self.m_CustomTrace[p_Player.onlineId]:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0)
		else
			-- No clear view, path should just invert at the end.
			self.m_CustomTrace[p_Player.onlineId]:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0XFF)
		end

		self.m_CustomTrace[p_Player.onlineId]:ClearSelection()
	end

	self:Log(p_Player, 'Custom Trace Ended')
end

---@param p_Player Player
function NodeEditor:ClearTrace(p_Player)
	-- Check if custom-Trace is available. Otherwise, delete selected trace.
	if self.m_CustomTrace[p_Player.onlineId] and #self.m_CustomTrace[p_Player.onlineId]:Get() > 0 then
		self.m_CustomTraceTimer[p_Player.onlineId] = -1
		self.m_CustomTraceIndex[p_Player.onlineId] = self:_getNewIndex()
		self.m_CustomTraceDistance[p_Player.onlineId] = 0
		self.m_CustomTrace[p_Player.onlineId]:Clear()

		-- To-do: Client: set UI.
		local s_TotalTraceDistance = self.m_CustomTraceDistance[p_Player.onlineId]
		local s_TotalTraceNodes = #self.m_CustomTrace[p_Player.onlineId]:Get()
		local s_TraceIndex = self.m_CustomTraceIndex[p_Player.onlineId] -- To-do: not really needed ?
		NetEvents:SendToLocal('UI_ClientNodeEditor_TraceData', p_Player, s_TotalTraceNodes, s_TotalTraceDistance, s_TraceIndex,
			false, nil)
		NetEvents:SendToLocal('ClientNodeEditor:ClearCustomTrace', p_Player)
		self:Log(p_Player, 'Custom Trace Cleared')
	else
		-- Delete paths of selection.
		local s_PathIndexes = {}

		-- Detect selected path(s).
		local s_Selection = m_NodeCollection:GetSelected(p_Player.onlineId)
		for l_Index = 1, #s_Selection do
			local l_Node = s_Selection[l_Index]
			local s_PathIndex = l_Node.PathIndex
			s_PathIndexes[s_PathIndex] = true -- Add more checks?
		end

		for l_PathIndex in pairs(s_PathIndexes) do
			if s_PathIndexes[l_PathIndex] == true then
				local s_PathWaypoints = m_NodeCollection:Get(nil, l_PathIndex)

				if #s_PathWaypoints > 0 then
					m_NodeCollection:RemovePath(l_PathIndex)
					self:SendToAllPlayers('ClientNodeEditor:ClearTrace', l_PathIndex)
					self:Log(p_Player, 'Trace Nr. %d Cleared', l_PathIndex)
				end
			end
		end
	end
end

function NodeEditor:IsSavingOrLoading()
	return self.m_NodeOperation ~= ''
end

---@param p_Player Player
---@param p_PathIndex integer|number
---@return boolean
function NodeEditor:SaveTrace(p_Player, p_PathIndex)
	if self:IsSavingOrLoading() then
		self:Log(p_Player, 'Operation in progress, please wait...')
		return false
	end

	if type(p_PathIndex) == 'table' then
		p_PathIndex = p_PathIndex[1]
	end

	if self.m_CustomTrace[p_Player.onlineId] == nil or #self.m_CustomTrace[p_Player.onlineId]:Get() == 0 then
		self:Log(p_Player, 'Custom Trace is empty')
		return false
	end

	self.m_NodeOperation = 'Custom Trace'

	local s_PathCount = m_NodeCollection:GetNrOfPaths()
	p_PathIndex = tonumber(p_PathIndex) or self:_getNewIndex()
	local s_CurrentWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetFirst()
	local s_ReferrenceWaypoint = nil
	local s_Direction = 'Next'

	if s_PathCount == 0 then
		s_CurrentWaypoint.PathIndex = p_PathIndex
		s_ReferrenceWaypoint = m_NodeCollection:Create(s_CurrentWaypoint)
		s_CurrentWaypoint = s_CurrentWaypoint.Next
	end

	-- Check for first index smaller first path.
	local s_LowestPathIndex = 1
	if m_NodeCollection:GetFirst(p_PathIndex) then
		s_LowestPathIndex = m_NodeCollection:GetFirst(p_PathIndex).PathIndex
	end

	if s_PathCount > 0 then
		if p_PathIndex <= s_LowestPathIndex then
			-- Remove existing path and replace with current.
			if #m_NodeCollection:Get(nil, p_PathIndex) > 0 then
				s_CurrentWaypoint.PathIndex = p_PathIndex
				s_ReferrenceWaypoint = m_NodeCollection:Create(s_CurrentWaypoint)
				s_CurrentWaypoint = s_CurrentWaypoint.Next
			else
				-- Get first node of first path, we'll InsertBefore the new nodes.
				s_ReferrenceWaypoint = m_NodeCollection:GetFirst()
				s_CurrentWaypoint = self.m_CustomTrace[p_Player.onlineId]:GetLast()
				s_Direction = 'Previous'
			end

			-- p_PathIndex is greater or equal 2.
			-- Get the node before the start of the specified path, if the path is existing, otherwise use the end.
		else
			if #m_NodeCollection:Get(nil, p_PathIndex) > 0 then
				s_ReferrenceWaypoint = m_NodeCollection:GetFirst(p_PathIndex).Previous
			else
				s_ReferrenceWaypoint = m_NodeCollection:GetLast()
			end
		end

		-- We might have a path to delete.
		if p_PathIndex > 0 then
			local s_PathWaypoints = m_NodeCollection:Get(nil, p_PathIndex)

			if #s_PathWaypoints > 0 then
				m_NodeCollection:RemovePath(p_PathIndex)
			end
		end
	end

	collectgarbage('collect')

	-- Merge custom trace into main node collection.
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
	self:Log(p_Player, 'Custom Trace Saved to Path: %d', p_PathIndex)
	self.m_NodeOperation = ''

	NetEvents:SendToLocal('ClientNodeEditor:ClearCustomTrace', p_Player)
	local s_NewPathNodes = m_NodeCollection:Get(nil, p_PathIndex)
	self:SendToAllPlayers('ClientNodeEditor:AddNodes', self:GetNodesForPlayer(s_NewPathNodes))
	return true
end

-- COMMON EVENTS.
---@param p_LevelName string
---@param p_GameMode string
---@param p_CustomGameMode string|nil
function NodeEditor:OnLevelLoaded(p_LevelName, p_GameMode, p_CustomGameMode)
	self:Log(nil, 'Level Load: %s %s', p_LevelName, p_GameMode)

	local s_GameModeToLoad = p_GameMode

	-- check if the mapfile is available. If not, check if a valid alternative is available
	if p_CustomGameMode and m_NodeCollection:IsMapAvailable(p_LevelName, p_CustomGameMode) then
		s_GameModeToLoad = p_CustomGameMode
	elseif not m_NodeCollection:IsMapAvailable(p_LevelName, s_GameModeToLoad) then
		-- Try Convert map names if needed.
		if Globals.IsTdm or Globals.IsGm or Globals.IsScavenger then
			s_GameModeToLoad = 'TeamDeathMatch0' -- Paths are compatible.
		end

		if p_GameMode == 'BFLAG0' then
			s_GameModeToLoad = 'BFLAG'
		end

		if p_LevelName == 'MP_Subway' and p_GameMode == 'ConquestSmall0' then
			s_GameModeToLoad = 'ConquestLarge0' -- Paths are the same.
		end

		if p_LevelName == 'XP5_003' and p_GameMode == 'ConquestLarge0' then
			s_GameModeToLoad = 'ConquestSmall0' -- Paths are the same.
		end

		if p_LevelName == 'XP4_Rubble' and p_GameMode == 'ConquestAssaultLarge0' then
			s_GameModeToLoad = 'ConquestAssaultSmall0' -- Paths are the same.
		end
	end

	m_NodeCollection:StartLoad(p_LevelName, s_GameModeToLoad)
end

function NodeEditor:Reload()
	self:Clear()
	m_NodeCollection:Reload()
end

function NodeEditor:EndOfLoad()
	m_NodeCollection:ParseObjectives()
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

	self:Log(nil, 'Load -> Stale Nodes: %d', s_Counter)
	if self.m_DataWasRequested then
		self:OnRequestData() -- send nodes to all players
	end
end

function NodeEditor:RefreshWaypointsOnClient()
	self:OnRequestData() -- send nodes to all players
end

function NodeEditor:Clear()
	m_NodeCollection:Clear()
	self:SendToAllPlayers('ClientNodeEditor:ClearAll')
end

---VEXT Shared Level:Destroy Event
function NodeEditor:OnLevelDestroy()
	m_NodeCollection:Clear()
	self:RegisterVars()
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
	self.m_CustomTrace[p_Player.onlineId] = nil

	for l_Index = 1, #self.m_ActivePlayers do
		if self.m_ActivePlayers[l_Index] == p_Player.onlineId then
			table.remove(self.m_ActivePlayers, l_Index)
			break
		end
	end
end

---VEXT Server Player:Destroyed Event
---@param p_Player Player
function NodeEditor:OnPlayerDestroyed(p_Player)
end

---@param p_Player Player
function NodeEditor:OnJumpDetected(p_Player)
	if p_Player and p_Player.soldier and self.m_ActiveTracePlayers[p_Player.onlineId] and self.m_CustomTraceTimer[p_Player.onlineId] >= 0 then
		self.m_JumpDetected[p_Player.onlineId] = true
	end
end

-- =============================================
-- Update Events
-- =============================================
---VEXT Shared Engine:Update Event
---@param p_DeltaTime number
---@param p_SimulationDeltaTime number
function NodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	-- SAVING.
	if m_NodeCollection:UpdateSaving() then
		return
	end
	-- LOADING.
	if m_NodeCollection:UpdateLoading() then
		return
	end

	-- TRACE-Handling.
	for l_PlayerGuid, l_Active in pairs(self.m_ActiveTracePlayers) do
		local s_Player = PlayerManager:GetPlayerByOnlineId(l_PlayerGuid)
		if (s_Player and s_Player.soldier and l_Active and self.m_CustomTraceTimer[l_PlayerGuid] >= 0) then
			self.m_CustomTraceTimer[l_PlayerGuid] = self.m_CustomTraceTimer[l_PlayerGuid] + p_DeltaTime

			local s_PlayerPos = nil
			if not s_Player.attachedControllable then
				s_PlayerPos = s_Player.soldier.worldTransform.trans:Clone()
			else
				s_PlayerPos = s_Player.controlledControllable.transform.trans:Clone()
			end

			if self.m_CustomTraceTimer[l_PlayerGuid] > Config.TraceDelta then
				local s_LastWaypoint = self.m_CustomTrace[l_PlayerGuid]:GetLast()

				if s_LastWaypoint then
					local s_LastDistance = s_LastWaypoint.Position:Distance(s_PlayerPos)

					if s_LastDistance >= Config.TraceDelta then
						-- Primary weapon, record movement.
						if s_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_0 then
							self.m_NodeWaitTimer[l_PlayerGuid] = 0.0

							local s_NewWaypoint, s_Msg = self.m_CustomTrace[l_PlayerGuid]:Add()
							self.m_CustomTrace[l_PlayerGuid]:Update(s_NewWaypoint, {
								Position = s_PlayerPos,
							})
							self.m_CustomTrace[l_PlayerGuid]:ClearSelection()
							self.m_CustomTrace[l_PlayerGuid]:Select(nil, s_NewWaypoint)

							local s_Speed = BotMoveSpeeds.NoMovement -- 0 = wait, 1 = prone ... (4 Bits).
							local s_Extra = 0   -- 0 = nothing, 1 = jump ... (4 Bits).

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
								if s_Player.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then -- Record only if moving.
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

									if self.m_JumpDetected[l_PlayerGuid] then
										s_Extra = 1
									end

									self.m_CustomTrace[l_PlayerGuid]:SetInput(s_Speed, s_Extra, 0)
								end
							end

							self.m_CustomTraceDistance[l_PlayerGuid] = self.m_CustomTraceDistance[l_PlayerGuid] + s_LastDistance
							-- Secondary weapon, increase wait timer.
						elseif s_Player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_1 then
							self.m_NodeWaitTimer[l_PlayerGuid] = self.m_NodeWaitTimer[l_PlayerGuid] + Config.TraceDelta
							local s_LastWaypointAgain = self.m_CustomTrace[l_PlayerGuid]:GetLast()
							self.m_CustomTrace[l_PlayerGuid]:ClearSelection()
							self.m_CustomTrace[l_PlayerGuid]:Select(nil, s_LastWaypointAgain)
							self.m_CustomTrace[l_PlayerGuid]:SetInput(0, s_LastWaypointAgain.ExtraMode,
								math.floor(self.m_NodeWaitTimer[l_PlayerGuid]))
						end

						local s_TotalTraceDistance = self.m_CustomTraceDistance[l_PlayerGuid]
						local s_TraceNodes = self.m_CustomTrace[l_PlayerGuid]:Get()
						local s_TotalTraceNodes = #s_TraceNodes
						local s_NodesToSend = {}
						for i = self.m_CustomTraceLastNodeIndex[l_PlayerGuid] + 1, s_TotalTraceNodes do
							s_NodesToSend[#s_NodesToSend + 1] = {
								Position = s_TraceNodes[i].Position,
							}
						end
						NetEvents:SendToLocal('UI_ClientNodeEditor_TraceData', s_Player, s_TotalTraceNodes, s_TotalTraceDistance, nil, nil, s_NodesToSend)
						self.m_CustomTraceLastNodeIndex[l_PlayerGuid] = s_TotalTraceNodes
					end
				else
					-- Collection is empty, stop the timer.
					self.m_CustomTraceTimer[l_PlayerGuid] = -1
				end

				self.m_CustomTraceTimer[l_PlayerGuid] = 0
				self.m_JumpDetected[l_PlayerGuid] = false
			end
		end
	end
end

-- =============================================
-- Functions
-- =============================================

function NodeEditor:RegisterActivePlayer(p_Player)
	-- Check if the player is already listed
	if table.has(self.m_ActivePlayers, p_Player.onlineId) then
		return
	end

	self.m_ActivePlayers[#self.m_ActivePlayers + 1] = p_Player.onlineId
end

function NodeEditor:Log(p_Player, ...)
	local s_MessageString = Language:I18N(...)
	m_Logger:Write(s_MessageString)
	-- Send message to client as well.
	if p_Player and table.has(self.m_ActivePlayers, p_Player.onlineId) then
		-- Check if the player is already listed
		ChatManager:SendMessage('TRACE: ' .. s_MessageString, p_Player)
	end
end

if g_NodeEditor == nil then
	---@type NodeEditor
	g_NodeEditor = NodeEditor()
end

return g_NodeEditor
