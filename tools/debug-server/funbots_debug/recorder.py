"""Records everything the mod sends into a JSON-lines file and plays it back later.

One line per request of the mod: {"recv": <unix-time>, "payload": <body>}. Files ending on .gz are compressed.
A recording can be analyzed offline with `--replay`, or read line by line with read_recording() in own scripts.
"""

from __future__ import annotations

import gzip
import json
import threading
import time
from pathlib import Path
from typing import IO, Callable, Iterator


def _open(path: Path, mode: str) -> IO[str]:
    if path.suffix == ".gz":
        return gzip.open(path, mode + "t", encoding="utf-8")
    return open(path, mode, encoding="utf-8")


class Recorder:
    def __init__(self, directory: Path, compress: bool = True):
        self.directory = directory
        self.compress = compress
        self._file: IO[str] | None = None
        self._lock = threading.Lock()
        self.path: Path | None = None

    def write(self, payload: dict, level: str | None) -> None:
        with self._lock:
            if self._file is None:
                self.directory.mkdir(parents=True, exist_ok=True)
                name = (level or "unknown").rsplit("/", 1)[-1]
                self.path = self.directory / f"{time.strftime('%Y%m%d-%H%M%S')}_{name}.jsonl"
                if self.compress:
                    self.path = self.path.with_suffix(".jsonl.gz")
                self._file = _open(self.path, "w")
            self._file.write(json.dumps({"recv": time.time(), "payload": payload}, separators=(",", ":")))
            self._file.write("\n")

    def split(self) -> None:
        """Starts a new file with the next write (on a new level)."""
        self.close()

    def close(self) -> None:
        with self._lock:
            if self._file is not None:
                self._file.close()
                self._file = None


def read_recording(path: Path) -> Iterator[tuple[float, dict]]:
    """(receive-time, payload) of every request in a recording."""
    with _open(path, "r") as file:
        for line in file:
            line = line.strip()
            if line:
                entry = json.loads(line)
                yield entry["recv"], entry["payload"]


def replay(path: Path, ingest: Callable[[dict], object], speed: float = 1.0, loop: bool = False,
           stop: threading.Event | None = None) -> None:
    """Feeds a recording into ingest() with the original timing (speed = factor, 0 = as fast as possible)."""
    stop = stop or threading.Event()
    while not stop.is_set():
        previous = None
        for recv, payload in read_recording(path):
            if stop.is_set():
                return
            if previous is not None and speed > 0:
                time.sleep(max(0.0, (recv - previous) / speed))
            previous = recv
            ingest(payload)
        if not loop:
            return
