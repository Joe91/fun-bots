class('WayPoint')

function WayPoint:__init()
    self.trans = Vec3()
    self.inputVar = 0x0
end

function WayPoint:setValues(x, y, z, invar)
    self.trans.x = x
    self.trans.y = y
    self.trans.z = z
    self.inputVar = invar
end

return WayPoint