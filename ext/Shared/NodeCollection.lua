---@class NodeCollection
---@overload fun(p_DisableServerEvents?: boolean):NodeCollection
NodeCollection = class "NodeCollection"

---@type Utilities
local m_Utilities = require('__shared/Utilities.lua')
---@type Logger
local m_Logger = Logger("NodeCollection", true)

function NodeCollection:__init(p_DisableServerEvents)
	self:InitTables()
	if p_DisableServerEvents == nil or not p_DisableServerEvents then
		NetEvents:Subscribe('NodeCollection:Create', self, self.Create)
		NetEvents:Subscribe('NodeCollection:Clear', self, self.Clear)
	end
end

function NodeCollection:InitTables()
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByPathIndex = {}

	self.selectedWaypoints = {}
	self.hiddenPaths = {}

	self.mapName = ''
end

function NodeCollection:RegisterEvents()
	-- Management
	NetEvents:Subscribe('NodeCollection:Register', self, self.Register)
	NetEvents:Subscribe('NodeCollection:Add', self, self.Add)
	NetEvents:Subscribe('NodeCollection:Remove', self, self.Remove)
	NetEvents:Subscribe('NodeCollection:InsertAfter', self, self.InsertAfter)
	NetEvents:Subscribe('NodeCollection:InsertBefore', self, self.InsertBefore)
	NetEvents:Subscribe('NodeCollection:RecalculateIndexes', self, self.RecalculateIndexes)
	NetEvents:Subscribe('NodeCollection:ProcessMetadata', self, self.ProcessMetadata)
	NetEvents:Subscribe('NodeCollection:Update', self, self.Update)
	NetEvents:Subscribe('NodeCollection:UpdateMetadata', self, self.UpdateMetadata)
	NetEvents:Subscribe('NodeCollection:SetInput', self, self.SetInput)
	NetEvents:Subscribe('NodeCollection:Link', self, self.Link)
	NetEvents:Subscribe('NodeCollection:Unlink', self, self.Unlink)
	NetEvents:Subscribe('NodeCollection:Merge', self, self.MergeSelection)
	NetEvents:Subscribe('NodeCollection:Split', self, self.SplitSelection)

	-- Selection
	NetEvents:Subscribe('NodeCollection:Select', self, self.Select)
	NetEvents:Subscribe('NodeCollection:Deselect', self, self.Deselect)
	NetEvents:Subscribe('NodeCollection:ClearSelection', self, self.ClearSelection)

	-- Paths
	NetEvents:Subscribe('NodeCollection:ShowPath', self, self.ShowPath)
	NetEvents:Subscribe('NodeCollection:HidePath', self, self.HidePath)

	-- Save/Load
	NetEvents:Subscribe('NodeCollection:Save', self, self.Save)
	NetEvents:Subscribe('NodeCollection:Load', self, self.Load)
end

-----------------------------
-- Management

function NodeCollection:Create(p_Data, p_Authoritative)
	p_Authoritative = p_Authoritative or false
	local s_NewIndex = #self.waypoints + 1
	local s_InputVar = 3

	-- setup defaults for a blank node
	---@class Waypoint
	local s_Waypoint = {
		ID = string.format('p_%d', s_NewIndex), -- new generated id for internal storage
		OriginalID = nil, -- original id from database
		Index = s_NewIndex, -- new generated id in numerical form
		Position = Vec3(0, 0, 0),
		PathIndex = 1, -- Path #
		PointIndex = 1, -- index inside parent path
		InputVar = s_InputVar, -- raw input value
		SpeedMode = s_InputVar & 0xF, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
		ExtraMode = (s_InputVar >> 4) & 0xF,
		OptValue = (s_InputVar >> 8) & 0xFF,
		Data = {},
		Distance = nil, -- current distance to player
		Updated = false, -- if true, needs to be sent to server for saving
		Previous = false, -- tree navigation
		Next = false
	}

	if p_Data ~= nil then
		for l_Key, l_Value in pairs(p_Data) do
			if l_Value ~= nil then
				if not p_Authoritative and (l_Key == 'ID' or l_Key == 'Index' or l_Key == 'Previous' or l_Key == 'Next') then
					goto continue
				end

				s_Waypoint[l_Key] = l_Value
			end

			::continue::
		end
	end

	self:Register(s_Waypoint)
	return s_Waypoint
end

