class('PathSwitcher');
require('__shared/NodeCollection')

function PathSwitcher:__init()
	self.dummyData = 0;
end

function PathSwitcher:getNewPath(point, objective)
	if point.Data == nil or point.Data.Links == nil or #point.Data.Links < 1 then
		return false
	end

	-- i have an objective to get to, this takes priority over all
	if (objective ~= '') then
		print('my objective: '..objective)

		local checkedPaths = {}

		-- loop through each link
		for i=1, #point.Data.Links do

			local newPoint = g_NodeCollection:Get(point.Data.Links[i])

			-- don't double-check paths
			if (newPoint ~= nil and checkedPaths[newPoint.PathIndex] ~= true) then
				checkedPaths[newPoint.PathIndex] = true

				local pathNode = g_NodeCollection:GetFirst(newPoint.PathIndex)
				local myPathNode = g_NodeCollection:GetFirst(point.PathIndex)

				-- this path has listed objectives
				print('path ['..newPoint.PathIndex..'] has objectives: '..g_Utilities:dump(pathNode.Data.Objectives))
				if (pathNode.Data.Objectives ~= nil) then

					-- always select a path with a single objective that matches mine
					if (#pathNode.Data.Objectives == 1 and pathNode.Data.Objectives[1] == objective and
						#myPathNode.Data.Objectives == 1 and myPathNode.Data.Objectives[1] == objective) then
						print('found another path with 1 objective that matches mine, retry selection for random choice')
						return self:getNewPath(point, '') -- retry selection, but with no objective

					-- otherwise, check if the path has an objective i want
					else
						-- loop through the path's objectives and compare to mine
						for _,pathObjective in pairs(pathNode.Data.Objectives) do
							-- this path is where i want to go
							if (objective == pathObjective) then
								print('this path is where i want to go')
								return true, newPoint.PathIndex, newPoint.PointIndex
							end 
						end
					end
				end
			end
		end

		-- nothing better found, don't change

		print('nothing better found, dont change')
		return false

	-- no objectives found or none to look for
	else

		local linkMode = tonumber(point.Data.LinkMode) or 0
		if linkMode == 0 then -- random path switch

			local chance = tonumber(point.Data.LinkChance) or 25
			local randNum = MathUtils:GetRandomInt(0, 100)

			if randNum >= chance then
				local linkID = point.Data.Links[MathUtils:GetRandomInt(1, #point.Data.Links)];
				local newPoint = g_NodeCollection:Get(linkID)
				if newPoint ~= nil then
					print('chose to switch at random ('..randNum..' >= '..chance..')')
					return true, newPoint.PathIndex, newPoint.PointIndex;
				end
			end
		elseif linkMode == 1 then -- some other kind of switching decision
			-- etc...
		end
	end

	-- don't switch at all
	print('chose not to switch')
	return false;
end



-- Singleton.
if g_PathSwitcher == nil then
	g_PathSwitcher = PathSwitcher();
end

return g_PathSwitcher;