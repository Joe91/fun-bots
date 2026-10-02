"""Kills, weapons and targets that should never happen (teammates)."""

from __future__ import annotations

from collections import Counter

from ..protocol import vec
from .base import Analyzer, Finding, register

# Actions where a bot has a teammate as "target" on purpose (BotEnums.lua, BotActionFlags).
FRIENDLY_ACTIONS = {"ReviveActive", "RepairActive", "EnterVehicleActive"}


@register
class CombatAnalyzer(Analyzer):
    name = "combat"
    description = "Kill-statistics, team-kills and bots targeting teammates."

    def __init__(self) -> None:
        super().__init__()
        self.reset()

    def reset(self) -> None:
        super().reset()
        self._kills_by_team: Counter = Counter()
        self._weapons: Counter = Counter()
        self._headshots = 0
        self._kills = 0
        self._team_kills = 0

    def on_event(self, event: dict, state) -> None:
        if event.get("type") != "kill":
            return
        self._kills += 1
        killer, victim = event.get("killer", -1), event.get("victim", -1)
        killer_team, victim_team = event.get("killerTeam"), event.get("victimTeam")
        if killer_team:
            self._kills_by_team[f"team {killer_team}"] += 1
        weapon = str(event.get("weapon"))
        if weapon == "Death" and event.get("killerVehicle"):
            weapon = str(event["killerVehicle"])  # weapons of vehicles come as "Death"
        self._weapons[weapon] += 1
        if event.get("headshot"):
            self._headshots += 1
        if killer not in (-1, victim) and killer_team and killer_team == victim_team:
            self._team_kills += 1
            pos = vec(event.get("pos"))
            self.report(Finding(
                key=f"teamkill:{killer}:{victim}:{event.get('t')}", severity="error", bot=killer,
                pos=list(pos) if pos else None, time=float(event.get("t", 0)),
                message=f"team-kill: {state.name_of(killer)} killed {state.name_of(victim)} ({event.get('weapon')})"))

    def on_frame(self, frame: dict, state) -> None:
        for bot_id, bot in state.bots.items():
            key = f"friendly-target:{bot_id}"
            target = bot.get("target", -1)
            if (target is None or target == -1 or not bot.get("alive")
                    or bot.get("action") in FRIENDLY_ACTIONS):
                self.resolve(key)
                continue
            if state.team_of(target) == bot.get("team"):
                pos = vec(bot.get("pos"))
                self.report(Finding(
                    key=key, severity="error", bot=bot_id, pos=list(pos) if pos else None, time=state.time,
                    message=f"{bot.get('name')} targets teammate {state.name_of(target)} "
                            f"(state {bot.get('state')}, action {bot.get('action')})"))
            else:
                self.resolve(key)

    def stats(self) -> dict:
        data = {"kills": self._kills, "team-kills": self._team_kills,
                "headshots": f"{self._headshots / self._kills:.0%}" if self._kills else "-"}
        data.update(self._kills_by_team)
        for weapon, count in self._weapons.most_common(5):
            data[f"weapon {weapon}"] = count
        return data
