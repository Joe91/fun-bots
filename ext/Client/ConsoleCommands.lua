---@class ConsoleCommands
---@overload fun():ConsoleCommands
ConsoleCommands = class('ConsoleCommands')

function ConsoleCommands:__init()
	self._ConfigList = {}
end

function ConsoleCommands:OnRegisterConsoleCommands(p_ConfigList)
	if #self._ConfigList == 0 then
		for _, l_Item in pairs(p_ConfigList) do
			Console:Register('config.get.' .. l_Item.Name, 'read this value', function(p_Args)
				print(Config[l_Item.Name])
			end)

			Console:Register('config.set.' .. l_Item.Name, 'Default: ' .. tostring(l_Item.Default) .. ', ' .. l_Item.Description,
				function(p_Args)
					NetEvents:SendLocal('ConsoleCommands:SetConfig', l_Item.Name, p_Args[1])
				end)
		end

		self._ConfigList = p_ConfigList
	end

	Console:Register('config.saveall', 'save all values to database', function(p_Args)
		NetEvents:SendLocal('ConsoleCommands:SaveAll', true)
	end)

	Console:Register('config.restore', 'restores default-values', function(p_Args)
		NetEvents:SendLocal('ConsoleCommands:Restore', true)
	end)

	Console:Register('SpawnGrenade', 'spawns grenade at your feet:)', function(p_Args)
		NetEvents:SendLocal('ConsoleCommands:SpawnGrenade', p_Args)
	end)

	Console:Register('DestroyObstaclesTest', '', function(p_Args)
		NetEvents:SendLocal('ConsoleCommands:DestroyObstaclesTest', p_Args)
	end)
end

function ConsoleCommands:OnPrintResponse(p_Response)
	print(p_Response)
end

if g_ConsoleCommands == nil then
	---@type ConsoleCommands
	g_ConsoleCommands = ConsoleCommands()
end

return g_ConsoleCommands
