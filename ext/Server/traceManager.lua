class('TraceManager')
require('waypoint')
require('__shared/config')
local Globals = require('globals')

function TraceManager:__init()
    self.activeTraceIndexes = 0
    self._tracePlayer = {}
    self._traceUpdateTimer = {}
    self._traceWaitTimer = {}
    self._mapName = ""

    Events:Subscribe('Engine:Update', self, self._onUpdate)
    Events:Subscribe('Player:Left', self, self._onPlayerLeft)
end

function TraceManager:onLevelLoaded(levelName, gameMode)
    self._mapName = levelName.."_"..gameMode
    for i = 1, Config.maxTraceNumber do
        Globals.wayPoints[i] = {}
    end
    self:_loadWayPoints()
    print(self.activeTraceIndexes.." paths have been loaded")
end

function TraceManager:_onPlayerLeft(player)
    for i = 1, Config.maxTraceNumber do
        if self._tracePlayer[i] == player then
            self._tracePlayer[i] = nil
        end
    end
end

function TraceManager:startTrace(player, index)
    if index == 0 then
        for i = 1, Config.maxTraceNumber do
            if Globals.wayPoints[i][1] == nil then
                index = i
                break
            end
        end
    end
    if index > Config.maxTraceNumber or index < 1 then
        index = 1
    end
    
    print("!trace started")
    ChatManager:Yell("!trace "..index.." started", 5.5)
    self:_clearTrace(index)
    self._traceUpdateTimer[index] = 0
    self._tracePlayer[index] = player
end

function TraceManager:endTrace(player)
    print("!trace done")
    ChatManager:Yell("!trace done", 5.5)
    self.activeTraceIndexes = self.activeTraceIndexes + 1
    for i = 1, Config.maxTraceNumber do
        if self._tracePlayer[i] == player then
            self._tracePlayer[i] = nil
        end
    end
end

function TraceManager:setPoint(player, index)
    print("!setpoint")
    ChatManager:Yell("!setpoint", 5.5)
    local point = WayPoint()
    point.trans = player.soldier.transform.trans
    table.insert(Globals.wayPoints[index], point)
end

function TraceManager:clearTrace(index)
    print("!cleartrace")
    ChatManager:Yell("!cleartrace "..index, 5.5)
    self:_clearTrace(index)
end

function TraceManager:clearAllTraces()
    print("!clearalltraces")
    ChatManager:Yell("!clearalltraces", 5.5)
    for i = 1, Config.maxTraceNumber do
        self:_clearTrace(i)
    end
    self.activeTraceIndexes = 0
end

function TraceManager:savePaths()
    self:_saveWayPoints()
end

function TraceManager:_clearTrace(traceIndex)
    if traceIndex < 1 or traceIndex > Config.maxTraceNumber then
        return
    end
    if Globals.wayPoints[traceIndex][1] ~= nil then
        self.activeTraceIndexes = self.activeTraceIndexes - 1
    end
    Globals.wayPoints[traceIndex] = {}
end

