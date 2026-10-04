"""The levels of mapfiles/ and what has been done for them: the Maps tab of the web interface.

For each waypoint-file it tells which steps are done (see NEW_MAP.md) and runs the missing ones, one job after the
other, each as the same command a person would type:

    export   mod.db -> mapfiles/<map>.map (the paths recorded in the game)
    label    links and loop mode (python -m funbots_debug.paths <file> --write)
    import   mapfiles/<map>.map (and navzones/<map>.json) -> mod.db
    census   measure the level and make its mesh (python -m funbots_debug.census run --map ... --apply), needs the
             game-server and RCON
    cut      navigation paths (python -m funbots_debug.census navpaths <map> --write --db mod.db); a level that is cut
             already is cut again from the newest version in git without navigation paths
    check    rays of the game over the mesh (python -m funbots_debug.census check <map>, switches the level), then
             the cut again: walls and ceilings the census missed are left out of the mesh
    report   the checks of the census

    GET  /api/maps            the levels and their state, the jobs
    POST /api/maps/run        {maps: [name], steps: [step]} or {maps, steps: "missing"}: queue jobs
    POST /api/maps/cancel     {job}: stop a queued or running job (all with job = null)
"""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
import threading
import time
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

from .census.navpaths import MESH_ROW, write_db
from .paths.mapfile import HEADER, MapData

REPO = Path(__file__).resolve().parents[3]
MAPFILES = REPO / "mapfiles"
NAVZONES = REPO / "navzones"
MOD_DB = REPO / "mod.db"
DEBUG_SERVER = Path(__file__).resolve().parents[1]
CENSUS = DEBUG_SERVER / "census"

STEPS = ("export", "label", "import", "census", "cut", "check", "report")
# Modes whose bots go for objectives: they need the census, the mesh and the cut. The others only walk the paths.
MESH_MODES = ("ConquestLarge0", "ConquestSmall0", "ConquestAssaultLarge0", "ConquestAssaultSmall0",
              "ConquestAssaultSmall1", "RushLarge0", "SquadRush0", "TankSuperiority0")
PATH_MODES = ("TeamDeathMatch0", "TeamDeathMatchC0", "SquadDeathMatch0", "GunMaster0", "Scavenger0", "Domination0")
LOG_LINES = 400  # lines of output kept per job
STATUS_TTL = 20.0  # seconds the state of the levels is reused (reading mod.db takes a moment)


def kind_of(mode: str) -> str:
    if mode in MESH_MODES:
        return "mesh"
    if mode in PATH_MODES:
        return "paths"
    if mode == "AirSuperiority0":
        return "none"
    return "unsupported"


# --- mod.db --------------------------------------------------------------------------------------------------------

