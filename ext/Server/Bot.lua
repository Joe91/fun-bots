class('Bot')

require('__shared/Config')
require('__shared/Constants/VehicleNames')

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
	self._SpawnMode = 0
	self._MoveMode = 0
	self.m_Kit = ""
	self.m_Color = ""
	self.m_ActiveWeapon = nil
	self.m_Primary = nil
	self.m_Pistol = nil
	self.m_PrimaryGadget = nil
	self.m_SecondaryGadget = nil
	self.m_Grenade = nil
	self.m_Knife = nil
	self._CheckSwapTeam = false
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

	--shared movement vars
	self.m_ActiveMoveMode = 0
	self.m_ActiveSpeedValue = 0
	self.m_KnifeMode = false
	self.m_InVehicle = false
	self.m_NewInputs = {}
	self.m_ActiveInputs = {}

	--advanced movement
	self._AttackMode = 0
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
	self._ZombieSpeedValue = 0
	self._Objective = ''
	self._OnSwitch = false
	self._ActionActive = false
	self._ReviveActive = false
	self._GrenadeActive = false
	self._C4Active = false

	-- vehicle stuff
	self._VehicleEntity = nil
	self._VehicleMovableId = nil
	self._LastVehicleYaw = 0.0
	self._VehicleDirBackPositive = false
	self._VehicleMovableTransform = nil

	--shooting
	self._Shoot = false
	self._ShootPlayer = nil
	self._ShootPlayerName = ""
	self._WeaponToUse = "Primary"
	self._ShootWayPoints = {}
	self._KnifeWayPositions = {}
	self._LastTargetTrans = Vec3()
	self._LastShootPlayer = nil
	self._Skill = 0.0

	--simple movement
	self._BotSpeed = 0
	self._TargetPlayer = nil
	self._SpawnTransform = LinearTransform()
end

function Bot:onUpdate(p_DeltaTime)
	if self.m_Player.soldier ~= nil then
		self.m_Player.soldier:SingleStepEntry(self.m_Player.controlledEntryId)
	end

	if Globals.IsInputAllowed then
		self._UpdateTimer = self._UpdateTimer + p_DeltaTime

		self:_updateYaw()

		if self._UpdateTimer > StaticConfig.BotUpdateCycle then
			self:_setActiveVars()
			self:_updateRespwawn()
			self:_updateAiming()
			self:_updateShooting()
			self:_updateMovement()

			self:_updateInputs()
			self._UpdateTimer = 0
		end
	end
end

function Bot:_setInput(p_Input, p_Value)
	self.m_ActiveInputs[p_Input] = {
	 	value = p_Value,
		reset = false
	}
end

function Bot:_updateInputs()
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

--public functions
function Bot:revive(p_Player)
	if self.m_Kit == "Assault" and p_Player.corpse ~= nil then
		if Config.BotsRevive then
			self._ReviveActive = true
			self._ShootPlayer = nil
			self._ShootPlayerName = p_Player.name
		end
	end
end

function Bot:shootAt(p_Player, p_IgnoreYaw)
	if self._ActionActive or self._ReviveActive or self._GrenadeActive then
		return false
	end

	-- don't shoot at teammates
	if self.m_Player.teamId == p_Player.teamId then
		return false
	end

	if p_Player.soldier == nil or self.m_Player.soldier == nil then
		return false
	end

	-- don't shoot if too far away
	local s_Distance = p_Player.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans)
	if not p_IgnoreYaw then

		if self.m_ActiveWeapon.type ~= "Sniper" and s_Distance > Config.MaxShootDistanceNoSniper then
			return false
		end
	end

	-- check for vehicles
	local s_Type = self:_findOutVehicleType(p_Player)
	if s_Type ~= 0 and self:_ceckForVehicleAttack(s_Type, s_Distance) == 0 then
		return false
	end

	local s_DifferenceYaw = 0
	local s_FovHalf = 0

	if not p_IgnoreYaw then
		local s_OldYaw = self.m_Player.input.authoritativeAimingYaw
		local s_DifferenceY = p_Player.soldier.worldTransform.trans.z - self.m_Player.soldier.worldTransform.trans.z
		local s_DifferenceX = p_Player.soldier.worldTransform.trans.x - self.m_Player.soldier.worldTransform.trans.x
		local s_Yaw = (math.atan(s_DifferenceY, s_DifferenceX) > math.pi / 2) and (math.atan(s_DifferenceY, s_DifferenceX) - math.pi / 2) or (math.atan(s_DifferenceY, s_DifferenceX) + 3 * math.pi / 2)

		s_DifferenceYaw = math.abs(s_OldYaw - s_Yaw)

		if s_DifferenceYaw > math.pi then
			s_DifferenceYaw = math.pi * 2 - s_DifferenceYaw
		end

		s_FovHalf = Config.FovForShooting / 360 * math.pi
	end

	if s_DifferenceYaw < s_FovHalf or p_IgnoreYaw then
		if self._Shoot then
			if self._ShootPlayer == nil or self._ShootModeTimer > Config.BotMinTimeShootAtPlayer or (self.m_KnifeMode and self._ShootModeTimer > (Config.BotMinTimeShootAtPlayer/2)) then
				self._ShootModeTimer = 0
				self._ShootPlayerName = p_Player.name
				self._ShootPlayer = nil
				self._LastShootPlayer = nil
				self._LastTargetTrans = p_Player.soldier.worldTransform.trans:Clone()
				self._KnifeWayPositions = {}
				self._ShotTimer = - (Config.BotFirstShotDelay + math.random()*self._Skill)

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

function Bot:setVarsDefault()
	self._SpawnMode = 5
	self._MoveMode = 5
	self._BotSpeed = 3
	self._PathIndex = 1
	self._Respawning = Globals.RespawnWayBots
	self._Shoot = Globals.AttackWayBots
end

