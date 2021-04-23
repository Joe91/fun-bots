class('Bot')

require('__shared/Config')
require('__shared/Constants/VehicleNames')

local m_NodeCollection = require('__shared/NodeCollection')
local m_PathSwitcher = require('PathSwitcher')
local m_Utilities = require('__shared/Utilities')

function Bot:__init(p_Player)
	--Player Object
	self.player = p_Player
	self.name = p_Player.name
	self.id = p_Player.id

	--common settings
	self._spawnMode = 0
	self._moveMode = 0
	self.kit = ""
	self.color = ""
	self.activeWeapon = nil
	self.primary = nil
	self.pistol = nil
	self.gadget2 = nil
	self.gadget1 = nil
	self.grenade = nil
	self.knife = nil
	self._checkSwapTeam = false
	self._respawning = false

	--timers
	self._updateTimer = 0
	self._aimUpdateTimer = 0
	self._spawnDelayTimer = 0
	self._wayWaitTimer = 0
	self._wayWaitYawTimer = 0
	self._obstaceSequenceTimer = 0
	self._stuckTimer = 0
	self._shotTimer = 0
	self._shootModeTimer = 0
	self._reloadTimer = 0
	self._deployTimer = 0
	self._attackModeMoveTimer = 0
	self._meleeCooldownTimer = 0
	self._shootTraceTimer = 0
	self._actionTimer = 0

	--shared movement vars
	self.activeMoveMode = 0
	self.activeSpeedValue = 0
	self.knifeMode = false
	self.inVehicle = false
	self.newInputs = {}
	self.activeInputs = {}

	--advanced movement
	self._attackMode = 0
	self._currentWayPoint = nil
	self._targetYaw = 0
	self._targetPitch = 0
	self._targetPoint = nil
	self._nextTargetPoint = nil
	self._pathIndex = 0
	self._meleeActive = false
	self._lastWayDistance = 0
	self._invertPathDirection = false
	self._obstacleRetryCounter = 0
	self._zombieSpeedValue = 0
	self._objective = ''
	self._onSwitch = false
	self._actionActive = false
	self._reviveActive = false
	self._grenadeActive	= false
	self._c4Active = false

	--shooting
	self._shoot = false
	self._shootPlayer = nil
	self._shootPlayerName = ""
	self._weaponToUse = "Primary"
	self._shootWayPoints = {}
	self._knifeWayPositions = {}
	self._lastTargetTrans = Vec3()
	self._lastShootPlayer = nil
	self._skill = 0.0

	--simple movement
	self._botSpeed = 0
	self._targetPlayer = nil
	self._spawnTransform = LinearTransform()
end

function Bot:onUpdate(p_DeltaTime)
	if self.player.soldier ~= nil then
		self.player.soldier:SingleStepEntry(self.player.controlledEntryId)
	end

	if Globals.IsInputAllowed then
		self._updateTimer		= self._updateTimer + p_DeltaTime

		self:_updateYaw()

		if self._updateTimer > StaticConfig.BotUpdateCycle then
			self:_setActiveVars()
			self:_updateRespwawn()
			self:_updateAiming()
			self:_updateShooting()
			self:_updateMovement()

			self:_updateInputs()
			self._updateTimer = 0
		end
	end
end

function Bot:_setInput(p_Input, p_Value)
	self.activeInputs[p_Input] = {
	 	value = p_Value,
		reset = false
	}
end

function Bot:_updateInputs()
	for i = 0, 36 do
		if self.activeInputs[i].reset then
			self.player.input:SetLevel(i, 0)
			self.activeInputs[i].value = 0
			self.activeInputs[i].reset = false
		elseif self.activeInputs[i].value ~= 0 then
			self.player.input:SetLevel(i, self.activeInputs[i].value)
			self.activeInputs[i].reset = true
		end
	end
end

--public functions
function Bot:revive(p_Player)
	if self.kit == "Assault" and p_Player.corpse ~= nil then
		if Config.BotsRevive then
			self._reviveActive = true
			self._shootPlayer = nil
			self._shootPlayerName = p_Player.name
		end
	end
end

function Bot:shootAt(p_Player, p_IgnoreYaw)
	if self._actionActive or self._reviveActive or self._grenadeActive then
		return false
	end

	-- don't shoot at teammates
	if self.player.teamId == p_Player.teamId then
		return false
	end

	if p_Player.soldier == nil or self.player.soldier == nil then
		return false
	end

	-- don't shoot if too far away
	local distance = p_Player.soldier.worldTransform.trans:Distance(self.player.soldier.worldTransform.trans)
	if not p_IgnoreYaw then

		if self.activeWeapon.type ~= "Sniper" and distance > Config.MaxShootDistanceNoSniper then
			return false
		end
	end

	-- check for vehicles
	local type = self:_findOutVehicleType(p_Player)
	if type ~= 0 and self:_ceckForVehicleAttack(type, distance) == 0 then
		return false
	end

	local dYaw		= 0
	local fovHalf	= 0

	if not p_IgnoreYaw then
		local oldYaw	= self.player.input.authoritativeAimingYaw
		local dy		= p_Player.soldier.worldTransform.trans.z - self.player.soldier.worldTransform.trans.z
		local dx		= p_Player.soldier.worldTransform.trans.x - self.player.soldier.worldTransform.trans.x
		local yaw		= (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2)

		dYaw			= math.abs(oldYaw-yaw)

		if dYaw > math.pi then
			dYaw =math.pi * 2 - dYaw
		end

		fovHalf = Config.FovForShooting / 360 * math.pi
	end

	if dYaw < fovHalf or p_IgnoreYaw then
		if self._shoot then
			if self._shootPlayer == nil or self._shootModeTimer > Config.BotMinTimeShootAtPlayer or (self.knifeMode and self._shootModeTimer > (Config.BotMinTimeShootAtPlayer/2)) then
				self._shootModeTimer		= 0
				self._shootPlayerName		= p_Player.name
				self._shootPlayer			= nil
				self._lastShootPlayer 		= nil
				self._lastTargetTrans 		= p_Player.soldier.worldTransform.trans:Clone()
				self._knifeWayPositions 	= {}
				self._shotTimer				= - (Config.BotFirstShotDelay + math.random()*self._skill)

				if self.knifeMode then
					table.insert(self._knifeWayPositions, self._lastTargetTrans)
				end

				return true
			end
		else
			self._shootModeTimer = Config.BotFireModeDuration
			return false
		end
	end

	return false
end

function Bot:setVarsDefault()
	self._spawnMode		= 5
	self._moveMode		= 5
	self._botSpeed		= 3
	self._pathIndex		= 1
	self._respawning	= Globals.RespawnWayBots
	self._shoot			= Globals.AttackWayBots
end

