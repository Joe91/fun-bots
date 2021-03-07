class 'Language';

require('__shared/Utilities');

function Language:__init()
	self._translations	= {};
	self._language		= 'en_US';
	
	if Config ~= nil and Config.language ~= nil then
		self:loadLanguage(Config.language);
	end
end

function Language:loadLanguage(name)
	if name == nil then
		if Debug.Shared.LANGUAGE then
			print('Language:loadLanguage parameter is nil.');
		end
		
		return;
	end
	
	if Debug.Shared.LANGUAGE then
		print('Loading language file: ' .. name);
	end
	
	self._language = name;
    requireExists('__shared/Languages/' .. name .. '.lua');
	
	if Debug.Shared.LANGUAGE then
		print(self._translations);
	end
end

function Language:add(code, string, translation)
	if self._translations[code] == nil then
		self._translations[code] = {};
	end
	
	self._translations[code][string] = translation;
end

function Language:I18NReplace(input, arguments)
    local position = 0;
    
    -- ToDo implement %1$d, %2$d for indexes
    
   return (string.gsub(input, '%%[d|s]', function(placeholder)
        position = position + 1;
        
        return arguments[position];
    end));
end

function Language:I18N(input, ...)
	local arguments = {};
    local length    = select('#', ...);
    
    for index = 1, length do
        arguments[#arguments + 1] = select(index, ...);
    end
    
	--if Debug.Shared.LANGUAGE then
    --print(arguments[1]);
	--end
	
    if (self._translations ~= nil) then
		if (self._translations[self._language] ~= nil) then
			if(self._translations[self._language][input] ~= nil) then
				if(self._translations[self._language][input] ~= "") then
					return self:I18NReplace(self._translations[self._language][input], arguments);
				end
			end
		end
	end
    
    return self:I18NReplace(input, arguments);
end

if (g_Language == nil) then
	g_Language = Language();
end

return g_Language;
