class "NodeCollection"

require('__shared/Utilities.lua')
requireExists('Globals')

function NodeCollection:__init()
	self:InitTables()
	NetEvents:Subscribe('NodeCollection:Clear', self, self.Clear)
	NetEvents:Subscribe('NodeCollection:Create', self, self.Create)
end

function NodeCollection:InitTables()
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByPathIndex = {}

	self.selectedWaypoints = {}
	self.hiddenPaths = {}

	self.mapName = ''

	self.debugcount = 0
	self.debugcount2 = 0
end

function NodeCollection:RegisterEvents()
	-- Management
	NetEvents:Subscribe('NodeCollection:Register', self, self.Register)
	NetEvents:Subscribe('NodeCollection:Remove', self, self.Remove)
	NetEvents:Subscribe('NodeCollection:InsertAfter', self, self.InsertAfter)
	NetEvents:Subscribe('NodeCollection:InsertBefore', self, self.InsertBefore)
	NetEvents:Subscribe('NodeCollection:Update', self, self.Update)
	NetEvents:Subscribe('NodeCollection:SetInput', self, self.SetInput)
	NetEvents:Subscribe('NodeCollection:Merge', self, self.MergeSelected)
	NetEvents:Subscribe('NodeCollection:Split', self, self.SplitSelected)

	-- Selection
	NetEvents:Subscribe('NodeCollection:Select', self, self.Select)
	NetEvents:Subscribe('NodeCollection:SelectByID', self, self.SelectByID)
	NetEvents:Subscribe('NodeCollection:Deselect', self, self.Deselect)
	NetEvents:Subscribe('NodeCollection:DeselectByID', self, self.DeselectByID)
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
	NetEvents:Unsubscribe('NodeCollection:SelectByID')
	NetEvents:Unsubscribe('NodeCollection:Deselect')
	NetEvents:Unsubscribe('NodeCollection:DeselectByID')
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

