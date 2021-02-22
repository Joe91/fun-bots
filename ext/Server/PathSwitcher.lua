class('PathSwitcher');
require('__shared/NodeCollection')

function PathSwitcher:__init()
	self.dummyData = 0;
end

function PathSwitcher:getNewPath(point, objective)
	if point.Data ~= nil and point.Data.Links ~= nil and #point.Data.Links > 0 then
		print(point.Data)
		if point.Data.LinkMode >= 0 then -- random PathSwitcher
			if MathUtils:GetRandomInt(1, 100) > 0 then -- only swith every time :-)
				local link = point.Data.Links[MathUtils:GetRandomInt(1, #point.Data.Links)];
				print(link)
				--local point = g_NodeCollection.waypointsByID[link[2]]
				local newPoint = g_NodeCollection:Get(link)
				if newPoint~= nil then
					print("switch done")
					return true, newPoint.PathIndex, newPoint.PointIndex;
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