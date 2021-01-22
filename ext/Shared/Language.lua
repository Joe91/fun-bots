class 'Language';

function Language:__init()
	
end

function ArrayMap:I18N(string)
	-- @ToDo check if language-file exists and translate.
  
  return string;
end

if (g_Language == nil) then
	g_Language = Language();
end

return g_Language;
