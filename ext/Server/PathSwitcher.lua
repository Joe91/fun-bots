class('PathSwitcher');

--require('NodeEditor');

function PathSwitcher:__init()
	self.dummyData = 0;
end

function PathSwitcher:getNewPath(data, currentPath, currentPoint, objective)
	if data ~= nil and data.Links ~= nil and #data.Links > 0 then
		if data.LinkMode >= 0 then -- random PathSwitcher
			if MathUtils:GetRandomInt(1, 100) > 0 then -- only swith every time :-)
				local link = data.Links[MathUtils:GetRandomInt(1, #data.Links)];
				print(link[2])
				local point = g_NodeCollection.waypointsByID[link[2]]
				if point~= nil then
					print("switch done")
					return true, point.PathIndex, point.PointIndex;
				else
					print("point not available")
				end
			end
		end
	end
	return false;
end



-- Singleton.
if g_PathSwitcher == nil then
	g_PathSwitcher = PathSwitcher();
end

return g_PathSwitcher;