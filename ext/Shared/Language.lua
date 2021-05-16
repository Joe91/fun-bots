class 'Language'

require('__shared/Utilities')

function Language:__init()
	self._translations = {}
	self._language = 'en_US'

	if Config ~= nil and Config.Language ~= nil then
		self:loadLanguage(Config.Language)
	end
end

function Language:loadLanguage(p_Name)
	if p_Name == nil then
		if Debug.Shared.LANGUAGE then
			print('Language:loadLanguage parameter is nil.')
		end

		return
	end

	if Debug.Shared.LANGUAGE then
		print('Loading language file: ' .. p_Name)
	end

	self._language = p_Name
	requireExists('__shared/Languages/' .. p_Name .. '.lua')

	if Debug.Shared.LANGUAGE then
		print(self._translations)
	end
end

function Language:add(p_Code, p_String, p_Translation)
	if self._translations[p_Code] == nil then
		self._translations[p_Code] = {}
	end

	self._translations[p_Code][p_String] = p_Translation
end

function Language:I18NReplace(p_Input, p_Arguments)
	local position = 0

-- ToDo implement %1$d, %2$d for indexes

	return (string.gsub(p_Input, '%%[d|s]', function(placeholder)
		position = position + 1

		return p_Arguments[position]
	end))
end

function Language:I18N(p_Input, ...)
	local arguments = {}
	local length = select('#', ...)

	for index = 1, length do
		arguments[#arguments + 1] = select(index, ...)
	end

	--if Debug.Shared.LANGUAGE then
	--print(arguments[1])
	--end

	if (self._translations ~= nil) then
		if (self._translations[self._language] ~= nil) then
			if(self._translations[self._language][p_Input] ~= nil) then
				if(self._translations[self._language][p_Input] ~= "") then
					return self:I18NReplace(self._translations[self._language][p_Input], arguments)
				end
			end
		end
	end

	return self:I18NReplace(p_Input, arguments)
end

if g_Language == nil then
	g_Language = Language()
end

return g_Language
