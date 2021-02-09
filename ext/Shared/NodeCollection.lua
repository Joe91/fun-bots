class "NodeCollection"

require('__shared/Utilities.lua')

function NodeCollection:__init()
	self:InitTables()
	NetEvents:Subscribe('NodeEditor:Clear', self, self.Clear)
	NetEvents:Subscribe('NodeEditor:Create', self, self.Create)
end

function NodeCollection:InitTables()
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByPathIndex = {}

	self.selectedWaypoints = {}
	self.hiddenPaths = {}

	self.debugcount = 0
	self.debugcount2 = 0
end

function NodeCollection:RegisterEvents()
	-- Management
	NetEvents:Subscribe('NodeEditor:Register', self, self.Register)
	NetEvents:Subscribe('NodeEditor:Remove', self, self.Remove)
	NetEvents:Subscribe('NodeEditor:InsertAfter', self, self.InsertAfter)
	NetEvents:Subscribe('NodeEditor:InsertBefore', self, self.InsertBefore)
	NetEvents:Subscribe('NodeEditor:Update', self, self.Update)
	NetEvents:Subscribe('NodeEditor:SetInput', self, self.SetInput)
	NetEvents:Subscribe('NodeEditor:Merge', self, self.MergeSelected)
	NetEvents:Subscribe('NodeEditor:Split', self, self.SplitSelected)

	-- Selection
	NetEvents:Subscribe('NodeEditor:Select', self, self.Select)
	NetEvents:Subscribe('NodeEditor:SelectByID', self, self.SelectByID)
	NetEvents:Subscribe('NodeEditor:Deselect', self, self.Deselect)
	NetEvents:Subscribe('NodeEditor:DeselectByID', self, self.DeselectByID)
	NetEvents:Subscribe('NodeEditor:ClearSelection', self, self.ClearSelection)

	-- Paths
	NetEvents:Subscribe('NodeEditor:ShowPath', self, self.ShowPath)
	NetEvents:Subscribe('NodeEditor:HidePath', self, self.HidePath)

	-- Save/Load
	NetEvents:Subscribe('NodeEditor:Save', self, self.Save)
	NetEvents:Subscribe('NodeEditor:Load', self, self.Load)
end

function NodeCollection:DeregisterEvents()
		-- Management
	NetEvents:Unsubscribe('NodeEditor:Register')
	NetEvents:Unsubscribe('NodeEditor:Remove')
	NetEvents:Unsubscribe('NodeEditor:InsertAfter')
	NetEvents:Unsubscribe('NodeEditor:InsertBefore')
	NetEvents:Unsubscribe('NodeEditor:Update')
	NetEvents:Unsubscribe('NodeEditor:SetInput')
	NetEvents:Unsubscribe('NodeEditor:Merge')
	NetEvents:Unsubscribe('NodeEditor:Split')

	-- Selection
	NetEvents:Unsubscribe('NodeEditor:Select')
	NetEvents:Unsubscribe('NodeEditor:SelectByID')
	NetEvents:Unsubscribe('NodeEditor:Deselect')
	NetEvents:Unsubscribe('NodeEditor:DeselectByID')
	NetEvents:Unsubscribe('NodeEditor:ClearSelection')

	-- Paths
	NetEvents:Unsubscribe('NodeEditor:ShowPath')
	NetEvents:Unsubscribe('NodeEditor:HidePath')

	-- Save/Load
	NetEvents:Unsubscribe('NodeEditor:Save')
	NetEvents:Unsubscribe('NodeEditor:Load')
end

-----------------------------
-- Management

