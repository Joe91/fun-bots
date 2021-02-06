require('__shared/Config');
local nodeCollection = require('__shared/NodeCollection')


-- caching values for drawing performance
local waypoints = {}
local playerPos = nil
local textColor = Vec4(1,1,1,1)
local sphereColors = {
	Vec4(1,0,0,0.25),
	Vec4(0,1,0,0.25),
	Vec4(0,0,1,0.25),
	Vec4(1,1,0,0.25),
	Vec4(1,0,1,0.25),
	Vec4(0,1,1,0.25),
	Vec4(1,0.5,0,0.25),
	Vec4(1,0,0.5,0.25),
	Vec4(0,0.5,1,0.25),
	Vec4(1,0.5,0.5,0.25),
}
local lineColors = {
	Vec4(1,0,0,1),
	Vec4(0,1,0,1),
	Vec4(0,0,1,1),
	Vec4(1,1,0,1),
	Vec4(1,0,1,1),
	Vec4(0,1,1,1),
	Vec4(1,0.5,0,1),
	Vec4(1,0,0.5,1),
	Vec4(0,0.5,1,1),
	Vec4(1,0.5,0.5,1),
}



local lastTraceSrearchAreaPos = nil
local lastTraceSrearchAreaSize = nil
NetEvents:Subscribe('NodeEditor:SetLastTraceSearchArea', function(data)
	--print('NodeEditor:SetLastTraceSearchArea')
	lastTraceSrearchAreaPos = data[1]
	lastTraceSrearchAreaSize = data[2]
end)

NetEvents:Subscribe('NodeEditor:ClientInit', function(args)
	--print('NodeEditor:Init')
	player = PlayerManager:GetLocalPlayer()
	waypoints = nodeCollection:Get()
end)


Events:Subscribe('UpdateManager:Update', function(delta, pass)
	-- Only do math on presimulation UpdatePass
	if pass ~= UpdatePass.UpdatePass_PreSim then
		return
	end

	-- doing this here and not in UI:DrawHud prevents a memory leak that crashes you in under a minute
	if (player ~= nil and player.soldier ~= nil and player.soldier.worldTransform ~= nil) then
		playerPos = player.soldier.worldTransform.trans
    	for i=1, #waypoints do
    		if (waypoints[i] ~= nil) then
    			-- precalc the distances for less overhead on the hud draw
    			waypoints[i].Distance = playerPos:Distance(waypoints[i].Position)
    		end
    	end
    end
end)

CommoRose = {
	Pressed = false,
	Active = false,
	LastAction = ''
}

Hooks:Install('UI:PushScreen', 999, function(hook, screen, priority, parentGraph, stateNodeGuid)
	if (screen ~= nil and UIScreenAsset(screen).name == 'UI/Flow/Screen/CommRoseScreen') then
    	CommoRose.Active = CommoRose.Pressed

    	if (CommoRose.Active) then
    		hook:Return() -- don't actually display the UI
    	end
    end
	hook:Pass(screen, priority, parentGraph, stateNodeGuid)
end)

Hooks:Install('UI:InputConceptEvent', 1, function(hook, eventType, action)
    if (action == UIInputAction.UIInputAction_CommoRose) then
		CommoRose.Pressed = (eventType == UIInputActionEventType.UIInputActionEventType_Pressed)
	end
    hook:Pass(eventType, action)
end)

Hooks:Install('UI:CreateAction', 1, function(hook, action)
	if (action == UIAction.ContextVO and CommoRose.Active) then -- center item used
		CommoRose.LastAction = 'ContextVO'
    end

    if (action == UIAction.RadioVO and CommoRose.Active) then -- side item used
    	CommoRose.LastAction = 'RadioVO'
    end

    if (CommoRose.LastAction ~= '') then

    	local selectedWaypoints = nodeCollection:GetSelected()
    	for k,v in pairs(selectedWaypoints) do
    		if (v) then
    			print('selectedWaypoints['..tostring(k)..']: '..tostring(v))
    		end
    	end

		CommoRoseAction(CommoRose.LastAction)
		CommoRose.LastAction = ''
	end

    hook:Pass(action)
end)

