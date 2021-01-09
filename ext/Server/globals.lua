class('Globals')

function Globals:__init()
	self.wayPoints = {}
	self.activeTraceIndexes = 0
	self.botTeam = TeamId.Team2
end

-- Singleton.
if g_Globals == nil then
	g_Globals = Globals()
end

return g_Globals