class('Bot')

require('__shared/Config')

local m_NodeCollection = require('__shared/NodeCollection')
local m_PathSwitcher = require('PathSwitcher')
local m_Utilities = require('__shared/Utilities')
local m_Logger = Logger("Bot", Debug.Server.BOT)

function Bot:__init(p_Player)
	--Player Object
	self.m_Player = p_Player
	self.m_Name = p_Player.name
	self.m_Id = p_Player.id

	--common settings
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._MoveMode = BotMoveModes.Standstill
	self.m_Kit = nil
	self.m_Color = nil
	self.m_ActiveWeapon = nil
	self.m_ActiveVehicle = nil
	self.m_Primary = nil
	self.m_Pistol = nil
	self.m_PrimaryGadget = nil
	self.m_SecondaryGadget = nil
	self.m_Grenade = nil
	self.m_Knife = nil
	self._Respawning = false

	--timers
	self._UpdateTimer = 0
	self._AimUpdateTimer = 0
	self._SpawnDelayTimer = 0
	self._WayWaitTimer = 0
	self._WayWaitYawTimer = 0
	self._ObstaceSequenceTimer = 0
	self._StuckTimer = 0
	self._ShotTimer = 0
	self._ShootModeTimer = 0
	self._ReloadTimer = 0
	self._DeployTimer = 0
	self._AttackModeMoveTimer = 0
	self._MeleeCooldownTimer = 0
	self._ShootTraceTimer = 0
	self._ActionTimer = 0
	self._BrakeTimer = 0
	self._SpawnProtectionTimer = 0

	--shared movement vars
	self.m_ActiveMoveMode = BotMoveModes.Standstill
	self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
	self.m_KnifeMode = false
	self.m_InVehicle = false
	self.m_NewInputs = {}
	self.m_ActiveInputs = {}

	--advanced movement
	self._AttackMode = BotAttackModes.RandomNotSet
	self._CurrentWayPoint = nil
	self._TargetYaw = 0
	self._TargetPitch = 0
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._PathIndex = 0
	self._MeleeActive = false
	self._LastWayDistance = 0
	self._InvertPathDirection = false
	self._ObstacleRetryCounter = 0
	self._ZombieSpeedValue = BotMoveSpeeds.NoMovement
	self._Objective = ''
	self._OnSwitch = false
	self._ActionActive = false
	self._ReviveActive = false
	self._EnterVehicleActice = false
	self._GrenadeActive = false
	self._C4Active = false

	-- vehicle stuff
	self._VehicleMovableId = nil
	self._LastVehicleYaw = 0.0
	self._VehicleReadyToShoot = false
	self._FullVehicleSteering = false
	self._VehicleDirBackPositive = false
	self._Esum_drive = 0.0
	self._Esum_yaw = 0.0
	self._Esum_pitch = 0.0

	--shooting
	self._Shoot = false
	self._ShootPlayer = nil
	self._ShootPlayerVehicleType = VehicleTypes.NoVehicle
	self._ShootPlayerName = ""
	self._DistanceToPlayer = 0.0
	self._WeaponToUse = BotWeapons.Primary
	self._ShootWayPoints = {}
	self._KnifeWayPositions = {}
	self._LastTargetTrans = Vec3()
	self._LastShootPlayer = nil
	self._Skill = 0.0

	--simple movement
	self._BotSpeed = BotMoveSpeeds.NoMovement
	self._TargetPlayer = nil
	self._SpawnTransform = LinearTransform()
end

-- =============================================
-- Events
-- =============================================

function Bot:OnUpdatePassPostFrame(p_DeltaTime)
	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:SingleStepEntry(self.m_Player.controlledEntryId)
	end

	if Globals.IsInputAllowed and self._SpawnProtectionTimer <= 0 then
		self._UpdateTimer = self._UpdateTimer + p_DeltaTime

		self:_UpdateYaw(p_DeltaTime)

		if self._UpdateTimer > StaticConfig.BotUpdateCycle then
			self:_SetActiveVars()
			self:_UpdateRespawn()
			self:_UpdateAiming()
			self:_UpdateShooting()
			self:_UpdateMovement()

			self:_UpdateInputs()
			self._UpdateTimer = 0
		end
	else
		if self._SpawnProtectionTimer > 0 then
			self._SpawnProtectionTimer = self._SpawnProtectionTimer - p_DeltaTime
		else
			self._SpawnProtectionTimer = 0
		end

		self:_UpdateYaw(p_DeltaTime)
		self:_LookAround(p_DeltaTime)
		self:_UpdateInputs()
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================

function Bot:Revive(p_Player)
	if self.m_Kit == BotKits.Assault and p_Player.corpse ~= nil then
		if Config.BotsRevive then
			self._ReviveActive = true
			self._ShootPlayer = nil
			self._ShootPlayerName = p_Player.name
		end
	end
end

function Bot:EnterVehicleOfPlayer(p_Player)
	self._EnterVehicleActice = true
	self._ShootPlayer = nil
	self._ShootPlayerName = p_Player.name
end

function Bot:ShootAt(p_Player, p_IgnoreYaw)
	if self._ActionActive or self._ReviveActive or self._EnterVehicleActice or self._GrenadeActive then
		return false
	end

	-- don't shoot at teammates
	if self.m_Player.teamId == p_Player.teamId then
		return false
	end

	if p_Player.soldier == nil or self.m_Player.soldier == nil then
		return false
	end

	-- check for vehicles
	local s_Type = g_Vehicles:FindOutVehicleType(p_Player)

	-- don't shoot if too far away
	self._DistanceToPlayer = 0

	if s_Type == VehicleTypes.MavBot then
		self._DistanceToPlayer = p_Player.controlledControllable.transform.trans:Distance(self.m_Player.soldier.worldTransform.trans)
	else
		self._DistanceToPlayer = p_Player.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans)
	end

	if not self.m_InVehicle then
		if not p_IgnoreYaw  then
			if self.m_ActiveWeapon.type ~= WeaponTypes.Sniper and self._DistanceToPlayer > Config.MaxShootDistanceNoSniper then
				return false
			end
		end

		if s_Type ~= VehicleTypes.NoVehicle and g_Vehicles:CheckForVehicleAttack(s_Type, self._DistanceToPlayer, self.m_SecondaryGadget, self.m_InVehicle) == VehicleAttackModes.NoAttack then
			return false
		end
	end

	self._ShootPlayerVehicleType = s_Type

	local s_DifferenceYaw = 0
	local s_Pitch = 0
	local s_FovHalf = 0
	local s_PitchHalf = 0

	if not p_IgnoreYaw then
		local s_OldYaw = self.m_Player.input.authoritativeAimingYaw
		local s_DifferenceY = p_Player.soldier.worldTransform.trans.z - self.m_Player.soldier.worldTransform.trans.z
		local s_DifferenceX = p_Player.soldier.worldTransform.trans.x - self.m_Player.soldier.worldTransform.trans.x
		local s_DifferenceZ = p_Player.soldier.worldTransform.trans.y - self.m_Player.soldier.worldTransform.trans.y
		local s_DistanceHoizontal = math.sqrt(s_DifferenceY^2 + s_DifferenceY^2)
		local s_AtanYaw = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanYaw > math.pi / 2) and (s_AtanYaw - math.pi / 2) or (s_AtanYaw + 3 * math.pi / 2)

		s_Pitch = math.abs(math.atan(s_DifferenceZ, s_DistanceHoizontal))
		s_DifferenceYaw = math.abs(s_OldYaw - s_Yaw)

		if s_DifferenceYaw > math.pi then
			s_DifferenceYaw = math.pi * 2 - s_DifferenceYaw
		end

		s_FovHalf = Config.FovForShooting / 360 * math.pi
		s_PitchHalf = Config.FovVerticleForShooting / 360 * math.pi
	end

	if p_IgnoreYaw or (s_DifferenceYaw < s_FovHalf and s_Pitch < s_PitchHalf) then
		if self._Shoot then
			if self._ShootPlayer == nil or (self.m_InVehicle and (self._ShootModeTimer > Config.BotMinTimeShootAtPlayer * 2)) or (not self.m_InVehicle and (self._ShootModeTimer > Config.BotMinTimeShootAtPlayer)) or (self.m_KnifeMode and self._ShootModeTimer > (Config.BotMinTimeShootAtPlayer/2)) then
				self._ShootModeTimer = 0
				self._ShootPlayerName = p_Player.name
				self._ShootPlayer = nil
				self._LastShootPlayer = nil
				self._LastTargetTrans = p_Player.soldier.worldTransform.trans:Clone()
				self._KnifeWayPositions = {}
				self._VehicleReadyToShoot = false
				self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)

				if self.m_KnifeMode then
					table.insert(self._KnifeWayPositions, self._LastTargetTrans)
				end

				return true
			end
		else
			self._ShootModeTimer = Config.BotFireModeDuration
			return false
		end
	end

	return false
