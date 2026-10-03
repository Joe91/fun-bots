"""Center of the server: takes the requests of the mod, updates state and analyzers, and pushes the changes to
all browsers (and other subscribers)."""

from __future__ import annotations

import json
import math
import queue
import threading
import time
from pathlib import Path
from typing import Any, Callable

from .analyzers import Analyzer, Finding
from .census.report import Report, build_report
from .census import navzones
from .census.store import Census, CensusStore
from .census.zones import ZoneEstimator
from .commands import Command, CommandQueue
from .paths.labeler import (Options, anchors_from_flags, anchors_from_labels, apply_patch, label, make_patch,
                            merge_anchors, uses_objectives)
from .paths.mapfile import MapData
from .protocol import as_list
from .rcon import RconClient, RconError
from .recorder import Recorder
from .state import ScanGrid, WorldState

# Seconds without request after which the mod counts as disconnected.
MOD_TIMEOUT = 4.0
# Seconds between two analysis-messages to the browsers.
ANALYSIS_INTERVAL = 1.0
# Events that get a message of their own. All others go with the next "frame" message.
OWN_MESSAGE_EVENTS = {"nodes", "nodes_started", "scan_started", "scan_row", "command_result"}
# Switches of the labeler the browser may set (paths/labeler.py, Options).
LABEL_OPTIONS = ("relabel", "relink", "crossings", "vehicles", "loops")
# Seconds to wait for the mod to take over the labels.
APPLY_TIMEOUT = 30.0
# Metres a node of a waypoint-file may be off the one in the game (the mod sends positions rounded to cm).
WRITE_TOLERANCE = 0.05
# The grids of a census are shown as scans with these ids (+ 100 * census + area), apart from the scans of the mod.
CENSUS_SCAN_BASE = 100000
# Grids around the objectives: metres around the measured capture-radius, the radius if nothing was measured yet,
# and the radius around an MCOM.
CENSUS_AREA_MARGIN = 15.0
CENSUS_UNKNOWN_RADIUS = 25.0
CENSUS_MCOM_RADIUS = 30.0
# Grids around the HQs: the bases, named like their objectives on the waypoints (GameDirector: "base us", "base ru").
CENSUS_BASE_RADIUS = 60.0
CENSUS_BASE_NAMES = {1: "base us", 2: "base ru"}


class LabelError(Exception):
    """The labeler can't run, or its result can't be applied."""


class Subscriber:
    """One browser (or script). Messages are pre-encoded JSON strings."""

    def __init__(self, maxsize: int = 2000):
        self.queue: queue.Queue[tuple[str, str]] = queue.Queue(maxsize=maxsize)

    def push(self, kind: str, data: str) -> None:
        try:
            self.queue.put_nowait((kind, data))
        except queue.Full:
            # Too slow: throw everything away and let the browser load the whole state again.
            while not self.queue.empty():
                try:
                    self.queue.get_nowait()
                except queue.Empty:
                    break
            self.queue.put_nowait(("resync", "{}"))


