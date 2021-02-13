class "ClientNodeEditor"

require('__shared/Config');
require('__shared/NodeCollection')

function ClientNodeEditor:__init()
	-- caching values for drawing performance
	self.player = nil
	self.waypoints = {}
	self.playerPos = nil


	self.cumulatedTime = 0
	self.nodeGetTimer = 0

	self.editMode = 'none' -- 'move', 'linkprevious', 'linknext', 'none'
	self.editStartPos = nil
	self.nodeStartPos = {}
	self.editModeManualOffset = Vec3.zero
	self.editModeManualSpeed = 0.05

	self.colors = {
		["Text"] = Vec4(1,1,1,1),
		["White"] = Vec4(1,1,1,1),
		["Red"] = Vec4(1,0,0,1),
		["Green"] = Vec4(0,1,0,1),
		["Blue"] = Vec4(0,0,1,1),
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

	self.botVisionEnabled = false
	self.botVisionPlayers = {}
	self.botVistionCrosshair = nil

	self.debugEntries = {}

	self:RegisterEvents()
end

function ClientNodeEditor:RegisterEvents()

	NetEvents:Subscribe('ClientNodeEditor:SetLastTraceSearchArea', self, self._onSetLastTraceSearchArea)
	NetEvents:Subscribe('ClientNodeEditor:ReceiveNodes', self, self._onGetNodes)
	NetEvents:Subscribe('ClientNodeEditor:Init', self, self._onInit)

	NetEvents:Subscribe('UI_CommoRose_Action_Save', self, self._onSaveNodes)
	NetEvents:Subscribe('UI_CommoRose_Action_Select', self, self._onSelectNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Load', self, self._onLoadNodes)

	NetEvents:Subscribe('UI_CommoRose_Action_Merge', self, self._onMergeNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Move', self, self._onToggleMoveNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Delete', self, self._onRemoveNode)

	NetEvents:Subscribe('UI_CommoRose_Action_Split', self, self._onSplitNode)
	NetEvents:Subscribe('UI_CommoRose_Action_SetInput', self, self._onSetInputNode)
	NetEvents:Subscribe('UI_CommoRose_Action_Create', self, self._onCreateNode)

	NetEvents:Subscribe('UI_Settings', self, self._onUISettings)

	Events:Subscribe('Player:Created', self, self._onPlayerCreated)
	Events:Subscribe('Player:Deleted', self, self._onPlayerDeleted)
	Events:Subscribe('Level:Destroy', self, self._onUnload)
	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput)
	Events:Subscribe('UpdateManager:Update', self, self._onUpdateManagerUpdate)
	Events:Subscribe('UI:DrawHud', self, self._onUIDrawHud)

	Hooks:Install('UI:PushScreen', 100, self, self._onUIPushScreen)

	Console:Register('GetNodes', 'Resend all waypoints and lose all changes', self, self._onGetNodes)
	Console:Register('Remove', 'Remove selected waypoints', self, self._onRemoveNode)
	Console:Register('Merge', 'Merge selected waypoints', self, self._onMergeNode)
	Console:Register('Split', 'Split selected waypoints', self, self._onSplitNode)
	Console:Register('ClearSelection', 'Clear selection', self, self._onClearSelection)
	Console:Register('Move', 'toggle move mode on selected waypoints', self, self._onToggleMoveNode)
	Console:Register('ShowPath', '(\'all\' or *<number|PathIndex>*) - Show path\'s waypoints', self, self._onShowPath)
	Console:Register('HidePath', '(\'all\' or *<number|PathIndex>*) - Hide path\'s waypoints', self, self._onHidePath)
	Console:Register('ShowRose', 'Show custom Commo Rose', self, self._onShowRose)
	Console:Register('HideRose', 'Hide custom Commo Rose', self, self._onHideRose)
	Console:Register('DumpNodes', 'Print selected nodes or all nodes', self, self._onDumpNodes)
	Console:Register('RecalculateIndexes', 'Recalculate Indexes starting with selected nodes or all nodes', self, self._onRecalculateIndexes)
	Console:Register('UnloadNodes', 'Clears and unloads all clientside nodes', self, self._onUnload)

	Console:Register('BotVision', 'Lets you see what the bots see [Experimental]', self, self._onSetBotVision)
end

-- commo rose top / middle / bottom

function ClientNodeEditor:_onSaveNodes(args)
	self.CommoRose.Active = false
	print(Language:I18N('Not Implemented Yet'))
	return false
end

function ClientNodeEditor:_onSelectNode(args)
	self.CommoRose.Active = false
	self:_onCommoRoseAction('Select')
end

function ClientNodeEditor:_onLoadNodes(args)
	self.CommoRose.Active = false
	self:_onGetNodes()
	return true
end

-- commo rose left side

function ClientNodeEditor:_onMergeNode(args)
	self.CommoRose.Active = false
	local result, message = g_NodeCollection:MergeSelection()
	self.waypoints = g_NodeCollection:Get()
	print(Language:I18N(message))
	return result
end

function ClientNodeEditor:_onToggleMoveNode(args)
	print('ClientNodeEditor:_onToggleMoveNode: '..tostring(args))
	self.CommoRose.Active = false

	if (self.editMode == 'move') then
		self.editMode = 'none'
		self.editRayHitStart = nil
		self.editModeManualOffset = Vec3.zero

		-- move was cancelled
		if (args ~= nil and args == true) then
			local selection = g_NodeCollection:GetSelected()
			for i=1, #selection do
				g_NodeCollection:Update(selection[i], {
					Position = self.editNodeStartPos[selection[i].ID]
				})
			end
		end

		print(Language:I18N('Exiting Node Move Mode'))
		return true
	else
		if (self.player ~= nil and self.player.soldier ~= nil) then
			
			local selection = g_NodeCollection:GetSelected()
			if (#selection < 1) then
				print(Language:I18N('Must select at least one waypoint'))
				return false
			end

			self.editNodeStartPos = {}
			for i=1, #selection do
				self.editNodeStartPos[i] = selection[i].Position:Clone()
				self.editNodeStartPos[selection[i].ID] = selection[i].Position:Clone()
			end

			self.editMode = 'move'
			self.editModeManualOffset = Vec3.zero
			print(Language:I18N('Entering Node Move Mode'))
			return true

		else
			print(Language:I18N('Player not alive'))
			return false
		end
	end

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

-- commo rose right side

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

-- other methods

function ClientNodeEditor:_onSetBotVision(args)
	self.botVisionEnabled = (args ~= nil and (args[1] == '1' or args[1] == 'true'))
	print('ClientNodeEditor:_onSetBotVision: '..tostring(self.botVisionEnabled))
	NetEvents:Send('NodeEditor:SetBotVision', self.botVisionEnabled)
	if (self.botVisionEnabled) then
		-- unload our current cache
		self:_onUnload(args)
		-- set a 1 second timer before we are ready to receive
		self.cumulatedTime = 0
		self.nodeGetTimer = 1
	end
end

-- debug methods

function ClientNodeEditor:_onDumpNodes(args)

	local selection = g_NodeCollection:GetSelected()

	if (#selection < 1) then
		selection = g_NodeCollection:Get()
	end

	for i=1, #selection do
		print(g_Utilities:dump(selection[i], true, 1))
	end
	print('Dumped ['..tostring(#selection)..'] Nodes!')
	return true
end

function ClientNodeEditor:_onRecalculateIndexes(args)

	local selection = g_NodeCollection:GetSelected()
	local firstnode = nil

	if (#selection > 0) then
		firstnode = selection[1]
	end
	g_NodeCollection:RecalculateIndexes(firstnode)
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

function ClientNodeEditor:_onUISettings(data)

	if (data == false) then -- client closed settings

		if (Config.debugTracePaths) then
			self:_onUnload(args)
			-- set a 1 second timer before we are ready to receive
			self.cumulatedTime = 0
			self.nodeGetTimer = 1
		end
	end
end

-- request a fresh node list from the server
-- or server has told us be ready to receive
function ClientNodeEditor:_onGetNodes(args)
	print('ClientNodeEditor:_onGetNodes: '..tostring(args))
	-- unload our current cache
	self:_onUnload(args)
	-- set a 1 second timer before we are ready to receive
	self.cumulatedTime = 0
	self.nodeGetTimer = 1
	return true
end

function ClientNodeEditor:_onPlayerCreated(player)
	print('ClientNodeEditor:_onPlayerCreated: '..tostring(player.name))
	if (Config.debugTracePaths) then
		self:_onUnload(args)
		-- set a 1 second timer before we are ready to receive
		self.cumulatedTime = 0
		self.nodeGetTimer = 1
	end
end

function ClientNodeEditor:_onPlayerDeleted(player)
	if (self.player ~= nil and player ~= nil and self.player.name == player.name) then
		self:_onUnload()
	end
end

function ClientNodeEditor:_onUnload(args)
	for i=1, #self.waypoints do
		self.waypoints[i].Next = nil
		self.waypoints[i].Previous = nil
	end
	self.player = nil
	self.waypoints = {}
	g_NodeCollection:Clear(args)
	g_NodeCollection:DeregisterEvents()
end

-- node payload has finished sending, setup events and calc indexes
function ClientNodeEditor:_onInit()
	g_NodeCollection:RegisterEvents()
	g_NodeCollection:RecalculateIndexes()

	self.waypoints = g_NodeCollection:Get()
	self.player = PlayerManager:GetLocalPlayer()

	print('ClientNodeEditor:_onInit -> Nodes received: '..tostring(#self.waypoints))
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
	print('ClientNodeEditor:_onInit -> Stale Nodes: '..tostring(counter))
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

function ClientNodeEditor:_onUpdateInput(player, delta)
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

	if (self.editMode == 'move') then

		self.debugEntries['self.editModeManualSpeed'] = self.editModeManualSpeed

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowLeft) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad4) then
			self.editModeManualOffset = self.editModeManualOffset + (Vec3.left * self.editModeManualSpeed)
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowRight) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad6) then
			self.editModeManualOffset = self.editModeManualOffset - (Vec3.left * self.editModeManualSpeed)
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowUp) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad8) then
			self.editModeManualOffset = self.editModeManualOffset + (Vec3.forward * self.editModeManualSpeed)
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowDown) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad2) then
			self.editModeManualOffset = self.editModeManualOffset - (Vec3.forward * self.editModeManualSpeed)
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageUp) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad9) then
			self.editModeManualOffset = self.editModeManualOffset + (Vec3.up * self.editModeManualSpeed)
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageDown) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad7) then
			self.editModeManualOffset = self.editModeManualOffset - (Vec3.up * self.editModeManualSpeed)
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Equals) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Add) then
			self.editModeManualSpeed = self.editModeManualSpeed + 0.05
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Minus) or InputManager:WentKeyDown(InputDeviceKeys.IDK_Subtract) then
			self.editModeManualSpeed = self.editModeManualSpeed - 0.05
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Multiply) then
			self.editModeManualOffset = Vec3.zero
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Divide) then
			if (self.editPositionMode == 'absolute') then
				self.editPositionMode = 'relative'
			else
				self.editPositionMode = 'absolute'
			end
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Backspace) then
			self:_onToggleMoveNode(true)
			return false
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad5) then
			self:_onToggleMoveNode()
			return false
		end

	elseif (self.editMode == 'none') then

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad8) then
			self:_onSaveNodes()
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad5) then
			self:_onSelectNode()
		end

		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad2) then
			self:_onLoadNodes()
		end


		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad7) then
			self:_onMergeNode()
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad4) then
			self:_onToggleMoveNode()
			return false
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad1) then
			self:_onRemoveNode()
		end


		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad9) then
			self:_onSplitNode()
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad6) then
			self:_onSetInputNode()
		end
		if InputManager:WentKeyDown(InputDeviceKeys.IDK_Numpad3) then
			self:_onCreateNode()
		end
	end
