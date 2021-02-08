class "NodeCollection"

require('__shared/Utilities.lua')

function NodeCollection:__init()
	self:InitTables()
	NetEvents:Subscribe('NodeEditor:Clear', self, self.Clear)
	NetEvents:Subscribe('NodeEditor:Add', self, self.Add)
end

function NodeCollection:InitTables()
	self.waypointIDs = 1
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByPathIndex = {}

	self.selectedWaypoints = {}
	self.disabledPaths = {}

	self.debugcount = 1
	self.debugcount2 = 1
end

function NodeCollection:RegisterEvents()
	-- Management
	NetEvents:Subscribe('NodeEditor:Create', self, self.Create)
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
	NetEvents:Subscribe('NodeEditor:EnablePath', self, self.EnablePath)
	NetEvents:Subscribe('NodeEditor:DisablePath', self, self.DisablePath)

	-- Save/Load
	NetEvents:Subscribe('NodeEditor:Save', self, self.Save)
	NetEvents:Subscribe('NodeEditor:Load', self, self.Load)
end

-----------------------------
-- Management

function NodeCollection:Create(vec3Position, pathIndex, pointIndex, inputVar)
	local newIndex = self:_createID()
	inputVar = tonumber(inputVar) or 20

	local waypoint = {
		ID = string.format('p_%d', newIndex), 	-- new generated id for internal storage
		OriginalID = nil,						-- original id from database
		Index = newIndex, 						-- new generated id in numerical form
		Position = vec3Position,
		PathIndex = tonumber(pathIndex) or 10, 	-- Path #
		PointIndex = tonumber(pointIndex) or 0, -- index inside parent path
		InputVar = inputVar, 					-- raw input value
		SpeedMode = inputVar & 0xF,
		ExtraMode = (inputVar >> 4) & 0xF,
		OptValue = (inputVar >> 8) & 0xFF,
		Distance = nil,							-- current distance to player
		Updated = false,						-- if true, needs to be sent to server for saving
		Previous = nil,							-- tree navigation
		Next = nil
	}
	self:Add(waypoint)
	return waypoint
end

