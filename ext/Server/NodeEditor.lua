class "NodeEditor"

require('__shared/NodeCollection')

function NodeEditor:__init()
	self:RegisterEvents()
end

function NodeEditor:RegisterEvents()
	NetEvents:Subscribe('NodeEditor:GetNodes', self, self._onGetNodes)
	NetEvents:Subscribe('UI_Request_Save_Settings', self, self._onUIRequestSaveSettings)
	Events:Subscribe('Level:Loaded', self, self._onLevelLoaded)
end

-- send to players when they spawn
function NodeEditor:_onGetNodes(player)
	NetEvents:SendToLocal('NodeEditor:Clear', player)
	for id, waypoint in pairs(g_NodeCollection:Get()) do
		NetEvents:SendToLocal('NodeEditor:Add', player, waypoint)
	end
	NetEvents:SendToLocal('NodeEditor:ClientInit', player)
end

-- load waypoints from sql
function NodeEditor:_onLevelLoaded(levelName, gameMode)
	print('NodeEditor:_onLevelLoaded -> '.. levelName..'_'..gameMode)
	g_NodeCollection:Load(levelName .. '_TeamDeathMatch0')
end

function NodeEditor:_onUIRequestSaveSettings(player, data)
	if Config.disableUserInterface == true then
		return
	end

	if (Config.settingsPassword ~= nil and g_FunBotUIServer:_isAuthenticated(player.accountGuid) ~= true) then
		return;
	end

	local request = json.decode(data);

	if (request.debugTracePaths) then
		-- enabled, send them a fresh list
		self:_onGetNodes(player)
	else
		-- disabled, delete the client's list
		NetEvents:SendToLocal('NodeEditor:Clear', player)
		NetEvents:SendToLocal('NodeEditor:ClientInit', player)
	end
end

if (g_NodeEditor == nil) then
	g_NodeEditor = NodeEditor()
end

return g_NodeEditor