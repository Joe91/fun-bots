class('RCONCommands');

require('__shared/Config');

local BotManager	= require('BotManager');
local BotSpawner	= require('BotSpawner');
local Globals 		= require('Globals');


function RCONCommands:__init()
	self.commands	= {
		-- Kick All
		KICKALLL	= {
			Name		= 'funbots.kickAll',
			Callback	= (function(command, args)
				BotManager:destroyAllBots();
				
				return { 'OK' };
			end)
		},
		
		-- Kill All
		KILLALL	= {
			Name		= 'funbots.killAll',
			Callback	= (function(command, args)
				BotManager:killAll();
				
				return { 'OK' };
			end)
		},
		
		-- Spawn <Amount> <Team>
		SPAWN	= {
			Name		= 'funbots.spawn',
			Parameters	= { 'Amount', 'Team' },
			Callback	= (function(command, args)
				local value	= args[1];
				local team	= args[2];
				
				if value == nil then
					return {'ERROR', 'Needing Spawn amount.'};
				end
				
				if team == nil then
					return {'ERROR', 'Needing Team.'};
				end
				
				if tonumber(value) == nil then
					return {'ERROR', 'Needing Spawn amount.'};
				end

				local amount	= tonumber(value);
				local t			= TeamId.Neutral;

				if team == "Team1" then
					t = TeamId.Team1;
				elseif team == "Team2" then
					t = TeamId.Team2;
				end
				
				BotSpawner:spawnWayBots(nil, amount, true, nil, nil, t);
				
				return {'OK'};
			end)
		}
	};
	
	self:createCommand('funbots', (function(command, args)
		local result = {};
		
		table.insert(result, 'OK');
		
		for index, command in pairs(self.commands) do
			local the_command = command.Name;
			
			if command.Parameters ~= nil then
				for _, parameter in pairs(command.Parameters) do
					the_command = the_command .. ' <' .. parameter .. '>';
				end
			end
			
			table.insert(result, the_command);
		end
		
		return result;
	end));
	
	self:create();
end

function RCONCommands:create()
	for index, command in pairs(self.commands) do
		self:createCommand(command.Name, command.Callback);
	end
end

function RCONCommands:createCommand(name, callback)
	RCON:RegisterCommand(name, RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
		return callback(command, args);
	end);
end

-- Singleton.
if g_RCONCommands == nil then
	g_RCONCommands = RCONCommands();
end

return g_RCONCommands;