function Bot:resetVars()
	self._SpawnMode = 0
	self._MoveMode = 0
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
	self._ZombieSpeedValue = 0
	self._SpawnDelayTimer = 0
	self._Objective = ''
	self._MeleeActive = false
	self._ActionActive = false
	self._ReviveActive = false
	self._GrenadeActive = false
	self._C4Active = false
	self._WeaponToUse = "Primary"
end

function Bot:setVarsStatic(p_Player)
	self._SpawnMode = 0
	self._MoveMode = 0
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = p_Player
end

function Bot:setVarsSimpleMovement(p_Player, p_SpawnMode, p_Transform)
	self._SpawnMode = p_SpawnMode
	self._MoveMode = 2
	self._BotSpeed = 3
	self._PathIndex = 0
	self._Respawning = false
	self._Shoot = false
	self._TargetPlayer = p_Player

	if p_Transform ~= nil then
		self._SpawnTransform = p_Transform
	end
end

function Bot:setVarsWay(p_Player, p_UseRandomWay, p_PathIndex, p_CurrentWayPoint, p_InverseDirection)
	if p_UseRandomWay then
		self._SpawnMode = 5
		self._TargetPlayer = nil
		self._Shoot = Globals.AttackWayBots
		self._Respawning = Globals.RespawnWayBots
	else
		self._SpawnMode = 4
		self._TargetPlayer = p_Player
		self._Shoot = false
		self._Respawning = false
	end

	self._BotSpeed = 3
	self._MoveMode = 5
	self._PathIndex = p_PathIndex
	self._CurrentWayPoint = p_CurrentWayPoint
	self._InvertPathDirection = p_InverseDirection
end

function Bot:isStaticMovement()
	if self._MoveMode == 0 or self._MoveMode == 3 or self._MoveMode == 4 then
		return true
	else
		return false
	end
end

function Bot:setMoveMode(p_MoveMode)
	self._MoveMode = p_MoveMode
end

function Bot:setRespawn(p_Respawn)
	self._Respawning = p_Respawn
end

function Bot:setShoot(p_Shoot)
	self._Shoot = p_Shoot
end

function Bot:setSpeed(p_Speed)
	self._BotSpeed = p_Speed
end

function Bot:setObjective(p_Objective)
	self._Objective = p_Objective or ''
end

function Bot:getObjective(p_Objective)
	return self._Objective
end

function Bot:getSpawnMode()
	return self._SpawnMode
end

function Bot:getWayIndex()
	return self._PathIndex
end

function Bot:getSpawnTransform()
	return self._SpawnTransform
end

function Bot:getTargetPlayer()
	return self._TargetPlayer
end

function Bot:isInactive()
	if self.m_Player.alive or self._SpawnMode ~= 0 then
		return false
	else
		return true
	end
end

function Bot:resetSpawnVars()
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
	self._AttackMode = 0
	self._ShootWayPoints = {}
	self._Skill = math.random()*Config.BotWorseningSkill

	self._ShotTimer = 0
	self._UpdateTimer = 0
	self._AimUpdateTimer = 0 --timer sync
	self._StuckTimer = 0
	self._TargetPoint = nil
	self._NextTargetPoint = nil
	self._MeleeActive = false
	self._KnifeWayPositions = {}
	self._ZombieSpeedValue = 0
	self._OnSwitch = false
	self._ActionActive = false
	self._ReviveActive = false
	self._GrenadeActive = false
	self._C4Active = false
	self._Objective = '' --reset objective on spawn, as an other spawn-point might have chosen...
	self._WeaponToUse = "Primary"

	-- reset all input-vars
	for i = 0, 36 do
		self.m_ActiveInputs[i] = {
			value = 0,
			reset = false
		}
		self.m_Player.input:SetLevel(i, 0)
	end
end

function Bot:clearPlayer(p_Player)
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

function Bot:kill()
	self:resetVars()

	if self.m_Player.alive then
		self.m_Player.soldier:Kill()
	end
end

function Bot:destroy()
	self:resetVars()
	self.m_Player.input = nil

	PlayerManager:DeletePlayer(self.m_Player)
	self.m_Player = nil
end

-- private functions
function Bot:_updateRespwawn()
	if self._Respawning and self.m_Player.soldier == nil and self._SpawnMode > 0 then
		-- wait for respawn-delay gone
		if self._SpawnDelayTimer < Globals.RespawnDelay then
			self._SpawnDelayTimer = self._SpawnDelayTimer + StaticConfig.BotUpdateCycle
		else
			Events:DispatchLocal('Bot:RespawnBot', self.m_Name)
		end
	end
end

