class('PathSwitcher');
require('__shared/NodeCollection')
require('GameDirector')
require('Globals')

function PathSwitcher:__init()
	self.dummyData = 0;
	self.killYourselfCounter = {}
end

function PathSwitcher:getNewPath(botname, point, objective)
	-- check if on base, or on path away from base. In this case: change path
	local onBasePath = false;
	local currentPathFirst = g_NodeCollection:GetFirst(point.PathIndex);
	local currentPathStatus = 0;
	if currentPathFirst.Data ~= nil and currentPathFirst.Data.Objectives ~= nil then
		currentPathStatus = g_GameDirector:getEnableSateOfPath(currentPathFirst.Data.Objectives)
		onBasePath = g_GameDirector:isBasePath(currentPathFirst.Data.Objectives)
	end

	if point.Data == nil or point.Data.Links == nil or #point.Data.Links < 1 then
		return false
	end

	if g_Globals.isRush then
		if self.killYourselfCounter[botname] == nil then
			self.killYourselfCounter[botname] = 0
		end
		if currentPathStatus == 0 then
			self.killYourselfCounter[botname] = self.killYourselfCounter[botname] + 1;
		else
			self.killYourselfCounter[botname] = 0
		end
		if self.killYourselfCounter[botname] > 20 then
			local bot = PlayerManager:GetPlayerByName(botname)
			if bot ~= nil and bot.soldier ~= nil then
				bot.soldier:Kill()
				self.killYourselfCounter[botname] = 0
				if Debug.Server.PATH then
					print("kill "..botname.." because of inactivity on wrong paths")
				end
				return false
			end
		end
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
		local newPoint = possiblePaths[i]
		local pathNode = g_NodeCollection:GetFirst(newPoint.PathIndex)
		local newPathStatus = g_GameDirector:getEnableSateOfPath(pathNode.Data.Objectives or {})
		local newBasePath = g_GameDirector:isBasePath(pathNode.Data.Objectives or {})

		-- this path has listed objectives
		if (pathNode.Data.Objectives ~= nil and objective ~= '') then
			-- check for possible subObjective
			if ((#pathNode.Data.Objectives == 1 ) and (newPoint.ID ~= point.ID)) then
				if (g_GameDirector:useSubobjective(botname, pathNode.Data.Objectives[1]) == true) then
					return true, newPoint;
				end
			end

			-- path with a single objective that matches mine, top priority
			if (#pathNode.Data.Objectives == 1 and pathNode.Data.Objectives[1] == objective) then
				if (highestPriority < 2) then highestPriority = 2 end
				table.insert(paths, {
					Priority = 2,
					Point = newPoint,
					State = newPathStatus,
					Base = newBasePath
				})
				if (newPoint.ID == point.ID) then
					currentPriority = 2
				end
			-- otherwise, check if the path has an objective i want
			else
				-- loop through the path's objectives and compare to mine
				for _,pathObjective in pairs(pathNode.Data.Objectives) do
					if (objective == pathObjective) then
						if (highestPriority < 1) then highestPriority = 1 end
						table.insert(paths, {
							Priority = 1,
							Point = newPoint,
							State = newPathStatus,
							Base = newBasePath
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
				Point = newPoint,
				State = newPathStatus,
				Base = newBasePath
			})
			if (newPoint.ID == point.ID) then
				currentPriority = 0
			end
		end

		-- check for base-Path or inactive path
		if (newPoint.ID ~= point.ID) then
			local switchAnyways = false;
			local countOld = #(currentPathFirst.Data.Objectives or {})
			local countNew = #(pathNode.Data.Objectives or {})

			if onBasePath then -- if on base path, check for objective count.
				if not newBasePath and newPathStatus == 2 then
					switchAnyways = true;
				elseif newBasePath then
					if countOld == 1 and countNew > 1 and newPathStatus == 2 then
						switchAnyways = true;
					end
				end
			end
			if (newPathStatus > currentPathStatus) then
				switchAnyways = true;
			end
			if newPathStatus == 0 and currentPathStatus == 0 and countOld > countNew and not newBasePath then
				switchAnyways = true;
			end
			if switchAnyways then
				if (highestPriority < 3) then highestPriority = 3 end
				table.insert(paths, {
					Priority = 3,
					Point = newPoint,
					State = newPathStatus,
					Base = newBasePath
				})
			end
		end
	end

	-- remove paths below our highest priority
	local validPaths = {}
	for i=1, #paths do
		if (paths[i].Priority >= highestPriority and paths[i].State >= currentPathStatus) then
			if(onBasePath or (not onBasePath and paths[i].Base == false)) then
				table.insert(validPaths, paths[i])
			end
		end
	end

	--if Debug.Server.PATH then
	--print('Trimmed Priority List -> '..g_Utilities:dump(paths, true, 2))
	--print('Highest Priority -> '..highestPriority)
	--print('#paths -> '..(#paths))
	--end
	
	if (#validPaths == 0) then
		return false
	end

	if (#validPaths == 1 and currentPriority < validPaths[1].Priority) then
		--if Debug.Server.PATH then
		--print('found single higher priority path ( '..currentPriority..' | '..validPaths[1].Priority..' )')
		--end
		return true, validPaths[1].Point
	end

	local linkMode = tonumber(point.Data.LinkMode) or 0
	if linkMode == 0 then -- random path switch

		local chance = tonumber(point.Data.LinkChance) or 40
		local randNum = MathUtils:GetRandomInt(0, 100)
		local randIndex = MathUtils:GetRandomInt(1, #validPaths)

		if currentPriority < highestPriority then
			local randomPath = validPaths[randIndex]
			if randomPath == nil then
				if Debug.Server.PATH then
					print('[A] validPaths['..randIndex..'] was nil : '..g_Utilities:dump(validPaths, true, 2))
				end
				return false
			end
			
			--if Debug.Server.PATH then
			--print('found multiple higher priority validPaths | Priority: ( '..currentPriority..' | '..highestPriority..' )')
			--end
			
			return true, randomPath.Point
		end

		if randNum <= chance then
			local randomPath = validPaths[randIndex]
			if randomPath == nil then
				if Debug.Server.PATH then
					print('[B] validPaths['..randIndex..'] was nil : '..g_Utilities:dump(validPaths, true, 2))
				end
				
				return false
			end
			
			--if Debug.Server.PATH then
			--print('chose to switch at random ('..randNum..' >= '..chance..') | Priority: ( '..currentPriority..' | '..randomPath.Priority..' )')
			--end
			return true, randomPath.Point
		end
	elseif linkMode == 1 then -- some other kind of switching decision
		-- etc...
	end

	--if Debug.Server.PATH then
	--print('dont change')
	--end
	return false
end



-- Singleton.
if g_PathSwitcher == nil then
	g_PathSwitcher = PathSwitcher();
end

return g_PathSwitcher;