---@param p_Waypoint Waypoint
---@return Waypoint
function NodeCollection:Register(p_Waypoint)

	if self.hiddenPaths[p_Waypoint.PathIndex] == nil then
		self.hiddenPaths[p_Waypoint.PathIndex] = false
	end

	if self.waypointsByPathIndex[p_Waypoint.PathIndex] == nil then
		self.waypointsByPathIndex[p_Waypoint.PathIndex] = {}
	end

	-- node associations are already set, don't change them
	if p_Waypoint.Previous and p_Waypoint.Next and false then -- disabled for now
		-- begin searching for related nodes from the tail and work backwards
		for i = #self.waypointsByPathIndex[p_Waypoint.PathIndex], 1, -1 do
			local s_CurrentWaypoint = self.waypointsByPathIndex[p_Waypoint.PathIndex][i]

			if s_CurrentWaypoint ~= nil then
				-- our new node should go ahead of the currentWaypoint
				if s_CurrentWaypoint.PointIndex == p_Waypoint.PointIndex - 1 then
					-- update connections
					self:InsertAfter(s_CurrentWaypoint, p_Waypoint)
				-- our new node should go behind the current waypoint
				elseif s_CurrentWaypoint.PointIndex == p_Waypoint.PointIndex + 1 then
					-- update connections
					self:InsertBefore(s_CurrentWaypoint, p_Waypoint)
				end
			end
		end
	end

	table.insert(self.waypoints, p_Waypoint)

	if #self.waypoints ~= p_Waypoint.Index then
		local s_Diff = p_Waypoint.Index - #self.waypoints

		m_Logger:Warning('New Node Index does not match: p_Waypoint.Index:' ..
			tostring(p_Waypoint.Index) .. ' | #self.waypoints:' .. tostring(#self.waypoints) .. ' | ' .. tostring(s_Diff))
	end

	table.insert(self.waypointsByPathIndex[p_Waypoint.PathIndex], p_Waypoint)

	if #self.waypointsByPathIndex[p_Waypoint.PathIndex] ~= p_Waypoint.PointIndex then
		local s_Diff = p_Waypoint.PointIndex - #self.waypointsByPathIndex[p_Waypoint.PathIndex]

		m_Logger:Warning('New Node PointIndex does not match: p_Waypoint.PointIndex: ' ..
			tostring(p_Waypoint.PointIndex) ..
			' | #self.waypointsByPathIndex[' ..
			p_Waypoint.PathIndex ..
			']: ' .. tostring(#self.waypointsByPathIndex[p_Waypoint.PathIndex]) .. ' | ' .. tostring(s_Diff))
	end

	self.waypointsByID[p_Waypoint.ID] = p_Waypoint

	return p_Waypoint
end

---@return boolean
---@return string
function NodeCollection:Add(p_SelectionId)
	local s_Selection = self:GetSelected(p_SelectionId)

	if #s_Selection == 1 then
		local s_LastWaypoint = s_Selection[#s_Selection]
		local s_NewWaypoint = self:Create({
			PathIndex = s_LastWaypoint.PathIndex,
			PointIndex = s_LastWaypoint.PointIndex + 1,
			Previous = s_LastWaypoint.ID
		})
		self:InsertAfter(s_LastWaypoint, s_NewWaypoint)
		return s_NewWaypoint, 'Success'
	elseif #s_Selection == 0 then
		local s_LastWaypoint = self.waypoints[#self.waypoints]
		local s_NewWaypoint = self:Create({
			PathIndex = s_LastWaypoint.PathIndex + 1,
			PointIndex = s_LastWaypoint.PointIndex + 1,
			Previous = s_LastWaypoint.ID
		})
		self:InsertAfter(s_LastWaypoint, s_NewWaypoint)
		return s_NewWaypoint, 'Success'
	end

	return false, 'Must select up to two waypoints'
end

---@param p_Waypoint? Waypoint
---@return boolean
---@return string
function NodeCollection:Remove(p_SelectionId, p_Waypoint)
	-- batch operation on selections
	if p_Waypoint == nil then
		local s_Selection = self:GetSelected(p_SelectionId)

		for _, l_SelectedWaypoint in pairs(s_Selection) do
			self:Remove(p_SelectionId, l_SelectedWaypoint)
		end

		return true, 'Success'
	end

	m_Logger:Write('Removing: ' .. tostring(p_Waypoint.ID))

	-- update connections, no more middle-man
	if p_Waypoint.Previous then
		p_Waypoint.Previous.Next = p_Waypoint.Next
	end

	if p_Waypoint.Next then
		p_Waypoint.Next.Previous = p_Waypoint.Previous
	end

	-- use connections to update indexes
	self:Unlink(p_SelectionId, p_Waypoint)

	if p_Waypoint.Previous then
		self:RecalculateIndexes(p_Waypoint.Previous)
	elseif (p_Waypoint.Next) then
		self:RecalculateIndexes(p_Waypoint.Next)
	end

	-- cut ties with old friends
	p_Waypoint.Next = false
	p_Waypoint.Previous = false

	-- delete facebook
	self.waypoints[p_Waypoint.Index] = p_Waypoint
	self.waypointsByID[p_Waypoint.ID] = p_Waypoint
	self.waypointsByPathIndex[p_Waypoint.PathIndex][p_Waypoint.PointIndex] = p_Waypoint
	-- delete IDs for everyone
	for l_PlayerGuid, _ in pairs(self.selectedWaypoints) do
		self.selectedWaypoints[l_PlayerGuid][p_Waypoint.ID] = nil
	end
	return true, 'Success'
	-- go hit the gym
end

---@param p_ReferrenceWaypoint Waypoint
---@param p_Waypoint Waypoint
function NodeCollection:InsertAfter(p_ReferrenceWaypoint, p_Waypoint)
	if type(p_Waypoint.Next) == 'string' then
		p_Waypoint.Next = self.waypointsByID[p_Waypoint.Next]
	end

	if type(p_Waypoint.Previous) == 'string' then
		p_Waypoint.Previous = self.waypointsByID[p_Waypoint.Previous]
	end

	p_Waypoint.Next = p_ReferrenceWaypoint.Next
	p_Waypoint.Previous = p_ReferrenceWaypoint
	p_ReferrenceWaypoint.Next = p_Waypoint

	if p_Waypoint.Next then
		p_Waypoint.Next.Previous = p_Waypoint
	end

	-- use connections to update indexes
	self:RecalculateIndexes(p_ReferrenceWaypoint)
end

---@param p_ReferrenceWaypoint Waypoint
---@param p_Waypoint Waypoint
function NodeCollection:InsertBefore(p_ReferrenceWaypoint, p_Waypoint)
	if type(p_Waypoint.Next) == 'string' then
		p_Waypoint.Next = self.waypointsByID[p_Waypoint.Next]
	end

	if type(p_Waypoint.Previous) == 'string' then
		p_Waypoint.Previous = self.waypointsByID[p_Waypoint.Previous]
	end

	p_Waypoint.Previous = p_ReferrenceWaypoint.Previous
	p_Waypoint.Next = p_ReferrenceWaypoint
	p_ReferrenceWaypoint.Previous = p_Waypoint

	if p_Waypoint.Previous then
		p_Waypoint.Previous.Next = p_Waypoint
	end

	-- use connections to update indexes
	self:RecalculateIndexes(p_Waypoint.Previous or p_Waypoint)
end

---@param p_Waypoint Waypoint|nil
function NodeCollection:RecalculateIndexes(p_Waypoint)
	m_Logger:Write('RecalculateIndexes Starting...')

	local s_Counter = 0

	if p_Waypoint == nil then
		for i = 1, #self.waypoints do
			self.waypoints[i] = self:_processWaypointRecalc(self.waypoints[i])
			s_Counter = s_Counter + 1
		end
	else
		local s_Direction = "Next"

		if not p_Waypoint.Next then
			s_Direction = "Previous"
		end

		while p_Waypoint do
			self.waypoints[p_Waypoint.Index] = self:_processWaypointRecalc(p_Waypoint)
			p_Waypoint = p_Waypoint[s_Direction]
			s_Counter = s_Counter + 1
		end
	end

	m_Logger:Write('RecalculateIndexes Finished! [' .. tostring(s_Counter) .. ']')
end

---@param p_Waypoint Waypoint
---@return Waypoint
function NodeCollection:_processWaypointRecalc(p_Waypoint)
	local s_LastIndex = 0
	local s_LastPathIndex = 0
	local s_LastPointIndex = 0
	local s_CurrentPathIndex = -1

	-- convert neighbor referrences
	if type(p_Waypoint.Next) == 'string' then
		p_Waypoint.Next = self.waypointsByID[p_Waypoint.Next]

		if p_Waypoint.Next then
			p_Waypoint.Next.Previous = p_Waypoint
		end
	end

	if type(p_Waypoint.Previous) == 'string' then
		p_Waypoint.Previous = self.waypointsByID[p_Waypoint.Previous]

		if p_Waypoint.Previous then
			p_Waypoint.Previous.Next = p_Waypoint
		end
	end

	if p_Waypoint.Previous then
		s_LastIndex = p_Waypoint.Previous.Index
		s_LastPathIndex = p_Waypoint.Previous.PathIndex
		s_LastPointIndex = p_Waypoint.Previous.PointIndex
	end

	--reset lastPointIndex on new path
	if p_Waypoint.PathIndex ~= s_LastPathIndex then
		s_LastPathIndex = p_Waypoint.PathIndex
		s_LastPointIndex = 0
	end

	if p_Waypoint.PointIndex ~= s_LastPointIndex + 1 then
		s_LastPointIndex = s_LastPointIndex + 1
		p_Waypoint.PointIndex = s_LastPointIndex
		p_Waypoint.Updated = true
	end

	return p_Waypoint
end

---@param p_Waypoint Waypoint|nil
function NodeCollection:ProcessMetadata(p_Waypoint)
	m_Logger:Write('ProcessMetadata Starting...')

	local s_Counter = 0

	if p_Waypoint == nil then
		for i = 1, #self.waypoints do
			self.waypoints[i] = self:_processWaypointMetadata(self.waypoints[i])
			s_Counter = s_Counter + 1
		end
	else
		self.waypoints[p_Waypoint.Index] = self:_processWaypointMetadata(p_Waypoint)
		s_Counter = s_Counter + 1
	end

	m_Logger:Write('ProcessMetadata Finished! [' .. tostring(s_Counter) .. ']')
end

---@param p_Waypoint Waypoint
---@return Waypoint
function NodeCollection:_processWaypointMetadata(p_Waypoint)
	-- safety checks
	if p_Waypoint.Data == nil then
		p_Waypoint.Data = {}
	end

	if type(p_Waypoint.Data) == 'string' then
		p_Waypoint.Data = json.decode(p_Waypoint.Data)
	end
	-- -----

	-- Check if indirect connections, create if missing
	-- p_Waypoint.Data.LinkMode = 1
	-- p_Waypoint.Data.Links = {
	-- <p_Waypoint_ID>,
	-- <p_Waypoint_ID>,
	-- ...
	--}

	-- if the node has a linkmode and no links then try to find them
	if p_Waypoint.Data.LinkMode ~= nil and
		(p_Waypoint.Data.Links == nil or (type(p_Waypoint.Data.Links) == 'table' and #p_Waypoint.Data.Links < 1)) then
		-- indirect connections
		if p_Waypoint.Data.LinkMode == 1 then
			local s_Range = p_Waypoint.Data.Range or 3 -- meters, box-like area
			local s_Chance = p_Waypoint.Data.Chance or 25 -- 1 - 100
			local s_NearbyNodes = self:FindAll(p_Waypoint.Position, s_Range)

			p_Waypoint.Data.Links = {}

			for i = 1, s_NearbyNodes do
				table.insert(p_Waypoint.Data.Links, s_NearbyNodes[i].ID)
			end
		end
	end

	-- if the Links table has entries, but they need converting
	if p_Waypoint.Data.Links ~= nil then
		for i = 1, #p_Waypoint.Data.Links do
			local s_LinkedData = p_Waypoint.Data.Links[i]

			if type(s_LinkedData) == 'table' then
				local s_LinkedWaypoint = self:Get(s_LinkedData[2], s_LinkedData[1])

				if s_LinkedWaypoint ~= nil then
					p_Waypoint.Data.Links[i] = s_LinkedWaypoint.ID
				end
			end
		end
	end

	return p_Waypoint
end

---@param p_Waypoint Waypoint
---@param p_Data any
function NodeCollection:Update(p_Waypoint, p_Data)
	m_Utilities:mergeKeys(p_Waypoint, p_Data)
end

---@param p_Data any
---@return boolean
---@return string
function NodeCollection:UpdateMetadata(p_Data)
	m_Logger:Write('[A] NodeCollection:UpdateMetadata -> p_Data: ' .. m_Utilities:dump(p_Data, true))

	local s_Selection = self:GetSelected()

	if #s_Selection < 1 then
		return false, 'Must select one or more waypoints'
	end

	if type(p_Data) == 'string' then
		p_Data = json.decode(p_Data) or {}
	end

	m_Logger:Write('[B] NodeCollection:UpdateMetadata -> p_Data: ' .. m_Utilities:dump(p_Data, true))

	for i = 1, #s_Selection do
		self:Update(s_Selection[i], {
			Data = m_Utilities:mergeKeys(s_Selection[i].Data, p_Data)
		})
	end

	return true, 'Success'
end

function NodeCollection:SetInput(p_Speed, p_Extra, p_Option)
	p_Speed = tonumber(p_Speed) or 3
	p_Extra = tonumber(p_Extra) or 0
	p_Option = tonumber(p_Option) or 0
	local s_InputVar = (p_Speed & 0xF) + ((p_Extra & 0xF) << 4) + ((p_Option & 0xFF) << 8)

	local s_Selection = self:GetSelected()

	for i = 1, #s_Selection do
		self:Update(s_Selection[i], {
			InputVar = s_InputVar,
			SpeedMode = p_Speed,
			ExtraMode = p_Extra,
			OptValue = p_Option
		})
	end

	return s_InputVar
end

-- Created a linked connection between two or more arbitrary waypoints
-- p_Waypoints | Waypoint or {Waypoint} | Can be a single waypoint or a table of waypoints, `nil` defaults to current selection
-- p_LinkID | string | a waypoint ID, must not be `nil`
-- p_OneWay | boolean | if true, the connection is only made on this node, prevents infinite recursion
---@param p_Waypoints? Waypoint|Waypoint[]
---@param p_LinkID string
---@param p_OneWay? boolean
---@return boolean
---@return string
function NodeCollection:Link(p_SelectionId, p_Waypoints, p_LinkID, p_OneWay)
	local s_Selection = p_Waypoints or g_NodeCollection:GetSelected(p_SelectionId)
	p_OneWay = p_OneWay or false

	if #s_Selection == 2 then
		--special case, nodes link to each other
		self:Link(p_SelectionId, s_Selection[1], s_Selection[2].ID, true)
		self:Link(p_SelectionId, s_Selection[2], s_Selection[1].ID, true)
		return true, 'Success'
	elseif #s_Selection > 0 then
		for i = 1, #s_Selection do
			local s_Success, s_Msg = self:Link(p_SelectionId, s_Selection[i], p_LinkID, nil)

			if not s_Success then
				return s_Success, s_Msg
			end
		end

		return true, 'Success'
	end

	if p_LinkID == nil then
		return false, 'Must specify link id'
	end

	local s_Links = s_Selection.Data.Links or {}
	table.insert(s_Links, p_LinkID)
	self:Update(s_Selection.Data, {
		LinkMode = (s_Selection.Data.LinkMode or 0),
		Links = s_Links
	})

	if not p_OneWay then
		self:Link(p_SelectionId, self:Get(p_LinkID), s_Selection.ID, true)
	end

	return true, 'Success'
end

-- Removes a linked connection between two or more arbitrary waypoints
-- p_Waypoints | Waypoint or {Waypoint} | Can be a single waypoint or a table of waypoints, `nil` defaults to current selection
-- p_LinkID | string | a waypoint ID to remove, can be `nil` to clear connections
-- p_OneWay | boolean | if true, the connection is only made on this node, prevents infinite recursion
---@param p_Waypoints Waypoint|Waypoint[]|nil
---@param p_LinkID string|nil
---@param p_OneWay? boolean
---@return boolean
---@return string
function NodeCollection:Unlink(p_SelectionId, p_Waypoints, p_LinkID, p_OneWay)

	local s_Selection = p_Waypoints or g_NodeCollection:GetSelected(p_SelectionId)
	p_OneWay = p_OneWay or false

	if #s_Selection == 2 then
		--special case, nodes unlink from each other
		self:Unlink(p_SelectionId, s_Selection[1], s_Selection[2].ID, true)
		self:Unlink(p_SelectionId, s_Selection[2], s_Selection[1].ID, true)
		return true, 'Success'
	elseif (#s_Selection > 0) then
		for i = 1, #s_Selection do
			local s_Success, s_Msg = self:Unlink(p_SelectionId, s_Selection[i], p_LinkID, nil)

			if not s_Success then
				return s_Success, s_Msg
			end
		end

		return true, 'Success'
	end

	local s_NewLinks = {}

	-- generate new links table, otherwise it gets emptied
	if p_LinkID ~= nil and s_Selection.Data.Links ~= nil then
		for i = 1, #s_Selection.Data.Links do
			if s_Selection.Data.Links[i] ~= p_LinkID then
				-- skip matching connections
				table.insert(s_NewLinks, s_Selection.Data.Links[i])
			else
				-- remove link from connected node, `p_OneWay` prevents infinite recursion
				if not p_OneWay then
					self:Unlink(p_SelectionId, self:Get(p_LinkID), s_Selection.ID, true)
				end
			end
		end
	end

	-- update waypoint's Data table, remove linking info if necessary
	m_Logger:Write('newLinks -> ' .. m_Utilities:dump(s_NewLinks, true))

	if #s_NewLinks > 0 then
		self:Update(s_Selection.Data, {
			LinkMode = (s_Selection.Data.LinkMode or 0),
			Links = s_NewLinks
		})
	else
		local s_NewData = {}

		if s_Selection.Data ~= nil then
			for l_Key, l_Value in pairs(s_Selection.Data) do
				if l_Key ~= 'Links' and l_Key ~= 'LinkMode' then
					s_NewData[l_Key] = l_Value
				end
			end
		end

		self:Update(s_Selection, {
			Data = s_NewData
		})
	end

	return true, 'Success'
end

-- USAGE
-- g_NodeCollection:Get() -- all waypoints as unsorted table
-- g_NodeCollection:Get(nil, <int|PathIndex>) -- all waypoints in PathIndex as unsorted table
--
-- g_NodeCollection:Get(<string|WaypointID>) -- waypoint from id - Speed: O(1)
-- g_NodeCollection:Get(<table|Waypoint>) -- waypoint from another waypoint referrence - Speed: O(1)
-- g_NodeCollection:Get(<int|Index>) -- waypoint from waypoint Index - Speed: O(n)
-- g_NodeCollection:Get(<int|PointIndex>, <int|PathIndex>) -- waypoint from PointIndex and PathIndex - Speed: O(1)
-- g_NodeCollection:Get(<string|WaypointID>, <int|PathIndex>) -- waypoint from PointIndex and PathIndex - Speed: O(n)
-- g_NodeCollection:Get(<table|Waypoint>, <int|PathIndex>) -- waypoint from PointIndex and PathIndex - Speed: O(n)

---@param p_Waypoint? integer|string|Waypoint
---@param p_PathIndex? integer
---@return Waypoint
function NodeCollection:Get(p_Waypoint, p_PathIndex)
	if p_Waypoint ~= nil then
		if p_PathIndex ~= nil then

			if self.waypointsByPathIndex[p_PathIndex] == nil then
				self.waypointsByPathIndex[p_PathIndex] = {}
			end

			if type(p_Waypoint) == 'number' then
				return self.waypointsByPathIndex[p_PathIndex][p_Waypoint]
			elseif type(p_Waypoint) == 'string' then
				for i = 1, #self.waypointsByPathIndex[p_PathIndex] do
					local s_TargetWaypoint = self.waypointsByPathIndex[p_PathIndex][i]

					if s_TargetWaypoint.PathIndex == p_PathIndex and s_TargetWaypoint.ID == p_Waypoint then
						return s_TargetWaypoint
					end
				end
			elseif type(p_Waypoint) == 'table' then
				for i = 1, #self.waypointsByPathIndex[p_PathIndex] do
					local s_TargetWaypoint = self.waypointsByPathIndex[p_PathIndex][i]

					if s_TargetWaypoint.PathIndex == p_PathIndex and s_TargetWaypoint.ID == p_Waypoint.ID then
						return s_TargetWaypoint
					end
				end
			end
		else
			if type(p_Waypoint) == 'string' then
				return self.waypointsByID[p_Waypoint]
			elseif type(p_Waypoint) == 'table' then
				return self.waypointsByID[p_Waypoint.ID]
			else
				for i = 1, #self.waypoints do
					if self.waypoints[i].Index == p_Waypoint then
						return self.waypoints[i]
					end
				end
			end
		end

		return nil
	elseif p_PathIndex ~= nil then
		if self.waypointsByPathIndex[p_PathIndex] == nil then
			self.waypointsByPathIndex[p_PathIndex] = {}
		end

		return self.waypointsByPathIndex[p_PathIndex]
	end

	return self.waypoints
end

---@param p_PathIndex? integer
---@return Waypoint|boolean
function NodeCollection:GetFirst(p_PathIndex)
	local s_FirstWaypoint = self.waypoints[1]

	if p_PathIndex ~= nil then
		if self.waypointsByPathIndex[p_PathIndex] == nil then
			return false
		end

		s_FirstWaypoint = self.waypointsByPathIndex[p_PathIndex][1]
	end

	if s_FirstWaypoint == nil then
		return false
	end

	while s_FirstWaypoint.Previous and
		((p_PathIndex ~= nil and s_FirstWaypoint.Previous.PathIndex == s_FirstWaypoint.PathIndex) or p_PathIndex == nil) do
		s_FirstWaypoint = s_FirstWaypoint.Previous
	end

	return s_FirstWaypoint
end

---@param p_PathIndex? integer
---@return Waypoint|boolean
function NodeCollection:GetLast(p_PathIndex)
	local s_LastWaypoint = self.waypoints[#self.waypoints]

	if p_PathIndex ~= nil then
		if self.waypointsByPathIndex[p_PathIndex] == nil then
			return false
		end

		s_LastWaypoint = self.waypointsByPathIndex[p_PathIndex][#self.waypointsByPathIndex[p_PathIndex]]
	end

	if s_LastWaypoint == nil then
		return false
	end

	while s_LastWaypoint.Next and
		((p_PathIndex ~= nil and s_LastWaypoint.Next.PathIndex == s_LastWaypoint.PathIndex) or p_PathIndex == nil) do
		s_LastWaypoint = s_LastWaypoint.Next
	end

	return s_LastWaypoint
end

function NodeCollection:GetPaths()
	return self.waypointsByPathIndex
end

function NodeCollection:Clear()
	m_Logger:Write('NodeCollection:Clear')

	for i = 1, #self.waypoints do
		self.waypoints[i].Next = nil
		self.waypoints[i].Previous = nil
	end

	self.waypoints = {}
	self.waypointsByID = {}

	for l_PathIndex, _ in pairs(self.waypointsByPathIndex) do
		self.waypointsByPathIndex[l_PathIndex] = {}
	end

	self.waypointsByPathIndex = {}
	self.selectedWaypoints = {}
end

-----------------------------
-- Selection

---@param p_Waypoint? Waypoint
---@param p_PathIndex? integer
function NodeCollection:Select(p_SelectionId, p_Waypoint, p_PathIndex)
	if not p_SelectionId then
		p_SelectionId = 1
	end
	if self.selectedWaypoints[p_SelectionId] == nil then
		self.selectedWaypoints[p_SelectionId] = {}
	end

	if p_Waypoint == nil then return end

	p_Waypoint = self:Get(p_Waypoint, p_PathIndex)

	if p_Waypoint == nil then return end

	self.selectedWaypoints[p_SelectionId][p_Waypoint.ID] = p_Waypoint
end

---@param p_Waypoint? Waypoint
---@param p_PathIndex? integer
function NodeCollection:Deselect(p_SelectionId, p_Waypoint, p_PathIndex)
	if not p_SelectionId then
		p_SelectionId = 1
	end
	if self.selectedWaypoints[p_SelectionId] == nil then
		self.selectedWaypoints[p_SelectionId] = {}
	end

	if p_Waypoint == nil then
		self:ClearSelection(p_SelectionId)
	else
		p_Waypoint = self:Get(p_Waypoint, p_PathIndex)

		if p_Waypoint == nil then return end

		self.selectedWaypoints[p_SelectionId][p_Waypoint.ID] = nil
	end
end

---@param p_Waypoint? Waypoint
---@param p_PathIndex? integer
function NodeCollection:IsSelected(p_SelectionId, p_Waypoint, p_PathIndex)
	if not p_SelectionId then
		p_SelectionId = 1
	end
	if self.selectedWaypoints[p_SelectionId] == nil then
		self.selectedWaypoints[p_SelectionId] = {}
	end

	if p_Waypoint == nil then return false end

	p_Waypoint = self:Get(p_Waypoint, p_PathIndex)

	if p_Waypoint == nil then return false end

	return self.selectedWaypoints[p_SelectionId][p_Waypoint.ID] ~= nil
end

---@param p_PathIndex? integer
---@return Waypoint[]
function NodeCollection:GetSelected(p_SelectionId, p_PathIndex)
	if not p_SelectionId then
		p_SelectionId = 1
	end
	if self.selectedWaypoints[p_SelectionId] == nil then
		self.selectedWaypoints[p_SelectionId] = {}
	end

	local s_Selection = {}

	-- copy selection into index-based array and sort results
	for l_WaypointID, l_Waypoint in pairs(self.selectedWaypoints[p_SelectionId]) do
		if self:IsSelected(p_SelectionId, l_Waypoint) and (p_PathIndex == nil or l_Waypoint.PathIndex == p_PathIndex) then
			table.insert(s_Selection, l_Waypoint)
		end
	end

	if p_PathIndex == nil then
		self:_sort(s_Selection, 'Index')
	else
		self:_sort(s_Selection, 'PointIndex')
	end

	return s_Selection
end

function NodeCollection:ClearSelection(p_SelectionId)
	if not p_SelectionId then
		p_SelectionId = 1
	end

	self.selectedWaypoints[p_SelectionId] = {}
end

function NodeCollection:_sort(p_Collection, p_KeyName, p_Descending)

	p_KeyName = p_KeyName or 'Index'

	table.sort(p_Collection, function(a, b)
		if a == nil then
			return false
		end

		if b == nil then
			return true
		end

		if p_Descending then
			return a[p_KeyName] > b[p_KeyName]
		else
			return a[p_KeyName] < b[p_KeyName]
		end

	end)
	return p_Collection
end

function NodeCollection:MergeSelection(p_SelectionId)
	-- TODO
	-- combine selected nodes
	-- nodes must be sequential or the start/end of two paths
	local s_Selection = self:GetSelected(p_SelectionId)

	if #s_Selection < 2 then
		return false, 'Must select two or more waypoints'
	end

	-- check is same path and sequential
	local s_CurrentWaypoint = s_Selection[1]

	for i = 2, #s_Selection do
		if s_CurrentWaypoint.PathIndex ~= s_Selection[i].PathIndex then
			return false, 'Waypoints must be on same path'
		end

		if s_CurrentWaypoint.Next and s_CurrentWaypoint.Next.PointIndex ~= s_Selection[i].PointIndex then
			return false, 'Waypoints must be sequential'
		end

		s_CurrentWaypoint = s_Selection[i]
	end

	-- all clear, points are on same path, and in order with no gaps
	local s_FirstPoint = s_Selection[1]
	local s_LastPoint = s_Selection[#s_Selection]
	local s_MiddlePosition = (s_FirstPoint.Position + s_LastPoint.Position) / 2

	-- move the first node to the center
	s_FirstPoint.Position = s_MiddlePosition

	-- remove all selected nodes except the first one
	for i = 2, #s_Selection do
		self:Remove(p_SelectionId, s_Selection[i])
	end

	return true, 'Success'
end

function NodeCollection:SplitSelection(p_SelectionId)
	local s_Selection = self:GetSelected(p_SelectionId)

	if #s_Selection < 2 then
		return false, 'Must select two or more waypoints'
	end

	-- check is same path and sequential
	local s_CurrentWaypoint = s_Selection[1]
	for i = 2, #s_Selection do
		if s_CurrentWaypoint.PathIndex ~= s_Selection[i].PathIndex then
			return false, 'Waypoints must be on same path'
		end

		if s_CurrentWaypoint.Next and s_CurrentWaypoint.Next.PointIndex ~= s_Selection[i].PointIndex then
			return false, 'Waypoints must be sequential'
		end

		s_CurrentWaypoint = s_Selection[i]
	end

	for i = 1, #s_Selection - 1 do
		local s_NewWaypoint = self:Create({
			Position = ((s_Selection[i].Position + s_Selection[i + 1].Position) / 2),
			PathIndex = s_Selection[i].PathIndex
		})

		self:Select(p_SelectionId, s_NewWaypoint)
		self:InsertAfter(s_Selection[i], s_NewWaypoint)
	end

	return true, 'Success'
end

-----------------------------
-- Paths

function NodeCollection:ShowPath(p_PathIndex)
	self.hiddenPaths[p_PathIndex] = false
end

function NodeCollection:HidePath(p_PathIndex)
	self.hiddenPaths[p_PathIndex] = true
end

function NodeCollection:IsPathVisible(p_PathIndex)
	return self.hiddenPaths[p_PathIndex] == nil or self.hiddenPaths[p_PathIndex] == false
end

function NodeCollection:GetHiddenPaths()
	return self.hiddenPaths
end

-----------------------------
-- Save/Load

function NodeCollection:Load(p_LevelName, p_GameMode)

	if p_GameMode ~= nil and p_LevelName ~= nil then
		self.mapName = p_LevelName .. '_' .. p_GameMode
		self.mapName = self.mapName:gsub(" ", "_")
	end

	if self.mapName == '' or self.mapName == nil then
		m_Logger:Error('Mapname not set. Abort Load')
		return
	end

	m_Logger:Write('Load: ' .. self.mapName)

	if not SQL:Open() then
		m_Logger:Error('Failed to open SQL. ' .. SQL:Error())
		return
	end

	local s_Query = [[
		CREATE TABLE IF NOT EXISTS ]] .. self.mapName .. [[_table (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		pathIndex INTEGER,
		pointIndex INTEGER,
		transX FLOAT,
		transY FLOAT,
		transZ FLOAT,
		inputVar INTEGER,
		data TEXT
		)
	]]

	if not SQL:Query(s_Query) then
		m_Logger:Error('Failed to create table for map [' .. self.mapName .. ']: ' .. SQL:Error())
		return
	end


	-- Fetch all rows from the table.
	local s_Results = SQL:Query('SELECT * FROM ' .. self.mapName .. '_table ORDER BY pathIndex, pointIndex ASC')

	if not s_Results then
		m_Logger:Error('Failed to retrieve waypoints for map [' .. self.mapName .. ']: ' .. SQL:Error())
		return
	end

	self:Clear()
	local s_PathCount = 0
	local s_WaypointCount = 0
	local s_FirstWaypoint = nil
	local s_LastWaypoint = nil

	for _, l_Row in pairs(s_Results) do
		if l_Row["pathIndex"] > s_PathCount then
			s_PathCount = l_Row["pathIndex"]
		end

		local s_Waypoint = {
			OriginalID = l_Row["id"],
			Position = Vec3(l_Row["transX"], l_Row["transY"], l_Row["transZ"]),
			PathIndex = l_Row["pathIndex"],
			PointIndex = l_Row["pointIndex"],
			InputVar = l_Row["inputVar"],
			SpeedMode = l_Row["inputVar"] & 0xF,
			ExtraMode = (l_Row["inputVar"] >> 4) & 0xF,
			OptValue = (l_Row["inputVar"] >> 8) & 0xFF,
			Data = json.decode(l_Row["data"] or '{}')
		}

		if s_FirstWaypoint == nil then
			s_FirstWaypoint = s_Waypoint
		end

		if s_LastWaypoint ~= nil then
			s_Waypoint.Previous = s_LastWaypoint.ID
			s_LastWaypoint.Next = s_Waypoint.ID
		end

		s_Waypoint = self:Create(s_Waypoint, true)
		s_LastWaypoint = s_Waypoint
		s_WaypointCount = s_WaypointCount + 1
	end

	SQL:Close()
	self:RecalculateIndexes(s_LastWaypoint)
	self:ProcessMetadata()

	-- we're on the server
	-- if Globals ~= nil then
	-- Globals.wayPoints = self.waypointsByPathIndex
	-- Globals.activeTraceIndexes = pathCount
	-- end

	m_Logger:Write('Load -> Paths: ' .. tostring(s_PathCount) .. ' | Waypoints: ' .. tostring(s_WaypointCount))

	ChatManager:Yell(Language:I18N('Loaded %d paths with %d waypoints for map %s', s_PathCount, s_WaypointCount,
		self.mapName), 5.5)
end

function NodeCollection:Save()
	if not SQL:Open() then
		m_Logger:Error('Could not open database')
		return
	end

	if self.mapName == '' or self.mapName == nil then
		m_Logger:Error('Mapname not set. Abort Save')
		return
	end

	if not SQL:Query('DROP TABLE IF EXISTS ' .. self.mapName .. '_table') then
		m_Logger:Error('Failed to reset table for map [' .. self.mapName .. ']: ' .. SQL:Error())
		return
	end

	local s_Query = [[
		CREATE TABLE IF NOT EXISTS ]] .. self.mapName .. [[_table (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		pathIndex INTEGER,
		pointIndex INTEGER,
		transX FLOAT,
		transY FLOAT,
		transZ FLOAT,
		inputVar INTEGER,
		data TEXT
		)
	]]

	if not SQL:Query(s_Query) then
		m_Logger:Error('Failed to create table for map [' .. self.mapName .. ']: ' .. SQL:Error())
		return
	end

	ChatManager:Yell(Language:I18N('Save in progress...'), 1)

	local s_ChangedWaypoints = {}
	local s_WaypointCount = #self.waypoints
	local s_PathCount = 0
	local s_WaypointsChanged = 0
	local s_Orphans = {}
	local s_Disconnects = {}

	local s_BatchQueries = {}

	m_Logger:Write('NodeCollection:Save -> Processing: ' .. (s_WaypointCount))

	for _, l_Waypoint in pairs(self.waypoints) do
		-- keep track of disconnected nodes, only two should exist
		-- the first node and the last node
		if l_Waypoint.Previous == false and l_Waypoint.Next ~= false then
			table.insert(s_Disconnects, l_Waypoint)
		elseif l_Waypoint.Previous ~= false and l_Waypoint.Next == false then
			table.insert(s_Disconnects, l_Waypoint)
		end

		-- skip orphaned nodes
		if l_Waypoint.Previous == false and l_Waypoint.Next == false then
			table.insert(s_Orphans, l_Waypoint)
		else
			local s_WaypointData = {}

			if l_Waypoint.Data then
				-- shallow clone
				for l_Key, l_Value in pairs(l_Waypoint.Data) do
					s_WaypointData[l_Key] = l_Value
				end

				--convert linked node ids to {pathIndex,pointindex}
				if l_Waypoint.Data.Links ~= nil and #l_Waypoint.Data.Links > 0 then
					local s_ConvertedLinks = {}

					for i = 1, #l_Waypoint.Data.Links do
						local s_LinkedWaypoint = self:Get(l_Waypoint.Data.Links[i])

						if s_LinkedWaypoint ~= nil then
							table.insert(s_ConvertedLinks, { s_LinkedWaypoint.PathIndex, s_LinkedWaypoint.PointIndex })
						end
					end

					s_WaypointData.Links = s_ConvertedLinks
				end
			end

			local s_JsonSaveData = ''

			if s_WaypointData ~= nil and type(s_WaypointData) == 'table' then
				local s_JsonData, s_EncodeError = json.encode(s_WaypointData)

				if s_JsonData == nil then
					m_Logger:Warning('Waypoint [' .. l_Waypoint.ID .. '] data could not encode: ' .. tostring(s_EncodeError))
					m_Logger:Warning('waypoint -> ' .. m_Utilities:dump(l_Waypoint, true, 1))
					m_Logger:Warning('waypointData -> ' .. m_Utilities:dump(s_WaypointData, true))
				end

				if s_JsonData ~= '{}' then
					s_JsonSaveData = SQL:Escape(table.concat(s_JsonData:split('"'), '""'))
				end
			end

			if l_Waypoint.PathIndex > s_PathCount then
				s_PathCount = l_Waypoint.PathIndex
			end

			table.insert(s_BatchQueries, '(' .. table.concat({
				l_Waypoint.PathIndex,
				l_Waypoint.PointIndex,
				l_Waypoint.Position.x,
				l_Waypoint.Position.y,
				l_Waypoint.Position.z,
				l_Waypoint.InputVar,
				'"' .. s_JsonSaveData .. '"'
			}, ',') .. ')')
		end
	end

	m_Logger:Write('Save -> Waypoints to write: ' .. (#s_BatchQueries))
	m_Logger:Write('Save -> Orphans: ' .. (#s_Orphans) .. ' (Removed)')
	m_Logger:Write('Save -> Disconnected: ' .. (#s_Disconnects) .. ' (Expected: 2)')

	if #s_Disconnects > 2 then
		m_Logger:Warning('WARNING! More than two disconnected nodes were found!')
		m_Logger:Warning(m_Utilities:dump(s_Disconnects, true, 2))
	end

	local s_QueriesDone = 0
	local s_QueriesTotal = #s_BatchQueries
	local s_BatchSize = 1000
	local s_HasError = false
	local s_InsertQuery = 'INSERT INTO ' ..
		self.mapName .. '_table (pathIndex, pointIndex, transX, transY, transZ, inputVar, data) VALUES '

	while s_QueriesTotal > s_QueriesDone and not s_HasError do
		local s_QueriesLeft = s_QueriesTotal - s_QueriesDone

		if s_QueriesLeft > s_BatchSize then
			s_QueriesLeft = s_BatchSize
		end

		local s_Values = ''

		for i = 1 + s_QueriesDone, s_QueriesLeft + s_QueriesDone do
			s_Values = s_Values .. s_BatchQueries[i]

			if i < s_QueriesLeft + s_QueriesDone then
				s_Values = s_Values .. ','
			end
		end

		if not SQL:Query(s_InsertQuery .. s_Values) then
			m_Logger:Write('Save -> Batch query failed [' .. s_QueriesDone .. ']: ' .. SQL:Error())
			return
		end

		s_QueriesDone = s_QueriesDone + s_QueriesLeft
	end

	-- Fetch all rows from the table.
	local s_Results = SQL:Query('SELECT * FROM ' .. self.mapName .. '_table')

	if not s_Results then
		m_Logger:Error('NodeCollection:Save -> Failed to double-check table entries for map [' ..
			self.mapName .. ']: ' .. SQL:Error())
		ChatManager:Yell(Language:I18N('Failed to execute query: %s', SQL:Error()), 5.5)
		return
	end

	SQL:Close()

	m_Logger:Write('Save -> Saved [' .. s_QueriesTotal .. '] waypoints for map [' .. self.mapName .. ']')
	ChatManager:Yell(Language:I18N('Saved %d paths with %d waypoints for map %s', s_PathCount, s_QueriesTotal, self.mapName)
		, 5.5)
end

-----------------------------
-- Navigation

function NodeCollection:Previous(p_Waypoint)
	if type(p_Waypoint.Previous) == 'string' then
		return self.waypointsByID[p_Waypoint.Previous]
	end

	return p_Waypoint.Previous
end

function NodeCollection:Next(p_Waypoint)
	if type(p_Waypoint.Next) == 'string' then
		return self.waypointsByID[p_Waypoint.Next]
	end

	return p_Waypoint.Next
end

-- discover in which direction an objective is from a given waypoint
-- returns <Direction>, <BestWaypoint>
-- <Direction> will be either 'Next' or 'Previous'
function NodeCollection:ObjectiveDirection(p_Waypoint, p_Objective, p_InVehicle)
	if p_Objective == '' then
		return 'Next', nil
	end

	local s_BestDirection = nil
	local s_BestWaypoint = nil

	local s_Direction = 'Next'
	local s_CurrentWaypoint = p_Waypoint

	while s_CurrentWaypoint and s_CurrentWaypoint[s_Direction] do
		if s_CurrentWaypoint[s_Direction].PathIndex > p_Waypoint.PathIndex then
			-- hit the last node in the path, reset start and reverse direction
			s_CurrentWaypoint = p_Waypoint
			s_Direction = 'Previous'
		elseif s_CurrentWaypoint[s_Direction].PathIndex < p_Waypoint.PathIndex then
			-- hit the first node in the path, finish searching
			break
		else
			if s_CurrentWaypoint[s_Direction].Data.Links ~= nil then
				for _, l_LinkID in pairs(s_CurrentWaypoint[s_Direction].Data.Links) do
					local s_Link = self:Get(l_LinkID)
					local s_PathWaypoint = self:GetFirst(s_Link.PathIndex)

					if s_PathWaypoint ~= nil and s_PathWaypoint.Data.Objectives ~= nil and
						table.has(s_PathWaypoint.Data.Objectives, p_Objective) then
						-- highest priority path found, return now
						if #s_PathWaypoint.Data.Objectives == 1 then
							return s_Direction, s_CurrentWaypoint[s_Direction]
						-- lower priority connecting path found, store for now
						else
							if s_BestDirection == nil then
								s_BestDirection = s_Direction
								s_BestWaypoint = s_CurrentWaypoint[s_Direction]
							end
						end
					end
				end
			end
		end

		s_CurrentWaypoint = s_CurrentWaypoint[s_Direction]
	end

	if s_BestDirection == nil then
		if not p_InVehicle then
			local s_Directions = { 'Next', 'Previous' }
			s_BestDirection = s_Directions[MathUtils:GetRandomInt(1, 2)]
		else
			s_BestDirection = 'Next'
		end
	end

	return s_BestDirection, s_BestWaypoint
end

function NodeCollection:GetKnownObjectives()
	local s_Objectives = {
		--[<Objective Name>] = {<PathIndex 1>, <PathIndex 2>}
	}

	for l_PathIndex, _ in pairs(self.waypointsByPathIndex) do
		local s_PathWaypoint = self.waypointsByPathIndex[l_PathIndex][1]

		-- only insert objectives that are objectives (on at least one path alone)
		if s_PathWaypoint ~= nil and s_PathWaypoint.Data.Objectives ~= nil and #s_PathWaypoint.Data.Objectives == 1 then
			local s_Objective = s_PathWaypoint.Data.Objectives[1]
			if s_Objectives[s_Objective] == nil then
				s_Objectives[s_Objective] = {}
			end

			table.insert(s_Objectives[s_Objective], l_PathIndex)
		end
	end

	return s_Objectives
end

-- this method avoids the use of the Vec3:Distance() method to avoid complex math internally
-- it's a tradeoff for speed over accuracy, as this method produces a box instead of a sphere
-- @returns boolean whther given waypoint is inside the given range
function NodeCollection:InRange(p_Waypoint, p_Vec3Position, p_Range)
	local s_PosA = p_Waypoint.Position or Vec3.zero
	local s_PosB = p_Vec3Position or Vec3.zero
	return (math.abs(s_PosA.x - s_PosB.x) <= p_Range and
		math.abs(s_PosA.y - s_PosB.y) <= p_Range and
		math.abs(s_PosA.z - s_PosB.z) <= p_Range)
end

-- this method avoids the use of the Vec3:Distance() method to avoid complex math internally
-- it's a tradeoff for speed over accuracy, as this method produces a box instead of a sphere
-- @returns float of Distance
function NodeCollection:GetDistance(p_Waypoint, p_Vec3Position)
	local s_PosA = p_Waypoint.Position or Vec3.zero
	local s_PosB = p_Vec3Position or Vec3.zero
	local s_DiffX = math.abs(s_PosA.x - s_PosB.x)
	local s_DiffY = math.abs(s_PosA.y - s_PosB.y)
	local s_DiffZ = math.abs(s_PosA.z - s_PosB.z)
	if s_DiffX > s_DiffZ then
		return s_DiffX + 0.5 * s_DiffZ + 0.25 * s_DiffY
	else
		return s_DiffZ + 0.5 * s_DiffX + 0.25 * s_DiffY
	end
end

-- Find the closest waypoint at position `p_Vec3Position` with a search radius of `p_Tolerance`
function NodeCollection:Find(p_Vec3Position, p_Tolerance)
	if p_Tolerance == nil then
		p_Tolerance = 0.2
	end

	local s_ClosestWaypoint = nil
	local s_ClosestWaypointDist = p_Tolerance

	for _, l_Waypoint in pairs(self.waypointsByID) do
		if l_Waypoint ~= nil and l_Waypoint.Position ~= nil and self:IsPathVisible(l_Waypoint.PathIndex) and
			self:IsPathVisible(l_Waypoint.PathIndex) then
			if self:InRange(l_Waypoint, p_Vec3Position, p_Tolerance) then -- faster check
				local s_Distance = l_Waypoint.Position:Distance(p_Vec3Position) -- then do slower math

				if s_ClosestWaypoint == nil then
					s_ClosestWaypoint = l_Waypoint
					s_ClosestWaypointDist = s_Distance
				elseif (s_Distance < s_ClosestWaypointDist) then
					s_ClosestWaypoint = l_Waypoint
					s_ClosestWaypointDist = s_Distance
				end
			end
		end
	end

	return s_ClosestWaypoint
end

-- Find all waypoints within `p_Tolerance` range of the position `p_Vec3Position`
function NodeCollection:FindAll(p_Vec3Position, p_Tolerance)
	if p_Tolerance == nil then
		p_Tolerance = 0.2
	end

	local s_WaypointsFound = {}

	for _, l_Waypoint in pairs(self.waypointsByID) do
		if l_Waypoint ~= nil and l_Waypoint.Position ~= nil and self:IsPathVisible(l_Waypoint.PathIndex) and
			self:InRange(l_Waypoint, p_Vec3Position, p_Tolerance) then
			table.insert(s_WaypointsFound, l_Waypoint)
		end
	end

	return s_WaypointsFound
end

function NodeCollection:FindAlongTrace(p_Vec3Start, p_Vec3End, p_Granularity, p_Tolerance)
	if p_Granularity == nil then
		p_Granularity = 0.25
	end

	if p_Tolerance == nil then
		p_Tolerance = 0.2
	end

	self:Log('NodeCollection:FindAlongTrace - p_Granularity: ' .. tostring(p_Granularity))
	self:Log('NodeCollection:FindAlongTrace - p_Tolerance: ' .. tostring(p_Tolerance))

	local s_Distance = math.min(math.max(p_Vec3Start:Distance(p_Vec3End), 0.05), 10)

	-- instead of searching a possible 3k or more nodes, we grab only those that would be in range
	-- shift the search area forward by 1/2 distance and also 1/2 the radius needed
	local s_SearchAreaPos = p_Vec3Start + ((p_Vec3End - p_Vec3Start) * 0.4) -- not exactly half ahead
	local s_SearchAreaSize = (s_Distance * 0.6) -- lil bit bigger than half for searching
	NetEvents:Send('ClientNodeEditor:SetLastTraceSearchArea', { s_SearchAreaPos:Clone(), s_SearchAreaSize })

	if g_ClientNodeEditor then
		g_ClientNodeEditor:_onSetLastTraceSearchArea({ s_SearchAreaPos:Clone(), s_SearchAreaSize })
	end

	local s_SearchWaypoints = self:FindAll(s_SearchAreaPos, s_SearchAreaSize)
	local s_TestPos = p_Vec3Start:Clone()

	self:Log('distance: ' .. tostring(s_Distance))
	self:Log('searchWaypoints: ' .. tostring(#s_SearchWaypoints))

	if #s_SearchWaypoints == 1 then
		return s_SearchWaypoints[1]
	end

	local s_Heading = p_Vec3End - p_Vec3Start
	local s_Direction = s_Heading / s_Heading.magnitude

	while #s_SearchWaypoints > 0 and s_Distance > p_Granularity and s_Distance > 0 do
		for _, l_Waypoint in pairs(s_SearchWaypoints) do
			if l_Waypoint ~= nil and self:IsPathVisible(l_Waypoint.PathIndex) and l_Waypoint.Position ~= nil and
				l_Waypoint.Position:Distance(s_TestPos) <= p_Tolerance then
				self:Log('NodeCollection:FindAlongTrace -> Found: ' .. l_Waypoint.ID)
				return l_Waypoint
			end
		end

		s_TestPos = s_TestPos + (s_Direction * p_Granularity)
		s_Distance = s_TestPos:Distance(p_Vec3End)
	end

	return nil
end

function NodeCollection:Log(...)
	m_Logger:Write(Language:I18N(...))
end

if g_NodeCollection == nil then
	---@type NodeCollection
	g_NodeCollection = NodeCollection()
end

return g_NodeCollection
