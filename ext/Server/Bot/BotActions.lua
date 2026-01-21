---@type Vehicles
local m_Vehicles = require('Vehicles')

-- Initialize a revive on a teammate.
---@param p_Player Player the player to revive.
function Bot:Revive(p_Player)
	-- Config for revives disabled.
	if not Config.BotsRevive then return end

	-- TODO: if some mod allows defib in other kits then this isn't accurate.
	-- Only Assaults can revive.
	if self.m_Kit ~= BotKits.Assault then return end

	-- TODO: if some mod allows defib in one of these modes then this isn't accurate.
	-- These gamemodes don't allow revives.
	if Globals.IsGm or Globals.IsScavenger then return end

	-- The player to revive is not revivable. Could be already alive or dead.
	if not p_Player.corpse or p_Player.corpse.isDead then return end

	-- The bot is not alive.
	if not self.m_Player.soldier then return end

	--[[
		TODO: if some mod allows defib in other weapon slots then this isn't accurate.
		Might make sense to create a m_HasDefibrillator bool inside the non-existing Bot.Loadout class.
		And then get rid of all other checks that are not needed.
	]]
	-- Make sure the bot has a defibrillator.
	if self.m_Player.soldier.weaponsComponent.weapons[6] and
		string.find(self.m_Player.soldier.weaponsComponent.weapons[6].name, "Defibrillator") then
		self._ActiveAction = BotActionFlags.ReviveActive
		self._ShootPlayerId = p_Player.id
		self._ShootPlayer = PlayerManager:GetPlayerById(self._ShootPlayerId)
		self._ShootPlayerVehicleType = VehicleTypes.NoVehicle -- does not matter here
	end
end

---@param p_Player Player
function Bot:Repair(p_Player)
	if self.m_Kit == BotKits.Engineer and p_Player.soldier ~= nil and p_Player.controlledControllable ~= nil then
		self._ActiveAction = BotActionFlags.RepairActive
		self._RepairVehicleEntity = p_Player.controlledControllable
		self._LastVehicleHealth = 0.0
		self._ShootPlayerId = p_Player.id
		self._ShootPlayer = PlayerManager:GetPlayerById(self._ShootPlayerId)
		self._ShootPlayerVehicleType = VehicleTypes.NoVehicle -- does not matter here
		self._ShootModeTimer = Registry.BOT.MAX_TIME_TRY_REPAIR
	end
end

---@param p_Player Player
function Bot:EnterVehicleOfPlayer(p_Player)
	self._ActiveAction = BotActionFlags.EnterVehicleActive
	self._ShootPlayerId = p_Player.id
	self._ShootPlayer = PlayerManager:GetPlayerById(self._ShootPlayerId)
	self._ShootPlayerVehicleType = VehicleTypes.NoVehicle -- does not matter here
	self._ShootModeTimer = 12.0
end

