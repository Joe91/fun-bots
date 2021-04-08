class "NodeCollection"

require('__shared/Utilities.lua')
requireExists('Globals')

function NodeCollection:__init(disableServerEvents)
	self:InitTables()
	if (disableServerEvents == nil or not disableServerEvents) then
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

function NodeCollection:Create(data, authoritative)
	authoritative = authoritative or false
	local newIndex = #self.waypoints+1
	local inputVar = 3

	-- setup defaults for a blank node
	local waypoint = {
		ID = string.format('p_%d', newIndex), -- new generated id for internal storage
		OriginalID = nil,					-- original id from database
		Index = newIndex, 					-- new generated id in numerical form
		Position = Vec3(0,0,0),
		PathIndex = 1, 						-- Path #
		PointIndex = 1, 					-- index inside parent path
		InputVar = inputVar, 				-- raw input value
		SpeedMode = inputVar & 0xF,			-- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
		ExtraMode = (inputVar >> 4) & 0xF,	-- 
		OptValue = (inputVar >> 8) & 0xFF,
		Data = {},
		Distance = nil,						-- current distance to player
		Updated = false,					-- if true, needs to be sent to server for saving
		Previous = false,						-- tree navigation
		Next = false
	}

	if (data ~= nil) then
		for k,v in pairs(data) do
			if (v ~= nil) then
				if (not authoritative and (k == 'ID' or k == 'Index' or k == 'Previous' or k == 'Next')) then
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

