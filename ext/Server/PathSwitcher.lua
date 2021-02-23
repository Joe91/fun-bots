class('PathSwitcher');
require('__shared/NodeCollection')

function PathSwitcher:__init()
	self.dummyData = 0;
end

function PathSwitcher:getNewPath(point, objective)
	if point.Data ~= nil and point.Data.Links ~= nil and #point.Data.Links > 0 then
		if point.Data.LinkMode >= 0 then -- random PathSwitcher

			local chance = tonumber(point.Data.LinkChance) or 50

			if MathUtils:GetRandomInt(0, 100) >= chance then -- only swith every time :-)
				local link = point.Data.Links[MathUtils:GetRandomInt(1, #point.Data.Links)];
				--print(link..' chosen with '..chance..'% chance')
				local newPoint = g_NodeCollection:Get(link)
				if newPoint ~= nil then
					return true, newPoint.PathIndex, newPoint.PointIndex;
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