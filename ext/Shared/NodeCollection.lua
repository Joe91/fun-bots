class "NodeCollection"

require('__shared/Utilities.lua')

function NodeCollection:__init()
	self:InitTables()
	self:RegisterEvents()
end

function NodeCollection:InitTables()
	self.waypointIDs = 0
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByIndex = {}
	self.selectedWaypoints = {}
	self.disabledPaths = {}
end

function NodeCollection:RegisterEvents()
	-- Management
	NetEvents:Subscribe('NodeEditor:Create', self, self.Create)
	NetEvents:Subscribe('NodeEditor:Add', self, self.Add)
	NetEvents:Subscribe('NodeEditor:Remove', self, self.Remove)
	NetEvents:Subscribe('NodeEditor:Update', self, self.Update)
	NetEvents:Subscribe('NodeEditor:Clear', self, self.Clear)
	NetEvents:Subscribe('NodeEditor:SetInput', self, self.SetInput)
	NetEvents:Subscribe('NodeEditor:Merge', self, self.Merge)
	NetEvents:Subscribe('NodeEditor:Split', self, self.Split)

	-- Selection
	NetEvents:Subscribe('NodeEditor:Select', self, self.Select)
	NetEvents:Subscribe('NodeEditor:SelectByID', self, self.SelectByID)
	NetEvents:Subscribe('NodeEditor:Deselect', self, self.Deselect)
	NetEvents:Subscribe('NodeEditor:DeselectByID', self, self.DeselectByID)
	NetEvents:Subscribe('NodeEditor:DeselectAll', self, self.DeselectAll)

	-- Paths
	NetEvents:Subscribe('NodeEditor:EnablePath', self, self.EnablePath)
	NetEvents:Subscribe('NodeEditor:DisablePath', self, self.DisablePath)

	-- Save/Load
	NetEvents:Subscribe('NodeEditor:Save', self, self.Save)
	NetEvents:Subscribe('NodeEditor:Load', self, self.Load)
end

-----------------------------
-- Management

function NodeCollection:Create(vec3Position, pathIndex, pointIndex, inputVar, setIndex)
	local newIndex = self:_createID()
	local inputVar = tonumber(inputVar) or 20

	local waypoint = {
		ID = string.format('p_%d', newIndex), 	-- new generated id for internal storage
		OriginalID = nil,							-- original id from database
		Index = setIndex or newIndex, 						-- new generated id in numerical form
		Position = vec3Position,
		PathIndex = tonumber(pathIndex) or 10, 	-- Path #
		PointIndex = tonumber(pointIndex) or 0, -- index inside parent path
		InputVar = inputVar, 					-- raw input value
		SpeedMode = inputVar & 0xF,
		ExtraMode = (inputVar >> 4) & 0xF,
		OptValue = (inputVar >> 8) & 0xFF,
		Distance = nil,							-- current distance to player
		Updated = false							-- if true, needs to be sent to server for saving
	}
	self:Add(waypoint)
	return waypoint
end

function NodeCollection:Add(waypoint)
	self.waypointsByID[waypoint.ID] = waypoint
	self.waypointsByIndex[waypoint.Index] = waypoint
	self.selectedWaypoints[waypoint.ID] = false
	table.insert(self.waypoints, waypoint)
	if (self.disabledPaths[waypoint.PathIndex] == nil) then
		self.disabledPaths[waypoint.PathIndex] = false
	end
	if (self.waypointIDs < waypoint.Index) then
		self.waypointIDs = waypoint.Index+1
	end
end

function NodeCollection:Remove(waypoint)
	self.waypointsByID[waypoint.ID] = nil
	self.waypointsByIndex[waypoint.Index] = nil
	self.selectedWaypoints[waypoint.ID] = nil
	local eraseIndex = nil
	for i = 1, #self.waypoints do
		if (self.waypoints[i].ID == waypoint.ID) then
			eraseIndex = i
		end
	end
	if (eraseIndex ~= nil) then
		table.remove(self.waypoints, eraseIndex)
	end
end

function NodeCollection:Update(waypoint, data)

	g_Utilities:mergeKeys(waypoint, data)
	waypoint.Updated = true

	self.waypointsByID[waypoint.ID] = waypoint
	self.waypointsByIndex[waypoint.Index] = waypoint
	for i = 1, #self.waypoints do
		if (self.waypoints[i].ID == waypoint.ID) then
			self.waypoints[i] = waypoint
		end
	end
	return waypoint
end

function NodeCollection:SetInput(inputVar)

	for i=1, #self.selectedWaypoints do
		self:Update(self.selectedWaypoints[i], {InputVar = (tonumber(inputVar) or 20)})
	end

	-- TODO
	-- set input var for selected waypoints
	-- any number of selected nodes
end

