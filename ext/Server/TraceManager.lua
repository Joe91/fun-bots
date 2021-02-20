class('TraceManager');

require('Waypoint');
require('__shared/Config');
require('Globals');

function TraceManager:__init()
	self._tracePlayer		= {};
	self._traceStatePlayer	= {}; --0 inactive, 1 started
	self._traceUpdateTimer	= {};
	self._traceWaitTimer	= {};
	self._mapName			= '';

	Events:Subscribe('Engine:Update', self, self._onUpdate);
	Events:Subscribe('Player:Left', self, self._onPlayerLeft);
	NetEvents:Subscribe('ClientEndTraceResponse', self, self._onClientEndTraceResponse);
end

function TraceManager:onLevelLoaded(levelName, gameMode)
	SQL:Close();
	if g_Globals.isTdm or g_Globals.isGm or g_Globals.isScavenger then
		gameMode = 'TeamDeathMatch0';
	end
	
	self._mapName = levelName .. '_' .. gameMode;
	self:loadPaths();
end

function TraceManager:loadPaths()
	for i = 1, MAX_TRACE_NUMBERS do
		g_Globals.wayPoints[i] = {};
	end

	self:_loadWayPoints();

	print(g_Globals.activeTraceIndexes .. ' paths have been loaded');
end

function TraceManager:onUnload()
	for i = 1, MAX_TRACE_NUMBERS do
		g_Globals.wayPoints[i] = {};
	end

	NetEvents:Send('UI_Trace', 'false');
	g_Globals.activeTraceIndexes = 0;
end

function TraceManager:_checkForValidUsage(player)
	if player ~= nil then
		if self._traceStatePlayer[player.name] == nil then
			self._traceStatePlayer[player.name] = 0;
		end
	end

	if not Config.traceUsageAllowed then
		return false;
	end

	return true;
end

function TraceManager:_onPlayerLeft(player)
	self._traceStatePlayer[player.name] = nil;

	for i = 1, MAX_TRACE_NUMBERS do
		if self._tracePlayer[i] == player then
			self._tracePlayer[i] = nil;
		end
	end
end

function TraceManager:getTraceState(player)
	if self._traceStatePlayer[player.name] == nil then
		self._traceStatePlayer[player.name] = 0;
	end

	return self._traceStatePlayer[player.name];
end

function TraceManager:startTrace(player, index)
	if not self:_checkForValidUsage(player) then
		return
	end

	if  self._traceStatePlayer[player.name] ~= 0 then  --trace still running
		for i = 1, MAX_TRACE_NUMBERS do
			if self._tracePlayer[i] == player then
				self._tracePlayer[i] = nil;
				g_Globals.wayPoints[i] = {};
			end
		end
	end

	if index == 0 then
		for i = 1, MAX_TRACE_NUMBERS do
			if g_Globals.wayPoints[i][1] == nil then
				index = i;
				break
			end
		end
	end

	if index > MAX_TRACE_NUMBERS or index < 1 then
		index = 1;
	end

	self:_clearTrace(index);
	self._traceUpdateTimer[index]		= 0;
	self._tracePlayer[index]			= player;
	self._traceStatePlayer[player.name]	= 1; --trace started
	self:_generateAndInsertPoint(player, index); --create first point, to block this trace
	print('Trace ' .. index .. ' started');
	NetEvents:SendToLocal('UI_Trace', player, 'true');
	NetEvents:SendToLocal('UI_Trace_Index', player, index);
	ChatManager:Yell(Language:I18N('Trace %d started', index), 2.5);
end

