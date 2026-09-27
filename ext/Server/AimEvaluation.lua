---@class AimEvaluation
---@overload fun():AimEvaluation
AimEvaluation = class('AimEvaluation')

-- Debug-mode to find wrong vehicle-data (Offset, AimOffset, Parts, Speed, Drop).
-- Every projectile that spawns is matched to the vehicle-player that fired it. The spawn-transform of the projectile
-- is the real muzzle and the real shot-direction, so it can be compared to what the bot-aiming assumes:
--   Offset:    muzzle-position in the frame of the aiming-transform (part or vehicle). Directly usable as "Offset".
--   AimOffset: yaw / pitch of the shot relative to the forward of the aiming-transform. Directly usable as "AimOffset".
--              A big spread here means the part does not follow the gun (wrong part-id) → see "best parts".
--   Aim-error: (bots only) shot-direction against the direction to the lead-point the bot wanted to hit.
--   Impact:    (bullets only) closest distance of the shot to the target, measured speed, drop and inherited velocity.
-- Usage: "!aimeval on|off|report|reset|verbose". Works for bots and for human players in vehicles.

---@type Vehicles
local m_Vehicles = require('Vehicles')
---@type Utilities
local m_Utilities = require('__shared/Utilities')

local MAX_MUZZLE_DISTANCE = 40.0 -- m. Gunships are big.
local MAX_MATCH_ANGLE = 0.5      -- rad. Only used to decide which seat fired, not as aim-limit.
local MAX_PENDING_TIME = 6.0     -- s. Shots without collision are dropped after that.

local s_Pi = math.pi

local function _Wrap(p_Angle)
	if p_Angle > s_Pi then
		return p_Angle - 2 * s_Pi
	elseif p_Angle < -s_Pi then
		return p_Angle + 2 * s_Pi
	end
	return p_Angle
end

---yaw in the bot-convention (decreasing = turning left), pitch positive = up.
local function _YawPitch(p_X, p_Y, p_Z)
	local s_AtanDzDx = math.atan(p_Z, p_X)
	local s_Yaw = (s_AtanDzDx > s_Pi / 2) and (s_AtanDzDx - s_Pi / 2) or (s_AtanDzDx + 3 * s_Pi / 2)
	return s_Yaw, math.atan(p_Y, math.sqrt(p_X * p_X + p_Z * p_Z))
end

local function _NewStat()
	return { n = 0, sum = 0.0, sq = 0.0 }
end

local function _Add(p_Stat, p_Value)
	p_Stat.n = p_Stat.n + 1
	p_Stat.sum = p_Stat.sum + p_Value
	p_Stat.sq = p_Stat.sq + p_Value * p_Value
end

local function _Mean(p_Stat)
	if p_Stat.n == 0 then
		return 0.0
	end
	return p_Stat.sum / p_Stat.n
end

local function _Std(p_Stat)
	if p_Stat.n < 2 then
		return 0.0
	end
	local s_Mean = p_Stat.sum / p_Stat.n
	return math.sqrt(math.max(0.0, p_Stat.sq / p_Stat.n - s_Mean * s_Mean))
end

local function _Fmt(p_Stat, p_Format)
	return string.format(p_Format .. " (±" .. p_Format .. ")", _Mean(p_Stat), _Std(p_Stat))
end

---Deviation in words: GetDeviationFromTransform returns yaw > 0 for left and pitch < 0 for up.
local function _Words(p_YawDev, p_PitchDev)
	return string.format("%.2f° %s, %.2f° %s",
		math.abs(math.deg(p_YawDev)), p_YawDev > 0 and "left" or "right",
		math.abs(math.deg(p_PitchDev)), p_PitchDev < 0 and "high" or "low")
end

function AimEvaluation:__init()
	self.m_Enabled = Registry.DEBUG.AIM_EVALUATION == true
	self.m_Verbose = false
	self:Reset()
end

function AimEvaluation:Reset()
	self._Groups = {}
	self._GroupOrder = {}
	self._Pending = {}
	self._ReportTimer = 0.0
	self._Dirty = false
	-- Diagnostics: shows where shots get lost when the report stays empty.
	self._Seen = {}          -- projectiles per entity-type from the EntityFactory-hook
	self._NoVehicleNear = 0  -- no player in a vehicle close to the spawn (e.g. infantry)
	self._NoSeatMatch = 0    -- vehicle close, but no seat / weapon pointing that way
	self._UnknownVehicle = 0 -- vehicle close, but not in VehicleData
	self._MovingAtImpact = 0 -- only matched at impact, but the vehicle moved in between
	self._MatchedAtSpawn = 0
	self._MatchedAtImpact = 0
	self._Collisions = 0
	self._DiagnosticsLeft = 5 -- print details of the first unmatched projectiles
end