end

function Bot:ResetVars()
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._MoveMode = BotMoveModes.Standstill
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = nil
	self._ShootPlayer = nil
	self._ShootPlayerName = ""
	self._LastShootPlayer = nil
	self._InvertPathDirection = false
	self._ShotTimer = 0
	self._UpdateTimer = 0
	self._AimUpdateTimer = 0 --timer sync
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._KnifeWayPositions = {}
	self._ShootWayPoints = {}
	self._ZombieSpeedValue = BotMoveSpeeds.NoMovement
	self._SpawnDelayTimer = 0
	self._SpawnProtectionTimer = 0
	self._Objective = ''
	self._MeleeActive = false
	self._ActionActive = false
	self._ReviveActive = false
	self._EnterVehicleActice = false
	self._GrenadeActive = false
	self._C4Active = false
	self._WeaponToUse = BotWeapons.Primary
end

function Bot:GetFirstShotDelay(p_DistanceToTarget, p_ReducedTiming)
	local s_Delay = (Config.BotFirstShotDelay + math.random()*self._Skill)
	if p_ReducedTiming then
		s_Delay = s_Delay * 0.6
	end
	-- slower reaction on greater distances. 100m = 1 extra second
	s_Delay = s_Delay + (p_DistanceToTarget * 0.01)
	return s_Delay
end

function Bot:SetVarsStatic(p_Player)
	self._SpawnMode = BotSpawnModes.NoRespawn
	self._MoveMode = BotMoveModes.Standstill
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = p_Player
end

function Bot:SetVarsWay(p_Player, p_UseRandomWay, p_PathIndex, p_CurrentWayPoint, p_InverseDirection)
	if p_UseRandomWay then
		self._SpawnMode = BotSpawnModes.RespawnRandomPath
		self._TargetPlayer = nil
		self._Shoot = Globals.AttackWayBots
		self._Respawning = Globals.RespawnWayBots
	else
		self._SpawnMode = BotSpawnModes.RespawnFixedPath
		self._TargetPlayer = p_Player
		self._Shoot = false
		self._Respawning = false
	end

	self._BotSpeed = BotMoveSpeeds.Normal
	self._MoveMode = BotMoveModes.Paths
	self._PathIndex = p_PathIndex
	self._CurrentWayPoint = p_CurrentWayPoint
	self._InvertPathDirection = p_InverseDirection
end

function Bot:IsStaticMovement()
	if self._MoveMode == BotMoveModes.Standstill or self._MoveMode == BotMoveModes.Mirror or self._MoveMode == BotMoveModes.Mimic then
		return true
	else
		return false
	end
end

function Bot:SetMoveMode(p_MoveMode)
	self._MoveMode = p_MoveMode
end

function Bot:SetRespawn(p_Respawn)
	self._Respawning = p_Respawn
end

function Bot:SetShoot(p_Shoot)
	self._Shoot = p_Shoot
end

function Bot:SetSpeed(p_Speed)
	self._BotSpeed = p_Speed
end

function Bot:SetObjective(p_Objective)
	self._Objective = p_Objective or ''
end

function Bot:GetObjective()
	return self._Objective
end

function Bot:GetSpawnMode()
	return self._SpawnMode
end

function Bot:GetWayIndex()
	return self._PathIndex
end

function Bot:GetPointIndex()
	return self._CurrentWayPoint
end

function Bot:GetTargetPlayer()
	return self._TargetPlayer
end

function Bot:IsInactive()
	if self.m_Player.alive or self._SpawnMode ~= BotSpawnModes.NoRespawn then
		return false
	else
		return true
	end
end

function Bot:IsStuck()
	if self._ObstaceSequenceTimer ~= 0 then
		return true
	else
		return false
	end
end


function Bot:ResetSpawnVars()
	self._SpawnDelayTimer = 0
	self._ObstaceSequenceTimer = 0
	self._ObstacleRetryCounter = 0
	self._LastWayDistance = 1000
	self._ShootPlayer = nil
	self._LastShootPlayer = nil
	self._ShootPlayerName = ""
	self._ShootModeTimer = 0
	self._MeleeCooldownTimer = 0
	self._ShootTraceTimer = 0
	self._ReloadTimer = 0
	self._BrakeTimer = 0
	self._DeployTimer = MathUtils:GetRandomInt(1, Config.DeployCycle)
	self._AttackModeMoveTimer = 0
	self._AttackMode = BotAttackModes.RandomNotSet
	self._ShootWayPoints = {}

	if self.m_ActiveWeapon.Type == WeaponTypes.Sniper then
		self._Skill = math.random()*Config.BotSniperWorseningSkill
	else
		self._Skill = math.random()*Config.BotWorseningSkill
	end

	self._ShotTimer = 0
	self._UpdateTimer = 0
	self._AimUpdateTimer = 0 --timer sync
	self._StuckTimer = 0
	self._SpawnProtectionTimer = 2.0
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._MeleeActive = false
	self._KnifeWayPositions = {}
	self._ZombieSpeedValue = BotMoveSpeeds.NoMovement
	self._OnSwitch = false
	self._ActionActive = false
	self._ReviveActive = false
	self._EnterVehicleActice = false
	self._GrenadeActive = false
	self._TargetPitch = 0.0
	self._C4Active = false
	self._Objective = '' --reset objective on spawn, as an other spawn-point might have chosen...
	self._WeaponToUse = BotWeapons.Primary

	-- reset all input-vars
	for i = 0, 36 do
		self.m_ActiveInputs[i] = {
			value = 0,
			reset = false
		}
		self.m_Player.input:SetLevel(i, 0)
	end
end

function Bot:ClearPlayer(p_Player)
	if self._ShootPlayer == p_Player then
		self._ShootPlayer = nil
	end

	if self._TargetPlayer == p_Player then
		self._TargetPlayer = nil
	end

	if self._LastShootPlayer == p_Player then
		self._LastShootPlayer = nil
	end

	local s_CurrentShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
	if s_CurrentShootPlayer == p_Player then
		self._ShootPlayerName = ""
	end
end

function Bot:Kill()
	self:ResetVars()

	if self.m_Player.alive then
		self.m_Player.soldier:Kill()
	end
end

function Bot:Destroy()
	self:ResetVars()
	self.m_Player.input = nil
	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:Destroy()
	end
	if self.m_Player.corpse ~= nil then
		self.m_Player.corpse:Destroy()
	end
	PlayerManager:DeletePlayer(self.m_Player)
	self.m_Player = nil
end

-- this is unused
function Bot:SetVarsDefault()
	self._SpawnMode = BotSpawnModes.RespawnRandomPath
	self._MoveMode = BotMoveModes.Paths
	self._BotSpeed = BotMoveSpeeds.Normal
	self._PathIndex = 1
	self._Respawning = Globals.RespawnWayBots
	self._Shoot = Globals.AttackWayBots
end

-- this is unused
function Bot:GetSpawnTransform()
	return self._SpawnTransform
end

-- =============================================
-- Private Functions
-- =============================================

