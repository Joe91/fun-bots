-- update L0, called every tick
function Bot:UpdatePrecheck()
	self.m_ActiveState.UpdatePrecheck(self.m_ActiveState, self)
end

function Bot:UpdateL0()
	self.m_ActiveState.UpdateVeryFast(self.m_ActiveState, self)
end

-- very fast Bot-Code
function Bot:UpdateL1(p_DeltaTime)
	self.m_ActiveState.UpdateFast(self.m_ActiveState, self, p_DeltaTime)
end

-- normal fast Bot-Code
function Bot:UpdateL2(p_DeltaTime)
	self.m_ActiveState.Update(self.m_ActiveState, self, p_DeltaTime)
end

-- slow Bot-Code TODO: fill some slow stuff here
function Bot:UpdateL3(p_DeltaTime)
	self.m_ActiveState.UpdateSlow(self.m_ActiveState, self, p_DeltaTime)
end
