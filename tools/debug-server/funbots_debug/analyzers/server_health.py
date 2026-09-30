"""Health of the game-server as far as the snapshots show it: hitches, Lua-memory, errors of the bridge."""

from __future__ import annotations

from .base import Analyzer, Finding, register

# A gap between two snapshots this much longer than the usual one means the server hung.
HITCH_FACTOR = 3.0
MIN_HITCH = 0.5


@register
class ServerHealthAnalyzer(Analyzer):
    name = "server"
    description = "Hitches of the server (gaps between snapshots), Lua-memory and errors of the debug-bridge."

    def __init__(self) -> None:
        super().__init__()
        self.reset()

    def reset(self) -> None:
        super().reset()
        self._last_time: float | None = None
        self._intervals: list[float] = []
        self._hitches = 0
        self._max_gap = 0.0
        self._memory_start: int | None = None
        self._memory: int | None = None
        self._errors = 0

    def on_frame(self, frame: dict, state) -> None:
        t = float(frame.get("t", 0))
        if self._last_time is not None:
            gap = t - self._last_time
            if gap > 0:
                usual = sorted(self._intervals)[len(self._intervals) // 2] if self._intervals else gap
                if len(self._intervals) >= 10 and gap > max(MIN_HITCH, usual * HITCH_FACTOR):
                    self._hitches += 1
                    self.report(Finding(
                        key=f"hitch:{t}", severity="warn", time=t,
                        message=f"server-hitch: {gap:.2f} s between snapshots (usual {usual:.2f} s)"))
                self._max_gap = max(self._max_gap, gap)
                self._intervals.append(gap)
                del self._intervals[:-50]
        self._last_time = t

        memory = state.meta.get("luaMemoryKb")
        if memory is not None:
            self._memory = int(memory)
            if self._memory_start is None:
                self._memory_start = self._memory

        # Keep only the latest hitches.
        hitches = [key for key in self._findings if key.startswith("hitch:")]
        for key in hitches[:-20]:
            self.resolve(key)

    def on_event(self, event: dict, state) -> None:
        if event.get("type") == "error":
            self._errors += 1
            self.report(Finding(
                key=f"error:{event.get('source')}", severity="error", time=float(event.get("t", 0)),
                message=f"debug-bridge error in {event.get('source')}: {event.get('message')}"))

    def stats(self) -> dict:
        data = {"hitches": self._hitches, "max gap (s)": round(self._max_gap, 2), "bridge errors": self._errors}
        if self._memory is not None:
            data["lua memory (MB)"] = round(self._memory / 1024, 1)
            data["lua memory growth (MB)"] = round((self._memory - (self._memory_start or 0)) / 1024, 1)
        return data
