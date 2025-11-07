---@class ClientSpawnPointHelper
---@overload fun():ClientSpawnPointHelper
ClientSpawnPointHelper = class 'ClientSpawnPointHelper'

require('__shared/Config')
local m_Utilities = require('__shared/Utilities')

function ClientSpawnPointHelper:__init()
	self.m_Enabled = false
	self.m_SpawnPointTable = {}
	self.m_SelectedSpawnPoint = nil
	self.m_SelectedSpawnPointIndex = nil
end

---VEXT Shared Partition:Loaded Event
---@param p_Partition DatabasePartition
function ClientSpawnPointHelper:OnPartitionLoaded(p_Partition)
	---@type AlternateSpawnEntityData
	for _, l_Instance in pairs(p_Partition.instances) do
		if l_Instance:Is("AlternateSpawnEntityData") then
			---@type AlternateSpawnEntityData
			l_Instance = AlternateSpawnEntityData(l_Instance)
			self.m_SpawnPointTable[#self.m_SpawnPointTable + 1] = l_Instance.transform
		end
	end
end

---VEXT Shared Level:Destroy Event
function ClientSpawnPointHelper:OnLevelDestroy()
	self.m_SpawnPointTable = {}
end

function ClientSpawnPointHelper:OnSetEnabled(p_Args)
	local s_Enabled = p_Args

	if type(p_Args) == 'table' then
		s_Enabled = p_Args[1]
	end

	self.m_Enabled = (s_Enabled == true or s_Enabled == 'true' or s_Enabled == '1')
end

function ClientSpawnPointHelper:FindSpawn(p_Position)
	local s_ClosestIndex = 0
	local s_ClosestDistance = 999999

	for l_Index = 1, #self.m_SpawnPointTable do
		local s_Transform = self.m_SpawnPointTable[l_Index]
		local s_Distance = m_Utilities:DistanceFast(s_Transform.trans, p_Position)
		if s_Distance < s_ClosestDistance then
			s_ClosestIndex = l_Index
			s_ClosestDistance = s_Distance
		end
	end

	if s_ClosestDistance < 0.6 then
		return s_ClosestIndex
	end
end

function ClientSpawnPointHelper:GetSelectedSpawn()
	return self.m_SelectedSpawnPointIndex
end

function ClientSpawnPointHelper:Update(p_PlayerPos, p_NodesToDraw, p_LinesToDraw)
	if not Config.DrawSpawnPoints or not self.m_Enabled then
		return
	end

	for l_Index = 1, #self.m_SpawnPointTable do
		local l_Transform = self.m_SpawnPointTable[l_Index]
		if m_Utilities:DistanceFast(l_Transform.trans, p_PlayerPos) <= Config.SpawnPointRange then
			-- self:DrawSpawnPoint(l_Transform, l_Index)
			local s_Color = Vec4(1, 1, 1, 0.5)
			local s_PointScreenPos = ClientUtils:WorldToScreen(l_Transform.trans)

			-- Skip to the next point if this one isn't in view.
			-- if s_PointScreenPos ~= nil then
			local s_Center = ClientUtils:GetWindowSize() / 2

			-- Select point if it's close to the hitPosition.
			if s_PointScreenPos and s_Center:Distance(s_PointScreenPos) < 20 then
				self.m_SelectedSpawnPoint = l_Transform
				self.m_SelectedSpawnPointIndex = l_Index
				s_Color = Vec4(0, 0, 1, 0.5)
			end
			-- end

			-- local s_Up = Vec3(0, 1.5, 0)
			-- local s_Offset = self:GetForwardOffsetFromLT(p_Transform)

			table.insert(p_NodesToDraw, {
				pos = l_Transform.trans,
				radius = 0.3,
				color = s_Color,
				renderLines = true,
				smallSizeSegmentDecrease = false,
			})
			-- table.insert(p_NodesToDraw, {
			-- 	pos = l_Transform.trans + s_Up,
			-- 	radius = 0.3,
			-- 	color = s_Color,
			-- 	renderLines = true,
			-- 	smallSizeSegmentDecrease = false,
			-- })
			-- table.insert(p_NodesToDraw, {
			-- 	pos = s_Offset + s_Up,
			-- 	radius = 0.1,
			-- 	color = s_Color,
			-- 	renderLines = true,
			-- 	smallSizeSegmentDecrease = false,
			-- })

			-- table.insert(p_LinesToDraw, {
			-- 	from = l_Transform.trans,
			-- 	to = l_Transform.trans + s_Up,
			-- 	colorFrom = s_Color,
			-- 	colorTo = s_Color,
			-- })
			-- table.insert(p_LinesToDraw, {
			-- 	from = l_Transform.trans + s_Up,
			-- 	to = s_Offset + s_Up,
			-- 	colorFrom = s_Color,
			-- 	colorTo = s_Color,
			-- })
		end
	end
end

---VEXT Client Client:UpdateInput Event
---@param p_DeltaTime number
function ClientSpawnPointHelper:OnClientUpdateInput(p_DeltaTime)
	if not Config.DrawSpawnPoints or not self.m_Enabled then
		return
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_T) and self.m_SelectedSpawnPoint ~= nil then
		local s_LocalPlayer = PlayerManager:GetLocalPlayer()

		if s_LocalPlayer == nil or s_LocalPlayer.soldier == nil then
			return
		end

		NetEvents:SendLocal("SpawnPointHelper:TeleportTo", self.m_SelectedSpawnPoint)
	end
end

-- Returns a Vec3 that's offset in the direction of the linearTransform.
function ClientSpawnPointHelper:GetForwardOffsetFromLT(p_Transform)
	-- We get the direction from the forward vector.
	local s_Direction = p_Transform.forward

	local s_Forward = Vec3(
		p_Transform.trans.x + (s_Direction.x * 0.4),
		p_Transform.trans.y + (s_Direction.y * 0.4),
		p_Transform.trans.z + (s_Direction.z * 0.4))

	return s_Forward
end

if g_ClientSpawnPointHelper == nil then
	---@type ClientSpawnPointHelper
	g_ClientSpawnPointHelper = ClientSpawnPointHelper()
end

return g_ClientSpawnPointHelper
