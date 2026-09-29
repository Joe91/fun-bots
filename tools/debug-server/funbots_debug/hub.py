"""Center of the server: takes the requests of the mod, updates state and analyzers, and pushes the changes to
all browsers (and other subscribers)."""

from __future__ import annotations

import json
import queue
import threading
import time
from typing import Any, Callable

from .analyzers import Analyzer
from .commands import Command, CommandQueue
from .protocol import as_list
from .rcon import RconClient, RconError
from .recorder import Recorder
from .state import WorldState

# Seconds without request after which the mod counts as disconnected.
MOD_TIMEOUT = 4.0
# Seconds between two analysis-messages to the browsers.
ANALYSIS_INTERVAL = 1.0
# Events that get a message of their own. All others go with the next "frame" message.
OWN_MESSAGE_EVENTS = {"nodes", "nodes_started", "scan_started", "scan_row", "command_result"}


class Subscriber:
    """One browser (or script). Messages are pre-encoded JSON strings."""

    def __init__(self, maxsize: int = 2000):
        self.queue: queue.Queue[tuple[str, str]] = queue.Queue(maxsize=maxsize)

    def push(self, kind: str, data: str) -> None:
        try:
            self.queue.put_nowait((kind, data))
        except queue.Full:
            # Too slow: throw everything away and let the browser load the whole state again.
            while not self.queue.empty():
                try:
                    self.queue.get_nowait()
                except queue.Empty:
                    break
            self.queue.put_nowait(("resync", "{}"))


