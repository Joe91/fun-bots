class('Bot');

require('__shared/Config');
require('Waypoint');

local Globals = require('Globals');
local Utilities = require('__shared/Utilities')

function Bot:__init(player)
	--Player Object
	self.player = player;
	self.name = player.name;
	self.id = player.id;

	--common settings
	self._spawnMode = 0;
	self._moveMode = 0;
	self.kit = "";
	self.color = "";
	self.activeWeapon = nil;
	self.primary = nil;
	self.pistol = nil;
	self.knife = nil;
	self.inEnemyTeam = false;
	self._checkSwapTeam = false;
	self._respawning = false;

	--timers
	self._updateTimer = 0;
	self._aimUpdateTimer = 0;
	self._spawnDelayTimer = 0;
	self._wayWaitTimer = 0;
	self._wayWaitYawTimer = 0;
	self._obstaceSequenceTimer = 0;
	self._shotTimer = -Config.botFirstShotDelay;
	self._shootModeTimer = 0;
	self._reloadTimer = 0;
	self._attackModeMoveTimer = 0;
	self._meleeCooldownTimer = 0;
	self._shootTraceTimer = 0;

	--shared movement vars
	self.activeMoveMode = 0;
	self.activeSpeedValue = 0;

	--advanced movement
	self._currentWayPoint = nil;
	self._targetYaw = 0;
	self._targetPitch = 0;
	self._targetPoint = nil;
	self._pathIndex = 0;
	self._meleeActive = false;
	self._lastWayDistance = 0;
	self._invertPathDirection = false;
	self._obstacleRetryCounter = 0;

	--shooting
	self._shoot = false;
	self._shootPlayer = nil;
	self._shootWayPoints = {};
	self._lastTargetTrans = Vec3();
	self._lastShootPlayer = nil;

	--simple movement
	self._botSpeed = 0;
	self._targetPlayer = nil;
	self._spawnTransform = LinearTransform();
end

function Bot:onUpdate(dt)
	if self.player.soldier ~= nil then
		self.player.soldier:SingleStepEntry(self.player.controlledEntryId);
	end

	self._updateTimer		= self._updateTimer + dt;
	self._aimUpdateTimer	= self._aimUpdateTimer + dt;

	if self._aimUpdateTimer > StaticConfig.botAimUpdateCycle then
		self:_updateAiming();
		self._aimUpdateTimer = 0; --reset afterwards, to use it for targetinterpolation
	end

	self:_updateYaw();

	if self._updateTimer > StaticConfig.botUpdateCycle then
		self._updateTimer = 0;

		self:_setActiveVars();
		self:_updateRespwawn();
		self:_updateShooting();
		self:_updateMovement(); --TODO: move-mode shoot
	end
end


--public functions
function Bot:shootAt(player, ignoreYaw)
	-- don't shoot at teammates
	if self.player.teamId == player.teamId then
		return
	end

	if player.soldier == nil or self.player.soldier == nil then
		return
	end

	-- don't shoot if too far away
	if not ignoreYaw then
		local distance = player.soldier.worldTransform.trans:Distance(self.player.soldier.worldTransform.trans)
		if self.activeWeapon.type ~= "Sniper" and distance > Config.maxShootDistanceNoSniper then
			return
		end
	end

	local dYaw		= 0;
	local fovHalf	= 0;

	if not ignoreYaw then
		local oldYaw	= self.player.input.authoritativeAimingYaw;
		local dy		= player.soldier.worldTransform.trans.z - self.player.soldier.worldTransform.trans.z;
		local dx		= player.soldier.worldTransform.trans.x - self.player.soldier.worldTransform.trans.x;
		local yaw		= (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2);

		dYaw			= math.abs(oldYaw-yaw);

		if dYaw > math.pi then
			dYaw =math.pi * 2 - dYaw;
		end

		fovHalf = Config.fovForShooting / 360 * math.pi;
	end

	if dYaw < fovHalf or ignoreYaw then
		if self._shoot then
			if self._shootPlayer == nil or self._shootModeTimer > Config.botMinTimeShootAtPlayer then
				self._shootModeTimer	= 0;
				self._shootPlayer		= player;
				self._lastShootPlayer 	= player;
				self._lastTargetTrans 	= player.soldier.worldTransform.trans:Clone();
			end
		else
			self._shootModeTimer = Config.botFireModeDuration;
		end
	end
