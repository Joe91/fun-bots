class "NodeCollection"

local m_Utilities = require('__shared/Utilities.lua')
local m_Logger = Logger("NodeCollection", Debug.Server.NODECOLLECTION)

requireExists('Globals')

function NodeCollection:__init(p_DisableServerEvents)
	self:InitTables()
	if (p_DisableServerEvents == nil or not p_DisableServerEvents) then
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
	NetEvents:Subscribe('NodeCollection:Merge', self, self.MergeSelected)
	NetEvents:Subscribe('NodeCollection:Split', self, self.SplitSelected)

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

function NodeCollection:DeregisterEvents()
		-- Management
	NetEvents:Unsubscribe('NodeCollection:Register')
	NetEvents:Unsubscribe('NodeCollection:Remove')
	NetEvents:Unsubscribe('NodeCollection:InsertAfter')
	NetEvents:Unsubscribe('NodeCollection:InsertBefore')
	NetEvents:Unsubscribe('NodeCollection:Update')
	NetEvents:Unsubscribe('NodeCollection:SetInput')
	NetEvents:Unsubscribe('NodeCollection:Merge')
	NetEvents:Unsubscribe('NodeCollection:Split')

	-- Selection
	NetEvents:Unsubscribe('NodeCollection:Select')
	NetEvents:Unsubscribe('NodeCollection:Deselect')
	NetEvents:Unsubscribe('NodeCollection:ClearSelection')

	-- Paths
	NetEvents:Unsubscribe('NodeCollection:ShowPath')
	NetEvents:Unsubscribe('NodeCollection:HidePath')

	-- Save/Load
	NetEvents:Unsubscribe('NodeCollection:Save')
	NetEvents:Unsubscribe('NodeCollection:Load')
end

-----------------------------
-- Management

function NodeCollection:Create(p_Data, p_Authoritative)
	p_Authoritative = p_Authoritative or false
	local newIndex = #self.waypoints+1
	local inputVar = 3

	-- setup defaults for a blank node
	local waypoint = {
		ID = string.format('p_%d', newIndex), -- new generated id for internal storage
		OriginalID = nil, -- original id from database
		Index = newIndex, -- new generated id in numerical form
		Position = Vec3(0,0,0),
		PathIndex = 1, -- Path #
		PointIndex = 1, -- index inside parent path
		InputVar = inputVar, -- raw input value
		SpeedMode = inputVar & 0xF, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
		ExtraMode = (inputVar >> 4) & 0xF,
		OptValue = (inputVar >> 8) & 0xFF,
		Data = {},
		Distance = nil, -- current distance to player
		Updated = false, -- if true, needs to be sent to server for saving
		Previous = false, -- tree navigation
		Next = false
	}

	if (p_Data ~= nil) then
		for k,v in pairs(p_Data) do
			if (v ~= nil) then
				if (not p_Authoritative and (k == 'ID' or k == 'Index' or k == 'Previous' or k == 'Next')) then
					goto continue
				end
				waypoint[k] = v
			end
			::continue::
		end
	end

	self:Register(waypoint)
	return waypoint
end

