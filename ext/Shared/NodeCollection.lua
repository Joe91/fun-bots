class "NodeCollection"

function NodeCollection:__init()
	self.waypointIDs = 0
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByIndex = {}
	self.selectedWaypoints = {}

	self:RegisterEvents()
end

function NodeCollection:RegisterEvents()
	-- Management
	NetEvents:Subscribe('NodeEditor:Create', self, self.Create)
	NetEvents:Subscribe('NodeEditor:Add', self, self.Add)
	NetEvents:Subscribe('NodeEditor:Remove', self, self.Remove)
	NetEvents:Subscribe('NodeEditor:Update', self, self.Update)
	NetEvents:Subscribe('NodeEditor:Clear', self, self.Clear)

	-- Selection
	NetEvents:Subscribe('NodeEditor:Select', self, self.Select)
	NetEvents:Subscribe('NodeEditor:SelectByID', self, self.SelectByID)
	NetEvents:Subscribe('NodeEditor:Deselect', self, self.Deselect)
	NetEvents:Subscribe('NodeEditor:DeselectByID', self, self.DeselectByID)
	NetEvents:Subscribe('NodeEditor:DeselectAll', self, self.DeselectAll)

	-- Save/Load
	NetEvents:Subscribe('NodeEditor:Save', self, self.Save)
	NetEvents:Subscribe('NodeEditor:Load', self, self.Load)
end

-- Management

function NodeCollection:Create(vec3Position, pathIndex, inputVar)
	local newIndex = self:_createID()
	local waypoint = {
		ID = string.format('p_%d', newIndex),
		Index = newIndex,
		Position = vec3Position,
		PathIndex = pathIndex,
		InputVar = inputVar,
		Distance = nil
	}
	self:Add(waypoint)
	return waypoint
end

function NodeCollection:Add(waypoint)
	self.waypointsByID[waypoint.ID] = waypoint
	self.waypointsByIndex[waypoint.Index] = waypoint
	self.selectedWaypoints[waypoint.ID] = false
	table.insert(self.waypoints, waypoint)
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

function NodeCollection:Update(waypoint)
	self.waypointsByID[waypoint.ID] = waypoint
	self.waypointsByIndex[waypoint.Index] = waypoint
	for i = 1, #self.waypoints do
		if (self.waypoints[i].ID == waypoint.ID) then
			self.waypoints[i] = waypoint
		end
	end
end

function NodeCollection:Clear()
	self.waypoints = {}
	self.waypointsByID = {}
	self.waypointsByIndex = {}
	self.selectedWaypoints = {}
end

function NodeCollection:Get()
	return self.waypoints
end

-- Selection

function NodeCollection:Select(waypoint)
	self.selectedWaypoints[waypoint.ID] = true
end

function NodeCollection:SelectByID(waypointID)
	self:Select({ID = string.format('p_%d', waypointID)})
end

function NodeCollection:Deselect(waypoint)
	if (waypoint == nil) then
		self.selectedWaypoints = {}
	else
		self.selectedWaypoints[waypoint.ID] = false
	end
end

function NodeCollection:DeselectByID(waypointID)
	self:Deselect({ID = string.format('p_%d', waypointID)})
end

function NodeCollection:IsSelected(waypoint)
	return self.selectedWaypoints[waypoint.ID] == true
end

function NodeCollection:IsSelectedByID(waypointID)
	return self:IsSelected({ID = string.format('p_%d', waypointID)})
end

function NodeCollection:GetSelected()
	return self.selectedWaypoints
end

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

		self:Create(Vec3(row["transX"], row["transY"], row["transZ"]), row["pathIndex"], row["inputVar"])
		waypointCount = waypointCount+1
	end

	SQL:Close()
	print('NodeCollection:Load -> Paths: '..tostring(pathCount)..' | Waypoints: '..tostring(waypointCount))
end

function NodeCollection:Save(mapName)


end

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

return NodeCollection()