local lastTraceStart = nil
local lastTraceEnd = nil
function CommoRoseAction(action, hit)
	print('CommoRoseAction')

	local localPlayer = PlayerManager:GetLocalPlayer() 
	local hit = Raycast()
    local hitPoint = nodeCollection:Find(hit.position)

	-- nothing found at hit location, try a raytracing check
	if (hitPoint == nil and localPlayer ~= nil and localPlayer.soldier ~= nil) then
		local playerCamPos = localPlayer.soldier.worldTransform.trans + localPlayer.input.authoritativeCameraPosition
		hitPoint = nodeCollection:FindAlongTrace(playerCamPos, hit.position)
		lastTraceStart = playerCamPos
		lastTraceEnd = hit.position
	end

	-- still no results, let's create one
	if (hitPoint == nil) then
		local waypoint = nodeCollection:Create(hit.position, 10, 0)
		-- then send it to everyone
		NetEvents:Send('NodeEditor:Add', waypoint)
		-- tell the player who made it that it should be selected
		nodeCollection:Select(waypoint)
		return

	else -- we found one, let's toggle its selected state

		local isSelected = nodeCollection:IsSelected(hitPoint)

		if (isSelected) then 
			nodeCollection:Deselect(hitPoint)
			return
		else
			nodeCollection:Select(hitPoint)
			return
		end
	end
end

Events:Subscribe('UI:DrawHud', function()

	DebugRenderer:DrawText2D(20, 20, 'CommoRose.Pressed: '..tostring(CommoRose.Pressed).."\nCommoRose.Active: "..tostring(CommoRose.Active).."\nCommoRose.LastAction: "..tostring(CommoRose.LastAction) ,textColor, 1)

	if (Config.debugTraces) then
		if (lastTraceStart ~= nil and lastTraceEnd ~= nil) then
			DebugRenderer:DrawLine(lastTraceStart, lastTraceEnd, textColor, textColor)
		end
		if (lastTraceSrearchAreaPos ~= nil and lastTraceSrearchAreaSize ~= nil) then
			DebugRenderer:DrawSphere(lastTraceSrearchAreaPos, lastTraceSrearchAreaSize, sphereColors[9], false, false)
		end
	end

	for i=1, #waypoints do
		if (waypoints[i] ~= nil) then

			local isSelected = nodeCollection:IsSelected(waypoints[i])

			if (waypoints[i].Distance ~= nil and waypoints[i].Distance < Config.waypointRange) then
				DebugRenderer:DrawSphere(waypoints[i].Position, 0.05, sphereColors[waypoints[i].PathIndex], false, false)
			end

			if (waypoints[i].Distance ~= nil and waypoints[i].Distance < Config.waypointRange and isSelected) then
				DebugRenderer:DrawSphere(waypoints[i].Position, 0.07, sphereColors[waypoints[i].PathIndex], false, false)
				DebugRenderer:DrawLine(waypoints[i].Position, waypoints[i].Position + (Vec3.up * 0.5), lineColors[waypoints[i].PathIndex], lineColors[waypoints[i].PathIndex])
			end

			if (waypoints[i].Distance ~= nil and waypoints[i].Distance < Config.lineRange and Config.drawWaypointLines) then
				-- try to find a previous node and draw a line to it
				local previousWaypoint = nodeCollection:Previous(waypoints[i])
				if (previousWaypoint ~= nil) then
					DebugRenderer:DrawLine(previousWaypoint.Position, waypoints[i].Position, lineColors[waypoints[i].PathIndex], lineColors[waypoints[i].PathIndex])
					previousWaypoint = nil
				end
			end

			if (waypoints[i].Distance ~= nil and waypoints[i].Distance < Config.textRange and Config.drawWaypointIDs) then
				-- don't try to precalc this value like with the distance, another memory leak crash awaits you
				if (isSelected) then
					local screenPos = ClientUtils:WorldToScreen(waypoints[i].Position + (Vec3.up * 0.5))
					if (screenPos ~= nil) then
						local text = 'ID: '..tostring(waypoints[i].ID).."\n"
						text = text..'PathIndex: '..tostring(waypoints[i].PathIndex).."\n"
						text = text..'InputVar: '..tostring(getEnumName(EntryInputActionEnum, waypoints[i].InputVar))..' ('..tostring(waypoints[i].InputVar)..')'
						DebugRenderer:DrawText2D(screenPos.x, screenPos.y, text, textColor, 1.2)
					end
					screenPos = nil
				else
					local screenPos = ClientUtils:WorldToScreen(waypoints[i].Position + (Vec3.up * 0.05))
					if (screenPos ~= nil) then
						DebugRenderer:DrawText2D(screenPos.x, screenPos.y, tostring(waypoints[i].ID).."\n"..tostring(getEnumName(EntryInputActionEnum, waypoints[i].InputVar)), textColor, 1)
						screenPos = nil
					end
				end
			end
		end
	end
end)