function Bot:_updateAiming()
	if (not self.m_Player.alive or self._ShootPlayer == nil) then
		return
	end
	if not self._ReviveActive then
		if (not self._Shoot or self._ShootPlayer.soldier == nil or self.m_ActiveWeapon == nil) then
			return
		end
		--interpolate player movement
		local s_TargetMovement = Vec3.zero
		local s_PitchCorrection = 0.0
		local s_FullPositionTarget = self._ShootPlayer.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self._ShootPlayer, true)
		local s_FullPositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false)
		if self.m_InVehicle then --TODO: calculate height of gun of vehicle
			s_FullPositionBot = s_FullPositionBot + Vec3(0.0, 1.5, 0.0)  -- bot in vehicle is higher
		end
		local s_GrenadePitch = 0.0
		--calculate how long the distance is --> time to travel
		local s_DistanceToPlayer = s_FullPositionTarget:Distance(s_FullPositionBot)

		if not self.m_KnifeMode then
			local s_FactorForMovement = 0.0
			local s_Drop = 0.0
			local s_Speed = 0.0
			if self.m_InVehicle then
				s_Drop = 9.81
				s_Speed = 350
			else
				s_Drop = self.m_ActiveWeapon.bulletDrop
				s_Speed = self.m_ActiveWeapon.bulletSpeed
			end
			if self.m_ActiveWeapon.type == "Grenade" then
				if s_DistanceToPlayer < 5 then
					s_DistanceToPlayer = 5 -- don't throw them too close..
				end
				local s_Angle = math.asin((s_DistanceToPlayer * s_Drop)/(s_Speed*s_Speed))
				if s_Angle ~= s_Angle then --NAN check
					s_GrenadePitch = (math.pi / 4)
				else
					s_GrenadePitch = (math.pi / 2) - (s_Angle / 2)
				end
			else
				local s_TimeToTravel = (s_DistanceToPlayer / s_Speed)
				s_FactorForMovement = (s_TimeToTravel) / self._UpdateTimer
				s_PitchCorrection = 0.5 * s_TimeToTravel * s_TimeToTravel * s_Drop
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
		-- worsen yaw depending on bot-skill
		local s_WorseningValue = (math.random()*self._Skill/s_DistanceToPlayer) -- value scaled in offset in 1m
		s_Yaw = s_Yaw + s_WorseningValue

		--calculate pitch
		local s_Pitch = 0
		if self.m_ActiveWeapon.type == "Grenade" then
			s_Pitch = s_GrenadePitch
		else
			local s_Distance = math.sqrt(s_DifferenceZ ^ 2 + s_DifferenceX ^ 2)
			s_Pitch = math.atan(s_DifferenceY, s_Distance)
		end
		-- worsen yaw depending on bot-skill
		s_Pitch = s_Pitch + s_WorseningValue

		self._TargetPitch = s_Pitch
		self._TargetYaw = s_Yaw
	else
		if (self._ShootPlayer.corpse == nil) then
			return
		end
		local s_PositionTarget = self._ShootPlayer.corpse.worldTransform.trans:Clone()
		local s_PositionBot = self.m_Player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.m_Player, false)

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

function Bot:_updateYaw()
	if self.m_InVehicle and self.m_Player.attachedControllable == nil then
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
			s_Pos = self.m_Player.attachedControllable.transform.forward
			local s_AtanDzDx = math.atan(s_Pos.z, s_Pos.x)
			local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
			s_DeltaYaw = s_Yaw - self._TargetYaw
			local s_DiffPos = s_Pos - self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(self._VehicleMovableId):ToLinearTransform().forward
			-- prepare for moving gun back
			self._LastVehicleYaw = s_Yaw
			if s_DiffPos.x > 0.1 or s_DiffPos.z > 0.1 then
				s_CorrectGunYaw = true
			end

		else
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
		local s_Value = 1.0
		if math.abs(s_DeltaPitch) < 0.05 then -- 3°
			s_Value = 0.2
		end

		if s_DeltaPitch > 0 then
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, -s_Value)
		else
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAPitch, s_Value)
		end
	end

	if s_AbsDeltaYaw < s_Increment then
		if self.m_InVehicle then
			if not s_AttackAiming then
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0.0)
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
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0.0)
				if s_Increment > 0 then
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 0.2)
				elseif s_Increment < 0 then
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -0.2)
				else
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 0.0)
				end
			end
		else
			self.m_Player.input.authoritativeAimingYaw = self._TargetYaw
			self.m_Player.input.authoritativeAimingPitch = self._TargetPitch
		end
		return
	end

	if s_DeltaYaw > 0  then
		s_Increment = -s_Increment
	end

	local s_TempYaw = self.m_Player.input.authoritativeAimingYaw + s_Increment

	if s_TempYaw >= (math.pi * 2) then
		s_TempYaw = s_TempYaw - (math.pi * 2)
	elseif s_TempYaw < 0.0 then
		s_TempYaw = s_TempYaw + (math.pi * 2)
	end

	if self.m_InVehicle then
		local s_YawValue = 0;
		if s_AttackAiming then
			s_YawValue = 1.0
		else
			if self.m_ActiveSpeedValue < 0 then
				s_YawValue = -1.0
			else
				s_YawValue = 1.0
			end
		end


		if not s_AttackAiming then
			if s_CorrectGunYaw then
				if self._VehicleDirBackPositive then
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 1)
				else
					self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -1)
				end
			else
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, 0)
			end

			if s_Increment > 0 then
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, s_YawValue)
			else
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, -s_YawValue)
			end
		else
			self.m_Player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0.0)
			if s_Increment > 0 then
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, s_YawValue)
			else
				self.m_Player.input:SetLevel(EntryInputActionEnum.EIARoll, -s_YawValue)
			end
		end
	else
		self.m_Player.input.authoritativeAimingYaw = s_TempYaw
		self.m_Player.input.authoritativeAimingPitch = self._TargetPitch
	end
end

