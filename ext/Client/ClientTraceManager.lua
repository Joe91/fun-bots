class('ClientTraceManager');

function ClientTraceManager:__init()
	NetEvents:Subscribe('ClientEndTraceRequest', self, self._endTrace);
end

function ClientTraceManager:_endTrace(pos1, pos2)
	--check for clear view to startpoint
	local clearView = false;
	local startPos 	= Vec3(pos1.x, pos1.y + 1.0, pos1.z);
	local endPos 	= Vec3(pos2.x, pos2.y + 1.0, pos2.z);
	local raycast	= RaycastManager:Raycast(startPos, endPos, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter| RayCastFlags.IsAsyncRaycast);

	if (raycast == nil or raycast.rigidBody == nil) then
		clearView = true;
	end
	NetEvents:SendLocal('ClientEndTraceResponse', clearView);
end


-- Singleton.
if g_ClientTraceManager == nil then
	g_ClientTraceManager = ClientTraceManager();
end

return g_ClientTraceManager;