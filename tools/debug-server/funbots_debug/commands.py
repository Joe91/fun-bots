"""Commands for the mod. They wait here until the mod posts its next snapshot and takes them with the answer.
The mod answers with a "command_result" event (DebugBridge:Reply)."""

from __future__ import annotations

import itertools
import threading
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from typing import Any


@dataclass
class Command:
    id: int
    type: str
    args: dict
    status: str = "queued"  # queued -> sent -> ok | error
    created: float = field(default_factory=time.time)
    sent: float | None = None
    done: float | None = None
    result: Any = None
    error: str | None = None
    _event: threading.Event = field(default_factory=threading.Event, repr=False)

    def to_json(self) -> dict:
        return {
            "id": self.id, "type": self.type, "args": self.args, "status": self.status, "created": self.created,
            "sent": self.sent, "done": self.done, "result": self.result, "error": self.error,
        }


class CommandQueue:
    def __init__(self, history: int = 200):
        self._lock = threading.Lock()
        self._ids = itertools.count(1)
        self._pending: list[Command] = []
        self._commands: OrderedDict[int, Command] = OrderedDict()
        self._history = history

    def submit(self, command_type: str, args: dict | None = None) -> Command:
        with self._lock:
            command = Command(id=next(self._ids), type=command_type, args=args or {})
            self._pending.append(command)
            self._commands[command.id] = command
            while len(self._commands) > self._history:
                self._commands.popitem(last=False)
            return command

    def take_pending(self) -> list[dict]:
        """The commands for the answer to the mod."""
        with self._lock:
            pending, self._pending = self._pending, []
            now = time.time()
            for command in pending:
                command.status = "sent"
                command.sent = now
            return [{"id": command.id, "type": command.type, "args": command.args} for command in pending]

    def resolve(self, event: dict) -> Command | None:
        """Takes over a "command_result" event of the mod."""
        with self._lock:
            command = self._commands.get(event.get("id"))
            if command is None:
                return None
            command.done = time.time()
            if event.get("ok"):
                command.status = "ok"
                command.result = event.get("data")
            else:
                command.status = "error"
                command.error = str(event.get("error"))
        command._event.set()
        return command

    def wait(self, command: Command, timeout: float) -> bool:
        """Blocks until the mod answered the command. False on timeout."""
        return command._event.wait(timeout)

    def get(self, command_id: int) -> Command | None:
        with self._lock:
            return self._commands.get(command_id)

    def history(self) -> list[dict]:
        with self._lock:
            return [command.to_json() for command in reversed(self._commands.values())]
