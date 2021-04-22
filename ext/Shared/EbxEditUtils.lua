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
function EbxEditUtils:GetWritableInstance(resourcePathOrGUIDOrContainer)

	if (type(resourcePathOrGUIDOrContainer) == 'userdata' and resourcePathOrGUIDOrContainer.typeInfo ~= nil) then
		local returnInstance = _G[resourcePathOrGUIDOrContainer.typeInfo.name](resourcePathOrGUIDOrContainer)
		if (returnInstance.MakeWritable ~= nil) then
			returnInstance:MakeWritable()
		end
		return returnInstance, true
	end

	local instance = ResourceManager:SearchForDataContainer(resourcePathOrGUIDOrContainer)

	if (instance == nil) then
		instance = ResourceManager:SearchForInstanceByGuid(Guid(resourcePathOrGUIDOrContainer))
	end
	if (instance == nil) then
		instance = ResourceManager:FindDatabasePartition(Guid(resourcePathOrGUIDOrContainer))
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
function EbxEditUtils:GetWritableContainer(instance, containerPath)
	local propertyName = nil
	local workingInstance = self:GetWritableInstance(instance)
	local workingPath = self:GetValidPath(containerPath)
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
function EbxEditUtils:GetWritableProperty(instance, propertyPath)
	local propertyName = nil
	local workingInstance = self:GetWritableInstance(instance)
	local workingPath = self:GetValidPath(propertyPath)
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

function EbxEditUtils:CheckInstancePropertyExists(instance, propertyName)
	if (instance == nil or propertyName == nil) then
		return instance, propertyName, false
	end

	if (instance[propertyName] ~= nil) then -- try for property
		return instance, propertyName, true
	end

	if (tonumber(propertyName) ~= nil) then -- simple lookup failed, maybe it's an array index
		if (instance[tonumber(propertyName)] ~= nil) then -- try for property again
			return instance, tonumber(propertyName), true
		end
	end

	local instanceType = instance.typeInfo.name -- get type
	local workingInstance = _G[instanceType](instance) -- cast to type

	if (workingInstance[propertyName] ~= nil) then -- try for property again
		return workingInstance, propertyName, true
	end

	if (tonumber(propertyName) ~= nil) then -- still no, lets try array on the cast
		if (workingInstance[tonumber(propertyName)] ~= nil) then -- try for property again
			return workingInstance, tonumber(propertyName), true
		end
	end

	return instance, propertyName, false
end

-- returns two values <value>,<status>
-- <value>: the validated value, with default applied if necessary
-- <status>: boolean true if valid, string with message if failed
function EbxEditUtils:ValidateValue(argValue, argParams)
	local defaultValue = argParams.Default

	if (argValue == nil and argParams.IsOptional) then

		return defaultValue, true

	elseif (argParams.Type == 'number' or argParams.Type == 'float') then

		if (argValue ~= nil and tonumber(argValue) == nil) then
			return defaultValue, 'Must be a **'..argParams.Type..'**'
		end

	elseif (argParams.Type == 'boolean') then

		if (argValue ~= nil) then -- sorry this is ugly
			if (argValue == '1' or argValue == '0' or
				string.lower(argValue) == 'true' or string.lower(argValue) == 'false' or
				string.lower(argValue) == 'y' or string.lower(argValue) == 'n') then

				-- the value still needs to be a string, but let's normalise it
				local booltostring = tostring((argValue == '1' or string.lower(argValue) == 'true' or string.lower(argValue) == 'y'))
				return (booltostring == 'true'), true
			end
		end

		return defaultValue, 'Not a valid **boolean**, use 1/0, true/false, or y/n'

	elseif (argParams.Type == 'choices') then

		for i=1, #argParams.Choices do
			if (argValue ~= nil and argValue == argParams.Choices[i]) then
				return argValue, true
			end
		end

		local choices = ''
		for i=1, argParams.Choices do
			if (string.len(choices) > 0) then
				choices = choices..', '
			end
			choices = choices..'*'..argParams.Choices[i]..'*'
		end

		return defaultValue, 'Not a valid **choice**, use: ['..choices..']'
	elseif (argParams.Type == 'string') then
		if (argValue == nil) then
			return defaultValue, 'Must be a **string**'
		end
	end
	return argValue, true
end

function EbxEditUtils:GetValidPath(propertyPath)

	if (type(propertyPath) == 'string') then
		propertyPath = self:StringSplit(propertyPath, '\\.')
	end

	local result = {}

	for piece=1, #propertyPath do
		result[#result+1] = self:FormatMemberName(propertyPath[piece])
	end
	return result
end

-- Adapted from the C# implementation used by VU provided by NoFaTe
function EbxEditUtils:FormatMemberName(memberName)
	local outputName = ''
	local foundLower = false
	local memberLength = memberName:len()

	for i=1, memberLength do
		local continue = false -- dirty hack to give lua a 'continue' statement in loops

		if (foundLower) then
			outputName = outputName..memberName:sub(i,i)
			continue = true
		end

		if (i < memberLength-1 and (self:StringIsLower(memberName:sub(i+1,i+1)) or self:StringIsDigit(memberName:sub(i+1,i+1))) and not continue) then

			foundLower = true

			if (i > 1) then
				outputName = outputName..memberName:sub(i,i)
				continue = true
			end

		end

		if (not continue) then
			outputName = outputName..memberName:sub(i,1):lower()
		end
	end

	for i=1, #self.LuaReserverdWords do
		if (outputName:lower() == self.LuaReserverdWords[i]) then
			outputName = outputName..'Value'
		end
	end
	return outputName
end

function EbxEditUtils:StringSplit(value, seperator)
	if (seperator == nil) then
		seperator = "%s"
	end
	local result = {}
	for piece in string.gmatch(value, "([^"..seperator.."]+)") do
		result[#result+1] = piece
	end
	return result
end

function EbxEditUtils:StringIsLower(str)
	return str:lower() == str
end

function EbxEditUtils:StringIsDigit(str)
	return tonumber(str) ~= nil
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

function EbxEditUtils:dump(o)
	if (o == nil) then
		if Debug.Shared.EBX then
			print("nil")
		end
	end

	if (type(o) == 'table') then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. self:dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

if (g_EbxEditUtils == nil) then
	g_EbxEditUtils = EbxEditUtils()
end

return g_EbxEditUtils
