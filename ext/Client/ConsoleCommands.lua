class('ConsoleCommands')

function ConsoleCommands:__init()
	for key, value in pairs(Config) do
		
		Console:Register('config.get.'..key, 'read this value', function(p_Args)
			print(Config[key])
		end)
		Console:Register('config.get.'..key, 'write this value', function(p_Args)
			print(p_Args)
			Config[key] = tostring(p_Args[1])
		end)
	end
end

if g_ConsoleCommands == nil then
	g_ConsoleCommands = ConsoleCommands()
end

return g_ConsoleCommands