function Bot:_LookAround(p_DeltaTime)
	-- move around a little
	local s_LastYawTimer = self._WayWaitYawTimer
	self._WayWaitYawTimer = self._WayWaitYawTimer + p_DeltaTime
	self.m_ActiveSpeedValue = 0
	self._TargetPoint = nil

	if self._WayWaitYawTimer > 6 then
		self._WayWaitYawTimer = 0
		self._TargetYaw = self._TargetYaw + 1.0 -- 60 ° rotation right

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 4 and s_LastYawTimer < 4 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60 ° rotation left

		if self._TargetYaw < 0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 3 and s_LastYawTimer < 3 then
		self._TargetYaw = self._TargetYaw - 1.0 -- 60 ° rotation left

		if self._TargetYaw < 0 then
			self._TargetYaw = self._TargetYaw + (2 * math.pi)
		end
	elseif self._WayWaitYawTimer >= 1 and s_LastYawTimer < 1 then
		self._TargetYaw = self._TargetYaw + 1.0 -- 60 ° rotation right

		if self._TargetYaw > (math.pi * 2) then
			self._TargetYaw = self._TargetYaw - (2 * math.pi)
		end
	end
end

function Bot:_SetInput(p_Input, p_Value)
	self.m_ActiveInputs[p_Input] = {
		value = p_Value,
		reset = p_Value == 0
	}
end

function Bot:_UpdateInputs()
	for i = 0, 36 do
		if self.m_ActiveInputs[i].reset then
			self.m_Player.input:SetLevel(i, 0)
			self.m_ActiveInputs[i].value = 0
			self.m_ActiveInputs[i].reset = false
		elseif self.m_ActiveInputs[i].value ~= 0 then
			self.m_Player.input:SetLevel(i, self.m_ActiveInputs[i].value)
			self.m_ActiveInputs[i].reset = true
		end
	end
end

function Bot:_UpdateRespawn()
	if not self._Respawning or self._SpawnMode == BotSpawnModes.NoRespawn then
		return
	end

	if self.m_Player.soldier == nil then
		-- wait for respawn-delay gone
		if self._SpawnDelayTimer < (Globals.RespawnDelay + Config.AdditionalBotSpawnDelay) then
			self._SpawnDelayTimer = self._SpawnDelayTimer + StaticConfig.BotUpdateCycle
		else
			self._SpawnDelayTimer = 0 -- prevent triggering again.
			Events:DispatchLocal('Bot:RespawnBot', self.m_Name)
		end
	else
		self._SpawnDelayTimer = 0 -- reset Timer if player is alive
	end
end

function Bot:_UpdateAiming()
	if not self.m_Player.alive or self._ShootPlayer == nil then
		return
	end

	if not self._ReviveActive then
		if not self._Shoot or self._ShootPlayer.soldier == nil or self.m_ActiveWeapon == nil then
			return
		end

		--interpolate player movement
		local s_TargetMovement = Vec3.zero
		local s_PitchCorrection = 0.0
		local s_FullPositionTarget = nil
		local s_FullPositionBot = nil

		if self.m_InVehicle and self._VehicleMovableId ~= nil then
			s_FullPositionBot = self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().trans
		else
			s_FullPositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false, false)
		end

		if self._ShootPlayerVehicleType == VehicleTypes.MavBot then
			s_FullPositionTarget = self._ShootPlayer.controlledControllable.transform.trans:Clone()
		else
			local s_AimForHead = false
			if self.m_ActiveWeapon.Type == WeaponTypes.Sniper then
				s_AimForHead = Config.AimForHeadSniper
			elseif self.m_ActiveWeapon.Type == WeaponTypes.LMG then
				s_AimForHead = Config.AimForHeadSupport
			else
				s_AimForHead = Config.AimForHead
			end

			s_FullPositionTarget = self._ShootPlayer.soldier.worldTransform.trans:Clone()
			if self.m_InVehicle and self.m_Player.controlledEntryId == 0 and self._ShootPlayerVehicleType == VehicleTypes.NoVehicle and s_FullPositionTarget.y < s_FullPositionBot.y then
				-- do nothing --> aim for the feet of the target
			else
				s_FullPositionTarget = s_FullPositionTarget + m_Utilities:getCameraPos(self._ShootPlayer, true, s_AimForHead)
			end
		end


		local s_GrenadePitch = 0.0
		--calculate how long the distance is --> time to travel
		self._DistanceToPlayer = s_FullPositionTarget:Distance(s_FullPositionBot)

		if not self.m_KnifeMode then
			local s_FactorForMovement = 0.0
			local s_Drop = 0.0
			local s_Speed = 0.0

			if self.m_InVehicle then
				s_Speed, s_Drop = g_Vehicles:GetSpeedAndDrop(self.m_ActiveVehicle, self.m_Player.controlledEntryId)
			else
				s_Drop = self.m_ActiveWeapon.bulletDrop
				s_Speed = self.m_ActiveWeapon.bulletSpeed
			end

			if self.m_ActiveWeapon.type == WeaponTypes.Grenade then
				if self._DistanceToPlayer < 5 then
					self._DistanceToPlayer = 5 -- don't throw them too close..
				end

				local s_Angle = math.asin((self._DistanceToPlayer * s_Drop)/(s_Speed*s_Speed))

				if s_Angle ~= s_Angle then --NAN check
					s_GrenadePitch = (math.pi / 4)
				else
					s_GrenadePitch = (math.pi / 2) - (s_Angle / 2)
				end
			else
				local s_TimeToTravel = (self._DistanceToPlayer / s_Speed)
				s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop

				-- if self.m_InVehicle then
				-- 	s_TimeToTravel = s_TimeToTravel -- + 0.5 -- TODO: FIXME find right delay and find out why this is needed!!
				-- end

				s_FactorForMovement = (s_TimeToTravel) / self._UpdateTimer
			end

			if self._LastShootPlayer == self._ShootPlayer then
				s_TargetMovement = (s_FullPositionTarget - self._LastTargetTrans) * s_FactorForMovement --movement in one dt
			end

			self._LastShootPlayer = self._ShootPlayer
			self._LastTargetTrans = s_FullPositionTarget
		end

		--calculate yaw and pitch
		local s_DifferenceZ = s_FullPositionTarget.z + s_TargetMovement.z - s_FullPositionBot.z
		local s_DifferenceX = s_FullPositionTarget.x + s_TargetMovement.x - s_FullPositionBot.x
		local s_DifferenceY = s_FullPositionTarget.y + s_TargetMovement.y + s_PitchCorrection - s_FullPositionBot.y
		local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local s_Pitch = 0

		if self.m_ActiveWeapon.type == WeaponTypes.Grenade then
			s_Pitch = s_GrenadePitch
		else
			local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
			s_Pitch = math.atan(s_DifferenceY, s_Distance)
		end

		-- worsen yaw and pitch depending on bot-skill
		if not self.m_InVehicle then
			local s_WorseningValue = (math.random()*self._Skill/self._DistanceToPlayer) -- value scaled in offset in 1m
			s_Yaw = s_Yaw + s_WorseningValue
			s_Pitch = s_Pitch + s_WorseningValue
		end

		self._TargetPitch = s_Pitch
		self._TargetYaw = s_Yaw

	else -- revive active
		if self._ShootPlayer.corpse == nil then
			return
		end

		local s_PositionTarget = self._ShootPlayer.corpse.worldTransform.trans:Clone()
		local s_PositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false, false)

		local s_DifferenceZ = s_PositionTarget.z - s_PositionBot.z
		local s_DifferenceX = s_PositionTarget.x - s_PositionBot.x
		local s_DifferenceY = s_PositionTarget.y - s_PositionBot.y

		local s_AtanDzDx = math.atan(s_DifferenceZ, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
		local s_Pitch = math.atan(s_DifferenceY, s_Distance)

		self._TargetPitch = s_Pitch
		self._TargetYaw = s_Yaw
	end
end

function Bot:_UpdateYaw(p_DeltaTime)
	if self.m_InVehicle and self.m_Player.controlledControllable == nil then
		self.m_InVehicle = false
	end

	local s_AttackAiming = true

	if self._MeleeActive then
		return
	end

	if self._TargetPoint ~= nil and self._ShootPlayer == nil and self.m_Player.soldier ~= nil then
		s_AttackAiming = false
		local s_Distance = self.m_Player.soldier.worldTransform.trans:Distance(self._TargetPoint.Position)

		if s_Distance < 0.2 or (self.m_InVehicle and s_Distance < 3.0) then
			self._TargetPoint = self._NextTargetPoint
		end

		local s_DifferenceY = self._TargetPoint.Position.z - self.m_Player.soldier.worldTransform.trans.z
		local s_DifferenceX = self._TargetPoint.Position.x - self.m_Player.soldier.worldTransform.trans.x
		local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
		self._TargetYaw = s_Yaw
	end

	if self.m_KnifeMode then
		if self._ShootPlayer ~= nil and self.m_Player.soldier ~= nil then
			if #self._KnifeWayPositions > 0 then
				local s_DifferenceY = self._KnifeWayPositions[1].z - self.m_Player.soldier.worldTransform.trans.z
				local s_DifferenceX = self._KnifeWayPositions[1].x - self.m_Player.soldier.worldTransform.trans.x
				local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
				local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
				self._TargetYaw = s_Yaw

				if self.m_Player.soldier.worldTransform.trans:Distance(self._KnifeWayPositions[1]) < 1.5 then
					table.remove(self._KnifeWayPositions, 1)
				end
			end
		end
	end

	local s_DeltaYaw = 0
	local s_DeltaPitch = 0
	local s_CorrectGunYaw = false

	if self.m_InVehicle then
		local s_Pos = nil

		if not s_AttackAiming then
			s_Pos = self.m_Player.controlledControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			s_DeltaYaw = s_Yaw - self._TargetYaw

			if self._VehicleMovableId ~= nil then
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, 0)
				local s_DiffPos = s_Pos - self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().forward
				-- prepare for moving gun back
				self._LastVehicleYaw = s_Yaw

				if math.abs(s_DiffPos.x) > 0.08 or math.abs(s_DiffPos.z) > 0.08 then
					s_CorrectGunYaw = true
				end
			end
		else
			if self._VehicleMovableId ~= nil then
				s_Pos = self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().forward
				local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
				local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
				local s_Pitch = math.atan(s_Pos.y, 1.0)
				s_DeltaPitch = s_Pitch - self._TargetPitch
				s_DeltaYaw = s_Yaw - self._TargetYaw

				--detect direction for moving gun back
				local s_GunDeltaYaw = s_Yaw - self._LastVehicleYaw

				if s_GunDeltaYaw > math.pi then
					s_GunDeltaYaw = s_GunDeltaYaw - 2*math.pi
				elseif s_GunDeltaYaw < -math.pi then
					s_GunDeltaYaw = s_GunDeltaYaw + 2*math.pi
				end

				if s_GunDeltaYaw > 0 then
					self._VehicleDirBackPositive = false
				else
					self._VehicleDirBackPositive = true
				end
			end
		end
	else
		s_DeltaYaw = self.m_Player.input.authoritativeAimingYaw - self._TargetYaw
	end

	if s_DeltaYaw > math.pi then
		s_DeltaYaw = s_DeltaYaw - 2*math.pi
	elseif s_DeltaYaw < -math.pi then
		s_DeltaYaw = s_DeltaYaw + 2*math.pi
	end

	local s_AbsDeltaYaw = math.abs(s_DeltaYaw)
	local s_Increment = Globals.YawPerFrame

	if self.m_InVehicle and s_AttackAiming then
		self._Esum_pitch = self._Esum_pitch + s_DeltaPitch
		local s_Output = 5 * s_DeltaPitch + 0.1 * self._Esum_pitch

		if self._Esum_pitch > 2 then
			self._Esum_pitch = 2
		elseif self._Esum_pitch <-2 then
			self._Esum_pitch = -2
		end

		self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Output)
	end

	if self.m_InVehicle then
		self.m_Player.input.authoritativeAimingYaw = self._TargetYaw --alsways set yaw to let the FOV work

		if s_AbsDeltaYaw < 0.1 then
			self._FullVehicleSteering = false
			if s_AttackAiming then
				self._VehicleReadyToShoot = true
			end
		else
			self._FullVehicleSteering = true
			self._VehicleReadyToShoot = false
		end

		if not s_AttackAiming then
			self._Esum_yaw = 0.0
			self._Esum_pitch = 0.0
			self._Esum_drive = self._Esum_drive + s_DeltaYaw
			local s_Output = 5 * s_DeltaYaw + 0.05 * self._Esum_drive
	
			if self._Esum_drive > 5 then
				self._Esum_drive = 5
			elseif self._Esum_drive <-5 then
				self._Esum_drive = -5
			end


			if self.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, s_Output)
			else
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_Output)
			end

			if s_CorrectGunYaw then
				if self._VehicleDirBackPositive then
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 1)
				else
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -1)
				end
			else
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 0)
			end
		else
			self._Esum_drive = 0.0
			self._Esum_yaw = self._Esum_yaw + s_DeltaYaw
			local s_Output = 4 * s_DeltaYaw + 0.3 * self._Esum_yaw
	
			if self._Esum_yaw > 2 then
				self._Esum_yaw = 2
			elseif self._Esum_yaw <-2 then
				self._Esum_yaw = -2
			end

			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0.0)
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -s_Output)
		end

		return
	else
		if s_AbsDeltaYaw < s_Increment then
			self.m_Player.input.authoritativeAimingYaw = self._TargetYaw
			self.m_Player.input.authoritativeAimingPitch = self._TargetPitch
			return
		end
	end

	if s_DeltaYaw > 0 then
		s_Increment = -s_Increment
	end

	local s_TempYaw = self.m_Player.input.authoritativeAimingYaw + s_Increment

	if s_TempYaw >= (math.pi * 2) then
		s_TempYaw = s_TempYaw - (math.pi * 2)
	elseif s_TempYaw < 0.0 then
		s_TempYaw = s_TempYaw + (math.pi * 2)
	end

	self.m_Player.input.authoritativeAimingYaw = s_TempYaw
	self.m_Player.input.authoritativeAimingPitch = self._TargetPitch

