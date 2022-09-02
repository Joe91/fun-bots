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
	self.m_BotVision = {}
	self.m_Debugprints = 0


	
	self.m_ActiveTracePlayers = {}

	self.m_CustomTrace = {}
	self.m_CustomTraceIndex = {}
	self.m_CustomTraceTimer = {}
	self.m_CustomTraceDelay = Config.TraceDelta
	self.m_CustomTraceDistance = {}
	self.m_CustomTraceSaving = false

	self.m_NodeOperation = ''

	self.m_NodeSendUpdateTimer = 0
end

function NodeEditor:RegisterCustomEvents()
	-- management:
	-- Open Editor
	-- Close Editor

	-- Engine Update()


	NetEvents:Subscribe('NodeEditor:RequestNodes', self, self.OnRequestNodes)
	NetEvents:Subscribe('NodeEditor:SendNodes', self, self.OnSendNodes)
	NetEvents:Subscribe('NodeEditor:ReceivingNodes', self, self.OnReceiveNodes)
	NetEvents:Subscribe('NodeEditor:Create', self, self.OnCreate)
	NetEvents:Subscribe('NodeEditor:Init', self, self.OnInit)
	NetEvents:Subscribe('NodeEditor:WarpTo', self, self.OnWarpTo)
	-- NetEvents:Subscribe('UI_Request_Save_Settings', self, self.OnUIRequestSaveSettings)
	NetEvents:Subscribe('NodeEditor:SetBotVision', self, self.OnSetBotVision)


	-- tracing
		-- trace recording events
	NetEvents:Subscribe('NodeEditor:StartTrace', self, self._onStartTrace)
	NetEvents:Subscribe('NodeEditor:EndTrace', self, self._onEndTrace)
	NetEvents:Subscribe('NodeEditor:ClearTrace', self, self._onClearTrace)
	NetEvents:Subscribe('NodeEditor:SaveTrace', self, self._onSaveTrace)
	-- start clear
end

-- =============================================
-- Events
-- =============================================

-- =============================================
-- Level Events
-- =============================================

-- Management Events
function NodeEditor:OnOpenEditor(p_Player)
	self.m_ActiveTracePlayers[p_Player.guid] = true
end

function NodeEditor:OnCloseEditor(p_Player)
	self.m_ActiveTracePlayers[p_Player.guid] = false
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

function NodeEditor:_onStartTrace(p_Player)
	if self.m_Player == nil or self.m_Player.soldier == nil then
		return
	end

	if self.m_CustomTrace[p_Player.guid] ~= nil then
		self.m_CustomTrace[p_Player.guid]:Clear()
	end

	self.m_CustomTrace[p_Player.guid] = NodeCollection(true)
	self.m_CustomTraceTimer[p_Player.guid] = 0
	self.m_CustomTraceIndex[p_Player.guid] = self:_getNewIndex()
	self.m_CustomTraceDistance[p_Player.guid] = 0

	local s_FirstWaypoint = self.m_CustomTrace[p_Player.guid]:Create({
		Position = self.m_Player.soldier.worldTransform.trans:Clone()
	})
	self.m_CustomTrace[p_Player.guid]:ClearSelection()
	self.m_CustomTrace[p_Player.guid]:Select(s_FirstWaypoint)

	self:Log('Custom Trace Started')

	local s_TotalTraceDistance = self.m_CustomTraceDistance[l_PlayerGuid]
	local s_TotalTraceNodes = #self.m_CustomTrace[l_PlayerGuid]:Get()
	local s_TraceIndex = self.m_CustomTraceIndex[p_Player.guid]  -- TODO: not really needed ?
	NetEvents:SendToLocal("ClientNodeEditor:TraceUiData", p_Player, s_TotalTraceNodes, s_TotalTraceDistance, s_TraceIndex, true)
end

