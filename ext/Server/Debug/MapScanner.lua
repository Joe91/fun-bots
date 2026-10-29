---@class MapScanner
---@overload fun():MapScanner
MapScanner = class('MapScanner')

-- Scans an area of the map with vertical raycasts: height and surface-normal of the ground on a grid.
-- First step towards generated nav-meshes. Runs as task of the DebugBridge, spread over several updates, and
-- streams every finished row as event:
--   { type = "scan_row", scan, row, z, x0, step, heights = { y | false }, normals = { ny | false } }
-- With layers > 1 heights[i] / normals[i] are lists (top down): the ray continues below every hit, so bridges,
-- floors of buildings and tunnels get found as well. Experimental, depends on how the engine hits the geometry
-- from inside.

-- Protects the server from typos in the area. 2000 x 2000 cells.
local MAX_CELLS = 4000000
-- The ray continues this far below a hit to find the next layer.
local LAYER_GAP = 0.3
-- Every material ends the ray.
---@type MaterialFlags|integer
local NO_MATERIAL_FLAGS = 0

---@class MapScanTask
---@field CommandId any
---@field ScanId integer
---@field X0 number
---@field Z0 number
---@field Step number
---@field Columns integer
---@field Rows integer
---@field Top number
---@field Bottom number
---@field Layers integer
---@field PerUpdate integer raycasts per update
---@field Flags RayCastFlags|integer
---@field Row integer
---@field Column integer
---@field Heights table
---@field Normals table
---@field Raycasts integer
local MapScanTask = {}
MapScanTask.__index = MapScanTask

function MapScanner:__init()
	self._NextScanId = 1
end

---@param p_Bridge DebugBridge
---@param p_CommandId any
---@param p_Args table { x0, z0, x1, z1, step = 2, top = 1000, bottom = -200, layers = 1, perUpdate = 100, water = false, detailed = false }
---@return table info about the scan
function MapScanner:Start(p_Bridge, p_CommandId, p_Args)
	local s_X0 = tonumber(p_Args.x0)
	local s_Z0 = tonumber(p_Args.z0)
	local s_X1 = tonumber(p_Args.x1)
	local s_Z1 = tonumber(p_Args.z1)
	if s_X0 == nil or s_Z0 == nil or s_X1 == nil or s_Z1 == nil then
		error('scan needs x0, z0, x1, z1')
	end

	local s_Step = math.max(0.25, tonumber(p_Args.step) or 2.0)
	local s_Columns = math.floor(math.abs(s_X1 - s_X0) / s_Step) + 1
	local s_Rows = math.floor(math.abs(s_Z1 - s_Z0) / s_Step) + 1
	if s_Columns * s_Rows > MAX_CELLS then
		error('scan too big: ' .. s_Columns .. ' x ' .. s_Rows .. ' cells, max ' .. MAX_CELLS)
	end

	local s_Flags = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll
	if not p_Args.water then
		s_Flags = s_Flags | RayCastFlags.DontCheckWater
	end
	if p_Args.detailed then
		s_Flags = s_Flags | RayCastFlags.CheckDetailMesh
	end

	local s_Task = setmetatable({
		CommandId = p_CommandId,
		ScanId = self._NextScanId,
		X0 = math.min(s_X0, s_X1),
		Z0 = math.min(s_Z0, s_Z1),
		Step = s_Step,
		Columns = s_Columns,
		Rows = s_Rows,
		Top = tonumber(p_Args.top) or 1000.0,
		Bottom = tonumber(p_Args.bottom) or -200.0,
		Layers = math.max(1, math.floor(tonumber(p_Args.layers) or 1)),
		PerUpdate = math.max(1, math.floor(tonumber(p_Args.perUpdate) or 100)),
		Flags = s_Flags,
		Row = 0,
		Column = 0,
		Heights = {},
		Normals = {},
		Raycasts = 0,
	}, MapScanTask)
	self._NextScanId = self._NextScanId + 1

	p_Bridge:AddTask(s_Task)
	p_Bridge:Event('scan_started', {
		scan = s_Task.ScanId,
		x0 = s_Task.X0,
		z0 = s_Task.Z0,
		step = s_Step,
		columns = s_Columns,
		rows = s_Rows,
		layers = s_Task.Layers,
	})

	return { scan = s_Task.ScanId, columns = s_Columns, rows = s_Rows }
end

---@param p_Bridge DebugBridge
---@param p_ScanId? integer nil = all scans
---@return integer stopped scans
function MapScanner:Stop(p_Bridge, p_ScanId)
	return p_Bridge:AbortTasks(function(p_Task)
		return getmetatable(p_Task) == MapScanTask and (p_ScanId == nil or p_Task.ScanId == p_ScanId)
	end, 'stopped')
end

---Raycasts one column from the top down.
---@return number|boolean|table height
---@return number|boolean|table normal-y
function MapScanTask:_ScanColumn(p_X, p_Z)
	local s_Top = self.Top
	local s_Heights = nil
	local s_Normals = nil

	for _ = 1, self.Layers do
		local s_Hits = RaycastManager:CollisionRaycast(Vec3(p_X, s_Top, p_Z), Vec3(p_X, self.Bottom, p_Z), 1,
			NO_MATERIAL_FLAGS, self.Flags --[[@as RayCastFlags]])
		self.Raycasts = self.Raycasts + 1
		local s_Hit = s_Hits[1]
		if s_Hit == nil then
			break
		end

		local s_Height = DebugBridge.Round(s_Hit.position.y)
		local s_NormalY = DebugBridge.Round(s_Hit.normal.y, 3)
		if self.Layers == 1 then
			return s_Height, s_NormalY
		end

		s_Heights = s_Heights or {}
		s_Normals = s_Normals or {}
		s_Heights[#s_Heights + 1] = s_Height
		s_Normals[#s_Normals + 1] = s_NormalY
		s_Top = s_Hit.position.y - LAYER_GAP
		if s_Top <= self.Bottom then
			break
		end
	end

	-- JSON-arrays can't hold nil.
	return s_Heights or false, s_Normals or false
end

---@param p_Bridge DebugBridge
---@return boolean done
function MapScanTask:Update(p_Bridge)
	for _ = 1, self.PerUpdate do
		local s_Z = self.Z0 + self.Row * self.Step
		local s_Height, s_Normal = self:_ScanColumn(self.X0 + self.Column * self.Step, s_Z)
		self.Column = self.Column + 1
		self.Heights[self.Column] = s_Height
		self.Normals[self.Column] = s_Normal

		if self.Column >= self.Columns then
			p_Bridge:Event('scan_row', {
				scan = self.ScanId,
				row = self.Row,
				z = DebugBridge.Round(s_Z),
				x0 = self.X0,
				step = self.Step,
				heights = self.Heights,
				normals = self.Normals,
			})
			self.Heights = {}
			self.Normals = {}
			self.Column = 0
			self.Row = self.Row + 1

			if self.Row >= self.Rows then
				p_Bridge:Reply(self.CommandId, true, { scan = self.ScanId, raycasts = self.Raycasts })
				return true
			end
		end
	end

	return false
end

---@param p_Bridge DebugBridge
---@param p_Reason string
function MapScanTask:Abort(p_Bridge, p_Reason)
	p_Bridge:Reply(self.CommandId, false, 'scan ' .. self.ScanId .. ' aborted: ' .. p_Reason)
end

if g_MapScanner == nil then
	---@type MapScanner
	g_MapScanner = MapScanner()
end

return g_MapScanner
