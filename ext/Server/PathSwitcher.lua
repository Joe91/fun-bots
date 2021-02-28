class('PathSwitcher');
require('__shared/NodeCollection')
require('GameDirector')

function PathSwitcher:__init()
	self.dummyData = 0;
end

function PathSwitcher:getNewPath(point, objective)
	-- check if on base, or on path away from base. In this case: change path
	local isBasePath = false;
	local currentPathFirst = g_NodeCollection:GetFirst(point.PathIndex);
	local currentPathStatus = 0;
	if currentPathFirst.Data ~= nil and currentPathFirst.Data.Objectives ~= nil then
		currentPathStatus = g_GameDirector:getEnableSateOfPath(currentPathFirst.Data.Objectives)
		isBasePath = g_GameDirector:isBasePath(currentPathFirst.Data.Objectives)
	end

	if point.Data == nil or point.Data.Links == nil or #point.Data.Links < 1 then
		return false
	end

	-- TODO get all paths via links, assign priority, sort by priority
	-- if multiple are top priority, choose at random

	objective = objective or ''
	local paths = {}
	local highestPriority = 0
	local currentPriority = 0

	local possiblePaths = {}
	table.insert(possiblePaths, point) -- include our current path
	for i=1, #point.Data.Links do
		local newPoint = g_NodeCollection:Get(point.Data.Links[i])
		if (newPoint ~= nil) then
			table.insert(possiblePaths, newPoint)
		end
	end
	
	-- loop through each possible path
	for i=1, #possiblePaths do

		local newPathStatus = 0;
		local newPoint = possiblePaths[i]
		local pathNode = g_NodeCollection:GetFirst(newPoint.PathIndex)

		-- this path has listed objectives
		if (pathNode.Data.Objectives ~= nil and objective ~= '') then
			newPathStatus = g_GameDirector:getEnableSateOfPath(pathNode.Data.Objectives)
			local switchFromInactive = newPathStatus > currentPathStatus;
			-- path with a single objective that matches mine, top priority
			if (#pathNode.Data.Objectives == 1 and pathNode.Data.Objectives[1] == objective) or isBasePath then
				if (highestPriority < 2) then highestPriority = 2 end
				table.insert(paths, {
					Priority = 2,
					Point = newPoint
				})
				if (newPoint.ID == point.ID) then
					currentPriority = 2
				end
			-- otherwise, check if the path has an objective i want
			else
				-- loop through the path's objectives and compare to mine
				for _,pathObjective in pairs(pathNode.Data.Objectives) do
					if (objective == pathObjective) or isBasePath or switchFromInactive then
						if (highestPriority < 1) then highestPriority = 1 end
						table.insert(paths, {
							Priority = 1,
							Point = newPoint
						})
						if (newPoint.ID == point.ID) then
							currentPriority = 1
						end
					end
				end
			end
		else
			--path has no objectives, lowest priority
			table.insert(paths, {
				Priority = 0,
				Point = newPoint
			})
			if (newPoint.ID == point.ID) then
				currentPriority = 0
			end
		end
	end

	-- remove paths below our highest priority
	local validPaths = {}
	for i=1, #paths do
		if (paths[i].Priority >= highestPriority) then
			table.insert(validPaths, paths[i])
		end
	end

	--print('Trimmed Priority List -> '..g_Utilities:dump(paths, true, 2))
	--print('Highest Priority -> '..highestPriority)
	--print('#paths -> '..(#paths))

	if (#validPaths == 0) then
		return false
	end

	if (#validPaths == 1 and currentPriority < validPaths[1].Priority) then
		--print('found single higher priority path ( '..currentPriority..' | '..validPaths[1].Priority..' )')
		return true, validPaths[1].Point
	end

	local linkMode = tonumber(point.Data.LinkMode) or 0
	if linkMode == 0 then -- random path switch

		local chance = tonumber(point.Data.LinkChance) or 25
		local randNum = MathUtils:GetRandomInt(0, 100)
		local randIndex = MathUtils:GetRandomInt(1, #validPaths)

		if currentPriority < highestPriority then
			local randomPath = validPaths[randIndex]
			if randomPath == nil then
				print('[A] validPaths['..randIndex..'] was nil : '..g_Utilities:dump(validPaths, true, 2))
				return false
			end
			--print('found multiple higher priority validPaths | Priority: ( '..currentPriority..' | '..highestPriority..' )')
			return true, randomPath.Point
		end

		if randNum >= chance then
			local randomPath = validPaths[randIndex]
			if randomPath == nil then
				print('[B] validPaths['..randIndex..'] was nil : '..g_Utilities:dump(validPaths, true, 2))
				return false
			end
			--print('chose to switch at random ('..randNum..' >= '..chance..') | Priority: ( '..currentPriority..' | '..randomPath.Priority..' )')
			return true, randomPath.Point
		end
	elseif linkMode == 1 then -- some other kind of switching decision
		-- etc...
	end

	--print('dont change')
	return false
end



-- Singleton.
if g_PathSwitcher == nil then
	g_PathSwitcher = PathSwitcher();
end

return g_PathSwitcher;