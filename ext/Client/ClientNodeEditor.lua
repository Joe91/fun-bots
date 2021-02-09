class "ClientNodeEditor"

require('__shared/Config');
require('__shared/NodeCollection')

function ClientNodeEditor:__init()
	-- caching values for drawing performance
	self.player = nil
	self.waypoints = {}
	self.playerPos = nil

	self.colors = {
		["Text"] = Vec4(1,1,1,1),
		["Ray"] = {Node = Vec4(1,1,1,0.2), Line = {Vec4(1,1,1,1),Vec4(0,0,0,1)}},
		["Orphan"] = {Node = Vec4(0,0,0,0.2), Line = Vec4(0,0,0,1)},
		{Node = Vec4(1,0,0,0.25), Line = Vec4(1,0,0,1)},
		{Node = Vec4(1,0.55,0,0.25), Line = Vec4(1,0.55,0,1)},
		{Node = Vec4(1,1,0,0.25), Line = Vec4(1,1,0,1)},
		{Node = Vec4(0,0.5,0,0.25), Line = Vec4(0,0.5,0,1)},
		{Node = Vec4(0,0,1,0.25), Line = Vec4(0,0,1,1)},
		{Node = Vec4(0.29,0,0.51,0.25), Line = Vec4(0.29,0,0.51,1)},
		{Node = Vec4(1,0,1,0.25), Line = Vec4(1,0,1,1)},
		{Node = Vec4(0.55,0,0,0.25), Line = Vec4(0.55,0,0,1)},
		{Node = Vec4(1,0.65,0,0.25), Line = Vec4(1,0.65,0,1)},
		{Node = Vec4(0.94,0.9,0.55,0.25), Line = Vec4(0.94,0.9,0.55,1)},
		{Node = Vec4(0.5,1,0,0.25), Line = Vec4(0.5,1,0,1)},
		{Node = Vec4(0.39,0.58,0.93,0.25), Line = Vec4(0.39,0.58,0.93,1)},
		{Node = Vec4(0.86,0.44,0.58,0.25), Line = Vec4(0.86,0.44,0.58,1)},
		{Node = Vec4(0.93,0.51,0.93,0.25), Line = Vec4(0.93,0.51,0.93,1)},
		{Node = Vec4(1,0.63,0.48,0.25), Line = Vec4(1,0.63,0.48,1)},
		{Node = Vec4(0.5,0.5,0,0.25), Line = Vec4(0.5,0.5,0,1)},
		{Node = Vec4(0,0.98,0.6,0.25), Line = Vec4(0,0.98,0.6,1)},
		{Node = Vec4(0.18,0.31,0.31,0.25), Line = Vec4(0.18,0.31,0.31,1)},
		{Node = Vec4(0,1,1,0.25), Line = Vec4(0,1,1,1)},
		{Node = Vec4(1,0.08,0.58,0.25), Line = Vec4(1,0.08,0.58,1)},
	}

	self.CommoRose = {
		Pressed = false,
		Active = false,
		LastAction = ''
	}

	self.lastTraceSearchAreaPos = nil
	self.lastTraceSearchAreaSize = nil
	self.lastTraceStart = nil
	self.lastTraceEnd = nil

	self.debugprints = 0

	self:RegisterEvents()
end

