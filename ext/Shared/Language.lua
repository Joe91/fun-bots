class 'Language';

function Language:__init()
    self:loadLanguage(Config.language);
end

function Language:loadLanguage(name)
    require('__shared/Languages/' .. name .. '.lua');
end

function Language:I18N(string)
	-- @ToDo check if language-file exists and translate.
    if (Languages ~= nil ) then
	if (Languages[Config.language] ~= nil ) then
	    if (Languages[Config.language][string] ~= nil ) then
	        return Languages[Config.language][string];
	    end
	end
    end
    
    return string;
end

if (g_Language == nil) then
	g_Language = Language();
end

return g_Language;