def _tables(connection: sqlite3.Connection) -> set[str]:
    return {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def _db_text(connection: sqlite3.Connection, name: str) -> str | None:
    """The waypoints of the level in mod.db, as the text of a waypoint-file (like the export of the fun-bots-helper)."""
    try:
        rows = connection.execute(f"SELECT pathIndex, pointIndex, transX, transY, transZ, inputVar, data FROM "
                                  f"{name}_table ORDER BY pathIndex, pointIndex ASC").fetchall()
    except sqlite3.Error:
        return None
    lines = [HEADER]
    for row in rows:
        values = [format(value, ".6f") if isinstance(value, float) else str(value if value is not None else "")
                  for value in row]
        lines.append(";".join(values))
    return "\n".join(lines) + "\n"


def export_map(db: Path, name: str) -> MapData:
    """The waypoints of mod.db (what the node-editor saved in the game)."""
    connection = sqlite3.connect(db)
    try:
        text = _db_text(connection, name)
    finally:
        connection.close()
    if text is None:
        raise ValueError(f"{name}_table is not in {db}")
    return MapData.parse(text)


def import_map(db: Path, name: str, data: MapData, networks: dict | None) -> None:
    """The waypoints (and the mesh, if any) into mod.db. Without mesh only the waypoints, the mesh-table stays."""
    if networks is not None:
        write_db(db, name, data, networks)
        return
    connection = sqlite3.connect(db, timeout=30.0)
    try:
        with connection:
            table = f"{name}_table"
            connection.execute(f"DROP TABLE IF EXISTS {table}")
            connection.execute(f"CREATE TABLE {table} (id INTEGER PRIMARY KEY AUTOINCREMENT, pathIndex INTEGER, "
                               "pointIndex INTEGER, transX FLOAT, transY FLOAT, transZ FLOAT, inputVar INTEGER, "
                               "data TEXT)")
            rows = []
            for line in data.dumps().splitlines()[1:]:
                items = line.split(";", 6)
                rows.append((int(items[0]), int(items[1]), float(items[2]), float(items[3]), float(items[4]),
                             int(items[5]), items[6] if len(items) > 6 else ""))
            connection.executemany(f"INSERT INTO {table} (pathIndex, pointIndex, transX, transY, transZ, inputVar, "
                                   "data) VALUES (?, ?, ?, ?, ?, ?, ?)", rows)
    finally:
        connection.close()


# --- state of the levels -------------------------------------------------------------------------------------------

def _git_changes(repo: Path) -> dict[str, str]:
    """mapfiles/ and navzones/ files that differ from the last commit: path -> "changed" | "new"."""
    try:
        output = subprocess.run(["git", "-C", str(repo), "status", "--porcelain", "--", "mapfiles", "navzones"],
                                capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    changes = {}
    for line in output.splitlines():
        status, path = line[:2], line[3:].strip()
        changes[path] = "new" if "?" in status or "A" in status else "changed"
    return changes


def level_states(mapfiles: Path = MAPFILES, navzones: Path = NAVZONES, census: Path = CENSUS,
                 db: Path = MOD_DB, repo: Path = REPO) -> list[dict]:
    connection = sqlite3.connect(db) if db.is_file() else None
    tables = _tables(connection) if connection is not None else set()
    git = _git_changes(repo)
    states = []
    try:
        for file in sorted(mapfiles.glob("*.map")):
            name = file.stem
            level, _, mode = name.rpartition("_")
            text = file.read_text(encoding="utf-8")
            data = MapData.parse(text)
            state = {
                "name": name, "level": level, "mode": mode, "kind": kind_of(mode),
                "paths": len(data.paths), "waypoints": sum(len(path.nodes) for path in data.paths.values()),
                "cut": any("Nav" in path.first.data for path in data.paths.values()),
                "navigation": sum(1 for path in data.paths.values() if "Nav" in path.first.data),
                "links": sum(len(node.links) for path in data.paths.values() for node in path.nodes),
                "git": git.get(f"mapfiles/{name}.map") or git.get(f"navzones/{name}.json") or "",
            }
            census_file = census / f"{name}.json.gz"
            state["census"] = census_file.stat().st_mtime if census_file.is_file() else None
            checks_file = census / f"{name}.checks.json"
            state["checked"] = checks_file.stat().st_mtime if checks_file.is_file() else None
            zones_file = navzones / f"{name}.json"
            mesh = None
            if zones_file.is_file():
                try:
                    networks = json.loads(zones_file.read_text(encoding="utf-8"))
                    mesh = {"zones": len(networks.get("zones") or []), "points": len(networks.get("points") or []),
                            "junctions": len(networks.get("attach") or [])}
                except (OSError, ValueError):
                    mesh = {"error": "unreadable"}
            state["mesh"] = mesh
            # mod.db: the same waypoints as the file?
            if connection is None or f"{name}_table" not in tables:
                state["db"] = "missing"
            else:
                db_text = _db_text(connection, name)
                state["db"] = "same" if db_text is not None and MapData.parse(db_text).dumps() == data.dumps() \
                    else "differs"
            if mesh is not None and connection is not None:
                row = None
                if f"{name}_navzones" in tables:
                    row = connection.execute(f"SELECT data FROM {name}_navzones WHERE name=?", (MESH_ROW,)).fetchone()
                if row is None:
                    state["dbMesh"] = "missing"
                else:
                    try:
                        same = json.loads(row[0]) == json.loads(zones_file.read_text(encoding="utf-8"))
                    except ValueError:
                        same = False
                    state["dbMesh"] = "same" if same else "differs"
            else:
                state["dbMesh"] = None
            state["missing"] = missing_steps(state)
            states.append(state)
    finally:
        if connection is not None:
            connection.close()
    return states


def missing_steps(state: dict) -> list[str]:
    """What is still to do for the level, in order. Export from mod.db is never guessed: if the game has other
    waypoints than the file, the person decides which ones are right."""
    steps = []
    if state["kind"] == "mesh":
        if not state["cut"]:
            if state["db"] != "same":
                steps.append("import")
            if state["census"] is None or state["mesh"] is None:
                steps.append("census")
            steps.append("cut")
            steps.append("check")
        else:
            if state["db"] != "same" or state.get("dbMesh") not in ("same", None):
                steps.append("import")
            if state.get("checked") is None:
                steps.append("check")
    elif state["kind"] == "paths":
        if state["links"] == 0:
            steps.append("label")
        if state["db"] != "same":
            steps.append("import")
    return steps


# --- jobs ----------------------------------------------------------------------------------------------------------

@dataclass
class Job:
    id: int
    map: str
    step: str
    state: str = "queued"  # queued | running | done | failed | cancelled
    started: float | None = None
    ended: float | None = None
    log: deque = field(default_factory=lambda: deque(maxlen=LOG_LINES))
    process: subprocess.Popen | None = None

    def to_json(self) -> dict:
        return {"id": self.id, "map": self.map, "step": self.step, "state": self.state, "started": self.started,
                "ended": self.ended, "log": list(self.log)}


class MapWorkbench:
    """Runs the steps for the levels, one job after the other, in a thread of its own."""

    def __init__(self, server_url: str, restart_command: str | None = None, mapfiles: Path = MAPFILES,
                 navzones: Path = NAVZONES, census: Path = CENSUS, db: Path = MOD_DB, repo: Path = REPO):
        self.server_url = server_url
        self.restart_command = restart_command
        self.mapfiles, self.navzones, self.census, self.db, self.repo = mapfiles, navzones, census, db, repo
        self.jobs: list[Job] = []
        self._next_id = 1
        self._lock = threading.Lock()
        self._wake = threading.Event()
        self._states: list[dict] | None = None
        self._states_time = 0.0
        self._refreshing = False
        self._thread = threading.Thread(target=self._run, name="map-jobs", daemon=True)
        self._thread.start()

    # --- state ---------------------------------------------------------------------------------------------------

    def states(self, refresh: bool = False) -> list[dict]:
        """The state of the levels (reading all of them takes seconds): the last one, read anew in the background
        when it is older than STATUS_TTL. refresh: wait for a fresh one."""
        stale = self._states is None or time.monotonic() - self._states_time > STATUS_TTL
        # Not while a job runs: reading mod.db would block the job writing it.
        busy = any(job.state == "running" for job in self.jobs)
        if busy and self._states is not None:
            return self._states
        if refresh or self._states is None:
            self._refresh()
        elif stale and not self._refreshing:
            self._refreshing = True
            threading.Thread(target=self._refresh, name="map-states", daemon=True).start()
        return self._states or []

    def _refresh(self) -> None:
        try:
            states = level_states(self.mapfiles, self.navzones, self.census, self.db, self.repo)
            self._states = states
            self._states_time = time.monotonic()
        finally:
            self._refreshing = False

    def to_json(self, refresh: bool = False) -> dict:
        maps = self.states(refresh)
        with self._lock:
            jobs = [job.to_json() for job in self.jobs[-50:]]
        return {"maps": maps, "jobs": jobs, "steps": list(STEPS), "restartCommand": self.restart_command or "",
                "refreshing": self._refreshing}

    def start_game(self) -> dict:
        """Starts the game-server with the command of --game-command (detached, it outlives the debug-server)."""
        if not self.restart_command:
            raise OSError("no command to start the game-server (--game-command, or the field in the Maps tab)")
        subprocess.Popen(self.restart_command, shell=True, cwd=DEBUG_SERVER, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {"started": self.restart_command}

    # --- queue ---------------------------------------------------------------------------------------------------

    def enqueue(self, maps: list[str], steps, restart_command: str | None = None) -> list[dict]:
        if restart_command is not None:
            self.restart_command = restart_command.strip() or None
        known = {state["name"]: state for state in self.states()}
        added = []
        with self._lock:
            for name in maps:
                state = known.get(name)
                if state is None:
                    continue
                wanted = state["missing"] if steps == "missing" else [step for step in STEPS if step in steps]
                for step in wanted:
                    job = Job(self._next_id, name, step)
                    self._next_id += 1
                    self.jobs.append(job)
                    added.append(job.to_json())
        self._wake.set()
        return added

    def cancel(self, job_id: int | None) -> int:
        count = 0
        with self._lock:
            for job in self.jobs:
                if (job_id is None or job.id == job_id) and job.state in ("queued", "running"):
                    if job.process is not None and job.process.poll() is None:
                        job.process.terminate()
                    job.state = "cancelled"
                    job.ended = time.time()
                    count += 1
        return count

    def _run(self) -> None:
        while True:
            self._wake.wait(1.0)
            self._wake.clear()
            while True:
                with self._lock:
                    job = next((job for job in self.jobs if job.state == "queued"), None)
                    if job is None:
                        break
                    job.state = "running"
                    job.started = time.time()
                try:
                    ok = self._execute(job)
                except Exception as error:  # noqa: BLE001 (a job must never stop the queue)
                    job.log.append(f"error: {error}")
                    ok = False
                with self._lock:
                    if job.state == "running":
                        job.state = "done" if ok else "failed"
                    job.ended = time.time()
                    if not ok:
                        # The following steps of this level need this one.
                        for other in self.jobs:
                            if other.map == job.map and other.state == "queued":
                                other.state = "cancelled"
                                other.log.append(f"cancelled: {job.step} failed")
                self._states_time = 0.0

    # --- steps ---------------------------------------------------------------------------------------------------

    def _execute(self, job: Job) -> bool:
        name = job.map
        level, _, mode = name.rpartition("_")
        file = self.mapfiles / f"{name}.map"
        if job.step == "export":
            data = export_map(self.db, name)
            data.save(file)
            job.log.append(f"written {file} ({len(data.paths)} paths) from {self.db}")
            return True
        if job.step == "import":
            data = MapData.load(file)
            zones_file = self.navzones / f"{name}.json"
            networks = json.loads(zones_file.read_text(encoding="utf-8")) if zones_file.is_file() else None
            import_map(self.db, name, data, networks)
            job.log.append(f"written {name} into {self.db}" + (" with its mesh" if networks else ""))
            return True
        if job.step == "label":
            return self._command(job, [sys.executable, "-m", "funbots_debug.paths", str(file), "--write"])
        if job.step == "census":
            command = [sys.executable, "-u", "-m", "funbots_debug.census", "run", "--server", self.server_url,
                       "--map", f"{level} {mode}", "--apply"]
            if self.restart_command:
                command += ["--restart-command", self.restart_command]
            return self._command(job, command)
        if job.step == "cut":
            if any("Nav" in path.first.data for path in MapData.load(file).paths.values()) \
                    and not self._restore_uncut(job, file):
                return False
            return self._command(job, [sys.executable, "-m", "funbots_debug.census", "navpaths", name, "--write",
                                       "--db", str(self.db)])
        if job.step == "check":
            if not self._command(job, [sys.executable, "-u", "-m", "funbots_debug.census", "check", name, "--server",
                                       self.server_url]):
                return False
            if not self._restore_uncut(job, file):
                return False
            return self._command(job, [sys.executable, "-m", "funbots_debug.census", "navpaths", name, "--write",
                                       "--db", str(self.db)])
        if job.step == "report":
            return self._command(job, [sys.executable, "-m", "funbots_debug.census", "report",
                                       str(self.census / f"{name}.json.gz"), "--issues", "30"])
        job.log.append(f"unknown step {job.step}")
        return False

    def _restore_uncut(self, job: Job, file: Path) -> bool:
        """The newest version of the waypoint-file in git without navigation paths (the cut is made from it)."""
        relative = file.relative_to(self.repo).as_posix()
        try:
            commits = subprocess.run(["git", "-C", str(self.repo), "log", "--format=%h", "--", relative],
                                     capture_output=True, text=True, timeout=30).stdout.split()
            for commit in commits:
                text = subprocess.run(["git", "-C", str(self.repo), "show", f"{commit}:{relative}"],
                                      capture_output=True, text=True, timeout=30).stdout
                if text and '"Nav"' not in text:
                    file.write_text(text, encoding="utf-8")
                    job.log.append(f"{file.name}: the uncut version of {commit}")
                    return True
        except (OSError, subprocess.SubprocessError) as error:
            job.log.append(f"git: {error}")
            return False
        job.log.append(f"{file.name}: no version without navigation paths in git, record the paths anew")
        return False

    def _command(self, job: Job, command: list[str]) -> bool:
        job.log.append("$ " + " ".join(command[1:] if command[0] == sys.executable else command))
        environment = dict(os.environ, PYTHONUNBUFFERED="1")
        process = subprocess.Popen(command, cwd=DEBUG_SERVER, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, env=environment)
        job.process = process
        assert process.stdout is not None
        for line in process.stdout:
            # Progress lines rewrite themselves with \r: keep the last state only.
            line = line.rstrip("\n").rsplit("\r", 1)[-1]
            if line:
                job.log.append(line)
        process.wait()
        job.process = None
        if process.returncode != 0 and job.state == "running":
            job.log.append(f"exit code {process.returncode}")
        return process.returncode == 0