function NodeCollection:Create(data)
	local newIndex = #self.waypoints+1
	local inputVar = 20

	-- setup defaults for a blank node
	local waypoint = {
		ID = string.format('p_%d', newIndex), -- new generated id for internal storage
		OriginalID = nil,					-- original id from database
		Index = newIndex, 					-- new generated id in numerical form
		Position = Vec3(0,0,0),
		PathIndex = 1, 						-- Path #
		PointIndex = 1, 					-- index inside parent path
		InputVar = inputVar, 				-- raw input value
		SpeedMode = inputVar & 0xF,
		ExtraMode = (inputVar >> 4) & 0xF,
		OptValue = (inputVar >> 8) & 0xFF,
		Distance = nil,						-- current distance to player
		Updated = false,					-- if true, needs to be sent to server for saving
		Previous = nil,						-- tree navigation
		Next = nil
	}

	for k,v in pairs(data) do
		if (v ~= nil) then
			waypoint[k] = v
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
	if (waypoint.Previous ~= nil and waypoint.Next ~= nil and false) then -- disabled for now

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
		print('Warning, New Node index does not match: waypoint.Index:'..tostring(waypoint.Index)..' ('..type(waypoint.Index)..') | #self.waypoints:'..tostring(#self.waypoints)..' ('..type(waypoint.Index)..') | '.. tostring(diff))
	end

	table.insert(self.waypointsByPathIndex[waypoint.PathIndex], self.waypoints[#self.waypoints])
	self.waypointsByID[waypoint.ID] = self.waypoints[#self.waypoints]

	return waypoint
end

function NodeCollection:Remove(waypoint)

	-- batch operation on selections
	if (waypoint == nil) then
		local selection = self:GetSelected()
		for _,selectedWaypoint in pairs(selection) do
			self:Remove(selectedWaypoint)
		end
		return
	end

	print('Removing: '..tostring(waypoint.ID))

	-- update connections, no more middle-man
	waypoint.Previous.Next = waypoint.Next
	waypoint.Next.Previous = waypoint.Previous

	-- use connections to update indexes
	self:RecalculateIndexes(waypoint.Previous)

	-- cut ties with old friends
	waypoint.Next = nil
	waypoint.Previous = nil

	-- delete facebook
	self.waypoints[waypoint.Index] = waypoint
	self.waypointsByID[waypoint.ID] = waypoint
	self.waypointsByPathIndex[waypoint.PathIndex][waypoint.PointIndex] = waypoint
	self.selectedWaypoints[waypoint.ID] = nil
	-- go hit the gym
end

function NodeCollection:InsertAfter(referrenceWaypoint, waypoint)

	if (type(waypoint.Next) == 'string') then
		waypoint.Next = self.waypointsByID[waypoint.Next]
		if (waypoint.Next ~= nil) then
			waypoint.Next.Previous = waypoint
		end
	end
	if (type(waypoint.Previous) == 'string') then
		waypoint.Previous = self.waypointsByID[waypoint.Previous]
		if (waypoint.Previous ~= nil) then
			waypoint.Previous.Next = waypoint
		end
	end

	-- update connections
	waypoint.Previous = referrenceWaypoint
	waypoint.Next = referrenceWaypoint.Next
	referrenceWaypoint.Next = waypoint

	if (waypoint.Next ~= nil) then
		waypoint.Next.Previous = waypoint
	end

	-- add to lookup tables
	self:Register(waypoint)

	-- use connections to update indexes
	self:RecalculateIndexes(referrenceWaypoint)
end

function NodeCollection:InsertBefore(referrenceWaypoint, waypoint)

	if (type(waypoint.Next) == 'string') then
		waypoint.Next = self.waypointsByID[waypoint.Next]
		if (waypoint.Next ~= nil) then
			waypoint.Next.Previous = waypoint
		end
	end
	if (type(waypoint.Previous) == 'string') then
		waypoint.Previous = self.waypointsByID[waypoint.Previous]
		if (waypoint.Previous ~= nil) then
			waypoint.Previous.Next = waypoint
		end
	end

	-- update connections
	waypoint.Previous = referrenceWaypoint.Previous
	waypoint.Next = referrenceWaypoint
	referrenceWaypoint.Previous = waypoint

	if (waypoint.Previous ~= nil) then
		waypoint.Previous.Next = waypoint
	end

	-- add to lookup tables
	self:Register(waypoint)

	-- use connections to update indexes
	self:RecalculateIndexes(waypoint)
end

function NodeCollection:RecalculateIndexes(waypoint)
	print('NodeCollection:RecalculateIndexes Starting...')
	local counter = 0

	if (waypoint == nil) then
		for i=1, #self.waypoints do
			self.waypoints[i] = self:_processWaypointRecalc(self.waypoints[i])
			counter = counter + 1
		end
	else
		while waypoint do
			self.waypoints[waypoint.Index] = self:_processWaypointRecalc(waypoint)
			waypoint = waypoint.Next
			counter = counter + 1
		end
	end
	print('NodeCollection:RecalculateIndexes Finished! ['..tostring(counter)..']')
end

function NodeCollection:_processWaypointRecalc(waypoint)
	
	local lastIndex = 0
	local lastPathIndex = 0
	local lastPointIndex = 0
	local currentPathIndex = -1

	-- convert neighbor referrences
	if (type(waypoint.Next) == 'string') then
		waypoint.Next = self.waypointsByID[waypoint.Next]
		if (waypoint.Next ~= nil) then
			waypoint.Next.Previous = waypoint
		end
	end
	if (type(waypoint.Previous) == 'string') then
		waypoint.Previous = self.waypointsByID[waypoint.Previous]
		if (waypoint.Previous ~= nil) then
			waypoint.Previous.Next = waypoint
		end
	end

	if (waypoint.Previous ~= nil) then
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

function NodeCollection:Update(waypoint, data)
	g_Utilities:mergeKeys(waypoint, data)
	waypoint.Updated = true
	self.waypoints[waypoint.Index] = waypoint
end

function NodeCollection:SetInput(inputVar)
	local selection = self:GetSelected()
	for _,selectedWaypoint in pairs(selection) do
		self:Update(selectedWaypoint, {InputVar = (tonumber(inputVar) or 20)})
	end
end

function NodeCollection:Get(waypointID, pathIndex)
	if (waypointID ~= nil) then
		local searchTable = self.waypoints
		if (pathIndex ~= nil) then
			local searchTable = self:Get(nil, pathIndex)
			for _, waypoint in pairs(searchTable) do
				if (waypoint.ID == waypointID) then
					return waypoint
				end
			end
		else
			return self.waypointsByID[waypointsByID]
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

function NodeCollection:GetPaths()
	return self.waypointsByPathIndex
end

function NodeCollection:Clear(initSize)
	print('NodeCollection:Clear')
	
	self.waypoints = {}
	self.waypointsByID = {}
	for i=1, #self.waypointsByPathIndex do
		self.waypointsByPathIndex[i] = {}
	end
	self.waypointsByPathIndex = {}
	self.selectedWaypoints = {}

	if (initSize ~= nil) then
		print('NodeCollection:Clear -> Expecting: '..tostring(initSize))
	end
end

-----------------------------
-- Selection

function NodeCollection:Select(waypoint)
	if (waypoint.ID == nil) then return end
	self.selectedWaypoints[waypoint.ID] = waypoint
end

function NodeCollection:SelectByID(waypointID, pathIndex)
	self:Select(self:Get(waypointID, pathIndex))
end

function NodeCollection:Deselect(waypoint)
	if (waypoint == nil) then
		self:ClearSelection()
	else
		if (waypoint.ID == nil) then return end
		self.selectedWaypoints[waypoint.ID] = nil
	end
end

function NodeCollection:DeselectByID(waypointID, pathIndex)
	self:Deselect(self:Get(waypointID, pathIndex))
end

function NodeCollection:IsSelected(waypoint)
	if (waypoint.ID == nil) then return false end
	return self.selectedWaypoints[waypoint.ID] ~= nil
end

function NodeCollection:IsSelectedByID(waypointID, pathIndex)
	return self:IsSelected(self:Get(waypointID, pathIndex))
end

function NodeCollection:GetSelected(pathIndex)
	local selection = {}
	-- copy selection into index-based array and sort results
	for waypointID,waypoint in pairs(self.selectedWaypoints) do
		if (self:IsSelected(waypoint) and (pathIndex == nil or waypoint.PathIndex == pathIndex)) then
			table.insert(selection, waypoint)
		end
	end

	self:_sort(selection, 'PointIndex')
	return selection
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
	print('currentWaypoint.Next: '..tostring(currentWaypoint.Next))
	print('currentWaypoint.Previous: '..tostring(currentWaypoint.Previous))
	print('NodeCollection:Merge -> selection[1]: '..tostring(selection[1].Index))
	print('NodeCollection:Merge -> selection[1].Next: '..tostring(selection[1].Next.Index))
	for i=2, #selection do
		print('NodeCollection:Merge -> selection['..tostring(i)..']: '..tostring(selection[i].Index))

		if (currentWaypoint.PathIndex ~= selection[i].PathIndex) then
			return false, 'Waypoints must be on same path'
		end

		if (currentWaypoint.Next.Index ~= selection[i].Index) then
			print('currentWaypoint.Next.Index: '..tostring(currentWaypoint.Next.Index))
			print('selection['..tostring(i)..'].Index: '..tostring(selection[i].Index))
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
	if (#selection ~= 2) then
		return false, 'Must select only two waypoints'
	end

	if (selection[1].PathIndex ~= selection[2].PathIndex) then
		return false, 'Waypoints must be on same path'
	end

	if (selection[1].Next.Index ~= selection[2].Index) then
		print('selection[1].Next.Index: '..tostring(selection[1].Next.Index))
		print('selection[2].Index: '..tostring(selection[2].Index))
		return false, 'Waypoints must be sequential'
	end

	local middlePosition = (selection[1].Position + selection[2].Position) / 2
	local newWaypoint = self:Create(middlePosition, selection[1].PathIndex)
	self:InsertAfter(selection[1], newWaypoint)
	return true, 'Success'
end

function NodeCollection:_sort(collection, keyName, descending)

	if (keyName == nil) then
		keyName = 'Index'
	end

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

function NodeCollection:ClearSelection()
	self.selectedWaypoints = {}
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

function NodeCollection:Load(mapName)
	if not SQL:Open() then
		return
	end

	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM ' .. mapName .. '_table ORDER BY `pathIndex`, `pointIndex` ASC')

	if not results then
		print('Failed to execute query: ' .. SQL:Error())
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
			OptValue = (row["inputVar"] >> 8) & 0xFF
		}

		waypoint = self:Create(waypoint)

		if (firstWaypoint == nil) then
			firstWaypoint = waypoint
		end
		if (lastWaypoint ~= nil) then
			waypoint.Previous = lastWaypoint.ID
			lastWaypoint.Next = waypoint.ID
		end

		lastWaypoint = waypoint
		waypointCount = waypointCount+1
	end
	SQL:Close()
	self:RecalculateIndexes(firstWaypoint)

	print('NodeCollection:Load -> Paths: '..tostring(pathCount)..' | Waypoints: '..tostring(waypointCount))
end

function NodeCollection:Save(mapName)

	if not SQL:Open() then
		return
	end

	local changedWaypoints = {}
	local waypointCount = 0

	for _,waypoint in pairs(self.waypoints) do
		if (waypoint.Updated) then
			local rowData = {
				id = waypoint.Index,
				pathIndex = waypoint.PathIndex,
				pointIndex = waypoint.PointIndex,
				transX = waypoint.Position.x,
				transY = waypoint.Position.y,
				transZ = waypoint.Position.z,
				inputVar = waypoint.InputVar,
			}
			table.insert(changedWaypoints, rowData)
		end
		print('NodeCollection:Save -> Changed nodes: '..tostring(#changedWaypoints))
	end

	--> TODO save back to DB <--

end

-----------------------------
-- Navigation

function NodeCollection:Previous(waypoint)
	return waypoint.Previous
end

function NodeCollection:Next(waypoint)
	return waypoint.Next
end

-- Find the closest waypoint at position `vec3Position` with a search radius of `tolerance`
function NodeCollection:Find(vec3Position, tolerance)
	if (tolerance == nil) then
		tolerance = 0.2
	end

	local closestWaypoint = nil
	local closestWaypointDist = tolerance

	for _,waypoint in pairs(self.waypointsByID) do

		if (waypoint ~= nil and waypoint.Position ~= nil and self:IsPathVisible(waypoint.PathIndex)) then
			local distance = waypoint.Position:Distance(vec3Position)
			if (distance <= tolerance) then
				if (closestWaypoint == nil) then
					print('NodeCollection:Find -> Found: '..waypoint.ID.. '('..tostring(distance)..')')
					closestWaypoint = waypoint
					closestWaypointDist = distance
				elseif (distance < closestWaypointDist) then
					print('NodeCollection:Find -> Found Closer: '..waypoint.ID.. '('..tostring(distance)..')')
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

		if (waypoint ~= nil and waypoint.Position ~= nil and self:IsPathVisible(waypoint.PathIndex) and waypoint.Position:Distance(vec3Position) <= tolerance) then
			print('NodeCollection:FindAll -> Found: '..waypoint.ID)
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
	print('NodeCollection:FindAlongTrace - granularity: '..tostring(granularity))

	local distance = math.min(math.max(vec3Start:Distance(vec3End), 0.05), 10)

	-- instead of searching a possible 3k or more nodes, we grab only those that would be in range
	-- shift the search area forward by 1/2 distance and also 1/2 the radius needed
	local searchAreaPos = vec3Start + ((vec3End - vec3Start) * 0.4) -- not exactly half ahead
	local searchAreaSize = (distance*0.6) -- lil bit bigger than half for searching
	NetEvents:Send('NodeEditor:SetLastTraceSearchArea', {searchAreaPos, searchAreaSize})

	local searchWaypoints = self:FindAll(searchAreaPos, searchAreaSize)
	local testPos = vec3Start

	print('distance: '..tostring(distance))
	print('searchWaypoints: '..tostring(#searchWaypoints))

	while distance > granularity and distance > 0 do
		for _,waypoint in pairs(searchWaypoints) do

			if (waypoint ~= nil and self:IsPathVisible(waypoint.PathIndex) and waypoint.Position ~= nil and waypoint.Position:Distance(testPos) <= tolerance) then
				print('NodeCollection:FindAlongTrace -> Found: '..waypoint.ID)
				return waypoint
			end
		end
		testPos = testPos:MoveTowards(vec3End, granularity)
		distance = testPos:Distance(vec3End)
	end
	return nil
end

function NodeCollection:getModuleState()
     if (SharedUtils:IsClientModule() and SharedUtils:IsServerModule()) then
          return 'Shared'
     elseif (SharedUtils:IsClientModule() and not SharedUtils:IsServerModule()) then
          return 'Client'
     elseif (not SharedUtils:IsClientModule() and SharedUtils:IsServerModule()) then
          return 'Server'
     end
     return 'Unkown'
end

if (g_NodeCollection == nil) then
	g_NodeCollection = NodeCollection()
end

return g_NodeCollection