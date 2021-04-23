class 'EbxEditUtils'

function EbxEditUtils:__init()

	self.LuaReserverdWords = {
		"and", "break", "do", "else", "elseif",
		"end", "false", "for", "function", "goto", "if",
		"in", "local", "nil", "not", "or",
		"repeat", "return", "then", "true", "until", "while"
	}

end

-- returns two values <value>,<status>
-- <value>: the found instance as a typed object and made writable
-- <status>: boolean true if valid, string with message if failed
function EbxEditUtils:GetWritableInstance(p_ResourcePathOrGUIDOrContainer)

	if (type(p_ResourcePathOrGUIDOrContainer) == 'userdata' and p_ResourcePathOrGUIDOrContainer.typeInfo ~= nil) then
		local returnInstance = _G[p_ResourcePathOrGUIDOrContainer.typeInfo.name](p_ResourcePathOrGUIDOrContainer)
		if (returnInstance.MakeWritable ~= nil) then
			returnInstance:MakeWritable()
		end
		return returnInstance, true
	end

	local instance = ResourceManager:SearchForDataContainer(p_ResourcePathOrGUIDOrContainer)

	if (instance == nil) then
		instance = ResourceManager:SearchForInstanceByGuid(Guid(p_ResourcePathOrGUIDOrContainer))
	end
	if (instance == nil) then
		instance = ResourceManager:FindDatabasePartition(Guid(p_ResourcePathOrGUIDOrContainer))
	end

	if (instance == nil) then
		return nil, 'Could not find Data Container, Instance, or Partition'
	end

	local workingInstance = _G[instance.typeInfo.name](instance)
	if (workingInstance.MakeWritable ~= nil) then
		workingInstance:MakeWritable()
	end
	return workingInstance, true
end