end

function Bot:setVarsDefault()
	self._spawnMode		= 5;
	self._moveMode		= 5;
	self._botSpeed		= 3;
	self._pathIndex		= 1;
	self._respawning	= Globals.respawnWayBots;
	self._shoot			= Globals.attackWayBots;
end

function Bot:resetVars()
	self._spawnMode				= 0;
	self._moveMode				= 0;
	self._pathIndex				= 0;
	self._respawning			= false;
	self._shoot					= false;
	self._targetPlayer			= nil;
	self._shootPlayer			= nil;
	self._lastShootPlayer		= nil;
	self._invertPathDirection	= false;
	self._shotTimer				= -Config.botFirstShotDelay;
	self._updateTimer			= 0;
	self._aimUpdateTimer		= 0; --timer sync
	self._targetPoint			= nil;
	self._meleeActive 			= false;

	self.player.input:SetLevel(EntryInputActionEnum.EIAZoom, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeFastMelee, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIASprint, 0);
end

function Bot:setVarsStatic(player)
	self._spawnMode		= 0;
	self._moveMode		= 0;
	self._pathIndex		= 0;
	self._respawning	= false;
	self._shoot			= false;
	self._targetPlayer	= player;
end

function Bot:setVarsSimpleMovement(player, spawnMode, transform)
	self._spawnMode		= spawnMode;
	self._moveMode		= 2;
	self._botSpeed		= 3;
	self._pathIndex		= 0;
	self._respawning	= false;
	self._shoot			= false;
	self._targetPlayer	= player;

	if transform ~= nil then
		self._spawnTransform = transform;
	end
end

function Bot:setVarsWay(player, useRandomWay, pathIndex, currentWayPoint, inverseDirection)
	if useRandomWay then
		self._spawnMode		= 5;
		self._targetPlayer	= nil;
		self._shoot			= Globals.attackWayBots;
		self._respawning	= Globals.respawnWayBots;
	else
		self._spawnMode		= 4;
		self._targetPlayer	= player;
		self._shoot			= false;
		self._respawning	= false;
	end

	self._botSpeed				= 3;
	self._moveMode				= 5;
	self._pathIndex				= pathIndex;
	self._currentWayPoint		= currentWayPoint;
	self._invertPathDirection	= inverseDirection;
end

function Bot:isStaticMovement()
	if self._moveMode == 0 or self._moveMode == 3 or self._moveMode == 4 then
		return true;
	else
		return false;
	end
end

function Bot:setMoveMode(moveMode)
	self._moveMode = moveMode;
end

function Bot:setRespawn(respawn)
	self._respawning = respawn;
end

function Bot:setShoot(shoot)
	self._shoot = shoot;
end

function Bot:setSpeed(speed)
	self._botSpeed = speed;
end

function Bot:getSpawnMode()
	return self._spawnMode;
end

function Bot:getWayIndex()
	return self._pathIndex;
end

function Bot:getSpawnTransform()
	return self._spawnTransform;
end

function Bot:getTargetPlayer()
	return self._targetPlayer;
end