end

function Bot:_UpdateShooting()
	if self.m_Player.alive and self._Shoot then
		--select weapon-slot
		if not self._MeleeActive then
			if self.m_Player.soldier.weaponsComponent ~= nil then
				if self.m_KnifeMode then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
						self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
						self.m_ActiveWeapon = self.m_Knife
						self._ShotTimer = 0
					end
				elseif self._ReviveActive or (self._WeaponToUse == BotWeapons.Gadget2 and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Gadget2 then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_5 then
						self:_SetInput(EntryInputActionEnum.EIASelectWeapon5, 1)
						self.m_ActiveWeapon = self.m_SecondaryGadget
						self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)
					end
				elseif (self._WeaponToUse == BotWeapons.Gadget1 and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Gadget1 then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_2 and self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_4 then
						self:_SetInput(EntryInputActionEnum.EIASelectWeapon4, 1)
						self:_SetInput(EntryInputActionEnum.EIASelectWeapon3, 1)
						self.m_ActiveWeapon = self.m_PrimaryGadget
						self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)
					end
				elseif self._GrenadeActive or (self._WeaponToUse == BotWeapons.Grenade and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Grenade then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_6 then
						self:_SetInput(EntryInputActionEnum.EIASelectWeapon6, 1)
						self.m_ActiveWeapon = self.m_Grenade
						self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer)
					end
				elseif (self._WeaponToUse == BotWeapons.Pistol and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Pistol then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_1 then
						self.m_Player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 1)
						self:_SetInput(EntryInputActionEnum.EIASelectWeapon2, 1)
						self.m_ActiveWeapon = self.m_Pistol
						self._ShotTimer = - self:GetFirstShotDelay(self._DistanceToPlayer, true)
					end
				elseif (self._WeaponToUse == BotWeapons.Primary and Config.BotWeapon == BotWeapons.Auto) or Config.BotWeapon == BotWeapons.Primary then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
						self:_SetInput(EntryInputActionEnum.EIASelectWeapon1, 1)
						self.m_ActiveWeapon = self.m_Primary
						self._ShotTimer = 0
					end
				end
			end
		end

		if self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil and not self._EnterVehicleActice then
			if self._ShootModeTimer < Config.BotFireModeDuration or (Config.ZombieMode and self._ShootModeTimer < (Config.BotFireModeDuration * 4)) then
				if not self._C4Active then
					self:_SetInput(EntryInputActionEnum.EIAZoom, 1)
				end

				if not self._GrenadeActive then
					self._ShootModeTimer = self._ShootModeTimer + StaticConfig.BotUpdateCycle
				end

				if self._C4Active then
					self.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : C4 / revive
				else
					self.m_ActiveMoveMode = BotMoveModes.Shooting -- movement-mode : attack
				end

				self._ReloadTimer = 0 -- reset reloading

				--check for melee attack
				if not self.m_InVehicle and Config.MeleeAttackIfClose and not self._MeleeActive and self._MeleeCooldownTimer <= 0 and self._ShootPlayer.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 2 then
					self._MeleeActive = true
					self.m_ActiveWeapon = self.m_Knife

					self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
					self:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
					self:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
					self._MeleeCooldownTimer = Config.MeleeAttackCoolDown

					if not USE_REAL_DAMAGE then
						Events:DispatchLocal("Server:DamagePlayer", self._ShootPlayer.name, self.m_Player.name, true)
					end
				else
					if self._MeleeCooldownTimer < 0 then
						self._MeleeCooldownTimer = 0
					elseif self._MeleeCooldownTimer > 0 then
						self._MeleeCooldownTimer = self._MeleeCooldownTimer - StaticConfig.BotUpdateCycle
						if self._MeleeCooldownTimer < (Config.MeleeAttackCoolDown - 0.8) then
							self._MeleeActive = false
						end
					end
				end

				if self._GrenadeActive then -- throw grenade
					if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 0 then
						self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 1
						self._GrenadeActive = false
						self._ShootModeTimer = Config.BotFireModeDuration
					end
				end

				if self._ShootPlayerVehicleType ~= VehicleTypes.NoVehicle then
					local s_AttackMode = g_Vehicles:CheckForVehicleAttack(self._ShootPlayerVehicleType, self._DistanceToPlayer, self.m_SecondaryGadget, self.m_InVehicle)

					if s_AttackMode ~= VehicleAttackModes.NoAttack then
						if s_AttackMode == VehicleAttackModes.AttackWithNade then -- grenade
							self._GrenadeActive = true
						elseif s_AttackMode == VehicleAttackModes.AttackWithRocket then -- rocket
							self._WeaponToUse = BotWeapons.Gadget2

							if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 2 then
								self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 3
							end
						elseif s_AttackMode == VehicleAttackModes.AttackWithC4 then -- C4
							self._WeaponToUse = BotWeapons.Gadget2
							self._C4Active = true
						elseif s_AttackMode == VehicleAttackModes.AttackWithRifle then
							-- TODO: double code is not nice
							if not self._GrenadeActive and self.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
								if self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 then
									self._WeaponToUse = BotWeapons.Pistol
								else
									self._WeaponToUse = BotWeapons.Primary
								end
							end
						end
					else
						self._ShootModeTimer = Config.BotFireModeDuration -- end attack
					end
				else
					if self.m_KnifeMode or self._MeleeActive then
						self._WeaponToUse = BotWeapons.Knife
					else
						if not self._GrenadeActive and self.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
							if self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 and self._DistanceToPlayer <= Config.MaxShootDistancePistol then
								self._WeaponToUse = BotWeapons.Pistol
							else
								self._WeaponToUse = BotWeapons.Primary
							end
						end
						-- use grenade from time to time
						if Config.BotsThrowGrenades and not self.m_InVehicle then
							local s_TargetTimeValue = Config.BotFireModeDuration - 0.5

							if ((self._ShootModeTimer >= s_TargetTimeValue) and (self._ShootModeTimer < (s_TargetTimeValue + StaticConfig.BotUpdateCycle)) and not self._GrenadeActive) or Config.BotWeapon == BotWeapons.Grenade then
								-- should be triggered only once per fireMode
								if MathUtils:GetRandomInt(1,100) <= 40 then
									if self.m_Grenade ~= nil and self._DistanceToPlayer < 35 then
										self._GrenadeActive = true
									end
								end
							end
						end
					end
				end

				--trace way back
				if (self.m_ActiveWeapon ~= nil and self.m_ActiveWeapon.type ~= WeaponTypes.Sniper and not self.m_InVehicle) or self.m_KnifeMode then
					if self._ShootTraceTimer > StaticConfig.TraceDeltaShooting then
						--create a Trace to find way back
						self._ShootTraceTimer = 0
						local s_Point = {
							Position = self.m_Player.soldier.worldTransform.trans:Clone(),
							SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
							ExtraMode = 0,
							OptValue = 0,
						}

						table.insert(self._ShootWayPoints, s_Point)

						if self.m_KnifeMode then
							local s_Trans = self._ShootPlayer.soldier.worldTransform.trans:Clone()
							table.insert(self._KnifeWayPositions, s_Trans)
						end
					end

					self._ShootTraceTimer = self._ShootTraceTimer + StaticConfig.BotUpdateCycle
				end

				--shooting sequence
				if self.m_ActiveWeapon ~= nil then
					if self.m_KnifeMode then
						-- nothing to do
					elseif self._C4Active then
						if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo > 0 then
							if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
								self._ShotTimer = 0
							end

							if self._DistanceToPlayer < 5 then
								if self._ShotTimer >= self.m_ActiveWeapon.pauseCycle then
									self:_SetInput(EntryInputActionEnum.EIAZoom, 1)
								end
							end
						else
							if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
								--TODO: run away from object now
								if self._ShotTimer >= ((self.m_ActiveWeapon.fireCycle * 2) + self.m_ActiveWeapon.pauseCycle) then
									self:_SetInput(EntryInputActionEnum.EIAFire, 1)
									self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 4
									self._C4Active = false
								end
							end
						end
					else
						if self.m_InVehicle then
							if self.m_ActiveVehicle.Type ~= nil and self.m_ActiveVehicle.Type == VehicleTypes.AntiAir then
								if self._ShotTimer >= 5.0 then
									self._ShotTimer = 0
								end
								if self._ShotTimer >= 1.0 and self._VehicleReadyToShoot then
									self:_SetInput(EntryInputActionEnum.EIAFire, 1)
								end
							else
								if self._ShotTimer >= 0.6 then
									self._ShotTimer = 0
								end
								if self._ShotTimer >= 0.3 and self._VehicleReadyToShoot then
									self:_SetInput(EntryInputActionEnum.EIAFire, 1)
								end
							end
						else
							if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
								self._ShotTimer = 0
							end

							if self._ShotTimer >= 0 then
								if self.m_ActiveWeapon.delayed == false then
									if self._ShotTimer <= self.m_ActiveWeapon.fireCycle and not self._MeleeActive then
										self:_SetInput(EntryInputActionEnum.EIAFire, 1)
									end
								else --start with pause Cycle
									if self._ShotTimer >= self.m_ActiveWeapon.pauseCycle and not self._MeleeActive then
										self:_SetInput(EntryInputActionEnum.EIAFire, 1)
									end
								end
							end
						end
					end

					self._ShotTimer = self._ShotTimer + StaticConfig.BotUpdateCycle
				end
			else
				self._TargetPitch = 0.0
				self._WeaponToUse = BotWeapons.Primary
				self._ShootPlayerName = ""
				self._ShootPlayer = nil
				self._GrenadeActive = false
				self._C4Active = false
				self._LastShootPlayer = nil
			end
		elseif self._ReviveActive and self._ShootPlayer ~= nil then
			if self._ShootPlayer.corpse ~= nil then -- revive
				self._ShootModeTimer = self._ShootModeTimer + StaticConfig.BotUpdateCycle
				self.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : revive
				self._ReloadTimer = 0 -- reset reloading

				--check for revive if close
				if self._ShootPlayer.corpse.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 3 then
					self:_SetInput(EntryInputActionEnum.EIAFire, 1)
				end

				--trace way back
				if self._ShootTraceTimer > StaticConfig.TraceDeltaShooting then
					--create a Trace to find way back
					self._ShootTraceTimer = 0
					local s_Point = {
						Position = self.m_Player.soldier.worldTransform.trans:Clone(),
						SpeedMode = BotMoveSpeeds.Sprint, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
						ExtraMode = 0,
						OptValue = 0,
					}

					table.insert(self._ShootWayPoints, s_Point)
					if self.m_KnifeMode then
						local s_Trans = self._ShootPlayer.soldier.worldTransform.trans:Clone()
						table.insert(self._KnifeWayPositions, s_Trans)
					end
				end

				self._ShootTraceTimer = self._ShootTraceTimer + StaticConfig.BotUpdateCycle
			else
				self._WeaponToUse = BotWeapons.Primary
				self._TargetPitch = 0.0
				self._ShootPlayer = nil
				self._ReviveActive = false
			end
		elseif self._EnterVehicleActice then
			if self._ShootPlayer.soldier ~= nil then -- try to enter
				self._ShootModeTimer = self._ShootModeTimer + StaticConfig.BotUpdateCycle
				self.m_ActiveMoveMode = BotMoveModes.ReviveC4 -- movement-mode : revive

				--check for enter of vehicle if close
				if self._ShootPlayer.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 5 then
					self:_EnterVehicle()
					self._TargetPitch = 0.0
					self._ShootPlayer = nil
					self._EnterVehicleActice = false
				end
			else
				self._TargetPitch = 0.0
				self._ShootPlayer = nil
				self._EnterVehicleActice = false
			end
		else
			self._WeaponToUse = BotWeapons.Primary
			self._GrenadeActive = false
			self._C4Active = false
			self._ShootPlayer = nil
			self._LastShootPlayer = nil
			self._ReviveActive = false
			self._ShootModeTimer = 0
			self._AttackMode = 0
			if not self._ActionActive then
				self._TargetPitch = 0.0
			end

			self._ReloadTimer = self._ReloadTimer + StaticConfig.BotUpdateCycle

			if self._ReloadTimer > 1.5 and self._ReloadTimer < 2.5 and self.m_Player.soldier.weaponsComponent.currentWeapon.primaryAmmo <= self.m_ActiveWeapon.reload then
				self:_SetInput(EntryInputActionEnum.EIAReload, 1)
			end

			-- deploy from time to time
			if Config.BotsDeploy then
				if self.m_Kit == BotKits.Support or self.m_Kit == BotKits.Assault then
					if self.m_PrimaryGadget.type == WeaponTypes.Ammobag or self.m_PrimaryGadget.type == WeaponTypes.Medkit then
						self._DeployTimer = self._DeployTimer + StaticConfig.BotUpdateCycle

						if self._DeployTimer > Config.DeployCycle then
							self._DeployTimer = 0
						end

						if self._DeployTimer < 0.7 then
							self._WeaponToUse = BotWeapons.Gadget1
						end
					end
				end
			end
		end
	end