function ClientNodeEditor:RegisterEvents()

	NetEvents:Subscribe('UI_CommoRose_Action_Select', self, self._onSelectNode)

	NetEvents:Subscribe('UI_CommoRose_Action_Merge', self, self._onMergeNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Move', self, self._onToggleMoveNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Delete', self, self._onRemoveNode)

	NetEvents:Subscribe('UI_CommoRose_Action_Split', self, self._onSplitNode)
	NetEvents:Subscribe('UI_CommoRose_Action_SetInput', self, self._onSetInputNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Create', self, self._onCreateNode)

	NetEvents:Subscribe('UI_CommoRose_Action_Save', self, self._onSaveNodes)
	NetEvents:Subscribe('UI_CommoRose_Action_Load', self, self._onLoadNodes)

	NetEvents:Subscribe('NodeEditor:SetLastTraceSearchArea', self, self._onSetLastTraceSearchArea)
	NetEvents:Subscribe('NodeEditor:ClientInit', self, self._onClientInit)

	--Events:Subscribe('Player:Respawn', self, self._onPlayerRespawn)
	Events:Subscribe('Player:Deleted', self, self._onUnload)
	Events:Subscribe('Level:Destroy', self, self._onUnload)
	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput)

	Hooks:Install('UI:PushScreen', 100, self, self._onUIPushScreen)

	Console:Register('GetNodes', 'Have server resend all waypoints and lose all changes', self, self._onGetNodes)
	Console:Register('Remove', 'Remove selected waypoints', self, self._onRemoveNode)
	Console:Register('Merge', 'Merge selected waypoints', self, self._onMergeNode)
	Console:Register('Split', 'Split selected waypoints', self, self._onSplitNode)
	Console:Register('ClearSelection', 'Clear selection', self, self._onClearSelection)
	Console:Register('Move', 'toggle move mode on selected waypoints', self, self._onToggleMoveNode)
	Console:Register('ShowPath', '(\'all\' or *<number|PathIndex>*) - Show path\'s waypoints', self, self._onShowPath)
	Console:Register('HidePath', '(\'all\' or *<number|PathIndex>*) - Hide path\'s waypoints', self, self._onHidePath)
	Console:Register('ShowRose', 'Show custom Commo Rose', self, self._onShowRose)
	Console:Register('HideRose', 'Hide custom Commo Rose', self, self._onHideRose)

end

function ClientNodeEditor:_onSelectNode(args)
	self.CommoRose.Active = false
	self:_onCommoRoseAction('Select')
end


function ClientNodeEditor:_onMergeNode(args)
	self.CommoRose.Active = false
	local result, message = g_NodeCollection:MergeSelection()
	self.waypoints = g_NodeCollection:Get()
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onToggleMoveNode(args)
	self.CommoRose.Active = false
	print(Language:I18N('Not Implemented Yet'))
	return false
end

function ClientNodeEditor:_onRemoveNode(args)
	self.CommoRose.Active = false
	g_NodeCollection:Remove()
	self.waypoints = g_NodeCollection:Get()
	print(Language:I18N('Success'))
	return true
end


function ClientNodeEditor:_onSplitNode(args)
	self.CommoRose.Active = false
	local result, message = g_NodeCollection:SplitSelection()
	self.waypoints = g_NodeCollection:Get()
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onSetInputNode(args)
	self.CommoRose.Active = false
	g_NodeCollection:SetInput(args[1])
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onCreateNode(args)
	self.CommoRose.Active = false
	print(Language:I18N('Not Implemented Yet'))
	return false
end


function ClientNodeEditor:_onSaveNodes(args)
	self.CommoRose.Active = false
	print(Language:I18N('Not Implemented Yet'))
	return false
end

function ClientNodeEditor:_onLoadNodes(args)
	self.CommoRose.Active = false
	print(Language:I18N('Not Implemented Yet'))
	return false
end


function ClientNodeEditor:_onGetNodes(args)
	NetEvents:Send('NodeEditor:GetNodes')
	return true
end

