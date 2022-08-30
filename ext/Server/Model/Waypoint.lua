---@class WayPoint
WayPoint = {}

function WayPoint:__init()
	self.m_Trans = Vec3()
	self.m_SpeedMode = 0
	self.m_ExtraMode = 0
	self.m_OptValue = 0
	self.m_Data = {}
end

return WayPoint