end

function Bot:_EnterVehicle()
	local s_Iterator = EntityManager:GetIterator("ServerVehicleEntity")
	local s_Entity = s_Iterator:Next()

	while s_Entity ~= nil do
		s_Entity = ControllableEntity(s_Entity)
		local s_Position = s_Entity.transform.trans

		if s_Position:Distance(self.m_Player.soldier.worldTransform.trans) < 5 then
			for i = 0, s_Entity.entryCount - 1 do
				if s_Entity:GetPlayerInEntry(i) == nil then
					self.m_Player:EnterVehicle(s_Entity, i)
					-- self._VehicleEntity = s_Entity.physicsEntityBase

					-- get ID
					self.m_ActiveVehicle = g_Vehicles:GetVehicle(self.m_Player, i)
					self._VehicleMovableId = g_Vehicles:GetPartIdForSeat(self.m_ActiveVehicle, i)
					m_Logger:Write(self.m_ActiveVehicle)

					return 0, s_Position -- everything fine
				end
			end
			return -2 --no place left
		end

		s_Entity = s_Iterator:Next()
	end
	return -3 -- no vehicle found
end

function Bot:_GetWayIndex(p_CurrentWayPoint)
	local s_ActivePointIndex = 1

	if p_CurrentWayPoint == nil then
		p_CurrentWayPoint = s_ActivePointIndex
	else
		s_ActivePointIndex = p_CurrentWayPoint

		-- direction handling
		local s_CountOfPoints = #m_NodeCollection:Get(nil, self._PathIndex)
		local s_FirstPoint = m_NodeCollection:GetFirst(self._PathIndex)

		if s_ActivePointIndex > s_CountOfPoints then
			if s_FirstPoint.OptValue == 0xFF then --inversion needed
				s_ActivePointIndex = s_CountOfPoints
				self._InvertPathDirection = true
			else
				s_ActivePointIndex = 1
			end
		elseif s_ActivePointIndex < 1 then
			if s_FirstPoint.OptValue == 0xFF then --inversion needed
				s_ActivePointIndex = 1
				self._InvertPathDirection = false
			else
				s_ActivePointIndex = s_CountOfPoints
			end
		end
	end

	return s_ActivePointIndex