class Hub:
    def __init__(self, analyzers: list[Analyzer], recorder: Recorder | None = None, accept_commands: bool = True,
                 rcon: RconClient | None = None):
        self.lock = threading.RLock()
        self.state = WorldState()
        self.commands = CommandQueue()
        self.analyzers = analyzers
        self.recorder = recorder
        # False in replay-mode: nobody would answer.
        self.accept_commands = accept_commands
        # Direct connection to the RCON-port of the game-server, None without password.
        self.rcon = rcon
        self._subscribers: set[Subscriber] = set()
        self._subscribers_lock = threading.Lock()
        self._last_request = 0.0
        self._last_analysis = 0.0
        self.mod_connected = False
        self.requests = 0
        self.bytes_received = 0
        self.dropped_events = 0
        # Hooks for own code: called with (payload) after every request of the mod, under the lock.
        self.on_ingest: list[Callable[[dict], None]] = []

    # --- mod-side ----------------------------------------------------------------------------------------------

    def ingest(self, payload: dict, size: int = 0) -> dict:
        """A request of the mod. Returns the answer (the commands for the mod)."""
        messages: list[tuple[str, Any]] = []
        with self.lock:
            now = time.monotonic()
            self._last_request = now
            self.requests += 1
            self.bytes_received += size
            self.dropped_events += int(payload.get("dropped") or 0)
            if not self.mod_connected:
                self.mod_connected = True
                messages.append(("status", self._status()))

            events = as_list(payload.get("events"))
            frames = as_list(payload.get("frames"))

            if self.recorder is not None:
                level = self.state.level
                for frame in frames:
                    level = (frame.get("meta") or {}).get("level") or level
                self.recorder.write(payload, level)

            frame_events = []
            for event in events:
                if not isinstance(event, dict):
                    continue
                if self.state.apply_event(event) == "reset":
                    self._reset(messages, already_reset=True)
                if event.get("type") == "command_result":
                    command = self.commands.resolve(event)
                    if command is not None:
                        messages.append(("command", command.to_json()))
                for analyzer in self.analyzers:
                    analyzer.on_event(event, self.state)
                if event.get("type") in OWN_MESSAGE_EVENTS:
                    if event.get("type") != "command_result":
                        messages.append((event["type"], event))
                else:
                    frame_events.append(event)

            for frame in frames:
                if self.state.apply_frame(frame):
                    self._reset(messages, already_reset=True)
                for analyzer in self.analyzers:
                    analyzer.on_frame(frame, self.state)

            if frames or frame_events:
                messages.append(("frame", {
                    "time": self.state.time,
                    "meta": self.state.meta,
                    "bots": list(self.state.bots.values()),
                    "players": list(self.state.players.values()),
                    "vehicles": list(self.state.vehicles.values()),
                    "objectives": self.state.objectives,
                    "extras": self.state.extras,
                    "events": frame_events,
                }))

            if now - self._last_analysis > ANALYSIS_INTERVAL:
                self._last_analysis = now
                messages.append(("analysis", self._analysis()))

            answer = {"commands": self.commands.take_pending() if self.accept_commands else []}

        self._publish(messages)
        return answer

    def _reset(self, messages: list, already_reset: bool = False) -> None:
        if not already_reset:
            self.state.reset()
        for analyzer in self.analyzers:
            analyzer.reset()
        if self.recorder is not None:
            self.recorder.split()
        messages.append(("reset", {"level": self.state.level}))

    def check_connection(self) -> None:
        """Called regularly by the server: notices a mod that stopped sending."""
        with self.lock:
            if not self.mod_connected or time.monotonic() - self._last_request < MOD_TIMEOUT:
                return
            self.mod_connected = False
            status = self._status()
        self._publish([("status", status)])

    # --- browser-side ------------------------------------------------------------------------------------------

    def submit_command(self, command_type: str, args: dict | None = None) -> Command:
        command = self.commands.submit(command_type, args)
        self._publish([("command", command.to_json())])
        return command

    def run_command(self, command_type: str, args: dict | None = None, timeout: float = 10.0) -> Command:
        """Sends a command and blocks until the mod answered (for own scripts). Check command.status."""
        command = self.submit_command(command_type, args)
        self.commands.wait(command, timeout)
        return command

    def clear_scans(self, scan: int | None = None) -> list[int]:
        """Forgets one scan (None = all), also in all browsers. A scan that is still running gets stopped."""
        with self.lock:
            removed = self.state.clear_scans(scan)
        running = [grid.scan for grid in removed if not grid.complete]
        if running and self.accept_commands:
            self.submit_command("scan_stop", {} if scan is None else {"scan": scan})
        ids = [grid.scan for grid in removed]
        self._publish([("scans_cleared", {"scans": ids})])
        return ids

    def run_rcon(self, words: list[str]) -> list[str]:
        """A command over the RCON-port. Raises RconError. The browsers get the new RCON-state."""
        assert self.rcon is not None
        try:
            return self.rcon.command(words)
        finally:
            self._publish([("status", self._status())])

    def check_rcon(self) -> None:
        """Logs in once, so problems show up at the start and not with the first command."""
        if self.rcon is None:
            return
        try:
            self.rcon.connect()
        except RconError:
            pass
        self._publish([("status", self._status())])

    def subscribe(self) -> Subscriber:
        subscriber = Subscriber()
        with self._subscribers_lock:
            self._subscribers.add(subscriber)
        return subscriber

    def unsubscribe(self, subscriber: Subscriber) -> None:
        with self._subscribers_lock:
            self._subscribers.discard(subscriber)

    def snapshot(self) -> dict:
        """The whole state for a new browser."""
        with self.lock:
            data = self.state.to_json()
            data["status"] = self._status()
            data["analysis"] = self._analysis()
            data["commands"] = self.commands.history()[:50]
            return data

    # --- helpers -----------------------------------------------------------------------------------------------

    def _status(self) -> dict:
        return {
            "modConnected": self.mod_connected,
            "acceptCommands": self.accept_commands,
            "requests": self.requests,
            "bytesReceived": self.bytes_received,
            "droppedEvents": self.dropped_events,
            "recording": str(self.recorder.path) if self.recorder and self.recorder.path else None,
            "rcon": self.rcon.to_json() if self.rcon else None,
        }

    def _analysis(self) -> dict:
        findings = []
        stats = {}
        for analyzer in self.analyzers:
            findings.extend(finding.to_json() for finding in analyzer.findings())
            analyzer_stats = analyzer.stats()
            if analyzer_stats:
                stats[analyzer.name] = analyzer_stats
        findings.sort(key=lambda finding: -finding["time"])
        stats["connection"] = {"requests": self.requests, "MB received": round(self.bytes_received / 1e6, 1),
                               "dropped events": self.dropped_events}
        return {"findings": findings[:200], "stats": stats}

    def _publish(self, messages: list[tuple[str, Any]]) -> None:
        if not messages:
            return
        encoded = [(kind, json.dumps(data, separators=(",", ":"))) for kind, data in messages]
        with self._subscribers_lock:
            subscribers = list(self._subscribers)
        for subscriber in subscribers:
            for kind, data in encoded:
                subscriber.push(kind, data)
