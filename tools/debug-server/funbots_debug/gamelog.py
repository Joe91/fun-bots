"""Follows the console output of the game-server (a file, --game-log) and hands its lines to the hub.

The mod only sends what it puts into its snapshots: Lua errors, tracebacks and the prints of the mod are only in the
console of the game-server. Its lines of fun-bots, all warnings and errors, and the lines that continue one of them (a
traceback) become events "game_log" ({level, text}) in the recording; errors show up as findings.

A line of the server: "[2026-10-09 21:37:35+02:00] [info] [VeniceEXT] [fun-bots] [NavZones] 28 zones, ...".
"""

from __future__ import annotations

import os
import re
import threading
import time
from pathlib import Path
from typing import Callable

LINE = re.compile(r"^\[[^\]]*\] \[(?P<level>\w+)\] (?P<text>.*)$")
# Lines of these levels are always kept, the others only if they are of the mod.
KEEP_LEVELS = {"warning", "warn", "error", "critical", "fatal"}
MOD_MARK = "[fun-bots]"
# Seconds between two looks into the file.
POLL = 0.5
# At most this many lines per look (a mod printing in a loop must not flood the recording).
MAX_LINES = 200


def parse(line: str) -> tuple[str | None, str]:
    """(level, text) of a line, level None for a line without the prefix (continues the line before)."""
    match = LINE.match(line)
    if match is None:
        return None, line
    return match.group("level").lower(), match.group("text")


def is_error(level: str | None, text: str) -> bool:
    lowered = text.lower()
    return level in ("error", "critical", "fatal") or "traceback" in lowered or lowered.startswith("error")


class GameLog:
    """Reads the lines added to the file, from its end at the start. A file written anew (the game-server started
    again, `> file`) is read from its beginning."""

    def __init__(self, path: Path, sink: Callable[[list[dict]], None]):
        self.path = path
        self.sink = sink
        self._keep_continuation = False

    def run(self, stop: threading.Event) -> None:
        file = None
        identity = None
        position = 0
        rest = ""
        first = True
        while not stop.is_set():
            try:
                stat = os.stat(self.path)
                if file is None or (stat.st_dev, stat.st_ino) != identity or stat.st_size < position:
                    if file is not None:
                        file.close()
                    file = open(self.path, "r", encoding="utf-8", errors="replace")
                    identity = (stat.st_dev, stat.st_ino)
                    # At the start only what comes from now on, a new file from its beginning.
                    position = stat.st_size if first else 0
                    file.seek(position)
                    rest = ""
                first = False
                data = file.read()
                position = file.tell()
            except OSError:
                if file is not None:
                    file.close()
                file = None
                first = False
                stop.wait(POLL * 4)
                continue
            if data:
                lines = (rest + data).split("\n")
                rest = lines.pop()
                events = self._events(lines)
                if events:
                    self.sink(events)
            stop.wait(POLL)
        if file is not None:
            file.close()

    def _events(self, lines: list[str]) -> list[dict]:
        events = []
        dropped = 0
        for line in lines:
            line = line.rstrip("\r")
            if not line.strip():
                continue
            level, text = parse(line)
            if level is None:
                keep = self._keep_continuation
            else:
                keep = level in KEEP_LEVELS or MOD_MARK in text or is_error(level, text)
                self._keep_continuation = keep
            if not keep:
                continue
            if len(events) >= MAX_LINES:
                dropped += 1
                continue
            events.append({"type": "game_log", "level": level or "", "text": text, "error": is_error(level, text),
                           "wall": time.time()})
        if dropped:
            events.append({"type": "game_log", "level": "warning", "text": f"[debug-server] {dropped} lines left out",
                           "error": False, "wall": time.time()})
        return events
