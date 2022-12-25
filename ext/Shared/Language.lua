---@class Language
---@overload fun():Language
Language = class 'Language'

require('__shared/Utilities')

function Language:__init()
	self._Translations = {}
	self._Language = 'en_US'

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

	self._Language = p_Name
	requireExists('__shared/Languages/' .. p_Name .. '.lua')

	if Debug.Shared.LANGUAGE then
		print(self._Translations)
	end
end

function Language:add(p_Code, p_String, p_Translation)
	if self._Translations[p_Code] == nil then
		self._Translations[p_Code] = {}
	end

	self._Translations[p_Code][p_String] = p_Translation
end

function Language:I18NReplace(p_Input, p_Arguments)
	local s_Position = 0

	-- To-do: Implement %1$d, %2$d for indexes.

	return (string.gsub(p_Input, '%%[d|s]', function(placeholder)
		s_Position = s_Position + 1

		return p_Arguments[s_Position]
	end))
end

function Language:I18N(p_Input, ...)
	local s_Arguments = {}
	local s_Length = select('#', ...)

	for index = 1, s_Length do
		s_Arguments[#s_Arguments + 1] = select(index, ...)
	end

	-- if Debug.Shared.LANGUAGE then
	-- print(s_Arguments[1])
	-- end

	if self._Translations ~= nil then
		if self._Translations[self._Language] ~= nil then
			if self._Translations[self._Language][p_Input] ~= nil then
				if self._Translations[self._Language][p_Input] ~= "" then
					return self:I18NReplace(self._Translations[self._Language][p_Input], s_Arguments)
				end
			end
		end
	end

	return self:I18NReplace(p_Input, s_Arguments)
end

if g_Language == nil then
	---@type Language
	g_Language = Language()
end

return g_Language
