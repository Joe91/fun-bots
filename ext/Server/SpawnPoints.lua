---@class SpawnPoints
---@overload fun():SpawnPoints
SpawnPoints = class('SpawnPoints')

-- Where the game spawns the soldiers of the running mode: the alternate spawns (AlternateSpawnEntityData) of the layers
-- of the mode, collected while the level loads them (as ClientSpawnPointHelper). Only the partitions of the layers of the
-- mode ("levels/mp_012/rush/layer0_base1"): the level loads its common layers for every mode
-- ("levels/mp_012/mp_012/layer15_cq_t1_common_spawnpoints", spawns of conquest also in rush), those count only where
-- the layer of the mode links them (census, MapCensus._AlternateSpawns). Rush: the stage is in the name of the layer
-- ("base1", "base_2").
-- A mod reloaded within a level has none until the next level.

---@class SpawnPoint
---@field Position Vec3
---@field Team integer TeamId, 0: whoever holds the capture point
---@field Stage integer|nil rush
---@field Partition string

function SpawnPoints:__init()
	---@type SpawnPoint[]
	self._Points = {}
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
end

---Whether the partition is a layer of the running mode: "levels/<level>/<mode>/...", not the common folder of the level
---("levels/<level>/<level>/...") and not a blueprint (vehicles carry spawns too).
---@param p_Name string
---@return boolean
local function _IsModeLayer(p_Name)
	local s_Level, s_Folder = p_Name:lower():match('^levels/([^/]+)/([^/]+)/')
	return s_Level ~= nil and s_Folder ~= s_Level
end

---@param p_Partition DatabasePartition
function SpawnPoints:OnPartitionLoaded(p_Partition)
	if not _IsModeLayer(p_Partition.name) then
		return
	end
	for _, l_Instance in pairs(p_Partition.instances) do
		if l_Instance:Is('AlternateSpawnEntityData') then
			local s_Data = AlternateSpawnEntityData(l_Instance)
			local s_Ok, s_Team = pcall(function() return s_Data.team end)
			self._Points[#self._Points + 1] = {
				-- Clone it, the transform of the instance points into the memory of the partition.
				Position = s_Data.transform.trans:Clone(),
				Team = s_Ok and s_Team or 0,
				Stage = tonumber(p_Partition.name:lower():match('base_?(%d+)')),
				Partition = p_Partition.name,
			}
		end
	end
end

function SpawnPoints:OnLevelDestroy()
	self._Points = {}
end

---@return SpawnPoint[]
function SpawnPoints:GetAll()
	return self._Points
end

---The spawn of the team closest to the position (horizontally), and its distance.
---@param p_Position Vec3
---@param p_Team integer
---@return SpawnPoint|nil, number
function SpawnPoints:Closest(p_Position, p_Team)
	local s_Best = nil
	local s_BestDistance = math.huge
	for l_Index = 1, #self._Points do
		local l_Point = self._Points[l_Index]
		if l_Point.Team == p_Team then
			local s_DeltaX = l_Point.Position.x - p_Position.x
			local s_DeltaZ = l_Point.Position.z - p_Position.z
			local s_Distance = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
			if s_Distance < s_BestDistance then
				s_Best = l_Point
				s_BestDistance = s_Distance
			end
		end
	end
	return s_Best, s_BestDistance
end

if g_SpawnPoints == nil then
	---@type SpawnPoints
	g_SpawnPoints = SpawnPoints()
end

return g_SpawnPoints
