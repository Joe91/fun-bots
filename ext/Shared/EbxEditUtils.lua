---@class EbxEditUtils
---@overload fun():EbxEditUtils
EbxEditUtils = class 'EbxEditUtils'

function EbxEditUtils:__init()
	self.LuaReserverdWords = {
		"and", "break", "do", "else", "elseif",
		"end", "false", "for", "function", "goto", "if",
		"in", "local", "nil", "not", "or",
		"repeat", "return", "then", "true", "until", "while"
	}
end

-- Returns two values <value>,<status>
-- <value>: The found instance as a typed object and made writable.
-- <status>: Boolean true if valid, string with message if failed.
function EbxEditUtils:GetWritableInstance(p_ResourcePathOrGUIDOrContainer)
	if type(p_ResourcePathOrGUIDOrContainer) == 'userdata' and p_ResourcePathOrGUIDOrContainer.typeInfo ~= nil then
		local s_ReturnInstance = _G[p_ResourcePathOrGUIDOrContainer.typeInfo.name](p_ResourcePathOrGUIDOrContainer)

		if s_ReturnInstance.MakeWritable ~= nil then
			s_ReturnInstance:MakeWritable()
		end

		return s_ReturnInstance, true
	end

	local s_Instance = ResourceManager:SearchForDataContainer(p_ResourcePathOrGUIDOrContainer)

	if s_Instance == nil then
		s_Instance = ResourceManager:SearchForInstanceByGuid(Guid(p_ResourcePathOrGUIDOrContainer))
	end

	if s_Instance == nil then
		s_Instance = ResourceManager:FindDatabasePartition(Guid(p_ResourcePathOrGUIDOrContainer))
	end

	if s_Instance == nil then
		return nil, 'Could not find Data Container, Instance, or Partition'
	end

	local s_WorkingInstance = _G[s_Instance.typeInfo.name](s_Instance)

	if s_WorkingInstance.MakeWritable ~= nil then
		s_WorkingInstance:MakeWritable()
	end

	return s_WorkingInstance, true
end

-- Returns three values <workingInstance>,<valid>
-- <workingInstance>: The found instance as a typed object and made writable.
-- <valid>: The given values were valid.
function EbxEditUtils:GetWritableContainer(p_Instance, p_ContainerPath)
	local s_PropertyName = nil
	local s_WorkingInstance = self:GetWritableInstance(p_Instance)
	local s_WorkingPath = self:GetValidPath(p_ContainerPath)
	local s_Valid = false

	for i = 1, #s_WorkingPath do
		s_WorkingInstance, s_PropertyName, s_Valid = self:CheckInstancePropertyExists(s_WorkingInstance, s_WorkingPath[i])

		if not s_Valid then
			return s_WorkingInstance, s_Valid
		else
			s_WorkingInstance = s_WorkingInstance[s_PropertyName]

			if i == #s_WorkingPath then
				-- Safety cast.
				s_WorkingInstance = _G[s_WorkingInstance.typeInfo.name](s_WorkingInstance)

				if s_WorkingInstance.MakeWritable ~= nil then
					s_WorkingInstance:MakeWritable()
				end

				return s_WorkingInstance, true
			end
		end
	end

	return s_WorkingInstance, false
end

-- Returns three values <workingInstance>,<propertyName>,<valid>
-- <workingInstance>: The found instance as a typed object and made writable.
-- <propertyName>: The property name that works.
-- <valid>: The given values were valid.
function EbxEditUtils:GetWritableProperty(p_Instance, p_PropertyPath)
	local s_PropertyName = nil
	local s_WorkingInstance = self:GetWritableInstance(p_Instance)
	local s_WorkingPath = self:GetValidPath(p_PropertyPath)
	local s_Valid = false

	for i = 1, #s_WorkingPath do
		s_WorkingInstance, s_PropertyName, s_Valid = self:CheckInstancePropertyExists(s_WorkingInstance, s_WorkingPath[i])

		if not s_Valid then
			return s_WorkingInstance, s_PropertyName, s_Valid
		else
			-- We've reached a value
			if type(s_WorkingInstance[s_PropertyName]) == 'string' or
				type(s_WorkingInstance[s_PropertyName]) == 'number' or
				type(s_WorkingInstance[s_PropertyName]) == 'boolean' or
				type(s_WorkingInstance[s_PropertyName]) == 'nil' then
				if s_WorkingInstance.MakeWritable ~= nil then
					s_WorkingInstance:MakeWritable()
				end

				return s_WorkingInstance, s_PropertyName, true
			end

			s_WorkingInstance = s_WorkingInstance[s_PropertyName]
		end
	end

	return s_WorkingInstance, s_PropertyName, false
end

function EbxEditUtils:CheckInstancePropertyExists(p_Instance, p_PropertyName)
	if p_Instance == nil or p_PropertyName == nil then
		return p_Instance, p_PropertyName, false
	end

	if p_Instance[p_PropertyName] ~= nil then -- Try for property.
		return p_Instance, p_PropertyName, true
	end

	if tonumber(p_PropertyName) ~= nil then           -- Simple lookup failed, maybe it's an array index.
		if p_Instance[tonumber(p_PropertyName)] ~= nil then -- Try for property again.
			return p_Instance, tonumber(p_PropertyName), true
		end
	end

	local s_InstanceType = p_Instance.typeInfo.name       -- Get type.
	local s_WorkingInstance = _G[s_InstanceType](p_Instance) -- Cast to type.

	if s_WorkingInstance[p_PropertyName] ~= nil then      -- Try for property again.
		return s_WorkingInstance, p_PropertyName, true
	end

	if tonumber(p_PropertyName) ~= nil then                  -- Still no, let's try array on the cast.
		if s_WorkingInstance[tonumber(p_PropertyName)] ~= nil then -- Try for property again.
			return s_WorkingInstance, tonumber(p_PropertyName), true
		end
	end

	return p_Instance, p_PropertyName, false
