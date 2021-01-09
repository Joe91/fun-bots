class('Bot')

require('__shared/config')
local Globals = require('globals')
local fovHalf = Config.fovForShooting / 360 * math.pi * 2 / 2

function Bot:__init(player)
    --Player Object
    self.player = player
    self.name = player.name
    self.id = player.id

    --common settings
    self._spawnMode = 0
    self._moveMode = 0
    self.kit = 0
    self.color = 0
    self._checkSwapTeam = false
    self._respawning = false

    --timers
    self._updateTimer = 0  --was timesGone
    self._spawnDelayTimer = 0
    self._wayWaitTimer = 0
    self._obstaceSequenceTimer = 0
    self._shotTimer = 0
    self._shootModeTimer = nil
    
    --shared movement vars
    self.activeMoveMode = 0
    self.activeSpeedValue = 0

    --advanced movement
    self._currentWayPoint = nil
    self._pathIndex = 0
    self._jumpTargetPoint = nil
    self._jumpTriggerDistance = 0
    self._lastWayDistance = 0
    self._obstacleRetryCounter = 0

    --shooting
    self._shoot = false
    self._shootPlayer = 0

    --simple movement
    self._botSpeed = 0
    self._targetPlayer = nil
    self._spawnTransform = LinearTransform()
end

function Bot:onUpdate(dt)
    if self.player.soldier ~= nil then
        self.player.soldier:SingleStepEntry(self.player.controlledEntryId)
    end

    self:_updateAiming() --needs to be fast?

    self._updateTimer = self._updateTimer + dt
    if self._updateTimer > Config.botUpdateCycle then
        self._updateTimer = 0

        self:_setActiveVars()

        self:_updateRespwawn()
        self:_updateShooting()
        self:_updateMovement()  --TODO: move-mode shoot
    end
end


--public functions
function Bot:shootAt(player, ignoreYaw)
    local oldYaw = self.player.input.authoritativeAimingYaw
    local dy = player.soldier.worldTransform.trans.z - self.player.soldier.worldTransform.trans.z
    local dx = player.soldier.worldTransform.trans.x - self.player.soldier.worldTransform.trans.x
    local yaw = (math.atan(dy, dx) > math.pi / 2) and (math.atan(dy, dx) - math.pi / 2) or (math.atan(dy, dx) + 3 * math.pi / 2)

    local dYaw = math.abs(oldYaw-yaw)
    if dYaw > math.pi then
        dYaw =math.pi * 2 - dYaw
    end

    if dYaw < fovHalf or ignoreYaw then
        if self._shoot then
            if self._shootModeTimer == nil or self._shootModeTimer > 1 then
                self._shootModeTimer = 0
                self._shootPlayer = player
                self._shotTimer = 0
            end
        else
            self._shootModeTimer = Config.botFireModeDuration
        end
    end
end

function Bot:setVarsDefault()
    self._spawnMode = 5
    self._moveMode = 5
    self._pathIndex = 1
    self._respawning = true
    self._shoot = true
end

function Bot:resetVars()
    self._spawnMode = 0
    self._moveMode = 0
    self._pathIndex = 0
    self._respawning = false
    self._shoot = false
    self._targetPlayer = nil
end

function Bot:setVarsStatic(player)
    self._spawnMode = 0
    self._moveMode = 0
    self._pathIndex = 0
    self._respawning = false
    self._shoot = false
    self._targetPlayer = player
end

function Bot:setVarsSimpleMovement(player, spawnMode, transform)
    self._spawnMode = spawnMode
    self._moveMode = 2
    self._botSpeed = 3
    self._pathIndex = 0
    self._respawning = false
    self._shoot = false
    self._targetPlayer = player
    if transform ~= nil then
        self._spawnTransform = transform
    end
end

