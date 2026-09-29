---@class DebugBridge
---@overload fun():DebugBridge
DebugBridge = class('DebugBridge')

-- Streams the game-state to an external debug-server (tools/debug-server) and executes its commands.
-- Enable it with Registry.DEBUG.DEBUG_BRIDGE, "!debugbridge on|off" or RCON "funbots.debugBridge on|off".
--
-- Protocol: JSON over HTTP, the mod always starts the request and only one request is in flight.
--   POST <url>/api/ingest   { v, seq, frames = { snapshot }, events = { event }, dropped }
--   response                { commands = { { id, type, args } } }
-- A snapshot is { t, <collector-name> = data, ... }, an event is { t, type, ... }.
-- Each command is answered by the event { type = "command_result", id, ok, data | error }.
--
-- Extend it with:
--   DebugBridge:RegisterCollector(name, callback)  part of every snapshot, see DebugSnapshots
--   DebugBridge:RegisterCommand(type, callback)    command of the debug-server, see DebugCommands
--   DebugBridge:Event(type, data)                  anything else, from anywhere. Check m_Enabled first.
--   DebugBridge:AddTask(task)                      work spread over several updates, see MapScanner
-- Collectors and commands run in pcall, a bug in them only produces an "error" event.

local PROTOCOL_VERSION = 1
-- Events queued until the next request. Newer ones are dropped once full (counted in "dropped").
local MAX_QUEUED_EVENTS = 5000
-- Tasks pause while this many events are queued, so a long scan can't flood the queue.
local TASK_EVENT_LIMIT = 1000
-- Seconds between two tries while the debug-server is not reachable.
local RETRY_INTERVAL = 3.0
-- Timeout of a request in seconds.
local HTTP_TIMEOUT = 5

-- Returned by a command-callback that answers later with DebugBridge:Reply.
DebugBridge.ASYNC = {}

---Rounds to cm (or p_Decimals). NaN and inf are not valid JSON and become 0.
---@param p_Value number
---@param p_Decimals? integer
---@return number
function DebugBridge.Round(p_Value, p_Decimals)
	if p_Value ~= p_Value or p_Value == math.huge or p_Value == -math.huge then
		return 0
	end

	local s_Factor = 10 ^ (p_Decimals or 2)
	return math.floor(p_Value * s_Factor + 0.5) / s_Factor
end

---@param p_Vec Vec3
---@return number[]
function DebugBridge.Vec(p_Vec)
	local s_Round = DebugBridge.Round
	return { s_Round(p_Vec.x), s_Round(p_Vec.y), s_Round(p_Vec.z) }
end

function DebugBridge:__init()
	self.m_Enabled = false
	-- Read by ServerRaycasts before it builds a trace. Only true while connected and the channel is on.
	self.m_TraceRaycasts = false

	---@type { Name: string, Callback: fun(p_Bridge: DebugBridge): any }[]
	self._Collectors = {}
	---@type table<string, fun(p_Args: table, p_Bridge: DebugBridge, p_Command: table): any>
	self._Commands = {}
	---`[collector-name or "traces"] -> false` for switched off channels.
	self._Channels = {}
	self._Tasks = {}
	self._Url = Registry.DEBUG.DEBUG_BRIDGE_URL
	self._Interval = Registry.DEBUG.DEBUG_BRIDGE_INTERVAL
	self:_ResetConnection()

	if Registry.DEBUG.DEBUG_BRIDGE then
		self:SetEnabled(true)
	end
end

function DebugBridge:_ResetConnection()
	self._Events = {}
	self._DroppedEvents = 0
	self._InFlight = false
	self._Connected = false
	self._Timer = 0.0
	self._Seq = 0
	self:_UpdateTraceState()
end

function DebugBridge:_UpdateTraceState()
	self.m_TraceRaycasts = self.m_Enabled and self._Connected and self._Channels.traces ~= false
end

-- =============================================
-- Public Functions
-- =============================================

---@param p_Enabled boolean
function DebugBridge:SetEnabled(p_Enabled)
	if self.m_Enabled == p_Enabled then
		return
	end

	self.m_Enabled = p_Enabled
	self:_AbortTasks('debug-bridge disabled')
	self:_ResetConnection()
	print('[DebugBridge] ' .. (p_Enabled and ('on, sending to ' .. self._Url) or 'off'))
end

---@return boolean
function DebugBridge:IsEnabled()
	return self.m_Enabled
end

---@return boolean
function DebugBridge:IsConnected()
	return self._Connected
end

---@return string
function DebugBridge:GetUrl()
	return self._Url
end

---@param p_Url string
function DebugBridge:SetUrl(p_Url)
	self._Url = p_Url
	self._Connected = false
	self:_UpdateTraceState()
end