end

-- Returns two values <value>,<status>
-- <value>: The validated value, with default applied if necessary.
-- <status>: Boolean true if valid, string with message if failed.
function EbxEditUtils:ValidateValue(p_ArgValue, p_ArgParams)
	local s_DefaultValue = p_ArgParams.Default

	if p_ArgValue == nil and p_ArgParams.IsOptional then
		return s_DefaultValue, true
	elseif p_ArgParams.Type == 'number' or p_ArgParams.Type == 'float' then
		if p_ArgValue ~= nil and tonumber(p_ArgValue) == nil then
			return s_DefaultValue, 'Must be a **' .. p_ArgParams.Type .. '**'
		end
	elseif p_ArgParams.Type == 'boolean' then
		if p_ArgValue ~= nil then -- Sorry, this is ugly.
			if p_ArgValue == '1' or p_ArgValue == '0' or
				string.lower(p_ArgValue) == 'true' or string.lower(p_ArgValue) == 'false' or
				string.lower(p_ArgValue) == 'y' or string.lower(p_ArgValue) == 'n' then
				-- The value still needs to be a string, but let's normalize it.
				local s_BoolToString = tostring((
					p_ArgValue == '1' or string.lower(p_ArgValue) == 'true' or string.lower(p_ArgValue) == 'y'))
				return (s_BoolToString == 'true'), true
			end
		end

		return s_DefaultValue, 'Not a valid **boolean**, use 1/0, true/false, or y/n'
	elseif p_ArgParams.Type == 'choices' then
		for i = 1, #p_ArgParams.Choices do
			if p_ArgValue ~= nil and p_ArgValue == p_ArgParams.Choices[i] then
				return p_ArgValue, true
			end
		end

		local s_Choices = ''

		for i = 1, p_ArgParams.Choices do
			if string.len(s_Choices) > 0 then
				s_Choices = s_Choices .. ', '
			end

			s_Choices = s_Choices .. '*' .. p_ArgParams.Choices[i] .. '*'
		end

		return s_DefaultValue, 'Not a valid **choice**, use: [' .. s_Choices .. ']'
	elseif p_ArgParams.Type == 'string' then
		if p_ArgValue == nil then
			return s_DefaultValue, 'Must be a **string**'
		end
	end

	return p_ArgValue, true
end

function EbxEditUtils:GetValidPath(p_PropertyPath)
	if type(p_PropertyPath) == 'string' then
		p_PropertyPath = self:StringSplit(p_PropertyPath, '\\.')
	end

	local s_Result = {}

	for l_Piece = 1, #p_PropertyPath do
		s_Result[#s_Result + 1] = self:FormatMemberName(p_PropertyPath[l_Piece])
	end

	return s_Result
end

-- Adapted from the C# implementation used by VU, provided by NoFaTe.
function EbxEditUtils:FormatMemberName(p_MemberName)
	local s_OutputName = ''
	local s_FoundLower = false
	local s_MemberLength = p_MemberName:len()

	for i = 1, s_MemberLength do
		local s_Continue = false -- Dirty hack to give Lua a 'continue' statement in loops.

		if s_FoundLower then
			s_OutputName = s_OutputName .. p_MemberName:sub(i, i)
			s_Continue = true
		end

		if i < s_MemberLength - 1 and
			(self:StringIsLower(p_MemberName:sub(i + 1, i + 1)) or self:StringIsDigit(p_MemberName:sub(i + 1, i + 1))) and
			not s_Continue then
			s_FoundLower = true

			if i > 1 then
				s_OutputName = s_OutputName .. p_MemberName:sub(i, i)
				s_Continue = true
			end
		end

		if not s_Continue then
			s_OutputName = s_OutputName .. p_MemberName:sub(i, 1):lower()
		end
	end

	for i = 1, #self.LuaReserverdWords do
		if s_OutputName:lower() == self.LuaReserverdWords[i] then
			s_OutputName = s_OutputName .. 'Value'
		end
	end

	return s_OutputName
end

function EbxEditUtils:StringSplit(p_Value, p_Seperator)
	if p_Seperator == nil then
		p_Seperator = "%s"
	end

	local s_Result = {}

	for l_Piece in string.gmatch(p_Value, "([^" .. p_Seperator .. "]+)") do
		s_Result[#s_Result + 1] = l_Piece
	end

	return s_Result
end

function EbxEditUtils:StringIsLower(p_Str)
	return p_Str:lower() == p_Str
end

function EbxEditUtils:StringIsDigit(p_Str)
	return tonumber(p_Str) ~= nil
end

function EbxEditUtils:getModuleState()
	if SharedUtils:IsClientModule() and SharedUtils:IsServerModule() then
		return 'Shared'
	elseif SharedUtils:IsClientModule() and not SharedUtils:IsServerModule() then
		return 'Client'
	elseif not SharedUtils:IsClientModule() and SharedUtils:IsServerModule() then
		return 'Server'
	end

	return 'Unkown'
end

function EbxEditUtils:dump(p)
	if p == nil then
		if Debug.Shared.EBX then
			print("nil")
		end
	end

	if type(p) == 'table' then
		local s = '{ '

		for k, v in pairs(p) do
			if type(k) ~= 'number' then k = '"' .. k .. '"' end

			s = s .. '[' .. k .. '] = ' .. self:dump(v) .. ','
		end

		return s .. '} '
	else
		return tostring(p)
	end
end

if g_EbxEditUtils == nil then
	---@type EbxEditUtils
	g_EbxEditUtils = EbxEditUtils()
end

return g_EbxEditUtils
