"""Model of the game, built from the snapshots and events of the mod."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from typing import Any

from .protocol import as_dict, as_list, vec

# Parts of a snapshot the state knows. Everything else lands in WorldState.extras, so a new collector in the
# mod shows up (raw) without any change here.
KNOWN_FRAME_KEYS = {"t", "meta", "bots", "players", "vehicles"}


@dataclass
class ScanGrid:
    """Result of a map-scan (MapScanner.lua): heights and normal-y on a grid, row by row."""

    scan: int
    x0: float
    z0: float
    step: float
    columns: int
    rows: int
    layers: int = 1
    # row -> (heights, normals). A cell is a number, false (no hit) or a list (layers > 1).
    data: dict[int, tuple[list, list]] = field(default_factory=dict)

    def to_json(self) -> dict:
        return {
            "scan": self.scan,
            "x0": self.x0,
            "z0": self.z0,
            "step": self.step,
            "columns": self.columns,
            "rows": self.rows,
            "layers": self.layers,
            "rowData": [[row, heights, normals] for row, (heights, normals) in sorted(self.data.items())],
        }

    def height_at(self, x: float, z: float) -> float | None:
        """Top height of the cell at (x, z), None if not scanned or no hit."""
        column = round((x - self.x0) / self.step)
        row = round((z - self.z0) / self.step)
        heights = self.data.get(row, (None, None))[0]
        if heights is None or not 0 <= column < len(heights):
            return None
        cell = heights[column]
        if isinstance(cell, list):
            cell = cell[0] if cell else None
        return None if cell is False or cell is None else float(cell)


class WorldState:
    """Latest snapshot plus some history: trails, traces, kills, waypoints and scans."""

    def __init__(self, trail_seconds: float = 15.0, max_traces: int = 3000, max_kills: int = 500,
                 max_log: int = 500):
        self.trail_seconds = trail_seconds
        self.traces: deque[dict] = deque(maxlen=max_traces)
        self.kills: deque[dict] = deque(maxlen=max_kills)
        self.log: deque[dict] = deque(maxlen=max_log)
        self.reset()

    def reset(self) -> None:
        self.time = 0.0
        self.meta: dict[str, Any] = {}
        self.bots: dict[int, dict] = {}
        self.players: dict[int, dict] = {}
        self.vehicles: dict[int, dict] = {}
        self.trails: dict[int, deque] = {}
        self.extras: dict[str, Any] = {}
        # path-index -> {"points": [[x, y, z]], "objectives": [...], "vehicles": [...]}
        self.paths: dict[int, dict] = {}
        self.scans: dict[int, ScanGrid] = {}
        self.traces.clear()
        self.kills.clear()
        self.frames = 0

    @property
    def level(self) -> str | None:
        return self.meta.get("level")

    def name_of(self, player_id: int) -> str:
        entry = self.bots.get(player_id) or self.players.get(player_id)
        return entry.get("name", str(player_id)) if entry else str(player_id)

    def team_of(self, player_id: int) -> int | None:
        entry = self.bots.get(player_id) or self.players.get(player_id)
        return entry.get("team") if entry else None

    # --- snapshots ---------------------------------------------------------------------------------------------

    def apply_frame(self, frame: dict) -> bool:
        """Takes over a snapshot. Returns True if the level changed (the state was reset then)."""
        level_changed = False
        meta = as_dict(frame.get("meta"))
        if meta:
            old_level = self.meta.get("level")
            if old_level is not None and meta.get("level") != old_level:
                self.reset()
                level_changed = True
            self.meta = meta

        self.time = float(frame.get("t", self.time))
        self.frames += 1

        if "bots" in frame:
            self.bots = {bot["id"]: bot for bot in as_list(frame["bots"]) if "id" in bot}
            self._update_trails()
        if "players" in frame:
            self.players = {player["id"]: player for player in as_list(frame["players"]) if "id" in player}
        if "vehicles" in frame:
            self.vehicles = {vehicle["id"]: vehicle for vehicle in as_list(frame["vehicles"]) if "id" in vehicle}
            for vehicle in self.vehicles.values():
                vehicle["occupants"] = as_list(vehicle.get("occupants"))

        for key, value in frame.items():
            if key not in KNOWN_FRAME_KEYS:
                self.extras[key] = value
        return level_changed

    def _update_trails(self) -> None:
        for bot_id, bot in self.bots.items():
            pos = vec(bot.get("pos"))
            trail = self.trails.setdefault(bot_id, deque())
            if pos is None or not bot.get("alive"):
                trail.clear()
                continue
            if not trail or abs(trail[-1][1] - pos[0]) + abs(trail[-1][2] - pos[2]) > 0.3:
                trail.append((self.time, pos[0], pos[2]))
            while trail and self.time - trail[0][0] > self.trail_seconds:
                trail.popleft()
        for bot_id in list(self.trails):
            if bot_id not in self.bots:
                del self.trails[bot_id]

    # --- events ------------------------------------------------------------------------------------------------

    def apply_event(self, event: dict) -> str | None:
        """Takes over an event. Returns "reset" when the state was reset because of it."""
        kind = event.get("type")
        if kind == "ray":
            self.traces.append(event)
        elif kind == "kill":
            self.kills.append(event)
        elif kind == "nodes_started":
            self.paths.clear()
        elif kind == "nodes":
            self._apply_nodes(event)
        elif kind == "scan_started":
            self.scans[int(event["scan"])] = ScanGrid(
                scan=int(event["scan"]), x0=float(event["x0"]), z0=float(event["z0"]), step=float(event["step"]),
                columns=int(event["columns"]), rows=int(event["rows"]), layers=int(event.get("layers", 1)))
        elif kind == "scan_row":
            grid = self.scans.get(int(event.get("scan", -1)))
            if grid is not None:
                grid.data[int(event["row"])] = (as_list(event.get("heights")), as_list(event.get("normals")))
        elif kind == "level_loaded":
            # Also a new round on the same map: waypoints, scans and history belong to the old one.
            self.log.append(event)
            self.reset()
            return "reset"
        elif kind in ("command_result",):
            pass
        else:
            self.log.append(event)
        return None

    def _apply_nodes(self, event: dict) -> None:
        path = int(event.get("path", -1))
        entry = self.paths.setdefault(path, {"points": []})
        first = int(event.get("first", 1))
        points = as_list(event.get("points"))
        if first == 1:
            entry["points"] = []
        entry["points"].extend(points)
        if "objectives" in event:
            entry["objectives"] = as_list(event["objectives"])
        if "vehicles" in event:
            entry["vehicles"] = as_list(event["vehicles"])

    # --- export ------------------------------------------------------------------------------------------------

    def to_json(self, include_static: bool = True) -> dict:
        """Everything a new browser needs. Paths and scans can be big, include_static=False skips them."""
        data = {
            "time": self.time,
            "meta": self.meta,
            "bots": list(self.bots.values()),
            "players": list(self.players.values()),
            "vehicles": list(self.vehicles.values()),
            "trails": {bot_id: [[x, z] for _, x, z in trail] for bot_id, trail in self.trails.items()},
            "traces": list(self.traces)[-300:],
            "kills": list(self.kills)[-100:],
            "log": list(self.log)[-100:],
            "extras": self.extras,
        }
        if include_static:
            data["paths"] = self.paths
            data["scans"] = [grid.to_json() for grid in self.scans.values()]
        return data
