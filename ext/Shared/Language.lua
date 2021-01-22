class 'Language';

-- @ToDo export to global utils
function requireExists(module)
    local function reference(module)
        require(module)
    end
	
    res = pcall(reference, module);
	
    if not(res) then
        -- Not found.
    end
end

function Language:__init()
	self._translations	= {};
	self._language		= 'en_US';
	
	if Config ~= nil and Config.language ~= nil then
		self:loadLanguage(Config.language);
	end
end

function Language:loadLanguage(name)
	if name == nil then
		print('Language:loadLanguage parameter is nil.');
		return;
	end
	
	print('Loading language file: ' .. name);
	self._language = name;
    requireExists('__shared/Languages/' .. name .. '.lua');
	print(self._translations);
end

function Language:add(code, string, translation)
	if self._translations[code] == nil then
		self._translations[code] = {};
	end
	
	self._translations[code][string] = translation;
end

function Language:I18N(string, ...)
	-- @ToDo check if language-file exists and translate.
    if (self._translations ~= nil) then
		if (self._translations[self._language] ~= nil) then
			if(self._translations[self._language][string] ~= nil) then
				if(self._translations[self._language][string] ~= "") then
					return self._translations[self._language][string];
				end
			end
		end
	end
    
    return string;
end

if (g_Language == nil) then
	g_Language = Language();
end

return g_Language;