function Bot:resetSpawnVars()
	self._spawnDelayTimer		= 0;
	self._obstaceSequenceTimer	= 0;
	self._obstacleRetryCounter	= 0;
	self._lastWayDistance		= 1000;
	self._shootPlayer			= nil;
	self._lastShootPlayer		= nil;
	self._shootModeTimer		= 0;
	self._meleeCooldownTimer	= 0;
	self._shootTraceTimer		= 0;
	self._reloadTimer 			= 0;
	self._attackModeMoveTimer	= 0;
	self._shootWayPoints		= {};

	self._shotTimer				= -Config.botFirstShotDelay;
	self._updateTimer			= 0;
	self._aimUpdateTimer		= 0; --timer sync
	self._targetPoint			= nil;
	self._meleeActive 			= false;

	self.player.input:SetLevel(EntryInputActionEnum.EIAZoom, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeFastMelee, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
	self.player.input:SetLevel(EntryInputActionEnum.EIAThrottle, 0);
	self.player.input:SetLevel(EntryInputActionEnum.EIASprint, 0);
end

function Bot:clearPlayer(player)
	if self._shootPlayer == player then
		self._shootPlayer = nil;
	end

	if self._targetPlayer == player then
		self._targetPlayer = nil;
	end

	if self._lastShootPlayer == player then
		self._lastShootPlayer = nil;
	end
end

function Bot:destroy()
	self:resetVars();
	self.player.input	= nil;

	PlayerManager:DeletePlayer(self.player);
	self.player			= nil;
end

-- private functions
function Bot:_updateRespwawn()
	if self._respawning and self.player.soldier == nil and self._spawnMode > 0 then
		-- wait for respawn-delay gone
		if self._spawnDelayTimer < Config.spawnDelayBots then
			self._spawnDelayTimer = self._spawnDelayTimer + StaticConfig.botUpdateCycle;
		else
			Events:DispatchLocal('Bot:RespawnBot', self.name);
		end
	end
end

function Bot:_updateAiming()
	if self.player.alive and self._shoot then
		if self._shootPlayer ~= nil and self._shootPlayer.soldier ~= nil then

			--interpolate player movement
			local targetMovement = Vec3(0,0,0);
			local ptichCorrection = 0.0;
			local fullPositionTarget =  self._shootPlayer.soldier.worldTransform.trans:Clone() + Utilities:getCameraPos(self._shootPlayer, true);
			local fullPositionBot = self.player.soldier.worldTransform.trans:Clone() + Utilities:getCameraPos(self.player, false);

			if self.activeWeapon.type ~= "Knife" then
				local distanceToPlayer	= fullPositionTarget:Distance(fullPositionBot);
				--calculate how long the distance is --> time to travel
				local timeToTravel		= (distanceToPlayer / self.activeWeapon.bulletSpeed)
				local factorForMovement	= (timeToTravel) / self._aimUpdateTimer
				ptichCorrection	= 0.5 * timeToTravel * timeToTravel * self.activeWeapon.bulletDrop;
				if self._lastShootPlayer == self._shootPlayer then
					targetMovement			= (fullPositionTarget - self._lastTargetTrans) * factorForMovement; --movement in one dt
				end

				self._lastShootPlayer = self._shootPlayer;
				self._lastTargetTrans = fullPositionTarget;
			end

			--calculate yaw and pith
			local dz		= fullPositionTarget.z + targetMovement.z - fullPositionBot.z;
			local dx		= fullPositionTarget.x + targetMovement.x - fullPositionBot.x;
			local dy		= fullPositionTarget.y + targetMovement.y + ptichCorrection - fullPositionBot.y;
			local atanDzDx	= math.atan(dz, dx);
			local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2);

			--calculate pitch
			local distance	= math.sqrt(dz ^ 2 + dx ^ 2);
			local pitch		= math.atan(dy, distance);

			self._targetPitch	= pitch;
			self._targetYaw		= yaw;
		end
	end
end