function Bot:_findOutVehicleType(p_Player)
	local s_VehicleType = 0 -- no vehicle
	if p_Player.attachedControllable ~= nil and not p_Player.attachedControllable:Is("SoldierEntity") then
		local s_VehicleName = VehicleTable[VehicleEntityData(p_Player.attachedControllable.data).controllableType:gsub(".+/.+/","")]
		-- Tank
		if s_VehicleName == "[LAV-25]" or
		s_VehicleName == "[SPRUT-SD]" or
		s_VehicleName == "[BMP-2M]" or
		s_VehicleName == "[M1 ABRAMS]" or
		s_VehicleName == "[T-90A]" or
		s_VehicleName == "[M1128]" or
		s_VehicleName == "[RHINO]"
		then
			s_VehicleType = 1
		end

		-- light Vehicle
		if s_VehicleName == "[AAV-7A1 AMTRAC]" or
		s_VehicleName == "[9K22 TUNGUSKA-M]" or

		s_VehicleName == "[GAZ-3937 VODNIK]" or
		s_VehicleName == "[LAV-AD]"  or
		s_VehicleName == "[M1114 HMMWV]" or
		s_VehicleName == "[HMMWV ASRAD]" or
		s_VehicleName == "[GUNSHIP]" or
		s_VehicleName == "[M142]" or
		s_VehicleName == "[BM-23]" or
		s_VehicleName == "[BARSUK]" or
		s_VehicleName == "[VODNIK AA]" or
		s_VehicleName == "[BTR-90]"
		then
			s_VehicleType = 2
		end

		-- Air vehicles
		if s_VehicleName == "[A-10 THUNDERBOLT]" or
		s_VehicleName == "[AH-1Z VIPER]" or
		s_VehicleName == "[AH-6J LITTLE BIRD]" or
		s_VehicleName == "[F/A-18E SUPER HORNET]" or
		s_VehicleName == "[KA-60 KASATKA]" or
		s_VehicleName == "[MI-28 HAVOC]" or
		s_VehicleName == "[SU-25TM FROGFOOT]" or
		s_VehicleName == "[SU-35BM FLANKER-E]" or
		s_VehicleName == "[SU-37]" or
		s_VehicleName == "[UH-1Y VENOM]" or
		s_VehicleName == "[Z-11W]" or
		s_VehicleName == "[F-35]"
		then
			s_VehicleType = 3
		end

		-- no armor at all
		if s_VehicleName == "[GROWLER ITV]" or
		s_VehicleName == "[CIVILIAN CAR]" or
		s_VehicleName == "[DELIVERY VAN]" or
		s_VehicleName == "[SUV]" or
		s_VehicleName == "[POLICE VAN]" or
		s_VehicleName == "[RHIB BOAT]" or
		s_VehicleName == "[TECHNICAL TRUCK]" or
		s_VehicleName == "[VDV Buggy]" or
		s_VehicleName == "[QUAD BIKE]" or
		s_VehicleName == "[DIRTBIKE]" or
		s_VehicleName == "[DPV]" or
		s_VehicleName == "[SKID LOADER]"
		then
			s_VehicleType = 4
		end
	end
	return s_VehicleType
end

function Bot:_ceckForVehicleAttack(p_VehicleType, p_Distance)
	local s_AttackMode = 0 -- no attack
	if p_VehicleType == 4 and p_Distance < Config.MaxRaycastDistance then
		s_AttackMode = 1 -- attack with rifle
	elseif p_VehicleType == 3 and p_Distance < Config.MaxRaycastDistance then
		s_AttackMode = 1 -- attack with rifle
	elseif p_VehicleType == 2 and p_Distance < 35 then
		s_AttackMode = 2 -- attack with grenade
	end
	if self.m_SecondaryGadget.type == "Rocket" then
		s_AttackMode = 3 -- always use rocket if possible
	elseif self.m_SecondaryGadget.type == "C4" and p_Distance < 25 then
		if p_VehicleType ~= 3 then -- no air vehicles
			s_AttackMode = 4 -- always use c4 if possible
		end
	end
	return s_AttackMode
end