function NodeEditor:_onEndTrace(p_Player, p_ClearSightToStart)
	self.m_CustomTraceTimer[p_Player.guid] = -1
	-- TODO: UI Client:
	NetEvents:SendToLocal("ClientNodeEditor:TraceUiData", p_Player, nil, nil, nil, false)
	-- get RaycastData for Node

	local s_FirstWaypoint = self.m_CustomTrace[p_Player.guid]:GetFirst()

	if s_FirstWaypoint then	
		self.m_CustomTrace[p_Player.guid]:ClearSelection()
		self.m_CustomTrace[p_Player.guid]:Select(s_FirstWaypoint)

		if p_ClearSightToStart then
			-- clear view from start node to end node, path loops
			self.m_CustomTrace[p_Player.guid]:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0)
		else
			-- no clear view, path should just invert at the end
			self.m_CustomTrace[p_Player.guid]:SetInput(s_FirstWaypoint.SpeedMode, s_FirstWaypoint.ExtraMode, 0XFF)
		end

		self.m_CustomTrace[p_Player.guid]:ClearSelection()
	end

	self:Log('Custom Trace Ended')
end

function NodeEditor:_onClearTrace(p_Player)
	self.m_CustomTraceTimer[p_Player.guid] = -1
	self.m_CustomTraceIndex[p_Player.guid] = self:_getNewIndex()
	self.m_CustomTraceDistance[p_Player.guid] = 0
	self.m_CustomTrace[p_Player.guid]:Clear()

	-- TODO: Client: set UI
	local s_TotalTraceDistance = self.m_CustomTraceDistance[l_PlayerGuid]
	local s_TotalTraceNodes = #self.m_CustomTrace[l_PlayerGuid]:Get()
	local s_TraceIndex = self.m_CustomTraceIndex[p_Player.guid]  -- TODO: not really needed ?
	NetEvents:SendToLocal("ClientNodeEditor:TraceUiData", p_Player, s_TotalTraceNodes, s_TotalTraceDistance, s_TraceIndex, false)

	self:Log('Custom Trace Cleared')
end

function NodeEditor:IsSavingOrLoading()
	return self.m_NodeOperation ~= ''
end

function NodeEditor:_onSaveTrace(p_Player, p_PathIndex)
	if self:IsSavingOrLoading() then
		self:Log('Operation in progress, please wait...')
		return false
	end

	if type(p_PathIndex) == 'table' then
		p_PathIndex = p_PathIndex[1]
	end

	if self.m_CustomTrace[p_Player.guid] == nil then
		self:Log('Custom Trace is empty')
		return false
	end

	self.m_NodeOperation = 'Custom Trace'

	local s_PathCount = #m_NodeCollection:GetPaths()
	p_PathIndex = tonumber(p_PathIndex) or self:_getNewIndex()
	local s_CurrentWaypoint = self.m_CustomTrace[p_Player.guid]:GetFirst()
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
			s_CurrentWaypoint = self.m_CustomTrace[p_Player.guid]:GetLast()
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

	self.m_CustomTrace[p_Player.guid]:Clear()
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
	if self.m_BotVision[p_Player.name] == nil then
		return
	end

	self.m_BotVision[p_Player.name] = {
		Player = p_Player,
		Current = 0,
		Delay = 1,
		Speed = 0.5,
		State = true
	}
end

---VEXT Server Player:Killed Event
---@param p_Player Player
function NodeEditor:OnPlayerKilled(p_Player)
	if p_Player == nil or self.m_BotVision[p_Player.name] == nil then
		return
	end

	self.m_BotVision[p_Player.name] = {
		Player = p_Player,
		Current = 0,
		Delay = 0,
		Speed = 0.5,
		State = false
	}
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

