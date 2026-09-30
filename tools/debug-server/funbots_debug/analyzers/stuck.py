"""Bots that should move but don't."""

from __future__ import annotations

from collections import deque

from ..protocol import distance_2d, vec
from .base import Analyzer, Finding, register

# States in which a bot follows its path (BotStates.lua).
MOVING_STATES = {"Moving", "InVehicleMoving"}
# A bot that moved less than MIN_DISTANCE within WINDOW seconds while moving counts as stuck.
WINDOW = 10.0
MIN_DISTANCE = {"Moving": 2.0, "InVehicleMoving": 5.0}


@register
class StuckBotAnalyzer(Analyzer):
    name = "stuck"
    description = "Bots in a moving-state that barely moved for a while."

    def reset(self) -> None:
        super().reset()
        self._history: dict[int, deque] = {}
        self._stuck_total = 0
        self._obstacle_frames = 0

    def __init__(self) -> None:
        super().__init__()
        self.reset()

    def on_frame(self, frame: dict, state) -> None:
        for bot_id, bot in state.bots.items():
            key = f"stuck:{bot_id}"
            pos = vec(bot.get("pos"))
            bot_state = bot.get("state")
            # "holding": the bot stands on purpose (defending, waiting on a node, action, waiting for passengers).
            if pos is None or not bot.get("alive") or bot_state not in MOVING_STATES or bot.get("holding"):
                self._history.pop(bot_id, None)
                self.resolve(key)
                continue

            if bot.get("stuck"):
                self._obstacle_frames += 1

            history = self._history.setdefault(bot_id, deque())
            history.append((state.time, pos))
            while history and state.time - history[0][0] > WINDOW:
                history.popleft()
            if state.time - history[0][0] < WINDOW * 0.9:
                continue  # not enough history yet

            moved = max(distance_2d(pos, old) for _, old in history)
            if moved < MIN_DISTANCE[bot_state]:
                if key not in self._findings:
                    self._stuck_total += 1
                self.report(Finding(
                    key=key, bot=bot_id, pos=list(pos), time=state.time,
                    message=f"{bot.get('name')} stuck ({bot_state}, moved {moved:.1f} m in {WINDOW:.0f} s, "
                            f"path {bot.get('path')} point {bot.get('point')})"))
            else:
                self.resolve(key)

    def stats(self) -> dict:
        return {"stuck now": len(self._findings), "stuck total": self._stuck_total,
                "obstacle-handling (frames)": self._obstacle_frames}
