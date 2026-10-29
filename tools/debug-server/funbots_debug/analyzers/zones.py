"""Bots that got stuck in the walking network of a zone (BotZoneMovement.lua, event "zone_stuck")."""

from __future__ import annotations

from collections import Counter

from ..protocol import vec
from .base import Analyzer, Finding, register


@register
class ZoneStuckAnalyzer(Analyzer):
    name = "zones"
    description = "Connections of the zone networks bots got stuck on."

    def reset(self) -> None:
        super().reset()
        self._per_zone: Counter = Counter()

    def __init__(self) -> None:
        super().__init__()
        self.reset()

    def on_event(self, event: dict, state) -> None:
        if event.get("type") != "zone_stuck":
            return
        zone = event.get("zone")
        self._per_zone[zone] += 1
        pos = vec(event.get("pos"))
        key = f"zone:{zone}:{event.get('from')}-{event.get('to')}"
        count = (self._findings[key].data.get("count", 0) if key in self._findings else 0) + 1
        self.report(Finding(
            key=key, bot=event.get("bot"), pos=list(pos) if pos else None, time=state.time,
            severity="warn" if count > 1 else "info", data={"count": count, "target": event.get("target")},
            message=f"zone {zone}: stuck between points {event.get('from')} and {event.get('to')} ({count}x)"))

    def stats(self) -> dict:
        return {f"stuck in {zone}": count for zone, count in sorted(self._per_zone.items())}