-- Instance-ids are reused on the next level. The statistics stay until "!aimeval reset".
function AimEvaluation:OnLevelDestroy()
	self._Pending = {}
end

---@param p_Enabled boolean
function AimEvaluation:SetEnabled(p_Enabled)
	self.m_Enabled = p_Enabled
	if not p_Enabled then
		self._Pending = {}
	end
end

function AimEvaluation:IsEnabled()
	return self.m_Enabled
end

---@param p_Verbose boolean
function AimEvaluation:SetVerbose(p_Verbose)
	self.m_Verbose = p_Verbose
end

-- =============================================
-- Transform the bot-aiming uses for a seat and weapon (same logic as VehicleAiming).
-- =============================================

---@param p_Vehicle ControllableEntity
---@param p_VehicleData VehicleDataInner
---@param p_EntryId integer
---@param p_Slot integer
---@return LinearTransform|nil
---@return integer partId
function AimEvaluation:_GetAimTransform(p_Vehicle, p_VehicleData, p_EntryId, p_Slot)
	local s_PartId = m_Vehicles:GetPartIdForSeat(p_VehicleData, p_EntryId, p_Slot)
	if s_PartId >= 0 then
		local s_QuatTransform = p_Vehicle.physicsEntityBase:GetPartTransform(s_PartId)
		if s_QuatTransform then
			return s_QuatTransform:ToLinearTransform(), s_PartId
		end
		return nil, s_PartId
	elseif m_Vehicles:IsAirVehicle(p_VehicleData) and p_EntryId == 0 then
		return p_Vehicle.transform, s_PartId
	end
	return nil, s_PartId
end

---Configured angle of the shot relative to the aiming-part. Gunships have their own field (RotationOffset: yaw around
---up, then pitch around the new left), which ends up in the same convention as AimOffset.
---@return number yaw
---@return number pitch
---@return string fieldName
local function _ConfiguredShotAngles(p_VehicleData, p_EntryId, p_Slot)
	if m_Vehicles:IsGunship(p_VehicleData) then
		local s_Rotation = m_Vehicles:GetRotationOffsets(p_VehicleData, p_EntryId, p_Slot) or Vec3.zero
		return s_Rotation.x, s_Rotation.y, "RotationOffset"
	end
	local s_Yaw, s_Pitch = m_Vehicles:GetAimOffsets(p_VehicleData, p_EntryId, p_Slot)
	return s_Yaw, s_Pitch, "AimOffset"
end

---True if a soldier on foot is that close to the position (then the shot is probably from infantry).
---@param p_Pos Vec3
---@param p_Radius number
local function _SoldierOnFootNear(p_Pos, p_Radius)
	local s_Players = PlayerManager:GetPlayers()
	for l_Index = 1, #s_Players do
		local l_Player = s_Players[l_Index]
		local s_Soldier = l_Player.soldier
		if s_Soldier ~= nil and l_Player.attachedControllable == nil then
			local s_Trans = s_Soldier.worldTransform.trans
			local s_DX, s_DY, s_DZ = s_Trans.x - p_Pos.x, s_Trans.y + 1.2 - p_Pos.y, s_Trans.z - p_Pos.z
			if s_DX * s_DX + s_DY * s_DY + s_DZ * s_DZ < p_Radius * p_Radius then
				return true
			end
		end
	end
	return false
end

---Part whose forward matches the shot best. Ties (parts that did not rotate) are decided by the distance to the muzzle.
---@param p_Vehicle ControllableEntity
---@param p_Spawn LinearTransform
---@return integer partId
---@return number angle
function AimEvaluation:_FindBestPart(p_Vehicle, p_Spawn)
	local s_Physics = p_Vehicle.physicsEntityBase
	local s_Dir = p_Spawn.forward
	local s_Pos = p_Spawn.trans
	local s_BestPart, s_BestScore, s_BestAngle = -1, math.huge, 0.0

	for l_Part = 0, s_Physics.partCount - 1 do
		if s_Physics:GetPart(l_Part) ~= nil then
			local s_QuatTransform = s_Physics:GetPartTransform(l_Part)
			if s_QuatTransform then
				local s_Transform = s_QuatTransform:ToLinearTransform()
				local s_Forward = s_Transform.forward
				local s_Dot = s_Forward.x * s_Dir.x + s_Forward.y * s_Dir.y + s_Forward.z * s_Dir.z
				local s_Angle = math.acos(math.max(-1.0, math.min(1.0, s_Dot)))
				local s_Distance = s_Transform.trans:Distance(s_Pos)
				local s_Score = s_Angle + s_Distance * 0.002 -- 1 m weighs as much as ~0.1°
				if s_Score < s_BestScore then
					s_BestPart, s_BestScore, s_BestAngle = l_Part, s_Score, s_Angle
				end
			end
		end
	end

	return s_BestPart, s_BestAngle