function Bot:setVarsWay(player, useRandomWay, pathIndex, currentWayPoint)
    if useRandomWay then
        self._spawnMode = 5
        self._shoot = true
    else
        self._spawnMode = 4
        self._shoot = false
    end

    self._moveMode = 5
    self._pathIndex = pathIndex
    self._currentWayPoint = currentWayPoint
    self._respawning = false
    self._targetPlayer = player
end

function Bot:isStaticMovement()
    if self._moveMode == 0 or self._moveMode == 3 or self._moveMode == 4 then
        return true
    else
        return false
    end
end

function Bot:setMoveMode(moveMode)
    self._moveMode = moveMode
end
function Bot:setRespawn(respawn)
    self._respawning = respawn
end
function Bot:setShoot(shoot)
    self._shoot = shoot
end
function Bot:setWayIndex(wayIndex)
    self._pathIndex = wayIndex
end
function Bot:setCurrentWayPoint(wayPoint)
    self._currentWayPoint = wayPoint
end
function Bot:setSpeed(speed)
    self._botSpeed = speed
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

function Bot:resetSpawnVars()
    self._spawnDelayTimer = 0
    self._obstaceSequenceTimer = 0
    self._obstacleRetryCounter = 0
    self._lastWayDistance = 1000
    self._shootPlayer = nil
    self._shootModeTimer = nil
end

function Bot:clearPlayer(player)
    if self._shootPlayer == player then
        self._shootPlayer = nil
    end
    if self._targetPlayer == player then
        self._targetPlayer = nil
    end
end

function Bot:destroy()
    self.player.input = nil
    PlayerManager:DeletePlayer(self.player)
end

--private functions
function Bot:_updateRespwawn()
    if self._respawning and self.player.soldier == nil and self._spawnMode > 0 then
        -- wait for respawn-delay gone
        if self._spawnDelayTimer < Config.spawnDelayBots then
            self._spawnDelayTimer = self._spawnDelayTimer + Config.botUpdateCycle
        else
            Events:Dispatch('Bot:RespawnBot', self.name)
        end
    end
end

function Bot:_updateAiming()
    if self.player.alive and self._shoot then
        if self._shootPlayer ~= nil and self._shootPlayer.soldier ~= nil then
            self.player.input:SetLevel(EntryInputActionEnum.EIAZoom, 1)
            --calculate yaw and pith
            local dz = self._shootPlayer.soldier.worldTransform.trans.z - self.player.soldier.worldTransform.trans.z
            local dx = self._shootPlayer.soldier.worldTransform.trans.x - self.player.soldier.worldTransform.trans.x
            local dy = self._shootPlayer.soldier.worldTransform.trans.y + self:_getCameraHight(self._shootPlayer.soldier) - 0.2 -self.player.soldier.worldTransform.trans.y - self:_getCameraHight(self.player.soldier) --0.2 to shoot a litle lower
            local atanDzDx = math.atan(dz, dx)
            local yaw = (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
            --calculate pitch
            local distance = math.sqrt(dz^2 + dx^2)
            local pitch =  math.atan(dy, distance)
            self.player.input.authoritativeAimingPitch = pitch
            self.player.input.authoritativeAimingYaw = yaw
        end
    end
end

function Bot:_updateShooting()
    if self.player.alive and self._shoot then
        if self._shootPlayer ~= nil and self._shootPlayer.soldier ~= nil then
            if self._shootModeTimer < Config.botFireModeDuration then
                self._shootModeTimer = self._shootModeTimer + Config.botUpdateCycle

                self.activeMoveMode = 9 -- movement-mode : shoot

                if self._shotTimer >= (Config.botFireDuration + Config.botFirePause) then
                    self._shotTimer = 0
                end
                if self._shotTimer >= Config.botFireDuration then
                    self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0)
                else
                    self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 1)
                end
                self._shotTimer = self._shotTimer + Config.botUpdateCycle
            else
                self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0)
                self._shootPlayer = nil
            end
        else
            self.player.input:SetLevel(EntryInputActionEnum.EIAZoom, 0)
            self.player.input:SetLevel(EntryInputActionEnum.EIAFire, 0)
            self._shootPlayer = nil
            self._shootModeTimer = nil
        end
    end
