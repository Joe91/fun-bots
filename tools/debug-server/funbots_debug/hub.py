"""Center of the server: takes the requests of the mod, updates state and analyzers, and pushes the changes to
all browsers (and other subscribers)."""

from __future__ import annotations

import json
import math
import queue
import threading
import time
from pathlib import Path
from typing import Any, Callable

from .analyzers import Analyzer
from .commands import Command, CommandQueue
from .paths.labeler import (Options, anchors_from_flags, anchors_from_labels, apply_patch, label, make_patch,
                            merge_anchors, uses_objectives)
from .paths.mapfile import MapData
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
# Switches of the labeler the browser may set (paths/labeler.py, Options).
LABEL_OPTIONS = ("relabel", "relink", "crossings", "vehicles", "loops")
# Seconds to wait for the mod to take over the labels.
APPLY_TIMEOUT = 30.0
# Metres a node of a waypoint-file may be off the one in the game (the mod sends positions rounded to cm).
WRITE_TOLERANCE = 0.05


class LabelError(Exception):
    """The labeler can't run, or its result can't be applied."""


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
                 rcon: RconClient | None = None, mapfiles: Path | None = None):
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
        # The waypoint-files (mapfiles/ of the repository), for writing the labels.
        self.mapfiles = mapfiles
        # Last run of the labeler: {"level", "result", "patch"}, see label_paths.
        self.labels: dict | None = None
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
                if event.get("type") == "nodes_started" and self.labels is not None:
                    # New waypoints, the labels were made for the old ones.
                    self.labels = None
                    messages.append(("labels", None))
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
        self.labels = None
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

    # --- labeling the paths (paths/labeler.py) ------------------------------------------------------------------

    def label_paths(self, options: dict | None = None) -> dict:
        """Runs the labeler on the waypoints of the game (load them first). Nothing changes in the game yet: the
        result waits in self.labels for apply_labels or write_labels, the browsers show it."""
        options = options or {}
        with self.lock:
            rows = self.state.paths
            if not rows:
                raise LabelError("no waypoints: load the waypoints first")
            if any("inputs" not in entry for entry in rows.values()):
                raise LabelError("the waypoints came without links: update the mod and load them again")
            before = MapData.from_rows(rows)
            data = MapData.from_rows(rows)
            flags = list(self.state.objectives.get("flags") or [])
            meta = self.state.meta
            mode = str(meta.get("mode") or "")
            level = meta.get("paths") or f"{str(meta.get('level') or '').rsplit('/', 1)[-1]}_{mode}"

        anchors = merge_anchors(anchors_from_flags(flags), anchors_from_labels(before))
        switches = {key: bool(options[key]) for key in LABEL_OPTIONS if key in options}
        result = label(data, anchors, Options(objectives=uses_objectives(mode), **switches))
        labels = {"level": level, "result": result.to_json(), "patch": make_patch(before, data)}
        with self.lock:
            self.labels = labels
            answer = self._labels_json()
        self._publish([("labels", answer)])
        return answer

    def apply_labels(self, save: bool = True, timeout: float = APPLY_TIMEOUT) -> dict:
        """Sends the labels to the mod (paths_apply), which saves them into mod.db with save. Blocks until the
        mod answered."""
        with self.lock:
            labels = self._current_labels()
            if not labels["patch"]:
                raise LabelError("nothing to change")
        if not self.accept_commands:
            raise LabelError("replay-mode, no mod to send the labels to")
        command = self.submit_command("paths_apply", {"paths": labels["patch"], "save": save})
        self.commands.wait(command, timeout)
        if command.status == "ok":
            with self.lock:
                try:
                    self._patch_rows(labels["patch"])
                except (KeyError, ValueError):
                    pass  # The waypoints were loaded again in the meantime, they are up to date.
                if self.labels is labels:
                    self.labels = None
                paths = json.loads(json.dumps(self.state.paths))
            self._publish([("labels", None), ("paths", paths)])
        return command.to_json()

    def write_labels(self) -> dict:
        """Writes the labels into the waypoint-file of the level. The file has to hold the same paths as the game."""
        with self.lock:
            labels = self._current_labels()
            rows = {entry["path"]: self.state.paths.get(entry["path"]) for entry in labels["patch"]}
        if self.mapfiles is None:
            raise LabelError("no folder for the waypoint-files, start with --mapfiles")
        file = self.mapfiles / f"{labels['level']}.map"
        if not file.is_file():
            raise LabelError(f"{file} doesn't exist: export the waypoints with the fun-bots-helper first")
        data = MapData.load(file)
        try:
            apply_patch(data, labels["patch"])
            for index, row in rows.items():
                for node, pos in zip(data.paths[index].nodes, (row or {}).get("points") or []):
                    if math.dist(node.pos, pos) > WRITE_TOLERANCE:
                        raise ValueError(f"node {index}:{node.point} is somewhere else")
        except ValueError as error:
            raise LabelError(f"{file.name} doesn't hold the paths of the game ({error}): save them in the game and "
                             f"export them with the fun-bots-helper first") from error
        data.save(file)
        return {"file": str(file), "paths": len(labels["patch"])}

    def _current_labels(self) -> dict:
        if self.labels is None:
            raise LabelError("no labels: run the labeler first")
        return self.labels

    def _labels_json(self) -> dict | None:
        if self.labels is None:
            return None
        return dict(self.labels["result"], level=self.labels["level"], patched=len(self.labels["patch"]))

    def _patch_rows(self, patch: list[dict]) -> None:
        """Takes the applied labels over into the waypoints of the state."""
        rows = self.state.paths
        data = MapData.from_rows(rows)
        apply_patch(data, patch)
        for entry in patch:
            path = data.paths[entry["path"]]
            row = rows[entry["path"]]
            row["inputs"] = [node.input for node in path.nodes]
            row["data"] = {str(node.point): node.data for node in path.nodes if node.data}
            row["objectives"] = path.objectives

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
            data["labels"] = self._labels_json()
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