function Bot:_updateShooting()
	if self.m_Player.alive and self._Shoot then
		--select weapon-slot TODO: keep button pressed or not?
		if not self._MeleeActive then
			if self.m_Player.soldier.weaponsComponent ~= nil then
				if self.m_KnifeMode then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon7, 1)
						self.m_ActiveWeapon = self.m_Knife
						self._ShotTimer = 0
					end
				elseif self._ReviveActive or (self._WeaponToUse == "Gadget2" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Gadget2" then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_5 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon5, 1)
						self.m_ActiveWeapon = self.m_SecondaryGadget
						self._ShotTimer = - (Config.BotFirstShotDelay + math.random()*self._Skill)
					end
				elseif (self._WeaponToUse == "Gadget1" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Gadget1" then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_2 and self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_4 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon4, 1)
						self:_setInput(EntryInputActionEnum.EIASelectWeapon3, 1)
						self.m_ActiveWeapon = self.m_PrimaryGadget
						self._ShotTimer = - (Config.BotFirstShotDelay + math.random()*self._Skill)
					end
				elseif self._GrenadeActive or (self._WeaponToUse == "Grenade" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Grenade" then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_6 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon6, 1)
						self.m_ActiveWeapon = self.m_Grenade
						self._ShotTimer = - (Config.BotFirstShotDelay + math.random()*self._Skill)
					end
				elseif (self._WeaponToUse == "Pistol" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Pistol" then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_1 then
						self.m_Player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 1)
						self:_setInput(EntryInputActionEnum.EIASelectWeapon2, 1)
						self.m_ActiveWeapon = self.m_Pistol
						self._ShotTimer = - (Config.BotFirstShotDelay + math.random()*self._Skill)/2 -- TODO: maybe a little less or more?
					end
				elseif (self._WeaponToUse == "Primary" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Primary" then
					if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon1, 1)
						self.m_ActiveWeapon = self.m_Primary
						self._ShotTimer = 0
					end
				end
			end
		end

		if self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil then
			if self._ShootModeTimer < Config.BotFireModeDuration or (Config.ZombieMode and self._ShootModeTimer < (Config.BotFireModeDuration * 4)) then
				local s_CurrentDistance = self._ShootPlayer.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans)
				if not self._C4Active then
					self:_setInput(EntryInputActionEnum.EIAZoom, 1)
				end
				if not self._GrenadeActive then
					self._ShootModeTimer = self._ShootModeTimer + StaticConfig.BotUpdateCycle
				end
				if self._C4Active then
					self.m_ActiveMoveMode = 8 -- movement-mode : C4 / revive
				else
					self.m_ActiveMoveMode = 9 -- movement-mode : attack
				end
				self._ReloadTimer = 0 -- reset reloading

				--check for melee attack
				if Config.MeleeAttackIfClose and not self._MeleeActive and self._MeleeCooldownTimer <= 0 and self._ShootPlayer.soldier.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 2 then
					self._MeleeActive = true
					self.m_ActiveWeapon = self.m_Knife

					self:_setInput(EntryInputActionEnum.EIASelectWeapon7, 1)
					self:_setInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
					self:_setInput(EntryInputActionEnum.EIAMeleeAttack, 1)
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

				-- target in vehicle - use gadget 2 if rocket --TODO: don't shoot with other classes
				local s_VehicleType = self:_findOutVehicleType(self._ShootPlayer)
				if s_VehicleType ~= 0 then
					local s_AttackMode = self:_ceckForVehicleAttack(s_VehicleType, s_CurrentDistance)
					if s_AttackMode > 0 then
						if s_AttackMode == 2 then -- grenade
							self._GrenadeActive = true
						elseif s_AttackMode == 3 then -- rocket
							self._WeaponToUse = "Gadget2"
							if self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 2 then
								self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 3
							end
						elseif s_AttackMode == 4 then -- C4
							self._WeaponToUse = "Gadget2"
							self._C4Active = true
						elseif s_AttackMode == 1 then
							-- TODO: doble code is not nice
							if not self._GrenadeActive and self.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
								if self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 then
									self._WeaponToUse = "Pistol"
								else
									self._WeaponToUse = "Primary"
								end
							end
						end
					else
						self._ShootModeTimer = Config.BotFireModeDuration -- end attack
					end
				else
					if self.m_KnifeMode or self._MeleeActive then
						self._WeaponToUse = "Knife"
					else
						if not self._GrenadeActive and self.m_Player.soldier.weaponsComponent.weapons[1] ~= nil then
							if self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 and s_CurrentDistance <= Config.MaxShootDistancePistol then
								self._WeaponToUse = "Pistol"
							else
								self._WeaponToUse = "Primary"
							end
						end
						-- use grenade from time to time
						if Config.BotsThrowGrenades then
							local s_TargetTimeValue = Config.BotFireModeDuration - 0.5
							if ((self._ShootModeTimer >= s_TargetTimeValue) and (self._ShootModeTimer < (s_TargetTimeValue + StaticConfig.BotUpdateCycle)) and not self._GrenadeActive) or Config.BotWeapon == "Grenade" then
								-- should be triggered only once per fireMode
								if MathUtils:GetRandomInt(1,100) <= 30 then
									if self.m_Grenade ~= nil and s_CurrentDistance < 35 then
										self._GrenadeActive = true
									end
								end
							end
						end
					end
				end

				--trace way back
				if (self.m_ActiveWeapon ~= nil and self.m_ActiveWeapon.type ~= "Sniper" and not self.m_InVehicle) or self.m_KnifeMode then
					if self._ShootTraceTimer > StaticConfig.TraceDeltaShooting then
						--create a Trace to find way back
						self._ShootTraceTimer = 0
						local s_Point = {
							Position = self.m_Player.soldier.worldTransform.trans:Clone(),
							SpeedMode = 4, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
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

							if s_CurrentDistance < 5 then
								if self._ShotTimer >= self.m_ActiveWeapon.pauseCycle then
									self:_setInput(EntryInputActionEnum.EIAZoom, 1)
								end
							end

						else
							if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
								--TODO: run away from object now
								if self._ShotTimer >= ((self.m_ActiveWeapon.fireCycle * 2) + self.m_ActiveWeapon.pauseCycle) then
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
									self.m_Player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 4
									self._C4Active = false
								end
							else
						end
						end
					else
						if self._ShotTimer >= (self.m_ActiveWeapon.fireCycle + self.m_ActiveWeapon.pauseCycle) then
							self._ShotTimer = 0
						end
						if self._ShotTimer >= 0 then
							if self.m_ActiveWeapon.delayed == false then
								if self._ShotTimer <= self.m_ActiveWeapon.fireCycle and not self._MeleeActive then
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
								end
							else --start with pause Cycle
								if self._ShotTimer >= self.m_ActiveWeapon.pauseCycle and not self._MeleeActive then
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
								end
							end
						end
					end

					self._ShotTimer = self._ShotTimer + StaticConfig.BotUpdateCycle
				end

			else
				self._TargetPitch = 0.0
				self._WeaponToUse = "Primary"
				self._ShootPlayerName = ""
				self._ShootPlayer = nil
				self._GrenadeActive = false
				self._C4Active = false
				self._LastShootPlayer = nil
			end
		elseif self._ReviveActive and self._ShootPlayer ~= nil then
			if self._ShootPlayer.corpse ~= nil then  -- revive
				self._ShootModeTimer = self._ShootModeTimer + StaticConfig.BotUpdateCycle
				self.m_ActiveMoveMode = 8 -- movement-mode : revive
				self._ReloadTimer = 0 -- reset reloading

				--check for revive if close
				if self._ShootPlayer.corpse.worldTransform.trans:Distance(self.m_Player.soldier.worldTransform.trans) < 3 then
					self:_setInput(EntryInputActionEnum.EIAFire, 1)
				end

				--trace way back
				if self._ShootTraceTimer > StaticConfig.TraceDeltaShooting then
					--create a Trace to find way back
					self._ShootTraceTimer = 0
					local s_Point = {
						Position = self.m_Player.soldier.worldTransform.trans:Clone(),
						SpeedMode = 4, -- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
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
				self._WeaponToUse = "Primary"
				self._ShootPlayer = nil
				self._ReviveActive = false
			end
		else
			self._WeaponToUse = "Primary"
			self._GrenadeActive = false
			self._C4Active = false
			self._ShootPlayer = nil
			self._LastShootPlayer = nil
			self._ReviveActive = false
			self._ShootModeTimer = 0
			self._AttackMode = 0

			self._ReloadTimer = self._ReloadTimer + StaticConfig.BotUpdateCycle
			if self._ReloadTimer > 1.5 and self._ReloadTimer < 2.5 and self.m_Player.soldier.weaponsComponent.currentWeapon.primaryAmmo <= self.m_ActiveWeapon.reload then
				self:_setInput(EntryInputActionEnum.EIAReload, 1)
			end

			-- deploy from time to time
			if Config.BotsDeploy then
				if self.m_Kit == "Support" or self.m_Kit == "Assault" then
					if self.m_PrimaryGadget.type == "Ammobag" or self.m_PrimaryGadget.type == "Medkit" then
						self._DeployTimer = self._DeployTimer + StaticConfig.BotUpdateCycle
						if self._DeployTimer > Config.DeployCycle then
							self._DeployTimer = 0
						end
						if self._DeployTimer < 0.7 then
							self._WeaponToUse = "Gadget1"
						end
					end
				end
			end
		end
	end
end

function Bot:_getWayIndex(p_CurrentWayPoint)
	local s_ActivePointIndex = 1

	if p_CurrentWayPoint == nil then
		p_CurrentWayPoint = s_ActivePointIndex
	else
		s_ActivePointIndex = p_CurrentWayPoint

		-- direction handling
		local s_CountOfPoints = #m_NodeCollection:Get(nil, self._PathIndex)
		local s_FirstPoint =  m_NodeCollection:GetFirst(self._PathIndex)
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

function Bot:_updateMovement()
	-- movement-mode of bots
	local s_AdditionalMovementPossible = true

	if self.m_Player.alive then
		-- pointing
		if self.m_ActiveMoveMode == 2 and self._TargetPlayer ~= nil then
			if self._TargetPlayer.soldier ~= nil then
				local s_DifferenceY = self._TargetPlayer.soldier.worldTransform.trans.z - self.m_Player.soldier.worldTransform.trans.z
				local s_DifferenceX = self._TargetPlayer.soldier.worldTransform.trans.x - self.m_Player.soldier.worldTransform.trans.x
				local s_AtanDzDx = math.atan(s_DifferenceY, s_DifferenceX)
				local s_Yaw = (s_AtanDzDx > math.pi / 2) and (s_AtanDzDx - math.pi / 2) or (s_AtanDzDx + 3 * math.pi / 2)
				self._TargetYaw = s_Yaw
			end

		-- mimicking
		elseif self.m_ActiveMoveMode == 3 and self._TargetPlayer ~= nil then
			s_AdditionalMovementPossible = false

			for i = 0, 36 do
				self:_setInput(i, self._TargetPlayer.input:GetLevel(i))
			end

			self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw
			self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch

		-- mirroring
		elseif self.m_ActiveMoveMode == 4 and self._TargetPlayer ~= nil then
			s_AdditionalMovementPossible = false

			for i = 0, 36 do
				self:_setInput(i, self._TargetPlayer.input:GetLevel(i))
			end

			self._TargetYaw = self._TargetPlayer.input.authoritativeAimingYaw + ((self._TargetPlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
			self._TargetPitch = self._TargetPlayer.input.authoritativeAimingPitch

		-- move along points
		elseif self.m_ActiveMoveMode == 5 then
			self._AttackModeMoveTimer = 0

			if m_NodeCollection:Get(1, self._PathIndex) ~= nil then -- check for valid point
				-- get next point
				local s_ActivePointIndex = self:_getWayIndex(self._CurrentWayPoint)

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
						if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, s_ActivePointIndex, self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0), "Blue")
						end
					end
					s_UseShootWayPoint = true
				else
					s_Point = m_NodeCollection:Get(s_ActivePointIndex, self._PathIndex)
					if not self._InvertPathDirection then
						s_NextPoint = m_NodeCollection:Get(self:_getWayIndex(self._CurrentWayPoint + 1), self._PathIndex)
						if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, self:_getWayIndex(self._CurrentWayPoint + 1), self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0), "Green")
						end
					else
						s_NextPoint = m_NodeCollection:Get(self:_getWayIndex(self._CurrentWayPoint - 1), self._PathIndex)
						if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._PathIndex, self:_getWayIndex(self._CurrentWayPoint - 1), self.m_Player.soldier.worldTransform.trans, (self._ObstaceSequenceTimer > 0), "Green")
						end
					end
				end

				-- execute Action if needed
				if self._ActionActive then
					if s_Point.Data ~= nil and s_Point.Data.Action ~= nil then
						if s_Point.Data.Action.type == "vehicle" then
							local s_Iterator = EntityManager:GetIterator("ServerVehicleEntity")
							local s_Entity = s_Iterator:Next()

							while s_Entity ~= nil do
								s_Entity = ControllableEntity(s_Entity)
								local s_Position = s_Entity.transform.trans
								if s_Position:Distance(self.m_Player.soldier.worldTransform.trans) < 5 then
									for i = 0, s_Entity.entryCount - 1 do
										if s_Entity:GetPlayerInEntry(i) == nil then
											self.m_Player:EnterVehicle(s_Entity, i)
											self._VehicleEntity = s_Entity.physicsEntityBase
											for j = 0, self._VehicleEntity.partCount - 1 do
												if self.m_Player.controlledControllable.physicsEntityBase:GetPart(j) ~= nil and self.m_Player.controlledControllable.physicsEntityBase:GetPart(j):Is("ServerChildComponent") then
													local s_QuatTransform = self.m_Player.controlledControllable.physicsEntityBase:GetPartTransform(j)
													if s_QuatTransform == nil then
														return
													end
													self._VehicleMovableTransform = s_QuatTransform
													self._VehicleMovableId = j
													break
												end
											end

											self._ActionActive = false
											local s_Node = g_GameDirector:findClosestPath(s_Position, true)
											if s_Node ~= nil then
												-- switch to vehicle
												s_Point = s_Node
												self._InvertPathDirection = false
												self._PathIndex = s_Node.PathIndex
												self._CurrentWayPoint = s_Node.PointIndex
												s_NextPoint = m_NodeCollection:Get(self:_getWayIndex(self._CurrentWayPoint + 1), self._PathIndex)
												self._LastWayDistance = 1000
											end
											break
										end
									end
									break
								end
								s_Entity = s_Iterator:Next()
							end
							self._ActionActive = false

						elseif self._ActionTimer <= s_Point.Data.Action.time then
							for _, l_Input in pairs(s_Point.Data.Action.inputs) do
								self:_setInput(l_Input, 1)
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

				if (s_Point.SpeedMode) > 0 then -- movement
					self._WayWaitTimer = 0
					self._WayWaitYawTimer = 0
					self.m_ActiveSpeedValue = s_Point.SpeedMode --speed
					if Config.ZombieMode then
						if self._ZombieSpeedValue == 0 then
							self._ZombieSpeedValue = MathUtils:GetRandomInt(1,2)
						end
						self.m_ActiveSpeedValue = self._ZombieSpeedValue
					end
					if Config.OverWriteBotSpeedMode > 0 then
						self.m_ActiveSpeedValue = Config.OverWriteBotSpeedMode
					end
					local s_DifferenceY = s_Point.Position.z - self.m_Player.soldier.worldTransform.trans.z
					local s_DifferenceX = s_Point.Position.x - self.m_Player.soldier.worldTransform.trans.x
					local s_DistanceFromTarget = math.sqrt(s_DifferenceX ^ 2 + s_DifferenceY ^ 2)
					local s_HeightDistance = math.abs(s_Point.Position.y - self.m_Player.soldier.worldTransform.trans.y)


					--detect obstacle and move over or around TODO: Move before normal jump
					local s_CurrentWayPointDistance = self.m_Player.soldier.worldTransform.trans:Distance(s_Point.Position)
					if s_CurrentWayPointDistance > self._LastWayDistance + 0.02 and self._ObstaceSequenceTimer == 0 then
						--TODO: skip one pooint?
						s_DistanceFromTarget = 0
						s_HeightDistance = 0
					end

					self._TargetPoint = s_Point
					self._NextTargetPoint = s_NextPoint


					if (math.abs(s_CurrentWayPointDistance - self._LastWayDistance) < 0.02 or self._ObstaceSequenceTimer ~= 0) then
						-- try to get around obstacle
						self.m_ActiveSpeedValue = 4 --always try to stand
						if self.m_InVehicle then
							if self._ObstacleRetryCounter == 0 then
								self.m_ActiveSpeedValue = -1
							else
								self.m_ActiveSpeedValue = 1
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
									self:_setInput(EntryInputActionEnum.EIASelectWeapon7, 1)
									self:_setInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
									self:_setInput(EntryInputActionEnum.EIAMeleeAttack, 1)
								else
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
								end
							end

						elseif self._ObstaceSequenceTimer > 0.4 then --step 2
							self._TargetPitch = 0.0
							if (MathUtils:GetRandomInt(0,1) == 1) then
								self:_setInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
							else
								self:_setInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
							end

						elseif self._ObstaceSequenceTimer > 0.0 then --step 1
							self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
							self:_setInput(EntryInputActionEnum.EIAJump, 1)
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
							--if Globals.IsConquest or Globals.IsRush then  --TODO: only invert path, if its not a connecting path
								--self._InvertPathDirection = (MathUtils:GetRandomInt(0,100) < 40)
							--end
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
								self:_setInput(EntryInputActionEnum.EIAJump, 1)
								self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
							end
						end
					end

					local s_TargetDistanceSpeed = Config.TargetDistanceWayPoint
					if self.m_InVehicle  then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 5
					elseif self.m_ActiveSpeedValue == 4 then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 1.5
					elseif self.m_ActiveSpeedValue == 2 then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.7
					elseif self.m_ActiveSpeedValue == 1 then
						s_TargetDistanceSpeed = s_TargetDistanceSpeed * 0.5
					end

					--check for reached target
					if (s_DistanceFromTarget <= s_TargetDistanceSpeed and s_HeightDistance <= StaticConfig.TargetHeightDistanceWayPoint) then
						if not s_NoStuckReset then
							self._StuckTimer = 0
						end
						if not s_UseShootWayPoint then
							-- CHECK FOR ACTION
							if s_Point.Data.Action ~= nil then
								local s_Action = s_Point.Data.Action
								if g_GameDirector:checkForExecution(s_Point, self.m_Player.teamId) then
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
							s_SwitchPath, s_NewWaypoint = m_PathSwitcher:GetNewPath(self.m_Name, s_Point, self._Objective, self.m_InVehicle)
							if not self.m_Player.alive then
								return
							end

							if s_SwitchPath == true and not self._OnSwitch then
								if (self._Objective ~= '') then
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
					local s_LastYawTimer = self._WayWaitYawTimer
					self._WayWaitYawTimer = self._WayWaitYawTimer + StaticConfig.BotUpdateCycle
					self.m_ActiveSpeedValue = 0
					self._TargetPoint = nil

					-- move around a little
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
		elseif self.m_ActiveMoveMode == 9 then
			if self._AttackMode == 0 then
				if Config.BotAttackMode == "Crouch" then
					self._AttackMode = 2
				elseif Config.BotAttackMode == "Stand" then
					self._AttackMode = 3
				else -- random
					self._AttackMode = MathUtils:GetRandomInt(2, 3)
				end
			end
			--crouch moving (only mode with modified gun)
			if (self.m_ActiveWeapon.type == "Sniper" and not self.m_KnifeMode) or self.m_InVehicle then --don't move while shooting in a vehicle
				if self._AttackMode == 2 then
					if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
						self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
					end
				else
					if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
						self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
					end
				end
				self.m_ActiveSpeedValue = 0
			else
				local s_TargetTime = 5.0
				local s_TargetCycles = math.floor(s_TargetTime / StaticConfig.TraceDeltaShooting)

				if self.m_KnifeMode then --Knife Only Mode
					s_TargetCycles = 1
					self.m_ActiveSpeedValue = 4 --run towards player
				else
					if self._AttackMode == 2 then
						self.m_ActiveSpeedValue = 2
					else
						self.m_ActiveSpeedValue = 3
					end
				end
				if Config.OverWriteBotAttackMode > 0 then
					self.m_ActiveSpeedValue = Config.OverWriteBotAttackMode
				end

				if #self._ShootWayPoints > s_TargetCycles and Config.JumpWhileShooting then
					local s_DistanceDone = self._ShootWayPoints[#self._ShootWayPoints].Position:Distance(self._ShootWayPoints[#self._ShootWayPoints-s_TargetCycles].Position)
					if s_DistanceDone < 0.5 then --no movement was possible. Try to jump over obstacle
						self.m_ActiveSpeedValue = 3
						self:_setInput(EntryInputActionEnum.EIAJump, 1)
						self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					end
				end

				-- do some sidwards movement from time to time
				if self._AttackModeMoveTimer > 20 then
					self._AttackModeMoveTimer = 0
				elseif self._AttackModeMoveTimer > 17 then
					self:_setInput(EntryInputActionEnum.EIAStrafe, -0.5 * Config.SpeedFactorAttack)
				elseif self._AttackModeMoveTimer > 12 and self._AttackModeMoveTimer <= 13 then
					self:_setInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
				elseif self._AttackModeMoveTimer > 7 and self._AttackModeMoveTimer <= 9 then
					self:_setInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
				end

				self._AttackModeMoveTimer = self._AttackModeMoveTimer + StaticConfig.BotUpdateCycle
			end

		elseif self.m_ActiveMoveMode == 8 then  -- Revive Move Mode / C4 Mode
			self.m_ActiveSpeedValue = 4 --run to player
			if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
			local s_Jump = true
			if self._ShootPlayer ~= nil and self._ShootPlayer.corpse ~= nil then
				if self.m_Player.soldier.worldTransform.trans:Distance(self._ShootPlayer.corpse.worldTransform.trans) < 1 then
					self.m_ActiveSpeedValue = 0
					s_Jump = false
				end
			end

			--TODO: obstacle detection
			if s_Jump == true then
				self._AttackModeMoveTimer = self._AttackModeMoveTimer + StaticConfig.BotUpdateCycle
				if self._AttackModeMoveTimer > 3 then
					self._AttackModeMoveTimer = 0
				elseif self._AttackModeMoveTimer > 2.5 then
					self:_setInput(EntryInputActionEnum.EIAJump, 1)
					self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
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
				if self.m_ActiveMoveMode > 0 then
					if self.m_ActiveSpeedValue == 1 then
						s_SpeedVal = 0.25
					elseif self.m_ActiveSpeedValue == 2 then
						s_SpeedVal = 0.35
					elseif self.m_ActiveSpeedValue >= 3 then
						s_SpeedVal = 0.5
					elseif self.m_ActiveSpeedValue < 0 then
						s_SpeedVal = -0.4
					end
				end
			else
				if self.m_ActiveMoveMode > 0 then
					if self.m_ActiveSpeedValue == 1 then
						s_SpeedVal = 1.0

						if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
							self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
						end

					elseif self.m_ActiveSpeedValue == 2 then
						s_SpeedVal = 1.0

						if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
							self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
						end

					elseif self.m_ActiveSpeedValue >= 3 then
						s_SpeedVal = 1.0

						if self.m_Player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
							self.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
						end
					end
				end
			end

			-- do not reduce speed if sprinting
			if s_SpeedVal > 0 and self._ShootPlayer ~= nil and self._ShootPlayer.soldier ~= nil and self.m_ActiveSpeedValue <= 3 then
				s_SpeedVal = s_SpeedVal * Config.SpeedFactorAttack
			end

			-- movent speed
			if self.m_Player.alive then
				if self.m_ActiveSpeedValue <= 3 then
					if self.m_InVehicle then
						if self.m_ActiveSpeedValue < 0 then
							self._BrakeTimer = 0
							self:_setInput(EntryInputActionEnum.EIABrake, -s_SpeedVal)
						elseif self.m_ActiveSpeedValue > 0 then
							self._BrakeTimer = 0
							self:_setInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal)
						else
							if self._BrakeTimer < 0.7 then
								self:_setInput(EntryInputActionEnum.EIABrake, 1)
							end
							self._BrakeTimer = self._BrakeTimer + StaticConfig.BotUpdateCycle
						end
					else
						self:_setInput(EntryInputActionEnum.EIAThrottle, s_SpeedVal * Config.SpeedFactor)
					end

				else
					self:_setInput(EntryInputActionEnum.EIAThrottle, 1)
					self:_setInput(EntryInputActionEnum.EIASprint, s_SpeedVal * Config.SpeedFactor)
				end
			end
		end
	end
end

function Bot:_setActiveVars()
	if self._ShootPlayerName ~= "" then
		self._ShootPlayer = PlayerManager:GetPlayerByName(self._ShootPlayerName)
	else
		self._ShootPlayer = nil
		self._LastShootPlayer = nil
	end

	self.m_ActiveMoveMode = self._MoveMode
	self.m_ActiveSpeedValue = self._BotSpeed
	if self.m_Player.attachedControllable ~= nil and not self.m_Player.attachedControllable:Is("SoldierEntity") then
		self.m_InVehicle = true
	else
		self.m_InVehicle = false
	end

	if Config.BotWeapon == "Knife" or Config.ZombieMode then
		self.m_KnifeMode = true
	else
		self.m_KnifeMode = false
	end
end

function Bot:_getCameraHight(p_Soldier, p_IsTarget)
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