function NodeCollection:Create(data)
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
		print('Warning, New Node index does not match: waypoint.Index:'..tostring(waypoint.Index)..' | #self.waypoints:'..tostring(#self.waypoints)..' | '.. tostring(diff))
	end

	table.insert(self.waypointsByPathIndex[waypoint.PathIndex], waypoint)
	self.waypointsByID[waypoint.ID] = waypoint

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
	waypoint.Next = false
	waypoint.Previous = false

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
	print('NodeCollection:ProcessMetadata Starting...')
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
	print('NodeCollection:ProcessMetadata Finished! ['..tostring(counter)..']')
end

function NodeCollection:_processWaypointMetadata(waypoint)

	if (waypoint.Data == nil) then
		waypoint.Data = {}
	end

	if (type(waypoint.Data) == 'string') then
		waypoint.Data = json.decode(waypoint.Data)
	end

	-- TODO Check if indirect connections
	-- waypoint.Data.LinkMode = 0
	-- waypoint.Data.Links = { 'p_1', ... }

	-- TODO Check if direct connections
	-- waypoint.Data.LinkMode = 1
	-- waypoint.Data.Links = { 'p_1', ... }


end


function NodeCollection:Update(waypoint, data)
	g_Utilities:mergeKeys(waypoint, data)
end

function NodeCollection:UpdateMetadata(waypoint, data)
	self:Update(waypoint, {Data = g_Utilities:mergeKeys(waypoint.Data, data)})
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


function NodeCollection:Get(waypointIndex, pathIndex)
	if (waypointIndex ~= nil) then
		if (pathIndex ~= nil) then
			
			if (self.waypointsByPathIndex[pathIndex] == nil) then
				self.waypointsByPathIndex[pathIndex] = {}
			end

			for i=1, #self.waypointsByPathIndex[pathIndex] do
				local waypoint = self.waypointsByPathIndex[pathIndex][i]
				if (waypoint.PathIndex == pathIndex and waypoint.PointIndex == waypointIndex) then
					return waypoint
				end
			end
		else
			if (type(waypointIndex) == 'string') then
				return self.waypointsByID[waypointIndex]
			else
				for i=1, #self.waypoints do
					if (self.waypoints[i].Index == waypointIndex) then
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
	local firstWaypoint = nil
	local searchTable = self.waypoints
	if (pathIndex ~= nil) then
		searchTable = self.waypointsByPathIndex[pathIndex]
	end

	for i=1, #searchTable do
		local waypoint = searchTable[i]
		if (waypoint.Previous == false and waypoint.Next ~= false) then
			return waypoint
		end
	end
end

function NodeCollection:GetPaths()
	return self.waypointsByPathIndex
end

function NodeCollection:Clear()
	print('NodeCollection:Clear')

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
	self.debugcount = 0
end

-----------------------------
-- Selection

function NodeCollection:Select(waypoint)
	if (waypoint == nil or waypoint.ID == nil) then return end
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
	if (waypoint == nil or waypoint.ID == nil) then return false end
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
	for i=2, #selection do

		if (currentWaypoint.PathIndex ~= selection[i].PathIndex) then
			return false, 'Waypoints must be on same path'
		end

		if (currentWaypoint.Next and currentWaypoint.Next.Index ~= selection[i].Index) then
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

		if (currentWaypoint.Next and currentWaypoint.Next.Index ~= selection[i].Index) then
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

function NodeCollection:Load(levelName, gameMode)

	if g_Globals.isTdm then
		gameMode = 'TeamDeathMatch0'
	end
	self.mapName = levelName .. '_' .. gameMode
	print('NodeCollection:Load: '..self.mapName)

	if not SQL:Open() then
		return
	end

	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM ' .. self.mapName .. '_table ORDER BY `pathIndex`, `pointIndex` ASC')

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

		waypoint = self:Create(waypoint)
		lastWaypoint = waypoint
		waypointCount = waypointCount+1
	end
	SQL:Close()
	self:RecalculateIndexes(lastWaypoint)

	print('NodeCollection:Load -> Paths: '..tostring(pathCount)..' | Waypoints: '..tostring(waypointCount))
end

function NodeCollection:Save()
	--if not SQL:Open() then
	--	return
	--end

	--self.mapName

	local changedWaypoints = {}
	local waypointCount = #self.waypoints
	local waypointsChanged = 0
	local orphans = {}
	local disconnects = {}

	print('NodeCollection:Save -> Processing: '..(waypointCount))

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
			local rowData = {
				trans = waypoint.Position:Clone(),
				speedMode = waypoint.SpeedMode,
				extraMode = waypoint.ExtraMode,
				optValue = waypoint.OptValue,
			}

			if (changedWaypoints[waypoint.PathIndex] == nil) then
				changedWaypoints[waypoint.PathIndex] = {}
			end
			changedWaypoints[waypoint.PathIndex][waypoint.PointIndex] = rowData
			waypointsChanged = waypointsChanged + 1
		end
	end

	print('NodeCollection:Save -> Updated: '..(waypointsChanged))
	print('NodeCollection:Save -> Orphans: '..(#orphans)..' (Removed)')
	print('NodeCollection:Save -> Disconnected: '..(#disconnects)..' (Expected: 2)')

	if (#disconnects > 2) then
		print('WARNING! More than two disconnected nodes were found!')
		print(g_Utilities:dump(disconnects, true, 2))
	end

	-- we're on the server
	if (g_Globals ~= nil) then

		-- replace global waypoints table
		local lastPathIndex = 0
		for i=1, MAX_TRACE_NUMBERS do
			if (changedWaypoints[i] ~= nil) then
				if (lastPathIndex < i) then
					lastPathIndex = i
				end
			else
				changedWaypoints[i] = {}
			end
		end
		g_Globals.wayPoints = changedWaypoints
		g_Globals.activeTraceIndexes = lastPathIndex
	end
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
	--print('NodeCollection:FindAlongTrace - granularity: '..tostring(granularity))

	local distance = math.min(math.max(vec3Start:Distance(vec3End), 0.05), 10)

	-- instead of searching a possible 3k or more nodes, we grab only those that would be in range
	-- shift the search area forward by 1/2 distance and also 1/2 the radius needed
	local searchAreaPos = vec3Start + ((vec3End - vec3Start) * 0.4) -- not exactly half ahead
	local searchAreaSize = (distance*0.6) -- lil bit bigger than half for searching
	NetEvents:Send('ClientNodeEditor:SetLastTraceSearchArea', {searchAreaPos, searchAreaSize})
	if (g_ClientNodeEditor) then
		g_ClientNodeEditor:_onSetLastTraceSearchArea({searchAreaPos, searchAreaSize})
	end

	local searchWaypoints = self:FindAll(searchAreaPos, searchAreaSize)
	local testPos = vec3Start

	--print('distance: '..tostring(distance))
	--print('searchWaypoints: '..tostring(#searchWaypoints))

	while distance > granularity and distance > 0 do
		for _,waypoint in pairs(searchWaypoints) do

			if (waypoint ~= nil and self:IsPathVisible(waypoint.PathIndex) and waypoint.Position ~= nil and waypoint.Position:Distance(testPos) <= tolerance) then
				--print('NodeCollection:FindAlongTrace -> Found: '..waypoint.ID)
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