-- returns three values <workingInstance>,<valid>
-- <workingInstance>: the found instance as a typed object and made writable
-- <valid>: the given values were valid
function EbxEditUtils:GetWritableContainer(p_Instance, p_ContainerPath)
	local propertyName = nil
	local workingInstance = self:GetWritableInstance(p_Instance)
	local workingPath = self:GetValidPath(p_ContainerPath)
	local valid = false

	for i=1, #workingPath do

		workingInstance, propertyName, valid = self:CheckInstancePropertyExists(workingInstance, workingPath[i])

		if (not valid) then
			return workingInstance, valid
		else
			workingInstance = workingInstance[propertyName]
			if (i == #workingPath) then

				-- safety cast
				workingInstance = _G[workingInstance.typeInfo.name](workingInstance)

				if (workingInstance.MakeWritable ~= nil) then
					workingInstance:MakeWritable()
				end

				return workingInstance, true
			end
		end
	end
	return workingInstance, false
end

-- returns three values <workingInstance>,<propertyName>,<valid>
-- <workingInstance>: the found instance as a typed object and made writable
-- <propertyName>: the property name that works
-- <valid>: the given values were valid
function EbxEditUtils:GetWritableProperty(p_Instance, p_PropertyPath)
	local propertyName = nil
	local workingInstance = self:GetWritableInstance(p_Instance)
	local workingPath = self:GetValidPath(p_PropertyPath)
	local valid = false

	for i=1, #workingPath do

		workingInstance, propertyName, valid = self:CheckInstancePropertyExists(workingInstance, workingPath[i])
		if (not valid) then
			return workingInstance, propertyName, valid
		else

			-- we've reached a value
			if (type(workingInstance[propertyName]) == 'string' or
				type(workingInstance[propertyName]) == 'number' or
				type(workingInstance[propertyName]) == 'boolean' or
				type(workingInstance[propertyName]) == 'nil') then

				if (workingInstance.MakeWritable ~= nil) then
					workingInstance:MakeWritable()
				end

				return workingInstance, propertyName, true
			end

			workingInstance = workingInstance[propertyName]
		end
	end
	return workingInstance, propertyName, false
end

function EbxEditUtils:CheckInstancePropertyExists(p_Instance, p_PropertyName)
	if (p_Instance == nil or p_PropertyName == nil) then
		return p_Instance, p_PropertyName, false
	end

	if (p_Instance[p_PropertyName] ~= nil) then -- try for property
		return p_Instance, p_PropertyName, true
	end

	if (tonumber(p_PropertyName) ~= nil) then -- simple lookup failed, maybe it's an array index
		if (p_Instance[tonumber(p_PropertyName)] ~= nil) then -- try for property again
			return p_Instance, tonumber(p_PropertyName), true
		end
	end

	local p_InstanceType = p_Instance.typeInfo.name -- get type
	local workingInstance = _G[p_InstanceType](p_Instance) -- cast to type

	if (workingInstance[p_PropertyName] ~= nil) then -- try for property again
		return workingInstance, p_PropertyName, true
	end

	if (tonumber(p_PropertyName) ~= nil) then -- still no, lets try array on the cast
		if (workingInstance[tonumber(p_PropertyName)] ~= nil) then -- try for property again
			return workingInstance, tonumber(p_PropertyName), true
		end
	end

	return p_Instance, p_PropertyName, false
end

-- returns two values <value>,<status>
-- <value>: the validated value, with default applied if necessary
-- <status>: boolean true if valid, string with message if failed
function EbxEditUtils:ValidateValue(p_ArgValue, p_ArgParams)
	local defaultValue = p_ArgParams.Default

	if (p_ArgValue == nil and p_ArgParams.IsOptional) then

		return defaultValue, true

	elseif (p_ArgParams.Type == 'number' or p_ArgParams.Type == 'float') then

		if (p_ArgValue ~= nil and tonumber(p_ArgValue) == nil) then
			return defaultValue, 'Must be a **'..p_ArgParams.Type..'**'
		end

	elseif (p_ArgParams.Type == 'boolean') then

		if (p_ArgValue ~= nil) then -- sorry this is ugly
			if (p_ArgValue == '1' or p_ArgValue == '0' or
				string.lower(p_ArgValue) == 'true' or string.lower(p_ArgValue) == 'false' or
				string.lower(p_ArgValue) == 'y' or string.lower(p_ArgValue) == 'n') then

				-- the value still needs to be a string, but let's normalise it
				local booltostring = tostring((p_ArgValue == '1' or string.lower(p_ArgValue) == 'true' or string.lower(p_ArgValue) == 'y'))
				return (booltostring == 'true'), true
			end
		end

		return defaultValue, 'Not a valid **boolean**, use 1/0, true/false, or y/n'

	elseif (p_ArgParams.Type == 'choices') then

		for i=1, #p_ArgParams.Choices do
			if (p_ArgValue ~= nil and p_ArgValue == p_ArgParams.Choices[i]) then
				return p_ArgValue, true
			end
		end

		local choices = ''
		for i=1, p_ArgParams.Choices do
			if (string.len(choices) > 0) then
				choices = choices..', '
			end
			choices = choices..'*'..p_ArgParams.Choices[i]..'*'
		end

		return defaultValue, 'Not a valid **choice**, use: ['..choices..']'
	elseif (p_ArgParams.Type == 'string') then
		if (p_ArgValue == nil) then
			return defaultValue, 'Must be a **string**'
		end
	end
	return p_ArgValue, true
end

function EbxEditUtils:GetValidPath(p_PropertyPath)

	if (type(p_PropertyPath) == 'string') then
		p_PropertyPath = self:StringSplit(p_PropertyPath, '\\.')
	end

	local result = {}

	for piece=1, #p_PropertyPath do
		result[#result+1] = self:FormatMemberName(p_PropertyPath[piece])
	end
	return result
end

-- Adapted from the C# implementation used by VU provided by NoFaTe
function EbxEditUtils:FormatMemberName(p_MemberName)
	local outputName = ''
	local foundLower = false
	local memberLength = p_MemberName:len()

	for i=1, memberLength do
		local continue = false -- dirty hack to give lua a 'continue' statement in loops

		if (foundLower) then
			outputName = outputName..p_MemberName:sub(i,i)
			continue = true
		end

		if (i < memberLength-1 and (self:StringIsLower(p_MemberName:sub(i+1,i+1)) or self:StringIsDigit(p_MemberName:sub(i+1,i+1))) and not continue) then

			foundLower = true

			if (i > 1) then
				outputName = outputName..p_MemberName:sub(i,i)
				continue = true
			end

		end

		if (not continue) then
			outputName = outputName..p_MemberName:sub(i,1):lower()
		end
	end

	for i=1, #self.LuaReserverdWords do
		if (outputName:lower() == self.LuaReserverdWords[i]) then
			outputName = outputName..'Value'
		end
	end
	return outputName
end

function EbxEditUtils:StringSplit(p_Value, p_Seperator)
	if (p_Seperator == nil) then
		p_Seperator = "%s"
	end
	local result = {}
	for piece in string.gmatch(p_Value, "([^"..p_Seperator.."]+)") do
		result[#result+1] = piece
	end
	return result
end

function EbxEditUtils:StringIsLower(p_Str)
	return p_Str:lower() == p_Str
end

function EbxEditUtils:StringIsDigit(p_Str)
	return tonumber(p_Str) ~= nil
end

function EbxEditUtils:getModuleState()
	if (SharedUtils:IsClientModule() and SharedUtils:IsServerModule()) then
		return 'Shared'
	elseif (SharedUtils:IsClientModule() and not SharedUtils:IsServerModule()) then
		return 'Client'
	elseif (not SharedUtils:IsClientModule() and SharedUtils:IsServerModule()) then
		return 'Server'
	end
	return 'Unkown'
end

function EbxEditUtils:dump(p)
	if (p == nil) then
		if Debug.Shared.EBX then
			print("nil")
		end
	end

	if (type(p) == 'table') then
		local s = '{ '
		for k,v in pairs(p) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. self:dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(p)
	end
end

if (g_EbxEditUtils == nil) then
	g_EbxEditUtils = EbxEditUtils()
end

return g_EbxEditUtils