end

-- =============================================
-- Hooks.
-- =============================================

---Finds the vehicle-seat and weapon that fired a shot from this position into this direction.
---@param p_Pos Vec3
---@param p_Dir Vec3
---@param p_OnlyPlayer Player|nil only check this player (known shooter)
---@return table|nil best
---@return string|nil reason why nothing matched
---@return number nearestDistance distance of the nearest vehicle-player (diagnostics)
function AimEvaluation:_FindShooter(p_Pos, p_Dir, p_OnlyPlayer)
	local s_Best = nil
	local s_BestScore = math.huge
	-- Seat close enough, but the shot points elsewhere than configured (e.g. wrong part or a wrong / missing offset).
	-- That is what this mode is for, so use it as long as no soldier on foot could have fired.
	local s_Weak = nil
	local s_WeakScore = math.huge
	local s_Reason = "novehicle"
	local s_Nearest = math.huge
	local s_Players = p_OnlyPlayer and { p_OnlyPlayer } or PlayerManager:GetPlayers()

	for l_Index = 1, #s_Players do
		local l_Player = s_Players[l_Index]
		local s_Vehicle = l_Player.controlledControllable
		if s_Vehicle ~= nil and not s_Vehicle:Is('ServerSoldierEntity') then
			local s_VehicleTransform = s_Vehicle.transform
			local s_VehicleDistance = s_VehicleTransform.trans:Distance(p_Pos)
			s_Nearest = math.min(s_Nearest, s_VehicleDistance)
			if s_VehicleDistance < MAX_MUZZLE_DISTANCE then
				local s_VehicleData = m_Vehicles:GetVehicleByEntity(s_Vehicle)
				if s_VehicleData == nil then
					if s_Reason ~= "noseat" then
						s_Reason = "unknown"
					end
				else
					s_Reason = "noseat"
					local s_EntryId = l_Player.controlledEntryId
					local s_Bot = g_BotManager:GetBotByName(l_Player.name)
					local s_Slots = {}
					if s_Bot ~= nil and s_Bot._ActiveVehicleWeaponSlot > 0 then
						s_Slots[1] = s_Bot._ActiveVehicleWeaponSlot
					else
						for l_Slot = 1, math.max(1, m_Vehicles:GetAvailableWeaponSlots(s_VehicleData, s_EntryId)) do
							s_Slots[#s_Slots + 1] = l_Slot
						end
					end

					for l_SlotIndex = 1, #s_Slots do
						local l_Slot = s_Slots[l_SlotIndex]
						local s_AimTransform, s_PartId = self:_GetAimTransform(s_Vehicle, s_VehicleData, s_EntryId, l_Slot)
						local s_RefTransform = s_AimTransform or s_VehicleTransform
						local s_YawDev, s_PitchDev = m_Utilities:GetDeviationFromTransform(s_RefTransform, p_Dir.x, p_Dir.y, p_Dir.z)
						-- Compare against the configured shot-direction (gunship-guns point sideways).
						local s_CfgYaw, s_CfgPitch = _ConfiguredShotAngles(s_VehicleData, s_EntryId, l_Slot)
						local s_ErrYaw = _Wrap(s_YawDev - s_CfgYaw)
						local s_ErrPitch = s_PitchDev - s_CfgPitch
						local s_Angle = math.sqrt(s_ErrYaw * s_ErrYaw + s_ErrPitch * s_ErrPitch)
						-- Without an aiming-transform (soldier-based aiming) the angle to the vehicle says nothing.
						-- With a known shooter the angle must not reject: a wrong part is exactly what we look for.
						if s_AimTransform == nil or p_OnlyPlayer ~= nil then
							s_Angle = 0.0
						end
						local s_Distance = s_RefTransform.trans:Distance(p_Pos)
						local s_Score = s_Distance + s_Angle * 40.0
						local s_Candidate = {
							Player = l_Player,
							Bot = s_Bot,
							Vehicle = s_Vehicle,
							VehicleData = s_VehicleData,
							EntryId = s_EntryId,
							Slot = l_Slot,
							PartId = s_PartId,
							AimTransform = s_AimTransform,
							YawDev = s_YawDev,
							PitchDev = s_PitchDev,
						}
						if s_Angle < MAX_MATCH_ANGLE then
							if s_Score < s_BestScore then
								s_BestScore = s_Score
								s_Best = s_Candidate
							end
						elseif s_Distance < s_WeakScore then
							s_WeakScore = s_Distance
							s_Weak = s_Candidate
						end
					end
				end
			end
		end
	end

	if s_Best == nil and s_Weak ~= nil and not _SoldierOnFootNear(p_Pos, 3.0) then
		s_Best = s_Weak
	end

	return s_Best, s_Best == nil and s_Reason or nil, s_Nearest
end

---Transform of a projectile-entity. Bullets keep their spawn-transform (the old "!car"-offset-tool relies on that).
---@param p_Entity Entity|nil
---@return LinearTransform|nil
local function _EntityTransform(p_Entity)
	if p_Entity == nil then
		return nil
	end
	local s_Transform = SpatialEntity(p_Entity).transform
	local s_Trans = s_Transform.trans
	if s_Trans.x == 0.0 and s_Trans.y == 0.0 and s_Trans.z == 0.0 then
		return nil
	end
	return s_Transform
end

---Called from the EntityFactory:Create hook for projectiles.
---@param p_Transform LinearTransform transform passed to the factory
---@param p_Entity Entity|nil created entity
---@param p_TypeName string
function AimEvaluation:OnProjectileCreated(p_Transform, p_Entity, p_TypeName)
	self._Seen[p_TypeName] = (self._Seen[p_TypeName] or 0) + 1
	self._Dirty = true

	-- Not sure which of both is the muzzle for every projectile-type: try the entity first, then the factory-transform.
	local s_EntityTransform = _EntityTransform(p_Entity)
	local s_Best, s_Reason, s_Nearest, s_Spawn = nil, nil, math.huge, nil
	if s_EntityTransform ~= nil then
		s_Best, s_Reason, s_Nearest = self:_FindShooter(s_EntityTransform.trans, s_EntityTransform.forward, nil)
		s_Spawn = s_EntityTransform
	end
	if s_Best == nil then
		local s_Reason2, s_Nearest2
		s_Best, s_Reason2, s_Nearest2 = self:_FindShooter(p_Transform.trans, p_Transform.forward, nil)
		s_Spawn = p_Transform
		if s_Reason == nil or s_Reason2 == "noseat" then
			s_Reason = s_Reason2
		end
		s_Nearest = math.min(s_Nearest, s_Nearest2)
	end

	if s_Best ~= nil then
		self._MatchedAtSpawn = self._MatchedAtSpawn + 1
		local s_Pending = self:_Evaluate(s_Best, s_Spawn, p_TypeName, SharedUtils:GetTime())
		if p_Entity ~= nil then
			self._Pending[p_Entity.instanceId] = s_Pending
		end
		return
	end

	self:_CountMiss(s_Reason)
	if self._DiagnosticsLeft > 0 then
		self._DiagnosticsLeft = self._DiagnosticsLeft - 1
		print(string.format("[AimEval] unmatched %s: factory-pos %s, entity-pos %s, nearest vehicle-player %.1f m, reason %s",
			p_TypeName, tostring(p_Transform.trans), s_EntityTransform and tostring(s_EntityTransform.trans) or "-",
			s_Nearest, tostring(s_Reason)))
	end

	-- Retry on impact, there the shooter is known.
	if p_Entity ~= nil then
		self._Pending[p_Entity.instanceId] = { Time = SharedUtils:GetTime(), TypeName = p_TypeName }
	end
end

---@param p_Reason string|nil
function AimEvaluation:_CountMiss(p_Reason)
	if p_Reason == "noseat" then
		self._NoSeatMatch = self._NoSeatMatch + 1
	elseif p_Reason == "unknown" then
		self._UnknownVehicle = self._UnknownVehicle + 1
	else
		self._NoVehicleNear = self._NoVehicleNear + 1
	end
end

---Statistics of one shot.
---@param p_Best table result of _FindShooter
---@param p_Spawn LinearTransform
---@param p_TypeName string
---@param p_Time number|nil spawn-time, nil if unknown (no ballistics then)
---@return table pending shot for the impact-evaluation
function AimEvaluation:_Evaluate(p_Best, p_Spawn, p_TypeName, p_Time)
	local s_Dir = p_Spawn.forward
	local s_Pos = p_Spawn.trans
	local s_Group = self:_GetGroup(p_Best)
	local s_Line = nil
	if self.m_Verbose then
		s_Line = string.format("[AimEval] %s seat %d slot %d (%s, %s):", p_Best.VehicleData.Name or "?", p_Best.EntryId,
			p_Best.Slot, p_Best.Bot and "bot" or "player", p_TypeName)
	end

	-- 1) Muzzle-offset and alignment of the aiming-transform.
	if p_Best.AimTransform ~= nil then
		local s_T = p_Best.AimTransform
		local s_Trans = s_T.trans
		local s_DX, s_DY, s_DZ = s_Pos.x - s_Trans.x, s_Pos.y - s_Trans.y, s_Pos.z - s_Trans.z
		local s_Left, s_Up, s_Forward = s_T.left, s_T.up, s_T.forward
		local s_OffX = s_DX * s_Left.x + s_DY * s_Left.y + s_DZ * s_Left.z
		local s_OffY = s_DX * s_Up.x + s_DY * s_Up.y + s_DZ * s_Up.z
		local s_OffZ = s_DX * s_Forward.x + s_DY * s_Forward.y + s_DZ * s_Forward.z
		_Add(s_Group.OffX, s_OffX)
		_Add(s_Group.OffY, s_OffY)
		_Add(s_Group.OffZ, s_OffZ)
		_Add(s_Group.BoreYaw, p_Best.YawDev)
		_Add(s_Group.BorePitch, p_Best.PitchDev)

		if s_Line then
			local s_Configured = m_Vehicles:GetOffsets(p_Best.VehicleData, p_Best.EntryId, p_Best.Slot)
			s_Line = s_Line .. string.format(" offset Vec3(%.3f, %.3f, %.3f) (configured Vec3(%.3f, %.3f, %.3f)), shot %s of part",
				s_OffX, s_OffY, s_OffZ, s_Configured.x, s_Configured.y, s_Configured.z, _Words(p_Best.YawDev, p_Best.PitchDev))
		end
	end

	-- 2) Which part really follows the gun.
	local s_BestPart, s_BestPartAngle = self:_FindBestPart(p_Best.Vehicle, p_Spawn)
	s_Group.BestParts[s_BestPart] = (s_Group.BestParts[s_BestPart] or 0) + 1
	if s_Line then
		s_Line = s_Line .. string.format(" | best part %d (%.2f°)", s_BestPart, math.deg(s_BestPartAngle))
	end

	-- 3) Aim-error of the bot against its lead-point.
	local s_Bot = p_Best.Bot
	local s_ShooterVelocity = PhysicsEntity(p_Best.Vehicle).velocity
	local s_Pending = {
		Group = s_Group,
		Time = p_Time,
		PosX = s_Pos.x, PosY = s_Pos.y, PosZ = s_Pos.z,
		DirX = s_Dir.x, DirY = s_Dir.y, DirZ = s_Dir.z,
		VelX = s_ShooterVelocity.x, VelY = s_ShooterVelocity.y, VelZ = s_ShooterVelocity.z,
		TargetId = nil,
		TargetIsVehicle = false,
	}

	if s_Bot ~= nil and s_Bot._ShootPlayer ~= nil and s_Bot._AttackPosition ~= nil then
		local s_Lead = s_Bot._AttackPosition
		local s_LX, s_LY, s_LZ = s_Lead.x - s_Pos.x, s_Lead.y - s_Pos.y, s_Lead.z - s_Pos.z
		local s_LeadDistance = math.sqrt(s_LX * s_LX + s_LY * s_LY + s_LZ * s_LZ)
		if s_LeadDistance > 1.0 then
			local s_LeadYaw, s_LeadPitch = _YawPitch(s_LX, s_LY, s_LZ)
			local s_ShotYaw, s_ShotPitch = _YawPitch(s_Dir.x, s_Dir.y, s_Dir.z)
			-- Same sign-convention as the deviations: yaw > 0 → shot left of lead-point, pitch < 0 → shot high.
			local s_ErrYaw = -_Wrap(s_ShotYaw - s_LeadYaw)
			local s_ErrPitch = s_LeadPitch - s_ShotPitch
			local s_ErrAngle = math.sqrt(s_ErrYaw * s_ErrYaw + s_ErrPitch * s_ErrPitch)
			_Add(s_Group.AimYaw, s_ErrYaw)
			_Add(s_Group.AimPitch, s_ErrPitch)
			_Add(s_Group.AimMiss, s_ErrAngle * s_LeadDistance)
			_Add(s_Group.AimDistance, s_LeadDistance)
			if s_Line then
				s_Line = s_Line .. string.format(" | aim %s of lead-point → %.1f m miss at %.0f m", _Words(s_ErrYaw, s_ErrPitch),
					s_ErrAngle * s_LeadDistance, s_LeadDistance)
			end
		end
		s_Pending.TargetId = s_Bot._ShootPlayer.id
		s_Pending.TargetIsVehicle = s_Bot._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle
	end

	if s_Line then
		print(s_Line)
	end

	self._Dirty = true
	return s_Pending
