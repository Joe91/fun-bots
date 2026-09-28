"""Raycasts of the sight-checks (only the server-raycasts, see ServerRaycasts.lua)."""

from __future__ import annotations

from collections import Counter, deque

from .base import Analyzer, register

RATE_WINDOW = 5.0


@register
class RaycastAnalyzer(Analyzer):
    name = "raycasts"
    description = "Rate and visible-ratio of the server-raycasts per kind."

    def __init__(self) -> None:
        super().__init__()
        self.reset()

    def reset(self) -> None:
        super().reset()
        self._total: Counter = Counter()
        self._visible: Counter = Counter()
        self._recent: deque = deque()

    def on_event(self, event: dict, state) -> None:
        if event.get("type") != "ray":
            return
        kind = event.get("kind", "?")
        self._total[kind] += 1
        if event.get("visible"):
            self._visible[kind] += 1
        t = float(event.get("t", 0))
        self._recent.append((t, kind))
        while self._recent and t - self._recent[0][0] > RATE_WINDOW:
            self._recent.popleft()

    def stats(self) -> dict:
        rates = Counter(kind for _, kind in self._recent)
        data = {}
        for kind, total in sorted(self._total.items()):
            data[f"{kind} /s"] = round(rates[kind] / RATE_WINDOW, 1)
            data[f"{kind} visible"] = f"{self._visible[kind] / total:.0%}"
        return data