function ClientNodeEditor:_onClearSelection(args)
	g_NodeCollection:ClearSelection()
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onShowPath(args)

	if (args[1] == nil) then
		print('Use `all` or *<number|PathIndex>*')
		return false
	end

	if (args[1]:lower() == 'all') then
		for pathID, waypoints in pairs(g_NodeCollection:GetPaths()) do
			g_NodeCollection:ShowPath(pathID)
		end
		print(Language:I18N('Success'))
		return true
	end

	if (tonumber(args[1]) ~= nil) then
		g_NodeCollection:ShowPath(tonumber(args[1]))
		print(Language:I18N('Success'))
		return true
	end
	print('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onHidePath(args)

	if (args[1] == nil) then
		print('Use `all` or *<number|PathIndex>*')
		return false
	end

	if (args[1]:lower() == 'all') then
		for pathID, waypoints in pairs(g_NodeCollection:GetPaths()) do
			g_NodeCollection:HidePath(pathID)
		end
		print(Language:I18N('Success'))
		return true
	end

	if (tonumber(args[1]) ~= nil) then
		g_NodeCollection:HidePath(tonumber(args[1]))
		print(Language:I18N('Success'))
		return true
	end
	print('Use `all` or *<number|PathIndex>*')
	return false
end

function ClientNodeEditor:_onShowRose(args)
	self:_onCommoRoseAction('Show')
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onHideRose(args)
	self:_onCommoRoseAction('Hide')
	print(Language:I18N('Success'))
	return true
end

function ClientNodeEditor:_onSetLastTraceSearchArea(data)
	self.lastTraceSearchAreaPos = data[1]
	self.lastTraceSearchAreaSize = data[2]
end

function ClientNodeEditor:_onPlayerRespawn(args)
	if (Config.debugTracePaths) then
		self:_onUnload()
		NetEvents:Send('NodeEditor:GetNodes')
	end
end

function ClientNodeEditor:_onUnload(args)
	self.player = nil
	self.waypoints = {}
	g_NodeCollection:Clear()
	g_NodeCollection:DeregisterEvents()
	Events:Unsubscribe('UpdateManager:Update')
	Events:Unsubscribe('UI:DrawHud')
end

function ClientNodeEditor:_onClientInit()
	g_NodeCollection:RegisterEvents()
	g_NodeCollection:RecalculateIndexes()

	self.waypoints = g_NodeCollection:Get()
	self.player = PlayerManager:GetLocalPlayer()

	Events:Subscribe('UpdateManager:Update', self, self._onUpdateManagerUpdate)
	Events:Subscribe('UI:DrawHud', self, self._onUIDrawHud)

	print('ClientNodeEditor:_onClientInit -> Nodes received: '..tostring(#self.waypoints))
	local counter = 0
	for i=1, #self.waypoints do

		local waypoint = self.waypoints[i]
		if (type(waypoint.Next) == 'string') then
			counter = counter+1
		end
		if (type(waypoint.Previous) == 'string') then
			counter = counter+1
		end
	end
	print('ClientNodeEditor:_onClientInit -> Stale Nodes: '..tostring(counter))
end

function ClientNodeEditor:_onUpdateManagerUpdate(delta, pass)

	if (not Config.debugTracePaths) then
		return
	end

	-- Only do math on presimulation UpdatePass
	if pass ~= UpdatePass.UpdatePass_PreSim then
		return
	end

	-- doing this here and not in UI:DrawHud prevents a memory leak that crashes you in under a minute
	if (self.player ~= nil and self.player.alive and self.player.soldier ~= nil and self.player.soldier.alive and self.player.soldier.worldTransform ~= nil) then
		self.playerPos = self.player.soldier.worldTransform.trans
    	for i=1, #self.waypoints do
    		if (self.waypoints[i] ~= nil) then
    			-- precalc the distances for less overhead on the hud draw
    			self.waypoints[i].Distance = self.playerPos:Distance(self.waypoints[i].Position)
    		end
    	end
    end
end

function ClientNodeEditor:_onUIPushScreen(hook, screen, priority, parentGraph, stateNodeGuid)

	if (Config.debugTracePaths and screen ~= nil and UIScreenAsset(screen).name == 'UI/Flow/Screen/CommRoseScreen') then

		-- triggered vanilla commo rose
		if self.CommoRose.Pressed and not self.CommoRose.Active then
    		self:_onCommoRoseAction('Show')
    	end
		hook:Return() -- don't actually display the UI
    end
	hook:Pass(screen, priority, parentGraph, stateNodeGuid)
end


function ClientNodeEditor:_onUpdateInput(delta)
	if (not Config.debugTracePaths) then
		return
	end

	local Comm1 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu1) > 0
	local Comm2 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu2) > 0
	local Comm3 = InputManager:GetLevel(InputConceptIdentifiers.ConceptCommMenu3) > 0

	-- pressed and released without triggering commo rose
	if (self.CommoRose.Pressed and not self.CommoRose.Active and not (Comm1 or Comm2 or Comm3)) then
		self:_onCommoRoseAction('Select')
	end

	self.CommoRose.Pressed = (Comm1 or Comm2 or Comm3)

	if (not self.CommoRose.Pressed and self.CommoRose.Active) then
		--self:_onCommoRoseAction('Select')
		--self:_onCommoRoseAction('Hide')
		--self.CommoRose.Active = false
	end

end

function ClientNodeEditor:_onCommoRoseAction(action, hit)
	print('CommoRoseAction: '..tostring(action))

	if (action == 'Show') then
		self.CommoRose.Active = true
		g_FunBotUIClient:_onUICommonRose({
			Top = { Action = 'UI_CommoRose_Action_Save', Label = Language:I18N('Save') },
			Bottom = { Action = 'UI_CommoRose_Action_Load', Label = Language:I18N('Load') },
			Center = { Action = 'UI_CommoRose_Action_Select', Label = Language:I18N('Select') },
			Left = {
				{ Action = 'UI_CommoRose_Action_Merge', Label = Language:I18N('Merge') },
				{ Action = 'UI_CommoRose_Action_Move', Label = Language:I18N('Move') },
				{ Action = 'UI_CommoRose_Action_Delete', Label = Language:I18N('Delete') },
			},
			Right = {
				{ Action = 'UI_CommoRose_Action_Split', Label = Language:I18N('Split') },
				{ Action = 'UI_CommoRose_Action_SetInput', Label = Language:I18N('Set Input') },
				{ Action = 'UI_CommoRose_Action_Create', Label = Language:I18N('Create') },
			}
		})
		return
	end

	if (action == 'Hide') then
		self.CommoRose.Active = false
		g_FunBotUIClient:_onUICommonRose(false)
		return
	end

	if (action == 'Select') then

		local hit = self:Raycast()
		if (hit == nil) then
			return
		end
	    local hitPoint = g_NodeCollection:Find(hit.position)

		-- nothing found at hit location, try a raytracing check
		if (hitPoint == nil and self.player ~= nil and self.player ~= nil) then
			local playerCamPos = self.player.soldier.worldTransform.trans + self.player.input.authoritativeCameraPosition
			hitPoint = g_NodeCollection:FindAlongTrace(playerCamPos, hit.position)
			self.lastTraceStart = playerCamPos
			self.lastTraceEnd = hit.position
		end

		-- still no results, let's create one
		if (hitPoint == nil) then
			--local waypoint = g_NodeCollection:Create(hit.position)
			--NetEvents:Send('NodeEditor:Add', waypoint) -- send it to everyone
			--g_NodeCollection:Select(waypoint)
			return
		else -- we found one, let's toggle its selected state

			local isSelected = g_NodeCollection:IsSelected(hitPoint)

			if (isSelected) then 
				g_NodeCollection:Deselect(hitPoint)
				return
			else
				g_NodeCollection:Select(hitPoint)
				return
			end
		end
	end
end

function ClientNodeEditor:_onUIDrawHud()

	if (not Config.debugTracePaths) then
		return
	end

	DebugRenderer:DrawText2D(20, 20,
		'CommoRose.Pressed: '..tostring(self.CommoRose.Pressed).."\nCommoRose.Active: "..tostring(self.CommoRose.Active).."\nCommoRose.LastAction: "..tostring(self.CommoRose.LastAction),
		self.colors.Text, 1)

	if (Config.debugSelectionRaytraces) then
		if (self.lastTraceStart ~= nil and self.lastTraceEnd ~= nil) then
			DebugRenderer:DrawLine(self.lastTraceStart, self.lastTraceEnd, self.colors.Ray.Line[1], self.colors.Ray.Line[2])
		end
		if (self.lastTraceSearchAreaPos ~= nil and self.lastTraceSearchAreaSize ~= nil) then
			DebugRenderer:DrawSphere(self.lastTraceSearchAreaPos, self.lastTraceSearchAreaSize, self.colors.Ray.Node, false, false)
		end
	end

	for i=1, #self.waypoints do
		local waypoint = self.waypoints[i]
		if (waypoint ~= nil and g_NodeCollection:IsPathVisible(waypoint.PathIndex)) then

			local isSelected = g_NodeCollection:IsSelected(waypoint)
			local color = self.colors[waypoint.PathIndex]

			if (waypoint.Previous == nil and waypoint.Next == nil) then
				color = self.colors.Orphan
			end


			if (waypoint.Distance ~= nil and waypoint.Distance < Config.waypointRange) then
				DebugRenderer:DrawSphere(waypoint.Position, 0.05, color.Node, false, false)
			end

			if (waypoint.Distance ~= nil and waypoint.Distance < Config.waypointRange and isSelected) then
				DebugRenderer:DrawSphere(waypoint.Position, 0.07,  color.Node, false, false)
				DebugRenderer:DrawLine(waypoint.Position, waypoint.Position + (Vec3.up * 0.7), color.Line, color.Line)
			end

			if (waypoint.Distance ~= nil and waypoint.Distance < Config.lineRange and Config.drawWaypointLines) then
				-- try to find a previous node and draw a line to it
				if (waypoint.Previous ~= nil and type(waypoint.Previous) == 'string') then
					waypoint.Previous = g_NodeCollection:Get(waypoint.Previous)
				end

				if (waypoint.Previous ~= nil) then
					DebugRenderer:DrawLine(waypoint.Previous.Position, waypoint.Position, color.Line, color.Node)
				end
			end

			if (waypoint.Distance ~= nil and waypoint.Distance < Config.textRange and Config.drawWaypointIDs) then
				if (isSelected) then
					-- don't try to precalc this value like with the distance, another memory leak crash awaits you
					local screenPos = ClientUtils:WorldToScreen(waypoint.Position + (Vec3.up * 0.7))
					if (screenPos ~= nil) then

						local previousNode = "None"
						local nextNode = "None"
						if (waypoint.Previous ~= nil) then
							previousNode = waypoint.Previous.ID
						end
						if (waypoint.Next ~= nil) then
							nextNode = waypoint.Next.ID
						end

						local text = tostring(previousNode)..' <-- |'..tostring(waypoint.ID)..'| --> '..tostring(nextNode).."\n"
						text = text..'Custom Index: '..tostring(waypoint.Index).."\n"
						text = text..'Database ID: '..tostring(waypoint.OriginalID).."\n"
						text = text..'PathIndex: '..tostring(waypoint.PathIndex).."\n"
						text = text..'PointIndex: '..tostring(waypoint.PointIndex).."\n"
						text = text..'InputVar: '..tostring(g_Utilities:getEnumName(EntryInputActionEnum, waypoint.InputVar))..' ('..tostring(waypoint.InputVar)..')'
						DebugRenderer:DrawText2D(screenPos.x, screenPos.y, text, self.colors.Text, 1.2)
					end
					screenPos = nil
				else
					-- don't try to precalc this value like with the distance, another memory leak crash awaits you
					local screenPos = ClientUtils:WorldToScreen(waypoint.Position + (Vec3.up * 0.05))
					if (screenPos ~= nil) then
						DebugRenderer:DrawText2D(screenPos.x, screenPos.y, tostring(waypoint.ID), self.colors.Text, 1)
						screenPos = nil
					end
				end
			end
		end
	end
end

-- ##################################################
-- ##################################################
-- ###################################### DEBUG STUFF


function ClientNodeEditor:_onLevelLoaded(player)

	local TheBigList = {}

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

	print('ClientUIGraphEntity Callbacks Registered: '..self:_registerCallbacks('ClientUIGraphEntity'))
	print('ClientSoldierEntity Callbacks Registered: '..self:_registerCallbacks('ClientSoldierEntity'))
end

-- stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
function ClientNodeEditor:Raycast()
	if self.player == nil then
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

function ClientNodeEditor:_registerCallbacks(entityType)
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

if (g_ClientNodeEditor == nil) then
	g_ClientNodeEditor = ClientNodeEditor()
end

return g_ClientNodeEditor