end

function Bot:_UpdateMovement()
	-- movement-mode of bots
	local s_AdditionalMovementPossible = true

	if self.m_Player.alive then
		-- mimicking
		if self.m_ActiveMoveMode == BotMoveModes.Mimic and self._TargetPlayer ~= nil then
			s_AdditionalMovementPossible = false

			for i = 0, 36 do
				self:_SetInput(i, self._TargetPlayer.input:GetLevel(i))
			end

			self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw
			self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch

		-- mirroring
		elseif self.m_ActiveMoveMode == BotMoveModes.Mirror and self._TargetPlayer ~= nil then
			s_AdditionalMovementPossible = false

			for i = 0, 36 do
				self:_SetInput(i, self._TargetPlayer.input:GetLevel(i))
			end

			self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw + ((self._TargetPlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
			self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch

		-- move along points
		elseif self.m_ActiveMoveMode == BotMoveModes.Paths then
			self._AttackModeMoveTimer = 0

			if m_NodeCollection:Get(1, self._PathIndex) ~= nil then -- check for valid point
				-- get next point
				local s_ActivePointIndex = self:_GetWayIndex(self._CurrentWayPoint)

				local s_Point = nil
				local s_NextPoint = nil
				local s_PointIncrement = 1
				local s_NoStuckReset = false
				local s_UseShootWayPoint = false

				if #self._ShootWayPoints > 0 then --we need to go back to path first
					s_Point = self._ShootWayPoints[#self._ShootWayPoints]
					s_NextPoint = self._ShootWayPoints[#self._ShootWayPoints - 1]

					if s_NextPoint == nil then
						s_NextPoint = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)

						--[[if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, s_ActivePointIndex, self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0), "Blue")
						end--]]
					end

					s_UseShootWayPoint = true
				else
					s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)

					if not self._InvertPathDirection then
						s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 1), self._PathIndex)

						--[[if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, self:_GetWayIndex(self._CurrentWayPoint + 1), self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0), "Green")
						end--]]
					else
						s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint - 1), self._PathIndex)

						--[[if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, self:_GetWayIndex(self._CurrentWayPoint - 1), self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0), "Green")
						end--]]
					end
				end

				-- execute Action if needed
				if self._ActionActive then
					if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
						if s_Point.Data.Action.type == "vehicle" then

							local s_RetCode, s_Position = self:_EnterVehicle()
							if s_RetCode == 0 then
								self._ActionActive = false
								local s_Node = g_GameDirector:FindClosestPath(s_Position, true)
			
								if s_Node ~= nil then
									-- switch to vehicle
									s_Point = s_Node
									self._InvertPathDirection = false
									self._PathIndex = s_Node.PathIndex
									self._CurrentWayPoint = s_Node.PointIndex
									s_NextPoint = m_NodeCollection:Get(self:_GetWayIndex(self._CurrentWayPoint + 1), self._PathIndex)
									self._LastWayDistance = 1000
								end
							elseif s_RetCode == -1 then
								return
							end

							self._ActionActive = false
						elseif self._ActionTimer <= s_Point.Data.Action.time then
							for _, l_Input in pairs(s_Point.Data.Action.inputs) do
								self:_SetInput(l_Input, 1)
							end
						end
					else
						self._ActionActive = false
					end

					self._ActionTimer = self._ActionTimer - StaticConfig.BotUpdateCycle

					if self._ActionTimer <= 0 then
						self._ActionActive = false
					end

					if self._ActionActive then
						return --DONT EXECUTE ANYTHING ELSE
					else
						s_Point = s_NextPoint
					end
				end

				if s_Point.SpeedMode ~= BotMoveSpeeds.NoMovement then -- movement
					self._WayWaitTimer = 0
					self._WayWaitYawTimer = 0
					self.m_ActiveSpeedValue = s_Point.SpeedMode --speed

					if Config.ZombieMode then
						if self._ZombieSpeedValue == BotMoveSpeeds.NoMovement then
							if MathUtils:GetRandomInt(0,1) == 1 then
								self._ZombieSpeedValue = BotMoveSpeeds.SlowCrouch
							else
								self._ZombieSpeedValue = BotMoveSpeeds.VerySlowProne
							end
						end

						self.m_ActiveSpeedValue = self._ZombieSpeedValue
					end

					if Config.OverWriteBotSpeedMode ~= BotMoveSpeeds.NoMovement and not self.m_InVehicle then
						self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
					end

					local s_DifferenceY = s_Point.Position.z - self.m_Player.soldier.worldTransform.trans.z
					local s_DifferenceX = s_Point.Position.x - self.m_Player.soldier.worldTransform.trans.x
					local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
					local s_HeightDistance = math.abs(s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y)

					--detect obstacle and move over or around TODO: Move before normal jump
					local s_CurrentWayPointDistance = self.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)

					if s_CurrentWayPointDistance > self._LastWayDistance + 0.02 and self._ObstaceSequenceTimer == 0 then
						--skip one pooint
						s_DistanceFromTarget = 0
						s_HeightDistance = 0
					end

					self._TargetPoint = s_Point
					self._NextTargetPoint = s_NextPoint

					if math.abs(s_CurrentWayPointDistance - self._LastWayDistance) < 0.02 or self._ObstaceSequenceTimer ~= 0 then
						-- try to get around obstacle
						self.m_ActiveSpeedValue = 4 --always try to stand

						if self.m_InVehicle then
							if self._ObstacleRetryCounter == 0 then
								self.m_ActiveSpeedValue = -1
							else
								self.m_ActiveSpeedValue = 3
							end
						end

						if self._ObstaceSequenceTimer == 0 then --step 0

						elseif self._ObstaceSequenceTimer > 2.4 then --step 4 - repeat afterwards
							self._ObstaceSequenceTimer = 0
							self._MeleeActive = false
							self._ObstacleRetryCounter = self._ObstacleRetryCounter + 1
						elseif self._ObstaceSequenceTimer > 1.0 then --step 3
							if not self.m_InVehicle then
								if self._ObstacleRetryCounter == 0 then
									self._MeleeActive = true
									self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
									self:_SetInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
									self:_SetInput(EntryInputActionEnum.EIAMeleeAttack, 1)
								else
									self:_SetInput(EntryInputActionEnum.EIAFire, 1)
								end
							end
						elseif self._ObstaceSequenceTimer > 0.4 then --step 2
							self._TargetPitch = 0.0

							if (MathUtils:GetRandomInt(0,1) == 1) then
								self:_SetInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
							else
								self:_SetInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
							end
						elseif self._ObstaceSequenceTimer > 0.0 then --step 1
							self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
							self:_SetInput(EntryInputActionEnum.EIAJump, 1)
						end

						self._ObstaceSequenceTimer = self._ObstaceSequenceTimer + StaticConfig.BotUpdateCycle
						self._StuckTimer = self._StuckTimer + StaticConfig.BotUpdateCycle

						if self._ObstacleRetryCounter >= 2 then --try next waypoint
							self._ObstacleRetryCounter = 0
							self._MeleeActive = false
							s_DistanceFromTarget = 0
							s_HeightDistance = 0
							s_NoStuckReset = true
							s_PointIncrement = MathUtils:GetRandomInt(-5,5) -- go 5 points further

							if (Globals.IsConquest or Globals.IsRush) and not self.m_InVehicle then
								if g_GameDirector:IsOnObjectivePath(self._PathIndex) then
									self._InvertPathDirection = (MathUtils:GetRandomInt(0,100) < 50)
								end
							end

							-- experimental
							if s_PointIncrement == 0 then -- we can't have this
								s_PointIncrement = -2 --go backwards and try again
							end
						end

						if self._StuckTimer > 15 and not self.m_InVehicle then -- don't kill bots in vehicles
							self.m_Player.soldier:Kill()

							m_Logger:Write(self.m_Player.name.." got stuck. Kill")

							return
						end
					else
						self._MeleeActive = false
					end

					self._LastWayDistance = s_CurrentWayPointDistance

					-- jump detection. Much more simple now, but works fine -)
					if self._ObstaceSequenceTimer == 0 then
						if (s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y) > 0.3 and Config.JumpWhileMoving then
							--detect, if a jump was recorded or not
							local s_TimeForwardBackwardJumpDetection = 1.1 -- 1.5 s ahead and back
							local s_JumpValid = false

							for i = 1, math.floor(s_TimeForwardBackwardJumpDetection / Config.TraceDelta) do
								local s_PointBefore = m_NodeCollection:Get(s_ActivePointIndex - i, self._PathIndex)
								local s_PointAfter = m_NodeCollection:Get(s_ActivePointIndex + i, self._PathIndex)

								if (s_PointBefore ~= nil and s_PointBefore.ExtraMode == 1) or (s_PointAfter ~= nil and s_PointAfter.ExtraMode == 1) then
									s_JumpValid = true
									break
								end
							end

							if s_JumpValid then
								self:_SetInput(EntryInputActionEnum.EIAJump, 1)
								self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
							end
						end
					end

					local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint

					if self.m_InVehicle then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 5
					elseif self.m_ActiveSpeedValue == 4 then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 1.5
					elseif self.m_ActiveSpeedValue == 2 then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.7
					elseif self.m_ActiveSpeedValue == 1 then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.5
					end

					--check for reached target
					if s_DistanceFromTarget <= s_TargetDistanceSpeed and s_HeightDistance <= StaticConfig.TargetHeightDistanceWayPoint then
						if not s_NoStuckReset then
							self._StuckTimer = 0
						end

						if not s_UseShootWayPoint then
							-- CHECK FOR ACTION
							if s_Point.Data.Action ~= nil then
								local s_Action = s_Point.Data.Action

								if g_GameDirector:CheckForExecution(s_Point, self.m_Player.teamId) then
									self._ActionActive = true

									if s_Action.time ~= nil then
										self._ActionTimer = s_Action.time
									else
										self._ActionTimer = 0
									end

									if s_Action.yaw ~= nil then
										self._TargetYaw = s_Action.yaw
									end

									if s_Action.pitch ~= nil then
										self._TargetPitch = s_Action.pitch
									end

									return --DONT DO ANYTHING ELSE ANYMORE
								end
							end

							-- CHECK FOR PATH-SWITCHES
							local s_NewWaypoint = nil
							local s_SwitchPath = false
							s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(self.m_Name, s_Point, self._Objective, self.m_InVehicle, self.m_Player.teamId)

							if not self.m_Player.alive then
								return
							end

							if s_SwitchPath == true and not self._OnSwitch then
								if self._Objective ~= '' then
									-- 'best' direction for objective on switch
									local s_Direction = m_NodeCollection:ObjectiveDirection(s_NewWaypoint, self._Objective, self.m_InVehicle)
									self._InvertPathDirection = (s_Direction == 'Previous')
								else
									-- random path direction on switch
									self._InvertPathDirection = MathUtils:GetRandomInt(1,2) == 1
								end

								self._PathIndex = s_NewWaypoint.PathIndex
								self._CurrentWayPoint = s_NewWaypoint.PointIndex
								self._OnSwitch = true
							else
								self._OnSwitch = false

								if self._InvertPathDirection then
									self._CurrentWayPoint = s_ActivePointIndex - s_PointIncrement
								else
									self._CurrentWayPoint = s_ActivePointIndex + s_PointIncrement
								end
							end
						else
							for i = 1, s_PointIncrement do --one already gets removed on start of wayfinding
								table.remove(self._ShootWayPoints)
							end
						end

						self._ObstaceSequenceTimer = 0
						self._MeleeActive = false
						self._LastWayDistance = 1000
					end
				else -- wait mode
					self._WayWaitTimer = self._WayWaitTimer + StaticConfig.BotUpdateCycle

					self:_LookAround(StaticConfig.BotUpdateCycle)

					if self._WayWaitTimer > s_Point.OptValue then
						self._WayWaitTimer = 0

						if self._InvertPathDirection then
							self._CurrentWayPoint = s_ActivePointIndex - 1
						else
							self._CurrentWayPoint = s_ActivePointIndex + 1
						end
					end
				end
			--else -- no point: do nothing
			end
		-- Shoot MoveMode
		elseif self.m_ActiveMoveMode == BotMoveModes.Shooting then
			if self._AttackMode == BotAttackModes.RandomNotSet then
				if Config.BotAttackMode ~= BotAttackModes.RandomNotSet then
					self._AttackMode = Config.BotAttackMode
				else -- random
					if MathUtils:GetRandomInt(0, 1) == 1 then
						self._AttackMode = BotAttackModes.Stand
					else
						self._AttackMode = BotAttackModes.Crouch
					end
				end
			end

			--crouch moving (only mode with modified gun)
			if (self.m_ActiveWeapon.type == WeaponTypes.Sniper and not self.m_KnifeMode) or self.m_InVehicle then --don't move while shooting in a vehicle
				if self._AttackMode == BotAttackModes.Crouch then
					if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
						self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
					end
				else
					if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
						self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
					end
				end

				self.m_ActiveSpeedValue = BotMoveSpeeds.NoMovement
			else
				local s_TargetTime = 5.0
				local s_TargetCycles = math.floor(s_TargetTime / StaticConfig.TraceDeltaShooting)

				if self.m_KnifeMode then --Knife Only Mode
					s_TargetCycles = 1
					self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint --run towards player
				else
					if self._AttackMode == BotAttackModes.Crouch then
						self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
					else
						self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
					end
				end

				if Config.OverWriteBotAttackMode ~= BotMoveSpeeds.NoMovement then
					self.m_ActiveSpeedValue = Config.OverWriteBotAttackMode
				end

				if #self._ShootWayPoints > s_TargetCycles and Config.JumpWhileShooting then
					local s_DistanceDone = self._ShootWayPoints[#self._ShootWayPoints].Position:Distance(self._ShootWayPoints[#self._ShootWayPoints-s_TargetCycles].Position)
					if s_DistanceDone < 0.5 then --no movement was possible. Try to jump over obstacle
						self.m_ActiveSpeedValue = BotMoveSpeeds.Normal
						self:_SetInput(EntryInputActionEnum.EIAJump, 1)
						self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					end
				end

				-- do some sidwards movement from time to time
				if self._AttackModeMoveTimer > 20 then
					self._AttackModeMoveTimer = 0
				elseif self._AttackModeMoveTimer > 17 then
					self:_SetInput(EntryInputActionEnum.EIAStrafe, -0.5 * Config.SpeedFactorAttack)
				elseif self._AttackModeMoveTimer > 12 and self._AttackModeMoveTimer <= 13 then
					self:_SetInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
				elseif self._AttackModeMoveTimer > 7 and self._AttackModeMoveTimer <= 9 then
					self:_SetInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
				end

				self._AttackModeMoveTimer = self._AttackModeMoveTimer + StaticConfig.BotUpdateCycle
			end

		elseif self.m_ActiveMoveMode == BotMoveModes.ReviveC4 then -- Revive Move Mode / C4 Mode
			self.m_ActiveSpeedValue = BotMoveSpeeds.Sprint --run to player

			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end

			local s_Jump = true

			if self._ShootPlayer ~= nil and self._ShootPlayer.corpse ~= nil then
				if self.m_Player.soldier.worldTransform.trans:Distance(self._ShootPlayer.corpse.worldTransform.trans) < 2 then
					self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
					s_Jump = false
				end
			end

			--TODO: obstacle detection
			if s_Jump == true then
				self._AttackModeMoveTimer = self._AttackModeMoveTimer + StaticConfig.BotUpdateCycle

				if self._AttackModeMoveTimer > 3 then
					self._AttackModeMoveTimer = 0
				elseif self._AttackModeMoveTimer > 2.5 then
					self:_SetInput(EntryInputActionEnum.EIAJump, 1)
					self:_SetInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
				end
			end
		end

		-- additional movement
		if s_AdditionalMovementPossible then
			local s_SpeedVal = 0

			if self.m_InVehicle then
				if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
					self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				end

				if self.m_ActiveMoveMode ~= BotMoveModes.Standstill then
					-- limit speed if full steering active
					if self._FullVehicleSteering and self.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
						self.m_ActiveSpeedValue = BotMoveSpeeds.SlowCrouch
					end

					-- normal values
					if self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
						s_SpeedVal = 0.25
					elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
						s_SpeedVal = 0.5
					elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Normal then
						s_SpeedVal = 0.8
					elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Sprint then
						s_SpeedVal = 1.0
					elseif self.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
						s_SpeedVal = -0.7
					end
				end
			else
				if self.m_ActiveMoveMode ~= BotMoveModes.Standstill then
					if self.m_ActiveSpeedValue == BotMoveSpeeds.VerySlowProne then
						s_SpeedVal = 1.0

						if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
							self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
						end
					elseif self.m_ActiveSpeedValue == BotMoveSpeeds.SlowCrouch then
						s_SpeedVal = 1.0

						if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
							self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
						end
					elseif self.m_ActiveSpeedValue >= BotMoveSpeeds.Normal then
						s_SpeedVal = 1.0

						if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
							self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
						end
					end
				end
			end

			-- do not reduce speed if sprinting
			if s_SpeedVal > 0 and self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil and self.m_ActiveSpeedValue <= BotMoveSpeeds.Normal then
				s_SpeedVal = s_SpeedVal * Config.SpeedFactorAttack
			end

			-- movent speed
			if self.m_Player.alive then
				if self.m_InVehicle then
					if self.m_ActiveSpeedValue == BotMoveSpeeds.Backwards then
						self._BrakeTimer = 0
						self:_SetInput(EntryInputActionEnum.EIABrake, -s_SpeedVal)
					elseif self.m_ActiveSpeedValue ~= BotMoveSpeeds.NoMovement then
						self._BrakeTimer = 0
						self:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal)
						-- if self.m_ActiveSpeedValue >= 4 then
							-- self:_setInput(EntryInputActionEnum.EIASprint, 1)
						-- end
					else
						if self._BrakeTimer < 0.7 then
							self:_SetInput(EntryInputActionEnum.EIABrake, 1)
						end

						self._BrakeTimer = self._BrakeTimer + StaticConfig.BotUpdateCycle
					end
				else
					if self.m_ActiveSpeedValue ~= BotMoveSpeeds.Sprint then
						self:_SetInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal * Config.SpeedFactor)
					else
						self:_SetInput(EntryInputActionEnum.EIAThrottle, 1)
						self:_SetInput(EntryInputActionEnum.EIASprint, s_SpeedVal * Config.SpeedFactor)
					end
				end
			end
		end
	end
