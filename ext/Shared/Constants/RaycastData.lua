---@class RaycastResults
---@field Bot1 integer
---@field Bot2 integer
---@field IgnoreYaw boolean
---@field Mode RaycastResultModes

---@class RaycastRequests
---@field Bot1 integer
---@field Bot2 integer
---@field Bot1InVehicle boolean
---@field Bot2InVehicle boolean

---@enum RaycastResultModes
RaycastResultModes = {
	ShootAtBot = 0,
	ShootAtPlayer = 1,
	RevivePlayer = 2
}