---@param p_Seconds number
function DebugBridge:SetInterval(p_Seconds)
	self._Interval = math.max(0.02, p_Seconds)
end

---@param p_Name string collector-name or "traces"
---@param p_Enabled boolean
function DebugBridge:SetChannel(p_Name, p_Enabled)
	self._Channels[p_Name] = p_Enabled
	self:_UpdateTraceState()
end

---@return table<string, boolean>
function DebugBridge:GetChannels()
	local s_Channels = { traces = self._Channels.traces ~= false }
	for l_Index = 1, #self._Collectors do
		local l_Name = self._Collectors[l_Index].Name
		s_Channels[l_Name] = self._Channels[l_Name] ~= false
	end
	return s_Channels
end

---@param p_Name string key of the data in the snapshot
---@param p_Callback fun(p_Bridge: DebugBridge): any returns plain tables only (no engine-objects)
function DebugBridge:RegisterCollector(p_Name, p_Callback)
	self._Collectors[#self._Collectors + 1] = { Name = p_Name, Callback = p_Callback }
end

---The callback returns the data of the answer, raises an error, or returns DebugBridge.ASYNC and answers later
---with DebugBridge:Reply(p_Command.id, ...).
---@param p_Type string
---@param p_Callback fun(p_Args: table, p_Bridge: DebugBridge, p_Command: table): any
function DebugBridge:RegisterCommand(p_Type, p_Callback)
	self._Commands[p_Type] = p_Callback
end

---The registered commands, sorted. Tells the debug-server whether the running mod is older than itself.
---@return string[]
function DebugBridge:GetCommandNames()
	local s_Names = {}
	for l_Name, _ in pairs(self._Commands) do
		s_Names[#s_Names + 1] = l_Name
	end
	table.sort(s_Names)
	return s_Names
end

---@param p_Type string
---@param p_Data? table plain table, gets the fields "type" and "t"
function DebugBridge:Event(p_Type, p_Data)
	if not self.m_Enabled then
		return
	end

	if #self._Events >= MAX_QUEUED_EVENTS then
		self._DroppedEvents = self._DroppedEvents + 1
		return
	end

	local s_Event = p_Data or {}
	s_Event.type = p_Type
	s_Event.t = DebugBridge.Round(SharedUtils:GetTime(), 3)
	self._Events[#self._Events + 1] = s_Event
end

---A raycast for the map. Called by ServerRaycasts while m_TraceRaycasts is set.
---@param p_Kind string what the raycast was for, e.g. "botbot"
---@param p_From Vec3
---@param p_To Vec3
---@param p_Visible boolean
---@param p_HitPosition Vec3|nil position of the blocking hit
function DebugBridge:Trace(p_Kind, p_From, p_To, p_Visible, p_HitPosition)
	self:Event('ray', {
		kind = p_Kind,
		from = DebugBridge.Vec(p_From),
		to = DebugBridge.Vec(p_To),
		visible = p_Visible,
		hit = (not p_Visible and p_HitPosition ~= nil) and DebugBridge.Vec(p_HitPosition) or nil,
	})
end

---@param p_Id any id of the command
---@param p_Ok boolean
---@param p_Data any data of the answer, or the error-message
function DebugBridge:Reply(p_Id, p_Ok, p_Data)
	if p_Ok then
		self:Event('command_result', { id = p_Id, ok = true, data = p_Data })
	else
		self:Event('command_result', { id = p_Id, ok = false, error = tostring(p_Data) })
	end
end

---A task is a table with `Update(self, p_Bridge) -> boolean` (true = done) and optional `Abort(self, p_Bridge, p_Reason)`.
---Tasks only run while the debug-server is connected.
---@param p_Task table
function DebugBridge:AddTask(p_Task)
	self._Tasks[#self._Tasks + 1] = p_Task
end

---@param p_Filter? fun(p_Task: table): boolean only abort the tasks the filter returns true for
---@param p_Reason string
---@return integer aborted tasks
function DebugBridge:AbortTasks(p_Filter, p_Reason)
	local s_Count = 0
	for l_Index = #self._Tasks, 1, -1 do
		local l_Task = self._Tasks[l_Index]
		if p_Filter == nil or p_Filter(l_Task) then
			if l_Task.Abort then
				pcall(l_Task.Abort, l_Task, self, p_Reason)
			end
			table.remove(self._Tasks, l_Index)
			s_Count = s_Count + 1
		end
	end
	return s_Count
end

-- =============================================
-- Events
-- =============================================

---VEXT Shared Engine:Update Event
---@param p_DeltaTime number
function DebugBridge:OnEngineUpdate(p_DeltaTime)
	if not self.m_Enabled then
		return
	end

	if self._Connected and #self._Events < TASK_EVENT_LIMIT then
		self:_UpdateTasks()
	end

	self._Timer = self._Timer + p_DeltaTime
	if self._InFlight or self._Timer < (self._Connected and self._Interval or RETRY_INTERVAL) then
		return
	end

	self._Timer = 0.0
	self:_Send()
end

---VEXT Shared Level:Destroy Event
function DebugBridge:OnLevelDestroy()
	self:_AbortTasks('level destroyed')
	self:Event('level_destroyed')
end

-- =============================================
-- Private Functions
-- =============================================

---@param p_Reason string
function DebugBridge:_AbortTasks(p_Reason)
	self:AbortTasks(nil, p_Reason)
end

function DebugBridge:_UpdateTasks()
	for l_Index = #self._Tasks, 1, -1 do
		local l_Task = self._Tasks[l_Index]
		local s_Ok, s_Done = pcall(l_Task.Update, l_Task, self)

		if not s_Ok then
			self:Event('error', { source = 'task', message = tostring(s_Done) })
			if l_Task.CommandId ~= nil then
				self:Reply(l_Task.CommandId, false, s_Done)
			end
			table.remove(self._Tasks, l_Index)
		elseif s_Done then
			table.remove(self._Tasks, l_Index)
		end
	end
end

---@return table
function DebugBridge:_TakeSnapshot()
	local s_Frame = { t = DebugBridge.Round(SharedUtils:GetTime(), 3) }

	for l_Index = 1, #self._Collectors do
		local l_Collector = self._Collectors[l_Index]
		if self._Channels[l_Collector.Name] ~= false then
			local s_Ok, s_Data = pcall(l_Collector.Callback, self)
			if s_Ok then
				s_Frame[l_Collector.Name] = s_Data
			else
				self:Event('error', { source = l_Collector.Name, message = tostring(s_Data) })
			end
		end
	end

	return s_Frame
end

function DebugBridge:_Send()
	self._Seq = self._Seq + 1

	-- While not connected, only a small hello without snapshot is sent.
	local s_Frames = {}
	if self._Connected then
		s_Frames[1] = self:_TakeSnapshot()
	end

	local s_Ok, s_Body = pcall(json.encode, {
		v = PROTOCOL_VERSION,
		seq = self._Seq,
		frames = s_Frames,
		events = self._Events,
		dropped = self._DroppedEvents,
	})
	self._Events = {}
	self._DroppedEvents = 0

	if not s_Ok then
		print('[DebugBridge] json.encode failed: ' .. tostring(s_Body))
		return
	end

	local s_Options = HttpOptions({}, HTTP_TIMEOUT)
	s_Options:SetHeader('Content-Type', 'application/json')
	self._InFlight = true
	Net:PostHTTPAsync(self._Url .. '/api/ingest', s_Body, s_Options, self, self._OnResponse)
end

---@param p_Response HttpResponse|nil
function DebugBridge:_OnResponse(p_Response)
	self._InFlight = false
	if not self.m_Enabled then
		return
	end

	if p_Response == nil or p_Response.status ~= 200 then
		if self._Connected then
			print('[DebugBridge] lost connection to ' .. self._Url .. ' (status ' ..
				tostring(p_Response and p_Response.status) .. ')')
			self:_AbortTasks('connection lost')
		end
		self._Connected = false
		self:_UpdateTraceState()
		return
	end

	if not self._Connected then
		print('[DebugBridge] connected to ' .. self._Url)
		self._Connected = true
		self:_UpdateTraceState()
		-- Send the first snapshot right away.
		self._Timer = self._Interval
	end

	local s_Ok, s_Data = pcall(json.decode, p_Response.body)
	if not s_Ok or type(s_Data) ~= 'table' or type(s_Data.commands) ~= 'table' then
		return
	end

	for l_Index = 1, #s_Data.commands do
		self:_ExecuteCommand(s_Data.commands[l_Index])
	end
end

---@param p_Command table { id, type, args }
function DebugBridge:_ExecuteCommand(p_Command)
	if type(p_Command) ~= 'table' then
		return
	end

	local s_Callback = self._Commands[p_Command.type]
	if s_Callback == nil then
		self:Reply(p_Command.id, false, 'unknown command: ' .. tostring(p_Command.type))
		return
	end

	local s_Args = type(p_Command.args) == 'table' and p_Command.args or {}
	local s_Ok, s_Result = pcall(s_Callback, s_Args, self, p_Command)

	if not s_Ok then
		self:Reply(p_Command.id, false, s_Result)
	elseif s_Result ~= DebugBridge.ASYNC then
		self:Reply(p_Command.id, true, s_Result)
	end
end

if g_DebugBridge == nil then
	---@type DebugBridge
	g_DebugBridge = DebugBridge()
end

return g_DebugBridge
