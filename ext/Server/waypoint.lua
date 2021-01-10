class('WayPoint')

function WayPoint:__init()
    self.trans = Vec3()
    self.speedMode = 0
    self.extraMode = 0
    self.optValue = 0
end

function WayPoint:setValues(x, y, z, speed, extra, value)
    self.trans.x = x
    self.trans.y = y
    self.trans.z = z
    self.speedMode = speed
    self.extraMode = extra
    self.optValue = value
end

function WayPoint:setWithInputVar(x, y, z, inputVar)
    self.trans.x = x
    self.trans.y = y
    self.trans.z = z
    self.speedMode = inputVar & 0xF
    self.extraMode = (inputVar >> 4) & 0xF
    self.optValue = (inputVar >> 8) & 0xFF
end

function WayPoint:getInputVar()
    return (self.speedMode & 0xF) + ((self.extraMode & 0xF)<<4) + ((self.optValue & 0xFF) <<8)
end

return WayPoint