function TraceManager:_onUpdate(dt)
    --trace way if wanted
    for i = 1, Config.maxTraceNumber do
        if self._tracePlayer[i] ~= nil then
            self._traceUpdateTimer[i] = self._traceUpdateTimer[i] + dt
            if self._traceUpdateTimer[i] >= Config.traceDelta then
                self._traceUpdateTimer[i] = 0
                local player = self._tracePlayer[i]

                local MoveMode = 0 -- 0 = wait, 1 = prone ... (4 Bits)
                local MoveAddon = 0 -- 0 = nothing, 1 = jump ... (4 Bits)
                local vlaue = 0 -- waittime in 0.5 s (0-255) (8 Bits)

                local point = WayPoint()
                point.trans = player.soldier.transform.trans

                --trace movement with primary weapon
                if player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_0 then
                    self._traceWaitTimer[i] = 0
                    if player.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then --record only if moving
                        if player.soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
                            MoveMode = 1
                        elseif player.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
                            MoveMode = 2
                        else
                            MoveMode = 3
                            if player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
                                MoveMode = 4
                            end
                        end

                        if player.input:GetLevel(EntryInputActionEnum.EIAJump) == 1 then
                            MoveAddon = 1
                        end

                        local inputVar = MoveMode + (MoveAddon << 4) + (vlaue << 8)
                        point.inputVar = inputVar
                        table.insert(Globals.wayPoints[i], point)
                    end
                -- trace wait time with secondary weapon
                elseif player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_1 then
                    if self._traceWaitTimer[i] == 0 or self._traceWaitTimer[i] == nil then
                        self._traceWaitTimer[i] = 0
                        table.insert(Globals.wayPoints[i], point)
                    end
                    self._traceWaitTimer[i] =  self._traceWaitTimer[i] + Config.traceDelta
                    local inputVar = 0 + (math.floor(tonumber(self._traceWaitTimer[i])) & 0xFF) << 8
                    Globals.wayPoints[i][#Globals.wayPoints[i]].inputVar = inputVar
                end
            end
        end
    end
end

function TraceManager:_loadWayPoints()
    if not SQL:Open() then
        return
    end

    local query = [[
        CREATE TABLE IF NOT EXISTS ]]..self._mapName..[[_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pathIndex INTEGER,
        pointIndex INTEGER,
        transX FLOAT,
        transY FLOAT,
        transZ FLOAT,
        inputVar INTEGER
        )
    ]]
    if not SQL:Query(query) then
        print('Failed to execute query: ' .. SQL:Error())
        return
    end

    -- Fetch all rows from the table.
    local results = SQL:Query('SELECT * FROM '..self._mapName..'_table')

    if not results then
        print('Failed to execute query: ' .. SQL:Error())
        return
    end

    -- clear waypoints
    Globals.wayPoints = {}
    for i = 1, Config.maxTraceNumber do
        Globals.wayPoints[i] = {}
    end

    -- Load the fetched rows.
    local nrOfPaths = 0
    for _, row in pairs(results) do
        local pathIndex = row["pathIndex"]
        if pathIndex > nrOfPaths then
            nrOfPaths = pathIndex
        end
        local pointIndex = row["pointIndex"]
        local transX = row["transX"]
        local transY = row["transY"]
        local transZ = row["transZ"]
        local inputVar = row["inputVar"]
        local point = WayPoint()
        point:setValues(transX, transY, transZ, inputVar)
        Globals.wayPoints[pathIndex][pointIndex] = point
    end
    self.activeTraceIndexes = nrOfPaths
    SQL:Close()
    print("LOAD - The waypoint list has been loaded.")
end

function TraceManager:_saveWayPoints()
    if not SQL:Open() then
        print("failed to save")
        return
    end
    local query = [[DROP TABLE IF EXISTS ]]..self._mapName..[[_table]]
    if not SQL:Query(query) then
        print('Failed to execute query: ' .. SQL:Error())
        return
    end
    query = [[
        CREATE TABLE IF NOT EXISTS ]]..self._mapName..[[_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pathIndex INTEGER,
        pointIndex INTEGER,
        transX FLOAT,
        transY FLOAT,
        transZ FLOAT,
        inputVar INTEGER
        )
    ]]
    if not SQL:Query(query) then
        print('Failed to execute query: ' .. SQL:Error())
        return
    end
    query = 'INSERT INTO '..self._mapName..'_table (pathIndex, pointIndex, transX, transY, transZ, inputVar) VALUES '
    local pathIndex = 0
    for oldPathIndex = 1, Config.maxTraceNumber do
        local pointsDone = 0
        local maxPointsInOneQuery = 1000
        local errorActive = false
        if Globals.wayPoints[oldPathIndex][1] ~= nil then
            pathIndex = pathIndex + 1
            while #Globals.wayPoints[oldPathIndex] > pointsDone and not errorActive do
                local pointsToTo = #Globals.wayPoints[oldPathIndex] - pointsDone
                if pointsToTo > maxPointsInOneQuery then
                    pointsToTo = maxPointsInOneQuery
                end

                local sqlValuesString = ""
                for pointIndex = 1 + pointsDone, pointsToTo + pointsDone do
                    local trans = Vec3()
                    trans = Globals.wayPoints[oldPathIndex][pointIndex].trans
                    local transX = trans.x
                    local transY = trans.y
                    local transZ = trans.z
                    local inputVar = Globals.wayPoints[oldPathIndex][pointIndex].inputVar
                    local inerString = "("..pathIndex..","..pointIndex..","..tostring(transX)..","..tostring(transY)..","..tostring(transZ)..","..tostring(inputVar)..")"
                    sqlValuesString = sqlValuesString..inerString
                    if pointIndex < pointsToTo + pointsDone then
                        sqlValuesString = sqlValuesString..","
                    end
                end
                if not SQL:Query(query..sqlValuesString) then
                    print('Failed to execute query: ' .. SQL:Error())
                    return
                end
                pointsDone = pointsDone + pointsToTo
            end
        end
    end

    -- Fetch all rows from the table.
    local results = SQL:Query('SELECT * FROM '..self._mapName..'_table')

    if not results then
        print('Failed to execute query: ' .. SQL:Error())
		ChatManager:Yell("Failed to execute query: " .. SQL:Error(), 5.5)
        return
    end

    SQL:Close()
    print("SAVE - The waypoint list has been saved.")
	ChatManager:Yell("The waypoint list has been saved", 5.5)
end


-- Singleton.
if g_TraceManager == nil then
	g_TraceManager = TraceManager()
end

return g_TraceManager