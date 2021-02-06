nodeCollection = require('__shared/NodeCollection')

-- send to players when they spawn
Events:Subscribe('Player:Respawn', function(player)
	NetEvents:SendToLocal('NodeEditor:Clear', player)
	for id, waypoint in pairs(nodeCollection:Get()) do
		NetEvents:SendToLocal('NodeEditor:Add', player, waypoint)
	end
	NetEvents:SendToLocal('NodeEditor:ClientInit', player)
end)

-- load waypoints from sql
Events:Subscribe('Level:Loaded', function(levelName, gameMode)
	print('Level:Loaded')
	nodeCollection:Load(levelName .. '_TeamDeathMatch0')
end)