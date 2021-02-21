class('PathSwitcher');

--require('NodeEditor');

function PathSwitcher:__init()
	self.dummyData = 0;
end

function PathSwitcher:getNewPath(data, currentPath, currentPoint, objective)
	if data ~= nil and data.links ~= nil then
		print("data")
		--if data.LinkMode >= 0 then -- random PathSwitcher
			if MathUtils:GetRandomInt(1, 100) > 0 then -- only swith every time :-)
				local point = g_NodeCollection.waypointsByID[data.links[MathUtils:GetRandomInt(1,#data.links)]]
				return true, point.PathIndex, point.PointIndex;
			end
		--end
	end
	return false;
end



-- Singleton.
if g_PathSwitcher == nil then
	g_PathSwitcher = PathSwitcher();
end

return g_PathSwitcher;