function TraceManager:endTrace(player)
	if not self:_checkForValidUsage(player) then
		return;
	end

	local traceIndex = 0;
	for i = 1, MAX_TRACE_NUMBERS do
		if self._tracePlayer[i] == player then
			traceIndex = i;
			break;
		end
	end

	if  self._traceStatePlayer[player.name] == 0 or traceIndex == 0 then
		return;
	end

	-- find out if trace is a roundway or not
	NetEvents:SendToLocal('UI_Trace', player, 'false');
	NetEvents:SendToLocal('UI_Trace_Index', player, 0);
	NetEvents:SendToLocal('ClientEndTraceRequest', player, g_Globals.wayPoints[traceIndex][1].trans, g_Globals.wayPoints[traceIndex][#g_Globals.wayPoints[traceIndex]].trans);
	-- continue with respone
end

function TraceManager:_onClientEndTraceResponse(player, isClearView)
	local traceIndex = 0;
	for i = 1, MAX_TRACE_NUMBERS do
		if self._tracePlayer[i] == player then
			traceIndex = i;
			break;
		end
	end

	if isClearView then
		g_Globals.wayPoints[traceIndex][1].optValue = 0  --normal behavior
	else
		g_Globals.wayPoints[traceIndex][1].optValue = 0XFF;  --signal, that the way needs to reverse its directon
	end

	print('Trace done');
	NetEvents:SendToLocal('UI_Trace', player, 'false');
	ChatManager:Yell(Language:I18N('Trace done'), 2.5);

	g_Globals.activeTraceIndexes = g_Globals.activeTraceIndexes + 1;

	self._tracePlayer[traceIndex] = nil;
	self._traceStatePlayer[player.name] = 0;
end

function TraceManager:clearTrace(index)
	if not self:_checkForValidUsage() then
		return;
	end

	print('clear trace');
	ChatManager:Yell(Language:I18N('Clearing Trace %d', index), 2.5);
	self:_clearTrace(index);
end

function TraceManager:clearAllTraces()
	if not self:_checkForValidUsage() then
		return;
	end

	print('Clearing all traces');
	ChatManager:Yell(Language:I18N("Clearing all traces"), 2.5);

	for i = 1, MAX_TRACE_NUMBERS do
		self:_clearTrace(i);
	end

	g_Globals.activeTraceIndexes = 0;
end

function TraceManager:savePaths()
	if not self:_checkForValidUsage() then
		return;
	end

	print('Trying to Save paths');
	ChatManager:Yell(Language:I18N('Trying to save paths check console...'), 2.5);
	self:_saveWayPoints();
	--local co = coroutine.create(function ()
	--	self:_saveWayPoints();
	--end)
	--coroutine.resume(co)
end

function TraceManager:_clearTrace(traceIndex)
	if traceIndex < 1 or traceIndex > MAX_TRACE_NUMBERS then
		return;
	end

	if g_Globals.wayPoints[traceIndex][1] ~= nil then
		g_Globals.activeTraceIndexes = g_Globals.activeTraceIndexes - 1;
	end

	g_Globals.wayPoints[traceIndex] = {};
end

function TraceManager:_onUpdate(dt)
	--trace way if wanted
	for i = 1, MAX_TRACE_NUMBERS do
		if self._tracePlayer[i] ~= nil then
			self._traceUpdateTimer[i] = self._traceUpdateTimer[i] + dt;

			if self._traceUpdateTimer[i] >= Config.traceDelta then
				self._traceUpdateTimer[i] = 0;
				self:_generateAndInsertPoint(self._tracePlayer[i], i);
			end
		end
	end
end

function TraceManager:_generateAndInsertPoint(player, traceIndex)
	local MoveMode	= 0; -- 0 = wait, 1 = prone ... (4 Bits)
	local MoveAddon	= 0; -- 0 = nothing, 1 = jump ... (4 Bits)
	local vlaue		= 0; -- waittime in 0.5 s (0-255) (8 Bits)
	local point		= WayPoint();
	if player.soldier ~= nil then
		point.trans		= player.soldier.worldTransform.trans:Clone();

		--trace movement with primary weapon
		if player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_0 then
			self._traceWaitTimer[traceIndex] = 0;

			if player.input:GetLevel(EntryInputActionEnum.EIAThrottle) > 0 then --record only if moving
				if player.soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
					MoveMode = 1;
				elseif player.soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
					MoveMode = 2;
				else
					MoveMode = 3;

					if player.input:GetLevel(EntryInputActionEnum.EIASprint) == 1 then
						MoveMode = 4;
					end
				end

				if player.input:GetLevel(EntryInputActionEnum.EIAJump) == 1 then
					MoveAddon = 1;
				end

				point.speedMode	= MoveMode;
				point.extraMode	= MoveAddon;
				point.optValue	= vlaue;

				table.insert(g_Globals.wayPoints[traceIndex], point);
			end

		-- trace wait time with secondary weapon
		elseif player.soldier.weaponsComponent.currentWeaponSlot == WeaponSlot.WeaponSlot_1 then
			if self._traceWaitTimer[traceIndex] == 0 or self._traceWaitTimer[traceIndex] == nil then
				self._traceWaitTimer[traceIndex] = 0;
				table.insert(g_Globals.wayPoints[traceIndex], point);
			end

			self._traceWaitTimer[traceIndex]	= self._traceWaitTimer[traceIndex] + Config.traceDelta;
			local waitValue						= math.floor(tonumber(self._traceWaitTimer[traceIndex]));

			g_Globals.wayPoints[traceIndex][#g_Globals.wayPoints[traceIndex]].optValue = waitValue;
		end
	end
end

function TraceManager:_setWaypointWithInputVar(point, inputVar)
	point.speedMode	= inputVar & 0xF;
	point.extraMode	= (inputVar >> 4) & 0xF;
	point.optValue	= (inputVar >> 8) & 0xFF;
end

function TraceManager:_getInputVar(point)
	return (point.speedMode & 0xF) + ((point.extraMode & 0xF)<<4) + ((point.optValue & 0xFF) <<8);
end

function TraceManager:_loadWayPoints()
	if not SQL:Open() then
		return;
	end

	local query = [[
		CREATE TABLE IF NOT EXISTS ]] .. self._mapName .. [[_table (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		pathIndex INTEGER,
		pointIndex INTEGER,
		transX FLOAT,
		transY FLOAT,
		transZ FLOAT,
		inputVar INTEGER,
		data TEXT
		)
	]]

	if not SQL:Query(query) then
		print('Failed to execute query: ' .. SQL:Error());
		return;
	end

	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM ' .. self._mapName .. '_table');

	if not results then
		print('Failed to execute query: ' .. SQL:Error());
		return;
	end

	-- clear waypoints
	g_Globals.wayPoints = {};

	for i = 1, MAX_TRACE_NUMBERS do
		g_Globals.wayPoints[i] = {};
	end

	-- Load the fetched rows.
	local nrOfPaths = 0;

	for _, row in pairs(results) do
		local pathIndex = row["pathIndex"];

		if pathIndex > nrOfPaths then
			nrOfPaths = pathIndex;
		end

		local pointIndex	= row["pointIndex"];
		local transX		= row["transX"];
		local transY		= row["transY"];
		local transZ		= row["transZ"];
		local inputVar		= row["inputVar"];
		local point			= WayPoint();
		point.trans			= Vec3(transX, transY, transZ);
		point.data 			= json.decode(row['data'] or '{}')

		self:_setWaypointWithInputVar(point, inputVar);

		g_Globals.wayPoints[pathIndex][pointIndex] = point;
	end

	g_Globals.activeTraceIndexes = nrOfPaths;
	SQL:Close();
	print('LOAD - The waypoint list has been loaded.');
end

function TraceManager:_saveWayPoints()
	if not SQL:Open() then
		print('failed to save');
		return;
	end

	local query = [[DROP TABLE IF EXISTS ]] .. self._mapName .. [[_table]]

	if not SQL:Query(query) then
		print('Failed to execute query: ' .. SQL:Error());
		return
	end

	query = [[
		CREATE TABLE IF NOT EXISTS ]] .. self._mapName .. [[_table (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		pathIndex INTEGER,
		pointIndex INTEGER,
		transX FLOAT,
		transY FLOAT,
		transZ FLOAT,
		inputVar INTEGER,
		data TEXT
		)
	]]

	if not SQL:Query(query) then
		print('Failed to execute query: ' .. SQL:Error());
		return;
	end

	query				= 'INSERT INTO ' .. self._mapName .. '_table (pathIndex, pointIndex, transX, transY, transZ, inputVar, data) VALUES ';
	local pathIndex		= 0;

	for oldPathIndex = 1, MAX_TRACE_NUMBERS do
		local pointsDone			= 0;
		local maxPointsInOneQuery	= 1000;
		local errorActive			= false;

		if (g_Globals.wayPoints[oldPathIndex] == nil) then
			print('WARNING! Path ['..oldPathIndex..'] is nil!')
		else

			if g_Globals.wayPoints[oldPathIndex][1] ~= nil then
				pathIndex = pathIndex + 1;

				while #g_Globals.wayPoints[oldPathIndex] > pointsDone and not errorActive do
					local pointsToTo = #g_Globals.wayPoints[oldPathIndex] - pointsDone;

					if pointsToTo > maxPointsInOneQuery then
						pointsToTo = maxPointsInOneQuery;
					end

					local sqlValuesString = '';

					for pointIndex = 1 + pointsDone, pointsToTo + pointsDone do

						local waypoint = g_Globals.wayPoints[oldPathIndex][pointIndex]

						if (waypoint == nil) then
							print('WARNING! Node ['..oldPathIndex..']['..pointIndex..'] is nil!')
						else

							local trans			= waypoint.trans;
							local inputVar		= self:_getInputVar(waypoint);
							local data			= ''
							if (waypoint.data ~= nil and type(waypoint.data) == 'table') then
								local _data, encodeError = json.encode(waypoint.data)
								if (_data == nil) then
									print('WARNING! Node ['..oldPathIndex..']['..pointIndex..'] data could not encode: '..tostring(encodeError))
								end
								if (_data ~= '{}') then
									data = SQL:Escape(table.concat(_data:split('"'), '""'))
								end
							end

							sqlValuesString		= sqlValuesString..'('..table.concat({pathIndex, pointIndex, trans.x, trans.y, trans.z, inputVar, '"'..data..'"'}, ',')..')';

							if pointIndex < pointsToTo + pointsDone then
								sqlValuesString = sqlValuesString .. ',';
							end
						end
					end

					if not SQL:Query(query..sqlValuesString) then
						print('Failed to execute query: ' .. SQL:Error());
						return;
					end

					pointsDone = pointsDone + pointsToTo;
				end
			end
		end
	end

	-- Fetch all rows from the table.
	local results = SQL:Query('SELECT * FROM ' .. self._mapName .. '_table');

	if not results then
		print('Failed to execute query: ' .. SQL:Error());
		ChatManager:Yell(Language:I18N('Failed to execute query: %s', SQL:Error()), 5.5);
		return;
	end

	SQL:Close();
	print('SAVE - The waypoint list has been saved.');
	ChatManager:Yell(Language:I18N('The waypoint list has been saved'), 5.5);
end


-- Singleton.
if g_TraceManager == nil then
	g_TraceManager = TraceManager();
end

return g_TraceManager;