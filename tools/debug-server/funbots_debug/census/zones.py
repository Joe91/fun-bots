"""Size of the capture zones, measured from who is inside them.

The engine doesn't tell the radius of a capture point (CapturePointEntityData.CaptureRadius is 0, the real value comes
from the level). The mod sends which players are inside each capture point (objectives.flags[].inside), so every
snapshot gives bounds: the zone reaches at least as far as the farthest player inside, and not as far as the closest
one outside (at about the same height). The bounds get tight the longer bots play the level.

Zones aren't always circles (on XP3_Alborz a player was outside at 20 m of A while another one was inside at 32 m),
so the positions are also counted on a grid of CELL metres: the cells with players inside are the shape of the zone.

Faster and complete: the zone probe of the mod (ZoneProbe.lua) puts bots around each capture point and searches in
several directions how far the zone reaches (apply_probe). A capture point nobody is inside of then is not active.
"""

from __future__ import annotations

import math

from ..protocol import as_list, vec

# Players outside count for the upper bound only at about the height of the flag: the zone may be a cylinder.
OUTSIDE_HEIGHT = 5.0
# Grid of the shape: cell size, and how far around the flag positions are counted.
CELL = 2.0
CELL_RANGE = 80.0


class ZoneEstimator:
    def __init__(self) -> None:
        self.zones: dict[str, dict] = {}

    def reset(self) -> None:
        self.zones.clear()

    @staticmethod
    def key(flag: dict) -> str | None:
        pos = vec(flag.get("pos"))
        if pos is None:
            return None
        # Names aren't unique (layouts of other modes are loaded as well), the position is.
        return f"{flag.get('name')}@{round(pos[0])},{round(pos[2])}"

    def on_frame(self, state) -> None:
        flags = as_list((state.objectives or {}).get("flags"))
        if not flags:
            return
        positions = {}
        for entry in list(state.bots.values()) + list(state.players.values()):
            pos = vec(entry.get("pos"))
            if pos is not None and entry.get("alive"):
                positions[entry.get("id")] = pos

        for flag in flags:
            key = self.key(flag)
            center = vec(flag.get("pos"))
            if key is None or center is None:
                continue
            zone = self.zones.setdefault(key, {"name": flag.get("name"), "pos": list(center), "samples": 0,
                                               "inside": 0.0, "outside": None, "below": 0.0, "above": 0.0,
                                               "cells": {}})
            inside = set(as_list(flag.get("inside")))
            for player, pos in positions.items():
                distance = math.hypot(pos[0] - center[0], pos[2] - center[2])
                height = pos[1] - center[1]
                if distance <= CELL_RANGE and (player in inside or abs(height) <= OUTSIDE_HEIGHT):
                    cell = zone["cells"].setdefault((math.floor(pos[0] / CELL), math.floor(pos[2] / CELL)), [0, 0])
                    cell[0 if player in inside else 1] += 1
                if player in inside:
                    zone["samples"] += 1
                    zone["inside"] = max(zone["inside"], distance)
                    zone["below"] = min(zone["below"], height)
                    zone["above"] = max(zone["above"], height)
                elif abs(height) <= OUTSIDE_HEIGHT and (zone["outside"] is None or distance < zone["outside"]):
                    zone["outside"] = distance

    def apply_probe(self, flags: list) -> None:
        """The result of the zone probe: per capture point the distance inside / outside in each direction. Replaces
        what was measured before; the shape between the directions is interpolated onto the cells."""
        for flag in flags:
            key = self.key(flag)
            center = vec(flag.get("pos"))
            if key is None or center is None:
                continue
            directions = sorted(((float(entry["angle"]), float(entry["inside"]), float(entry["outside"]))
                                 for entry in as_list(flag.get("directions"))), key=lambda entry: entry[0])
            active = bool(flag.get("active")) and bool(directions)
            zone = {"name": flag.get("name"), "pos": list(center), "samples": 0, "inside": 0.0, "outside": None,
                    "below": 0.0, "above": 0.0, "cells": {}, "probed": True, "active": active}
            self.zones[key] = zone
            if not active:
                continue
            zone["samples"] = sum(1 for entry in directions if entry[1] > 0)
            zone["inside"] = max(entry[1] for entry in directions)
            zone["outside"] = min(entry[2] for entry in directions)
            reach = zone["inside"] + 2 * CELL
            first = math.floor((center[0] - reach) / CELL), math.floor((center[2] - reach) / CELL)
            last = math.floor((center[0] + reach) / CELL), math.floor((center[2] + reach) / CELL)
            for column in range(first[0], last[0] + 1):
                for row in range(first[1], last[1] + 1):
                    x, z = (column + 0.5) * CELL - center[0], (row + 0.5) * CELL - center[2]
                    distance = math.hypot(x, z)
                    if distance > reach:
                        continue
                    inside = distance <= _boundary(directions, math.atan2(z, x))
                    zone["cells"][(column, row)] = [1, 0] if inside else [0, 1]

    def to_json(self) -> list[dict]:
        """Per capture point: radius (at least, from the players inside), outside (the closest one outside), samples."""
        result = []
        for zone in self.zones.values():
            result.append({
                "name": zone["name"],
                "pos": zone["pos"],
                "samples": zone["samples"],
                "radius": round(zone["inside"], 1) if zone["samples"] else None,
                "outside": round(zone["outside"], 1) if zone["outside"] is not None else None,
                "heights": [round(zone["below"], 1), round(zone["above"], 1)] if zone["samples"] else None,
                # [column, row, inside, outside]: the cell covers x = column * cell ... + cell, z the same with row.
                "cell": CELL,
                "cells": [[column, row, counts[0], counts[1]] for (column, row), counts in sorted(zone["cells"].items())],
            })
            if zone.get("probed"):
                result[-1]["probed"] = True
                result[-1]["active"] = zone["active"]
        return result


def _boundary(directions: list[tuple[float, float, float]], angle: float) -> float:
    """How far the zone reaches at the angle: between the two probed directions around it, linear in the angle.
    directions: (angle, inside, outside), sorted by angle."""
    count = len(directions)
    for index in range(count):
        a_angle, a_inside, _ = directions[index]
        b_angle, b_inside, _ = directions[(index + 1) % count]
        span = (b_angle - a_angle) % (2 * math.pi) or 2 * math.pi
        offset = (angle - a_angle) % (2 * math.pi)
        if offset <= span:
            return a_inside + (b_inside - a_inside) * offset / span
    return directions[0][1]