function Bot:resetVars()
	self._spawnMode				= 0
	self._moveMode				= 0
	self._pathIndex				= 0
	self._respawning			= false
	self._shoot					= false
	self._targetPlayer			= nil
	self._shootPlayer			= nil
	self._shootPlayerName		= ""
	self._lastShootPlayer		= nil
	self._invertPathDirection	= false
	self._shotTimer				= 0
	self._updateTimer			= 0
	self._aimUpdateTimer		= 0 --timer sync
	self._targetPoint			= nil
	self._nextTargetPoint		= nil
	self._knifeWayPositions		= {}
	self._shootWayPoints 		= {}
	self._zombieSpeedValue 		= 0
	self._spawnDelayTimer		= 0
	self._objective 			= ''
	self._meleeActive 			= false
	self._actionActive 			= false
	self._reviveActive 			= false
	self._grenadeActive			= false
	self._c4Active 				= false
	self._weaponToUse 			= "Primary"
end

function Bot:setVarsStatic(p_Player)
	self._spawnMode		= 0
	self._moveMode		= 0
	self._pathIndex		= 0
	self._respawning	= false
	self._shoot			= false
	self._targetPlayer	= p_Player
end

function Bot:setVarsSimpleMovement(p_Player, p_SpawnMode, p_Transform)
	self._spawnMode		= p_SpawnMode
	self._moveMode		= 2
	self._botSpeed		= 3
	self._pathIndex		= 0
	self._respawning	= false
	self._shoot			= false
	self._targetPlayer	= p_Player

	if p_Transform ~= nil then
		self._spawnTransform = p_Transform
	end
end

function Bot:setVarsWay(p_Player, p_UseRandomWay, p_PathIndex, p_CurrentWayPoint, p_InverseDirection)
	if p_UseRandomWay then
		self._spawnMode		= 5
		self._targetPlayer	= nil
		self._shoot			= Globals.AttackWayBots
		self._respawning	= Globals.RespawnWayBots
	else
		self._spawnMode		= 4
		self._targetPlayer	= p_Player
		self._shoot			= false
		self._respawning	= false
	end

	self._botSpeed				= 3
	self._moveMode				= 5
	self._pathIndex				= p_PathIndex
	self._currentWayPoint		= p_CurrentWayPoint
	self._invertPathDirection	= p_InverseDirection
end

function Bot:isStaticMovement()
	if self._moveMode == 0 or self._moveMode == 3 or self._moveMode == 4 then
		return true
	else
		return false
	end
end

function Bot:setMoveMode(p_MoveMode)
	self._moveMode = p_MoveMode
end

function Bot:setRespawn(p_Respawn)
	self._respawning = p_Respawn
end

function Bot:setShoot(p_Shoot)
	self._shoot = p_Shoot
end

function Bot:setSpeed(p_Speed)
	self._botSpeed = p_Speed
end

function Bot:setObjective(p_Objective)
	self._objective = p_Objective or ''
end

function Bot:getObjective(p_Objective)
	return self._objective
end

function Bot:getSpawnMode()
	return self._spawnMode
end

function Bot:getWayIndex()
	return self._pathIndex
end

function Bot:getSpawnTransform()
	return self._spawnTransform
end

function Bot:getTargetPlayer()
	return self._targetPlayer
end

function Bot:isInactive()
	if self.player.alive or self._spawnMode ~= 0 then
		return false
	else
		return true
	end
end

function Bot:resetSpawnVars()
	self._spawnDelayTimer		= 0
	self._obstaceSequenceTimer	= 0
	self._obstacleRetryCounter	= 0
	self._lastWayDistance		= 1000
	self._shootPlayer			= nil
	self._lastShootPlayer		= nil
	self._shootPlayerName		= ""
	self._shootModeTimer		= 0
	self._meleeCooldownTimer	= 0
	self._shootTraceTimer		= 0
	self._reloadTimer 			= 0
	self._deployTimer 			= MathUtils:GetRandomInt(1, Config.DeployCycle)
	self._attackModeMoveTimer	= 0
	self._attackMode 			= 0
	self._shootWayPoints		= {}
	self._skill					= math.random()*Config.BotWorseningSkill
	--print("assigned Skill "..tostring(self._skill).." to "..self.name)

	self._shotTimer				= 0
	self._updateTimer			= 0
	self._aimUpdateTimer		= 0 --timer sync
	self._stuckTimer			= 0
	self._targetPoint			= nil
	self._nextTargetPoint		= nil
	self._meleeActive 			= false
	self._knifeWayPositions		= {}
	self._zombieSpeedValue 		= 0
	self._onSwitch 				= false
	self._actionActive 			= false
	self._reviveActive 			= false
	self._grenadeActive			= false
	self._c4Active 				= false
	self._objective 			= '' --reset objective on spawn, as an other spawn-point might have chosen...
	self._weaponToUse 			= "Primary"

	-- reset all input-vars
	for i = 0, 36 do
		self.activeInputs[i] = {
			value = 0,
			reset = false
		}
		self.player.input:SetLevel(i, 0)
	end
end

function Bot:clearPlayer(p_Player)
	if self._shootPlayer == p_Player then
		self._shootPlayer = nil
	end

	if self._targetPlayer == p_Player then
		self._targetPlayer = nil
	end

	if self._lastShootPlayer == p_Player then
		self._lastShootPlayer = nil
	end

	local currentShootPlayer = PlayerManager:GetPlayerByName(self._shootPlayerName)
	if currentShootPlayer == p_Player then
		self._shootPlayerName = ""
	end
end

function Bot:kill()
	self:resetVars()

	if self.player.alive then
		self.player.soldier:Kill()
	end
end

function Bot:destroy()
	self:resetVars()
	self.player.input	= nil

	PlayerManager:DeletePlayer(self.player)
	self.player			= nil
end

-- private functions
function Bot:_updateRespwawn()
	if self._respawning and self.player.soldier == nil and self._spawnMode > 0 then
		-- wait for respawn-delay gone
		if self._spawnDelayTimer < Globals.RespawnDelay then
			self._spawnDelayTimer = self._spawnDelayTimer + StaticConfig.BotUpdateCycle
		else
			Events:DispatchLocal('Bot:RespawnBot', self.name)
		end
	end
end

