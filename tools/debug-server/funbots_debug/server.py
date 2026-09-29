"""HTTP-server (standard library only).

  POST /api/ingest     the mod: snapshots and events in, commands out
  GET  /api/stream     the browser: server-sent events (first "hello" with the whole state, then changes)
  GET  /api/state      the whole state as JSON (for scripts)
  POST /api/command    {type, args} -> {id}. With ?wait=<seconds> it blocks until the mod answered.
  POST /api/rcon       {words} -> {words}. Any RCON-command, straight to the RCON-port of the game-server.
  POST /api/scans/clear  {scan} -> {cleared}. Forgets one scan (no scan = all) and stops it if it still runs.
  GET  /api/commands   the last commands and their answers
  GET  /               the web-interface (web/)
"""

from __future__ import annotations

import json
import mimetypes
import queue
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from .hub import Hub
from .rcon import RconError

WEB_DIR = Path(__file__).parent / "web"
MAX_BODY = 64 * 1024 * 1024
KEEPALIVE_INTERVAL = 15.0


class DebugServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], hub: Hub, quiet: bool = True):
        super().__init__(address, Handler)
        self.hub = hub
        self.quiet = quiet
        self._stop = threading.Event()
        self._watchdog = threading.Thread(target=self._watch, name="mod-watchdog", daemon=True)
        self._watchdog.start()

    def _watch(self) -> None:
        while not self._stop.wait(1.0):
            self.hub.check_connection()

    def server_close(self) -> None:
        self._stop.set()
        super().server_close()


class Handler(BaseHTTPRequestHandler):
    server: DebugServer
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args) -> None:  # noqa: A002 (signature of the base-class)
        if not self.server.quiet:
            super().log_message(format, *args)

    # --- routing -----------------------------------------------------------------------------------------------

    def do_GET(self) -> None:  # noqa: N802
        url = urlparse(self.path)
        if url.path == "/api/stream":
            self._stream()
        elif url.path == "/api/state":
            self._send_json(self.server.hub.snapshot())
        elif url.path == "/api/commands":
            self._send_json(self.server.hub.commands.history())
        elif url.path.startswith("/api/"):
            self._send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)
        else:
            self._static(url.path)

    def do_POST(self) -> None:  # noqa: N802
        url = urlparse(self.path)
        body = self._read_body()
        if body is None:
            return
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError as error:
            self._send_json({"error": f"invalid json: {error}"}, HTTPStatus.BAD_REQUEST)
            return

        if url.path == "/api/ingest":
            if not isinstance(data, dict):
                self._send_json({"error": "payload must be an object"}, HTTPStatus.BAD_REQUEST)
                return
            self._send_json(self.server.hub.ingest(data, len(body)))
        elif url.path == "/api/command":
            self._command(data, parse_qs(url.query))
        elif url.path == "/api/rcon":
            self._rcon(data)
        elif url.path == "/api/scans/clear":
            scan = data.get("scan") if isinstance(data, dict) else None
            if scan is not None and not isinstance(scan, int):
                self._send_json({"error": "scan must be an id"}, HTTPStatus.BAD_REQUEST)
                return
            self._send_json({"cleared": self.server.hub.clear_scans(scan)})
        else:
            self._send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)

    # --- handlers ----------------------------------------------------------------------------------------------

    def _command(self, data: dict, query: dict) -> None:
        if not isinstance(data, dict) or not isinstance(data.get("type"), str):
            self._send_json({"error": "needs {type, args}"}, HTTPStatus.BAD_REQUEST)
            return
        hub = self.server.hub
        if not hub.accept_commands:
            self._send_json({"error": "replay-mode, no mod to send commands to"}, HTTPStatus.CONFLICT)
            return
        args = data.get("args") if isinstance(data.get("args"), dict) else {}
        command = hub.submit_command(data["type"], args)
        wait = query.get("wait")
        if wait:
            hub.commands.wait(command, min(float(wait[0]), 120.0))
        self._send_json(command.to_json())

    def _rcon(self, data) -> None:
        words = data.get("words") if isinstance(data, dict) else None
        if not isinstance(words, list) or not words or not all(isinstance(word, str) for word in words):
            self._send_json({"error": "needs {words: [command, args...]}"}, HTTPStatus.BAD_REQUEST)
            return
        rcon = self.server.hub.rcon
        if rcon is None:
            self._send_json({"error": "no RCON-password, start with --rcon-password"}, HTTPStatus.SERVICE_UNAVAILABLE)
            return
        try:
            self._send_json({"words": self.server.hub.run_rcon(words)})
        except RconError as error:
            self._send_json({"error": str(error)}, HTTPStatus.BAD_GATEWAY)

    def _stream(self) -> None:
        hub = self.server.hub
        subscriber = hub.subscribe()
        try:
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()
            self._write_event("hello", json.dumps(hub.snapshot(), separators=(",", ":")))
            last_write = time.monotonic()
            while True:
                try:
                    kind, data = subscriber.queue.get(timeout=1.0)
                except queue.Empty:
                    if time.monotonic() - last_write > KEEPALIVE_INTERVAL:
                        self.wfile.write(b": keepalive\n\n")
                        self.wfile.flush()
                        last_write = time.monotonic()
                    continue
                if kind == "resync":
                    self._write_event("hello", json.dumps(hub.snapshot(), separators=(",", ":")))
                else:
                    self._write_event(kind, data)
                last_write = time.monotonic()
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
            pass
        finally:
            hub.unsubscribe(subscriber)
            self.close_connection = True

    def _write_event(self, kind: str, data: str) -> None:
        self.wfile.write(f"event: {kind}\ndata: {data}\n\n".encode("utf-8"))
        self.wfile.flush()

    def _static(self, path: str) -> None:
        relative = path.lstrip("/") or "index.html"
        file = (WEB_DIR / relative).resolve()
        if WEB_DIR.resolve() not in file.parents or not file.is_file():
            self._send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)
            return
        content = file.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", mimetypes.guess_type(file.name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(content)

    # --- helpers -----------------------------------------------------------------------------------------------

    def _read_body(self) -> bytes | None:
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY:
            self._send_json({"error": "body too big"}, HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
            return None
        return self.rfile.read(length) if length else b""

    def _send_json(self, data, status: HTTPStatus = HTTPStatus.OK) -> None:
        content = json.dumps(data, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)