end

function Bot:_updateMovement()
    -- movement-mode of bots
    local additionalMovementPossible = true

    if self.player.alive then
        -- pointing
        if self.activeMoveMode == 2 and self._targetPlayer ~= nil then
            if self._targetPlayer.soldier  ~= nil then 
                local dy = self._targetPlayer.soldier.worldTransform.trans.z - self.player.soldier.worldTransform.trans.z
                local dx = self._targetPlayer.soldier.worldTransform.trans.x - self.player.soldier.worldTransform.trans.x
                local atanDzDx = math.atan(dy, dx)
                local yaw = (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
                self.player.input.authoritativeAimingYaw = yaw
            end

        -- mimicking
        elseif self.activeMoveMode == 3 and self._targetPlayer ~= nil then 
            additionalMovementPossible = false
            for i = 0, 36 do
                self.player.input:SetLevel(i, self._targetPlayer.input:GetLevel(i))
            end
            self.player.input.authoritativeAimingYaw = self._targetPlayer.input.authoritativeAimingYaw
            self.player.input.authoritativeAimingPitch = self._targetPlayer.input.authoritativeAimingPitch

        -- mirroring
        elseif self.activeMoveMode == 4 and self._targetPlayer ~= nil then 
            additionalMovementPossible = false
            for i = 0, 36 do
                self.player.input:SetLevel(i, self._targetPlayer.input:GetLevel(i))
            end
            self.player.input.authoritativeAimingYaw = self._targetPlayer.input.authoritativeAimingYaw + ((self._targetPlayer.input.authoritativeAimingYaw > math.pi) and -math.pi or math.pi)
            self.player.input.authoritativeAimingPitch = self._targetPlayer.input.authoritativeAimingPitch

        -- move along points
        elseif self.activeMoveMode == 5 then 
            -- get next point
            local activePointIndex = 1
            if self._currentWayPoint == nil then
                self._currentWayPoint = activePointIndex
            else
                activePointIndex = self._currentWayPoint
                if #Globals.wayPoints[self._pathIndex] < activePointIndex then
                    activePointIndex = 1
                end
            end
            if Globals.wayPoints[self._pathIndex][1] ~= nil then   -- check for reached point
                local inputVar = Globals.wayPoints[self._pathIndex][activePointIndex].inputVar
                if (inputVar & 0x000F) > 0 then -- movement
                    self._wayWaitTimer = 0
                    self.activeSpeedValue = inputVar & 0x000F  --speed
                    local trans = Vec3()
                    trans = Globals.wayPoints[self._pathIndex][activePointIndex].trans
                    local dy = trans.z - self.player.soldier.worldTransform.trans.z
                    local dx = trans.x - self.player.soldier.worldTransform.trans.x
                    local distanceFromTarget = math.sqrt(dx ^ 2 + dy ^ 2)

                    --detect obstacle and move over or around TODO: Move before normal jump
                    local currentWayPontDistance = math.abs(trans.x - self.player.soldier.worldTransform.trans.x) + math.abs(trans.z - self.player.soldier.worldTransform.trans.z)
                    if currentWayPontDistance >= self._lastWayDistance  or self._obstaceSequenceTimer ~= 0 then
                        -- try to get around obstacle
                        self.activeSpeedValue = 3 --always stand
                        if self._obstaceSequenceTimer == 0 then  --step 0
                            self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                            self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        elseif self._obstaceSequenceTimer > 1.0 then  --step 4 - repeat afterwards
                            self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0)
                            self._obstaceSequenceTimer = 0.1
                            self._obstacleRetryCounter = self._obstacleRetryCounter + 1
                        elseif self._obstaceSequenceTimer > 0.6 then  --step 3
                            self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                            self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                            self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 1.0)
                        elseif self._obstaceSequenceTimer > 0.4 then --step 2
                            self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                            self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        elseif self._obstaceSequenceTimer > 0.0 then --step 1
                            self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 1)
                            self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
                        end
                        self._obstaceSequenceTimer = self._obstaceSequenceTimer + Config.botUpdateCycle

                        if self._obstacleRetryCounter >= 2 then --tried twice, try next waypoint
                            self._obstacleRetryCounter = 0
                            distanceFromTarget = 0
                        end
                    else
                        self._lastWayDistance = currentWayPontDistance
                        self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                        self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        self.player.input:SetLevel(EntryInputActionEnum.EIAStrafe, 0.0)
                    end

                    -- jup on command
                    if ((inputVar & 0x00F0) >> 4) == 1 and self._jumpTargetPoint == nil then
                        self._jumpTargetPoint = trans
                        self._jumpTriggerDistance = math.abs(trans.x -self.player.soldier.worldTransform.trans.x) + math.abs(trans.z -self.player.soldier.worldTransform.trans.z)
                    elseif self._jumpTargetPoint ~= nil then
                        local currentJumpDistance = math.abs(self._jumpTargetPoint.x -self.player.soldier.worldTransform.trans.x) + math.abs(self._jumpTargetPoint.z -self.player.soldier.worldTransform.trans.z)
                        if currentJumpDistance > self._jumpTriggerDistance then
                            --now we are really close to the Jump-Point --> Jump
                            self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 1)
                            self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 1)
                            self._jumpTargetPoint = nil
                        else
                            self._jumpTriggerDistance = currentJumpDistance
                        end
                    else
                        self.player.input:SetLevel(EntryInputActionEnum.EIAQuicktimeJumpClimb, 0)
                        self.player.input:SetLevel(EntryInputActionEnum.EIAJump, 0)
                    end
                         
                    if distanceFromTarget > 1 then
                        local atanDzDx = math.atan(dy, dx)
                        local yaw = (atanDzDx > math.pi / 2) and (atanDzDx - math.pi / 2) or (atanDzDx + 3 * math.pi / 2)
                        self.player.input.authoritativeAimingYaw = yaw
                    else  -- target reached
                        self._currentWayPoint = activePointIndex + 1
                        self._obstaceSequenceTimer = 0
                        self._lastWayDistance = 1000
                    end
                else -- wait mode
                    self._wayWaitTimer  = self._wayWaitTimer  + Config.botUpdateCycle
                    self.activeSpeedValue = 0
                    -- TODO: Move yaw while waiting?
                    if  self._wayWaitTimer  > (inputVar >> 8) then
                        self._wayWaitTimer  = 0
                        self._currentWayPoint = activePointIndex + 1
                    end
                end
            end

        -- shooting MoveMode
        elseif self.activeMoveMode == 9 then
            --reduce speed
            if self.activeSpeedValue > 1 then
                self.activeSpeedValue = self.activeSpeedValue - 1
            end
            -- TODO: trace way back
        end

        -- additional movement
        if additionalMovementPossible then
            local speedVal = 0
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

            -- movent speed
            if self.player.alive then
                self.player.input:SetLevel(EntryInputActionEnum.EIAThrottle, speedVal)
                if self.activeSpeedValue > 3 then
                    self.player.input:SetLevel(EntryInputActionEnum.EIASprint, 1)
                else
                    self.player.input:SetLevel(EntryInputActionEnum.EIASprint, 0)
                end
            end
        end
    end
end

function Bot:_setActiveVars()
    self.activeMoveMode = self._moveMode
    self.activeSpeedValue = self._botSpeed
end

function Bot:_getCameraHight(soldier)
    local camereaHight = 1.6 --bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand
    if soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
        camereaHight = 0.3
    elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
        camereaHight = 1.0
    end
    return camereaHight
end


return Bot