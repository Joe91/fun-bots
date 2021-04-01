class('SpawnSet');

function SpawnSet:__init()
	self.playerVarOfBot 	= nil;
	self.useRandomWay 		= true;
	self.activeWayIndex 	= 0;
	self.indexOnPath 		= 1;
	self.team				= nil;
end

return SpawnSet;