---@param p_Player Player
---@param p_IgnoreYaw boolean
---@return boolean
function Bot:ShootAt(p_Player, p_IgnoreYaw)
	if p_IgnoreYaw and self._DefendTimer == 0.0 then -- was hit, not in defend-mode, check for special behavior
		if self.m_Behavior == BotBehavior.DontShootBackHide then
			self._ActionTimer = 7.0
			self._ActiveAction = BotActionFlags.HideOnAttack
			return false
		elseif self.m_Behavior == BotBehavior.DontShootBackBail then
			self._ActionTimer = 5.0
			self._ActiveAction = BotActionFlags.RunAway
			return false
		end
	end

	-- Don't shoot at teammates.
	if self.m_Player.teamId == p_Player.teamId then
		return false
	end

	if p_Player.soldier == nil or self.m_Player.soldier == nil then
		return false
	end

	-- Check for vehicles.
	local s_Type = m_Vehicles:FindOutVehicleType(p_Player)

	-- Don't shoot at stationary AA.
	if s_Type == VehicleTypes.StationaryAA then
		return false
	end

	local s_NewAttackPriority = self:GetAttackPriority(s_Type)
	local s_NewTarget = self._ShootPlayerId ~= p_Player.id

	local s_Ready = (s_NewAttackPriority > self.m_AttackPriority) or self:IsReadyToAttack(p_IgnoreYaw, p_Player, true, s_NewTarget)
	if not s_Ready or self._Shoot == false or self._DontAttackPlayers then
		return false
	end

	-- Don't shoot if too far away.
	self._DistanceToPlayer = 0.0
	local s_PlayerPos = nil
	local s_TargetPos = nil
	if s_Type == VehicleTypes.MavBot or s_Type == VehicleTypes.MobileArtillery then
		s_TargetPos = p_Player.controlledControllable.transform.trans:Clone()
	else
		s_TargetPos = p_Player.soldier.worldTransform.trans:Clone()
	end

	if m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.MobileArtillery) then
		s_PlayerPos = self.m_Player.controlledControllable.transform.trans:Clone()
	else
		s_PlayerPos = self.m_Player.soldier.worldTransform.trans:Clone()
	end

	self._DistanceToPlayer = s_TargetPos:Distance(s_PlayerPos)

	local s_VehicleAttackMode = nil
	local s_InVehicle = g_BotStates:IsInVehicleState(self.m_ActiveState)
	if s_Type ~= VehicleTypes.NoVehicle then
		s_VehicleAttackMode = m_Vehicles:CheckForVehicleAttack(s_Type, self)
		if s_VehicleAttackMode == VehicleAttackModes.NoAttack then
			return false
		end
	end

	-- in lightAA: only attack air-vehicles
	if s_InVehicle and m_Vehicles:IsVehicleType(self.m_ActiveVehicle, VehicleTypes.LightAA) and not m_Vehicles:IsAirVehicleType(s_Type) then
		return false
	end

	local s_AttackDistance = self:GetAttackDistance(p_IgnoreYaw, s_VehicleAttackMode)

	-- Don't attack if too far away.
	if self._DistanceToPlayer > s_AttackDistance then
		return false
	end

	self._ShootPlayerVehicleType = s_Type

	-- If target is air-vehicle and bot is in AA → ignore yaw.
	if m_Vehicles:IsAirVehicleType(s_Type) then
		if (s_InVehicle and m_Vehicles:IsAAVehicle(self.m_ActiveVehicle)) or
			(s_VehicleAttackMode == VehicleAttackModes.AttackWithMissileAir) then
			p_IgnoreYaw = true
		end
	end

	local s_Bot = g_BotManager:GetBotByName(p_Player.name)

	local s_SoundDistance = 100
	if s_Type == VehicleTypes.NoVehicle then
		s_SoundDistance = 50
	end

	if s_Bot ~= nil
		and s_Bot._SoundTimer <= 5.0
		and self._DistanceToPlayer < s_SoundDistance
	then
		p_IgnoreYaw = true
	end

	local s_RelativePitch = 0
	local s_RelativeYaw = 0
	local s_HalfHfov = 0
	local s_HalfVfov = 0
	if not p_IgnoreYaw then
		-- Determine the target's position relative to the bot.
		local s_Vector = s_TargetPos - s_PlayerPos

		-- Compute the pitch and yaw between the bot and its target. These
		-- angles are relative to the absolute coordinate system; pitch is
		-- measured from the x-y plane while yaw is measured from the x axis.
		local s_Pitch = math.atan(s_Vector.z, math.sqrt(s_Vector.x^2 + s_Vector.y^2))
		local s_Yaw = math.atan(s_Vector.y, s_Vector.x)

		-- Transform the pitch and yaw to be relative to the bot's current
		-- heading.
		s_RelativePitch = s_Pitch - self.m_Player.input.authoritativeAimingPitch
		s_RelativeYaw = s_Yaw - self.m_Player.input.authoritativeAimingYaw

		-- Halve configured horizontal & vertical FOVs and convert them to
		-- radians.
		if s_InVehicle then
			if m_Vehicles:IsAAVehicle(self.m_ActiveVehicle) then
				s_HalfHfov = Config.FovVehicleAAForShooting
				s_HalfVfov = Config.FovVerticleVehicleAAForShooting
			elseif m_Vehicles:IsAirVehicle(self.m_ActiveVehicle) and
				self.m_Player.controlledEntryId == 0 then
				s_HalfHfov = Config.FovVehicleForShooting
				s_HalfVfov = Config.FovVerticleChopperForShooting
			else
				s_HalfHfov = Config.FovVehicleForShooting
				s_HalfVfov = Config.FovVerticleVehicleForShooting
			end
		else
			s_HalfHfov = Config.FovForShooting
			s_HalfVfov = Config.FovVerticleForShooting
		end
		s_HalfHfov = math.rad(s_HalfHfov / 2)
		s_HalfVfov = math.rad(s_HalfVfov / 2)
	end

	if p_IgnoreYaw or (math.abs(s_RelativeYaw) < s_HalfHfov
	                   and math.abs(s_RelativePitch) < s_HalfVfov) then
		if self._Shoot then
			-- only reset ShotTimer, if not already attacking
			if self._ShootModeTimer <= 0 then
				self._ShotTimer = -self:GetFirstShotDelay(self._DistanceToPlayer, false)
			end
			if s_InVehicle then
				self._ShootModeTimer = Config.BotVehicleFireModeDuration
			else
				self._ShootModeTimer = Config.BotFireModeDuration
				if self.m_Behavior == BotBehavior.LongerAttacking then
					self._ShootModeTimer = Config.BotFireModeDuration * 1.7
				elseif self.m_Behavior == BotBehavior.AbortAttackFast then
					self._ShootModeTimer = Config.BotFireModeDuration * 0.5
				end
			end
			self._ActiveShootDuration = self._ShootModeTimer
			if s_NewTarget then
				self._DoneShootDuration = 0.0
				self._ShootPlayerId = p_Player.id
				self._ShootPlayer = PlayerManager:GetPlayerById(self._ShootPlayerId)
				local s_PlayerData = g_PlayerData:GetData(self._ShootPlayerId)
				if s_PlayerData then
					self._ShootPlayerVehicleType = s_PlayerData.Vehicle
				else
					self._ShootPlayerVehicleType = VehicleTypes.NoVehicle
				end
			end
			self._KnifeWayPositions = {}
			self._VehicleReadyToShoot = false

			if self.m_KnifeMode then
				self._KnifeWayPositions[#self._KnifeWayPositions + 1] = p_Player.soldier.worldTransform.trans:Clone()
			end

			if Globals.IsGm then
				-- check for changed weapon
				BotSpawner:UpdateGmWeapon(self)
			end
			self._KillYourselfTimer = 0.0
			self.m_AttackPriority = s_NewAttackPriority
			return true
		else
			self._ShootPlayerId = -1
			self._ShootPlayer = nil
			self._ShootModeTimer = 0.0
			return false
		end
	end

	return false
end

---@param p_Entity ControllableEntity|nil
---@param p_PlayerIsDriver boolean
---@return integer
---@return Vec3|nil
function Bot:_EnterVehicleEntity(p_Entity, p_PlayerIsDriver)
	if not p_Entity then
		return -2
	end

	local s_Position = p_Entity.transform.trans
	local s_VehicleData = m_Vehicles:GetVehicleByEntity(p_Entity)

	if not s_VehicleData then
		return -2
	end

	if not Config.UseAirVehicles and m_Vehicles:IsAirVehicle(s_VehicleData) then
		return -3 -- Not allowed to use.
	end

	if not Config.UseJets and m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.Plane) then
		return -3 -- Not allowed to use.
	end

	-- Keep one seat free, if enough available.
	local s_MaxEntries = p_Entity.entryCount
	if s_VehicleData.Type == VehicleTypes.Gunship then
		s_MaxEntries = 2
	end
	if s_VehicleData.Type == VehicleTypes.MobileArtillery then
		s_MaxEntries = 1
	end
	-- The idea is to avoid the bots from seating in the 3rd slot of the tanks to be more useful somwhere else.
	if s_VehicleData.Type == VehicleTypes.UnarmedGunship then
		s_MaxEntries = 0
	end

	--Now the bots may fully occupy a vehicle ( attack choppers, scout choppers, and some other transport vehicles.)
	if not p_PlayerIsDriver then
		-- Leave a place for a player if more than two seats are available.
		if s_MaxEntries > 2 and Config.KeepVehicleSeatForPlayer then
			s_MaxEntries = s_MaxEntries - 1
		end
		-- Limit the bots per vehicle, if no player is the driver.
		if s_MaxEntries > Config.MaxBotsPerVehicle then
			s_MaxEntries = Config.MaxBotsPerVehicle
		end
	else
		-- Allow one more bot, if driver is player.
		if s_MaxEntries > (Config.MaxBotsPerVehicle + 1) then
			s_MaxEntries = Config.MaxBotsPerVehicle + 1
		end
	end

	for seatIndex = 0, s_MaxEntries - 1 do
		if s_VehicleData.Type == VehicleTypes.Gunship then
			seatIndex = seatIndex + 1
		end
		if p_Entity:GetPlayerInEntry(seatIndex) == nil or Globals.IsAirSuperiority or (Globals.MapHasDynamiJetSpawns and m_Vehicles:IsVehicleType(s_VehicleData, VehicleTypes.Plane)) then -- already in this seat in air superiority
			self.m_Player:EnterVehicle(p_Entity, seatIndex)
			self._ExitVehicleHealth = PhysicsEntity(p_Entity).internalHealth * (Registry.VEHICLES.VEHICLE_EXIT_HEALTH / 100.0)
			-- Get ID.
			self.m_ActiveVehicle = s_VehicleData
			self._ActiveVehicleWeaponSlot = 0
			self:UpdateVehicleMovableId()
			if seatIndex == 0 then
				if seatIndex == s_MaxEntries - 1 then
					self._VehicleWaitTimer = 0.5 -- Always wait a short time to check for free start.
					if Globals.IsAirSuperiority then
						self._VehicleTakeoffTimer = 0.0
						self._JetTakeoffActive = false
					else
						self._VehicleTakeoffTimer = Registry.VEHICLES.JET_TAKEOFF_TIME
						self._JetTakeoffActive = true
					end
					g_GameDirector:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
				else
					self._VehicleWaitTimer = Config.VehicleWaitForPassengersTime
					self._BrakeTimer = 0.0
				end
			else
				self._VehicleWaitTimer = 0.0

				if seatIndex == s_MaxEntries - 1 then
					-- Last seat taken: Disable vehicle and abort, wait for passengers.
					local s_Driver = p_Entity:GetPlayerInEntry(0)

					if s_Driver ~= nil then
						Events:Dispatch('Bot:AbortWait', s_Driver.id)
						g_GameDirector:_SetVehicleObjectiveState(p_Entity.transform.trans, false)
					end
				end
			end

			return 0, s_Position -- Everything fine.
		end
	end

	-- No place left.
	return -2
end

---@param p_PlayerIsDriver boolean
---@param p_Distance integer|nil
---@return integer
---@return Vec3|nil
function Bot:_EnterVehicle(p_PlayerIsDriver, p_Distance)
	local s_Iterator = EntityManager:GetIterator('ServerVehicleEntity')
	local s_Entity = s_Iterator:Next()

	local s_ClosestEntity = nil
	local s_ClosestDistance = p_Distance or Registry.VEHICLES.MIN_DISTANCE_VEHICLE_ENTER

	while s_Entity ~= nil do
		s_Entity = ControllableEntity(s_Entity)
		local s_Position = s_Entity.transform.trans
		local s_Distance = s_Position:Distance(self.m_Player.soldier.worldTransform.trans)

		if s_Distance < s_ClosestDistance then
			s_ClosestEntity = s_Entity
			s_ClosestDistance = s_Distance
		end

		s_Entity = s_Iterator:Next()
	end

	if s_ClosestEntity ~= nil then
		return self:_EnterVehicleEntity(s_ClosestEntity, p_PlayerIsDriver)
	end

	return -3 -- No vehicle found.
end