end

function ClientNodeEditor:_onCommoRoseAction(action, hit)
	print('CommoRoseAction: '..tostring(action))

	if (action == 'Show') then
		self.CommoRose.Active = true

		local center = { Action = 'UI_CommoRose_Action_Select', Label = Language:I18N('Select') }

		if (self.editMode == 'move') then
			center = { Action = 'UI_CommoRose_Action_Move', Label = Language:I18N('Place') }
		elseif (self.editMode == 'link') then
			center = { Action = 'UI_CommoRose_Action_Connect', Label = Language:I18N('Connect') }
		end


		g_FunBotUIClient:_onUICommonRose({
			Top = { Action = 'UI_CommoRose_Action_Save', Label = Language:I18N('Save') },
			Bottom = { Action = 'UI_CommoRose_Action_Load', Label = Language:I18N('Load') },
			Center = center,
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

function ClientNodeEditor:_onUpdateManagerUpdate(delta, pass)

	if (self.nodeGetTimer > 0) then
		self.cumulatedTime = self.cumulatedTime + delta
	end

	-- timer for receiving node payload
	if (self.cumulatedTime > self.nodeGetTimer) then
		print('NodeEditor:SendNodes')
		NetEvents:Send('NodeEditor:SendNodes')
		self.cumulatedTime = 0
		self.nodeGetTimer = 0
	end

	-- Only do math on presimulation UpdatePass, don't bother if debugging is off
	if pass ~= UpdatePass.UpdatePass_PreSim and not Config.debugTracePaths and not self.botVisionEnabled then
		return
	end

	-- doing this here and not in UI:DrawHud prevents a memory leak that crashes you in under a minute
	if (self.player ~= nil and self.player.alive and self.player.soldier ~= nil and self.player.soldier.alive and self.player.soldier.worldTransform ~= nil) then
		self.playerPos = self.player.soldier.worldTransform.trans

		if (self.editMode == 'move') then
			local selection = g_NodeCollection:GetSelected()
			if (#selection > 0) then
				--raycast to 4 meters
				local hit = self:Raycast(4)
				if (hit ~= nil) then
					if (self.editRayHitStart == nil) then
						self.editRayHitStart = hit.position
						self.editRayHitCurrent = hit.position
						self.editRayHitRelative = Vec3.zero
					else 
						self.editRayHitCurrent = hit.position
						self.editRayHitRelative = self.editRayHitCurrent - self.editRayHitStart
					end
				end
			end
		end

    	for i=1, #self.waypoints do
    		if (self.waypoints[i] ~= nil) then

    			if (self.editMode == 'move') then
					if (g_NodeCollection:IsSelected(self.waypoints[i])) then

						local adjustedPosition = self.editNodeStartPos[self.waypoints[i].ID] + self.editModeManualOffset
						if (self.editPositionMode == 'relative') then
							adjustedPosition = adjustedPosition + self.editRayHitRelative
						else
							adjustedPosition = self.editRayHitCurrent
						end 

						self.waypoints[i] = g_NodeCollection:Update(self.waypoints[i], {
							Position = adjustedPosition
						})
					end
				end

    			-- precalc the distances for less overhead on the hud draw
    			self.waypoints[i].Distance = self.playerPos:Distance(self.waypoints[i].Position)
    		end
    	end

    	if (self.botVisionEnabled) then

    		-- bot vision crosshair lines, generate once only
    		if (self.botVistionCrosshair == nil) then
    			local windowSize = ClientUtils:GetWindowSize()
				local cx = math.floor(windowSize.x / 2.0 + 0.5)
				local cy = math.floor(windowSize.y / 2.0 + 0.5)

				self.botVistionCrosshair = {
					Vec2(cx - 9, cy - 1),	Vec2(cx + 8, cy - 1),
					Vec2(cx - 10, cy),		Vec2(cx + 9, cy),
					Vec2(cx - 9, cy + 1),	Vec2(cx + 8, cy + 1),

					Vec2(cx - 1, cy - 9),	Vec2(cx - 1, cy + 8),
					Vec2(cx,	 cy - 10),	Vec2(cx,	 cy + 9),
					Vec2(cx + 1, cy - 9),	Vec2(cx + 1, cy + 8)
				}
    		end

    		-- check vision from player to "enemies", only update position if visible
    		local players = PlayerManager:GetPlayers()
    		for p=1, #players do
    			if (players[p].soldier ~= nil and self.player.teamId ~= players[p].teamId) then

    				local ray = RaycastManager:Raycast(self.playerPos+Vec3.up, (players[p].soldier.worldTransform.trans+Vec3.up), RayCastFlags.CheckDetailMesh | RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.IsAsyncRaycast)
    				
					local posData = {
						Visible = (ray == nil or ray.rigidBody == nil),
						Alive = players[p].soldier.alive
					}

					if (posData.Visible) then
						posData.Position = players[p].soldier.worldTransform.trans
					end

					self.botVisionPlayers[players[p].name] = posData
    			end

    		end
    	end
    end
end


function ClientNodeEditor:_onUIDrawHud()

	if (self.botVisionEnabled) then

		if(self.botVistionCrosshair ~= nil) then
			-- all this for a simple + in the middle of the screen
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[1],	self.botVistionCrosshair[2],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[3],	self.botVistionCrosshair[4],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[5],	self.botVistionCrosshair[6],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[7],	self.botVistionCrosshair[8],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[9],	self.botVistionCrosshair[10],	self.colors.Text)
			DebugRenderer:DrawLine2D(self.botVistionCrosshair[11],	self.botVistionCrosshair[12],	self.colors.Text)
		end

		for k,v in pairs(self.botVisionPlayers) do
			if (v ~= nil and v ~= false and v.Position ~= nil) then
				local screenPos = ClientUtils:WorldToScreen(v.Position + (Vec3.up * 0.3))

				if (screenPos ~= nil) then
					DebugRenderer:DrawText2D(screenPos.x, screenPos.y, k, self.colors.Text, 1)
				end

				local color = self.colors.Text
				
				if (not v.Alive) then
					color = self.colors[1].Line
				else
					if (v.Visible) then
						color = self.colors[4].Line
					end
				end

				DebugRenderer:DrawSphere(v.Position+(Vec3.up*1.5), 0.15, color, false, false)
				DebugRenderer:DrawSphere(v.Position+(Vec3.up*1.0), 0.3, color, false, false)
				DebugRenderer:DrawSphere(v.Position+(Vec3.up*0.3), 0.2, color, false, false)
			end
		end
	end

	-- generic debug values
	local debugText = ''
	self.debugEntries['self.editPositionMode'] = self.editPositionMode

	for k,v in pairs(self.debugEntries) do
		debugText = debugText .. k..': '..tostring(v).."\n"
	end

	DebugRenderer:DrawText2D(20, 20, debugText, self.colors.Text, 1)

	-- dont process waypoints if we're not supposed to see them
	if (not Config.debugTracePaths and not self.botVisionEnabled) then
		return
	end

	-- TODO draw help info?

	-- draw debug selection traces
	if (Config.debugSelectionRaytraces) then
		if (self.lastTraceStart ~= nil and self.lastTraceEnd ~= nil) then
			DebugRenderer:DrawLine(self.lastTraceStart, self.lastTraceEnd, self.colors.Ray.Line[1], self.colors.Ray.Line[2])
		end
		if (self.lastTraceSearchAreaPos ~= nil and self.lastTraceSearchAreaSize ~= nil) then
			DebugRenderer:DrawSphere(self.lastTraceSearchAreaPos, self.lastTraceSearchAreaSize, self.colors.Ray.Node, false, false)
		end
	end

	-- draw the actual waypoints
	for i=1, #self.waypoints do
		local waypoint = self.waypoints[i]
		if (waypoint ~= nil and g_NodeCollection:IsPathVisible(waypoint.PathIndex)) then

			local isSelected = g_NodeCollection:IsSelected(waypoint)

			-- setup node color information
			local color = self.colors[waypoint.PathIndex]
			if (waypoint.Previous == false and waypoint.Next == false) then
				color = self.colors.Orphan
			end


			-- draw the node for the waypoint itself
			if (waypoint.Distance ~= nil and waypoint.Distance < Config.waypointRange) then
				DebugRenderer:DrawSphere(waypoint.Position, 0.05, color.Node, false, false)
			end

			-- if selected draw bigger node and transform helper
			if (waypoint.Distance ~= nil and waypoint.Distance < Config.waypointRange and isSelected) then
				-- node selection indicator
				DebugRenderer:DrawSphere(waypoint.Position, 0.08,  color.Node, false, false)

				-- transform marker
				DebugRenderer:DrawLine(waypoint.Position, waypoint.Position + (Vec3.up * 0.7), self.colors.Red, self.colors.Red)
				DebugRenderer:DrawLine(waypoint.Position, waypoint.Position + (Vec3.right * 0.5), self.colors.Green, self.colors.Green)
				DebugRenderer:DrawLine(waypoint.Position, waypoint.Position + (Vec3.forward * 0.5), self.colors.Blue, self.colors.Blue)
			end

			-- draw connection lines
			if (waypoint.Distance ~= nil and waypoint.Distance < Config.lineRange and Config.drawWaypointLines) then
				-- try to find a previous node and draw a line to it
				if (waypoint.Previous and type(waypoint.Previous) == 'string') then
					waypoint.Previous = g_NodeCollection:Get(waypoint.Previous)
				end

				if (waypoint.Previous) then
					if (waypoint.PathIndex ~= waypoint.Previous.PathIndex) then
						-- draw a white line between nodes on separate paths
						DebugRenderer:DrawLine(waypoint.Previous.Position, waypoint.Position, self.colors.White, self.colors.White)
					else
						-- draw fading line between nodes on same path
						DebugRenderer:DrawLine(waypoint.Previous.Position, waypoint.Position, color.Line, color.Node)
					end
				end
			end

			-- draw debugging text
			if (waypoint.Distance ~= nil and waypoint.Distance < Config.textRange and Config.drawWaypointIDs) then
				if (isSelected) then
					-- don't try to precalc this value like with the distance, another memory leak crash awaits you
					local screenPos = ClientUtils:WorldToScreen(waypoint.Position + (Vec3.up * 0.7))
					if (screenPos ~= nil) then

						local previousNode = tostring(waypoint.Previous)
						local nextNode = tostring(waypoint.Next)
						if (type(waypoint.Previous) == 'table') then
							previousNode = waypoint.Previous.ID
						end
						if (type(waypoint.Next) == 'table') then
							nextNode = waypoint.Next.ID
						end

						local text = tostring(previousNode)..' <-- |'..tostring(waypoint.ID)..'| --> '..tostring(nextNode).."\n"
						text = text..'self.waypoints Index: '..tostring(i).."\n"
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
function ClientNodeEditor:Raycast(maxDistance, useAsync)
	if self.player == nil then
		return
	end
	maxDistance = maxDistance or 100

	-- We get the camera transform, from which we will start the raycast. We get the direction from the forward vector. Camera transform
	-- is inverted, so we have to invert this vector.
	local transform = ClientUtils:GetCameraTransform()
	local direction = Vec3(-transform.forward.x, -transform.forward.y, -transform.forward.z)

	if transform.trans == Vec3.zero then
		return
	end

	local castStart = transform.trans

	-- We get the raycast end transform with the calculated direction and the max distance.
	local castEnd = Vec3(
		transform.trans.x + (direction.x * maxDistance),
		transform.trans.y + (direction.y * maxDistance),
		transform.trans.z + (direction.z * maxDistance))

	-- Perform raycast, returns a RayCastHit object.

	local flags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh
	if (useAsync) then
		flags = flags | RayCastFlags.IsAsyncRaycast
	end

	local raycastHit = RaycastManager:Raycast(castStart, castEnd, flags)

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