class('FunBotUIServer')

local TraceManager = require('traceManager');

function FunBotUIServer:__init()
	self._webui = 0;
	
    NetEvents:Subscribe('keypressF5', self, self._onF5)
    NetEvents:Subscribe('keypressF6', self, self._onF6)
    NetEvents:Subscribe('keypressF7', self, self._onF7)
    NetEvents:Subscribe('keypressF8', self, self._onF8)
    NetEvents:Subscribe('keypressF9', self, self._onF9)
    NetEvents:Subscribe('keypressF10', self, self._onF10)
    NetEvents:Subscribe('keypressF11', self, self._onF11)
    NetEvents:Subscribe('keypressF12', self, self._onF12)
end

function FunBotServer:_onF5(player, data)
	print(player.name .." pressed F5")
	local traceIndex = tonumber(0)
	TraceManager:startTrace(player, traceIndex)
end
function FunBotServer:_onF6(player, data)
	print(player.name .." pressed F6")
	TraceManager:endTrace(player)
end
function FunBotServer:_onF7(player, data)
	print(player.name .." pressed F7")
	local traceIndex = tonumber(0)
    TraceManager:clearTrace(traceIndex)
end
function FunBotServer:_onF8(player, data)
	print(player.name .." pressed F8")
	TraceManager:clearAllTraces()
end
function FunBotServer:_onF9(player, data)
	print(player.name .." pressed F9")
	TraceManager:savePaths()
end
function FunBotServer:_onF10(player, data)
	print(player.name .." pressed F10")
end
function FunBotServer:_onF11(player, data)
	print(player.name .." pressed F11")
end
function FunBotServer:_onF12(player, data)
	print(player.name .." pressed F12")
end

if (g_FunBotUIServer == nil) then
	g_FunBotUIServer = FunBotUIServer();
end

return g_FunBotUIServer;