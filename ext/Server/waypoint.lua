class('WayPoint')

function WayPoint:__init()
    self.trans = Vec3()
    self.speedMode = 0
    self.extraMode = 0
    self.optValue = 0
end

return WayPoint