---VEXT Shared Engine:Update Event
---@param p_DeltaTime number
---@param p_SimulationDeltaTime number
function NodeEditor:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
	-- TRACE-Handling
	for l_PlayerGuid, l_Active in pairs(self.m_ActiveTracePlayers) do
		local s_Player = PlayerManager:GetPlayerByGuid(l_PlayerGuid)
		if (s_Player and s_Player.soldier and self.m_CustomTraceTimer[l_PlayerGuid] >= 0) then
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
							self.m_CustomTrace[l_PlayerGuid]:Select(s_NewWaypoint)

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
							self.m_CustomTrace[l_PlayerGuid]:Select(s_LastWaypointAgain)
							self.m_CustomTrace[l_PlayerGuid]:SetInput(s_LastWaypointAgain.SpeedMode, s_LastWaypointAgain.ExtraMode,
								s_LastWaypointAgain.OptValue + p_DeltaTime)
						end

						self.m_CustomTraceDistance[l_PlayerGuid] = self.m_CustomTraceDistance[l_PlayerGuid] + s_LastDistance

						-- TODO: Send to Client UI:
						local s_TotalTraceDistance = self.m_CustomTraceDistance[l_PlayerGuid]
						local s_TotalTraceNodes = #self.m_CustomTrace[l_PlayerGuid]:Get()
						NetEvents:SendToLocal("ClientNodeEditor:TraceUiData", s_Player, s_TotalTraceNodes, s_TotalTraceDistance)
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
	if self.m_NodeSendUpdateTimer < 1.5 then
		self.m_NodeSendUpdateTimer = self.m_NodeSendUpdateTimer + p_DeltaTime
	else	
		self.m_NodeSendUpdateTimer = 0.0

		-- ToDo: distribute load equally (multible Players)
		for l_PlayerGuid, l_Active in pairs(self.m_ActiveTracePlayers) do
			local s_Player = PlayerManager:GetPlayerByGuid(l_PlayerGuid)
			if not s_Player or not s_Player.soldier then
				goto continue
			end

			local s_NodesToDraw = {}

			-- selected + isTracepath + showOption (text, node, id)

			local s_PlayerPos = s_Player.soldier.worldTransform.trans
			local s_WaypointPaths = m_NodeCollection:GetPaths()
			for l_Path, _ in pairs(s_WaypointPaths) do
				if m_NodeCollection:IsPathVisible(l_Path) then
					for _, l_Node in pairs(s_WaypointPaths[l_Path]) do

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

						if s_DrawNode or s_DrawLine or s_DrawText then
							if m_NodeCollection:IsSelected(l_PlayerGuid) then
								s_IsSelected = true
							end

							local s_DataNode = {
								Node = l_Node,
								DrawNode = s_DrawNode,
								DrawLine = s_DrawLine,
								DrawText = s_DrawText,
								IsSelected = s_IsSelected,
								IsTrace = false
							}
							table.insert(s_NodesToDraw, s_DataNode)
						end
					end
				end
			end

			-- custom trace of player
			-- TODO: also show active Traces of other players with other color?
			if self.m_CustomTrace[l_PlayerGuid] then
				local s_CustomWaypoints = self.m_CustomTrace[l_PlayerGuid]:Get()
				for _, l_Node in pairs(s_CustomWaypoints) do
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

					if s_DrawNode or s_DrawLine or s_DrawText then
						if m_NodeCollection:IsSelected(l_PlayerGuid) then
							s_IsSelected = true
						end

						local s_DataNode = {
							Node = l_Node,
							DrawNode = s_DrawNode,
							DrawLine = s_DrawLine,
							DrawText = s_DrawText,
							IsSelected = s_IsSelected,
							IsTrace = true
						}
						table.insert(s_NodesToDraw, s_DataNode)
					end
				end
			end

			NetEvents:SendToLocal('ClientNodeEditor:SendNodes', s_Player, s_NodesToDraw)) -- send all nodes that are visible for the player

			::continue::
		end
	end
end


function NodeEditor:OnEngineUpdateOld(p_DeltaTime, p_SimulatioonDeltaTime)
	for l_PlayerName, l_TimeData in pairs(self.m_BotVision) do
		if type(l_TimeData) == 'table' then
			l_TimeData.Current = l_TimeData.Current + p_DeltaTime

			if l_TimeData.Current >= l_TimeData.Delay then
				self:Log('Player -> Fade [%s]: %s', l_TimeData.Player.name, l_TimeData.State)
				l_TimeData.Player:Fade(l_TimeData.Speed, l_TimeData.State)
				self.m_BotVision[l_PlayerName] = true
			else
				self.m_BotVision[l_PlayerName] = l_TimeData
			end
		end
	end
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

function NodeEditor:OnSetBotVision(p_Player, p_Enabled)
	self:Log('Player -> BotVision [%s]: %s', p_Player.name, p_Enabled)

	if p_Enabled then
		self.m_BotVision[p_Player.name] = {
			Player = p_Player,
			Current = 0,
			Delay = 1,
			Speed = 0.5,
			State = p_Enabled
		}
	else
		p_Player:Fade(0.5, false)
		self.m_BotVision[p_Player.name] = nil
	end
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
