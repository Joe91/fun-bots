"""Puts the "census_*" events of the mod (ext/Server/Debug/MapCensus.lua) together and saves them.

A census file (census/<level>_<mode>.json.gz) holds:

    {"version", "level", "mode", "paths", "created", "parts", "summary",
     "entities": {capturePoints, spawns, vehicleSpawns, combatAreas, mcoms, vehicles, objectives, entityTypes, ...},
     "nodes": {"<path>": {"loops", "objectives", "vehicles", "points", "inputs", "ground", "normal", "water",
                          "ceiling", "left", "right", "next", "nextHit", "actions"}},
     "links": [[path, point, path, point, [fraction | false, ...], kind | false], ...],
     "areas": [{"name", "kind", "center", "radius", "x0", "z0", "step", "columns", "rows", "layers",
                "cells": [[cell, ...] per row]}]}

All lists of a path have one entry per waypoint (point 1 at index 0). What each value means is described at
CensusTask:_ProbeNode and CensusTask:_ProbeCell in MapCensus.lua.
"""

from __future__ import annotations

import gzip
import json
import time
from pathlib import Path

from ..protocol import as_dict, as_list

VERSION = 1
# Lists of the census_nodes event with one entry per waypoint.
NODE_FIELDS = ("points", "inputs", "ground", "normal", "water", "ceiling", "left", "right", "next", "nextHit")


class Census:
    """One run of the census, while it comes in."""

    def __init__(self, event: dict):
        self.id = int(event.get("census", 0))
        self.level = str(event.get("level") or "")
        self.mode = str(event.get("mode") or "")
        self.paths_name = str(event.get("paths") or "")
        self.parts = as_list(event.get("parts"))
        self.created = time.strftime("%Y-%m-%d %H:%M:%S")
        self.entities: dict | None = None
        self.nodes: dict[int, dict] = {}
        self.links: list[list] = []
        self.areas: dict[int, dict] = {}
        self.summary: dict | None = None
        self.error: str | None = None
        # Size of the capture zones, measured by the debug-server (zones.py).
        self.zones: list[dict] = []

    @property
    def name(self) -> str:
        """<level>_<mode>, the name of the waypoint-file (mapfiles/<name>.map)."""
        return self.paths_name or f"{self.level.rsplit('/', 1)[-1]}_{self.mode}"

    def add_nodes(self, event: dict) -> None:
        path = int(event["path"])
        entry = self.nodes.setdefault(path, {"loops": bool(event.get("loops")), "actions": [],
                                             **{key: [] for key in NODE_FIELDS}})
        if event.get("objectives") is not None:
            entry["objectives"] = as_list(event.get("objectives"))
        if event.get("vehicles") is not None:
            entry["vehicles"] = as_list(event.get("vehicles"))
        for key in NODE_FIELDS:
            entry[key].extend(as_list(event.get(key)))
        entry["actions"].extend(as_list(event.get("actions")))
        for link in as_list(event.get("links")):
            point, other_path, other_point, fractions, kind = as_list(link)
            self.links.append([path, int(point), int(other_path), int(other_point), as_list(fractions), kind])

    def add_area(self, event: dict) -> dict:
        area = {key: event.get(key) for key in ("name", "kind", "center", "radius", "x0", "z0", "step", "columns",
                                                 "rows", "layers")}
        if event.get("spawns"):
            area["spawns"] = as_list(event.get("spawns"))  # spawn areas: where the soldiers appear, on the ground
        if event.get("discs"):
            area["discs"] = as_list(event.get("discs"))  # ways: [x, z, radius] along the way, only they are measured
        area["cells"] = [None] * int(event.get("rows") or 0)
        self.areas[int(event["area"])] = area
        return area

    def add_area_row(self, event: dict) -> dict | None:
        area = self.areas.get(int(event.get("area", -1)))
        row = int(event.get("row", -1))
        if area is None or not 0 <= row < len(area["cells"]):
            return None
        area["cells"][row] = as_list(event.get("cells"))
        return area

    def progress(self) -> dict:
        rows = sum(len(area["cells"]) for area in self.areas.values())
        rows_done = sum(1 for area in self.areas.values() for row in area["cells"] if row is not None)
        return {
            "census": self.id,
            "name": self.name,
            "entities": self.entities is not None,
            "paths": len(self.nodes),
            "nodes": sum(len(entry["points"]) for entry in self.nodes.values()),
            "areas": len(self.areas),
            "areaRows": f"{rows_done}/{rows}",
            "done": self.summary is not None,
            "error": self.error,
        }

    def to_json(self) -> dict:
        return {
            "version": VERSION,
            "level": self.level,
            "mode": self.mode,
            "paths": self.name,
            "created": self.created,
            "parts": self.parts,
            "summary": self.summary,
            "entities": self.entities or {},
            "nodes": {str(path): entry for path, entry in sorted(self.nodes.items())},
            "links": self.links,
            "areas": [area for _, area in sorted(self.areas.items())],
            "zones": self.zones,
        }


class CensusStore:
    """Takes the census-events, saves every finished census into the folder."""

    def __init__(self, directory: Path | None):
        self.directory = directory
        self.current: Census | None = None
        # The last finished census: {"file", "progress", "save"}.
        self.last: dict | None = None
        # Counts the saves. The ids of the censuses start again with every reload of the mod.
        self.saves = 0

    def on_event(self, event: dict) -> Census | None:
        """Takes over one census-event. Returns the census it belongs to (None for an unknown one)."""
        kind = event.get("type")
        if kind == "census_started":
            self.current = Census(event)
            return self.current

        census = self.current
        if census is None or int(event.get("census", -1)) != census.id:
            return None

        if kind == "census_entities":
            census.entities = as_dict(event.get("data"))
        elif kind == "census_nodes":
            census.add_nodes(event)
        elif kind == "census_area":
            census.add_area(event)
        elif kind == "census_area_row":
            census.add_area_row(event)
        elif kind == "census_done":
            census.summary = {key: event.get(key) for key in ("raycasts", "seconds", "nodes", "cells")}
        elif kind == "census_aborted":
            census.error = str(event.get("reason") or "aborted")
        return census

    def save(self, census: Census) -> Path | None:
        if self.directory is None:
            return None
        self.directory.mkdir(parents=True, exist_ok=True)
        file = self.directory / f"{census.name}.json.gz"
        with gzip.open(file, "wt", encoding="utf-8") as stream:
            json.dump(census.to_json(), stream, separators=(",", ":"))
        self.saves += 1
        self.last = {"file": str(file), "progress": census.progress(), "save": self.saves}
        return file

    def status(self) -> dict:
        return {
            "directory": str(self.directory) if self.directory else None,
            "current": self.current.progress() if self.current else None,
            "last": self.last,
            "saves": self.saves,
            "files": sorted(file.name for file in self.directory.glob("*.json.gz"))
            if self.directory and self.directory.is_dir() else [],
        }


def load(file: Path | str) -> dict:
    """A saved census."""
    with gzip.open(file, "rt", encoding="utf-8") as stream:
        return json.load(stream)
