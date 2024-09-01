---@class ClientSpawnPointHelper
---@overload fun():ClientSpawnPointHelper
ClientSpawnPointHelper = class 'ClientSpawnPointHelper'

require('__shared/Config')

function ClientSpawnPointHelper:__init()
	self.m_Enabled = false
	self.m_SpawnPointTable = {}
	self.m_SelectedSpawnPoint = nil
end

---VEXT Shared Partition:Loaded Event
---@param p_Partition DatabasePartition
function ClientSpawnPointHelper:OnPartitionLoaded(p_Partition)
	---@type AlternateSpawnEntityData
	for _, l_Instance in pairs(p_Partition.instances) do
		if l_Instance:Is("AlternateSpawnEntityData") then
			---@type AlternateSpawnEntityData
			l_Instance = AlternateSpawnEntityData(l_Instance)
			table.insert(self.m_SpawnPointTable, l_Instance.transform)
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

---VEXT Client UI:DrawHud Event
function ClientSpawnPointHelper:OnUIDrawHud()
	self.m_SelectedSpawnPoint = nil

	if not Config.DrawSpawnPoints or not self.m_Enabled then
		return
	end

	local s_LocalPlayer = PlayerManager:GetLocalPlayer()

	if s_LocalPlayer == nil then
		return
	end

	if s_LocalPlayer.soldier == nil then
		return
	end

	for _, l_Transform in pairs(self.m_SpawnPointTable) do
		if l_Transform.trans:Distance(s_LocalPlayer.soldier.worldTransform.trans) <= Config.SpawnPointRange then
			self:DrawSpawnPoint(l_Transform)
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

function ClientSpawnPointHelper:DrawSpawnPoint(p_Transform)
	local s_Color = Vec4(1, 1, 1, 0.5)
	local s_PointScreenPos = ClientUtils:WorldToScreen(p_Transform.trans)

	-- Skip to the next point if this one isn't in view.
	if s_PointScreenPos ~= nil then
		local s_Center = ClientUtils:GetWindowSize() / 2

		-- Select point if it's close to the hitPosition.
		if s_Center:Distance(s_PointScreenPos) < 20 then
			self.m_SelectedSpawnPoint = p_Transform
			s_Color = Vec4(0, 0, 1, 0.5)
		end
	end

	local s_Up = Vec3(0, 1.5, 0)
	local s_Offset = self:GetForwardOffsetFromLT(p_Transform)

	DebugRenderer:DrawSphere(p_Transform.trans, 0.3, s_Color, true, false)
	DebugRenderer:DrawSphere(p_Transform.trans + s_Up, 0.15, s_Color, true, false)
	DebugRenderer:DrawSphere(s_Offset + s_Up, 0.1, s_Color, true, false)

	DebugRenderer:DrawLine(p_Transform.trans, p_Transform.trans + s_Up, s_Color, s_Color)
	DebugRenderer:DrawLine(p_Transform.trans + s_Up, s_Offset + s_Up, s_Color, s_Color)
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