end

function Bot:_SetActiveVars()
	if self._ShootPlayerName ~= "" then
		self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
	else
		self._ShootPlayer = nil
		self._LastShootPlayer = nil
	end

	self.m_ActiveMoveMode = self._MoveMode
	self.m_ActiveSpeedValue = self._BotSpeed

	if self.m_Player.controlledControllable ~= nil and not self.m_Player.controlledControllable:Is("ServerSoldierEntity") then
		self.m_InVehicle = true
	else
		self.m_InVehicle = false
	end

	if Config.BotWeapon == BotWeapons.Knife or Config.ZombieMode then
		self.m_KnifeMode = true
	else
		self.m_KnifeMode = false
	end
end

-- this is unused
function Bot:_GetCameraHeight(p_Soldier, p_IsTarget)
	local s_CameraHeight = 0

	if not p_IsTarget then
		s_CameraHeight = 1.6 --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand

		if p_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			s_CameraHeight = 0.3
		elseif p_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			s_CameraHeight = 1.0
		end
	else
		s_CameraHeight = 1.3 --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand - reduce by 0.3

		if p_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			s_CameraHeight = 0.3 -- don't reduce
		elseif p_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			s_CameraHeight = 0.8 -- reduce by 0.2
		end
	end

	return s_CameraHeight
end

return Bot