class Hub:
    def __init__(self, analyzers: list[Analyzer], recorder: Recorder | None = None, accept_commands: bool = True,
                 rcon: RconClient | None = None, mapfiles: Path | None = None, census: Path | None = None):
        self.lock = threading.RLock()
        self.state = WorldState()
        self.commands = CommandQueue()
        self.analyzers = analyzers
        self.recorder = recorder
        # False in replay-mode: nobody would answer.
        self.accept_commands = accept_commands
        # Direct connection to the RCON-port of the game-server, None without password.
        self.rcon = rcon
        self._subscribers: set[Subscriber] = set()
        self._subscribers_lock = threading.Lock()
        self._last_request = 0.0
        self._last_analysis = 0.0
        self.mod_connected = False
        self.requests = 0
        self.bytes_received = 0
        self.dropped_events = 0
        # The waypoint-files (mapfiles/ of the repository), for writing the labels.
        self.mapfiles = mapfiles
        # Last run of the labeler: {"level", "result", "patch"}, see label_paths.
        self.labels: dict | None = None
        # Hooks for own code: called with (payload) after every request of the mod, under the lock.
        self.on_ingest: list[Callable[[dict], None]] = []
        # The census of the level (census/), saved into the folder. The report of the last one is shown as findings.
        self.census = CensusStore(census)
        self.census_report: Report | None = None
        # Size of the capture zones, from who is inside them (census/zones.py).
        self.zones = ZoneEstimator()
        # Walking networks of the zones (census/navzones.py), shown on the map. Those of navzones/<level>_<mode>.json
        # are loaded for the running level (once per level, _auto_navzones).
        self.navzones: dict | None = None
        self._navzones_tried: str | None = None
        # The census the shown networks were built from (None: loaded from a file).
        self.navzones_census: str | None = None

    # --- mod-side ----------------------------------------------------------------------------------------------

    def ingest(self, payload: dict, size: int = 0) -> dict:
        """A request of the mod. Returns the answer (the commands for the mod)."""
        messages: list[tuple[str, Any]] = []
        with self.lock:
            now = time.monotonic()
            self._last_request = now
            self.requests += 1
            self.bytes_received += size
            self.dropped_events += int(payload.get("dropped") or 0)
            if not self.mod_connected:
                self.mod_connected = True
                messages.append(("status", self._status()))

            events = as_list(payload.get("events"))
            frames = as_list(payload.get("frames"))

            if self.recorder is not None:
                level = self.state.level
                for frame in frames:
                    level = (frame.get("meta") or {}).get("level") or level
                self.recorder.write(payload, level)

            frame_events = []
            for event in events:
                if not isinstance(event, dict):
                    continue
                if str(event.get("type") or "").startswith("census_"):
                    # Big, and only for the census: not into the state, the analyzers and the browsers.
                    self._census_event(event, messages)
                    continue
                if self.state.apply_event(event) == "reset":
                    self._reset(messages, already_reset=True)
                if event.get("type") == "nodes_started" and self.labels is not None:
                    # New waypoints, the labels were made for the old ones.
                    self.labels = None
                    messages.append(("labels", None))
                if event.get("type") == "command_result":
                    command = self.commands.resolve(event)
                    if command is not None:
                        messages.append(("command", command.to_json()))
                for analyzer in self.analyzers:
                    analyzer.on_event(event, self.state)
                if event.get("type") in OWN_MESSAGE_EVENTS:
                    if event.get("type") != "command_result":
                        messages.append((event["type"], event))
                else:
                    frame_events.append(event)

            for frame in frames:
                if self.state.apply_frame(frame):
                    self._reset(messages, already_reset=True)
                self.zones.on_frame(self.state)
                for analyzer in self.analyzers:
                    analyzer.on_frame(frame, self.state)

            if frames or frame_events:
                messages.append(("frame", {
                    "time": self.state.time,
                    "meta": self.state.meta,
                    "bots": list(self.state.bots.values()),
                    "players": list(self.state.players.values()),
                    "vehicles": list(self.state.vehicles.values()),
                    "objectives": self.state.objectives,
                    "extras": self.state.extras,
                    "events": frame_events,
                }))

            self._auto_navzones(messages)

            if now - self._last_analysis > ANALYSIS_INTERVAL:
                self._last_analysis = now
                messages.append(("analysis", self._analysis()))

            answer = {"commands": self.commands.take_pending() if self.accept_commands else []}

        self._publish(messages)
        return answer

    def _auto_navzones(self, messages: list) -> None:
        """The networks of the running level from navzones/ of the repository, if none are shown yet."""
        name = self.state.meta.get("paths")
        if self.navzones is not None or not name or name == self._navzones_tried or self.mapfiles is None:
            return
        self._navzones_tried = name
        file = self.mapfiles.parent / "navzones" / f"{name}.json"
        if not file.is_file():
            return
        try:
            self.navzones = json.loads(file.read_text(encoding="utf-8"))
            self.navzones_census = None
        except (OSError, ValueError) as error:
            print(f"navzones {file}: {error}")
            return
        messages.append(("navzones", self.navzones))

    def _reset(self, messages: list, already_reset: bool = False) -> None:
        if not already_reset:
            self.state.reset()
        self.labels = None
        self.census_report = None
        self.zones.reset()
        self.navzones = None
        self.navzones_census = None
        self._navzones_tried = None
        for analyzer in self.analyzers:
            analyzer.reset()
        if self.recorder is not None:
            self.recorder.split()
        messages.append(("reset", {"level": self.state.level}))

    def check_connection(self) -> None:
        """Called regularly by the server: notices a mod that stopped sending."""
        with self.lock:
            if not self.mod_connected or time.monotonic() - self._last_request < MOD_TIMEOUT:
                return
            self.mod_connected = False
            status = self._status()
        lost = self.commands.lose_sent()
        self._publish([("status", status)] + [("command", command.to_json()) for command in lost])

    # --- browser-side ------------------------------------------------------------------------------------------

    def submit_command(self, command_type: str, args: dict | None = None) -> Command:
        command = self.commands.submit(command_type, args)
        self._publish([("command", command.to_json())])
        return command

    def run_command(self, command_type: str, args: dict | None = None, timeout: float = 10.0) -> Command:
        """Sends a command and blocks until the mod answered (for own scripts). Check command.status."""
        command = self.submit_command(command_type, args)
        self.commands.wait(command, timeout)
        return command

    def clear_scans(self, scan: int | None = None) -> list[int]:
        """Forgets one scan (None = all), also in all browsers. A scan that is still running gets stopped."""
        with self.lock:
            removed = self.state.clear_scans(scan)
        running = [grid.scan for grid in removed if not grid.complete]
        if running and self.accept_commands:
            self.submit_command("scan_stop", {} if scan is None else {"scan": scan})
        ids = [grid.scan for grid in removed]
        self._publish([("scans_cleared", {"scans": ids})])
        return ids

    def run_rcon(self, words: list[str]) -> list[str]:
        """A command over the RCON-port. Raises RconError. The browsers get the new RCON-state."""
        assert self.rcon is not None
        try:
            return self.rcon.command(words)
        finally:
            self._publish([("status", self._status())])

    def check_rcon(self) -> None:
        """Logs in once, so problems show up at the start and not with the first command."""
        if self.rcon is None:
            return
        try:
            self.rcon.connect()
        except RconError:
            pass
        self._publish([("status", self._status())])

    # --- census (census/) ----------------------------------------------------------------------------------------

    def start_census(self, args: dict | None = None) -> Command:
        """Starts a census of the running level (MapCensus.lua). It is saved when done, see census_status.
        Without areas in args, the grids go around the capture points (measured radius) and the MCOMs."""
        return self.submit_command("census", self.census_args(args))

    def _census_areas(self) -> list[dict]:
        objectives = self.state.objectives or {}
        zones = {(zone["name"], tuple(round(value) for value in zone["pos"])): zone for zone in self.zones.to_json()}
        visited = {zone["name"] for zone in zones.values() if zone["samples"]}
        areas = []
        for flag in as_list(objectives.get("flags")):
            pos = as_list(flag.get("pos"))
            if len(pos) < 3:
                continue
            if flag.get("hq"):
                # The HQs of the running mode have a team, the ones of other modes (loaded as well) none.
                name = CENSUS_BASE_NAMES.get(int(flag.get("team") or 0))
                if name is not None:
                    areas.append({"name": name, "kind": "base", "pos": pos, "radius": CENSUS_BASE_RADIUS})
                continue
            zone = zones.get((flag.get("name"), tuple(round(value) for value in pos)))
            if zone and zone["samples"]:
                radius = zone["radius"] + CENSUS_AREA_MARGIN
            elif flag.get("name") in visited:
                continue  # Nobody was ever inside, but in another one of this name: a layout of another mode.
            else:
                radius = CENSUS_UNKNOWN_RADIUS + CENSUS_AREA_MARGIN
            areas.append({"name": flag.get("objective") or flag.get("name"), "kind": "capturepoint", "pos": pos,
                          "radius": round(radius, 1)})
        for mcom in as_list(objectives.get("mcoms")):
            pos = as_list(mcom.get("pos"))
            if len(pos) >= 3:
                areas.append({"name": mcom.get("name"), "kind": "mcom", "pos": pos, "radius": CENSUS_MCOM_RADIUS})
        return areas

    def census_args(self, args: dict | None = None) -> dict:
        """The arguments of a census: the areas around the objectives, and the bases from the waypoints in modes
        without HQs (rush, MapCensus.lua)."""
        args = dict(args or {})
        with self.lock:
            if "areas" not in args:
                args["areas"] = self._census_areas()
            if "basePaths" not in args:
                args["basePaths"] = not any(area["kind"] == "base" for area in args["areas"])
        return args

    def census_status(self) -> dict:
        with self.lock:
            status = self.census.status()
            status["zones"] = self.zones.to_json()
            report = self.census_report
            if report is not None:
                status["report"] = {"name": report.name, "summary": report.summary, "issues": report.counts()}
            return status

    def _census_event(self, event: dict, messages: list) -> None:
        census = self.census.on_event(event)
        if census is None:
            return
        kind = event.get("type")
        if kind == "census_area":
            # Shown like a scan of the mod (several layers), so the grid can be checked on the map.
            scan = CENSUS_SCAN_BASE + 100 * census.id + int(event["area"])
            self.state.scans[scan] = ScanGrid(scan=scan, x0=float(event["x0"]), z0=float(event["z0"]),
                                              step=float(event["step"]), columns=int(event["columns"]),
                                              rows=int(event["rows"]), layers=int(event.get("layers") or 1))
            messages.append(("scan_started", {"type": "scan_started", "scan": scan, "x0": event["x0"],
                                              "z0": event["z0"], "step": event["step"], "columns": event["columns"],
                                              "rows": event["rows"], "layers": event.get("layers") or 1}))
        elif kind == "census_area_row":
            scan = CENSUS_SCAN_BASE + 100 * census.id + int(event.get("area", 0))
            grid = self.state.scans.get(scan)
            if grid is not None:
                heights, normals = _cells_to_scan(as_list(event.get("cells")))
                grid.set_row(int(event["row"]), heights, normals)
                messages.append(("scan_row", {"type": "scan_row", "scan": scan, "row": event["row"],
                                              "heights": heights, "normals": normals}))
        elif kind == "census_done":
            census.zones = self.zones.to_json()
            # Saving and checking take a while, the mod must not wait for the answer that long.
            threading.Thread(target=self._finish_census, args=(census,), name="census", daemon=True).start()
        messages.append(("census", census.progress()))

    def _finish_census(self, census: Census) -> None:
        try:
            file = self.census.save(census)
            report = build_report(census.to_json())
        except Exception as error:  # noqa: BLE001 - shown in the terminal, the server keeps running
            print(f"census {census.name}: {error!r}")
            return
        print(f"census saved to {file}" if file else "census not saved (no folder, start with --census)")
        print(report.text())
        with self.lock:
            self.census_report = report
        self._publish([("census", census.progress())])
        if census.areas:
            data = navzones.build(census.to_json())
            if file is not None:
                navzones.save(data, file.with_name(f"{census.name}.navzones.json"))
            print(navzones.summary(data))
            self.set_navzones(data, census.name)

    def set_navzones(self, data: dict | None, census: str | None = None) -> None:
        """Shows walking networks on the map of all browsers. census: the one they were built from."""
        with self.lock:
            self.navzones = data
            self.navzones_census = census
        self._publish([("navzones", data)])

    def apply_navzones(self, save: bool = True, timeout: float = APPLY_TIMEOUT, census: str | None = None) -> dict:
        """Sends the networks shown on the map to the mod (NavZones.lua), which saves them into mod.db with save.
        census: only the networks built from this census, not older ones loaded from navzones/ (they are built in the
        background after the census)."""
        with self.lock:
            data = self.navzones
            built_from = self.navzones_census
        if data is None:
            raise LabelError("no zone networks: run a census or load them first")
        if census is not None and built_from != census:
            raise LabelError(f"the networks of the census {census} aren't built yet")
        if not self.accept_commands:
            raise LabelError("replay-mode, no mod to send the networks to")
        command = self.submit_command("navzones_apply", {"map": data.get("map"), "mesh": data, "save": save})
        self.commands.wait(command, timeout)
        result = command.to_json()
        # Saved in the game: also into navzones/<map>.json of the repository (fun-bots-helper imports it into mod.db).
        if save and command.status == "ok" and self.mapfiles is not None and data.get("map"):
            folder = self.mapfiles.parent / "navzones"
            folder.mkdir(exist_ok=True)
            file = folder / f"{data['map']}.json"
            navzones.save(data, file)
            result["file"] = str(file)
        return result

    def navzones_from(self, file: Path | None = None) -> dict:
        """Builds the networks from a census (default: the one of the running level) or loads saved ones."""
        if file is None:
            with self.lock:
                meta = self.state.meta
                name = meta.get("paths") or f"{str(meta.get('level') or '').rsplit('/', 1)[-1]}_{meta.get('mode')}"
            if self.census.directory is None:
                raise FileNotFoundError("no census-folder")
            file = self.census.directory / f"{name}.json.gz"
        data = navzones.load_or_build(file)
        self.set_navzones(data)
        return {"map": data.get("map"), "zones": len(data.get("zones") or [])}

    def _census_findings(self) -> list[dict]:
        report = self.census_report
        if report is None:
            return []
        return [Finding(key=issue.key, message=issue.message, severity=issue.severity, time=self.state.time,
                        pos=list(issue.pos) if issue.pos else None, analyzer="census",
                        data={"kind": issue.kind}).to_json()
                for issue in report.limited()]

    # --- labeling the paths (paths/labeler.py) ------------------------------------------------------------------

    def label_paths(self, options: dict | None = None) -> dict:
        """Runs the labeler on the waypoints of the game (load them first). Nothing changes in the game yet: the
        result waits in self.labels for apply_labels or write_labels, the browsers show it."""
        options = options or {}
        with self.lock:
            rows = self.state.paths
            if not rows:
                raise LabelError("no waypoints: load the waypoints first")
            if any("inputs" not in entry for entry in rows.values()):
                raise LabelError("the waypoints came without links: update the mod and load them again")
            before = MapData.from_rows(rows)
            data = MapData.from_rows(rows)
            flags = list(self.state.objectives.get("flags") or [])
            meta = self.state.meta
            mode = str(meta.get("mode") or "")
            level = meta.get("paths") or f"{str(meta.get('level') or '').rsplit('/', 1)[-1]}_{mode}"

        anchors = merge_anchors(anchors_from_flags(flags), anchors_from_labels(before))
        switches = {key: bool(options[key]) for key in LABEL_OPTIONS if key in options}
        result = label(data, anchors, Options(objectives=uses_objectives(mode), **switches))
        labels = {"level": level, "result": result.to_json(), "patch": make_patch(before, data)}
        with self.lock:
            self.labels = labels
            answer = self._labels_json()
        self._publish([("labels", answer)])
        return answer

    def apply_labels(self, save: bool = True, timeout: float = APPLY_TIMEOUT) -> dict:
        """Sends the labels to the mod (paths_apply), which saves them into mod.db with save. Blocks until the
        mod answered."""
        with self.lock:
            labels = self._current_labels()
            if not labels["patch"]:
                raise LabelError("nothing to change")
        if not self.accept_commands:
            raise LabelError("replay-mode, no mod to send the labels to")
        command = self.submit_command("paths_apply", {"paths": labels["patch"], "save": save})
        self.commands.wait(command, timeout)
        if command.status == "ok":
            with self.lock:
                try:
                    self._patch_rows(labels["patch"])
                except (KeyError, ValueError):
                    pass  # The waypoints were loaded again in the meantime, they are up to date.
                if self.labels is labels:
                    self.labels = None
                paths = json.loads(json.dumps(self.state.paths))
            self._publish([("labels", None), ("paths", paths)])
        return command.to_json()

    def write_labels(self) -> dict:
        """Writes the labels into the waypoint-file of the level. The file has to hold the same paths as the game."""
        with self.lock:
            labels = self._current_labels()
            rows = {entry["path"]: self.state.paths.get(entry["path"]) for entry in labels["patch"]}
        if self.mapfiles is None:
            raise LabelError("no folder for the waypoint-files, start with --mapfiles")
        file = self.mapfiles / f"{labels['level']}.map"
        if not file.is_file():
            raise LabelError(f"{file} doesn't exist: export the waypoints with the fun-bots-helper first")
        data = MapData.load(file)
        try:
            apply_patch(data, labels["patch"])
            for index, row in rows.items():
                for node, pos in zip(data.paths[index].nodes, (row or {}).get("points") or []):
                    if math.dist(node.pos, pos) > WRITE_TOLERANCE:
                        raise ValueError(f"node {index}:{node.point} is somewhere else")
        except ValueError as error:
            raise LabelError(f"{file.name} doesn't hold the paths of the game ({error}): save them in the game and "
                             f"export them with the fun-bots-helper first") from error
        data.save(file)
        return {"file": str(file), "paths": len(labels["patch"])}

    def _current_labels(self) -> dict:
        if self.labels is None:
            raise LabelError("no labels: run the labeler first")
        return self.labels

    def _labels_json(self) -> dict | None:
        if self.labels is None:
            return None
        return dict(self.labels["result"], level=self.labels["level"], patched=len(self.labels["patch"]))

    def _patch_rows(self, patch: list[dict]) -> None:
        """Takes the applied labels over into the waypoints of the state."""
        rows = self.state.paths
        data = MapData.from_rows(rows)
        apply_patch(data, patch)
        for entry in patch:
            path = data.paths[entry["path"]]
            row = rows[entry["path"]]
            row["inputs"] = [node.input for node in path.nodes]
            row["data"] = {str(node.point): node.data for node in path.nodes if node.data}
            row["objectives"] = path.objectives

    def subscribe(self) -> Subscriber:
        subscriber = Subscriber()
        with self._subscribers_lock:
            self._subscribers.add(subscriber)
        return subscriber

    def unsubscribe(self, subscriber: Subscriber) -> None:
        with self._subscribers_lock:
            self._subscribers.discard(subscriber)

    def snapshot(self) -> dict:
        """The whole state for a new browser."""
        with self.lock:
            data = self.state.to_json()
            data["status"] = self._status()
            data["analysis"] = self._analysis()
            data["commands"] = self.commands.history()[:50]
            data["labels"] = self._labels_json()
            data["navzones"] = self.navzones
            return data

    # --- helpers -----------------------------------------------------------------------------------------------

    def _status(self) -> dict:
        return {
            "modConnected": self.mod_connected,
            "acceptCommands": self.accept_commands,
            "requests": self.requests,
            "bytesReceived": self.bytes_received,
            "droppedEvents": self.dropped_events,
            "recording": str(self.recorder.path) if self.recorder and self.recorder.path else None,
            "rcon": self.rcon.to_json() if self.rcon else None,
        }

    def _analysis(self) -> dict:
        findings = []
        stats = {}
        for analyzer in self.analyzers:
            findings.extend(finding.to_json() for finding in analyzer.findings())
            analyzer_stats = analyzer.stats()
            if analyzer_stats:
                stats[analyzer.name] = analyzer_stats
        findings.sort(key=lambda finding: -finding["time"])
        census = self._census_findings()
        if census:
            findings = census + findings
            stats["census"] = self.census_report.counts() if self.census_report else {}
        stats["connection"] = {"requests": self.requests, "MB received": round(self.bytes_received / 1e6, 1),
                               "dropped events": self.dropped_events}
        return {"findings": findings[:200 + len(census)], "stats": stats}

    def _publish(self, messages: list[tuple[str, Any]]) -> None:
        if not messages:
            return
        encoded = [(kind, json.dumps(data, separators=(",", ":"))) for kind, data in messages]
        with self._subscribers_lock:
            subscribers = list(self._subscribers)
        for subscriber in subscribers:
            for kind, data in encoded:
                subscriber.push(kind, data)


def _cells_to_scan(cells: list) -> tuple[list, list]:
    """Cells of a census-grid ([height, normal-y, edges, headroom] per layer) as heights and normals of a scan."""
    heights, normals = [], []
    for cell in cells:
        values = as_list(cell)
        if not values:
            heights.append(False)
            normals.append(False)
            continue
        heights.append(values[0::4])
        normals.append(values[1::4])
    return heights, normals