function NodeCollection:Register(waypoint)

	if (self.hiddenPaths[waypoint.PathIndex] == nil) then
		self.hiddenPaths[waypoint.PathIndex] = false
	end
	if (self.waypointsByPathIndex[waypoint.PathIndex] == nil) then
		self.waypointsByPathIndex[waypoint.PathIndex] = {}
	end

	-- node associations are already set, don't change them
	if (waypoint.Previous and waypoint.Next and false) then -- disabled for now

		-- begin searching for related nodes from the tail and work backwards
		for i=#self.waypointsByPathIndex[waypoint.PathIndex], 1, -1 do

			local currentWaypoint = self.waypointsByPathIndex[waypoint.PathIndex][i]

			if (currentWaypoint ~= nil) then
				-- our new node should go ahead of the currentWaypoint
				if (currentWaypoint.PointIndex == waypoint.PointIndex-1) then
					-- update connections
					self:InsertAfter(currentWaypoint, waypoint)

				-- our new node should go behind the current waypoint
				elseif (currentWaypoint.PointIndex == waypoint.PointIndex+1) then
					-- update connections
					self:InsertBefore(currentWaypoint, waypoint)
				end
			end
		end
	end

	table.insert(self.waypoints, waypoint)
	if (#self.waypoints ~= waypoint.Index) then
		local diff = waypoint.Index - #self.waypoints
		
		if Debug.Shared.NODECOLLECTION then
			print('Warning, New Node Index does not match: waypoint.Index:'..tostring(waypoint.Index)..' | #self.waypoints:'..tostring(#self.waypoints)..' | '.. tostring(diff))
		end
	end

	table.insert(self.waypointsByPathIndex[waypoint.PathIndex], waypoint)
	if (#self.waypointsByPathIndex[waypoint.PathIndex] ~= waypoint.PointIndex) then
		local diff = waypoint.PointIndex - #self.waypointsByPathIndex[waypoint.PathIndex]
		
		if Debug.Shared.NODECOLLECTION then
			print('Warning, New Node PointIndex does not match: waypoint.PointIndex: '..tostring(waypoint.PointIndex)..' | #self.waypointsByPathIndex['..waypoint.PathIndex..']: '..tostring(#self.waypointsByPathIndex[waypoint.PathIndex])..' | '.. tostring(diff))
		end
	end
	self.waypointsByID[waypoint.ID] = waypoint

	return waypoint
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

function NodeCollection:Remove(waypoint)

	-- batch operation on selections
	if (waypoint == nil) then
		local selection = self:GetSelected()
		for _,selectedWaypoint in pairs(selection) do
			self:Remove(selectedWaypoint)
		end
		return true, 'Success'
	end

	if Debug.Shared.NODECOLLECTION then
		print('Removing: '..tostring(waypoint.ID))
	end
	
	-- update connections, no more middle-man
	if (waypoint.Previous) then
		waypoint.Previous.Next = waypoint.Next
	end
	if (waypoint.Next) then
		waypoint.Next.Previous = waypoint.Previous
	end

	-- use connections to update indexes
	self:Unlink(waypoint)
	if (waypoint.Previous) then
		self:RecalculateIndexes(waypoint.Previous)
	elseif (waypoint.Next) then
		self:RecalculateIndexes(waypoint.Next)
	end 

	-- cut ties with old friends
	waypoint.Next = false
	waypoint.Previous = false

	-- delete facebook
	self.waypoints[waypoint.Index] = waypoint
	self.waypointsByID[waypoint.ID] = waypoint
	self.waypointsByPathIndex[waypoint.PathIndex][waypoint.PointIndex] = waypoint
	self.selectedWaypoints[waypoint.ID] = nil
	return true, 'Success'
	-- go hit the gym
end

function NodeCollection:InsertAfter(referrenceWaypoint, waypoint)
	
	if (type(waypoint.Next) == 'string') then
		waypoint.Next = self.waypointsByID[waypoint.Next]
	end
	if (type(waypoint.Previous) == 'string') then
		waypoint.Previous = self.waypointsByID[waypoint.Previous]
	end

	waypoint.Next = referrenceWaypoint.Next
	waypoint.Previous = referrenceWaypoint
	referrenceWaypoint.Next = waypoint
	if (waypoint.Next) then
		waypoint.Next.Previous = waypoint
	end

	-- use connections to update indexes
	self:RecalculateIndexes(referrenceWaypoint)
end

function NodeCollection:InsertBefore(referrenceWaypoint, waypoint)

	if (type(waypoint.Next) == 'string') then
		waypoint.Next = self.waypointsByID[waypoint.Next]
	end
	if (type(waypoint.Previous) == 'string') then
		waypoint.Previous = self.waypointsByID[waypoint.Previous]
	end

	waypoint.Previous = referrenceWaypoint.Previous
	waypoint.Next = referrenceWaypoint
	referrenceWaypoint.Previous = waypoint
	if (waypoint.Previous) then
		waypoint.Previous.Next = waypoint
	end

	-- use connections to update indexes
	self:RecalculateIndexes(waypoint.Previous or waypoint)
end

function NodeCollection:RecalculateIndexes(waypoint)
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:RecalculateIndexes Starting...')
	end
	
	local counter = 0

	if (waypoint == nil) then
		for i=1, #self.waypoints do
			self.waypoints[i] = self:_processWaypointRecalc(self.waypoints[i])
			counter = counter + 1
		end
	else

		local direction = "Next"
		if (not waypoint.Next) then
			direction = "Previous"
		end

		while waypoint do
			self.waypoints[waypoint.Index] = self:_processWaypointRecalc(waypoint)
			waypoint = waypoint[direction]
			counter = counter + 1
		end
	end
	
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:RecalculateIndexes Finished! ['..tostring(counter)..']')
	end
end

function NodeCollection:_processWaypointRecalc(waypoint)
	local lastIndex = 0
	local lastPathIndex = 0
	local lastPointIndex = 0
	local currentPathIndex = -1

	-- convert neighbor referrences
	if (type(waypoint.Next) == 'string') then
		waypoint.Next = self.waypointsByID[waypoint.Next]
		if (waypoint.Next) then
			waypoint.Next.Previous = waypoint
		end
	end
	
	if (type(waypoint.Previous) == 'string') then
		waypoint.Previous = self.waypointsByID[waypoint.Previous]
		if (waypoint.Previous) then
			waypoint.Previous.Next = waypoint
		end
	end

	if (waypoint.Previous) then
		lastIndex = waypoint.Previous.Index
		lastPathIndex = waypoint.Previous.PathIndex
		lastPointIndex = waypoint.Previous.PointIndex
	end
		
	--reset lastPointIndex on new path
	if (waypoint.PathIndex ~= lastPathIndex) then
		lastPathIndex = waypoint.PathIndex
		lastPointIndex = 0
	end

	if (waypoint.PointIndex ~= lastPointIndex + 1) then
		lastPointIndex = lastPointIndex + 1
		waypoint.PointIndex = lastPointIndex
		waypoint.Updated = true
	end

	return waypoint
end

function NodeCollection:ProcessMetadata(waypoint)
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:ProcessMetadata Starting...')
	end
	
	local counter = 0

	if (waypoint == nil) then
		for i=1, #self.waypoints do
			self.waypoints[i] = self:_processWaypointMetadata(self.waypoints[i])
			counter = counter + 1
		end
	else
		self.waypoints[waypoint.Index] = self:_processWaypointMetadata(waypoint)
		counter = counter + 1
	end
	
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:ProcessMetadata Finished! ['..tostring(counter)..']')
	end
end

function NodeCollection:_processWaypointMetadata(waypoint)
	-- safety checks
	if (waypoint.Data == nil) then
		waypoint.Data = {}
	end

	if (type(waypoint.Data) == 'string') then
		waypoint.Data = json.decode(waypoint.Data)
	end
	-- -----

	-- Check if indirect connections, create if missing
	-- waypoint.Data.LinkMode = 1
	-- waypoint.Data.Links = { 
		-- <waypoint_ID>, 
		-- <waypoint_ID>, 
		-- ...
	--}

	-- if the node has a linkmode and no links then try to find them
	if (waypoint.Data.LinkMode ~= nil and (waypoint.Data.Links == nil or (type(waypoint.Data.Links) == 'table' and #waypoint.Data.Links < 1))) then

		-- indirect connections
		if (waypoint.Data.LinkMode == 1) then

			local range = waypoint.Data.Range or 3 -- meters, box-like area
			local chance = waypoint.Data.Chance or 25 -- 1 - 100
			local nearbyNodes = self:FindAll(waypoint.Position, range)

			waypoint.Data.Links = {}
			for i=1, nearbyNodes do
				table.insert(waypoint.Data.Links, nearbyNodes[i].ID)
			end
		end 
	end

	-- if the Links table has entries, but they need converting
	if (waypoint.Data.Links ~= nil) then
		for i=1, #waypoint.Data.Links do
			local linkedData = waypoint.Data.Links[i]
			if type(linkedData) == 'table' then
				local linkedWaypoint = self:Get(linkedData[2], linkedData[1])
				if (linkedWaypoint ~= nil) then
					waypoint.Data.Links[i] = linkedWaypoint.ID
				end
			end
		end
	end

	return waypoint
end

function NodeCollection:Update(waypoint, data)
	g_Utilities:mergeKeys(waypoint, data)
end

function NodeCollection:UpdateMetadata(data)
	if Debug.Shared.NODECOLLECTION then
		print('[A] NodeCollection:UpdateMetadata -> data: '..g_Utilities:dump(data, true))
	end
	
	local selection = self:GetSelected()
	if (#selection < 1) then
		return false, 'Must select one or more waypoints'
	end

	local errorMsg = ''
	if (type(data) == 'string') then
		data, errorMsg = json.decode(data) or {}
	end
	
	if Debug.Shared.NODECOLLECTION then
		print('[B] NodeCollection:UpdateMetadata -> data: '..g_Utilities:dump(data, true))
	end
	
	for i=1, #selection do
		self:Update(selection[i], {
			Data = g_Utilities:mergeKeys(selection[i].Data, data)
		})
	end
	return true, 'Success'
end

function NodeCollection:SetInput(speed, extra, option)

	speed = tonumber(speed) or 3
	extra = tonumber(extra) or 0
	option = tonumber(option) or 0
	local inputVar = (speed & 0xF) + ((extra & 0xF)<<4) + ((option & 0xFF) <<8)

	local selection = self:GetSelected()
	for i=1, #selection do
		self:Update(selection[i], {
			InputVar = inputVar,
			SpeedMode = speed,
			ExtraMode = extra,
			OptValue = option
		})
	end
	return inputVar
end

-- Created a linked connection between two or more arbitrary waypoints
-- waypoints | Waypoint or {Waypoint} | Can be a single waypoint or a table of waypoints, `nil` defaults to current selection
-- linkID | string | a waypoint ID, must not be `nil`
-- oneWay | boolean | if true, the connection is only made on this node, prevents infinite recursion
function NodeCollection:Link(waypoints, linkID, oneWay)

	local selection = waypoints or g_NodeCollection:GetSelected()
	oneWay = oneWay or false

	if (#selection == 2) then
		--special case, nodes link to each other
		self:Link(selection[1], selection[2].ID, true)
		self:Link(selection[2], selection[1].ID, true)
		return true, 'Success'

	elseif (#selection > 0) then
		for i=1, #selection do
			local success, msg = self:Link(selection[i], linkID)
			if (not success) then
				return success, msg
			end
		end
		return true, 'Success'
	end

	if (linkID == nil) then
		return false, 'Must specify link id'
	end

	local links = selection.Data.Links or {}
	table.insert(links, linkID)
	self:Update(selection.Data, {
		LinkMode = (selection.Data.LinkMode or 0),
		Links = links
	})

	if (not oneWay) then
		self:Link(self:Get(linkID), selection.ID, true)
	end

	return true, 'Success'
end

-- Removes a linked connection between two or more arbitrary waypoints
-- waypoints | Waypoint or {Waypoint} | Can be a single waypoint or a table of waypoints, `nil` defaults to current selection
-- linkID | string | a waypoint ID to remove, can be `nil` to clear connections
-- oneWay | boolean | if true, the connection is only made on this node, prevents infinite recursion
function NodeCollection:Unlink(waypoints, linkID, oneWay)

	local selection = waypoints or g_NodeCollection:GetSelected()
	oneWay = oneWay or false

	if (#selection == 2) then
		--special case, nodes unlink from each other
		self:Unlink(selection[1], selection[2].ID, true)
		self:Unlink(selection[2], selection[1].ID, true)
		return true, 'Success'

	elseif (#selection > 0) then
		for i=1, #selection do
			local success, msg = self:Unlink(selection[i], linkID)
			if (not success) then
				return success, msg
			end
		end
		return true, 'Success'
	end

	local newLinks = {}

	-- generate new links table, otherwise it gets emptied
	if (linkID ~= nil and selection.Data.Links ~= nil) then
		for i=1, #selection.Data.Links do
			if (selection.Data.Links[i] ~= linkID) then
				-- skip matching connections
				table.insert(newLinks, selection.Data.Links[i])
			else
				-- remove link from connected node, `oneWay` prevents infinite recursion
				if (not oneWay) then
					self:Unlink(self:Get(linkID), selection.ID, true)
				end
			end
		end
	end

	-- update waypoint's Data table, remove linking info if necessary
	if Debug.Shared.NODECOLLECTION then
		print('newLinks -> '..g_Utilities:dump(newLinks, true))
	end
	
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

function NodeCollection:Get(waypoint, pathIndex)
	if (waypoint ~= nil) then
		if (pathIndex ~= nil) then
			
			if (self.waypointsByPathIndex[pathIndex] == nil) then
				self.waypointsByPathIndex[pathIndex] = {}
			end

			if (type(waypoint) == 'number') then
				return self.waypointsByPathIndex[pathIndex][waypoint]
			elseif (type(waypoint) == 'string') then
				for i=1, #self.waypointsByPathIndex[pathIndex] do
					local targetWaypoint = self.waypointsByPathIndex[pathIndex][i]
					if (targetWaypoint.PathIndex == pathIndex and targetWaypoint.ID == waypoint) then
						return targetWaypoint
					end
				end
			elseif (type(waypoint) == 'table') then
				for i=1, #self.waypointsByPathIndex[pathIndex] do
					local targetWaypoint = self.waypointsByPathIndex[pathIndex][i]
					if (targetWaypoint.PathIndex == pathIndex and targetWaypoint.ID == waypoint.ID) then
						return targetWaypoint
					end
				end
			end
		else
			if (type(waypoint) == 'string') then
				return self.waypointsByID[waypoint]
			elseif (type(waypoint) == 'table') then
				return self.waypointsByID[waypoint.ID]
			else
				for i=1, #self.waypoints do
					if (self.waypoints[i].Index == waypoint) then
						return self.waypoints[i]
					end
				end
			end
		end
		return nil
	elseif (pathIndex ~= nil) then
		if (self.waypointsByPathIndex[pathIndex] == nil) then
			self.waypointsByPathIndex[pathIndex] = {}
		end
		return self.waypointsByPathIndex[pathIndex]
	end
	return self.waypoints
end

function NodeCollection:GetFirst(pathIndex)

	local firstWaypoint = self.waypoints[1]

	if (pathIndex ~= nil) then

		if (self.waypointsByPathIndex[pathIndex] == nil) then
			return false
		end

		firstWaypoint = self.waypointsByPathIndex[pathIndex][1]
	end

	if (firstWaypoint == nil) then
		return false
	end

	while firstWaypoint.Previous and ((pathIndex ~= nil and firstWaypoint.Previous.PathIndex == firstWaypoint.PathIndex) or pathIndex == nil) do
		firstWaypoint = firstWaypoint.Previous
	end
	return firstWaypoint
end

function NodeCollection:GetLast(pathIndex)

	local lastWaypoint = self.waypoints[#self.waypoints]

	if (pathIndex ~= nil) then

		if (self.waypointsByPathIndex[pathIndex] == nil) then
			return false
		end
		
		lastWaypoint = self.waypointsByPathIndex[pathIndex][#self.waypointsByPathIndex[pathIndex]]
	end

	if (lastWaypoint == nil) then
		return false
	end
	
	while lastWaypoint.Next and ((pathIndex ~= nil and lastWaypoint.Next.PathIndex == lastWaypoint.PathIndex) or pathIndex == nil) do
		lastWaypoint = lastWaypoint.Next
	end
	return lastWaypoint
end

function NodeCollection:GetPaths()
	return self.waypointsByPathIndex
end

function NodeCollection:Clear()
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:Clear')
	end
	
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

function NodeCollection:Select(waypoint, pathIndex)
	if (waypoint == nil) then return end

	waypoint = self:Get(waypoint, pathIndex)
	if (waypoint == nil) then return end
	self.selectedWaypoints[waypoint.ID] = waypoint
end

function NodeCollection:Deselect(waypoint, pathIndex)
	if (waypoint == nil) then
		self:ClearSelection()
	else

		waypoint = self:Get(waypoint, pathIndex)
		if (waypoint == nil) then return end
		self.selectedWaypoints[waypoint.ID] = nil
	end
end

function NodeCollection:IsSelected(waypoint, pathIndex)
	if (waypoint == nil) then return false end

	waypoint = self:Get(waypoint, pathIndex)
	if (waypoint == nil) then return false end
	return self.selectedWaypoints[waypoint.ID] ~= nil
end

function NodeCollection:GetSelected(pathIndex)
	local selection = {}
	-- copy selection into index-based array and sort results
	for waypointID,waypoint in pairs(self.selectedWaypoints) do
		if (self:IsSelected(waypoint) and (pathIndex == nil or waypoint.PathIndex == pathIndex)) then
			table.insert(selection, waypoint)
		end
	end

	if (pathIndex == nil) then
		self:_sort(selection, 'Index')
	else
		self:_sort(selection, 'PointIndex')
	end
	return selection
end

function NodeCollection:ClearSelection()
	self.selectedWaypoints = {}
end

function NodeCollection:_sort(collection, keyName, descending)

	keyName = keyName or 'Index'

	table.sort(collection, function(a,b)
		if (a == nil) then
			return false
		end
		if (b == nil) then
			return true
		end
		if (descending) then
			return a[keyName] > b[keyName]
		else
			return a[keyName] < b[keyName]
		end
	end)
	return collection
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

function NodeCollection:ShowPath(pathIndex)
	self.hiddenPaths[pathIndex] = false
end

function NodeCollection:HidePath(pathIndex)
	self.hiddenPaths[pathIndex] = true
end

function NodeCollection:IsPathVisible(pathIndex)
	return self.hiddenPaths[pathIndex] == nil or self.hiddenPaths[pathIndex] == false
end

function NodeCollection:GetHiddenPaths()
	return self.hiddenPaths
end

-----------------------------
-- Save/Load

function NodeCollection:Load(levelName, gameMode)

	self.levelName = levelName or self.levelName
	self.gameMode = gameMode or self.gameMode

	if g_Globals.isTdm or g_Globals.isGm or g_Globals.isScavenger then
		self.gameMode = 'TeamDeathMatch0'; -- paths are compatible
	end
	self.mapName = self.levelName .. '_' .. self.gameMode
	if self.mapName == "MP_Subway_ConquestSmall0" then
		self.mapName = "MP_Subway_ConquestLarge0"; --paths are the same
	end
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:Load: '..self.mapName)
	end
	
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
		if Debug.Shared.DATABASE then
			print('Failed to create table for map ['..self.mapName..']: '..SQL:Error())
		end
		
		return
	end


	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM '..self.mapName..'_table ORDER BY `pathIndex`, `pointIndex` ASC')

	if not results then
		if Debug.Shared.DATABASE then
			print('Failed to retrieve waypoints for map ['..self.mapName..']: '..SQL:Error())
		end
		
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
	--if (g_Globals ~= nil) then
		--g_Globals.wayPoints = self.waypointsByPathIndex
		--g_Globals.activeTraceIndexes = pathCount
	--end

	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:Load -> Paths: '..tostring(pathCount)..' | Waypoints: '..tostring(waypointCount))
	end
	
	ChatManager:Yell(Language:I18N('Loaded %d paths with %d waypoints for map %s', pathCount, waypointCount, self.mapName), 5.5);
end

function NodeCollection:Save()
	if not SQL:Open() then
		if Debug.Shared.DATABASE then
			print('Could not open database')
		end
		
		return
	end

	if not SQL:Query('DROP TABLE IF EXISTS '..self.mapName..'_table') then
		if Debug.Shared.DATABASE then
			print('Failed to reset table for map ['..self.mapName..']: '..SQL:Error());
		end
		
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
		if Debug.Shared.DATABASE then
			print('Failed to create table for map ['..self.mapName..']: '..SQL:Error())
		end
		
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

	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:Save -> Processing: '..(waypointCount))
	end
	
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
					if Debug.Shared.NODECOLLECTION then
						print('WARNING! Waypoint ['..waypoint.ID..'] data could not encode: '..tostring(encodeError))
						print('waypoint -> '..g_Utilities:dump(waypoint, true, 1))
						print('waypointData -> '..g_Utilities:dump(waypointData, true))
					end
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

	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:Save -> Waypoints to write: '..(#batchQueries))
		print('NodeCollection:Save -> Orphans: '..(#orphans)..' (Removed)')
		print('NodeCollection:Save -> Disconnected: '..(#disconnects)..' (Expected: 2)')
	end
	
	if (#disconnects > 2) then
		if Debug.Shared.NODECOLLECTION then
			print('WARNING! More than two disconnected nodes were found!')
			print(g_Utilities:dump(disconnects, true, 2))
		end
	end

	local queriesDone = 0;
	local queriesTotal = #batchQueries
	local batchSize = 1000;
	local hasError = false;
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
			if Debug.Shared.DATABASE then
				print('NodeCollection:Save -> Batch query failed ['..queriesDone..']: ' .. SQL:Error())
			end
			
			return
		end

		queriesDone = queriesDone + queriesLeft
	end

	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM '..self.mapName..'_table')

	if not results then
		if Debug.Shared.DATABASE then
			print('NodeCollection:Save -> Failed to double-check table entries for map ['..self.mapName..']: '..SQL:Error());
		end
		
		ChatManager:Yell(Language:I18N('Failed to execute query: %s', SQL:Error()), 5.5)
		return
	end

	SQL:Close();
	
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection:Save -> Saved ['..queriesTotal..'] waypoints for map ['..self.mapName..']');
	end
	
	ChatManager:Yell(Language:I18N('Saved %d paths with %d waypoints for map %s', pathCount, queriesTotal, self.mapName), 5.5);
end

-----------------------------
-- Navigation

function NodeCollection:Previous(waypoint)
	if (type(waypoint.Previous) == 'string') then
		return self.waypointsByID[waypoint.Previous]
	end
	return waypoint.Previous
end

function NodeCollection:Next(waypoint)
	if (type(waypoint.Next) == 'string') then
		return self.waypointsByID[waypoint.Next]
	end

	return waypoint.Next
end

-- discover in which direction an objective is from a given waypoint
-- returns <Direction>, <BestWaypoint>
-- <Direction> will be either 'Next' or 'Previous'
function NodeCollection:ObjectiveDirection(waypoint, objective)

	local bestDirection = nil
	local bestWaypoint = nil

	local direction = 'Next'
	local currentWaypoint = waypoint

	while currentWaypoint and currentWaypoint[direction] do

		if (currentWaypoint[direction].PathIndex > waypoint.PathIndex) then
			-- hit the last node in the path, reset start and reverse direction
			currentWaypoint = waypoint
			direction = 'Previous'

		elseif (currentWaypoint[direction].PathIndex < waypoint.PathIndex) then
			-- hit the first node in the path, finish searching
			break
		else
			if (currentWaypoint[direction].Data.Links ~= nil) then
				for _,linkID in pairs(currentWaypoint[direction].Data.Links) do

					local link = self:Get(linkID)
					local pathWaypoint = self:GetFirst(link.PathIndex)

					if (pathWaypoint ~= nil and pathWaypoint.Data.Objectives ~= nil and table.has(pathWaypoint.Data.Objectives, objective)) then

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
function NodeCollection:InRange(waypoint, vec3Position, range)
	local posA = waypoint.Position or Vec3.zero
	local posB = vec3Position or Vec3.zero
	return ( math.abs(posA.x - posB.x) <= range and
		math.abs(posA.y - posB.y) <= range and
		math.abs(posA.z - posB.z) <= range )
end

-- Find the closest waypoint at position `vec3Position` with a search radius of `tolerance`
function NodeCollection:Find(vec3Position, tolerance)
	if (tolerance == nil) then
		tolerance = 0.2
	end

	local closestWaypoint = nil
	local closestWaypointDist = tolerance

	for _,waypoint in pairs(self.waypointsByID) do

		if (waypoint ~= nil and waypoint.Position ~= nil and self:IsPathVisible(waypoint.PathIndex) and self:IsPathVisible(waypoint.PathIndex)) then
			if (self:InRange(waypoint, vec3Position, tolerance)) then -- faster check

				local distance = waypoint.Position:Distance(vec3Position) -- then do slower math
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

-- Find all waypoints within `tolerance` range of the position `vec3Position`
function NodeCollection:FindAll(vec3Position, tolerance)
	if (tolerance == nil) then
		tolerance = 0.2
	end

	local waypointsFound = {}

	for _,waypoint in pairs(self.waypointsByID) do

		if (waypoint ~= nil and waypoint.Position ~= nil and self:IsPathVisible(waypoint.PathIndex) and self:InRange(waypoint, vec3Position, tolerance)) then
			table.insert(waypointsFound, waypoint)
		end
	end
	return waypointsFound
end

function NodeCollection:FindAlongTrace(vec3Start, vec3End, granularity, tolerance)
	if (granularity == nil) then
		granularity = 0.25
	end
	if (tolerance == nil) then
		tolerance = 0.2
	end
	
	self:Print('NodeCollection:FindAlongTrace - granularity: '..tostring(granularity))
	self:Print('NodeCollection:FindAlongTrace - tolerance: '..tostring(tolerance))
	
	local distance = math.min(math.max(vec3Start:Distance(vec3End), 0.05), 10)

	-- instead of searching a possible 3k or more nodes, we grab only those that would be in range
	-- shift the search area forward by 1/2 distance and also 1/2 the radius needed
	local searchAreaPos = vec3Start + ((vec3End - vec3Start) * 0.4) -- not exactly half ahead
	local searchAreaSize = (distance*0.6) -- lil bit bigger than half for searching
	NetEvents:Send('ClientNodeEditor:SetLastTraceSearchArea', {searchAreaPos:Clone(), searchAreaSize})
	if (g_ClientNodeEditor) then
		g_ClientNodeEditor:_onSetLastTraceSearchArea({searchAreaPos:Clone(), searchAreaSize})
	end

	local searchWaypoints = self:FindAll(searchAreaPos, searchAreaSize)
	local testPos = vec3Start:Clone()

	self:Print('distance: '..tostring(distance))
	self:Print('searchWaypoints: '..tostring(#searchWaypoints))

	if (#searchWaypoints == 1) then
		return searchWaypoints[1]
	end

	local heading = vec3End - vec3Start
	local direction = heading / heading.magnitude
	
	while #searchWaypoints > 0 and distance > granularity and distance > 0 do
		for _,waypoint in pairs(searchWaypoints) do
			if (waypoint ~= nil and self:IsPathVisible(waypoint.PathIndex) and waypoint.Position ~= nil and waypoint.Position:Distance(testPos) <= tolerance) then
				self:Print('NodeCollection:FindAlongTrace -> Found: '..waypoint.ID)
				return waypoint
			end
		end
		testPos = testPos + (direction * granularity)
		distance = testPos:Distance(vec3End)
	end
	return nil
end

function NodeCollection:Print(...)
	if Debug.Shared.NODECOLLECTION then
		print('NodeCollection: ' .. Language:I18N(...))
	end
end

if (g_NodeCollection == nil) then
	g_NodeCollection = NodeCollection()
end

return g_NodeCollection