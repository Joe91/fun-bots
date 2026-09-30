"""Helpers for the data the mod sends.

The JSON comes from the VU json-encoder, which does not know whether an empty Lua-table is an array or an
object, and may encode sparse arrays as objects with string keys. Everything that should be a list goes
through as_list().
"""

from __future__ import annotations

import math
from typing import Any, Iterable


def as_list(value: Any) -> list:
    """A Lua-array as list: [] for None/{} and the values of {"1": a, "2": b} in key order."""
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        if not value:
            return []
        try:
            return [value[key] for key in sorted(value, key=lambda k: int(k))]
        except (TypeError, ValueError):
            return list(value.values())
    return [value]


def as_dict(value: Any) -> dict:
    """A Lua-table as dict: {} for None and for an empty list."""
    if isinstance(value, dict):
        return value
    return {}


def vec(value: Any) -> tuple[float, float, float] | None:
    """[x, y, z] as tuple, None if it isn't one."""
    items = as_list(value)
    if len(items) < 3:
        return None
    try:
        return float(items[0]), float(items[1]), float(items[2])
    except (TypeError, ValueError):
        return None


def distance_2d(a: Iterable[float], b: Iterable[float]) -> float:
    """Distance on the map (x, z) of two [x, y, z]."""
    ax, _, az = a
    bx, _, bz = b
    return math.hypot(ax - bx, az - bz)


def yaw_to_direction(yaw: float) -> tuple[float, float]:
    """View-direction (x, z) of a bot-yaw. The bots use (x = -sin(yaw), z = cos(yaw)), see AimEvaluation.lua."""
    return -math.sin(yaw), math.cos(yaw)