function Bot:_updateAiming()
	if (not self.player.alive or self._shootPlayer == nil) then
		return
	end
	if not self._reviveActive then
		if (not self._shoot or self._shootPlayer.soldier == nil or self.activeWeapon == nil) then
			return
		end
		--interpolate player movement
		local targetMovement		= Vec3.zero
		local pitchCorrection		= 0.0
		local fullPositionTarget	=  self._shootPlayer.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self._shootPlayer, true)
		local fullPositionBot		= self.player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.player, false)
		local grenadePith			= 0.0
		local distanceToPlayer		= 0.0

		if not self.knifeMode and not self.inVehicle then
			distanceToPlayer	= fullPositionTarget:Distance(fullPositionBot)
			--calculate how long the distance is --> time to travel
			local factorForMovement = 0.0
			if self.activeWeapon.type == "Grenade" then
				if distanceToPlayer < 5 then
					distanceToPlayer = 5 -- don't throw them too close..
				end
				local angle =  math.asin((distanceToPlayer * self.activeWeapon.bulletDrop)/(self.activeWeapon.bulletSpeed*self.activeWeapon.bulletSpeed))
				if angle ~= angle then	--NAN check
					grenadePith = (math.pi / 4)
				else
					grenadePith = (math.pi / 2) - (angle / 2)
				end
			else
				local timeToTravel		= (distanceToPlayer / self.activeWeapon.bulletSpeed)
				factorForMovement	= (timeToTravel) / self._updateTimer
				pitchCorrection	= 0.5 * timeToTravel * timeToTravel * self.activeWeapon.bulletDrop
			end

			if self._lastShootPlayer == self._shootPlayer then
				targetMovement			= (fullPositionTarget - self._lastTargetTrans) * factorForMovement --movement in one dt
			end

			self._lastShootPlayer = self._shootPlayer
			self._lastTargetTrans = fullPositionTarget
		end

		--calculate yaw and pitch
		local dz		= fullPositionTarget.z + targetMovement.z - fullPositionBot.z
		local dx		= fullPositionTarget.x + targetMovement.x - fullPositionBot.x
		local dy		= fullPositionTarget.y + targetMovement.y + pitchCorrection - fullPositionBot.y
		local atanDzDx	= math.atan(dz, dx)
		local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
		-- worsen yaw depending on bot-skill
		local worseningValue = (math.random()*self._skill/distanceToPlayer) -- value scaled in offset in 1m
		yaw = yaw + worseningValue

		--calculate pitch
		local pitch = 0
		if self.activeWeapon.type == "Grenade" then
			pitch	= grenadePith
		else
			local distance	= math.sqrt(dz ^ 2 + dx ^ 2)
			pitch	= math.atan(dy, distance)
		end
		-- worsen yaw depending on bot-skill
		pitch = pitch + worseningValue

		self._targetPitch	= pitch
		self._targetYaw		= yaw
	else
		if (self._shootPlayer.corpse == nil) then
			return
		end
		local positionTarget	=  self._shootPlayer.corpse.worldTransform.trans:Clone()
		local positionBot		= self.player.soldier.worldTransform.trans:Clone() + m_Utilities:getCameraPos(self.player, false)

		local dz		= positionTarget.z - positionBot.z
		local dx		= positionTarget.x - positionBot.x
		local dy		= positionTarget.y - positionBot.y

		local atanDzDx	= math.atan(dz, dx)
		local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)

		--calculate pitch
		local distance	= math.sqrt(dz ^ 2 + dx ^ 2)
		local pitch		= math.atan(dy, distance)

		self._targetPitch	= pitch
		self._targetYaw		= yaw
	end
end

function Bot:_updateYaw()
	if self.inVehicle and self.player.attachedControllable == nil then
		self.inVehicle = false
	end
	local attackAiming = true
	if self._meleeActive then
		return
	end
	if self._targetPoint ~= nil and self._shootPlayer == nil and self.player.soldier ~= nil then
		attackAiming = false
		if self.player.soldier.worldTransform.trans:Distance(self._targetPoint.Position) < 0.2 then
			self._targetPoint = self._nextTargetPoint
		end

		local dy		= self._targetPoint.Position.z - self.player.soldier.worldTransform.trans.z
		local dx		= self._targetPoint.Position.x - self.player.soldier.worldTransform.trans.x
		local atanDzDx	= math.atan(dy, dx)
		local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
		self._targetYaw = yaw
	end

	if self.knifeMode then
		if self._shootPlayer ~= nil and self.player.soldier ~= nil then
			if #self._knifeWayPositions > 0 then
				local dy		= self._knifeWayPositions[1].z - self.player.soldier.worldTransform.trans.z
				local dx		= self._knifeWayPositions[1].x - self.player.soldier.worldTransform.trans.x
				local atanDzDx	= math.atan(dy, dx)
				local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
				self._targetYaw = yaw

				if self.player.soldier.worldTransform.trans:Distance(self._knifeWayPositions[1]) < 1.5 then
					table.remove(self._knifeWayPositions, 1)
				end
			end
		end
	end

	local deltaYaw = 0
	if self.inVehicle then
		local pos = self.player.attachedControllable.transform.forward
		--print(pos)
		local atanDzDx	= math.atan(pos.z, pos.x)
		local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
		--print(yaw)
		deltaYaw = yaw - self._targetYaw
	else
		deltaYaw = self.player.input.authoritativeAimingYaw - self._targetYaw
	end

	if deltaYaw > math.pi then
		deltaYaw = deltaYaw - 2*math.pi
	elseif deltaYaw < -math.pi then
		deltaYaw = deltaYaw + 2*math.pi
	end

	local absDeltaYaw	= math.abs(deltaYaw)
	local inkrement 	= Globals.YawPerFrame

	if absDeltaYaw < inkrement then
		if self.inVehicle then
			self.player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0.0)
		end
		self.player.input.authoritativeAimingYaw	= self._targetYaw
		self.player.input.authoritativeAimingPitch	= self._targetPitch
		return
	end

	if deltaYaw > 0  then
		inkrement = -inkrement
	end

	local tempYaw = self.player.input.authoritativeAimingYaw + inkrement

	if tempYaw >= (math.pi * 2) then
		tempYaw = tempYaw - (math.pi * 2)
	elseif tempYaw < 0.0 then
		tempYaw = tempYaw + (math.pi * 2)
	end

	if self.inVehicle then
		if inkrement > 0 then --TODO: steer in smaller values
			self.player.input:SetLevel(EntryInputActionEnum.EIAYaw, 0.8)
		else
			self.player.input:SetLevel(EntryInputActionEnum.EIAYaw, -0.8)
		end
	end
	self.player.input.authoritativeAimingYaw	= tempYaw
	self.player.input.authoritativeAimingPitch	= self._targetPitch
end

function Bot:_findOutVehicleType(p_Player)
	local type = 0 -- no vehicle
	if p_Player.attachedControllable ~= nil then
		local vehicleName = VehicleTable[VehicleEntityData(p_Player.attachedControllable.data).controllableType:gsub(".+/.+/","")]
		--print(vehicleName)
		-- Tank
		if vehicleName == "[LAV-25]" or
		vehicleName == "[SPRUT-SD]" or
		vehicleName == "[BMP-2M]" or
		vehicleName == "[M1 ABRAMS]" or
		vehicleName == "[T-90A]" or
		vehicleName == "[M1128]" or
		vehicleName == "[RHINO]"
		then
			type = 1
		end

		-- light Vehicle
		if vehicleName == "[AAV-7A1 AMTRAC]" or
		vehicleName == "[9K22 TUNGUSKA-M]" or

		vehicleName == "[GAZ-3937 VODNIK]" or
		vehicleName == "[LAV-AD]"  or
		vehicleName == "[M1114 HMMWV]" or
		vehicleName == "[HMMWV ASRAD]" or
		vehicleName == "[GUNSHIP]" or
		vehicleName == "[M142]" or
		vehicleName == "[BM-23]" or
		vehicleName == "[BARSUK]" or
		vehicleName == "[VODNIK AA]" or
		vehicleName == "[BTR-90]"
		then
			type = 2
		end

		-- Air vehicles
		if vehicleName == "[A-10 THUNDERBOLT]" or
		vehicleName == "[AH-1Z VIPER]" or
		vehicleName == "[AH-6J LITTLE BIRD]" or
		vehicleName == "[F/A-18E SUPER HORNET]" or
		vehicleName == "[KA-60 KASATKA]" or
		vehicleName == "[MI-28 HAVOC]" or
		vehicleName == "[SU-25TM FROGFOOT]" or
		vehicleName == "[SU-35BM FLANKER-E]" or
		vehicleName == "[SU-37]" or
		vehicleName == "[UH-1Y VENOM]" or
		vehicleName == "[Z-11W]" or
		vehicleName == "[F-35]"
		then
			type = 3
		end

		-- no armor at all
		if vehicleName == "[GROWLER ITV]" or
		vehicleName == "[CIVILIAN CAR]" or
		vehicleName == "[DELIVERY VAN]" or
		vehicleName == "[SUV]" or
		vehicleName == "[POLICE VAN]" or
		vehicleName == "[RHIB BOAT]" or
		vehicleName == "[TECHNICAL TRUCK]" or
		vehicleName == "[VDV Buggy]" or
		vehicleName == "[QUAD BIKE]" or
		vehicleName == "[DIRTBIKE]" or
		vehicleName == "[DPV]" or
		vehicleName == "[SKID LOADER]"
		then
			type = 4
		end
	end
	return type