function NodeCollection:Register(p_Waypoint)

	if (self.hiddenPaths[p_Waypoint.PathIndex] == nil) then
		self.hiddenPaths[p_Waypoint.PathIndex] = false
	end
	if (self.waypointsByPathIndex[p_Waypoint.PathIndex] == nil) then
		self.waypointsByPathIndex[p_Waypoint.PathIndex] = {}
	end

	-- node associations are already set, don't change them
	if (p_Waypoint.Previous and p_Waypoint.Next and false) then -- disabled for now

		-- begin searching for related nodes from the tail and work backwards
		for i=#self.waypointsByPathIndex[p_Waypoint.PathIndex], 1, -1 do

			local currentWaypoint = self.waypointsByPathIndex[p_Waypoint.PathIndex][i]

			if (currentWaypoint ~= nil) then
				-- our new node should go ahead of the currentWaypoint
				if (currentWaypoint.PointIndex == p_Waypoint.PointIndex-1) then
					-- update connections
					self:InsertAfter(currentWaypoint, p_Waypoint)

				-- our new node should go behind the current waypoint
				elseif (currentWaypoint.PointIndex == p_Waypoint.PointIndex+1) then
					-- update connections
					self:InsertBefore(currentWaypoint, p_Waypoint)
				end
			end
		end
	end

	table.insert(self.waypoints, p_Waypoint)
	if (#self.waypoints ~= p_Waypoint.Index) then
		local diff = p_Waypoint.Index - #self.waypoints

		m_Logger:Warning('New Node Index does not match: p_Waypoint.Index:'..tostring(p_Waypoint.Index)..' | #self.waypoints:'..tostring(#self.waypoints)..' | '.. tostring(diff))
	end

	table.insert(self.waypointsByPathIndex[p_Waypoint.PathIndex], p_Waypoint)
	if (#self.waypointsByPathIndex[p_Waypoint.PathIndex] ~= p_Waypoint.PointIndex) then
		local diff = p_Waypoint.PointIndex - #self.waypointsByPathIndex[p_Waypoint.PathIndex]

		m_Logger:Warning('New Node PointIndex does not match: p_Waypoint.PointIndex: '..tostring(p_Waypoint.PointIndex)..' | #self.waypointsByPathIndex['..p_Waypoint.PathIndex..']: '..tostring(#self.waypointsByPathIndex[p_Waypoint.PathIndex])..' | '.. tostring(diff))
	end
	self.waypointsByID[p_Waypoint.ID] = p_Waypoint

	return p_Waypoint
end

function NodeCollection:Add()
	local selection = self:GetSelected()
	if (#selection == 2) then

		local orphan = nil
		local referrence = nil
		for i=1, #selection do
			if (not selection[i].Previous and not selection[i].Next) then
				orphan = selection[i]
			else
				referrence = selection[i]
			end
		end

		if (orphan ~= nil and referrence ~= nil) then
			self:Update(orphan, {
				PathIndex = referrence.PathIndex
			})

			self:InsertAfter(referrence, orphan)
			return true, 'Success'
		else
			return false, 'Two Waypoints: Must select only orphaned node and connected node'
		end
	elseif (#selection == 1) then
		local lastWaypoint = selection[#selection]
		local newWaypoint = self:Create({
			PathIndex = lastWaypoint.PathIndex,
			PointIndex = lastWaypoint.PointIndex + 1,
			Previous = lastWaypoint.ID
		})
		self:InsertAfter(lastWaypoint, newWaypoint)
		return newWaypoint, 'Success'
	else
		local lastWaypoint = self.waypoints[#self.waypoints]
		local newWaypoint = self:Create({
			PathIndex = lastWaypoint.PathIndex + 1,
			PointIndex = lastWaypoint.PointIndex + 1,
			Previous = lastWaypoint.ID
		})
		self:InsertAfter(lastWaypoint, newWaypoint)
		return newWaypoint, 'Success'
	end
	return false, 'Must select up to two waypoints'
end

function NodeCollection:Remove(p_Waypoint)

	-- batch operation on selections
	if (p_Waypoint == nil) then
		local selection = self:GetSelected()
		for _,selectedWaypoint in pairs(selection) do
			self:Remove(selectedWaypoint)
		end
		return true, 'Success'
	end

	m_Logger:Write('Removing: '..tostring(p_Waypoint.ID))

	-- update connections, no more middle-man
	if (p_Waypoint.Previous) then
		p_Waypoint.Previous.Next = p_Waypoint.Next
	end
	if (p_Waypoint.Next) then
		p_Waypoint.Next.Previous = p_Waypoint.Previous
	end

	-- use connections to update indexes
	self:Unlink(p_Waypoint)
	if (p_Waypoint.Previous) then
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
	self.selectedWaypoints[p_Waypoint.ID] = nil
	return true, 'Success'
	-- go hit the gym
end

function NodeCollection:InsertAfter(p_ReferrenceWaypoint, p_Waypoint)

	if (type(p_Waypoint.Next) == 'string') then
		p_Waypoint.Next = self.waypointsByID[p_Waypoint.Next]
	end
	if (type(p_Waypoint.Previous) == 'string') then
		p_Waypoint.Previous = self.waypointsByID[p_Waypoint.Previous]
	end

	p_Waypoint.Next = p_ReferrenceWaypoint.Next
	p_Waypoint.Previous = p_ReferrenceWaypoint
	p_ReferrenceWaypoint.Next = p_Waypoint
	if (p_Waypoint.Next) then
		p_Waypoint.Next.Previous = p_Waypoint
	end

	-- use connections to update indexes
	self:RecalculateIndexes(p_ReferrenceWaypoint)
end

function NodeCollection:InsertBefore(p_ReferrenceWaypoint, p_Waypoint)

	if (type(p_Waypoint.Next) == 'string') then
		p_Waypoint.Next = self.waypointsByID[p_Waypoint.Next]
	end
	if (type(p_Waypoint.Previous) == 'string') then
		p_Waypoint.Previous = self.waypointsByID[p_Waypoint.Previous]
	end

	p_Waypoint.Previous = p_ReferrenceWaypoint.Previous
	p_Waypoint.Next = p_ReferrenceWaypoint
	p_ReferrenceWaypoint.Previous = p_Waypoint
	if (p_Waypoint.Previous) then
		p_Waypoint.Previous.Next = p_Waypoint
	end

	-- use connections to update indexes
	self:RecalculateIndexes(p_Waypoint.Previous or p_Waypoint)
end

function NodeCollection:RecalculateIndexes(p_Waypoint)
	m_Logger:Write('RecalculateIndexes Starting...')

	local counter = 0

	if (p_Waypoint == nil) then
		for i=1, #self.waypoints do
			self.waypoints[i] = self:_processWaypointRecalc(self.waypoints[i])
			counter = counter + 1
		end
	else

		local direction = "Next"
		if (not p_Waypoint.Next) then
			direction = "Previous"
		end

		while p_Waypoint do
			self.waypoints[p_Waypoint.Index] = self:_processWaypointRecalc(p_Waypoint)
			p_Waypoint = p_Waypoint[direction]
			counter = counter + 1
		end
	end

	m_Logger:Write('RecalculateIndexes Finished! ['..tostring(counter)..']')
end

function NodeCollection:_processWaypointRecalc(p_Waypoint)
	local lastIndex = 0
	local lastPathIndex = 0
	local lastPointIndex = 0
	local currentPathIndex = -1

	-- convert neighbor referrences
	if (type(p_Waypoint.Next) == 'string') then
		p_Waypoint.Next = self.waypointsByID[p_Waypoint.Next]
		if (p_Waypoint.Next) then
			p_Waypoint.Next.Previous = p_Waypoint
		end
	end

	if (type(p_Waypoint.Previous) == 'string') then
		p_Waypoint.Previous = self.waypointsByID[p_Waypoint.Previous]
		if (p_Waypoint.Previous) then
			p_Waypoint.Previous.Next = p_Waypoint
		end
	end

	if (p_Waypoint.Previous) then
		lastIndex = p_Waypoint.Previous.Index
		lastPathIndex = p_Waypoint.Previous.PathIndex
		lastPointIndex = p_Waypoint.Previous.PointIndex
	end

	--reset lastPointIndex on new path
	if (p_Waypoint.PathIndex ~= lastPathIndex) then
		lastPathIndex = p_Waypoint.PathIndex
		lastPointIndex = 0
	end

	if (p_Waypoint.PointIndex ~= lastPointIndex + 1) then
		lastPointIndex = lastPointIndex + 1
		p_Waypoint.PointIndex = lastPointIndex
		p_Waypoint.Updated = true
	end

	return p_Waypoint
end

function NodeCollection:ProcessMetadata(p_Waypoint)
	m_Logger:Write('ProcessMetadata Starting...')

	local counter = 0

	if (p_Waypoint == nil) then
		for i=1, #self.waypoints do
			self.waypoints[i] = self:_processWaypointMetadata(self.waypoints[i])
			counter = counter + 1
		end
	else
		self.waypoints[p_Waypoint.Index] = self:_processWaypointMetadata(p_Waypoint)
		counter = counter + 1
	end

	m_Logger:Write('ProcessMetadata Finished! ['..tostring(counter)..']')
end

function NodeCollection:_processWaypointMetadata(p_Waypoint)
	-- safety checks
	if (p_Waypoint.Data == nil) then
		p_Waypoint.Data = {}
	end

	if (type(p_Waypoint.Data) == 'string') then
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
	if (p_Waypoint.Data.LinkMode ~= nil and (p_Waypoint.Data.Links == nil or (type(p_Waypoint.Data.Links) == 'table' and #p_Waypoint.Data.Links < 1))) then

		-- indirect connections
		if (p_Waypoint.Data.LinkMode == 1) then

			local range = p_Waypoint.Data.Range or 3 -- meters, box-like area
			local chance = p_Waypoint.Data.Chance or 25 -- 1 - 100
			local nearbyNodes = self:FindAll(p_Waypoint.Position, range)

			p_Waypoint.Data.Links = {}
			for i=1, nearbyNodes do
				table.insert(p_Waypoint.Data.Links, nearbyNodes[i].ID)
			end
		end
	end

	-- if the Links table has entries, but they need converting
	if (p_Waypoint.Data.Links ~= nil) then
		for i=1, #p_Waypoint.Data.Links do
			local linkedData = p_Waypoint.Data.Links[i]
			if type(linkedData) == 'table' then
				local linkedWaypoint = self:Get(linkedData[2], linkedData[1])
				if (linkedWaypoint ~= nil) then
					p_Waypoint.Data.Links[i] = linkedWaypoint.ID
				end
			end
		end
	end

	return p_Waypoint
end

function NodeCollection:Update(p_Waypoint, p_Data)
	m_Utilities:mergeKeys(p_Waypoint, p_Data)
end

function NodeCollection:UpdateMetadata(p_Data)
	m_Logger:Write('[A] NodeCollection:UpdateMetadata -> p_Data: '..m_Utilities:dump(p_Data, true))

	local selection = self:GetSelected()
	if (#selection < 1) then
		return false, 'Must select one or more waypoints'
	end

	local errorMsg = ''
	if (type(p_Data) == 'string') then
		p_Data, errorMsg = json.decode(p_Data) or {}
	end

	m_Logger:Write('[B] NodeCollection:UpdateMetadata -> p_Data: '..m_Utilities:dump(p_Data, true))

	for i=1, #selection do
		self:Update(selection[i], {
			Data = m_Utilities:mergeKeys(selection[i].Data, p_Data)
		})
	end
	return true, 'Success'
end

function NodeCollection:SetInput(p_Speed, p_Extra, p_Option)

	p_Speed = tonumber(p_Speed) or 3
	p_Extra = tonumber(p_Extra) or 0
	p_Option = tonumber(p_Option) or 0
	local inputVar = (p_Speed & 0xF) + ((p_Extra & 0xF)<<4) + ((p_Option & 0xFF) <<8)

	local selection = self:GetSelected()
	for i=1, #selection do
		self:Update(selection[i], {
			InputVar = inputVar,
			SpeedMode = p_Speed,
			ExtraMode = p_Extra,
			OptValue = p_Option
		})
	end
	return inputVar
end

-- Created a linked connection between two or more arbitrary waypoints
-- p_Waypoints | Waypoint or {Waypoint} | Can be a single waypoint or a table of waypoints, `nil` defaults to current selection
-- p_LinkID | string | a waypoint ID, must not be `nil`
-- p_OneWay | boolean | if true, the connection is only made on this node, prevents infinite recursion
function NodeCollection:Link(p_Waypoints, p_LinkID, p_OneWay)

	local selection = p_Waypoints or g_NodeCollection:GetSelected()
	p_OneWay = p_OneWay or false

	if (#selection == 2) then
		--special case, nodes link to each other
		self:Link(selection[1], selection[2].ID, true)
		self:Link(selection[2], selection[1].ID, true)
		return true, 'Success'

	elseif (#selection > 0) then
		for i=1, #selection do
			local success, msg = self:Link(selection[i], p_LinkID)
			if (not success) then
				return success, msg
			end
		end
		return true, 'Success'
	end

	if (p_LinkID == nil) then
		return false, 'Must specify link id'
	end

	local links = selection.Data.Links or {}
	table.insert(links, p_LinkID)
	self:Update(selection.Data, {
		LinkMode = (selection.Data.LinkMode or 0),
		Links = links
	})

	if (not p_OneWay) then
		self:Link(self:Get(p_LinkID), selection.ID, true)
	end

	return true, 'Success'
end

-- Removes a linked connection between two or more arbitrary waypoints
-- p_Waypoints | Waypoint or {Waypoint} | Can be a single waypoint or a table of waypoints, `nil` defaults to current selection
-- p_LinkID | string | a waypoint ID to remove, can be `nil` to clear connections
-- p_OneWay | boolean | if true, the connection is only made on this node, prevents infinite recursion
function NodeCollection:Unlink(p_Waypoints, p_LinkID, p_OneWay)

	local selection = p_Waypoints or g_NodeCollection:GetSelected()
	p_OneWay = p_OneWay or false

	if (#selection == 2) then
		--special case, nodes unlink from each other
		self:Unlink(selection[1], selection[2].ID, true)
		self:Unlink(selection[2], selection[1].ID, true)
		return true, 'Success'

	elseif (#selection > 0) then
		for i=1, #selection do
			local success, msg = self:Unlink(selection[i], p_LinkID)
			if (not success) then
				return success, msg
			end
		end
		return true, 'Success'
	end

	local newLinks = {}

	-- generate new links table, otherwise it gets emptied
	if (p_LinkID ~= nil and selection.Data.Links ~= nil) then
		for i=1, #selection.Data.Links do
			if (selection.Data.Links[i] ~= p_LinkID) then
				-- skip matching connections
				table.insert(newLinks, selection.Data.Links[i])
			else
				-- remove link from connected node, `p_OneWay` prevents infinite recursion
				if (not p_OneWay) then
					self:Unlink(self:Get(p_LinkID), selection.ID, true)
				end
			end
		end
	end

	-- update waypoint's Data table, remove linking info if necessary
	m_Logger:Write('newLinks -> '..m_Utilities:dump(newLinks, true))

	if (#newLinks > 0) then
		self:Update(selection.Data, {
			LinkMode = (selection.Data.LinkMode or 0),
			Links = newLinks
		})
	else
		local newData = {}
		if (selection.Data ~= nil) then
			for k,v in pairs(selection.Data) do
				if (k ~= 'Links' and k ~= 'LinkMode') then
					newData[k] = v
				end
			end
		end
		self:Update(selection, {
			Data = newData
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

function NodeCollection:Get(p_Waypoint, p_PathIndex)
	if (p_Waypoint ~= nil) then
		if (p_PathIndex ~= nil) then

			if (self.waypointsByPathIndex[p_PathIndex] == nil) then
				self.waypointsByPathIndex[p_PathIndex] = {}
			end

			if (type(p_Waypoint) == 'number') then
				return self.waypointsByPathIndex[p_PathIndex][p_Waypoint]
			elseif (type(p_Waypoint) == 'string') then
				for i=1, #self.waypointsByPathIndex[p_PathIndex] do
					local targetWaypoint = self.waypointsByPathIndex[p_PathIndex][i]
					if (targetWaypoint.PathIndex == p_PathIndex and targetWaypoint.ID == p_Waypoint) then
						return targetWaypoint
					end
				end
			elseif (type(p_Waypoint) == 'table') then
				for i=1, #self.waypointsByPathIndex[p_PathIndex] do
					local targetWaypoint = self.waypointsByPathIndex[p_PathIndex][i]
					if (targetWaypoint.PathIndex == p_PathIndex and targetWaypoint.ID == p_Waypoint.ID) then
						return targetWaypoint
					end
				end
			end
		else
			if (type(p_Waypoint) == 'string') then
				return self.waypointsByID[p_Waypoint]
			elseif (type(p_Waypoint) == 'table') then
				return self.waypointsByID[p_Waypoint.ID]
			else
				for i=1, #self.waypoints do
					if (self.waypoints[i].Index == p_Waypoint) then
						return self.waypoints[i]
					end
				end
			end
		end
		return nil
	elseif (p_PathIndex ~= nil) then
		if (self.waypointsByPathIndex[p_PathIndex] == nil) then
			self.waypointsByPathIndex[p_PathIndex] = {}
		end
		return self.waypointsByPathIndex[p_PathIndex]
	end
	return self.waypoints
end

function NodeCollection:GetFirst(p_PathIndex)

	local firstWaypoint = self.waypoints[1]

	if (p_PathIndex ~= nil) then

		if (self.waypointsByPathIndex[p_PathIndex] == nil) then
			return false
		end

		firstWaypoint = self.waypointsByPathIndex[p_PathIndex][1]
	end

	if (firstWaypoint == nil) then
		return false
	end

	while firstWaypoint.Previous and ((p_PathIndex ~= nil and firstWaypoint.Previous.PathIndex == firstWaypoint.PathIndex) or p_PathIndex == nil) do
		firstWaypoint = firstWaypoint.Previous
	end
	return firstWaypoint
end

function NodeCollection:GetLast(p_PathIndex)

	local lastWaypoint = self.waypoints[#self.waypoints]

	if (p_PathIndex ~= nil) then

		if (self.waypointsByPathIndex[p_PathIndex] == nil) then
			return false
		end

		lastWaypoint = self.waypointsByPathIndex[p_PathIndex][#self.waypointsByPathIndex[p_PathIndex]]
	end

	if (lastWaypoint == nil) then
		return false
	end

	while lastWaypoint.Next and ((p_PathIndex ~= nil and lastWaypoint.Next.PathIndex == lastWaypoint.PathIndex) or p_PathIndex == nil) do
		lastWaypoint = lastWaypoint.Next
	end
	return lastWaypoint
end

function NodeCollection:GetPaths()
	return self.waypointsByPathIndex
end

function NodeCollection:Clear()
	m_Logger:Write('NodeCollection:Clear')

	for i=1, #self.waypoints do
		self.waypoints[i].Next = nil
		self.waypoints[i].Previous = nil
	end
	self.waypoints = {}

	self.waypointsByID = {}
	for i=1, #self.waypointsByPathIndex do
		self.waypointsByPathIndex[i] = {}
	end
	self.waypointsByPathIndex = {}
	self.selectedWaypoints = {}
end

-----------------------------
-- Selection

function NodeCollection:Select(p_Waypoint, p_PathIndex)
	if (p_Waypoint == nil) then return end

	p_Waypoint = self:Get(p_Waypoint, p_PathIndex)
	if (p_Waypoint == nil) then return end
	self.selectedWaypoints[p_Waypoint.ID] = p_Waypoint
end

function NodeCollection:Deselect(p_Waypoint, p_PathIndex)
	if (p_Waypoint == nil) then
		self:ClearSelection()
	else

		p_Waypoint = self:Get(p_Waypoint, p_PathIndex)
		if (p_Waypoint == nil) then return end
		self.selectedWaypoints[p_Waypoint.ID] = nil
	end
end

function NodeCollection:IsSelected(p_Waypoint, p_PathIndex)
	if (p_Waypoint == nil) then return false end

	p_Waypoint = self:Get(p_Waypoint, p_PathIndex)
	if (p_Waypoint == nil) then return false end
	return self.selectedWaypoints[p_Waypoint.ID] ~= nil
end

function NodeCollection:GetSelected(p_PathIndex)
	local selection = {}
	-- copy selection into index-based array and sort results
	for waypointID,waypoint in pairs(self.selectedWaypoints) do
		if (self:IsSelected(waypoint) and (p_PathIndex == nil or waypoint.PathIndex == p_PathIndex)) then
			table.insert(selection, waypoint)
		end
	end

	if (p_PathIndex == nil) then
		self:_sort(selection, 'Index')
	else
		self:_sort(selection, 'PointIndex')
	end
	return selection
end

function NodeCollection:ClearSelection()
	self.selectedWaypoints = {}
end

function NodeCollection:_sort(p_Collection, p_KeyName, p_Descending)

	p_KeyName = p_KeyName or 'Index'

	table.sort(p_Collection, function(a,b)
		if (a == nil) then
			return false
		end
		if (b == nil) then
			return true
		end
		if (p_Descending) then
			return a[p_KeyName] > b[p_KeyName]
		else
			return a[p_KeyName] < b[p_KeyName]
		end
	end)
	return p_Collection
end

function NodeCollection:MergeSelection()
	-- TODO
	-- combine selected nodes
	-- nodes must be sequential or the start/end of two paths

	local selection = self:GetSelected()
	if (#selection < 2) then
		return false, 'Must select two or more waypoints'
	end

	-- check is same path and sequential
	local currentWaypoint = selection[1]
	for i=2, #selection do

		if (currentWaypoint.PathIndex ~= selection[i].PathIndex) then
			return false, 'Waypoints must be on same path'
		end

		if (currentWaypoint.Next and currentWaypoint.Next.PointIndex ~= selection[i].PointIndex) then
			return false, 'Waypoints must be sequential'
		end
		currentWaypoint = selection[i]
	end

	-- all clear, points are on same path, and in order with no gaps
	local firstPoint = selection[1]
	local lastPoint = selection[#selection]
	local middlePosition = (firstPoint.Position + lastPoint.Position) / 2

	-- move the first node to the center
	firstPoint.Position = middlePosition

	-- remove all selected nodes except the first one
	for i=2, #selection do
		self:Remove(selection[i])
	end

	return true, 'Success'
end

function NodeCollection:SplitSelection()

	local selection = self:GetSelected()
	if (#selection < 2) then
		return false, 'Must select two or more waypoints'
	end

	-- check is same path and sequential
	local currentWaypoint = selection[1]
	for i=2, #selection do

		if (currentWaypoint.PathIndex ~= selection[i].PathIndex) then
			return false, 'Waypoints must be on same path'
		end

		if (currentWaypoint.Next and currentWaypoint.Next.PointIndex ~= selection[i].PointIndex) then
			return false, 'Waypoints must be sequential'
		end
		currentWaypoint = selection[i]
	end

	for i=1, #selection-1 do
		local newWaypoint = self:Create({
			Position = ((selection[i].Position + selection[i+1].Position) / 2),
			PathIndex = selection[i].PathIndex
		})

		self:Select(newWaypoint)
		self:InsertAfter(selection[i], newWaypoint)
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

	self.levelName = p_LevelName or self.levelName
	self.gameMode = p_GameMode or self.gameMode

	if Globals.isTdm or Globals.isGm or Globals.isScavenger then
		self.gameMode = 'TeamDeathMatch0' -- paths are compatible
	end
	self.mapName = self.levelName .. '_' .. self.gameMode
	if self.mapName == "MP_Subway_ConquestSmall0" then
		self.mapName = "MP_Subway_ConquestLarge0" --paths are the same
	end
	m_Logger:Write('Load: '..self.mapName)

	if not SQL:Open() then
		return
	end

	local query = [[
		CREATE TABLE IF NOT EXISTS ]]..self.mapName..[[_table (
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

	if not SQL:Query(query) then
		m_Logger:Error('Failed to create table for map ['..self.mapName..']: '..SQL:Error())
		return
	end


	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM '..self.mapName..'_table ORDER BY `pathIndex`, `pointIndex` ASC')

	if not results then
		m_Logger:Error('Failed to retrieve waypoints for map ['..self.mapName..']: '..SQL:Error())
		return
	end

	self:Clear()
	local pathCount = 0
	local waypointCount = 0
	local firstWaypoint = nil
	local lastWaypoint = nil

	for _, row in pairs(results) do
		if row["pathIndex"] > pathCount then
			pathCount = row["pathIndex"]
		end

		local waypoint = {
			OriginalID = row["id"],
			Position = Vec3(row["transX"], row["transY"], row["transZ"]),
			PathIndex = row["pathIndex"],
			PointIndex = row["pointIndex"],
			InputVar = row["inputVar"],
			SpeedMode = row["inputVar"] & 0xF,
			ExtraMode = (row["inputVar"] >> 4) & 0xF,
			OptValue = (row["inputVar"] >> 8) & 0xFF,
			Data = json.decode(row["data"] or '{}')
		}

		if (firstWaypoint == nil) then
			firstWaypoint = waypoint
		end
		if (lastWaypoint ~= nil) then
			waypoint.Previous = lastWaypoint.ID
			lastWaypoint.Next = waypoint.ID
		end

		waypoint = self:Create(waypoint, true)
		lastWaypoint = waypoint
		waypointCount = waypointCount+1
	end
	SQL:Close()
	self:RecalculateIndexes(lastWaypoint)
	self:ProcessMetadata()

	-- we're on the server
	--if (Globals ~= nil) then
		--Globals.wayPoints = self.waypointsByPathIndex
		--Globals.activeTraceIndexes = pathCount
	--end

	m_Logger:Write('Load -> Paths: '..tostring(pathCount)..' | Waypoints: '..tostring(waypointCount))

	ChatManager:Yell(Language:I18N('Loaded %d paths with %d waypoints for map %s', pathCount, waypointCount, self.mapName), 5.5)
end

function NodeCollection:Save()
	if not SQL:Open() then
		m_Logger:Error('Could not open database')
		return
	end

	if not SQL:Query('DROP TABLE IF EXISTS '..self.mapName..'_table') then
		m_Logger:Error('Failed to reset table for map ['..self.mapName..']: '..SQL:Error())
		return
	end

	local query = [[
		CREATE TABLE IF NOT EXISTS ]]..self.mapName..[[_table (
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

	if not SQL:Query(query) then
		m_Logger:Error('Failed to create table for map ['..self.mapName..']: '..SQL:Error())
		return
	end

	--self.mapName

	local changedWaypoints = {}
	local waypointCount = #self.waypoints
	local pathCount = 0
	local waypointsChanged = 0
	local orphans = {}
	local disconnects = {}

	local batchQueries = {}

	m_Logger:Write('NodeCollection:Save -> Processing: '..(waypointCount))

	for _,waypoint in pairs(self.waypoints) do

		-- keep track of disconnected nodes, only two should exist
		-- the first node and the last node
		if (waypoint.Previous == false and waypoint.Next ~= false) then
			table.insert(disconnects, waypoint)
		elseif (waypoint.Previous ~= false and waypoint.Next == false) then
			table.insert(disconnects, waypoint)
		end

		-- skip orphaned nodes
		if (waypoint.Previous == false and waypoint.Next == false) then
			table.insert(orphans, waypoint)
		else

			local waypointData = {}

			if (waypoint.Data) then

				-- shallow clone
				for k,v in pairs(waypoint.Data) do
					waypointData[k] = v
				end

				--convert linked node ids to {pathIndex,pointindex}
				if (waypoint.Data.Links ~= nil and #waypoint.Data.Links > 0) then
					local convertedLinks = {}
					for i=1, #waypoint.Data.Links do
						local linkedWaypoint = self:Get(waypoint.Data.Links[i])
						if (linkedWaypoint ~= nil) then
							table.insert(convertedLinks, {linkedWaypoint.PathIndex, linkedWaypoint.PointIndex})
						end
					end
					waypointData.Links = convertedLinks
				end
			end

			local jsonSaveData = ''

			if (waypointData ~= nil and type(waypointData) == 'table') then
				local jsonData, encodeError = json.encode(waypointData)
				if (jsonData == nil) then
					m_Logger:Warning('Waypoint ['..waypoint.ID..'] data could not encode: '..tostring(encodeError))
					m_Logger:Warning('waypoint -> '..m_Utilities:dump(waypoint, true, 1))
					m_Logger:Warning('waypointData -> '..m_Utilities:dump(waypointData, true))
				end

				if (jsonData ~= '{}') then
					jsonSaveData = SQL:Escape(table.concat(jsonData:split('"'), '""'))
				end
			end

			if (waypoint.PathIndex > pathCount) then
				pathCount = waypoint.PathIndex
			end

			table.insert(batchQueries, '('..table.concat({
				waypoint.PathIndex,
				waypoint.PointIndex,
				waypoint.Position.x,
				waypoint.Position.y,
				waypoint.Position.z,
				waypoint.InputVar,
				'"'..jsonSaveData..'"'
			}, ',')..')')
		end
	end

	m_Logger:Write('Save -> Waypoints to write: '..(#batchQueries))
	m_Logger:Write('Save -> Orphans: '..(#orphans)..' (Removed)')
	m_Logger:Write('Save -> Disconnected: '..(#disconnects)..' (Expected: 2)')

	if (#disconnects > 2) then
		m_Logger:Warning('WARNING! More than two disconnected nodes were found!')
		m_Logger:Warning(m_Utilities:dump(disconnects, true, 2))
	end

	local queriesDone = 0
	local queriesTotal = #batchQueries
	local batchSize = 1000
	local hasError = false
	local insertQuery = 'INSERT INTO '..self.mapName..'_table (pathIndex, pointIndex, transX, transY, transZ, inputVar, data) VALUES '

	while queriesTotal > queriesDone and not hasError do

		local queriesLeft = queriesTotal - queriesDone
		if queriesLeft > batchSize then
			queriesLeft = batchSize
		end
		local values = ''

		for i=1+queriesDone, queriesLeft+queriesDone do
			values = values..batchQueries[i]

			if i < queriesLeft+queriesDone then
				values = values .. ','
			end
		end

		if not SQL:Query(insertQuery..values) then
			m_Logger:Write('Save -> Batch query failed ['..queriesDone..']: ' .. SQL:Error())
			return
		end

		queriesDone = queriesDone + queriesLeft
	end

	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM '..self.mapName..'_table')

	if not results then
		m_Logger:Error('NodeCollection:Save -> Failed to double-check table entries for map ['..self.mapName..']: '..SQL:Error())
		ChatManager:Yell(Language:I18N('Failed to execute query: %s', SQL:Error()), 5.5)
		return
	end

	SQL:Close()

	m_Logger:Write('Save -> Saved ['..queriesTotal..'] waypoints for map ['..self.mapName..']')
	ChatManager:Yell(Language:I18N('Saved %d paths with %d waypoints for map %s', pathCount, queriesTotal, self.mapName), 5.5)
end

-----------------------------
-- Navigation

function NodeCollection:Previous(p_Waypoint)
	if (type(p_Waypoint.Previous) == 'string') then
		return self.waypointsByID[p_Waypoint.Previous]
	end
	return p_Waypoint.Previous
end

function NodeCollection:Next(p_Waypoint)
	if (type(p_Waypoint.Next) == 'string') then
		return self.waypointsByID[p_Waypoint.Next]
	end

	return p_Waypoint.Next
end

-- discover in which direction an objective is from a given waypoint
-- returns <Direction>, <BestWaypoint>
-- <Direction> will be either 'Next' or 'Previous'
function NodeCollection:ObjectiveDirection(p_Waypoint, p_Objective)

	local bestDirection = nil
	local bestWaypoint = nil

	local direction = 'Next'
	local currentWaypoint = p_Waypoint

	while currentWaypoint and currentWaypoint[direction] do

		if (currentWaypoint[direction].PathIndex > p_Waypoint.PathIndex) then
			-- hit the last node in the path, reset start and reverse direction
			currentWaypoint = p_Waypoint
			direction = 'Previous'

		elseif (currentWaypoint[direction].PathIndex < p_Waypoint.PathIndex) then
			-- hit the first node in the path, finish searching
			break
		else
			if (currentWaypoint[direction].Data.Links ~= nil) then
				for _,linkID in pairs(currentWaypoint[direction].Data.Links) do

					local link = self:Get(linkID)
					local pathWaypoint = self:GetFirst(link.PathIndex)

					if (pathWaypoint ~= nil and pathWaypoint.Data.Objectives ~= nil and table.has(pathWaypoint.Data.Objectives, p_Objective)) then

						-- highest priority path found, return now
						if (#pathWaypoint.Data.Objectives == 1) then
							return direction, currentWaypoint[direction]

						-- lower priority connecting path found, store for now
						else
							if (bestDirection == nil) then
								bestDirection = direction
								bestWaypoint = currentWaypoint[direction]
							end
						end
					end
				end
			end
		end

		currentWaypoint = currentWaypoint[direction]
	end

	if (bestDirection == nil) then
		local directions = {'Next','Previous'}
		bestDirection = directions[MathUtils:GetRandomInt(1, 2)]
	end

	return bestDirection, bestWaypoint
end

function NodeCollection:GetKnownOjectives()
	local objectives = {
		--[<Objective Name>] = {<PathIndex 1>, <PathIndex 2>}
	}
	for pathIndex,_ in pairs(self.waypointsByPathIndex) do
		local pathWaypoint = self.waypointsByPathIndex[pathIndex][1]
		if (pathWaypoint ~= nil and pathWaypoint.Data.Objectives ~= nil) then
			for _,objective in pairs(pathWaypoint.Data.Objectives) do
				if (objectives[objective] == nil) then
					objectives[objective] = {}
				end
				table.insert(objectives[objective], pathIndex)
			end
		end
	end
	return objectives
end

-- this method avoids the use of the Vec3:Distance() method to avoid complex math internally
-- it's a tradeoff for speed over accuracy, as this method produces a box instead of a sphere
-- @returns boolean whther given waypoint is inside the given range
function NodeCollection:InRange(p_Waypoint, p_Vec3Position, p_Range)
	local posA = p_Waypoint.Position or Vec3.zero
	local posB = p_Vec3Position or Vec3.zero
	return ( math.abs(posA.x - posB.x) <= p_Range and
		math.abs(posA.y - posB.y) <= p_Range and
		math.abs(posA.z - posB.z) <= p_Range )
end

-- Find the closest waypoint at position `p_Vec3Position` with a search radius of `p_Tolerance`
function NodeCollection:Find(p_Vec3Position, p_Tolerance)
	if (p_Tolerance == nil) then
		p_Tolerance = 0.2
	end

	local closestWaypoint = nil
	local closestWaypointDist = p_Tolerance

	for _,waypoint in pairs(self.waypointsByID) do

		if (waypoint ~= nil and waypoint.Position ~= nil and self:IsPathVisible(waypoint.PathIndex) and self:IsPathVisible(waypoint.PathIndex)) then
			if (self:InRange(waypoint, p_Vec3Position, p_Tolerance)) then -- faster check

				local distance = waypoint.Position:Distance(p_Vec3Position) -- then do slower math
				if (closestWaypoint == nil) then
					closestWaypoint = waypoint
					closestWaypointDist = distance
				elseif (distance < closestWaypointDist) then
					closestWaypoint = waypoint
					closestWaypointDist = distance
				end
			end
		end
	end
	return closestWaypoint
end

-- Find all waypoints within `p_Tolerance` range of the position `p_Vec3Position`
function NodeCollection:FindAll(p_Vec3Position, p_Tolerance)
	if (p_Tolerance == nil) then
		p_Tolerance = 0.2
	end

	local waypointsFound = {}

	for _,waypoint in pairs(self.waypointsByID) do

		if (waypoint ~= nil and waypoint.Position ~= nil and self:IsPathVisible(waypoint.PathIndex) and self:InRange(waypoint, p_Vec3Position, p_Tolerance)) then
			table.insert(waypointsFound, waypoint)
		end
	end
	return waypointsFound
end

function NodeCollection:FindAlongTrace(p_Vec3Start, p_Vec3End, p_Granularity, p_Tolerance)
	if (p_Granularity == nil) then
		p_Granularity = 0.25
	end
	if (p_Tolerance == nil) then
		p_Tolerance = 0.2
	end

	self:Log('NodeCollection:FindAlongTrace - p_Granularity: '..tostring(p_Granularity))
	self:Log('NodeCollection:FindAlongTrace - p_Tolerance: '..tostring(p_Tolerance))

	local distance = math.min(math.max(p_Vec3Start:Distance(p_Vec3End), 0.05), 10)

	-- instead of searching a possible 3k or more nodes, we grab only those that would be in range
	-- shift the search area forward by 1/2 distance and also 1/2 the radius needed
	local searchAreaPos = p_Vec3Start + ((p_Vec3End - p_Vec3Start) * 0.4) -- not exactly half ahead
	local searchAreaSize = (distance*0.6) -- lil bit bigger than half for searching
	NetEvents:Send('ClientNodeEditor:SetLastTraceSearchArea', {searchAreaPos:Clone(), searchAreaSize})
	if (g_ClientNodeEditor) then
		g_ClientNodeEditor:_onSetLastTraceSearchArea({searchAreaPos:Clone(), searchAreaSize})
	end

	local searchWaypoints = self:FindAll(searchAreaPos, searchAreaSize)
	local testPos = p_Vec3Start:Clone()

	self:Log('distance: '..tostring(distance))
	self:Log('searchWaypoints: '..tostring(#searchWaypoints))

	if (#searchWaypoints == 1) then
		return searchWaypoints[1]
	end

	local heading = p_Vec3End - p_Vec3Start
	local direction = heading / heading.magnitude

	while #searchWaypoints > 0 and distance > p_Granularity and distance > 0 do
		for _,waypoint in pairs(searchWaypoints) do
			if (waypoint ~= nil and self:IsPathVisible(waypoint.PathIndex) and waypoint.Position ~= nil and waypoint.Position:Distance(testPos) <= p_Tolerance) then
				self:Log('NodeCollection:FindAlongTrace -> Found: '..waypoint.ID)
				return waypoint
			end
		end
		testPos = testPos + (direction * p_Granularity)
		distance = testPos:Distance(p_Vec3End)
	end
	return nil
end

function NodeCollection:Log(...)
	m_Logger:Write(Language:I18N(...))
end

if g_NodeCollection == nil then
	g_NodeCollection = NodeCollection()
end

return g_NodeCollection
