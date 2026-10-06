---@class MapCensus
---@overload fun():MapCensus
MapCensus = class('MapCensus')

-- Collects in one run everything about the running level that the tools for the waypoints need
-- (tools/debug-server/funbots_debug/census). Runs as task of the DebugBridge, spread over several updates, and streams
-- the result as events. The debug-server puts them together and saves them as census/<level>_<mode>.json.gz.
--   census_started   { census, level, mode, paths, parts }
--   census_entities  { census, data }  capture points, spawns, vehicle spawns, combat areas, mcoms, entity types
--   census_nodes     { census, path, first, last, loops, points, inputs, ground, normal, water, ceiling, left, right,
--                      next, nextHit, links, actions, objectives, vehicles }  one part of a path, see CensusTask:_ProbeNode
--   census_area      { census, area, name, kind, center, radius, x0, z0, step, columns, rows, layers, spawns, discs }
--   census_area_row  { census, area, row, cells }  see CensusTask:_ProbeCell
--   census_done      { census, raycasts, seconds, nodes, cells }
-- All raycasts ignore soldiers, every other material (also glass and fences) ends them. Vehicles standing around
-- block them as well, nextHit tells which entity was hit.

---@type DebugSnapshots
local m_DebugSnapshots = require('Debug/DebugSnapshots')
---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type Utilities
local m_Utilities = require('__shared/Utilities')
---@type SpawnPoints
local m_SpawnPoints = require('SpawnPoints')

local _Vec = DebugBridge.Vec
local _Round = DebugBridge.Round

---@type MaterialFlags|integer
local NO_MATERIAL_FLAGS = 0
local RAY_FLAGS = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.DontCheckWater
local RAY_FLAGS_WATER = RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll

-- Waypoints. All heights are above the ground below the waypoint (or the waypoint, if there is no ground).
local GROUND_UP = 1.0             -- The ground-ray starts this far above the waypoint...
local GROUND_DOWN = 4.0           -- ...and ends this far below it.
local GROUND_COVER = 0.3          -- A hit higher above the waypoint is something over it, not its ground.
local CEILING_MAX = 3.0           -- Headroom is measured up to this height.
local CLEARANCE_HEIGHTS = { 0.6, 1.3 } -- Knee and chest.
local CLEARANCE_MAX = 4.0         -- Free space to the sides is measured up to this distance.
local SEGMENT_HEIGHTS = { 0.4, 1.0, 1.6 } -- Prone, crouched, standing: rays to the next waypoint and along links.
local MIN_LINK_LENGTH = 1.0       -- Shorter links are not checked.
local NODES_PER_EVENT = 250

-- Grids around the objectives.
local AREA_MARGIN = 15.0          -- Metres around the capture-radius.
local AREA_MCOM_RADIUS = 30.0
local AREA_SPAWN_MARGIN = 8.0     -- Areas around the spawns of the game that no other area covers: this far around the
local AREA_SPAWN_MERGE = 40.0     -- outer spawns of a group, one group for spawns this close to each other.
local AREA_SPAWN_COVERED = 2.0    -- A spawn at least this far inside of another area is covered by it.
local AREA_WAY_RADIUS = 12.0      -- The way from a group of spawns to its target: discs of this radius...
local AREA_WAY_STEP = 8.0         -- ...this far apart along the straight line...
local AREA_WAY_INTO = 10.0        -- ...up to this far into the area of the target.
local AREA_HUB_MARGIN = 8.0       -- Hubs (ends of foot paths outside of the zones): this far around the outer ends of a
local AREA_HUB_MERGE = 30.0       -- group, one group for ends this close to each other...
local AREA_HUB_COVERED = 5.0      -- ...an end at least this far inside of another area is covered.
local AREA_SPAWN_GROUND = 200.0   -- The ground below a spawn is searched this far down.
local AREA_CORRIDOR_RADIUS = 5.0  -- Corridors along the foot paths outside of the other areas: discs of this radius...
local AREA_CORRIDOR_STEP = 6.0    -- ...this far apart along the path...
local AREA_CORRIDOR_DISCS = 8     -- ...at most this many per area (a long path gets several)...
local AREA_CORRIDOR_HEIGHT = 12.0 -- ...the vertical rays from this far above the highest waypoint to below the lowest.
local AREA_STEP = 0.5
local AREA_LAYERS = 4
local AREA_UP = 60.0              -- The vertical rays start this far above the objective...
local AREA_DOWN = 30.0            -- ...and end this far below it.
local LAYER_GAP = 0.3             -- The ray continues this far below a hit to find the next layer.
local WALKABLE_NORMAL_Y = 0.5     -- Surfaces up to 60° get edges and headroom, steeper ones are walls.
local WADE_DEPTH = 1.3            -- Ground under more water than this isn't walked on (the soldier swims, report.py).
-- Rays to the neighbour-cells (+x, +z) and back from them, as bits: 1 +x knee, 2 +x chest, 4 +z knee, 8 +z chest, 16 to 128
-- the same from the neighbour back. Both ways: a ray that starts inside of a rock doesn't hit it.
local EDGE_HEIGHTS = { 0.6, 1.3 }

-- Time per update for the raycasts, in ms.
local BUDGET_MS = 6.0
-- Entity-types that are listed with their position, matched as part of the type-name.
local DUMP_TYPES = { 'Ladder', 'Mcom', 'MCOM', 'Objective', 'Zipline', 'Door', 'Interaction' }
local MAX_DUMP_PER_TYPE = 300

---@class CensusTask
---@field CommandId any
---@field Census integer
---@field Parts table<string, boolean>
---@field BudgetMs number
---@field Args table
---@field Phase string entities -> nodes -> areas
---@field Raycasts integer
---@field NodeCount integer
---@field CellCount integer
---@field StartMs number
---@field Chunk table|nil the census_nodes-event being filled
---@field Paths table
---@field PathIndices integer[]
---@field PathSlot integer
---@field Point integer
---@field SeenLinks table<string, boolean>
---@field Areas table
---@field AreaSlot integer
---@field Area table|nil
local CensusTask = {}
CensusTask.__index = CensusTask

function MapCensus:__init()
	self._NextCensus = 1
end

---@return number milliseconds
local function _NowMs()
	return SharedUtils:GetTimeNS() / 1000000
end

---Calls p_Callback for every entity of the type.
---@param p_Type string
---@param p_Callback fun(p_Entity: Entity)
local function _Iterate(p_Type, p_Callback)
	local s_Iterator = EntityManager:GetIterator(p_Type)
	local s_Entity = s_Iterator:Next()
	while s_Entity ~= nil do
		p_Callback(s_Entity)
		s_Entity = s_Iterator:Next()
	end
end

---@param p_Transform LinearTransform
---@return table
local function _Transform(p_Transform)
	return {
		trans = _Vec(p_Transform.trans),
		left = _Vec(p_Transform.left),
		up = _Vec(p_Transform.up),
		forward = _Vec(p_Transform.forward),
	}
end

---@param p_Container DataContainer|nil
---@return string|nil
local function _TypeName(p_Container)
	return p_Container ~= nil and p_Container.typeInfo.name or nil
end

-- =============================================
-- Entities
-- =============================================

---A value of a field as plain JSON: numbers, strings and booleans as they are, vectors as positions, other objects as
---their type-name, lists as their length.
---@param p_Value any
---@return any
local function _Plain(p_Value)
	local s_Type = type(p_Value)
	if s_Type == 'number' then
		return _Round(p_Value, 3)
	elseif s_Type == 'string' or s_Type == 'boolean' then
		return p_Value
	elseif s_Type ~= 'userdata' then
		return tostring(p_Value)
	end
	local s_Ok, s_Result = pcall(function()
		if p_Value.x ~= nil and p_Value.y ~= nil and p_Value.z ~= nil then
			return _Vec(p_Value)
		elseif p_Value.trans ~= nil then
			return { trans = _Vec(p_Value.trans) }
		elseif p_Value.typeInfo ~= nil then
			return '<' .. p_Value.typeInfo.name .. '>'
		end
		return '<' .. #p_Value .. ' entries>'
	end)
	return s_Ok and s_Result or tostring(p_Value)
end

---All fields of a (cast) data-container and its super-types, for finding out where the engine keeps something.
---@param p_Container any
---@return table<string, any>
local function _Fields(p_Container)
	local s_Result = {}
	local s_Type = p_Container.typeInfo
	-- The chain of super-types doesn't reliably end with nil: at most 8 steps, and never the same type twice.
	local s_Seen = {}
	for _ = 1, 8 do
		if s_Type == nil or s_Seen[s_Type.name] then
			break
		end
		s_Seen[s_Type.name] = true
		local s_Fields = s_Type.fields
		for l_Index = 1, #s_Fields do
			local s_Name = s_Fields[l_Index].name
			local s_Key = s_Name:sub(1, 1):lower() .. s_Name:sub(2)
			local s_Ok, s_Value = pcall(function() return p_Container[s_Key] end)
			if s_Ok and s_Value ~= nil then
				s_Result[s_Name] = _Plain(s_Value)
			end
		end
		s_Type = s_Type.super
	end
	return s_Result
end


---The ground below the position (first hit up to AREA_SPAWN_GROUND below), else the position itself.
---@param p_Position Vec3
---@return Vec3
local function _Ground(p_Position)
	local s_Hit = RaycastManager:CollisionRaycast(p_Position + Vec3(0, 1, 0), p_Position - Vec3(0, AREA_SPAWN_GROUND, 0), 1,
		NO_MATERIAL_FLAGS, RAY_FLAGS)[1]
	if s_Hit == nil then
		return p_Position
	end
	return s_Hit.position:Clone()
end