end

---Called from the BulletEntity:Collision hook.
---@param p_Entity Entity
---@param p_Hit RayCastHit
---@param p_GiverInfo DamageGiverInfo
function AimEvaluation:OnBulletCollision(p_Entity, p_Hit, p_GiverInfo)
	local s_Id = p_Entity.instanceId
	local s_Shot = self._Pending[s_Id]
	self._Pending[s_Id] = nil
	self._Collisions = self._Collisions + 1
	self._Dirty = true

	if s_Shot == nil or s_Shot.Group == nil then
		-- Not matched on spawn: the giver is the shooter and the bullet still has its spawn-transform.
		local s_Giver = p_GiverInfo and p_GiverInfo.giver
		local s_Spawn = _EntityTransform(p_Entity)
		if s_Giver == nil or s_Spawn == nil then
			return
		end
		local s_Best, s_Reason = self:_FindShooter(s_Spawn.trans, s_Spawn.forward, s_Giver)
		-- The vehicle kept moving while the bullet flew: offsets against its current position would be wrong.
		if s_Best ~= nil then
			local s_Speed = PhysicsEntity(s_Best.Vehicle).velocity.magnitude
			local s_FlightTime = s_Shot and (SharedUtils:GetTime() - s_Shot.Time) or nil
			if (s_FlightTime and s_Speed * s_FlightTime > 1.0) or (s_FlightTime == nil and s_Speed > 1.0) then
				self._MovingAtImpact = self._MovingAtImpact + 1
				return
			end
		end
		if s_Best == nil then
			if s_Shot == nil then
				-- Not seen on spawn either (only collisions arrive for this type).
				self:_CountMiss(s_Reason)
			end
			return
		end
		self._MatchedAtImpact = self._MatchedAtImpact + 1
		s_Shot = self:_Evaluate(s_Best, s_Spawn, "impact", s_Shot and s_Shot.Time or nil)
	end

	local s_Group = s_Shot.Group
	local s_Hit = p_Hit.position
	local s_DX, s_DY, s_DZ = s_Hit.x - s_Shot.PosX, s_Hit.y - s_Shot.PosY, s_Hit.z - s_Shot.PosZ
	local s_Length = math.sqrt(s_DX * s_DX + s_DY * s_DY + s_DZ * s_DZ)
	_Add(s_Group.Impacts, 1)

	-- Ballistics: displacement = dir * speed * t + k * shooterVelocity * t - 0.5 * g * t² * up.
	-- Solve the part perpendicular to the shot-direction for k and g (least squares), then the speed along it.
	local s_DeltaTime = s_Shot.Time and (SharedUtils:GetTime() - s_Shot.Time) or 0.0
	if s_DeltaTime > 0.05 and s_Length > 20.0 then
		local s_FX, s_FY, s_FZ = s_Shot.DirX, s_Shot.DirY, s_Shot.DirZ
		local function _Perp(p_X, p_Y, p_Z)
			local s_Dot = p_X * s_FX + p_Y * s_FY + p_Z * s_FZ
			return p_X - s_Dot * s_FX, p_Y - s_Dot * s_FY, p_Z - s_Dot * s_FZ
		end
		local s_PX, s_PY, s_PZ = _Perp(s_DX, s_DY, s_DZ)
		local s_T = s_DeltaTime
		local s_AX, s_AY, s_AZ = _Perp(s_Shot.VelX * s_T, s_Shot.VelY * s_T, s_Shot.VelZ * s_T)
		local s_BX, s_BY, s_BZ = _Perp(0.0, -0.5 * s_T * s_T, 0.0)

		local s_AA = s_AX * s_AX + s_AY * s_AY + s_AZ * s_AZ
		local s_BB = s_BX * s_BX + s_BY * s_BY + s_BZ * s_BZ
		local s_AB = s_AX * s_BX + s_AY * s_BY + s_AZ * s_BZ
		local s_PA = s_PX * s_AX + s_PY * s_AY + s_PZ * s_AZ
		local s_PB = s_PX * s_BX + s_PY * s_BY + s_PZ * s_BZ

		local s_K, s_G = 0.0, 0.0
		local s_Det = s_AA * s_BB - s_AB * s_AB
		if s_AA > 1.0 and math.abs(s_Det) > 1e-6 then
			s_K = (s_PA * s_BB - s_PB * s_AB) / s_Det
			s_G = (s_AA * s_PB - s_AB * s_PA) / s_Det
			_Add(s_Group.Inherit, s_K)
		elseif s_BB > 1e-6 then
			s_G = s_PB / s_BB
		end
		_Add(s_Group.Gravity, s_G)

		local s_Along = s_DX * s_FX + s_DY * s_FY + s_DZ * s_FZ
		local s_VelAlong = s_Shot.VelX * s_FX + s_Shot.VelY * s_FY + s_Shot.VelZ * s_FZ
		local s_Speed = (s_Along - s_K * s_VelAlong * s_T + 0.5 * s_G * s_T * s_T * s_FY) / s_T
		_Add(s_Group.Speed, s_Speed)
	end

	-- Closest distance of the flight-path (straight approximation) to the target at impact-time.
	if s_Shot.TargetId ~= nil then
		local s_Target = PlayerManager:GetPlayerById(s_Shot.TargetId)
		if s_Target ~= nil and s_Target.soldier ~= nil then
			local s_TargetPos
			if s_Shot.TargetIsVehicle and s_Target.controlledControllable ~= nil then
				s_TargetPos = s_Target.controlledControllable.transform.trans
			else
				s_TargetPos = s_Target.soldier.worldTransform.trans
			end
			local s_TX, s_TY, s_TZ = s_TargetPos.x - s_Shot.PosX, s_TargetPos.y - s_Shot.PosY, s_TargetPos.z - s_Shot.PosZ
			local s_Proj = 0.0
			if s_Length > 0 then
				s_Proj = math.max(0.0, math.min(s_Length, (s_TX * s_DX + s_TY * s_DY + s_TZ * s_DZ) / s_Length))
			end
			local s_Scale = s_Length > 0 and s_Proj / s_Length or 0.0
			local s_CX, s_CY, s_CZ = s_TX - s_DX * s_Scale, s_TY - s_DY * s_Scale, s_TZ - s_DZ * s_Scale
			_Add(s_Group.ImpactMiss, math.sqrt(s_CX * s_CX + s_CY * s_CY + s_CZ * s_CZ))
		end
	end