function NodeCollection:Merge()
	-- TODO
	-- combine selected nodes
	-- nodes must be sequential or the start/end of two paths

	-- move selection into index-based array and sort ascending
	local selection = {}
	for k,v in pairs(self.selectedWaypoints) do
		if (v) then
			table.insert(selection, self.waypointsByID[k])
		end
	end
	self:Sort(selection, 'PointIndex', true)
	
	if (#selection < 2) then
		return false, 'Must select two or more waypoints'
	end

	-- check is same path and sequential
	local currentpath = selection[1].PathIndex
	local expectedIndex = selection[1].PointIndex
	for i=1, #selection do
		print('NodeCollection:Split -> selection['..tostring(i)..']: '..tostring(selection[i].ID))

		if (selection[i].PathIndex ~= currentpath) then
			return false, 'Waypoints must be on same path'
		end

		if (selection[i].PointIndex == expectedIndex) then
			expectedIndex = selection[i].PointIndex+1
		else
			return false, 'Waypoints must be sequential'
		end
	end

	-- all clear, points are on same path, and in order with no gaps
	local firstPoint = selection[1]
	local lastPoint = selection[#selection]
	local middlePosition = (firstPoint.Position + lastPoint.Position) / 2

	-- remove all selected nodes
	for i=1, #selection do
		self:Remove(selection[i])
	end

	-- create new node in the center
	local newWaypoint = self:Create(middlePosition, firstPoint.PathIndex, firstPoint.PointIndex, firstPoint.InputVar, firstPoint.Index)

	-- shift all node's indexes by the removed amount
	-- start at first selected node, iterate to the end
	local indexDifference = lastPoint.Index - firstPoint.Index 
	for i=(lastPoint.Index+1), (#self.waypointsByIndex - (firstPoint.Index+1)) do
		local nextWaypoint = self.waypointsByIndex[i]
		if (nextWaypoint ~= nil) then
			nextWaypoint.Updated = true
			nextWaypoint.Index = nextWaypoint.Index - indexDifference
			nextWaypoint.PointIndex = nextWaypoint.PointIndex - indexDifference
			self.waypointsByIndex[nextWaypoint.Index] = nextWaypoint
		end
	end
 	
	return true, 'Success'
end

function NodeCollection:Split()
	-- TODO
	-- splits selected nodes in half
	-- must be at least two sequential nodes
end

function NodeCollection:Get()
	return self.waypoints
end

-----------------------------
-- Selection

function NodeCollection:Select(waypoint)
	self.selectedWaypoints[waypoint.ID] = true
end

function NodeCollection:SelectByID(waypointID, pathID)
	if (pathID == nil) then
		self:Select({ID = string.format('p_%d', waypointID)})
	else
		for i = 1, #self.waypoints do
			if (self.waypoints[i].PointIndex == waypointID and self.waypoints[i].PathIndex == pathID) then
				self:Select(self.waypoints[i])
				return
			end
		end
	end
end

function NodeCollection:Deselect(waypoint)
	if (waypoint == nil) then
		self.selectedWaypoints = {}
	else
		self.selectedWaypoints[waypoint.ID] = false
	end
end

function NodeCollection:DeselectByID(waypointID, pathID)
	if (pathID == nil) then
		self:Deselect({ID = string.format('p_%d', waypointID)})
	else
		for i = 1, #self.waypoints do
			if (self.waypoints[i].PointIndex == waypointID and self.waypoints[i].PathIndex == pathID) then
				self:Deselect(self.waypoints[i])
				return
			end
		end
	end
end

function NodeCollection:IsSelected(waypoint)
	return self.selectedWaypoints[waypoint.ID] == true
end

function NodeCollection:IsSelectedByID(waypointID, pathID)
	if (pathID == nil) then
		return self:IsSelected({ID = string.format('p_%d', waypointID)})
	else
		for i = 1, #self.waypoints do
			if (self.waypoints[i].PointIndex == waypointID and self.waypoints[i].PathIndex == pathID) then
				self:IsSelected(self.waypoints[i])
				return
			end
		end
	end
end

function NodeCollection:GetSelected()
	return self.selectedWaypoints
end

function NodeCollection:Sort(collection, keyName, ascending)
	return table.sort(collection, function(a,b)
		if (ascending) then
			return a[keyName] < b[keyName]
		else
			return a[keyName] > b[keyName]
		end
	end)
end

function NodeCollection:Clear()
	self:InitTables()
end

-----------------------------
-- Paths

function NodeCollection:EnablePath(pathIndex)
	return self.disabledPaths[pathIndex] == false
end

function NodeCollection:DisablePath(pathIndex)
	self.disabledPaths[pathIndex] = true
end

function NodeCollection:IsPathEnabled(waypoint)
	return self.disabledPaths[waypoint.ID] == nil or self.disabledPaths[waypoint.ID] == false
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

function NodeCollection:Previous(currentWaypoint)
	local previousWaypoint = self.waypointsByIndex[currentWaypoint.Index-1]
	if (previousWaypoint ~= nil and previousWaypoint.PathIndex == currentWaypoint.PathIndex) then
		return previousWaypoint
	end
	return nil
end

function NodeCollection:Next(currentWaypoint)
	local nextWaypoint = self.waypointsByIndex[currentWaypoint.Index+1]
	if (nextWaypoint ~= nil and nextWaypoint.PathIndex == currentWaypoint.PathIndex) then
		return nextWaypoint
	end
	return nil
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
	local searchAreaPos = vec3Start + ((vec3End - vec3Start) * 0.5)
	local searchAreaSize = (distance*0.6) -- lil bit bigger than half
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