end

function Bot:_ceckForVehicleAttack(p_Type, p_Distance)
	local attackMode = 0 -- no attack
	if p_Type == 4 and p_Distance < Config.MaxRaycastDistance then
		attackMode = 1 -- attack with rifle
	elseif p_Type == 3 and p_Distance < Config.MaxRaycastDistance then
		attackMode = 1 -- attack with rifle
	elseif p_Type == 2 and p_Distance < 35 then
		attackMode = 2	-- attack with grenade
	end
	if self.gadget2.type == "Rocket" then
		attackMode = 3		-- always use rocket if possible
	elseif self.gadget2.type == "C4" and p_Distance < 25 then
		if p_Type ~= 3 then -- no air vehicles
			attackMode = 4	-- always use c4 if possible
		end
	end
	return attackMode
end

function Bot:_updateShooting()
	if self.player.alive and self._shoot then
		--select weapon-slot TODO: keep button pressed or not?
		if not self._meleeActive then
			if self.player.soldier.weaponsComponent ~= nil then
				if self.knifeMode then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon7, 1)
						self.activeWeapon = self.knife
						self._shotTimer = 0
					end
				elseif self._reviveActive or (self._weaponToUse == "Gadget2" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Gadget2" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_5 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon5, 1)
						self.activeWeapon = self.gadget2
						self._shotTimer = - (Config.BotFirstShotDelay + math.random()*self._skill)
					end
				elseif (self._weaponToUse == "Gadget1" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Gadget1" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_2 and self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_4 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon4, 1)
						self:_setInput(EntryInputActionEnum.EIASelectWeapon3, 1)
						self.activeWeapon = self.gadget1
						self._shotTimer = - (Config.BotFirstShotDelay + math.random()*self._skill)
					end
				elseif self._grenadeActive or (self._weaponToUse == "Grenade" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Grenade" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_6 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon6, 1)
						self.activeWeapon = self.grenade
						self._shotTimer = - (Config.BotFirstShotDelay + math.random()*self._skill)
					end
				elseif (self._weaponToUse == "Pistol" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Pistol" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_1 then
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 1)
						self:_setInput(EntryInputActionEnum.EIASelectWeapon2, 1)
						self.activeWeapon = self.pistol
						self._shotTimer = - (Config.BotFirstShotDelay + math.random()*self._skill)/2 -- TODO: maybe a little less or more?
					end
				elseif (self._weaponToUse == "Primary" and Config.BotWeapon == "Auto") or Config.BotWeapon == "Primary" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
						self:_setInput(EntryInputActionEnum.EIASelectWeapon1, 1)
						self.activeWeapon = self.primary
						self._shotTimer = 0
					end
				end
			end
		end

		if self._shootPlayer ~= nil and self._shootPlayer.soldier ~= nil then
			if self._shootModeTimer < Config.BotFireModeDuration or (Config.ZombieMode and self._shootModeTimer < (Config.BotFireModeDuration * 4)) then
				local currentDistance = self._shootPlayer.soldier.worldTransform.trans:Distance(self.player.soldier.worldTransform.trans)
				if not self._c4Active then
					self:_setInput(EntryInputActionEnum.EIAZoom, 1)
				end
				if not self._grenadeActive then
					self._shootModeTimer	= self._shootModeTimer + StaticConfig.BotUpdateCycle
				end
				self.activeMoveMode		= 9 -- movement-mode : attack
				if self._c4Active then
					self.activeMoveMode		= 8 -- movement-mode : C4 / revive
				end
				self._reloadTimer		= 0 -- reset reloading

				--check for melee attack
				if Config.MeleeAttackIfClose and not self._meleeActive and self._meleeCooldownTimer <= 0 and self._shootPlayer.soldier.worldTransform.trans:Distance(self.player.soldier.worldTransform.trans) < 2 then
					self._meleeActive = true
					self.activeWeapon = self.knife

					self:_setInput(EntryInputActionEnum.EIASelectWeapon7, 1)
					self:_setInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
					self:_setInput(EntryInputActionEnum.EIAMeleeAttack, 1)
					self._meleeCooldownTimer = Config.MeleeAttackCoolDown

					if not USE_REAL_DAMAGE then
						Events:DispatchLocal("ServerDamagePlayer", self._shootPlayer.name, self.player.name, true)
					end
				else
					if self._meleeCooldownTimer < 0 then
						self._meleeCooldownTimer = 0
					elseif self._meleeCooldownTimer > 0 then
						self._meleeCooldownTimer = self._meleeCooldownTimer - StaticConfig.BotUpdateCycle
						if self._meleeCooldownTimer < (Config.MeleeAttackCoolDown - 0.8) then
							self._meleeActive = false
						end
					end
				end

				if self._grenadeActive then -- throw grenade
					if self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 0 then
						self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 1
						self._grenadeActive = false
						self._shootModeTimer = Config.BotFireModeDuration
					end
				end

				-- target in vehicle - use gadget 2 if rocket --TODO: don't shoot with other classes
				local type = self:_findOutVehicleType(self._shootPlayer)
				if type ~= 0 then
					local attackMode = self:_ceckForVehicleAttack(type, currentDistance)
					if attackMode > 0 then
						if attackMode == 2 then -- grenade
							self._grenadeActive = true
						elseif attackMode == 3 then -- rocket
							self._weaponToUse = "Gadget2"
							if self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo <= 2 then
								self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo + 3
							end
						elseif attackMode == 4 then -- C4
							self._weaponToUse = "Gadget2"
							self._c4Active = true
						elseif attackMode == 1 then
							-- TODO: doble code is not nice
							if not self._grenadeActive and self.player.soldier.weaponsComponent.weapons[1] ~= nil then
								if self.player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 then
									self._weaponToUse = "Pistol"
								else
									self._weaponToUse = "Primary"
								end
							end
						end
					else
						self._shootModeTimer = Config.BotFireModeDuration -- end attack
					end
				else
					if self.knifeMode or self._meleeActive then
						self._weaponToUse = "Knife"
					else
						if not self._grenadeActive and self.player.soldier.weaponsComponent.weapons[1] ~= nil then
							if self.player.soldier.weaponsComponent.weapons[1].primaryAmmo == 0 and currentDistance <= Config.MaxShootDistancePistol then
								self._weaponToUse = "Pistol"
							else
								self._weaponToUse = "Primary"
							end
						end
						-- use grenade from time to time
						if Config.BotsThrowGrenades then
							local targetTimeValue = Config.BotFireModeDuration - 0.5
							if ((self._shootModeTimer >= targetTimeValue) and (self._shootModeTimer < (targetTimeValue + StaticConfig.BotUpdateCycle)) and not self._grenadeActive) or Config.BotWeapon == "Grenade" then
								-- should be triggered only once per fireMode
								if MathUtils:GetRandomInt(1,100) <= 30 then
									if self.grenade ~= nil and currentDistance < 35 then
										self._grenadeActive = true
									end
								end
							end
						end
					end
				end

				--trace way back
				if (self.activeWeapon ~= nil and self.activeWeapon.type ~= "Sniper" and not self.inVehicle) or self.knifeMode then
					if self._shootTraceTimer > StaticConfig.TraceDeltaShooting then
						--create a Trace to find way back
						self._shootTraceTimer 	= 0
						local point				= {
							Position = self.player.soldier.worldTransform.trans:Clone(),
							SpeedMode = 4,			-- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
							ExtraMode = 0,
							OptValue = 0,
						}

						table.insert(self._shootWayPoints, point)
						if self.knifeMode then
							local trans = self._shootPlayer.soldier.worldTransform.trans:Clone()
							table.insert(self._knifeWayPositions, trans)
						end
					end
					self._shootTraceTimer = self._shootTraceTimer + StaticConfig.BotUpdateCycle
				end

				--shooting sequence
				if self.activeWeapon ~= nil then
					if self.knifeMode then
						-- nothing to do
					elseif self._c4Active then
						if self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo > 0 then
							if self._shotTimer >= (self.activeWeapon.fireCycle + self.activeWeapon.pauseCycle) then
								self._shotTimer	= 0
							end

							if currentDistance < 5 then
								if self._shotTimer >= self.activeWeapon.pauseCycle then
									self:_setInput(EntryInputActionEnum.EIAZoom, 1)
								end
							end

						else
							if self._shotTimer >= (self.activeWeapon.fireCycle + self.activeWeapon.pauseCycle) then
								--TODO: run away from object now
								if self._shotTimer >= ((self.activeWeapon.fireCycle * 2) + self.activeWeapon.pauseCycle) then
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
									self.player.soldier.weaponsComponent.currentWeapon.secondaryAmmo = 4
									self._c4Active = false
								end
							else
						end
						end
					else
						if self._shotTimer >= (self.activeWeapon.fireCycle + self.activeWeapon.pauseCycle) then
							self._shotTimer	= 0
						end
						if self._shotTimer >= 0 then
							if self.activeWeapon.delayed == false then
								if self._shotTimer <= self.activeWeapon.fireCycle and not self._meleeActive then
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
								end
							else --start with pause Cycle
								if self._shotTimer >= self.activeWeapon.pauseCycle and not self._meleeActive then
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
								end
							end
						end
					end

					self._shotTimer = self._shotTimer + StaticConfig.BotUpdateCycle
				end

			else
				self._targetPitch 		= 0.0
				self._weaponToUse 		= "Primary"
				self._shootPlayerName	= ""
				self._shootPlayer		= nil
				self._grenadeActive 	= false
				self._c4Active 			= false
				self._lastShootPlayer	= nil
			end
		elseif self._reviveActive and self._shootPlayer ~= nil then
			if self._shootPlayer.corpse ~= nil then  -- revive
				self._shootModeTimer	= self._shootModeTimer + StaticConfig.BotUpdateCycle
				self.activeMoveMode		= 8 -- movement-mode : revive
				self._reloadTimer		= 0 -- reset reloading

				--check for revive if close
				if self._shootPlayer.corpse.worldTransform.trans:Distance(self.player.soldier.worldTransform.trans) < 3 then
					self:_setInput(EntryInputActionEnum.EIAFire, 1)
				end

				--trace way back
				if self._shootTraceTimer > StaticConfig.TraceDeltaShooting then
					--create a Trace to find way back
					self._shootTraceTimer 	= 0
					local point				= {
						Position = self.player.soldier.worldTransform.trans:Clone(),
						SpeedMode = 4,			-- 0 = wait, 1 = prone, 2 = crouch, 3 = walk, 4 run
						ExtraMode = 0,
						OptValue = 0,
					}

					table.insert(self._shootWayPoints, point)
					if self.knifeMode then
						local trans = self._shootPlayer.soldier.worldTransform.trans:Clone()
						table.insert(self._knifeWayPositions, trans)
					end
				end
				self._shootTraceTimer = self._shootTraceTimer + StaticConfig.BotUpdateCycle
			else
				self._weaponToUse 		= "Primary"
				self._shootPlayer		= nil
				self._reviveActive		= false
			end
		else
			self._weaponToUse 		= "Primary"
			self._grenadeActive 	= false
			self._c4Active 			= false
			self._shootPlayer		= nil
			self._lastShootPlayer	= nil
			self._reviveActive		= false
			self._shootModeTimer	= 0
			self._attackMode		= 0

			self._reloadTimer = self._reloadTimer + StaticConfig.BotUpdateCycle
			if self._reloadTimer > 1.5 and self._reloadTimer < 2.5 and self.player.soldier.weaponsComponent.currentWeapon.primaryAmmo <= self.activeWeapon.reload then
				self:_setInput(EntryInputActionEnum.EIAReload, 1)
			end

			-- deploy from time to time
			if Config.BotsDeploy then
				if self.kit == "Support" or self.kit == "Assault" then
					if self.gadget1.type == "Ammobag" or self.gadget1.type == "Medkit" then
						self._deployTimer = self._deployTimer + StaticConfig.BotUpdateCycle
						if self._deployTimer > Config.DeployCycle then
							self._deployTimer = 0
						end
						if self._deployTimer < 0.7 then
							self._weaponToUse = "Gadget1"
						end
					end
				end
			end
		end
	end
end

function Bot:_getWayIndex(p_CurrentWayPoint)
	local activePointIndex = 1

	if p_CurrentWayPoint == nil then
		p_CurrentWayPoint = activePointIndex
	else
		activePointIndex = p_CurrentWayPoint

		-- direction handling
		local countOfPoints = #m_NodeCollection:Get(nil, self._pathIndex)
		local firstPoint =  m_NodeCollection:GetFirst(self._pathIndex)
		if activePointIndex > countOfPoints then
			if firstPoint.OptValue == 0xFF then --inversion needed
				activePointIndex			= countOfPoints
				self._invertPathDirection	= true
			else
				activePointIndex			= 1
			end
		elseif activePointIndex < 1 then
			if firstPoint.OptValue == 0xFF then --inversion needed
				activePointIndex			= 1
				self._invertPathDirection	= false
			else
				activePointIndex			= countOfPoints
			end
		end
	end
	return activePointIndex
end

function Bot:_updateMovement()
	-- movement-mode of bots
	local additionalMovementPossible = true

	if self.player.alive then
		-- pointing
		if self.activeMoveMode == 2 and self._targetPlayer ~= nil then
			if self._targetPlayer.soldier ~= nil then
				local dy		= self._targetPlayer.soldier.worldTransform.trans.z - self.player.soldier.worldTransform.trans.z
				local dx		= self._targetPlayer.soldier.worldTransform.trans.x - self.player.soldier.worldTransform.trans.x
				local atanDzDx	= math.atan(dy, dx)
				local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
				self._targetYaw = yaw
			end

		-- mimicking
		elseif self.activeMoveMode == 3 and self._targetPlayer ~= nil then
			additionalMovementPossible = false

			for i = 0, 36 do
				self:_setInput(i, self._targetPlayer.input:GetLevel(i))
			end

			self._targetYaw		= self._targetPlayer.input.authoritativeAimingYaw
			self._targetPitch	= self._targetPlayer.input.authoritativeAimingPitch

		-- mirroring
		elseif self.activeMoveMode == 4 and self._targetPlayer ~= nil then
			additionalMovementPossible = false

			for i = 0, 36 do
				self:_setInput(i, self._targetPlayer.input:GetLevel(i))
			end

			self._targetYaw		= self._targetPlayer.input.authoritativeAimingYaw + ((self._targetPlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
			self._targetPitch	= self._targetPlayer.input.authoritativeAimingPitch

		-- move along points
		elseif self.activeMoveMode == 5 then
			self._attackModeMoveTimer = 0

			if m_NodeCollection:Get(1, self._pathIndex) ~= nil then -- check for valid point
				-- get next point
				local activePointIndex = self:_getWayIndex(self._currentWayPoint)

				local point				= nil
				local nextPoint			= nil
				local pointIncrement	= 1
				local noStuckReset		= false
				local useShootWayPoint	= false

				if #self._shootWayPoints > 0 then	--we need to go back to path first
					point 				= self._shootWayPoints[#self._shootWayPoints]
					nextPoint 			= self._shootWayPoints[#self._shootWayPoints - 1]
					if nextPoint == nil then
						nextPoint = m_NodeCollection:Get(activePointIndex, self._pathIndex)
						if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._pathIndex, activePointIndex, self.player.soldier.worldTransform.trans, (self._obstaceSequenceTimer > 0), "Blue")
						end
					end
					useShootWayPoint	= true
				else
					point = m_NodeCollection:Get(activePointIndex, self._pathIndex)
					if not self._invertPathDirection then
						nextPoint 		= m_NodeCollection:Get(self:_getWayIndex(self._currentWayPoint + 1), self._pathIndex)
						if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._pathIndex, self:_getWayIndex(self._currentWayPoint + 1), self.player.soldier.worldTransform.trans, (self._obstaceSequenceTimer > 0), "Green")
						end
					else
						nextPoint 		= m_NodeCollection:Get(self:_getWayIndex(self._currentWayPoint - 1), self._pathIndex)
						if Config.DebugTracePaths then
							NetEvents:BroadcastLocal('ClientNodeEditor:BotSelect', self._pathIndex, self:_getWayIndex(self._currentWayPoint - 1), self.player.soldier.worldTransform.trans, (self._obstaceSequenceTimer > 0), "Green")
						end
					end
				end

				-- execute Action if needed
				if self._actionActive then
					if point.Data ~= nil and point.Data.Action ~= nil then
						if point.Data.Action.type == "vehicle" then
							local iterator = EntityManager:GetIterator("ServerVehicleEntity")
							local vehicleEntity = iterator:Next()

							while vehicleEntity ~= nil do
								local tempEntity = ControllableEntity(vehicleEntity)
								local position = tempEntity.transform.trans
								if position:Distance(self.player.soldier.worldTransform.trans) < 5 then
									print(tempEntity.entryCount)
									for i = 0, tempEntity.entryCount - 1 do
										if tempEntity:GetPlayerInEntry(i) == nil then
											self.player:EnterVehicle(vehicleEntity, 0)
											self._actionActive = false
											break
										end
									end
									break
								end
								vehicleEntity = iterator:Next()
							end
							self._actionActive = false

						elseif self._actionTimer <= point.Data.Action.time then
							for _,input in pairs(point.Data.Action.inputs) do
								self:_setInput(input, 1)
							end
						end
					else
						self._actionActive = false
					end

					self._actionTimer = self._actionTimer - StaticConfig.BotUpdateCycle
					if self._actionTimer <= 0 then
						self._actionActive = false
					end

					if self._actionActive then
						return --DONT EXECUTE ANYTHING ELSE
					else
						point = nextPoint
					end
				end

				if (point.SpeedMode) > 0 then -- movement
					self._wayWaitTimer			= 0
					self._wayWaitYawTimer		= 0
					self.activeSpeedValue		= point.SpeedMode --speed
					if Config.ZombieMode then
						if self._zombieSpeedValue == 0 then
							self._zombieSpeedValue = MathUtils:GetRandomInt(1,2)
						end
						self.activeSpeedValue = self._zombieSpeedValue
					end
					if Config.OverWriteBotSpeedMode > 0 then
						self.activeSpeedValue = Config.OverWriteBotSpeedMode
					end
					local dy					= point.Position.z - self.player.soldier.worldTransform.trans.z
					local dx					= point.Position.x - self.player.soldier.worldTransform.trans.x
					local distanceFromTarget	= math.sqrt(dx ^ 2 + dy ^ 2)
					local heightDistance		= math.abs(point.Position.y - self.player.soldier.worldTransform.trans.y)


					--detect obstacle and move over or around TODO: Move before normal jump
					local currentWayPontDistance = self.player.soldier.worldTransform.trans:Distance(point.Position)
					if currentWayPontDistance > self._lastWayDistance + 0.02 and self._obstaceSequenceTimer == 0 then
						--TODO: skip one pooint?
						distanceFromTarget			= 0
						heightDistance				= 0
					end

					self._targetPoint = point
					self._nextTargetPoint = nextPoint


					if (math.abs(currentWayPontDistance - self._lastWayDistance) < 0.02 or self._obstaceSequenceTimer ~= 0) then
						-- try to get around obstacle
						self.activeSpeedValue = 4 --always try to stand
						if self.inVehicle then
							if self._obstacleRetryCounter == 0 then
								self.activeSpeedValue = -1
							else
								self.activeSpeedValue = 1
							end
						end

						if self._obstaceSequenceTimer == 0 then --step 0

						elseif self._obstaceSequenceTimer > 2.4 then --step 4 - repeat afterwards
							self._obstaceSequenceTimer = 0
							self._meleeActive = false
							self._obstacleRetryCounter = self._obstacleRetryCounter + 1

						elseif self._obstaceSequenceTimer > 1.0 then --step 3
							if not self.inVehicle then
								if self._obstacleRetryCounter == 0 then
									self._meleeActive = true
									self:_setInput(EntryInputActionEnum.EIASelectWeapon7, 1)
									self:_setInput(EntryInputActionEnum.EIAQuicktimeFastMelee, 1)
									self:_setInput(EntryInputActionEnum.EIAMeleeAttack, 1)
								else
									self:_setInput(EntryInputActionEnum.EIAFire, 1)
								end
							end

						elseif self._obstaceSequenceTimer > 0.4 then --step 2
							self._targetPitch		= 0.0
							if (MathUtils:GetRandomInt(0,1) == 1) then
								self:_setInput(EntryInputActionEnum.EIAStrafe, 1.0 * Config.SpeedFactor)
							else
								self:_setInput(EntryInputActionEnum.EIAStrafe, -1.0 * Config.SpeedFactor)
							end

						elseif self._obstaceSequenceTimer > 0.0 then --step 1
							self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
							self:_setInput(EntryInputActionEnum.EIAJump, 1)
						end

						self._obstaceSequenceTimer = self._obstaceSequenceTimer + StaticConfig.BotUpdateCycle
						self._stuckTimer = self._stuckTimer + StaticConfig.BotUpdateCycle

						if self._obstacleRetryCounter >= 2 then --try next waypoint
							self._obstacleRetryCounter	= 0
							self._meleeActive 			= false
							distanceFromTarget			= 0
							heightDistance				= 0
							noStuckReset				= true
							pointIncrement				= MathUtils:GetRandomInt(-3,7) -- go 5 points further
							--if Globals.IsConquest or Globals.IsRush then  --TODO: only invert path, if its not a connecting path
							--	self._invertPathDirection	= (MathUtils:GetRandomInt(0,100) < 40)
							--end
							-- experimental
							if pointIncrement == 0 then -- we can't have this
								pointIncrement = 2 --go backwards and try again
							end
						end

						if self._stuckTimer > 15 and not self.inVehicle then -- don't kill bots in vehicles
							self.player.soldier:Kill()

							if Debug.Server.BOT then
								print(self.player.name.." got stuck. Kill")
							end

							return
						end
					else
						self._meleeActive = false
					end

					self._lastWayDistance = currentWayPontDistance

					-- jump detection. Much more simple now, but works fine -)
					if self._obstaceSequenceTimer == 0 then
						if (point.Position.y - self.player.soldier.worldTransform.trans.y) > 0.3 and Config.JumpWhileMoving then
							--detect, if a jump was recorded or not
							local timeForwardBackwardJumpDetection = 1.1 -- 1.5 s ahead and back
							local jumpValid = false
							for i = 1, math.floor(timeForwardBackwardJumpDetection/Config.TraceDelta) do
								local pointBefore = m_NodeCollection:Get(activePointIndex - i, self._pathIndex)
								local pointAfter = m_NodeCollection:Get(activePointIndex + i, self._pathIndex)
								if (pointBefore ~= nil and pointBefore.ExtraMode == 1) or (pointAfter ~= nil and pointAfter.ExtraMode == 1) then
									jumpValid = true
									break
								end
							end
							if jumpValid then
								self:_setInput(EntryInputActionEnum.EIAJump, 1)
								self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
							end
						end
					end

					local targetDistanceSpeed = Config.TargetDistanceWayPoint
					if self.inVehicle  then
						targetDistanceSpeed = targetDistanceSpeed * 6
					elseif self.activeSpeedValue == 4 then
						targetDistanceSpeed = targetDistanceSpeed * 1.5
					elseif self.activeSpeedValue == 2 then
						targetDistanceSpeed = targetDistanceSpeed * 0.7
					elseif self.activeSpeedValue == 1 then
						targetDistanceSpeed = targetDistanceSpeed * 0.5
					end

					--check for reached target
					if (distanceFromTarget <= targetDistanceSpeed and heightDistance <= StaticConfig.TargetHeightDistanceWayPoint) then
						if not noStuckReset then
							self._stuckTimer = 0
						end
						if not useShootWayPoint then
							-- CHECK FOR ACTION
							if point.Data.Action ~= nil then
								local action = point.Data.Action
								if g_GameDirector:checkForExecution(point, self.player.teamId) then
									self._actionActive = true
									if action.time ~= nil then
										self._actionTimer = action.time
									else
										self._actionTimer = 0
									end
									if action.yaw ~= nil then
										self._targetYaw = action.yaw
									end
									if action.pitch ~= nil then
										self._targetPitch = action.pitch
									end
									return --DONT DO ANYTHING ELSE ANYMORE
								end
							end
							-- CHECK FOR PATH-SWITCHES
							local newWaypoint = nil
							local switchPath = false
							switchPath, newWaypoint = m_PathSwitcher:getNewPath(self.name, point, self._objective)
							if not self.player.alive then
								return
							end

							if switchPath == true and not self._onSwitch then
								if (self._objective ~= '') then
									-- 'best' direction for objective on switch
									local direction = m_NodeCollection:ObjectiveDirection(newWaypoint, self._objective)
									self._invertPathDirection = (direction == 'Previous')
								else
									-- random path direction on switch
									self._invertPathDirection = MathUtils:GetRandomInt(1,2) == 1
								end

								self._pathIndex = newWaypoint.PathIndex
								self._currentWayPoint = newWaypoint.PointIndex
								self._onSwitch = true
							else
								self._onSwitch = false
								if self._invertPathDirection then
									self._currentWayPoint = activePointIndex - pointIncrement
								else
									self._currentWayPoint = activePointIndex + pointIncrement
								end
							end

						else
							for i = 1, pointIncrement do --one already gets removed on start of wayfinding
								table.remove(self._shootWayPoints)
							end
						end
						self._obstaceSequenceTimer	= 0
						self._meleeActive = false
						self._lastWayDistance		= 1000
					end
				else -- wait mode
					self._wayWaitTimer		= self._wayWaitTimer + StaticConfig.BotUpdateCycle
					local lastYawTimer 		= self._wayWaitYawTimer
					self._wayWaitYawTimer 	= self._wayWaitYawTimer + StaticConfig.BotUpdateCycle
					self.activeSpeedValue	= 0
					self._targetPoint		= nil

					-- move around a little
					if self._wayWaitYawTimer > 6 then
						self._wayWaitYawTimer = 0
						self._targetYaw = self._targetYaw + 1.0 -- 60 ° rotation right
						if self._targetYaw > (math.pi * 2) then
							self._targetYaw = self._targetYaw - (2 * math.pi)
						end
					elseif self._wayWaitYawTimer >= 4 and lastYawTimer < 4 then
						self._targetYaw = self._targetYaw - 1.0 -- 60 ° rotation left
						if self._targetYaw < 0 then
							self._targetYaw = self._targetYaw + (2 * math.pi)
						end
					elseif self._wayWaitYawTimer >= 3 and lastYawTimer < 3 then
						self._targetYaw = self._targetYaw - 1.0 -- 60 ° rotation left
						if self._targetYaw < 0 then
							self._targetYaw = self._targetYaw + (2 * math.pi)
						end
					elseif self._wayWaitYawTimer >= 1 and lastYawTimer < 1 then
						self._targetYaw = self._targetYaw + 1.0 -- 60 ° rotation right
						if self._targetYaw > (math.pi * 2) then
							self._targetYaw = self._targetYaw - (2 * math.pi)
						end
					end

					if self._wayWaitTimer > point.OptValue then
						self._wayWaitTimer		= 0
						if self._invertPathDirection then
							self._currentWayPoint	= activePointIndex - 1
						else
							self._currentWayPoint	= activePointIndex + 1
						end
					end
				end
			--else -- no point: do nothing
			end

		-- Shoot MoveMode
		elseif self.activeMoveMode == 9 then
			if self._attackMode == 0 then
				if Config.BotAttackMode == "Crouch" then
					self._attackMode = 2
				elseif Config.BotAttackMode == "Stand" then
					self._attackMode = 3
				else -- random
					self._attackMode = MathUtils:GetRandomInt(2, 3)
				end
			end
			--crouch moving (only mode with modified gun)
			if (self.activeWeapon.type == "Sniper" and not self.knifeMode) or self.inVehicle then --don't move while shooting in a vehicle
				if self._attackMode == 2 then
					if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
						self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
					end
				else
					if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
						self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
					end
				end
				self.activeSpeedValue = 0
			else
				local targetTime = 5.0
				local targetCycles = math.floor(targetTime / StaticConfig.TraceDeltaShooting)

				if self.knifeMode then --Knife Only Mode
					targetCycles = 1
					self.activeSpeedValue = 4 --run towards player
				else
					if self._attackMode == 2 then
						self.activeSpeedValue = 2
					else
						self.activeSpeedValue = 3
					end
				end
				if Config.OverWriteBotAttackMode > 0 then
					self.activeSpeedValue = Config.OverWriteBotAttackMode
				end

				if #self._shootWayPoints > targetCycles and Config.JumpWhileShooting then
					local distanceDone = self._shootWayPoints[#self._shootWayPoints].Position:Distance(self._shootWayPoints[#self._shootWayPoints-targetCycles].Position)
					if distanceDone < 0.5 then --no movement was possible. Try to jump over obstacle
						self.activeSpeedValue = 3
						self:_setInput(EntryInputActionEnum.EIAJump, 1)
						self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
					end
				end

				-- do some sidwards movement from time to time
				if self._attackModeMoveTimer > 20 then
					self._attackModeMoveTimer = 0
				elseif self._attackModeMoveTimer > 17 then
					self:_setInput(EntryInputActionEnum.EIAStrafe, -0.5 * Config.SpeedFactorAttack)
				elseif self._attackModeMoveTimer > 12 and self._attackModeMoveTimer <= 13 then
					self:_setInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
				elseif self._attackModeMoveTimer > 7 and self._attackModeMoveTimer <= 9 then
					self:_setInput(EntryInputActionEnum.EIAStrafe, 0.5 * Config.SpeedFactorAttack)
				end

				self._attackModeMoveTimer = self._attackModeMoveTimer + StaticConfig.BotUpdateCycle
			end

		elseif self.activeMoveMode == 8 then  -- Revive Move Mode / C4 Mode
			self.activeSpeedValue = 4 --run to player
			if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
				self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
			end
			local jump = true
			if self._shootPlayer ~= nil and self._shootPlayer.corpse ~= nil then
				if self.player.soldier.worldTransform.trans:Distance(self._shootPlayer.corpse.worldTransform.trans) < 1 then
					self.activeSpeedValue = 0
					jump = false
				end
			end

			--TODO: obstacle detection
			if jump == true then
				self._attackModeMoveTimer = self._attackModeMoveTimer + StaticConfig.BotUpdateCycle
				if self._attackModeMoveTimer > 3 then
					self._attackModeMoveTimer = 0
				elseif self._attackModeMoveTimer > 2.5 then
					self:_setInput(EntryInputActionEnum.EIAJump, 1)
					self:_setInput(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
				end
			end
		end

		-- additional movement
		if additionalMovementPossible then
			local speedVal = 0

			if self.inVehicle then
				if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
					self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				end
				if self.activeMoveMode > 0 then
					if self.activeSpeedValue == 1 then
						speedVal = 0.5
					elseif self.activeSpeedValue == 2 then
						speedVal = 0.75
					elseif self.activeSpeedValue >= 3 then
						speedVal = 1.0
					elseif self.activeSpeedValue < 0 then
						speedVal = -1.0
					end
				end
			else
				if self.activeMoveMode > 0 then
					if self.activeSpeedValue == 1 then
						speedVal = 1.0

						if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
							self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true)
						end

					elseif self.activeSpeedValue == 2 then
						speedVal = 1.0

						if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
							self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true)
						end

					elseif self.activeSpeedValue >= 3 then
						speedVal = 1.0

						if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
							self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
						end
					end
				end
			end

			-- do not reduce speed if sprinting
			if speedVal > 0 and self._shootPlayer ~= nil and self._shootPlayer.soldier ~= nil and self.activeSpeedValue <= 3 then
				speedVal = speedVal * Config.SpeedFactorAttack

			end

			-- movent speed
			if self.player.alive then
				if self.activeSpeedValue <= 3 then
					if self.inVehicle then
						if self.activeSpeedValue < 0 then
							self:_setInput(EntryInputActionEnum.EIABrake, speedVal)
						else
							self:_setInput(EntryInputActionEnum.EIAThrottle, speedVal)
						end
					else
						self:_setInput(EntryInputActionEnum.EIAThrottle, speedVal * Config.SpeedFactor)
					end

				else
					self:_setInput(EntryInputActionEnum.EIAThrottle, 1)
					self:_setInput(EntryInputActionEnum.EIASprint, speedVal * Config.SpeedFactor)
				end
			end
		end
	end
end

function Bot:_setActiveVars()
	if self._shootPlayerName ~= "" then
		self._shootPlayer = PlayerManager:GetPlayerByName(self._shootPlayerName)
	else
		self._shootPlayer = nil
		self._lastShootPlayer = nil
	end

	self.activeMoveMode		= self._moveMode
	self.activeSpeedValue	= self._botSpeed
	if self.player.attachedControllable ~= nil then
		self.inVehicle = true
	else
		self.inVehicle = false
	end

	if Config.BotWeapon == "Knife" or Config.ZombieMode then
		self.knifeMode = true
	else
		self.knifeMode = false
	end
end

function Bot:_getCameraHight(p_Soldier, p_IsTarget)
	local cameraHeight = 0

	if not p_IsTarget then
		cameraHeight = 1.6 --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand

		if p_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			cameraHeight = 0.3
		elseif p_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			cameraHeight = 1.0
		end
	else
		cameraHeight = 1.3 --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand - reduce by 0.3

		if p_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			cameraHeight = 0.3 -- don't reduce
		elseif p_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			cameraHeight = 0.8 -- reduce by 0.2
		end
	end

	return cameraHeight
end

return Bot
