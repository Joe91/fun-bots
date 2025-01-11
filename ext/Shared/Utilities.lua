---@class Utilities
---@overload fun():Utilities
Utilities = class('Utilities')

require('__shared/Config')

function Utilities:__init()
	-- Nothing to do.
end

---@param p_Player Player
---@param p_IsTarget boolean
---@param p_AimForHead boolean
---@return Vec3
function Utilities:getCameraPos(p_Player, p_IsTarget, p_AimForHead)
	return Vec3(0.00, self:getTargetHeight(p_Player.soldier, p_IsTarget, p_AimForHead), 0.00)
end

---@param p_Soldier Soldier
---@param p_IsTarget boolean
---@param p_AimForHead boolean
---@return number
function Utilities:getTargetHeight(p_Soldier, p_IsTarget, p_AimForHead)
	local s_CameraHeight = 0

	if not p_IsTarget then
		s_CameraHeight = 1.6 -- bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand

		if p_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			s_CameraHeight = 0.3
		elseif p_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			s_CameraHeight = 1.0
		end
	elseif p_IsTarget and p_AimForHead then
		s_CameraHeight = 1.65 -- bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand

		if p_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			s_CameraHeight = 0.25
		elseif p_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			s_CameraHeight = 1.05
		end
	else               -- Aim a little lower.
		s_CameraHeight = 1.1 -- bot.soldier.pose == CharacterPoseType.CharacterPoseType_Stand - reduce by 0.5

		if p_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			s_CameraHeight = 0.2 -- Reduce by 0.1
		elseif p_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			s_CameraHeight = 0.7 -- Reduce by 0.3
		end
	end

	return s_CameraHeight
end

---@param p_Player Player|string|integer
---@return boolean
function Utilities:isBot(p_Player)
	local s_Player = nil
	if type(p_Player) == 'string' then
		s_Player = PlayerManager:GetPlayerByName(p_Player)
	elseif type(p_Player) == 'number' then
		s_Player = PlayerManager:GetPlayerById(p_Player)

		if s_Player == nil then
			s_Player = PlayerManager:GetPlayerByOnlineId(p_Player)
		end
	else
		s_Player = p_Player
	end

	return s_Player ~= nil and s_Player.onlineId == 0
end

---@param p_PosA Vec3
---@param p_PosB Vec3
---@return number
function Utilities:DistanceFast(p_PosA, p_PosB)
	return (math.abs(p_PosA.x - p_PosB.x) +
		math.abs(p_PosA.y - p_PosB.y) +
		math.abs(p_PosA.z - p_PosB.z))
end

-- Do not use on numerically indexed tables, only tables with string keys.
-- This is a shallow merge, does not recurse deeper than one p_Level.
---@param p_OriginalTable table
---@param p_NewData table
---@return table
function Utilities:mergeKeys(p_OriginalTable, p_NewData)
	for l_Key, l_Value in pairs(p_NewData) do
		p_OriginalTable[l_Key] = l_Value
	end

	return p_OriginalTable
end

-- <object|o> | The object to dump.
-- <boolean|p_Format> | If enabled, tab-spacing and newlines are used.
-- <int|p_MaxLevels> | Max recursion level, defaults to -1 for infinite.
-- <int|level> | Current recursion level.
-- Returns <string> | a string representation of the object.
---@param o any
---@param p_Format boolean
---@param p_MaxLevels integer|nil
---@param p_Level integer|nil
---@return string
function Utilities:dump(o, p_Format, p_MaxLevels, p_Level)
	local s_Tablevel = ''
	local s_Tablevellessone = ''
	local s_Newline = ''
	p_MaxLevels = p_MaxLevels or -1
	p_Level = p_Level or 1

	if p_Format then
		s_Tablevel = string.rep("\t", p_Level)
		s_Tablevellessone = string.rep("\t", math.max(p_Level - 1, 0))
		s_Newline = "\n"
	end

	if o == nil then
		return 'nil'
	end

	if type(o) == 'table' or tostring(o):starts('sol.VEXTRefArray') or tostring(o):starts('sol.VEXTArray') then
		if p_MaxLevels == -1 or p_Level <= p_MaxLevels then
			local s = type(o) .. ' -> { ' .. s_Newline

			for l_Key, l_Value in pairs(o) do
				if type(l_Key) ~= 'number' then
					l_Key = '"' .. l_Key .. '"'
				end

				s = s ..
					s_Tablevel ..
					'[' .. l_Key .. '] = ' .. g_Utilities:dump(l_Value, p_Format, p_MaxLevels, p_Level + 1) .. ',' .. s_Newline
			end

			return s .. s_Tablevellessone .. '}'
		else
			return '{ ' .. tostring(o) .. ' }'
		end
	elseif type(o) == 'userdata' and not tostring(o):starts('sol.VEXTRefArray') and not tostring(o):starts('sol.VEXTArray')
		and getmetatable(o) ~= nil then
		if p_MaxLevels == -1 or p_Level <= p_MaxLevels then
			local s = tostring(o)

			if o.typeInfo ~= nil then
				s = s .. ' (' .. o.typeInfo.name .. ')'
			end
			s = s .. ' -> [ ' .. s_Newline

			for l_Key, _ in pairs(getmetatable(o)) do
				if (not l_Key:starts('__') and l_Key ~= 'typeInfo' and l_Key ~= 'class_cast' and l_Key ~= 'class_check') then
					s = s ..
						s_Tablevel .. l_Key .. ': ' .. g_Utilities:dump(o[l_Key], p_Format, p_MaxLevels, p_Level + 1) .. ',' .. s_Newline
				end
			end

			return s .. s_Tablevellessone .. ']'
		else
			return '[ ' .. tostring(o) .. ' ]'
		end
	else
		return tostring(o)
	end
end

---@param p_Value number
---@return boolean
function Utilities:CheckProbablity(p_Value)
	return MathUtils:GetRandomInt(1, 100) <= p_Value
end

function Utilities:has(p_Object, p_Value)
	for i = 1, #p_Object do
		if p_Object[i] == p_Value then
			return true
		end
	end

	return false
end

---@param p_Value any
---@return boolean
function table:has(p_Value)
	for i = 1, #self do
		if (self[i] == p_Value) then
			return true
		end
	end
	return false
end

---@param p_Value string
---@return boolean
function string:isLower(p_Value)
	return p_Value:lower() == p_Value
end

---@param p_Value string
---@return boolean
function string:isDigit(p_Value)
	return tonumber(p_Value) ~= nil
end

---@param p_Sep string
---@return table<string>
function string:split(p_Sep)
	local s_Fields = nil
	p_Sep, s_Fields = p_Sep or ':', {}
	local s_Pattern = string.format("([^%s]+)", p_Sep)

	self:gsub(s_Pattern, function(c) s_Fields[#s_Fields + 1] = c end)

	return s_Fields
end

---@param p_Start string
---@return boolean
function string:starts(p_Start)
	return string.sub(self, 1, string.len(p_Start)) == p_Start
end

function requireExists(p_Module)
	local function reference(p_Module)
		require(p_Module)
		return true
	end

	local s_Status, s_Error = pcall(reference, p_Module)

	if not (s_Status) then
		return s_Error
	end

	return s_Status
end

if g_Utilities == nil then
	---@type Utilities
	g_Utilities = Utilities()
end

return g_Utilities
