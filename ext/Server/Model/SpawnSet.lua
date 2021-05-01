class('SpawnSet')

function SpawnSet:__init()
	self.m_PlayerVarOfBot = nil
	self.m_UseRandomWay = true
	self.m_ActiveWayIndex = 0
	self.m_IndexOnPath = 1
	self.m_Team = nil
end

return SpawnSet
