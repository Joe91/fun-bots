-- thanks to RM https://github.com/BF3RM/MapEditor/blob/development/ext/Shared/Util/Logger.lua

---@class Logger
Logger = class "Logger"

---@param p_ClassName string
---@param p_ActivateLogging boolean
function Logger:__init(p_ClassName, p_ActivateLogging)
	if type(p_ClassName) ~= "string" then
		error("Logger: Wrong arguments creating object, className is not a string. ClassName: "..tostring(p_ClassName))
		return
	elseif type(p_ActivateLogging) ~= "boolean" then
		error("Logger: Wrong arguments creating object, ActivateLogging is not a boolean. ActivateLogging: " ..tostring(p_ActivateLogging))
		return
	end

	-- print("Creating object with: "..p_ClassName..", "..tostring(p_ActivateLogging))
	self.m_Debug = p_ActivateLogging
	self.m_ClassName = p_ClassName
end

function Logger:Write(p_Message)
	if not Debug.Logger.ENABLED then
		return
	end

	if Debug.Logger.PRINTALL == true and self.m_ClassName ~= nil then
		goto continue
	elseif self.m_Debug == false or
		self.m_Debug == nil or
		self.m_ClassName == nil then
		return
	end

	::continue::

	if type(p_Message) == 'table' then
		print("["..self.m_ClassName.."]")
		print(p_Message)
	else
		print("["..self.m_ClassName.."] " .. tostring(p_Message))
	end
end

function Logger:WriteTable(p_Table)
	for l_Key, l_Value in pairs(p_Table) do
		self:Write(tostring(l_Key) .. " - " .. tostring(l_Value))
	end
end

function Logger:Warning(p_Message)
	if self.m_ClassName == nil then
		return
	end

	print("["..self.m_ClassName.."] WARNING: " .. tostring(p_Message))
end

function Logger:Error(p_Message)
	if self.m_ClassName == nil then
		return
	end

	print("["..self.m_ClassName.."] ERROR: " .. tostring(p_Message))
end

return Logger