function Bot:_updateYaw()
	if self._meleeActive then
		return
	end
	if self._targetPoint ~= nil and self._shootPlayer == nil and self.player.soldier ~= nil then
		local dy					= self._targetPoint.trans.z - self.player.soldier.worldTransform.trans.z;
		local dx					= self._targetPoint.trans.x - self.player.soldier.worldTransform.trans.x;
		local atanDzDx	= math.atan(dy, dx);
		local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2);
		self._targetYaw = yaw;
	end

	local deltaYaw = self.player.input.authoritativeAimingYaw - self._targetYaw;
	if deltaYaw > math.pi then
		deltaYaw = deltaYaw - 2*math.pi
	elseif deltaYaw < -math.pi then
		deltaYaw = deltaYaw + 2*math.pi
	end

	local absDeltaYaw = math.abs(deltaYaw)

	local inkrement = Globals.yawPerFrame;
	if absDeltaYaw < inkrement then
		self.player.input.authoritativeAimingYaw = self._targetYaw;
		self.player.input.authoritativeAimingPitch = self._targetPitch;
		return;
	end

	if deltaYaw > 0  then
		inkrement = -inkrement;
	end
	local tempYaw = self.player.input.authoritativeAimingYaw + inkrement;
	if tempYaw >= (math.pi * 2) then
		tempYaw = tempYaw - (math.pi * 2);
	elseif tempYaw < 0.0 then
		tempYaw = tempYaw + (math.pi * 2);
	end
	self.player.input.authoritativeAimingYaw = tempYaw
	self.player.input.authoritativeAimingPitch = self._targetPitch;
end


function Bot:_updateShooting()
	if self.player.alive and self._shoot then
		--select weapon-slot TODO: keep button pressed or not?
		if not self._meleeActive then
			if self.player.soldier.weaponsComponent ~= nil then
				if Config.botWeapon == "Knife" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon7, 1);
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon1, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
						self.activeWeapon = self.knife;
					else
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon7, 0);
					end
				elseif Config.botWeapon == "Pistol" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_1 then
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon7, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 1);
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon1, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
						self.activeWeapon = self.pistol;
					else
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 0);
					end
				else -- "Primary" then
					if self.player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon7, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon2, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon1, 1);
						self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
						self.activeWeapon = self.primary;
					else
						self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon1, 0);
					end
				end
			end
		end

		if self._shootPlayer ~= nil and self._shootPlayer.soldier ~= nil then
			if self._shootModeTimer < Config.botFireModeDuration then
				self.player.input:SetLevel(EntryInputActionEnum.EIAZoom, 1); --does not work.
				self.player.input:SetLevel(EntryInputActionEnum.EIAReload, 0);
				self._shootModeTimer	= self._shootModeTimer + StaticConfig.botUpdateCycle;
				self.activeMoveMode		= 9; -- movement-mode : attack
				self._reloadTimer		= 0; -- reset reloading

				--check for melee attack
				if Config.meleeAttackIfClose and not self._meleeActive and self._shootPlayer.soldier.worldTransform.trans:Distance(self.player.soldier.worldTransform.trans) < 1.5 and self._meleeCooldownTimer <= 0 then
					self._meleeActive = true;
					self.activeWeapon = self.knife;
					self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
					self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon7, 1);
					self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeFastMelee, 1);
					self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 1);
					self._meleeCooldownTimer = Config.meleeAttackCoolDown;
					if not USE_REAL_DAMAGE then
						Events:DispatchLocal("ServerDamagePlayer", self._shootPlayer.name, self.player.name, true);
					end
				else
					if self._meleeCooldownTimer < 0 then
						self._meleeCooldownTimer = 0;
					elseif self._meleeCooldownTimer > 0 then
						self._meleeCooldownTimer = self._meleeCooldownTimer - StaticConfig.botUpdateCycle;
						if self._meleeCooldownTimer < (Config.meleeAttackCoolDown - 0.8) then
							self._meleeActive = false;
							self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeFastMelee, 0);
							self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 0);
						end
					end
				end

				--trace way back
				if self.activeWeapon.type ~= "Sniper" then
					if self._shootTraceTimer > StaticConfig.traceDeltaShooting then
						--create a Trace to find way back
						self._shootTraceTimer 	= 0;
						local point				= WayPoint();
						point.trans				= self.player.soldier.worldTransform.trans:Clone();
						point.speedMode			= 4;

						table.insert(self._shootWayPoints, point);
					end
					self._shootTraceTimer = self._shootTraceTimer + StaticConfig.botUpdateCycle;
				end

				--shooting sequence
				if Config.botWeapon == "Knife" then
					self._shotTimer	= -Config.botFirstShotDelay;
				else
					if self._shotTimer >= (self.activeWeapon.fireCycle + self.activeWeapon.pauseCycle) then
						self._shotTimer	= 0;
					end
					if self._shotTimer >= 0 then
						if self.activeWeapon.delayed == false then
							if self._shotTimer >= self.activeWeapon.fireCycle or self._meleeActive then
								self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
							else
								self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 1);
							end
						else --start with pause Cycle
							if self._shotTimer >= self.activeWeapon.pauseCycle and not self._meleeActive then
								self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 1);
							else
								self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
							end
						end
					end
				end

				self._shotTimer = self._shotTimer + StaticConfig.botUpdateCycle;

			else
				self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
				self._shotTimer			= -Config.botFirstShotDelay;
				self._shootPlayer		= nil;
				self._lastShootPlayer	= nil;
			end
		else
			self.player.input:SetLevel(EntryInputActionEnum.EIAZoom, 0);
			self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0);
			self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeFastMelee, 0);
			self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 0);
			self._shootPlayer		= nil;
			self._lastShootPlayer	= nil;
			self._shootModeTimer	= 0;

			self._reloadTimer = self._reloadTimer + StaticConfig.botUpdateCycle;
			if self._reloadTimer > 4 then
				self.player.input:SetLevel(EntryInputActionEnum.EIAReload, 0);
			elseif self._reloadTimer > 3 and self.player.soldier.weaponsComponent.currentWeapon.primaryAmmo <= self.activeWeapon.reload then
				self.player.input:SetLevel(EntryInputActionEnum.EIAReload, 1);
			end
		end
	end