local function _CharacterSpawns()
	local s_Result = {}
	_Iterate('ServerCharacterSpawnEntity', function(p_Entity)
		local s_Spawn = SpawnEntity(p_Entity)
		local s_Entry = {
			id = p_Entity.instanceId,
			pos = _Vec(s_Spawn.transform.trans),
			team = s_Spawn.teamId,
			enabled = s_Spawn.enabled,
		}

		if p_Entity.data ~= nil and p_Entity.data:Is('CharacterSpawnReferenceObjectData') then
			local s_Data = CharacterSpawnReferenceObjectData(p_Entity.data)
			s_Entry.dataTeam = s_Data.team
			s_Entry.radius = _Round(s_Data.spawnAreaRadius)
			s_Entry.playerType = s_Data.playerType
		end

		-- A spawn with a vehicle-spawn on its bus puts the soldier into that vehicle.
		local s_Bus = p_Entity.bus
		if s_Bus ~= nil then
			for l_Index = 1, #s_Bus.entities do
				local l_Entity = s_Bus.entities[l_Index]
				if l_Entity:Is('ServerVehicleSpawnEntity') then
					s_Entry.vehicleSpawn = l_Entity.instanceId
					break
				end
			end
		end

		s_Result[#s_Result + 1] = s_Entry
	end)
	return s_Result
end

---Where the soldiers of the running mode really spawn: the alternate spawns (AlternateSpawnEntityData) of the layers of
---the mode (SpawnPoints.lua) and the ones the level links to the layer of the mode (the ReferenceObjectData above the
---spawn-entities; spawns of the common layers of the level). A capture point spawns its team there, up to 70 m from the
---flag, not at its spawn-entity.
---@return table[] { pos, ground, team }
local function _AlternateSpawns()
	local s_Result = {}
	local s_SeenPositions = {}
	local s_SeenRepresentatives = {}

	---@param p_Position Vec3
	---@param p_Team integer|nil
	---@param p_Source string
	local function _AddAt(p_Position, p_Team, p_Source)
		-- The spawns of prefabs (the vehicles on MP_018) have their position in the prefab: about the origin of the level.
		if math.abs(p_Position.x) < 1.0 and math.abs(p_Position.y) < 1.0 and math.abs(p_Position.z) < 1.0 then
			return
		end
		local s_Key = string.format('%.1f %.1f %.1f', p_Position.x, p_Position.y, p_Position.z)
		if not s_SeenPositions[s_Key] then
			s_SeenPositions[s_Key] = true
			s_Result[#s_Result + 1] = {
				pos = _Vec(p_Position),
				ground = _Vec(_Ground(p_Position)),
				team = p_Team,
				source = p_Source,
			}
		end
	end

	---@param p_Spawn DataContainer
	local function _Add(p_Spawn)
		local s_Data = AlternateSpawnEntityData(p_Spawn)
		local s_Ok, s_Team = pcall(function() return s_Data.team end)
		_AddAt(s_Data.transform.trans, s_Ok and s_Team or nil, 'link')
	end

	---@param p_Representative DataContainer
	local function _Collect(p_Representative)
		local s_Instances = p_Representative.partition.instances
		for l_Index = 1, #s_Instances do
			local l_Instance = s_Instances[l_Index]
			if l_Instance:Is('DataBusData') then
				local s_Links = DataBusData(l_Instance).linkConnections
				for l_LinkIndex = 1, #s_Links do
					local l_Link = s_Links[l_LinkIndex]
					local s_Other = nil
					if l_Link.source ~= nil and l_Link.source:Eq(p_Representative) then
						s_Other = l_Link.target
					elseif l_Link.target ~= nil and l_Link.target:Eq(p_Representative) then
						s_Other = l_Link.source
					end
					if s_Other ~= nil and s_Other:Is('AlternateSpawnEntityData') then
						_Add(s_Other)
					end
				end
			end
		end
	end

	local s_Layers = m_SpawnPoints:GetAll()
	if #s_Layers == 0 then
		print('[MapCensus] no alternate spawns of the layers: the mod was reloaded within the level, load it again')
	end
	for l_Index = 1, #s_Layers do
		_AddAt(s_Layers[l_Index].Position, s_Layers[l_Index].Team, s_Layers[l_Index].Partition)
	end
	_Iterate('ServerCharacterSpawnEntity', function(p_Entity)
		local s_Bus = p_Entity.bus
		local s_Depth = 0
		while s_Bus ~= nil and s_Depth < 6 do
			local s_Representative = s_Bus.parentRepresentative
			if s_Representative ~= nil and s_Representative.partition ~= nil then
				local s_Key = tostring(s_Representative.instanceGuid)
				if not s_SeenRepresentatives[s_Key] then
					s_SeenRepresentatives[s_Key] = true
					_Collect(s_Representative)
				end
			end
			s_Bus = s_Bus.parent
			s_Depth = s_Depth + 1
		end
	end)
	return s_Result
end

---The spawns of the game (for the debug-command "spawns").
---@return table
function MapCensus:EngineSpawns()
	return {
		spawns = _CharacterSpawns(),
		alternateSpawns = _AlternateSpawns(),
	}
end

local function _VehicleSpawns()
	local s_Result = {}
	_Iterate('ServerVehicleSpawnEntity', function(p_Entity)
		local s_Spawn = SpawnEntity(p_Entity)
		local s_Transform = s_Spawn.transform
		local s_Entry = {
			id = p_Entity.instanceId,
			pos = _Vec(s_Transform.trans),
			forward = _Vec(s_Transform.forward),
			team = s_Spawn.teamId,
			enabled = s_Spawn.enabled,
		}

		if p_Entity.data ~= nil and p_Entity.data:Is('VehicleSpawnReferenceObjectData') then
			local s_Data = VehicleSpawnReferenceObjectData(p_Entity.data)
			s_Entry.dataTeam = s_Data.team
			-- As BotSpawner:_CheckForSpawnableJet.
			s_Entry.blueprint = s_Data.blueprint ~= nil and s_Data.blueprint.name or nil
		end

		s_Result[#s_Result + 1] = s_Entry
	end)
	return s_Result
end

---@param p_Shape DataContainer a VolumeVectorShapeData
---@return table
local function _ShapeEntry(p_Shape)
	local s_Shape = VolumeVectorShapeData(p_Shape)
	local s_Points = {}
	for l_Index = 1, #s_Shape.points do
		s_Points[#s_Points + 1] = _Vec(s_Shape.points[l_Index])
	end
	return { points = s_Points, height = _Round(s_Shape.height), closed = s_Shape.isClosed }
end

---The shapes (VolumeVectorShapeData) linked to the data of an entity, searched in the blueprint of its bus and the
---ones above. Without a shape the diagnostics tell what was found on the way.
---@param p_Entity Entity
---@return table shapes, table diagnostics { levels = { { type, links, linked, objects, shapeObjects } }, partition }
local function _LinkedShapes(p_Entity)
	local s_Shapes = {}
	local s_Levels = {}
	local s_Data = p_Entity.data
	local s_Bus = p_Entity.bus

	while s_Bus ~= nil and #s_Levels < 4 and #s_Shapes == 0 do
		local s_BusData = s_Bus.data
		local s_Level = { type = _TypeName(s_BusData) }
		if s_BusData ~= nil and s_Data ~= nil and s_BusData:Is('DataBusData') then
			local s_Links = DataBusData(s_BusData).linkConnections
			local s_Linked = {}
			s_Level.links = #s_Links
			for l_Index = 1, #s_Links do
				local l_Link = s_Links[l_Index]
				local s_Other = nil
				if l_Link.source ~= nil and l_Link.source:Eq(s_Data) then
					s_Other = l_Link.target
				elseif l_Link.target ~= nil and l_Link.target:Eq(s_Data) then
					s_Other = l_Link.source
				end
				if s_Other ~= nil then
					if s_Other:Is('VolumeVectorShapeData') then
						s_Shapes[#s_Shapes + 1] = _ShapeEntry(s_Other)
					elseif #s_Linked < 10 then
						s_Linked[#s_Linked + 1] = _TypeName(s_Other)
					end
				end
			end
			s_Level.linked = s_Linked
		end
		if s_BusData ~= nil and s_BusData:Is('PrefabBlueprint') then
			local s_Objects = PrefabBlueprint(s_BusData).objects
			local s_ShapeObjects = 0
			for l_Index = 1, #s_Objects do
				if s_Objects[l_Index]:Is('VolumeVectorShapeData') then
					s_ShapeObjects = s_ShapeObjects + 1
				end
			end
			s_Level.objects = #s_Objects
			s_Level.shapeObjects = s_ShapeObjects
		end
		s_Levels[#s_Levels + 1] = s_Level
		s_Bus = s_Bus.parent
	end

	-- The prefab of the entity gets its shapes from outside: the level links them to the ReferenceObjectData that
	-- places the prefab (the parentRepresentative of a bus), in a blueprint of the partition of that.
	s_Bus = p_Entity.bus
	local s_Outer = {}
	while s_Bus ~= nil and #s_Outer < 4 and #s_Shapes == 0 do
		local s_Representative = s_Bus.parentRepresentative
		if s_Representative ~= nil and s_Representative.partition ~= nil then
			local s_Entry = { type = _TypeName(s_Representative), partition = s_Representative.partition.name, linked = {} }
			local s_Instances = s_Representative.partition.instances
			for l_Index = 1, #s_Instances do
				local l_Instance = s_Instances[l_Index]
				if l_Instance:Is('DataBusData') then
					local s_Links = DataBusData(l_Instance).linkConnections
					for l_LinkIndex = 1, #s_Links do
						local l_Link = s_Links[l_LinkIndex]
						local s_Other = nil
						if l_Link.source ~= nil and l_Link.source:Eq(s_Representative) then
							s_Other = l_Link.target
						elseif l_Link.target ~= nil and l_Link.target:Eq(s_Representative) then
							s_Other = l_Link.source
						end
						if s_Other ~= nil then
							if s_Other:Is('VolumeVectorShapeData') then
								local s_Shape = _ShapeEntry(s_Other)
								s_Shape.sourceField = l_Link.sourceFieldId
								s_Shape.targetField = l_Link.targetFieldId
								s_Shapes[#s_Shapes + 1] = s_Shape
							elseif #s_Entry.linked < 10 then
								s_Entry.linked[#s_Entry.linked + 1] = _TypeName(s_Other)
							end
						end
					end
				end
			end
			s_Outer[#s_Outer + 1] = s_Entry
		end
		s_Bus = s_Bus.parent
	end

	local s_Diagnostics = { levels = s_Levels, outer = s_Outer }
	local s_Partition = s_Data ~= nil and s_Data.partition or nil
	if s_Partition ~= nil then
		local s_Count = 0
		local s_Instances = s_Partition.instances
		for l_Index = 1, #s_Instances do
			if s_Instances[l_Index]:Is('VolumeVectorShapeData') then
				s_Count = s_Count + 1
			end
		end
		s_Diagnostics.partition = s_Partition.name
		s_Diagnostics.partitionShapes = s_Count
	end
	return s_Shapes, s_Diagnostics
end

---@param p_Id integer
---@return integer the id as signed 32 bit (field-ids come signed, MathUtils:FNVHash may not)
local function _FieldId(p_Id)
	p_Id = p_Id & 0xFFFFFFFF
	return p_Id >= 0x80000000 and p_Id - 0x100000000 or p_Id
end

---Where a field of the data of an entity gets its value from: follows the property-connections that target it out
---through the blueprints (prefab -> interface -> the ReferenceObjectData that places the prefab -> ...). Each step
---lists the default value of the interface-field, the outermost one with a value is what the engine uses.
---@param p_Entity Entity
---@param p_FieldName string e.g. "CaptureRadius"
---@return table { value, chain = { { partition, source, sourceField, default } } }
local function _FieldChain(p_Entity, p_FieldName)
	local s_Chain = {}
	local s_Value = nil
	local s_Target = p_Entity.data
	local s_FieldId = _FieldId(MathUtils:FNVHash(p_FieldName))
	local s_Bus = p_Entity.bus

	for _ = 1, 6 do
		if s_Target == nil or s_Target.partition == nil then
			break
		end
		local s_Found = nil
		local s_Instances = s_Target.partition.instances
		for l_Index = 1, #s_Instances do
			local l_Instance = s_Instances[l_Index]
			if s_Found == nil and l_Instance:Is('DataBusData') then
				local s_Connections = DataBusData(l_Instance).propertyConnections
				for l_ConnectionIndex = 1, #s_Connections do
					local l_Connection = s_Connections[l_ConnectionIndex]
					if l_Connection.target ~= nil and l_Connection.target:Eq(s_Target)
						and _FieldId(l_Connection.targetFieldId) == s_FieldId then
						s_Found = l_Connection
						break
					end
				end
			end
		end

		local s_Step = { partition = s_Target.partition.name, field = s_FieldId }
		s_Chain[#s_Chain + 1] = s_Step
		if s_Found == nil or s_Found.source == nil then
			break
		end
		s_Step.source = _TypeName(s_Found.source)
		s_Step.sourceField = _FieldId(s_Found.sourceFieldId)

		if not s_Found.source:Is('InterfaceDescriptorData') then
			-- A value of another entity: its fields tell more.
			s_Step.sourceFields = _Fields(s_Found.source)
			break
		end

		local s_Fields = InterfaceDescriptorData(s_Found.source).fields
		for l_Index = 1, #s_Fields do
			if _FieldId(s_Fields[l_Index].id) == s_Step.sourceField then
				s_Step.default = s_Fields[l_Index].value
				if s_Step.default ~= nil and s_Step.default ~= '' then
					s_Value = s_Step.default
				end
			end
		end

		-- One blueprint further out: the interface-field is set on the ReferenceObjectData that placed this one.
		if s_Bus == nil then
			break
		end
		s_Target = s_Bus.parentRepresentative
		s_FieldId = s_Step.sourceField
		s_Bus = s_Bus.parent
	end

	return { value = s_Value, chain = s_Chain }
end

---Area-triggers: the zones of the capture points among others.
local function _AreaTriggers()
	local s_Result = {}
	_Iterate('ServerAreaTriggerEntity', function(p_Entity)
		local s_Entry = { id = p_Entity.instanceId, dataType = _TypeName(p_Entity.data) }
		local s_World = p_Entity.computedWorldTransform
		if s_World ~= nil then
			s_Entry.pos = _Vec(s_World.trans)
		end
		if p_Entity.data ~= nil and p_Entity.data:Is('AreaTriggerEntityData') then
			local s_Data = AreaTriggerEntityData(p_Entity.data)
			s_Entry.radius = _Round(s_Data.radius)
			s_Entry.geometry = _Transform(s_Data.geometryTransform)
		end
		s_Result[#s_Result + 1] = s_Entry
	end)
	return s_Result
end

local function _CapturePoints()
	local s_Result = {}
	_Iterate('ServerCapturePointEntity', function(p_Entity)
		local s_CapturePoint = CapturePointEntity(p_Entity)
		local s_Entry = {
			id = p_Entity.instanceId,
			name = s_CapturePoint.name,
			objective = g_GameDirector.m_Translations[s_CapturePoint.name],
			hq = m_Utilities:IsHq(s_CapturePoint),
			pos = _Vec(s_CapturePoint.transform.trans),
			team = s_CapturePoint.team,
			captureEnabled = s_CapturePoint.isCaptureEnabled,
			controlled = s_CapturePoint.isControlled,
		}

		if p_Entity.data ~= nil and p_Entity.data:Is('CapturePointEntityData') then
			local s_Data = CapturePointEntityData(p_Entity.data)
			s_Entry.radius = _Round(s_Data.captureRadius)
			s_Entry.initialTeam = s_Data.initialOwnerTeam
			s_Entry.onlyTeam = s_Data.onlyTakeableByTeam
			s_Entry.upperSphere = s_Data.isCapturedInUpperSphere
			s_Entry.fields = _Fields(s_Data)
			local s_Components = {}
			for l_Index = 1, #s_Data.components do
				s_Components[#s_Components + 1] = _TypeName(s_Data.components[l_Index])
			end
			s_Entry.components = s_Components
			s_Entry.radiusSource = _FieldChain(p_Entity, 'CaptureRadius')
		end

		-- The spawns (see BotSpawner:_FindClosestSpawnPoint) and area-triggers that belong to the capture point.
		local s_Spawns = {}
		local s_Zones = {}
		local s_Bus = p_Entity.bus
		if s_Bus ~= nil then
			for l_Index = 1, #s_Bus.entities do
				local l_Entity = s_Bus.entities[l_Index]
				if l_Entity:Is('ServerCharacterSpawnEntity') then
					s_Spawns[#s_Spawns + 1] = l_Entity.instanceId
				elseif l_Entity:Is('ServerAreaTriggerEntity') then
					s_Zones[#s_Zones + 1] = l_Entity.instanceId
				end
			end
		end
		s_Entry.spawns = s_Spawns
		s_Entry.zones = s_Zones

		local s_Shapes, s_Diagnostics = _LinkedShapes(p_Entity)
		s_Entry.shapes = s_Shapes
		if #s_Shapes == 0 then
			s_Entry.diagnostics = s_Diagnostics
		end

		s_Result[#s_Result + 1] = s_Entry
	end)
	return s_Result
end

local function _CombatAreas()
	local s_Result = {}
	_Iterate('ServerCombatAreaTriggerEntity', function(p_Entity)
		local s_Entry = { id = p_Entity.instanceId, dataType = _TypeName(p_Entity.data) }

		if p_Entity.data ~= nil and p_Entity.data:Is('CombatAreaTriggerEntityData') then
			local s_Data = CombatAreaTriggerEntityData(p_Entity.data)
			s_Entry.team = s_Data.team
			s_Entry.teamSpecific = s_Data.isTeamSpecific
			s_Entry.enabled = s_Data.enabled
		end

		-- The points of the shapes are in the space of the blueprint. Both transforms, until it's clear which applies.
		local s_World = p_Entity.computedWorldTransform
		if s_World ~= nil then
			s_Entry.transform = _Transform(s_World)
		end
		local s_Representative = p_Entity.bus ~= nil and p_Entity.bus.parentRepresentative or nil
		if s_Representative ~= nil and s_Representative:Is('ReferenceObjectData') then
			s_Entry.blueprintTransform = _Transform(ReferenceObjectData(s_Representative).blueprintTransform)
		end

		local s_Shapes, s_Diagnostics = _LinkedShapes(p_Entity)
		s_Entry.shapes = s_Shapes
		if #s_Shapes == 0 then
			s_Entry.diagnostics = s_Diagnostics
		end

		s_Result[#s_Result + 1] = s_Entry
	end)
	return s_Result
end

---@param p_Entity Entity
---@return table
local function _DumpEntity(p_Entity)
	local s_Entry = { id = p_Entity.instanceId, dataType = _TypeName(p_Entity.data) }
	local s_World = p_Entity.computedWorldTransform
	if s_World ~= nil then
		s_Entry.pos = _Vec(s_World.trans)
	end
	if p_Entity:Is('SpatialEntity') then
		local s_Box = SpatialEntity(p_Entity).aabb
		s_Entry.aabb = { _Vec(s_Box.min), _Vec(s_Box.max) }
	end
	-- The blueprint the entity belongs to (e.g. the MCOM of an interaction).
	local s_Ok, s_Owner = pcall(function()
		local s_Representative = p_Entity.bus ~= nil and p_Entity.bus.parentRepresentative or nil
		if s_Representative ~= nil and s_Representative:Is('Blueprint') then
			return Blueprint(s_Representative).name
		end
		return s_Representative ~= nil and s_Representative.typeInfo.name or nil
	end)
	if s_Ok then
		s_Entry.owner = s_Owner
	end
	return s_Entry
end

---How often each entity-type exists, and the position of the types in DUMP_TYPES.
---@return table counts, table dumps
local function _EntityTypes()
	local s_Counts = {}
	local s_Dumps = {}
	EntityManager:TraverseAllEntities(function(p_Entity)
		local s_Name = p_Entity.typeInfo.name
		s_Counts[s_Name] = (s_Counts[s_Name] or 0) + 1

		for l_Index = 1, #DUMP_TYPES do
			if string.find(s_Name, DUMP_TYPES[l_Index], 1, true) ~= nil then
				local s_List = s_Dumps[s_Name] or {}
				s_Dumps[s_Name] = s_List
				if #s_List < MAX_DUMP_PER_TYPE then
					local s_Ok, s_Entry = pcall(_DumpEntity, p_Entity)
					s_List[#s_List + 1] = s_Ok and s_Entry or { id = p_Entity.instanceId, error = tostring(s_Entry) }
				end
				break
			end
		end
	end)
	return s_Counts, s_Dumps
end

---The MCOMs of rush: the positions of the "mcom N interact" paths (GameDirector._McomPositions).
local function _Mcoms()
	local s_Result = {}
	for l_Index, l_Position in pairs(g_GameDirector._McomPositions or {}) do
		s_Result[#s_Result + 1] = { index = l_Index, name = 'mcom ' .. l_Index, pos = _Vec(l_Position) }
	end
	table.sort(s_Result, function(p_A, p_B) return p_A.index < p_B.index end)
	return s_Result
end

---Everything that isn't a raycast. Each part runs on its own, an error only loses that part.
---@return table
local function _CollectEntities()
	local s_Errors = {}
	local function _Try(p_Name, p_Function)
		local s_Ok, s_Result, s_Second = pcall(p_Function)
		if not s_Ok then
			s_Errors[#s_Errors + 1] = p_Name .. ': ' .. tostring(s_Result)
			return nil
		end
		return s_Result, s_Second
	end

	local s_Data = {
		modes = {
			conquest = Globals.IsConquest,
			rush = Globals.IsRush,
			tdm = Globals.IsTdm,
		},
		capturePoints = _Try('capturePoints', _CapturePoints),
		spawns = _Try('spawns', _CharacterSpawns),
		alternateSpawns = _Try('alternateSpawns', _AlternateSpawns),
		vehicleSpawns = _Try('vehicleSpawns', _VehicleSpawns),
		combatAreas = _Try('combatAreas', _CombatAreas),
		areaTriggers = _Try('areaTriggers', _AreaTriggers),
		mcoms = _Try('mcoms', _Mcoms),
		vehicles = _Try('vehicles', m_DebugSnapshots.CollectVehicles),
		objectives = _Try('objectives', m_DebugSnapshots.CollectObjectives),
	}
	s_Data.entityTypes, s_Data.entities = _Try('entityTypes', _EntityTypes)
	s_Data.errors = s_Errors
	return s_Data
end

-- =============================================
-- Census
-- =============================================

---@param p_Bridge DebugBridge
---@param p_CommandId any
---@param p_Args table { parts = { "entities", "nodes", "areas" }, budgetMs, areas = { { name, kind, pos, radius } },
---                     areaMargin, mcomRadius, areaStep, areaLayers, hq = false, detailMesh = false }
---@return table info about the census
function MapCensus:Start(p_Bridge, p_CommandId, p_Args)
	if m_NodeCollection._LoadActive then
		error('the waypoints are still loading, try again in a moment')
	end

	-- One at a time.
	self:Stop(p_Bridge)

	local s_Parts = {}
	local s_PartList = type(p_Args.parts) == 'table' and p_Args.parts or { 'entities', 'nodes', 'areas' }
	for l_Index = 1, #s_PartList do
		s_Parts[s_PartList[l_Index]] = true
	end

	local s_Task = setmetatable({
		CommandId = p_CommandId,
		Census = self._NextCensus,
		Parts = s_Parts,
		BudgetMs = math.max(1.0, tonumber(p_Args.budgetMs) or BUDGET_MS),
		Args = p_Args,
		Phase = 'entities',
		Raycasts = 0,
		NodeCount = 0,
		CellCount = 0,
		StartMs = _NowMs(),
	}, CensusTask)
	self._NextCensus = self._NextCensus + 1

	local s_Level = SharedUtils:GetLevelName()
	local s_Mode = SharedUtils:GetCurrentGameMode()
	p_Bridge:AddTask(s_Task)
	p_Bridge:Event('census_started', {
		census = s_Task.Census,
		level = s_Level,
		mode = s_Mode,
		paths = m_NodeCollection:GetMapName(),
		parts = s_PartList,
	})

	return { census = s_Task.Census, level = s_Level, mode = s_Mode }
end

---@param p_Bridge DebugBridge
---@return integer stopped censuses
function MapCensus:Stop(p_Bridge)
	return p_Bridge:AbortTasks(function(p_Task)
		return getmetatable(p_Task) == CensusTask
	end, 'stopped')
end

---@return RayCastHit|nil first hit
function CensusTask:_Ray(p_From, p_To, p_Flags)
	self.Raycasts = self.Raycasts + 1
	local s_Flags = p_Flags or RAY_FLAGS
	-- args.detailMesh: also the detail-meshes of the level (some walls, ceilings and floors are only those).
	if self.Args.detailMesh then
		s_Flags = s_Flags | RayCastFlags.CheckDetailMesh
	end
	---@cast s_Flags RayCastFlags
	return RaycastManager:CollisionRaycast(p_From, p_To, 1, NO_MATERIAL_FLAGS, s_Flags)[1]
end

---@param p_Hit RayCastHit
---@return string
local function _HitKind(p_Hit)
	return p_Hit.rigidBody ~= nil and p_Hit.rigidBody.typeInfo.name or '?'
end

---Rays at SEGMENT_HEIGHTS from one position to another.
---@return table fractions of the distance where each ray hit, false if it got through
---@return string|false kind of the lowest hit
function CensusTask:_SegmentRays(p_From, p_To)
	local s_Fractions = {}
	---@type string|false
	local s_Kind = false
	local s_Length = p_From:Distance(p_To)
	for l_Index = 1, #SEGMENT_HEIGHTS do
		local l_Height = SEGMENT_HEIGHTS[l_Index]
		local s_From = Vec3(p_From.x, p_From.y + l_Height, p_From.z)
		local s_Hit = self:_Ray(s_From, Vec3(p_To.x, p_To.y + l_Height, p_To.z))
		if s_Hit ~= nil and s_Length > 0.01 then
			s_Fractions[l_Index] = _Round(s_From:Distance(s_Hit.position) / s_Length)
			if s_Kind == false then
				s_Kind = _HitKind(s_Hit)
			end
		else
			s_Fractions[l_Index] = false
		end
	end
	return s_Fractions, s_Kind
end

---Raycasts around one waypoint. Writes into the arrays of self.Chunk:
---  ground   height of the ground below minus the waypoint (negative: it floats), false = none within GROUND_DOWN
---  normal   normal-y of that ground (1 = flat), false = no ground
---  water    depth of water above the ground, false = none
---  ceiling  headroom above the ground, false = more than CEILING_MAX
---  left/right  free space to the sides of the path (min of knee and chest), false = more than CLEARANCE_MAX,
---           -1 = the path has no direction here
---  next     SEGMENT_HEIGHTS-rays to the next waypoint of the path: fraction of the way where each one hit, or false.
---           false instead of the list at the end of a path that doesn't loop.
---  nextHit  entity-type of the lowest hit on the way to the next waypoint, false = none
---  links    { point, path, point, fractions, kind } for links longer than MIN_LINK_LENGTH
---Also inputs (inputVar of every waypoint), actions ({ point, type }), and objectives / vehicles of the path.
function CensusTask:_ProbeNode(p_Nodes, p_Index, p_Loops)
	local s_Chunk = self.Chunk
	local s_Node = p_Nodes[p_Index]
	local s_Pos = s_Node.Position
	local s_X, s_Y, s_Z = s_Pos.x, s_Pos.y, s_Pos.z
	local s_Slot = #s_Chunk.points + 1

	s_Chunk.points[s_Slot] = _Vec(s_Pos)
	s_Chunk.inputs[s_Slot] = s_Node.InputVar
	if s_Node.Data ~= nil and type(s_Node.Data.Action) == 'table' then
		s_Chunk.actions[#s_Chunk.actions + 1] = { p_Index, tostring(s_Node.Data.Action.type) }
	end

	-- Ground and water.
	local s_GroundY = s_Y
	local s_Top = Vec3(s_X, s_Y + GROUND_UP, s_Z)
	local s_Hit = self:_Ray(s_Top, Vec3(s_X, s_Y - GROUND_DOWN, s_Z))
	if s_Hit ~= nil and s_Hit.position.y > s_Y + GROUND_COVER then
		-- Something right above the waypoint (a table, a low roof): the ground is below that.
		s_Top = Vec3(s_X, s_Y + GROUND_COVER, s_Z)
		s_Hit = self:_Ray(s_Top, Vec3(s_X, s_Y - GROUND_DOWN, s_Z))
	end
	if s_Hit ~= nil then
		s_GroundY = s_Hit.position.y
		s_Chunk.ground[s_Slot] = _Round(s_GroundY - s_Y)
		s_Chunk.normal[s_Slot] = _Round(s_Hit.normal.y)
	else
		s_Chunk.ground[s_Slot] = false
		s_Chunk.normal[s_Slot] = false
	end

	s_Hit = self:_Ray(s_Top, Vec3(s_X, s_GroundY - 0.05, s_Z), RAY_FLAGS_WATER)
	if s_Hit ~= nil and s_Hit.position.y > s_GroundY + 0.05 then
		s_Chunk.water[s_Slot] = _Round(s_Hit.position.y - s_GroundY)
	else
		s_Chunk.water[s_Slot] = false
	end

	-- Headroom.
	s_Hit = self:_Ray(Vec3(s_X, s_GroundY + 0.2, s_Z), Vec3(s_X, s_GroundY + CEILING_MAX, s_Z))
	s_Chunk.ceiling[s_Slot] = s_Hit ~= nil and _Round(s_Hit.position.y - s_GroundY) or false

	-- Free space to the sides, across the direction of the path.
	local s_Previous = p_Nodes[p_Index - 1] or (p_Loops and p_Nodes[#p_Nodes]) or s_Node
	local s_Next = p_Nodes[p_Index + 1] or (p_Loops and p_Nodes[1]) or s_Node
	local s_DeltaX = s_Next.Position.x - s_Previous.Position.x
	local s_DeltaZ = s_Next.Position.z - s_Previous.Position.z
	local s_Length = math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
	if s_Length < 0.05 then
		s_Chunk.left[s_Slot] = -1
		s_Chunk.right[s_Slot] = -1
	else
		-- right = (dir.z, 0, -dir.x), as Bot:_GetPathOffsetEntry
		local s_RightX = s_DeltaZ / s_Length
		local s_RightZ = -s_DeltaX / s_Length
		for l_Side = 1, 2 do
			local s_Sign = l_Side == 1 and 1 or -1
			local s_Free = CLEARANCE_MAX
			for l_Index = 1, #CLEARANCE_HEIGHTS do
				local s_From = Vec3(s_X, s_GroundY + CLEARANCE_HEIGHTS[l_Index], s_Z)
				local s_To = Vec3(s_X + s_Sign * s_RightX * CLEARANCE_MAX, s_From.y, s_Z + s_Sign * s_RightZ * CLEARANCE_MAX)
				local s_SideHit = self:_Ray(s_From, s_To)
				if s_SideHit ~= nil then
					s_Free = math.min(s_Free, s_From:Distance(s_SideHit.position))
				end
			end
			local s_Value = s_Free < CLEARANCE_MAX and _Round(s_Free) or false
			if l_Side == 1 then
				s_Chunk.right[s_Slot] = s_Value
			else
				s_Chunk.left[s_Slot] = s_Value
			end
		end
	end

	-- The way to the next waypoint. A looping path goes from the last one to the first.
	local s_NextNode = p_Nodes[p_Index + 1] or (p_Loops and #p_Nodes > 2 and p_Nodes[1]) or nil
	if s_NextNode ~= nil then
		local s_Fractions, s_Kind = self:_SegmentRays(s_Pos, s_NextNode.Position)
		s_Chunk.next[s_Slot] = s_Fractions
		s_Chunk.nextHit[s_Slot] = s_Kind
	else
		s_Chunk.next[s_Slot] = false
		s_Chunk.nextHit[s_Slot] = false
	end

	-- Links, each pair once.
	local s_Links = s_Node.Data ~= nil and s_Node.Data.Links or nil
	if type(s_Links) == 'table' then
		for l_Index = 1, #s_Links do
			local l_Link = s_Links[l_Index]
			local s_Target = type(l_Link) == 'string' and m_NodeCollection:Get(l_Link) or nil
			if s_Target ~= nil and s_Target.Position ~= nil then
				local s_Key = s_Node.ID < s_Target.ID and (s_Node.ID .. '|' .. s_Target.ID) or (s_Target.ID .. '|' .. s_Node.ID)
				if not self.SeenLinks[s_Key] and s_Pos:Distance(s_Target.Position) >= MIN_LINK_LENGTH then
					self.SeenLinks[s_Key] = true
					local s_Fractions, s_Kind = self:_SegmentRays(s_Pos, s_Target.Position)
					s_Chunk.links[#s_Chunk.links + 1] = { p_Index, s_Target.PathIndex, s_Target.PointIndex, s_Fractions, s_Kind }
				end
			end
		end
	end

	self.NodeCount = self.NodeCount + 1
end

function CensusTask:_NewChunk(p_Nodes, p_PathIndex, p_First, p_Loops)
	self.Chunk = {
		path = p_PathIndex,
		first = p_First,
		loops = p_Loops,
		points = {},
		inputs = {},
		actions = {},
		ground = {},
		normal = {},
		water = {},
		ceiling = {},
		left = {},
		right = {},
		next = {},
		nextHit = {},
		links = {},
	}

	-- Objectives and vehicles of the path are stored at its first waypoint.
	local s_FirstData = p_First == 1 and p_Nodes[1].Data or nil
	if type(s_FirstData) == 'table' then
		self.Chunk.objectives = s_FirstData.Objectives
		self.Chunk.vehicles = s_FirstData.Vehicles
	end
end

---@param p_Bridge DebugBridge
---@param p_Last boolean
function CensusTask:_SendChunk(p_Bridge, p_Last)
	local s_Chunk = self.Chunk
	if s_Chunk == nil or #s_Chunk.points == 0 then
		return
	end
	s_Chunk.census = self.Census
	s_Chunk.last = p_Last
	p_Bridge:Event('census_nodes', s_Chunk)
	self.Chunk = nil
end

function CensusTask:_StartNodes()
	local s_Paths = m_NodeCollection:GetPaths()
	local s_PathIndices = {}
	for l_PathIndex, l_Waypoints in pairs(s_Paths) do
		if #l_Waypoints > 0 then
			s_PathIndices[#s_PathIndices + 1] = l_PathIndex
		end
	end
	table.sort(s_PathIndices)

	self.Paths = s_Paths
	self.PathIndices = s_PathIndices
	self.PathSlot = 1
	self.Point = 1
	self.SeenLinks = {}
end

---@return boolean done
function CensusTask:_UpdateNodes(p_Bridge, p_EndMs)
	while _NowMs() < p_EndMs do
		local s_PathIndex = self.PathIndices[self.PathSlot]
		if s_PathIndex == nil then
			return true
		end

		local s_Nodes = self.Paths[s_PathIndex] or {}
		-- Only looping paths continue at the other end (see Bot:_GetWayIndex).
		local s_Loops = #s_Nodes > 0 and s_Nodes[1].OptValue ~= 0xFF
		if self.Chunk == nil then
			self:_NewChunk(s_Nodes, s_PathIndex, self.Point, s_Loops)
		end

		self:_ProbeNode(s_Nodes, self.Point, s_Loops)
		self.Point = self.Point + 1

		if self.Point > #s_Nodes then
			self:_SendChunk(p_Bridge, true)
			self.PathSlot = self.PathSlot + 1
			self.Point = 1
		elseif #self.Chunk.points >= NODES_PER_EVENT then
			self:_SendChunk(p_Bridge, false)
		end
	end
	return false
end

---The areas around the objectives: capture points (without HQs) and MCOMs, or the ones of the command.
---@return table
function CensusTask:_DefaultAreas()
	local s_Args = self.Args
	local s_Margin = tonumber(s_Args.areaMargin) or AREA_MARGIN
	local s_Areas = {}

	if type(s_Args.areas) == 'table' then
		for l_Index = 1, #s_Args.areas do
			local l_Area = s_Args.areas[l_Index]
			local s_Pos = type(l_Area.pos) == 'table' and l_Area.pos or {}
			s_Areas[#s_Areas + 1] = {
				name = tostring(l_Area.name or ('area ' .. l_Index)),
				kind = tostring(l_Area.kind or 'custom'),
				center = Vec3(tonumber(s_Pos[1]) or 0, tonumber(s_Pos[2]) or 0, tonumber(s_Pos[3]) or 0),
				radius = tonumber(l_Area.radius) or 30.0,
			}
		end
		return s_Areas
	end

	-- Capture points of several modes can share a layer and their names (XP3_Alborz): one area per name, the one owned
	-- by a team at the start (of the running mode), as GameDirector:_InitFlagTeams.
	local s_ByName = {}
	_Iterate('ServerCapturePointEntity', function(p_Entity)
		local s_CapturePoint = CapturePointEntity(p_Entity)
		local s_Hq = m_Utilities:IsHq(s_CapturePoint)
		if s_Hq and not s_Args.hq then
			return
		end
		local s_Radius = 20.0
		if p_Entity.data ~= nil and p_Entity.data:Is('CapturePointEntityData') then
			s_Radius = CapturePointEntityData(p_Entity.data).captureRadius
		end
		local s_Area = {
			name = g_GameDirector.m_Translations[s_CapturePoint.name] or s_CapturePoint.name,
			kind = s_Hq and 'hq' or 'capturepoint',
			center = s_CapturePoint.transform.trans:Clone(),
			radius = s_Radius + s_Margin,
		}
		local s_Owned = s_CapturePoint.team ~= TeamId.TeamNeutral
		local s_Known = s_ByName[s_Area.name]
		if s_Known == nil then
			s_Areas[#s_Areas + 1] = s_Area
			s_ByName[s_Area.name] = { Index = #s_Areas, Owned = s_Owned }
		elseif s_Owned and not s_Known.Owned then
			s_Areas[s_Known.Index] = s_Area
			s_Known.Owned = true
		end
	end)

	for l_Index, l_Position in pairs(g_GameDirector._McomPositions or {}) do
		s_Areas[#s_Areas + 1] = {
			name = 'mcom ' .. l_Index,
			kind = 'mcom',
			center = l_Position:Clone(),
			radius = tonumber(s_Args.mcomRadius) or AREA_MCOM_RADIUS,
		}
	end

	table.sort(s_Areas, function(p_A, p_B) return p_A.name < p_B.name end)
	return s_Areas
end

---Whether the area covers the position (horizontally), at least p_Margin inside: its circle, or its discs (ways).
---@param p_Area table
---@param p_Position Vec3
---@param p_Margin number
---@return boolean
local function _Covers(p_Area, p_Position, p_Margin)
	if p_Area.discs ~= nil then
		for l_Index = 1, #p_Area.discs do
			local l_Disc = p_Area.discs[l_Index]
			local s_DeltaX = p_Position.x - l_Disc[1]
			local s_DeltaZ = p_Position.z - l_Disc[2]
			if math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ) + p_Margin <= l_Disc[3] then
				return true
			end
		end
		return false
	end
	local s_Delta = p_Position - p_Area.center
	return math.sqrt(s_Delta.x * s_Delta.x + s_Delta.z * s_Delta.z) + p_Margin <= p_Area.radius
end

---@param p_A Vec3
---@param p_B Vec3
---@return number
local function _Horizontal(p_A, p_B)
	local s_DeltaX = p_A.x - p_B.x
	local s_DeltaZ = p_A.z - p_B.z
	return math.sqrt(s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ)
end

---The areas a spawn leads to: in rush the MCOMs of its stage (the stage is in the name of its layer), else the
---objective closest to it (capture point, base, MCOM).
---@param p_Areas table[]
---@param p_Position Vec3
---@param p_Stage integer|nil
---@return table[]
local function _SpawnTargets(p_Areas, p_Position, p_Stage)
	local s_Result = {}
	if Globals.IsRush and p_Stage ~= nil then
		local s_Names = Globals.IsSquadRush and { 'mcom ' .. p_Stage }
			or { 'mcom ' .. (2 * p_Stage - 1), 'mcom ' .. (2 * p_Stage) }
		for l_Index = 1, #p_Areas do
			if table.has(s_Names, p_Areas[l_Index].name) then
				s_Result[#s_Result + 1] = p_Areas[l_Index]
			end
		end
		if #s_Result > 0 then
			return s_Result
		end
	end
	local s_Best = nil
	local s_BestDistance = math.huge
	for l_Index = 1, #p_Areas do
		local l_Area = p_Areas[l_Index]
		if l_Area.kind == 'capturepoint' or l_Area.kind == 'base' or l_Area.kind == 'mcom' or l_Area.kind == 'hq' then
			local s_Distance = _Horizontal(p_Position, l_Area.center)
			if s_Distance < s_BestDistance then
				s_Best = l_Area
				s_BestDistance = s_Distance
			end
		end
	end
	return s_Best ~= nil and { s_Best } or {}
end

---The way from a group of spawns to the area of its target: discs of AREA_WAY_RADIUS along the straight line, up to
---AREA_WAY_INTO into the area. The mesh gets measured there as well, so the bots walk it from the spawn to their
---target, no waypoints needed. nil if the group reaches into the area already.
---@param p_Name string
---@param p_From Vec3 middle of the group
---@param p_Reach number radius of the group
---@param p_Target table the area
---@return table|nil
local function _WayArea(p_Name, p_From, p_Reach, p_Target)
	local s_To = p_Target.center
	local s_Distance = _Horizontal(p_From, s_To)
	if s_Distance + AREA_WAY_INTO <= p_Reach + p_Target.radius or s_Distance < 1.0 then
		return nil
	end
	local s_Length = s_Distance - p_Target.radius + AREA_WAY_INTO
	local s_Count = math.max(1, math.ceil(s_Length / AREA_WAY_STEP))
	local s_Discs = {}
	local s_MinX, s_MaxX, s_MinZ, s_MaxZ = math.huge, -math.huge, math.huge, -math.huge
	for l_Index = 0, s_Count do
		local s_Share = math.min(s_Length, l_Index * AREA_WAY_STEP) / s_Distance
		local s_X = p_From.x + (s_To.x - p_From.x) * s_Share
		local s_Z = p_From.z + (s_To.z - p_From.z) * s_Share
		s_Discs[#s_Discs + 1] = { _Round(s_X), _Round(s_Z), AREA_WAY_RADIUS }
		s_MinX = math.min(s_MinX, s_X - AREA_WAY_RADIUS)
		s_MaxX = math.max(s_MaxX, s_X + AREA_WAY_RADIUS)
		s_MinZ = math.min(s_MinZ, s_Z - AREA_WAY_RADIUS)
		s_MaxZ = math.max(s_MaxZ, s_Z + AREA_WAY_RADIUS)
	end
	local s_Center = Vec3((s_MinX + s_MaxX) / 2, (p_From.y + s_To.y) / 2, (s_MinZ + s_MaxZ) / 2)
	return {
		name = 'way ' .. p_Name .. ' ' .. p_Target.name,
		kind = 'way',
		center = s_Center,
		radius = math.sqrt((s_MaxX - s_MinX) ^ 2 + (s_MaxZ - s_MinZ) ^ 2) / 2,
		discs = s_Discs,
		-- The vertical rays from above the higher end down to below the lower one: the ground between can be far
		-- below the middle (a valley).
		top = math.max(p_From.y, s_To.y) + AREA_UP,
		bottom = math.min(p_From.y, s_To.y) - AREA_DOWN,
	}
end

---Areas around the spawns of the game: bots spawned by the game (SpawnMethod.Spawn) start on the mesh there. Only the
---engine decides where they are, no waypoints: the alternate spawns of the running mode, else (none found) the
---soldier-spawn-entities. In rush they are zones (kind "base"): the navigation paths lead from them to the MCOMs.
---Elsewhere they only add to the mesh (kind "spawn"). Spawns another area covers get none of their own. Spawns into
---vehicles are left out.
---Each group of spawns also gets the way to its target (_WayArea, kind "way"): the mesh leads from the spawn to the
---MCOMs of its stage, to the capture point it belongs to.
---@param p_Areas table[] the areas so far
---@return table[]
local function _SpawnAreas(p_Areas)
	-- { position (on the ground), team (0: whoever holds the capture point), rush stage }
	local s_Positions = {}
	local s_Alternates = _AlternateSpawns()
	for l_Index = 1, #s_Alternates do
		local l_Spawn = s_Alternates[l_Index]
		local s_Stage = tonumber(tostring(l_Spawn.source or ''):lower():match('base_?(%d+)'))
		s_Positions[#s_Positions + 1] = { Vec3(l_Spawn.ground[1], l_Spawn.ground[2], l_Spawn.ground[3]), l_Spawn.team or 0,
			s_Stage }
	end
	if #s_Positions == 0 then
		local s_Spawns = _CharacterSpawns()
		for l_Index = 1, #s_Spawns do
			local l_Spawn = s_Spawns[l_Index]
			local s_Team = (l_Spawn.dataTeam == 1 or l_Spawn.dataTeam == 2) and l_Spawn.dataTeam or l_Spawn.team
			if l_Spawn.vehicleSpawn == nil and (l_Spawn.playerType or 0) == 0 and (s_Team == 1 or s_Team == 2) then
				-- The spawn-entity can be far above the ground (40 m on XP5_004): the grid around it must reach the ground.
				s_Positions[#s_Positions + 1] = { _Ground(Vec3(l_Spawn.pos[1], l_Spawn.pos[2], l_Spawn.pos[3])), s_Team }
			end
		end
	end

	-- One group for spawns close to each other, also of both teams.
	local s_Groups = {}
	for l_Index = 1, #s_Positions do
		local s_Position, s_Team, s_Stage = s_Positions[l_Index][1], s_Positions[l_Index][2], s_Positions[l_Index][3]
		local s_Covered = false
		for l_Area = 1, #p_Areas do
			if _Covers(p_Areas[l_Area], s_Position, AREA_SPAWN_COVERED) then
				s_Covered = true
				break
			end
		end
		local s_Group = nil
		for l_Group = 1, #s_Groups do
			if _Horizontal(s_Position, s_Groups[l_Group].first) <= AREA_SPAWN_MERGE then
				s_Group = s_Groups[l_Group]
				break
			end
		end
		if s_Group == nil then
			s_Group = { teams = {}, first = s_Position, positions = {}, uncovered = {}, targets = {} }
			s_Groups[#s_Groups + 1] = s_Group
		end
		s_Group.positions[#s_Group.positions + 1] = s_Position
		if not s_Covered then
			s_Group.uncovered[#s_Group.uncovered + 1] = s_Position
			s_Group.teams[s_Team] = true
		end
		local s_Targets = _SpawnTargets(p_Areas, s_Position, s_Stage)
		for l_Target = 1, #s_Targets do
			if not table.has(s_Group.targets, s_Targets[l_Target]) then
				s_Group.targets[#s_Group.targets + 1] = s_Targets[l_Target]
			end
		end
	end

	for l_Index = 1, #s_Groups do
		local l_Group = s_Groups[l_Index]
		l_Group.team = (l_Group.teams[1] and not l_Group.teams[2] and not l_Group.teams[0]) and 'us '
			or ((l_Group.teams[2] and not l_Group.teams[1] and not l_Group.teams[0]) and 'ru ' or '')
	end
	table.sort(s_Groups, function(p_A, p_B)
		if p_A.team ~= p_B.team then
			return p_A.team > p_B.team
		end
		return p_A.first.x < p_B.first.x
	end)

	---@param p_Positions Vec3[]
	---@return Vec3, number middle and radius
	local function _Circle(p_Positions)
		local s_Center = Vec3(0, 0, 0)
		for l_Position = 1, #p_Positions do
			s_Center = s_Center + p_Positions[l_Position]
		end
		s_Center = s_Center * (1.0 / #p_Positions)
		local s_Radius = 0.0
		for l_Position = 1, #p_Positions do
			s_Radius = math.max(s_Radius, _Horizontal(p_Positions[l_Position], s_Center))
		end
		return s_Center, s_Radius
	end

	local s_Areas = {}
	local s_Ways = {}
	local s_Counts = {}
	local s_WayCount = 0
	for l_Index = 1, #s_Groups do
		local l_Group = s_Groups[l_Index]
		local s_Name = nil
		if #l_Group.uncovered > 0 then
			-- The spawns no other area covers and AREA_SPAWN_MARGIN around the outer ones: only where they are and the
			-- ground between them, the way connects them to their target.
			local s_Center, s_Radius = _Circle(l_Group.uncovered)
			local s_Ground = {}
			for l_Position = 1, #l_Group.uncovered do
				s_Ground[l_Position] = _Vec(l_Group.uncovered[l_Position])
			end
			s_Counts[l_Group.team] = (s_Counts[l_Group.team] or 0) + 1
			s_Name = 'spawn ' .. l_Group.team .. s_Counts[l_Group.team]
			s_Areas[#s_Areas + 1] = {
				name = s_Name,
				-- Rush: zones (kind "base"), the ends of the navigation paths from the spawns to the MCOMs (no capture points
				-- or HQs to end at). Elsewhere only the mesh (the paths are cut there, but it's no objective).
				kind = Globals.IsRush and 'base' or 'spawn',
				center = s_Center,
				radius = s_Radius + AREA_SPAWN_MARGIN,
				spawns = s_Ground,
			}
		end
		-- The ways from the spawns of the area of the group, and from the ones other areas cover (those may not lead
		-- to the target either, e.g. the MCOM of another stage).
		local s_Covered = {}
		for l_Position = 1, #l_Group.positions do
			if not table.has(l_Group.uncovered, l_Group.positions[l_Position]) then
				s_Covered[#s_Covered + 1] = l_Group.positions[l_Position]
			end
		end
		for _, l_Positions in ipairs({ l_Group.uncovered, s_Covered }) do
			if #l_Positions > 0 then
				local s_From, s_Reach = _Circle(l_Positions)
				s_Reach = s_Reach + AREA_SPAWN_MARGIN
				local s_WayName = l_Positions == l_Group.uncovered and s_Name or nil
				for l_Target = 1, #l_Group.targets do
					s_WayCount = s_WayCount + 1
					local s_Way = _WayArea(s_WayName or ('spawns ' .. s_WayCount), s_From, s_Reach, l_Group.targets[l_Target])
					if s_Way ~= nil then
						s_Ways[#s_Ways + 1] = s_Way
					end
				end
			end
		end
	end
	for l_Index = 1, #s_Ways do
		s_Areas[#s_Areas + 1] = s_Ways[l_Index]
	end
	return s_Areas
end

-- Words in the names of paths that lead to something to do (not cut, no hub at their ends).
local HUB_FUNCTION_WORDS = { 'vehicle', 'beacon', 'interact' }

---Whether the path is one the cut turns into navigation paths: walked on foot, no actions, not the way to a vehicle,
---a beacon or an MCOM to arm.
---@param p_Waypoints Waypoint[]
---@return boolean
local function _IsFootPath(p_Waypoints)
	local s_Data = p_Waypoints[1] and p_Waypoints[1].Data or {}
	if s_Data.Vehicles ~= nil or s_Data.Nav ~= nil then
		return false
	end
	for _, l_Name in ipairs(s_Data.Objectives or {}) do
		for _, l_Word in ipairs(HUB_FUNCTION_WORDS) do
			if tostring(l_Name):lower():find(l_Word, 1, true) then
				return false
			end
		end
	end
	for l_Index = 1, #p_Waypoints do
		if p_Waypoints[l_Index].Data ~= nil and p_Waypoints[l_Index].Data.Action ~= nil then
			return false
		end
	end
	return true
end

---Hubs: where foot paths end outside of every zone, several of them meet over links (the old bases of the waypoints).
---An area around each group of such ends (AREA_HUB_MARGIN around the outer ones), kind "hub": a zone the navigation
---paths end at, no objective. Without it the cut drops these paths (their ends lie nowhere), and with them the other
---routes. The cut drops the ones that lead nowhere else (a dead end).
---@param p_Areas table[] the areas so far
---@return table[]
local function _HubAreas(p_Areas)
	local s_Groups = {}
	for _, l_Waypoints in pairs(m_NodeCollection:GetPaths() or {}) do
		if #l_Waypoints >= 2 and _IsFootPath(l_Waypoints) then
			for _, l_End in ipairs({ l_Waypoints[1], l_Waypoints[#l_Waypoints] }) do
				local s_Position = l_End.Position
				local s_Covered = false
				for l_Area = 1, #p_Areas do
					if _Covers(p_Areas[l_Area], s_Position, AREA_HUB_COVERED) then
						s_Covered = true
						break
					end
				end
				if not s_Covered then
					local s_Group = nil
					for l_Group = 1, #s_Groups do
						local s_Delta = s_Position - s_Groups[l_Group].first
						if math.sqrt(s_Delta.x * s_Delta.x + s_Delta.z * s_Delta.z) <= AREA_HUB_MERGE then
							s_Group = s_Groups[l_Group]
							break
						end
					end
					if s_Group == nil then
						s_Group = { first = s_Position, positions = {} }
						s_Groups[#s_Groups + 1] = s_Group
					end
					s_Group.positions[#s_Group.positions + 1] = s_Position
				end
			end
		end
	end
	table.sort(s_Groups, function(p_A, p_B) return p_A.first.x < p_B.first.x end)

	local s_Areas = {}
	for l_Index = 1, #s_Groups do
		local l_Group = s_Groups[l_Index]
		local s_Center = Vec3(0, 0, 0)
		for l_Position = 1, #l_Group.positions do
			s_Center = s_Center + l_Group.positions[l_Position]
		end
		s_Center = s_Center * (1.0 / #l_Group.positions)
		local s_Radius = 0.0
		for l_Position = 1, #l_Group.positions do
			local s_Delta = l_Group.positions[l_Position] - s_Center
			s_Radius = math.max(s_Radius, math.sqrt(s_Delta.x * s_Delta.x + s_Delta.z * s_Delta.z))
		end
		s_Areas[#s_Areas + 1] = {
			name = 'hub ' .. l_Index,
			kind = 'hub',
			center = s_Center,
			radius = s_Radius + AREA_HUB_MARGIN,
		}
	end
	return s_Areas
end

---Corridors: the ground along the foot paths between the other areas (kind "way", mesh only), so the mesh connects the
---zones itself where it can be walked, not only the paths between them (the cut keeps those only where the mesh doesn't
---lead: stairs and ladders the vertical rays don't see). Discs of AREA_CORRIDOR_RADIUS every AREA_CORRIDOR_STEP along
---each path, where no area covers the path yet (also not a corridor of another path along the same way).
---@param p_Areas table[] the areas so far
---@return table[]
local function _CorridorAreas(p_Areas)
	local s_Result = {}
	local s_Discs = {} -- all corridor discs so far: { x, z }

	local function _Free(p_Position)
		for l_Area = 1, #p_Areas do
			if _Covers(p_Areas[l_Area], p_Position, AREA_CORRIDOR_RADIUS) then
				return false
			end
		end
		for l_Index = 1, #s_Discs do
			local l_Disc = s_Discs[l_Index]
			local s_DeltaX = l_Disc[1] - p_Position.x
			local s_DeltaZ = l_Disc[2] - p_Position.z
			if s_DeltaX * s_DeltaX + s_DeltaZ * s_DeltaZ < AREA_CORRIDOR_STEP * AREA_CORRIDOR_STEP * 0.5 then
				return false
			end
		end
		return true
	end

	local s_Chunk = nil
	local function _Close()
		if s_Chunk ~= nil and #s_Chunk.discs > 0 then
			s_Result[#s_Result + 1] = {
				name = 'corridor ' .. (#s_Result + 1),
				kind = 'way',
				center = Vec3((s_Chunk.minX + s_Chunk.maxX) / 2, (s_Chunk.minY + s_Chunk.maxY) / 2,
					(s_Chunk.minZ + s_Chunk.maxZ) / 2),
				radius = math.sqrt((s_Chunk.maxX - s_Chunk.minX) ^ 2 + (s_Chunk.maxZ - s_Chunk.minZ) ^ 2) / 2,
				discs = s_Chunk.discs,
				top = s_Chunk.maxY + AREA_CORRIDOR_HEIGHT,
				bottom = s_Chunk.minY - AREA_CORRIDOR_HEIGHT,
			}
		end
		s_Chunk = nil
	end

	local function _Add(p_Position)
		if s_Chunk == nil or #s_Chunk.discs >= AREA_CORRIDOR_DISCS then
			_Close()
			s_Chunk = { discs = {}, minX = math.huge, maxX = -math.huge, minY = math.huge, maxY = -math.huge,
				minZ = math.huge, maxZ = -math.huge }
		end
		s_Chunk.discs[#s_Chunk.discs + 1] = { _Round(p_Position.x), _Round(p_Position.z), AREA_CORRIDOR_RADIUS }
		s_Discs[#s_Discs + 1] = { p_Position.x, p_Position.z }
		s_Chunk.minX = math.min(s_Chunk.minX, p_Position.x - AREA_CORRIDOR_RADIUS)
		s_Chunk.maxX = math.max(s_Chunk.maxX, p_Position.x + AREA_CORRIDOR_RADIUS)
		s_Chunk.minZ = math.min(s_Chunk.minZ, p_Position.z - AREA_CORRIDOR_RADIUS)
		s_Chunk.maxZ = math.max(s_Chunk.maxZ, p_Position.z + AREA_CORRIDOR_RADIUS)
		s_Chunk.minY = math.min(s_Chunk.minY, p_Position.y)
		s_Chunk.maxY = math.max(s_Chunk.maxY, p_Position.y)
	end

	local s_PathIndices = {}
	for l_PathIndex, l_Waypoints in pairs(m_NodeCollection:GetPaths() or {}) do
		if #l_Waypoints >= 2 and _IsFootPath(l_Waypoints) then
			s_PathIndices[#s_PathIndices + 1] = l_PathIndex
		end
	end
	table.sort(s_PathIndices)
	local s_Paths = m_NodeCollection:GetPaths()
	for _, l_PathIndex in ipairs(s_PathIndices) do
		local s_Waypoints = s_Paths[l_PathIndex]
		local s_Walked = AREA_CORRIDOR_STEP
		for l_Index = 1, #s_Waypoints do
			local s_Position = s_Waypoints[l_Index].Position
			if l_Index > 1 then
				s_Walked = s_Walked + s_Position:Distance(s_Waypoints[l_Index - 1].Position)
			end
			if s_Walked >= AREA_CORRIDOR_STEP then
				s_Walked = 0.0
				if _Free(s_Position) then
					_Add(s_Position)
				else
					_Close()
				end
			end
		end
		_Close()
	end
	return s_Result
end

function CensusTask:_StartAreas()
	self.Areas = self:_DefaultAreas()
	if self.Args.spawns ~= false then
		local s_Spawns = _SpawnAreas(self.Areas)
		for l_Index = 1, #s_Spawns do
			self.Areas[#self.Areas + 1] = s_Spawns[l_Index]
		end
	end
	if self.Args.hubs ~= false then
		local s_Hubs = _HubAreas(self.Areas)
		for l_Index = 1, #s_Hubs do
			self.Areas[#self.Areas + 1] = s_Hubs[l_Index]
		end
	end
	if self.Args.corridors ~= false then
		local s_Corridors = _CorridorAreas(self.Areas)
		for l_Index = 1, #s_Corridors do
			self.Areas[#self.Areas + 1] = s_Corridors[l_Index]
		end
	end
	self.AreaSlot = 0
	self.Area = nil
end

---Opens the next area. false if there is none.
function CensusTask:_NextArea(p_Bridge)
	self.AreaSlot = self.AreaSlot + 1
	local s_Area = self.Areas[self.AreaSlot]
	if s_Area == nil then
		self.Area = nil
		return false
	end

	local s_Step = math.max(0.25, tonumber(self.Args.areaStep) or AREA_STEP)
	s_Area.step = s_Step
	s_Area.layers = math.max(1, math.floor(tonumber(self.Args.areaLayers) or AREA_LAYERS))
	if s_Area.discs ~= nil then
		-- A way: the box around its discs, only the cells in a disc are measured (_ProbeCell).
		local s_MinX, s_MaxX, s_MinZ, s_MaxZ = math.huge, -math.huge, math.huge, -math.huge
		for l_Index = 1, #s_Area.discs do
			local l_Disc = s_Area.discs[l_Index]
			s_MinX = math.min(s_MinX, l_Disc[1] - l_Disc[3])
			s_MaxX = math.max(s_MaxX, l_Disc[1] + l_Disc[3])
			s_MinZ = math.min(s_MinZ, l_Disc[2] - l_Disc[3])
			s_MaxZ = math.max(s_MaxZ, l_Disc[2] + l_Disc[3])
		end
		s_Area.x0 = s_MinX
		s_Area.z0 = s_MinZ
		s_Area.columns = math.floor((s_MaxX - s_MinX) / s_Step) + 1
		s_Area.rows = math.floor((s_MaxZ - s_MinZ) / s_Step) + 1
	else
		local s_Cells = math.floor(2 * s_Area.radius / s_Step) + 1
		s_Area.x0 = s_Area.center.x - s_Area.radius
		s_Area.z0 = s_Area.center.z - s_Area.radius
		s_Area.columns = s_Cells
		s_Area.rows = s_Cells
	end
	s_Area.top = s_Area.top or (s_Area.center.y + (tonumber(self.Args.areaUp) or AREA_UP))
	s_Area.bottom = s_Area.bottom or (s_Area.center.y - (tonumber(self.Args.areaDown) or AREA_DOWN))
	s_Area.row = 0
	s_Area.column = 0
	s_Area.cells = {}
	self.Area = s_Area

	p_Bridge:Event('census_area', {
		census = self.Census,
		area = self.AreaSlot,
		name = s_Area.name,
		kind = s_Area.kind,
		center = _Vec(s_Area.center),
		radius = _Round(s_Area.radius),
		x0 = _Round(s_Area.x0),
		z0 = _Round(s_Area.z0),
		step = s_Step,
		columns = s_Area.columns,
		rows = s_Area.rows,
		layers = s_Area.layers,
		-- Spawn areas: where the soldiers appear (on the ground), the mesh grows from there as from the waypoints.
		spawns = s_Area.spawns,
		-- Ways: { x, z, radius } along the way, the cells in them are measured.
		discs = s_Area.discs,
	})
	return true
end

---Vertical rays through one cell, from the top down. A cell is false (outside of the circle, or no hit) or a flat list
---with four numbers per layer: height, normal-y, edges, headroom.
---  edges     bits of the blocked rays to the neighbour-cells at EDGE_HEIGHTS: 1 +x knee, 2 +x chest, 4 +z knee,
---            8 +z chest, 16 / 32 / 64 / 128 the same rays from the neighbour back. -1 for surfaces too steep to walk on.
---  headroom  free height above the surface, -1 = more than CEILING_MAX (or too steep to measure)
function CensusTask:_ProbeCell(p_Area, p_X, p_Z)
	if not _Covers(p_Area, Vec3(p_X, 0, p_Z), 0.0) then
		return false
	end

	local s_Step = p_Area.step
	local s_Top = p_Area.top
	local s_Cell = nil
	for l_Layer = 1, p_Area.layers do
		local s_Hit = self:_Ray(Vec3(p_X, s_Top, p_Z), Vec3(p_X, p_Area.bottom, p_Z))
		if s_Hit == nil then
			break
		end

		local s_Y = s_Hit.position.y
		local s_NormalY = s_Hit.normal.y
		local s_Edges = -1
		local s_Headroom = -1
		-- Deep under water (the seabed off a shore): not walkable, as a surface too steep.
		local s_Water = s_NormalY >= WALKABLE_NORMAL_Y
			and self:_Ray(Vec3(p_X, s_Top, p_Z), Vec3(p_X, s_Y - 0.05, p_Z), RAY_FLAGS_WATER) or nil
		local s_Deep = s_Water ~= nil and s_Water.position.y > s_Y + WADE_DEPTH
		if s_NormalY >= WALKABLE_NORMAL_Y and not s_Deep then
			s_Edges = 0
			for l_Index = 1, #EDGE_HEIGHTS do
				local s_Height = s_Y + EDGE_HEIGHTS[l_Index]
				local s_From = Vec3(p_X, s_Height, p_Z)
				local s_ToX = Vec3(p_X + s_Step, s_Height, p_Z)
				local s_ToZ = Vec3(p_X, s_Height, p_Z + s_Step)
				local s_Bit = l_Index == 1 and 1 or 2
				if self:_Ray(s_From, s_ToX) ~= nil then
					s_Edges = s_Edges | s_Bit
				end
				if self:_Ray(s_From, s_ToZ) ~= nil then
					s_Edges = s_Edges | (s_Bit * 4)
				end
				if self:_Ray(s_ToX, s_From) ~= nil then
					s_Edges = s_Edges | (s_Bit * 16)
				end
				if self:_Ray(s_ToZ, s_From) ~= nil then
					s_Edges = s_Edges | (s_Bit * 64)
				end
			end
			-- The top layer has nothing above it.
			if l_Layer > 1 then
				local s_Ceiling = self:_Ray(Vec3(p_X, s_Y + 0.2, p_Z), Vec3(p_X, s_Y + CEILING_MAX, p_Z))
				if s_Ceiling ~= nil then
					s_Headroom = _Round(s_Ceiling.position.y - s_Y)
				end
			end
		end

		s_Cell = s_Cell or {}
		s_Cell[#s_Cell + 1] = _Round(s_Y)
		s_Cell[#s_Cell + 1] = _Round(s_NormalY)
		s_Cell[#s_Cell + 1] = s_Edges
		s_Cell[#s_Cell + 1] = s_Headroom

		s_Top = s_Y - LAYER_GAP
		if s_Top <= p_Area.bottom then
			break
		end
	end

	self.CellCount = self.CellCount + 1
	return s_Cell or false
end

---@return boolean done
function CensusTask:_UpdateAreas(p_Bridge, p_EndMs)
	while _NowMs() < p_EndMs do
		local s_Area = self.Area
		if s_Area == nil then
			if not self:_NextArea(p_Bridge) then
				return true
			end
			s_Area = self.Area
		end
		---@cast s_Area -nil

		s_Area.column = s_Area.column + 1
		s_Area.cells[s_Area.column] = self:_ProbeCell(s_Area, s_Area.x0 + (s_Area.column - 1) * s_Area.step,
			s_Area.z0 + s_Area.row * s_Area.step)

		if s_Area.column >= s_Area.columns then
			p_Bridge:Event('census_area_row', {
				census = self.Census,
				area = self.AreaSlot,
				row = s_Area.row,
				cells = s_Area.cells,
			})
			s_Area.cells = {}
			s_Area.column = 0
			s_Area.row = s_Area.row + 1
			if s_Area.row >= s_Area.rows then
				self.Area = nil
			end
		end
	end
	return false
end

---@param p_Bridge DebugBridge
---@return boolean done
function CensusTask:Update(p_Bridge)
	local s_EndMs = _NowMs() + self.BudgetMs

	if self.Phase == 'entities' then
		if self.Parts.entities then
			p_Bridge:Event('census_entities', { census = self.Census, data = _CollectEntities() })
		end
		self.Phase = 'nodes'
		self:_StartNodes()
		return false
	end

	if self.Phase == 'nodes' then
		if not self.Parts.nodes or self:_UpdateNodes(p_Bridge, s_EndMs) then
			self.Phase = 'areas'
			self:_StartAreas()
		end
		return false
	end

	if self.Parts.areas and not self:_UpdateAreas(p_Bridge, s_EndMs) then
		return false
	end

	local s_Summary = {
		census = self.Census,
		raycasts = self.Raycasts,
		seconds = _Round((_NowMs() - self.StartMs) / 1000, 1),
		nodes = self.NodeCount,
		cells = self.CellCount,
	}
	p_Bridge:Event('census_done', s_Summary)
	p_Bridge:Reply(self.CommandId, true, s_Summary)
	return true
end

---@param p_Bridge DebugBridge
---@param p_Reason string
function CensusTask:Abort(p_Bridge, p_Reason)
	p_Bridge:Event('census_aborted', { census = self.Census, reason = p_Reason })
	p_Bridge:Reply(self.CommandId, false, 'census ' .. self.Census .. ' aborted: ' .. p_Reason)
end

if g_MapCensus == nil then
	---@type MapCensus
	g_MapCensus = MapCensus()
end

return g_MapCensus
