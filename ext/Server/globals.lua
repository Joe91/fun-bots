class('Globals')

function Globals:__init()
	self.wayPoints = {}
end

-- Singleton.
if g_Globals == nil then
	g_Globals = Globals()
end

return g_Globals