end

function Bot:_getWayIndex(currentWayPoint)
	local activePointIndex = 1;

	if currentWayPoint == nil then
		currentWayPoint = activePointIndex;
	else
		activePointIndex = currentWayPoint;

		-- direction handling
		if activePointIndex > #Globals.wayPoints[self._pathIndex] then
			if Globals.wayPoints[self._pathIndex][1].optValue == 0xFF then --inversion needed
				activePointIndex			= #Globals.wayPoints[self._pathIndex];
				self._invertPathDirection	= true;
			else
				activePointIndex			= 1;
			end
		elseif activePointIndex < 1 then
			if Globals.wayPoints[self._pathIndex][1].optValue == 0xFF then --inversion needed
				activePointIndex			= 1;
				self._invertPathDirection	= false;
			else
				activePointIndex			= #Globals.wayPoints[self._pathIndex];
			end
		end
	end
	return activePointIndex;
end

function Bot:_updateMovement()
	-- movement-mode of bots
	local additionalMovementPossible = true;

	if self.player.alive then
		-- pointing
		if self.activeMoveMode == 2 and self._targetPlayer ~= nil then
			if self._targetPlayer.soldier ~= nil then
				local dy		= self._targetPlayer.soldier.worldTransform.trans.z - self.player.soldier.worldTransform.trans.z;
				local dx		= self._targetPlayer.soldier.worldTransform.trans.x - self.player.soldier.worldTransform.trans.x;
				local atanDzDx	= math.atan(dy, dx);
				local yaw		= (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2);
				self._targetYaw = yaw;
			end

		-- mimicking
		elseif self.activeMoveMode == 3 and self._targetPlayer ~= nil then
			additionalMovementPossible = false;

			for i = 0, 36 do
				self.player.input:SetLevel(i, self._targetPlayer.input:GetLevel(i));
			end

			self._targetYaw		= self._targetPlayer.input.authoritativeAimingYaw;
			self._targetPitch	= self._targetPlayer.input.authoritativeAimingPitch;

		-- mirroring
		elseif self.activeMoveMode == 4 and self._targetPlayer ~= nil then
			additionalMovementPossible = false;

			for i = 0, 36 do
				self.player.input:SetLevel(i, self._targetPlayer.input:GetLevel(i));
			end

			self._targetYaw		= self._targetPlayer.input.authoritativeAimingYaw + ((self._targetPlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi);
			self._targetPitch	= self._targetPlayer.input.authoritativeAimingPitch;

		-- move along points
		elseif self.activeMoveMode == 5 then
			self._attackModeMoveTimer = 0;

			-- get next point
			local activePointIndex = self:_getWayIndex(self._currentWayPoint)

			if Globals.wayPoints[self._pathIndex][1] ~= nil then -- check for reached point
				local point				= nil;
				local nextPoint			= nil;
				local pointIncrement	= 1;
				local useShootWayPoint	= false;

				if #self._shootWayPoints > 0 then	--we need to go back to path first
					point 				= self._shootWayPoints[#self._shootWayPoints];
					nextPoint 			= self._shootWayPoints[#self._shootWayPoints - 1];
					if nextPoint == nil then
						nextPoint = Globals.wayPoints[self._pathIndex][activePointIndex];
					end
					useShootWayPoint	= true;
				else
					point = Globals.wayPoints[self._pathIndex][activePointIndex];
					if not self._invertPathDirection then
						nextPoint = Globals.wayPoints[self._pathIndex][self:_getWayIndex(self._currentWayPoint + 1)]
					else
						nextPoint = Globals.wayPoints[self._pathIndex][self:_getWayIndex(self._currentWayPoint - 1)]
					end
				end

				if (point.speedMode) > 0 then -- movement
					self._wayWaitTimer			= 0;
					self._wayWaitYawTimer		= 0;
					self.activeSpeedValue		= point.speedMode; --speed
					if Config.overWriteBotSpeedMode > 0 then
						self.activeSpeedValue = Config.overWriteBotSpeedMode;
					end
					local dy					= point.trans.z - self.player.soldier.worldTransform.trans.z;
					local dx					= point.trans.x - self.player.soldier.worldTransform.trans.x;
					local distanceFromTarget	= math.sqrt(dx ^ 2 + dy ^ 2);
					local heightDistance		= math.abs(point.trans.y - self.player.soldier.worldTransform.trans.y);


					--detect obstacle and move over or around TODO: Move before normal jump
					local currentWayPontDistance = self.player.soldier.worldTransform.trans:Distance(point.trans);
					if currentWayPontDistance > self._lastWayDistance and self._obstaceSequenceTimer == 0 then
						--TODO: skip one pooint?
						self._targetPoint = nextPoint;
						distanceFromTarget			= 0;
						heightDistance				= 0;

					else
						self._targetPoint = point;
					end


					if math.abs(currentWayPontDistance - self._lastWayDistance) < 0.02 or self._obstaceSequenceTimer ~= 0 then
						-- try to get around obstacle
						self.activeSpeedValue = 4; --always try to stand

						if self._obstaceSequenceTimer == 0 then --step 0
							self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
							self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0);

						elseif self._obstaceSequenceTimer > 2.4 then --step 4 - repeat afterwards
							self._obstaceSequenceTimer = 0;
							self._meleeActive = false;
							self._obstacleRetryCounter = self._obstacleRetryCounter + 1;
							self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
							self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 0);
							self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeFastMelee, 0);
							self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0.0);
						
						elseif self._obstaceSequenceTimer > 1.0 then --step 3
							if self._obstacleRetryCounter == 0 then
								self._meleeActive = true;
								self.player.input:SetLevel(EntryInputActionEnum.EIASelectWeapon7, 1);
								self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeFastMelee, 1);
								self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 1); --maybe a fence?
							else
								self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 1);
							end
							
						elseif self._obstaceSequenceTimer > 0.4 then --step 2
							self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
							self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0);
							self._targetPitch		= 0.0;
							if (MathUtils:GetRandomInt(0,1) == 1) then
								self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 1.0 * Config.speedFactor);
							else
								self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, -1.0 * Config.speedFactor);
							end

						elseif self._obstaceSequenceTimer > 0.0 then --step 1
							self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1);
							self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 1);
						end

						self._obstaceSequenceTimer = self._obstaceSequenceTimer + StaticConfig.botUpdateCycle;

						if self._obstacleRetryCounter >= 2 then --try next waypoint
							self._obstacleRetryCounter	= 0;
							self._meleeActive 			= false;
							distanceFromTarget			= 0;
							heightDistance				= 0;
							pointIncrement				= 5; -- go 5 points further
						end
					else
						self._meleeActive = false;
						self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
						self.player.input:SetLevel(EntryInputActionEnum.EIAMeleeAttack, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0.0);
					end

					self._lastWayDistance = currentWayPontDistance;

					-- jump detection. Much more simple now, but works fine ;-)
					if self._obstaceSequenceTimer == 0 then
						if (point.trans.y - self.player.soldier.worldTransform.trans.y) > 0.3 and Config.jumpWhileMoving then
							--detect, if a jump was recorded or not
							local timeForwardBackwardJumpDetection = 1.1; -- 1.5 s ahead and back
							local jumpValid = false;
							for i = 1, math.floor(timeForwardBackwardJumpDetection/StaticConfig.traceDelta) do
								local pointBefore = Globals.wayPoints[self._pathIndex][activePointIndex - i];
								local pointAfter = Globals.wayPoints[self._pathIndex][activePointIndex + i];
								if (pointBefore ~= nil and pointBefore.extraMode == 1) or (pointAfter ~= nil and pointAfter.extraMode == 1) then
									jumpValid = true;
									break;
								end
							end
							if jumpValid then
								self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 1);
								self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1);
							end

						else --only reset, if no obstacle-sequence active
							self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0);
							self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
						end
					end

					--check for reached target
					if distanceFromTarget <= Config.targetDistanceWayPoint and heightDistance <= StaticConfig.targetHeightDistanceWayPoint then
						if not useShootWayPoint then
							if self._invertPathDirection then
								self._currentWayPoint = activePointIndex - pointIncrement;
							else
								self._currentWayPoint = activePointIndex + pointIncrement;
							end

						else
							for i = 1, pointIncrement do --one already gets removed on start of wayfinding
								table.remove(self._shootWayPoints);
							end
						end
						self._obstaceSequenceTimer	= 0;
						self._meleeActive = false;
						self._lastWayDistance		= 1000;
					end
				else -- wait mode
					self._wayWaitTimer		= self._wayWaitTimer + StaticConfig.botUpdateCycle;
					local lastYawTimer 		= self._wayWaitYawTimer
					self._wayWaitYawTimer 	= self._wayWaitYawTimer + StaticConfig.botUpdateCycle;
					self.activeSpeedValue	= 0;
					self._targetPoint		= nil;

					-- move around a little
					if self._wayWaitYawTimer > 6 then
						self._wayWaitYawTimer = 0;
						self._targetYaw = self._targetYaw + 1.0; -- 60 ° rotation right
						if self._targetYaw > (math.pi * 2) then
							self._targetYaw = self._targetYaw - (2 * math.pi)
						end
					elseif self._wayWaitYawTimer >= 4 and lastYawTimer < 4 then
						self._targetYaw = self._targetYaw - 1.0; -- 60 ° rotation left
						if self._targetYaw < 0 then
							self._targetYaw = self._targetYaw + (2 * math.pi)
						end
					elseif self._wayWaitYawTimer >= 3 and lastYawTimer < 3 then
						self._targetYaw = self._targetYaw - 1.0; -- 60 ° rotation left
						if self._targetYaw < 0 then
							self._targetYaw = self._targetYaw + (2 * math.pi)
						end
					elseif self._wayWaitYawTimer >= 1 and lastYawTimer < 1 then
						self._targetYaw = self._targetYaw + 1.0; -- 60 ° rotation right
						if self._targetYaw > (math.pi * 2) then
							self._targetYaw = self._targetYaw - (2 * math.pi)
						end
					end

					if self._wayWaitTimer > point.optValue then
						self._wayWaitTimer		= 0;
						if self._invertPathDirection then
							self._currentWayPoint	= activePointIndex - 1;
						else
							self._currentWayPoint	= activePointIndex + 1;
						end
					end
				end
			end

		-- Shoot MoveMode
		elseif self.activeMoveMode == 9 then
			--crouch moving (only mode with modified gun)
			if self.activeWeapon.type == "Sniper" then
				if BOT_ATTACK_MODE == "Crouch" then
					if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
						self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true);
					end
				else
					if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
						self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true);
					end
				end
				self.activeSpeedValue = 0;
				self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
				self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
			else
				if Config.botWeapon == "Knife" then --Knife Only Mode
					self.activeSpeedValue = 4; --run towards player
				else
					if BOT_ATTACK_MODE == "Crouch" then
						self.activeSpeedValue = 2;
					else
						self.activeSpeedValue = 3;
					end
				end
				if Config.overWriteBotAttackMode > 0 then
					self.activeSpeedValue = Config.overWriteBotAttackMode;
				end

				local targetTime = 5.0
				local targetCycles = math.floor(targetTime / StaticConfig.traceDeltaShooting);

				if #self._shootWayPoints > targetCycles and Config.jumpWhileShooting then
					local distanceDone = self._shootWayPoints[#self._shootWayPoints].trans:Distance(self._shootWayPoints[#self._shootWayPoints-targetCycles].trans);
					if distanceDone < 1.0 then --no movement was possible. Try to jump over obstacle
						self.activeSpeedValue = 3;
						self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 1);
						self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1);
					else
						self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
						self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0);
					end
				else
					self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0);
					self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
				end

				-- do some sidwards movement from time to time
				if self._attackModeMoveTimer > 20 then
					self._attackModeMoveTimer = 0;
					self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
				elseif self._attackModeMoveTimer > 17 then
					self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, -0.5 * Config.speedFactorAttack);
				elseif self._attackModeMoveTimer > 13 then
					self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0);
				elseif self._attackModeMoveTimer > 12 then
					self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.5 * Config.speedFactorAttack);
				elseif self._attackModeMoveTimer > 9 then
					self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0);
				elseif self._attackModeMoveTimer > 7 then
					self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.5 * Config.speedFactorAttack);
				end

				self._attackModeMoveTimer = self._attackModeMoveTimer + StaticConfig.botUpdateCycle;
			end
		end

		-- additional movement
		if additionalMovementPossible then
			local speedVal = 0;

			if self.activeMoveMode > 0 then
				if self.activeSpeedValue == 1 then
					speedVal = 1.0;

					if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Prone then
						self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Prone, true, true);
					end

				elseif self.activeSpeedValue == 2 then
					speedVal = 1.0;

					if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Crouch then
						self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Crouch, true, true);
					end

				elseif self.activeSpeedValue >= 3 then
					speedVal = 1.0;

					if self.player.soldier.pose ~= CharacterPoseType.CharacterPoseType_Stand then
						self.player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true);
					end
				end
			end

			if speedVal > 0 and self._shootPlayer ~= nil and self._shootPlayer.soldier ~= nil and Config.botWeapon ~= "Knife" then
				speedVal = speedVal * Config.speedFactorAttack;
			end

			-- movent speed
			if self.player.alive then
				self.player.input:SetLevel(EntryInputActionEnum.EIAThrottle, speedVal * Config.speedFactor);

				if self.activeSpeedValue > 3 then
					self.player.input:SetLevel(EntryInputActionEnum.EIASprint, 1);
				else
					self.player.input:SetLevel(EntryInputActionEnum.EIASprint, 0);
				end
			end
		end
	end
end

function Bot:_setActiveVars()
	self.activeMoveMode		= self._moveMode;
	self.activeSpeedValue	= self._botSpeed;
end

function Bot:_getCameraHight(soldier, isTarget)
	local camereaHight = 0;

	if not isTarget then
		camereaHight = 1.6; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand

		if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			camereaHight = 0.3;
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			camereaHight = 1.0;
		end
	else
		camereaHight = 1.3; --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand - reduce by 0.3

		if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			camereaHight = 0.3; -- don't reduce
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			camereaHight = 0.8; -- reduce by 0.2
		end
	end

	return camereaHight;
end

return Bot;