-- ##################################################
-- ##################################################
-- ###################################### DEBUG STUFF

local TheBigList = {}
Events:Subscribe('Level:Loaded', function(player)
	print('Level:Loaded')

	EntityManager:TraverseAllEntities(function(entity)
		if (entity.typeInfo ~= nil) then
			if (TheBigList[entity.typeInfo.name] == nil) then
				TheBigList[entity.typeInfo.name] = 1
			else
				TheBigList[entity.typeInfo.name] = TheBigList[entity.typeInfo.name] + 1
			end
		end
	end)

	for k,v in pairs(TheBigList) do
		print(k..': '..tostring(v))
	end

	print('ClientUIGraphEntity Callbacks Registered: '..registerCallbacks('ClientUIGraphEntity'))
	print('ClientSoldierEntity Callbacks Registered: '..registerCallbacks('ClientSoldierEntity'))

end)

-- stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
function Raycast()

	local localPlayer = PlayerManager:GetLocalPlayer()

	if localPlayer == nil then
		return
	end

	-- We get the camera transform, from which we will start the raycast. We get the direction from the forward vector. Camera transform
	-- is inverted, so we have to invert this vector.
	local transform = ClientUtils:GetCameraTransform()
	local direction = Vec3(-transform.forward.x, -transform.forward.y, -transform.forward.z)

	if transform.trans == Vec3(0,0,0) then
		return
	end

	local castStart = transform.trans

	-- We get the raycast end transform with the calculated direction and the max distance.
	local castEnd = Vec3(
		transform.trans.x + (direction.x * 100),
		transform.trans.y + (direction.y * 100),
		transform.trans.z + (direction.z * 100))

	-- Perform raycast, returns a RayCastHit object.
	local raycastHit = RaycastManager:Raycast(castStart, castEnd, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh)

	return raycastHit	
end

function registerCallbacks(entityType)
	local messageIterator = EntityManager:GetIterator(entityType)
	local messageEntity = messageIterator:Next()
	local total = 0
	
	while messageEntity do
		messageEntity = Entity(messageEntity)
		messageEntity:RegisterEventCallback(function(ent, entityEvent)
			if (ent.data ~= nil) then
				print(tostring(entityType)..': '..tostring(ent.data.instanceGuid)..' -> '..tostring(ent.data.name))
			end
        end)
        total = total+1
		
		messageEntity = messageIterator:Next()
	end
	return total
end

function getEnumName(enum, value)
	for k,v in pairs(getmetatable(enum)['__index']) do
		if (v == value) then
			return k
		end
	end
	return nil
end