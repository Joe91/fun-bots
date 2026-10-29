"""Debug-server for fun-bots.

The mod (ext/Server/Debug/DebugBridge.lua) posts snapshots and events to this server and gets commands back.
The server keeps a model of the game (state.py), runs analyzers on it (analyzers/), records it (recorder.py)
and shows everything live in the browser (web/).
"""

__version__ = "0.1.0"
PROTOCOL_VERSION = 1