function NodeCollection:Add(waypoint)

	if (self.disabledPaths[waypoint.PathIndex] == nil) then
		self.disabledPaths[waypoint.PathIndex] = false
	end
	if (self.waypointsByPathIndex[waypoint.PathIndex] == nil) then
		self.waypointsByPathIndex[waypoint.PathIndex] = {}
	end
	if (self.waypointIDs < waypoint.Index) then
		self.waypointIDs = waypoint.Index+1
	end

	-- relevant nodes are more likely at the end than the beginning
	for i=#self.waypointsByPathIndex[waypoint.PathIndex], 1, -1 do

		if (waypoint.Previous ~= nil and waypoint.Next ~= nil) then
			break
		end

		local currentWaypoint = self.waypointsByPathIndex[waypoint.PathIndex][i]

		if (currentWaypoint ~= nil) then
			if (currentWaypoint.PointIndex == waypoint.PointIndex-1) then
				waypoint.Previous = currentWaypoint
				currentWaypoint.Next = waypoint
			end
			if (currentWaypoint.PointIndex == waypoint.PointIndex+1) then
				waypoint.Next = currentWaypoint
				currentWaypoint.Previous = waypoint
			end
			--if (currentWaypoint.Next ~= nil and currentWaypoint.Next.Index == waypoint.Index) then
			--	waypoint.Previous = currentWaypoint
			--end
			--if (currentWaypoint.Previous ~= nil and currentWaypoint.Previous.Index == waypoint.Index) then
			--	waypoint.Next = currentWaypoint
			--end
		end
	end

	table.insert(self.waypoints, waypoint)
	table.insert(self.waypointsByPathIndex[waypoint.PathIndex], self.waypoints[#self.waypoints])
	self.waypointsByID[waypoint.ID] = self.waypoints[#self.waypoints]
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

	-- update connections
	if (waypoint.Next ~= nil) then
		waypoint.Next.Previous = waypoint.Previous
	end
	if (waypoint.Previous ~= nil) then
		waypoint.Previous.Next = waypoint.Next
	end

	--use connections to update indexes
	local nextWaypoint = waypoint.Next
	while nextWaypoint do
		nextWaypoint.Index = nextWaypoint.Index - 1
		nextWaypoint.PointIndex = nextWaypoint.PointIndex - 1
		nextWaypoint = nextWaypoint.Next
	end

	self.waypointsByID[waypoint.ID] = nil
	self.selectedWaypoints[waypoint.ID] = nil

	for i = 1, #self.waypoints do
		if (self.waypoints[i].ID == waypoint.ID) then
			table.remove(self.waypoints, i)
			break
		end
	end
	for i = 1, #self.waypointsByPathIndex[waypoint.PathIndex] do
		if (self.waypointsByPathIndex[waypoint.PathIndex][i].ID == waypoint.ID) then
			table.remove(self.waypointsByPathIndex[waypoint.PathIndex], i)
			break
		end
	end
end

function NodeCollection:InsertAfter(referrenceWaypoint, waypoint)

	-- update connections
	if (referrenceWaypoint.Next ~= nil) then
		waypoint.Next = referrenceWaypoint.Next
		referrenceWaypoint.Next = waypoint
	end
	waypoint.Previous = referrenceWaypoint

	-- use connections to update indexes		
	local nextWaypoint = referrenceWaypoint.Next
	while nextWaypoint do
		nextWaypoint.Index = nextWaypoint.Previous.Index + 1
		nextWaypoint.PointIndex = nextWaypoint.Previous.PointIndex + 1
		nextWaypoint = nextWaypoint.Next
	end

	-- add to lookup tables
	self:Add(waypoint)
end

function NodeCollection:InsertBefore(referrenceWaypoint, waypoint)

	-- update connections
	if (referrenceWaypoint.Previous ~= nil) then
		waypoint.Previous = referrenceWaypoint.Previous
		referrenceWaypoint.Previous = waypoint
	end
	waypoint.Next = referrenceWaypoint

	-- use connections to update indexes
	local nextWaypoint = waypoint
	while nextWaypoint do
		nextWaypoint.Index = nextWaypoint.Previous.Index + 1
		nextWaypoint.PointIndex = nextWaypoint.Previous.PointIndex + 1
		nextWaypoint = nextWaypoint.Next
	end

	-- add to lookup tables
	self:Add(waypoint)
end

function NodeCollection:Update(waypoint, data)
	g_Utilities:mergeKeys(waypoint, data)
	waypoint.Updated = true
end

function NodeCollection:SetInput(inputVar)
	for i=1, #self.selectedWaypoints do
		self:Update(self.selectedWaypoints[i], {InputVar = (tonumber(inputVar) or 20)})
	end
end

function NodeCollection:Get(waypointID, pathIndex)
	if (waypointID ~= nil) then
		local searchTable = self.waypoints
		if (pathIndex ~= nil) then
			searchTable = self:Get(nil, pathIndex)
		end
		for _, waypoint in pairs(searchTable) do
			if (waypoint.ID == waypointID) then
				return waypoint
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

function NodeCollection:Clear()
	self.waypointIDs = 1
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByPathIndex = {}
end

-----------------------------
-- Selection

function NodeCollection:Select(waypoint)
	if (self.debugcount2 < 10) then
		print('Select Node: '..tostring(waypoint.ID))
		self.debugcount2 = self.debugcount2 + 1
	end
	if (waypoint.ID == nil) then return end
	self.selectedWaypoints[waypoint.ID] = waypoint
end

function NodeCollection:SelectByID(waypointID, pathIndex)
	self:Select(self:Get(waypointID, pathIndex))
end

function NodeCollection:Deselect(waypoint)
	if (waypoint.ID == nil) then return end
	if (waypoint == nil) then
		self:ClearSelection()
	else
		self.selectedWaypoints[waypoint.ID] = nil
	end
end

function NodeCollection:DeselectByID(waypointID, pathIndex)
	self:Deselect(self:Get(waypointID, pathIndex))
end

function NodeCollection:IsSelected(waypoint)
	if (waypoint.ID == nil) then return end
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

	self:_sort(selection)
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
	for i=2, #selection do
		print('NodeCollection:Merge -> selection['..tostring(i)..']: '..tostring(selection[i].Index))

		if (selection[i].PathIndex ~= currentWaypoint.PathIndex) then
			return false, 'Waypoints must be on same path'
		end

		if (currentWaypoint.Index+1 ~= currentWaypoint.Next.Index) then
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

	if (selection[1].Index ~= selection[2].Previous.Index) then
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

function NodeCollection:EnablePath(pathIndex)
	return self.disabledPaths[pathIndex] == false
end

function NodeCollection:DisablePath(pathIndex)
	self.disabledPaths[pathIndex] = true
end

function NodeCollection:IsPathEnabled(pathIndex)
	return self.disabledPaths[pathIndex] == nil or self.disabledPaths[pathIndex] == false
end

function NodeCollection:GetDisabledPaths()
	return self.disabledPaths
end

-----------------------------
-- Save/Load

function NodeCollection:Load(mapName)
	if not SQL:Open() then
		return
	end

	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM ' .. mapName .. '_table')

	if not results then
		print('Failed to execute query: ' .. SQL:Error())
		return
	end

	self:Clear()
	local pathCount = 0
	local waypointCount = 0

	for _, row in pairs(results) do
		if row["pathIndex"] > pathCount then
			pathCount = row["pathIndex"]
		end

		local newPoint = self:Create(Vec3(row["transX"], row["transY"], row["transZ"]), row["pathIndex"], row["pointIndex"], row["inputVar"])
		newPoint.OriginalID = tonumber(row["id"])
		waypointCount = waypointCount+1
	end

	SQL:Close()
	print('NodeCollection:Load -> Paths: '..tostring(pathCount)..' | Waypoints: '..tostring(waypointCount))
end

function NodeCollection:Save(mapName)

	if not SQL:Open() then
		return
	end

	local pathsSaved = {}
	local waypointCount = 0

	for _,waypoint in pairs(self.waypoints) do
		if (waypoint.Updated) then

			local row = {
				id = waypoint.Index,
				pathIndex = waypoint.PathIndex,
				pointIndex = waypoint.PointIndex,
				transX = waypoint.Position.x,
				transY = waypoint.Position.y,
				transZ = waypoint.Position.z,
				inputVar = waypoint.InputVar,
			}

		end
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

		--> TODO check if path disabled here <--

		if (waypoint ~= nil and waypoint.Position ~= nil) then
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

		--> TODO check if path disabled here <--

		if (waypoint ~= nil and waypoint.Position ~= nil and waypoint.Position:Distance(vec3Position) <= tolerance) then
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

			--> TODO check if path disabled here <--

			if (waypoint ~= nil and waypoint.Position ~= nil and waypoint.Position:Distance(testPos) <= tolerance) then
				print('NodeCollection:FindAlongTrace -> Found: '..waypoint.ID)
				return waypoint
			end
		end
		testPos = testPos:MoveTowards(vec3End, granularity)
		distance = testPos:Distance(vec3End)
	end
	return nil
end

function NodeCollection:_createID()
	local index = self.waypointIDs
	self.waypointIDs = self.waypointIDs+1
	return index
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