end

---@param p_DeltaTime number
function AimEvaluation:OnEngineUpdate(p_DeltaTime)
	if not self.m_Enabled then
		return
	end

	self._ReportTimer = self._ReportTimer + p_DeltaTime
	if self._ReportTimer < Registry.DEBUG.AIM_EVALUATION_REPORT_INTERVAL then
		return
	end
	self._ReportTimer = 0.0

	-- Drop shots that never hit anything.
	local s_Now = SharedUtils:GetTime()
	for l_Id, l_Shot in pairs(self._Pending) do
		if s_Now - l_Shot.Time > MAX_PENDING_TIME then
			self._Pending[l_Id] = nil
		end
	end

	if self._Dirty then
		self._Dirty = false
		self:PrintReport()
	end
end

-- =============================================
-- Statistics.
-- =============================================

function AimEvaluation:_GetGroup(p_Info)
	local s_Key = (p_Info.VehicleData.Name or "?") .. "|" .. p_Info.EntryId .. "|" .. p_Info.Slot
	local s_Group = self._Groups[s_Key]
	if s_Group == nil then
		s_Group = {
			VehicleName = m_Vehicles:GetVehicleName(p_Info.Player) or "?",
			Name = p_Info.VehicleData.Name or "?",
			VehicleData = p_Info.VehicleData,
			EntryId = p_Info.EntryId,
			Slot = p_Info.Slot,
			PartId = p_Info.PartId,
			HasAimTransform = p_Info.AimTransform ~= nil,
			OffX = _NewStat(), OffY = _NewStat(), OffZ = _NewStat(),
			BoreYaw = _NewStat(), BorePitch = _NewStat(),
			AimYaw = _NewStat(), AimPitch = _NewStat(), AimMiss = _NewStat(), AimDistance = _NewStat(),
			ImpactMiss = _NewStat(), Impacts = _NewStat(), Speed = _NewStat(), Gravity = _NewStat(), Inherit = _NewStat(),
			BestParts = {},
			Shots = 0,
		}
		self._Groups[s_Key] = s_Group
		self._GroupOrder[#self._GroupOrder + 1] = s_Key
	end
	s_Group.Shots = s_Group.Shots + 1
	return s_Group
end

---@param p_Player Player|nil if set, a short summary is sent to the chat of this player
function AimEvaluation:PrintReport(p_Player)
	print("========== [AimEval] report ==========")
	local s_Seen = {}
	for l_Type, l_Count in pairs(self._Seen) do
		s_Seen[#s_Seen + 1] = l_Type .. ": " .. l_Count
	end
	local s_Status = string.format("projectiles seen [%s], impacts %d, matched at spawn %d / at impact %d, "
		.. "not matched: no vehicle near %d, vehicle not in VehicleData %d, no seat pointing that way %d, vehicle moved until impact %d",
		table.concat(s_Seen, ", "), self._Collisions, self._MatchedAtSpawn, self._MatchedAtImpact,
		self._NoVehicleNear, self._UnknownVehicle, self._NoSeatMatch, self._MovingAtImpact)
	print(s_Status)
	if p_Player then
		ChatManager:SendMessage('AimEval ' .. (self.m_Enabled and 'on' or 'OFF') .. ': ' .. s_Status, p_Player)
	end

	if #self._GroupOrder == 0 then
		if #s_Seen == 0 and self._Collisions == 0 then
			print("no projectile was created or hit anything yet")
		else
			print("no vehicle-shots recorded yet")
		end
		return
	end

	for l_Index = 1, #self._GroupOrder do
		local s_Group = self._Groups[self._GroupOrder[l_Index]]
		local s_Data = s_Group.VehicleData
		print(string.format("--- %s (%s) seat %d, weapon %d: %d shots, configured part %d",
			s_Group.Name, s_Group.VehicleName, s_Group.EntryId, s_Group.Slot, s_Group.Shots, s_Group.PartId))

		local s_Parts = {}
		for l_Part, l_Count in pairs(s_Group.BestParts) do
			s_Parts[#s_Parts + 1] = "part " .. l_Part .. ": " .. l_Count
		end
		print("  best matching parts:   " .. table.concat(s_Parts, ", "))

		if s_Group.OffX.n > 0 then
			local s_Configured = m_Vehicles:GetOffsets(s_Data, s_Group.EntryId, s_Group.Slot)
			local s_CfgYaw, s_CfgPitch, s_Field = _ConfiguredShotAngles(s_Data, s_Group.EntryId, s_Group.Slot)
			print("  Offset    measured:    " .. string.format("Vec3(%.3f, %.3f, %.3f)", _Mean(s_Group.OffX), _Mean(s_Group.OffY), _Mean(s_Group.OffZ))
				.. string.format("  spread (%.3f, %.3f, %.3f)", _Std(s_Group.OffX), _Std(s_Group.OffY), _Std(s_Group.OffZ)))
			print("            configured:  " .. string.format("Vec3(%.3f, %.3f, %.3f)", s_Configured.x, s_Configured.y, s_Configured.z))
			print(string.format("  %-16s measured: ", s_Field) .. string.format("Vec3(%.4f, %.4f, 0)", _Mean(s_Group.BoreYaw), _Mean(s_Group.BorePitch))
				.. string.format("  spread (%.4f, %.4f)", _Std(s_Group.BoreYaw), _Std(s_Group.BorePitch))
				.. "  = shot " .. _Words(_Mean(s_Group.BoreYaw), _Mean(s_Group.BorePitch)) .. " of part-forward")
			print("                   configured: " .. string.format("Vec3(%.4f, %.4f, 0)", s_CfgYaw, s_CfgPitch))
			if _Std(s_Group.BoreYaw) > 0.02 or _Std(s_Group.BorePitch) > 0.02 then
				print("  WARNING: shot-direction does not follow the part → probably wrong part-id (see best matching parts)")
			end
		else
			print("  no aiming-part (soldier-based aiming) → Offset / AimOffset not used for this seat")
		end

		if s_Group.AimYaw.n > 0 then
			print("  bot aim-error:         yaw " .. _Fmt(s_Group.AimYaw, "%.4f") .. ", pitch " .. _Fmt(s_Group.AimPitch, "%.4f")
				.. " rad → " .. _Fmt(s_Group.AimMiss, "%.1f") .. " m miss at " .. string.format("%.0f", _Mean(s_Group.AimDistance)) .. " m"
				.. "  (mean = shot " .. _Words(_Mean(s_Group.AimYaw), _Mean(s_Group.AimPitch)) .. ")")
		end

		local s_Speed, s_Drop = m_Vehicles:GetSpeedAndDrop(s_Data, s_Group.EntryId, s_Group.Slot)
		if s_Group.Impacts.n > 0 then
			local s_Line = "  impacts:               " .. s_Group.Impacts.n
			if s_Group.Speed.n > 0 then
				s_Line = s_Line .. string.format(", speed %s m/s (configured %d), gravity %s (configured %.2f)",
					_Fmt(s_Group.Speed, "%.0f"), s_Speed, _Fmt(s_Group.Gravity, "%.2f"), s_Drop)
			end
			print(s_Line)
		end
		if s_Group.Inherit.n > 0 then
			print("  inherited velocity:    " .. _Fmt(s_Group.Inherit, "%.2f") .. " (1.0 = shot gets full vehicle-velocity)")
		end
		if s_Group.ImpactMiss.n > 0 then
			print("  closest to target:     " .. _Fmt(s_Group.ImpactMiss, "%.1f") .. " m")
		end

		if p_Player then
			local s_Message = string.format("AimEval %s s%d w%d: %d shots", s_Group.Name, s_Group.EntryId, s_Group.Slot, s_Group.Shots)
			if s_Group.AimMiss.n > 0 then
				s_Message = s_Message .. string.format(", aim-miss %.1fm", _Mean(s_Group.AimMiss))
			end
			if s_Group.ImpactMiss.n > 0 then
				s_Message = s_Message .. string.format(", target-miss %.1fm", _Mean(s_Group.ImpactMiss))
			end
			ChatManager:SendMessage(s_Message, p_Player)
		end
	end
	print("Speed / gravity / inherited velocity are estimated from frame-times: expect some % error, compare means.")
	print("======================================")
end

if g_AimEvaluation == nil then
	---@type AimEvaluation
	g_AimEvaluation = AimEvaluation()
end

return g_AimEvaluation
