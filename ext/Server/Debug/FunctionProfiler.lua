---@class FunctionProfiler
---@overload fun():FunctionProfiler
FunctionProfiler = class('FunctionProfiler')

-- Debug-profiling of single functions, only with Registry.DEBUG.ROUND_STATS_INTERVAL > 0: wraps the functions below
-- and sums their time and allocations into the profile of the BotManager. Printed with the round-stats.
-- The times are inclusive: a function contains the time of the functions it calls.
-- The timer of the server has a resolution of 1 ms, so single calls are not exact, but the sums over many calls are.

-- { class-name, instance-name or nil, { methods } }
local TARGETS = {
	{ 'Bot', nil, {
		'UpdateNormalMovement', 'UpdateShootMovement', 'UpdateMovementSprintToTarget', 'UpdateTargetMovement',
		'UpdateSpeedOfMovement', '_UpdateInputs', 'UpdateWeaponSelection', 'UpdateDeployAndReload', 'UpdateAiming',
		'UpdateAttacking', '_DetectObstacle', '_ObstacleHandling', '_JumpDetection', '_HandleSidwardsMovement',
		'_CheckAndDoPathSwitch', '_CheckForAction', '_CheckForVehicleActions', '_SetActiveVars', '_SetActiveVarsSlow',
		'_GetPathOffsetEntry', 'ApplyPathOffset', 'LookAround', 'UpdateObjective', 'ShootAt',
		'DeployIfPossible', 'UpdateDontAttackFlag', 'FindVehiclePath', '_UpdateRespawn', 'GetAttackDistance',
	} },
	{ 'VehicleMovement', 'g_VehicleMovement', {
		'UpdateNormalMovementVehicle', 'UpdateShootMovementVehicle', 'UpdateSpeedOfMovementVehicle',
		'UpdateTargetMovementVehicle', 'UpdateYawVehicle', '_DetectObstacle', 'UpdateVehicleLookAround',
	} },
	{ 'VehicleAiming', 'g_VehicleAiming', { 'UpdateAimingVehicle' } },
	{ 'VehicleAttacking', 'g_VehicleAttacking', { 'UpdateAttackingVehicle', 'UpdateAttackStationaryAAVehicle' } },
	{ 'VehicleWeaponHandling', 'g_VehicleWeaponHandling', { 'UpdateWeaponSelectionVehicle', 'UpdateReloadVehicle' } },
	{ 'VehicleJetControl', 'g_VehicleJetControl', { 'UpdateMovementJet', 'UpdateYawJet' } },
	{ 'VehicleChopperControl', 'g_VehicleChopperControl', {
		'UpdateMovementChopper', 'UpdateTargetMovementChopper', 'UpdateYawChopperPilot',
	} },
	{ 'BotManager', 'g_BotManager', {
		'_CheckForBotBotAttack', '_DispatchRaycastsBotBotAttack', '_CheckForBotBotRevive', 'OnSoldierDamage',
		'OnClientRaycastResults', 'RefreshTables', 'CreateBot', 'SpawnBot', 'GetKitCount',
	} },
	{ 'ServerRaycasts', 'g_ServerRaycasts', { 'CheckSight', 'UpdatePlayerChecks' } },
	{ 'GameDirector', 'g_GameDirector', { 'OnEngineUpdate', 'FindClosestPath' } },
	{ 'BotSpawner', 'g_BotSpawner', {
		'OnEngineUpdate', 'UpdateBotAmountAndTeam', '_SpawnSingleWayBot', '_GetSpawnPoint', '_SpawnBot', '_SelectLoadout',
		'_SetBotWeapons', '_SetKitAndAppearance', '_GetCustomization', '_TriggerSpawn', '_ApplyKitLimit',
	} },
	{ 'DebugBridge', 'g_DebugBridge', { 'OnEngineUpdate', '_TakeSnapshot', '_Send' } },
}

---@param p_Name string
---@param p_Start number
---@param p_Mem number
---@return ...
local function _Record(p_Name, p_Start, p_Mem, ...)
	local s_Profile = g_BotManager and g_BotManager._ProfileStats
	if s_Profile then
		local s_Functions = s_Profile.Functions
		if s_Functions == nil then
			s_Functions = {}
			s_Profile.Functions = s_Functions
		end
		local s_Entry = s_Functions[p_Name]
		if s_Entry == nil then
			s_Entry = { Total = 0, Count = 0, AllocKb = 0 }
			s_Functions[p_Name] = s_Entry
		end
		s_Entry.Total = s_Entry.Total + (SharedUtils:GetTimeNS() - p_Start) / 1000000
		s_Entry.Count = s_Entry.Count + 1
		-- Only exact while no GC step runs inside, otherwise freed memory is subtracted.
		s_Entry.AllocKb = s_Entry.AllocKb + math.max(0, collectgarbage("count") - p_Mem)
	end
	return ...
end

---@param p_Name string
---@param p_Function function
---@return function
local function _Wrap(p_Name, p_Function)
	return function(...)
		-- The arguments are evaluated in order: start-time and memory before the call.
		return _Record(p_Name, SharedUtils:GetTimeNS(), collectgarbage("count"), p_Function(...))
	end
end

function FunctionProfiler:__init()
	if Registry.DEBUG.ROUND_STATS_INTERVAL <= 0 then
		return
	end

	local s_Count = 0
	for l_Index = 1, #TARGETS do
		local l_Target = TARGETS[l_Index]
		local s_Class = _G[l_Target[1]]
		local s_Instance = l_Target[2] and _G[l_Target[2]] or nil

		for _, l_Method in ipairs(l_Target[3]) do
			local s_Name = l_Target[1] .. ':' .. l_Method
			-- Wrap the class for new instances and the instance for the existing singleton.
			if s_Class ~= nil and type(s_Class[l_Method]) == 'function' then
				s_Class[l_Method] = _Wrap(s_Name, s_Class[l_Method])
				s_Count = s_Count + 1
			end
			if s_Instance ~= nil and type(s_Instance[l_Method]) == 'function' then
				s_Instance[l_Method] = s_Class ~= nil and s_Class[l_Method] or _Wrap(s_Name, s_Instance[l_Method])
			end
		end
	end

	-- The collectors of the debug-bridge are registered as callbacks.
	local s_Bridge = _G['g_DebugBridge']
	if s_Bridge ~= nil then
		for _, l_Collector in ipairs(s_Bridge._Collectors) do
			l_Collector.Callback = _Wrap('Collector:' .. l_Collector.Name, l_Collector.Callback)
			s_Count = s_Count + 1
		end
	end
	if json ~= nil and type(json.encode) == 'function' then
		json.encode = _Wrap('json.encode', json.encode) -- luacheck: ignore 122
		s_Count = s_Count + 1
	end

	print('[FunctionProfiler] ' .. s_Count .. ' functions wrapped')
end

if g_FunctionProfiler == nil then
	---@type FunctionProfiler
	g_FunctionProfiler = FunctionProfiler()
end

return g_FunctionProfiler
