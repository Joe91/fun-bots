class('RCONCommands');

require('__shared/Config');

local BotManager	= require('BotManager');
local BotSpawner	= require('BotSpawner');
local Globals 		= require('Globals');


function RCONCommands:__init()
	if Config.disableRCONCommands then
		return;
	end
	
	self.commands	= {
		-- Get Config
		GET_CONFIG	= {
			Name		= 'funbots.config',
			Callback	= (function(command, args);
				return {
					'OK',
					json.encode({
						MAX_NUMBER_OF_BOTS	= MAX_NUMBER_OF_BOTS,
						MAX_TRACE_NUMBERS	= MAX_TRACE_NUMBERS,
						USE_REAL_DAMAGE		= USE_REAL_DAMAGE,
						Config				= Config,
						StaticConfig		= StaticConfig
					})
				};
			end)
		},
		
		-- Set Config
		SET_CONFIG	= {
			Name		= 'funbots.set.config',
			Parameters	= { 'Name', 'Value' },
			Callback	= (function(command, args);
				local old	= {
					Name	= nil,
					Value	= nil
				};
				
				local new	= {
					Name	= nil,
					Value	= nil
				};
				
				local name	= args[1];
				local value	= args[2];
				
				if name == nil then
					return {'ERROR', 'Needing <Name>.'};
				end
				
				if value == nil then
					return {'ERROR', 'Needing <Value>.'};
				end
				
				-- Constants
				if name == 'MAX_NUMBER_OF_BOTS' then
					old.Name			= name;
					old.Value			= MAX_NUMBER_OF_BOTS;
					MAX_NUMBER_OF_BOTS	= tonumber(value);
					new.Name			= name;
					new.Value			= MAX_NUMBER_OF_BOTS;
					
				elseif name == 'MAX_TRACE_NUMBERS' then
					old.Name			= name;
					old.Value			= MAX_TRACE_NUMBERS;
					MAX_TRACE_NUMBERS	= tonumber(value);
					new.Name			= name;
					new.Value			= MAX_TRACE_NUMBERS;
					
				elseif name == 'USE_REAL_DAMAGE' then
					local new_value = false;
					
					if value == true or value == '1' or value == 'true' or value == 'True' or value == 'TRUE' then
						new_value = true;
					end
					
					old.Name			= name;
					old.Value			= USE_REAL_DAMAGE;
					USE_REAL_DAMAGE		= new_value;
					new.Name			= name;
					new.Value			= USE_REAL_DAMAGE;
				else
					-- Config
					if Config[name] ~= nil then
						local test = tostring(Config[name]);
						local type = 'nil';
						
						-- Boolean
						if (test == 'true' or test == 'false') then
							type = 'boolean';
							
						-- String
						elseif (test == Config[name]) then
							type = 'string';
							
						-- Number
						elseif (tonumber(test) == Config[name]) then
							type = 'number';
						end
						
							
						old.Name	= 'Config.' .. name;
						old.Value	= Config[name];
						
						if type == 'boolean' then
							local new_value = false;
					
							if value == true or value == '1' or value == 'true' or value == 'True' or value == 'TRUE' then
								new_value = true;
							end
							
							Config[name]	= new_value;
							new.Name		= 'Config.' .. name;
							new.Value		= Config[name];
							
						elseif type == 'string' then
							Config[name]	= tostring(value);
							new.Name		= 'Config.' .. name;
							new.Value		= Config[name];
							
						elseif type == 'number' then
							Config[name]	= tonumber(value);
							new.Name		= 'Config.' .. name;
							new.Value		= Config[name];
							
						else
							print('Unknown Config property-Type: ' .. name .. ' -> ' .. type);
						end
					elseif StaticConfig[name] ~= nil then
						local test = tostring(StaticConfig[name]);
						local type = 'nil';
						
						old.Name	= 'StaticConfig.' .. name;
						old.Value	= StaticConfig[name];
						
						-- Boolean
						if (test == 'true' or test == 'false') then
							type = 'boolean';
							
						-- String
						elseif (test == StaticConfig[name]) then
							type = 'string';
							
						-- Number
						elseif (tonumber(test) == StaticConfig[name]) then
							type = 'number';
						end
						
						if type == 'boolean' then
							local new_value = false;
					
							if value == true or value == '1' or value == 'true' or value == 'True' or value == 'TRUE' then
								new_value = true;
							end
							
							StaticConfig[name]	= new_value;
							new.Name			= 'StaticConfig.' .. name;
							new.Value			= StaticConfig[name];
							
						elseif type == 'string' then
							StaticConfig[name]	= tostring(value);
							new.Name			= 'StaticConfig.' .. name;
							new.Value			= StaticConfig[name];
							
						elseif type == 'number' then
							StaticConfig[name]	= tonumber(value);
							new.Name			= 'StaticConfig.' .. name;
							new.Value			= StaticConfig[name];
							
						else
							print('Unknown Config property-Type: ' .. name .. ' -> ' .. type);
						end
					else
						print('Unknown Config property: ' .. name);
					end
				end
				
				return { 'OK', old.Name .. ' = ' .. tostring(old.Value), new.Name .. ' = ' .. tostring(new.Value) };
			end)
		},
		
		-- Clear/Reset Botnames
		CLEAR_BOTNAMES	= {
			Name		= 'funbots.clear.BotNames',
			Callback	= (function(command, args);
				BotNames = {};
				
				return { 'OK' };
			end)
		},
		
		-- Add BotName
		ADD_BOTNAMES	= {
			Name		= 'funbots.add.BotNames',
			Parameters	= { 'String' },
			Callback	= (function(command, args);
				local value	= args[1];
				
				if value == nil then
					return {'ERROR', 'Needing <String>.'};
				end
				
				table.insert(BotNames, value);
				
				return { 'OK' };
			end)
		},
		
		-- Replace BotName
		REPLACE_BOTNAMES	= {
			Name		= 'funbots.replace.BotNames',
			Parameters	= { 'JSONArray' },
			Callback	= (function(command, args);
				local value	= args[1];
				
				if value == nil then
					return {'ERROR', 'Needing <JSONArray>.'};
				end
				
				local result = json.decode(value);
				
				if result == nil then
					return {'ERROR', 'Needing <JSONArray>.'};
				end
				
				BotNames = result;
				
				return { 'OK' };
			end)
		},
		
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