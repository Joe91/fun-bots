"""Client for the RCON-port of the game-server (Frostbite RCON protocol, like Procon).

The mod can only run the RCON-commands of the mods through RCON:SendCommand. Everything else (admin.nextLevel,
modList.reloadExtensions, ...) needs the real RCON-connection, which this client opens itself.

A packet is: header (uint32: bit 31 = the request came from the server, bit 30 = response, bits 0-29 = sequence),
size of the packet (uint32), number of words (uint32), then each word as size (uint32), bytes and a zero byte.
Little endian. Requests of the server are events (player.onJoin, ...), each must be answered with "OK".
"""

from __future__ import annotations

import hashlib
import socket
import struct
import threading
from pathlib import Path

DEFAULT_PORT = 47200
TIMEOUT = 10.0
FROM_SERVER = 0x80000000
IS_RESPONSE = 0x40000000
SEQUENCE_MASK = 0x3FFFFFFF


class RconError(Exception):
    pass


def encode_packet(sequence: int, words: list[str], from_server: bool = False, response: bool = False) -> bytes:
    header = (sequence & SEQUENCE_MASK) | (FROM_SERVER if from_server else 0) | (IS_RESPONSE if response else 0)
    body = b"".join(struct.pack("<I", len(data)) + data + b"\0" for data in (word.encode("utf-8") for word in words))
    return struct.pack("<III", header, 12 + len(body), len(words)) + body


def decode_packet(data: bytes) -> tuple[int, list[str]]:
    """(header, words) of one whole packet."""
    header, _, count = struct.unpack_from("<III", data)
    words, offset = [], 12
    for _ in range(count):
        (length,) = struct.unpack_from("<I", data, offset)
        words.append(data[offset + 4:offset + 4 + length].decode("utf-8", errors="replace"))
        offset += 4 + length + 1
    return header, words


def find_startup_password(start: Path) -> tuple[str, Path] | None:
    """admin.password from the Startup.txt of the server this folder lies in (…/Admin/Mods/fun-bots/…)."""
    for folder in start.resolve().parents:
        startup = folder / "Startup.txt"
        if startup.is_file():
            for line in startup.read_text(encoding="utf-8", errors="replace").splitlines():
                key, _, value = line.strip().partition(" ")
                if key.lower() == "admin.password" and value.strip():
                    return value.strip().strip('"'), startup
    return None


class RconClient:
    """One connection, opened and logged in on first use and again after an error. Thread-safe."""

    def __init__(self, host: str, port: int, password: str, log: bool = True):
        self.host, self.port, self.password = host, port, password
        # Prints every packet (not the login) to the terminal of the debug-server.
        self.log = log
        self._lock = threading.Lock()
        self._socket: socket.socket | None = None
        self._sequence = 0
        # For the UI: "not connected", "logged in" or the last error.
        self.state = "not connected"
        self.ok: bool | None = None

    def to_json(self) -> dict:
        return {"address": self.address, "state": self.state, "ok": self.ok}

    def connect(self) -> None:
        """Connects and logs in (if not yet). Raises RconError."""
        with self._lock:
            self._ensure_connected()

    @property
    def address(self) -> str:
        return f"{self.host}:{self.port}"

    def command(self, words: list[str]) -> list[str]:
        """Sends one command and returns the words of the answer, e.g. ["OK"] or ["UnknownCommand"]."""
        if not words or not words[0]:
            raise RconError("no command")
        with self._lock:
            self._ensure_connected()
            try:
                return self._request(words, self.log)
            except OSError as error:
                self._fail(f"RCON {self.address}: {error}")
                raise RconError(self.state) from error

    def _ensure_connected(self) -> None:
        if self._socket is not None:
            return
        try:
            self._connect()
        except OSError as error:
            self._fail(f"RCON {self.address}: {error or type(error).__name__}")
            raise RconError(self.state) from error
        except RconError as error:
            self._fail(str(error))
            raise
        self.state, self.ok = "logged in", True
        if self.log:
            print(f"rcon: logged in to {self.address}", flush=True)

    def _fail(self, message: str) -> None:
        self._close()
        self.state, self.ok = message, False
        if self.log:
            print(f"rcon: {message}", flush=True)

    def close(self) -> None:
        with self._lock:
            self._close()

    def _connect(self) -> None:
        self._socket = socket.create_connection((self.host, self.port), timeout=TIMEOUT)
        answer = self._request(["login.hashed"], self.log)
        if answer[0] != "OK" or len(answer) < 2:
            raise RconError(f"RCON login failed: {' '.join(answer)}")
        try:
            salt = bytes.fromhex(answer[1])
        except ValueError as error:
            raise RconError(f"RCON login failed: invalid salt {answer[1]!r}") from error
        digest = hashlib.md5(salt + self.password.encode("utf-8")).hexdigest().upper()
        answer = self._request(["login.hashed", digest], self.log)
        if answer[0] != "OK":
            raise RconError(f"RCON login failed: {' '.join(answer)} (wrong password?)")
        # The console only needs the answers.
        self._request(["admin.eventsEnabled", "false"], self.log)

    def _request(self, words: list[str], log: bool = False) -> list[str]:
        assert self._socket is not None
        self._sequence = (self._sequence + 1) & SEQUENCE_MASK
        if log:
            print(f"rcon > {self._sequence:#010x} {words}", flush=True)
        self._socket.sendall(encode_packet(self._sequence, words))
        while True:
            header, answer = decode_packet(self._read_packet())
            if header & FROM_SERVER and not header & IS_RESPONSE:
                # An event: acknowledge it, it is not the answer.
                self._socket.sendall(encode_packet(header, ["OK"], from_server=True, response=True))
                continue
            if log:
                print(f"rcon < {header:#010x} {answer}", flush=True)
            if header & IS_RESPONSE and not header & FROM_SERVER and header & SEQUENCE_MASK == self._sequence:
                return answer or [""]

    def _read_packet(self) -> bytes:
        head = self._read(12)
        _, size, _ = struct.unpack("<III", head)
        if size < 12 or size > 16 * 1024 * 1024:
            raise OSError(f"invalid packet size {size}")
        return head + self._read(size - 12)

    def _read(self, count: int) -> bytes:
        assert self._socket is not None
        data = b""
        while len(data) < count:
            chunk = self._socket.recv(count - len(data))
            if not chunk:
                raise OSError("connection closed by the server")
            data += chunk
        return data

    def _close(self) -> None:
        if self._socket is not None:
            try:
                self._socket.close()
            except OSError:
                pass
        self._socket = None
