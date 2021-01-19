class('Globals');

function Globals:__init()
	self.wayPoints			= {};
	self.activeTraceIndexes	= 0;

	self.botTeam 			= 0;		--used for the runtime botTeam
	self.respawnWayBots 	= false;	--used for the runtime respawn
	self.attackWayBots 		= false;	--used for the runtime attack
end

-- Singleton.
if g_Globals == nil then
	g_Globals = Globals();
end

return g_Globals;