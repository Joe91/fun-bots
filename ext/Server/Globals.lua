class('Globals');

function Globals:__init()
	self.wayPoints			= {};
	self.activeTraceIndexes	= 0;
	self.yawPerFrame 		= 0.0;
	self.isTdm				= false;
	self.isScavenger		= false;
	self.isGm				= false;
	self.maxPlayers			= 0;

	self.respawnWayBots 	= false;	--used for the runtime respawn
	self.attackWayBots 		= false;	--used for the runtime attack
	self.spawnmMode			= "manual"	--used for the runtime spawnmode
end

-- Singleton.
if g_Globals == nil then
	g_Globals = Globals();
end

return g_Globals;